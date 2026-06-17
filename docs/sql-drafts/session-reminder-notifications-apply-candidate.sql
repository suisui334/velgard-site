-- session-reminder-notifications-apply-candidate.sql
-- APPLY CANDIDATE ONLY.
-- Do not run automatically.
-- Paste into Supabase SQL Editor only after explicit user approval.
-- If any error occurs, stop and do not re-run blindly.
--
-- Purpose:
-- - Add DB/RPC support for optional session start reminders.
-- - This file is still a docs/sql-drafts apply candidate, not a migration.
-- - Do not move this file to supabase/migrations without a separate gate.
--
-- Scope:
-- - Add reminder setting columns to public.sessions.
-- - Add public.session_reminder_logs for production duplicate prevention.
-- - Add an owner/admin settings RPC.
-- - Add service-role-only preview, claim, and finalize RPCs for a later Edge
--   Function gate.
-- - Add SELECT-only post-apply checks at the end.
--
-- Out of scope:
-- - No Edge Function deploy.
-- - No Discord dry run or production send.
-- - No secret or Webhook value.
-- - No raw user id, email, JWT, management key, or Discord id value.
-- - No UI, HTML, CSS, JS, or updates.json change.

begin;

-- ============================================================
-- 1. Session reminder settings
-- ============================================================
-- Existing table names and status values were reviewed against the current
-- SQL docs:
-- - public.sessions
-- - public.session_applications
-- - sessions.status:
--   draft / tentative / recruiting / full / closed / finished / canceled
-- - session_applications.status:
--   pending / accepted / rejected / waitlisted / canceled
--
-- Timing policy:
-- - Enabled reminders require a valid timing value.
-- - Disabled reminders require null timing values.
-- - Existing rows default to disabled and keep timing null.

alter table public.sessions
  add column if not exists shortage_reminder_enabled boolean not null default false,
  add column if not exists shortage_reminder_hours_before integer,
  add column if not exists gm_reminder_enabled boolean not null default false,
  add column if not exists gm_reminder_minutes_before integer;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.sessions'::regclass
      and conname = 'sessions_shortage_reminder_config_check'
  ) then
    alter table public.sessions
      add constraint sessions_shortage_reminder_config_check
      check (
        (
          shortage_reminder_enabled = false
          and shortage_reminder_hours_before is null
        )
        or (
          shortage_reminder_enabled = true
          and shortage_reminder_hours_before in (1, 2, 3)
        )
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.sessions'::regclass
      and conname = 'sessions_gm_reminder_config_check'
  ) then
    alter table public.sessions
      add constraint sessions_gm_reminder_config_check
      check (
        (
          gm_reminder_enabled = false
          and gm_reminder_minutes_before is null
        )
        or (
          gm_reminder_enabled = true
          and gm_reminder_minutes_before in (30, 60)
        )
      );
  end if;
end $$;

comment on column public.sessions.shortage_reminder_enabled is
  'Optional shortage reminder flag. Production @everyone delivery requires a separate gate.';

comment on column public.sessions.shortage_reminder_hours_before is
  'Allowed values when enabled: 1, 2, 3. Stored as hours before session start.';

comment on column public.sessions.gm_reminder_enabled is
  'Optional GM confirmed reminder flag. First version routes to a channel with GM display name.';

comment on column public.sessions.gm_reminder_minutes_before is
  'Allowed values when enabled: 30, 60. Stored as minutes before session start.';

-- ============================================================
-- 2. Reminder log table
-- ============================================================
-- First-version duplicate policy:
-- - unique(session_id, reminder_type)
-- - One production log per session/reminder type.
-- - No automatic resend after start time or timing edits.
-- - Future resend support should add a manual reset/log invalidation gate, or
--   replace the unique key with a reviewed scheduled_for/offset-based key.
--
-- dry_run policy:
-- - dry-run/preview must not write rows.
-- - dry_run is kept as a defensive column and constrained to false for this
--   first production-only log table.

