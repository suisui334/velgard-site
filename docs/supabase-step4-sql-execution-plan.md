# Supabase Step 4 SQL実行前・最終分解プラン

## 1. 目的

この文書は、Supabase Freeプロトタイプ `velgard-session-prototype` に対して、既存SQL草案を安全に段階実行するための最終分解プランです。

この段階では、まだSQL EditorでSQLを実行しません。

本番公開中のGitHub PagesサイトへSupabase接続コードを追加せず、API key、Project URL、service role key、secret key、DB password、JWT secret、Webhook URL、bot token、実メールアドレスなども記録しません。

## 2. 実行前停止条件

SQL Editorへ進む前に、以下をすべて満たしていることを確認します。

| 確認項目 | 条件 |
| --- | --- |
| Supabase project | STATUS が Healthy である |
| SQL Editor | 画面を開ける |
| Table Editor | 画面を開ける |
| secret管理 | Project URL / API key / service_role / secret key をチャットやファイルに貼っていない |
| 本番接続 | GitHub Pages本体へSupabase接続コードを入れていない |
| 作業ツリー | SQL実行前はGit状態がcleanであることが望ましい |
| ユーザー確認 | このStep 4実行計画をユーザーが確認済みである |

いずれかが満たせない場合は、SQL実行へ進まずに止まります。

## 3. SQL実行順の分解

SQLは一括実行せず、以下の4段階に分けます。

| Step | 対象ファイル | 目的 |
| --- | --- | --- |
| Step 4-1 | `docs/supabase/sql/001_core_schema_draft.sql` | テーブル、制約、index、trigger、公開用view草案の作成 |
| Step 4-2 | `docs/supabase/sql/002_rls_grants_draft.sql` | RLS有効化、grant/revoke、policy、公開用RPC/viewの整理 |
| Step 4-3 | `docs/supabase/sql/003_rpc_draft.sql` | `create_application_comment` / `edit_comment` / `cancel_application` / `set_application_status` / `close_session` などの関数作成 |
| Step 4-4 | `docs/supabase/sql/004_validation_queries_draft.sql` | 作成済みオブジェクト、RLS、権限、公開範囲の検証 |

## 4. Step 4-1: core schema

| 項目 | 内容 |
| --- | --- |
| 実行対象ファイル | `docs/supabase/sql/001_core_schema_draft.sql` |
| 実行前確認 | 空プロジェクトであること、まだ本番サイトへ接続していないこと、SQL草案に実URL/key/secretが含まれていないこと |
| 実行後確認 | `profiles` / `user_roles` / `sessions` / `session_comments` / `session_applications` が作成されていること |
| 成功条件 | 最小核5テーブル、制約、index、`updated_at` trigger、`public_profiles` viewがエラーなく作成される |
| 失敗時に止まる条件 | テーブル作成エラー、外部キーエラー、`is_closed` のような二重管理列の混入、`public_profiles` に `discord_user_id` が含まれる |
| 次Stepへ進む条件 | テーブル構造と公開用viewの列が意図通りであること |

Step 4-1では、RLS policyやRPCの動作確認にはまだ進みません。

## 5. Step 4-2: RLS / grants / policies

| 項目 | 内容 |
| --- | --- |
| 実行対象ファイル | `docs/supabase/sql/002_rls_grants_draft.sql` |
| 実行前確認 | Step 4-1が成功していること、対象テーブルが存在していること |
| 実行後確認 | すべての対象テーブルでRLSが有効化されていること、grant/revokeが意図通りであること |
| 成功条件 | anonがprivate / hidden sessionや `user_roles` / `profiles.discord_user_id` を読めない方針になっている |
| 失敗時に止まる条件 | `profiles` 本体のanon全公開、private / hidden session漏洩、関数execute権限の過剰開放、service role前提の運用 |
| 次Stepへ進む条件 | RLS有効化、公開view/RPC、権限付与が意図通り整理されていること |

