-- 051_admin_discord_announcements_post_apply_select_only.sql
-- SELECT ONLY / NO MUTATION / NOT EXECUTED BY CODEX
--
-- Purpose:
-- - Confirm the post-apply state for the admin-only Discord cap announcement
--   schema/RPC gate.
-- - Return only generalized check results.
-- - Do not return row data, real IDs, Webhook URLs, Discord IDs, JWTs, token
--   values, Supabase project URLs, or full function bodies.
--
-- Run policy:
-- - Run only after a separate explicit SQL apply approval and execution.
-- - This file itself must not change DB state.

with role_refs as (
  select
    to_regrole('anon')::oid as anon_oid,
    to_regrole('authenticated')::oid as authenticated_oid
),
target_table as (
  select c.oid, c.relrowsecurity, c.relforcerowsecurity
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'admin_discord_announcements'
    and c.relkind in ('r', 'p')
),
target_constraints as (
  select
    con.conname,
    pg_get_constraintdef(con.oid) as constraint_def
  from pg_constraint con
  join target_table tt on tt.oid = con.conrelid
),
constraint_flags as (
  select
    exists (
      select 1
      from target_constraints
      where conname = 'admin_discord_announcements_status_check'
        and constraint_def ilike '%''draft''%'
        and constraint_def ilike '%''scheduled''%'
        and constraint_def ilike '%''processing''%'
        and constraint_def ilike '%''posted''%'
        and constraint_def ilike '%''failed''%'
        and constraint_def ilike '%''canceled''%'
    ) as status_check_ok,
    exists (
      select 1
      from target_constraints
      where conname = 'admin_discord_announcements_mention_mode_check'
        and constraint_def ilike '%''none''%'
        and constraint_def ilike '%''everyone''%'
    ) as mention_mode_check_ok,
    exists (
      select 1
      from target_constraints
      where conname = 'admin_discord_announcements_type_check'
        and constraint_def ilike '%''cap_update''%'
    ) as announcement_type_check_ok,
    exists (
      select 1
      from target_constraints
      where conname = 'admin_discord_announcements_target_channel_key_check'
        and constraint_def ilike '%''cap_announcement''%'
    ) as target_channel_key_check_ok
),
table_privileges as (
  select
    case
      when rr.anon_oid is null or tt.oid is null then false
      else has_table_privilege(rr.anon_oid, tt.oid, 'SELECT')
    end as anon_select,
    case
      when rr.anon_oid is null or tt.oid is null then false
      else has_table_privilege(rr.anon_oid, tt.oid, 'INSERT')
    end as anon_insert,
    case
      when rr.anon_oid is null or tt.oid is null then false
      else has_table_privilege(rr.anon_oid, tt.oid, 'UPDATE')
    end as anon_update,
    case
      when rr.anon_oid is null or tt.oid is null then false
      else has_table_privilege(rr.anon_oid, tt.oid, 'DELETE')
    end as anon_delete,
    case
      when rr.authenticated_oid is null or tt.oid is null then false
      else has_table_privilege(rr.authenticated_oid, tt.oid, 'SELECT')
    end as authenticated_select,
    case
      when rr.authenticated_oid is null or tt.oid is null then false
      else has_table_privilege(rr.authenticated_oid, tt.oid, 'INSERT')
    end as authenticated_insert,
    case
      when rr.authenticated_oid is null or tt.oid is null then false
      else has_table_privilege(rr.authenticated_oid, tt.oid, 'UPDATE')
    end as authenticated_update,
    case
      when rr.authenticated_oid is null or tt.oid is null then false
      else has_table_privilege(rr.authenticated_oid, tt.oid, 'DELETE')
    end as authenticated_delete
  from role_refs rr
  left join target_table tt on true
),
policy_flags as (
  select
    exists (
      select 1
      from pg_policies p
      where p.schemaname = 'public'
        and p.tablename = 'admin_discord_announcements'
        and p.cmd = 'SELECT'
        and 'authenticated' = any(p.roles)
        and coalesce(p.qual, '') ilike '%is_admin%'
    ) as admin_select_policy_ok,
    exists (
      select 1
      from pg_policies p
      where p.schemaname = 'public'
        and p.tablename = 'admin_discord_announcements'
        and p.cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL')
    ) as direct_write_policy_present
),
expected_functions as (
  select *
  from (values
    ('create_admin_discord_announcement', 'browser_admin'),
    ('update_admin_discord_announcement', 'browser_admin'),
    ('cancel_admin_discord_announcement', 'browser_admin'),
    ('list_admin_discord_announcements', 'browser_admin'),
    ('claim_due_admin_discord_announcements', 'server_only'),
    ('finalize_admin_discord_announcement', 'server_only')
  ) as f(proname, rpc_kind)
),
target_functions as (
  select
    ef.proname,
    ef.rpc_kind,
    p.oid,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config,
    pg_get_function_identity_arguments(p.oid) as identity_arguments,
    pg_get_function_result(p.oid) as result_def,
    pg_get_functiondef(p.oid) as function_def
  from expected_functions ef
  left join pg_proc p on p.proname = ef.proname
  left join pg_namespace n on n.oid = p.pronamespace
  where p.oid is null or n.nspname = 'public'
),
function_flags as (
  select
    proname,
    rpc_kind,
    count(oid) as function_count,
    bool_or(coalesce(security_definer, false)) filter (where oid is not null) as any_security_definer,
    bool_and(coalesce(security_definer, false)) filter (where oid is not null) as all_security_definer,
    bool_or(function_config ilike '%search_path%') filter (where oid is not null) as any_search_path,
    bool_and(function_config ilike '%search_path%') filter (where oid is not null) as all_search_path,
    bool_or(function_def ilike '%is_admin()%'
      or function_def ilike '%public.is_admin()%'
      or function_def ilike '%public.is_admin(%') filter (where oid is not null) as has_admin_check_pattern,
    bool_or(function_def ilike '%admin_discord_announcements%') filter (where oid is not null) as has_target_table_pattern,
    bool_or(function_def ilike '%cap_update%') filter (where oid is not null) as has_cap_update_pattern,
    bool_or(function_def ilike '%cap_announcement%') filter (where oid is not null) as has_target_channel_key_pattern,
    bool_or(function_def ilike '%none%' and function_def ilike '%everyone%') filter (where oid is not null) as has_mention_mode_pattern,
    bool_or(function_def ilike '%draft%'
      and function_def ilike '%scheduled%'
      and function_def ilike '%processing%'
      and function_def ilike '%posted%'
      and function_def ilike '%failed%'
      and function_def ilike '%canceled%') filter (where oid is not null) as has_status_pattern
  from target_functions
  group by proname, rpc_kind
),
function_privileges as (
  select
    tf.proname,
    tf.rpc_kind,
    bool_or(
      case
        when rr.anon_oid is null or tf.oid is null then false
        else has_function_privilege(rr.anon_oid, tf.oid, 'EXECUTE')
      end
    ) as anon_execute,
    bool_or(
      case
        when rr.authenticated_oid is null or tf.oid is null then false
        else has_function_privilege(rr.authenticated_oid, tf.oid, 'EXECUTE')
      end
    ) as authenticated_execute
  from target_functions tf
  cross join role_refs rr
  group by tf.proname, tf.rpc_kind
),
browser_rpc_summary as (
  select
    count(*) filter (where function_count > 0) as existing_count,
    bool_and(function_count > 0) as all_exist,
    bool_and(coalesce(all_security_definer, false)) as all_security_definer,
    bool_and(coalesce(all_search_path, false)) as all_search_path,
    bool_and(coalesce(has_admin_check_pattern, false)) as all_have_admin_check,
    bool_and(coalesce(has_target_table_pattern, false)) as all_have_target_table,
    bool_and(coalesce(has_cap_update_pattern, false)) as all_have_cap_update,
    bool_and(coalesce(has_target_channel_key_pattern, false)) as all_have_target_channel_key,
    bool_and(coalesce(has_mention_mode_pattern, false)) as all_have_mention_mode,
    bool_or(coalesce(has_status_pattern, false)) as any_has_status_pattern
  from function_flags
  where rpc_kind = 'browser_admin'
),
server_rpc_summary as (
  select
    count(*) filter (where function_count > 0) as existing_count,
    bool_and(function_count > 0) as all_exist,
    bool_and(coalesce(all_security_definer, false)) as all_security_definer,
    bool_and(coalesce(all_search_path, false)) as all_search_path,
    bool_and(coalesce(has_target_table_pattern, false)) as all_have_target_table,
    bool_and(coalesce(has_cap_update_pattern, false)) as all_have_cap_update,
    bool_and(coalesce(has_target_channel_key_pattern, false)) as all_have_target_channel_key,
    bool_or(coalesce(has_status_pattern, false)) as any_has_status_pattern
  from function_flags
  where rpc_kind = 'server_only'
),
rpc_privilege_summary as (
  select
    bool_and(not coalesce(anon_execute, false)) as no_anon_execute,
    bool_and(coalesce(authenticated_execute, false)) filter (where rpc_kind = 'browser_admin') as browser_authenticated_execute,
    bool_and(not coalesce(authenticated_execute, false)) filter (where rpc_kind = 'server_only') as server_not_authenticated_execute
  from function_privileges
),
checks as (
  select
    'table_exists' as check_name,
    case when exists (select 1 from target_table) then 'ok' else 'missing' end as status,
    (select count(*)::text from target_table) as result_value,
    'public.admin_discord_announcements table presence' as note
  union all
  select
    'status_check',
    case when (select status_check_ok from constraint_flags) then 'ok' else 'missing' end,
    (select status_check_ok::text from constraint_flags),
    'draft/scheduled/processing/posted/failed/canceled'
  union all
  select
    'mention_mode_check',
    case when (select mention_mode_check_ok from constraint_flags) then 'ok' else 'missing' end,
    (select mention_mode_check_ok::text from constraint_flags),
    'none/everyone only'
  union all
  select
    'announcement_type_check',
    case when (select announcement_type_check_ok from constraint_flags) then 'ok' else 'missing' end,
    (select announcement_type_check_ok::text from constraint_flags),
    'announcement_type fixed to cap_update'
  union all
  select
    'target_channel_key_check',
    case when (select target_channel_key_check_ok from constraint_flags) then 'ok' else 'missing' end,
    (select target_channel_key_check_ok::text from constraint_flags),
    'target_channel_key fixed to logical cap_announcement'
  union all
  select
    'rls_enabled',
    case when exists (select 1 from target_table where relrowsecurity) then 'ok' else 'review' end,
    coalesce((select relrowsecurity::text from target_table limit 1), 'missing'),
    'RLS must be enabled'
  union all
  select
    'admin_select_policy',
    case when (select admin_select_policy_ok from policy_flags) then 'ok' else 'review' end,
    (select admin_select_policy_ok::text from policy_flags),
    'SELECT policy should be authenticated admin only'
  union all
  select
    'direct_write_policy_absent',
    case when not (select direct_write_policy_present from policy_flags) then 'ok' else 'review' end,
    (not (select direct_write_policy_present from policy_flags))::text,
    'direct table write policies should be absent for browser callers'
  union all
  select
    'anon_table_privileges',
    case when exists (
      select 1 from table_privileges
      where not anon_select and not anon_insert and not anon_update and not anon_delete
    ) then 'ok' else 'review' end,
    coalesce((select concat_ws(
      ',',
      'select=' || anon_select::text,
      'insert=' || anon_insert::text,
      'update=' || anon_update::text,
      'delete=' || anon_delete::text
    ) from table_privileges limit 1), 'missing'),
    'anon should not have table access'
  union all
  select
    'authenticated_table_privileges',
    case when exists (
      select 1 from table_privileges
      where authenticated_select
        and not authenticated_insert
        and not authenticated_update
        and not authenticated_delete
    ) then 'ok' else 'review' end,
    coalesce((select concat_ws(
      ',',
      'select=' || authenticated_select::text,
      'insert=' || authenticated_insert::text,
      'update=' || authenticated_update::text,
      'delete=' || authenticated_delete::text
    ) from table_privileges limit 1), 'missing'),
    'authenticated may SELECT through admin RLS, but should not write table directly'
  union all
  select
    'browser_admin_rpc_exists',
    case when (select all_exist from browser_rpc_summary) then 'ok' else 'missing' end,
    (select existing_count::text || '/4' from browser_rpc_summary),
    'create/update/cancel/list admin RPC presence'
  union all
  select
    'browser_admin_rpc_security_definer',
    case when (select all_security_definer from browser_rpc_summary) then 'ok' else 'review' end,
    coalesce((select all_security_definer::text from browser_rpc_summary), 'false'),
    'browser admin RPCs should be security definer'
  union all
  select
    'browser_admin_rpc_search_path',
    case when (select all_search_path from browser_rpc_summary) then 'ok' else 'review' end,
    coalesce((select all_search_path::text from browser_rpc_summary), 'false'),
    'browser admin RPCs should pin search_path'
  union all
  select
    'browser_admin_rpc_admin_check',
    case when (select all_have_admin_check from browser_rpc_summary) then 'ok' else 'review' end,
    coalesce((select all_have_admin_check::text from browser_rpc_summary), 'false'),
    'browser admin RPC bodies should check public.is_admin()'
  union all
  select
    'browser_admin_rpc_contract_patterns',
    case when exists (
      select 1 from browser_rpc_summary
      where all_have_target_table
        and all_have_cap_update
        and all_have_target_channel_key
        and all_have_mention_mode
    ) then 'ok' else 'review' end,
    coalesce((select concat_ws(
      ',',
      'table=' || all_have_target_table::text,
      'cap_update=' || all_have_cap_update::text,
      'channel_key=' || all_have_target_channel_key::text,
      'mention=' || all_have_mention_mode::text
    ) from browser_rpc_summary), 'missing'),
    'admin cap announcement contract patterns only; no function body returned'
  union all
  select
    'server_rpc_exists',
    case when (select all_exist from server_rpc_summary) then 'ok' else 'missing' end,
    (select existing_count::text || '/2' from server_rpc_summary),
    'claim/finalize server-only RPC presence'
  union all
  select
    'server_rpc_security_definer',
    case when (select all_security_definer from server_rpc_summary) then 'ok' else 'review' end,
    coalesce((select all_security_definer::text from server_rpc_summary), 'false'),
    'server RPCs should be security definer'
  union all
  select
    'server_rpc_search_path',
    case when (select all_search_path from server_rpc_summary) then 'ok' else 'review' end,
    coalesce((select all_search_path::text from server_rpc_summary), 'false'),
    'server RPCs should pin search_path'
  union all
  select
    'server_rpc_contract_patterns',
    case when exists (
      select 1 from server_rpc_summary
      where all_have_target_table
        and all_have_cap_update
        and all_have_target_channel_key
        and any_has_status_pattern
    ) then 'ok' else 'review' end,
    coalesce((select concat_ws(
      ',',
      'table=' || all_have_target_table::text,
      'cap_update=' || all_have_cap_update::text,
      'channel_key=' || all_have_target_channel_key::text,
      'status=' || any_has_status_pattern::text
    ) from server_rpc_summary), 'missing'),
    'claim/finalize should target only cap announcement rows and safe statuses'
  union all
  select
    'rpc_anon_execute',
    case when (select no_anon_execute from rpc_privilege_summary) then 'ok' else 'review' end,
    coalesce((select no_anon_execute::text from rpc_privilege_summary), 'false'),
    'anon should not execute admin cap announcement RPCs'
  union all
  select
    'browser_rpc_authenticated_execute',
    case when (select browser_authenticated_execute from rpc_privilege_summary) then 'ok' else 'review' end,
    coalesce((select browser_authenticated_execute::text from rpc_privilege_summary), 'false'),
    'authenticated may execute browser admin RPCs, which must still call is_admin()'
  union all
  select
    'server_rpc_authenticated_execute',
    case when (select server_not_authenticated_execute from rpc_privilege_summary) then 'ok' else 'review' end,
    coalesce((select server_not_authenticated_execute::text from rpc_privilege_summary), 'false'),
    'normal authenticated browser callers should not execute claim/finalize'
  union all
  select
    'post_apply_ready_for_next_gate',
    case when
      exists (select 1 from target_table)
      and (select status_check_ok from constraint_flags)
      and (select mention_mode_check_ok from constraint_flags)
      and (select announcement_type_check_ok from constraint_flags)
      and (select target_channel_key_check_ok from constraint_flags)
      and exists (select 1 from target_table where relrowsecurity)
      and (select admin_select_policy_ok from policy_flags)
      and not (select direct_write_policy_present from policy_flags)
      and exists (
        select 1 from table_privileges
        where not anon_select
          and not anon_insert
          and not anon_update
          and not anon_delete
          and authenticated_select
          and not authenticated_insert
          and not authenticated_update
          and not authenticated_delete
      )
      and coalesce((select all_exist from browser_rpc_summary), false)
      and coalesce((select all_security_definer from browser_rpc_summary), false)
      and coalesce((select all_search_path from browser_rpc_summary), false)
      and coalesce((select all_have_admin_check from browser_rpc_summary), false)
      and coalesce((select no_anon_execute from rpc_privilege_summary), false)
    then 'ok' else 'review' end,
    'see individual checks',
    'ok means SQL/RPC state is ready for a separate Edge Function draft review gate'
)
select
  check_name,
  status,
  result_value,
  note
from checks
order by check_name;
