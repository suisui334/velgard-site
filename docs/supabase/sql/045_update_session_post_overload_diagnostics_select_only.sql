-- 045_update_session_post_overload_diagnostics_select_only.sql
-- SELECT ONLY / DO NOT APPLY / NO MUTATION
--
-- Purpose:
-- - Diagnose public.update_session_post overloads after the 044 apply gate.
-- - Identify which overload matches the current frontend payload.
-- - Check whether any overload still contains the old GM-role owner gate.
--
-- Run policy:
-- - Run once only in a later SQL Editor gate.
-- - If an error appears, stop and do not rerun.
-- - Do not paste raw IDs, user IDs, emails, JWTs, session IDs, URLs, Discord IDs, or message previews.

with expected_frontend_args(arg_name, sort_order) as (
  values
    ('p_session_id', 1),
    ('p_title', 2),
    ('p_session_date', 3),
    ('p_start_time', 4),
    ('p_end_time', 5),
    ('p_application_deadline', 6),
    ('p_session_type', 7),
    ('p_player_min', 8),
    ('p_player_max', 9),
    ('p_summary', 10),
    ('p_visibility', 11),
    ('p_status', 12),
    ('p_end_at', 13),
    ('p_session_tool', 14)
),
role_oids as (
  select
    to_regrole('authenticated') as authenticated_role,
    to_regrole('anon') as anon_role
),
target_functions as (
  select
    row_number() over (order by p.oid::regprocedure::text) as overload_ordinal,
    p.oid,
    p.oid::regprocedure::text as signature,
    p.pronargs as input_arg_count,
    pg_get_function_identity_arguments(p.oid) as identity_arguments,
    pg_get_function_arguments(p.oid) as full_arguments,
    pg_get_function_result(p.oid) as function_result,
    p.prosecdef as security_definer,
    exists (
      select 1
      from unnest(coalesce(p.proconfig, array[]::text[])) as cfg
      where cfg like 'search_path=%'
    ) as has_search_path,
    pg_get_functiondef(p.oid) as function_def
  from pg_proc as p
  join pg_namespace as n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'update_session_post'
),
function_checks as (
  select
    f.overload_ordinal,
    f.oid,
    f.signature,
    f.input_arg_count,
    f.identity_arguments,
    f.full_arguments,
    f.function_result,
    f.security_definer,
    f.has_search_path,
    lower(f.function_def) like '%has_role(''gm'')%'
      and lower(f.function_def) like '%gm_user_id = v_actor%' as has_old_gm_owner_gate,
    lower(f.function_def) like '%is_session_gm%' as has_is_session_gm_pattern,
    (
      select count(*)
      from expected_frontend_args as e
      where f.identity_arguments ~ ('(^|,\s*)' || e.arg_name || '\s+')
    ) as frontend_arg_match_count,
    exists (
      select 1
      from expected_frontend_args as e
      where e.arg_name = 'p_session_tool'
        and f.identity_arguments ~ ('(^|,\s*)' || e.arg_name || '\s+')
    ) as has_p_session_tool_arg,
    exists (
      select 1
      from expected_frontend_args as e
      where e.arg_name = 'p_end_at'
        and f.identity_arguments ~ ('(^|,\s*)' || e.arg_name || '\s+')
    ) as has_p_end_at_arg,
    case
      when (select authenticated_role from role_oids) is null then null
      else has_function_privilege((select authenticated_role from role_oids), f.oid, 'EXECUTE')
    end as authenticated_can_execute,
    case
      when (select anon_role from role_oids) is null then null
      else has_function_privilege((select anon_role from role_oids), f.oid, 'EXECUTE')
    end as anon_can_execute
  from target_functions as f
),
summary as (
  select
    count(*) as overload_count,
    count(*) filter (where frontend_arg_match_count = (select count(*) from expected_frontend_args)) as frontend_matching_overload_count,
    count(*) filter (
      where frontend_arg_match_count = (select count(*) from expected_frontend_args)
        and has_old_gm_owner_gate
    ) as frontend_matching_old_gate_count,
    count(*) filter (where has_old_gm_owner_gate) as old_gate_overload_count,
    count(*) filter (where has_is_session_gm_pattern) as is_session_gm_overload_count,
    count(*) filter (where not has_p_session_tool_arg) as overload_without_session_tool_count,
    count(*) filter (where input_arg_count = 13 and not has_p_session_tool_arg) as legacy_without_session_tool_count,
    count(*) filter (where security_definer) as security_definer_count,
    count(*) filter (where has_search_path) as search_path_count
  from function_checks
),
checks as (
  select
    'update_session_post_overload_count' as check_name,
    case when overload_count = 1 then 'ok' when overload_count > 1 then 'review' else 'missing' end as status,
    overload_count::text as result_value,
    'more than one overload can cause PostgREST/RPC ambiguity review' as note
  from summary

  union all
  select
    'frontend_expected_arg_count',
    'info',
    count(*)::text,
    'current renderSessionPost.js update payload includes p_session_tool'
  from expected_frontend_args

  union all
  select
    'frontend_matching_overload_count',
    case when frontend_matching_overload_count = 1 then 'ok' when frontend_matching_overload_count = 0 then 'missing' else 'review' end,
    frontend_matching_overload_count::text,
    'expected exactly one overload matching all frontend payload keys'
  from summary

  union all
  select
    'frontend_matching_old_gate_count',
    case when frontend_matching_old_gate_count = 0 then 'ok' else 'review' end,
    frontend_matching_old_gate_count::text,
    'nonzero means the frontend-callable overload still has the old GM-role gate'
  from summary

  union all
  select
    'old_gate_overload_count',
    case when old_gate_overload_count = 0 then 'ok' else 'review' end,
    old_gate_overload_count::text,
    'nonzero means at least one update_session_post overload still has old has_role(gm)+owner logic'
  from summary

  union all
  select
    'legacy_without_session_tool_count',
    case when legacy_without_session_tool_count = 0 then 'ok' else 'review' end,
    legacy_without_session_tool_count::text,
    'legacy 13-input overload without p_session_tool may need a cleanup apply draft'
  from summary

  union all
  select
    'is_session_gm_overload_count',
    case when is_session_gm_overload_count = overload_count and overload_count > 0 then 'ok' else 'review' end,
    is_session_gm_overload_count::text,
    'all active update overloads should use owner/admin helper after cleanup'
  from summary

  union all
  select
    'security_definer_overload_count',
    case when security_definer_count = overload_count and overload_count > 0 then 'ok' else 'review' end,
    security_definer_count::text,
    'all update overloads should remain security definer'
  from summary

  union all
  select
    'search_path_overload_count',
    case when search_path_count = overload_count and overload_count > 0 then 'ok' else 'review' end,
    search_path_count::text,
    'all update overloads should keep search_path set'
  from summary

  union all
  select
    'overload_cleanup_needed',
    case
      when old_gate_overload_count > 0 then 'review'
      when overload_count > 1 then 'review'
      else 'ok'
    end,
    (old_gate_overload_count > 0 or overload_count > 1)::text,
    'true means prepare a cleanup/replacement apply draft before edit or close-mark QA'
  from summary

  union all
  select
    'frontend_call_risk',
    case
      when frontend_matching_old_gate_count > 0 then 'review'
      when frontend_matching_overload_count <> 1 then 'review'
      when overload_count > 1 then 'review'
      else 'ok'
    end,
    case
      when frontend_matching_old_gate_count > 0 then 'frontend_matching_old_gate'
      when frontend_matching_overload_count = 0 then 'no_frontend_match'
      when frontend_matching_overload_count > 1 then 'multiple_frontend_matches'
      when overload_count > 1 then 'extra_overload_present'
      else 'single_frontend_match_no_old_gate'
    end,
    'review before using edit-save or GM close-mark on the diagnostic target'
)
select
  check_name,
  status,
  result_value,
  note
