-- Supabase F-6 comment management RPC draft
-- Purpose:
--   Draft RPCs for application comment editing, logical deletion, and
--   application cancel handling after the last active application comment.
--
-- DRAFT ONLY:
--   Do not run against production.
--   Do not paste Project URL, API keys, high privilege keys, DB passwords,
--   real emails, real Discord IDs, Discord tokens, or notification URLs here.
--   Review in a prototype project before any execution.
--
-- Existing assumptions from 001/002/003:
--   session_comments has:
--     id, session_id, user_id, body, is_application,
--     created_at, updated_at, edited_at, deleted_at
--   session_applications has:
--     id, session_id, user_id, comment_id, status,
--     created_at, updated_at, canceled_at
--   session_applications.status currently allows:
--     pending, accepted, rejected, waitlisted, canceled
--   public.is_session_gm(text) and public.is_admin() already exist.

-- ============================================================
-- 0. Optional audit columns
-- ============================================================
-- Existing schema already has edited_at / deleted_at.
-- If the project wants to record who edited/deleted a comment, add these columns.
-- They are intentionally nullable so existing rows remain valid.

alter table public.session_comments
  add column if not exists edited_by uuid references public.profiles(id) on delete set null,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

create index if not exists session_comments_edited_by_idx
  on public.session_comments(edited_by);

create index if not exists session_comments_deleted_by_idx
  on public.session_comments(deleted_by);

-- ============================================================
-- 1. Status constraint verification
-- ============================================================
-- Existing 001_core_schema_draft.sql already defines:
--   session_applications_status_check
-- with canceled included.
-- Use this query to verify before running F-6 functions.
-- Do not change the constraint unless this check shows a mismatch.

select
  'session_applications_status_check' as check_name,
  conname,
  pg_catalog.pg_get_constraintdef(oid) as definition
from pg_catalog.pg_constraint
where conrelid = 'public.session_applications'::regclass
  and conname = 'session_applications_status_check';

-- If a prototype database was created from an older draft that does not allow
-- canceled, update the constraint in a separate reviewed migration. Do not
-- mix that repair with this RPC draft without review.

-- ============================================================
-- 2. update_application_comment
-- ============================================================
-- Allows:
--   - comment owner to edit their own non-deleted comment
--   - target session GM to edit comments on their own session
--   - admin to edit all comments
-- Does not allow:
--   - anon edits
--   - editing deleted comments
--   - blank body
--   - body longer than the current 4000 character check
--
-- HTML/script safety should be handled by rendering text safely in the UI.
-- This RPC stores text; frontend must not inject body as HTML.

