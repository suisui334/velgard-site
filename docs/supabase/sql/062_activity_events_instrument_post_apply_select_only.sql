-- 062_activity_events_instrument_post_apply_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Confirm player comment/application activity timeline instrumentation after a separately
--   approved 061 apply gate.
-- - Return boolean/status style results only.
-- - Do not return function bodies, real user ids, emails, tokens, full URLs,
--   project refs, notification ids, activity ids, session ids, or secrets.

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
activity_helper_rpc as (
  select
    p.oid,
    p.oid::regprocedure::text as signature,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'record_activity_event'
    and p.oid::regprocedure::text
      = 'record_activity_event(uuid,text,text,text,text,text,text,jsonb)'
),
owner_notification_helper_rpc as (
  select
    p.oid,
    p.oid::regprocedure::text as signature
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'create_session_owner_notification'
    and p.oid::regprocedure::text
      = 'create_session_owner_notification(text,uuid,text,text,text,text,jsonb)'
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
activity_helper_privileges as (
  select
    coalesce(bool_or(
      case
        when (select authenticated_role from role_refs) is null then false
        else pg_catalog.has_function_privilege(
          (select authenticated_role from role_refs),
          ahr.oid,
          'EXECUTE'
        )
      end
    ), false) as authenticated_execute,
    coalesce(bool_or(
      case
        when (select anon_role from role_refs) is null then false
        else pg_catalog.has_function_privilege(
          (select anon_role from role_refs),
          ahr.oid,
          'EXECUTE'
        )
      end
    ), false) as anon_execute
  from activity_helper_rpc ahr
),
target_summary as (
  select
    count(*) as rpc_count,
    coalesce(bool_and(security_definer), false) as all_security_definer,
    coalesce(bool_and(function_config ilike '%search_path=public%'), false) as all_search_path_public,
    coalesce(bool_or(function_def like '%create_session_owner_notification%'), false) as has_owner_notification_call,
    coalesce(bool_or(function_def like '%record_activity_event%'), false) as has_activity_helper_call,
    coalesce(bool_or(function_def like '%session_application%'), false) as has_session_application_type,
    coalesce(bool_or(function_def like '%session_comment%'), false) as has_session_comment_type,
    coalesce(bool_or(function_def like '%session-detail.html?id=%'), false) as has_relative_target_path,
    coalesce(bool_or(function_def like '%authenticated%'), false) as has_authenticated_visibility,
    coalesce(bool_or(function_def like '%A participation application was posted.%'), false) as has_generic_application_body,
    coalesce(bool_or(function_def like '%A comment was posted.%'), false) as has_generic_comment_body,
    coalesce(bool_or(function_def like '%A management comment was posted.%'), false) as has_management_activity_body,
    coalesce(bool_or(function_def like '%v_actor_id%'), false) as passes_actor_to_helpers,
    min(signature) as signature
  from target_rpc
),
activity_helper_summary as (
  select
    count(*) as helper_count,
    coalesce(bool_and(security_definer), false) as all_security_definer,
    coalesce(bool_and(function_config ilike '%search_path=public%'), false) as all_search_path_public,
    min(signature) as signature
  from activity_helper_rpc
),
owner_notification_helper_summary as (
  select
    count(*) as helper_count
  from owner_notification_helper_rpc
),
ready_summary as (
  select
    (
      ts.rpc_count = 1
      and ts.all_security_definer
      and ts.all_search_path_public
      and tp.authenticated_execute
      and not tp.anon_execute
      and ts.has_owner_notification_call
      and ts.has_activity_helper_call
      and ts.has_session_application_type
      and ts.has_session_comment_type
      and ts.has_relative_target_path
      and ts.has_authenticated_visibility
      and ts.has_generic_application_body
      and ts.has_generic_comment_body
      and not ts.has_management_activity_body
      and ts.passes_actor_to_helpers
      and ahs.helper_count = 1
      and ahs.all_security_definer
      and ahs.all_search_path_public
      and not ahp.authenticated_execute
      and not ahp.anon_execute
      and onhs.helper_count = 1
    ) as ready_for_activity_generation_qa
  from target_summary ts
  cross join target_privileges tp
  cross join activity_helper_summary ahs
  cross join activity_helper_privileges ahp
  cross join owner_notification_helper_summary onhs
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
    'Frontend payload uses target_session_id and comment_body against this two-argument RPC.'
  from target_summary

  union all
  select
    30,
    'create_application_comment_security_definer',
    case when all_security_definer then 'ok' else 'review' end,
    all_security_definer::text,
    'RPC should remain security definer.'
  from target_summary

  union all
  select
    40,
    'create_application_comment_search_path_public',
    case when all_search_path_public then 'ok' else 'review' end,
    all_search_path_public::text,
    'Security definer RPC should pin search_path=public.'
  from target_summary

  union all
  select
    50,
    'create_application_comment_authenticated_execute',
    case when authenticated_execute then 'ok' else 'review' end,
    authenticated_execute::text,
    'Logged-in users should still be able to post comments/applications.'
  from target_privileges

  union all
  select
    60,
    'create_application_comment_anon_execute',
    case when not anon_execute then 'ok' else 'review' end,
    anon_execute::text,
    'Anonymous users should not execute the post RPC.'
  from target_privileges

  union all
  select
    70,
    'create_application_comment_keeps_owner_notifications',
    case when has_owner_notification_call then 'ok' else 'review' end,
    has_owner_notification_call::text,
    'Existing private owner notification instrumentation should remain connected.'
  from target_summary

  union all
  select
    80,
    'create_application_comment_calls_activity_helper',
    case when has_activity_helper_call then 'ok' else 'review' end,
    has_activity_helper_call::text,
    'RPC should call the internal activity timeline helper.'
  from target_summary

  union all
  select
    90,
    'create_application_comment_has_application_activity_type',
    case when has_session_application_type then 'ok' else 'review' end,
    has_session_application_type::text,
    'New or reapplied participation should produce session_application activity.'
  from target_summary

  union all
  select
    100,
    'create_application_comment_has_comment_activity_type',
    case when has_session_comment_type then 'ok' else 'review' end,
    has_session_comment_type::text,
    'PL follow-up comments should produce session_comment activity.'
  from target_summary

  union all
  select
    110,
    'create_application_comment_uses_relative_target_path',
    case when has_relative_target_path then 'ok' else 'review' end,
    has_relative_target_path::text,
    'Activity targets should stay relative and not store full external URLs.'
  from target_summary

  union all
  select
    120,
    'create_application_comment_uses_authenticated_visibility',
    case when has_authenticated_visibility then 'ok' else 'review' end,
    has_authenticated_visibility::text,
    'Comment/application activity should be login-visible rather than fully public.'
  from target_summary

  union all
  select
    130,
    'create_application_comment_uses_generic_activity_body',
    case when has_generic_application_body and has_generic_comment_body then 'ok' else 'review' end,
    concat('application=', has_generic_application_body, ',comment=', has_generic_comment_body),
    'Activity should not store raw long comment/application text.'
  from target_summary

  union all
  select
    140,
    'create_application_comment_skips_management_activity',
    case when not has_management_activity_body then 'ok' else 'review' end,
    (not has_management_activity_body)::text,
    'GM/admin management comments should not write shared activity rows in this MVP.'
  from target_summary

  union all
  select
    150,
    'create_application_comment_passes_actor',
    case when passes_actor_to_helpers then 'ok' else 'review' end,
    passes_actor_to_helpers::text,
    'Helpers receive the actor so timeline rows can show who performed the action.'
  from target_summary

  union all
  select
    160,
    'record_activity_event_exists',
    case when helper_count = 1 then 'ok' else 'review' end,
    helper_count::text,
    'Internal activity helper should exist.'
  from activity_helper_summary

  union all
  select
    170,
    'record_activity_event_security_definer',
    case when all_security_definer then 'ok' else 'review' end,
    all_security_definer::text,
    'Internal activity helper should remain security definer.'
  from activity_helper_summary

  union all
  select
    180,
    'record_activity_event_search_path_public',
    case when all_search_path_public then 'ok' else 'review' end,
    all_search_path_public::text,
    'Internal activity helper should pin search_path=public.'
  from activity_helper_summary

  union all
  select
    190,
    'record_activity_event_web_client_direct_execute',
    case when not authenticated_execute and not anon_execute then 'ok' else 'review' end,
    concat('authenticated=', authenticated_execute, ',anon=', anon_execute),
    'Web clients should not be able to create arbitrary activity rows directly.'
  from activity_helper_privileges

  union all
  select
    200,
    'create_session_owner_notification_still_present',
    case when helper_count = 1 then 'ok' else 'review' end,
    helper_count::text,
    'Private owner notification helper should still be present.'
  from owner_notification_helper_summary

  union all
  select
    210,
    'session_create_activity_scope',
    'ok',
    'future',
    'create_session_post activity instrumentation is intentionally left for a separate focused gate.'

  union all
  select
    220,
    'session_update_and_status_activity_scope',
    'ok',
    'future',
    'Session edit, approval/rejection, close mark, delete, Discord, and email events remain future scope.'

  union all
  select
    230,
    'post_apply_ready_for_activity_generation_qa',
    case when ready_for_activity_generation_qa then 'ok' else 'review' end,
    ready_for_activity_generation_qa::text,
    'True means real comment/application timeline activity generation QA can proceed.'
  from ready_summary
)
select
  check_name,
  status,
  result_value,
  note
from output_rows
order by sort_order;
