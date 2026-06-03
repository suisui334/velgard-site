-- 023_gm_template_storage_rpc_draft.sql
-- M-15I-3 GM template preset storage SQL draft.
--
-- DRAFT ONLY:
-- - Do not run this file in SQL Editor.
-- - A later reviewed apply file must be created before any apply step.
-- - This draft is for review of schema, RLS, RPC, grants, and rollback shape.
-- - Do not write credential values, connection values, contact values, or
--   internal row values into this file or related notes.
--
-- Preflight reviewed:
-- - public.gm_template_presets does not exist yet and the name is available.
-- - Similar template / preset / message table names were not found.
-- - public.profiles.id is uuid, not null, and references auth.users(id).
-- - auth.uid() returns uuid, so it is compatible with public.profiles.id.
-- - public.set_updated_at() exists and can be reused for updated_at.
-- - public.has_role(text), public.is_admin(), public.is_session_gm(text), and
--   public.user_roles exist.
-- - Existing comparable RPCs use security definer with explicit search_path.
-- - Comparable RPCs grant EXECUTE to authenticated.
-- - Planned RPC names do not currently collide.

-- ============================================================
-- SECTION 1: REVIEW NOTES
-- ============================================================

-- Product direction:
-- - Store personal template presets for the logged-in user.
-- - M-15H continues to perform variable replacement on the frontend.
-- - Initial storage is not a shared/admin-common template system.
-- - Template type values are fixed DB values; Japanese labels stay in UI/docs.
-- - Deletion means is_active = false. Physical deletion is not part of the
--   initial feature.
--
-- Stop and revise before apply if:
-- - public.gm_template_presets already exists with a different contract.
-- - public.profiles.id no longer matches auth.uid() type expectations.
-- - public.set_updated_at() behavior is not suitable for this table.
-- - The team decides shared templates, admin-common templates, sort ordering,
--   description, or scope must be included in the first release.
-- - Direct frontend table writes become a requirement.
-- - Draft review finds that same-name template presets must be unique.

-- ============================================================
-- SECTION 2: SCHEMA DRAFT
-- DO NOT RUN UNTIL A REVIEWED APPLY STEP IS REQUESTED.
-- ============================================================

begin;

create table public.gm_template_presets (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.profiles(id) on delete cascade,
  template_name text not null,
  template_type text not null,
  template_body text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint gm_template_presets_template_name_not_blank check (
    length(trim(template_name)) > 0
  ),
  constraint gm_template_presets_template_name_length_check check (
    char_length(trim(template_name)) between 1 and 80
  ),
  constraint gm_template_presets_template_name_single_line_check check (
    position(chr(10) in template_name) = 0
    and position(chr(13) in template_name) = 0
  ),
  constraint gm_template_presets_template_type_check check (
    template_type in (
      'call',
      'result',
      'session_post',
      'application',
      'other'
    )
  ),
  constraint gm_template_presets_template_body_not_blank check (
    length(trim(template_body)) > 0
  ),
  constraint gm_template_presets_template_body_length_check check (
    char_length(template_body) between 1 and 5000
  )
);

create index gm_template_presets_owner_active_updated_idx
on public.gm_template_presets(
  owner_user_id,
  is_active,
  updated_at desc,
  created_at desc
);

create index gm_template_presets_owner_type_active_updated_idx
on public.gm_template_presets(
  owner_user_id,
  template_type,
  is_active,
  updated_at desc,
  created_at desc
);

create trigger gm_template_presets_set_updated_at
before update on public.gm_template_presets
for each row execute function public.set_updated_at();

alter table public.gm_template_presets enable row level security;

create policy "gm_template_presets_select_own"
on public.gm_template_presets
for select
to authenticated
using (auth.uid() is not null and owner_user_id = auth.uid());

create policy "gm_template_presets_insert_own"
on public.gm_template_presets
for insert
to authenticated
with check (auth.uid() is not null and owner_user_id = auth.uid());

create policy "gm_template_presets_update_own"
on public.gm_template_presets
for update
to authenticated
using (auth.uid() is not null and owner_user_id = auth.uid())
with check (auth.uid() is not null and owner_user_id = auth.uid());

revoke all on table public.gm_template_presets from public;
revoke all on table public.gm_template_presets from anon;
revoke all on table public.gm_template_presets from authenticated;

-- ============================================================
-- SECTION 3: RPC DRAFT
-- DO NOT RUN UNTIL SCHEMA DRAFT IS REVIEWED.
-- ============================================================

