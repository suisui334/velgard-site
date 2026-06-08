-- 055_profile_avatars_storage_schema_apply_draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
--
-- Purpose:
-- - Prepare the MVP schema and storage policy shape for account/profile avatars.
-- - Store only a bucket object path in public.profiles, not a full image URL.
-- - Expose public avatar fields through public_profiles and public comment display.
--
-- Scope:
-- - profiles.avatar_path / profiles.avatar_updated_at
-- - public.public_profiles view public field extension
-- - public.get_public_session_comments(text) public avatar fields
-- - avatars storage bucket draft
-- - owner-only storage policies draft
-- - authenticated avatar path update/clear RPCs
--
-- Out of scope in this draft:
-- - Frontend wiring
-- - Real file upload
-- - Dashboard operation
-- - Any secret, token, real user id, real avatar path, or full URL recording

begin;

-- 1. Profile avatar metadata.
alter table public.profiles
  add column if not exists avatar_path text,
  add column if not exists avatar_updated_at timestamptz;

alter table public.profiles
  drop constraint if exists profiles_avatar_path_safe_check;

alter table public.profiles
  add constraint profiles_avatar_path_safe_check
  check (
    avatar_path is null
    or (
      char_length(avatar_path) <= 300
      and avatar_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[A-Za-z0-9._-]+\.(png|jpg|jpeg|webp)$'
      and position('..' in avatar_path) = 0
      and position('//' in avatar_path) = 0
    )
  );

comment on column public.profiles.avatar_path is
  'Public avatar object path in the avatars bucket. This stores an object key, not a full URL.';

comment on column public.profiles.avatar_updated_at is
  'Avatar metadata last-change timestamp for cache invalidation and display refresh.';

-- 2. Public profile view. Keep email, auth ids, contact-only fields, and tokens out.
create or replace view public.public_profiles
with (security_barrier = true)
as
select
  id,
  display_name,
  avatar_path,
  avatar_updated_at
from public.profiles;

grant select on public.public_profiles to anon, authenticated;

-- 3. Public comments RPC. Return public avatar fields next to display_name.
-- Changing a table-returning shape requires replacing the function signature.
drop function if exists public.get_public_session_comments(text);

create function public.get_public_session_comments(
  target_session_id text
)
returns table (
  comment_id uuid,
  session_id text,
  display_name text,
  avatar_path text,
  avatar_updated_at timestamptz,
  body text,
  application_status text,
  created_at timestamptz,
  updated_at timestamptz,
  edited_at timestamptz,
  is_own boolean,
  can_edit boolean,
  can_delete boolean
)
language sql
security definer
stable
set search_path = ''
as $$
  select
    c.id as comment_id,
    c.session_id,
    p.display_name,
    p.avatar_path,
    p.avatar_updated_at,
    c.body,
    sa.status as application_status,
    c.created_at,
    c.updated_at,
    c.edited_at,
    auth.uid() is not null and c.user_id = auth.uid() as is_own,
    auth.uid() is not null and c.user_id = auth.uid() and c.deleted_at is null as can_edit,
    auth.uid() is not null and c.user_id = auth.uid() and c.deleted_at is null as can_delete
  from public.session_comments c
  join public.sessions s
    on s.id = c.session_id
  join public.profiles p
    on p.id = c.user_id
  left join public.session_applications sa
    on sa.session_id = c.session_id
   and sa.user_id = c.user_id
  where c.session_id = target_session_id
    and c.deleted_at is null
    and s.visibility = 'public'
    and s.status not in ('draft', 'canceled')
  order by c.created_at asc, c.id asc;
$$;

revoke all on function public.get_public_session_comments(text) from public;
grant execute on function public.get_public_session_comments(text) to anon, authenticated;

-- 4. Storage bucket draft.
-- Public read is intended because avatars are public display assets.
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'avatars',
  'avatars',
  true,
  1048576,
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- 5. Storage object policies draft.
-- Path convention: <auth.uid()>/<filename> under bucket avatars.
drop policy if exists avatars_public_read on storage.objects;
drop policy if exists avatars_owner_insert on storage.objects;
drop policy if exists avatars_owner_update on storage.objects;
drop policy if exists avatars_owner_delete on storage.objects;

create policy avatars_public_read
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'avatars');

create policy avatars_owner_insert
on storage.objects
for insert
to authenticated
with check (
  auth.uid() is not null
  and bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
  and lower(storage.extension(name)) in ('png', 'jpg', 'jpeg', 'webp')
);

create policy avatars_owner_update
on storage.objects
for update
to authenticated
using (
  auth.uid() is not null
  and bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  auth.uid() is not null
  and bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
  and lower(storage.extension(name)) in ('png', 'jpg', 'jpeg', 'webp')
);

create policy avatars_owner_delete
on storage.objects
for delete
to authenticated
using (
  auth.uid() is not null
  and bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- 6. Avatar metadata RPCs.
-- The frontend uploads/removes storage objects first, then records or clears the path.
create or replace function public.update_my_avatar_path(new_avatar_path text)
returns table (
  display_name text,
  avatar_path text,
  avatar_updated_at timestamptz
)
language plpgsql
security definer
volatile
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_avatar_path text := nullif(trim(coalesce(new_avatar_path, '')), '');
begin
  if v_user_id is null then
    raise exception 'auth_required' using errcode = '28000';
  end if;

  if v_avatar_path is null then
    raise exception 'avatar_path_required' using errcode = '22023';
  end if;

  if v_avatar_path not like v_user_id::text || '/%' then
    raise exception 'avatar_path_owner_mismatch' using errcode = '42501';
  end if;

  if char_length(v_avatar_path) > 300
     or v_avatar_path !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[A-Za-z0-9._-]+\.(png|jpg|jpeg|webp)$'
     or position('..' in v_avatar_path) > 0
     or position('//' in v_avatar_path) > 0 then
    raise exception 'avatar_path_invalid' using errcode = '22023';
  end if;

  return query
  update public.profiles as p
     set avatar_path = v_avatar_path,
         avatar_updated_at = now()
   where p.id = v_user_id
   returning
     p.display_name,
     p.avatar_path,
     p.avatar_updated_at;
end;
$$;

revoke all on function public.update_my_avatar_path(text) from public;
grant execute on function public.update_my_avatar_path(text) to authenticated;

create or replace function public.clear_my_avatar_path()
returns table (
  display_name text,
  avatar_path text,
  avatar_updated_at timestamptz
)
language plpgsql
security definer
volatile
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'auth_required' using errcode = '28000';
  end if;

  return query
  update public.profiles as p
     set avatar_path = null,
         avatar_updated_at = now()
   where p.id = v_user_id
   returning
     p.display_name,
     p.avatar_path,
     p.avatar_updated_at;
end;
$$;

revoke all on function public.clear_my_avatar_path() from public;
grant execute on function public.clear_my_avatar_path() to authenticated;

commit;

-- Post-apply gate:
-- Run docs/supabase/sql/056_profile_avatars_post_apply_select_only.sql once,
-- then connect mypage avatar UI and session-detail comment rendering in a separate frontend gate.
