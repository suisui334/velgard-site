-- 073_security_definer_search_path_exact_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Follow up the 072 security definer search_path inventory.
-- - Classify the exact configured search_path values for security definer
--   functions, especially the 38 functions that do not report search_path=public.
-- - Keep the result actionable for a future narrow apply draft.
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
    p.proconfig,
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
search_path_values as (
  select
    rr.*,
    coalesce(
      (
        select split_part(setting_item, '=', 2)
        from unnest(coalesce(rr.proconfig, array[]::text[])) as setting_item
        where setting_item like 'search_path=%'
        order by setting_item
        limit 1
      ),
      ''
    ) as configured_search_path
  from routine_rows rr
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
    spv.*,
    exists (
      select 1
      from aclexplode(coalesce(spv.proacl, acldefault('f', spv.proowner))) acl
      where acl.grantee = 0
        and acl.privilege_type = 'EXECUTE'
    ) as public_execute,
    coalesce(
      case
        when (select anon_role from role_refs) is null then false
        else pg_catalog.has_function_privilege((select anon_role from role_refs), spv.oid, 'EXECUTE')
      end,
      false
    ) as anon_execute,
    coalesce(
      case
        when (select authenticated_role from role_refs) is null then false
        else pg_catalog.has_function_privilege((select authenticated_role from role_refs), spv.oid, 'EXECUTE')
      end,
      false
    ) as authenticated_execute,
    coalesce(
      case
        when (select service_role from role_refs) is null then false
        else pg_catalog.has_function_privilege((select service_role from role_refs), spv.oid, 'EXECUTE')
      end,
      false
    ) as service_role_execute,
    coalesce(tu.user_trigger_count, 0) as user_trigger_count
  from search_path_values spv
  left join trigger_usage tu
    on tu.function_oid = spv.oid
),
routine_flags as (
  select
    rp.*,
    rp.function_config ilike '%search_path=%' as has_any_search_path,
    rp.function_config ilike '%search_path=public%' as has_public_search_path,
    btrim(rp.configured_search_path) = '' as configured_empty_path,
    rp.configured_search_path ilike '%$user%' as contains_user_path,
    rp.configured_search_path ilike '%pg_temp%' as contains_pg_temp_path,
    rp.configured_search_path <> ''
      and rp.configured_search_path not in ('public', '""')
      and rp.configured_search_path not ilike '%$user%'
      and rp.configured_search_path not ilike '%pg_temp%' as contains_other_path,
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
    case
      when not rf.security_definer then 'not_security_definer'
      when rf.has_public_search_path then 'safe_public_path'
      when rf.contains_user_path or rf.contains_pg_temp_path then 'dangerous_or_untrusted_path'
      when rf.configured_empty_path or rf.configured_search_path = '""' then 'safe_empty_path_candidate'
      else 'needs_manual_review'
    end as path_safety_class,
    case
      when not rf.security_definer then 'not_security_definer'
      when rf.has_public_search_path then 'already_search_path_public'
      when (rf.contains_user_path or rf.contains_pg_temp_path)
        and (rf.public_execute or rf.anon_execute or rf.authenticated_execute)
      then 'P0_review_untrusted_web_path'
      when (rf.public_execute or rf.anon_execute or rf.authenticated_execute)
        and (rf.mutating_or_stateful or rf.authz_or_actor_context or not rf.read_like_name)
      then 'P1_high_web_rpc'
      when rf.anon_execute and rf.read_like_name then 'P1_public_read_rpc'
      when rf.authenticated_execute then 'P1_web_callable_rpc'
      when rf.service_role_execute then 'P1_service_role_or_cron_rpc'
      when rf.trigger_like then 'P2_trigger_or_internal'
      else 'P2_low_or_needs_owner_review'
    end as priority_bucket,
    case
      when not rf.security_definer or rf.has_public_search_path then 'not_target'
      when (rf.contains_user_path or rf.contains_pg_temp_path) then 'dangerous_or_untrusted_path'
      when (rf.anon_execute or rf.public_execute or rf.authenticated_execute)
        and (rf.mutating_or_stateful or rf.authz_or_actor_context or not rf.read_like_name)
      then 'high_priority_web_surface'
      when rf.anon_execute or rf.authenticated_execute or rf.service_role_execute
      then 'additional_confirmation_needed'
      when rf.trigger_like then 'trigger_internal'
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
summary_counts as (
  select
    count(*) filter (where security_definer) as security_definer_count,
    count(*) filter (where security_definer and has_public_search_path) as public_search_path_count,
    count(*) filter (where security_definer and not has_public_search_path) as needs_review_count,
    count(*) filter (where security_definer and not has_any_search_path) as missing_any_search_path_count,
    count(*) filter (where security_definer and path_safety_class = 'safe_empty_path_candidate') as safe_empty_candidate_count,
    count(*) filter (where security_definer and contains_user_path) as contains_user_path_count,
    count(*) filter (where security_definer and contains_pg_temp_path) as contains_pg_temp_path_count,
    count(*) filter (where security_definer and contains_other_path) as contains_other_path_count,
    count(*) filter (where security_definer and path_safety_class = 'dangerous_or_untrusted_path') as dangerous_or_untrusted_count,
    count(*) filter (where security_definer and path_safety_class = 'needs_manual_review') as manual_review_count,
    count(*) filter (where security_definer and priority_bucket like 'P0%') as p0_review_count,
    count(*) filter (where security_definer and priority_bucket like 'P1%') as p1_review_count,
    count(*) filter (where security_definer and priority_bucket like 'P2%') as p2_review_count
  from classified_functions
),
review_targets as (
  select *
  from classified_functions
  where security_definer
    and not has_public_search_path
),
summary_rows as (
  select
    10 as sort_order,
    'security_definer_search_path_exact_summary'::text as check_name,
    case
      when dangerous_or_untrusted_count = 0 then 'ok'
      else 'review'
    end as status,
    concat(
      'security_definer=', security_definer_count,
      ',search_path_public=', public_search_path_count,
      ',needs_review=', needs_review_count,
      ',missing_any_search_path=', missing_any_search_path_count
    ) as result_value,
    'Count-only summary. missing_any_search_path=0 means every security definer has some search_path setting, but not all are public.'::text as note
  from summary_counts

  union all
  select
    20,
    'security_definer_search_path_exact_values',
    case
      when dangerous_or_untrusted_count = 0 then 'ok'
      else 'review'
    end,
    concat(
      'safe_empty_candidate=', safe_empty_candidate_count,
      ',user_path=', contains_user_path_count,
      ',pg_temp=', contains_pg_temp_path_count,
      ',other_path=', contains_other_path_count,
      ',manual_review=', manual_review_count
    ),
    'Classifies configured search_path values without returning function bodies.'
  from summary_counts

  union all
  select
    30,
    'security_definer_search_path_exact_priority',
    case when p0_review_count = 0 then 'ok' else 'review' end,
    concat(
      'p0=', p0_review_count,
      ',p1=', p1_review_count,
      ',p2=', p2_review_count
    ),
    'P0 indicates untrusted search_path with web exposure. P1 should drive the first narrow cleanup scope.'
  from summary_counts

  union all
  select
    40,
    'security_definer_search_path_exact_next_step',
    'review',
    case
      when dangerous_or_untrusted_count > 0 then 'triage_untrusted_paths_first'
      when p1_review_count > 0 then 'choose_small_p1_apply_scope'
      when p2_review_count > 0 then 'review_trigger_or_low_priority_later'
      else 'no_cleanup_needed'
    end,
    'Do not bulk-edit all review rows. Choose a narrow apply draft after this result is recorded.'
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
        path_safety_class,
        review_category,
        signature
    ) as sort_order,
    'security_definer_search_path_exact_detail_' || lpad((row_number() over (
      order by
        case
          when priority_bucket like 'P0%' then 0
          when priority_bucket like 'P1%' then 1
          else 2
        end,
        path_safety_class,
        review_category,
        signature
    ))::text, 3, '0') as check_name,
    case
      when path_safety_class = 'dangerous_or_untrusted_path' then 'review'
      when path_safety_class = 'needs_manual_review' then 'review'
      else 'info'
    end as status,
    signature as result_value,
    concat(
      'owner=', owner_name,
      ',path_class=', path_safety_class,
      ',path_value=', coalesce(nullif(configured_search_path, ''), '<empty>'),
      ',category=', review_category,
      ',priority=', priority_bucket,
      ',public_execute=', public_execute,
      ',anon_execute=', anon_execute,
      ',authenticated_execute=', authenticated_execute,
      ',service_role_execute=', service_role_execute,
      ',trigger_refs=', user_trigger_count,
      ',hints=', coalesce(nullif(object_hints, ''), 'none')
    ) as note
  from review_targets
)
select
  check_name,
  status,
  result_value,
  note
from (
  select sort_order, check_name, status, result_value, note
  from summary_rows
  union all
  select sort_order, check_name, status, result_value, note
  from detail_rows
) combined_rows
order by sort_order, check_name;
