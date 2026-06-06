-- 027_session_tool_apply_review_draft.sql
-- M-14E-15D reviewed draft for adding sessions.session_tool.
--
-- DRAFT ONLY.
-- Do not paste into Supabase SQL Editor until a separate apply review is done.
-- This chat does not execute this SQL.
--
-- Goals:
-- - Add nullable public.sessions.session_tool for the UI label "開催場所".
-- - Keep the DB value as a session tool / online play environment, not a physical venue.
-- - Keep existing rows valid by allowing NULL.
-- - Keep initial input free text; no fixed-value CHECK in this draft.
-- - Avoid PostgREST default-argument overload ambiguity by replacing existing RPC signatures.
--
-- Safety notes:
-- - No DROP TABLE, DROP COLUMN, TRUNCATE, or direct data cleanup.
-- - DROP FUNCTION is used only to replace RPC signatures.
-- - Do not use CASCADE for DROP FUNCTION in this draft.
-- - INSERT/UPDATE statements appear only inside RPC function bodies and do not run at apply time.
-- - The schema/RPC/grant section is wrapped in an explicit transaction.
-- - Keep credential values, connection strings, external post targets, auth tokens, and row data out of this file.
-- - Keep SQL string literals and review labels ASCII-only where possible to avoid paste encoding issues.

begin;

-- ============================================================
-- 1. Schema draft
-- ============================================================

alter table public.sessions
  add column if not exists session_tool text;

-- No CHECK constraint in the initial draft.
-- RPCs normalize blank values to NULL.
-- UI and Discord output should display a fallback label for NULL/blank.

-- ============================================================
-- 2. create_session_post RPC replacement draft
-- ============================================================

-- Drop old and new candidate signatures before creating the reviewed signature.
-- This avoids ambiguous overloaded RPCs with default arguments.

drop function if exists public.create_session_post(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  text,
  text,
  text,
  text,
  text,
  text,
  text
);

drop function if exists public.create_session_post(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  text,
  text,
  text,
  text,
  text,
  text
);

