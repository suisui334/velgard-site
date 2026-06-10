-- 060_notifications_instrument_post_apply_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Confirm comment/application notification instrumentation after a separately
--   approved 059 apply gate.
-- - Return boolean/status style results only.
-- - Do not return function bodies, real user ids, emails, tokens, full URLs,
--   project refs, notification ids, session ids, or secrets.

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
helper_rpc as (
  select
    p.oid,
    p.oid::regprocedure::text as signature,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config
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
helper_privileges as (
  select
    coalesce(bool_or(
      case
        when (select authenticated_role from role_refs) is null then false
        else pg_catalog.has_function_privilege(
          (select authenticated_role from role_refs),
          hr.oid,
          'EXECUTE'
        )
      end
    ), false) as authenticated_execute,
    coalesce(bool_or(
      case
        when (select anon_role from role_refs) is null then false
        else pg_catalog.has_function_privilege(
          (select anon_role from role_refs),
          hr.oid,
          'EXECUTE'
        )
      end
    ), false) as anon_execute
  from helper_rpc hr
),
target_summary as (
  select
    count(*) as rpc_count,
    coalesce(bool_and(security_definer), false) as all_security_definer,
    coalesce(bool_and(function_config ilike '%search_path=public%'), false) as all_search_path_public,
    coalesce(bool_or(function_def like '%create_session_owner_notification%'), false) as has_owner_notification_call,
    coalesce(bool_or(function_def like '%session_application%'), false) as has_session_application_type,
    coalesce(bool_or(function_def like '%session_comment%'), false) as has_session_comment_type,
    coalesce(bool_or(function_def like '%session-detail.html?id=%'), false) as has_relative_target_path,
    coalesce(bool_or(function_def like '%jsonb_build_object%'), false) as has_metadata_object,
    coalesce(bool_or(function_def like '%v_actor_id%'), false) as passes_actor_to_helper,
    min(signature) as signature
  from target_rpc
),
helper_summary as (
  select
    count(*) as helper_count,
    coalesce(bool_and(security_definer), false) as all_security_definer,
    coalesce(bool_and(function_config ilike '%search_path=public%'), false) as all_search_path_public,
    min(signature) as signature
  from helper_rpc
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
      and ts.has_session_application_type
      and ts.has_session_comment_type
      and ts.has_relative_target_path
      and ts.passes_actor_to_helper
      and hs.helper_count = 1
      and hs.all_security_definer
      and hs.all_search_path_public
      and not hp.authenticated_execute
      and not hp.anon_execute
    ) as ready_for_notification_generation_qa
  from target_summary ts
  cross join target_privileges tp
  cross join helper_summary hs
  cross join helper_privileges hp
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
    'create_application_comment_calls_owner_notification_helper',
    case when has_owner_notification_call then 'ok' else 'review' end,
    has_owner_notification_call::text,
    'RPC should call the internal owner notification helper.'
  from target_summary

  union all
  select
    80,
    'create_application_comment_has_application_notification_type',
    case when has_session_application_type then 'ok' else 'review' end,
    has_session_application_type::text,
    'New or reapplied participation should use session_application notification type.'
  from target_summary

  union all
  select
    90,
    'create_application_comment_has_comment_notification_type',
    case when has_session_comment_type then 'ok' else 'review' end,
    has_session_comment_type::text,
    'Follow-up comments should use session_comment notification type.'
  from target_summary

  union all
  select
    100,
    'create_application_comment_uses_relative_target_path',
    case when has_relative_target_path then 'ok' else 'review' end,
    has_relative_target_path::text,
    'Notification targets should stay relative and not store full external URLs.'
  from target_summary

  union all
  select
    110,
    'create_application_comment_passes_actor',
    case when passes_actor_to_helper then 'ok' else 'review' end,
    passes_actor_to_helper::text,
    'Helper receives the actor so it can skip self-notifications.'
  from target_summary

  union all
  select
    120,
    'create_session_owner_notification_exists',
    case when helper_count = 1 then 'ok' else 'review' end,
    helper_count::text,
    'Internal owner notification helper should exist.'
  from helper_summary

  union all
  select
    130,
    'create_session_owner_notification_security_definer',
    case when all_security_definer then 'ok' else 'review' end,
    all_security_definer::text,
    'Internal helper should remain security definer.'
  from helper_summary

  union all
  select
    140,
    'create_session_owner_notification_search_path_public',
    case when all_search_path_public then 'ok' else 'review' end,
    all_search_path_public::text,
    'Internal helper should pin search_path=public.'
  from helper_summary

  union all
  select
    150,
    'create_session_owner_notification_web_client_direct_execute',
    case when not authenticated_execute and not anon_execute then 'ok' else 'review' end,
    concat('authenticated=', authenticated_execute, ',anon=', anon_execute),
    'Web clients should not be able to call the arbitrary-recipient helper directly.'
  from helper_privileges

  union all
  select
    160,
    'application_status_notifications_scope',
    'ok',
    'future',
    'PL-facing approval/rejection notifications are intentionally left for a later gate.'

  union all
  select
    170,
    'post_apply_ready_for_notification_generation_qa',
    case when ready_for_notification_generation_qa then 'ok' else 'review' end,
    ready_for_notification_generation_qa::text,
    'True means real comment/application notification generation QA can proceed.'
  from ready_summary
)
select
  check_name,
  status,
  result_value,
  note
from output_rows
order by sort_order;
