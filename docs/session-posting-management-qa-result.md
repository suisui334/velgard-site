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
