# M-14A セッション予定投稿＋Discord同期 全体設計

## 1. 目的

GM/adminがサイト上からセッション予定、つまり依頼書を投稿できるようにする。

投稿された依頼書はサイト上のセッション予定として保存し、Discordの専用投稿先にもサーバー側から同期する。GitHub Pages上のフロントだけでは `data/sessions.json` を更新できないため、投稿セッションの正本はSupabaseへ寄せる。

この工程では調査と最小設計のみを行う。フロント実装、SQL Editor実行、DB変更、Discord送信、credential値の記録は行わない。

## 2. 現在のセッション表示構造

現行の静的セッション表示は `data/sessions.json` が正本。

主な表示経路:

- `calendar.html` は `assets/js/main.js` 経由で `assets/js/renderCalendar.js` を呼ぶ。
- `renderCalendar.js` は `data/sessions.json` を読み、`visibility === "public"` かつ `status !== "draft"` の予定をカレンダーセルと選択日一覧へ表示する。
- `session-detail.html` は `assets/js/main.js` 経由で `assets/js/renderSessionDetail.js` を呼ぶ。
- `renderSessionDetail.js` はURLの `id` で `data/sessions.json` から対象セッションを探し、`renderSessionDetailContent(session, { mode: "page" })` で詳細本文を描画する。
- `assets/js/sessionDisplay.js` は、タイトル、状態、種別、開催時刻、申請締切、人数、概要、詳細、参加希望コメント枠などの共通表示を持つ。

現在表示に使っている主なフィールド:

| 表示用フィールド | 用途 |
| --- | --- |
| `id` | 詳細URL、Supabase RPCの `target_session_id` |
| `title` | カレンダーセル、選択日一覧、詳細見出し |
| `date` | カレンダー分類、詳細の開催日 |
| `startTime` / `endTime` | 開催時刻。申請締切には流用しない |
| `applicationDeadline` | 申請締切。未設定時は `未定` |
| `sessionType` | 固定分類。`one-shot` / `campaign` / `special` / `other` |
| `gmName` | calendar側のGM表示。session-detail基本情報では固定表示しない |
| `gmUserId` | 将来の権限・同期用。画面には出さない |
| `status` | 募集状態。`closed` は締切表示、`finished` / `canceled` は読み取り寄り |
| `levelRange` | レベル帯 |
| `playerMin` / `playerMax` / `playerCount` | 募集人数表示 |
| `summary` / `detail` / `requirements` | 概要、詳細、参加条件 |
| `tags` | calendarカードでは既存表示あり。session-detailでは自由タグ非表示を維持 |
| `visibility` | publicのみ通常表示 |
| `updatedAt` | 詳細の補足情報 |

`session-detail.html` の参加希望コメント、本人投稿、編集、削除、辞退、GM履歴、承認/却下、GM Discord連絡先はSupabase RPCを使う。これらは静的 `data/sessions.json` の本文情報とは別に、同じ `session.id` を `target_session_id` として参照している。

## 3. data/sessions.json と Supabase sessions の関係

現状:

- カレンダーとセッション詳細の予定本文は `data/sessions.json` を読む。
- 参加希望コメント、申請状態、GM履歴、承認/却下、GM連絡先はSupabase側の `sessions.id` / `session_applications.session_id` と連動する。
- M-10以降、DB側 `sessions.id` と `data/sessions.json` の `sessions[].id` を合わせることで、mypageやsession-detailの連携を成立させている。

既存SQL草案の `public.sessions` は、`id` / `title` / `date` / `start_time` / `end_time` / `gm_user_id` / `gm_name` / `status` / `level_range` / `player_min` / `player_max` / `summary` / `detail` / `requirements` / `visibility` / `created_at` / `updated_at` を持つ。

ただし、M-13A/M-13Bで追加した `sessionType` と `applicationDeadline` は、既存SQL草案にはまだ対応列がない。投稿機能を実装する前に、Supabase側へ `session_type` と `application_deadline` 相当を追加する設計・SQLレビューが必要。

## 4. 投稿先DB案

第一候補は既存 `public.sessions` を使う。

理由:

- `session_comments` と `session_applications` がすでに `sessions.id` を外部キーとして参照している。
- `is_session_gm(target_session_id)` 系のGM判定が `sessions.gm_user_id` を軸にしている。
- mypage、session-detail、GM履歴、GM Discord連絡先が同じ `session_id` を前提に動いている。
- 新テーブルを正本にすると、既存RPC群との接続や二重管理が増える。

追加候補列:

