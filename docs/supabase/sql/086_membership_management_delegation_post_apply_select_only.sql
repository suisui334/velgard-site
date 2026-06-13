-- 086_membership_management_delegation_post_apply_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Confirm the separately approved 085 membership management delegation apply.
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
    pg_get_function_result(p.oid) as function_result,
    pg_get_functiondef(p.oid) as function_def
  from pg_proc p
  join pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'list_membership_review_users',
      'set_member_review_status',
      'grant_membership_manager',
      'revoke_membership_manager'
    )
),
function_summary as (
  select
    count(*) filter (
      where proname = 'list_membership_review_users'
        and signature = 'list_membership_review_users(text,integer)'
    ) as list_count,
    count(*) filter (
      where proname = 'set_member_review_status'
        and signature = 'set_member_review_status(uuid,text,text)'
    ) as set_status_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and signature = 'grant_membership_manager(uuid)'
    ) as grant_manager_count,
    count(*) filter (
      where proname = 'revoke_membership_manager'
        and signature = 'revoke_membership_manager(uuid)'
    ) as revoke_manager_count,
    count(*) filter (where security_definer) as security_definer_count,
    count(*) filter (where function_config ilike '%search_path=public%') as search_path_public_count,
    count(*) filter (where function_def ilike '%email%') as email_pattern_count,
    count(*) filter (
      where function_def ilike '%public.is_admin()%'
    ) as admin_guard_count,
    count(*) filter (
      where proname in ('list_membership_review_users', 'set_member_review_status')
        and function_def ilike '%is_membership_approver()%'
        and function_def ilike '%has_role(''membership_approver'')%'
        and function_def ilike '%is_approved_member()%'
    ) as approved_manager_guard_count,
    count(*) filter (
      where proname in ('grant_membership_manager', 'revoke_membership_manager')
        and function_def ilike '%public.is_admin()%'
        and function_def not ilike '%has_role(''membership_approver'')%'
        and function_def not ilike '%is_membership_approver()%'
    ) as admin_only_role_rpc_count,
    count(*) filter (
      where proname in ('set_member_review_status', 'grant_membership_manager', 'revoke_membership_manager')
        and function_def ilike '%v_target_user_id = v_actor_id%'
    ) as self_action_guard_count,
    count(*) filter (
      where proname in ('set_member_review_status', 'grant_membership_manager', 'revoke_membership_manager')
        and function_def ilike '%role = ''admin''%'
    ) as target_admin_guard_count,
    count(*) filter (
      where proname = 'set_member_review_status'
        and function_def ilike '%not v_is_admin%'
        and function_def ilike '%role = ''membership_approver''%'
    ) as target_manager_non_admin_guard_count,
    count(*) filter (
      where proname = 'set_member_review_status'
        and function_def ilike '%v_new_status is null%'
        and function_def ilike '%v_new_status not in (''pending'', ''approved'', ''rejected'')%'
    ) as allowed_status_guard_count,
    count(*) filter (
      where proname = 'set_member_review_status'
        and function_def ilike '%v_current_status in (''revoked'', ''blocked'')%'
    ) as revoked_blocked_guard_count,
    count(*) filter (
      where proname = 'set_member_review_status'
        and function_def ilike '%v_current_status = ''approved'' and v_new_status = ''rejected''%'
        and function_def ilike '%v_current_status = ''rejected'' and v_new_status = ''approved''%'
        and function_def ilike '%v_current_status = ''pending'' and v_new_status in (''approved'', ''rejected'')%'
        and function_def not ilike '%v_current_status = ''rejected'' and v_new_status in (''approved'', ''pending'')%'
    ) as expected_transition_guard_count,
    count(*) filter (
      where proname = 'set_member_review_status'
        and function_def ilike '%char_length(v_review_note) > 1000%'
    ) as review_note_guard_count,
    count(*) filter (
      where proname = 'list_membership_review_users'
        and function_def ilike '%cm.status in (''pending'', ''approved'', ''rejected'')%'
    ) as list_status_scope_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%values (v_target_user_id, ''membership_approver'')%'
        and function_def not ilike '%values (v_target_user_id, ''admin'')%'
    ) as manager_grant_scope_count,
    count(*) filter (
      where proname = 'revoke_membership_manager'
        and function_def ilike '%ur.role = ''membership_approver''%'
        and function_def not ilike '%ur.role = ''admin''%'
    ) as manager_revoke_scope_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%v_status is distinct from ''approved''%'
    ) as grant_requires_approved_count,
    count(*) filter (
      where proname = 'list_membership_review_users'
        and function_def ilike '%cm.management_key as member_key%'
    ) as list_returns_management_key_count,
    count(*) filter (
      where proname in ('set_member_review_status', 'grant_membership_manager', 'revoke_membership_manager')
        and function_def ilike '%p_target_member_key uuid%'
        and function_def ilike '%cm.management_key = p_target_member_key%'
    ) as target_member_key_lookup_count,
    count(*) filter (
      where function_result ilike '%user_id%'
    ) as returns_user_id_column_count
  from function_rows
),
membership_key_schema as (
  select
    (
      select count(*)
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'community_memberships'
        and c.column_name = 'management_key'
        and c.udt_name = 'uuid'
        and c.is_nullable = 'NO'
    ) as management_key_column_count,
    (
      select count(*)
      from pg_indexes i
      where i.schemaname = 'public'
        and i.tablename = 'community_memberships'
        and i.indexname = 'community_memberships_management_key_key'
    ) as management_key_unique_index_count
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
    ) as direct_membership_write_count
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
    'membership_management_delegation_rpc_exists'::text as check_name,
    case
      when list_count = 1
       and set_status_count = 1
       and grant_manager_count = 1
       and revoke_manager_count = 1
      then 'ok'
      else 'review'
    end as status,
    concat(
      'list=', list_count,
      ',set_status=', set_status_count,
      ',grant_manager=', grant_manager_count,
      ',revoke_manager=', revoke_manager_count
    ) as result_value,
    'The four 085 RPCs should exist with the reviewed signatures.'::text as note
  from function_summary

  union all
  select
    20,
    'membership_management_delegation_rpc_security',
    case
      when security_definer_count = 4
       and search_path_public_count = 4
      then 'ok'
      else 'review'
    end,
    concat('security_definer=', security_definer_count, ',search_path_public=', search_path_public_count),
    'All four 085 RPCs should be security definer with search_path=public.'
  from function_summary

  union all
  select
    30,
    'membership_management_delegation_execute_grants',
    case
      when authenticated_execute_count = 4
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
    'Delegation RPCs should be callable by authenticated users only; internal guards perform authorization.'
  from privilege_summary

  union all
  select
    40,
    'membership_management_delegation_authorization_guards',
    case
      when admin_guard_count = 4
       and approved_manager_guard_count = 2
       and admin_only_role_rpc_count = 2
      then 'ok'
      else 'review'
    end,
    concat(
      'admin_guard=', admin_guard_count,
      ',approved_manager_guard=', approved_manager_guard_count,
      ',admin_only_role_rpc=', admin_only_role_rpc_count
    ),
    'List/status RPCs allow admin or approved membership managers; manager-role grant/revoke RPCs are admin-only.'
  from function_summary

  union all
  select
    50,
    'membership_management_delegation_target_guards',
    case
      when self_action_guard_count = 3
       and target_admin_guard_count >= 3
       and target_manager_non_admin_guard_count = 1
      then 'ok'
      else 'review'
    end,
    concat(
      'self_action_guard=', self_action_guard_count,
      ',target_admin_guard=', target_admin_guard_count,
      ',target_manager_non_admin_guard=', target_manager_non_admin_guard_count
    ),
    'Status and manager-role mutations should block self actions, admin targets, and non-admin changes to membership managers.'
  from function_summary

  union all
  select
    60,
    'membership_management_delegation_status_scope',
    case
      when allowed_status_guard_count = 1
       and revoked_blocked_guard_count = 1
       and expected_transition_guard_count = 1
       and list_status_scope_count = 1
      then 'ok'
      else 'review'
    end,
    concat(
      'allowed_status_guard=', allowed_status_guard_count,
      ',revoked_blocked_guard=', revoked_blocked_guard_count,
      ',expected_transition_guard=', expected_transition_guard_count,
      ',list_status_scope=', list_status_scope_count
    ),
    'Normal management should cover pending/approved/rejected only, with revoked/blocked excluded.'
  from function_summary

  union all
  select
    70,
    'membership_management_delegation_role_scope',
    case
      when manager_grant_scope_count = 1
       and manager_revoke_scope_count = 1
       and grant_requires_approved_count = 1
      then 'ok'
      else 'review'
    end,
    concat(
      'manager_grant_scope=', manager_grant_scope_count,
      ',manager_revoke_scope=', manager_revoke_scope_count,
      ',grant_requires_approved=', grant_requires_approved_count
    ),
    'Admin-only role RPCs should affect only membership_approver and should not grant admin.'
  from function_summary

  union all
  select
    75,
    'membership_management_delegation_member_key_surface',
    case
      when mks.management_key_column_count = 1
       and mks.management_key_unique_index_count = 1
       and fs.list_returns_management_key_count = 1
       and fs.target_member_key_lookup_count = 3
       and fs.returns_user_id_column_count = 0
      then 'ok'
      else 'review'
    end,
    concat(
      'management_key_column=', mks.management_key_column_count,
      ',management_key_unique_index=', mks.management_key_unique_index_count,
      ',list_returns_management_key=', fs.list_returns_management_key_count,
      ',target_member_key_lookup=', fs.target_member_key_lookup_count,
      ',returns_user_id_column=', fs.returns_user_id_column_count
    ),
    'Management RPCs should use the opaque management_key surface and should not return user_id columns.'
  from function_summary fs
  cross join membership_key_schema mks

  union all
  select
    80,
    'membership_management_delegation_review_note_guard',
    case when review_note_guard_count = 1 then 'ok' else 'review' end,
    review_note_guard_count::text,
    'Status switching should keep the review note length guard.'
  from function_summary

  union all
  select
    90,
    'membership_management_delegation_no_email_surface',
    case when email_pattern_count = 0 then 'ok' else 'review' end,
    concat('email_pattern=', email_pattern_count),
    'The new management RPC definitions should not reference or return email.'
  from function_summary

  union all
  select
    100,
    'membership_management_delegation_no_direct_table_write',
    case when direct_membership_write_count = 0 then 'ok' else 'review' end,
    direct_membership_write_count::text,
    'community_memberships direct write grants for web roles should remain closed.'
  from table_privileges

  union all
  select
    110,
    'membership_management_delegation_public_profiles_exposure',
    case when risky_column_count = 0 then 'ok' else 'review' end,
    concat('risky_columns=', risky_column_count),
    'public_profiles should still avoid membership or role state columns.'
  from public_profiles_exposure

  union all
  select
    999,
    'post_apply_ready_for_membership_management_delegation_qa',
    case
      when fs.list_count = 1
       and fs.set_status_count = 1
       and fs.grant_manager_count = 1
       and fs.revoke_manager_count = 1
       and fs.security_definer_count = 4
       and fs.search_path_public_count = 4
       and ps.authenticated_execute_count = 4
       and ps.anon_execute_count = 0
       and ps.public_execute_count = 0
       and fs.admin_guard_count = 4
       and fs.approved_manager_guard_count = 2
       and fs.admin_only_role_rpc_count = 2
       and fs.self_action_guard_count = 3
       and fs.target_admin_guard_count >= 3
       and fs.target_manager_non_admin_guard_count = 1
       and fs.allowed_status_guard_count = 1
       and fs.revoked_blocked_guard_count = 1
       and fs.expected_transition_guard_count = 1
       and fs.list_status_scope_count = 1
      and fs.manager_grant_scope_count = 1
      and fs.manager_revoke_scope_count = 1
      and fs.grant_requires_approved_count = 1
      and mks.management_key_column_count = 1
      and mks.management_key_unique_index_count = 1
      and fs.list_returns_management_key_count = 1
      and fs.target_member_key_lookup_count = 3
      and fs.returns_user_id_column_count = 0
      and fs.review_note_guard_count = 1
       and fs.email_pattern_count = 0
       and tp.direct_membership_write_count = 0
       and ppe.risky_column_count = 0
      then 'ok'
      else 'review'
    end,
    case
      when fs.list_count = 1
       and fs.set_status_count = 1
       and fs.grant_manager_count = 1
       and fs.revoke_manager_count = 1
       and fs.security_definer_count = 4
       and fs.search_path_public_count = 4
       and ps.authenticated_execute_count = 4
       and ps.anon_execute_count = 0
       and ps.public_execute_count = 0
       and fs.admin_guard_count = 4
       and fs.approved_manager_guard_count = 2
       and fs.admin_only_role_rpc_count = 2
       and fs.self_action_guard_count = 3
       and fs.target_admin_guard_count >= 3
       and fs.target_manager_non_admin_guard_count = 1
       and fs.allowed_status_guard_count = 1
       and fs.revoked_blocked_guard_count = 1
       and fs.expected_transition_guard_count = 1
       and fs.list_status_scope_count = 1
      and fs.manager_grant_scope_count = 1
      and fs.manager_revoke_scope_count = 1
      and fs.grant_requires_approved_count = 1
      and mks.management_key_column_count = 1
      and mks.management_key_unique_index_count = 1
      and fs.list_returns_management_key_count = 1
      and fs.target_member_key_lookup_count = 3
      and fs.returns_user_id_column_count = 0
      and fs.review_note_guard_count = 1
       and fs.email_pattern_count = 0
       and tp.direct_membership_write_count = 0
       and ppe.risky_column_count = 0
      then 'true'
      else 'false'
    end,
    'If ok, proceed to membership management delegation functional QA and UI implementation gates.'
  from function_summary fs
  cross join membership_key_schema mks
  cross join privilege_summary ps
  cross join table_privileges tp
  cross join public_profiles_exposure ppe
)
select
  check_name,
  status,
  result_value,
  note
from output_rows
order by sort_order;
