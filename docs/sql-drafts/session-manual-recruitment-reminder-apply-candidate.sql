-- APPLY CANDIDATE ONLY.
-- Do not run automatically.
-- Paste into Supabase SQL Editor only after explicit user approval.
-- If any error occurs, stop and do not re-run blindly.
--
-- Gate MR-02.5 review notes:
-- - This candidate is based on
--   docs/sql-drafts/session-manual-recruitment-reminder-draft.sql.
-- - It keeps manual recruitment reminder logs separate from automatic
--   public.session_reminder_logs.
-- - It uses a manual-only log table, authenticated GM/admin preview + claim
--   RPCs, and service-role-only finalize RPC.
-- - It does not send Discord, configure secrets, deploy Edge Functions, or
--   call Webhooks.
-- - Run the apply section and SELECT-only checks separately.

begin;

-- ============================================================
-- 1. Manual recruitment reminder log table
-- ============================================================
-- First-version policy:
-- - Direct table access is closed to browser roles.
-- - RLS is enabled.
-- - A claimed row prevents double-click / concurrent sends for the same
--   session until finalized.
-- - Only a sent row starts cooldown.
-- - Cooldown is currently 6 hours after successful send.
-- - Failed/skipped rows do not start cooldown.
-- - Discord message ids may be stored, but must not be exposed in docs or UI.

create table if not exists public.session_manual_recruitment_reminder_logs (
  id uuid primary key default gen_random_uuid(),
  session_id text not null references public.sessions(id) on delete cascade,
  actor_user_id uuid references public.profiles(id) on delete set null,
  status text not null default 'claimed',
  lock_token uuid,
  discord_message_id text,
  error_message text,
  created_at timestamptz not null default now(),
  claimed_at timestamptz,
  sent_at timestamptz,
  failed_at timestamptz,
  skipped_at timestamptz,
  finalized_at timestamptz,
  cooldown_until timestamptz,
  constraint session_manual_recruitment_reminder_logs_status_check
    check (status in ('claimed', 'sent', 'failed', 'skipped')),
  constraint session_manual_recruitment_reminder_logs_lock_check
    check (status <> 'claimed' or (claimed_at is not null and lock_token is not null)),
  constraint session_manual_recruitment_reminder_logs_message_id_check
    check (
      discord_message_id is null
      or (
        char_length(trim(discord_message_id)) between 1 and 120
        and discord_message_id !~ '[[:space:]]'
      )
    ),
  constraint session_manual_recruitment_reminder_logs_error_message_check
    check (error_message is null or char_length(error_message) <= 500),
  constraint session_manual_recruitment_reminder_logs_sent_check
    check (status <> 'sent' or (sent_at is not null and cooldown_until is not null)),
  constraint session_manual_recruitment_reminder_logs_failed_check
    check (status <> 'failed' or failed_at is not null),
  constraint session_manual_recruitment_reminder_logs_skipped_check
    check (status <> 'skipped' or skipped_at is not null),
  constraint session_manual_recruitment_reminder_logs_finalized_check
    check (status = 'claimed' or finalized_at is not null)
);

create index if not exists session_manual_recruitment_reminder_logs_session_idx
  on public.session_manual_recruitment_reminder_logs (session_id, created_at desc);

create index if not exists session_manual_recruitment_reminder_logs_actor_idx
  on public.session_manual_recruitment_reminder_logs (actor_user_id, created_at desc);

create index if not exists session_manual_recruitment_reminder_logs_status_idx
  on public.session_manual_recruitment_reminder_logs (status, created_at desc);

create index if not exists session_manual_recruitment_reminder_logs_cooldown_idx
  on public.session_manual_recruitment_reminder_logs (session_id, cooldown_until)
  where status = 'sent';

create unique index if not exists session_manual_recruitment_reminder_logs_claimed_unique
  on public.session_manual_recruitment_reminder_logs (session_id)
  where status = 'claimed';

alter table public.session_manual_recruitment_reminder_logs enable row level security;

revoke all on table public.session_manual_recruitment_reminder_logs from public;
revoke all on table public.session_manual_recruitment_reminder_logs from anon;
revoke all on table public.session_manual_recruitment_reminder_logs from authenticated;

comment on table public.session_manual_recruitment_reminder_logs is
  'Manual GM/admin recruitment reminder send log. Separate from automatic session_reminder_logs.';

comment on column public.session_manual_recruitment_reminder_logs.actor_user_id is
  'Authenticated actor who requested the manual recruitment reminder. May become null if the profile is removed.';

