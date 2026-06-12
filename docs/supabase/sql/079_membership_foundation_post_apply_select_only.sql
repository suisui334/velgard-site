-- 079_membership_foundation_post_apply_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Confirm the separately approved 078 membership foundation apply.
-- - Return status/count/boolean-style results only.
-- - Do not return concrete user ids, emails, session ids, full URLs, project
--   refs, tokens, keys, or secrets.

with role_refs as (
  select
    to_regrole('anon') as anon_role,
    to_regrole('authenticated') as authenticated_role
),
object_refs as (
  select
    to_regclass('public.community_memberships') as community_memberships_regclass,
    to_regclass('public.user_roles') as user_roles_regclass
),
table_rows as (
  select
    c.relname as table_name,
    c.relrowsecurity as rls_enabled
  from pg_class c
  join pg_namespace n
    on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in ('community_memberships', 'user_roles')
    and c.relkind = 'r'
),
membership_columns as (
  select
    count(*) filter (where column_name = 'user_id') as user_id_count,
    count(*) filter (where column_name = 'status') as status_count,
    count(*) filter (where column_name = 'approved_at') as approved_at_count,
    count(*) filter (where column_name = 'approved_by') as approved_by_count,
    count(*) filter (where column_name = 'rejected_at') as rejected_at_count,
    count(*) filter (where column_name = 'rejected_by') as rejected_by_count,
    count(*) filter (where column_name = 'revoked_at') as revoked_at_count,
    count(*) filter (where column_name = 'revoked_by') as revoked_by_count,
    count(*) filter (where column_name = 'blocked_at') as blocked_at_count,
    count(*) filter (where column_name = 'blocked_by') as blocked_by_count,
    count(*) filter (where column_name = 'review_note') as review_note_count,
    count(*) filter (where column_name = 'created_at') as created_at_count,
    count(*) filter (where column_name = 'updated_at') as updated_at_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'community_memberships'
),
membership_constraints as (
  select
    count(*) filter (
      where conname = 'community_memberships_status_check'
        and pg_get_constraintdef(oid) ilike '%pending%'
        and pg_get_constraintdef(oid) ilike '%approved%'
        and pg_get_constraintdef(oid) ilike '%rejected%'
        and pg_get_constraintdef(oid) ilike '%revoked%'
        and pg_get_constraintdef(oid) ilike '%blocked%'
    ) as status_check_count,
    count(*) filter (
      where conname = 'community_memberships_review_note_length_check'
    ) as review_note_length_check_count
  from pg_constraint
  where conrelid = (select community_memberships_regclass from object_refs)
),
role_constraints as (
  select
    count(*) filter (
      where conrelid = (select user_roles_regclass from object_refs)
        and pg_get_constraintdef(oid) ilike '%membership_approver%'
    ) as membership_approver_allowed_count
  from pg_constraint
  where conrelid = (select user_roles_regclass from object_refs)
),
policy_summary as (
  select
    count(*) filter (where policyname = 'community_memberships_select_own') as select_own_count,
    count(*) filter (where policyname = 'community_memberships_select_admin_approver') as select_admin_approver_count
  from pg_policies
  where schemaname = 'public'
    and tablename = 'community_memberships'
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
membership_counts as (
  select
    (select count(*) from auth.users) as auth_user_count,
    (select count(*) from public.community_memberships) as membership_count,
    (
      select count(*)
      from auth.users au
      where not exists (
        select 1
        from public.community_memberships cm
        where cm.user_id = au.id
      )
    ) as missing_membership_count,
    (select count(*) from public.community_memberships where status = 'approved') as approved_count,
    (select count(*) from public.community_memberships where status = 'pending') as pending_count,
    (select count(*) from public.community_memberships where status in ('rejected', 'revoked', 'blocked')) as restricted_count
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
      'has_role',
      'is_approved_member',
      'is_membership_approver',
      'get_my_membership_status',
      'handle_new_auth_user_membership'
    )
),
function_summary as (
  select
    count(*) filter (where proname = 'has_role' and signature = 'has_role(text)') as has_role_count,
    count(*) filter (where proname = 'is_approved_member' and signature = 'is_approved_member()') as is_approved_member_count,
    count(*) filter (where proname = 'is_membership_approver' and signature = 'is_membership_approver()') as is_membership_approver_count,
    count(*) filter (where proname = 'get_my_membership_status' and signature = 'get_my_membership_status()') as get_my_membership_status_count,
    count(*) filter (where proname = 'handle_new_auth_user_membership' and signature = 'handle_new_auth_user_membership()') as trigger_function_count,
    count(*) filter (where security_definer) as security_definer_count,
    count(*) filter (where function_config ilike '%search_path=public%') as search_path_public_count,
    count(*) filter (where proname = 'has_role' and function_def ilike '%membership_approver%') as has_role_mentions_approver_count,
    count(*) filter (where proname = 'is_approved_member' and function_def ilike '%status = ''approved''%') as approved_status_pattern_count,
    count(*) filter (where proname = 'is_membership_approver' and function_def ilike '%membership_approver%') as approver_pattern_count
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
    bool_and(authenticated_execute) filter (
      where proname in ('has_role', 'is_approved_member', 'is_membership_approver', 'get_my_membership_status')
    ) as web_helpers_authenticated_execute,
    bool_or(anon_execute) filter (
      where proname in ('has_role', 'is_approved_member', 'is_membership_approver', 'get_my_membership_status')
    ) as web_helpers_anon_execute,
    bool_or(public_execute) filter (
      where proname in ('has_role', 'is_approved_member', 'is_membership_approver', 'get_my_membership_status')
    ) as web_helpers_public_execute,
    bool_or(authenticated_execute or anon_execute or public_execute) filter (
      where proname = 'handle_new_auth_user_membership'
    ) as trigger_function_external_execute
  from function_privileges
),
trigger_summary as (
  select
    count(*) filter (
      where t.tgname = 'on_auth_user_created_create_membership'
        and p.proname = 'handle_new_auth_user_membership'
    ) as membership_trigger_count
  from pg_trigger t
  join pg_proc p
    on p.oid = t.tgfoid
  join pg_class c
    on c.oid = t.tgrelid
  join pg_namespace n
    on n.oid = c.relnamespace
  where n.nspname = 'auth'
    and c.relname = 'users'
    and not t.tgisinternal
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
    'community_memberships_table_exists'::text as check_name,
    case when exists (select 1 from table_rows where table_name = 'community_memberships') then 'ok' else 'review' end as status,
    (select count(*)::text from table_rows where table_name = 'community_memberships') as result_value,
    'The private membership table should exist after 078.'::text as note

  union all
  select
    20,
    'community_memberships_rls_enabled',
    case when exists (select 1 from table_rows where table_name = 'community_memberships' and rls_enabled) then 'ok' else 'review' end,
    (select coalesce(bool_or(rls_enabled), false)::text from table_rows where table_name = 'community_memberships'),
    'RLS should be enabled on community_memberships.'

  union all
  select
    30,
    'community_memberships_columns',
    case
      when user_id_count = 1
       and status_count = 1
       and approved_at_count = 1
       and approved_by_count = 1
       and rejected_at_count = 1
       and rejected_by_count = 1
       and revoked_at_count = 1
       and revoked_by_count = 1
       and blocked_at_count = 1
       and blocked_by_count = 1
       and review_note_count = 1
       and created_at_count = 1
       and updated_at_count = 1
      then 'ok'
      else 'review'
    end,
    concat(
      'user_id=', user_id_count,
      ',status=', status_count,
      ',decision_columns=',
      approved_at_count + approved_by_count + rejected_at_count + rejected_by_count +
      revoked_at_count + revoked_by_count + blocked_at_count + blocked_by_count,
      ',review_note=', review_note_count,
      ',timestamps=', created_at_count + updated_at_count
    ),
    'Expected minimum membership foundation columns.'
  from membership_columns

  union all
  select
    40,
    'community_memberships_status_constraints',
    case
      when status_check_count = 1
       and review_note_length_check_count = 1
      then 'ok'
      else 'review'
    end,
    concat('status_check=', status_check_count, ',review_note_length=', review_note_length_check_count),
    'Status must be constrained to pending/approved/rejected/revoked/blocked, with bounded review notes.'
  from membership_constraints

  union all
  select
    50,
    'community_memberships_policies',
    case
      when select_own_count = 1
       and select_admin_approver_count = 1
      then 'ok'
      else 'review'
    end,
    concat('select_own=', select_own_count, ',select_admin_approver=', select_admin_approver_count),
    'Foundation policies should support own-status and approver/admin review reads, while table grants remain closed.'
  from policy_summary

  union all
  select
    60,
    'community_memberships_direct_grants_closed',
    case
      when direct_write_count = 0
       and direct_select_count = 0
      then 'ok'
      else 'review'
    end,
    concat('direct_write=', direct_write_count, ',direct_select=', direct_select_count),
    'Web clients should use RPCs, not direct table grants, for membership state.'
  from table_privileges

  union all
  select
    70,
    'user_roles_membership_approver_allowed',
    case when membership_approver_allowed_count >= 1 then 'ok' else 'review' end,
    membership_approver_allowed_count::text,
    'Existing role storage should allow the limited membership_approver role after 078.'
  from role_constraints

  union all
  select
    80,
    'membership_existing_user_backfill',
    case
      when auth_user_count = membership_count
       and missing_membership_count = 0
      then 'ok'
      else 'review'
    end,
    concat(
      'auth_users=', auth_user_count,
      ',memberships=', membership_count,
      ',missing=', missing_membership_count,
      ',approved=', approved_count,
      ',pending=', pending_count,
      ',restricted=', restricted_count
    ),
    'Count-only check: existing auth users should have membership rows; initial existing users are expected to be approved.'
  from membership_counts

  union all
  select
    90,
    'membership_helpers_exist',
    case
      when has_role_count = 1
       and is_approved_member_count = 1
       and is_membership_approver_count = 1
       and get_my_membership_status_count = 1
       and trigger_function_count = 1
      then 'ok'
      else 'review'
    end,
    concat(
      'has_role=', has_role_count,
      ',is_approved_member=', is_approved_member_count,
      ',is_membership_approver=', is_membership_approver_count,
      ',get_my_membership_status=', get_my_membership_status_count,
      ',trigger_function=', trigger_function_count
    ),
    'Expected helper RPCs and trigger function should exist.'
  from function_summary

  union all
  select
    100,
    'membership_helpers_security',
    case
      when security_definer_count = 5
       and search_path_public_count = 5
      then 'ok'
      else 'review'
    end,
    concat('security_definer=', security_definer_count, ',search_path_public=', search_path_public_count),
    'All 078 helper functions should be security definer with search_path=public.'
  from function_summary

  union all
  select
    110,
    'membership_helper_patterns',
    case
      when has_role_mentions_approver_count = 1
       and approved_status_pattern_count = 1
       and approver_pattern_count = 1
      then 'ok'
      else 'review'
    end,
    concat(
      'has_role_mentions_approver=', has_role_mentions_approver_count,
      ',approved_status_pattern=', approved_status_pattern_count,
      ',approver_pattern=', approver_pattern_count
    ),
    'Static pattern check only; function bodies are not returned.'
  from function_summary

  union all
  select
    120,
    'membership_helper_execute_grants',
    case
      when coalesce(web_helpers_authenticated_execute, false)
       and not coalesce(web_helpers_anon_execute, false)
       and not coalesce(web_helpers_public_execute, false)
       and not coalesce(trigger_function_external_execute, false)
      then 'ok'
      else 'review'
    end,
    concat(
      'authenticated=', coalesce(web_helpers_authenticated_execute, false),
      ',anon=', coalesce(web_helpers_anon_execute, false),
      ',public=', coalesce(web_helpers_public_execute, false),
      ',trigger_external=', coalesce(trigger_function_external_execute, false)
    ),
    'Web helpers should be authenticated-only; the auth trigger function should not be directly executable by web roles.'
  from privilege_summary

  union all
  select
    130,
    'membership_new_user_pending_trigger',
    case when membership_trigger_count = 1 then 'ok' else 'review' end,
    membership_trigger_count::text,
    'A separate auth.users trigger should create pending membership rows for future signups.'
  from trigger_summary

  union all
  select
    140,
    'public_profiles_membership_not_exposed',
    case when risky_column_count = 0 then 'ok' else 'review' end,
    risky_column_count::text,
    'public_profiles should not expose membership or role state.'
  from public_profiles_exposure

  union all
  select
    150,
    'post_apply_ready_for_membership_gate_design',
    case
      when exists (select 1 from table_rows where table_name = 'community_memberships' and rls_enabled)
       and (select missing_membership_count from membership_counts) = 0
       and (select membership_trigger_count from trigger_summary) = 1
       and (select risky_column_count from public_profiles_exposure) = 0
       and (select direct_write_count + direct_select_count from table_privileges) = 0
       and (select has_role_count + is_approved_member_count + is_membership_approver_count + get_my_membership_status_count + trigger_function_count from function_summary) = 5
      then 'ok'
      else 'review'
    end,
    case
      when exists (select 1 from table_rows where table_name = 'community_memberships' and rls_enabled)
       and (select missing_membership_count from membership_counts) = 0
       and (select membership_trigger_count from trigger_summary) = 1
       and (select risky_column_count from public_profiles_exposure) = 0
       and (select direct_write_count + direct_select_count from table_privileges) = 0
       and (select has_role_count + is_approved_member_count + is_membership_approver_count + get_my_membership_status_count + trigger_function_count from function_summary) = 5
      then 'true'
      else 'false'
    end,
    'If true, the foundation is ready for separate approved-gate and approver-RPC design gates.'
)
select
  check_name,
  status,
  result_value,
  note
from output_rows
order by sort_order, check_name;
