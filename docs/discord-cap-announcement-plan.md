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
- `docs/supabase/sql/051_admin_discord_announcements_post_apply_select_only.sql`: SQL Apply後に使うSELECT-only確認SQL。
- `supabase/functions/dispatch-admin-cap-announcements/index.ts`: 未deployのEdge Function draft。
- `mypage` admin専用導線: `is_admin()` がtrueの時だけ表示する。

## SQL Apply前準備バッチ

`4b56ff2 Refocus Discord scheduling on admin cap announcements` を祖先として含む現行ツリー上で、SQL Apply前の非破壊準備をまとめて実施する。

確認・整理した内容:

- 現行ファイル名は `admin-cap-announcements` / `AdminCapAnnouncement` / `admin_discord_announcements` 系へ統一する。
- 汎用リマインダー用のページ、JS、docs、SQL draftは現行実装として残さない。
- `admin-cap-announcements.html` はadmin権限確認後だけフォームを表示する。
- `mypage` の導線は `is_admin()` がtrueの場合だけ追加する。
- URL直開きで未ログインまたは非adminの場合、フォームを表示しない。
- `050_admin_discord_announcements_schema_apply_draft.sql` は `DO NOT RUN` / `NOT EXECUTED` の未実行draftとして維持する。
- `051_admin_discord_announcements_post_apply_select_only.sql` はDB変更を行わず、`check_name / status / result_value / note` の形式で確認する。
- Edge Function draftはdeployしない。Webhook URL実値、JWT、Supabase URL全文、Discord ID、token類は置かない。

## 050/051結果と052準備

050 SQL Applyはユーザー操作を含む明示ゲートで一度だけ実行され、成功扱いとする。続けて051 SELECT-only確認を行い、テーブル、RLS、CHECK、テーブル権限、direct write policy不在はOKだった。

051で停止した理由:

- `browser_admin_rpc_exists`: `missing 0/4`。
- `server_rpc_exists`: `missing 0/2`。
- RPC未作成に起因する `review` が複数出た。
- ルール通り、Edge Function deploy、Discord投稿、secret/env設定、cron設定、フロントRPC接続確認へは進まなかった。

052 RPC追加SQL draft:

- `docs/supabase/sql/052_admin_discord_announcements_rpc_apply_draft.sql` を未実行draftとして追加する。
- 冒頭に `DO NOT RUN` / `NOT EXECUTED` / 明示承認必須を残す。
- 050 apply後に実行するRPC追加SQLとして扱う。
- 051でRPC missing/reviewが出たため追加する。
- `admin_discord_announcements` の成功記録用に任意の `discord_message_id` 列案も含める。ただしブラウザ一覧RPCでは返さず、Webhook URL、チャンネルID、secret、raw external response bodyは保存・返却しない。

052で追加するbrowser/admin用RPC:

- `create_admin_discord_announcement`: adminのみ作成。`status` は `draft` / `scheduled`、`announcement_type='cap_update'`、`target_channel_key='cap_announcement'`、`mention_mode` は `none` / `everyone`。
- `update_admin_discord_announcement`: adminのみ更新。既存 `draft` / `scheduled` / `failed` だけを編集可能にし、`processing` / `posted` / `canceled` は更新不可。
- `cancel_admin_discord_announcement`: adminのみ取消。`draft` / `scheduled` / `failed` だけを `canceled` にでき、`processing` / `posted` は不可。
- `list_admin_discord_announcements`: adminのみ一覧取得。Webhook URL、secret、実チャンネル値、raw external response、外部メッセージID値は返さない。

052で追加するserver/Edge用RPC:

- `claim_due_admin_discord_announcements`: service role境界でのみ実行する。期限到来の `scheduled` 行を `processing` にし、`lock_token` を設定して二重投稿を避ける。返却は配送に必要な一般化済みフィールドだけにする。
- `finalize_admin_discord_announcement`: service role境界でのみ実行する。`id + lock_token` でclaim済み行を検証し、成功なら `posted`、retry可能なら `scheduled`、終端失敗なら `failed` にする。`attempt_count`、`delivery_error_code`、`posted_at`、任意の `discord_message_id` を安全に更新する。

