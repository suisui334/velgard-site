-- 043_general_user_created_session_permission_diagnostics_select_only.sql
-- SELECT ONLY / DO NOT APPLY / NO MUTATION
--
-- Purpose:
-- - Diagnose the already-created general-user session post without exposing raw IDs.
-- - Confirm whether the created row has safe owner/sync state.
-- - Confirm whether owner/admin follow-up RPCs still contain the old GM-role owner gate.
--
-- Before running in SQL Editor:
-- - Replace target_title below locally with the exact session title to inspect.
-- - Do not commit the edited title value.
-- - Run once only. If an error appears, stop and do not rerun.
-- - Do not paste raw IDs, user IDs, emails, JWTs, URLs, Discord IDs, or message previews.

with params as (
  select
    ''::text as target_title
),
target_sessions as (
  select
    s.status,
    s.visibility,
    s.discord_sync_status,
    s.discord_last_action,
    s.discord_sync_error,
    s.gm_user_id is not null as has_owner,
    exists (
      select 1
      from public.profiles as p
      where p.id = s.gm_user_id
    ) as owner_profile_exists,
    case
      when auth.uid() is null then null
      else s.gm_user_id = auth.uid()
    end as owner_matches_sql_auth_uid,
    nullif(btrim(coalesce(s.discord_message_id, '')), '') is not null as has_discord_message_id,
    nullif(btrim(coalesce(s.discord_channel_id, '')), '') is not null as has_discord_channel_id,
    nullif(btrim(coalesce(s.discord_post_url, '')), '') is not null as has_discord_post_url,
    s.discord_synced_at is not null as has_discord_synced_at
  from public.sessions as s
  cross join params as p
  where btrim(coalesce(p.target_title, '')) <> ''
    and s.title = p.target_title
),
target_summary as (
  select
    count(*) as match_count,
    bool_or(has_owner) as any_has_owner,
    bool_or(owner_profile_exists) as any_owner_profile_exists,
    bool_or(owner_matches_sql_auth_uid) as any_owner_matches_sql_auth_uid,
    bool_or(status in ('draft', 'tentative', 'recruiting')) as any_status_allowed_initial,
    bool_or(has_discord_message_id) as any_discord_message_id,
    bool_or(has_discord_channel_id) as any_discord_channel_id,
    bool_or(has_discord_post_url) as any_discord_post_url,
    bool_or(has_discord_synced_at) as any_discord_synced_at,
    bool_or(nullif(btrim(coalesce(discord_sync_error, '')), '') is null) as any_discord_sync_error_empty
  from target_sessions
),
target_functions as (
  select
    p.proname,
    pg_get_functiondef(p.oid) as function_def
  from pg_proc as p
  join pg_namespace as n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'update_session_post',
      'delete_session_post',
      'check_discord_session_post_create_ready',
      'record_discord_session_post_create_success',
      'record_discord_session_post_create_failure',
      'check_discord_session_post_update_ready',
      'record_discord_session_post_update_success',
      'record_discord_session_post_update_failure',
      'check_discord_session_post_delete_ready',
      'record_discord_session_post_delete_failure'
    )
),
function_patterns as (
  select
    proname,
    (
      lower(function_def) like '%has_role(''gm'')%'
      and lower(function_def) like '%gm_user_id = v_actor%'
    ) as has_old_gm_owner_gate,
    lower(function_def) like '%is_session_gm%' as has_is_session_gm_pattern
  from target_functions
),
checks as (
  select
    'target_title_configured' as check_name,
    case when btrim(coalesce((select target_title from params), '')) <> '' then 'ok' else 'blocked' end as status,
    (btrim(coalesce((select target_title from params), '')) <> '')::text as result_value,
    'set params.target_title locally before running; the title value is not returned' as note

  union all
  select
    'target_session_match_count',
    case when match_count = 1 then 'ok' when match_count = 0 then 'missing' else 'review' end,
    match_count::text,
    'expect exactly one target session by title; no raw session ID is returned'
  from target_summary

  union all
  select
    'target_status',
    case when match_count = 1 then 'info' else 'review' end,
    case when match_count = 1 then coalesce((select status from target_sessions limit 1), 'null') else match_count::text end,
    'status text only; no row ID is returned'
  from target_summary

  union all
  select
    'target_visibility',
    case when match_count = 1 then 'info' else 'review' end,
    case when match_count = 1 then coalesce((select visibility from target_sessions limit 1), 'null') else match_count::text end,
    'visibility text only; no row ID is returned'
  from target_summary

  union all
  select
    'target_status_allowed_initial',
    case when match_count = 1 and coalesce(any_status_allowed_initial, false) then 'ok' else 'review' end,
    coalesce(any_status_allowed_initial, false)::text,
    'expected create statuses are draft / tentative / recruiting'
  from target_summary

  union all
  select
    'target_has_owner',
    case when match_count = 1 and coalesce(any_has_owner, false) then 'ok' else 'review' end,
    coalesce(any_has_owner, false)::text,
    'checks owner presence only; owner ID is not returned'
  from target_summary

  union all
  select
    'target_owner_profile_exists',
    case when match_count = 1 and coalesce(any_owner_profile_exists, false) then 'ok' else 'review' end,
    coalesce(any_owner_profile_exists, false)::text,
    'checks owner profile existence only; profile ID is not returned'
  from target_summary

  union all
  select
    'target_owner_matches_sql_auth_uid',
    case
      when match_count <> 1 then 'review'
      when auth.uid() is null then 'unknown'
      when coalesce(any_owner_matches_sql_auth_uid, false) then 'ok'
      else 'review'
    end,
    case
      when auth.uid() is null then 'auth_uid_unavailable'
      else coalesce(any_owner_matches_sql_auth_uid, false)::text
    end,
    'SQL Editor usually has no browser auth.uid; use as supplemental only'
  from target_summary

  union all
  select
    'target_discord_message_id_saved',
    case when match_count = 1 then 'info' else 'review' end,
    coalesce(any_discord_message_id, false)::text,
    'boolean only; Discord message ID is not returned'
  from target_summary

  union all
  select
    'target_discord_channel_id_saved',
    case when match_count = 1 then 'info' else 'review' end,
    coalesce(any_discord_channel_id, false)::text,
    'boolean only; Discord channel ID is not returned'
  from target_summary

  union all
  select
    'target_discord_post_url_saved',
    case when match_count = 1 then 'info' else 'review' end,
    coalesce(any_discord_post_url, false)::text,
    'boolean only; post URL is not returned'
  from target_summary

  union all
  select
    'target_discord_synced_at_present',
    case when match_count = 1 then 'info' else 'review' end,
    coalesce(any_discord_synced_at, false)::text,
    'boolean only; timestamp value is not returned'
  from target_summary

  union all
  select
    'target_discord_sync_status',
    case when match_count = 1 then 'info' else 'review' end,
    case when match_count = 1 then coalesce((select discord_sync_status from target_sessions limit 1), 'null') else match_count::text end,
    'status text only'
  from target_summary

  union all
  select
    'target_discord_last_action',
    case when match_count = 1 then 'info' else 'review' end,
    case when match_count = 1 then coalesce((select discord_last_action from target_sessions limit 1), 'null') else match_count::text end,
    'action text only'
  from target_summary

  union all
  select
    'target_discord_sync_error_empty',
    case when match_count = 1 then 'info' else 'review' end,
    coalesce(any_discord_sync_error_empty, false)::text,
    'boolean only; error text is not returned'
  from target_summary

  union all
  select
    'is_session_gm_helper_exists',
    case when to_regprocedure('public.is_session_gm(text)') is not null then 'ok' else 'missing' end,
    (to_regprocedure('public.is_session_gm(text)') is not null)::text,
    'helper should authorize owner/admin checks without requiring GM role'

  union all
  select
    proname || '_has_old_gm_owner_gate',
    case when has_old_gm_owner_gate then 'review' else 'ok' end,
    has_old_gm_owner_gate::text,
    'true means the function likely still requires GM role plus ownership'
  from function_patterns

  union all
  select
    'owner_permission_rpc_change_needed',
    case when exists (
      select 1
      from function_patterns
      where proname in ('update_session_post', 'delete_session_post')
        and has_old_gm_owner_gate
    ) then 'review' else 'ok' end,
    exists (
      select 1
      from function_patterns
      where proname in ('update_session_post', 'delete_session_post')
        and has_old_gm_owner_gate
    )::text,
    'true means edit/delete/close-mark owner flows likely need RPC replacement'

  union all
  select
    'discord_create_sync_rpc_change_needed',
    case when exists (
      select 1
      from function_patterns
      where proname in (
        'check_discord_session_post_create_ready',
        'record_discord_session_post_create_success',
        'record_discord_session_post_create_failure'
      )
      and has_old_gm_owner_gate
    ) then 'review' else 'ok' end,
    exists (
      select 1
      from function_patterns
      where proname in (
        'check_discord_session_post_create_ready',
        'record_discord_session_post_create_success',
        'record_discord_session_post_create_failure'
      )
      and has_old_gm_owner_gate
    )::text,
    'true means Discord create auto-sync likely still blocks general owners'

  union all
  select
    'discord_update_delete_sync_old_gate_count',
    case when count(*) filter (where has_old_gm_owner_gate) = 0 then 'ok' else 'review' end,
    count(*) filter (where has_old_gm_owner_gate)::text,
    'count among update/delete Discord sync helper RPCs'
  from function_patterns
  where proname in (
    'check_discord_session_post_update_ready',
    'record_discord_session_post_update_success',
    'record_discord_session_post_update_failure',
    'check_discord_session_post_delete_ready',
    'record_discord_session_post_delete_failure'
  )
)
select
  check_name,
  status,
  result_value,
  note
from checks
order by check_name;
