-- session-reminder-notifications-draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
-- DESIGN DRAFT ONLY
--
-- Purpose:
-- - Draft DB/RPC design for optional Discord reminders before a session starts.
-- - This file is intentionally under docs/sql-drafts, not supabase/migrations.
-- - It is a review artifact for the next gate, not an executable migration.
--
-- Feature scope:
-- - Shortage reminder: public channel reminder with separately gated @everyone.
-- - GM confirmed reminder: first version routes to an existing Discord
--   notification channel with GM display name, not direct GM mention or DM.
--
-- Initial product decisions captured in this draft:
-- - Minimum-count logic uses pending + accepted.
-- - waitlisted_count is returned for visibility but does not count in the first
--   threshold decision.
-- - Shortage reminder excludes full status and only considers tentative /
--   recruiting.
-- - GM confirmed reminder may include full status if the session is future,
--   public, not canceled/deleted, and otherwise eligible.
-- - After a reminder has been logged once per session/type, the first version
--   does not auto-resend even if start time or reminder settings change.
-- - dry_run/preview does not write DB rows. Production claim/finalize writes
--   reminder logs.
--
-- Safety:
-- - Do not paste into Supabase SQL Editor in this gate.
-- - Do not apply from Codex.
-- - Do not put Webhook URLs, tokens, JWTs, project refs, raw user identifiers,
--   emails, Discord IDs, or Discord URLs in this file or result docs.
-- - Browser/static JS must keep using RPC boundaries and must not add direct
--   Supabase write calls.

begin;

-- ============================================================
-- 1. Session reminder setting columns
-- ============================================================
-- Existing table confirmed from existing drafts:
-- - public.sessions
-- - status check values:
--   draft / tentative / recruiting / full / closed / finished / canceled
-- - visibility check values:
--   public / private / hidden
--
-- The first implementation keeps settings on public.sessions because the
-- settings are one small optional pair per reminder type.
-- Existing rows default to disabled.

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
  'Session-level optional shortage reminder flag. Production @everyone delivery requires a separate gate.';

comment on column public.sessions.shortage_reminder_hours_before is
  'Allowed values when enabled: 1, 2, 3. Stored as hours before session start.';

comment on column public.sessions.gm_reminder_enabled is
  'Session-level optional GM confirmed reminder flag. First version routes to a channel with GM display name.';

comment on column public.sessions.gm_reminder_minutes_before is
  'Allowed values when enabled: 30, 60. Stored as minutes before session start.';

-- ============================================================
-- 2. Reminder log table
-- ============================================================
-- Purpose:
-- - Prevent duplicate sends.
-- - Store production claim/finalize state.
-- - Keep dry-run/preview write-free.
--
-- First-version unique policy:
-- - unique(session_id, reminder_type)
-- - This prevents automatic resend after a reminder has been claimed/logged.
-- - If resend is required later, add a manual reset/invalidate gate or replace
--   uniqueness with (session_id, reminder_type, scheduled_for,
--   reminder_offset_minutes) in a reviewed migration.

