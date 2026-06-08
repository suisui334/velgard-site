# adminキャップ更新告知Discord予約投稿MVP計画

## 方針転換

当初のDiscord予約投稿案は、汎用リマインダーではなく、admin専用のキャップ更新告知機能へ方針転換する。

作らないもの:

- 卓ごとのリマインド。
- GM/PL向けの自由なリマインド作成。
- 一般ユーザーが作る予約投稿。
- 複数用途の自由なDiscord予約投稿。
- チャンネルURLやWebhook URLの自由入力。
- Discord Bot本体やスラッシュコマンド。

作るもの:

- adminがキャップ更新告知を作成する。
- 告知タイトル、告知本文、投稿予定日時、投稿先チャンネルkey、メンション設定を保存する。
- 指定時刻にEdge Function + cronがDiscord Webhookへ投稿する。
- 投稿成功/失敗とエラー有無をadmin管理画面で確認できる設計にする。

## 今回の範囲

今回は低リスク工程のみで、SQL Editor実行、DB/RPC/RLSの実適用、Edge Function deploy、Discord投稿、secret設定は行わない。

追加・変更したもの:

- `admin-cap-announcements.html`: admin専用キャップ更新告知ページ。
- `assets/js/renderAdminCapAnnouncements.js`: admin確認後だけ表示する入力・payload確認UI。
- `assets/js/adminCapAnnouncementClient.js`: 将来RPC接続する関数名とpayload構造。
- `docs/supabase/sql/050_admin_discord_announcements_schema_apply_draft.sql`: 未実行apply draft。
- `mypage` admin専用導線: `is_admin()` がtrueの時だけ表示する。

## UI仕様

専用ページ名は `admin-cap-announcements.html` とする。公開グローバルナビには追加しない。

表示制御:

- Supabase接続設定がない場合は操作不可。
- 未ログインの場合は操作不可。
- `is_admin()` がtrueでない場合は「権限がありません」と表示し、フォームを出さない。
- adminログイン時だけ入力フォームを表示する。
- `mypage` の導線もadmin時だけ表示する。

重要な前提:

- フロント側で隠すだけではセキュリティにならない。
- DB/RPC/Edge Function側でも必ずadmin確認を行う。
- RPCは `is_admin()` または同等のreviewed helperでadminを確認する。
- Edge Functionのclaim/finalize処理もサーバー側境界で対象用途と状態を検証する。

入力項目:

- 告知タイトル。
- 告知本文。
- 投稿予定日時。
- 投稿先チャンネルkey。
- メンション設定: `none` / `everyone`。
- 保存状態: `draft` / `scheduled`。
- 将来の自動生成を見据えた任意項目: キャップLv、適用開始日、適用終了日、補足文。

今回の画面動作:

- 入力値を検証する。
- 将来RPC `create_admin_discord_announcement` に渡すpayloadを表示する。
- DB保存はまだ実行しない。
- Supabase直接 `.insert` / `.update` / `.delete` / `.upsert` は使わない。

## 投稿先チャンネル方針

- Webhook URLをフロント、静的JS、docsに書かない。
- DBにもWebhook URLそのものは保存しない。
- DBには `target_channel_key` のみ保存する。
- 最初の候補は `cap_announcement` とする。
- Edge Function側で `target_channel_key` とsecret/envを対応させる。

対応案:

- `cap_announcement` -> Edge Function secret/env `DISCORD_WEBHOOK_CAP_ANNOUNCEMENT`

上記は環境変数名の設計であり、実値は記録しない。

## メンション方針

- `mention_mode` は `none` / `everyone` の2択。
- `mention_mode=none` の場合、Discord投稿時は `allowed_mentions.parse=[]` とする。
- `mention_mode=none` では本文中に `@everyone` が含まれていても通知させない。
- `mention_mode=everyone` の場合のみ、本文冒頭などに `@everyone` を入れ、`allowed_mentions.parse=["everyone"]` を許可する。
- 通知暴発防止を優先し、既存Discord同期実装と同じく明示選択時のみeveryoneを許可する。

## RPC案

静的JS側で揃えたRPC名:

- `create_admin_discord_announcement`
- `update_admin_discord_announcement`
- `cancel_admin_discord_announcement`
- `list_admin_discord_announcements`

