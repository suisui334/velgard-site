-- SELECT-ONLY POST-APPLY CHECKS.
-- Run only after the apply transaction succeeds in a separate SQL Editor run.
-- Do not call preview, claim, or finalize from this file.
-- Record counts/booleans only; do not record session or Discord values.

select
  'session_revision_column' as check_name,
  count(*) as column_count,
  bool_and(data_type = 'integer') as all_integer,
  bool_and(is_nullable = 'NO') as all_not_null,
  bool_and(column_default is not null) as all_have_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'sessions'
  and column_name = 'shortage_reminder_revision';

select
  'session_revision_constraint' as check_name,
  count(*) filter (
    where conname = 'sessions_shortage_reminder_revision_check'
  ) as constraint_count
from pg_constraint
where conrelid = 'public.sessions'::regclass;

select
  'session_revision_trigger' as check_name,
  count(*) as trigger_count,
  bool_and(tgenabled <> 'D') as all_enabled
from pg_trigger
where tgrelid = 'public.sessions'::regclass
  and tgname = 'sessions_shortage_reminder_revision_trigger'
  and not tgisinternal;

with trigger_function as (
  select pg_get_functiondef(
    'public.bump_session_shortage_reminder_revision()'::regprocedure
  ) as definition
)
select
  'session_revision_trigger_markers' as check_name,
  definition like '%old.date is distinct from new.date%' as checks_date,
  definition like '%old.start_time is distinct from new.start_time%' as checks_start_time,
  definition like '%old.shortage_reminder_enabled is distinct from new.shortage_reminder_enabled%' as checks_enabled,
  definition like '%old.shortage_reminder_hours_before is distinct from new.shortage_reminder_hours_before%' as checks_offset,
  definition like '%new.shortage_reminder_revision := greatest%' as owns_revision
from trigger_function;

select
  'log_revision_column' as check_name,
  count(*) as column_count,
  bool_and(data_type = 'integer') as all_integer,
  bool_and(is_nullable = 'YES') as all_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'session_reminder_logs'
  and column_name = 'shortage_reminder_revision';

select
  'log_revision_constraints' as check_name,
  count(*) filter (
    where conname = 'session_reminder_logs_shortage_revision_check'
  ) as revision_constraint_count,
  count(*) filter (
    where conname = 'session_reminder_logs_unique_session_type'
  ) as old_unique_constraint_count
from pg_constraint
where conrelid = 'public.session_reminder_logs'::regclass;

select
  'per_type_unique_indexes' as check_name,
  count(*) filter (
    where indexname = 'session_reminder_logs_shortage_revision_unique'
      and indexdef like 'CREATE UNIQUE INDEX%'
      and indexdef like '%(session_id, reminder_type, shortage_reminder_revision)%'
      and indexdef like '%WHERE (reminder_type = ''shortage''::text)%'
  ) as shortage_index_count,
  count(*) filter (
    where indexname = 'session_reminder_logs_gm_confirmed_unique'
      and indexdef like 'CREATE UNIQUE INDEX%'
      and indexdef like '%(session_id, reminder_type)%'
      and indexdef like '%WHERE (reminder_type = ''gm_confirmed''::text)%'
  ) as gm_index_count
from pg_indexes
where schemaname = 'public'
  and tablename = 'session_reminder_logs';

select
  'log_access' as check_name,
  c.relrowsecurity as rls_enabled,
  has_table_privilege(
    'anon',
    'public.session_reminder_logs',
    'select'
  ) as anon_select,
  has_table_privilege(
    'authenticated',
    'public.session_reminder_logs',
    'select'
  ) as authenticated_select,
  has_table_privilege(
    'authenticated',
    'public.session_reminder_logs',
    'insert'
  ) as authenticated_insert,
  has_table_privilege(
    'authenticated',
    'public.session_reminder_logs',
    'update'
  ) as authenticated_update,
  has_table_privilege(
    'authenticated',
    'public.session_reminder_logs',
    'delete'
  ) as authenticated_delete
from pg_class as c
where c.oid = 'public.session_reminder_logs'::regclass;

select
  'log_revision_shape' as check_name,
  count(*) filter (
    where reminder_type = 'shortage'
      and (
        shortage_reminder_revision is null
        or shortage_reminder_revision < 1
      )
  ) as invalid_shortage_rows,
  count(*) filter (
    where reminder_type = 'gm_confirmed'
      and shortage_reminder_revision is not null
  ) as invalid_gm_rows,
  count(*) as total_log_count
from public.session_reminder_logs;