| DB列候補 | 表示用フィールド | 備考 |
| --- | --- | --- |
| `session_type text` | `sessionType` | check制約で `one-shot` / `campaign` / `special` / `other` |
| `application_deadline timestamptz` | `applicationDeadline` | Japan timeで表示する。DBには時区付きで保存する案 |
| `request_body text` または既存 `detail` | `detail` / `body` | 依頼書本文。既存 `detail` を使うなら列追加不要 |
| `discord_sync_status text` | 画面には原則出さない | `not_required` / `pending` / `posted` / `failed` など |
| `discord_last_action text` | 画面には原則出さない | `create` / `update` / `delete` / `close` / `resync` |
| `discord_message_id text` | 画面には原則出さない | 既存投稿の編集・削除・再同期に使う |
| `discord_channel_id text` | 画面には原則出さない | 投稿先識別子 |
| `discord_thread_id text` | 画面には原則出さない | フォーラム/スレッド運用時の識別子 |
| `discord_synced_at timestamptz` | 画面には原則出さない | 同期完了日時 |

Discord投稿メタデータは、初期は `sessions` に直列で持てる。ただし、将来の再送、編集、削除/非公開化、複数投稿先、同期履歴監査まで考えるなら別テーブル案を優先する。

別テーブル案:

```text
session_discord_posts
```

列候補:

- `id uuid`
- `session_id text`
- `destination_type text`
- `discord_message_id text`
- `discord_channel_id text`
- `discord_thread_id text`
- `discord_post_url text`
- `sync_status text`
- `error_summary text`
- `created_at`
- `updated_at`

このテーブルにもDiscord投稿credentialは保存しない。保存するのは投稿結果の識別子と状態だけ。

## 5. 投稿フィールド案

投稿フォームからサーバーへ送る候補:

- `title`
- `date`
- `startTime`
- `endTime`
- `applicationDeadline`
- `sessionType`
- `levelRange`
- `playerMin`
- `playerMax`
- `summary`
- `detail` または `requestBody`
- `requirements`
- `status`
- `visibility`

サーバー側で補完・固定する候補:

- `id`: サーバー側で生成。既存URL互換のためtext idを維持する案。
- `gm_user_id`: 原則 `auth.uid()`。通常GMが他人のIDを指定できないようにする。
- `gm_name`: `public_profiles.display_name` などから取得。入力欄で自由に他人を名乗らせない。
- `created_at` / `updated_at`: DBで自動管理。

注意点:

- `startTime` / `endTime` は開催時刻であり、申請締切には流用しない。
- 既存DB草案の `end_time time` は `24:00` と相性が悪い。実装前に `24:00` を許可しない、`00:00` + 別日扱いにする、表示用text列へ寄せる、などの方針確認が必要。
- `playerCount` は投稿時に保存せず、承認済み申請数から算出する方針を優先する。
- `tags` はセッション種別には使わない。自由タグを投稿フォームに入れるかは別工程で判断する。

## 6. Discord同期案

Discord投稿credentialはフロントへ置かない。GitHub Pagesに置いた値は公開値になるため、Discord投稿権限を第三者に渡すことになる。

推奨構成:

```text
GM/adminが投稿フォーム送信
↓
Supabase Edge Functionへ送信
↓
Edge FunctionがログインユーザーとGM/admin権限を確認
↓
DBへ public.sessions 行を保存
↓
Edge Functionがサーバー側credentialでDiscordへ投稿
↓
投稿結果を session_discord_posts 等へ記録
```

Edge Functionを推奨する理由:

- Discord投稿credentialをSupabase側の管理領域に閉じ込められる。
- 投稿権限チェック、DB保存、Discord送信、失敗時の記録をサーバー側で一貫して扱える。
- フロントは公開可能なSupabase anon keyだけでよく、Discord権限を持たない。

同期対象は新規作成だけに限定しない。依頼書のライフサイクルに合わせて以下を扱う。

| 操作 | DB側 | Discord側 |
| --- | --- | --- |
| 作成 | `sessions` 新規保存 | 専用投稿先へ新規投稿 |
| 編集 | `sessions` 既存行更新 | 既存投稿を編集、または更新通知を追記 |
| 削除/非公開 | 物理削除より `visibility = hidden` 等を優先 | 投稿削除、または「削除済み」表示へ編集 |
| 募集終了 | `status = closed` 等へ更新 | 「募集終了」表示へ編集、または終了通知を追記 |
| 再同期 | 既存行を再取得 | 失敗後に再送/再編集 |

Edge Functionは `action = create / update / delete / close / resync` を受け取る1 endpoint案を第一候補にする。関数を分ける場合も、同じ権限確認・Discord本文生成・失敗記録ロジックを共有する。

DB保存とDiscord投稿の扱い:

- 推奨は「DB保存を先に成功させ、Discord投稿失敗時はDBを残して `failed` として記録」。
- 理由は、Discord障害で依頼書本文そのものが失われるのを避けるため。
- 失敗時はGM/admin向けに再同期ボタンを将来用意する。
- Discord投稿成功時は `posted` とし、message id / post url等を保存する。