comment on column public.session_manual_recruitment_reminder_logs.lock_token is
  'Claim token for finalize. Do not expose to browser clients.';

comment on column public.session_manual_recruitment_reminder_logs.discord_message_id is
  'Optional provider message id recorded after successful Discord send. Do not expose in docs or UI.';

comment on column public.session_manual_recruitment_reminder_logs.cooldown_until is
  'Successful send cooldown boundary. First-version policy is 6 hours after sent_at.';

comment on index public.session_manual_recruitment_reminder_logs_claimed_unique is
  'Prevents concurrent claimed manual recruitment reminders for the same session.';

-- ============================================================
-- 2. Preview / eligibility RPC
-- ============================================================
-- This RPC is recommended for UI disabled-state and dry-run confirmation.
--
-- It performs no writes and does not return Webhook URL, Discord IDs, token,
-- raw user id, or message id.

create or replace function public.preview_manual_recruitment_reminder(
  p_session_id text
)
returns table (
  session_id text,
  session_public_id text,
  can_send boolean,
  blocked_reason text,
  title text,
  start_at timestamptz,
  player_min integer,
  accepted_count integer,
  pending_count integer,
  waitlisted_count integer,
  gm_display_name text,
  cooldown_until timestamptz,
  cooldown_seconds_remaining integer
)
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_session_id text := nullif(btrim(coalesce(p_session_id, '')), '');
  v_session record;
  v_start_at timestamptz;
  v_accepted_count integer := 0;
  v_pending_count integer := 0;
  v_waitlisted_count integer := 0;
  v_cooldown_until timestamptz;
  v_blocked_reason text;
begin
  if v_actor_id is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  if v_session_id is null then
    raise exception 'session_id_required' using errcode = '22023';
  end if;

  select
    s.id,
    s.title,
    s.date,
    s.start_time,
    s.application_deadline,
    s.player_min,
    s.visibility,
    s.status,
    s.gm_user_id,
    coalesce(nullif(btrim(s.gm_name), ''), nullif(btrim(p.display_name), ''), 'GM')::text as gm_display_name
  into v_session
  from public.sessions as s
  left join public.profiles as p
    on p.id = s.gm_user_id
  where s.id = v_session_id;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not (
    coalesce(public.is_admin(), false)
    or coalesce(public.is_session_gm(v_session_id), false)
  ) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if v_session.start_time is not null then
    v_start_at := (v_session.date + v_session.start_time)::timestamp at time zone 'Asia/Tokyo';
  end if;

  select
    count(*) filter (where sa.status = 'accepted')::integer,
    count(*) filter (where sa.status = 'pending')::integer,
    count(*) filter (where sa.status = 'waitlisted')::integer
  into v_accepted_count, v_pending_count, v_waitlisted_count
  from public.session_applications as sa
  where sa.session_id = v_session_id;

  select max(l.cooldown_until)
  into v_cooldown_until
  from public.session_manual_recruitment_reminder_logs as l
  where l.session_id = v_session_id
    and l.status = 'sent'
    and l.cooldown_until > now();

  if v_session.visibility <> 'public' then
    v_blocked_reason := 'not_public';
  elsif v_session.status not in ('recruiting', 'tentative') then
    v_blocked_reason := 'status_not_recruiting';
  elsif v_start_at is null then
    v_blocked_reason := 'start_time_missing';
  elsif v_start_at <= now() then
    v_blocked_reason := 'already_started';
  elsif v_session.application_deadline is null then
    v_blocked_reason := 'application_deadline_missing';
  elsif v_session.application_deadline <= now() then
    v_blocked_reason := 'application_deadline_passed';
  elsif v_cooldown_until is not null then
    v_blocked_reason := 'cooldown_active';
  elsif exists (
    select 1
    from public.session_manual_recruitment_reminder_logs as l
    where l.session_id = v_session_id
      and l.status = 'claimed'
  ) then
    v_blocked_reason := 'send_in_progress';
  end if;

  return query
  select
    v_session.id::text as session_id,
    v_session.id::text as session_public_id,
    (v_blocked_reason is null) as can_send,
    v_blocked_reason as blocked_reason,
    v_session.title::text as title,
    v_start_at as start_at,
    v_session.player_min::integer as player_min,
    v_accepted_count as accepted_count,
    v_pending_count as pending_count,
    v_waitlisted_count as waitlisted_count,
    v_session.gm_display_name::text as gm_display_name,
    v_cooldown_until as cooldown_until,
    case
      when v_cooldown_until is null then 0
      else greatest(0, ceiling(extract(epoch from (v_cooldown_until - now())))::integer)
    end as cooldown_seconds_remaining;
