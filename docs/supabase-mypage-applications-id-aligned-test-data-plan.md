# Supabase M-10 follow-up ID整合検証データ作成計画

作業日: 2026-05-31

## 1. 目的

M-10の `mypage.html` は、`session_applications.session_id` と公開JSON `data/sessions.json` の `sessions[].id` が完全一致した場合だけ、公開セッション情報と詳細リンクを表示する。

現DBテストデータは `rls-test-*` 系IDで、公開JSONの `session-2026-*` 系IDと一致しない。そのため、現在のテストプレイヤーAでは全件が「非公開または未同期のセッション」になる。

この計画では、公開JSONと同じIDを持つDB側検証データを作成する前に、対象セッション、必要データ、SQL草案、停止条件、確認項目を整理する。SQL Editorでの実行はこの工程では行わない。

## 2. 検証に使う公開セッション候補

候補:

```text
session-2026-06-08-railway-incident
```

公開JSON上の内容:

- タイトル: 灰壁線異常調査
- 開催日: 2026-06-08
- 開始時刻: 21:00
- 終了時刻: 24:00
- GM表示名: GMサンプルA
- 状態: recruiting
- visibility: public
- レベル帯: 3Lv
- 募集人数: 3-5名

選定理由:

- `visibility: "public"`。
- `status: "recruiting"` で募集状態に近い。
- `session-detail.html?id=session-2026-06-08-railway-incident` が既存詳細ページのID形式と一致する。
- IDが明確に `session-2026-*` 系。

## 3. DB側スキーマ確認

`docs/supabase/sql/001_core_schema_draft.sql` より、`public.sessions` の主要列は以下。

- 必須: `id`, `title`, `date`, `status`, `visibility`
- 任意: `start_time`, `end_time`, `gm_user_id`, `gm_name`, `level_range`, `player_min`, `player_max`, `summary`, `detail`, `requirements`

`session_applications.session_id` は `public.sessions(id)` を参照する。`session_applications` の主要列は以下。

- 必須: `session_id`, `user_id`, `status`
- 任意: `comment_id`, `canceled_at`
- `status` 許容値: `pending`, `accepted`, `rejected`, `waitlisted`, `canceled`
- `session_id + user_id` は一意。

`session_comments` の主要列は以下。

- 必須: `session_id`, `user_id`, `body`
- `is_application` は既定で `true`
- `comment_id` は `session_applications.comment_id` から参照できる。

## 4. session_comments が必要か

M-10のマイページ表示だけなら、`session_applications` に `pending` または `accepted` の本人行があれば表示確認はできる。

ただし、プロジェクト正本では「コメント投稿 = 参加申請の意思表示」であり、`create_application_comment` RPCも `session_comments` と `session_applications` をセットで扱う。そのため、検証データは `session_comments` を作成し、その `id` を `session_applications.comment_id` に入れる形を推奨する。

コメント本文はM-10画面には表示しない。本文には個人情報やsecret類を書かない。

## 5. user_id の扱い

`session_applications.user_id` と `session_comments.user_id` は `public.profiles(id)` を参照する。

SQL草案では実UUIDを書かず、以下のplaceholderを使う。

```text
<TEST_PLAYER_A_PROFILE_ID>
```

実行前に、Supabase上でテストプレイヤーAの `auth.users.id` / `profiles.id` と一致するUUIDに置換する。実emailはSQL草案やdocsに書かない。

## 6. RLS上の期待

`docs/supabase/sql/002_rls_grants_draft.sql` の `applications_select_own` により、ログイン中ユーザーは `user_id = auth.uid()` の `session_applications` を読める。

M-10では `session_applications` から本人行のみを読み、画面には `user_id` を出さない。公開JSONに突合できた場合のみ、公開セッション情報と詳細リンクを出す。

## 7. SQL草案

SQL草案:

```text
docs/supabase/sql/010_mypage_applications_id_aligned_test_data_draft.sql
```

草案の方針:

- SQL Editorでの実行前に停止条件を確認する。
- service_role、secret、DB password、実email、実user_idは書かない。
- 既存本番データを削除しない。
- `session-2026-06-08-railway-incident` をDB側 `public.sessions.id` に使う。
- `session_comments` と `session_applications` をセットで作る。
- 既定では `ROLLBACK` で終わる。実データを作る場合は、確認後に最後を `COMMIT` へ変更する。

## 8. 実行前停止条件

以下に該当する場合は実行しない。

- `<TEST_PLAYER_A_PROFILE_ID>` を実UUIDに置換していない。
- 対象profileが存在しない。
- 対象セッションIDが既にDBにあり、公開JSONと異なる内容になっている。
- 対象ユーザーに同一 `session_id` の `session_applications` が既にあり、状態が `pending` / `waitlisted` / `accepted` 以外。
- SQL Editorで実行するプロジェクトが想定のSupabaseプロジェクトか確認できない。
- service_role、secret、DB password、Direct connection string などを使う必要がある。

## 9. rollback / cleanup 方針

草案は初期状態では `ROLLBACK` にしているため、試読時にはデータを残さない。

実際に検証データを作る場合は、`COMMIT` に変更して実行する。M-10のGitHub Pages確認が終わるまでは、申請行とコメント行を残してよい。

検証完了後の cleanup は以下の優先度で考える。

1. テストプレイヤーAの `session_applications` と `session_comments` だけ削除する。
2. `public.sessions` の公開JSON整合行は、今後のDB移行検証に使うなら残してよい。
3. 完全に検証専用として不要なら、関連行がないことを確認してから `public.sessions` も削除する。

## 10. 検証後の期待表示

テストプレイヤーAでログイン後:

- 「参加申請中」に「灰壁線異常調査」が表示される。
- 日付、開始時刻、GM表示名、セッション状態、申請ステータス、更新日時が不自然でない。
- `詳細を見る` が表示される。
- `詳細を見る` のhrefが `session-detail.html?id=session-2026-06-08-railway-incident` になる。
- クリックで該当セッション詳細へ遷移する。
- email / user_id全文 / token / key / gmUserId が画面やconsoleに漏れない。
- 既存の `rls-test-*` など未同期行は、引き続き「非公開または未同期のセッション」と表示され、詳細リンクを出さない。

## 11. この工程で行わないこと

- Supabase SQL EditorでSQLを実行しない。
- DBデータを変更しない。
- commit / pushしない。
- 本番フロントコードを変更しない。
- `session-detail.html` 投稿統合、GM操作、`close_session` を実装しない。
- `updates.json` を変更しない。
