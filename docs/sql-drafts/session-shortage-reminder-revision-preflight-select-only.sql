-- SELECT-ONLY PREFLIGHT.
-- Run separately before the shortage revision apply candidate.
-- Do not append DDL, DML, RPC execution, or secret-value reads.
-- Record only this aggregate result; do not record session or Discord values.

with
session_columns as (
  select
    count(*) filter (
      where column_name in (
        'date',
        'start_time',
        'shortage_reminder_enabled',
        'shortage_reminder_hours_before',
        'gm_reminder_enabled',
        'gm_reminder_minutes_before'
      )
    )::integer as required_count,
    count(*) filter (
      where column_name = 'shortage_reminder_revision'
    )::integer as revision_count,
    bool_and(
      case
        when column_name = 'date' then data_type = 'date'
        when column_name = 'start_time' then data_type like 'time%'
        when column_name in (
          'shortage_reminder_enabled',
          'gm_reminder_enabled'
        ) then data_type = 'boolean'
        when column_name in (
          'shortage_reminder_hours_before',
          'gm_reminder_minutes_before'
        ) then data_type = 'integer'
        else true
      end
    ) as types_match
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'sessions'
    and column_name in (
      'date',
      'start_time',
      'shortage_reminder_enabled',
      'shortage_reminder_hours_before',
      'gm_reminder_enabled',
      'gm_reminder_minutes_before',
      'shortage_reminder_revision'
    )
),
log_columns as (
  select
    count(*) filter (
      where column_name in (
        'id',
        'session_id',
        'reminder_type',
        'scheduled_for',
        'reminder_offset_minutes',
        'status',
        'dry_run',
        'lock_token',
        'created_at',
        'claimed_at',
        'sent_at',
        'finalized_at'
      )
    )::integer as required_count,
    count(*) filter (
      where column_name = 'shortage_reminder_revision'
    )::integer as revision_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'session_reminder_logs'
),
log_constraints as (
  select
    count(*)::integer as total_count,
    count(*) filter (
      where conname = 'session_reminder_logs_unique_session_type'
    )::integer as old_unique_count,
    bool_or(
      conname = 'session_reminder_logs_unique_session_type'
      and pg_get_constraintdef(oid) = 'UNIQUE (session_id, reminder_type)'
    ) as old_unique_matches,
    count(*) filter (where contype = 'f')::integer as foreign_key_count,
    count(*) filter (where contype = 'c')::integer as check_count
  from pg_constraint
  where conrelid = 'public.session_reminder_logs'::regclass
),
revision_indexes as (
  select count(*)::integer as index_count
  from pg_indexes
  where schemaname = 'public'
    and tablename = 'session_reminder_logs'
    and indexname in (
      'session_reminder_logs_shortage_revision_unique',
      'session_reminder_logs_gm_confirmed_unique'
    )
),
rpc_definitions as (
  select
    p.proname,
    p.prosecdef,
    pg_get_functiondef(p.oid) as definition
  from pg_proc as p
  join pg_namespace as n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.oid in (
      to_regprocedure('public.preview_due_session_reminders(timestamptz, integer)'),
      to_regprocedure('public.claim_due_session_reminders(timestamptz, integer)'),
      to_regprocedure('public.finalize_session_reminder(uuid, uuid, text, text, text)'),
      to_regprocedure('public.update_session_reminder_settings(text, boolean, integer, boolean, integer)')
    )
),
rpc_outputs as (
  select
    r.routine_name,
    count(*) filter (where p.parameter_mode = 'OUT')::integer as output_count,
    bool_or(
      p.parameter_mode = 'OUT'
      and p.parameter_name = 'gm_discord_user_id'
      and p.data_type = 'text'
    ) as has_gm_discord_user_id,
    bool_or(
      p.parameter_mode = 'OUT'
      and p.parameter_name = 'shortage_reminder_revision'
    ) as has_shortage_revision
  from information_schema.routines as r
  join information_schema.parameters as p
    on p.specific_schema = r.specific_schema
   and p.specific_name = r.specific_name
  where r.specific_schema = 'public'
    and r.routine_name in (
      'preview_due_session_reminders',
      'claim_due_session_reminders'
    )
  group by r.routine_name
),
log_counts as (
  select
    count(*)::integer as total_count,
    count(*) filter (where reminder_type = 'shortage')::integer as shortage_count,
    count(*) filter (where reminder_type = 'gm_confirmed')::integer as gm_count,
    count(*) filter (where status = 'claimed')::integer as claimed_count,
    count(*) filter (where status = 'sent')::integer as sent_count,
    count(*) filter (where status = 'failed')::integer as failed_count,
    count(*) filter (where status = 'skipped')::integer as skipped_count
  from public.session_reminder_logs
),
application_counts as (
  select
    sa.session_id,
    count(distinct sa.user_id) filter (
      where sa.status = 'pending'
    )::integer as pending_count,
    count(distinct sa.user_id) filter (
      where sa.status = 'accepted'
    )::integer as accepted_count
  from public.session_applications as sa
  where sa.status in ('pending', 'accepted', 'waitlisted')
  group by sa.session_id
),
changed_historical_shortage as (
  select distinct
    s.id,
    (s.date + s.start_time)::timestamp at time zone 'Asia/Tokyo' as start_at,
    s.shortage_reminder_enabled,
    s.shortage_reminder_hours_before,
    s.status,
    s.visibility,
    s.application_deadline,
    s.player_min,
    (
      coalesce(ac.pending_count, 0) + coalesce(ac.accepted_count, 0)
    )::integer as count_for_minimum
  from public.sessions as s
  join public.session_reminder_logs as l
    on l.session_id = s.id
   and l.reminder_type = 'shortage'
  left join application_counts as ac on ac.session_id = s.id
  where l.scheduled_for is distinct from
      ((s.date + s.start_time)::timestamp at time zone 'Asia/Tokyo')
    or l.reminder_offset_minutes is distinct from
      (s.shortage_reminder_hours_before * 60)
),
historical_shortage_state as (
  select
    count(*)::integer as changed_schedule_count,
    count(*) filter (
      where shortage_reminder_enabled = true
        and shortage_reminder_hours_before in (1, 2, 3)
        and status in ('tentative', 'recruiting')
        and visibility = 'public'
        and start_at > now()
        and (
          start_at - make_interval(
            mins => shortage_reminder_hours_before * 60
          )
        ) <= now()
        and (
          application_deadline is null
          or application_deadline > now()
        )
        and count_for_minimum < player_min
    )::integer as would_be_due_now_count
  from changed_historical_shortage
),
cron_state as (
  select
    count(*)::integer as job_count,
    bool_and(schedule = '* * * * *') as every_minute,
    bool_and(active) as all_active,
    bool_and(command like '%net.http_post%') as uses_pg_net,
    bool_and(command like '%SESSION_REMINDER_FUNCTION_URL%') as uses_function_url_secret,
    bool_and(command like '%SESSION_REMINDER_INVOKE_JWT%') as uses_invoke_jwt_secret,
    bool_and(command like '%SESSION_REMINDER_DISPATCH_TOKEN%') as uses_dispatch_token_secret,
    bool_and(command like '%''dry_run'', false%') as uses_production_payload,
    bool_and(command like '%''limit'', 1%') as uses_limit_one
  from cron.job
  where jobname = 'dispatch-session-reminders-every-minute'
),
recent_cron as (
  select
    count(*)::integer as run_count,
    count(*) filter (where status = 'succeeded')::integer as succeeded_count,
    count(*) filter (where status = 'failed')::integer as failed_count
  from cron.job_run_details
  where jobid in (
    select jobid
    from cron.job
    where jobname = 'dispatch-session-reminders-every-minute'
  )
    and start_time >= now() - interval '10 minutes'
),
recent_json_responses as (
  select
    status_code,
    content::jsonb as body
  from net._http_response
  where created >= now() - interval '10 minutes'
    and content is not null
    and ltrim(content) like '{%'
),
recent_reminder_responses as (
  select status_code, body
  from recent_json_responses
  where body ? 'production_enabled'
    and (body ? 'dry_run' or body ? 'error')
),
runtime_state as (
  select
    count(*)::integer as response_count,
    count(*) filter (
      where status_code between 200 and 299
    )::integer as http_2xx_count,
    count(*) filter (where status_code = 403)::integer as http_403_count,
    count(*) filter (
      where coalesce((body ->> 'production_enabled')::boolean, false)
    )::integer as production_enabled_true_count,
    count(*) filter (
      where coalesce((body ->> 'discord_send')::boolean, false)
    )::integer as discord_send_true_count,
    count(*) filter (
      where coalesce((body ->> 'db_write')::boolean, false)
    )::integer as db_write_true_count,
    count(*) filter (
      where coalesce((body ->> 'sent_count')::integer, 0) > 0
    )::integer as positive_sent_count,
    count(*) filter (
      where coalesce((body ->> 'claimed_count')::integer, 0) > 0
    )::integer as positive_claimed_count
  from recent_reminder_responses
),
vault_state as (
  select count(*)::integer as expected_secret_count
  from vault.secrets
  where name in (
    'SESSION_REMINDER_FUNCTION_URL',
    'SESSION_REMINDER_INVOKE_JWT',
    'SESSION_REMINDER_DISPATCH_TOKEN'
  )
)
select
  (select required_count from session_columns) as sessions_required_columns,
  (select types_match from session_columns) as sessions_types_match,
  (select revision_count from session_columns) as sessions_revision_columns_before,
  (select required_count from log_columns) as logs_required_columns,
  (select revision_count from log_columns) as logs_revision_columns_before,
  (select total_count from log_constraints) as logs_constraint_count,
  (select old_unique_count from log_constraints) as old_unique_constraint_count,
  (select old_unique_matches from log_constraints) as old_unique_matches,
  (select foreign_key_count from log_constraints) as logs_foreign_key_count,
  (select check_count from log_constraints) as logs_check_count,
  (select index_count from revision_indexes) as revision_index_count_before,
  (select count(*) from rpc_definitions)::integer as rpc_count,
  (select bool_and(prosecdef) from rpc_definitions) as all_security_definer,
  (select output_count from rpc_outputs where routine_name = 'preview_due_session_reminders') as preview_output_count,
  (select output_count from rpc_outputs where routine_name = 'claim_due_session_reminders') as claim_output_count,
  (select has_gm_discord_user_id from rpc_outputs where routine_name = 'preview_due_session_reminders') as preview_has_gm_discord_user_id,
  (select has_gm_discord_user_id from rpc_outputs where routine_name = 'claim_due_session_reminders') as claim_has_gm_discord_user_id,
  (select has_shortage_revision from rpc_outputs where routine_name = 'preview_due_session_reminders') as preview_has_revision_before,
  (select has_shortage_revision from rpc_outputs where routine_name = 'claim_due_session_reminders') as claim_has_revision_before,
  (select bool_or(
    definition like '%l.session_id = c.session_id%'
    and definition like '%l.reminder_type = c.reminder_type%'
  ) from rpc_definitions where proname = 'preview_due_session_reminders') as preview_uses_old_duplicate_unit,
  (select bool_or(
    definition like '%on conflict on constraint session_reminder_logs_unique_session_type do nothing%'
  ) from rpc_definitions where proname = 'claim_due_session_reminders') as claim_uses_old_unique_constraint,
  (select bool_or(
    definition ilike '%update public.sessions%'
    and definition ilike '%shortage_reminder_enabled%'
    and definition ilike '%shortage_reminder_hours_before%'
    and definition ilike '%gm_reminder_enabled%'
    and definition ilike '%gm_reminder_minutes_before%'
  ) from rpc_definitions where proname = 'update_session_reminder_settings') as settings_rpc_markers,
  (select bool_or(
    definition ilike '%status%sent%failed%skipped%'
    and definition ilike '%lock_token%'
  ) from rpc_definitions where proname = 'finalize_session_reminder') as finalize_rpc_markers,
  has_function_privilege(
    'service_role',
    'public.preview_due_session_reminders(timestamptz, integer)',
    'execute'
  ) as service_role_can_preview,
  has_function_privilege(
    'service_role',
    'public.claim_due_session_reminders(timestamptz, integer)',
    'execute'
  ) as service_role_can_claim,
  has_function_privilege(
    'service_role',
    'public.finalize_session_reminder(uuid, uuid, text, text, text)',
    'execute'
  ) as service_role_can_finalize,
  has_function_privilege(
    'authenticated',
    'public.update_session_reminder_settings(text, boolean, integer, boolean, integer)',
    'execute'
  ) as authenticated_can_update_settings,
  has_function_privilege(
    'anon',
    'public.preview_due_session_reminders(timestamptz, integer)',
    'execute'
  ) as anon_can_preview,
  has_function_privilege(
    'authenticated',
    'public.preview_due_session_reminders(timestamptz, integer)',
    'execute'
  ) as authenticated_can_preview,
  has_function_privilege(
    'anon',
    'public.claim_due_session_reminders(timestamptz, integer)',
    'execute'
  ) as anon_can_claim,
  has_function_privilege(
    'authenticated',
    'public.claim_due_session_reminders(timestamptz, integer)',
    'execute'
  ) as authenticated_can_claim,
  (select total_count from log_counts) as log_total_count,
  (select shortage_count from log_counts) as shortage_log_count,
  (select gm_count from log_counts) as gm_log_count,
  (select claimed_count from log_counts) as claimed_log_count,
  (select sent_count from log_counts) as sent_log_count,
  (select failed_count from log_counts) as failed_log_count,
  (select skipped_count from log_counts) as skipped_log_count,
  (select changed_schedule_count from historical_shortage_state) as changed_historical_shortage_count,
  (select would_be_due_now_count from historical_shortage_state) as changed_historical_due_now_count,
  (select job_count from cron_state) as cron_job_count,
  (select every_minute from cron_state) as cron_every_minute,
  (select all_active from cron_state) as cron_active,
  (select uses_pg_net from cron_state) as cron_uses_pg_net,
  (select uses_function_url_secret from cron_state) as cron_uses_function_url_secret,
  (select uses_invoke_jwt_secret from cron_state) as cron_uses_invoke_jwt_secret,
  (select uses_dispatch_token_secret from cron_state) as cron_uses_dispatch_token_secret,
  (select uses_production_payload from cron_state) as cron_uses_production_payload,
  (select uses_limit_one from cron_state) as cron_uses_limit_one,
  (select expected_secret_count from vault_state) as expected_vault_secret_count,
  (select run_count from recent_cron) as recent_cron_run_count,
  (select succeeded_count from recent_cron) as recent_cron_succeeded_count,
  (select failed_count from recent_cron) as recent_cron_failed_count,
  (select response_count from runtime_state) as recent_runtime_response_count,
  (select http_2xx_count from runtime_state) as recent_runtime_http_2xx_count,
  (select http_403_count from runtime_state) as recent_runtime_http_403_count,
  (select production_enabled_true_count from runtime_state) as recent_production_enabled_true_count,
  (select discord_send_true_count from runtime_state) as recent_discord_send_true_count,
  (select db_write_true_count from runtime_state) as recent_db_write_true_count,
  (select positive_sent_count from runtime_state) as recent_positive_sent_count,
  (select positive_claimed_count from runtime_state) as recent_positive_claimed_count;
