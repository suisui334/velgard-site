# Supabase Step 5 RLSテスト準備計画

## 1. 目的

この文書は、Supabase FreeプロトタイプでStep 4のSQL実行が完了した後、RLSテストを安全に進めるための準備資料です。

Step 5では、以下を確認します。

* RLSが意図通り効いているか。
* anon / player / gm / admin の権限差が表現できているか。
* public / private / hidden / full / closed / finished / canceled のセッション状態差が反映されるか。
* 参加申請コメントは公開申請欄扱いだが、Discord ID / 内部 `user_id` / 権限情報を公開しないか。
* 参加人数はコメント件数ではなく、`session_applications` の一意ユーザー単位で数えられるか。
* `full` session は満席として新規申請不可になっているか。
* 本番サイト接続前にRLSテスト全件成功を必須条件にできるか。

この段階でも、GitHub Pages本体へSupabase接続コードは追加しません。

## 2. まだやらないこと

以下はStep 5計画作成時点では行いません。

* Supabase上で追加SQLを実行する
* API key / Project URL / service_role / secret key / DB password を出力する
* GitHub Pages本体へSupabase接続コードを追加する
* `assets/js` にSupabase clientを追加する
* `session-detail.html` に実コメント投稿処理を追加する
* Edge Functions / Discord bot / Webhook を実装する
* 実メールアドレスや実Discord IDをdocsやSQLに書く
* 本番用データを投入する

## 3. テストユーザー方針

Supabase Authentication上で、テスト専用ユーザーを作成する想定です。

docsやチャットには、実メールアドレス、実UUID、実Discord IDを書きません。以下はプレースホルダーです。

| テストユーザー | 役割 | プレースホルダー |
| --- | --- | --- |
| player A | 一般PL | `<PLAYER_A_ID>` |
| player B | 一般PL | `<PLAYER_B_ID>` |
| gm A | セッションGM | `<GM_A_ID>` |
| gm B | 別GM | `<GM_B_ID>` |
| admin | 管理者 | `<ADMIN_ID>` |

実操作時は、Supabase上でAuthユーザーを作成した後、SQL Editor内だけでUUIDを置換します。置換済みSQLをGitへcommitしません。

初回admin付与は通常UIからは行わず、SQL Editor上で手動投入する想定です。以後、一般ユーザーが自分をadmin / gm化できないことを必ずRLSテストします。

## 4. テストデータ方針

`005_rls_test_seed_draft.sql` では、以下のテスト用sessionを用意する想定です。

| session id | visibility | status | 目的 |
| --- | --- | --- | --- |
| `rls-test-public-recruiting` | public | recruiting | 申請可能な通常募集 |
| `rls-test-public-tentative` | public | tentative | 仮予定でも申請可能か確認 |
| `rls-test-public-full` | public | full | 満席のため申請不可 |
| `rls-test-public-closed` | public | closed | 〆状態のため申請不可 |
| `rls-test-public-finished` | public | finished | 終了済みのため申請不可 |
| `rls-test-public-canceled` | public | canceled | 中止のため申請不可 |
| `rls-test-private-recruiting` | private | recruiting | 無関係player / anonに漏れないことを確認 |
| `rls-test-hidden-recruiting` | hidden | recruiting | 無関係player / anonに漏れないことを確認 |
| `rls-test-other-gm-recruiting` | public | recruiting | 他GM操作拒否の確認 |

テストデータはプロトタイプ専用です。本番データは投入しません。

## 5. テスト項目

最低限、以下を確認します。