with shortage_duplicates as (
  select session_id, reminder_type, shortage_reminder_revision
  from public.session_reminder_logs
  where reminder_type = 'shortage'
  group by session_id, reminder_type, shortage_reminder_revision
  having count(*) > 1
),
gm_duplicates as (
  select session_id, reminder_type
  from public.session_reminder_logs
  where reminder_type = 'gm_confirmed'
  group by session_id, reminder_type
  having count(*) > 1
)
select
  'duplicate_groups' as check_name,
  (select count(*) from shortage_duplicates) as shortage_duplicate_group_count,
  (select count(*) from gm_duplicates) as gm_duplicate_group_count;

select
  'historical_revision_alignment' as check_name,
  count(*) filter (
    where l.reminder_type = 'shortage'
      and l.shortage_reminder_revision = s.shortage_reminder_revision
  ) as current_revision_shortage_logs,
  count(*) filter (
    where l.reminder_type = 'shortage'
      and l.shortage_reminder_revision < s.shortage_reminder_revision
  ) as historical_revision_shortage_logs,
  count(*) filter (
    where l.reminder_type = 'shortage'
      and l.shortage_reminder_revision > s.shortage_reminder_revision
  ) as invalid_future_revision_logs,
  count(*) filter (
    where l.reminder_type = 'gm_confirmed'
      and l.shortage_reminder_revision is not null
  ) as invalid_gm_revision_logs
from public.session_reminder_logs as l
join public.sessions as s on s.id = l.session_id;

select
  'rpc_presence' as check_name,
  to_regprocedure(
    'public.preview_due_session_reminders(timestamptz, integer)'
  ) is not null as preview_exists,
  to_regprocedure(
    'public.claim_due_session_reminders(timestamptz, integer)'
  ) is not null as claim_exists,
  to_regprocedure(
    'public.finalize_session_reminder(uuid, uuid, text, text, text)'
  ) is not null as finalize_exists,
  to_regprocedure(
    'public.update_session_reminder_settings(text, boolean, integer, boolean, integer)'
  ) is not null as settings_exists;

select
  'rpc_security' as check_name,
  bool_and(p.prosecdef) as all_security_definer
from pg_proc as p
join pg_namespace as n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'preview_due_session_reminders',
    'claim_due_session_reminders',
    'finalize_session_reminder',
    'update_session_reminder_settings'
  );

select
  'rpc_privileges' as check_name,
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
  ) as authenticated_can_claim;

with output_columns as (
  select
    r.routine_name,
    count(*) filter (where p.parameter_mode = 'OUT')::integer as output_count,
    max(p.ordinal_position) filter (
      where p.parameter_mode = 'OUT'
        and p.parameter_name = 'shortage_reminder_revision'
        and p.data_type = 'integer'
    ) as revision_ordinal
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
)
select
  'rpc_return_shapes' as check_name,
  max(output_count) filter (
    where routine_name = 'preview_due_session_reminders'
  ) as preview_output_count,
  max(output_count) filter (
    where routine_name = 'claim_due_session_reminders'
  ) as claim_output_count,
  max(revision_ordinal) filter (
    where routine_name = 'preview_due_session_reminders'
  ) as preview_revision_ordinal,
  max(revision_ordinal) filter (
    where routine_name = 'claim_due_session_reminders'
  ) as claim_revision_ordinal
from output_columns;

with rpc_definitions as (
  select
    p.proname,
    pg_get_functiondef(p.oid) as definition
  from pg_proc as p
  join pg_namespace as n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.oid in (
      to_regprocedure('public.preview_due_session_reminders(timestamptz, integer)'),
      to_regprocedure('public.claim_due_session_reminders(timestamptz, integer)')
    )
)
select
  'rpc_revision_markers' as check_name,
  bool_or(
    proname = 'preview_due_session_reminders'
    and definition like '%l.shortage_reminder_revision = c.shortage_reminder_revision%'
    and definition like '%or c.reminder_type = ''gm_confirmed''%'
  ) as preview_separates_shortage_and_gm,
  bool_or(
    proname = 'claim_due_session_reminders'
    and definition like '%c.shortage_reminder_revision::integer%'
    and definition like '%on conflict do nothing%'
    and definition like '%inserted_shortage_reminder_revision%'
  ) as claim_carries_preview_revision
from rpc_definitions;

-- Expected after apply:
-- - preview_output_count = 17, preview_revision_ordinal = 17
-- - claim_output_count = 19, claim_revision_ordinal = 19
-- - old_unique_constraint_count = 0
-- - both per-type unique index counts = 1
-- - invalid/duplicate/future revision counts = 0
-- - GM rows keep null revision and one-log-per-session behavior
--
-- Do not execute these RPCs in this metadata gate:
-- select * from public.preview_due_session_reminders(...);
-- select * from public.claim_due_session_reminders(...);
-- select * from public.finalize_session_reminder(...);
