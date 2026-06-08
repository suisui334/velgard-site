-- 050_discord_reminders_schema_apply_draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
--
-- Purpose:
-- - Prepare the schema draft for Discord reminder reservations.
-- - Keep Webhook credentials and real channel routing out of browser JS, docs, and DB.
-- - Store only a channel_key that the future Edge Function can map server-side.
--
-- Scope:
-- - public.discord_reminders table draft.
-- - status CHECK.
-- - mention_mode CHECK.
-- - RLS baseline for owner SELECT.
-- - RPC/RLS policy notes for the later apply/review gates.
--
-- Out of scope:
-- - No SQL Editor execution by Codex.
-- - No actual DB/RPC/RLS change in this batch.
-- - No Edge Function deploy.
-- - No Discord post.
-- - No secret or Webhook value.
-- - No direct browser insert/update/delete/upsert path.
--
-- Apply policy:
-- - Review this file before apply.
-- - Run only in a separate explicit SQL apply gate.
-- - Run once only.
-- - If any error appears, stop and do not rerun.

begin;

create table if not exists public.discord_reminders (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null default auth.uid(),
  channel_key text not null,
  scheduled_at timestamptz not null,
  timezone text not null default 'Asia/Tokyo',
  message_body text not null,
  mention_mode text not null default 'none',
  status text not null default 'scheduled',
  attempt_count integer not null default 0,
  max_attempts integer not null default 3,
  next_attempt_at timestamptz,
  locked_at timestamptz,
  lock_token uuid,
  posted_at timestamptz,
  delivery_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint discord_reminders_channel_key_check
    check (channel_key ~ '^[a-z0-9][a-z0-9_-]{1,62}[a-z0-9]$'),
  constraint discord_reminders_timezone_check
    check (char_length(trim(timezone)) between 1 and 80),
  constraint discord_reminders_message_body_check
    check (char_length(trim(message_body)) between 1 and 1800),
  constraint discord_reminders_mention_mode_check
    check (mention_mode in ('none', 'everyone')),
  constraint discord_reminders_status_check
    check (status in ('scheduled', 'processing', 'posted', 'failed', 'canceled')),
  constraint discord_reminders_attempt_count_check
    check (attempt_count >= 0 and max_attempts between 1 and 10),
  constraint discord_reminders_processing_lock_check
    check (
      status <> 'processing'
      or (locked_at is not null and lock_token is not null)
    ),
  constraint discord_reminders_posted_at_check
    check (status <> 'posted' or posted_at is not null)
);

create index if not exists discord_reminders_owner_created_idx
  on public.discord_reminders (owner_user_id, created_at desc);

create index if not exists discord_reminders_due_idx
  on public.discord_reminders (status, scheduled_at, next_attempt_at)
  where status = 'scheduled';

create index if not exists discord_reminders_processing_lock_idx
  on public.discord_reminders (locked_at)
  where status = 'processing';

alter table public.discord_reminders enable row level security;

drop policy if exists discord_reminders_select_own on public.discord_reminders;
create policy discord_reminders_select_own
  on public.discord_reminders
  for select
  to authenticated
  using (owner_user_id = auth.uid());

revoke all on table public.discord_reminders from anon;
grant select on table public.discord_reminders to authenticated;

comment on table public.discord_reminders is
  'DO NOT STORE WEBHOOK CREDENTIALS. Reminder reservations for future Discord Webhook delivery.';

comment on column public.discord_reminders.channel_key is
  'Logical routing key only. Real channel routing must stay server-side.';

comment on column public.discord_reminders.mention_mode is
  'none => allowed_mentions.parse empty array. everyone => explicit everyone-only parse.';

comment on column public.discord_reminders.status is
  'scheduled -> processing -> posted, or scheduled/processing -> failed/canceled by reviewed RPC.';

-- RPC policy notes for a later reviewed apply draft:
--
-- create_discord_reminder(
--   p_channel_key text,
--   p_scheduled_at text,
--   p_timezone text,
--   p_message_body text,
--   p_mention_mode text default 'none'
-- )
-- - authenticated only.
-- - inserts owner_user_id = auth.uid().
-- - validates mention_mode and channel_key.
-- - no Webhook credential lookup.
--
-- update_discord_reminder(...)
-- - authenticated owner only.
-- - only status in ('scheduled', 'failed') can be edited.
-- - cannot edit once processing/posted/canceled except through explicit admin RPC.
--
-- cancel_discord_reminder(p_reminder_id uuid)
-- - authenticated owner only.
-- - scheduled/failed can become canceled.
-- - processing cancellation must be a separate reviewed gate.
--
-- list_my_discord_reminders(...)
-- - authenticated owner read.
-- - returns generalized fields and never returns secret routing values.
--
-- claim_due_discord_reminders(...)
-- - Edge Function/server-only boundary.
-- - atomically updates scheduled due rows to processing with lock_token.
-- - returns only rows claimed by that lock.
--
-- finalize_discord_reminder(...)
-- - Edge Function/server-only boundary.
-- - updates by id + lock_token only.
-- - success sets posted/posted_at.
-- - failure stores a generalized delivery_error_code and schedules retry or failed.
--
-- Do not add direct INSERT/UPDATE/DELETE policies unless a later review explicitly changes the architecture.

commit;
