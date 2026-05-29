# Supabase Step 9 Auth文脈RLSテスト手順書

## 1. 目的

Step 8までで、SQL Editor上の構造・権限確認は完了しています。ただし、SQL Editorの管理者寄りロールではRLSの実挙動を完全には確認できないため、Step 9ではAuthログイン済みユーザー文脈でRLSを確認します。

確認すること：

- anon / player A / player B / gm A / gm B / admin の見え方と実行可否を確認する。
- public session は読める。
- private / hidden session は無関係ユーザーから見えない。
- player は申請可能 session にコメント申請できる。
- player は full / closed / finished / canceled へ申請できない。
- player は他人コメント・他人申請を操作できない。
- GM は自分の session だけ管理できる。
- GM は他GM session を管理できない。
- admin は全件管理できる。
- 公開コメントRPCは内部 `user_id` / `discord_user_id` を返さない。
- public count RPC は private / hidden session の人数を漏らさない。
- service role key をフロント、テストスクリプト、docs、README、チャットに出さない。

この工程でも、本番GitHub PagesへSupabase接続コードは追加しません。

## 2. まだやらないこと

Step 9手順書作成時点では、以下を行いません。

- GitHub Pages本体へSupabase接続コードを追加する。
- `assets/js` に本番用Supabase client初期化を書く。
- `session-detail.html` に実投稿処理を追加する。
- Project URL / API key / service role key / secret key / DB password をdocsやREADMEへ書く。
- Project URL / API key / service role key / secret key / DB password をチャットに貼る前提の手順にする。
- `.env.local` をGit管理対象にする。
- service role key を使うテストスクリプトを書く。
- Discord bot / Webhook / Edge Functions へ進む。

## 3. テスト方法候補

### 案1：Supabase clientを使うローカル検証スクリプト

Node.js + `@supabase/supabase-js` を使い、ローカルだけでRLSのAuth文脈を確認します。

方針：

- Project URL と anon / publishable key は `.env.local` にだけ入れる。
- テストユーザーのメール・パスワードも `.env.local` にだけ入れる。
- `.env.local` はGit管理しない。
- service role key は使わない。
- 本番サイトコードには接続しない。
- テスト対象はSupabaseプロトタイプ環境だけにする。

利点：

- 本番HTMLや `assets/js` に混入しにくい。
- userごとにサインインし直してRLS差分を確認しやすい。
- 失敗したケースをログとして整理しやすい。

注意点：

- `.env.local` の管理を誤るとsecret漏洩につながる。
- 実行後に作成された application / comment の後始末方針を決める必要がある。
- anon / authenticated の切り替えを明示的に扱う必要がある。

### 案2：ブラウザ上の一時検証HTMLまたはConsole検証

ブラウザで一時的にSupabase clientを読み込み、手動で確認する方法です。

利点：

- 実際のブラウザ挙動に近い。
- UI実装前のAPI確認には使える。

注意点：

- 公開サイトのHTMLへ混入しやすい。
- 一時ファイルがGit管理対象になりやすい。
- 誤ってProject URLやkeyをスクリーンショット・チャット・docsに出しやすい。

### 推奨

Step 9では、案1のローカル検証スクリプト方式を推奨します。

理由は、本番サイトへの混入を避けやすく、Auth文脈ごとのRLS差分を機械的に確認しやすいためです。案2は、UI検証が必要になった後の補助手段に留めます。

## 4. 必要な環境変数案

実値はdocs、README、チャット、GitHubへ書きません。以下は名前だけの案です。

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

注意：

- `SUPABASE_SERVICE_ROLE_KEY` は使わない。
- service role key / secret key は不要。
- `.env.local` はGitに入れない。
- 実値はチャットにもdocsにも書かない。
- `.gitignore` に `.env.local` / `.env*.local` が含まれていることを確認する。

## 5. Auth文脈テスト項目