create or replace function public.get_my_template_presets()
returns table (
  template_id uuid,
  template_name text,
  template_type text,
  template_body text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  if not exists (
    select 1
    from public.profiles as p
    where p.id = v_actor
  ) then
    raise exception 'profile_not_found' using errcode = 'P0002';
  end if;

  return query
  select
    gtp.id as template_id,
    gtp.template_name,
    gtp.template_type,
    gtp.template_body,
    gtp.created_at,
    gtp.updated_at
  from public.gm_template_presets as gtp
  where gtp.owner_user_id = v_actor
    and gtp.is_active = true
  order by
    gtp.updated_at desc,
    gtp.created_at desc,
    gtp.template_name asc;
end;
$$;

create or replace function public.create_template_preset(
  p_template_name text,
  p_template_type text,
  p_template_body text
)
returns table (
  template_id uuid,
  template_name text,
  template_type text,
  template_body text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_template_name text;
  v_template_type text;
  v_template_body text;
  v_template_id uuid;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  if not exists (
    select 1
    from public.profiles as p
    where p.id = v_actor
  ) then
    raise exception 'profile_not_found' using errcode = 'P0002';
  end if;

  v_template_name := nullif(trim(coalesce(p_template_name, '')), '');
  if v_template_name is null then
    raise exception 'template_name_required' using errcode = '22023';
  end if;
  if char_length(v_template_name) > 80 then
    raise exception 'template_name_too_long' using errcode = '22023';
  end if;
  if position(chr(10) in v_template_name) > 0
    or position(chr(13) in v_template_name) > 0 then
    raise exception 'template_name_invalid' using errcode = '22023';
  end if;

  v_template_type := lower(nullif(trim(coalesce(p_template_type, '')), ''));
  if v_template_type is null
    or v_template_type not in (
    'call',
    'result',
    'session_post',
    'application',
    'other'
  ) then
    raise exception 'template_type_invalid' using errcode = '22023';
  end if;

  v_template_body := coalesce(p_template_body, '');
  if length(trim(v_template_body)) = 0 then
    raise exception 'template_body_required' using errcode = '22023';
  end if;
  if char_length(v_template_body) > 5000 then
    raise exception 'template_body_too_long' using errcode = '22023';
  end if;

  insert into public.gm_template_presets (
    owner_user_id,
    template_name,
    template_type,
    template_body,
    is_active
  )
  values (
    v_actor,
    v_template_name,
    v_template_type,
    v_template_body,
    true
  )
  returning id into v_template_id;

  return query
  select
    gtp.id as template_id,
    gtp.template_name,
    gtp.template_type,
    gtp.template_body,
    gtp.is_active,
    gtp.created_at,
    gtp.updated_at
  from public.gm_template_presets as gtp
  where gtp.id = v_template_id
    and gtp.owner_user_id = v_actor;
end;
$$;

create or replace function public.update_template_preset(
  p_template_id uuid,
  p_template_name text,
  p_template_type text,
  p_template_body text,
  p_is_active boolean
)
returns table (
  template_id uuid,
  template_name text,
  template_type text,
  template_body text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_template_name text;
  v_template_type text;
  v_template_body text;
  v_template_id uuid;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  if p_template_id is null then
    raise exception 'template_not_found' using errcode = 'P0002';
  end if;

  if not exists (
    select 1
    from public.profiles as p
    where p.id = v_actor
  ) then
    raise exception 'profile_not_found' using errcode = 'P0002';
  end if;

  v_template_name := nullif(trim(coalesce(p_template_name, '')), '');
  if v_template_name is null then
    raise exception 'template_name_required' using errcode = '22023';
  end if;
  if char_length(v_template_name) > 80 then
    raise exception 'template_name_too_long' using errcode = '22023';
  end if;
  if position(chr(10) in v_template_name) > 0
    or position(chr(13) in v_template_name) > 0 then
    raise exception 'template_name_invalid' using errcode = '22023';
  end if;

  v_template_type := lower(nullif(trim(coalesce(p_template_type, '')), ''));
  if v_template_type is null
    or v_template_type not in (
    'call',
    'result',
    'session_post',
    'application',
    'other'
  ) then
    raise exception 'template_type_invalid' using errcode = '22023';
  end if;

  v_template_body := coalesce(p_template_body, '');
  if length(trim(v_template_body)) = 0 then
    raise exception 'template_body_required' using errcode = '22023';
  end if;
  if char_length(v_template_body) > 5000 then
    raise exception 'template_body_too_long' using errcode = '22023';
  end if;

  if p_is_active is null then
    raise exception 'template_active_required' using errcode = '22023';
  end if;

  update public.gm_template_presets as gtp
  set
    template_name = v_template_name,
    template_type = v_template_type,
    template_body = v_template_body,
    is_active = p_is_active
  where gtp.id = p_template_id
    and gtp.owner_user_id = v_actor
  returning gtp.id into v_template_id;

  if v_template_id is null then
    raise exception 'template_not_found' using errcode = 'P0002';
  end if;

  return query
  select
    gtp.id as template_id,
    gtp.template_name,
    gtp.template_type,
    gtp.template_body,
    gtp.is_active,
    gtp.created_at,
    gtp.updated_at
  from public.gm_template_presets as gtp
  where gtp.id = v_template_id
    and gtp.owner_user_id = v_actor;
end;
$$;

create or replace function public.deactivate_template_preset(
  p_template_id uuid
)
returns table (
  template_id uuid,
  template_name text,
  template_type text,
  is_active boolean,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_template_id uuid;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  if p_template_id is null then
    raise exception 'template_not_found' using errcode = 'P0002';
  end if;

  if not exists (
    select 1
    from public.profiles as p
    where p.id = v_actor
  ) then
    raise exception 'profile_not_found' using errcode = 'P0002';
  end if;

  update public.gm_template_presets as gtp
  set is_active = false
  where gtp.id = p_template_id
    and gtp.owner_user_id = v_actor
  returning gtp.id into v_template_id;

  if v_template_id is null then
    raise exception 'template_not_found' using errcode = 'P0002';
  end if;

  return query
  select
    gtp.id as template_id,
    gtp.template_name,
    gtp.template_type,
    gtp.is_active,
    gtp.updated_at
  from public.gm_template_presets as gtp
  where gtp.id = v_template_id
    and gtp.owner_user_id = v_actor;
end;
$$;

-- ============================================================
-- SECTION 4: PRIVILEGE DRAFT
-- DO NOT RUN UNTIL ALL ROUTINE CONTRACTS ARE FINAL.
-- ============================================================

revoke all on function public.get_my_template_presets() from public;
revoke all on function public.get_my_template_presets() from anon;
revoke all on function public.get_my_template_presets() from authenticated;

revoke all on function public.create_template_preset(text, text, text) from public;
revoke all on function public.create_template_preset(text, text, text) from anon;
revoke all on function public.create_template_preset(text, text, text) from authenticated;

revoke all on function public.update_template_preset(uuid, text, text, text, boolean) from public;
revoke all on function public.update_template_preset(uuid, text, text, text, boolean) from anon;
revoke all on function public.update_template_preset(uuid, text, text, text, boolean) from authenticated;

revoke all on function public.deactivate_template_preset(uuid) from public;
revoke all on function public.deactivate_template_preset(uuid) from anon;
revoke all on function public.deactivate_template_preset(uuid) from authenticated;

grant execute on function public.get_my_template_presets() to authenticated;
grant execute on function public.create_template_preset(text, text, text) to authenticated;
grant execute on function public.update_template_preset(uuid, text, text, text, boolean) to authenticated;
grant execute on function public.deactivate_template_preset(uuid) to authenticated;

notify pgrst, 'reload schema';

commit;

-- ============================================================
-- SECTION 5: POST-APPLY CHECK DRAFT
-- RUN ONLY AFTER A REVIEWED APPLY STEP IN A LATER TASK.
-- ============================================================

select
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'gm_template_presets'
order by ordinal_position;

select
  con.conname,
  con.contype,
  pg_catalog.pg_get_constraintdef(con.oid) as definition
from pg_catalog.pg_constraint con
where con.conrelid = to_regclass('public.gm_template_presets')
order by con.contype, con.conname;

select
  p.oid::regprocedure as signature,
  pg_catalog.pg_get_function_arguments(p.oid) as arguments,
  pg_catalog.pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer,
  p.proconfig as function_config
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'get_my_template_presets',
    'create_template_preset',
    'update_template_preset',
    'deactivate_template_preset'
  )
order by p.proname, p.oid::regprocedure::text;

select
  routine_name,
  specific_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name in (
    'get_my_template_presets',
    'create_template_preset',
    'update_template_preset',
    'deactivate_template_preset'
  )
order by routine_name, specific_name, grantee, privilege_type;

select
  schemaname,
  tablename,
  policyname,
  roles,
  cmd
from pg_catalog.pg_policies
where schemaname = 'public'
  and tablename = 'gm_template_presets'
order by policyname;

-- Expected later:
-- - public.gm_template_presets exists with the reviewed column contract.
-- - template_type is limited to call / result / session_post / application / other.
-- - Template names are non-empty, single-line, and at most 80 characters.
-- - Template bodies are non-empty and at most 5000 characters.
-- - RPCs are security definer and have explicit search_path.
-- - authenticated has EXECUTE on the four RPCs.
-- - anon and public do not have EXECUTE on the four RPCs.
-- - RPC return columns do not include owner_user_id.
-- - Direct frontend table writes are not part of the feature contract.

-- Rollback draft, not for this step:
--
-- begin;
-- revoke all on function public.get_my_template_presets() from public;
-- revoke all on function public.get_my_template_presets() from anon;
-- revoke all on function public.get_my_template_presets() from authenticated;
-- revoke all on function public.create_template_preset(text, text, text) from public;
-- revoke all on function public.create_template_preset(text, text, text) from anon;
-- revoke all on function public.create_template_preset(text, text, text) from authenticated;
-- revoke all on function public.update_template_preset(uuid, text, text, text, boolean) from public;
-- revoke all on function public.update_template_preset(uuid, text, text, text, boolean) from anon;
-- revoke all on function public.update_template_preset(uuid, text, text, text, boolean) from authenticated;
-- revoke all on function public.deactivate_template_preset(uuid) from public;
-- revoke all on function public.deactivate_template_preset(uuid) from anon;
-- revoke all on function public.deactivate_template_preset(uuid) from authenticated;
-- drop function if exists public.deactivate_template_preset(uuid);
-- drop function if exists public.update_template_preset(uuid, text, text, text, boolean);
-- drop function if exists public.create_template_preset(text, text, text);
-- drop function if exists public.get_my_template_presets();
-- drop table if exists public.gm_template_presets;
-- notify pgrst, 'reload schema';
-- commit;
