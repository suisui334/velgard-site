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

## M-14D-7b 追記

カード一覧形式とスクロール付き依頼書一覧パネルは不採用にし、`自分の依頼書` はフォーム内の `公開状態` 欄の下段、`募集状態` の右隣付近にあるselect形式へ変更した。
selectの先頭項目は `新規依頼書を書く` とし、既存依頼書は `【募集状態・公開状態】YYYY/MM/DD HH:mm タイトル` の短い選択肢として表示する。

select option の value にはSupabase row id / uuidを入れず、`manage-0`、`manage-1` のようなローカルキーだけを使う。
対象レコードはJSメモリ上の配列から取得する。

既存依頼書を選択すると、同じ `session-post.html` のメインフォームへ以下を即時反映する。

- タイトル
- 開始日時
- 終了日時
- 申請締切
- 種別
- 募集人数min
- 募集人数max
- 公開状態
- 募集状態
- 概要

巨大な `編集中: タイトル` 見出しは削除し、ページ見出しは通常どおり `依頼書` のままにする。
編集状態はselect直下の小さな補助文で示す。

編集モード中は作成ボタンをdisabledにし、`create_session_post(...)` を呼ばない。
selectの `新規依頼書を書く` で選択解除、フォーム初期化、URLの `id` 除去を行い、新規作成モードへ戻れる。
編集保存・公開切替・削除・募集終了は次工程。
内部ユーザーID、email、token、key、secret、Discord credential、Webhook URL、bot token、service_role、Supabase row id / uuidは取得・表示しない。

詳細は `docs/session-posting-manage-detail-result.md` に分離済み。

## M-14D-7c 追記

M-14D-7bのselect化後、`募集状態` と `概要` が下へ押し下げられるレイアウト崩れがあったため、`自分の依頼書` selectを通常フォーム項目として再配置した。
フォーム下部は `募集人数 max` / `公開状態`、`募集状態` / `自分の依頼書`、その下に全幅の `概要` となる。

カード一覧時代の大型パネル余白、スクロール付き一覧、固定的な高さ指定は復活させない。
SQL Editor実行、DB構造変更、Discord実送信、secret類の出力は行っていない。

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
