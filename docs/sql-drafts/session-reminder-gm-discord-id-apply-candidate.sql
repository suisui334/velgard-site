-- APPLY CANDIDATE ONLY.
-- Do not run automatically.
-- Paste into Supabase SQL Editor only after explicit user approval.
-- If any error occurs, stop and do not re-run blindly.
--
-- Purpose:
-- - Add gm_discord_user_id to service-role-only session reminder preview/claim RPCs.
-- - Source the value from the session GM profile contact only.
-- - Return null unless the stored value is a Discord snowflake-like numeric id.
-- - Do not expose this value through public/browser RPCs.
-- - Gate 6.4 applied a corrected no-UNION version manually after the first
--   UNION-based candidate failed and was rolled back.
--
-- Safety:
-- - This draft does not change tables, RLS policies, browser grants, Edge Functions, or Webhook secrets.
-- - This draft does not execute preview_due_session_reminders.
-- - This draft does not write session_reminder_logs except through the existing claim RPC when a later production flow calls it.
-- - Do not record real Discord ids in docs or reports.

begin;

-- Return type changes require drop/recreate. Drop claim first because it calls preview.
drop function if exists public.claim_due_session_reminders(timestamptz, integer);
drop function if exists public.preview_due_session_reminders(timestamptz, integer);

