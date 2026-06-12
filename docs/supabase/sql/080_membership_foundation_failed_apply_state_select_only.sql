-- 080_membership_foundation_failed_apply_state_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Inspect the database state after the first 078 membership foundation apply
--   attempt stopped on a syntax error.
-- - Help decide whether the corrected 078 can be reviewed/applied safely.
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
    c.relrowsecurity as rls_enabled,
    c.reltuples::bigint as row_estimate
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
membership_exact_counts as (
  select
    case
      when (select community_memberships_regclass from object_refs) is null then 'not_created'
      else coalesce(
        ((xpath(
          '/row/membership_count/text()',
          query_to_xml(
            'select count(*) as membership_count from public.community_memberships',
            false,
            true,
            ''
          )
        ))[1])::text,
        '0'
      )
    end as membership_count,
    case
      when (select community_memberships_regclass from object_refs) is null then 'not_created'
      else coalesce(
        ((xpath(
          '/row/missing_count/text()',
          query_to_xml(
            'select count(*) as missing_count from auth.users au where not exists (select 1 from public.community_memberships cm where cm.user_id = au.id)',
            false,
            true,
            ''
          )
        ))[1])::text,
        '0'
      )
    end as missing_membership_count,
    case
      when (select community_memberships_regclass from object_refs) is null then 'not_created'
      else coalesce(
        ((xpath(
          '/row/approved_count/text()',
          query_to_xml(
            'select count(*) as approved_count from public.community_memberships where status = ''approved''',
            false,
            true,
            ''
          )
        ))[1])::text,
        '0'
      )
    end as approved_count,
    case
      when (select community_memberships_regclass from object_refs) is null then 'not_created'
      else coalesce(
        ((xpath(
          '/row/pending_count/text()',
          query_to_xml(
            'select count(*) as pending_count from public.community_memberships where status = ''pending''',
            false,
            true,
            ''
          )
        ))[1])::text,
        '0'
      )
    end as pending_count
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
    count(*) filter (where proname = 'get_my_membership_status' and function_def ~* '\)\s+current_user(\s|$)') as unsafe_current_user_alias_count,
    count(*) filter (where proname = 'get_my_membership_status' and function_def ilike '%auth_context%') as safe_auth_context_alias_count
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
    'membership_table_partial_state'::text as check_name,
    case
      when exists (select 1 from table_rows where table_name = 'community_memberships') then 'review'
      else 'ok'
    end as status,
    (select count(*)::text from table_rows where table_name = 'community_memberships') as result_value,
    '0 means the failed 078 attempt left no membership table; 1 means inspect partial state before re-apply.'::text as note

  union all
  select
    20,
    'membership_table_rls_state',
    case
      when not exists (select 1 from table_rows where table_name = 'community_memberships') then 'ok'
      when exists (select 1 from table_rows where table_name = 'community_memberships' and rls_enabled) then 'ok'
      else 'review'
    end,
    (select coalesce(bool_or(rls_enabled), false)::text from table_rows where table_name = 'community_memberships'),
    'If the table exists after failure, RLS should already be enabled or the corrected apply must finish it.'

  union all
  select
    30,
    'membership_columns_partial_state',
    case
      when (select community_memberships_regclass from object_refs) is null then 'ok'
      when user_id_count = 1
       and status_count = 1
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
    'Column-level partial-state check; concrete row values are not returned.'
  from membership_columns

  union all
  select
    40,
    'membership_constraints_partial_state',
    case
      when (select community_memberships_regclass from object_refs) is null then 'ok'
      when status_check_count = 1
       and review_note_length_check_count = 1
      then 'ok'
      else 'review'
    end,
    concat('status_check=', status_check_count, ',review_note_length=', review_note_length_check_count),
    'Checks whether the status/review-note constraints are already present.'
  from membership_constraints

  union all
  select
    50,
    'membership_policies_partial_state',
    case
      when (select community_memberships_regclass from object_refs) is null then 'ok'
      when select_own_count = 1
       and select_admin_approver_count = 1
      then 'ok'
      else 'review'
    end,
    concat('select_own=', select_own_count, ',select_admin_approver=', select_admin_approver_count),
    'Checks whether 078 membership SELECT policies already exist.'
  from policy_summary

  union all
  select
    60,
    'membership_direct_grants_partial_state',
    case
      when direct_write_count = 0
       and direct_select_count = 0
      then 'ok'
      else 'review'
    end,
    concat('direct_write=', direct_write_count, ',direct_select=', direct_select_count),
    'Web roles should not have direct table grants on community_memberships.'
  from table_privileges

  union all
  select
    70,
    'membership_backfill_partial_counts',
    case
      when membership_count = 'not_created' then 'ok'
      when missing_membership_count = '0' then 'ok'
      else 'review'
    end,
    concat(
      'memberships=', membership_count,
      ',missing=', missing_membership_count,
      ',approved=', approved_count,
      ',pending=', pending_count
    ),
    'Count-only check. No concrete user ids or emails are returned.'
  from membership_exact_counts

  union all
  select
    80,
    'membership_helpers_partial_state',
    case
      when has_role_count = 1
       and is_approved_member_count <= 1
       and is_membership_approver_count <= 1
       and get_my_membership_status_count <= 1
       and trigger_function_count <= 1
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
    'Shows which 078 helper functions already exist after the failed attempt.'
  from function_summary

  union all
  select
    90,
    'membership_helper_security_partial_state',
    case
      when security_definer_count = search_path_public_count then 'ok'
      else 'review'
    end,
    concat('security_definer=', security_definer_count, ',search_path_public=', search_path_public_count),
    'Any existing 078 helper should keep security definer and search_path=public.'
  from function_summary

  union all
  select
    100,
    'membership_alias_syntax_fix_state',
    case
      when unsafe_current_user_alias_count = 0 then 'ok'
      else 'review'
    end,
    concat('unsafe_current_user_alias=', unsafe_current_user_alias_count, ',safe_auth_context_alias=', safe_auth_context_alias_count),
    'The corrected draft should avoid current_user as a table alias.'
  from function_summary

  union all
  select
    110,
    'membership_helper_execute_partial_state',
    case
      when not coalesce(web_helpers_anon_execute, false)
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
    'Anon/public should not directly execute membership helpers; trigger function should remain closed.'
  from privilege_summary

  union all
  select
    120,
    'membership_trigger_partial_state',
    case when membership_trigger_count in (0, 1) then 'ok' else 'review' end,
    membership_trigger_count::text,
    '0 or 1 is expected depending on whether the failed apply left the separate auth.users trigger.'
  from trigger_summary

  union all
  select
    130,
    'user_roles_approver_constraint_partial_state',
    case when membership_approver_allowed_count in (0, 1) then 'ok' else 'review' end,
    membership_approver_allowed_count::text,
    '0 means the failed transaction likely rolled back; 1 means the role constraint update is already present.'
  from role_constraints

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
    'failed_apply_state_next_step',
    case
      when not exists (select 1 from table_rows where table_name = 'community_memberships') then 'ok'
      when (select direct_write_count + direct_select_count from table_privileges) = 0
       and (select risky_column_count from public_profiles_exposure) = 0
      then 'review'
      else 'review'
    end,
    case
      when not exists (select 1 from table_rows where table_name = 'community_memberships') then 'no_partial_membership_table_detected'
      else 'partial_membership_objects_detected'
    end,
    'Use this result before deciding whether to re-review and run the corrected 078.'
)
select
  check_name,
  status,
  result_value,
  note
from output_rows
order by sort_order, check_name;
