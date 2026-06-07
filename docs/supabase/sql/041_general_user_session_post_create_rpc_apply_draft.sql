-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
-- Purpose: replace create_session_post so logged-in authenticated users can create session posts.
-- This is an apply draft. Review 040 preflight result before using this file.
-- This chat does not execute this SQL.
--
-- Safety policy:
-- - Keep auth.uid() required.
-- - Remove only the create-time GM/admin role gate.
-- - The creator remains the owner/GM for the new session via gm_user_id = auth.uid().
-- - Do not change update_session_post or delete_session_post.
-- - Existing update/delete/close/manual-close controls remain owner-GM/admin scoped in frontend/RPC flows.
-- - Keep initial create status limited to draft / tentative / recruiting.
-- - Do not allow closed / finished / canceled as initial create statuses.
-- - Keep public draft rejection.
-- - Keep session_tool and Discord sync metadata behavior.
-- - Keep anon and PUBLIC execution revoked; grant authenticated only.
--
-- Stop before apply if:
-- - 040 preflight result does not match the expected function signature.
-- - authenticated EXECUTE is not expected.
-- - anon EXECUTE is unexpectedly required.
-- - live create_session_post body differs from the reviewed draft in an unsafe way.
-- - any secret, token, URL, user ID, session ID, or Discord ID appears in the SQL.

begin;

-- Drop current and legacy candidate signatures to avoid PostgREST overload ambiguity.
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

  -- General authenticated users may create session posts.
  -- The creator is stored as gm_user_id and later edit/delete permissions remain owner/admin scoped.

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

commit;

-- Post-apply SELECT-only checks to run in the next result-recording gate:
-- - create_session_post exists exactly once.
-- - security_definer = true.
-- - search_path is set.
-- - authenticated has EXECUTE.
-- - anon does not have EXECUTE.
-- - function body no longer contains gm_or_admin_required.
-- - function body still contains invalid_initial_status and draft/tentative/recruiting guard.
