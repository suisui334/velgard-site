-- 084_membership_gate_comment_application_post_apply_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Confirm the 083 comment/application approved-member RPC gate after apply.
-- - Confirm four RPC signatures, security mode, execute grants, approved checks,
--   and preservation of existing comment/application behavior.
-- - Return status/boolean summaries only.
-- - Do not return function bodies, row ids, user ids, session ids, emails, full
--   URLs, project refs, notification ids, activity ids, tokens, keys, or secrets.

with expected_rpcs as (
  select *
  from (
    values
      (10, 'create_application_comment', 'create_application_comment(text,text)'),
      (20, 'cancel_my_session_application', 'cancel_my_session_application(text)'),
      (30, 'update_application_comment', 'update_application_comment(uuid,text)'),
      (40, 'delete_application_comment_and_maybe_cancel', 'delete_application_comment_and_maybe_cancel(uuid)')
  ) as v(sort_order, rpc_name, expected_signature)
),
role_refs as (
  select
    to_regrole('anon') as anon_role,
    to_regrole('authenticated') as authenticated_role
),
target_rpc as (
  select
    p.oid,
    p.proname,
    p.oid::regprocedure::text as signature,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config,
    p.proacl,
    p.proowner,
    pg_catalog.pg_get_functiondef(p.oid) as function_def
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'create_application_comment',
      'cancel_my_session_application',
      'update_application_comment',
      'delete_application_comment_and_maybe_cancel'
    )
),
target_checks as (
  select
    er.sort_order,
    er.rpc_name,
    er.expected_signature,
    tr.oid,
    tr.signature,
    coalesce(tr.security_definer, false) as security_definer,
    coalesce(tr.function_config ilike '%search_path=public%', false) as search_path_public,
    case
      when tr.oid is null then false
      else exists (
        select 1
        from aclexplode(coalesce(tr.proacl, acldefault('f', tr.proowner))) acl
        where acl.grantee = 0
          and acl.privilege_type = 'EXECUTE'
      )
    end as public_execute,
    coalesce(
      case
        when (select anon_role from role_refs) is null or tr.oid is null then false
        else pg_catalog.has_function_privilege((select anon_role from role_refs), tr.oid, 'EXECUTE')
      end,
      false
    ) as anon_execute,
    coalesce(
      case
        when (select authenticated_role from role_refs) is null or tr.oid is null then false
        else pg_catalog.has_function_privilege((select authenticated_role from role_refs), tr.oid, 'EXECUTE')
      end,
      false
    ) as authenticated_execute,
    coalesce(tr.function_def ilike '%is_approved_member()%'
      and tr.function_def like '%承認済みアカウントのみ利用できます。%', false) as has_approved_gate,
    coalesce(tr.function_def ilike '%auth.uid()%'
      and tr.function_def ilike '%v_actor_id is null%', false) as has_auth_guard,
    coalesce(tr.function_def ilike '%raise exception%', false) as has_error_branches,
    coalesce(tr.function_def, '') as function_def
  from expected_rpcs er
  left join target_rpc tr
    on tr.signature = er.expected_signature
),
target_summary as (
  select
    count(*) as expected_count,
    count(oid) as found_count,
    count(*) filter (where signature = expected_signature) as signature_match_count,
    bool_and(security_definer) as all_security_definer,
    bool_and(search_path_public) as all_search_path_public,
    bool_and(authenticated_execute) as all_authenticated_execute,
    bool_or(anon_execute) as any_anon_execute,
    bool_or(public_execute) as any_public_execute,
    bool_and(has_auth_guard) as all_auth_guard,
    bool_and(has_approved_gate) as all_approved_gate,
    bool_and(has_error_branches) as all_error_branches
  from target_checks
),
create_comment_summary as (
  select
    coalesce(bool_or(function_def like '%length(v_comment_body) > 4000%'), false) as has_length_guard,
    coalesce(bool_or(function_def like '%v_url_match_count%'), false) as has_url_counter,
    coalesce(bool_or(function_def like '%regexp_matches(v_comment_body%'), false) as has_url_matcher,
    coalesce(bool_or(function_def like '%v_url_match_count > 2%'), false) as has_url_threshold,
    coalesce(bool_or(function_def like '%v_recent_comment_exists%'), false) as has_cooldown_flag,
    coalesce(bool_or(function_def like '%sc.session_id = v_target_session_id%'), false) as cooldown_same_session,
    coalesce(bool_or(function_def like '%sc.user_id = v_actor_id%'), false) as cooldown_same_user,
    coalesce(bool_or(function_def like '%interval ''60 seconds''%'), false) as cooldown_sixty_seconds,
    coalesce(bool_or(function_def like '%create_session_owner_notification%'), false) as has_owner_notification,
    coalesce(bool_or(function_def like '%insert into public.activity_events%'), false) as has_activity_insert,
    coalesce(bool_or(function_def like '%v_activity_event_id is null%'), false) as has_activity_failure_guard,
    coalesce(bool_or(function_def like '%session_application%'), false) as has_application_type,
    coalesce(bool_or(function_def like '%session_comment%'), false) as has_comment_type,
    coalesce(bool_or(function_def like '%selected_character_id%'), false) as keeps_pc_snapshot_character,
    coalesce(bool_or(function_def like '%pc_name_snapshot%'), false) as keeps_pc_snapshot_name,
    coalesce(bool_or(function_def like '%Shared timeline intentionally excludes GM/admin management comments.%'), false) as keeps_management_activity_skip,
    coalesce(bool_or(function_def like '%session-detail.html?id=%'), false) as has_relative_target_path,
    coalesce(bool_or(function_def like '%''authenticated''%'), false) as has_authenticated_visibility
  from target_checks
  where rpc_name = 'create_application_comment'
),
cancel_summary as (
  select
    coalesce(bool_or(function_def like '%sa.user_id = v_actor_id%'), false) as limits_to_actor_application,
    coalesce(bool_or(function_def like '%v_current_status not in (''pending'', ''waitlisted'', ''accepted'')%'), false) as keeps_withdrawable_statuses,
    coalesce(bool_or(function_def like '%status = ''canceled''%'), false) as keeps_canceled_status,
    coalesce(bool_or(function_def like '%return query%'), false) as keeps_return_query
  from target_checks
  where rpc_name = 'cancel_my_session_application'
),
update_summary as (
  select
    coalesce(bool_or(function_def like '%length(comment_body) > 4000%'), false) as has_length_guard,
    coalesce(bool_or(function_def like '%c.user_id = v_actor_id%'), false) as owner_can_edit,
    coalesce(bool_or(function_def like '%public.is_session_gm(c.session_id)%'), false) as gm_can_edit,
    coalesce(bool_or(function_def like '%public.is_admin()%'), false) as admin_can_edit,
    coalesce(bool_or(function_def like '%c.deleted_at is null%'), false) as ignores_deleted_comments,
    coalesce(bool_or(function_def like '%edited_at = now()%'), false) as keeps_edited_at,
    coalesce(bool_or(function_def like '%edited_by = v_actor_id%'), false) as keeps_edited_by,
    coalesce(bool_or(function_def like '%returns table%'), false) as keeps_table_return
  from target_checks
  where rpc_name = 'update_application_comment'
),
delete_summary as (
  select
    coalesce(bool_or(function_def like '%v_comment_user_id = v_actor_id%'), false) as owner_can_delete,
    coalesce(bool_or(function_def like '%public.is_session_gm(v_session_id)%'), false) as gm_can_delete,
    coalesce(bool_or(function_def like '%public.is_admin()%'), false) as admin_can_delete,
    coalesce(bool_or(function_def like '%deleted_at = now()%'), false) as keeps_deleted_at,
    coalesce(bool_or(function_def like '%deleted_by = v_actor_id%'), false) as keeps_deleted_by,
    coalesce(bool_or(function_def like '%v_active_count = 0%'), false) as keeps_last_comment_cancel_rule,
    coalesce(bool_or(function_def like '%status = ''canceled''%'), false) as keeps_canceled_status,
    coalesce(bool_or(function_def like '%active_application_comment_count integer%'), false) as keeps_return_shape
  from target_checks
  where rpc_name = 'delete_application_comment_and_maybe_cancel'
),
direct_write_grants as (
  select count(*) as direct_write_count
  from information_schema.table_privileges
  where table_schema = 'public'
    and table_name in ('session_comments', 'session_applications')
    and grantee in ('anon', 'authenticated')
    and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
),
public_profiles_exposure as (
  select
    count(*) filter (
      where column_name ilike '%membership%'
         or column_name ilike '%role%'
         or column_name ilike '%status%'
    ) as risky_column_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'public_profiles'
),
ready_summary as (
  select
    (
      ts.expected_count = 4
      and ts.found_count = 4
      and ts.signature_match_count = 4
      and ts.all_security_definer
      and ts.all_search_path_public
      and ts.all_authenticated_execute
      and not ts.any_anon_execute
      and not ts.any_public_execute
      and ts.all_auth_guard
      and ts.all_approved_gate
      and ts.all_error_branches
      and ccs.has_length_guard
      and ccs.has_url_counter
      and ccs.has_url_matcher
      and ccs.has_url_threshold
      and ccs.has_cooldown_flag
      and ccs.cooldown_same_session
      and ccs.cooldown_same_user
      and ccs.cooldown_sixty_seconds
      and ccs.has_owner_notification
      and ccs.has_activity_insert
      and ccs.has_activity_failure_guard
      and ccs.has_application_type
      and ccs.has_comment_type
      and ccs.keeps_pc_snapshot_character
      and ccs.keeps_pc_snapshot_name
      and ccs.keeps_management_activity_skip
      and ccs.has_relative_target_path
      and ccs.has_authenticated_visibility
      and cs.limits_to_actor_application
      and cs.keeps_withdrawable_statuses
      and cs.keeps_canceled_status
      and cs.keeps_return_query
      and us.has_length_guard
      and us.owner_can_edit
      and us.gm_can_edit
      and us.admin_can_edit
      and us.ignores_deleted_comments
      and us.keeps_edited_at
      and us.keeps_edited_by
      and ds.owner_can_delete
      and ds.gm_can_delete
      and ds.admin_can_delete
      and ds.keeps_deleted_at
      and ds.keeps_deleted_by
      and ds.keeps_last_comment_cancel_rule
      and ds.keeps_canceled_status
      and dwg.direct_write_count = 0
      and ppe.risky_column_count = 0
    ) as ready_for_comment_application_membership_gate_qa
  from target_summary ts
  cross join create_comment_summary ccs
  cross join cancel_summary cs
  cross join update_summary us
  cross join delete_summary ds
  cross join direct_write_grants dwg
  cross join public_profiles_exposure ppe
),
output_rows as (
  select
    sort_order,
    'comment_application_gate_rpc_' || rpc_name as check_name,
    case
      when oid is not null
       and signature = expected_signature
       and security_definer
       and search_path_public
       and authenticated_execute
       and not anon_execute
       and not public_execute
       and has_auth_guard
       and has_approved_gate
      then 'ok'
      else 'review'
    end as status,
    coalesce(signature, rpc_name || '(missing)') as result_value,
    concat(
      'security_definer=', security_definer,
      ',search_path_public=', search_path_public,
      ',authenticated_execute=', authenticated_execute,
      ',anon_execute=', anon_execute,
      ',public_execute=', public_execute,
      ',auth_guard=', has_auth_guard,
      ',approved_gate=', has_approved_gate
    ) as note
  from target_checks

  union all
  select
    100,
    'comment_application_gate_summary',
    case
      when expected_count = 4
       and found_count = 4
       and signature_match_count = 4
       and all_security_definer
       and all_search_path_public
       and all_authenticated_execute
       and not any_anon_execute
       and not any_public_execute
       and all_approved_gate
      then 'ok'
      else 'review'
    end,
    concat(
      'expected=', expected_count,
      ',found=', found_count,
      ',signature_match=', signature_match_count,
      ',approved_gate_all=', all_approved_gate
    ),
    'All four comment/application RPCs should keep signatures and add the approved-member gate.'
  from target_summary

  union all
  select
    200,
    'create_application_comment_existing_guards',
    case
      when has_length_guard
       and has_url_counter
       and has_url_matcher
       and has_url_threshold
       and has_cooldown_flag
       and cooldown_same_session
       and cooldown_same_user
       and cooldown_sixty_seconds
      then 'ok'
      else 'review'
    end,
    concat(
      'length=', has_length_guard,
      ',url_counter=', has_url_counter,
      ',url_matcher=', has_url_matcher,
      ',url_threshold=', has_url_threshold,
      ',cooldown=', has_cooldown_flag,
      ',same_session=', cooldown_same_session,
      ',same_user=', cooldown_same_user,
      ',seconds60=', cooldown_sixty_seconds
    ),
    'Existing length, URL-count, and 60-second same-user/same-session guards should remain.'
  from create_comment_summary

  union all
  select
    210,
    'create_application_comment_existing_instrumentation',
    case
      when has_owner_notification
       and has_activity_insert
       and has_activity_failure_guard
       and has_application_type
       and has_comment_type
       and keeps_pc_snapshot_character
       and keeps_pc_snapshot_name
       and keeps_management_activity_skip
       and has_relative_target_path
       and has_authenticated_visibility
      then 'ok'
      else 'review'
    end,
    concat(
      'notification=', has_owner_notification,
      ',activity=', has_activity_insert,
      ',activity_guard=', has_activity_failure_guard,
      ',application_type=', has_application_type,
      ',comment_type=', has_comment_type,
      ',pc_character=', keeps_pc_snapshot_character,
      ',pc_name=', keeps_pc_snapshot_name,
      ',management_skip=', keeps_management_activity_skip,
      ',target=', has_relative_target_path,
      ',visibility=', has_authenticated_visibility
    ),
    'Owner notifications, TIMELINE activity, PC snapshot, and management-comment activity skip should remain.'
  from create_comment_summary

  union all
  select
    300,
    'cancel_my_session_application_existing_behavior',
    case
      when limits_to_actor_application
       and keeps_withdrawable_statuses
       and keeps_canceled_status
       and keeps_return_query
      then 'ok'
      else 'review'
    end,
    concat(
      'actor_scope=', limits_to_actor_application,
      ',withdrawable_statuses=', keeps_withdrawable_statuses,
      ',canceled_status=', keeps_canceled_status,
      ',return_query=', keeps_return_query
    ),
    'Withdraw RPC should remain scoped to the caller application and existing withdrawable statuses.'
  from cancel_summary

  union all
  select
    400,
    'update_application_comment_existing_behavior',
    case
      when has_length_guard
       and owner_can_edit
       and gm_can_edit
       and admin_can_edit
       and ignores_deleted_comments
       and keeps_edited_at
       and keeps_edited_by
      then 'ok'
      else 'review'
    end,
    concat(
      'length=', has_length_guard,
      ',owner=', owner_can_edit,
      ',gm=', gm_can_edit,
      ',admin=', admin_can_edit,
      ',not_deleted=', ignores_deleted_comments,
      ',edited_at=', keeps_edited_at,
      ',edited_by=', keeps_edited_by
    ),
    'Comment edit permissions and audit fields should remain.'
  from update_summary

  union all
  select
    500,
    'delete_application_comment_existing_behavior',
    case
      when owner_can_delete
       and gm_can_delete
       and admin_can_delete
       and keeps_deleted_at
       and keeps_deleted_by
       and keeps_last_comment_cancel_rule
       and keeps_canceled_status
      then 'ok'
      else 'review'
    end,
    concat(
      'owner=', owner_can_delete,
      ',gm=', gm_can_delete,
      ',admin=', admin_can_delete,
      ',deleted_at=', keeps_deleted_at,
      ',deleted_by=', keeps_deleted_by,
      ',last_comment_cancel=', keeps_last_comment_cancel_rule,
      ',canceled_status=', keeps_canceled_status
    ),
    'Comment logical delete and maybe-cancel behavior should remain.'
  from delete_summary

  union all
  select
    700,
    'comment_application_direct_table_write_grants',
    case when direct_write_count = 0 then 'ok' else 'review' end,
    direct_write_count::text,
    'Web roles should not receive direct mutation grants on session_comments or session_applications.'
  from direct_write_grants

  union all
  select
    710,
    'public_profiles_membership_exposure',
    case when risky_column_count = 0 then 'ok' else 'review' end,
    risky_column_count::text,
    'public_profiles should still not expose membership or role state.'
  from public_profiles_exposure

  union all
  select
    900,
    'post_apply_ready_for_comment_application_membership_gate_qa',
    case when ready_for_comment_application_membership_gate_qa then 'ok' else 'review' end,
    ready_for_comment_application_membership_gate_qa::text,
    'If true, proceed to a separate functional QA gate for approved and unapproved users.'
  from ready_summary
)
select
  check_name,
  status,
  result_value,
  note
from output_rows
order by sort_order, check_name;
