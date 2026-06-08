-- 050_admin_discord_announcements_schema_apply_draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
-- DESIGN DRAFT ONLY
--
-- Purpose:
-- - Prepare the schema draft for admin-only Discord cap update announcements.
-- - This is not a general scheduling feature.
-- - This is not a GM/PL-created notification feature.
-- - Store only target_channel_key; never store Webhook URL values in DB.
--
-- Scope:
-- - public.admin_discord_announcements table draft.
-- - status CHECK.
-- - mention_mode CHECK.
-- - target_channel_key CHECK.
-- - admin-only RLS/RPC policy notes for later reviewed gates.
--
-- Out of scope:
-- - No SQL Editor execution by Codex.
-- - No actual DB/RPC/RLS change in this batch.
-- - No Edge Function deploy.
-- - No Discord post.
-- - No secret or Webhook value.
-- - No JWT, Supabase URL, Discord ID, or token values.
-- - No direct browser insert/update/delete/upsert path.
--
-- Apply policy:
-- - Review this file before apply.
-- - Run only in a separate explicit SQL apply gate.
-- - Run once only.
-- - If any error appears, stop and do not rerun.

begin;

create table if not exists public.admin_discord_announcements (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null default auth.uid(),
  announcement_type text not null default 'cap_update',
  announcement_title text not null,
  announcement_body text not null,
  target_channel_key text not null default 'cap_announcement',
  scheduled_at timestamptz not null,
  timezone text not null default 'Asia/Tokyo',
  mention_mode text not null default 'none',
  status text not null default 'draft',
  cap_level text,
  apply_start_date date,
  apply_end_date date,
  note text,
  attempt_count integer not null default 0,
  max_attempts integer not null default 3,
  next_attempt_at timestamptz,
  locked_at timestamptz,
  lock_token uuid,
  posted_at timestamptz,
  delivery_error_code text,
  delivery_error_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint admin_discord_announcements_type_check
    check (announcement_type = 'cap_update'),
  constraint admin_discord_announcements_title_check
    check (char_length(trim(announcement_title)) between 1 and 120),
  constraint admin_discord_announcements_body_check
    check (char_length(trim(announcement_body)) between 1 and 1800),
  constraint admin_discord_announcements_target_channel_key_check
    check (target_channel_key in ('cap_announcement')),
  constraint admin_discord_announcements_timezone_check
    check (char_length(trim(timezone)) between 1 and 80),
  constraint admin_discord_announcements_mention_mode_check
    check (mention_mode in ('none', 'everyone')),
  constraint admin_discord_announcements_status_check
    check (status in ('draft', 'scheduled', 'processing', 'posted', 'failed', 'canceled')),
  constraint admin_discord_announcements_cap_level_check
    check (cap_level is null or char_length(trim(cap_level)) between 1 and 40),
  constraint admin_discord_announcements_note_check
    check (note is null or char_length(trim(note)) <= 500),
  constraint admin_discord_announcements_apply_range_check
    check (apply_start_date is null or apply_end_date is null or apply_end_date >= apply_start_date),
  constraint admin_discord_announcements_attempt_count_check
    check (attempt_count >= 0 and max_attempts between 1 and 10),
  constraint admin_discord_announcements_processing_lock_check
    check (
      status <> 'processing'
      or (locked_at is not null and lock_token is not null)
    ),
  constraint admin_discord_announcements_posted_at_check
    check (status <> 'posted' or posted_at is not null),
  constraint admin_discord_announcements_error_check
    check (
      delivery_error_code is null
      or (status in ('scheduled', 'failed') and delivery_error_at is not null)
    )
);

create index if not exists admin_discord_announcements_created_idx
  on public.admin_discord_announcements (created_at desc);

create index if not exists admin_discord_announcements_due_idx
  on public.admin_discord_announcements (status, scheduled_at, next_attempt_at)
  where status = 'scheduled';

create index if not exists admin_discord_announcements_processing_lock_idx
  on public.admin_discord_announcements (locked_at)
  where status = 'processing';

alter table public.admin_discord_announcements enable row level security;