create table if not exists public.session_reminder_logs (
  id uuid primary key default gen_random_uuid(),
  session_id text not null references public.sessions(id) on delete cascade,
  reminder_type text not null,
  scheduled_for timestamptz not null,
  reminder_offset_minutes integer not null,
  status text not null default 'claimed',
  dry_run boolean not null default false,
  discord_message_id text,
  error_message text,
  created_at timestamptz not null default now(),
  claimed_at timestamptz not null default now(),
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

alter table public.session_reminder_logs enable row level security;

revoke all on table public.session_reminder_logs from anon;
revoke all on table public.session_reminder_logs from authenticated;

comment on table public.session_reminder_logs is
  'Production session reminder claim/finalize log. dry-run previews must not write rows.';

comment on column public.session_reminder_logs.discord_message_id is
  'Optional provider message identifier recorded after successful delivery. Do not expose in browser or docs.';

comment on constraint session_reminder_logs_unique_session_type
  on public.session_reminder_logs is
  'First-version duplicate prevention: one logged reminder per session and reminder type. Manual reset is a later gate.';

-- ============================================================
-- 3. Shared due reminder preview RPC
-- ============================================================
-- preview_due_session_reminders:
-- - DB write: none.
-- - Discord request: none.
-- - Intended caller: later Edge Function dry_run, or admin-only reviewed gate.
-- - Does not return raw user IDs, emails, Discord IDs, provider URLs, or secret
--   values.
--
-- Count policy:
-- - pending_count = distinct session_applications.user_id where status='pending'
-- - accepted_count = distinct session_applications.user_id where status='accepted'
-- - waitlisted_count is returned but excluded from total_for_minimum.
-- - total_for_minimum = pending_count + accepted_count
--
-- Deadline policy:
-- - Shortage reminder initially skips sessions after application_deadline when
--   a deadline exists.
-- - GM reminder does not use application_deadline in this draft.
--
-- Session status policy:
-- - shortage: tentative / recruiting only.
-- - gm_confirmed: tentative / recruiting / full.
-- - all reminders: visibility must be public, start must be future, and start
--   time must exist.

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
  total_for_minimum integer,
  shortage_count integer,
  gm_display_name text,
  reminder_offset_minutes integer,
  target_channel_key text,
  session_public_id text,
  scheduled_for timestamptz
)
language sql
security definer
set search_path = ''
as $$
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
      coalesce(nullif(trim(s.gm_name), ''), 'GM') as gm_display_name,
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
      (b.pending_count + b.accepted_count)::integer as total_for_minimum,
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
      (b.pending_count + b.accepted_count)::integer as total_for_minimum,
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
    c.total_for_minimum,
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
  limit greatest(coalesce(p_limit, 50), 0);
$$;

revoke all on function public.preview_due_session_reminders(timestamptz, integer) from public;
revoke all on function public.preview_due_session_reminders(timestamptz, integer) from anon;
revoke all on function public.preview_due_session_reminders(timestamptz, integer) from authenticated;
grant execute on function public.preview_due_session_reminders(timestamptz, integer) to service_role;

comment on function public.preview_due_session_reminders(timestamptz, integer) is
  'Dry-run preview for due session reminders. Must not write DB rows or send Discord messages.';

-- ============================================================
-- 4. Production claim RPC
-- ============================================================
-- claim_due_session_reminders:
-- - DB write: inserts session_reminder_logs rows with status=claimed.
-- - Discord request: none.
-- - Intended caller: later server-side Edge Function only.
-- - Uses unique(session_id, reminder_type) and ON CONFLICT DO NOTHING to avoid
--   duplicate claims.

