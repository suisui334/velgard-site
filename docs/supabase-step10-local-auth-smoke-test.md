# Supabase Step 10 ローカルAuth文脈RLSスモークテスト手順

## 1. 目的

`scripts/supabase-rls-smoke-test.mjs` は、Supabase Authログイン済み文脈でRLSの実挙動を確認するためのローカル検証スクリプトです。

このスクリプトは本番GitHub Pagesへ組み込みません。`assets/js` や公開HTMLからimportしません。

## 2. まだやらないこと

- 本番サイトへSupabase接続コードを追加しない。
- `assets/js` にSupabase client初期化を書かない。
- `session-detail.html` に実投稿処理を追加しない。
- Project URL / API key / password / secret類をREADMEやdocsへ書かない。
- service role keyを使わない。
- Discord bot / Webhook / Edge Functionsへ進まない。

## 3. 依存関係インストール

初回のみ、ローカルで依存関係をインストールします。

```powershell
npm install
```

`node_modules/` は `.gitignore` で除外しています。`package-lock.json` が生成された場合は、後続工程でcommit対象にするかを確認してから扱います。

## 4. `.env.local` の作成

`.env.example` を参考に、ローカルだけで `.env.local` を作成します。

```powershell
Copy-Item .env.example .env.local
```

`.env.local` にはSupabaseプロトタイプ用のProject URL、anon / publishable key、テストユーザーのメール・パスワードを入れます。ただし、これらの実値はチャット、README、docs、GitHubへ貼りません。

service role keyは不要です。`SUPABASE_SERVICE_ROLE_KEY` を `.env.local` に入れないでください。

## 5. 必要な環境変数

`.env.local` に設定する変数は以下です。

```text
SUPABASE_URL=
SUPABASE_ANON_KEY=

TEST_PLAYER_A_EMAIL=
TEST_PLAYER_A_PASSWORD=
TEST_PLAYER_B_EMAIL=
TEST_PLAYER_B_PASSWORD=
TEST_GM_A_EMAIL=
TEST_GM_A_PASSWORD=
TEST_GM_B_EMAIL=
TEST_GM_B_PASSWORD=
TEST_ADMIN_EMAIL=
TEST_ADMIN_PASSWORD=
```

任意：

```text
RUN_DESTRUCTIVE_TESTS=false
```

初回は `RUN_DESTRUCTIVE_TESTS=false` のままにします。`true` にすると `close_session` 成功系のようにセッション状態を変えるテストが走るため、RLS確認が安定するまで使いません。

## 6. 実行前チェック

実行前に以下を確認します。

- Step 5 seed投入が完了している。
- `profiles 5 / user_roles 7 / sessions 9` が確認済み。
- `.env.local` がGit管理対象ではない。
- `SUPABASE_SERVICE_ROLE_KEY` を使っていない。
- 本番DBではなくプロトタイプDBである。
- ログにProject URL / key / passwordが出ないことを意識する。

## 7. 実行コマンド

```powershell
npm run supabase:rls:smoke
```

出力は `PASS` / `FAIL` / `SKIP` で表示されます。

- `PASS`: 期待通り。
- `FAIL`: 期待と違う。RLS / RPC / seed / Authユーザー設定を確認する。
- `SKIP`: 初回では意図的に実行しない破壊的テスト。

失敗が1件でもある場合、スクリプトは `process.exitCode = 1` を設定します。

## 8. 状態変更テストの扱い

このスクリプトはテストDBに対して状態変更を行います。

- 実行により `session_comments` と `session_applications` が増える。
- 繰り返し実行するとコメント行は増える可能性がある。
- 同一ユーザーの複数コメントでも、`session_applications` は `session_id + user_id` の一意制約により1件扱いになる想定。
- `close_session` 成功系は初回ではSKIPする。
- `RUN_DESTRUCTIVE_TESTS=true` を明示した場合だけ、GMが自分のsessionをclosedにする成功系を実行する。

本番DBでは絶対に実行しません。

## 9. 失敗時の報告方法

失敗時は、以下だけを報告します。

- 失敗したテストID
- 期待結果
- 実際のエラー概要
- どのロールで失敗したか

以下は報告に含めません。

- Project URL
- API key
- password
- service role key
- secret key
- DB password
- 実メールアドレス
- 実Discord ID

ログを貼る場合は、URL / key / passwordが含まれていないことを必ず確認します。

## 10. 本番サイト接続前の停止ポイント

このスモークテストが通っても、すぐ本番サイトへ接続しません。

本番接続前に必要なこと：

- RLSテスト全件成功。
- 失敗ケースの原因整理。
- テストデータの扱い整理。
- secret管理方針の確認。
- 利用者向け説明の準備。
- バックアップ/復旧手順の準備。
- Discord同期方針の再確認。

## 11. 関連資料

- `docs/supabase-step9-auth-context-test-plan.md`
- `docs/supabase-step6-auth-test-users.md`
- `docs/supabase-step5-rls-test-plan.md`
- `docs/supabase-rls-test-matrix.md`
- `docs/supabase/sql/006_rls_test_queries_draft.sql`
