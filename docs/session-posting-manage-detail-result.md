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

M-14D-7時点では、既存依頼書を選んでいる間は作成ボタンをdisabledにし、文言を `編集保存は次工程` にしていた。M-14D-9で保存UIへ置き換え済み。
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

## M-14D-8 update_session_post計画

下書き依頼書の編集保存に向け、`update_session_post` RPC草案とUI接続計画を分離して作成した。

- SQL草案: `docs/supabase/sql/017_update_session_post_rpc_draft.sql`
- 設計docs: `docs/session-posting-update-rpc-plan.md`

既存 `public.sessions.id` はtextで、`public.is_session_gm(text)` もtext前提のため、RPC草案の対象IDは `p_session_id text` とする。
selectのoption valueは引き続き `manage-0` 形式のローカルキーだけを使い、保存時の実IDはJSメモリ上の選択レコードからRPCへ渡す計画。

UI接続時は、既存依頼書選択中に `変更を保存` を出し、保存成功後にselectラベルとJSメモリ上の選択レコードを最新値へ更新する。
新規依頼書を書く選択時は従来どおり `create_session_post` モードへ戻す。

この工程ではSQL Editor実行、DB構造変更、RPC作成/置換、UI接続実装、Discord実送信、Edge Function deploy、secret類の出力は行っていない。

## M-14D-9 変更保存UI接続

`session-post.html` の既存依頼書編集モードに `変更を保存` ボタンを追加し、選択中の依頼書を `update_session_post` RPCで保存できるようにした。
既存依頼書選択中は作成ボタンを非表示/disabledにし、保存ボタンだけを有効化する。
Enter submitでも `create_session_post(...)` は呼ばず、編集モード中は `update_session_post` 側へ流す。

保存時の `p_session_id` はselect option valueから取らない。
select option valueは引き続き `manage-0` 形式のローカルキーだけを使い、実IDはJSメモリ上の選択レコードからRPC payloadへ渡す。
raw id / uuid、user_id、email、token、key、secret類はDOM、画面、consoleへ出さない。

保存成功後は `変更を保存しました。` を表示し、フォーム内容、`自分の依頼書` selectの該当option表示、JSメモリ上の選択レコードを最新値へ更新する。
選択中の依頼書は選択されたままで、作成ボタンが誤って有効化されないようにした。
保存失敗時は既知のRPCエラーを日本語表示し、未知のエラーは `保存に失敗しました。` に丸める。

`新規依頼書を書く` を選んだ場合は、従来どおり編集モード解除、保存ボタン非表示、作成ボタン有効化、フォーム初期化、URLの `id` 除去を行う。
この工程ではSQL Editor実行、DB構造変更、RPC変更、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力は行っていない。

## M-14D-10 公開切替まわりのUI整理

既存依頼書編集中に、`公開状態` / `募集状態` の選択に応じた短い補助文を表示するようにした。
非公開または下書きは公開カレンダー非表示、公開系は公開カレンダー反映とDiscord通知未実装、終了系は募集終了扱いになることをフォーム内の小さな文で示す。

`visibility = public` かつ `status = draft` は、保存前にUI側で止める。
この場合は `下書きは公開にできません。募集状態を変更するか、公開状態を非公開にしてください。` と表示し、`update_session_post` RPCを呼ばない。

保存成功メッセージは公開状態に応じて出し分ける。
非公開保存では従来どおり `変更を保存しました。`、公開保存では公開カレンダー反映とDiscord通知未実装を明示する。

公開切替専用の大型ボタンや別パネル、削除/募集終了専用UIは追加していない。
既存の `公開状態` / `募集状態` select、`変更を保存` ボタン、新規作成モード、`create_session_post` / `update_session_post` 接続、`p_end_at` / 日跨ぎ対応、raw id / uuid非表示方針は維持する。

この工程ではSQL Editor実行、DB構造変更、RPC変更、GRANT/REVOKE実行、Discord実送信、Edge Function deploy、`updates.json` 変更、secret類の出力、commit / pushは行っていない。

## M-14D-10.5 session-detail編集導線

`session-detail.html` の基本情報グリッド右下に、編集 / 削除ボタン枠を追加した。
ボタンはPC幅で半々の横並びとし、`募集人数` の右側に収まる小さな管理セルとして扱う。

編集ボタンはSupabase由来の公開依頼書だけを対象にする。
ログイン済みユーザーについて `is_admin()` / `is_session_gm(target_session_id)` を確認し、編集可能な場合だけ有効化して `session-post.html?id=<session_id>#my-sessions` へ遷移する。
静的JSON由来、未ログイン、権限なし、確認失敗時は編集ボタンをdisabledにし、短い理由を表示する。

削除ボタンは配置のみでdisabledにした。
titleと補助文上の扱いは「削除機能は次工程で実装予定」とし、DB削除、status変更、visibility変更、削除RPC呼び出しは行っていない。

開催時刻は開始側にも年月日を出すよう修正した。
例として `2026-06-08 21:00〜2026-06-09 09:47` のように、`end_at` がある日跨ぎ依頼書でも開始日時が欠けない。

`session-post.html?id=...` からの復元は、既存の自分の依頼書select照合とフォーム反映を維持する。
編集状態の補助文を `選択中の依頼書を編集中です。内容を変更したら「変更を保存」を押してください。` にし、指定IDが自分の依頼書一覧に見つからない場合もIDを表示せず短文エラーにする。

raw id / uuid、user_id、email、token、key、secret類はDOM、画面、consoleへ出さない方針を維持する。
session-detailから編集画面へ渡すのは、既存URLで使っている公開セッションIDの範囲に留める。

この工程ではSQL Editor実行、DB構造変更、RPC変更、GRANT/REVOKE実行、Discord実送信、Edge Function deploy、admin全件管理UI、削除/募集終了本実装、`updates.json` 変更、secret類の出力、commit / pushは行っていない。

## 未実装

- 公開切替専用UI
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
