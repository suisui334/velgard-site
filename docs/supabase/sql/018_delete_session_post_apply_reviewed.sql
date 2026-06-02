-- 018_delete_session_post_apply_reviewed.sql
-- M-14D-13C reviewed APPLY-only SQL for delete_session_post.
-- Paste this entire file into Supabase SQL Editor only after review.
-- Do not paste the full draft file.
-- This file intentionally excludes preflight queries and rollback drafts.

create or replace function public.delete_session_post(
  p_session_id text
)
returns table (
  deleted_session_id text,
  deleted_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_target_session_id text;
  v_existing record;
  v_deleted_at timestamptz := now();
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_target_session_id := nullif(trim(coalesce(p_session_id, '')), '');
  if v_target_session_id is null then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  select
    s.id,
    s.gm_user_id
  into v_existing
  from public.sessions as s
  where s.id = v_target_session_id
  for update;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not (
    coalesce(public.is_admin(), false)
    or (
      coalesce(public.has_role('gm'), false)
      and v_existing.gm_user_id = v_actor
    )
  ) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  -- Static JSON sessions are outside public.sessions and cannot be targeted here.
  -- M-14D-13B preflight confirmed that session_applications.session_id and
  -- session_comments.session_id both use ON DELETE CASCADE.
  -- Application rows and application comment rows for the target session are
  -- removed together with the session by those constraints.
  delete from public.sessions as s
  where s.id = v_existing.id;

  deleted_session_id := v_existing.id;
  deleted_at := v_deleted_at;
  return next;
end;
$$;

comment on function public.delete_session_post(text) is
  'Deletes one session post for admin or owner GM. Returns only deleted_session_id and deleted_at.';

revoke execute on function public.delete_session_post(text) from public;
revoke execute on function public.delete_session_post(text) from anon;
grant execute on function public.delete_session_post(text) to authenticated;

select
  p.oid::regprocedure as signature,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'delete_session_post'
order by p.oid::regprocedure::text;

with expected_grants(grantee, expected_execute) as (
  values
    ('authenticated', true),
    ('anon', false),
    ('public', false)
),
actual_grants as (
  select
    lower(grantee) as grantee,
    bool_or(privilege_type = 'EXECUTE') as actual_execute
  from information_schema.routine_privileges
  where routine_schema = 'public'
    and routine_name = 'delete_session_post'
  group by lower(grantee)
)
select
  e.grantee,
  e.expected_execute,
  coalesce(a.actual_execute, false) as actual_execute,
  coalesce(a.actual_execute, false) = e.expected_execute as ok
from expected_grants e
left join actual_grants a
  on a.grantee = e.grantee
order by e.grantee;