参加申請コメントは公開申請欄扱いとします。ただし、公開対象は表示名、申請状態、本文、投稿日時などに限定し、Discord ID、内部 `user_id`、権限情報、private / hidden / deleted / internal情報を公開しません。

## 6. Step 4-3: RPC

| 項目 | 内容 |
| --- | --- |
| 実行対象ファイル | `docs/supabase/sql/003_rpc_draft.sql` |
| 実行前確認 | Step 4-1 / Step 4-2 が成功していること、helper関数が存在すること |
| 実行後確認 | `create_application_comment` / `edit_comment` / `cancel_application` / `set_application_status` / `close_session` が作成されていること |
| 成功条件 | コメント作成と申請作成、本人編集、申請取消、GM/admin承認、GM/admin〆操作をRPC経由で制御できる草案になっている |
| 失敗時に止まる条件 | `full` / `closed` / `finished` / `canceled` へ申請できる、playerが承認状態へ直接変更できる、GMが他GMのsessionを閉じられる |
| 次Stepへ進む条件 | 関数定義、`security definer`、`search_path`、入力検証、`revoke/grant execute` 方針が確認できていること |

`full` は満席状態として扱い、新規申請不可とします。キャンセル待ちは将来の別設計です。

## 7. Step 4-4: validation queries

| 項目 | 内容 |
| --- | --- |
| 実行対象ファイル | `docs/supabase/sql/004_validation_queries_draft.sql` |
| 実行前確認 | Step 4-1からStep 4-3までが成功していること |
| 実行後確認 | 必要テーブル、view、RPC、RLS状態、公開列、execute権限、申請可能status方針をSELECTで確認する |
| 成功条件 | 破壊的SQLなしで、公開範囲・権限・募集状態の重要方針を確認できる |
| 失敗時に止まる条件 | 必要オブジェクト不足、RLS無効、公開viewにDiscord ID混入、`full` が申請可能側に含まれる、関数executeが過剰に開いている |
| 次Stepへ進む条件 | validation queryの結果に重大なNGがなく、RLSテストへ進める状態であること |

`004_validation_queries_draft.sql` はSELECT中心の検証用です。DROP / DELETE / TRUNCATE は含めません。

## 8. RLSテストへの接続

SQL実行とvalidation queryの後は、`docs/supabase-rls-test-matrix.md` に従ってRLSテストへ進みます。

特に以下を再確認します。

* 参加申請コメントは公開申請欄扱いでよい。
* private / hidden session のコメントは公開しない。
* Discord ID、内部 `user_id`、権限情報は公開view / public RPC / public JSONレスポンスへ出さない。
* 参加人数はコメント件数ではなく、`session_applications` の一意ユーザー単位で数える。
* `full` session は満席として新規申請不可。
* `sessions.status = 'closed'` を〆状態の正本にし、`is_closed` は作らない。
* service role / secret key はフロントに置かない。

## 9. まだやらないこと

このStep 4実行計画の作成時点では、以下を行いません。

* Supabase SQL EditorでSQLを実行する
* API keyを取得・共有する
* Project URLをdocsやREADMEに書く
* service role / secret keyを出力する
* DB passwordを出力する
* GitHub Pages本体へ接続コードを追加する
* `assets/js` にSupabase clientを追加する
* `session-detail.html` に実コメント投稿処理を追加する
* Edge Functions / Discord bot / Webhook に進む

## 10. 次に進む条件

次にSupabase SQL Editorへ進む場合は、以下の順番で止まりながら進めます。

1. この文書をユーザーが確認する。
2. Git状態が意図通りであることを確認する。
3. SQL EditorでStep 4-1のみ実行する。
4. Table Editorまたはvalidation queryでStep 4-1の結果だけ確認する。
5. 問題がなければStep 4-2へ進む。

いきなりStep 4-1からStep 4-4まで連続実行しません。
