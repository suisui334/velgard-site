# M-15L テンプレート機能 統合QA・仕様締め

M-15Lでは、M-15I-6 / M-15J-1 / M-15Kで実装済みのテンプレート機能について、現状仕様、QA観点、確認済み事項、残課題、後続候補を整理する。今回の工程ではdocs整理のみを行い、SQL Editor実行、DB構造変更、RPC変更、フロント実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行わない。

## 1. 現状仕様

テンプレートはログインユーザー本人の個人テンプレートとして扱う。作成、更新、無効化、一覧取得は既存RPC経由で行う。

利用可能RPC:

```text
get_my_template_presets()
create_template_preset(text, text, text)
update_template_preset(uuid, text, text, text, boolean)
deactivate_template_preset(uuid)
```

テンプレート種別は5種類で固定する。

| 種別 | 用途 | 主な表示先 | 保存形式 | 変数・補足 |
| --- | --- | --- | --- | --- |
| `call` | GM向け呼び出し用 | session-detail GM/adminテンプレUI、mypage | 自由本文 | `{{session_title}}`、`{{approved_call_list}}`、`{{approved_pc_names}}` を利用可能 |
| `result` | GM向けリザルト用 | session-detail GM/adminテンプレUI、mypage | 自由本文 | `call` と同じ変数ヘルプを表示 |
| `session_post` | 依頼書フォーム用 | session-post、mypage | 依頼書フォームJSON文字列 | タイトル、日時、締切、種別、募集人数、公開状態、募集状態、概要を保存 |
| `application` | PL参加申請コメント用 | mypage、session-detail 通常PL申請コメント欄 | 自由本文 | M-15L時点では置換なし。未対応変数はそのまま扱う |
| `other` | 補助用途 | 各UIで文脈別に表示 | 文脈依存 | 混線しやすいため表示先を絞って扱う |

## 2. 表示先ごとの役割

| 表示先 | 表示種別 | 主な役割 | 備考 |
| --- | --- | --- | --- |
| mypage | `call` / `result` / `session_post` / `application` / `other` | 全種別の横断管理 | 保存済みselect、名前、種別、本文または依頼書フォーム、新規保存、変更保存、削除、新規入力に戻す |
| session-detail GM/admin | `call` / `result` / `other` | GM向けテンプレ作成、保存、置換プレビュー、コピー | `{{approved_call_list}}` / `{{approved_pc_names}}` の内部生成を利用 |
| session-post | `session_post` / `other` | 依頼書フォーム全体の保存・反映 | 既存依頼書編集中の反映は確認ポップアップあり |
| session-detail 通常PL申請コメント | `application` / `other` | 申請コメント本文へのテンプレート反映 | 保存・編集はmypage側。本文入力済みなら上書き確認 |

## 3. 保存形式の整理

自由本文系:

- `call`
- `result`
- `application`
- `other`

JSONフォーム系:

- `session_post`

`session_post` は依頼書フォーム全体を復元するための構造化JSON文字列として保存する。mypageではJSON直編集ではなくフォーム型UIで扱い、session-postではフォーム反映時に既存入力の上書き確認を行う。

`other` は文脈依存のため、自由本文として扱える画面と、依頼書フォームJSONとして読める画面をUI側で分ける。特にsession-postでは、依頼書フォームJSONとして扱えるものだけを反映対象にする。

## 4. 画面別QA観点

### mypage

- ログイン済み時だけテンプレート管理UIが表示される。
- 全種別を作成、編集、削除できる。
- 保存済みテンプレートを選ぶと、名前、種別、本文またはフォーム内容が反映される。
- `call` / `result` 選択時だけ、変数名、代入内容、出力例、補足つきの変数ヘルプが出る。
- `session_post` 選択時は依頼書フォーム編集UIになり、通常本文textareaと混同しない。
- `session_post` の保存内容が依頼書フォームJSON文字列として5000文字以内に収まる。
- 想定形式として読めない `session_post` は一般的な注意表示にし、無理にフォーム反映しない。

### session-detail GM/admin

- GM/admin向け「GM向け：テンプレート」UIが表示される。
- 通常PLにはGM/admin向けUIが表示されない。
- 表示対象は `call` / `result` / `other` のみ。
- `application` / `session_post` がGM向けテンプレselectに混ざらない。
- 保存済みテンプレート選択、新規保存、変更保存、削除、置換プレビュー、コピーが動く。
- `{{approved_call_list}}` はM-15G確定のラベル付き1人1行形式で出力される。
- `{{approved_pc_names}}` はPC名だけを `、` 区切りで出力する。

### session-post

- 依頼書フォーム上部に依頼書テンプレートUIが表示される。
- 表示対象は `session_post` / `other` のみ。
- `call` / `result` / `application` が依頼書テンプレselectに混ざらない。
- 新規依頼書モードでは、選択テンプレートをフォームへ反映できる。
- 既存依頼書編集中に反映する場合は、上書き確認が出る。
- `session_post` のJSONが壊れている場合は、内部情報を出さない一般的な注意表示にする。

### session-detail 通常PL申請コメント

- 通常PLの参加希望コメントフォーム付近に「申請コメントテンプレート」UIが表示される。
- GMコメントフォームにはPL申請コメントテンプレートUIが表示されない。
- 表示対象は `application` / `other` のみ。
- `call` / `result` / `session_post` がPL申請コメント欄に混ざらない。
- テンプレートを選んで反映すると、コメント本文欄へ本文が入る。
- 既にコメント本文が入力済みの場合は上書き確認が出る。
- キャンセル時は本文が保持され、OK時だけ置き換わる。
- 反映後も通常の参加希望コメント投稿導線を使える。

### 共通

