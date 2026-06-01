# M-14D-3 依頼書投稿フォーム 日跨ぎ終了日時正式対応案

## M-14D-4 apply結果

ユーザーが `docs/supabase/sql/016_session_posting_end_at_draft.sql` のapply sectionをSupabase SQL Editorで実行し、`Success. No rows returned` で通過済み。
`public.sessions.end_at timestamptz` が追加され、`create_session_post(...)` は `p_end_at` 対応版へ差し替わった。
旧signatureをdropしてから新signatureを作成したため、`create_session_post` は1本だけであることを確認済み。

grantは `authenticated EXECUTE` と `postgres EXECUTE` のみで、`anon EXECUTE` はない。
関数定義は `security definer = true`、`volatile`、`search_path` 固定あり、戻り値は `session_id` / `discord_sync_status` / `created_at` のみ。

`016_session_posting_end_at_draft.sql` は適用済みのため、通常運用では同じapply sectionをそのまま再実行しない。
日跨ぎhidden/draft投稿テスト、フォーム側の日跨ぎ許可切替、Edge Function deploy、Discord実送信はまだ未実施。
詳細は `docs/session-posting-end-at-apply-result.md` に記録した。

## 目的

M-14D-2の依頼書投稿フォームでは `開始日時` / `終了日時` を `datetime-local` UIに整理した。
ただし現DB/RPCは `sessions.end_time` しか保持せず、終了日を保存できないため、日跨ぎ終了日時は投稿前バリデーションで止めている。

正式対応では、終了日時を日付込みで保存するため `public.sessions.end_at timestamptz` を追加する案を第一候補にする。

## SQL/RPC方針

`docs/supabase/sql/015_session_posting_rpc_draft.sql` は適用済みのため、通常運用で同じapply sectionを再実行しない。
今回の変更は差分SQL `docs/supabase/sql/016_session_posting_end_at_draft.sql` として扱う。

追加DB列案:

- `public.sessions.end_at timestamptz`

`start_at` は今回は追加しない。
開始日時は既存互換を優先し、`sessions.date` と `sessions.start_time` から組み立てる。

`create_session_post(...)` は既存引数順を維持し、末尾に `p_end_at text default null` を追加する案にした。
`p_end_at` はフォームの `datetime-local` 値をAsia/Tokyo前提で `timestamptz` 化し、`end_at` へ保存する。
`p_end_at` がある場合も互換用に `end_time` へ時刻部分を保存する。
戻り値は従来どおり `session_id` / `discord_sync_status` / `created_at` のみに限定する。

`end_at` が開始日時相当より前の場合はRPC側で拒否する。
CHECK制約は、`date + start_time`、`24:00` 互換、timezone解釈が絡むため初期案では追加しない。

## フロント方針

SQL/RPC適用までは、M-14D-2の暫定挙動として日跨ぎ終了日時を投稿前に止める。

SQL/RPC適用後は以下へ切り替える。

- 投稿フォームは `開始日時` / `終了日時` の `datetime-local` UIを維持する。
- `開始日時` から `p_session_date` / `p_start_time` を送る。
- `終了日時` から `p_end_at` を送る。
- 互換表示用として `p_end_time` も終了日時の時刻部分を送ってよい。
- 日跨ぎ終了日時の投稿前ブロックは解除する。

## 表示・Discord同期方針

表示側は、Supabase sessions読み込み時に `end_at` を取得し、既存表示用の `endAt` へ正規化する。
`sessionDisplay.js` / `renderCalendar.js` / `renderSessionDetail.js` は `end_at` / `endAt` があれば終了日時として優先し、なければ従来どおり `date + end_time` / `endTime` を使う。

Discord本文生成も `end_at` を優先し、日跨ぎ終了日時が古い `end_time` 表示だけにならないようにする。
Discord本文に内部ID、user_id全文、email、credential類は含めない。

## 未実施

- CodexはSQL Editorを追加実行していない。
- CodexはDB変更していない。
- Edge Function deployはしていない。
- Discord実送信はしていない。
- Webhook URL、bot token、service_role key、token、key、secret類の実値は記録していない。
- `updates.json` は変更していない。
- commit / pushはしていない。
