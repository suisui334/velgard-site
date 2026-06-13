-- 087_membership_manager_grant_diagnostics_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Diagnose why admin-side membership manager grant may fail after 085/086.
-- - Confirm the grant/revoke RPC argument names, grants, role-storage
--   prerequisites, and profile prerequisites without exposing concrete ids.
--
-- Safety:
-- - SELECT-only. Do not run as an apply script.
-- - Do not return concrete user ids, email addresses, management_key values,
--   URLs, JWTs, tokens, project refs, API keys, Webhook values, or secrets.
-- - Do not return full function bodies.

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
    pg_get_function_arguments(p.oid) as arguments_text,
    pg_get_function_result(p.oid) as result_text,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config,
    pg_get_functiondef(p.oid) as function_def,
    p.proacl,
    p.proowner
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
function_privileges as (
  select
    fr.*,
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
grant_rpc as (
  select *
  from function_privileges
  where proname = 'grant_membership_manager'
),
revoke_rpc as (
  select *
  from function_privileges
  where proname = 'revoke_membership_manager'
),
list_rpc as (
  select *
  from function_privileges
  where proname = 'list_membership_review_users'
),
grant_patterns as (
  select
    count(*) filter (
      where proname = 'grant_membership_manager'
        and signature = 'grant_membership_manager(uuid)'
        and arguments_text = 'p_target_member_key uuid'
    ) as grant_signature_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and result_text ilike '%member_key%'
        and result_text ilike '%role%'
        and result_text ilike '%membership_status%'
    ) as grant_return_shape_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and security_definer
        and function_config ilike '%search_path=public%'
    ) as grant_security_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%public.is_admin()%'
        and function_def not ilike '%is_membership_approver()%'
    ) as grant_admin_only_guard_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%cm.management_key = p_target_member_key%'
    ) as grant_management_key_lookup_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%v_status is distinct from ''approved''%'
    ) as grant_requires_approved_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%from public.profiles p%'
        and function_def ilike '%p.id = v_target_user_id%'
    ) as grant_requires_profile_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%values (v_target_user_id, ''membership_approver'')%'
        and function_def not ilike '%values (v_target_user_id, ''admin'')%'
    ) as grant_role_scope_count,
    count(*) filter (
      where proname = 'list_membership_review_users'
        and function_def ilike '%cm.management_key as member_key%'
    ) as list_returns_member_key_count,
    count(*) filter (
      where proname = 'list_membership_review_users'
        and function_def ilike '%can_manage_manager_role%'
        and function_def ilike '%cm.status = ''approved''%'
    ) as list_manager_action_status_guard_count,
    count(*) filter (
      where proname = 'list_membership_review_users'
        and function_def ilike '%can_manage_manager_role%'
        and function_def ilike '%p.id is not null%'
    ) as list_manager_action_profile_guard_count
  from function_rows
),
user_roles_unique_indexes as (
  select
    count(*) filter (
      where idx.indisunique
        and (
          select array_agg(att.attname order by key_cols.ordinality)
          from unnest(idx.indkey) with ordinality as key_cols(attnum, ordinality)
          join pg_attribute att
            on att.attrelid = idx.indrelid
           and att.attnum = key_cols.attnum
        ) = array['user_id', 'role']
    ) as user_role_unique_count,
    count(*) filter (
      where idx.indisprimary
        and (
          select array_agg(att.attname order by key_cols.ordinality)
          from unnest(idx.indkey) with ordinality as key_cols(attnum, ordinality)
          join pg_attribute att
            on att.attrelid = idx.indrelid
           and att.attnum = key_cols.attnum
        ) = array['user_id', 'role']
    ) as user_role_primary_count
  from pg_index idx
  where idx.indrelid = 'public.user_roles'::regclass
),
user_roles_constraints as (
  select
    count(*) filter (
      where conname = 'user_roles_role_check'
        and pg_get_constraintdef(oid) ilike '%membership_approver%'
    ) as approver_allowed_count
  from pg_constraint
  where conrelid = 'public.user_roles'::regclass
),
profile_membership_counts as (
  select
    count(*) filter (where cm.status = 'approved') as approved_membership_count,
    count(*) filter (
      where cm.status = 'approved'
        and p.id is null
    ) as approved_without_profile_count,
    count(*) filter (
      where cm.status = 'approved'
        and p.id is null
        and not exists (
          select 1
          from public.user_roles ur_admin
          where ur_admin.user_id = cm.user_id
            and ur_admin.role = 'admin'
        )
        and not exists (
          select 1
          from public.user_roles ur_manager
          where ur_manager.user_id = cm.user_id
            and ur_manager.role = 'membership_approver'
        )
    ) as approved_normal_without_profile_count,
    count(*) filter (
      where cm.status = 'approved'
        and exists (
          select 1
          from public.user_roles ur_manager
          where ur_manager.user_id = cm.user_id
            and ur_manager.role = 'membership_approver'
        )
    ) as approved_existing_manager_count
  from public.community_memberships cm
  left join public.profiles p
    on p.id = cm.user_id
),
public_profile_surface as (
  select
    count(*) filter (
      where column_name ilike any (array[
        '%membership%',
        '%role%',
        '%management%',
        '%email%',
        '%user_id%'
      ])
    ) as risky_public_profile_column_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'public_profiles'
)
select
  'grant_membership_manager_signature' as check_name,
  case when gp.grant_signature_count = 1 then 'ok' else 'review' end as status,
  concat(
    'signature=', coalesce((select signature from grant_rpc limit 1), 'missing'),
    ',args=', coalesce((select arguments_text from grant_rpc limit 1), 'missing')
  ) as result_value,
  'Grant RPC should be grant_membership_manager(uuid) with p_target_member_key uuid.' as note