- 保存系操作は既存RPC経由で行う。
- 画面やDOMに内部識別子、認証系の生値、RPC結果の生データを出さない。
- consoleへテンプレート本文やRPC結果の生データを出さない。
- エラー表示は一般的な文言に丸める。
- console error 0件を確認する。
- `updates.json` は変更しない。

## 5. 確認済み事項

前工程までの実装・記録として、以下は確認済み扱いにする。

- M-15I-5でDB/RPC適用結果が成功扱いとなり、テンプレート保存テーブル、RLS、本人向けpolicy、RPC 4本、authenticatedのみEXECUTEの方針が確認済み。
- M-15I-6でsession-detail GM/adminテンプレUIとsession-post依頼書テンプレUIのフロント接続が完了済み。
- M-15J-1でmypageテンプレート管理UIが完了済み。
- M-15J-1追加改修で、`call` / `result` 向け変数ヘルプと `session_post` フォーム型編集UIが完了済み。
- M-15KでPL申請コメントテンプレート呼び出しUIが完了済み。
- 各UIは、画面文脈ごとに表示種別を絞る方針で整理済み。
- M-15L-2で、Codex側ブラウザでは未確認だった統合実ブラウザQAを、ユーザー実ブラウザ確認で補完済み。

M-15LではQA観点をdocsとして整理し、M-15L-2でユーザー実ブラウザ確認結果を追記した。

## 6. 残課題

- `application` 用変数ヘルプを追加するかどうか。
- `application` テンプレート内で `{{session_title}}` などを置換するかどうか。
- `other` の混線が運用上問題になるかどうか。
- admin共通テンプレート。
- 共有テンプレート。
- テンプレート並び順。
- テンプレート説明文。
- `session_post` テンプレートのJSON破損時UI改善。
- テンプレート一覧の検索・絞り込み。
- テンプレート管理UIのデザイン微調整。

## 7. other混線リスク

`other` は補助用途として便利だが、自由本文と依頼書フォームJSONが混ざる可能性がある。

現時点の対策:

- mypageでは全種別を横断管理するが、`session_post` はフォーム型UIとして明確に分ける。
- session-detail GM/adminでは `call` / `result` / `other` のみ表示する。
- session-postでは `session_post` / `other` のみ表示し、依頼書フォームJSONとして扱えるものを反映対象にする。
- session-detail 通常PL申請コメント欄では `application` / `other` のみ表示し、自由本文として反映する。
- 画面ごとに選択肢を絞り、選択だけでは本文やフォームを即時上書きしない。

後続候補:

- `other` の利用文脈が増えて混線が残る場合、テンプレート種別とは別に利用文脈を表す概念を検討する。
- 先にUI側のフィルタ、注意文、検索・絞り込みで運用できるかを確認し、DB/RPC拡張は必要性が見えてから検討する。

## 8. 次工程候補

- M-15L-3候補: 統合QA後の追加微修正が必要になった場合の小修正。
- M-15M候補: PL申請コメントテンプレートの変数ヘルプ設計。
- M-15N候補: PL申請コメントテンプレートで実セッション文脈の変数置換を行うか検討。
- M-15O候補: `other` の利用文脈整理と、必要時の追加設計。
- M-15P候補: テンプレート一覧の検索・絞り込み、説明文、並び順の検討。
- M-15Q候補: admin共通テンプレート、共有テンプレートの仕様設計。

## 9. M-15L-2 統合実ブラウザQA結果

M-15L-2では、mypage、session-detail GM/admin、session-post、session-detail 通常PL申請コメント欄を横断して実ブラウザQAを確認した。

作業前状態:

- `git status --short` はclean。
- 最新commitは `84441d0 Document template feature QA`。

補足:

- Codex側ブラウザでは、Chrome連携不可とアプリ内ブラウザ接続タイムアウトにより、認証済み統合QAを完走できなかった。
- その後、ユーザー実ブラウザ確認により、統合実ブラウザQAは補完確認済み。

ユーザー実ブラウザで確認済み:

- mypage: テンプレート管理UI表示、全種別の横断管理、保存、更新、削除、`call` / `result` 選択時の変数ヘルプ表示、`session_post` 選択時の依頼書フォーム編集UI、`session_post` JSON保存・反映、内部情報非露出、console errorなし。
- session-detail GM/admin: 「GM向け：テンプレート」UI、`call` / `result` / `other` のみ表示、`application` / `session_post` の混入なし、承認済み参加者連絡先UI削除済み、`{{approved_call_list}}` / `{{approved_pc_names}}` の置換維持、コピー機能維持、console errorなし。
- session-post: 依頼書テンプレートUI、`session_post` / `other` のみ表示、依頼書テンプレート反映、既存依頼書編集中の確認ポップアップ、キャンセル時の入力保持、console errorなし。
- session-detail 通常PL: 申請コメントテンプレートUI、`application` / `other` のみ表示、`call` / `result` / `session_post` の混入なし、本文空欄時の反映、本文入力済み時の上書き確認、キャンセル時の本文保持、GMコメントフォームには表示しないこと、console errorなし。
- 内部情報非露出: 指定の内部識別子、認証系の生値、PC選択・申請関連の内部キーが画面、DOM、consoleに出ていないこと。

判断:

- M-15L-2の統合実ブラウザQAは、ユーザー実ブラウザ確認により確認済み扱いへ更新する。
- 今回はQA記録のみとし、SQL Editor実行、DB/RPC変更、フロント実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

残課題:

- `application` 用変数ヘルプの将来追加。
- `application` テンプレートでの変数置換対応検討。
- `other` 混線が強くなった場合の利用文脈追加検討。
- admin共通 / 共有テンプレート。
- テンプレート検索・絞り込み。
- テンプレート説明文 / 並び順。
- `session_post` JSON破損時UI改善。
