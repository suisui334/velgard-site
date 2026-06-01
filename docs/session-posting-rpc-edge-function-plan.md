# M-14B 依頼書投稿DB/RPC + Discord同期Edge Function草案

## 1. 目的

M-14Aの全体設計を、次工程でレビュー・適用候補にできる粒度へ具体化する。

対象:

- GM/adminが依頼書を投稿するためのDB/RPC草案。
- Discord同期用Edge Function草案。
- 投稿済みセッションをcalendar/session-detailへ表示するための方針。

この工程ではSQL Editor実行、DB変更、Edge Function deploy、Discord実送信、フロント実装は行わない。

## 2. 既存sessions拡張で行けるか

第一候補は既存 `public.sessions` の拡張で問題ない。

理由:

- `session_comments` と `session_applications` が `sessions.id` を外部キーとして参照済み。
- GM判定は `sessions.gm_user_id` を見る `is_session_gm(target_session_id)` 系の既存関数を使っている。
- mypage、session-detail、GM履歴、GM承認/却下、GM Discord連絡先は `session_id` を共有している。
- 新テーブルを正本にすると、既存RPC群との接続と二重管理が増える。

新テーブルは、依頼書本文そのものではなくDiscord同期履歴や複数投稿先が必要になった段階で検討する。

## 3. 追加DB列案

`public.sessions` 追加候補:

- `session_type text`
- `application_deadline timestamptz`
- `discord_sync_status text`
- `discord_last_action text`
- `discord_message_id text`
- `discord_channel_id text`
- `discord_thread_id text`
- `discord_sync_requested_at timestamptz`
- `discord_synced_at timestamptz`
- `discord_sync_error text`
- `discord_post_url text`

`session_type` は `one-shot` / `campaign` / `special` / `other` の固定分類。`application_deadline` は開催時刻とは別に扱う。

Discord同期メタデータにはDiscord投稿credentialやサーバー側credential値を保存しない。

公開かつ `tentative` / `recruiting` の新規投稿だけを初期同期対象にする。`draft`、`private`、`hidden` は `discord_sync_status = skipped` とし、Discordへ即時同期しない。`draft` を `public` で保存する要件が出た場合は、公開範囲とRLS/一覧表示の扱いを再レビューしてから許可する。

## 4. 投稿RPC案

SQL草案:

```text
docs/supabase/sql/015_session_posting_rpc_draft.sql
```

RPC候補:

```text
create_session_post
```

戻り値:

- `session_id`
- `discord_sync_status`
- `created_at`

戻り値に含めない:

- 内部user ID
- email
- Discord credential
- サーバー側credential値

`update_session_post`、`delete_or_close_session_post` は、Edge Function側actionとして先に設計し、DB RPCとして切り出すかは次工程で判断する。

初期案ではGM本人投稿の `gm_user_id` は `auth.uid()` 固定。admin代理投稿やGM差し替えは未確定事項として残し、実装前に別途確認する。

## 5. Edge Function案

Edge Function草案:

```text
docs/supabase/functions/session-post-discord-sync-draft.md
```

1 endpointで以下のactionを受ける案を第一候補にする。

```text
action = create | update | delete | close | resync
```

各actionの概要:

- `create`: DBへ新規保存し、Discordへ新規投稿する。
- `update`: DBを更新し、既存Discord投稿を編集、または更新通知を追記する。
- `close`: DB上は募集終了状態にし、Discord投稿を「募集終了」表示へ編集する。
- `delete`: 初期案では物理削除ではなく非公開化し、Discord投稿を「削除済み」表示へ編集する。
- `resync`: 失敗・不整合時に現在のDB内容からDiscordへ再送/再編集する。

Discord投稿先が通常チャンネル、フォーラムチャンネル、既存スレッド、イベントのどれになるかは未確定。実装前にユーザー確認が必要。

## 6. Discord側の削除・編集方針

比較:

- 既存メッセージ編集: 最新情報を1投稿に集約できる。編集時の第一候補。
- 変更通知追記: 変更履歴を残しやすい。重要変更や編集不可時の代替。
- 物理削除: Discord側から消せるが監査性が落ちる。初期は非推奨。
- 募集終了/削除済みへ編集: 監査性と文脈を残せる。削除/非公開時の第一候補。