from grant_patterns gp

union all
select
  'grant_membership_manager_return_shape',
  case when gp.grant_return_shape_count = 1 then 'ok' else 'review' end,
  coalesce((select result_text from grant_rpc limit 1), 'missing'),
  'Grant RPC should return only action-safe result columns, not raw ids or email.'
from grant_patterns gp

union all
select
  'grant_membership_manager_security',
  case
    when gp.grant_security_count = 1
     and (select authenticated_execute from grant_rpc limit 1)
     and not (select anon_execute from grant_rpc limit 1)
     and not (select public_execute from grant_rpc limit 1)
    then 'ok'
    else 'review'
  end,
  concat(
    'security_definer=', coalesce((select security_definer::text from grant_rpc limit 1), 'missing'),
    ',search_path_public=', coalesce(((select function_config from grant_rpc limit 1) ilike '%search_path=public%')::text, 'missing'),
    ',authenticated=', coalesce((select authenticated_execute::text from grant_rpc limit 1), 'missing'),
    ',anon=', coalesce((select anon_execute::text from grant_rpc limit 1), 'missing'),
    ',public=', coalesce((select public_execute::text from grant_rpc limit 1), 'missing')
  ),
  'Grant RPC should be security definer, search_path=public, authenticated-only.'
from grant_patterns gp

union all
select
  'grant_membership_manager_static_guards',
  case
    when gp.grant_admin_only_guard_count = 1
     and gp.grant_management_key_lookup_count = 1
     and gp.grant_requires_approved_count = 1
     and gp.grant_requires_profile_count = 1
     and gp.grant_role_scope_count = 1
    then 'ok'
    else 'review'
  end,
  concat(
    'admin_only=', gp.grant_admin_only_guard_count,
    ',management_key_lookup=', gp.grant_management_key_lookup_count,
    ',approved_required=', gp.grant_requires_approved_count,
    ',profile_required=', gp.grant_requires_profile_count,
    ',role_scope=', gp.grant_role_scope_count
  ),
  'Grant RPC should be admin-only, use member_key lookup, require approved target, require profile row, and grant only membership_approver.'
from grant_patterns gp

union all
select
  'list_membership_review_users_manager_action_surface',
  case
    when gp.list_returns_member_key_count = 1
     and gp.list_manager_action_status_guard_count = 1
    then 'ok'
    else 'review'
  end,
  concat(
    'returns_member_key=', gp.list_returns_member_key_count,
    ',approved_status_guard=', gp.list_manager_action_status_guard_count,
    ',profile_guard=', gp.list_manager_action_profile_guard_count
  ),
  'If profile_guard=0, the UI may show manager-role action for approved memberships whose role insert would fail because no profile row exists.'
from grant_patterns gp

union all
select
  'user_roles_grant_prerequisites',
  case
    when uri.user_role_unique_count >= 1
     and urc.approver_allowed_count >= 1
    then 'ok'
    else 'review'
  end,
  concat(
    'unique_user_role=', uri.user_role_unique_count,
    ',primary_user_role=', uri.user_role_primary_count,
    ',approver_allowed=', urc.approver_allowed_count
  ),
  'Role storage should support duplicate-safe membership_approver grants.'
from user_roles_unique_indexes uri
cross join user_roles_constraints urc

union all
select
  'approved_membership_profile_prerequisite',
  case
    when pmc.approved_without_profile_count = 0 then 'ok'
    else 'review'
  end,
  concat(
    'approved_total=', pmc.approved_membership_count,
    ',approved_without_profile=', pmc.approved_without_profile_count,
    ',approved_normal_without_profile=', pmc.approved_normal_without_profile_count,
    ',approved_existing_manager=', pmc.approved_existing_manager_count
  ),
  'Approved memberships without profile rows cannot receive user_roles because user_roles references profiles.'
from profile_membership_counts pmc

union all
select
  'public_profiles_membership_management_surface',
  case when pps.risky_public_profile_column_count = 0 then 'ok' else 'review' end,
  concat('risky_columns=', pps.risky_public_profile_column_count),
  'public_profiles should not expose membership, role, management key, email, or raw user id columns.'
from public_profile_surface pps

union all
select
  'membership_manager_grant_diagnostics_next_step',
  case
    when uri.user_role_unique_count = 0 then 'review'
    when urc.approver_allowed_count = 0 then 'review'
    when pmc.approved_without_profile_count > 0 then 'review'
    else 'ok'
  end,
  concat(
    'unique_user_role=', uri.user_role_unique_count,
    ',approver_allowed=', urc.approver_allowed_count,
    ',approved_without_profile=', pmc.approved_without_profile_count,
    ',list_profile_guard=', gp.list_manager_action_profile_guard_count
  ),
  'If review, prepare the narrow next gate indicated by the failing prerequisite; otherwise inspect the exact UI actor/target condition without recording identifiers.'
from user_roles_unique_indexes uri
cross join user_roles_constraints urc
cross join profile_membership_counts pmc
cross join grant_patterns gp;