create table if not exists public.session_reminder_logs (
  id uuid primary key default gen_random_uuid(),
  session_id text not null references public.sessions(id) on delete cascade,
  reminder_type text not null,
  scheduled_for timestamptz not null,
  reminder_offset_minutes integer not null,
  status text not null default 'claimed',
  dry_run boolean not null default false,
  lock_token uuid,
  discord_message_id text,
  error_message text,
  created_at timestamptz not null default now(),
  claimed_at timestamptz,
  sent_at timestamptz,
  finalized_at timestamptz,
  constraint session_reminder_logs_type_check
    check (reminder_type in ('shortage', 'gm_confirmed')),
  constraint session_reminder_logs_status_check
    check (status in ('claimed', 'sent', 'failed', 'skipped')),
  constraint session_reminder_logs_offset_check
    check (reminder_offset_minutes in (30, 60, 120, 180)),
  constraint session_reminder_logs_dry_run_check
    check (dry_run = false),
  constraint session_reminder_logs_lock_check
    check (status <> 'claimed' or (claimed_at is not null and lock_token is not null)),
  constraint session_reminder_logs_discord_message_id_check
    check (
      discord_message_id is null
      or (
        char_length(trim(discord_message_id)) between 1 and 120
        and discord_message_id !~ '[[:space:]]'
      )
    ),
  constraint session_reminder_logs_error_message_check
    check (error_message is null or char_length(error_message) <= 500),
  constraint session_reminder_logs_sent_at_check
    check (status <> 'sent' or sent_at is not null),
  constraint session_reminder_logs_finalized_at_check
    check (status = 'claimed' or finalized_at is not null),
  constraint session_reminder_logs_unique_session_type
    unique (session_id, reminder_type)
);

create index if not exists session_reminder_logs_session_idx
  on public.session_reminder_logs (session_id);

create index if not exists session_reminder_logs_status_idx
  on public.session_reminder_logs (status, created_at);

create index if not exists session_reminder_logs_type_idx
  on public.session_reminder_logs (reminder_type, status);

create index if not exists session_reminder_logs_claim_idx
  on public.session_reminder_logs (status, claimed_at)
  where status = 'claimed';

alter table public.session_reminder_logs enable row level security;

revoke all on table public.session_reminder_logs from anon;
revoke all on table public.session_reminder_logs from authenticated;

comment on table public.session_reminder_logs is
  'Production session reminder claim/finalize log. Dry-run previews must not write rows.';

comment on column public.session_reminder_logs.lock_token is
  'Claim token for the Edge Function finalize step. Do not expose to browser clients.';

comment on column public.session_reminder_logs.discord_message_id is
  'Optional provider message identifier recorded after successful delivery. Do not expose in browser or docs.';

comment on constraint session_reminder_logs_unique_session_type
  on public.session_reminder_logs is
  'First-version duplicate prevention: one logged reminder per session and reminder type. Manual reset is a later gate.';

-- ============================================================
-- 3. Owner/admin settings RPC
-- ============================================================
-- This candidate uses a dedicated settings RPC instead of changing
-- create_session_post/update_session_post signatures in the same gate. That
-- avoids PostgREST overload ambiguity and keeps the UI integration gate
-- smaller.