初期推奨は、削除時も物理削除せず「募集終了 / 削除済み」に編集する方式。

## 7. 同期失敗時の扱い

初期方針:

- DB保存・更新は成功扱いにする。
- Discord同期失敗は `discord_sync_status = failed` として記録する。
- `discord_last_action` に失敗したactionを残す。
- `discord_sync_error` は短い概要だけを保存する。
- GM/admin画面から `resync` できる余地を残す。

外部API呼び出しを含むため、DB保存とDiscord反映を完全な単一トランザクションにしない。

## 8. Discord本文案

最低限含める:

- タイトル
- 開催日
- 開催時刻
- 申請締切
- 種別
- レベル帯（将来、カレンダー側算出値またはDB側値が使える場合）
- 募集人数
- 概要（依頼書本文）
- 詳細ページURL

含めない:

- 内部user ID
- email
- Discord投稿credential
- サーバー側credential値
- 内部application/comment ID
- 承認済み参加者のDiscord ID

## 9. data/sessions.jsonとの併用方針

次工程の表示統合では、しばらく静的 `data/sessions.json` とSupabase `sessions` を併用する。

案:

1. `data/sessions.json` を既存静的予定として読み込む。
2. Supabase `sessions` から公開投稿セッションを読み込む。
3. Supabase行を既存 `sessionDisplay.js` 用camelCaseへ変換する。
4. `id` で重複排除する。
5. 同じ `id` がある場合はSupabase側を優先する。
6. calendarではマージ後の配列を日付ごとに表示する。
7. `session-detail?id=...` では、まず静的/DBマージ後の対象を探す。投稿セッションだけでも詳細を開けるようにする。

ID重複防止:

- 投稿時の `id` はサーバー側生成を優先する。
- 既存静的IDと衝突しないことをDB側で確認する。
- URL互換のためtext idを維持する。

将来、投稿セッションが正本化できたら、`data/sessions.json` は初期データまたは移行前互換へ縮小する。

## 10. テンプレート保存との関係

テンプレート保存は今回実装しない。

後続:

- M-15A: `request_templates` SQL草案。
- M-15B: mypage/GM管理画面でテンプレート保存。
- M-15C: 投稿フォームへテンプレート挿入。

テンプレートは下書き補助であり、投稿済み依頼書の正本は `sessions`。

## 11. まだやらないこと

- SQL Editor実行。
- DB変更。
- Edge Function deploy。
- Discord実送信。
- フロント実装。
- credential値の記録。
- `updates.json` 変更。
- commit / push。

## 12. M-14C preflight follow-up

M-14C / 015 preflight中に、`public.sessions` だけでなくpublic schema内の複数テーブルで `anon` / `authenticated` に `TRUNCATE` 権限が見えていた。

ユーザーがSupabase SQL Editorで `TRUNCATE` だけをrevoke済み。`SELECT` / `INSERT` / `UPDATE` / `DELETE` は今回触っていない。確認クエリでは `anon` / `authenticated` の `TRUNCATE` 権限が0件になった。

`postgres` などの管理者系ロール側の権限は対象外。TRUNCATE権限整理時点では `015_session_posting_rpc_draft.sql` のapplyは未実行だった。

詳細は `docs/supabase-public-truncate-privilege-cleanup-result.md` に記録済み。

## 13. M-14C SQL apply result

ユーザーが `docs/supabase/sql/015_session_posting_rpc_draft.sql` のapply sectionをSupabase SQL Editorで実行し、`Success. No rows returned` で通過済み。

`public.sessions` の `session_type` / `application_deadline` / Discord同期メタデータ列、check制約、`create_session_post(...)` RPC、grantを確認済み。M-14C apply直後時点では、`create_session_post(...)` の実行テスト、Edge Function deploy、Discord実送信、フロント実装は未実施だった。

`015_session_posting_rpc_draft.sql` のapply sectionは適用済みのため、通常運用では同じapply sectionをそのまま再実行しない。詳細は `docs/session-posting-rpc-apply-result.md` に記録済み。

