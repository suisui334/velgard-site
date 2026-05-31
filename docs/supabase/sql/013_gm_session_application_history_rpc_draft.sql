-- ============================================================
-- Velgard Supabase M-11E-2
-- 013_gm_session_application_history_rpc_draft.sql
--
-- DRAFT ONLY:
--   Do not run this SQL until the M-11E-1 design is reviewed.
--   Do not paste Project URL, API keys, service role keys, DB passwords,
--   direct connection strings, JWT secrets, tokens, real emails, real user IDs,
--   real application IDs, real comment IDs, or Discord IDs here.
--   This draft creates/replaces one read-only GM-facing RPC definition.
-- ============================================================

-- Purpose:
--   Let the target session GM or an admin read a compact person-based
--   application status history for one session without returning user_id,
--   email, application_id, comment_id, Discord IDs, roles, tokens, or secrets.

-- Adopted RPC name:
--   get_gm_session_application_history(target_session_id text)

-- Return columns:
--   display_name text
--   application_status text
--   created_at timestamptz
--   updated_at timestamptz
--   canceled_at timestamptz
--   comment_count integer
--   last_comment_at timestamptz

-- Comment counting policy:
--   session_applications is the primary history row.
--   comment_count counts active application comments only:
--     session_comments.is_application = true and deleted_at is null
--   Deleted comments do not break the RPC. If every related comment is deleted,
--   the application row can still be returned with comment_count = 0 and
--   last_comment_at = null.

-- ============================================================
-- 0. Preflight checks
-- ============================================================

-- 0-1. Confirm helper functions exist, are security definer, and pin search_path.
select
  p.oid::regprocedure as function_name,
  p.prosecdef as is_security_definer,
  p.provolatile as volatility,
  p.proconfig as function_config,
  pg_catalog.pg_get_function_arguments(p.oid) as arguments,
  pg_catalog.pg_get_function_result(p.oid) as result_type
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('is_admin', 'is_session_gm')
order by p.proname, p.oid::regprocedure::text;

-- 0-2. Confirm application status check constraint.
-- Expected allowed values:
--   pending, accepted, rejected, waitlisted, canceled
select
  'session_applications_status_check' as check_name,
  conname,
  pg_catalog.pg_get_constraintdef(oid) as definition
from pg_catalog.pg_constraint
where conrelid = 'public.session_applications'::regclass
  and conname = 'session_applications_status_check';

-- 0-3. Confirm required application columns exist.
select
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'session_applications'
  and column_name in (
    'id',
    'session_id',
    'user_id',
    'comment_id',
    'status',
    'created_at',
    'updated_at',
    'canceled_at'
  )
order by ordinal_position;

-- 0-4. Confirm required comment columns exist.
select
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'session_comments'
  and column_name in (
    'id',
    'session_id',
    'user_id',
    'is_application',
    'created_at',
    'updated_at',
    'edited_at',
    'deleted_at'
  )
order by ordinal_position;

-- 0-5. Confirm public_profiles exposes only public display columns.
select
  table_name,
  column_name,
  data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'public_profiles'
order by ordinal_position;

-- 0-6. Review existing function name collision.
select
  p.oid::regprocedure as function_name,
  p.prosecdef as is_security_definer,
  p.provolatile as volatility,
  p.proconfig as function_config,
  pg_catalog.pg_get_function_arguments(p.oid) as arguments,
  pg_catalog.pg_get_function_result(p.oid) as result_type
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'get_gm_session_application_history'
order by p.oid::regprocedure::text;

-- 0-7. Review application RLS policies.
select
  schemaname,
  tablename,
  policyname,
  roles,
  cmd,
  qual,
  with_check
from pg_catalog.pg_policies
where schemaname = 'public'
  and tablename = 'session_applications'
order by policyname;

-- 0-8. Review direct mutation grants. This read RPC does not require broad
-- direct UPDATE/DELETE grants on session_applications or session_comments.
select
  table_name,
  grantee,
  privilege_type
from information_schema.table_privileges
where table_schema = 'public'
  and table_name in ('session_applications', 'session_comments')
  and grantee in ('anon', 'authenticated')
  and privilege_type in ('UPDATE', 'DELETE')
order by table_name, grantee, privilege_type;

-- Stop before creating/replacing the RPC if:
--   - is_admin() or is_session_gm(text) is missing, unexpected, or does not
--     pin search_path,
--   - public_profiles exposes more than id / display_name,
--   - required columns are missing,
--   - status check does not include canceled,
--   - get_gm_session_application_history(text) already exists with a different
--     reviewed contract,
--   - the team needs true state transition audit history rather than the current
--     session_applications row plus comment metadata,
--   - review requires real IDs, emails, keys, tokens, or secrets in docs.

-- ============================================================
-- 1. get_gm_session_application_history
-- ============================================================

-- Run this apply section only after the preflight checks pass.
-- SQL Editor usually runs with owner/editor privileges; do not use SQL Editor
-- results to infer anon/authenticated/GM behavior. Verify auth-context behavior
-- through reviewed clients or the smoke test.

begin;

