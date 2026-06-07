-- SELECT ONLY / DO NOT APPLY / NO MUTATION
-- Purpose: fixed preflight for logged-in non-GM session-post create failure.
-- Replaces 038 for the next SQL Editor gate because 038 treated PUBLIC as a role.
-- This query does not reference PUBLIC as a role and does not return real IDs.
-- Do not paste tokens, URLs, or user data into this file.

with role_refs as (
  select
    to_regrole('authenticated')::oid as authenticated_oid,
    to_regrole('anon')::oid as anon_oid
),
target_functions as (
  select
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) as args,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config,
    pg_get_functiondef(p.oid) as function_def
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('create_session_post', 'update_session_post', 'delete_session_post')
),
execute_privileges as (
  select
    tf.proname,
    coalesce(rr.authenticated_oid is not null, false) as authenticated_role_exists,
    coalesce(rr.anon_oid is not null, false) as anon_role_exists,
    case
      when rr.authenticated_oid is null then false
      else coalesce(has_function_privilege(rr.authenticated_oid, tf.oid, 'EXECUTE'), false)
    end as authenticated_can_execute,
    case
      when rr.anon_oid is null then false
      else coalesce(has_function_privilege(rr.anon_oid, tf.oid, 'EXECUTE'), false)
    end as anon_can_execute
  from target_functions tf
  cross join role_refs rr
),
helper_functions as (
  select
    p.proname,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('has_role', 'is_admin', 'is_session_gm')
),
status_checks as (
  select
    c.conname,
    pg_get_constraintdef(c.oid) as constraint_def
  from pg_constraint c
  join pg_class t on t.oid = c.conrelid
  join pg_namespace n on n.oid = t.relnamespace
  where n.nspname = 'public'
    and t.relname = 'sessions'
    and c.contype = 'c'
    and c.conname ilike '%status%'
),
checks as (
  select
    'create_rpc_exists' as check_name,
    case when exists (select 1 from target_functions where proname = 'create_session_post') then 'ok' else 'missing' end as status,
    (select count(*)::text from target_functions where proname = 'create_session_post') as result_value,
    'create_session_post function count' as note
  union all
  select
    'create_rpc_security_definer',
    case when exists (select 1 from target_functions where proname = 'create_session_post' and security_definer) then 'ok' else 'review' end,
    coalesce((select security_definer::text from target_functions where proname = 'create_session_post' limit 1), 'missing'),
    'security definer flag'
  union all
  select
    'create_rpc_has_search_path',
    case when exists (select 1 from target_functions where proname = 'create_session_post' and function_config ilike '%search_path%') then 'ok' else 'review' end,
    coalesce((select (function_config ilike '%search_path%')::text from target_functions where proname = 'create_session_post' limit 1), 'missing'),
    'search_path config'
  union all
  select
    'authenticated_role_exists',
    case when exists (select 1 from role_refs where authenticated_oid is not null) then 'ok' else 'missing' end,
    coalesce((select (authenticated_oid is not null)::text from role_refs), 'false'),
    'role lookup via to_regrole'
  union all
  select
    'create_rpc_authenticated_execute',
    case when exists (select 1 from execute_privileges where proname = 'create_session_post' and authenticated_can_execute) then 'ok' else 'review' end,
    coalesce((select authenticated_can_execute::text from execute_privileges where proname = 'create_session_post' limit 1), 'missing'),
    'authenticated execute privilege'
  union all
  select
    'create_rpc_anon_execute',
    case when exists (select 1 from execute_privileges where proname = 'create_session_post' and not anon_can_execute) then 'ok' else 'review' end,
    coalesce((select anon_can_execute::text from execute_privileges where proname = 'create_session_post' limit 1), 'missing'),
    'anon execute state; PUBLIC pseudo-role is intentionally not checked here'
  union all
  select
    'create_rpc_has_gm_admin_gate',
    case when exists (
      select 1 from target_functions
      where proname = 'create_session_post'
        and function_def ilike '%gm_or_admin_required%'
        and function_def ilike '%has_role(''gm'')%'
    ) then 'review' else 'ok' end,
    coalesce((
      select (
        function_def ilike '%gm_or_admin_required%'
        and function_def ilike '%has_role(''gm'')%'
      )::text
      from target_functions
      where proname = 'create_session_post'
      limit 1
    ), 'missing'),
    'review means logged-in non-GM users are blocked by RPC body'
  union all
  select
    'create_rpc_initial_status_limited',
    case when exists (
      select 1 from target_functions
      where proname = 'create_session_post'
        and function_def ilike '%invalid_initial_status%'
        and function_def ilike '%draft%'
        and function_def ilike '%tentative%'
        and function_def ilike '%recruiting%'
    ) then 'review' else 'unknown' end,
    coalesce((
      select (function_def ilike '%invalid_initial_status%')::text
      from target_functions
      where proname = 'create_session_post'
      limit 1
    ), 'missing'),
    'review means initial status likely excludes finished/closed/canceled'
  union all
  select
    'status_check_constraints_present',
    case when exists (select 1 from status_checks) then 'ok' else 'missing' end,
    (select count(*)::text from status_checks),
    'sessions status-related check count'
  union all
  select
    'helper_has_role_exists',
    case when exists (select 1 from helper_functions where proname = 'has_role') then 'ok' else 'missing' end,
    (select count(*)::text from helper_functions where proname = 'has_role'),
    'role helper presence'
  union all
  select
    'helper_is_admin_exists',
    case when exists (select 1 from helper_functions where proname = 'is_admin') then 'ok' else 'missing' end,
    (select count(*)::text from helper_functions where proname = 'is_admin'),
    'admin helper presence'
  union all
  select
    'general_user_create_change_needed',
    case when exists (
      select 1 from target_functions
      where proname = 'create_session_post'
        and function_def ilike '%gm_or_admin_required%'
        and function_def ilike '%has_role(''gm'')%'
    ) then 'review' else 'ok' end,
    coalesce((
      select (
        function_def ilike '%gm_or_admin_required%'
        and function_def ilike '%has_role(''gm'')%'
      )::text
      from target_functions
      where proname = 'create_session_post'
      limit 1
    ), 'missing'),
    'review means RPC change is likely required to allow logged-in non-GM create'
)
select
  check_name,
  status,
  result_value,
  note
from checks
order by check_name;
