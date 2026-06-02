# M-14D-13A session posting management QA result

## Scope

M-14D-13Aとして、依頼書管理導線を統合確認した。確認対象は新規依頼書作成、自分の依頼書編集、admin管理対象編集、`session-detail.html` から編集画面への遷移、soft delete、公開状態/募集状態補助文、静的JSON由来の編集不可・削除不可、calendar上の非表示条件、内部情報非露出である。

## Code review QA

- `session-post.html` は新規作成モードで作成ボタンを表示し、編集モードでは `変更を保存` に切り替える。編集中のsubmitは `update_session_post` 側へ流れ、`create_session_post` と混線しない。
- `p_end_at` は新規作成/編集保存のpayloadで維持され、終了日時が開始日時以下の場合はUI側で止まる。
- `draft + public` は保存前にUI側で止め、`update_session_post` / `create_session_post` を呼ばない。
- 自分の依頼書select / admin管理対象selectは `manage-N` 形式のローカル値のみをoption valueに使い、実IDはJSメモリ上の選択レコードからRPCへ渡す。
- admin判定は既存 `is_admin()`、GM投稿権限は `has_role('gm')`、詳細画面の編集/削除可否は `is_admin()` または `is_session_gm(target_session_id)` の既存helper方針と一致する。
- soft deleteは `update_session_post` RPCで `visibility = hidden` / `status = canceled` を保存する。物理削除、DB直UPDATE、service_role key利用はない。
- `sessionData.js` はSupabase由来の公開表示対象から `draft` / `canceled` / `cancelled` を除外している。

## Local browser QA

Codex側では未ログイン状態で以下を確認した。

- `session-post.html`: ログイン必須表示、フォームはhidden、作成ボタン/保存ボタンの初期状態、`p_start_at` / `p_end_at` が `datetime-local`、`closed` / `finished` / `canceled` の選択肢あり、console errorなし。
- `session-detail.html?id=session-2026-06-08-railway-incident`: 静的JSON由来の編集不可・削除不可理由、編集/削除ボタンdisabled、開催時刻の開始年月日表示、console errorなし。
- `calendar.html?date=2026-06-08`: カレンダー表示、公開セッション詳細リンク、`中止` 表示なし、console errorなし。
- 画面/DOM上に raw uuid / user_id / email / token / gmUserId / service_role は検出されなかった。URLに出るのは既存の公開セッションID範囲に限定される。

## Minor fixes

- `renderCalendar.js` のローカル可視判定にも `draft` / `canceled` / `cancelled` 除外を明示した。
- `renderSessionDetail.js` の詳細表示可視判定にも同じ除外を明示した。
- `sessionDisplay.js` の削除ボタン初期titleを、次工程予定文言から権限確認中の文言へ更新した。

## Remaining checks

- ログイン済みGM/adminでの新規作成、編集保存、`session-post.html?id=...` 復元、soft delete OK実行、リロード後の `hidden` / `canceled` 維持はユーザー実ブラウザのテスト用依頼書で確認する。
- admin管理対象が既存RLS/APIで十分に取得できない場合は、後続で管理用RPC追加が必要。M-14D-13AではRPC追加は行っていない。

## Delete policy addendum

M-14D-13A時点では soft delete = `visibility = hidden` / `status = canceled` としてQA確認済み。ただし運用方針として、削除ボタンは完全削除へ変更する。

`hidden` / `canceled` は「中止として残す」操作として扱う。完全削除は後続で `delete_session_post` RPC を新設して実装し、`session-detail.html` だけでなく `session-post.html` の編集画面にも削除ボタンを置く。

完全削除の実行前には確認ポップアップを出す。確認文には「中止として残したい場合は募集状態を中止にする」旨を入れ、完全削除と中止保存の違いを明示する。

この追記時点では SQL Editor未実行、DB変更なし、RPC変更なし。

## Not done

SQL Editor実行、DB構造変更、RPC作成/置換、GRANT/REVOKE、Discord実送信、Edge Function deploy、Discord resync UI、テンプレート保存実装、PC名登録実装、mypage予定プルダウン実装、`updates.json` 変更、service_role key利用、フロントからのDB直UPDATE、commit / push は行っていない。

