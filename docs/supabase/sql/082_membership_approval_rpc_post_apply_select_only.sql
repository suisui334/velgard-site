-- 082_membership_approval_rpc_post_apply_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Confirm the separately approved 081 membership approval RPC apply.
-- - Return status/count/boolean-style results only.
-- - Do not return concrete user ids, emails, session ids, full URLs, project
--   refs, tokens, keys, or secrets.

with role_refs as (
  select
    to_regrole('anon') as anon_role,
    to_regrole('authenticated') as authenticated_role
),
function_rows as (
  select
    p.oid,
    p.proname,
    p.oid::regprocedure::text as signature,
    p.prosecdef as security_definer,
    p.proacl,
    p.proowner,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config,
    pg_get_functiondef(p.oid) as function_def
  from pg_proc p
  join pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'get_pending_community_members',
      'approve_community_member',
      'reject_community_member'
    )
),
function_summary as (
  select
    count(*) filter (
      where proname = 'get_pending_community_members'
        and signature = 'get_pending_community_members(integer)'
    ) as list_pending_count,
    count(*) filter (
      where proname = 'approve_community_member'
        and signature = 'approve_community_member(uuid,text)'
    ) as approve_count,
    count(*) filter (
      where proname = 'reject_community_member'
        and signature = 'reject_community_member(uuid,text)'
    ) as reject_count,
    count(*) filter (where security_definer) as security_definer_count,
    count(*) filter (where function_config ilike '%search_path=public%') as search_path_public_count,
    count(*) filter (where function_def ilike '%is_admin()%') as admin_guard_count,
    count(*) filter (where function_def ilike '%is_membership_approver()%') as approver_helper_guard_count,
    count(*) filter (where function_def ilike '%has_role(''membership_approver'')%') as approver_role_guard_count,
    count(*) filter (where function_def ilike '%is_approved_member()%') as approved_approver_guard_count,
    count(*) filter (
      where proname in ('approve_community_member', 'reject_community_member')
        and function_def ilike '%p_target_user_id = v_actor_id%'
    ) as self_action_guard_count,
    count(*) filter (
      where proname in ('approve_community_member', 'reject_community_member')
        and function_def ilike '%cm.status = ''pending''%'
    ) as pending_only_guard_count,
    count(*) filter (
      where proname = 'approve_community_member'
        and function_def ilike '%status = ''approved''%'
    ) as approve_transition_count,
    count(*) filter (
      where proname = 'reject_community_member'
        and function_def ilike '%status = ''rejected''%'
    ) as reject_transition_count,
    count(*) filter (
      where proname in ('approve_community_member', 'reject_community_member')
        and (
          function_def ilike '%status = ''revoked''%'
          or function_def ilike '%status = ''blocked''%'
        )
    ) as unexpected_force_status_count,
    count(*) filter (
      where proname in ('approve_community_member', 'reject_community_member')
        and function_def ilike '%char_length(v_review_note) > 1000%'
    ) as review_note_guard_count,
    count(*) filter (
      where proname in ('approve_community_member', 'reject_community_member')
        and function_def ilike '%membership_not_pending%'
    ) as not_pending_error_count,
    count(*) filter (
      where function_def ilike '%email%'
    ) as email_pattern_count
  from function_rows
),
function_privileges as (
  select
    fr.proname,
    case
      when (select authenticated_role from role_refs) is null then false
      else has_function_privilege((select authenticated_role from role_refs), fr.oid, 'EXECUTE')
    end as authenticated_execute,
    case
      when (select anon_role from role_refs) is null then false
      else has_function_privilege((select anon_role from role_refs), fr.oid, 'EXECUTE')
    end as anon_execute,
    exists (
      select 1
      from aclexplode(coalesce(fr.proacl, acldefault('f', fr.proowner))) acl
      where acl.grantee = 0
        and acl.privilege_type = 'EXECUTE'
    ) as public_execute
  from function_rows fr
),
privilege_summary as (
  select
    count(*) filter (where authenticated_execute) as authenticated_execute_count,
    count(*) filter (where anon_execute) as anon_execute_count,
    count(*) filter (where public_execute) as public_execute_count
  from function_privileges
),
table_privileges as (
  select
    count(*) filter (
      where grantee in ('PUBLIC', 'anon', 'authenticated')
        and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
    ) as direct_write_count,
    count(*) filter (
      where grantee in ('PUBLIC', 'anon', 'authenticated')
        and privilege_type = 'SELECT'
    ) as direct_select_count
  from information_schema.table_privileges
  where table_schema = 'public'
    and table_name = 'community_memberships'
),
public_profiles_exposure as (
  select
    count(*) filter (
      where column_name ~* '(membership|role|approval|approved|blocked|revoked|rejected)'
    ) as risky_column_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'public_profiles'
),
output_rows as (
  select
    10 as sort_order,
    'membership_approval_rpc_exists'::text as check_name,
    case
      when list_pending_count = 1
       and approve_count = 1
       and reject_count = 1
      then 'ok'
      else 'review'
    end as status,
    concat(
      'list_pending=', list_pending_count,
      ',approve=', approve_count,
      ',reject=', reject_count
    ) as result_value,
    'The three 081 RPCs should exist with the reviewed signatures.'::text as note
  from function_summary

  union all
  select
    20,
    'membership_approval_rpc_security',
    case
      when security_definer_count = 3
       and search_path_public_count = 3
      then 'ok'
      else 'review'
    end,
    concat('security_definer=', security_definer_count, ',search_path_public=', search_path_public_count),
    'All three approval RPCs should be security definer with search_path=public.'
  from function_summary

  union all
  select
    30,
    'membership_approval_rpc_execute_grants',
    case
      when authenticated_execute_count = 3
       and anon_execute_count = 0
       and public_execute_count = 0
      then 'ok'
      else 'review'
    end,
    concat(
      'authenticated=', authenticated_execute_count,
      ',anon=', anon_execute_count,
      ',public=', public_execute_count
    ),
    'RPCs should be callable by authenticated users only; internal guards perform the admin/approver check.'
  from privilege_summary

  union all
  select
    40,
    'membership_approval_internal_authorization',
    case
      when admin_guard_count = 3
       and approver_helper_guard_count = 3
       and approver_role_guard_count = 3
       and approved_approver_guard_count = 3
      then 'ok'
      else 'review'
    end,
    concat(
      'admin_guard=', admin_guard_count,
      ',approver_helper_guard=', approver_helper_guard_count,
      ',approver_role_guard=', approver_role_guard_count,
      ',approved_approver_guard=', approved_approver_guard_count
    ),
    'RPC bodies should allow admin or approved membership_approver users only.'
  from function_summary

  union all
  select
    50,
    'membership_approval_self_action_guard',
    case when self_action_guard_count = 2 then 'ok' else 'review' end,
    self_action_guard_count::text,
    'Approve/reject RPCs should prevent an approver from acting on their own account.'
  from function_summary

  union all
  select
    60,
    'membership_approval_pending_only_transitions',
    case
      when pending_only_guard_count = 2
       and approve_transition_count = 1
       and reject_transition_count = 1
       and unexpected_force_status_count = 0
      then 'ok'
      else 'review'
    end,
    concat(
      'pending_guard=', pending_only_guard_count,
      ',approve_transition=', approve_transition_count,
      ',reject_transition=', reject_transition_count,
      ',unexpected_force_status=', unexpected_force_status_count
    ),
    '081 should allow only pending -> approved and pending -> rejected transitions.'
  from function_summary

  union all
  select
    70,
    'membership_approval_review_note_guard',
    case
      when review_note_guard_count = 2
       and not_pending_error_count = 2
      then 'ok'
      else 'review'
    end,
    concat('review_note_guard=', review_note_guard_count, ',not_pending_error=', not_pending_error_count),
    'Approve/reject RPCs should keep the existing review_note length boundary and non-pending error guard.'
  from function_summary

  union all
  select
    80,
    'membership_approval_no_email_return_or_storage',
    case when email_pattern_count = 0 then 'ok' else 'review' end,
    email_pattern_count::text,
    'Approval RPC bodies should not reference or return email values.'
  from function_summary

  union all
  select
    90,
    'community_memberships_direct_grants_still_closed',
    case
      when direct_write_count = 0
       and direct_select_count = 0
      then 'ok'
      else 'review'
    end,
    concat('direct_write=', direct_write_count, ',direct_select=', direct_select_count),
    '081 should not open direct web-role table grants on community_memberships.'
  from table_privileges

  union all
  select
    100,
    'public_profiles_membership_not_exposed',
    case when risky_column_count = 0 then 'ok' else 'review' end,
    risky_column_count::text,
    'public_profiles should not expose membership or role state.'
  from public_profiles_exposure

  union all
  select
    900,
    'post_apply_ready_for_membership_approval_rpc_qa',
    case
      when (select list_pending_count from function_summary) = 1
       and (select approve_count from function_summary) = 1
       and (select reject_count from function_summary) = 1
       and (select security_definer_count from function_summary) = 3
       and (select search_path_public_count from function_summary) = 3
       and (select authenticated_execute_count from privilege_summary) = 3
       and (select anon_execute_count from privilege_summary) = 0
       and (select public_execute_count from privilege_summary) = 0
       and (select admin_guard_count from function_summary) = 3
       and (select approver_helper_guard_count from function_summary) = 3
       and (select approver_role_guard_count from function_summary) = 3
       and (select approved_approver_guard_count from function_summary) = 3
       and (select self_action_guard_count from function_summary) = 2
       and (select pending_only_guard_count from function_summary) = 2
       and (select approve_transition_count from function_summary) = 1
       and (select reject_transition_count from function_summary) = 1
       and (select unexpected_force_status_count from function_summary) = 0
       and (select review_note_guard_count from function_summary) = 2
       and (select email_pattern_count from function_summary) = 0
       and (select direct_write_count from table_privileges) = 0
       and (select direct_select_count from table_privileges) = 0
       and (select risky_column_count from public_profiles_exposure) = 0
      then 'ok'
      else 'review'
    end,
    case
      when (select list_pending_count from function_summary) = 1
       and (select approve_count from function_summary) = 1
       and (select reject_count from function_summary) = 1
       and (select security_definer_count from function_summary) = 3
       and (select search_path_public_count from function_summary) = 3
       and (select authenticated_execute_count from privilege_summary) = 3
       and (select anon_execute_count from privilege_summary) = 0
       and (select public_execute_count from privilege_summary) = 0
       and (select admin_guard_count from function_summary) = 3
       and (select approver_helper_guard_count from function_summary) = 3
       and (select approver_role_guard_count from function_summary) = 3
       and (select approved_approver_guard_count from function_summary) = 3
       and (select self_action_guard_count from function_summary) = 2
       and (select pending_only_guard_count from function_summary) = 2
       and (select approve_transition_count from function_summary) = 1
       and (select reject_transition_count from function_summary) = 1
       and (select unexpected_force_status_count from function_summary) = 0
       and (select review_note_guard_count from function_summary) = 2
       and (select email_pattern_count from function_summary) = 0
       and (select direct_write_count from table_privileges) = 0
       and (select direct_select_count from table_privileges) = 0
       and (select risky_column_count from public_profiles_exposure) = 0
      then 'true'
      else 'false'
    end,
    'If true, proceed to approval RPC functional QA in a separate gate.'
)
select
  check_name,
  status,
  result_value,
  note
from output_rows
order by sort_order;
