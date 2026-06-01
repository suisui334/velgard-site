# M-14D-6 GM/admin向け 自分の依頼書一覧

## 実装概要

`session-post.html` にGM/admin向けの `自分の依頼書` 一覧を追加した。
hidden/draftは公開calendarには出ないため、GM/adminが保存済みの依頼書を確認できる管理導線として扱う。

一覧はログイン済みかつGM/admin判定が通った場合だけ表示する。
未ログインまたは通常PLには投稿フォームと同じく一覧を表示しない。

M-14D-6bでcalendar側の常設 `自分の依頼書` 導線は削除し、依頼書一覧は `session-post.html` 内へ集約した。
calendarの日付セルにある `＋依頼書` 導線は維持し、`session-post.html?date=YYYY-MM-DD` へ遷移できる。
`session-post.html` からは既存の `CALENDARへ` 導線で戻れる。

## 取得方針

認証済みSupabase clientから `public.sessions` をSELECTする。
取得列は一覧表示に必要な以下だけに限定する。

- `id`
- `title`
- `date`
- `start_time`
- `end_time`
- `end_at`
- `visibility`
- `status`
- `discord_sync_status`
- `created_at`

`gm_user_id`、email、user_id全文、token、key、secret、Discord credential類は取得・表示しない。
GM本人はRLSで自分のsessionsのみ、adminはadmin policyで見える範囲を表示する想定。

## 表示内容

一覧に表示する情報:

- タイトル
- 開催日時
- 終了日時
- 公開状態
- 募集状態
- Discord同期状態
- 作成日時
- 詳細を見る

`hidden` / `private` / `public` と、`draft` / `tentative` / `recruiting` / `closed` / `finished` / `canceled` を含め、まず表示だけ行う。
状態変更、削除、募集終了、公開切替は実装していない。

## 詳細/編集導線

`詳細を見る` は `session-post.html?id=SESSION_ID#my-sessions` へ向ける。
今回は一覧表示までで、下書き詳細表示、編集、削除、公開切替は次工程。
通常の公開 `session-detail.html?id=...` ではhidden/draftが見えない可能性があるため、管理専用詳細または編集画面として後続対応する。

## 未実装

- 下書き詳細表示
- 下書き編集
- 公開切替
- 削除/募集終了
- Discord実送信
- テンプレート保存

テンプレート保存はM-15系で扱う。

## 安全確認

- SQL Editorは実行していない。
- DB構造変更はしていない。
- Edge Function deployはしていない。
- Discord実送信はしていない。
- public/recruiting投稿は実行していない。
- Webhook URL、bot token、service_role key、secret類の実値は記録していない。
- email、user_id全文、gmUserId、token、keyは画面・console・docsへ出していない。
- `updates.json` は変更していない。
- commit / pushはしていない。