## M-14D-13B delete_session_post RPC preflight準備

M-14D-13Bとして、完全削除用 `delete_session_post` RPC のpreflight / 草案設計を追加した。
M-14D-13A時点のQA結果である `visibility = hidden` / `status = canceled` は「中止として残す」操作として扱い、削除ボタンは後続で完全削除へ変更する。

新規docs `docs/session-posting-delete-rpc-plan.md`、SELECT-only preflight `docs/supabase/sql/018_delete_session_post_preflight_select_only.sql`、RPC草案 `docs/supabase/sql/018_delete_session_post_rpc_draft.sql` を作成した。
preflightは `public.sessions` の主キー、`id` 型、sessionsを参照するFK、ON DELETE、`session_id` 列を持つテーブル、申請/コメント/連絡先/履歴候補テーブル、既存 `delete_session_post`、helper、`update_session_post` 権限をSELECTだけで確認する。

RPC草案は `delete_session_post(p_session_id text)`、戻り値 `deleted_session_id text` / `deleted_at timestamptz`、`security definer`、`set search_path = ''`、authenticatedのみEXECUTE方針。
許可対象はadminまたは対象GMのみで、通常PL、他GM、未ログイン、静的JSON由来は削除不可とする。

関連データはpreflight結果を見て確定する。`session_applications`、`session_comments`、申請履歴、Discord連絡先表示、Discord同期メタデータ、session-detail、calendar、mypageへの影響をdocsへ明記した。
Discord実送信は行わず、`discord_message_id` がある場合は将来Edge Functionの削除同期が必要。Edge Function未実装の間は公開済み完全削除前に強い確認を出し、「中止として残したい場合は、削除せず募集状態を中止にしてください」という趣旨を入れる。

この工程ではSQL Editor未実行、DB構造変更なし、RPC作成なし、GRANT/REVOKE未実行、実データ削除なし、Discord実送信なし、Edge Function deployなし、`updates.json` 未変更、secret類の出力なし、commit / pushなし。

## M-14D-13B preflight結果

ユーザーがSQL Editorで実行したのは `018_delete_session_post_preflight_select_only.sql` のSELECT-only preflightのみ。
`018_delete_session_post_rpc_draft.sql`、`delete_session_post` RPC本体、CREATE FUNCTION、GRANT / REVOKE、DELETE、DB構造変更は未実行。

preflightでは、`public.sessions` を参照する外部キーは `session_applications_session_id_fkey` と `session_comments_session_id_fkey` の2件だけと確認した。
どちらも `ON DELETE CASCADE` で、`session_id` 列を持つpublic base tableも `session_applications` / `session_comments` のみだった。

そのため、`delete_session_post` で `public.sessions` の対象行を完全削除すると、依頼書本体だけでなく該当セッションの参加申請・参加希望コメントもDB制約で削除される。
後続UIの削除確認文には `削除すると、依頼書本体に加えて参加申請・コメントも削除されます。` を明記する。

SQL草案は、`delete_session_post(p_session_id text)`、`security definer`、`set search_path = ''`、`auth.uid()` 確認、adminまたは対象GMのみ許可、静的JSONはDB対象外、`public.sessions` の対象1件のみDELETE、WHEREあり、戻り値最小限、`public` / `anon` revokeと `authenticated` grant方針で、preflight結果と矛盾しない。
`session_applications` / `session_comments` は `ON DELETE CASCADE` に任せる前提へ更新した。

## M-14D-13C apply-only SQL

M-14D-13Cとして、`delete_session_post` のAPPLY専用SQLファイル `docs/supabase/sql/018_delete_session_post_apply_reviewed.sql` を作成した。
SQL Editorで実行する場合は `apply_reviewed.sql` の全文のみを使い、draft全文は貼らない方針にした。

APPLY専用ファイルはpreflight SELECT群とrollback草案を含めず、`delete_session_post` RPC本体、function comment、`public` / `anon` revoke、`authenticated` grant、実行後確認SELECTだけを含む。
確認SELECTでは `delete_session_post(text)` の存在、`security_definer = true`、`authenticated` EXECUTEあり、`anon` / `public` EXECUTEなしを確認できる。

