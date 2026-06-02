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

## Not done

SQL Editor実行、DB構造変更、RPC作成/置換、GRANT/REVOKE、Discord実送信、Edge Function deploy、Discord resync UI、テンプレート保存実装、PC名登録実装、mypage予定プルダウン実装、`updates.json` 変更、service_role key利用、フロントからのDB直UPDATE、commit / push は行っていない。
