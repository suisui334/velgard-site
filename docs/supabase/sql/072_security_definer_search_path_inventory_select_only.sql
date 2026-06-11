-- 072_security_definer_search_path_inventory_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Inventory public security definer functions before any search_path cleanup.
-- - Classify functions that do not report search_path=public by exposure and
--   likely operational risk.
-- - Provide enough detail to choose a later apply-draft scope without returning
--   function bodies or row data.
--
-- Safety:
-- - SELECT-only.
-- - Do not return function bodies, row contents, concrete user ids, emails,
--   session ids, activity ids, notification ids, full URLs, project refs,
--   tokens, keys, or secrets.

with role_refs as (
  select
    to_regrole('anon') as anon_role,
    to_regrole('authenticated') as authenticated_role,
    to_regrole('service_role') as service_role
),
routine_rows as (
  select
    n.nspname as schema_name,
    p.oid,
    p.proname,
    p.oid::regprocedure::text as signature,
    r.rolname as owner_name,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config,
    lower(coalesce(pg_catalog.pg_get_function_result(p.oid), '')) as result_type,
    pg_catalog.pg_get_functiondef(p.oid) as function_def,
    p.proacl,
    p.proowner
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  join pg_catalog.pg_roles r
    on r.oid = p.proowner
  where n.nspname = 'public'
    and p.prokind = 'f'
),
trigger_usage as (
  select
    t.tgfoid as function_oid,
    count(*) filter (where not t.tgisinternal) as user_trigger_count
  from pg_catalog.pg_trigger t
  group by t.tgfoid
),
routine_privileges as (
  select
    rr.*,
    exists (
      select 1
      from aclexplode(coalesce(rr.proacl, acldefault('f', rr.proowner))) acl
      where acl.grantee = 0
        and acl.privilege_type = 'EXECUTE'
    ) as public_execute,
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
    ) as authenticated_execute,
    coalesce(
      case
        when (select service_role from role_refs) is null then false
        else pg_catalog.has_function_privilege((select service_role from role_refs), rr.oid, 'EXECUTE')
      end,
      false
    ) as service_role_execute,
    coalesce(tu.user_trigger_count, 0) as user_trigger_count
  from routine_rows rr
  left join trigger_usage tu
    on tu.function_oid = rr.oid
),
routine_flags as (
  select
    rp.*,
    rp.function_config ilike '%search_path=%' as has_any_search_path,
    rp.function_config ilike '%search_path=public%' as has_public_search_path,
    (
      rp.result_type = 'trigger'
      or rp.user_trigger_count > 0
      or rp.proname ilike '%trigger%'
    ) as trigger_like,
    (
      rp.proname ~ '^(get_|list_|is_|has_|can_)'
      and not (
        rp.function_def ilike '%insert into%'
        or rp.function_def ilike '%update public.%'
        or rp.function_def ilike '%delete from%'
      )
    ) as read_like_name,
    (
      rp.proname ~ '^(create_|update_|delete_|set_|cancel_|close_|mark_|record_|finalize_|claim_)'
      or rp.function_def ilike '%insert into%'
      or rp.function_def ilike '%update public.%'
      or rp.function_def ilike '%delete from%'
    ) as mutating_or_stateful,
    (
      rp.function_def ilike '%is_admin%'
      or rp.function_def ilike '%is_session_gm%'
      or rp.function_def ilike '%has_role%'
      or rp.function_def ilike '%auth.uid()%'
    ) as authz_or_actor_context,
    rp.function_def ilike '%discord%' as touches_discord,
    rp.function_def ilike '%session_post%' or rp.function_def ilike '%public.sessions%' as touches_sessions,
    rp.function_def ilike '%session_comments%' as touches_comments,
    rp.function_def ilike '%session_applications%' as touches_applications,
    rp.function_def ilike '%public.profiles%' or rp.function_def ilike '%public_profiles%' as touches_profiles,
    rp.function_def ilike '%player_characters%' as touches_player_characters,
    rp.function_def ilike '%user_notifications%' as touches_notifications,
    rp.function_def ilike '%activity_events%' as touches_activity,
    rp.function_def ilike '%storage.%' or rp.function_def ilike '%storage.objects%' as touches_storage
  from routine_privileges rp
),
classified_functions as (
  select
    rf.*,
    (rf.public_execute or rf.anon_execute or rf.authenticated_execute) as web_client_executable,
    case
      when not rf.security_definer then 'not_security_definer'
      when rf.has_public_search_path then 'already_search_path_public'
      when rf.anon_execute and not rf.read_like_name then 'P0_review_unexpected_anon_callable'
      when rf.public_execute and not rf.read_like_name then 'P0_review_public_callable'
      when rf.authenticated_execute and (rf.mutating_or_stateful or rf.authz_or_actor_context) then 'P1_high_web_rpc'
      when rf.anon_execute and rf.read_like_name then 'P1_public_read_rpc'
      when rf.authenticated_execute then 'P1_web_callable_rpc'
      when rf.service_role_execute then 'P1_service_role_or_cron_rpc'
      when rf.trigger_like then 'P2_trigger_or_internal'
      else 'P2_low_or_needs_owner_review'
    end as priority_bucket,
    case
      when not rf.security_definer or rf.has_public_search_path then 'not_target'
      when (rf.anon_execute or rf.public_execute or rf.authenticated_execute)
        and (rf.mutating_or_stateful or rf.authz_or_actor_context or not rf.read_like_name)
      then 'high_priority_web_surface'
      when rf.anon_execute or rf.authenticated_execute or rf.service_role_execute
      then 'additional_confirmation_needed'
      when rf.trigger_like then 'medium_priority_trigger_internal'
      else 'low_priority_or_historical'
    end as review_category,
    concat_ws('|',
      case when rf.touches_sessions then 'sessions' end,
      case when rf.touches_comments then 'comments' end,
      case when rf.touches_applications then 'applications' end,
      case when rf.touches_profiles then 'profiles' end,
      case when rf.touches_player_characters then 'player_characters' end,
      case when rf.touches_notifications then 'notifications' end,
      case when rf.touches_activity then 'activity' end,
      case when rf.touches_storage then 'storage' end,
      case when rf.touches_discord then 'discord' end,
      case when rf.authz_or_actor_context then 'authz_or_actor' end
    ) as object_hints
  from routine_flags rf
),
target_functions as (
  select *
  from classified_functions
  where security_definer
    and not has_public_search_path
),
summary_counts as (
  select
    count(*) filter (where security_definer) as security_definer_count,
    count(*) filter (where security_definer and has_public_search_path) as public_search_path_count,
    count(*) filter (where security_definer and not has_public_search_path) as needs_review_count,
    count(*) filter (where security_definer and not has_any_search_path) as missing_any_search_path_count,
    count(*) filter (where priority_bucket like 'P0%') as p0_review_count,
    count(*) filter (where priority_bucket like 'P1%') as p1_review_count,
    count(*) filter (where priority_bucket like 'P2%') as p2_review_count,
    count(*) filter (where review_category = 'high_priority_web_surface') as high_priority_web_count,
    count(*) filter (where review_category = 'additional_confirmation_needed') as additional_confirmation_count,
    count(*) filter (where review_category = 'medium_priority_trigger_internal') as trigger_internal_count,
    count(*) filter (where review_category = 'low_priority_or_historical') as low_priority_count
  from classified_functions
),
category_summary_rows as (
  select
    100 as sort_order,
    'security_definer_search_path_inventory_summary'::text as check_name,
    case
      when needs_review_count = 0 then 'ok'
      else 'review'
    end as status,
    concat(
      'security_definer=', security_definer_count,
      ',search_path_public=', public_search_path_count,
      ',needs_review=', needs_review_count,
      ',missing_any_search_path=', missing_any_search_path_count
    ) as result_value,
    'Count-only summary. Detail rows below identify signatures and non-secret exposure hints.'::text as note
  from summary_counts

  union all
  select
    110,
    'security_definer_search_path_priority_summary',
    case when p0_review_count = 0 then 'ok' else 'review' end,
    concat(
      'p0=', p0_review_count,
      ',p1=', p1_review_count,
      ',p2=', p2_review_count,
      ',high_web=', high_priority_web_count,
      ',additional_confirmation=', additional_confirmation_count,
      ',trigger_internal=', trigger_internal_count,
      ',low=', low_priority_count
    ),
    'P0 rows indicate unexpected public/anon non-read callable functions. P1 rows should be reviewed before wider public exposure.'
  from summary_counts

  union all
  select
    120,
    'security_definer_search_path_next_step',
    case when needs_review_count = 0 then 'ok' else 'review' end,
    case
      when needs_review_count = 0 then 'no_cleanup_needed'
      else 'manual_triage_required_before_apply_draft'
    end,
    'Use detail rows to choose a small apply-draft scope. Do not bulk-edit all functions at once.'
  from summary_counts
),
detail_rows as (
  select
    1000 + row_number() over (
      order by
        case
          when priority_bucket like 'P0%' then 0
          when priority_bucket like 'P1%' then 1
          else 2
        end,
        review_category,
        signature
    ) as sort_order,
    'security_definer_search_path_detail_' || lpad((row_number() over (
      order by
        case
          when priority_bucket like 'P0%' then 0
          when priority_bucket like 'P1%' then 1
          else 2
        end,
        review_category,
        signature
    ))::text, 3, '0') as check_name,
    'review'::text as status,
    signature as result_value,
    concat(
      'owner=', owner_name,
      ',category=', review_category,
      ',priority=', priority_bucket,
      ',has_any_search_path=', has_any_search_path,
      ',search_path_public=', has_public_search_path,
      ',public_execute=', public_execute,
      ',anon_execute=', anon_execute,
      ',authenticated_execute=', authenticated_execute,
      ',service_role_execute=', service_role_execute,
      ',trigger_like=', trigger_like,
      ',trigger_refs=', user_trigger_count,
      ',read_like=', read_like_name,
      ',stateful=', mutating_or_stateful,
      ',hints=', coalesce(nullif(object_hints, ''), 'none')
    ) as note
  from target_functions
)
select
  check_name,
  status,
  result_value,
  note
from (
  select sort_order, check_name, status, result_value, note
  from category_summary_rows
  union all
  select sort_order, check_name, status, result_value, note
  from detail_rows
) combined_rows
order by sort_order, check_name;
