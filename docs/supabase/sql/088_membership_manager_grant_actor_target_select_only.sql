-- 088_membership_manager_grant_actor_target_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Further diagnose admin-side membership manager grant failures after 087.
-- - Narrow remaining causes to actor/target guards, user_roles structural
--   requirements, or runtime policy/owner behavior without exposing concrete
--   identifiers.
--
-- Safety:
-- - SELECT-only. Do not run as an apply script.
-- - Do not return concrete user ids, email addresses, management_key values,
--   URLs, JWTs, tokens, project refs, API keys, Webhook values, or secrets.
-- - Do not return full function bodies.

with object_refs as (
  select
    to_regclass('public.community_memberships') as memberships_regclass,
    to_regclass('public.profiles') as profiles_regclass,
    to_regclass('public.user_roles') as user_roles_regclass,
    to_regclass('public.public_profiles') as public_profiles_regclass
),
role_refs as (
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
      'grant_membership_manager',
      'revoke_membership_manager',
      'is_admin'
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
list_rpc as (
  select *
  from function_privileges
  where proname = 'list_membership_review_users'
),
grant_static_patterns as (
  select
    count(*) filter (
      where proname = 'grant_membership_manager'
        and signature = 'grant_membership_manager(uuid)'
        and arguments_text = 'p_target_member_key uuid'
    ) as signature_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and result_text ilike '%member_key%'
        and result_text ilike '%role%'
        and result_text ilike '%membership_status%'
    ) as return_shape_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%if v_actor_id is null or not coalesce(public.is_admin(), false)%'
    ) as admin_only_guard_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%cm.management_key = p_target_member_key%'
    ) as management_key_lookup_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%v_target_user_id = v_actor_id%'
    ) as self_guard_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%ur_admin.role = ''admin''%'
    ) as target_admin_guard_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%v_status is distinct from ''approved''%'
    ) as approved_status_guard_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%from public.profiles p%'
        and function_def ilike '%p.id = v_target_user_id%'
    ) as profile_guard_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%insert into public.user_roles (user_id, role)%'
        and function_def ilike '%values (v_target_user_id, ''membership_approver'')%'
    ) as role_insert_scope_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%on conflict (user_id, role) do nothing%'
    ) as duplicate_safe_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%using errcode = ''42501''%'
    ) as permission_error_code_count,
    count(*) filter (
      where proname = 'grant_membership_manager'
        and function_def ilike '%using errcode = ''22023''%'
    ) as invalid_target_error_code_count
  from function_rows
),
list_static_patterns as (
  select
    count(*) filter (
      where proname = 'list_membership_review_users'
        and function_def ilike '%cm.management_key as member_key%'
    ) as returns_member_key_count,
    count(*) filter (
      where proname = 'list_membership_review_users'
        and function_def ilike '%can_manage_manager_role%'
        and function_def ilike '%v_is_admin%'
        and function_def ilike '%cm.status = ''approved''%'
    ) as manager_button_admin_status_guard_count,
    count(*) filter (
      where proname = 'list_membership_review_users'
        and function_def ilike '%can_manage_manager_role%'
        and function_def ilike '%ur_admin_guard.role = ''admin''%'
    ) as manager_button_admin_target_guard_count
  from function_rows
),
user_roles_shape as (
  select
    count(*) filter (where a.attname = 'user_id') as has_user_id_count,
    count(*) filter (where a.attname = 'role') as has_role_count,
    count(*) filter (where a.attname = 'created_at') as has_created_at_count,
    count(*) filter (
      where a.attnotnull
        and not a.atthasdef
        and coalesce(a.attidentity::text, '') = ''
        and coalesce(a.attgenerated::text, '') = ''
        and a.attname::text not in ('user_id', 'role')
    ) as extra_required_column_count
  from pg_attribute a
  where a.attrelid = (select user_roles_regclass from object_refs)
    and a.attnum > 0
    and not a.attisdropped
),
user_roles_unique_indexes as (
  select
    count(*) filter (
      where idx.indisunique
        and (
          select array_agg(att.attname::text order by key_cols.ordinality)
          from unnest(idx.indkey) with ordinality as key_cols(attnum, ordinality)
          join pg_attribute att
            on att.attrelid = idx.indrelid
           and att.attnum = key_cols.attnum
        ) = array['user_id', 'role']::text[]
    ) as user_role_unique_count,
    count(*) filter (
      where idx.indisprimary
        and (
          select array_agg(att.attname::text order by key_cols.ordinality)
          from unnest(idx.indkey) with ordinality as key_cols(attnum, ordinality)
          join pg_attribute att
            on att.attrelid = idx.indrelid
           and att.attnum = key_cols.attnum
        ) = array['user_id', 'role']::text[]
    ) as user_role_primary_count
  from pg_index idx
  where idx.indrelid = (select user_roles_regclass from object_refs)
),
user_roles_constraints as (
  select
    count(*) filter (
      where conname = 'user_roles_role_check'
        and pg_get_constraintdef(oid) ilike '%membership_approver%'
    ) as approver_allowed_count
  from pg_constraint
  where conrelid = (select user_roles_regclass from object_refs)
),
user_roles_rls as (
  select
    coalesce(c.relrowsecurity, false) as rls_enabled,
    coalesce(c.relforcerowsecurity, false) as force_rls,
    coalesce(owner_role.rolbypassrls, false) as table_owner_bypassrls,
    coalesce(grant_owner_role.rolbypassrls, false) as grant_function_owner_bypassrls,
    coalesce(c.relowner = (select proowner from grant_rpc limit 1), false) as grant_function_owner_matches_table_owner
  from object_refs refs
  left join pg_class c
    on c.oid = refs.user_roles_regclass
  left join pg_roles owner_role
    on owner_role.oid = c.relowner
  left join grant_rpc gr
    on true
  left join pg_roles grant_owner_role
    on grant_owner_role.oid = gr.proowner
),
user_roles_direct_write_grants as (
  select
    count(*) filter (
      where grantee in ('PUBLIC', 'anon', 'authenticated')
        and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
    ) as direct_write_grant_count
  from information_schema.table_privileges
  where table_schema = 'public'
    and table_name = 'user_roles'
),
candidate_counts as (
  select
    count(*) filter (
      where ur_admin.user_id is not null
    ) as admin_role_count,
    count(*) filter (
      where cm.status = 'approved'
        and p.id is not null
        and ur_admin.user_id is null
        and ur_manager.user_id is null
    ) as approved_normal_grantable_count,
    count(*) filter (
      where cm.status = 'approved'
        and p.id is null
        and ur_admin.user_id is null
        and ur_manager.user_id is null
    ) as approved_normal_without_profile_count,
    count(*) filter (
      where cm.status = 'approved'
        and ur_admin.user_id is not null
    ) as approved_admin_target_count,
    count(*) filter (
      where cm.status = 'approved'
        and ur_manager.user_id is not null
    ) as approved_existing_manager_count,
    count(*) filter (
      where cm.status in ('pending', 'rejected', 'revoked', 'blocked')
        and p.id is not null
        and ur_admin.user_id is null
    ) as non_approved_non_admin_count
  from public.community_memberships cm
  left join public.profiles p
    on p.id = cm.user_id
  left join public.user_roles ur_admin
    on ur_admin.user_id = cm.user_id
   and ur_admin.role = 'admin'
  left join public.user_roles ur_manager
    on ur_manager.user_id = cm.user_id
   and ur_manager.role = 'membership_approver'
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
  'grant_rpc_signature_security' as check_name,
  case
    when gps.signature_count = 1
     and gps.return_shape_count = 1
     and (select security_definer from grant_rpc limit 1)
     and ((select function_config from grant_rpc limit 1) ilike '%search_path=public%')
     and (select authenticated_execute from grant_rpc limit 1)
     and not (select anon_execute from grant_rpc limit 1)
     and not (select public_execute from grant_rpc limit 1)
    then 'ok'
    else 'review'
  end as status,
  concat(
    'signature=', gps.signature_count,
    ',return_shape=', gps.return_shape_count,
    ',security_definer=', coalesce((select security_definer::text from grant_rpc limit 1), 'missing'),
    ',authenticated=', coalesce((select authenticated_execute::text from grant_rpc limit 1), 'missing'),
    ',anon=', coalesce((select anon_execute::text from grant_rpc limit 1), 'missing'),
    ',public=', coalesce((select public_execute::text from grant_rpc limit 1), 'missing')
  ) as result_value,
  'Grant RPC should expose only the reviewed authenticated RPC surface.'
from grant_static_patterns gps

union all
select
  'grant_rpc_actor_target_guards',
  case
    when admin_only_guard_count = 1
     and management_key_lookup_count = 1
     and self_guard_count = 1
     and target_admin_guard_count = 1
     and approved_status_guard_count = 1
     and profile_guard_count = 1
    then 'ok'
    else 'review'
  end,
  concat(
    'admin_only=', admin_only_guard_count,
    ',management_key_lookup=', management_key_lookup_count,
    ',self_guard=', self_guard_count,
    ',target_admin_guard=', target_admin_guard_count,
    ',approved_guard=', approved_status_guard_count,
    ',profile_guard=', profile_guard_count
  ),
  'Static guard review only; the concrete clicked target is not returned by this diagnostic.'
from grant_static_patterns

union all
select
  'grant_rpc_role_insert_surface',
  case
    when role_insert_scope_count = 1
     and duplicate_safe_count = 1
     and permission_error_code_count >= 1
     and invalid_target_error_code_count >= 1
    then 'ok'
    else 'review'
  end,
  concat(
    'role_insert_scope=', role_insert_scope_count,
    ',duplicate_safe=', duplicate_safe_count,
    ',permission_error_code=', permission_error_code_count,
    ',invalid_target_error_code=', invalid_target_error_code_count
  ),
  'Grant RPC should only add membership_approver and expose safe SQLSTATE categories.'
from grant_static_patterns

union all
select
  'list_rpc_manager_action_surface',
  case
    when lsp.returns_member_key_count = 1
     and lsp.manager_button_admin_status_guard_count = 1
     and lsp.manager_button_admin_target_guard_count = 1
     and (select authenticated_execute from list_rpc limit 1)
     and not (select anon_execute from list_rpc limit 1)
     and not (select public_execute from list_rpc limit 1)
    then 'ok'
    else 'review'
  end,
  concat(
    'returns_member_key=', lsp.returns_member_key_count,
    ',admin_status_guard=', lsp.manager_button_admin_status_guard_count,
    ',admin_target_guard=', lsp.manager_button_admin_target_guard_count,
    ',authenticated=', coalesce((select authenticated_execute::text from list_rpc limit 1), 'missing'),
    ',anon=', coalesce((select anon_execute::text from list_rpc limit 1), 'missing'),
    ',public=', coalesce((select public_execute::text from list_rpc limit 1), 'missing')
  ),
  'List RPC should expose action-safe keys only to admin/approved managers.'
from list_static_patterns lsp

union all
select
  'user_roles_insert_prerequisites',
  case
    when urs.has_user_id_count = 1
     and urs.has_role_count = 1
     and urs.extra_required_column_count = 0
     and uri.user_role_unique_count >= 1
     and urc.approver_allowed_count >= 1
    then 'ok'
    else 'review'
  end,
  concat(
    'has_user_id=', urs.has_user_id_count,
    ',has_role=', urs.has_role_count,
    ',extra_required_columns=', urs.extra_required_column_count,
    ',unique_user_role=', uri.user_role_unique_count,
    ',approver_allowed=', urc.approver_allowed_count
  ),
  'The grant RPC writes only user_id and role; extra required columns would explain runtime failure.'
from user_roles_shape urs
cross join user_roles_unique_indexes uri
cross join user_roles_constraints urc

union all
select
  'user_roles_rls_owner_runtime_surface',
  case
    when not urr.force_rls
     and (
       urr.grant_function_owner_matches_table_owner
       or urr.grant_function_owner_bypassrls
     )
    then 'ok'
    else 'review'
  end,
  concat(
    'rls_enabled=', urr.rls_enabled,
    ',force_rls=', urr.force_rls,
    ',function_owner_matches_table_owner=', urr.grant_function_owner_matches_table_owner,
    ',function_owner_bypassrls=', urr.grant_function_owner_bypassrls,
    ',table_owner_bypassrls=', urr.table_owner_bypassrls
  ),
  'Reviews whether a security definer grant RPC is likely to bypass user_roles RLS as intended.'
from user_roles_rls urr

union all
select
  'user_roles_direct_write_surface',
  case when direct_write_grant_count = 0 then 'ok' else 'review' end,
  concat('direct_write_grants=', direct_write_grant_count),
  'Web roles should not receive direct write grants on user_roles.'
from user_roles_direct_write_grants

union all
select
  'membership_manager_target_pool',
  case
    when admin_role_count >= 1
     and approved_normal_grantable_count >= 1
     and approved_normal_without_profile_count = 0
    then 'ok'
    else 'review'
  end,
  concat(
    'admin_actors=', admin_role_count,
    ',approved_normal_grantable=', approved_normal_grantable_count,
    ',approved_normal_without_profile=', approved_normal_without_profile_count,
    ',approved_admin_targets=', approved_admin_target_count,
    ',approved_existing_manager=', approved_existing_manager_count,
    ',non_approved_non_admin=', non_approved_non_admin_count
  ),
  'Counts target classes without returning concrete identifiers; self-target cannot be proven without a concrete click target.'
from candidate_counts

union all
select
  'public_profiles_membership_surface',
  case when risky_public_profile_column_count = 0 then 'ok' else 'review' end,
  concat('risky_columns=', risky_public_profile_column_count),
  'public_profiles should not expose membership, role, management key, email, or raw user id columns.'
from public_profile_surface

union all
select
  'membership_manager_grant_next_step',
  case
    when (select extra_required_column_count from user_roles_shape) = 0
     and (select force_rls from user_roles_rls) = false
     and (select approved_normal_grantable_count from candidate_counts) >= 1
    then 'ok'
    else 'review'
  end,
  concat(
    'structural_insert_ready=', ((select extra_required_column_count from user_roles_shape) = 0),
    ',force_rls=', (select force_rls from user_roles_rls),
    ',grantable_targets=', (select approved_normal_grantable_count from candidate_counts)
  ),
  'If this is review, inspect the matching check above before retrying manager grant.'
;
