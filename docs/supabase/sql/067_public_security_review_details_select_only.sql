-- 067_public_security_review_details_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Follow up the 066 pre-public security audit review rows.
-- - Identify security definer functions that need search_path review.
-- - Identify anon-executable RPCs and the two anon non-read named functions.
-- - Detail comment/application anti-spam guard gaps.
-- - Clarify whether the TIMELINE management-comment warning from 066 is a
--   static-pattern false positive or a real remaining path.
--
-- Safety:
-- - Return function names, signatures, counts, booleans, and status notes only.
-- - Do not return function bodies, row contents, concrete user ids, emails,
--   session ids, activity ids, notification ids, full URLs, project refs,
--   tokens, keys, or secrets.

with role_refs as (
  select
    to_regrole('anon') as anon_role,
    to_regrole('authenticated') as authenticated_role
),
routine_rows as (
  select
    n.nspname as schema_name,
    p.oid,
    p.proname,
    p.oid::regprocedure::text as signature,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config,
    pg_catalog.pg_get_function_result(p.oid) as result_type,
    pg_catalog.pg_get_functiondef(p.oid) as function_def
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prokind = 'f'
),
routine_privileges as (
  select
    rr.*,
    coalesce(
      case
        when (select anon_role from role_refs) is null then false
        else pg_catalog.has_function_privilege((select anon_role from role_refs), rr.oid, 'EXECUTE')
      end,
      false
    ) as anon_execute,
    coalesce(
      case
        when (select authenticated_role from role_refs) is null then false
        else pg_catalog.has_function_privilege((select authenticated_role from role_refs), rr.oid, 'EXECUTE')
      end,
      false
    ) as authenticated_execute
  from routine_rows rr
),
function_flags as (
  select
    rp.*,
    rp.function_config ilike '%search_path=%' as has_any_search_path,
    rp.function_config ilike '%search_path=public%' as has_public_search_path,
    (
      lower(coalesce(rp.result_type, '')) = 'trigger'
      or rp.proname ilike '%trigger%'
      or rp.function_def ilike '%returns trigger%'
    ) as is_trigger_like,
    rp.proname ~ '^(get_|is_|list_|search_)' as is_read_named,
    (
      rp.proname in (
        'create_session_owner_notification',
        'record_activity_event'
      )
      or rp.proname ilike '%helper%'
    ) as is_internal_helper_named
  from routine_privileges rp
),
security_definer_summary as (
  select
    count(*) filter (where security_definer) as security_definer_count,
    count(*) filter (where security_definer and not has_any_search_path) as missing_any_search_path_count,
    count(*) filter (where security_definer and not has_public_search_path) as not_public_search_path_count,
    count(*) filter (where security_definer and not has_public_search_path and (anon_execute or authenticated_execute)) as web_executable_not_public_count,
    count(*) filter (where security_definer and not has_public_search_path and is_trigger_like) as trigger_like_not_public_count
  from function_flags
),
security_definer_detail_rows as (
  select
    1000 + row_number() over (order by signature) as sort_order,
    'security_definer_search_path_detail_' || lpad((row_number() over (order by signature))::text, 3, '0') as check_name,
    'review'::text as status,
    signature as result_value,
    concat(
      'schema=', schema_name,
      ',has_any_search_path=', has_any_search_path,
      ',search_path_public=', has_public_search_path,
      ',trigger_like=', is_trigger_like,
      ',anon_execute=', anon_execute,
      ',authenticated_execute=', authenticated_execute,
      ',priority=',
      case
        when anon_execute then 'P0_anon_executable'
        when authenticated_execute then 'P1_authenticated_executable'
        when is_trigger_like then 'P1_trigger_or_internal_review'
        else 'P1_internal_review'
      end
    ) as note
  from function_flags
  where security_definer
    and not has_public_search_path
),
anon_rpc_summary as (
  select
    count(*) filter (where anon_execute) as anon_executable_count,
    count(*) filter (where anon_execute and not is_read_named) as anon_non_read_named_count,
    count(*) filter (where anon_execute and is_internal_helper_named) as anon_internal_helper_count,
    count(*) filter (where anon_execute and security_definer and not has_public_search_path) as anon_security_definer_not_public_count
  from function_flags
),
anon_rpc_detail_rows as (
  select
    2000 + row_number() over (order by signature) as sort_order,
    'anon_executable_rpc_detail_' || lpad((row_number() over (order by signature))::text, 3, '0') as check_name,
    case
      when is_internal_helper_named then 'review'
      when not is_read_named then 'review'
      when security_definer and not has_public_search_path then 'review'
      else 'ok'
    end as status,
    signature as result_value,
    concat(
      'schema=', schema_name,
      ',read_named=', is_read_named,
      ',non_read_named=', (not is_read_named),
      ',internal_helper_named=', is_internal_helper_named,
      ',security_definer=', security_definer,
      ',search_path_public=', has_public_search_path,
      ',authenticated_execute=', authenticated_execute,
      ',priority=',
      case
        when is_internal_helper_named then 'P0_revoke_helper'
        when not is_read_named then 'P0_or_P1_manual_review'
        when security_definer and not has_public_search_path then 'P1_search_path_review'
        else 'documented_public_read'
      end
    ) as note
  from function_flags
  where anon_execute
),
comment_rpc as (
  select
    count(*) as rpc_count,
    coalesce(bool_or(security_definer), false) as security_definer,
    coalesce(bool_or(has_public_search_path), false) as search_path_public,
    coalesce(bool_or(authenticated_execute), false) as authenticated_execute,
    coalesce(bool_or(anon_execute), false) as anon_execute,
    coalesce(bool_or(function_def ilike '%char_length(%' or function_def ilike '%length(%'), false) as has_length_guard_pattern,
    coalesce(bool_or(
      function_def ~* 'cooldown|rate[ _-]?limit'
      or (function_def ilike '%created_at%' and function_def ilike '%interval%')
    ), false) as has_cooldown_pattern,
    coalesce(bool_or(function_def ~* 'https?://|url|regexp_count|regexp_matches'), false) as has_url_guard_pattern,
    coalesce(bool_or(function_def like '%create_session_owner_notification%'), false) as has_owner_notification_call,
    coalesce(bool_or(function_def like '%insert into public.activity_events%'), false) as has_activity_insert,
    coalesce(bool_or(function_def like '%session_application%'), false) as has_application_activity_type,
    coalesce(bool_or(function_def like '%session_comment%'), false) as has_comment_activity_type,
    coalesce(bool_or(function_def like '%A participation application was posted.%'), false) as has_generic_application_body,
    coalesce(bool_or(function_def like '%A comment was posted.%'), false) as has_generic_comment_body,
    coalesce(bool_or(function_def like '%v_is_management_comment%'), false) as has_management_branch,
    coalesce(bool_or(function_def like '%Shared timeline intentionally excludes GM/admin management comments.%'), false) as has_management_skip_note,
    coalesce(bool_or(function_def like '%A management comment was posted.%'), false) as has_management_activity_body,
    coalesce(bool_or(function_def like '%return v_new_comment_id;%'), false) as has_early_return_pattern,
    coalesce(bool_or(function_def like '%session-detail.html?id=%'), false) as has_relative_target_path
  from function_flags
  where signature = 'create_application_comment(text,text)'
),
activity_event_counts as (
  select
    count(*) as activity_total_count,
    count(*) filter (where visibility = 'authenticated') as authenticated_count,
    count(*) filter (where visibility = 'public') as public_count,
    count(*) filter (where visibility = 'private') as private_count,
    count(*) filter (
      where event_type in ('session_comment', 'session_application')
        and visibility = 'authenticated'
    ) as authenticated_pl_count,
    count(*) filter (
      where title ilike '%management%'
         or body ilike '%management%'
         or metadata::text ilike '%management_comment%'
         or metadata::text ilike '%admin%'
    ) as management_like_count
  from public.activity_events
),
output_rows as (
  select
    10 as sort_order,
    '066_review_result_recorded'::text as check_name,
    'info'::text as status,
    'manual_066_summary_recorded'::text as result_value,
    '066 found no direct table write grants and no helper direct execute, but search_path, anon RPC exposure, spam guards, and TIMELINE static patterns need review.'::text as note

  union all
  select
    20,
    'security_definer_search_path_summary',
    case when not_public_search_path_count = 0 then 'ok' else 'review' end,
    concat(
      'security_definer=', security_definer_count,
      ',missing_any_search_path=', missing_any_search_path_count,
      ',not_search_path_public=', not_public_search_path_count,
      ',web_executable_not_public=', web_executable_not_public_count,
      ',trigger_like_not_public=', trigger_like_not_public_count
    ),
    'Review detail rows below. Public web-executable rows are highest priority; trigger/internal rows still need planned cleanup.'
  from security_definer_summary

  union all
  select
    30,
    'anon_rpc_exposure_summary',
    case when anon_non_read_named_count = 0 and anon_internal_helper_count = 0 and anon_security_definer_not_public_count = 0 then 'ok' else 'review' end,
    concat(
      'anon_executable=', anon_executable_count,
      ',anon_non_read_named=', anon_non_read_named_count,
      ',anon_internal_helper=', anon_internal_helper_count,
      ',anon_security_definer_not_public=', anon_security_definer_not_public_count
    ),
    'Review anon executable detail rows below. Non-read named anon RPCs are P0/P1 manual-review candidates.'
  from anon_rpc_summary

  union all
  select
    40,
    'create_application_comment_spam_guard_summary',
    case when has_length_guard_pattern and has_cooldown_pattern and has_url_guard_pattern then 'ok' else 'review' end,
    concat(
      'rpc=', rpc_count,
      ',length=', has_length_guard_pattern,
      ',cooldown=', has_cooldown_pattern,
      ',url=', has_url_guard_pattern
    ),
    'Length guard exists in 066 result; cooldown and URL-count guards should become P1 apply-draft candidates if false.'
  from comment_rpc

  union all
  select
    50,
    'create_application_comment_security_and_execute',
    case when rpc_count = 1 and security_definer and search_path_public and authenticated_execute and not anon_execute then 'ok' else 'review' end,
    concat(
      'rpc=', rpc_count,
      ',security_definer=', security_definer,
      ',search_path_public=', search_path_public,
      ',authenticated=', authenticated_execute,
      ',anon=', anon_execute
    ),
    'Comment/application posting should stay authenticated-only and pinned to search_path=public.'
  from comment_rpc

  union all
  select
    60,
    'timeline_management_activity_static_detail',
    case
      when has_management_branch
       and has_management_skip_note
       and not has_management_activity_body
       and has_activity_insert
      then 'ok'
      else 'review'
    end,
    concat(
      'management_branch=', has_management_branch,
      ',skip_note=', has_management_skip_note,
      ',management_activity_body=', has_management_activity_body,
      ',activity_insert=', has_activity_insert,
      ',early_return_pattern=', has_early_return_pattern
    ),
    'If ok, the 066 management_skip=false row was likely an exact-string false positive. If review, inspect before public expansion.'
  from comment_rpc

  union all
  select
    70,
    'timeline_activity_generation_shape',
    case
      when has_activity_insert
       and has_application_activity_type
       and has_comment_activity_type
       and has_generic_application_body
       and has_generic_comment_body
       and has_relative_target_path
      then 'ok'
      else 'review'
    end,
    concat(
      'insert=', has_activity_insert,
      ',application=', has_application_activity_type,
      ',comment=', has_comment_activity_type,
      ',generic_application=', has_generic_application_body,
      ',generic_comment=', has_generic_comment_body,
      ',relative_target=', has_relative_target_path
    ),
    'Timeline events should be generic and use relative target paths.'
  from comment_rpc

  union all
  select
    80,
    'activity_events_visibility_counts',
    'info',
    concat(
      'total=', activity_total_count,
      ',public=', public_count,
      ',authenticated=', authenticated_count,
      ',private=', private_count,
      ',authenticated_pl=', authenticated_pl_count
    ),
    'Counts only; no row content or identifiers are returned.'
  from activity_event_counts

  union all
  select
    90,
    'activity_events_management_like_count',
    case when management_like_count = 0 then 'ok' else 'review' end,
    management_like_count::text,
    'Count-only heuristic for management/admin-like activity metadata/title/body. Nonzero requires manual review without exposing row contents.'
  from activity_event_counts

  union all
  select
    100,
    'auth_mail_abuse_dashboard_gate',
    'review',
    'dashboard_manual_review_required',
    'CAPTCHA, Auth rate limits, signup/reset abuse controls, and Resend bounce/suppression are not fully verifiable by SQL.'
)
select
  check_name,
  status,
  result_value,
  note
from (
  select sort_order, check_name, status, result_value, note from output_rows
  union all
  select sort_order, check_name, status, result_value, note from security_definer_detail_rows
  union all
  select sort_order, check_name, status, result_value, note from anon_rpc_detail_rows
) combined_rows
order by sort_order, check_name;
