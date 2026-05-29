# Supabase Step 6 Authテストユーザー作成手順・seed投入前チェック

## 1. 目的

この資料は、Supabase FreeプロトタイプでRLSテスト用Authユーザーを作成し、`005_rls_test_seed_draft.sql` を実行する前に確認するための手順メモです。

この段階では、まだ以下を行いません。

- Supabase上で追加SQLを実行する
- Project URL / API key / service role key / secret key / DB password を記録・共有する
- 実メールアドレス、実Discord ID、実UUIDをdocsやREADMEへ保存する
- GitHub Pages本体へSupabase接続コードを追加する
- `assets/js` にSupabase client初期化コードを追加する
- `session-detail.html` に実コメント投稿処理を追加する

## 2. 作成するテストユーザー

Supabase Authentication上で、RLS検証用に以下のテストユーザーを作成する想定です。

| テストユーザー | 役割 | メールアドレスの例 |
| --- | --- | --- |
| player A | 一般PL | `test-player-a@example.invalid` |
| player B | 一般PL | `test-player-b@example.invalid` |
| gm A | セッションGM | `test-gm-a@example.invalid` |
| gm B | 別GM | `test-gm-b@example.invalid` |
| admin | 管理者 | `test-admin@example.invalid` |

メールアドレスは実メールではなく、`.invalid` などのプレースホルダーを使います。実ユーザーのメールアドレスはdocs、README、チャット、GitHubへ書きません。

## 3. Supabase Dashboardでの作成手順

画面表示やボタン名はSupabase Dashboard側の表示を正とします。

1. Supabase Dashboardで対象プロトタイププロジェクトを開く。
2. Project Overviewから `Authentication` へ移動する。
3. `Users` 画面を開く。
4. `Add user` / `Invite user` / `Create user` など、画面に表示されているユーザー作成操作を選ぶ。
5. テスト用メールアドレスには `.invalid` ドメインのプレースホルダーを使う。
6. パスワードを設定する場合は、チャットやdocsに書かず安全な場所で管理する。
7. メール確認が必要な設定になっている場合は、RLSテスト方法をいったん止めて別途検討する。
8. 作成後、各ユーザーのUUIDをDashboard上で確認する。
9. UUIDはチャット、README、docs、GitHubへ貼らない。
10. UUIDは `005_rls_test_seed_draft.sql` 実行時に、Supabase SQL Editor内でだけ一時置換する。

## 4. UUIDの扱い

`005_rls_test_seed_draft.sql` には以下のプレースホルダーが含まれます。

```text
<PLAYER_A_ID>
<PLAYER_B_ID>
<GM_A_ID>
<GM_B_ID>
<ADMIN_ID>
```

実UUIDはローカルファイルへ保存しません。置換済みSQLをcommitしません。SQL Editor上で一時的に置換し、その画面内だけで扱います。

エラー報告が必要な場合も、UUIDを含む行は伏せます。報告するのはエラー種別と、どのStepで失敗したかだけにします。

## 5. seed投入前チェック

`005_rls_test_seed_draft.sql` を実行する前に、以下を確認します。

| 確認項目 | 判定 |
| --- | --- |
| Supabase project STATUS が `Healthy` | OKになるまで進まない |
| SQL Editorを開ける | 開けない場合は進まない |
| `005_rls_test_seed_draft.sql` の原本に実UUIDを書き込んでいない | 必須 |
| UUID置換はSQL Editor上でのみ行う | 必須 |
| 実Discord IDを入れていない | 必須 |
| 本番データを入れていない | 必須 |
| `full` / `closed` / `private` / `hidden` などのテストセッションが含まれている | 必須 |
| Project URL / API key / service role key / secret key を貼っていない | 必須 |
| 本番サイトへ接続していない | 必須 |

seed実行後は、まず `profiles` / `user_roles` / `sessions` のテストデータ件数だけ確認します。RLS挙動の本格確認は `006_rls_test_queries_draft.sql` と `docs/supabase-rls-test-matrix.md` に従って進めます。

## 6. 初回admin付与の注意

初回adminは通常UIから安全に作れないため、プロトタイプではSupabase Dashboard / SQL Editor上で手動投入する想定です。

注意点：

- 初回admin付与はテスト環境だけで行う。
- 一般ユーザーが自分を `admin` / `gm` にできないことをRLSテストで必ず確認する。
- 本番導入前にadmin復旧手順と予備admin方針を決める。
- `service_role` keyをブラウザやチャットに出さない。

Supabaseのadmin user creation系APIはサーバー側専用の高権限キーを前提にする領域です。このプロトタイプでは、ブラウザ実装やGitHub Pages側から高権限キーを使う方針は取りません。

## 7. 禁止事項

Step 6では以下を行いません。

- `service_role` keyを使ってユーザー作成する
- `service_role` keyをブラウザ、チャット、docs、README、GitHubへ出す
- Project URL / API keyを貼る
- 実メールアドレスを使う
- 実Discord IDを書く
- 実UUIDをdocsへ保存する
- 置換済みseed SQLを保存・commitする
- 本番サイトに接続する
- `assets/js` にSupabase clientを追加する
- GitHub Pages側の実装へ進む

## 8. 失敗時の報告方針

失敗した場合は、以下だけを報告します。

- どのStepで失敗したか
- エラーの概要
- 対象オブジェクト名
- UUID、Project URL、API key、secret類を伏せたエラー文

以下は報告に含めません。

- Project URL
- API key
- service role key
- secret key
- DB password
- 実メールアドレス
- 実Discord ID
- 実UUID

## 9. 次工程

Step 6以降は、次の順で進めます。

```text
Step 6：Authテストユーザー作成手順作成
Step 6-A：ユーザーがSupabase Dashboardでテストユーザー作成
Step 6-B：UUIDをチャットに貼らず、SQL Editor上でseedに一時置換
Step 7：005 seed 実行
Step 8：006 RLS test queries 実行
Step 9：失敗箇所修正
Step 10：全件成功まで本番接続禁止
```

Step 6-B以降でも、GitHub Pages本体にはまだ接続しません。RLSテスト全件成功、本番接続前チェック、secret管理方針、利用者向け説明、バックアップ/復旧手順が整うまで本番反映へ進みません。

