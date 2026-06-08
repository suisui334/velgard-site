-- SELECT ONLY / NO MUTATION
-- Purpose: post-apply confirmation for the general-user create_session_post RPC update.
-- Run once in SQL Editor only after a separate approval gate.
-- This query does not return real IDs, user rows, URLs, Discord IDs, JWTs, or personal data.
-- PUBLIC is not treated as a normal role.

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
    pg_get_function_result(p.oid) as result_def,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config,
    pg_get_functiondef(p.oid) as function_def
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('create_session_post', 'update_session_post', 'delete_session_post')
),
create_rpc as (
  select *
  from target_functions
  where proname = 'create_session_post'
),
execute_privileges as (
  select
    cr.proname,
    coalesce(rr.authenticated_oid is not null, false) as authenticated_role_exists,
    coalesce(rr.anon_oid is not null, false) as anon_role_exists,
    case
      when rr.authenticated_oid is null then false
      else coalesce(has_function_privilege(rr.authenticated_oid, cr.oid, 'EXECUTE'), false)
    end as authenticated_can_execute,
    case
      when rr.anon_oid is null then false
      else coalesce(has_function_privilege(rr.anon_oid, cr.oid, 'EXECUTE'), false)
    end as anon_can_execute
  from create_rpc cr
  cross join role_refs rr
),
create_patterns as (
  select
    exists (select 1 from create_rpc) as exists_flag,
    coalesce((select security_definer from create_rpc limit 1), false) as security_definer_flag,
    coalesce((select function_config ilike '%search_path%' from create_rpc limit 1), false) as search_path_flag,
    coalesce((select args ilike '%p_session_tool text%' from create_rpc limit 1), false) as has_session_tool_arg,
    coalesce((select result_def ilike '%session_id text%' and result_def ilike '%discord_sync_status text%' and result_def ilike '%created_at timestamp with time zone%' from create_rpc limit 1), false) as return_shape_ok,
    coalesce((select function_def ilike '%gm_or_admin_required%' from create_rpc limit 1), false) as has_gm_or_admin_required,
    coalesce((select function_def ilike '%has_role(''gm'')%' from create_rpc limit 1), false) as has_gm_role_pattern,
    coalesce((select function_def ilike '%is_admin()%' from create_rpc limit 1), false) as has_is_admin_pattern,
    coalesce((select function_def ilike '%gm_user_id%' and function_def ilike '%auth.uid()%' from create_rpc limit 1), false) as creator_owner_pattern,
    coalesce((select function_def ~* $$v_status\s+not\s+in\s*\(\s*'draft'\s*,\s*'tentative'\s*,\s*'recruiting'\s*\)$$ from create_rpc limit 1), false) as initial_status_guard_exact,
    coalesce((select function_def ilike '%invalid_initial_status%' from create_rpc limit 1), false) as invalid_initial_status_present,
    coalesce((select function_def ilike '%''closed''%' or function_def ilike '%''finished''%' or function_def ilike '%''canceled''%' from create_rpc limit 1), false) as create_body_mentions_disallowed_initial_statuses
),
checks as (
  select
    'create_rpc_exists' as check_name,
    case when (select exists_flag from create_patterns) then 'ok' else 'missing' end as status,
    (select count(*)::text from create_rpc) as result_value,
    'create_session_post function count' as note
  union all
  select
    'create_rpc_security_definer',
    case when (select security_definer_flag from create_patterns) then 'ok' else 'review' end,
    (select security_definer_flag::text from create_patterns),
    'security definer flag'
  union all
  select
    'create_rpc_has_search_path',
    case when (select search_path_flag from create_patterns) then 'ok' else 'review' end,
    (select search_path_flag::text from create_patterns),
    'search_path config'
  union all
  select
    'create_rpc_signature_has_session_tool',
    case when (select has_session_tool_arg from create_patterns) then 'ok' else 'review' end,
    (select has_session_tool_arg::text from create_patterns),
    'p_session_tool argument retained'
  union all
  select
    'create_rpc_return_shape',
    case when (select return_shape_ok from create_patterns) then 'ok' else 'review' end,
    (select return_shape_ok::text from create_patterns),
    'return shape contains session_id, discord_sync_status, created_at'
  union all
  select
    'authenticated_role_exists',
    case when exists (select 1 from role_refs where authenticated_oid is not null) then 'ok' else 'missing' end,
    coalesce((select (authenticated_oid is not null)::text from role_refs), 'false'),
    'role lookup via to_regrole'
  union all
  select
    'create_rpc_authenticated_execute',
    case when exists (select 1 from execute_privileges where authenticated_can_execute) then 'ok' else 'review' end,
    coalesce((select authenticated_can_execute::text from execute_privileges limit 1), 'missing'),
    'authenticated execute privilege'
  union all
  select
    'create_rpc_anon_execute',
    case when exists (select 1 from execute_privileges where not anon_can_execute) then 'ok' else 'review' end,
    coalesce((select anon_can_execute::text from execute_privileges limit 1), 'missing'),
    'anon execute state; expected false'
  union all
  select
    'create_rpc_gm_admin_gate_removed',
    case when not (
      (select has_gm_or_admin_required from create_patterns)
      or (select has_gm_role_pattern from create_patterns)
      or (select has_is_admin_pattern from create_patterns)
    ) then 'ok' else 'review' end,
    (
      not (
        (select has_gm_or_admin_required from create_patterns)
        or (select has_gm_role_pattern from create_patterns)
        or (select has_is_admin_pattern from create_patterns)
      )
    )::text,
    'true means no create-time GM/admin gate pattern was found'
  union all
  select
    'create_rpc_creator_owner_pattern',
    case when (select creator_owner_pattern from create_patterns) then 'ok' else 'review' end,
    (select creator_owner_pattern::text from create_patterns),
    'gm_user_id is tied to auth.uid() in the create RPC body'
  union all
  select
    'create_rpc_initial_status_guard',
    case when (select initial_status_guard_exact from create_patterns) and (select invalid_initial_status_present from create_patterns) then 'ok' else 'review' end,
    ((select initial_status_guard_exact from create_patterns) and (select invalid_initial_status_present from create_patterns))::text,
    'draft/tentative/recruiting guard retained'
  union all
  select
    'create_rpc_disallowed_initial_statuses_absent',
    case when not (select create_body_mentions_disallowed_initial_statuses from create_patterns) then 'ok' else 'review' end,
    (not (select create_body_mentions_disallowed_initial_statuses from create_patterns))::text,
    'true means closed/finished/canceled are not present in the create RPC body'
  union all
  select
    'update_session_post_exists',
    case when exists (select 1 from target_functions where proname = 'update_session_post') then 'ok' else 'missing' end,
    (select count(*)::text from target_functions where proname = 'update_session_post'),
    'presence only; 041 scope did not target update_session_post'
  union all
  select
    'delete_session_post_exists',
    case when exists (select 1 from target_functions where proname = 'delete_session_post') then 'ok' else 'missing' end,
    (select count(*)::text from target_functions where proname = 'delete_session_post'),
    'presence only; 041 scope did not target delete_session_post'
  union all
  select
    'post_apply_ready_for_general_create_qa',
    case when
      (select exists_flag from create_patterns)
      and (select security_definer_flag from create_patterns)
      and (select search_path_flag from create_patterns)
      and exists (select 1 from execute_privileges where authenticated_can_execute and not anon_can_execute)
      and not (
        (select has_gm_or_admin_required from create_patterns)
        or (select has_gm_role_pattern from create_patterns)
        or (select has_is_admin_pattern from create_patterns)
      )
      and (select creator_owner_pattern from create_patterns)
      and (select initial_status_guard_exact from create_patterns)
      and (select invalid_initial_status_present from create_patterns)
      and not (select create_body_mentions_disallowed_initial_statuses from create_patterns)
    then 'ok' else 'review' end,
    (
      (select exists_flag from create_patterns)
      and (select security_definer_flag from create_patterns)
      and (select search_path_flag from create_patterns)
      and exists (select 1 from execute_privileges where authenticated_can_execute and not anon_can_execute)
      and not (
        (select has_gm_or_admin_required from create_patterns)
        or (select has_gm_role_pattern from create_patterns)
        or (select has_is_admin_pattern from create_patterns)
      )
      and (select creator_owner_pattern from create_patterns)
      and (select initial_status_guard_exact from create_patterns)
      and (select invalid_initial_status_present from create_patterns)
      and not (select create_body_mentions_disallowed_initial_statuses from create_patterns)
    )::text,
    'ok means DB/RPC state is ready for a separate general-user create QA gate'
)
select
  check_name,
  status,
  result_value,
  note
from checks
order by check_name;
