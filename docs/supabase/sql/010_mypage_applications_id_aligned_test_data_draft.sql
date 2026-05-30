-- ============================================================
-- Velgard Supabase M-10 follow-up
-- 010_mypage_applications_id_aligned_test_data_draft.sql
--
-- DRAFT ONLY:
-- - M-10 ID整合検証で使用済み。同じSQLを再実行しない。
-- - 再確認が必要な場合も、必ず対象データの有無とcountを先に確認する。
-- - cleanupは未実行。検証データを残すか削除するかは別工程で判断する。
-- - SQL Editorで実行する前に必ずレビューする。
-- - このファイルには実email、実user_id、secret、DB passwordを書かない。
-- - service_role key / secret key / Direct connection string は使わない。
-- - 初期状態ではROLLBACKで終わる。検証データを実際に作る場合のみCOMMITへ変更する。
-- ============================================================

-- ------------------------------------------------------------
-- 0. 実行前停止条件
-- ------------------------------------------------------------
-- 以下に該当する場合は実行しない。
-- - <TEST_PLAYER_A_PROFILE_ID> をテストプレイヤーAの profiles.id UUIDへ置換していない。
-- - 対象profileが public.profiles に存在することを確認していない。
-- - 実行先Supabaseプロジェクトが想定プロジェクトか確認していない。
-- - 対象session idが既にDBにあり、公開JSONと異なる内容になっている。
-- - 対象ユーザーに同一sessionの申請が既にあり、既存状態の扱いを決めていない。
-- - service_role / secret / DB password / Direct connection string が必要になった。

begin;

-- ------------------------------------------------------------
-- 1. パラメータ
-- ------------------------------------------------------------
-- TODO:
-- - <TEST_PLAYER_A_PROFILE_ID> を実行直前に置換する。
-- - 実emailはこのSQLに書かない。
create temporary table m10_id_aligned_test_params (
  target_session_id text not null,
  target_player_id uuid not null,
  target_status text not null,
  target_comment_body text not null
) on commit drop;

insert into m10_id_aligned_test_params (
  target_session_id,
  target_player_id,
  target_status,
  target_comment_body
)
values (
  'session-2026-06-08-railway-incident',
  '<TEST_PLAYER_A_PROFILE_ID>'::uuid,
  'pending',
  'M-10 ID aligned mypage link verification comment.'
);

-- ------------------------------------------------------------
-- 2. 事前確認SELECT
-- ------------------------------------------------------------
-- 対象profileが1件返ること。display_nameのみ確認し、email / user_id全文は出さない。
select
  'profile_check' as check_name,
  p.display_name
from public.profiles as p
join m10_id_aligned_test_params as params
  on params.target_player_id = p.id;

-- 対象sessionの既存状態を確認する。
-- 0件なら、この草案で公開JSONに合わせたsessionを追加する。
-- 1件ある場合は、title/date/status/visibility等が公開JSONと矛盾しないことを確認する。
select
  'existing_session_check' as check_name,
  s.id,
  s.title,
  s.date,
  s.start_time,
  s.end_time,
  s.gm_name,
  s.status,
  s.visibility
from public.sessions as s
join m10_id_aligned_test_params as params
  on params.target_session_id = s.id;

-- 対象ユーザーの既存申請を確認する。
-- 既存行があり、statusが pending / waitlisted / accepted 以外なら実行を止める。
select
  'existing_application_check' as check_name,
  sa.session_id,
  sa.status,
  sa.created_at,
  sa.updated_at,
  sa.canceled_at
from public.session_applications as sa
join m10_id_aligned_test_params as params
  on params.target_session_id = sa.session_id
 and params.target_player_id = sa.user_id;

-- ------------------------------------------------------------
-- 2.5. 停止条件の機械チェック
-- ------------------------------------------------------------
-- ここで止まった場合は、後続のINSERTへ進まない。
-- エラーメッセージにはemail / user_id全文 / secret類を含めない。
do $$
begin
  if not exists (
    select 1
    from public.profiles as p
    join m10_id_aligned_test_params as params
      on params.target_player_id = p.id
  ) then
    raise exception 'M10 stop: target profile was not found.';
  end if;

  if exists (
    select 1
    from m10_id_aligned_test_params as params
    where params.target_status not in ('pending', 'accepted', 'waitlisted')
  ) then
    raise exception 'M10 stop: target status is not suitable for mypage visible test.';
  end if;

  if exists (
    select 1
    from public.sessions as s
    join m10_id_aligned_test_params as params
      on params.target_session_id = s.id
    where s.title <> '灰壁線異常調査'
       or s.date <> '2026-06-08'::date
       or s.start_time is distinct from '21:00'::time
       or s.end_time is distinct from '24:00'::time
       or s.gm_name is distinct from 'GMサンプルA'
       or s.status <> 'recruiting'
       or s.visibility <> 'public'
  ) then
    raise exception 'M10 stop: existing session does not match public JSON fields.';
  end if;

  if exists (
    select 1
    from public.session_applications as sa
    join m10_id_aligned_test_params as params
      on params.target_session_id = sa.session_id
     and params.target_player_id = sa.user_id
    where sa.status not in ('pending', 'waitlisted', 'accepted')
  ) then
    raise exception 'M10 stop: existing application status is not visible in M-10 mypage.';
  end if;
