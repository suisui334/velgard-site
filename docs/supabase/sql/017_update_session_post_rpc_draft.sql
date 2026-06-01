-- 017_update_session_post_rpc_draft.sql
-- M-14D-8 下書き依頼書編集保存 update_session_post RPC草案
--
-- DRAFT ONLY:
-- - SQL Editorではまだ実行しない。
-- - DB構造変更、RPC作成/置換、Edge Function deploy、Discord実送信は行わない。
-- - External credential values or connection values must not be written here.
-- - RPC戻り値に email、user_id全文、gm_user_id、Discord credential類を含めない。
--
-- 設計上の重要差分:
-- - 引き継ぎ時の想定引数案では p_session_id uuid だったが、既存 public.sessions.id は text。
-- - 既存 helper public.is_session_gm(target_session_id text) も text 前提。
-- - そのため、この草案では p_session_id text を採用する。
-- - p_min_players / p_max_players 案は、既存 create_session_post に合わせて
--   p_player_min / p_player_max とする。
--
-- M-14D-8c note:
-- - Do not copy this file by fixed line numbers.
-- - SQL Editor preflight must use the dedicated select-only file instead:
--   docs/supabase/sql/017_update_session_post_preflight_select_only.sql
-- - Review this draft file only after the dedicated preflight result is checked.

-- ============================================================
-- SECTION 1: PREFLIGHT ONLY
-- REFERENCE ONLY. DO NOT COPY BY LINE NUMBER.
-- ============================================================

-- SQL Editorでのpreflightは、この本体ファイルから行番号で抜き出さない。
-- 専用ファイル docs/supabase/sql/017_update_session_post_preflight_select_only.sql
-- の全文を貼る。
-- このSECTION 1は本体草案内の参照用コピーとして残す。

-- role確認。
select
  to_regrole('anon') as anon_role,
  to_regrole('authenticated') as authenticated_role;

-- helper functionが存在すること。
select
  to_regprocedure('public.has_role(text)') as has_role_fn,
  to_regprocedure('public.is_admin()') as is_admin_fn,
  to_regprocedure('public.is_session_gm(text)') as is_session_gm_fn;

-- helper functionの定義属性確認。
select
  p.oid::regprocedure as signature,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer,
  p.provolatile as volatility
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('has_role', 'is_admin', 'is_session_gm')
order by p.proname, p.oid::regprocedure::text;

-- 既存 public.sessions の列一覧確認。
select
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'sessions'
order by ordinal_position;

-- 既存 public.sessions の主要列確認。
select
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'sessions'
  and column_name in (
    'id',
    'title',
    'date',
    'start_time',
    'end_time',
    'end_at',
    'gm_user_id',
    'gm_name',
    'status',
    'session_type',
    'application_deadline',
    'player_min',
    'player_max',
    'summary',
    'visibility',
    'updated_at',
    'discord_sync_status',
    'discord_last_action',
    'discord_message_id',
    'discord_sync_requested_at',
    'discord_synced_at',
    'discord_sync_error'
  )
order by ordinal_position;

-- 既存制約確認。
select
  conname,
  pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid = to_regclass('public.sessions')
  and conname in (
    'sessions_session_type_check',
    'sessions_discord_sync_status_check',
    'sessions_discord_last_action_check',
    'sessions_discord_sync_error_length_check'
  )
order by conname;

-- 既存RPC名衝突確認。
select
  p.oid::regprocedure as signature,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'update_session_post'
order by p.oid::regprocedure::text;

-- create_session_postの現在signature確認。
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

-- 関連RPC/helperの既存grant確認。
select
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name in (
    'has_role',
    'is_admin',
    'is_session_gm',
    'create_session_post',
    'update_session_post'
  )
  and grantee in ('anon', 'authenticated')
order by routine_name, grantee, privilege_type;

