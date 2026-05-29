-- ============================================================
-- Velgard Supabase Free Prototype
-- 002_rls_grants_draft.sql
--
-- DRAFT ONLY:
-- - RLS / GRANT 方針SQL草案。
-- - 001_core_schema_draft.sql 実行後に段階実行する想定。
-- - 実プロジェクトURL、API key、secretは書かない。
-- ============================================================

-- Step 6: helper functions
create or replace function public.has_role(role_name text)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select
    role_name in ('player', 'gm', 'admin')
    and auth.uid() is not null
    and exists (
      select 1
      from public.user_roles ur
      where ur.user_id = auth.uid()
        and ur.role = role_name
    );
$$;

create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select public.has_role('admin');
$$;

create or replace function public.is_session_gm(target_session_id text)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select
    auth.uid() is not null
    and (
      exists (
        select 1
        from public.sessions s
        where s.id = target_session_id
          and s.gm_user_id = auth.uid()
      )
      or public.is_admin()
    );
$$;

create or replace function public.can_apply_to_session(target_session_id text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
    from public.sessions s
    where s.id = target_session_id
      and s.visibility = 'public'
      and s.status in ('tentative', 'recruiting')
  );
$$;

-- Functions are not protected by RLS; keep execution grants explicit.
revoke all on function public.has_role(text) from public;
revoke all on function public.is_admin() from public;
revoke all on function public.is_session_gm(text) from public;
revoke all on function public.can_apply_to_session(text) from public;

grant execute on function public.has_role(text) to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_session_gm(text) to authenticated;
grant execute on function public.can_apply_to_session(text) to authenticated;

-- Step 8: count view / public count RPC
create view public.session_application_counts
with (security_invoker = true)
as
select
  session_id,
  count(distinct user_id) filter (where status = 'accepted') as accepted_count,
  count(distinct user_id) filter (where status = 'pending') as pending_count,
  count(distinct user_id) filter (where status = 'waitlisted') as waitlisted_count
from public.session_applications
where status <> 'canceled'
group by session_id;

create or replace function public.get_public_session_application_counts(
  target_session_id text default null
)
returns table (
  session_id text,
  accepted_count bigint,
  pending_count bigint,
  waitlisted_count bigint
)
language sql
security definer
stable
set search_path = ''
as $$
  select
    s.id as session_id,
    count(distinct sa.user_id) filter (where sa.status = 'accepted') as accepted_count,
    count(distinct sa.user_id) filter (where sa.status = 'pending') as pending_count,
    count(distinct sa.user_id) filter (where sa.status = 'waitlisted') as waitlisted_count
  from public.sessions s
  left join public.session_applications sa
    on sa.session_id = s.id
   and sa.status <> 'canceled'
  where s.visibility = 'public'
    and (target_session_id is null or s.id = target_session_id)
  group by s.id;
$$;

revoke all on function public.get_public_session_application_counts(text) from public;
grant execute on function public.get_public_session_application_counts(text) to anon, authenticated;

-- Public comment display RPC.
-- Do not expose session_comments.user_id or profiles.discord_user_id.
-- If public comments need anon access, use this kind of narrow RPC/view instead of direct table select.
create or replace function public.get_public_session_comments(
  target_session_id text
)
returns table (
  comment_id uuid,
  session_id text,
  display_name text,
  body text,
  application_status text,
  created_at timestamptz,
  updated_at timestamptz,
  edited_at timestamptz
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
    c.body,
    sa.status as application_status,
    c.created_at,
    c.updated_at,
    c.edited_at
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
    and s.status not in ('draft', 'canceled');
$$;

revoke all on function public.get_public_session_comments(text) from public;
grant execute on function public.get_public_session_comments(text) to anon, authenticated;

-- Step 9: RLS enable
alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.sessions enable row level security;
alter table public.session_comments enable row level security;
alter table public.session_applications enable row level security;

-- Step 10: RLS policies

-- profiles: 本体のanon全公開は禁止。公開用はpublic_profiles viewのみ。
create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using (auth.uid() is not null and id = auth.uid());

create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (auth.uid() is not null and id = auth.uid())
with check (auth.uid() is not null and id = auth.uid());

create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check (auth.uid() is not null and id = auth.uid());

create policy "profiles_admin_all"
on public.profiles
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- user_roles: 一般ユーザーはroleを書き換え不可。
create policy "user_roles_select_own"
on public.user_roles
for select
to authenticated
using (auth.uid() is not null and user_id = auth.uid());

create policy "user_roles_admin_all"
on public.user_roles
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- sessions
create policy "sessions_select_public"
on public.sessions
for select
to anon, authenticated
using (visibility = 'public');

create policy "sessions_select_own_gm"
on public.sessions
for select
to authenticated
using (auth.uid() is not null and gm_user_id = auth.uid());

create policy "sessions_select_admin"
on public.sessions
for select
to authenticated
using (public.is_admin());

create policy "sessions_insert_own_gm"
on public.sessions
for insert
to authenticated
with check (
  auth.uid() is not null
  and gm_user_id = auth.uid()
  and public.has_role('gm')
);

create policy "sessions_insert_admin"
on public.sessions
for insert
to authenticated
with check (public.is_admin());

-- 最小PTではGM/admin編集を許す。本実装では状態遷移をRPCへ寄せる。
create policy "sessions_update_own_gm"
on public.sessions
for update
to authenticated
using (
  auth.uid() is not null
  and gm_user_id = auth.uid()
  and public.has_role('gm')
)
with check (
  auth.uid() is not null
  and gm_user_id = auth.uid()
  and public.has_role('gm')
);

create policy "sessions_update_admin"
on public.sessions
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- session_comments
-- 参加希望コメントは公開申請欄に近い扱いとする。
-- ただしsession_commentsを直接広くselectさせるとuser_id等が返り得るため、
-- public sessionの他PL/anon向け表示は get_public_session_comments() のような
-- 最小列RPC/viewを使う。
-- private / hidden sessionのコメント、deleted_at付きコメントは公開しない。
-- 将来非公開相談やGM宛メモが必要なら visibility = 'public' / 'gm_only'
-- または session_private_notes などを別設計にする。
create policy "comments_select_own"
on public.session_comments
for select
to authenticated
using (
  auth.uid() is not null
  and user_id = auth.uid()
  and deleted_at is null
);

create policy "comments_select_session_gm"
on public.session_comments
for select
to authenticated
using (
  deleted_at is null
  and public.is_session_gm(session_id)
);

-- session_applications
-- 個票は本人/対象GM/adminのみ。insert/updateはRPC推奨。
create policy "applications_select_own"
on public.session_applications
for select
to authenticated
using (auth.uid() is not null and user_id = auth.uid());

create policy "applications_select_session_gm"
on public.session_applications
for select
to authenticated
using (public.is_session_gm(session_id));

-- Step 11: grants for views
grant select on public.public_profiles to anon, authenticated;
grant select on public.session_application_counts to authenticated;
