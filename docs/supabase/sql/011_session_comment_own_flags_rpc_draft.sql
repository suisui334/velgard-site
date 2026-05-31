-- ============================================================
-- Velgard Supabase M-11C-1
-- 011_session_comment_own_flags_rpc_draft.sql
--
-- DRAFT ONLY:
--   Do not run this SQL until it has been reviewed.
--   Do not paste Project URL, API keys, service role keys, DB passwords,
--   direct connection strings, JWT secrets, tokens, real emails, or user IDs here.
--   This draft does not change data by itself, but it replaces an RPC definition.
-- ============================================================

-- Purpose:
--   Extend public.get_public_session_comments(target_session_id text) with
--   owner/self-operation flags for the PL-facing M-11C edit/delete UI.
--
-- Added return columns:
--   is_own     boolean: true only when auth.uid() matches session_comments.user_id.
--   can_edit   boolean: M-11C PL-facing flag. Same as is_own in this draft.
--   can_delete boolean: M-11C PL-facing flag. Same as is_own in this draft.
--
-- Security policy:
--   - anon receives false for all three flags because auth.uid() is null.
--   - authenticated owners receive true for their own visible, non-deleted comments.
--   - other authenticated users receive false.
--   - GM/admin operation flags are intentionally not included in this public RPC.
--     Add a separate GM/admin-facing RPC in a later M-11D/F step if needed.
--   - user_id, email, Discord IDs, role, edited_by, deleted_by, and application_id
--     are not returned.
--   - comment_id is kept because it already exists and is needed internally for
--     future edit/delete RPC calls. Do not display it in UI text or logs.

-- ============================================================
-- 0. Preflight checks
-- ============================================================

-- Confirm the current function signature, security mode, and return type.
select
  p.oid::regprocedure as function_name,
  p.prosecdef as is_security_definer,
  p.provolatile as volatility,
  pg_catalog.pg_get_function_arguments(p.oid) as arguments,
  pg_catalog.pg_get_function_result(p.oid) as result_type
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'get_public_session_comments'
order by p.oid::regprocedure::text;

-- Confirm existing execute grants. Expected before/after:
--   anon, authenticated
select
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name = 'get_public_session_comments'
order by grantee, privilege_type;

-- Review current function body before replacement.
select pg_catalog.pg_get_functiondef('public.get_public_session_comments(text)'::regprocedure);

-- Confirm the existing callable column shape without returning data.
-- Expected pre-replacement shape: the original 8 columns only.
select
  comment_id,
  session_id,
  display_name,
  body,
  application_status,
  created_at,
  updated_at,
  edited_at
from public.get_public_session_comments('__REPLACE_WITH_PUBLIC_SESSION_ID__')
limit 0;

-- Stop before running the replacement if:
--   - the function has unexpected overloads or arguments,
--   - the existing return columns differ from the M-11 docs,
--   - current grants are wider than anon/authenticated execute,
--   - user_id/email/Discord IDs are present in the return type,
--   - dependent database objects require DROP ... CASCADE.

-- ============================================================
-- 1. Replace public.get_public_session_comments(text)
-- ============================================================

-- PostgreSQL cannot change a function's table return type with CREATE OR REPLACE
-- alone. Use a transaction and do not use CASCADE; if DROP fails, stop and review.
-- Run this replacement section as one block. Do not continue after a transaction
-- error; rollback and review instead.
begin;

-- The function is expected to exist. If this fails because it is missing, stop
-- and confirm the target project/schema instead of silently creating a new RPC.
drop function public.get_public_session_comments(text);

create function public.get_public_session_comments(
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
    c.body,
    sa.status as application_status,
    c.created_at,
    c.updated_at,
    c.edited_at,
    (
      auth.uid() is not null
      and c.user_id = auth.uid()
    ) as is_own,
    (
      auth.uid() is not null
      and c.user_id = auth.uid()
    ) as can_edit,
    (
      auth.uid() is not null
      and c.user_id = auth.uid()
    ) as can_delete
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

-- Ask PostgREST/Supabase API to refresh function metadata after return type change.
notify pgrst, 'reload schema';

commit;

-- ============================================================
-- 2. Post-apply verification checks
-- ============================================================

-- Verify the new return type includes the three flags and still omits user_id/email.
select
  p.oid::regprocedure as function_name,
  p.prosecdef as is_security_definer,
  pg_catalog.pg_get_function_arguments(p.oid) as arguments,
  pg_catalog.pg_get_function_result(p.oid) as result_type
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'get_public_session_comments';

-- This checks column shape without requiring a real session id.
select
  comment_id,
  session_id,
  display_name,
  body,
  application_status,
  created_at,
  updated_at,
  edited_at,
  is_own,
  can_edit,
  can_delete
from public.get_public_session_comments('__REPLACE_WITH_PUBLIC_SESSION_ID__')
limit 0;

-- Verify execute grants were restored and not widened.
-- Expected grantees: anon and authenticated only.
select
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name = 'get_public_session_comments'
order by grantee, privilege_type;

-- Manual behavior checks to run only with reviewed disposable/auth-context fixtures:
--   SQL Editor usually runs with owner/editor privileges. Do not use SQL Editor
--   results to infer anon/authenticated behavior. Verify these cases through
--   the site, a reviewed smoke test, or Supabase client/REST calls that use
--   anon/publishable credentials plus real signed-in test users. Do not use
--   service_role or other privileged credentials for these auth-context checks.
--   anon:
--     is_own = false, can_edit = false, can_delete = false for all returned rows.
--   authenticated owner:
--     own visible comments return true/true/true.
--   authenticated non-owner:
--     other users' comments return false/false/false.
--   deleted comments:
--     no deleted comment row is returned.
--   sensitive fields:
--     user_id, email, Discord IDs, role, edited_by, deleted_by, application_id
--     are absent from the result shape.

-- ============================================================
-- 3. Rollback draft
-- ============================================================

-- If the new return type must be reverted, restore the M-11B/M-11C pre-flag
-- definition below. Do not use CASCADE.
--
-- begin;
--
-- drop function public.get_public_session_comments(text);
--
-- create function public.get_public_session_comments(
--   target_session_id text
-- )
-- returns table (
--   comment_id uuid,
--   session_id text,
--   display_name text,
--   body text,
--   application_status text,
--   created_at timestamptz,
--   updated_at timestamptz,
--   edited_at timestamptz
-- )
-- language sql
-- security definer
-- stable
-- set search_path = ''
-- as $$
--   select
--     c.id as comment_id,
--     c.session_id,
--     p.display_name,
--     c.body,
--     sa.status as application_status,
--     c.created_at,
--     c.updated_at,
--     c.edited_at
--   from public.session_comments c
--   join public.sessions s
--     on s.id = c.session_id
--   join public.profiles p
--     on p.id = c.user_id
--   left join public.session_applications sa
--     on sa.session_id = c.session_id
--    and sa.user_id = c.user_id
--   where c.session_id = target_session_id
--     and c.deleted_at is null
--     and s.visibility = 'public'
--     and s.status not in ('draft', 'canceled');
-- $$;
--
-- revoke all on function public.get_public_session_comments(text) from public;
-- grant execute on function public.get_public_session_comments(text) to anon, authenticated;
-- notify pgrst, 'reload schema';
--
-- commit;