create or replace function public.update_application_comment(
  target_comment_id uuid,
  comment_body text
)
returns table (
  comment_id uuid,
  session_id text,
  edited_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null then
    raise exception 'not authenticated';
  end if;

  if target_comment_id is null then
    raise exception 'comment id is required';
  end if;

  if comment_body is null or length(trim(comment_body)) = 0 then
    raise exception 'comment body is blank';
  end if;

  if length(comment_body) > 4000 then
    raise exception 'comment body is too long';
  end if;

  return query
  update public.session_comments as c
  set
    body = comment_body,
    edited_at = now(),
    edited_by = v_actor_id,
    updated_at = now()
  where c.id = target_comment_id
    and c.deleted_at is null
    and (
      c.user_id = v_actor_id
      or public.is_session_gm(c.session_id)
      or public.is_admin()
    )
  returning
    c.id,
    c.session_id,
    c.edited_at;

  if not found then
    raise exception 'comment not found or not editable';
  end if;
end;
$$;

revoke all on function public.update_application_comment(uuid, text) from public;
grant execute on function public.update_application_comment(uuid, text) to authenticated;

-- ============================================================
-- 3. delete_application_comment_and_maybe_cancel
-- ============================================================
-- Logical delete only:
--   - sets session_comments.deleted_at
--   - sets session_comments.deleted_by if audit column exists
--   - does not physically delete the row
--
-- Application cancel rule:
--   If the target user has no remaining active application comments for the
--   same session, set session_applications.status = 'canceled'.
--
-- Short-term status choice:
--   Use existing 'canceled' because the current status check already allows it.
--   A future 'withdrawn' value can distinguish PL self-withdrawal, but it
--   requires a separate constraint/RPC/test update.
--
-- Accepted applications:
--   This draft can cancel an accepted application if its last active comment
--   is deleted. The production UI must show a strong confirmation before
--   deleting the last active comment on an accepted application.

create or replace function public.delete_application_comment_and_maybe_cancel(
  target_comment_id uuid
)
returns table (
  deleted_comment_id uuid,
  affected_session_id text,
  application_status text,
  application_canceled boolean,
  active_application_comment_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_session_id text;
  v_comment_user_id uuid;
  v_is_application boolean := false;
  v_active_count integer := 0;
  v_cancel_update_count integer := 0;
  v_application_status text;
  v_can_manage boolean := false;
begin
  if v_actor_id is null then
    raise exception 'not authenticated';
  end if;

  if target_comment_id is null then
    raise exception 'comment id is required';
  end if;

  select
    c.session_id,
    c.user_id,
    c.is_application
  into
    v_session_id,
    v_comment_user_id,
    v_is_application
  from public.session_comments as c
  where c.id = target_comment_id
    and c.deleted_at is null;

  if v_session_id is null or v_comment_user_id is null then
    raise exception 'comment not found or already deleted';
  end if;

  v_can_manage :=
    v_comment_user_id = v_actor_id
    or public.is_session_gm(v_session_id)
    or public.is_admin();

  if not v_can_manage then
    raise exception 'comment not deletable';
  end if;

  update public.session_comments as c
  set
    deleted_at = now(),
    deleted_by = v_actor_id,
    updated_at = now()
  where c.id = target_comment_id
    and c.deleted_at is null;

  if not found then
    raise exception 'comment not found or already deleted';
  end if;

  select count(*)
  into v_active_count
  from public.session_comments as c
  where c.session_id = v_session_id
    and c.user_id = v_comment_user_id
    and c.is_application = true
    and c.deleted_at is null;

  if v_is_application and v_active_count = 0 then
    update public.session_applications as sa
    set
      status = 'canceled',
      canceled_at = coalesce(sa.canceled_at, now()),
      updated_at = now()
    where sa.session_id = v_session_id
      and sa.user_id = v_comment_user_id
      and sa.status in ('pending', 'accepted', 'rejected', 'waitlisted')
    returning sa.status
    into v_application_status;

    get diagnostics v_cancel_update_count = row_count;
  end if;

  if v_application_status is null then
    select sa.status
    into v_application_status
    from public.session_applications as sa
    where sa.session_id = v_session_id
      and sa.user_id = v_comment_user_id;
  end if;

  return query
  select
    target_comment_id,
    v_session_id,
    v_application_status,
    v_cancel_update_count > 0,
    v_active_count;
end;
$$;

revoke all on function public.delete_application_comment_and_maybe_cancel(uuid) from public;
grant execute on function public.delete_application_comment_and_maybe_cancel(uuid) to authenticated;

-- ============================================================
-- 4. Public comment RPC impact
-- ============================================================
-- Existing get_public_session_comments(target_session_id) already filters:
--   c.deleted_at is null
-- and does not return:
--   user_id, discord_user_id, email, role
--
-- Keep that separation:
--   - public comments RPC returns display_name/body/application_status only
--   - GM-specific operation screens should not depend on public RPC for
--     application_id or internal user_id
--
-- Future GM list RPC candidate, not implemented here:
--   get_gm_session_application_comments(target_session_id text)
-- It should return minimum GM-facing fields:
--   application_id, comment_id, session_id, display_name, body,
--   application_status, created_at, updated_at, edited_at
-- and should not return:
--   user_id, discord_user_id, email, role, tokens, secrets

-- Verification query: public comment RPC should keep deleted_at filtering.
select
  'get_public_session_comments_deleted_filter' as check_name,
  case
    when pg_catalog.pg_get_functiondef('public.get_public_session_comments(text)'::regprocedure)
      like '%c.deleted_at is null%'
    then 'ok'
    else 'review'
  end as result;

-- ============================================================
-- 5. Public application count RPC impact
-- ============================================================
-- Existing get_public_session_application_counts(target_session_id) counts by
-- session_applications rows, not by comment rows.
--
-- Expected:
--   accepted_count   = distinct accepted users
--   pending_count    = distinct pending users
--   waitlisted_count = distinct waitlisted users
-- Not counted:
--   rejected, canceled, future withdrawn
--
-- Because session_applications has unique(session_id, user_id), each applicant
-- contributes at most one row per session regardless of comment count.

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

-- ============================================================
-- 6. Privilege checks
-- ============================================================
-- Do not grant direct UPDATE / DELETE on session_comments or session_applications
-- to anon/authenticated for this feature. Mutations should go through RPCs.

select
  'comment_management_function_privileges' as check_name,
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name in (
    'update_application_comment',
    'delete_application_comment_and_maybe_cancel'
  )
order by routine_name, grantee, privilege_type;

select
  'direct_table_mutation_privileges_review' as check_name,
  table_name,
  grantee,
  privilege_type
from information_schema.table_privileges
where table_schema = 'public'
  and table_name in ('session_comments', 'session_applications')
  and grantee in ('anon', 'authenticated')
  and privilege_type in ('UPDATE', 'DELETE')
order by table_name, grantee, privilege_type;

-- ============================================================
-- 7. Test checklist for Auth-context smoke tests
-- ============================================================
-- Add these to the next smoke test script / manual matrix:
--
-- update_application_comment:
--   - owner can edit own comment
--   - owner cannot edit another user's comment
--   - GM can edit a comment on their own session
--   - GM cannot edit a comment on another GM's session
--   - anon cannot edit
--   - deleted comment cannot be edited
--   - blank body fails
--   - body > 4000 chars fails
--
-- delete_application_comment_and_maybe_cancel:
--   - owner can delete own comment
--   - owner cannot delete another user's comment
--   - GM can delete a comment on their own session
--   - GM cannot delete a comment on another GM's session
--   - anon cannot delete
--   - deleted comment does not appear in get_public_session_comments
--   - if another active application comment remains, application status stays
--   - if deleting the last active application comment, application status becomes canceled
--   - if deleting a future non-application comment, application status does not change
--   - accepted application last-comment deletion requires UI confirmation
--   - counts do not include canceled application rows
--
-- Out of scope for this draft:
--   - running this SQL in Supabase SQL Editor
--   - production session-detail.html implementation
--   - production calendar.html implementation
--   - dev UI prototype implementation
--   - Discord OAuth/notifications
--   - email notifications
--   - Edge Functions
--   - close_session
--   - production GM/admin management screen