作成payload案:

```json
{
  "p_announcement_title": "キャップ更新のお知らせ",
  "p_announcement_body": "次回からキャップLvが更新されます。",
  "p_target_channel_key": "cap_announcement",
  "p_scheduled_at": "2026-06-08T21:00",
  "p_timezone": "Asia/Tokyo",
  "p_mention_mode": "none",
  "p_status": "draft",
  "p_cap_level": "Lv7-8",
  "p_apply_start_date": "2026-06-09",
  "p_apply_end_date": "",
  "p_note": "運用メモ"
}
```

RPC方針:

- 全RPCはadmin限定。
- ブラウザからの作成・更新・取消・一覧はRPC経由に限定する。
- direct table write用のRLS policyは作らない方針でレビューする。
- `draft` は投稿対象外。
- `scheduled` のみclaim対象。
- `processing` / `posted` / `failed` / `canceled` は状態管理・管理画面表示の対象。

## DB案

`admin_discord_announcements` テーブル案:

- `id`: 告知予約ID。
- `created_by`: 作成adminユーザー。
- `announcement_type`: MVPでは `cap_update` 固定。
- `announcement_title`: 告知タイトル。
- `announcement_body`: 告知本文。
- `target_channel_key`: 投稿先管理キー。
- `scheduled_at`: 投稿予定時刻。
- `timezone`: 表示・入力基準。
- `mention_mode`: `none` / `everyone`。
- `status`: `draft` / `scheduled` / `processing` / `posted` / `failed` / `canceled`。
- `cap_level`, `apply_start_date`, `apply_end_date`, `note`: 将来の自動生成・運用補助用。
- `attempt_count`, `max_attempts`, `next_attempt_at`: retry管理。
- `locked_at`, `lock_token`: 二重投稿防止のclaim情報。
- `posted_at`: 投稿完了時刻。
- `delivery_error_code`, `delivery_error_at`: 一般化した失敗情報。
- `created_at`, `updated_at`: 監査用時刻。

RLS/RPC方針:

- RLSは有効化する。
- 読み取りも書き込みもadmin限定RPCを基本にする。
- 直接insert/update/delete policyは追加しない。
- SELECT policyを追加する場合もadmin限定にする。
- Edge Function用のclaim/finalize RPCはservice role相当のサーバー側境界で扱う。

## Edge Function案

Edge FunctionはWebhook型で実装する。Webhook credentialはEdge Functionのsecretとして扱い、ブラウザ、静的JS、docs、DBに置かない。

処理案:

1. cronからEdge Functionを起動する。
2. Edge Functionがclaim RPCを呼ぶ。
3. claim RPCは `announcement_type='cap_update'`、`status='scheduled'`、期限到来の行だけを `processing` に更新し、`lock_token` と対象行を返す。
4. Edge Functionは `target_channel_key` から環境変数名を選ぶ。
5. Edge Functionは `mention_mode` に応じてDiscord payloadを組み立てる。
6. Discord送信成功時、finalize RPCで `posted` に更新する。
7. 失敗時、一般化したエラーコードとエラー有無だけを保存し、retry可能なら `scheduled` に戻して `next_attempt_at` を設定する。
8. `max_attempts` 到達後は `failed` にする。

## cron案

- 1分間隔でEdge Functionを起動する案を第一候補にする。
- 1回の起動で少数件をclaimし、長時間処理を避ける。
- 実cron設定は危険工程として、deploy後の独立ゲートで行う。

## 安全ゲート

今回実施しない危険工程:

- SQL Editor実行。
- DB/RPC/RLS変更の実適用。
- Edge Function deploy。
- Discord投稿。
- secret設定/変更。
- Webhook URLの記録。
- JWT、Supabase URL全文、Discord ID、token類の記録。
- `dry_run=false` 実行。

次に必要なSQL applyゲート:

1. `docs/supabase/sql/050_admin_discord_announcements_schema_apply_draft.sql` をレビューする。
2. SQL Editorの旧内容を消して、050だけを貼る。
3. ユーザー明示承認後に一度だけ実行する。
4. エラーが出たら停止し、rerunしない。
5. 適用後、SELECT-only確認SQLを別途作成してテーブル・CHECK・RLS・grant・admin限定RPC方針を確認する。