create or replace function public.update_session_reminder_settings(
  p_session_id text,
  p_shortage_reminder_enabled boolean,
  p_shortage_reminder_hours_before integer default null,
  p_gm_reminder_enabled boolean default false,
  p_gm_reminder_minutes_before integer default null
)
returns table (
  session_id text,
  shortage_reminder_enabled boolean,
  shortage_reminder_hours_before integer,
  gm_reminder_enabled boolean,
  gm_reminder_minutes_before integer,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_session_id text := nullif(btrim(coalesce(p_session_id, '')), '');
  v_shortage_enabled boolean := coalesce(p_shortage_reminder_enabled, false);
  v_shortage_hours integer := p_shortage_reminder_hours_before;
  v_gm_enabled boolean := coalesce(p_gm_reminder_enabled, false);
  v_gm_minutes integer := p_gm_reminder_minutes_before;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  if v_session_id is null then
    raise exception 'session_id_required' using errcode = '22023';
  end if;

  if not (
    coalesce(public.is_admin(), false)
    or coalesce(public.is_session_gm(v_session_id), false)
  ) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if v_shortage_enabled then
    if v_shortage_hours not in (1, 2, 3) then
      raise exception 'invalid_shortage_reminder_hours_before' using errcode = '22023';
    end if;
  else
    v_shortage_hours := null;
  end if;

  if v_gm_enabled then
    if v_gm_minutes not in (30, 60) then
      raise exception 'invalid_gm_reminder_minutes_before' using errcode = '22023';
    end if;
  else
    v_gm_minutes := null;
  end if;

  return query
  update public.sessions as s
  set
    shortage_reminder_enabled = v_shortage_enabled,
    shortage_reminder_hours_before = v_shortage_hours,
    gm_reminder_enabled = v_gm_enabled,
    gm_reminder_minutes_before = v_gm_minutes,
    updated_at = now()
  where s.id = v_session_id
  returning
    s.id,
    s.shortage_reminder_enabled,
    s.shortage_reminder_hours_before,
    s.gm_reminder_enabled,
    s.gm_reminder_minutes_before,
    s.updated_at;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.update_session_reminder_settings(text, boolean, integer, boolean, integer) from public;
revoke all on function public.update_session_reminder_settings(text, boolean, integer, boolean, integer) from anon;
grant execute on function public.update_session_reminder_settings(text, boolean, integer, boolean, integer) to authenticated;

comment on function public.update_session_reminder_settings(text, boolean, integer, boolean, integer) is
  'Owner/admin RPC to update per-session reminder settings. Does not reset sent reminder logs.';

-- ============================================================
-- 4. Preview RPC
-- ============================================================
-- preview_due_session_reminders:
-- - DB write: none.
-- - Discord request: none.
-- - Intended caller: later Edge Function dry-run using service role.
-- - Returns safe values needed to build a message, not a message body.
-- - Does not return raw user IDs, emails, Discord IDs, provider URLs, or
--   secret values.
--
-- Count policy:
-- - pending_count = distinct session_applications.user_id where status='pending'
-- - accepted_count = distinct session_applications.user_id where status='accepted'
-- - waitlisted_count is returned but excluded from count_for_minimum.
-- - count_for_minimum = pending_count + accepted_count
--
-- Deadline policy:
-- - Shortage reminder initially skips sessions after application_deadline when
--   a deadline exists.
-- - GM reminder does not use application_deadline in this candidate.
--
-- Status policy:
-- - shortage: tentative / recruiting only.
-- - gm_confirmed: tentative / recruiting / full.
-- - all reminders: visibility public, future start, positive player_min.

create or replace function public.preview_due_session_reminders(
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
      s.status,
      s.visibility,
      s.application_deadline,
      s.shortage_reminder_enabled,
      s.shortage_reminder_hours_before,
      s.gm_reminder_enabled,
      s.gm_reminder_minutes_before
    from public.sessions as s
    left join app_counts as ac on ac.session_id = s.id
    where s.visibility = 'public'
      and s.start_time is not null
      and s.player_min is not null
      and s.player_min > 0
  ),
  candidates as (
    select
      b.id as session_id,
      'shortage'::text as reminder_type,
      b.title,
      b.start_at,
      b.player_min as min_players,
      b.pending_count,
      b.accepted_count,
      b.waitlisted_count,
      (b.pending_count + b.accepted_count)::integer as count_for_minimum,
      greatest(b.player_min - (b.pending_count + b.accepted_count), 0)::integer as shortage_count,
      b.gm_display_name,
      (b.shortage_reminder_hours_before * 60)::integer as reminder_offset_minutes,
      'session_reminder'::text as target_channel_key,
      b.id as session_public_id,
      b.start_at as scheduled_for
    from base_sessions as b
    where b.shortage_reminder_enabled = true
      and b.shortage_reminder_hours_before in (1, 2, 3)
      and b.status in ('tentative', 'recruiting')
      and b.start_at > p_now
      and (b.start_at - make_interval(mins => b.shortage_reminder_hours_before * 60)) <= p_now
      and (
        b.application_deadline is null
        or b.application_deadline > p_now
      )
      and (b.pending_count + b.accepted_count) < b.player_min

    union all

    select
      b.id as session_id,
      'gm_confirmed'::text as reminder_type,
      b.title,
      b.start_at,
      b.player_min as min_players,
      b.pending_count,
      b.accepted_count,
      b.waitlisted_count,
      (b.pending_count + b.accepted_count)::integer as count_for_minimum,
      0::integer as shortage_count,
      b.gm_display_name,
      b.gm_reminder_minutes_before::integer as reminder_offset_minutes,
      'session_reminder'::text as target_channel_key,
      b.id as session_public_id,
      b.start_at as scheduled_for
    from base_sessions as b
    where b.gm_reminder_enabled = true
      and b.gm_reminder_minutes_before in (30, 60)
      and b.status in ('tentative', 'recruiting', 'full')
      and b.start_at > p_now
      and (b.start_at - make_interval(mins => b.gm_reminder_minutes_before)) <= p_now
      and (b.pending_count + b.accepted_count) >= b.player_min
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
  )
  order by c.start_at, c.reminder_type, c.session_id
  limit v_limit;
end;
$$;

revoke all on function public.preview_due_session_reminders(timestamptz, integer) from public;
revoke all on function public.preview_due_session_reminders(timestamptz, integer) from anon;
revoke all on function public.preview_due_session_reminders(timestamptz, integer) from authenticated;
grant execute on function public.preview_due_session_reminders(timestamptz, integer) to service_role;

comment on function public.preview_due_session_reminders(timestamptz, integer) is
  'Service-role dry-run preview for due session reminders. Must not write DB rows or send Discord messages.';

-- ============================================================
-- 5. Claim RPC
-- ============================================================
-- claim_due_session_reminders:
-- - DB write: inserts claimed session_reminder_logs rows.
-- - Discord request: none.
-- - Intended caller: later server-side Edge Function only.
-- - Uses unique(session_id, reminder_type) and ON CONFLICT DO NOTHING.
-- - Returns only rows successfully claimed by this call.

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
    c.reminder_offset_minutes,
    c.target_channel_key,
    c.session_public_id,
    c.scheduled_for
  from inserted as i
  join candidates as c
    on c.session_id = i.session_id
   and c.reminder_type = i.reminder_type
  order by c.start_at, c.reminder_type, c.session_id;
end;
$$;

revoke all on function public.claim_due_session_reminders(timestamptz, integer) from public;
revoke all on function public.claim_due_session_reminders(timestamptz, integer) from anon;
revoke all on function public.claim_due_session_reminders(timestamptz, integer) from authenticated;
grant execute on function public.claim_due_session_reminders(timestamptz, integer) to service_role;

comment on function public.claim_due_session_reminders(timestamptz, integer) is
  'Service-role production claim for due session reminders. Do not call from browser clients.';

-- ============================================================
-- 6. Finalize RPC
-- ============================================================
-- finalize_session_reminder:
-- - DB write: updates an existing claimed log only.
-- - Discord request: none.
-- - Requires id + lock_token to prevent cross-claim finalization.
-- - p_discord_message_id is stored only after successful delivery and must not
--   be exposed in docs or browser APIs.
-- - p_error_message should be a short generalized code/string.

create or replace function public.finalize_session_reminder(
  p_log_id uuid,
  p_lock_token uuid,
  p_status text,
  p_discord_message_id text default null,
  p_error_message text default null
)
returns table (
  log_id uuid,
  session_id text,
  reminder_type text,
  status text,
  sent_at timestamptz,
  finalized_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
  v_message_id text := nullif(btrim(coalesce(p_discord_message_id, '')), '');
  v_error_message text := nullif(left(btrim(coalesce(p_error_message, '')), 500), '');
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'server_role_required' using errcode = '42501';
  end if;

  if p_log_id is null or p_lock_token is null then
    raise exception 'claim_identifier_required' using errcode = '22023';
  end if;

  if v_status not in ('sent', 'failed', 'skipped') then
    raise exception 'invalid_reminder_finalize_status' using errcode = '22023';
  end if;

  if v_status = 'sent' and v_message_id is null then
    raise exception 'discord_message_id_required' using errcode = '22023';
  end if;

  if v_message_id is not null and (
    char_length(v_message_id) > 120
    or v_message_id ~ '[[:space:]]'
  ) then
    raise exception 'invalid_discord_message_id' using errcode = '22023';
  end if;

  return query
  update public.session_reminder_logs as l
  set
    status = v_status,
    lock_token = null,
    discord_message_id = case when v_status = 'sent' then v_message_id else null end,
    error_message = case when v_status in ('failed', 'skipped') then v_error_message else null end,
    sent_at = case when v_status = 'sent' then now() else null end,
    finalized_at = now()
  where l.id = p_log_id
    and l.lock_token = p_lock_token
    and l.status = 'claimed'
  returning
    l.id as log_id,
    l.session_id,
    l.reminder_type,
    l.status,
    l.sent_at,
    l.finalized_at;

  if not found then
    raise exception 'session_reminder_log_not_claimed' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.finalize_session_reminder(uuid, uuid, text, text, text) from public;
revoke all on function public.finalize_session_reminder(uuid, uuid, text, text, text) from anon;
revoke all on function public.finalize_session_reminder(uuid, uuid, text, text, text) from authenticated;
grant execute on function public.finalize_session_reminder(uuid, uuid, text, text, text) to service_role;

comment on function public.finalize_session_reminder(uuid, uuid, text, text, text) is
  'Service-role finalize for claimed session reminders. Uses id plus lock_token and stores generalized result state.';

commit;

-- ============================================================
-- 7. SELECT-only post-apply checks
-- ============================================================
-- These checks are read-only. They do not send Discord messages and do not
-- write reminder logs.
--
-- Do not paste real user identifiers, emails, tokens, Discord ids, Discord
-- URLs, Webhook values, or provider message identifiers into result docs.

select
  'sessions_reminder_columns' as check_name,
  count(*) filter (
    where column_name in (
      'shortage_reminder_enabled',
      'shortage_reminder_hours_before',
      'gm_reminder_enabled',
      'gm_reminder_minutes_before'
    )
  ) as found_column_count
from information_schema.columns
where table_schema = 'public'
  and table_name = 'sessions';

select
  'sessions_reminder_constraints' as check_name,
  count(*) filter (
    where conname in (
      'sessions_shortage_reminder_config_check',
      'sessions_gm_reminder_config_check'
    )
  ) as found_constraint_count
from pg_constraint
where conrelid = 'public.sessions'::regclass;

select
  'session_reminder_logs_table' as check_name,
  to_regclass('public.session_reminder_logs') is not null as exists;

select
  'session_reminder_logs_constraints' as check_name,
  count(*) filter (
    where conname in (
      'session_reminder_logs_type_check',
      'session_reminder_logs_status_check',
      'session_reminder_logs_offset_check',
      'session_reminder_logs_dry_run_check',
      'session_reminder_logs_lock_check',
      'session_reminder_logs_unique_session_type'
    )
  ) as found_constraint_count
from pg_constraint
where conrelid = 'public.session_reminder_logs'::regclass;

select
  'session_reminder_logs_rls' as check_name,
  relrowsecurity as rls_enabled,
  relforcerowsecurity as rls_forced
from pg_class
where oid = 'public.session_reminder_logs'::regclass;

select
  'session_reminder_logs_direct_privileges' as check_name,
  has_table_privilege('anon', 'public.session_reminder_logs', 'select') as anon_select,
  has_table_privilege('authenticated', 'public.session_reminder_logs', 'select') as authenticated_select,
  has_table_privilege('authenticated', 'public.session_reminder_logs', 'insert') as authenticated_insert,
  has_table_privilege('authenticated', 'public.session_reminder_logs', 'update') as authenticated_update,
  has_table_privilege('authenticated', 'public.session_reminder_logs', 'delete') as authenticated_delete;

select
  'session_reminder_rpc_exists' as check_name,
  proname,
  prosecdef as security_definer,
  pg_get_function_identity_arguments(p.oid) as arguments
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'update_session_reminder_settings',
    'preview_due_session_reminders',
    'claim_due_session_reminders',
    'finalize_session_reminder'
  )
order by proname, arguments;

select
  'session_reminder_rpc_privileges' as check_name,
  has_function_privilege(
    'authenticated',
    'public.update_session_reminder_settings(text, boolean, integer, boolean, integer)',
    'execute'
  ) as authenticated_can_update_settings,
  has_function_privilege(
    'anon',
    'public.update_session_reminder_settings(text, boolean, integer, boolean, integer)',
    'execute'
  ) as anon_can_update_settings,
  has_function_privilege(
    'service_role',
    'public.preview_due_session_reminders(timestamptz, integer)',
    'execute'
  ) as service_role_can_preview,
  has_function_privilege(
    'authenticated',
    'public.preview_due_session_reminders(timestamptz, integer)',
    'execute'
  ) as authenticated_can_preview,
  has_function_privilege(
    'service_role',
    'public.claim_due_session_reminders(timestamptz, integer)',
    'execute'
  ) as service_role_can_claim,
  has_function_privilege(
    'service_role',
    'public.finalize_session_reminder(uuid, uuid, text, text, text)',
    'execute'
  ) as service_role_can_finalize;

select
  'sessions_count_after_apply' as check_name,
  count(*) as sessions_count
from public.sessions;

select
  'default_enabled_rows_after_apply' as check_name,
  count(*) filter (where shortage_reminder_enabled = true) as shortage_enabled_count,
  count(*) filter (where gm_reminder_enabled = true) as gm_enabled_count
from public.sessions;

select
  'session_reminder_logs_count_after_apply' as check_name,
  count(*) as log_count
from public.session_reminder_logs;

-- Optional later dry-run check:
-- - Do not run in this apply gate unless service-role execution context is
--   intentionally available and approved.
-- - If it is ever run, record only counts/status, not raw row values.
-- select count(*) from public.preview_due_session_reminders(now(), 10);
