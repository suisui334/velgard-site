-- 016_session_posting_end_at_draft.sql
-- M-14D-3 依頼書投稿フォーム 日跨ぎ終了日時正式対応 SQL/RPC差分草案
--
-- M-14D-4 apply result:
-- - ユーザーがSupabase SQL Editorでapply sectionを実行し、Success. No rows returnedで通過済み。
-- - public.sessions.end_at timestamptz が追加済み。
-- - create_session_post はp_end_at対応版に差し替え済みで、関数は1本だけ。
-- - 通常運用では同じapply sectionをそのまま再実行しない。
--
-- 目的:
-- - 015_session_posting_rpc_draft.sql は適用済みのため、同じapply sectionは再実行しない。
-- - 日跨ぎ終了日時を保存できるよう public.sessions.end_at timestamptz を追加する。
-- - create_session_post RPCへ末尾引数 p_end_at text default null を追加する。
-- - PostgreSQLでは引数追加が別signatureになるため、旧signatureを明示dropしてから新signatureを作る。
-- - Discord credential、service role key、Webhook URL、token類はこのSQLに書かない。
-- - RPC戻り値は session_id / discord_sync_status / created_at のまま維持する。
--
-- 実行前注意:
-- - このファイルのapply sectionは適用済み。SQL Editorで通常再実行しない。
-- - 実DB適用前にpreflight結果、既存関数定義、既存grant、PostgREST RPC挙動を確認する。
-- - p_end_at対応後は、フロント側の日跨ぎ終了日時バリデーションを解除してよい。

-- ============================================================
-- 0. Preflight checks
-- ============================================================

-- 015で追加済みの主要列と、今回追加予定のend_atを確認する。
select
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'sessions'
  and column_name in (
    'id',
    'date',
    'start_time',
    'end_time',
    'end_at',
    'session_type',
    'application_deadline',
    'discord_sync_status'
  )
order by ordinal_position;

-- 既存create_session_postの引数・戻り値確認。
select
  p.oid::regprocedure as signature,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'create_session_post'
order by p.oid::regprocedure::text;

-- 実行前はcreate_session_postが1本だけ存在し、p_end_atなしの旧signatureであることを確認する。
select
  count(*) as create_session_post_function_count
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'create_session_post';

-- 停止条件:
-- - public.sessions が存在しない。
-- - 015の追加列や create_session_post が未適用。
-- - 実行前の create_session_post が1本ではない。
-- - create_session_post に p_end_at 付きsignatureが既に存在する。
-- - sessions.date / start_time / end_time の型が想定と異なる。
-- - end_at という別目的の列が既に存在する。
-- - 既存フロントが旧RPC署名を前提にしていて、同時更新できない。

-- ============================================================
-- 1. public.sessions.end_at draft
-- ============================================================

alter table public.sessions
  add column if not exists end_at timestamptz;

create index if not exists sessions_end_at_idx
  on public.sessions(end_at);

comment on column public.sessions.end_at is
  'Session end datetime for cross-day session posts. Stored as timestamptz; form datetime-local values are interpreted as Asia/Tokyo by create_session_post.';

-- CHECK制約は初期案では追加しない。
-- 理由:
-- - start_at相当は date + start_time から組み立てる必要があり、time null / 24:00互換 / timezone解釈が絡む。
-- - create_session_post RPC内で p_end_at >= start_at 相当を検証する方がエラー制御しやすい。

-- ============================================================
-- 2. create_session_post RPC replacement draft
-- ============================================================

-- PostgREST RPCのoverload曖昧化を避けるため、旧signatureを明示dropしてから
-- 末尾に p_end_at text default null を追加した新signatureを作る。
-- 既存引数順は維持し、p_end_atだけ末尾に追加する。
-- revoke / grant / comment は、新signature作成後に新signatureへだけ行う。

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
  p_end_at text default null
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

    -- 互換表示用のend_timeはp_end_atの時刻を優先して保存する。
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
  text,
  text
) is 'GM/admin用セッション依頼書投稿RPC。p_end_atをAsia/Tokyoの終了日時として保存する。戻り値に内部ID、email、Discord credential類を含めない。';

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
  text,
  text
) to authenticated;

-- ============================================================
-- 3. Post-apply checks
-- ============================================================

select
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'sessions'
  and column_name = 'end_at';

select
  p.oid::regprocedure as signature,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'create_session_post'
order by p.oid::regprocedure::text;

select
  count(*) as create_session_post_function_count
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'create_session_post';

select
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name = 'create_session_post'
order by grantee, privilege_type;

-- 期待:
-- - public.sessions.end_at が timestamptz。
-- - create_session_post_function_count が1。
-- - create_session_post は p_end_at text default null を末尾に持つ。
-- - p_end_atなしの旧signatureは残っていない。
-- - 戻り値は session_id / discord_sync_status / created_at のみ。
-- - authenticated に EXECUTE がある。
-- - anon には EXECUTE がない。
-- - Discord credential、service_role key、Webhook URL、token類は保存されていない。

-- ============================================================
-- 4. Frontend/display follow-up notes
-- ============================================================

-- SQL適用後のフロント方針:
-- - 投稿フォームは開始日時/終了日時 datetime-local を維持する。
-- - 開始日時から p_session_date / p_start_time を送る。
-- - 終了日時から p_end_at を送る。
-- - 互換表示用として p_end_time も終了日時の時刻部分を送ってよい。
-- - SQL/RPC適用後は、現在の「日跨ぎ終了日時を投稿前に止める」暫定バリデーションを解除する。
--
-- 表示方針:
-- - Supabase sessions読み込みでは end_at を取得し、endAt / endTime相当へ正規化する。
-- - sessionDisplay.jsは end_at / endAt があれば終了日時として優先表示する。
-- - end_at がなければ従来どおり date + end_time / endTime を使う。
-- - Discord本文生成も end_at を優先し、日跨ぎ終了日時を正しく表示する。

-- ============================================================
-- 5. Rollback draft
-- ============================================================

-- rollbackが必要な場合の草案。適用前に必ず実データ影響を確認すること。
-- 新signatureをdropし、必要なら015時点の旧signatureをレビュー済み定義から復元する。
-- 旧signatureと新signatureを同時に残さないこと。
--
-- revoke all on function public.create_session_post(
--   text, text, text, text, text, text, text, integer, integer, text, text, text, text, text, text
-- ) from public;
-- drop function if exists public.create_session_post(
--   text, text, text, text, text, text, text, integer, integer, text, text, text, text, text, text
-- );
--
-- -- 必要なら015時点のcreate_session_postを再作成する。015 apply sectionをそのまま通常再実行せず、
-- -- 関数定義部分だけを実DB状態に合わせてレビューしてから戻すこと。
--
-- drop index if exists public.sessions_end_at_idx;
-- alter table public.sessions drop column if exists end_at;
