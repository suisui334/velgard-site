-- 052_admin_discord_announcements_rpc_apply_draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
-- RPC APPLY DRAFT ONLY
--
-- Purpose:
-- - Add reviewed RPCs after 050_admin_discord_announcements_schema_apply_draft.sql
--   has already been applied successfully.
-- - This draft exists because the 051 SELECT-only check found RPC missing/review
--   results while table, RLS, CHECK constraints, and table grants were OK.
-- - Keep the feature scoped to admin-only Discord cap update announcements.
--
-- Safety:
-- - Run only in a separate explicit SQL apply gate after user approval.
-- - Do not run from Codex without that gate.
-- - Do not store Webhook URL values, token values, JWTs, Supabase project URLs,
--   Discord channel IDs, or raw external response bodies in this SQL.
-- - Browser/static JS must keep using RPC boundaries and must not add direct
--   insert/update/delete/upsert calls.
--
-- RPCs added by this draft:
-- - create_admin_discord_announcement
-- - update_admin_discord_announcement
-- - cancel_admin_discord_announcement
-- - list_admin_discord_announcements
-- - claim_due_admin_discord_announcements
-- - finalize_admin_discord_announcement

begin;

alter table public.admin_discord_announcements
  add column if not exists discord_message_id text;

comment on column public.admin_discord_announcements.discord_message_id is
  'Optional external message identifier recorded after successful delivery. Do not return it to browser list RPCs.';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'admin_discord_announcements_discord_message_id_check'
      and conrelid = 'public.admin_discord_announcements'::regclass
  ) then
    alter table public.admin_discord_announcements
      add constraint admin_discord_announcements_discord_message_id_check
      check (
        discord_message_id is null
        or (
          char_length(trim(discord_message_id)) between 1 and 120
          and discord_message_id ~ '^[0-9A-Za-z._:-]+$'
        )
      );
  end if;
end $$;