DB保存とDiscord投稿を完全な1トランザクションにはできない。外部API呼び出しを含むため、失敗記録と再試行設計を前提にする。

## 6.1 Discord側の反映方式

A. 既存メッセージを編集する:

- 利点: 最新の依頼書情報を1投稿に集約できる。
- 懸念: 変更履歴がDiscord上で追いにくい場合がある。
- 初期推奨: 編集時の第一候補。

B. 変更通知を追記投稿する:

- 利点: 変更履歴が残る。
- 懸念: 投稿が増えて流れやすい。
- 初期推奨: 重要変更時、または既存投稿編集不可の場合の代替。

C. 削除時はDiscordメッセージも削除する:

- 利点: Discord側から依頼書を消せる。
- 懸念: 監査性が落ち、参照文脈が消える。
- 初期推奨: 原則非推奨。運用希望が明確な場合だけ選択。

D. 削除時は「募集終了 / 削除済み」に編集する:

- 利点: 監査性とリンク文脈を残せる。
- 懸念: 痕跡は残る。
- 初期推奨: 削除/非公開/close時の第一候補。

## 7. Discord投稿先の確認事項

「専用タブ」が具体的に以下のどれかは実装前にユーザー確認が必要。

- 通常のテキストチャンネルへWebhook投稿
- フォーラムチャンネルへスレッド付き投稿
- 既存スレッドへ投稿
- Discordイベント作成
- botで複数投稿先を制御

最小実装は通常チャンネルまたは既存スレッドへの1メッセージ投稿が最も単純。フォーラムチャンネルを使う場合は、投稿作成APIやタグ運用、スレッドID保存を別途設計する。

## 8. Discord投稿本文案

Discord本文には公開してよい情報だけを入れる。

案:

```text
【依頼書】{title}

種別: {sessionTypeLabel}
開催日: {date}
開催時刻: {startTime}〜{endTime}
申請締切: {applicationDeadline}
レベル帯: {levelRange}
募集人数: {playerMin}〜{playerMax}名
GM: {gmName}

概要:
{summary}

詳細:
{detail}

参加希望・詳細:
{publicSessionDetailUrl}
```

本文に入れないもの:

- email
- `user_id` 全文
- internal `application_id`
- internal `comment_id`
- Discord投稿credential
- サーバー側credential
- credential値
- 承認済み参加者のDiscord ID

## 9. 投稿権限

投稿可能:

- `admin`
- `gm`

不可:

- 未ログイン
- anon
- 通常PL

権限確認案:

- Edge FunctionでJWTを検証する。
- `user_roles` または既存の `is_admin()` 相当を確認する。
- GM投稿時の `gm_user_id` は原則 `auth.uid()` に固定する。
- adminだけは代理投稿・GM指定を許可する余地を残す。ただし初回実装では本人GM投稿だけに絞る方が安全。

## 10. テンプレート保存との関係

テンプレート保存は今回実装しない。

ただし、投稿フォームのpayloadは将来テンプレートを流し込める形に寄せる。

将来工程案:

- M-15A: `request_templates` テーブル設計。`owner_user_id`、`title`、`session_type`、`level_range`、`summary`、`detail`、`requirements` などを保存。
- M-15B: mypageまたはGM管理画面でテンプレート保存・編集。
- M-15C: 投稿フォームへテンプレート呼び出し。

テンプレートはあくまで下書き補助で、投稿済みセッションの正本は `sessions` に保存する。

## 11. 実装段階案

1. M-14B: DB/RPC/Edge Function詳細設計とSQL草案作成。
2. M-14C: `sessions` 追加列、Discord同期メタデータ、必要なら `session_discord_posts` 草案レビュー。
3. M-14D: Edge Function草案。`create` / `update` / `delete` / `close` / `resync` を扱う。
4. M-14E: GM/admin投稿フォームUI。未ログイン/通常PLには非表示。
5. M-14F: 投稿後にcalendar/session-detailへSupabase保存セッションを表示する読み取り統合。
6. M-14G: 編集・削除/非公開・募集終了・Discord再同期UI。
7. M-15系: 依頼書テンプレート保存。

M-14Bで追加した具体草案:

- `docs/session-posting-rpc-edge-function-plan.md`
- `docs/supabase/sql/015_session_posting_rpc_draft.sql`
- `docs/supabase/functions/session-post-discord-sync-draft.md`

## 12. まだやらないこと

- フロント実装。
- SQL Editor実行。
- DB変更。
- Edge Function作成。
- Discord投稿credential値の記録。
- Discord実投稿。
- `updates.json` 変更。
- commit / push。
