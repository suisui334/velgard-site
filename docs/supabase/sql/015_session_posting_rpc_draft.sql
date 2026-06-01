-- 015_session_posting_rpc_draft.sql
-- M-14B 依頼書投稿用DB/RPC草案
--
-- 目的:
-- - 既存 public.sessions を依頼書投稿の正本として拡張する。
-- - GM/adminだけが create_session_post RPC で投稿できるようにする。
-- - Discord同期状態をDB側に残し、Edge Functionが作成・編集・削除/非公開・再同期を扱える余地を作る。
--
-- 重要:
-- - M-14Cでapply sectionはユーザーがSQL Editorで適用済み。
-- - 通常運用では同じapply sectionをそのまま再実行しない。
-- - 追加修正が必要な場合は差分SQLとして別工程でレビューする。
-- - Discord投稿credential、サーバー側credential類はこのSQLに書かない。
-- - RPC戻り値に email、内部user id、Discord credential類を含めない。
--
-- M-14C preflight follow-up:
-- - public.sessions だけでなくpublic schema内の複数テーブルで、anon / authenticated に
--   TRUNCATE 権限が見えていた。
-- - ユーザーがTRUNCATEだけをrevokeし、確認クエリで0件になったことを確認済み。
-- - SELECT / INSERT / UPDATE / DELETE 権限は今回触っていない。
-- - postgresなどの管理者系ロール側の権限は対象外。
--
-- M-14C apply result:
-- - ユーザーがapply sectionを実行し、Success. No rows returned で通過済み。
-- - public.sessionsの追加列、check制約、create_session_post RPC、grantを確認済み。
-- - create_session_post の実行テスト、Edge Function deploy、Discord実送信は未実施。
-- - 適用結果は docs/session-posting-rpc-apply-result.md に記録済み。

-- ============================================================
-- 0. Preflight checks
-- ============================================================

-- helper functionが存在すること。
select
  to_regprocedure('public.has_role(text)') as has_role_fn,
  to_regprocedure('public.is_admin()') as is_admin_fn,
  to_regprocedure('public.is_session_gm(text)') as is_session_gm_fn;

-- 既存 public.sessions の主要列確認。
select
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'sessions'
  and column_name in (
    'id',
    'title',
    'date',
    'start_time',
    'end_time',
    'gm_user_id',
    'gm_name',
    'status',
    'level_range',
    'player_min',
    'player_max',
    'summary',
    'detail',
    'requirements',
    'visibility',
    'created_at',
    'updated_at'
  )
order by ordinal_position;

-- 停止条件:
-- - helper functionが存在しない。
-- - public.sessions が存在しない。
-- - 既存列の型が想定と違う。
-- - 既存データに session_type / discord_sync_status の制約候補へ反する値がある。
-- - admin代理投稿で任意GMを指定する要件がある。初期案では gm_user_id は auth.uid() 固定。
-- - draftをpublicで保存したい要件がある。初期案ではdraftの公開保存を拒否する。
-- - 非公開/下書き保存もDiscordへ即時同期したい要件がある。初期案では同期対象外にする。

-- ============================================================
-- 1. public.sessions extension draft
-- ============================================================

