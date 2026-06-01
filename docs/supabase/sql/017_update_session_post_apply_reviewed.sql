-- 017_update_session_post_apply_reviewed.sql
-- M-14D-8f reviewed APPLY-only SQL for update_session_post.
-- Paste this entire file into Supabase SQL Editor only after review.
-- Do not paste the full draft file.
-- This file intentionally excludes preflight queries and rollback drafts.

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

comment on function public.update_session_post(
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
) is 'Reviewed session posting update RPC. Returns only session_id, discord_sync_status, discord_last_action, and updated_at.';

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
  text
) to authenticated;

-- Post-apply verification. These queries do not change data.

select
  count(*) as function_count,
  bool_and(p.prosecdef) as all_security_definer,
  array_agg(p.oid::regprocedure::text order by p.oid::regprocedure::text) as signatures
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'update_session_post';

with expected(grantee, expected_execute) as (
  values
    ('authenticated', true),
    ('anon', false),
    ('PUBLIC', false)
),
actual as (
  select
    grantee,
    bool_or(privilege_type = 'EXECUTE') as has_execute
  from information_schema.routine_privileges
  where routine_schema = 'public'
    and routine_name = 'update_session_post'
  group by grantee
)
select
  case
    when expected.grantee = 'PUBLIC' then 'public'
    else expected.grantee
  end as grantee,
  expected.expected_execute,
  coalesce(actual.has_execute, false) as actual_execute,
  coalesce(actual.has_execute, false) = expected.expected_execute as ok
from expected
left join actual
  on actual.grantee = expected.grantee
order by expected.grantee;
