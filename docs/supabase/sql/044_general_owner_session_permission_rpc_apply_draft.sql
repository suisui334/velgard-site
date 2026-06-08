-- 044_general_owner_session_permission_rpc_apply_draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
--
-- Purpose:
-- - Replace owner-scoped session post RPCs so authenticated session owners do not need a separate GM role.
-- - Keep admin access through public.is_session_gm(text), which resolves owner-or-admin.
-- - Preserve existing signatures, return shapes, validations, security definer, and search_path.
--
-- Scope:
-- - update_session_post
-- - delete_session_post
-- - check_discord_session_post_create_ready
-- - record_discord_session_post_create_success
-- - record_discord_session_post_create_failure
-- - check_discord_session_post_update_ready
-- - record_discord_session_post_update_success
-- - record_discord_session_post_update_failure
-- - check_discord_session_post_delete_ready
-- - record_discord_session_post_delete_failure
--
-- Out of scope:
-- - No table/RLS/policy changes.
-- - No Edge Function changes or deploy.
-- - No Discord send/edit/delete.
-- - No target session delete or resync.
-- - No secret, Webhook URL, JWT, raw user ID, session ID, or Discord ID values.
--
-- Review notes:
-- - This draft was mechanically derived from the reviewed 017/018/030/031 RPC drafts.
-- - The old permission pattern was:
--     is_admin() OR (has_role('gm') AND existing.gm_user_id = auth.uid())
-- - The replacement is:
--     coalesce(public.is_session_gm(target_session_id), false)
-- - public.is_session_gm(text) is expected to mean owner-or-admin and requires auth.uid() to be present.
-- - Existing function EXECUTE grants should be retained by CREATE OR REPLACE because signatures are unchanged.
-- - If the live signatures differ from this draft, stop and do not apply.
--
-- Apply-after checks to run in a later SELECT-only gate:
-- - Each target RPC exists once with security_definer = true and search_path set.
-- - authenticated can execute and anon cannot execute.
-- - Old has_role('gm') + owner gate is absent from each target RPC.
-- - public.is_session_gm(...) pattern is present in each target RPC.
-- - General owner can edit, delete, and close-mark own session.
-- - General owner cannot edit/delete/close-mark another user's session.
-- - Discord create/update/delete ready and record helpers can run for an owner-created session.
-- - The pending/create diagnostic target is handled only in a later explicit gate.
create or replace function public.update_session_post(
  p_session_id text,
  p_title text,
  p_session_date text,
  p_start_time text default null,
  p_end_time text default null,
  p_application_deadline text default null,
  p_session_type text default 'one-shot',
  p_player_min integer default null,
  p_player_max integer default null,
  p_summary text default null,
  p_visibility text default 'hidden',
  p_status text default 'draft',
  p_end_at text default null
)
returns table (
  session_id text,
  discord_sync_status text,
  discord_last_action text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_session_id text;
  v_title text;
  v_session_date date;
  v_start_time time;
  v_end_time time;
  v_application_deadline timestamptz;
  v_session_type text;
  v_visibility text;
  v_status text;
  v_summary text;
  v_start_text text;
  v_end_text text;
  v_deadline_text text;
  v_end_at_text text;
  v_start_at timestamptz;
  v_end_at timestamptz;
  v_existing record;
  v_discord_sync_status text;
  v_discord_last_action text;
  v_discord_sync_requested_at timestamptz;
  v_updated_at timestamptz;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_session_id := nullif(trim(coalesce(p_session_id, '')), '');
  if v_session_id is null then
    raise exception 'session_id_required' using errcode = '22023';
  end if;

  select
    s.id,
    s.gm_user_id,
    s.visibility,
    s.status,
    s.discord_message_id
  into v_existing
  from public.sessions as s
  where s.id = v_session_id
  for update;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not coalesce(public.is_session_gm(v_session_id), false) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  v_title := nullif(trim(coalesce(p_title, '')), '');
  if v_title is null then
    raise exception 'title_required' using errcode = '22023';
  end if;
  if length(v_title) > 120 then
    raise exception 'title_too_long' using errcode = '22023';
  end if;

  begin
    v_session_date := nullif(trim(coalesce(p_session_date, '')), '')::date;
  exception when others then
    raise exception 'invalid_session_date' using errcode = '22007';
  end;
  if v_session_date is null then
    raise exception 'session_date_required' using errcode = '22023';
  end if;

  v_start_text := nullif(trim(coalesce(p_start_time, '')), '');
  if v_start_text is null then
    raise exception 'start_time_required' using errcode = '22023';
  end if;
  if v_start_text !~ '^(([01][0-9]|2[0-3]):[0-5][0-9]|24:00)$' then
    raise exception 'invalid_start_time' using errcode = '22007';
  end if;
  v_start_time := v_start_text::time;

  v_end_text := nullif(trim(coalesce(p_end_time, '')), '');
  if v_end_text is not null then
    if v_end_text !~ '^(([01][0-9]|2[0-3]):[0-5][0-9]|24:00)$' then
      raise exception 'invalid_end_time' using errcode = '22007';
    end if;
    v_end_time := v_end_text::time;
  end if;

  v_end_at_text := nullif(trim(coalesce(p_end_at, '')), '');
  if v_end_at_text is not null then
    if v_end_at_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}$' then
      raise exception 'invalid_end_at' using errcode = '22007';
    end if;

    begin
      v_end_at := replace(v_end_at_text, 'T', ' ')::timestamp at time zone 'Asia/Tokyo';
    exception when others then
      raise exception 'invalid_end_at' using errcode = '22007';
    end;

    v_start_at := (v_session_date + v_start_time)::timestamp at time zone 'Asia/Tokyo';
    if v_end_at <= v_start_at then
      raise exception 'end_at_must_be_after_start_at' using errcode = '22023';
    end if;

    v_end_time := (v_end_at at time zone 'Asia/Tokyo')::time;
  elsif v_end_time is not null and v_end_time <= v_start_time then
    raise exception 'end_time_must_be_after_start_time' using errcode = '22023';
  end if;

  v_deadline_text := nullif(trim(coalesce(p_application_deadline, '')), '');
  if v_deadline_text is not null then
    if v_deadline_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}$' then
      raise exception 'invalid_application_deadline' using errcode = '22007';
    end if;
    begin
      v_application_deadline := replace(v_deadline_text, 'T', ' ')::timestamp at time zone 'Asia/Tokyo';
    exception when others then
      raise exception 'invalid_application_deadline' using errcode = '22007';
    end;
  end if;

  v_session_type := nullif(trim(coalesce(p_session_type, '')), '');
  if v_session_type is null then
    v_session_type := 'one-shot';
  end if;
  if v_session_type not in ('one-shot', 'campaign', 'special', 'other') then
    raise exception 'invalid_session_type' using errcode = '22023';
  end if;

  v_visibility := nullif(trim(coalesce(p_visibility, '')), '');
  if v_visibility is null then
    v_visibility := 'hidden';
  end if;
  if v_visibility not in ('public', 'private', 'hidden') then
    raise exception 'invalid_visibility' using errcode = '22023';
  end if;

  v_status := nullif(trim(coalesce(p_status, '')), '');
  if v_status is null then
    v_status := 'draft';
  end if;
  if v_status not in ('draft', 'tentative', 'recruiting', 'full', 'closed', 'finished', 'canceled') then
    raise exception 'invalid_status' using errcode = '22023';
  end if;
  if v_status = 'draft' and v_visibility = 'public' then
    raise exception 'draft_must_not_be_public' using errcode = '22023';
  end if;

  if p_player_min is not null and p_player_min < 0 then
    raise exception 'invalid_player_min' using errcode = '22023';
  end if;
  if p_player_max is not null and p_player_max < 0 then
    raise exception 'invalid_player_max' using errcode = '22023';
  end if;
  if p_player_min is not null and p_player_max is not null and p_player_min > p_player_max then
    raise exception 'invalid_player_range' using errcode = '22023';
  end if;

  v_summary := nullif(trim(coalesce(p_summary, '')), '');
  if v_summary is not null and length(v_summary) > 1000 then
    raise exception 'summary_too_long' using errcode = '22023';
  end if;

  if v_visibility = 'public' and v_status in ('tentative', 'recruiting', 'full') then
    v_discord_sync_status := 'pending';
    v_discord_last_action := case
      when nullif(trim(coalesce(v_existing.discord_message_id, '')), '') is null then 'create'
      else 'update'
    end;
  elsif v_visibility = 'public'
    and v_status in ('closed', 'finished')
    and nullif(trim(coalesce(v_existing.discord_message_id, '')), '') is not null then
    v_discord_sync_status := 'pending';
    v_discord_last_action := 'close';
  elsif (
      v_visibility <> 'public'
      or v_status in ('draft', 'canceled')
    )
    and nullif(trim(coalesce(v_existing.discord_message_id, '')), '') is not null then
    v_discord_sync_status := 'pending';
    v_discord_last_action := 'delete';
  else
    v_discord_sync_status := 'skipped';
    v_discord_last_action := null;
  end if;

  v_discord_sync_requested_at := case
    when v_discord_sync_status = 'pending' then now()
    else null
  end;

  update public.sessions
  set
    title = v_title,
    date = v_session_date,
    start_time = v_start_time,
    end_time = v_end_time,
    end_at = v_end_at,
    application_deadline = v_application_deadline,
    session_type = v_session_type,
    player_min = p_player_min,
    player_max = p_player_max,
    summary = v_summary,
    visibility = v_visibility,
    status = v_status,
    updated_at = now(),
    discord_sync_status = v_discord_sync_status,
    discord_last_action = v_discord_last_action,
    discord_sync_requested_at = v_discord_sync_requested_at,
    discord_sync_error = null
  where id = v_session_id
  returning public.sessions.updated_at
    into v_updated_at;

  session_id := v_session_id;
  discord_sync_status := v_discord_sync_status;
  discord_last_action := v_discord_last_action;
  updated_at := v_updated_at;
  return next;