この工程ではSQL Editor追加実行なし、DB構造変更なし、RPC作成なし、GRANT/REVOKE未実行、実データ削除なし、Discord実送信なし、Edge Function deployなし、secret類なし、`updates.json` 変更なし、commit / pushなし。

## M-14D-13C APPLY結果

ユーザーがSupabase SQL Editorで `docs/supabase/sql/018_delete_session_post_apply_reviewed.sql` を適用し、`delete_session_post` RPC作成と権限設定が完了した。

確認結果は `function_count = 1`、`all_security_definer = true`、signatureは `delete_session_post(text)`。
権限確認は `authenticated EXECUTEあり`、`anon EXECUTEなし`、`public EXECUTEなし` で、すべて期待値どおり `ok = true`。

DB側の変更はRPC作成・権限設定のみ。
実データ削除、Discord実送信、Edge Function deploy、secret類の出力、`updates.json` 変更は行っていない。
次工程はM-14D-13Dとして、`session-detail.html` / `session-post.html` の削除ボタンを `delete_session_post` RPCへ接続する。

## M-14D-13D delete RPC UI接続QA記録

M-14D-13Dとして、依頼書管理導線の削除ボタンを `delete_session_post` RPCへ接続した。
M-14D-13A時点でQA済みだった soft delete = `visibility = hidden` / `status = canceled` は、「削除」ではなく「中止として残す」操作として扱う。
削除ボタンは完全削除で、DB制約により依頼書本体に加えて `session_applications` と `session_comments` も削除される前提を確認文へ明記した。

`session-detail.html` ではSupabase由来かつ作成者GMまたはadminとして編集可能な依頼書だけ削除可能にし、静的JSON由来は削除不可理由を表示する。
`session-post.html` では編集モード中のみ削除ボタンを出し、削除成功後は管理対象selectとJSメモリを更新して新規作成モードへ戻す。
`delete_session_post` 呼び出しは `p_session_id` のみで、フロントからDB直DELETEは行わない。

削除確認文には、完全削除であること、参加申請・コメントも削除されること、中止として残したい場合は募集状態を「中止」にすること、Discord通知・投稿削除は未実装であることを入れた。
成功時は「この依頼書を削除しました。」、既知エラーは `login_required` / `not_allowed` / `session_not_found` を日本語化し、未知エラーは「依頼書の削除に失敗しました。」へ丸める。
raw id / uuid / user_id / email / gmUserId / token / secret類は画面・DOM・consoleへ出さず、select option valueは `manage-N` のローカル値のみを維持する。

この工程でSQL Editor追加実行、DB構造変更、RPC変更、GRANT/REVOKE再実行、実データ削除、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushは行っていない。

## DiscordユーザーID登録UI方針

テンプレート機能の前提整備として、Discord連絡先登録UIのユーザー向け表記を `DiscordユーザーID` へ寄せる。

本人登録では17〜20桁の数字を基本形式とし、互換として `<@123456789012345678>` 形式も受け付ける。その場合は保存前に数字部分だけへ正規化し、`update_my_discord_id(new_discord_id text)` へ渡す。空欄は未登録扱いで許可する。

数字だけだが桁数不正、英字混じり、改行入り、`<@abc>`、`@123456789012345678` は保存前に止める。既に形式不正の値が保存されている場合は自動変換せず、再登録を促す。

保存成功後は、RPC返却が空でも保存に使った正規化済みDiscordユーザーIDで本人画面の表示状態を即時更新する。空欄保存時だけ `未登録` 表示に戻す。

GM向けの承認済み参加者連絡先表示では、保存された数字IDから `<@DiscordユーザーID>` を生成して表示・コピーする。未登録または形式不正の値は生表示せず `登録されていません` に丸める。raw Supabase `user_id` / email / token / secret類を画面・DOM・consoleへ出さない方針は維持する。