create or replace function public.get_gm_session_application_history(
  target_session_id text
)
returns table (
  display_name text,
  application_status text,
  created_at timestamptz,
  updated_at timestamptz,
  canceled_at timestamptz,
  comment_count integer,
  last_comment_at timestamptz
)
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_target_session_id text;
begin
  if v_actor_id is null then
    raise exception 'not authenticated';
  end if;

  v_target_session_id := nullif(trim(coalesce(target_session_id, '')), '');

  if v_target_session_id is null then
    raise exception 'session id is required';
  end if;

  if not (
    public.is_admin()
    or public.is_session_gm(v_target_session_id)
  ) then
    raise exception 'not allowed';
  end if;

  return query
  with comment_stats as (
    select
      c.session_id,
      c.user_id,
      count(*)::integer as comment_count,
      max(coalesce(c.edited_at, c.updated_at, c.created_at)) as last_comment_at
    from public.session_comments as c
    where c.session_id = v_target_session_id
      and c.is_application = true
      and c.deleted_at is null
    group by c.session_id, c.user_id
  )
  select
    coalesce(nullif(trim(pp.display_name), ''), '名前未設定')::text as display_name,
    sa.status as application_status,
    sa.created_at,
    sa.updated_at,
    sa.canceled_at,
    coalesce(cs.comment_count, 0)::integer as comment_count,
    cs.last_comment_at
  from public.session_applications as sa
  left join public.public_profiles as pp
    on pp.id = sa.user_id
  left join comment_stats as cs
    on cs.session_id = sa.session_id
   and cs.user_id = sa.user_id
  where sa.session_id = v_target_session_id
  order by
    case sa.status
      when 'pending' then 10
      when 'waitlisted' then 20
      when 'accepted' then 30
      when 'canceled' then 40
      when 'rejected' then 50
      else 90
    end,
    coalesce(sa.updated_at, sa.created_at) desc,
    pp.display_name asc nulls last;
end;
$$;

revoke all on function public.get_gm_session_application_history(text) from public;
revoke all on function public.get_gm_session_application_history(text) from anon;
revoke all on function public.get_gm_session_application_history(text) from authenticated;
grant execute on function public.get_gm_session_application_history(text) to authenticated;

notify pgrst, 'reload schema';

commit;

-- ============================================================
-- 2. Post-apply verification checks
-- ============================================================

-- Verify function contract and security mode.
select
  p.oid::regprocedure as function_name,
  p.prosecdef as is_security_definer,
  p.provolatile as volatility,
  p.proconfig as function_config,
  pg_catalog.pg_get_function_arguments(p.oid) as arguments,
  pg_catalog.pg_get_function_result(p.oid) as result_type
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'get_gm_session_application_history'
order by p.oid::regprocedure::text;

-- Verify execute grants.
-- Expected client grantee:
--   authenticated
-- Expected absent:
--   anon, PUBLIC/public
-- Owner or administrative roles may also appear and are not a client-side broad grant.
select
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name = 'get_gm_session_application_history'
order by grantee, privilege_type;

-- Verify declared return columns without executing the RPC in SQL Editor.
-- Auth-context behavior must be checked later through reviewed clients or the
-- smoke test, not from the SQL Editor owner/editor context.
select
  p.parameter_name,
  p.data_type,
  p.ordinal_position
from information_schema.parameters p
where p.specific_schema = 'public'
  and p.parameter_mode = 'OUT'
  and p.specific_name in (
    select r.specific_name
    from information_schema.routines r
    where r.specific_schema = 'public'
      and r.routine_name = 'get_gm_session_application_history'
  )
order by p.ordinal_position;

-- Verify function body for review. Do not paste secrets or real internal IDs into docs.
select pg_catalog.pg_get_functiondef(
  'public.get_gm_session_application_history(text)'::regprocedure
);

-- Manual / smoke-test behavior checks to run only with reviewed auth-context clients:
--   - anon cannot execute this RPC.
--   - GM can read the history for their own session.
--   - admin can read the history.
--   - GM cannot read another GM's session history.
--   - player cannot read GM history.
--   - returned rows do not include user_id, email, application_id, comment_id,
--     Discord IDs, roles, tokens, keys, or secrets.
--   - pending / waitlisted / accepted / canceled / rejected rows can appear.
--   - deleted comments do not break the RPC.
--   - an application row with no active comments can still appear with
--     comment_count = 0 and last_comment_at = null.

-- ============================================================
-- 3. Rollback draft
-- ============================================================

-- If this was a new RPC and must be removed:
--
-- begin;
--
-- revoke all on function public.get_gm_session_application_history(text) from public;
-- revoke all on function public.get_gm_session_application_history(text) from anon;
-- revoke all on function public.get_gm_session_application_history(text) from authenticated;
-- drop function if exists public.get_gm_session_application_history(text);
--
-- notify pgrst, 'reload schema';
--
-- commit;

-- If a previous version existed, do not use the removal rollback. Restore the
-- reviewed previous definition in a separate rollback SQL with its own grants
-- and post-rollback verification.

-- ============================================================
-- 4. Out of scope for this draft
-- ============================================================

-- - Running this SQL in Supabase SQL Editor.
-- - Changing DB data.
-- - Calling get_gm_session_application_history from Codex.
-- - Production session-detail.html implementation.
-- - GM approve / reject UI implementation.
-- - Discord ID copy implementation.
-- - close_session.
-- - updates.json changes.
-- - Secrets, real Project URL/key values, emails, tokens, or real internal IDs.
