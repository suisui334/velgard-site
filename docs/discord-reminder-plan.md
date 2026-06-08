# DiscordリマインダーMVP計画

## 今回の範囲

Discordの指定時刻リマインダーを、まずWebhook型のMVPとして準備する。今回は低リスク工程のみで、SQL Editor実行、DB/RPC/RLSの実適用、Edge Function deploy、Discord投稿、secret設定は行わない。

追加したもの:

- `reminders.html`: 日本語入力の管理画面。
- `assets/js/renderDiscordReminders.js`: DB未接続でも壊れない画面骨格。
- `assets/js/discordReminderClient.js`: 将来RPC接続する関数名とpayload構造。
- `docs/supabase/sql/050_discord_reminders_schema_apply_draft.sql`: 未実行apply draft。

## MVP仕様

- 管理画面で、投稿先管理キー、投稿予定日時、タイムゾーン、通知モード、投稿テキストを入力する。
- ブラウザや静的JSにはWebhook URL、secret、実チャンネル値を置かない。
- 投稿先は `channel_key` のような論理キーで保存し、Edge Function側で安全な設定に変換する。
- 通知モードは `mention_mode` で明示する。
- `mention_mode=none` はDiscord送信時に `allowed_mentions.parse=[]` とする。
- `mention_mode=everyone` の場合だけ `allowed_mentions.parse=["everyone"]` を許可する。
- 二重投稿防止のため、予約取得はDB側のclaim RPCで `scheduled -> processing` に原子的に遷移させる。

## 画面仕様

`reminders.html` は公開ナビにはまだ追加せず、直接アクセスできる管理画面として扱う。

入力項目:

- 投稿先チャンネル: 実値ではなく管理キーを選択する。
- 投稿予定日時: `datetime-local` 入力。
- タイムゾーン: 初期値 `Asia/Tokyo`。
- 通知モード: `none` / `everyone` の明示選択。
- 投稿テキスト: 日本語本文、最大1800文字。

今回の画面動作:

- 入力値を検証する。
- 将来RPC `create_discord_reminder` に渡すpayloadを表示する。
- DB保存はまだ実行しない。
- Supabase直接 `.insert` / `.update` / `.delete` / `.upsert` は使わない。

## RPC案

静的JS側で揃えたRPC名:

- `create_discord_reminder`
- `update_discord_reminder`
- `cancel_discord_reminder`
- `list_my_discord_reminders`

作成payload案:

```json
{
  "p_channel_key": "session-reminders",
  "p_scheduled_at": "2026-06-08T21:00",
  "p_timezone": "Asia/Tokyo",
  "p_message_body": "リマインダー本文",
  "p_mention_mode": "none"
}
```

RPC方針:

- ブラウザからの作成・更新・取消はRPC経由に限定する。
- direct table write用のRLS policyは作らない方針でレビューする。
- 作成者本人は自分の予約を参照・取消できる。
- admin用の横断管理は別ゲートでreviewed RPCを追加する。
- Edge Function用のclaim/finalize RPCはservice role相当のサーバー側境界で扱う。

## DB案

`discord_reminders` テーブル案:

- `id`: 予約ID。
- `owner_user_id`: 作成ユーザー。
- `channel_key`: 投稿先管理キー。
- `scheduled_at`: 投稿予定時刻。
- `timezone`: 表示・入力基準。
- `message_body`: 投稿本文。
- `mention_mode`: `none` / `everyone`。
- `status`: `scheduled` / `processing` / `posted` / `failed` / `canceled`。
- `attempt_count`, `max_attempts`: retry管理。
- `next_attempt_at`: retry可能時刻。
- `locked_at`, `lock_token`: 二重投稿防止のclaim情報。
- `posted_at`: 投稿完了時刻。
- `delivery_error_code`: 一般化したエラーコード。
- `created_at`, `updated_at`: 監査用時刻。

RLS方針:

- RLSは有効化する。
- 読み取りは本人の予約だけを基本にする。
- 書き込みはRPC経由に限定し、直接insert/update/delete policyは追加しない。
- admin横断管理は別reviewで追加する。

## Edge Function案

Edge FunctionはWebhook型で実装する。Webhook credentialはEdge Functionのsecretとして扱い、ブラウザ、静的JS、docs、DBに置かない。

処理案:

1. cronからEdge Functionを起動する。
2. Edge Functionがclaim RPCを呼ぶ。
3. claim RPCは期限到来かつ未処理の予約を `processing` に更新し、`lock_token` と対象行を返す。
4. Edge Functionは `mention_mode` に応じてDiscord payloadを組み立てる。
5. Discord送信成功時、finalize RPCで `posted` に更新する。
6. 失敗時、一般化したエラーコードだけを保存し、retry可能なら `scheduled` に戻して `next_attempt_at` を設定する。
7. `max_attempts` 到達後は `failed` にする。

allowed_mentions方針:

- `mention_mode=none`: `{ "parse": [] }`
- `mention_mode=everyone`: `{ "parse": ["everyone"] }`
- users/rolesのparseはMVPでは使わない。

## cron案

- 1分間隔でEdge Functionを起動する案を第一候補にする。
- 1回の起動で少数件をclaimし、長時間処理を避ける。
- retry対象は `scheduled_at <= now()` かつ `next_attempt_at is null or next_attempt_at <= now()` の条件で扱う。
- 実cron設定は危険工程として、deploy後の独立ゲートで行う。

## 安全ゲート

今回実施しない危険工程:

- SQL Editor実行。
- DB/RPC/RLS変更の実適用。
- Edge Function deploy。
- Discord投稿。
- secret設定。
- Webhook URLの記録。
- 実チャンネル値の記録。
- `dry_run=false` 実行。

次に必要なSQL applyゲート:

1. `docs/supabase/sql/050_discord_reminders_schema_apply_draft.sql` をレビューする。
2. SQL Editorの旧内容を消して、050だけを貼る。
3. ユーザー明示承認後に一度だけ実行する。
4. エラーが出たら停止し、rerunしない。
5. 適用後、SELECT-only確認SQLを別途作成してテーブル・CHECK・RLS状態を確認する。
