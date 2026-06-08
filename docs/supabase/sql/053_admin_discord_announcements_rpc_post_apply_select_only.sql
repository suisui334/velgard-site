-- 053_admin_discord_announcements_rpc_post_apply_select_only.sql
-- SELECT ONLY / NO MUTATION / NOT EXECUTED BY CODEX
--
-- Purpose:
-- - Confirm the post-052 RPC state for admin-only Discord cap update
--   announcements.
-- - Return only generalized check results.
-- - Do not return row data, real IDs, Webhook URLs, Discord IDs, JWTs, token
--   values, Supabase project URLs, or full function bodies.
--
-- Run policy:
-- - Run only after a separate explicit 052 SQL apply approval and execution.
-- - This file itself must not change DB state.

with role_refs as (
  select
    to_regrole('anon')::oid as anon_oid,
    to_regrole('authenticated')::oid as authenticated_oid,
    to_regrole('service_role')::oid as service_role_oid
),
expected_functions as (
  select *
  from (values
    (
      'create_admin_discord_announcement',
      'browser_admin',
      'public.create_admin_discord_announcement(text,text,text,text,text,text,text,text,text,text,text)'
    ),
    (
      'update_admin_discord_announcement',
      'browser_admin',
      'public.update_admin_discord_announcement(uuid,text,text,text,text,text,text,text,text,text,text,text)'
    ),
    (
      'cancel_admin_discord_announcement',
      'browser_admin',
      'public.cancel_admin_discord_announcement(uuid)'
    ),
    (
      'list_admin_discord_announcements',
      'browser_admin',
      'public.list_admin_discord_announcements(text,integer)'
    ),
    (
      'claim_due_admin_discord_announcements',
      'server_only',
      'public.claim_due_admin_discord_announcements(integer)'
    ),
    (
      'finalize_admin_discord_announcement',
      'server_only',
      'public.finalize_admin_discord_announcement(uuid,uuid,text,text,integer,text)'
    )
  ) as f(proname, rpc_kind, signature_text)
),
target_table as (
  select c.oid, c.relrowsecurity
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'admin_discord_announcements'
    and c.relkind in ('r', 'p')
),
target_columns as (
  select a.attname
  from target_table tt
  join pg_attribute a on a.attrelid = tt.oid
  where a.attnum > 0
    and not a.attisdropped
),
target_functions as (
  select
    ef.proname,
    ef.rpc_kind,
    ef.signature_text,
    to_regprocedure(ef.signature_text) as oid
  from expected_functions ef
),
function_details as (
  select
    tf.proname,
    tf.rpc_kind,
    tf.signature_text,
    tf.oid,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config,
    case when tf.oid is null then '' else pg_get_functiondef(tf.oid) end as function_def
  from target_functions tf
  left join pg_proc p on p.oid = tf.oid
),
function_privileges as (
  select
    fd.proname,
    fd.rpc_kind,
    case
      when rr.anon_oid is null or fd.oid is null then false
      else has_function_privilege(rr.anon_oid, fd.oid, 'EXECUTE')
    end as anon_execute,
    case
      when rr.authenticated_oid is null or fd.oid is null then false
      else has_function_privilege(rr.authenticated_oid, fd.oid, 'EXECUTE')
    end as authenticated_execute,
    case
      when rr.service_role_oid is null or fd.oid is null then false
      else has_function_privilege(rr.service_role_oid, fd.oid, 'EXECUTE')
    end as service_role_execute
  from function_details fd
  cross join role_refs rr
),
browser_summary as (
  select
    count(*) filter (where oid is not null) as existing_count,
    bool_and(oid is not null) as all_exist,
    bool_and(coalesce(security_definer, false)) as all_security_definer,
    bool_and(function_config ilike '%search_path%') as all_search_path,
    bool_and(function_def ilike '%public.is_admin%') as all_admin_check,
    bool_and(function_def ilike '%admin_discord_announcements%') as all_target_table,
    bool_and(function_def ilike '%cap_update%') as all_cap_update,
    bool_and(function_def ilike '%cap_announcement%') as all_target_channel_key,
    bool_and(function_def ilike '%none%' and function_def ilike '%everyone%') as all_mention_modes,
    bool_and(function_def ilike '%draft%'
      and function_def ilike '%scheduled%'
      and function_def ilike '%processing%'
      and function_def ilike '%posted%'
      and function_def ilike '%failed%'
      and function_def ilike '%canceled%') as all_status_patterns
  from function_details
  where rpc_kind = 'browser_admin'
),
server_summary as (
  select
    count(*) filter (where oid is not null) as existing_count,
    bool_and(oid is not null) as all_exist,
    bool_and(coalesce(security_definer, false)) as all_security_definer,
    bool_and(function_config ilike '%search_path%') as all_search_path,
    bool_and(function_def ilike '%auth.role()%'
      and function_def ilike '%service_role%') as all_service_role_check,
    bool_and(function_def ilike '%admin_discord_announcements%') as all_target_table,
    bool_and(function_def ilike '%cap_update%') as all_cap_update,
    bool_and(function_def ilike '%cap_announcement%') as all_target_channel_key,
    bool_and(function_def not ilike '%DISCORD_WEBHOOK%'
      and function_def not ilike '%webhook%') as no_webhook_value_pattern
  from function_details
  where rpc_kind = 'server_only'
),
claim_contract as (
  select
    (
      function_def ilike '%status = ''scheduled''%'
      and function_def ilike '%scheduled_at <= now()%'
      and function_def ilike '%processing%'
      and function_def ilike '%lock_token%'
      and function_def ilike '%for update skip locked%'
      and function_def ilike '%attempt_count%'
      and function_def ilike '%max_attempts%'
    ) as ok,
    concat_ws(
      ',',
      'scheduled=' || (function_def ilike '%status = ''scheduled''%')::text,
      'due=' || (function_def ilike '%scheduled_at <= now()%')::text,
      'processing=' || (function_def ilike '%processing%')::text,
      'lock=' || (function_def ilike '%lock_token%')::text,
      'skip_locked=' || (function_def ilike '%for update skip locked%')::text
    ) as detail
  from function_details
  where proname = 'claim_due_admin_discord_announcements'
),
finalize_contract as (
  select
    (
      function_def ilike '%p_lock_token%'
      and function_def ilike '%posted%'
      and function_def ilike '%scheduled%'
      and function_def ilike '%failed%'
      and function_def ilike '%attempt_count%'
      and function_def ilike '%delivery_error_code%'
      and function_def ilike '%discord_message_id%'
    ) as ok,
    concat_ws(
      ',',
      'lock=' || (function_def ilike '%p_lock_token%')::text,
      'posted=' || (function_def ilike '%posted%')::text,
      'retry_scheduled=' || (function_def ilike '%scheduled%')::text,
      'failed=' || (function_def ilike '%failed%')::text,
      'error_code=' || (function_def ilike '%delivery_error_code%')::text,
      'message_id=' || (function_def ilike '%discord_message_id%')::text
    ) as detail
  from function_details
  where proname = 'finalize_admin_discord_announcement'
),
privilege_summary as (
  select
    bool_and(not anon_execute) as no_anon_execute,
    bool_and(authenticated_execute) filter (where rpc_kind = 'browser_admin') as browser_authenticated_execute,
    bool_and(not authenticated_execute) filter (where rpc_kind = 'server_only') as server_not_authenticated_execute,
    bool_and(service_role_execute) filter (where rpc_kind = 'server_only') as server_service_role_execute
  from function_privileges
),
checks as (
  select
    'browser_admin_rpc_exists' as check_name,
    case when (select all_exist from browser_summary) then 'ok' else 'missing' end as status,
    (select existing_count::text || '/4' from browser_summary) as result_value,
    'create/update/cancel/list exact RPC signatures exist' as note
  union all
  select
    'server_rpc_exists',
    case when (select all_exist from server_summary) then 'ok' else 'missing' end,
    (select existing_count::text || '/2' from server_summary),
    'claim/finalize exact RPC signatures exist'
  union all
  select
    'rpc_anon_execute',
    case when (select no_anon_execute from privilege_summary) then 'ok' else 'review' end,
    coalesce((select no_anon_execute::text from privilege_summary), 'false'),
    'anon should not execute admin cap announcement RPCs'
  union all
  select
    'browser_rpc_authenticated_execute',
    case when (select browser_authenticated_execute from privilege_summary) then 'ok' else 'review' end,
    coalesce((select browser_authenticated_execute::text from privilege_summary), 'false'),
    'authenticated may execute browser admin RPCs; each RPC must still call public.is_admin()'
  union all
  select
    'server_rpc_authenticated_execute',
    case when (select server_not_authenticated_execute from privilege_summary) then 'ok' else 'review' end,
    coalesce((select server_not_authenticated_execute::text from privilege_summary), 'false'),
    'normal authenticated browser callers should not execute claim/finalize'
  union all
  select
    'server_rpc_service_role_execute',
    case when (select server_service_role_execute from privilege_summary) then 'ok' else 'review' end,
    coalesce((select server_service_role_execute::text from privilege_summary), 'false'),
    'server-only RPCs should be callable by the Edge Function service role boundary'
  union all
  select
    'browser_admin_rpc_security_definer',
    case when (select all_security_definer from browser_summary) then 'ok' else 'review' end,
    coalesce((select all_security_definer::text from browser_summary), 'false'),
    'browser admin RPCs should be security definer'
  union all
  select
    'server_rpc_security_definer',
    case when (select all_security_definer from server_summary) then 'ok' else 'review' end,
    coalesce((select all_security_definer::text from server_summary), 'false'),
    'server RPCs should be security definer'
  union all
  select
    'browser_admin_rpc_search_path',
    case when (select all_search_path from browser_summary) then 'ok' else 'review' end,
    coalesce((select all_search_path::text from browser_summary), 'false'),
    'browser admin RPCs should pin search_path'
  union all
  select
    'server_rpc_search_path',
    case when (select all_search_path from server_summary) then 'ok' else 'review' end,
    coalesce((select all_search_path::text from server_summary), 'false'),
    'server RPCs should pin search_path'
  union all
  select
    'browser_admin_rpc_admin_check',
    case when (select all_admin_check from browser_summary) then 'ok' else 'review' end,
    coalesce((select all_admin_check::text from browser_summary), 'false'),
    'browser admin RPC bodies should check public.is_admin()'
  union all
  select
    'server_rpc_service_role_check',
    case when (select all_service_role_check from server_summary) then 'ok' else 'review' end,
    coalesce((select all_service_role_check::text from server_summary), 'false'),
    'claim/finalize should reject normal browser role calls internally'
  union all
  select
    'browser_admin_rpc_contract_patterns',
    case when exists (
      select 1 from browser_summary
      where all_target_table
        and all_cap_update
        and all_target_channel_key
        and all_mention_modes
        and all_status_patterns
    ) then 'ok' else 'review' end,
    coalesce((select concat_ws(
      ',',
      'table=' || all_target_table::text,
      'cap_update=' || all_cap_update::text,
      'channel_key=' || all_target_channel_key::text,
      'mention=' || all_mention_modes::text,
      'status=' || all_status_patterns::text
    ) from browser_summary), 'missing'),
    'browser RPCs should be scoped to cap announcements and safe status/mention values'
  union all
  select
    'server_rpc_contract_patterns',
    case when exists (
      select 1 from server_summary
      where all_target_table
        and all_cap_update
        and all_target_channel_key
        and no_webhook_value_pattern
    ) then 'ok' else 'review' end,
    coalesce((select concat_ws(
      ',',
      'table=' || all_target_table::text,
      'cap_update=' || all_cap_update::text,
      'channel_key=' || all_target_channel_key::text,
      'no_webhook=' || no_webhook_value_pattern::text
    ) from server_summary), 'missing'),
    'server RPCs should target cap announcements and never contain Webhook values'
  union all
  select
    'claim_contract_patterns',
    case when coalesce((select ok from claim_contract), false) then 'ok' else 'review' end,
    coalesce((select detail from claim_contract), 'missing'),
    'claim should move due scheduled rows to processing with lock protection'
  union all
  select
    'finalize_contract_patterns',
    case when coalesce((select ok from finalize_contract), false) then 'ok' else 'review' end,
    coalesce((select detail from finalize_contract), 'missing'),
    'finalize should use lock_token and store posted/retry/failed delivery state'
  union all
  select
    'discord_message_id_column',
    case when exists (select 1 from target_columns where attname = 'discord_message_id') then 'ok' else 'missing' end,
    exists (select 1 from target_columns where attname = 'discord_message_id')::text,
    'optional message identifier column exists; list RPC should not return its values'
  union all
  select
    'post_apply_ready_for_next_gate',
    case when
      coalesce((select all_exist from browser_summary), false)
      and coalesce((select all_exist from server_summary), false)
      and coalesce((select no_anon_execute from privilege_summary), false)
      and coalesce((select browser_authenticated_execute from privilege_summary), false)
      and coalesce((select server_not_authenticated_execute from privilege_summary), false)
      and coalesce((select server_service_role_execute from privilege_summary), false)
      and coalesce((select all_security_definer from browser_summary), false)
      and coalesce((select all_security_definer from server_summary), false)
      and coalesce((select all_search_path from browser_summary), false)
      and coalesce((select all_search_path from server_summary), false)
      and coalesce((select all_admin_check from browser_summary), false)
      and coalesce((select all_service_role_check from server_summary), false)
      and coalesce((select ok from claim_contract), false)
      and coalesce((select ok from finalize_contract), false)
      and exists (select 1 from target_columns where attname = 'discord_message_id')
    then 'ok' else 'review' end,
    'see individual checks',
    'ok means RPC state is ready for a separate frontend RPC connection or Edge deploy draft gate'
)
select
  check_name,
  status,
  result_value,
  note
from checks
order by check_name;