from checks

union all

select
  'overload_' || overload_ordinal::text || '_signature',
  'info',
  signature,
  'signature text only; no function body or raw IDs returned'
from function_checks

union all

select
  'overload_' || overload_ordinal::text || '_identity_arguments',
  'info',
  identity_arguments,
  'input argument names/types/defaults; no function body returned'
from function_checks

union all

select
  'overload_' || overload_ordinal::text || '_input_arg_count',
  'info',
  input_arg_count::text,
  'frontend update payload expects all listed named parameters'
from function_checks

union all

select
  'overload_' || overload_ordinal::text || '_matches_frontend_payload',
  case when frontend_arg_match_count = (select count(*) from expected_frontend_args) then 'ok' else 'review' end,
  (frontend_arg_match_count = (select count(*) from expected_frontend_args))::text,
  'true means all current frontend update payload keys are present'
from function_checks

union all

select
  'overload_' || overload_ordinal::text || '_has_p_session_tool_arg',
  case when has_p_session_tool_arg then 'ok' else 'review' end,
  has_p_session_tool_arg::text,
  'current frontend update payload includes p_session_tool'
from function_checks

union all

select
  'overload_' || overload_ordinal::text || '_has_old_gm_owner_gate',
  case when has_old_gm_owner_gate then 'review' else 'ok' end,
  has_old_gm_owner_gate::text,
  'true means old role-gated owner logic remains in this overload'
from function_checks

union all

select
  'overload_' || overload_ordinal::text || '_has_is_session_gm_pattern',
  case when has_is_session_gm_pattern then 'ok' else 'review' end,
  has_is_session_gm_pattern::text,
  'true means owner/admin helper appears in this overload'
from function_checks

union all

select
  'overload_' || overload_ordinal::text || '_security_definer',
  case when security_definer then 'ok' else 'review' end,
  security_definer::text,
  'security definer should remain true'
from function_checks

union all

select
  'overload_' || overload_ordinal::text || '_has_search_path',
  case when has_search_path then 'ok' else 'review' end,
  has_search_path::text,
  'search_path should remain configured'
from function_checks

union all

select
  'overload_' || overload_ordinal::text || '_authenticated_execute',
  case when authenticated_can_execute is true then 'ok' else 'review' end,
  coalesce(authenticated_can_execute::text, 'role_missing'),
  'authenticated should execute the frontend-callable RPC'
from function_checks

union all

select
  'overload_' || overload_ordinal::text || '_anon_execute',
  case when anon_can_execute is false then 'ok' else 'review' end,
  coalesce(anon_can_execute::text, 'role_missing'),
  'anon should not execute update_session_post'
from function_checks
order by check_name;