create function public.create_session_post(
  p_title text,
  p_session_date text,
  p_start_time text default null,
  p_end_time text default null,
  p_application_deadline text default null,
  p_session_type text default 'one-shot',
  p_level_range text default null,
  p_player_min integer default null,
  p_player_max integer default null,
  p_summary text default null,
  p_request_body text default null,
  p_requirements text default null,
  p_visibility text default 'public',
  p_status text default 'recruiting',
  p_end_at text default null,
  p_session_tool text default null
)
returns table (
  session_id text,
  discord_sync_status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_title text;
  v_session_date date;
  v_start_time time;
  v_end_time time;
  v_application_deadline timestamptz;
  v_session_type text;
  v_visibility text;
  v_status text;
  v_summary text;
  v_detail text;
  v_requirements text;
  v_level_range text;
  v_session_tool text;
  v_gm_name text;
  v_session_id text;
  v_created_at timestamptz;
  v_discord_sync_status text;
  v_discord_last_action text;
  v_start_text text;
  v_end_text text;
  v_deadline_text text;
  v_end_at_text text;
  v_start_at timestamptz;
  v_end_at timestamptz;
  v_try integer;
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  if not (public.has_role('gm') or public.is_admin()) then
    raise exception 'gm_or_admin_required' using errcode = '42501';
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

  v_start_text := nullif(trim(coalesce(p_start_time, '')), '');
  if v_start_text is not null then
    if v_start_text !~ '^(([01][0-9]|2[0-3]):[0-5][0-9]|24:00)$' then
      raise exception 'invalid_start_time' using errcode = '22007';
    end if;
    v_start_time := v_start_text::time;
  end if;

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

    if v_start_time is not null then
      v_start_at := (v_session_date + v_start_time)::timestamp at time zone 'Asia/Tokyo';
      if v_end_at < v_start_at then
        raise exception 'end_at_before_start_at' using errcode = '22023';
      end if;
    end if;

    v_end_time := (v_end_at at time zone 'Asia/Tokyo')::time;
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
    v_visibility := 'public';
  end if;
  if v_visibility not in ('public', 'private', 'hidden') then
    raise exception 'invalid_visibility' using errcode = '22023';
  end if;

  v_status := nullif(trim(coalesce(p_status, '')), '');
  if v_status is null then
    v_status := 'recruiting';
  end if;
  if v_status not in ('draft', 'tentative', 'recruiting') then
    raise exception 'invalid_initial_status' using errcode = '22023';
  end if;
  if v_status = 'draft' and v_visibility = 'public' then
    raise exception 'draft_must_not_be_public' using errcode = '22023';
  end if;

  if v_visibility = 'public' and v_status in ('tentative', 'recruiting') then
    v_discord_sync_status := 'pending';
    v_discord_last_action := 'create';
  else
    v_discord_sync_status := 'skipped';
    v_discord_last_action := null;
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

  v_detail := nullif(trim(coalesce(p_request_body, '')), '');
  if v_detail is not null and length(v_detail) > 8000 then
    raise exception 'request_body_too_long' using errcode = '22023';
  end if;

  v_requirements := nullif(trim(coalesce(p_requirements, '')), '');
  if v_requirements is not null and length(v_requirements) > 2000 then
    raise exception 'requirements_too_long' using errcode = '22023';
  end if;

  v_level_range := nullif(trim(coalesce(p_level_range, '')), '');
  if v_level_range is not null and length(v_level_range) > 80 then
    raise exception 'level_range_too_long' using errcode = '22023';
  end if;

  v_session_tool := nullif(trim(coalesce(p_session_tool, '')), '');
  if v_session_tool is not null then
    if v_session_tool ~ '[\r\n]' then
      raise exception 'session_tool_must_be_single_line' using errcode = '22023';
    end if;
    if length(v_session_tool) > 80 then
      raise exception 'session_tool_too_long' using errcode = '22023';
    end if;
  end if;

  select coalesce(nullif(trim(p.display_name), ''), 'GM未設定')
    into v_gm_name
  from public.profiles as p
  where p.id = v_actor;

  if v_gm_name is null then
    v_gm_name := 'GM未設定';
  end if;

  for v_try in 1..8 loop
    v_session_id := 'session-' || to_char(v_session_date, 'YYYY-MM-DD') || '-' ||
      lower(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    exit when not exists (
      select 1
      from public.sessions as s
      where s.id = v_session_id
    );
  end loop;

  if exists (
    select 1
    from public.sessions as s
    where s.id = v_session_id
  ) then
    raise exception 'session_id_generation_failed' using errcode = '23505';
  end if;

  insert into public.sessions (
    id,
    title,
    date,
    start_time,
    end_time,
    end_at,
    gm_user_id,
    gm_name,
    status,
    session_type,
    session_tool,
    application_deadline,
    level_range,
    player_min,
    player_max,
    summary,
    detail,
    requirements,
    visibility,
    discord_sync_status,
    discord_last_action,
    discord_sync_requested_at
  )
  values (
    v_session_id,
    v_title,
    v_session_date,
    v_start_time,
    v_end_time,
    v_end_at,
    v_actor,
    v_gm_name,
    v_status,
    v_session_type,
    v_session_tool,
    v_application_deadline,
    v_level_range,
    p_player_min,
    p_player_max,
    v_summary,
    v_detail,
    v_requirements,
    v_visibility,
    v_discord_sync_status,
    v_discord_last_action,
    case when v_discord_sync_status = 'pending' then now() else null end
  )
  returning public.sessions.created_at
    into v_created_at;

  session_id := v_session_id;
  discord_sync_status := v_discord_sync_status;
  created_at := v_created_at;
  return next;
end;
$$;

revoke execute on function public.create_session_post(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  text,
  text,
  text,
  text,
  text,
  text,
  text
) from public;

revoke execute on function public.create_session_post(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  text,
  text,
  text,
  text,
  text,
  text,
  text
) from anon;

grant execute on function public.create_session_post(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  text,
  text,
  text,
  text,
  text,
  text,
  text
) to authenticated;

-- ============================================================
-- 3. update_session_post RPC replacement draft
-- ============================================================

-- For update_session_post, omitted p_session_tool keeps the existing value.
-- Passing an empty string clears the value to NULL after trim normalization.

drop function if exists public.update_session_post(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  text,
  text,
  text,
  text,
  text
);

drop function if exists public.update_session_post(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  text,
  text,
  text,
  text
);

create function public.update_session_post(
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
  p_end_at text default null,
  p_session_tool text default null
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
  v_session_tool text;
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
    s.discord_message_id,
    s.session_tool
  into v_existing
  from public.sessions as s
  where s.id = v_session_id
  for update;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not (
    public.is_admin()
    or (
      public.has_role('gm')
      and v_existing.gm_user_id = v_actor
    )
  ) then
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

  if p_session_tool is null then
    v_session_tool := v_existing.session_tool;
  else
    v_session_tool := nullif(trim(p_session_tool), '');
  end if;
  if v_session_tool is not null then
    if v_session_tool ~ '[\r\n]' then
      raise exception 'session_tool_must_be_single_line' using errcode = '22023';
    end if;
    if length(v_session_tool) > 80 then
      raise exception 'session_tool_too_long' using errcode = '22023';
    end if;
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
    session_tool = v_session_tool,
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

revoke execute on function public.update_session_post(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  text,
  text,
  text,
  text,
  text
) from public;

revoke execute on function public.update_session_post(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  text,
  text,
  text,
  text,
  text
) from anon;

grant execute on function public.update_session_post(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  integer,
  integer,
  text,
  text,
  text,
  text,
  text
) to authenticated;

commit;

-- ============================================================
-- 4. Post-apply verification queries
-- ============================================================

select
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'sessions'
  and column_name = 'session_tool';

select
  p.oid::regprocedure::text as signature,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer,
  coalesce(array_to_string(p.proconfig, ','), '') ilike '%search_path%' as has_search_path
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('create_session_post', 'update_session_post', 'delete_session_post')
order by p.proname, p.oid::regprocedure::text;

with expected(routine_name, grantee, expected_execute) as (
  values
    ('create_session_post', 'authenticated', true),
    ('create_session_post', 'anon', false),
    ('create_session_post', 'PUBLIC', false),
    ('update_session_post', 'authenticated', true),
    ('update_session_post', 'anon', false),
    ('update_session_post', 'PUBLIC', false),
    ('delete_session_post', 'authenticated', true),
    ('delete_session_post', 'anon', false),
    ('delete_session_post', 'PUBLIC', false)
),
actual as (
  select
    routine_name,
    grantee,
    bool_or(privilege_type = 'EXECUTE') as has_execute
  from information_schema.routine_privileges
  where routine_schema = 'public'
    and routine_name in ('create_session_post', 'update_session_post', 'delete_session_post')
  group by routine_name, grantee
)
select
  expected.routine_name,
  case
    when expected.grantee = 'PUBLIC' then 'public'
    else expected.grantee
  end as grantee,
  expected.expected_execute,
  coalesce(actual.has_execute, false) as actual_execute,
  coalesce(actual.has_execute, false) = expected.expected_execute as ok
from expected
left join actual
  on actual.routine_name = expected.routine_name
 and actual.grantee = expected.grantee
order by expected.routine_name, expected.grantee;

select
  c.relrowsecurity as sessions_rls_enabled,
  c.relforcerowsecurity as sessions_force_rls
from pg_class c
join pg_namespace n
  on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = 'sessions';

-- ============================================================
-- 5. Rollback notes for review
-- ============================================================

-- Do not casually drop public.sessions.session_tool after data is written.
-- Dropping the column would destroy saved session tool values.
-- If an error occurs before commit, stop and review instead of re-running blindly.
-- If this apply fails before use, prefer restoring RPC definitions from the
-- previous reviewed files and review data impact separately.