create function public.preview_due_session_reminders(
  p_now timestamptz default now(),
  p_limit integer default 50
)
returns table (
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
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'server_role_required' using errcode = '42501';
  end if;

  return query
  with app_counts as (
    select
      sa.session_id,
      count(distinct sa.user_id) filter (where sa.status = 'pending')::integer as pending_count,
      count(distinct sa.user_id) filter (where sa.status = 'accepted')::integer as accepted_count,
      count(distinct sa.user_id) filter (where sa.status = 'waitlisted')::integer as waitlisted_count
    from public.session_applications as sa
    where sa.status in ('pending', 'accepted', 'waitlisted')
    group by sa.session_id
  ),
  base_sessions as (
    select
      s.id,
      s.title,
      (s.date + s.start_time)::timestamp at time zone 'Asia/Tokyo' as start_at,
      s.player_min,
      coalesce(ac.pending_count, 0) as pending_count,
      coalesce(ac.accepted_count, 0) as accepted_count,
      coalesce(ac.waitlisted_count, 0) as waitlisted_count,
      coalesce(nullif(btrim(s.gm_name), ''), 'GM') as gm_display_name,
      case
        when nullif(btrim(gm_profile.discord_handle), '') ~ '^[0-9]{17,20}$'
          then nullif(btrim(gm_profile.discord_handle), '')::text
        else null::text
      end as gm_discord_user_id,
      s.status,
      s.visibility,
      s.application_deadline,
      s.shortage_reminder_enabled,
      s.shortage_reminder_hours_before,
      s.gm_reminder_enabled,
      s.gm_reminder_minutes_before
    from public.sessions as s
    left join app_counts as ac on ac.session_id = s.id
    left join public.profiles as gm_profile on gm_profile.id = s.gm_user_id
    where s.visibility = 'public'
      and s.start_time is not null
      and s.player_min is not null
      and s.player_min > 0
  ),
  candidate_types(reminder_type) as (
    values
      ('shortage'::text),
      ('gm_confirmed'::text)
  ),
  candidates as (
    select
      b.id as session_id,
      ct.reminder_type,
      b.title,
      b.start_at,
      b.player_min as min_players,
      b.pending_count,
      b.accepted_count,
      b.waitlisted_count,
      (b.pending_count + b.accepted_count)::integer as count_for_minimum,
      case
        when ct.reminder_type = 'shortage'
          then greatest(b.player_min - (b.pending_count + b.accepted_count), 0)::integer
        else 0::integer
      end as shortage_count,
      b.gm_display_name,
      case
        when ct.reminder_type = 'gm_confirmed' then b.gm_discord_user_id
        else null::text
      end as gm_discord_user_id,
      case
        when ct.reminder_type = 'shortage'
          then (b.shortage_reminder_hours_before * 60)::integer
        else b.gm_reminder_minutes_before::integer
      end as reminder_offset_minutes,
      'session_reminder'::text as target_channel_key,
      b.id as session_public_id,
      b.start_at as scheduled_for
    from base_sessions as b
    cross join candidate_types as ct
    where b.start_at > p_now
      and (
        (
          ct.reminder_type = 'shortage'
          and b.shortage_reminder_enabled = true
          and b.shortage_reminder_hours_before in (1, 2, 3)
          and b.status in ('tentative', 'recruiting')
          and (b.start_at - make_interval(mins => b.shortage_reminder_hours_before * 60)) <= p_now
          and (
            b.application_deadline is null
            or b.application_deadline > p_now
          )
          and (b.pending_count + b.accepted_count) < b.player_min
        )
        or
        (
          ct.reminder_type = 'gm_confirmed'
          and b.gm_reminder_enabled = true
          and b.gm_reminder_minutes_before in (30, 60)
          and b.status in ('tentative', 'recruiting', 'full')
          and (b.start_at - make_interval(mins => b.gm_reminder_minutes_before)) <= p_now
          and (b.pending_count + b.accepted_count) >= b.player_min
        )
      )
  )
  select
    c.session_id,
    c.reminder_type,
    c.title,
    c.start_at,
    c.min_players,
    c.pending_count,
    c.accepted_count,
    c.waitlisted_count,
    c.count_for_minimum,
    c.shortage_count,
    c.gm_display_name,
    c.gm_discord_user_id,
    c.reminder_offset_minutes,
    c.target_channel_key,
    c.session_public_id,
    c.scheduled_for
  from candidates as c
  where not exists (
    select 1
    from public.session_reminder_logs as l
    where l.session_id = c.session_id
      and l.reminder_type = c.reminder_type
      and l.status in ('claimed', 'sent', 'failed', 'skipped')
  )
  order by c.scheduled_for, c.session_id, c.reminder_type
  limit v_limit;
end;
$$;

revoke all on function public.preview_due_session_reminders(timestamptz, integer) from public;
revoke all on function public.preview_due_session_reminders(timestamptz, integer) from anon;
revoke all on function public.preview_due_session_reminders(timestamptz, integer) from authenticated;
grant execute on function public.preview_due_session_reminders(timestamptz, integer) to service_role;

comment on function public.preview_due_session_reminders(timestamptz, integer) is
  'Service-role preview for due session reminders. Returns sanitized GM Discord user id only when the GM profile contact is a 17-20 digit Discord snowflake-like id.';

create function public.claim_due_session_reminders(
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
    select *
    from public.preview_due_session_reminders(p_now, v_limit)
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
      c.session_id,
      c.reminder_type,
      c.scheduled_for,
      c.reminder_offset_minutes,
      'claimed',
      false,
      gen_random_uuid(),
      now(),
      now()
    from candidates as c
    on conflict (session_id, reminder_type) do nothing
    returning
      public.session_reminder_logs.id,
      public.session_reminder_logs.lock_token,
      public.session_reminder_logs.session_id,
      public.session_reminder_logs.reminder_type
  )
  select
    i.id as log_id,
    i.lock_token,
    c.session_id,
    c.reminder_type,
    c.title,
    c.start_at,
    c.min_players,
    c.pending_count,
    c.accepted_count,
    c.waitlisted_count,
    c.count_for_minimum,
    c.shortage_count,
    c.gm_display_name,
    c.gm_discord_user_id,
    c.reminder_offset_minutes,
    c.target_channel_key,
    c.session_public_id,
    c.scheduled_for
  from inserted as i
  join candidates as c
    on c.session_id = i.session_id
   and c.reminder_type = i.reminder_type
  order by c.scheduled_for, c.session_id, c.reminder_type;
end;
$$;

revoke all on function public.claim_due_session_reminders(timestamptz, integer) from public;
revoke all on function public.claim_due_session_reminders(timestamptz, integer) from anon;
revoke all on function public.claim_due_session_reminders(timestamptz, integer) from authenticated;
grant execute on function public.claim_due_session_reminders(timestamptz, integer) to service_role;

comment on function public.claim_due_session_reminders(timestamptz, integer) is
  'Service-role claim for due session reminders. Returns the sanitized GM Discord user id from preview for production dispatch, without exposing it to browser roles.';

commit;

-- SELECT-only post-apply checks.
-- Do not paste row values, Discord ids, session ids, or message previews into docs.
-- Do not run preview_due_session_reminders here unless a later gate explicitly approves service-role dry-run.

select
  'session_reminder_gm_discord_id_rpc_presence' as check_name,
  to_regprocedure('public.preview_due_session_reminders(timestamptz, integer)') is not null as preview_exists,
  to_regprocedure('public.claim_due_session_reminders(timestamptz, integer)') is not null as claim_exists;

with routine_columns as (
  select
    r.routine_name,
    p.parameter_name
  from information_schema.routines as r
  join information_schema.parameters as p
    on p.specific_schema = r.specific_schema
   and p.specific_name = r.specific_name
  where r.specific_schema = 'public'
    and r.routine_name in ('preview_due_session_reminders', 'claim_due_session_reminders')
    and p.parameter_mode = 'OUT'
)
select
  'session_reminder_gm_discord_id_return_columns' as check_name,
  bool_or(routine_name = 'preview_due_session_reminders' and parameter_name = 'gm_discord_user_id') as preview_has_gm_discord_user_id,
  bool_or(routine_name = 'claim_due_session_reminders' and parameter_name = 'gm_discord_user_id') as claim_has_gm_discord_user_id
from routine_columns;

select
  'session_reminder_gm_discord_id_security_definer' as check_name,
  bool_and(p.prosecdef) as all_security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('preview_due_session_reminders', 'claim_due_session_reminders');

select
  'session_reminder_gm_discord_id_execute_privileges' as check_name,
  has_function_privilege('service_role', 'public.preview_due_session_reminders(timestamptz, integer)', 'execute') as service_role_can_preview,
  has_function_privilege('service_role', 'public.claim_due_session_reminders(timestamptz, integer)', 'execute') as service_role_can_claim,
  has_function_privilege('anon', 'public.preview_due_session_reminders(timestamptz, integer)', 'execute') as anon_can_preview,
  has_function_privilege('anon', 'public.claim_due_session_reminders(timestamptz, integer)', 'execute') as anon_can_claim,
  has_function_privilege('authenticated', 'public.preview_due_session_reminders(timestamptz, integer)', 'execute') as authenticated_can_preview,
  has_function_privilege('authenticated', 'public.claim_due_session_reminders(timestamptz, integer)', 'execute') as authenticated_can_claim;

select
  'session_reminder_logs_count_reference_only' as check_name,
  count(*) as session_reminder_logs_count
from public.session_reminder_logs;