alter table public.sessions
  add column if not exists session_type text not null default 'one-shot',
  add column if not exists application_deadline timestamptz,
  add column if not exists discord_sync_status text not null default 'not_requested',
  add column if not exists discord_last_action text,
  add column if not exists discord_message_id text,
  add column if not exists discord_channel_id text,
  add column if not exists discord_thread_id text,
  add column if not exists discord_sync_requested_at timestamptz,
  add column if not exists discord_synced_at timestamptz,
  add column if not exists discord_sync_error text,
  add column if not exists discord_post_url text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'sessions_session_type_check'
      and conrelid = 'public.sessions'::regclass
  ) then
    alter table public.sessions
      add constraint sessions_session_type_check
      check (session_type in ('one-shot', 'campaign', 'special', 'other'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'sessions_discord_sync_status_check'
      and conrelid = 'public.sessions'::regclass
  ) then
    alter table public.sessions
      add constraint sessions_discord_sync_status_check
      check (discord_sync_status in ('not_requested', 'pending', 'posted', 'failed', 'skipped'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'sessions_discord_last_action_check'
      and conrelid = 'public.sessions'::regclass
  ) then
    alter table public.sessions
      add constraint sessions_discord_last_action_check
      check (
        discord_last_action is null
        or discord_last_action in ('create', 'update', 'delete', 'close', 'resync')
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'sessions_discord_sync_error_length_check'
      and conrelid = 'public.sessions'::regclass
  ) then
    alter table public.sessions
      add constraint sessions_discord_sync_error_length_check
      check (discord_sync_error is null or length(discord_sync_error) <= 1000);
  end if;
end $$;

create index if not exists sessions_session_type_idx
  on public.sessions(session_type);

create index if not exists sessions_application_deadline_idx
  on public.sessions(application_deadline);

create index if not exists sessions_discord_sync_status_idx
  on public.sessions(discord_sync_status);

create index if not exists sessions_discord_message_id_idx
  on public.sessions(discord_message_id);

-- ============================================================
-- 2. create_session_post RPC draft
-- ============================================================

create or replace function public.create_session_post(
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
  p_status text default 'recruiting'
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
  v_gm_name text;
  v_session_id text;
  v_created_at timestamptz;
  v_discord_sync_status text;
  v_discord_last_action text;
  v_start_text text;
  v_end_text text;
  v_deadline_text text;
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
    gm_user_id,
    gm_name,
    status,
    session_type,
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
    v_actor,
    v_gm_name,
    v_status,
    v_session_type,
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

comment on function public.create_session_post(
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
) is 'GM/admin用セッション依頼書投稿RPC草案。戻り値に内部ID、email、Discord credential類を含めない。';

-- Functions are not protected by RLS. Keep execution grants explicit.
revoke all on function public.create_session_post(
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
  text
) to authenticated;

-- ============================================================
-- 3. Post-apply checks
-- ============================================================

-- 追加列確認。
select
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'sessions'
  and column_name in (
    'session_type',
    'application_deadline',
    'discord_sync_status',
    'discord_last_action',
    'discord_message_id',
    'discord_channel_id',
    'discord_thread_id',
    'discord_sync_requested_at',
    'discord_synced_at',
    'discord_sync_error',
    'discord_post_url'
  )
order by ordinal_position;

-- RPCの戻り値確認。実行はしない。
select
  p.proname,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'create_session_post';

-- grant確認。
select
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name = 'create_session_post'
order by grantee, privilege_type;

-- 期待:
-- - authenticated に EXECUTE がある。
-- - anon には EXECUTE がない。
-- - 戻り値は session_id / discord_sync_status / created_at のみ。

-- Edge Functionによる同期メタデータ更新の想定:
-- - create対象: visibility='public' かつ status in ('tentative', 'recruiting') のみ。
-- - draft / private / hidden は discord_sync_status='skipped' とし、Discordへ即時同期しない。
-- - create成功: discord_sync_status='posted', discord_last_action='create',
--   discord_message_id / discord_channel_id / discord_thread_id / discord_post_url / discord_synced_at を保存。
-- - update成功: 既存Discord投稿を編集または更新通知投稿し、discord_last_action='update' を保存。
-- - close/delete成功: 物理削除より、Discord投稿を「募集終了/削除済み」に編集する案を優先し、
--   discord_last_action='close' または 'delete' を保存。
-- - resync成功: discord_last_action='resync' を保存。
-- - 失敗: DB保存は残し、discord_sync_status='failed' と discord_sync_error を保存。

-- ============================================================
-- 4. Rollback draft
-- ============================================================

-- rollbackが必要な場合の草案。適用前に必ず実データ影響を確認すること。
--
-- revoke all on function public.create_session_post(
--   text, text, text, text, text, text, text, integer, integer, text, text, text, text, text
-- ) from public;
-- drop function if exists public.create_session_post(
--   text, text, text, text, text, text, text, integer, integer, text, text, text, text, text
-- );
--
-- drop index if exists public.sessions_session_type_idx;
-- drop index if exists public.sessions_application_deadline_idx;
-- drop index if exists public.sessions_discord_sync_status_idx;
-- drop index if exists public.sessions_discord_message_id_idx;
--
-- alter table public.sessions drop constraint if exists sessions_discord_sync_error_length_check;
-- alter table public.sessions drop constraint if exists sessions_discord_last_action_check;
-- alter table public.sessions drop constraint if exists sessions_discord_sync_status_check;
-- alter table public.sessions drop constraint if exists sessions_session_type_check;
--
-- alter table public.sessions
--   drop column if exists discord_post_url,
--   drop column if exists discord_sync_error,
--   drop column if exists discord_synced_at,
--   drop column if exists discord_sync_requested_at,
--   drop column if exists discord_thread_id,
--   drop column if exists discord_channel_id,
--   drop column if exists discord_message_id,
--   drop column if exists discord_last_action,
--   drop column if exists discord_sync_status,
--   drop column if exists application_deadline,
--   drop column if exists session_type;