| 分類 | 確認項目 |
| --- | --- |
| anon閲覧 | anonがpublic sessionを読める |
| anon閲覧 | anonがprivate / hidden sessionを読めない |
| anon表示RPC | anonがpublic申請コメント表示RPCを読める |
| anon操作RPC | anonが申請作成RPCを実行できない |
| player申請 | playerがrecruiting / tentativeへ申請できる |
| player申請拒否 | playerがfull / closed / finished / canceledへ申請できない |
| player申請拒否 | playerがprivate / hiddenへ無関係に申請できない |
| player編集 | playerが自分のコメントを編集できる |
| player編集拒否 | playerが他人コメントを編集できない |
| player取消 | playerが自分の申請を取消できる |
| player取消拒否 | playerが他人申請を取消できない |
| player権限拒否 | playerがset_application_statusを使えない |
| player権限拒否 | playerがclose_sessionを使えない |
| GM操作 | GMが自分のsessionの申請ステータスを変更できる |
| GM操作拒否 | GMが他GMのsessionを操作できない |
| GM〆 | GMが自分のsessionをclosedにできる |
| admin | adminが全件管理できる |
| 公開profile | public_profilesにdiscord_user_idが出ない |
| 公開コメント | get_public_session_commentsに内部user_id / discord_user_idが出ない |
| 公開count | get_public_session_application_countsがprivate / hidden session人数を漏らさない |
| 人数計算 | 同一ユーザーが複数コメントしても参加人数が重複カウントされない |

## 6. SQL Editorでの注意

Supabase SQL Editorの通常実行ロールは管理者寄りで、RLSを迂回しうるため、RLSそのものの体感テストには不向きです。

RLSの実挙動確認は、可能ならSupabase client / API / Authenticated user contextで行います。

SQL Editorでは、主に以下を確認します。

* オブジェクト構造
* 関数定義
* RLS有効化
* grant / revoke
* 公開view / RPCの返却列
* テストデータの投入状態

SQL Editor内で `set local role anon` や `set_config('request.jwt.claim.sub', ...)` を使う疑似テスト案は `006_rls_test_queries_draft.sql` に含めますが、Supabase環境での正確な挙動は要追加検証です。疑似テストの成功だけで本番接続へ進みません。

## 7. seed SQLの扱い

`005_rls_test_seed_draft.sql` は、テスト用データ投入の草案です。

* 実UUIDは入れていません。
* 実メールアドレスは入れていません。
* 実Discord IDは入れていません。
* 本番データは入れていません。
* 実行前にSQL Editor内で `<PLAYER_A_ID>` などを置換する必要があります。
* 置換済みSQLはcommitしません。

## 8. RLSテストSQLの扱い

`006_rls_test_queries_draft.sql` は、RLS検証のためのクエリ草案です。

* 管理者権限のSQL EditorだけではRLSの最終判定にしません。
* 書き込み系RPCの確認は、必要に応じてtransaction内で行い、rollbackできる形で進めます。
* 実UUIDや実メール、実Discord IDはファイルに書きません。
* API keyやProject URLは使いません。

## 9. 成功条件

Step 5の成功条件は以下です。

* anonがpublic sessionを読める。
* anonがprivate / hidden sessionを読めない。
* anon / public表示RPCでDiscord ID、内部 `user_id`、権限情報が漏れない。
* playerがrecruiting / tentativeへ申請できる。
* playerがfull / closed / finished / canceledへ申請できない。
* 同一playerの追加コメントでapplicationが重複しない。
* playerが他人のコメントや申請状態を変更できない。
* GMが自分のsessionだけを管理できる。
* GMが他GMのsessionを操作できない。
* adminが全件管理できる。
* service role keyなしでフロント想定権限のテストへ進める。

## 10. 中止条件

以下が1つでも起きた場合は、本番サイト接続へ進まず、SQL/RLS草案へ戻ります。

* RLSをOFFにしないと動かない。
* anonがprivate / hidden sessionを読める。
* anonがDiscord IDや内部 `user_id` を読める。
* playerが他人のコメントを編集できる。
* playerが自分をadmin / gm化できる。
* playerがfull / closed / finished / canceled sessionへ申請できる。
* GMが他GM sessionをclosedにできる。
* public count RPCからprivate / hidden session人数が返る。
* service role keyをフロントへ置く必要が出る。
* API keyやsecretをGitHubへ入れそうになる。

## 11. 次に進む条件

この計画とSQL草案をユーザーが確認した後、Supabase SQL Editor上で必要に応じて以下の順に進めます。

1. `005_rls_test_seed_draft.sql` のプレースホルダーをSQL Editor内で置換する。
2. テストseedだけを投入する。
3. `006_rls_test_queries_draft.sql` の構造確認クエリを実行する。
4. 疑似RLSテストは参考として扱う。
5. 本格RLSテストはAuth contextで別途確認する。

まだ本番GitHub Pagesへ接続しません。
