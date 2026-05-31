-- ============================================================
-- Velgard Supabase M-11D-2
-- 012_session_application_cancel_my_rpc_draft.sql
--
-- DRAFT ONLY:
--   This SQL draft has not been run in Supabase SQL Editor.
--   Do not run against production without review.
--   Do not paste Project URL, API keys, service role keys, DB passwords,
--   direct connection strings, JWT secrets, tokens, real emails, or user IDs here.
--   This draft creates/replaces one RPC definition and does not intentionally
--   change application data until the RPC is called by an authenticated user.
-- ============================================================

-- Purpose:
--   Let a signed-in PL withdraw their own session application while keeping
--   existing application comments visible as history/context.
--
-- Short-term status choice:
--   Use existing session_applications.status = 'canceled'.
--   Do not add a new 'withdrawn' status in this draft.
--
-- Adopted RPC name:
--   cancel_my_session_application(target_session_id text)
--
-- Behavior:
--   - authenticated only
--   - target row must be the caller's own session_applications row
--   - pending / waitlisted / accepted can become canceled
--   - rejected is not withdrawable here
--   - already canceled returns safely without changing comments
--   - comments are not deleted or edited
--   - return only session_id, application_status, canceled_at, updated_at

-- ============================================================
-- 0. Preflight checks
-- ============================================================

-- 0-1. Confirm application status check constraint.
-- Expected allowed values:
--   pending, accepted, rejected, waitlisted, canceled
-- Expected absent value:
--   withdrawn
select
  'session_applications_status_check' as check_name,
  conname,
  pg_catalog.pg_get_constraintdef(oid) as definition
from pg_catalog.pg_constraint
where conrelid = 'public.session_applications'::regclass
  and conname = 'session_applications_status_check';

-- 0-2. Confirm required columns exist.
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

-- 0-3. Confirm no withdrawn status is currently present in application rows.
-- This should return 0 rows. If it returns rows, stop and review the actual DB state.
select
  status,
  count(*) as row_count
from public.session_applications
where status not in ('pending', 'accepted', 'rejected', 'waitlisted', 'canceled')
group by status
order by status;

-- 0-4. Review related functions and possible name collisions.
-- If cancel_my_session_application(text) already exists, compare its definition
-- and return type before running the replacement section.
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
  and p.proname in (
    'cancel_my_session_application',
    'cancel_application',
    'delete_application_comment_and_maybe_cancel',
    'set_application_status'
  )
order by p.proname, p.oid::regprocedure::text;

-- 0-5. Review application RLS policies.
-- The RPC below is security definer because direct UPDATE policies for
-- session_applications are intentionally not the feature surface.
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

-- 0-6. Review direct mutation grants on application rows.
-- Expected: anon/authenticated should not have broad direct UPDATE/DELETE grants.
select
  table_name,
  grantee,
  privilege_type
from information_schema.table_privileges
where table_schema = 'public'
  and table_name = 'session_applications'
  and grantee in ('anon', 'authenticated')
  and privilege_type in ('UPDATE', 'DELETE')
order by grantee, privilege_type;

-- 0-7. Confirm public count RPC still excludes canceled rows by counting only
-- accepted / pending / waitlisted in its definition.
select
  'get_public_session_application_counts_status_filters' as check_name,
  case
    when pg_catalog.pg_get_functiondef('public.get_public_session_application_counts(text)'::regprocedure)
      like '%status = ''accepted''%'
     and pg_catalog.pg_get_functiondef('public.get_public_session_application_counts(text)'::regprocedure)
      like '%status = ''pending''%'
     and pg_catalog.pg_get_functiondef('public.get_public_session_application_counts(text)'::regprocedure)
      like '%status = ''waitlisted''%'
    then 'ok'
    else 'review'
  end as result;

-- Stop before creating/replacing the RPC if:
--   - session_applications_status_check does not include canceled,
--   - session_applications_status_check already includes withdrawn,
--   - required columns are missing,
--   - cancel_my_session_application(text) exists with an unexpected contract,
--   - direct anon/authenticated UPDATE/DELETE grants are unexpectedly broad,
--   - any review requires real IDs, emails, keys, tokens, or secrets in docs.

-- ============================================================
-- 1. cancel_my_session_application
-- ============================================================

-- Run this apply section after the preflight checks pass.
-- The transaction keeps create/revoke/grant together, avoiding a temporary
-- broad EXECUTE grant if a later statement fails.
begin;