| テストID | ログイン主体 | 操作 | 期待結果 | 危険度 | 備考 |
| --- | --- | --- | --- | --- | --- |
| AUTH-001 | anon | public session一覧を読む | 成功 | 中 | `visibility = 'public'` のみ |
| AUTH-002 | anon | private / hidden sessionを読む | 失敗または0件 | 高 | 非公開予定漏洩防止 |
| AUTH-003 | anon | public comments RPCを読む | 成功 | 中 | 公開申請欄として扱う |
| AUTH-004 | anon | `create_application_comment()` を実行 | 失敗 | 高 | auth必須 |
| AUTH-005 | player A | public recruitingに申請 | 成功 | 高 | application/comment作成 |
| AUTH-006 | player A | public tentativeに申請 | 成功 | 中 | 仮予定も申請可能側 |
| AUTH-007 | player A | public fullに申請 | 失敗 | 高 | 満席は新規申請不可 |
| AUTH-008 | player A | closed / finished / canceledに申請 | 失敗 | 高 | 申請停止状態 |
| AUTH-009 | player A | private / hiddenに申請 | 失敗 | 高 | 無関係playerの非公開予定操作防止 |
| AUTH-010 | player A | 同じsessionへ複数コメント | commentは増えてもapplication countは1人扱い | 高 | 申請者単位カウント |
| AUTH-011 | player B | public recruitingに申請 | 成功 | 中 | 他人編集拒否の準備 |
| AUTH-012 | player A | player Bコメントを編集 | 失敗 | 高 | 他人コメント改変防止 |
| AUTH-013 | player A | 自分のコメントを編集 | 成功 | 中 | `edit_comment()` |
| AUTH-014 | player A | `set_application_status()` を実行 | 失敗 | 高 | GM/admin操作のみ |
| AUTH-015 | player A | `close_session()` を実行 | 失敗 | 高 | GM/admin操作のみ |
| AUTH-016 | player A | 自分の申請を取消 | 成功 | 中 | `cancel_application()` |
| AUTH-017 | player A | 他人申請を取消 | 失敗 | 高 | 他人申請改変防止 |
| AUTH-018 | gm A | 自分のsessionの申請をacceptedにする | 成功 | 中 | `set_application_status()` |
| AUTH-019 | gm A | gm Bのsessionを操作 | 失敗 | 高 | 他GM領域保護 |
| AUTH-020 | gm A | 自分のsessionをclosedにする | 成功 | 中 | `close_session()` |
| AUTH-021 | gm B | gm Aのsessionをclosedにする | 失敗 | 高 | 他GM領域保護 |
| AUTH-022 | gm A | finished / canceledをclosedにする | 失敗 | 中 | 状態遷移制御 |
| AUTH-023 | admin | 全件を確認・管理 | 成功 | 中 | adminのみ |
| AUTH-024 | anon / player | `public_profiles` を読む | `id` / `display_name` のみ | 高 | `discord_user_id` を返さない |
| AUTH-025 | anon / player | `get_public_session_comments()` を読む | 内部 `user_id` / `discord_user_id` を返さない | 高 | 表示用列のみ |
| AUTH-026 | anon / player | `get_public_session_application_counts()` を読む | private / hiddenの人数を返さない | 高 | 人数漏洩防止 |
| AUTH-027 | フロント想定 | service role keyなしで操作 | 必要操作のみ成功 | 高 | 高権限キーをフロントに置かない |

## 6. ローカル検証スクリプト作成候補

今回の工程では、まだスクリプト本体は作りません。次工程で作る候補は以下です。

```text
scripts/supabase-rls-smoke-test.mjs
```

作成条件：

- secretsを直書きしない。
- `.env.local` から読む。
- `.env.local` がGit無視されていることを確認する。
- service role keyを使わない。
- Supabase接続は本番サイトではなくローカル検証用途のみ。
- GitHub Pages公開用HTMLや `assets/js` へimportしない。
- 実行後に作成された application / comment の扱いを明記する。

実行後データの扱い候補：

- テスト用session IDを `rls-test-%` に統一し、後から識別できるようにする。
- 本番データと混ぜない。
- 削除やリセットが必要な場合は、別途テストデータ片付け手順を作る。
- 片付けSQLは、誤実行防止のため本番接続前には必ずレビューする。

## 7. 成功条件

Step 9の成功条件は以下です。

- anonでpublic sessionが読める。
- anonでprivate / hidden sessionが読めない。
- playerがrecruiting / tentativeに申請できる。
- playerがfull / closed / finished / canceledに申請できない。
- 同一playerの複数コメントでapplication countが増えない。
- playerが他人コメント・他人申請を操作できない。
- GMが自分のsessionだけ管理できる。
- GMが他GM sessionを管理できない。
- adminが全件管理できる。
- public RPCで内部 `user_id` / `discord_user_id` が漏れない。
- private / hidden sessionの人数が公開RPCから漏れない。
- service role keyなしでフロント想定権限の確認ができる。

## 8. 中止条件

以下が1つでも起きた場合は、本番接続へ進まずSQL/RLS設計へ戻ります。

- RLSをOFFにしないと動かない。
- anonや無関係playerがprivate / hidden sessionを読める。
- public RPCが内部 `user_id` / `discord_user_id` を返す。
- playerがfull / closed / finished / canceledへ申請できる。
- playerが他人コメント・他人申請を操作できる。
- playerが `set_application_status()` や `close_session()` を実行できる。
- GMが他GM sessionを操作できる。
- public count RPCがprivate / hidden session人数を返す。
- service role keyをローカル検証スクリプトやフロントに置く必要が出る。
- `.env.local` がGit管理対象になっている。
- Project URL / API key / secret類がdocsやREADMEに入りそうになる。

## 9. 本番接続前の停止ポイント

Step 9のAuth文脈テストが終わっても、以下が完了するまで本番サイトへ接続しません。

- RLSテスト全件成功。
- テスト失敗時の修正版SQL/RLS反映。
- secret管理方針の確認。
- `.env.local` / ローカル検証スクリプトのGit管理除外確認。
- 利用者向け説明の準備。
- バックアップ/復旧手順の準備。
- 管理者アカウント復旧手順の準備。
- Discord同期方針の再確認。
- 無料枠・課金条件の再確認。

## 10. 関連資料

- `docs/supabase-step5-rls-test-plan.md`
- `docs/supabase-step6-auth-test-users.md`
- `docs/supabase-rls-test-matrix.md`
- `docs/supabase/sql/006_rls_test_queries_draft.sql`
- `docs/supabase-prototype-runbook.md`