end;
$$;

-- ============================================================

create or replace function public.delete_session_post(
  p_session_id text
)
returns table (
  deleted_session_id text,
  deleted_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_target_session_id text;
  v_existing record;
  v_deleted_at timestamptz := now();
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_target_session_id := nullif(trim(coalesce(p_session_id, '')), '');
  if v_target_session_id is null then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  select
    s.id,
    s.gm_user_id
  into v_existing
  from public.sessions as s
  where s.id = v_target_session_id
  for update;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not coalesce(public.is_session_gm(v_target_session_id), false) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  -- Static JSON sessions are outside public.sessions and cannot be targeted here.
  -- M-14D-13B preflight confirmed that session_applications.session_id and
  -- session_comments.session_id both use ON DELETE CASCADE.
  -- Application rows and application comment rows for the target session are
  -- removed together with the session by those constraints.
  delete from public.sessions as s
  where s.id = v_existing.id;

  deleted_session_id := v_existing.id;
  deleted_at := v_deleted_at;
  return next;
end;
$$;

-- ============================================================

create or replace function public.check_discord_session_post_create_ready(
  p_session_id text
)
returns table (
  session_id text,
  can_send boolean,
  discord_sync_status text,
  discord_last_action text,
  has_existing_post boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_session_id text;
  v_existing record;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_session_id := nullif(btrim(coalesce(p_session_id, '')), '');
  if v_session_id is null then
    raise exception 'session_id_required' using errcode = '22023';
  end if;

  select
    s.id,
    s.gm_user_id,
    s.discord_message_id,
    s.discord_sync_status,
    s.discord_last_action
  into v_existing
  from public.sessions as s
  where s.id = v_session_id
  for update;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not coalesce(public.is_session_gm(v_session_id), false) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if nullif(btrim(coalesce(v_existing.discord_message_id, '')), '') is not null then
    raise exception 'discord_create_already_synced' using errcode = '23505';
  end if;

  session_id := v_session_id;
  can_send := true;
  discord_sync_status := v_existing.discord_sync_status;
  discord_last_action := v_existing.discord_last_action;
  has_existing_post := false;
  return next;
end;
$$;

-- ============================================================

create or replace function public.record_discord_session_post_create_success(
  p_session_id text,
  p_discord_message_id text,
  p_discord_channel_id text default null,
  p_discord_thread_id text default null,
  p_discord_post_url text default null
)
returns table (
  session_id text,
  discord_sync_status text,
  discord_last_action text,
  discord_synced_at timestamptz,
  has_external_post_identifier boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_session_id text;
  v_message_id text;
  v_channel_id text;
  v_thread_id text;
  v_post_url text;
  v_existing record;
  v_synced_at timestamptz;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_session_id := nullif(btrim(coalesce(p_session_id, '')), '');
  if v_session_id is null then
    raise exception 'session_id_required' using errcode = '22023';
  end if;

  v_message_id := nullif(btrim(coalesce(p_discord_message_id, '')), '');
  if v_message_id is null then
    raise exception 'discord_message_id_required' using errcode = '22023';
  end if;
  if v_message_id ~ '[\r\n]' or length(v_message_id) > 120 then
    raise exception 'invalid_discord_message_id' using errcode = '22023';
  end if;

  v_channel_id := nullif(btrim(coalesce(p_discord_channel_id, '')), '');
  if v_channel_id is not null and (v_channel_id ~ '[\r\n]' or length(v_channel_id) > 120) then
    raise exception 'invalid_discord_channel_id' using errcode = '22023';
  end if;

  v_thread_id := nullif(btrim(coalesce(p_discord_thread_id, '')), '');
  if v_thread_id is not null and (v_thread_id ~ '[\r\n]' or length(v_thread_id) > 120) then
    raise exception 'invalid_discord_thread_id' using errcode = '22023';
  end if;

  v_post_url := nullif(btrim(coalesce(p_discord_post_url, '')), '');
  if v_post_url is not null and (v_post_url ~ '[\r\n]' or length(v_post_url) > 500) then
    raise exception 'invalid_discord_post_url' using errcode = '22023';
  end if;

  select
    s.id,
    s.gm_user_id,
    s.discord_message_id
  into v_existing
  from public.sessions as s
  where s.id = v_session_id
  for update;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not coalesce(public.is_session_gm(v_session_id), false) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if nullif(btrim(coalesce(v_existing.discord_message_id, '')), '') is not null then
    raise exception 'discord_create_already_synced' using errcode = '23505';
  end if;

  update public.sessions as s
  set
    discord_message_id = v_message_id,
    discord_channel_id = v_channel_id,
    discord_thread_id = v_thread_id,
    discord_post_url = v_post_url,
    discord_sync_status = 'posted',
    discord_last_action = 'create',
    discord_synced_at = now(),
    discord_sync_error = null,
    updated_at = now()
  where s.id = v_session_id
    and nullif(btrim(coalesce(s.discord_message_id, '')), '') is null
  returning s.discord_synced_at
    into v_synced_at;

  if not found then
    raise exception 'discord_create_record_conflict' using errcode = '23505';
  end if;

  session_id := v_session_id;
  discord_sync_status := 'posted';
  discord_last_action := 'create';
  discord_synced_at := v_synced_at;
  has_external_post_identifier := true;
  return next;
end;
$$;

-- ============================================================

create or replace function public.record_discord_session_post_create_failure(
  p_session_id text,
  p_error_code text default null
)
returns table (
  session_id text,
  discord_sync_status text,
  discord_last_action text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_session_id text;
  v_error_code text;
  v_existing record;
  v_updated_at timestamptz;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_session_id := nullif(btrim(coalesce(p_session_id, '')), '');
  if v_session_id is null then
    raise exception 'session_id_required' using errcode = '22023';
  end if;

  v_error_code := nullif(btrim(coalesce(p_error_code, '')), '');
  if v_error_code is null then
    v_error_code := 'discord_send_failed';
  end if;
  if v_error_code ~ '[\r\n]' then
    raise exception 'invalid_error_code' using errcode = '22023';
  end if;
  v_error_code := left(v_error_code, 120);

  select
    s.id,
    s.gm_user_id,
    s.discord_message_id
  into v_existing
  from public.sessions as s
  where s.id = v_session_id
  for update;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not coalesce(public.is_session_gm(v_session_id), false) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if nullif(btrim(coalesce(v_existing.discord_message_id, '')), '') is not null then
    raise exception 'discord_create_already_synced' using errcode = '23505';
  end if;

  update public.sessions as s
  set
    discord_sync_status = 'failed',
    discord_last_action = 'create',
    discord_sync_error = v_error_code,
    updated_at = now()
  where s.id = v_session_id
    and nullif(btrim(coalesce(s.discord_message_id, '')), '') is null
  returning s.updated_at
    into v_updated_at;

  if not found then
    raise exception 'discord_failure_record_conflict' using errcode = '23505';
  end if;

  session_id := v_session_id;
  discord_sync_status := 'failed';
  discord_last_action := 'create';
  updated_at := v_updated_at;
  return next;
end;
$$;

-- ============================================================

create or replace function public.check_discord_session_post_update_ready(
  p_session_id text
)
returns table (
  session_id text,
  can_update boolean,
  discord_sync_status text,
  discord_last_action text,
  has_external_post_identifier boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_session_id text;
  v_existing record;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_session_id := nullif(btrim(coalesce(p_session_id, '')), '');
  if v_session_id is null then
    raise exception 'session_id_required' using errcode = '22023';
  end if;

  select
    s.id,
    s.gm_user_id,
    s.discord_message_id,
    s.discord_sync_status,
    s.discord_last_action
  into v_existing
  from public.sessions as s
  where s.id = v_session_id
  for update;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not coalesce(public.is_session_gm(v_session_id), false) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if nullif(btrim(coalesce(v_existing.discord_message_id, '')), '') is null then
    raise exception 'discord_post_reference_required' using errcode = '22023';
  end if;

  session_id := v_session_id;
  can_update := true;
  discord_sync_status := v_existing.discord_sync_status;
  discord_last_action := v_existing.discord_last_action;
  has_external_post_identifier := true;
  return next;
end;
$$;

-- ============================================================

create or replace function public.record_discord_session_post_update_success(
  p_session_id text
)
returns table (
  session_id text,
  discord_sync_status text,
  discord_last_action text,
  discord_synced_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_session_id text;
  v_existing record;
  v_synced_at timestamptz;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_session_id := nullif(btrim(coalesce(p_session_id, '')), '');
  if v_session_id is null then
    raise exception 'session_id_required' using errcode = '22023';
  end if;

  select
    s.id,
    s.gm_user_id,
    s.discord_message_id
  into v_existing
  from public.sessions as s
  where s.id = v_session_id
  for update;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not coalesce(public.is_session_gm(v_session_id), false) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if nullif(btrim(coalesce(v_existing.discord_message_id, '')), '') is null then
    raise exception 'discord_post_reference_required' using errcode = '22023';
  end if;

  update public.sessions as s
  set
    discord_sync_status = 'posted',
    discord_last_action = 'update',
    discord_synced_at = now(),
    discord_sync_error = null,
    updated_at = now()
  where s.id = v_session_id
    and nullif(btrim(coalesce(s.discord_message_id, '')), '') is not null
  returning s.discord_synced_at
    into v_synced_at;

  if not found then
    raise exception 'discord_update_record_conflict' using errcode = '23505';
  end if;

  session_id := v_session_id;
  discord_sync_status := 'posted';
  discord_last_action := 'update';
  discord_synced_at := v_synced_at;
  return next;
end;
$$;

-- ============================================================

create or replace function public.record_discord_session_post_update_failure(
  p_session_id text,
  p_error_code text default null
)
returns table (
  session_id text,
  discord_sync_status text,
  discord_last_action text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_session_id text;
  v_error_code text;
  v_existing record;
  v_updated_at timestamptz;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_session_id := nullif(btrim(coalesce(p_session_id, '')), '');
  if v_session_id is null then
    raise exception 'session_id_required' using errcode = '22023';
  end if;

  v_error_code := nullif(btrim(coalesce(p_error_code, '')), '');
  if v_error_code is null then
    v_error_code := 'discord_update_failed';
  end if;
  if v_error_code ~ '[\r\n]' then
    raise exception 'invalid_error_code' using errcode = '22023';
  end if;
  v_error_code := left(v_error_code, 120);

  select
    s.id,
    s.gm_user_id
  into v_existing
  from public.sessions as s
  where s.id = v_session_id
  for update;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not coalesce(public.is_session_gm(v_session_id), false) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  update public.sessions as s
  set
    discord_sync_status = 'failed',
    discord_last_action = 'update',
    discord_sync_error = v_error_code,
    updated_at = now()
  where s.id = v_session_id
  returning s.updated_at
    into v_updated_at;

  if not found then
    raise exception 'discord_update_failure_record_conflict' using errcode = '23505';
  end if;

  session_id := v_session_id;
  discord_sync_status := 'failed';
  discord_last_action := 'update';
  updated_at := v_updated_at;
  return next;
end;
$$;

-- ============================================================

create or replace function public.check_discord_session_post_delete_ready(
  p_session_id text
)
returns table (
  session_id text,
  can_delete boolean,
  needs_discord_delete boolean,
  discord_sync_status text,
  discord_last_action text,
  has_external_post_identifier boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_session_id text;
  v_existing record;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_session_id := nullif(btrim(coalesce(p_session_id, '')), '');
  if v_session_id is null then
    raise exception 'session_id_required' using errcode = '22023';
  end if;

  select
    s.id,
    s.gm_user_id,
    s.discord_message_id,
    s.discord_sync_status,
    s.discord_last_action
  into v_existing
  from public.sessions as s
  where s.id = v_session_id
  for update;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not coalesce(public.is_session_gm(v_session_id), false) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  session_id := v_session_id;
  can_delete := true;
  discord_sync_status := v_existing.discord_sync_status;
  discord_last_action := v_existing.discord_last_action;
  has_external_post_identifier := nullif(btrim(coalesce(v_existing.discord_message_id, '')), '') is not null;
  needs_discord_delete := has_external_post_identifier;
  return next;
end;
$$;

-- ============================================================

create or replace function public.record_discord_session_post_delete_failure(
  p_session_id text,
  p_error_code text default null
)
returns table (
  session_id text,
  discord_sync_status text,
  discord_last_action text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_session_id text;
  v_error_code text;
  v_existing record;
  v_updated_at timestamptz;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_session_id := nullif(btrim(coalesce(p_session_id, '')), '');
  if v_session_id is null then
    raise exception 'session_id_required' using errcode = '22023';
  end if;

  v_error_code := nullif(btrim(coalesce(p_error_code, '')), '');
  if v_error_code is null then
    v_error_code := 'discord_delete_failed';
  end if;
  if v_error_code ~ '[\r\n]' then
    raise exception 'invalid_error_code' using errcode = '22023';
  end if;
  v_error_code := left(v_error_code, 120);

  select
    s.id,
    s.gm_user_id
  into v_existing
  from public.sessions as s
  where s.id = v_session_id
  for update;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not coalesce(public.is_session_gm(v_session_id), false) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  update public.sessions as s
  set
    discord_sync_status = 'failed',
    discord_last_action = 'delete',
    discord_sync_error = v_error_code,
    updated_at = now()
  where s.id = v_session_id
  returning s.updated_at
    into v_updated_at;

  if not found then
    raise exception 'discord_delete_failure_record_conflict' using errcode = '23505';
  end if;

  session_id := v_session_id;
  discord_sync_status := 'failed';
  discord_last_action := 'delete';
  updated_at := v_updated_at;
  return next;
end;
$$;
-- ============================================================
-- Post-apply SELECT-only verification candidates for a later gate
-- ============================================================
-- Do not run as part of this draft review unless explicitly approved.

select
  p.proname as function_name,
  p.oid::regprocedure::text as signature,
  p.prosecdef as security_definer,
  exists (
    select 1
    from unnest(coalesce(p.proconfig, array[]::text[])) cfg
    where cfg like 'search_path=%'
  ) as has_search_path,
  (pg_get_functiondef(p.oid) ilike '%is_session_gm%') as has_is_session_gm_pattern,
  (pg_get_functiondef(p.oid) ilike '%has_role(''gm'')%') as has_gm_role_pattern
from pg_proc p
join pg_namespace n
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
order by p.proname, p.oid::regprocedure::text;
