# M-14D-7b 自分の依頼書select化

## 実装概要

`session-post.html` のGM/admin向け `自分の依頼書` は、カード一覧形式やスクロール付き一覧パネルを不採用にし、フォーム内の `公開状態` 欄の下段、`募集状態` の右隣付近に置くselect形式へ変更した。

表示は小さなフォーム項目として扱う。

- ラベル: `自分の依頼書`
- 先頭項目: `新規依頼書を書く`
- 既存依頼書: `【募集状態・公開状態】YYYY/MM/DD HH:mm タイトル`

件数がある場合はラベルを `自分の依頼書（N件）` にする。
概要、長文本文、内部IDはselectには表示しない。

## ID非表示

select option の value にはSupabase row id / uuidを入れない。
option value は `manage-0`、`manage-1` のようなローカルキーだけにし、JSメモリ上の配列から対象レコードを取得する。

画面、DOM属性、console、docsに以下を出さない。

- Supabase row id
- uuid
- user_id
- email
- gmUserId
- access_token / refresh_token / JWT
- token / key / secret類
- Discord credential
- Webhook URL
- bot token
- service_role

## フォーム反映

既存依頼書をselectで選ぶと、同じ `session-post.html` のメインフォームへ即時反映する。

反映する情報:

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

`p_end_at` / `end_at` 優先の日跨ぎ終了日時対応は維持する。

## 編集モード

巨大な `編集中: タイトル` 見出しは削除し、ページ見出しは通常どおり `依頼書` のままにする。
編集状態はselect直下の小さな補助文で示す。

既存依頼書を選んでいる間は作成ボタンをdisabledにし、文言を `編集保存は次工程` にする。
Enter submitでも `create_session_post(...)` を呼ばない。

selectの先頭項目 `新規依頼書を書く` を選ぶと、選択解除、編集モード解除、フォーム初期化、URLの `id` 除去、作成ボタンの再有効化を行う。

## M-14D-7c レイアウト調整

M-14D-7bのselect化後、`自分の依頼書` selectがGrid上で先に配置され、`募集状態` と `概要` が不自然に下へ押し下げられるレイアウト崩れがあった。
M-14D-7cでは、`自分の依頼書` selectを通常フォーム項目として扱い、`募集状態` の右隣付近に収めた。

フォーム下部の見た目は、`募集人数 max` / `公開状態`、`募集状態` / `自分の依頼書`、その下に全幅の `概要` となるように調整した。
カード一覧時代の大型パネル余白は使わず、固定的な高さ指定やスクロール一覧用の見た目は復活させない。

## M-14D-7d グリッド整列再調整

M-14D-7dで依頼書フォーム下部のグリッド整列を再修正した。
`自分の依頼書` は専用パネルではなく、`募集状態` や `公開状態` と同じ通常フォーム項目として扱う方針に統一した。

PC幅では `募集人数 max` / `公開状態`、`募集状態` / `自分の依頼書（N件）`、その下に全幅の `概要` となる。
`募集状態` と `自分の依頼書` のラベル上端、select上端が揃うように、`自分の依頼書` の専用wrapperと余計なCSSを削除した。

件数はラベルの `自分の依頼書（N件）` に集約し、select下の単独件数表示は削除した。
SQL Editor実行、DB構造変更、Discord実送信、secret類の出力は行っていない。

## 未実装

- 編集保存
- 公開切替
- 削除
- 募集終了
- Discord実送信
- テンプレート保存

## 安全確認

- SQL Editorは実行していない。
- DB構造変更はしていない。
- RPC変更はしていない。
- Edge Function deployはしていない。
- Discord実送信はしていない。
- public/recruiting投稿は実行していない。
- Webhook URL、bot token、service_role key、secret類の実値は記録していない。
- email、user_id全文、gmUserId、token、keyは画面・console・docsへ出していない。
- `updates.json` は変更していない。
- commit / pushはしていない。
