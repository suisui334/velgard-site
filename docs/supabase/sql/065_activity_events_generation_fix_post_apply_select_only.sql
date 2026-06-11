-- 065_activity_events_generation_fix_post_apply_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Confirm the separately approved 064 activity generation fix.
-- - Confirm public.create_application_comment(text,text) writes PL comment/application
--   activity rows through the concrete activity_events path.
-- - Return boolean/status style results only.
-- - Do not return function bodies, row ids, user ids, session ids, emails, tokens,
--   full URLs, project refs, notification ids, activity ids, or secrets.

with role_refs as (
  select
    to_regrole('anon') as anon_role,
    to_regrole('authenticated') as authenticated_role
),
target_rpc as (
  select
    p.oid,
    p.oid::regprocedure::text as signature,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config,
    pg_catalog.pg_get_functiondef(p.oid) as function_def
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'create_application_comment'
    and p.oid::regprocedure::text = 'create_application_comment(text,text)'
),
target_privileges as (
  select
    coalesce(bool_or(
      case
        when (select authenticated_role from role_refs) is null then false
        else pg_catalog.has_function_privilege(
          (select authenticated_role from role_refs),
          tr.oid,
          'EXECUTE'
        )
      end
    ), false) as authenticated_execute,
    coalesce(bool_or(
      case
        when (select anon_role from role_refs) is null then false
        else pg_catalog.has_function_privilege(
          (select anon_role from role_refs),
          tr.oid,
          'EXECUTE'
        )
      end
    ), false) as anon_execute
  from target_rpc tr
),
target_summary as (
  select
    count(*) as rpc_count,
    min(signature) as signature,
    coalesce(bool_and(security_definer), false) as all_security_definer,
    coalesce(bool_and(function_config ilike '%search_path=public%'), false) as all_search_path_public,
    coalesce(bool_or(function_def like '%create_session_owner_notification%'), false) as has_owner_notification_call,
    coalesce(bool_or(function_def like '%public.activity_events%'), false) as has_activity_table_path,
    coalesce(bool_or(function_def like '%v_activity_event_id%'), false) as has_activity_event_id_guard,
    coalesce(bool_or(function_def like '%activity event was not created%'), false) as has_activity_failure_guard,
    coalesce(bool_or(function_def like '%session_application%'), false) as has_session_application_type,
    coalesce(bool_or(function_def like '%session_comment%'), false) as has_session_comment_type,
    coalesce(bool_or(function_def like '%session-detail.html?id=%'), false) as has_relative_target_path,
    coalesce(bool_or(function_def like '%''authenticated''%'), false) as has_authenticated_visibility,
    coalesce(bool_or(function_def like '%A participation application was posted.%'), false) as has_generic_application_body,
    coalesce(bool_or(function_def like '%A comment was posted.%'), false) as has_generic_comment_body,
    coalesce(bool_or(function_def like '%A management comment was posted.%'), false) as has_management_activity_body,
    coalesce(bool_or(function_def like '%Shared timeline intentionally excludes GM/admin management comments.%'), false) as documents_management_skip,
    coalesce(bool_or(function_def like '%record_activity_event%'), false) as still_calls_activity_helper
  from target_rpc
),
activity_counts as (
  select
    count(*) as total_count,
    count(*) filter (
      where event_type in ('session_comment', 'session_application')
        and visibility = 'authenticated'
    ) as authenticated_pl_event_count,
    count(*) filter (
      where event_type = 'session_comment'
        and visibility = 'authenticated'
    ) as authenticated_comment_count,
    count(*) filter (
      where event_type = 'session_application'
        and visibility = 'authenticated'
    ) as authenticated_application_count,
    count(*) filter (
      where event_type in ('session_comment', 'session_application')
        and target_path like 'session-detail.html?id=%'
        and target_path !~* '^[a-z][a-z0-9+.-]*://'
        and position('..' in target_path) = 0
    ) as renderable_target_count,
    count(*) filter (
      where event_type in ('session_comment', 'session_application')
        and body in ('A participation application was posted.', 'A comment was posted.')
    ) as generic_body_count
  from public.activity_events
),
ready_summary as (
  select
    (
      ts.rpc_count = 1
      and ts.signature = 'create_application_comment(text,text)'
      and ts.all_security_definer
      and ts.all_search_path_public
      and tp.authenticated_execute
      and not tp.anon_execute
      and ts.has_owner_notification_call
      and ts.has_activity_table_path
      and ts.has_activity_event_id_guard
      and ts.has_activity_failure_guard
      and ts.has_session_application_type
      and ts.has_session_comment_type
      and ts.has_relative_target_path
      and ts.has_authenticated_visibility
      and ts.has_generic_application_body
      and ts.has_generic_comment_body
      and not ts.has_management_activity_body
      and ts.documents_management_skip
    ) as ready_for_activity_generation_qa
  from target_summary ts
  cross join target_privileges tp
),
output_rows as (
  select
    10 as sort_order,
    'create_application_comment_exists'::text as check_name,
    case when rpc_count = 1 then 'ok' else 'review' end as status,
    rpc_count::text as result_value,
    'Expected exactly one public.create_application_comment(text,text) function.'::text as note
  from target_summary

  union all
  select
    20,
    'create_application_comment_signature',
    case when signature = 'create_application_comment(text,text)' then 'ok' else 'review' end,
    coalesce(signature, 'missing'),
    'Frontend payload still targets the two-argument comment/application RPC.'
  from target_summary

  union all
  select
    30,
    'create_application_comment_security',
    case when all_security_definer and all_search_path_public then 'ok' else 'review' end,
    concat('security_definer=', all_security_definer, ',search_path_public=', all_search_path_public),
    'RPC should remain security definer with search_path=public.'
  from target_summary

  union all
  select
    40,
    'create_application_comment_execute_privileges',
    case when authenticated_execute and not anon_execute then 'ok' else 'review' end,
    concat('authenticated=', authenticated_execute, ',anon=', anon_execute),
    'Logged-in users can post; anonymous users cannot.'
  from target_privileges

  union all
  select
    50,
    'create_application_comment_keeps_owner_notifications',
    case when has_owner_notification_call then 'ok' else 'review' end,
    has_owner_notification_call::text,
    'Private owner notification instrumentation should remain connected.'
  from target_summary

  union all
  select
    60,
    'create_application_comment_activity_table_path',
    case when has_activity_table_path then 'ok' else 'review' end,
    has_activity_table_path::text,
    'PL branch should use the concrete activity_events path after the 064 fix.'
  from target_summary

  union all
  select
    70,
    'create_application_comment_activity_completion_guard',
    case when has_activity_event_id_guard and has_activity_failure_guard then 'ok' else 'review' end,
    concat('event_id_guard=', has_activity_event_id_guard, ',failure_guard=', has_activity_failure_guard),
    'RPC should verify that an activity row was produced before returning success.'
  from target_summary

  union all
  select
    80,
    'create_application_comment_activity_types',
    case when has_session_application_type and has_session_comment_type then 'ok' else 'review' end,
    concat('application=', has_session_application_type, ',comment=', has_session_comment_type),
    'PL applications and PL comments should both have activity paths.'
  from target_summary

  union all
  select
    90,
    'create_application_comment_relative_target_path',
    case when has_relative_target_path then 'ok' else 'review' end,
    has_relative_target_path::text,
    'Activity targets should remain relative in-site paths.'
  from target_summary

  union all
  select
    100,
    'create_application_comment_authenticated_visibility',
    case when has_authenticated_visibility then 'ok' else 'review' end,
    has_authenticated_visibility::text,
    'PL comment/application activity should remain login-visible.'
  from target_summary

  union all
  select
    110,
    'create_application_comment_generic_activity_body',
    case when has_generic_application_body and has_generic_comment_body then 'ok' else 'review' end,
    concat('application=', has_generic_application_body, ',comment=', has_generic_comment_body),
    'Activity body should stay generic and avoid raw comment/application text.'
  from target_summary

  union all
  select
    120,
    'create_application_comment_management_activity_skip',
    case when not has_management_activity_body and documents_management_skip then 'ok' else 'review' end,
    concat('management_body_absent=', (not has_management_activity_body), ',skip_note=', documents_management_skip),
    'GM/admin management comments should not create shared timeline activity in this MVP.'
  from target_summary

  union all
  select
    130,
    'create_application_comment_helper_dependency_removed',
    case when not still_calls_activity_helper then 'ok' else 'review' end,
    (not still_calls_activity_helper)::text,
    'The 064 fix should no longer depend on the internal activity helper for this RPC.'
  from target_summary

  union all
  select
    140,
    'activity_events_total_count',
    case when total_count > 0 then 'ok' else 'review' end,
    total_count::text,
    'After a real PL comment/application QA, this should be greater than zero.'
  from activity_counts

  union all
  select
    150,
    'activity_events_authenticated_pl_count',
    case when authenticated_pl_event_count > 0 then 'ok' else 'review' end,
    authenticated_pl_event_count::text,
    'Confirms real PL comment/application events exist with authenticated visibility.'
  from activity_counts

  union all
  select
    160,
    'activity_events_type_counts',
    'info',
    concat('comment=', authenticated_comment_count, ',application=', authenticated_application_count),
    'Counts only; no row content or identifiers are returned.'
  from activity_counts

  union all
  select
    170,
    'activity_events_renderable_target_count',
    case when renderable_target_count > 0 then 'ok' else 'review' end,
    renderable_target_count::text,
    'Timeline cards need safe relative session-detail target paths.'
  from activity_counts

  union all
  select
    180,
    'activity_events_generic_body_count',
    case when generic_body_count > 0 then 'ok' else 'review' end,
    generic_body_count::text,
    'Activity rows should use generic text rather than raw long comment text.'
  from activity_counts

  union all
  select
    190,
    'post_apply_ready_for_activity_generation_qa',
    case when ready_for_activity_generation_qa then 'ok' else 'review' end,
    ready_for_activity_generation_qa::text,
    'True means real PL comment/application activity generation QA can proceed.'
  from ready_summary
)
select
  check_name,
  status,
  result_value,
  note
from output_rows
order by sort_order;
