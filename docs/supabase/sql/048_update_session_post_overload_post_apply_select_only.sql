-- 048_update_session_post_overload_post_apply_select_only.sql
-- SELECT ONLY / DO NOT APPLY / NO MUTATION
--
-- Purpose:
-- - Confirm the post-047 public.update_session_post overload state.
-- - Verify that the frontend-matching 14-input overload uses owner/admin gating.
-- - Verify that the old GM-role owner gate and legacy anon-executable overload are gone.
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
expected_arg_count as (
  select count(*)::int as value
  from expected_frontend_args
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
    p.pronargs::int as input_arg_count,
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
function_pattern_checks as (
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
    lower(f.function_def) like '%has_role(''gm''%' as has_gm_role_call,
    lower(f.function_def) like '%gm_user_id%' as has_owner_column_reference,
    lower(f.function_def) like '%is_session_gm%' as has_is_session_gm_pattern,
    (
      select count(*)::int
      from expected_frontend_args as e
      where f.identity_arguments ~ ('(^|,[[:space:]]*)' || e.arg_name || '[[:space:]]+')
    ) as frontend_arg_match_count,
    exists (
      select 1
      from expected_frontend_args as e
      where e.arg_name = 'p_session_tool'
        and f.identity_arguments ~ ('(^|,[[:space:]]*)' || e.arg_name || '[[:space:]]+')
    ) as has_p_session_tool_arg,
    exists (
      select 1
      from expected_frontend_args as e
      where e.arg_name = 'p_end_at'
        and f.identity_arguments ~ ('(^|,[[:space:]]*)' || e.arg_name || '[[:space:]]+')
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
function_checks as (
  select
    f.*,
    (f.has_gm_role_call and f.has_owner_column_reference) as has_old_gm_owner_gate,
    (
      f.frontend_arg_match_count = e.value
      and f.input_arg_count = e.value
      and f.has_p_session_tool_arg
    ) as matches_frontend_payload
  from function_pattern_checks as f
  cross join expected_arg_count as e
),
summary_counts as (
  select
    count(*)::int as overload_count,
    (select value from expected_arg_count)::int as expected_frontend_arg_count,
    count(*) filter (where matches_frontend_payload)::int as frontend_matching_overload_count,
    count(*) filter (where matches_frontend_payload and has_old_gm_owner_gate)::int as frontend_matching_old_gate_count,
    count(*) filter (where matches_frontend_payload and has_is_session_gm_pattern)::int as frontend_matching_is_session_gm_count,
    count(*) filter (where matches_frontend_payload and security_definer)::int as frontend_matching_security_definer_count,
    count(*) filter (where matches_frontend_payload and has_search_path)::int as frontend_matching_search_path_count,
    count(*) filter (where matches_frontend_payload and authenticated_can_execute is true)::int as frontend_matching_authenticated_execute_count,
    count(*) filter (where matches_frontend_payload and anon_can_execute is true)::int as frontend_matching_anon_execute_count,
    count(*) filter (where has_old_gm_owner_gate)::int as old_gate_overload_count,
    count(*) filter (where has_is_session_gm_pattern)::int as is_session_gm_overload_count,
    count(*) filter (where not has_p_session_tool_arg)::int as overload_without_session_tool_count,
    count(*) filter (where input_arg_count = 13 and not has_p_session_tool_arg)::int as legacy_without_session_tool_count,
    count(*) filter (where security_definer)::int as security_definer_count,
    count(*) filter (where has_search_path)::int as search_path_count,
    count(*) filter (where authenticated_can_execute is true)::int as authenticated_execute_count,
    count(*) filter (where anon_can_execute is true)::int as anon_execute_count
  from function_checks
),
summary_flags as (
  select
    s.*,
    (
      s.frontend_matching_overload_count = 1
      and s.frontend_matching_old_gate_count = 0
      and s.frontend_matching_is_session_gm_count = 1
      and s.frontend_matching_security_definer_count = 1
      and s.frontend_matching_search_path_count = 1
      and s.frontend_matching_authenticated_execute_count = 1
      and s.frontend_matching_anon_execute_count = 0
      and s.old_gate_overload_count = 0
      and s.legacy_without_session_tool_count = 0
      and s.anon_execute_count = 0
    ) as post_apply_ready_for_owner_update_qa,
    case
      when s.frontend_matching_old_gate_count > 0 then 'frontend_matching_old_gate'
      when s.frontend_matching_overload_count = 0 then 'no_frontend_match'
      when s.frontend_matching_overload_count > 1 then 'multiple_frontend_matches'
      when s.frontend_matching_is_session_gm_count <> 1 then 'frontend_match_missing_is_session_gm'
      when s.frontend_matching_anon_execute_count > 0 then 'frontend_match_anon_executable'
      when s.old_gate_overload_count > 0 then 'old_gate_elsewhere'
      when s.legacy_without_session_tool_count > 0 then 'legacy_without_session_tool_present'
      when s.anon_execute_count > 0 then 'anon_executable_overload_present'
      else 'ready_for_owner_update_qa'
    end as frontend_call_risk_value
  from summary_counts as s
),
checks as (
  select
    'update_session_post_overload_count' as check_name,
    case when overload_count = 1 then 'ok' when overload_count > 1 then 'review' else 'missing' end as status,
    overload_count::text as result_value,
    'expected one frontend-matching overload after 047; review if extra overloads remain'
  from summary_flags

  union all
  select
    'frontend_expected_arg_count',
    'info',
    expected_frontend_arg_count::text,
    'current renderSessionPost.js and close-mark payloads include p_session_tool'
  from summary_flags

  union all
  select
    'frontend_matching_overload_count',
    case when frontend_matching_overload_count = 1 then 'ok' when frontend_matching_overload_count = 0 then 'missing' else 'review' end,
    frontend_matching_overload_count::text,
    'expected exactly one overload matching all frontend payload keys'
  from summary_flags

  union all
  select
    'frontend_matching_is_session_gm_count',
    case when frontend_matching_is_session_gm_count = 1 and frontend_matching_overload_count = 1 then 'ok' else 'review' end,
    frontend_matching_is_session_gm_count::text,
    'frontend-matching overload should use owner/admin helper'
  from summary_flags

  union all
  select
    'frontend_matching_old_gate_count',
    case when frontend_matching_old_gate_count = 0 then 'ok' else 'review' end,
    frontend_matching_old_gate_count::text,
    'nonzero means the frontend-callable overload still has the old GM-role gate'
  from summary_flags

  union all
  select
    'frontend_matching_authenticated_execute_count',
    case when frontend_matching_authenticated_execute_count = 1 and frontend_matching_overload_count = 1 then 'ok' else 'review' end,
    frontend_matching_authenticated_execute_count::text,
    'frontend-matching overload should be executable by authenticated'
  from summary_flags

  union all
  select
    'frontend_matching_anon_execute_count',
    case when frontend_matching_anon_execute_count = 0 then 'ok' else 'review' end,
    frontend_matching_anon_execute_count::text,
    'frontend-matching overload should not be executable by anon'
  from summary_flags

  union all
  select
    'old_gate_overload_count',
    case when old_gate_overload_count = 0 then 'ok' else 'review' end,
    old_gate_overload_count::text,
    'nonzero means at least one update_session_post overload still has old has_role(gm)+owner logic'
  from summary_flags

  union all
  select
    'legacy_without_session_tool_count',
    case when legacy_without_session_tool_count = 0 then 'ok' else 'review' end,
    legacy_without_session_tool_count::text,
    'legacy 13-input overload without p_session_tool should be gone after 047'
  from summary_flags

  union all
  select
    'anon_execute_overload_count',
    case when anon_execute_count = 0 then 'ok' else 'review' end,
    anon_execute_count::text,
    'no update_session_post overload should be executable by anon'
  from summary_flags

  union all
  select
    'security_definer_overload_count',
    case when security_definer_count = overload_count and overload_count > 0 then 'ok' else 'review' end,
    security_definer_count::text,
    'all remaining update overloads should remain security definer'
  from summary_flags

  union all
  select
    'search_path_overload_count',
    case when search_path_count = overload_count and overload_count > 0 then 'ok' else 'review' end,
    search_path_count::text,
    'all remaining update overloads should keep search_path set'
  from summary_flags

  union all
  select
    'frontend_call_risk',
    case when frontend_call_risk_value = 'ready_for_owner_update_qa' then 'ok' else 'review' end,
    frontend_call_risk_value,
    'review before edit-save or GM close-mark QA'
  from summary_flags

  union all
  select
    'post_apply_ready_for_owner_update_qa',
    case when post_apply_ready_for_owner_update_qa then 'ok' else 'review' end,
    post_apply_ready_for_owner_update_qa::text,
    'true means SELECT-only state is ready for general-owner edit-save and close-mark QA'
  from summary_flags
),
overload_rows as (
  select
    'overload_' || overload_ordinal::text || '_signature' as check_name,
    'info' as status,
    signature as result_value,
    'signature text only; no function body or raw IDs returned' as note
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
    case when matches_frontend_payload then 'ok' else 'review' end,
    matches_frontend_payload::text,
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
)
select
  check_name,
  status,
  result_value,
  note
from checks

union all

select
  check_name,
  status,
  result_value,
  note
from overload_rows
order by check_name;