## 14. M-14D-1 hidden draft execution test

`dev/run-create-session-post-test.mjs` で、GM認証文脈から `create_session_post(...)` のhidden draft最小実行を確認済み。通常実行ではSKIPし、明示フラグ付きの1回実行で `discord_sync_status = skipped`、作成行は `status = draft` / `visibility = hidden` / `session_type = one-shot`、anonからpublic表示対象として見えないことを確認した。

このテストで作成されたhidden draft rowは削除していない。Edge Function deploy、Discord実送信、SQL EditorでのRPC直接実行、DB構造変更、フロント実装は行っていない。

詳細は `docs/session-posting-rpc-execution-test-result.md` に記録済み。
## 15. M-14D-2 posting form and merged display

`session-post.html` にGM/admin向け依頼書投稿フォームを追加し、認証済みSupabase clientから `create_session_post(...)` を呼ぶ。
初期値は `visibility = hidden` / `status = draft` / `sessionType = one-shot` とし、公開保存時は確認チェックを要求する。
成功時の画面表示は `session_id` と `discord_sync_status` のみに限定する。
グローバルメニューの `POST` は削除し、投稿導線はcalendarの日付セル内の `＋依頼書` から `session-post.html?date=YYYY-MM-DD` へ遷移する形にした。
`date` queryがある場合は開始日時欄へ日付を初期反映する。
フォーム上は `開催日` / `開始時刻` を `開始日時` に統合し、送信時に `p_session_date` / `p_start_time` へ分解する。
`終了時刻` は `終了日時` に変更し、送信時は時刻部分だけを `p_end_time` として送る。
現DB/RPCは終了日を保持しないため、日跨ぎ終了日時は投稿前バリデーションで止める。
日跨ぎ対応は将来 `end_date` または `end_at` を追加する工程で扱う。
`レベル帯` 欄は削除し、`p_level_range` は `null` にする。
依頼書本文は概要欄へ記載する運用にし、フォームの `依頼書本文` 欄と `参加条件` 欄は削除した。
RPC送信時の `p_request_body` / `p_requirements` は `null` にする。

calendar / session-detail は `data/sessions.json` とSupabase `public.sessions` の公開表示対象をマージして読む。
Supabase側は `gm_user_id` を取得せず、`session_type` / `application_deadline` を既存表示用の `sessionType` / `applicationDeadline` に正規化する。
同一IDは静的JSON側を優先する。

Discord実送信はまだ行わず、RPC戻り値の同期状態表示に留める。
詳細は `docs/session-posting-form-result.md` に記録済み。

## 16. M-14D-3 end_at draft

M-14D-2の投稿フォームは `開始日時` / `終了日時` UIに整理済みだが、015適用済みのDB/RPCは終了日を保存できない。
そのため、SQL/RPCが対応するまでは日跨ぎ終了日時を投稿前バリデーションで止める。

正式対応の第一候補は `public.sessions.end_at timestamptz` を追加する差分SQL。
015は適用済みのため、同じapply sectionを通常運用で再実行せず、`docs/supabase/sql/016_session_posting_end_at_draft.sql` として扱う。

`create_session_post(...)` は既存引数順を維持し、末尾に `p_end_at text default null` を追加する案。
`p_end_at` はフォームの `datetime-local` 値をAsia/Tokyo前提で `timestamptz` 化し、`sessions.end_at` へ保存する。
互換用に `p_end_time` / `end_time` も維持し、戻り値は `session_id` / `discord_sync_status` / `created_at` のまま増やさない。

SQL/RPC適用後、フロントは `終了日時` から `p_end_at` を送信し、現在の日跨ぎブロックを解除する。
表示側は `end_at` / `endAt` を終了日時として優先し、なければ従来の `date + end_time` / `endTime` にフォールバックする。
Discord本文生成も `end_at` を優先し、日跨ぎ終了日時を正しく表示する。

この草案作成ではSQL Editor実行、DB変更、Edge Function deploy、Discord実送信、credential類の実値記録、`updates.json` 変更、commit / pushは行っていない。