create or replace function public.create_admin_discord_announcement(
  p_announcement_title text,
  p_announcement_body text,
  p_target_channel_key text,
  p_scheduled_at text,
  p_timezone text default 'Asia/Tokyo',
  p_mention_mode text default 'none',
  p_status text default 'draft',
  p_cap_level text default null,
  p_apply_start_date text default null,
  p_apply_end_date text default null,
  p_note text default null
)
returns table (
  id uuid,
  announcement_type text,
  announcement_title text,
  announcement_body text,
  target_channel_key text,
  scheduled_at timestamptz,
  timezone text,
  mention_mode text,
  status text,
  cap_level text,
  apply_start_date date,
  apply_end_date date,
  note text,
  attempt_count integer,
  max_attempts integer,
  next_attempt_at timestamptz,
  posted_at timestamptz,
  has_delivery_error boolean,
  delivery_error_code text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid := auth.uid();
  v_title text := btrim(coalesce(p_announcement_title, ''));
  v_body text := btrim(coalesce(p_announcement_body, ''));
  v_target_channel_key text := btrim(coalesce(p_target_channel_key, ''));
  v_timezone text := btrim(coalesce(p_timezone, 'Asia/Tokyo'));
  v_mention_mode text := btrim(coalesce(p_mention_mode, 'none'));
  v_status text := btrim(coalesce(p_status, 'draft'));
  v_cap_level text := nullif(btrim(coalesce(p_cap_level, '')), '');
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_scheduled_at timestamptz;
  v_apply_start_date date;
  v_apply_end_date date;
  v_inserted_id uuid;
begin
  if v_actor_id is null or not coalesce(public.is_admin(), false) then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  if v_title = '' or char_length(v_title) > 120 then
    raise exception 'invalid_announcement_title' using errcode = '22023';
  end if;

  if v_body = '' or char_length(v_body) > 1800 then
    raise exception 'invalid_announcement_body' using errcode = '22023';
  end if;

  if v_target_channel_key <> 'cap_announcement' then
    raise exception 'invalid_target_channel_key' using errcode = '22023';
  end if;

  if v_mention_mode not in ('none', 'everyone') then
    raise exception 'invalid_mention_mode' using errcode = '22023';
  end if;

  if v_status not in ('draft', 'scheduled') then
    raise exception 'invalid_create_status' using errcode = '22023';
  end if;

  if v_timezone = '' or not exists (
    select 1 from pg_catalog.pg_timezone_names where name = v_timezone
  ) then
    raise exception 'invalid_timezone' using errcode = '22023';
  end if;

  if nullif(btrim(coalesce(p_scheduled_at, '')), '') is null then
    raise exception 'scheduled_at_required' using errcode = '22023';
  end if;

  v_scheduled_at := (replace(btrim(p_scheduled_at), 'T', ' ')::timestamp at time zone v_timezone);
  v_apply_start_date := nullif(btrim(coalesce(p_apply_start_date, '')), '')::date;
  v_apply_end_date := nullif(btrim(coalesce(p_apply_end_date, '')), '')::date;

  if v_cap_level is not null and char_length(v_cap_level) > 40 then
    raise exception 'invalid_cap_level' using errcode = '22023';
  end if;

  if v_note is not null and char_length(v_note) > 500 then
    raise exception 'invalid_note' using errcode = '22023';
  end if;

  if v_apply_start_date is not null and v_apply_end_date is not null and v_apply_end_date < v_apply_start_date then
    raise exception 'invalid_apply_date_range' using errcode = '22023';
  end if;

  insert into public.admin_discord_announcements as a (
    created_by,
    announcement_type,
    announcement_title,
    announcement_body,
    target_channel_key,
    scheduled_at,
    timezone,
    mention_mode,
    status,
    cap_level,
    apply_start_date,
    apply_end_date,
    note
  )
  values (
    v_actor_id,
    'cap_update',
    v_title,
    v_body,
    'cap_announcement',
    v_scheduled_at,
    v_timezone,
    v_mention_mode,
    v_status,
    v_cap_level,
    v_apply_start_date,
    v_apply_end_date,
    v_note
  )
  returning a.id into v_inserted_id;

  return query
  select
    a.id,
    a.announcement_type,
    a.announcement_title,
    a.announcement_body,
    a.target_channel_key,
    a.scheduled_at,
    a.timezone,
    a.mention_mode,
    a.status,
    a.cap_level,
    a.apply_start_date,
    a.apply_end_date,
    a.note,
    a.attempt_count,
    a.max_attempts,
    a.next_attempt_at,
    a.posted_at,
    a.delivery_error_code is not null as has_delivery_error,
    a.delivery_error_code,
    a.created_at,
    a.updated_at
  from public.admin_discord_announcements a
  where a.id = v_inserted_id
    and a.announcement_type = 'cap_update'
    and a.target_channel_key = 'cap_announcement'
    and a.mention_mode in ('none', 'everyone')
    and a.status in ('draft', 'scheduled', 'processing', 'posted', 'failed', 'canceled');
end;
$$;

create or replace function public.update_admin_discord_announcement(
  p_announcement_id uuid,
  p_announcement_title text,
  p_announcement_body text,
  p_target_channel_key text,
  p_scheduled_at text,
  p_timezone text default 'Asia/Tokyo',
  p_mention_mode text default 'none',
  p_status text default 'draft',
  p_cap_level text default null,
  p_apply_start_date text default null,
  p_apply_end_date text default null,
  p_note text default null
)
returns table (
  id uuid,
  announcement_type text,
  announcement_title text,
  announcement_body text,
  target_channel_key text,
  scheduled_at timestamptz,
  timezone text,
  mention_mode text,
  status text,
  cap_level text,
  apply_start_date date,
  apply_end_date date,
  note text,
  attempt_count integer,
  max_attempts integer,
  next_attempt_at timestamptz,
  posted_at timestamptz,
  has_delivery_error boolean,
  delivery_error_code text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid := auth.uid();
  v_title text := btrim(coalesce(p_announcement_title, ''));
  v_body text := btrim(coalesce(p_announcement_body, ''));
  v_target_channel_key text := btrim(coalesce(p_target_channel_key, ''));
  v_timezone text := btrim(coalesce(p_timezone, 'Asia/Tokyo'));
  v_mention_mode text := btrim(coalesce(p_mention_mode, 'none'));
  v_status text := btrim(coalesce(p_status, 'draft'));
  v_cap_level text := nullif(btrim(coalesce(p_cap_level, '')), '');
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_scheduled_at timestamptz;
  v_apply_start_date date;
  v_apply_end_date date;
  v_existing_status text;
begin
  if p_announcement_id is null then
    raise exception 'announcement_id_required' using errcode = '22023';
  end if;

  if v_actor_id is null or not coalesce(public.is_admin(), false) then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  select a.status
    into v_existing_status
  from public.admin_discord_announcements a
  where a.id = p_announcement_id
    and a.announcement_type = 'cap_update'
    and a.target_channel_key = 'cap_announcement'
    and a.mention_mode in ('none', 'everyone')
  for update;

  if v_existing_status is null then
    raise exception 'announcement_not_found' using errcode = 'P0002';
  end if;

  if v_existing_status in ('processing', 'posted', 'canceled') then
    raise exception 'announcement_not_editable' using errcode = '55000';
  end if;

  if v_existing_status not in ('draft', 'scheduled', 'failed') then
    raise exception 'announcement_not_editable' using errcode = '55000';
  end if;

  if v_title = '' or char_length(v_title) > 120 then
    raise exception 'invalid_announcement_title' using errcode = '22023';
  end if;

  if v_body = '' or char_length(v_body) > 1800 then
    raise exception 'invalid_announcement_body' using errcode = '22023';
  end if;

  if v_target_channel_key <> 'cap_announcement' then
    raise exception 'invalid_target_channel_key' using errcode = '22023';
  end if;

  if v_mention_mode not in ('none', 'everyone') then
    raise exception 'invalid_mention_mode' using errcode = '22023';
  end if;

  if v_status not in ('draft', 'scheduled') then
    raise exception 'invalid_update_status' using errcode = '22023';
  end if;

  if v_timezone = '' or not exists (
    select 1 from pg_catalog.pg_timezone_names where name = v_timezone
  ) then
    raise exception 'invalid_timezone' using errcode = '22023';
  end if;

  if nullif(btrim(coalesce(p_scheduled_at, '')), '') is null then
    raise exception 'scheduled_at_required' using errcode = '22023';
  end if;

  v_scheduled_at := (replace(btrim(p_scheduled_at), 'T', ' ')::timestamp at time zone v_timezone);
  v_apply_start_date := nullif(btrim(coalesce(p_apply_start_date, '')), '')::date;
  v_apply_end_date := nullif(btrim(coalesce(p_apply_end_date, '')), '')::date;

  if v_cap_level is not null and char_length(v_cap_level) > 40 then
    raise exception 'invalid_cap_level' using errcode = '22023';
  end if;

  if v_note is not null and char_length(v_note) > 500 then
    raise exception 'invalid_note' using errcode = '22023';
  end if;

  if v_apply_start_date is not null and v_apply_end_date is not null and v_apply_end_date < v_apply_start_date then
    raise exception 'invalid_apply_date_range' using errcode = '22023';
  end if;

  return query
  update public.admin_discord_announcements a
  set
    announcement_title = v_title,
    announcement_body = v_body,
    target_channel_key = 'cap_announcement',
    scheduled_at = v_scheduled_at,
    timezone = v_timezone,
    mention_mode = v_mention_mode,
    status = v_status,
    cap_level = v_cap_level,
    apply_start_date = v_apply_start_date,
    apply_end_date = v_apply_end_date,
    note = v_note,
    attempt_count = 0,
    next_attempt_at = null,
    locked_at = null,
    lock_token = null,
    delivery_error_code = null,
    delivery_error_at = null,
    posted_at = null,
    discord_message_id = null,
    updated_at = now()
  where a.id = p_announcement_id
    and a.announcement_type = 'cap_update'
    and a.target_channel_key = 'cap_announcement'
    and a.mention_mode in ('none', 'everyone')
    and a.status in ('draft', 'scheduled', 'failed')
  returning
    a.id,
    a.announcement_type,
    a.announcement_title,
    a.announcement_body,
    a.target_channel_key,
    a.scheduled_at,
    a.timezone,
    a.mention_mode,
    a.status,
    a.cap_level,
    a.apply_start_date,
    a.apply_end_date,
    a.note,
    a.attempt_count,
    a.max_attempts,
    a.next_attempt_at,
    a.posted_at,
    a.delivery_error_code is not null as has_delivery_error,
    a.delivery_error_code,
    a.created_at,
    a.updated_at;

  if not found then
    raise exception 'announcement_not_editable' using errcode = '55000';
  end if;
end;
$$;

create or replace function public.cancel_admin_discord_announcement(
  p_announcement_id uuid
)
returns table (
  id uuid,
  announcement_type text,
  announcement_title text,
  announcement_body text,
  target_channel_key text,
  scheduled_at timestamptz,
  timezone text,
  mention_mode text,
  status text,
  cap_level text,
  apply_start_date date,
  apply_end_date date,
  note text,
  attempt_count integer,
  max_attempts integer,
  next_attempt_at timestamptz,
  posted_at timestamptz,
  has_delivery_error boolean,
  delivery_error_code text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid := auth.uid();
begin
  if p_announcement_id is null then
    raise exception 'announcement_id_required' using errcode = '22023';
  end if;

  if v_actor_id is null or not coalesce(public.is_admin(), false) then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  return query
  update public.admin_discord_announcements a
  set
    status = 'canceled',
    locked_at = null,
    lock_token = null,
    next_attempt_at = null,
    delivery_error_code = null,
    delivery_error_at = null,
    updated_at = now()
  where a.id = p_announcement_id
    and a.announcement_type = 'cap_update'
    and a.target_channel_key = 'cap_announcement'
    and a.mention_mode in ('none', 'everyone')
    and a.status in ('draft', 'scheduled', 'failed')
    and a.status not in ('processing', 'posted')
  returning
    a.id,
    a.announcement_type,
    a.announcement_title,
    a.announcement_body,
    a.target_channel_key,
    a.scheduled_at,
    a.timezone,
    a.mention_mode,
    a.status,
    a.cap_level,
    a.apply_start_date,
    a.apply_end_date,
    a.note,
    a.attempt_count,
    a.max_attempts,
    a.next_attempt_at,
    a.posted_at,
    a.delivery_error_code is not null as has_delivery_error,
    a.delivery_error_code,
    a.created_at,
    a.updated_at;

  if not found then
    raise exception 'announcement_not_cancelable' using errcode = '55000';
  end if;
end;
$$;

create or replace function public.list_admin_discord_announcements(
  p_status_filter text default null,
  p_limit integer default 50
)
returns table (
  id uuid,
  announcement_type text,
  announcement_title text,
  announcement_body text,
  target_channel_key text,
  scheduled_at timestamptz,
  timezone text,
  mention_mode text,
  status text,
  cap_level text,
  apply_start_date date,
  apply_end_date date,
  note text,
  attempt_count integer,
  max_attempts integer,
  next_attempt_at timestamptz,
  posted_at timestamptz,
  has_delivery_error boolean,
  delivery_error_code text,
  delivery_error_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid := auth.uid();
  v_status_filter text := nullif(btrim(coalesce(p_status_filter, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
begin
  if v_actor_id is null or not coalesce(public.is_admin(), false) then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  if v_status_filter is not null and v_status_filter not in ('draft', 'scheduled', 'processing', 'posted', 'failed', 'canceled') then
    raise exception 'invalid_status_filter' using errcode = '22023';
  end if;

  return query
  select
    a.id,
    a.announcement_type,
    a.announcement_title,
    a.announcement_body,
    a.target_channel_key,
    a.scheduled_at,
    a.timezone,
    a.mention_mode,
    a.status,
    a.cap_level,
    a.apply_start_date,
    a.apply_end_date,
    a.note,
    a.attempt_count,
    a.max_attempts,
    a.next_attempt_at,
    a.posted_at,
    a.delivery_error_code is not null as has_delivery_error,
    a.delivery_error_code,
    a.delivery_error_at,
    a.created_at,
    a.updated_at
  from public.admin_discord_announcements a
  where a.announcement_type = 'cap_update'
    and a.target_channel_key = 'cap_announcement'
    and a.mention_mode in ('none', 'everyone')
    and (v_status_filter is null or a.status = v_status_filter)
    and a.status in ('draft', 'scheduled', 'processing', 'posted', 'failed', 'canceled')
  order by a.created_at desc
  limit v_limit;
end;
$$;

create or replace function public.claim_due_admin_discord_announcements(
  p_limit integer default 5
)
returns table (
  id uuid,
  lock_token uuid,
  announcement_title text,
  announcement_body text,
  target_channel_key text,
  scheduled_at timestamptz,
  timezone text,
  mention_mode text,
  cap_level text,
  apply_start_date date,
  apply_end_date date,
  note text,
  attempt_count integer,
  max_attempts integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 5), 1), 10);
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'server_role_required' using errcode = '42501';
  end if;

  return query
  with due as (
    select a.id
    from public.admin_discord_announcements a
    where a.announcement_type = 'cap_update'
      and a.target_channel_key = 'cap_announcement'
      and a.mention_mode in ('none', 'everyone')
      and a.status = 'scheduled'
      and a.scheduled_at <= now()
      and coalesce(a.next_attempt_at, a.scheduled_at) <= now()
      and a.attempt_count < a.max_attempts
    order by a.scheduled_at asc, a.created_at asc
    limit v_limit
    for update skip locked
  ),
  claimed as (
    update public.admin_discord_announcements a
    set
      status = 'processing',
      locked_at = now(),
      lock_token = gen_random_uuid(),
      attempt_count = a.attempt_count + 1,
      delivery_error_code = null,
      delivery_error_at = null,
      updated_at = now()
    from due
    where a.id = due.id
      and a.announcement_type = 'cap_update'
      and a.target_channel_key = 'cap_announcement'
      and a.status = 'scheduled'
    returning
      a.id,
      a.lock_token,
      a.announcement_title,
      a.announcement_body,
      a.target_channel_key,
      a.scheduled_at,
      a.timezone,
      a.mention_mode,
      a.cap_level,
      a.apply_start_date,
      a.apply_end_date,
      a.note,
      a.attempt_count,
      a.max_attempts
  )
  select
    c.id,
    c.lock_token,
    c.announcement_title,
    c.announcement_body,
    c.target_channel_key,
    c.scheduled_at,
    c.timezone,
    c.mention_mode,
    c.cap_level,
    c.apply_start_date,
    c.apply_end_date,
    c.note,
    c.attempt_count,
    c.max_attempts
  from claimed c;
end;
$$;

create or replace function public.finalize_admin_discord_announcement(
  p_announcement_id uuid,
  p_lock_token uuid,
  p_delivery_status text,
  p_delivery_error_code text default null,
  p_retry_after_seconds integer default null,
  p_discord_message_id text default null
)
returns table (
  id uuid,
  status text,
  posted_at timestamptz,
  attempt_count integer,
  next_attempt_at timestamptz,
  has_delivery_error boolean,
  delivery_error_code text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery_status text := btrim(coalesce(p_delivery_status, ''));
  v_error_code text := lower(nullif(btrim(coalesce(p_delivery_error_code, '')), ''));
  v_retry_after_seconds integer := least(greatest(coalesce(p_retry_after_seconds, 60), 1), 3600);
  v_discord_message_id text := nullif(btrim(coalesce(p_discord_message_id, '')), '');
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'server_role_required' using errcode = '42501';
  end if;

  if p_announcement_id is null or p_lock_token is null then
    raise exception 'claim_identifier_required' using errcode = '22023';
  end if;

  if v_delivery_status not in ('posted', 'scheduled', 'failed') then
    raise exception 'invalid_delivery_status' using errcode = '22023';
  end if;

  if v_error_code is not null and v_error_code !~ '^[a-z0-9_]{1,80}$' then
    v_error_code := 'delivery_failed';
  end if;

  if v_delivery_status in ('scheduled', 'failed') and v_error_code is null then
    v_error_code := 'delivery_failed';
  end if;

  if v_discord_message_id is not null and (
    char_length(v_discord_message_id) > 120
    or v_discord_message_id !~ '^[0-9A-Za-z._:-]+$'
  ) then
    raise exception 'invalid_discord_message_id' using errcode = '22023';
  end if;

  return query
  update public.admin_discord_announcements a
  set
    status = case
      when v_delivery_status = 'posted' then 'posted'
      when v_delivery_status = 'scheduled' and a.attempt_count < a.max_attempts then 'scheduled'
      else 'failed'
    end,
    posted_at = case when v_delivery_status = 'posted' then now() else null end,
    next_attempt_at = case
      when v_delivery_status = 'scheduled' and a.attempt_count < a.max_attempts
        then now() + make_interval(secs => v_retry_after_seconds)
      else null
    end,
    delivery_error_code = case when v_delivery_status = 'posted' then null else v_error_code end,
    delivery_error_at = case when v_delivery_status = 'posted' then null else now() end,
    discord_message_id = case
      when v_delivery_status = 'posted' then v_discord_message_id
      else a.discord_message_id
    end,
    locked_at = null,
    lock_token = null,
    updated_at = now()
  where a.id = p_announcement_id
    and a.lock_token = p_lock_token
    and a.announcement_type = 'cap_update'
    and a.target_channel_key = 'cap_announcement'
    and a.mention_mode in ('none', 'everyone')
    and a.status = 'processing'
  returning
    a.id,
    a.status,
    a.posted_at,
    a.attempt_count,
    a.next_attempt_at,
    a.delivery_error_code is not null as has_delivery_error,
    a.delivery_error_code,
    a.updated_at;

  if not found then
    raise exception 'claimed_announcement_not_found' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.create_admin_discord_announcement(text,text,text,text,text,text,text,text,text,text,text) from public;
revoke all on function public.create_admin_discord_announcement(text,text,text,text,text,text,text,text,text,text,text) from anon;
revoke all on function public.create_admin_discord_announcement(text,text,text,text,text,text,text,text,text,text,text) from authenticated;
grant execute on function public.create_admin_discord_announcement(text,text,text,text,text,text,text,text,text,text,text) to authenticated;

revoke all on function public.update_admin_discord_announcement(uuid,text,text,text,text,text,text,text,text,text,text,text) from public;
revoke all on function public.update_admin_discord_announcement(uuid,text,text,text,text,text,text,text,text,text,text,text) from anon;
revoke all on function public.update_admin_discord_announcement(uuid,text,text,text,text,text,text,text,text,text,text,text) from authenticated;
grant execute on function public.update_admin_discord_announcement(uuid,text,text,text,text,text,text,text,text,text,text,text) to authenticated;

revoke all on function public.cancel_admin_discord_announcement(uuid) from public;
revoke all on function public.cancel_admin_discord_announcement(uuid) from anon;
revoke all on function public.cancel_admin_discord_announcement(uuid) from authenticated;
grant execute on function public.cancel_admin_discord_announcement(uuid) to authenticated;

revoke all on function public.list_admin_discord_announcements(text,integer) from public;
revoke all on function public.list_admin_discord_announcements(text,integer) from anon;
revoke all on function public.list_admin_discord_announcements(text,integer) from authenticated;
grant execute on function public.list_admin_discord_announcements(text,integer) to authenticated;

revoke all on function public.claim_due_admin_discord_announcements(integer) from public;
revoke all on function public.claim_due_admin_discord_announcements(integer) from anon;
revoke all on function public.claim_due_admin_discord_announcements(integer) from authenticated;
grant execute on function public.claim_due_admin_discord_announcements(integer) to service_role;

revoke all on function public.finalize_admin_discord_announcement(uuid,uuid,text,text,integer,text) from public;
revoke all on function public.finalize_admin_discord_announcement(uuid,uuid,text,text,integer,text) from anon;
revoke all on function public.finalize_admin_discord_announcement(uuid,uuid,text,text,integer,text) from authenticated;
grant execute on function public.finalize_admin_discord_announcement(uuid,uuid,text,text,integer,text) to service_role;

comment on function public.create_admin_discord_announcement(text,text,text,text,text,text,text,text,text,text,text) is
  'Admin-only browser RPC for cap update announcement creation. Checks public.is_admin(); stores target_channel_key only.';

comment on function public.update_admin_discord_announcement(uuid,text,text,text,text,text,text,text,text,text,text,text) is
  'Admin-only browser RPC for editable cap update announcements. Does not edit processing/posted/canceled rows.';

comment on function public.cancel_admin_discord_announcement(uuid) is
  'Admin-only browser RPC for canceling draft/scheduled/failed cap update announcements.';

comment on function public.list_admin_discord_announcements(text,integer) is
  'Admin-only browser RPC for listing cap update announcements without Webhook values or raw external identifiers.';

comment on function public.claim_due_admin_discord_announcements(integer) is
  'Server-only RPC for Edge Function claim. Moves due scheduled cap announcements to processing with lock_token.';

comment on function public.finalize_admin_discord_announcement(uuid,uuid,text,text,integer,text) is
  'Server-only RPC for Edge Function finalize. Uses id plus lock_token and stores generalized delivery result.';

commit;