create or replace function public.cancel_my_session_application(
  target_session_id text
)
returns table (
  session_id text,
  application_status text,
  canceled_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_target_session_id text;
  v_session_exists boolean := false;
  v_current_status text;
begin
  if v_actor_id is null then
    raise exception 'not authenticated';
  end if;

  v_target_session_id := nullif(trim(coalesce(target_session_id, '')), '');

  if v_target_session_id is null then
    raise exception 'session id is required';
  end if;

  select exists (
    select 1
    from public.sessions as s
    where s.id = v_target_session_id
  )
  into v_session_exists;

  if not v_session_exists then
    raise exception 'session or application not found';
  end if;

  select sa.status
  into v_current_status
  from public.session_applications as sa
  where sa.session_id = v_target_session_id
    and sa.user_id = v_actor_id
  for update;

  if v_current_status is null then
    raise exception 'session or application not found';
  end if;

  if v_current_status = 'canceled' then
    return query
    select
      sa.session_id,
      sa.status as application_status,
      sa.canceled_at,
      sa.updated_at
    from public.session_applications as sa
    where sa.session_id = v_target_session_id
      and sa.user_id = v_actor_id;

    return;
  end if;

  if v_current_status not in ('pending', 'waitlisted', 'accepted') then
    raise exception 'application is not withdrawable';
  end if;

  return query
  update public.session_applications as sa
  set
    status = 'canceled',
    canceled_at = now(),
    updated_at = now()
  where sa.session_id = v_target_session_id
    and sa.user_id = v_actor_id
    and sa.status in ('pending', 'waitlisted', 'accepted')
  returning
    sa.session_id,
    sa.status as application_status,
    sa.canceled_at,
    sa.updated_at;

  if not found then
    raise exception 'application not found or cannot be withdrawn';
  end if;
end;
$$;

revoke all on function public.cancel_my_session_application(text) from public;
revoke all on function public.cancel_my_session_application(text) from anon;
revoke all on function public.cancel_my_session_application(text) from authenticated;
grant execute on function public.cancel_my_session_application(text) to authenticated;

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
  pg_catalog.pg_get_function_arguments(p.oid) as arguments,
  pg_catalog.pg_get_function_result(p.oid) as result_type
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'cancel_my_session_application';

-- Verify execute grants.
-- Expected client grantee:
--   authenticated
-- Expected absent:
--   anon, PUBLIC/public
-- Owner or administrative roles may also appear in information_schema and are
-- not a client-side broad grant.
select
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name = 'cancel_my_session_application'
order by grantee, privilege_type;

-- Verify the function body for review. Do not paste secrets into docs.
select pg_catalog.pg_get_functiondef('public.cancel_my_session_application(text)'::regprocedure);

-- Manual behavior checks must be run only through reviewed auth-context clients
-- and disposable fixtures. SQL Editor usually runs with owner/editor privileges;
-- do not use SQL Editor results to infer anon/authenticated behavior.
--
-- Suggested auth-context checks:
--   - anon cannot execute cancel_my_session_application.
--   - authenticated owner can cancel their pending application.
--   - authenticated owner can cancel their waitlisted application.
--   - authenticated owner can cancel their accepted application.
--   - authenticated owner cannot cancel another user's application.
--   - missing session id fails.
--   - missing application row fails.
--   - rejected application fails as not withdrawable.
--   - already canceled application returns safely.
--   - after cancel, get_public_session_application_counts excludes that user.
--   - after cancel, get_public_session_comments still returns existing comments.
--   - after cancel, mypage pending/accepted lists do not show the application.
--   - returned columns do not include user_id, email, application_id, comment_id,
--     Discord IDs, tokens, or secrets.

-- ============================================================
-- 3. Rollback draft
-- ============================================================

-- If this was a new RPC and must be removed:
--
-- begin;
--
-- revoke all on function public.cancel_my_session_application(text) from public;
-- revoke all on function public.cancel_my_session_application(text) from anon;
-- revoke all on function public.cancel_my_session_application(text) from authenticated;
-- drop function if exists public.cancel_my_session_application(text);
-- notify pgrst, 'reload schema';
--
-- commit;
--
-- If preflight showed an older function with the same signature, save its
-- pg_get_functiondef output before replacement and restore that reviewed
-- definition instead of using this drop-only rollback.

-- ============================================================
-- 4. Out of scope for this draft
-- ============================================================

--   - running SQL in Supabase SQL Editor
--   - changing DB constraints or adding a withdrawn status
--   - adding session_application_events
--   - deleting, editing, or creating comments
--   - posting a withdrawal reason comment
--   - production session-detail.html implementation
--   - GM history RPC implementation
--   - GM operation UI
--   - close_session
--   - updates.json changes
