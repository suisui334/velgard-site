-- 091_membership_manager_grant_role_conflict_fix_post_apply_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Confirm 090 replaced grant_membership_manager(uuid) while preserving the
--   reviewed security surface and removing the ambiguous conflict target.
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
    and p.proname = 'grant_membership_manager'
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
patterns as (
  select
    count(*) filter (
      where signature = 'grant_membership_manager(uuid)'
        and arguments_text = 'p_target_member_key uuid'
    ) as signature_count,
    count(*) filter (
      where result_text ilike '%member_key%'
        and result_text ilike '%role%'
        and result_text ilike '%membership_status%'
    ) as return_shape_count,
    count(*) filter (
      where security_definer
        and function_config ilike '%search_path=public%'
    ) as security_count,
    count(*) filter (
      where function_def ilike '%if v_actor_id is null or not coalesce(public.is_admin(), false)%'
    ) as admin_guard_count,
    count(*) filter (
      where function_def ilike '%cm.management_key = p_target_member_key%'
    ) as management_key_lookup_count,
    count(*) filter (
      where function_def ilike '%v_target_user_id = v_actor_id%'
    ) as self_guard_count,
    count(*) filter (
      where function_def ilike '%ur_admin.role = ''admin''%'
    ) as target_admin_guard_count,
    count(*) filter (
      where function_def ilike '%v_status is distinct from ''approved''%'
    ) as approved_guard_count,
    count(*) filter (
      where function_def ilike '%from public.profiles p%'
        and function_def ilike '%p.id = v_target_user_id%'
    ) as profile_guard_count,
    count(*) filter (
      where function_def ilike '%insert into public.user_roles (user_id, role)%'
        and function_def ilike '%values (v_target_user_id, ''membership_approver'')%'
    ) as insert_scope_count,
    count(*) filter (
      where function_def ilike '%on conflict do nothing%'
    ) as broad_conflict_safe_count,
    count(*) filter (
      where function_def ilike '%on conflict (user_id, role)%'
    ) as ambiguous_conflict_target_count,
    count(*) filter (
      where function_def ilike '%select%p_target_member_key,%''membership_approver''::text,%v_status::text%'
    ) as positional_return_count
  from function_privileges
),
direct_write_grants as (
  select
    count(*) filter (
      where grantee in ('PUBLIC', 'anon', 'authenticated')
        and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
    ) as user_roles_direct_write_grant_count
  from information_schema.table_privileges
  where table_schema = 'public'
    and table_name = 'user_roles'
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
  case when signature_count = 1 and return_shape_count = 1 then 'ok' else 'review' end as status,
  concat('signature=', signature_count, ',return_shape=', return_shape_count) as result_value,
  'Signature and return shape should remain compatible with the UI.'
from patterns

union all
select
  'grant_membership_manager_security',
  case
    when security_count = 1
     and (select authenticated_execute from function_privileges limit 1)
     and not (select anon_execute from function_privileges limit 1)
     and not (select public_execute from function_privileges limit 1)
    then 'ok'
    else 'review'
  end,
  concat(
    'security_definer=', coalesce((select security_definer::text from function_privileges limit 1), 'missing'),
    ',search_path_public=', coalesce(((select function_config from function_privileges limit 1) ilike '%search_path=public%')::text, 'missing'),
    ',authenticated=', coalesce((select authenticated_execute::text from function_privileges limit 1), 'missing'),
    ',anon=', coalesce((select anon_execute::text from function_privileges limit 1), 'missing'),
    ',public=', coalesce((select public_execute::text from function_privileges limit 1), 'missing')
  ),
  'Grant RPC should remain security definer, search_path=public, authenticated-only.'
from patterns

union all
select
  'grant_membership_manager_guards',
  case
    when admin_guard_count = 1
     and management_key_lookup_count = 1
     and self_guard_count = 1
     and target_admin_guard_count = 1
     and approved_guard_count = 1
     and profile_guard_count = 1
    then 'ok'
    else 'review'
  end,
  concat(
    'admin_guard=', admin_guard_count,
    ',management_key_lookup=', management_key_lookup_count,
    ',self_guard=', self_guard_count,
    ',target_admin_guard=', target_admin_guard_count,
    ',approved_guard=', approved_guard_count,
    ',profile_guard=', profile_guard_count
  ),
  'Actor and target guards should remain unchanged.'
from patterns

union all
select
  'grant_membership_manager_role_insert',
  case
    when insert_scope_count = 1
     and broad_conflict_safe_count = 1
     and ambiguous_conflict_target_count = 0
     and positional_return_count = 1
    then 'ok'
    else 'review'
  end,
  concat(
    'insert_scope=', insert_scope_count,
    ',on_conflict_do_nothing=', broad_conflict_safe_count,
    ',ambiguous_conflict_target=', ambiguous_conflict_target_count,
    ',positional_return=', positional_return_count
  ),
  '090 should avoid ON CONFLICT (user_id, role) and avoid role aliases in RETURN QUERY.'
from patterns

union all
select
  'user_roles_direct_write_surface',
  case when user_roles_direct_write_grant_count = 0 then 'ok' else 'review' end,
  concat('direct_write_grants=', user_roles_direct_write_grant_count),
  'Web roles should not receive direct user_roles write grants.'
from direct_write_grants

union all
select
  'public_profiles_membership_surface',
  case when risky_public_profile_column_count = 0 then 'ok' else 'review' end,
  concat('risky_columns=', risky_public_profile_column_count),
  'public_profiles should not expose membership, role, management key, email, or raw user id columns.'
from public_profile_surface

union all
select
  'post_apply_ready_for_membership_manager_grant_qa',
  case
    when (select signature_count from patterns) = 1
     and (select return_shape_count from patterns) = 1
     and (select security_count from patterns) = 1
     and (select admin_guard_count + management_key_lookup_count + self_guard_count + target_admin_guard_count + approved_guard_count + profile_guard_count from patterns) = 6
     and (select insert_scope_count from patterns) = 1
     and (select broad_conflict_safe_count from patterns) = 1
     and (select ambiguous_conflict_target_count from patterns) = 0
     and (select positional_return_count from patterns) = 1
     and (select user_roles_direct_write_grant_count from direct_write_grants) = 0
     and (select risky_public_profile_column_count from public_profile_surface) = 0
    then 'ok'
    else 'review'
  end,
  concat(
    'signature=', (select signature_count from patterns),
    ',guards=', (select admin_guard_count + management_key_lookup_count + self_guard_count + target_admin_guard_count + approved_guard_count + profile_guard_count from patterns),
    ',safe_conflict=', (select broad_conflict_safe_count from patterns),
    ',ambiguous_conflict=', (select ambiguous_conflict_target_count from patterns)
  ),
  'If ok, retry manager grant functional QA in a separate UI gate.'
;