-- 停止条件:
-- - public.sessions が存在しない。
-- - public.sessions.id が text ではない。
-- - helper function public.has_role(text), public.is_admin(), public.is_session_gm(text) がない。
-- - end_at / updated_at / discord_sync_* 列の有無や型が想定と違う。
-- - update_session_post が既に存在し、signatureや戻り値の互換性が未確認。
-- - create_session_post の引数思想と大きく乖離している。
-- - visibility / status の既存制約や運用値がこの草案と衝突する。
-- - public/draft保存を許可したい、または公開切替を別RPCに分離したい方針が確定した。
-- - Discord投稿更新方式が、pendingメタデータ方式ではなくEdge Function即時呼び出し方式に変わった。

-- ============================================================
-- END SECTION 1: PREFLIGHT ONLY
-- ============================================================

-- ============================================================
-- SECTION 2: APPLY
-- DO NOT RUN UNTIL PREFLIGHT RESULT IS REVIEWED.
-- THIS SECTION CREATES/REPLACES RPC AND CHANGES GRANTS.
-- ============================================================

-- ============================================================
-- 2-1. update_session_post RPC draft
-- ============================================================

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

    -- 互換表示用のend_timeはp_end_atの時刻を優先して保存する。
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

  -- Discord同期メタデータ方針:
  -- - 公開かつ活動中: message_idがあればupdate、なければcreateをpending化。
  -- - 公開かつ終了系: 既存message_idがあればcloseをpending化。なければskipped。
  -- - 非公開/下書き/中止: 既存message_idがあればdelete相当をpending化。なければskipped。
  -- - Edge Function実送信はこのRPCでは行わず、pendingメタデータだけを残す。
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
) is 'GM/admin用セッション依頼書更新RPC草案。p_session_idはpublic.sessions.idに合わせてtext。戻り値に内部user id、email、Discord credential類を含めない。';

-- Functions are not protected by RLS. Keep execution grants explicit.
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

-- ============================================================
-- SECTION 3: POST-APPLY CHECKS
-- RUN ONLY AFTER SECTION 2 HAS BEEN REVIEWED AND APPLIED.
-- ============================================================

-- RPCの戻り値確認。実行はしない。
select
  p.oid::regprocedure as signature,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'update_session_post'
order by p.oid::regprocedure::text;

-- grant確認。
select
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name = 'update_session_post'
order by grantee, privilege_type;

-- 期待:
-- - update_session_post が1本だけ存在する。
-- - p_session_id は text。
-- - security_definer = true。
-- - authenticated に EXECUTE がある。
-- - anon には EXECUTE がない。
-- - 戻り値は session_id / discord_sync_status / discord_last_action / updated_at のみ。
-- - email、user_id全文、gm_user_id、Discord credential類を返さない。

-- ============================================================
-- 3. Smoke test観点メモ
-- ============================================================

-- 実行テストはこのファイルでは行わない。
-- 後続工程で、専用fixtureまたは破壊的テスト条件付きで以下を確認する。
-- - anon拒否。
-- - 通常PL拒否。
-- - 他GM拒否。
-- - 対象GM成功。
-- - admin成功。
-- - invalid status拒否。
-- - invalid visibility拒否。
-- - min > max拒否。
-- - end_at <= start_at拒否。
-- - raw id / email / internal credential values do not appear in results or errors.
-- - hidden/draft更新後もpublic calendarに出ない。
-- - public/recruiting更新時にdiscord_sync_statusがpending化し、message_id有無でcreate/updateが分かれる。

-- ============================================================
-- 4. Rollback draft
-- ============================================================

-- rollbackが必要な場合の草案。適用前に必ず実データ影響を確認すること。
--
-- revoke execute on function public.update_session_post(
--   text, text, text, text, text, text, text, integer, integer, text, text, text, text
-- ) from public;
-- revoke execute on function public.update_session_post(
--   text, text, text, text, text, text, text, integer, integer, text, text, text, text
-- ) from anon;
-- drop function if exists public.update_session_post(
--   text, text, text, text, text, text, text, integer, integer, text, text, text, text
-- );