end
$$;

-- ------------------------------------------------------------
-- 3. 公開JSONとIDが一致する public.sessions 行を用意する
-- ------------------------------------------------------------
-- data/sessions.json の sessions[].id と一致させる。
-- gm_user_id はこの検証では不要なため null のままにする。
insert into public.sessions (
  id,
  title,
  date,
  start_time,
  end_time,
  gm_user_id,
  gm_name,
  status,
  level_range,
  player_min,
  player_max,
  summary,
  detail,
  requirements,
  visibility
)
select
  params.target_session_id,
  '灰壁線異常調査',
  '2026-06-08'::date,
  '21:00'::time,
  '24:00'::time,
  null,
  'GMサンプルA',
  'recruiting',
  '3Lv',
  3,
  5,
  '灰壁線沿線の異常を調査する短編セッション。',
  'M-10 ID整合検証用に、公開JSONと同じIDで作成するDB側検証セッション。',
  null,
  'public'
from m10_id_aligned_test_params as params
where not exists (
  select 1
  from public.sessions as existing
  where existing.id = params.target_session_id
);

-- ------------------------------------------------------------
-- 4. コメントと申請をセットで用意する
-- ------------------------------------------------------------
-- M-10画面はコメント本文を表示しないが、正本方針に合わせて
-- session_comments と session_applications を紐づける。
with inserted_comment as (
  insert into public.session_comments (
    session_id,
    user_id,
    body,
    is_application
  )
  select
    params.target_session_id,
    params.target_player_id,
    params.target_comment_body,
    true
  from m10_id_aligned_test_params as params
  where not exists (
    select 1
    from public.session_applications as existing
    where existing.session_id = params.target_session_id
      and existing.user_id = params.target_player_id
  )
  returning id, session_id, user_id
)
insert into public.session_applications (
  session_id,
  user_id,
  comment_id,
  status,
  canceled_at
)
select
  inserted_comment.session_id,
  inserted_comment.user_id,
  inserted_comment.id,
  params.target_status,
  null
from inserted_comment
join m10_id_aligned_test_params as params
  on params.target_session_id = inserted_comment.session_id
 and params.target_player_id = inserted_comment.user_id
on conflict (session_id, user_id) do nothing;

-- ------------------------------------------------------------
-- 5. 実行後確認SELECT
-- ------------------------------------------------------------
-- sessionが public / recruiting で存在すること。
select
  'created_session_check' as check_name,
  s.id,
  s.title,
  s.date,
  s.start_time,
  s.gm_name,
  s.status,
  s.visibility
from public.sessions as s
join m10_id_aligned_test_params as params
  on params.target_session_id = s.id;

-- M-10 mypageが読む列だけを確認する。
-- user_id / email / token / key は出さない。
select
  'mypage_columns_check' as check_name,
  sa.session_id,
  sa.status,
  sa.comment_id,
  sa.created_at,
  sa.updated_at,
  sa.canceled_at
from public.session_applications as sa
join m10_id_aligned_test_params as params
  on params.target_session_id = sa.session_id
 and params.target_player_id = sa.user_id;

-- ------------------------------------------------------------
-- 6. 初期状態ではロールバック
-- ------------------------------------------------------------
-- 草案確認時にデータを残さないため、初期状態ではROLLBACKする。
-- 実際に検証データを作る段階で、上記SELECT結果を確認したうえで
-- 下の ROLLBACK を COMMIT に変更する。
rollback;

-- ------------------------------------------------------------
-- 7. 検証後cleanup草案
-- ------------------------------------------------------------
-- M-10の詳細リンク表示・遷移確認が終わった後、必要なら別途レビューして実行する。
-- 初期状態ではコメントアウトしたままにする。
--
-- begin;
--
-- create temporary table m10_id_aligned_test_params (
--   target_session_id text not null,
--   target_player_id uuid not null
-- ) on commit drop;
--
-- insert into m10_id_aligned_test_params (
--   target_session_id,
--   target_player_id
-- )
-- values (
--   'session-2026-06-08-railway-incident',
--   '<TEST_PLAYER_A_PROFILE_ID>'::uuid
-- );
--
-- delete from public.session_applications as sa
-- using m10_id_aligned_test_params as params
-- where sa.session_id = params.target_session_id
--   and sa.user_id = params.target_player_id;
--
-- delete from public.session_comments as c
-- using m10_id_aligned_test_params as params
-- where c.session_id = params.target_session_id
--   and c.user_id = params.target_player_id
--   and c.body = 'M-10 ID aligned mypage link verification comment.';
--
-- -- public.sessions行は、DB側の公開セッション整合seedとして残す選択肢がある。
-- -- 完全に不要になった場合だけ、関連行がないことを確認してから削除する。
-- -- delete from public.sessions as s
-- -- using m10_id_aligned_test_params as params
-- -- where s.id = params.target_session_id
-- --   and not exists (
-- --     select 1 from public.session_applications sa where sa.session_id = s.id
-- --   )
-- --   and not exists (
-- --     select 1 from public.session_comments c where c.session_id = s.id
-- --   );
--
-- rollback;