create or replace function public.claim_due_session_reminders(
  p_now timestamptz default now(),
  p_limit integer default 10
)
returns table (
  log_id uuid,
  session_id text,
  reminder_type text,
  title text,
  start_at timestamptz,
  min_players integer,
  pending_count integer,
  accepted_count integer,
  waitlisted_count integer,
  total_for_minimum integer,
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
begin
  return query
  with candidates as (
    select *
    from public.preview_due_session_reminders(p_now, p_limit)
  ),
  inserted as (
    insert into public.session_reminder_logs (
      session_id,
      reminder_type,
      scheduled_for,
      reminder_offset_minutes,
      status,
      dry_run,
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
      now(),
      now()
    from candidates as c
    on conflict (session_id, reminder_type) do nothing
    returning
      public.session_reminder_logs.id,
      public.session_reminder_logs.session_id,
      public.session_reminder_logs.reminder_type
  )
  select
    i.id as log_id,
    c.session_id,
    c.reminder_type,
    c.title,
    c.start_at,
    c.min_players,
    c.pending_count,
    c.accepted_count,
    c.waitlisted_count,
    c.total_for_minimum,
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
  'Production claim for due session reminders. Server-only boundary; do not call from browser clients.';

-- ============================================================
-- 5. Production finalize RPC
-- ============================================================
-- finalize_session_reminder:
-- - DB write: updates an existing claimed log only.
-- - Discord request: none.
-- - p_discord_message_id is stored only after successful delivery and must not
--   be exposed in docs or browser list APIs.
-- - p_error_message should be a short generalized code/string, not a raw
--   external response body.

create or replace function public.finalize_session_reminder(
  p_log_id uuid,
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
  if p_log_id is null then
    raise exception 'log_id_required' using errcode = '22023';
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
    discord_message_id = case when v_status = 'sent' then v_message_id else null end,
    error_message = case when v_status in ('failed', 'skipped') then v_error_message else null end,
    sent_at = case when v_status = 'sent' then now() else null end,
    finalized_at = now()
  where l.id = p_log_id
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

revoke all on function public.finalize_session_reminder(uuid, text, text, text) from public;
revoke all on function public.finalize_session_reminder(uuid, text, text, text) from anon;
revoke all on function public.finalize_session_reminder(uuid, text, text, text) from authenticated;
grant execute on function public.finalize_session_reminder(uuid, text, text, text) to service_role;

comment on function public.finalize_session_reminder(uuid, text, text, text) is
  'Production finalize for a claimed session reminder. Server-only boundary; stores only generalized result state.';

-- ============================================================
-- 6. Create/update RPC integration notes
-- ============================================================
-- Later Gate 1 review must decide whether to:
-- A. extend public.create_session_post and public.update_session_post signatures
--    with the four setting parameters, or
-- B. add a small owner/admin scoped RPC such as
--    public.update_session_reminder_settings(...)
--
-- Initial recommendation:
-- - Add a dedicated settings RPC first to avoid PostgREST overload ambiguity.
-- - Later, if UI ergonomics require single-save behavior, replace
--   create_session_post/update_session_post in a focused gate.
--
-- Candidate settings RPC signature:
-- public.update_session_reminder_settings(
--   p_session_id text,
--   p_shortage_reminder_enabled boolean,
--   p_shortage_reminder_hours_before integer default null,
--   p_gm_reminder_enabled boolean,
--   p_gm_reminder_minutes_before integer default null
-- )
--
-- Candidate permission:
-- - auth.uid() required.
-- - public.is_session_gm(p_session_id) or public.is_admin().
-- - Do not grant to anon.
-- - Do not expose or mutate Discord provider identifiers.
--
-- Candidate behavior:
-- - Validate the same timing constraints as table checks.
-- - Updating settings after a reminder was already logged does not auto-delete
--   logs and does not allow automatic resend in the first version.
-- - Manual reset/log invalidation requires a later explicit gate.

-- ============================================================
-- 7. Post-apply SELECT-only checks for a future gate
-- ============================================================
-- These are notes only for the eventual Gate 2. They are not executed here.
--
-- Check:
-- - public.sessions has the four reminder setting columns.
-- - public.session_reminder_logs exists outside supabase/migrations review.
-- - CHECK constraints exist for reminder settings, reminder type, status,
--   offset, and dry_run=false.
-- - unique(session_id, reminder_type) exists.
-- - RLS is enabled for public.session_reminder_logs.
-- - anon/authenticated do not have direct table privileges.
-- - preview_due_session_reminders writes no rows.
-- - claim_due_session_reminders creates claimed rows only in production flow.
-- - finalize_session_reminder updates only claimed rows.
-- - service_role-only grants are reviewed before any Edge Function use.

-- ============================================================
-- 8. Rollback draft notes for a later reviewed gate
-- ============================================================
-- Do not use this section without a separate rollback approval.
--
-- Candidate rollback order:
-- 1. Disable/stop the scheduled dispatcher and any cron first.
-- 2. Revoke execute on reminder RPCs.
-- 3. Drop reminder RPCs.
-- 4. Drop public.session_reminder_logs if logs are not needed for audit.
-- 5. Drop sessions reminder constraints.
-- 6. Drop sessions reminder columns.
-- 7. Re-run public-only and SELECT-only checks.

rollback;