end;
$$;

revoke all on function public.preview_manual_recruitment_reminder(text) from public;
revoke all on function public.preview_manual_recruitment_reminder(text) from anon;
revoke all on function public.preview_manual_recruitment_reminder(text) from authenticated;
grant execute on function public.preview_manual_recruitment_reminder(text) to authenticated;

comment on function public.preview_manual_recruitment_reminder(text) is
  'Authenticated GM/admin preview for manual recruitment reminder eligibility. Performs no writes and returns safe display/context fields only.';

-- ============================================================
-- 3. Claim RPC
-- ============================================================
-- Edge Function expectation:
-- - Call this using the caller authenticated JWT context, not service_role
--   alone, so auth.uid() identifies the GM/admin actor.
-- - The RPC writes one claimed log row only after permission, eligibility, and
--   cooldown checks pass.
-- - It returns safe fields needed for Discord message generation.
-- - It does not return Webhook URL, Discord IDs, token, email, raw gm_user_id,
--   or Discord message id.

create or replace function public.claim_manual_recruitment_reminder(
  p_session_id text
)
returns table (
  log_id uuid,
  lock_token uuid,
  session_id text,
  session_public_id text,
  title text,
  start_at timestamptz,
  player_min integer,
  accepted_count integer,
  pending_count integer,
  waitlisted_count integer,
  gm_display_name text,
  cooldown_until timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_session_id text := nullif(btrim(coalesce(p_session_id, '')), '');
  v_session record;
  v_start_at timestamptz;
  v_accepted_count integer := 0;
  v_pending_count integer := 0;
  v_waitlisted_count integer := 0;
  v_existing_cooldown timestamptz;
  v_log_id uuid;
  v_lock_token uuid := gen_random_uuid();
begin
  if v_actor_id is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  if v_session_id is null then
    raise exception 'session_id_required' using errcode = '22023';
  end if;

  if not exists (select 1 from public.profiles as p where p.id = v_actor_id) then
    raise exception 'profile_required' using errcode = '42501';
  end if;

  select
    s.id,
    s.title,
    s.date,
    s.start_time,
    s.application_deadline,
    s.player_min,
    s.visibility,
    s.status,
    s.gm_user_id,
    coalesce(nullif(btrim(s.gm_name), ''), nullif(btrim(p.display_name), ''), 'GM')::text as gm_display_name
  into v_session
  from public.sessions as s
  left join public.profiles as p
    on p.id = s.gm_user_id
  where s.id = v_session_id
  for update of s;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not (
    coalesce(public.is_admin(), false)
    or coalesce(public.is_session_gm(v_session_id), false)
  ) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if v_session.visibility <> 'public' then
    raise exception 'manual_recruitment_not_public' using errcode = '22023';
  end if;

  if v_session.status not in ('recruiting', 'tentative') then
    raise exception 'manual_recruitment_status_not_allowed' using errcode = '22023';
  end if;

  if v_session.start_time is null then
    raise exception 'manual_recruitment_start_time_missing' using errcode = '22023';
  end if;

  v_start_at := (v_session.date + v_session.start_time)::timestamp at time zone 'Asia/Tokyo';
  if v_start_at <= now() then
    raise exception 'manual_recruitment_already_started' using errcode = '22023';
  end if;

  if v_session.application_deadline is null then
    raise exception 'manual_recruitment_deadline_missing' using errcode = '22023';
  end if;

  if v_session.application_deadline <= now() then
    raise exception 'manual_recruitment_deadline_passed' using errcode = '22023';
  end if;

  select max(l.cooldown_until)
  into v_existing_cooldown
  from public.session_manual_recruitment_reminder_logs as l
  where l.session_id = v_session_id
    and l.status = 'sent'
    and l.cooldown_until > now();

  if v_existing_cooldown is not null then
    raise exception 'manual_recruitment_cooldown_active' using errcode = '23505';
  end if;

  if exists (
    select 1
    from public.session_manual_recruitment_reminder_logs as l
    where l.session_id = v_session_id
      and l.status = 'claimed'
  ) then
    raise exception 'manual_recruitment_send_in_progress' using errcode = '23505';
  end if;

  select
    count(*) filter (where sa.status = 'accepted')::integer,
    count(*) filter (where sa.status = 'pending')::integer,
    count(*) filter (where sa.status = 'waitlisted')::integer
  into v_accepted_count, v_pending_count, v_waitlisted_count
  from public.session_applications as sa
  where sa.session_id = v_session_id;

  insert into public.session_manual_recruitment_reminder_logs (
    session_id,
    actor_user_id,
    status,
    lock_token,
    claimed_at
  )
  values (
    v_session_id,
    v_actor_id,
    'claimed',
    v_lock_token,
    now()
  )
  on conflict do nothing
  returning id into v_log_id;

  if v_log_id is null then
    raise exception 'manual_recruitment_send_in_progress' using errcode = '23505';
  end if;

  return query
  select
    v_log_id as log_id,
    v_lock_token as lock_token,
    v_session.id::text as session_id,
    v_session.id::text as session_public_id,
    v_session.title::text as title,
    v_start_at as start_at,
    v_session.player_min::integer as player_min,
    v_accepted_count as accepted_count,
    v_pending_count as pending_count,
    v_waitlisted_count as waitlisted_count,
    v_session.gm_display_name::text as gm_display_name,
    null::timestamptz as cooldown_until;
end;
$$;

revoke all on function public.claim_manual_recruitment_reminder(text) from public;
revoke all on function public.claim_manual_recruitment_reminder(text) from anon;
revoke all on function public.claim_manual_recruitment_reminder(text) from authenticated;
grant execute on function public.claim_manual_recruitment_reminder(text) to authenticated;

comment on function public.claim_manual_recruitment_reminder(text) is
  'Authenticated GM/admin claim for one manual recruitment reminder. Enforces session eligibility, in-progress guard, and successful-send cooldown.';

-- ============================================================
-- 4. Finalize RPC
-- ============================================================
-- service_role only:
-- - Updates an existing claimed manual recruitment reminder log.
-- - Does not send Discord.
-- - Success sets sent_at and cooldown_until = now() + 6 hours.
-- - Failed/skipped finalization clears lock_token without starting cooldown.

create or replace function public.finalize_manual_recruitment_reminder(
  p_log_id uuid,
  p_lock_token uuid,
  p_status text,
  p_discord_message_id text default null,
  p_error_message text default null
)
returns table (
  log_id uuid,
  session_id text,
  status text,
  sent_at timestamptz,
  failed_at timestamptz,
  cooldown_until timestamptz,
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
    raise exception 'invalid_manual_recruitment_finalize_status' using errcode = '22023';
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
  update public.session_manual_recruitment_reminder_logs as l
  set
    status = v_status,
    lock_token = null,
    discord_message_id = case when v_status = 'sent' then v_message_id else null end,
    error_message = case when v_status in ('failed', 'skipped') then v_error_message else null end,
    sent_at = case when v_status = 'sent' then now() else null end,
    failed_at = case when v_status = 'failed' then now() else null end,
    skipped_at = case when v_status = 'skipped' then now() else null end,
    cooldown_until = case when v_status = 'sent' then now() + interval '6 hours' else null end,
    finalized_at = now()
  where l.id = p_log_id
    and l.lock_token = p_lock_token
    and l.status = 'claimed'
  returning
    l.id as log_id,
    l.session_id,
    l.status,
    l.sent_at,
    l.failed_at,
    l.cooldown_until,
    l.finalized_at;

  if not found then
    raise exception 'manual_recruitment_log_not_claimed' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.finalize_manual_recruitment_reminder(uuid, uuid, text, text, text) from public;
revoke all on function public.finalize_manual_recruitment_reminder(uuid, uuid, text, text, text) from anon;
revoke all on function public.finalize_manual_recruitment_reminder(uuid, uuid, text, text, text) from authenticated;
grant execute on function public.finalize_manual_recruitment_reminder(uuid, uuid, text, text, text) to service_role;

comment on function public.finalize_manual_recruitment_reminder(uuid, uuid, text, text, text) is
  'Service-role finalize for manual recruitment reminder claims. Success starts 6-hour cooldown.';

commit;

-- ============================================================
-- 5. SELECT-only post-apply checks
-- ============================================================
-- Run only after a reviewed apply gate succeeds.
-- Do not run preview/claim/finalize RPCs in this checklist.
-- Record counts/status only. Do not record concrete session ids, user ids,
-- Discord message ids, Webhook URL, token, or full message text.

select
  'manual_recruitment_log_table' as check_name,
  to_regclass('public.session_manual_recruitment_reminder_logs') is not null as exists;

select
  'manual_recruitment_log_rls' as check_name,
  relrowsecurity as rls_enabled,
  relforcerowsecurity as rls_forced
from pg_class
where oid = 'public.session_manual_recruitment_reminder_logs'::regclass;

select
  'manual_recruitment_log_direct_privileges' as check_name,
  has_table_privilege('public', 'public.session_manual_recruitment_reminder_logs', 'select') as public_select,
  has_table_privilege('anon', 'public.session_manual_recruitment_reminder_logs', 'select') as anon_select,
  has_table_privilege('authenticated', 'public.session_manual_recruitment_reminder_logs', 'select') as authenticated_select,
  has_table_privilege('authenticated', 'public.session_manual_recruitment_reminder_logs', 'insert') as authenticated_insert,
  has_table_privilege('authenticated', 'public.session_manual_recruitment_reminder_logs', 'update') as authenticated_update,
  has_table_privilege('authenticated', 'public.session_manual_recruitment_reminder_logs', 'delete') as authenticated_delete;

select
  'manual_recruitment_log_constraints' as check_name,
  count(*) filter (where conname in (
    'session_manual_recruitment_reminder_logs_status_check',
    'session_manual_recruitment_reminder_logs_lock_check',
    'session_manual_recruitment_reminder_logs_message_id_check',
    'session_manual_recruitment_reminder_logs_error_message_check',
    'session_manual_recruitment_reminder_logs_sent_check',
    'session_manual_recruitment_reminder_logs_failed_check',
    'session_manual_recruitment_reminder_logs_skipped_check',
    'session_manual_recruitment_reminder_logs_finalized_check'
  )) as expected_constraint_count
from pg_constraint
where conrelid = 'public.session_manual_recruitment_reminder_logs'::regclass;

select
  'manual_recruitment_log_indexes' as check_name,
  count(*) filter (where indexname = 'session_manual_recruitment_reminder_logs_claimed_unique') as claimed_unique_index_count,
  count(*) filter (where indexname = 'session_manual_recruitment_reminder_logs_cooldown_idx') as cooldown_index_count
from pg_indexes
where schemaname = 'public'
  and tablename = 'session_manual_recruitment_reminder_logs';

select
  'manual_recruitment_rpc_exists' as check_name,
  to_regprocedure('public.preview_manual_recruitment_reminder(text)') is not null as preview_exists,
  to_regprocedure('public.claim_manual_recruitment_reminder(text)') is not null as claim_exists,
  to_regprocedure('public.finalize_manual_recruitment_reminder(uuid, uuid, text, text, text)') is not null as finalize_exists;

select
  'manual_recruitment_rpc_security' as check_name,
  p.proname,
  p.prosecdef as security_definer,
  coalesce(array_to_string(p.proconfig, ','), '') as proconfig
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'preview_manual_recruitment_reminder',
    'claim_manual_recruitment_reminder',
    'finalize_manual_recruitment_reminder'
  )
order by p.proname;

select
  'manual_recruitment_rpc_privileges' as check_name,
  has_function_privilege('authenticated', 'public.preview_manual_recruitment_reminder(text)', 'execute') as authenticated_can_preview,
  has_function_privilege('authenticated', 'public.claim_manual_recruitment_reminder(text)', 'execute') as authenticated_can_claim,
  has_function_privilege('authenticated', 'public.finalize_manual_recruitment_reminder(uuid, uuid, text, text, text)', 'execute') as authenticated_can_finalize,
  has_function_privilege('public', 'public.preview_manual_recruitment_reminder(text)', 'execute') as public_can_preview,
  has_function_privilege('public', 'public.claim_manual_recruitment_reminder(text)', 'execute') as public_can_claim,
  has_function_privilege('public', 'public.finalize_manual_recruitment_reminder(uuid, uuid, text, text, text)', 'execute') as public_can_finalize,
  has_function_privilege('anon', 'public.preview_manual_recruitment_reminder(text)', 'execute') as anon_can_preview,
  has_function_privilege('anon', 'public.claim_manual_recruitment_reminder(text)', 'execute') as anon_can_claim,
  has_function_privilege('anon', 'public.finalize_manual_recruitment_reminder(uuid, uuid, text, text, text)', 'execute') as anon_can_finalize,
  has_function_privilege('service_role', 'public.finalize_manual_recruitment_reminder(uuid, uuid, text, text, text)', 'execute') as service_role_can_finalize;

select
  'manual_recruitment_log_count_reference_only' as check_name,
  count(*) as log_count
from public.session_manual_recruitment_reminder_logs;
