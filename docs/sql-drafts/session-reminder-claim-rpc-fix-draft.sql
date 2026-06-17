-- DRAFT ONLY.
-- Do not run automatically.
-- Paste into Supabase SQL Editor only after explicit user approval.
-- If any error occurs, stop and do not re-run blindly.
--
-- Purpose:
-- - Harden public.claim_due_session_reminders after Gate 11F returned
--   db_claim_failed / stage=claim_rpc.
-- - Keep the same function signature and return shape.
-- - Do not change table schema, RLS, grants outside this function, or
--   duplicate-prevention semantics.

begin;

create or replace function public.claim_due_session_reminders(
  p_now timestamptz default now(),
  p_limit integer default 10
)
returns table (
  log_id uuid,
  lock_token uuid,
  session_id text,
  reminder_type text,
  title text,
  start_at timestamptz,
  min_players integer,
  pending_count integer,
  accepted_count integer,
  waitlisted_count integer,
  count_for_minimum integer,
  shortage_count integer,
  gm_display_name text,
  gm_discord_user_id text,
  reminder_offset_minutes integer,
  target_channel_key text,
  session_public_id text,
  scheduled_for timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 10), 1), 50);
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'server_role_required' using errcode = '42501';
  end if;

  return query
  with candidates as (
    select
      c.session_id::text as candidate_session_id,
      c.reminder_type::text as candidate_reminder_type,
      c.title::text as candidate_title,
      c.start_at::timestamptz as candidate_start_at,
      c.min_players::integer as candidate_min_players,
      c.pending_count::integer as candidate_pending_count,
      c.accepted_count::integer as candidate_accepted_count,
      c.waitlisted_count::integer as candidate_waitlisted_count,
      c.count_for_minimum::integer as candidate_count_for_minimum,
      c.shortage_count::integer as candidate_shortage_count,
      c.gm_display_name::text as candidate_gm_display_name,
      c.gm_discord_user_id::text as candidate_gm_discord_user_id,
      c.reminder_offset_minutes::integer as candidate_reminder_offset_minutes,
      c.target_channel_key::text as candidate_target_channel_key,
      c.session_public_id::text as candidate_session_public_id,
      c.scheduled_for::timestamptz as candidate_scheduled_for
    from public.preview_due_session_reminders(p_now, v_limit) as c
  ),
  to_insert as (
    select
      c.*,
      gen_random_uuid()::uuid as generated_lock_token,
      now()::timestamptz as claim_time
    from candidates as c
  ),
  inserted as (
    insert into public.session_reminder_logs (
      session_id,
      reminder_type,
      scheduled_for,
      reminder_offset_minutes,
      status,
      dry_run,
      lock_token,
      created_at,
      claimed_at
    )
    select
      ti.candidate_session_id,
      ti.candidate_reminder_type,
      ti.candidate_scheduled_for,
      ti.candidate_reminder_offset_minutes,
      'claimed'::text,
      false::boolean,
      ti.generated_lock_token,
      ti.claim_time,
      ti.claim_time
    from to_insert as ti
    on conflict on constraint session_reminder_logs_unique_session_type do nothing
    returning
      public.session_reminder_logs.id as inserted_log_id,
      public.session_reminder_logs.lock_token as inserted_lock_token,
      public.session_reminder_logs.session_id as inserted_session_id,
      public.session_reminder_logs.reminder_type as inserted_reminder_type
  )
  select
    i.inserted_log_id as log_id,
    i.inserted_lock_token as lock_token,
    ti.candidate_session_id as session_id,
    ti.candidate_reminder_type as reminder_type,
    ti.candidate_title as title,
    ti.candidate_start_at as start_at,
    ti.candidate_min_players as min_players,
    ti.candidate_pending_count as pending_count,
    ti.candidate_accepted_count as accepted_count,
    ti.candidate_waitlisted_count as waitlisted_count,
    ti.candidate_count_for_minimum as count_for_minimum,
    ti.candidate_shortage_count as shortage_count,
    ti.candidate_gm_display_name as gm_display_name,
    ti.candidate_gm_discord_user_id as gm_discord_user_id,
    ti.candidate_reminder_offset_minutes as reminder_offset_minutes,
    ti.candidate_target_channel_key as target_channel_key,
    ti.candidate_session_public_id as session_public_id,
    ti.candidate_scheduled_for as scheduled_for
  from inserted as i
  join to_insert as ti
    on ti.candidate_session_id = i.inserted_session_id
   and ti.candidate_reminder_type = i.inserted_reminder_type
  order by
    ti.candidate_scheduled_for,
    ti.candidate_session_id,
    ti.candidate_reminder_type;
end;
$$;

revoke all on function public.claim_due_session_reminders(timestamptz, integer) from public;
revoke all on function public.claim_due_session_reminders(timestamptz, integer) from anon;
revoke all on function public.claim_due_session_reminders(timestamptz, integer) from authenticated;
grant execute on function public.claim_due_session_reminders(timestamptz, integer) to service_role;

comment on function public.claim_due_session_reminders(timestamptz, integer) is
  'Service-role claim for due session reminders. Uses explicit aliases/casts and the named unique constraint for duplicate prevention.';

commit;

-- SELECT-only post-apply checks.
-- Do not paste row values, Discord ids, session ids, message ids, URLs, or
-- message previews into docs.
-- Do not run claim_due_session_reminders in this checklist.

select
  to_regprocedure('public.claim_due_session_reminders(timestamptz, integer)') is not null as claim_exists,
  has_function_privilege('service_role', 'public.claim_due_session_reminders(timestamptz, integer)', 'execute') as service_role_can_claim,
  has_function_privilege('anon', 'public.claim_due_session_reminders(timestamptz, integer)', 'execute') as anon_can_claim,
  has_function_privilege('authenticated', 'public.claim_due_session_reminders(timestamptz, integer)', 'execute') as authenticated_can_claim;

with output_columns as (
  select
    p.parameter_name,
    p.data_type,
    p.udt_name,
    p.ordinal_position
  from information_schema.routines as r
  join information_schema.parameters as p
    on p.specific_schema = r.specific_schema
   and p.specific_name = r.specific_name
  where r.specific_schema = 'public'
    and r.routine_name = 'claim_due_session_reminders'
    and p.parameter_mode = 'OUT'
)
select
  count(*) as output_column_count,
  bool_or(parameter_name = 'log_id' and udt_name = 'uuid') as has_log_id_uuid,
  bool_or(parameter_name = 'lock_token' and udt_name = 'uuid') as has_lock_token_uuid,
  bool_or(parameter_name = 'gm_discord_user_id' and udt_name = 'text') as has_gm_discord_user_id_text,
  bool_or(parameter_name = 'scheduled_for' and udt_name = 'timestamptz') as has_scheduled_for_timestamptz
from output_columns;

select
  count(*) filter (where conname = 'session_reminder_logs_unique_session_type') as unique_constraint_count,
  count(*) filter (where conname = 'session_reminder_logs_lock_check') as lock_check_count,
  count(*) filter (where conname = 'session_reminder_logs_status_check') as status_check_count,
  count(*) filter (where conname = 'session_reminder_logs_dry_run_check') as dry_run_check_count,
  count(*) filter (where conname = 'session_reminder_logs_offset_check') as offset_check_count
from pg_constraint as c
join pg_class as t
  on t.oid = c.conrelid
join pg_namespace as n
  on n.oid = t.relnamespace
where n.nspname = 'public'
  and t.relname = 'session_reminder_logs';

select count(*)::int as session_reminder_logs_count
from public.session_reminder_logs;