052 RPC共通方針:

- `security definer` と `set search_path = public` を明示する。
- browser/admin用RPCは内部で `public.is_admin()` を確認する。
- anonにはexecute権限を与えない。
- browser/admin用RPCのみ authenticated executeを付与し、server/Edge用RPCは通常authenticatedブラウザから実行できない設計にする。
- 静的JSにSupabase直接 `.insert` / `.update` / `.delete` / `.upsert` は追加しない。

052後確認SQL:

- `docs/supabase/sql/053_admin_discord_announcements_rpc_post_apply_select_only.sql` を新規追加する。
- 050確認用の051とは分け、052 apply後のRPC確認専用にする。
- `check_name / status / result_value / note` 形式を維持する。
- browser/admin用RPC 4本、server/Edge用RPC 2本、anon不可、authenticated権限、service role境界、`security definer`、`search_path`、admin確認、claim/finalize契約、`post_apply_ready_for_next_gate` を確認する。

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

Edge Function側で想定するserver-only RPC名:

- `claim_due_admin_discord_announcements`
- `finalize_admin_discord_announcement`

server-only RPC方針:

- 通常のブラウザ呼び出しにはgrantしない。
- claimは期限到来の `scheduled` 行だけを `processing` にし、`lock_token` と配送に必要な一般化済みフィールドだけを返す。
- finalizeは `id + lock_token` でのみ更新し、成功時は `posted`、retry可能な失敗時は `scheduled`、終端失敗時は `failed` にする。
- Webhook URL、Discord ID、raw external response bodyは返さない。

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
- `discord_message_id`: 投稿成功時の外部メッセージ識別子。ブラウザ一覧RPCでは返さず、値の記録・表示は最小化する。
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

draftファイル:

- `supabase/functions/dispatch-admin-cap-announcements/index.ts`

処理案:

1. cronからEdge Functionを起動する。
2. Edge Functionがclaim RPCを呼ぶ。
3. claim RPCは `announcement_type='cap_update'`、`status='scheduled'`、期限到来の行だけを `processing` に更新し、`lock_token` と対象行を返す。
4. Edge Functionは `target_channel_key` から環境変数名を選ぶ。
5. Edge Functionは `mention_mode` に応じてDiscord payloadを組み立てる。
6. Discord送信成功時、finalize RPCで `posted` に更新する。
7. 失敗時、一般化したエラーコードとエラー有無だけを保存し、retry可能なら `scheduled` に戻して `next_attempt_at` を設定する。
8. `max_attempts` 到達後は `failed` にする。

draft安全設計:

- 既定はdry-run相当で、DB mutationとDiscord送信を行わない。
- 実送信は別途明示ゲート、secret/env設定、cron認証設計、deployレビューが完了するまで有効化しない。
- `target_channel_key='cap_announcement'` のみを許可し、secret/env名候補 `DISCORD_WEBHOOK_CAP_ANNOUNCEMENT` に対応させる。
- `mention_mode='none'` は `allowed_mentions.parse=[]`。
- `mention_mode='everyone'` のみ `@everyone` 行と `allowed_mentions.parse=["everyone"]` を許可する。
- ログやレスポンスにはWebhook URL、Discord ID、raw token、raw external responseを出さない。

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

1. `docs/supabase/sql/052_admin_discord_announcements_rpc_apply_draft.sql` をレビューする。
2. ファイル冒頭の `DO NOT RUN` / `NOT EXECUTED` / 明示承認必須を確認し、今回の実行対象として明示承認を得る。
3. SQL Editorの旧内容を消して、052だけを貼る。
4. ユーザー明示承認後に一度だけ実行する。
5. エラーが出たら停止し、rerunしない。
6. 052成功後、`docs/supabase/sql/053_admin_discord_announcements_rpc_post_apply_select_only.sql` をSELECT-onlyで実行する。
7. 053の結果が `missing` / `review` / `error` を含む場合は、Edge Function deployやフロントRPC接続へ進まず停止する。
