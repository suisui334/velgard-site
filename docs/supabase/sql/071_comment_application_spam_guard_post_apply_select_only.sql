-- 071_comment_application_spam_guard_post_apply_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Confirm the separately approved 070 comment/application spam guard.
-- - Confirm public.create_application_comment(text,text) keeps its existing
--   contract while adding URL-count and PL-side cooldown guards.
-- - Return boolean/status style results only.
-- - Do not return function bodies, row ids, user ids, session ids, emails,
--   full URLs, project refs, notification ids, activity ids, tokens, keys, or
--   secrets.

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
session_comment_columns as (
  select
    count(*) filter (where column_name = 'session_id') as has_session_id_col,
    count(*) filter (where column_name = 'user_id') as has_user_id_col,
    count(*) filter (where column_name = 'created_at') as has_created_at_col,
    count(*) filter (where column_name = 'deleted_at') as has_deleted_at_col
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'session_comments'
),
target_summary as (
  select
    count(*) as rpc_count,
    min(signature) as signature,
    coalesce(bool_and(security_definer), false) as all_security_definer,
    coalesce(bool_and(function_config ilike '%search_path=public%'), false) as all_search_path_public,
    coalesce(bool_or(function_def like '%length(v_comment_body) > 4000%'), false) as has_length_guard,
    coalesce(bool_or(function_def like '%v_url_match_count%'), false) as has_url_count_variable,
    coalesce(bool_or(function_def like '%from regexp_matches(v_comment_body%'), false) as has_url_regex_guard,
    coalesce(bool_or(function_def like '%if v_url_match_count > 2 then%'), false) as has_url_threshold_guard,
    coalesce(bool_or(function_def like '%raise exception%' and function_def like '%URL%' and function_def like '%2%'), false) as has_url_error_message,
    coalesce(bool_or(function_def like '%v_recent_comment_exists%'), false) as has_cooldown_variable,
    coalesce(bool_or(function_def like '%sc.session_id = v_target_session_id%'), false) as cooldown_checks_same_session,
    coalesce(bool_or(function_def like '%sc.user_id = v_actor_id%'), false) as cooldown_checks_same_user,
    coalesce(bool_or(function_def like '%sc.deleted_at is null%'), false) as cooldown_ignores_deleted_comments,
    coalesce(bool_or(function_def like '%sc.created_at >= now() - interval ''60 seconds''%'), false) as cooldown_checks_sixty_seconds,
    coalesce(bool_or(function_def like '%raise exception%' and function_def like '%v_recent_comment_exists%' and function_def like '%60 seconds%'), false) as has_cooldown_error_message,
    coalesce(bool_or(function_def like '%if not v_is_management_comment then%' and function_def like '%v_recent_comment_exists%'), false) as cooldown_scoped_to_pl_branch,
    coalesce(bool_or(function_def like '%create_session_owner_notification%'), false) as has_owner_notification_call,
    coalesce(bool_or(function_def like '%insert into public.activity_events%'), false) as has_activity_insert,
    coalesce(bool_or(function_def like '%v_activity_event_id%'), false) as has_activity_completion_guard,
    coalesce(bool_or(function_def like '%session_application%'), false) as has_session_application_type,
    coalesce(bool_or(function_def like '%session_comment%'), false) as has_session_comment_type,
    coalesce(bool_or(function_def like '%A participation application was posted.%'), false) as has_generic_application_body,
    coalesce(bool_or(function_def like '%A comment was posted.%'), false) as has_generic_comment_body,
    coalesce(bool_or(function_def like '%Shared timeline intentionally excludes GM/admin management comments.%'), false) as documents_management_skip,
    coalesce(bool_or(function_def like '%A management comment was posted.%'), false) as has_management_activity_body,
    coalesce(bool_or(function_def like '%selected_character_id%'), false) as keeps_pc_snapshot_character,
    coalesce(bool_or(function_def like '%pc_name_snapshot%'), false) as keeps_pc_snapshot_name,
    coalesce(bool_or(function_def like '%session-detail.html?id=%'), false) as has_relative_target_path,
    coalesce(bool_or(function_def like '%''authenticated''%'), false) as has_authenticated_visibility
  from target_rpc
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
      and ts.has_length_guard
      and ts.has_url_count_variable
      and ts.has_url_regex_guard
      and ts.has_url_threshold_guard
      and ts.has_url_error_message
      and ts.has_cooldown_variable
      and ts.cooldown_checks_same_session
      and ts.cooldown_checks_same_user
      and ts.cooldown_ignores_deleted_comments
      and ts.cooldown_checks_sixty_seconds
      and ts.has_cooldown_error_message
      and ts.cooldown_scoped_to_pl_branch
      and ts.has_owner_notification_call
      and ts.has_activity_insert
      and ts.has_activity_completion_guard
      and ts.has_session_application_type
      and ts.has_session_comment_type
      and ts.has_generic_application_body
      and ts.has_generic_comment_body
      and ts.documents_management_skip
      and not ts.has_management_activity_body
      and ts.keeps_pc_snapshot_character
      and ts.keeps_pc_snapshot_name
      and ts.has_relative_target_path
      and ts.has_authenticated_visibility
      and scc.has_session_id_col = 1
      and scc.has_user_id_col = 1
      and scc.has_created_at_col = 1
      and scc.has_deleted_at_col = 1
    ) as ready_for_spam_guard_qa
  from target_summary ts
  cross join target_privileges tp
  cross join session_comment_columns scc
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
    'Frontend payload should remain the two-argument comment/application RPC.'
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
    'session_comments_cooldown_columns',
    case
      when has_session_id_col = 1
       and has_user_id_col = 1
       and has_created_at_col = 1
       and has_deleted_at_col = 1
      then 'ok'
      else 'review'
    end,
    concat(
      'session_id=', has_session_id_col,
      ',user_id=', has_user_id_col,
      ',created_at=', has_created_at_col,
      ',deleted_at=', has_deleted_at_col
    ),
    'Cooldown relies on existing non-secret session_comments columns.'
  from session_comment_columns

  union all
  select
    60,
    'create_application_comment_length_guard',
    case when has_length_guard then 'ok' else 'review' end,
    has_length_guard::text,
    'Existing maximum body length guard should remain.'
  from target_summary

  union all
  select
    70,
    'create_application_comment_url_count_guard',
    case
      when has_url_count_variable
       and has_url_regex_guard
       and has_url_threshold_guard
       and has_url_error_message
      then 'ok'
      else 'review'
    end,
    concat(
      'counter=', has_url_count_variable,
      ',regex=', has_url_regex_guard,
      ',threshold=', has_url_threshold_guard,
      ',message=', has_url_error_message
    ),
    'URL-like tokens should be counted and rejected above two matches.'
  from target_summary

  union all
  select
    80,
    'create_application_comment_cooldown_guard',
    case
      when has_cooldown_variable
       and cooldown_checks_same_session
       and cooldown_checks_same_user
       and cooldown_ignores_deleted_comments
       and cooldown_checks_sixty_seconds
       and has_cooldown_error_message
      then 'ok'
      else 'review'
    end,
    concat(
      'flag=', has_cooldown_variable,
      ',session=', cooldown_checks_same_session,
      ',user=', cooldown_checks_same_user,
      ',not_deleted=', cooldown_ignores_deleted_comments,
      ',seconds60=', cooldown_checks_sixty_seconds,
      ',message=', has_cooldown_error_message
    ),
    'Same user and same session should be blocked for 60 seconds after a PL post.'
  from target_summary

  union all
  select
    90,
    'create_application_comment_cooldown_scope',
    case when cooldown_scoped_to_pl_branch and documents_management_skip then 'ok' else 'review' end,
    concat('pl_branch=', cooldown_scoped_to_pl_branch, ',management_skip=', documents_management_skip),
    'Cooldown should protect PL comment/application posting without changing shared timeline management-comment skip.'
  from target_summary

  union all
  select
    100,
    'create_application_comment_keeps_owner_notifications',
    case when has_owner_notification_call then 'ok' else 'review' end,
    has_owner_notification_call::text,
    'Private owner notification instrumentation should remain connected.'
  from target_summary

  union all
  select
    110,
    'create_application_comment_keeps_activity_generation',
    case
      when has_activity_insert
       and has_activity_completion_guard
       and has_session_application_type
       and has_session_comment_type
       and has_generic_application_body
       and has_generic_comment_body
       and has_relative_target_path
       and has_authenticated_visibility
      then 'ok'
      else 'review'
    end,
    concat(
      'activity=', has_activity_insert,
      ',guard=', has_activity_completion_guard,
      ',application=', has_session_application_type,
      ',comment=', has_session_comment_type,
      ',generic_application=', has_generic_application_body,
      ',generic_comment=', has_generic_comment_body,
      ',target=', has_relative_target_path,
      ',visibility=', has_authenticated_visibility
    ),
    'PL comment/application activity should stay generic, login-visible, and linkable.'
  from target_summary

  union all
  select
    120,
    'create_application_comment_management_activity_skip',
    case when documents_management_skip and not has_management_activity_body then 'ok' else 'review' end,
    concat('skip_note=', documents_management_skip, ',management_activity_body_absent=', (not has_management_activity_body)),
    'GM/admin management comments should remain excluded from shared TIMELINE activity.'
  from target_summary

  union all
  select
    130,
    'create_application_comment_keeps_pc_snapshot',
    case when keeps_pc_snapshot_character and keeps_pc_snapshot_name then 'ok' else 'review' end,
    concat('selected_character_id=', keeps_pc_snapshot_character, ',pc_name_snapshot=', keeps_pc_snapshot_name),
    'Application-time PC snapshot behavior should remain intact.'
  from target_summary

  union all
  select
    900,
    'post_apply_ready_for_comment_spam_guard_qa',
    case when ready_for_spam_guard_qa then 'ok' else 'review' end,
    ready_for_spam_guard_qa::text,
    'If true, proceed to a separate real comment/application spam-guard QA gate.'
  from ready_summary
)
select
  check_name,
  status,
  result_value,
  note
from output_rows
order by sort_order;