呼び出し用テンプレートでは、GMが承認済み参加者を一人ずつ選ぶ方式にはしない。現在のセッションに紐付く承認済み参加者全員を対象にし、コピー時にテンプレート内の変数をまとめて置換する。

初期実装で優先する変数は `{{session_title}}`、`{{approved_call_list}}`、`{{approved_pc_names}}` とする。`{{approved_call_list}}` は承認済み参加者のDiscordメンション、表示名、PC名を1人1行で出力し、DiscordユーザーIDが未登録または形式不正の場合は `登録されていません`、PC名未登録の場合は `PC名未登録` を出す方針を推奨する。

`{{approved_discord_mentions}}` はDiscordメンションだけをまとめて出す変数として残してよいが、呼び出し文で実用性が高いのは `{{approved_call_list}}` とする。`{{approved_discord_ids}}` は初期実装では見送る。

この工程でSQL Editor実行、DB構造変更、RPC変更、GRANT/REVOKE実行、Discord実送信、Edge Function deploy、テンプレート保存テーブル作成、テンプレート生成UI、`{{approved_call_list}}` の実際の置換処理、テンプレート保存機能本体、PC名登録機能、mypage予定プルダウン化、`updates.json` 変更、secret類の出力、commit / pushは行わない。

## GM本人コメントの参加人数カウント除外

session-detailの参加申請 / コメントまわりで、GM本人コメントが参加人数にカウントされる不具合を表示・集計側で修正した。GM本人コメントは告知・補足用として許可し、コメント一覧には表示してよい。ただし参加申請として扱わず、参加人数、申請者一覧、GM承認操作対象、承認済み参加者連絡先から除外する方針とした。

Supabase由来セッションでは `sessions.gm_user_id` をJS内部判定用に読み込み、画面、DOM、consoleには出さない。ログイン中ユーザーが対象セッションのGM本人かどうかは、Auth sessionのユーザーIDと `gm_user_id` の内部比較だけで判定する。

GM/admin文脈では、RLSで許可された範囲の `session_applications` から `user_id` / `status` だけを内部取得し、GM本人の `user_id` を除外して `pending` / `waitlisted` / `accepted` を再集計する。公開カウントRPC自体は今回変更しない。

GM本人の投稿フォームは消さず、GM本人には `GMとして管理中です。参加申請は不要です。` と `GMコメントとして投稿されます。参加申請には含まれません。` を表示する。投稿は既存 `create_application_comment` を使うため、投稿直後に既存 `cancel_my_session_application` を呼び、GM本人の申請行を `canceled` 側へ戻す。これにより公開カウントRPC、mypageの申請中/参加予定、承認済み連絡先にGM本人が復活しないようにした。

コメント一覧では、GM本人が自分のセッションを見ている場合に本人コメントへ `GMコメント` ラベルを付ける。公開コメントRPCは投稿者 `user_id` を返さないため、通常PLや未ログイン閲覧者向けに全GMコメントを厳密ラベル付けする変更は今回行わない。

GMコメント削除時の確認文は参加希望コメント用文言から分離し、`このGMコメントを削除しますか？` と `参加申請には影響しません。` を表示する。PL参加希望コメント削除時は、最後の有効コメント削除で参加申請が取り消される可能性がある既存注意文を維持する。

GM向け申請履歴と承認済み連絡先は、内部 `user_id` を返さないRPCがあるため、GM本人の表示名を使ったbest-effort除外とした。厳密に除外するには、後続でRPC側にGM本人除外条件を入れるか、内部IDを返さずにGM本人判定済みの結果だけ返す設計が必要。

adminコメントの扱いは、adminがGM管理コメントを投稿する文脈とPLとして参加申請する文脈の切り分けが必要なため後続課題とする。今回の最低条件は、`session.gm_user_id` と一致するGM本人を参加人数・申請者一覧・承認済み連絡先から外すこと。

既存DB上にGM本人の申請行やコメント行が存在しても、今回はDB cleanupは実施しない。SQL Editor実行、DB構造変更、`comment_type` 列追加、RPC作成/置換、GRANT/REVOKE、既存データcleanup、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushは行わない。
