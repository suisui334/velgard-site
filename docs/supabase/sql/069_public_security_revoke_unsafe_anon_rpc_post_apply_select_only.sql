-- 069_public_security_revoke_unsafe_anon_rpc_post_apply_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Confirm the separately approved 068 unsafe anon RPC revoke.
-- - Verify public.rls_auto_enable() and public.set_updated_at() still exist.
-- - Verify anon/authenticated/public no longer have direct EXECUTE on them.
-- - Check trigger references to set_updated_at() are still present by count only.
--
-- Safety:
-- - SELECT-only.
-- - Do not return function bodies, row contents, concrete user ids, emails,
--   session ids, activity ids, notification ids, full URLs, project refs,
--   tokens, keys, or secrets.

with role_refs as (
  select
    to_regrole('anon') as anon_role,
    to_regrole('authenticated') as authenticated_role
),
target_functions as (
  select
    n.nspname as schema_name,
    p.oid,
    p.proname,
    p.oid::regprocedure::text as signature,
    pg_catalog.pg_get_function_result(p.oid) as result_type,
    p.proacl,
    p.proowner,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('rls_auto_enable', 'set_updated_at')
    and p.oid::regprocedure::text in ('rls_auto_enable()', 'set_updated_at()')
),
target_function_privileges as (
  select
    tf.*,
    exists (
      select 1
      from aclexplode(coalesce(tf.proacl, acldefault('f', tf.proowner))) acl
      where acl.grantee = 0
        and acl.privilege_type = 'EXECUTE'
        and acl.is_grantable is not null
    ) as public_execute,
    coalesce(
      case
        when (select anon_role from role_refs) is null then false
        else pg_catalog.has_function_privilege((select anon_role from role_refs), tf.oid, 'EXECUTE')
      end,
      false
    ) as anon_execute,
    coalesce(
      case
        when (select authenticated_role from role_refs) is null then false
        else pg_catalog.has_function_privilege((select authenticated_role from role_refs), tf.oid, 'EXECUTE')
      end,
      false
    ) as authenticated_execute,
    lower(coalesce(tf.result_type, '')) = 'trigger' as returns_trigger,
    tf.function_config ilike '%search_path=public%' as search_path_public
  from target_functions tf
),
target_summary as (
  select
    count(*) as target_count,
    count(*) filter (where proname = 'rls_auto_enable') as rls_auto_enable_count,
    count(*) filter (where proname = 'set_updated_at') as set_updated_at_count,
    count(*) filter (where public_execute) as public_execute_count,
    count(*) filter (where anon_execute) as anon_execute_count,
    count(*) filter (where authenticated_execute) as authenticated_execute_count
  from target_function_privileges
),
trigger_reference_counts as (
  select
    count(*) filter (where p.proname = 'set_updated_at') as set_updated_at_trigger_count
  from pg_catalog.pg_trigger t
  join pg_catalog.pg_proc p
    on p.oid = t.tgfoid
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and not t.tgisinternal
),
target_detail_rows as (
  select
    100 + row_number() over (order by signature) as sort_order,
    'target_function_execute_detail_' || lpad((row_number() over (order by signature))::text, 3, '0') as check_name,
    case
      when public_execute or anon_execute or authenticated_execute then 'review'
      else 'ok'
    end as status,
    signature as result_value,
    concat(
      'public_execute=', public_execute,
      ',anon_execute=', anon_execute,
      ',authenticated_execute=', authenticated_execute,
      ',returns_trigger=', returns_trigger,
      ',search_path_public=', search_path_public
    ) as note
  from target_function_privileges
),
output_rows as (
  select
    10 as sort_order,
    'unsafe_rpc_targets_exist'::text as check_name,
    case
      when target_count = 2
       and rls_auto_enable_count = 1
       and set_updated_at_count = 1
      then 'ok'
      else 'review'
    end as status,
    concat(
      'targets=', target_count,
      ',rls_auto_enable=', rls_auto_enable_count,
      ',set_updated_at=', set_updated_at_count
    ) as result_value,
    'Expected both target helper functions to still exist after revoking web-client EXECUTE.'::text as note
  from target_summary

  union all
  select
    20,
    'unsafe_rpc_web_execute_closed',
    case
      when public_execute_count = 0
       and anon_execute_count = 0
       and authenticated_execute_count = 0
      then 'ok'
      else 'review'
    end,
    concat(
      'public=', public_execute_count,
      ',anon=', anon_execute_count,
      ',authenticated=', authenticated_execute_count
    ),
    'After 068, target helper functions should not be directly executable by public, anon, or authenticated.'
  from target_summary

  union all
  select
    30,
    'set_updated_at_trigger_references_present',
    case when set_updated_at_trigger_count > 0 then 'ok' else 'review' end,
    set_updated_at_trigger_count::text,
    'Count-only check that set_updated_at() remains referenced by triggers. This does not return table names.'
  from trigger_reference_counts

  union all
  select
    40,
    'post_apply_ready_for_public_security_qa',
    case
      when ts.target_count = 2
       and ts.rls_auto_enable_count = 1
       and ts.set_updated_at_count = 1
       and ts.public_execute_count = 0
       and ts.anon_execute_count = 0
       and ts.authenticated_execute_count = 0
       and trc.set_updated_at_trigger_count > 0
      then 'ok'
      else 'review'
    end,
    case
      when ts.target_count = 2
       and ts.public_execute_count = 0
       and ts.anon_execute_count = 0
       and ts.authenticated_execute_count = 0
       and trc.set_updated_at_trigger_count > 0
      then 'true'
      else 'false'
    end,
    'If true, the P0 unsafe anon RPC exposure is closed and follow-up P1 security work can proceed separately.'
  from target_summary ts
  cross join trigger_reference_counts trc
)
select
  check_name,
  status,
  result_value,
  note
from (
  select sort_order, check_name, status, result_value, note from output_rows
  union all
  select sort_order, check_name, status, result_value, note from target_detail_rows
) combined_rows
order by sort_order, check_name;