drop policy if exists admin_discord_announcements_select_admin on public.admin_discord_announcements;
create policy admin_discord_announcements_select_admin
  on public.admin_discord_announcements
  for select
  to authenticated
  using (coalesce(public.is_admin(), false));

revoke all on table public.admin_discord_announcements from anon;
revoke all on table public.admin_discord_announcements from authenticated;
grant select on table public.admin_discord_announcements to authenticated;

comment on table public.admin_discord_announcements is
  'Admin-only Discord cap update announcements. DO NOT STORE WEBHOOK CREDENTIALS.';

comment on column public.admin_discord_announcements.target_channel_key is
  'Logical routing key only. cap_announcement maps server-side to the appropriate Edge Function secret/env.';

comment on column public.admin_discord_announcements.mention_mode is
  'none => allowed_mentions.parse empty array. everyone => explicit everyone-only parse.';

comment on column public.admin_discord_announcements.status is
  'draft/scheduled/processing/posted/failed/canceled. Only scheduled rows are claim targets.';

comment on column public.admin_discord_announcements.delivery_error_code is
  'Generalized delivery error code only. Do not store raw external responses or secret values.';

-- RPC policy notes for a later reviewed apply draft:
--
-- create_admin_discord_announcement(
--   p_announcement_title text,
--   p_announcement_body text,
--   p_target_channel_key text,
--   p_scheduled_at text,
--   p_timezone text default 'Asia/Tokyo',
--   p_mention_mode text default 'none',
--   p_status text default 'draft',
--   p_cap_level text default null,
--   p_apply_start_date text default null,
--   p_apply_end_date text default null,
--   p_note text default null
-- )
-- - authenticated admin only.
-- - must call public.is_admin() or a reviewed equivalent helper.
-- - validates p_target_channel_key = 'cap_announcement'.
-- - validates p_mention_mode in ('none', 'everyone').
-- - allows only p_status in ('draft', 'scheduled') for create.
-- - inserts created_by = auth.uid().
-- - no Webhook credential lookup.
--
-- update_admin_discord_announcement(...)
-- - authenticated admin only.
-- - only draft/scheduled/failed can be edited in the first reviewed version.
-- - processing/posted/canceled require separate explicit behavior.
--
-- cancel_admin_discord_announcement(p_announcement_id uuid)
-- - authenticated admin only.
-- - draft/scheduled/failed can become canceled.
-- - processing cancellation must be a separate reviewed gate.
--
-- list_admin_discord_announcements(...)
-- - authenticated admin only.
-- - returns generalized fields including has_delivery_error boolean and delivery_error_code.
-- - never returns Webhook URL, token, raw Discord identifiers, or raw external response bodies.
--
-- claim_due_admin_discord_announcements(...)
-- - Edge Function/server-only boundary.
-- - atomically updates due scheduled rows to processing with lock_token.
-- - filters announcement_type = 'cap_update' and target_channel_key = 'cap_announcement'.
-- - returns only rows claimed by that lock.
--
-- finalize_admin_discord_announcement(...)
-- - Edge Function/server-only boundary.
-- - updates by id + lock_token only.
-- - success sets posted/posted_at and clears generalized delivery error fields.
-- - failure stores a generalized delivery_error_code and delivery_error_at.
-- - retryable failure returns the row to scheduled with next_attempt_at.
-- - max-attempt failure sets failed.
--
-- Edge Function environment mapping note:
-- - target_channel_key = 'cap_announcement'
-- - server-side secret/env name candidate: DISCORD_WEBHOOK_CAP_ANNOUNCEMENT
-- - Do not put the actual value in SQL, docs, browser JS, DB rows, logs, or chat.
--
-- Mention delivery note:
-- - mention_mode = 'none' must send allowed_mentions.parse = [].
-- - mention_mode = 'everyone' may prepend @everyone and send allowed_mentions.parse = ['everyone'].
-- - Do not allow users/roles parse in this MVP.
--
-- Do not add direct INSERT/UPDATE/DELETE policies unless a later review explicitly changes the architecture.

commit;
