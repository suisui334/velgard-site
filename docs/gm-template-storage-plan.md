# M-15I テンプレート保存機能 仕様設計

## 1. 目的

M-15Hで追加したGM/admin向けテンプレ変数置換UIを土台に、GMやPLが自分用のテンプレート本文を保存し、依頼書、呼び出し、リザルト、申請などで再利用できるようにする。

固定テンプレートを配布するのではなく、ユーザーが自由本文に変数を差し込める方式を採用する。

## 2. スコープ

M-15I-1では仕様設計のみを行う。SQLファイル作成、SQL Editor実行、DB構造変更、RPC作成、フロント実装、commit / pushは行わない。

初期実装の対象は「ログインユーザー本人の個人テンプレート」に絞る。admin共通テンプレート、公開共有テンプレート、テンプレート配布機能は後続拡張候補とする。

## 3. M-15Hとの関係

M-15Hの `session-detail.html` には、GM/admin管理領域に「GM向け：テンプレート」があり、テンプレ入力、変数置換プレビュー、置換結果コピーまで実装済み。

M-15Iでは、この入力欄に保存済みテンプレートを読み込み、作成、更新、無効化、一覧表示できるようにする。置換処理そのものはM-15Hの `{{session_title}}` / `{{approved_call_list}}` / `{{approved_pc_names}}` の仕様を維持する。

## 4. 保存対象

初期保存対象は以下に絞る。

```text
template_name
template_type
template_body
```

`template_name` は一覧で選ぶための必須名。`template_type` は用途分類。`template_body` は変数を含められる自由本文。

初期実装ではテンプレート説明文、共有設定、詳細なスコープ、更新者履歴は持たない。

## 5. テンプレート種別

初期候補は以下。

```text
call
result
session_post
application
other
```

画面表示は日本語で以下のように扱う。

```text
呼び出し用
リザルト用
依頼書用
申請用
その他
```

DB上の値は短い英字textにし、UI側で日本語ラベルへ変換する方針を推奨する。

M-15I-2時点では、DB値と日本語表示名を分ける案を採用候補とする。理由は、RPCやCHECK制約では短い固定値のほうが扱いやすく、画面文言は後から調整しやすいため。DBに日本語表示名をそのまま保存する案は、表示文言の変更がデータ更新に直結するため初期実装では優先しない。

M-15I-6追加改修では、DB上の許可値5種は維持しつつ、画面文脈ごとに選択肢を絞る。`session-detail.html` のGM/admin向けテンプレUIは `call` / `result` / `other`、`session-post.html` の依頼書テンプレUIは `session_post` / `other` のみ表示する。PL向け申請テンプレUIは将来工程で `application` / `other` を候補にする。

## 6. 権限設計

初期実装では、ログイン済みユーザーが自分のテンプレートだけを扱える。

- 作成: `auth.uid()` の本人テンプレートとして作成する。
- 一覧取得: `owner_user_id = auth.uid()` かつ `is_active = true` のみ返す。
- 更新: `owner_user_id = auth.uid()` のテンプレートのみ更新できる。
- 無効化: `owner_user_id = auth.uid()` のテンプレートのみ無効化できる。
- anonはすべて不可。

adminはアプリ内権限であり、サーバー側の高権限キーとは混同しない。初期の個人テンプレート操作では、adminであっても他人の個人テンプレートを編集しない方針を推奨する。

## 7. admin共通テンプレート

admin共通テンプレートは初期実装には含めない。

理由:

- 個人テンプレートだけなら権限境界が単純。
- 共有範囲、表示順、編集責任者、監査方針を後から分けて設計できる。
- M-15Hの現在UIは個人利用のテンプレ本文入力と相性がよい。

後続で必要になった場合は `scope` または `is_shared` を追加し、admin専用RPCで共通テンプレートを管理する案を検討する。

## 8. GM/PL個人テンプレート

初期実装はGM/PL共通の個人テンプレートとして扱う。保存機能自体はログインユーザー本人の道具であり、テンプレート種別によってGM専用・PL専用を厳密に分けない。

ただし、M-15Hの `{{approved_call_list}}` / `{{approved_pc_names}}` はGM/admin向けの承認済み参加者情報が必要なため、通常PL画面では置換データを取得できない。PL向け画面で同じテンプレート保存機能を使う場合、GM/admin専用変数は未対応変数として残すか、空扱いにする別設計が必要。

M-15I初期のフロント接続は、GM/admin向けの `session-detail.html` と `session-post.html` に限定する。通常PL向けテンプレ保存UIは、PL側で使える変数と申請フォーム形式を整理してから別工程にする。

## 9. 削除方式

物理削除ではなく、`is_active = false` による非アクティブ化を第一候補とする。

理由:

- 誤削除からの復旧余地を残せる。
- 将来の監査や履歴表示に拡張しやすい。
- フロントから直接DELETEしない方針と合う。

初期RPC名も削除ではなく `deactivate_template_preset` 相当とし、UI表示は「削除」でも内部処理は無効化として扱う。

## 10. 表示順

初期実装では、種別ごとに `updated_at desc`、同時刻の場合は `created_at desc` を推奨する。

`sort_order` は初期実装に含めない。手動並び替えは便利だが、保存機能の最初の段階としては過剰になりやすい。

後続で頻繁に使うテンプレートを上に固定したくなった場合に、`sort_order` または `pinned_at` を追加検討する。

## 11. 文字数制限

初期制限案:

```text
template_name: 1〜80文字
template_body: 1〜5000文字
```

`template_name` は空欄不可。改行は不可。前後空白は保存前にtrimする。

`template_body` は自由本文だが空欄不可。M-15I-3 draft SQLと合わせ、初期テンプレ本文は5000文字上限を推奨する。本文の改行は許可する。

説明文 `description` を将来追加する場合は200文字程度に抑える。

## 12. 変数仕様

初期対応変数:

```text
{{session_title}}
{{approved_call_list}}
{{approved_pc_names}}
```

`{{approved_call_list}}` はM-15G確定形式を使う。

```text
Discord：<mention>｜ユーザー名：<display_name>｜PC名：<pc_name>
```

Discord未登録または形式不正時は `Discord：登録されていません`。不正な `discord_handle` 生値は代替表示しない。

PC名未登録時は `PC名：PC名未登録`。

`{{approved_pc_names}}` はPC名のみを `、` 区切りで列挙する。PC名未登録が含まれる場合は `PC名未登録` を含める。

後続拡張候補:

```text
{{session_date}}
{{session_time}}
{{gm_name}}
{{approved_display_names}}
{{approved_discord_ids}}
{{application_deadline}}
{{player_min}}
{{player_max}}
{{session_type}}
```

`{{approved_discord_ids}}` はメンションではなくIDそのものを扱う可能性があり、誤送信や意図しない露出につながりやすいため初期実装では見送る。

## 13. 未対応変数の扱い

未対応変数はそのまま残す。

理由:

- 後続拡張前にユーザーが将来用の変数を含むテンプレートを保存できる。
- 未対応変数を消すと、テンプレート本文の意図が失われる。
- M-15Hの現在の置換UIとも相性がよい。

フロントでは「未対応変数はそのまま残ります」という短い注意文を表示する候補とする。

## 14. SQL/RPC方針

想定テーブル名は `gm_template_presets` を第一候補とする。

M-15I-1時点では `template_presets` / `user_template_presets` も候補にしたが、M-15I-2のpreflightでは `gm_template_presets` を確認対象にする。理由は、M-15Hの初期接続先がGM/admin管理領域であることが分かりやすく、既存テーブル名との衝突も避けやすいため。

ただし、保存データはGMだけに閉じた専用書式ではなく、将来PL向けにも広げられる個人テンプレートとして扱う。権限境界はテーブル名ではなく `owner_user_id` とRLS/RPCで守る。

初期テーブル案:

```text
id
owner_user_id
template_name
template_type
template_body
is_active
created_at
updated_at
```

初期に入れない項目:

```text
description
sort_order
is_shared
scope
created_by
updated_by
```

これらは便利だが、初期の個人テンプレート保存には必須ではない。必要になった段階で追加する。

想定RPC:

```text
get_my_template_presets()
create_template_preset(template_name text, template_type text, template_body text)
update_template_preset(template_preset_id uuid, template_name text, template_type text, template_body text, is_active boolean)
deactivate_template_preset(template_preset_id uuid)
```

RPC名は既存の `get_my_player_characters()` や `cancel_my_session_application(text)` と同じく、本人操作であることが分かる名前を優先する。更新RPCの `is_active boolean` は復旧や再有効化を含めるなら便利だが、初期UIで「削除」だけ扱うなら `deactivate_template_preset` に分ける。

フロントから直接INSERT / UPDATE / DELETEはしない。作成、更新、無効化、一覧取得はRPC経由とする。

RLSは本人行だけを扱う最終防衛線として設定し、RPCは入力検証、権限判定、戻り値制限を担う。RPCは既存方針に合わせて `security definer` と `search_path` 明示を検討する。

EXECUTE権限は `authenticated` のみ。`anon` / `public` には許可しない。

## 15. フロント接続方針

M-15I-6で、M-15HのテンプレUIへ以下を追加する。

- 保存済みテンプレート一覧
- テンプレート種別select
- テンプレート選択で入力欄へ反映
- 新規保存
- 上書き保存
- 名前変更
- 無効化

初期UIはGM/admin管理領域内に限定する。通常PL向けテンプレ保存UIは、PL側で使える変数の扱いを整理してから別工程にする。

保存後も置換処理はフロント側で行う。RPCはテンプレート本文を保存・取得するだけで、承認済み参加者連絡先の展開は既存M-15Hの置換処理を使う。

## 16. セキュリティ注意点

- テンプレート本文に認証情報、接続情報、外部連携用の秘匿値などを保存しないよう画面に注意文を置く。
- 内部識別子、連絡先、認証系の生値は画面、DOM、console、docsに出さない。
- RPC戻り値に `owner_user_id` を含めないか、少なくともフロント表示・DOM属性に使わない。
- エラー表示は短い文言に丸め、DB制約名や内部IDを表示しない。
- console.logでテンプレート本文やRPC戻り値を出さない。
- adminはアプリ内権限として扱い、サーバー側の高権限キーとは混同しない。
- サーバー側の高権限キーはフロントで使わない。

## 17. 段階的な実装ステップ

1. M-15I-1: 仕様設計docs作成。
2. M-15I-2: preflight SELECT-only SQL作成。
3. M-15I-3: RPC draft SQL作成。
4. M-15I-4: apply_reviewed.sql作成・レビュー。
5. M-15I-5: ユーザー手動SQL Editor適用。
6. M-15I-6: フロント接続。
7. M-15I-7: 実ブラウザ確認・commit / push。

## 18. M-15I-2以降のpreflight / draft / apply方針

M-15I-2 preflightで確認する候補:

- `profiles.id` の型。
- `auth.uid()` と `profiles.id` の対応。
- 既存 `user_roles` / admin判定helperの有無。
- `set_updated_at()` または同等のupdated_at trigger/helperの有無。
- 既存RPCの `security_definer` / `search_path` 方針。
- `anon` / `public` / `authenticated` のEXECUTE権限方針。
- `gm_template_presets` と類似テーブル名との衝突有無。
- 既存text CHECK制約の書き方。

M-15I-2 preflight手動実行結果:

- SQL Editorでの手動実行はエラーなく完了し、単一結果セット形式で全チェックが表示された。
- `gm_template_presets` は `pending_create` / `not found`。予定テーブル名は未使用で、M-15I draft/applyで新規作成対象として問題なし。
- 類似テーブル名は `none` / `not found`。template / preset / message 系の既存テーブル衝突はない。
- 想定列 `id` / `owner_user_id` / `template_name` / `template_type` / `template_body` / `is_active` / `created_at` / `updated_at` はすべて `pending_create` / `not found`。予定テーブルが未作成のため想定通り。
- `profiles.id` は `uuid, nullable=NO` で、`owner_user_id` の参照先として互換あり。
- `profiles.id` は `auth.users(id)` を参照している。
- `profiles.id` と `auth.uid()` はどちらもuuidで、RPC内の本人照合前提に問題なし。
- `set_updated_at()` は `security_definer=false` / `search_path=true` / `result=trigger` で、updated_at helperとして再利用候補。
- admin / role helperとして `has_role(text)`、`is_admin()`、`is_session_gm(text)` が存在し、`public.user_roles` も存在する。adminはアプリ内権限として扱い、サーバー側の高権限キーとは混同しない方針を維持する。
- 既存RPCは、PC管理RPC、承認済み参加者連絡先RPC、申請ステータス更新RPC、セッション投稿系RPCで `security_definer=true` かつ `search_path=true` の傾向を確認した。M-15IのRPC draftでもこの方針に合わせる。
- 既存RPCのEXECUTE権限は `authenticated` で確認できる。M-15Iでも `authenticated` のみEXECUTEを基本とし、`anon` / `public` は許可しない方針で検討する。
- 想定RPC名 `get_my_template_presets` / `create_template_preset` / `update_template_preset` / `deactivate_template_preset` はすべて `ok` / `not found`。同名衝突なし。
- 関連RLS / table privileges と既存text CHECK制約は、M-15I-3 draft SQL作成時の参考情報として扱う。
- 初期テンプレート種別候補は `call = 呼び出し用`、`result = リザルト用`、`session_post = 依頼書用`、`application = 申請用`、`other = その他`。

判断: preflight結果としては、M-15I-3 RPC draft SQL作成へ進める前提が整っている。ただしM-15I-2では結果記録までとし、RPC draft SQLはまだ作成しない。

M-15I-3 RPC draftでは、テーブル作成案、RLS案、RPC案、GRANT / REVOKE案、戻り値列、rollback案をまとめる。ただし実行しない草案として扱う。

M-15I-3 draft SQL作成結果:

- `docs/supabase/sql/023_gm_template_storage_rpc_draft.sql` を作成した。これはレビュー用草案であり、SQL Editorへ貼り付けるapply用ファイルではない。
- 作成予定テーブルは `public.gm_template_presets`。列は `id` / `owner_user_id` / `template_name` / `template_type` / `template_body` / `is_active` / `created_at` / `updated_at`。
- `template_type` はCHECK制約で `call` / `result` / `session_post` / `application` / `other` に制限する案を第一候補にした。日本語表示名はDBへ保存せず、UIまたはdocs側で扱う。
- `template_name` はtrim後1〜80文字、単一行。`template_body` はtrim後空を拒否し、最大5000文字。本文の改行は許可する。
- RLSは本人行のみselect / insert / updateできる方針で草案化した。物理削除policyは作らず、無効化は `is_active = false` で行う。
- フロントからのテーブル直書きは初期機能に含めず、テーブル権限は付与しない方針にした。作成、更新、無効化、一覧取得はRPC経由にする。
- RPCは `get_my_template_presets()`、`create_template_preset(text, text, text)`、`update_template_preset(uuid, text, text, text, boolean)`、`deactivate_template_preset(uuid)` の4本。すべて `security definer` と明示的な `search_path` を使う案。
- RPC戻り値には `owner_user_id` を含めない。本人判定はRPC内で `auth.uid()` と `profiles.id` を使い、他人のテンプレート指定はnot found扱いの例外に寄せる。
- EXECUTE権限は `authenticated` のみを付与し、`anon` / `public` は許可しない草案にした。
- admin共通テンプレート、共有テンプレート、`sort_order`、`scope`、`description`、同名テンプレートの一意制約は初期草案から除外した。
- この工程ではdraft SQL作成のみ。apply_reviewed SQL作成、SQL Editor実行、DB構造変更、RPC作成 / 変更、フロント実装は行っていない。

M-15I-4 apply_reviewedでは、レビュー済みのAPPLY専用SQLだけを分離する。SQL Editorで実行する場合はapply専用ファイルのみを使う方針にする。

M-15I-4 apply_reviewed SQL作成結果:

- `docs/supabase/sql/023_gm_template_storage_apply_reviewed.sql` を作成した。SQL Editorで適用する場合はこのAPPLY専用ファイル全文のみを使い、draft全文は貼らない。
- draftから、`gm_template_presets` テーブル作成、CHECK制約、index、updated_at trigger、RLS有効化、本人行向けRLS policy、RPC 4本、EXECUTE権限整理、`authenticated` へのEXECUTE付与、post-apply確認SELECTを切り出した。
- preflight SELECT、rollback草案、共有 / admin共通テンプレート、`sort_order`、`scope`、`description`、物理削除、フロント実装内容は含めていない。
- apply_reviewed SQLは `owner_user_id` をRPC引数にせず、RPC内で `auth.uid()` と `profiles.id` を使う方針を維持する。RPC戻り値にも `owner_user_id` を含めない。
- この工程ではapply_reviewed SQL作成とレビューのみ。SQL Editor実行、DB構造変更、RPC作成 / 変更、フロント実装は行っていない。

M-15I-5 apply_reviewed SQL適用結果:

- ユーザーがSupabase SQL Editorで `docs/supabase/sql/023_gm_template_storage_apply_reviewed.sql` を手動適用し、SQL Editor上のエラーなしを確認した。
- 適用後確認SELECTで、`gm_template_presets` テーブル存在、RLS有効化、本人向けRLS policy 3件、RPC 4本の存在、各RPCの `security_definer=true` と `search_path` 設定ありを確認した。
- RLS policyは `gm_template_presets_insert_own` / `gm_template_presets_select_own` / `gm_template_presets_update_own` の3件で、rolesはいずれも `authenticated`。DELETE policyがないことは、物理削除ではなく `is_active=false` の非アクティブ化方針と整合する。
- RPCは `create_template_preset(text, text, text)` / `deactivate_template_preset(uuid)` / `get_my_template_presets()` / `update_template_preset(uuid, text, text, text, boolean)` の4本すべて存在確認済み。
- EXECUTE権限は4本すべて `authenticated` のみ許可、`anon` / `public` は不可であることを確認した。
- M-15I-5は成功扱いとし、次工程はM-15I-6「フロント接続」。この記録工程でCodexはSQL Editor実行、DB/RPC追加変更、フロント実装を行っていない。

M-15I-6ではフロント接続のみ行い、フロントからDB直UPDATE / DELETEをしない。

M-15I-6 フロント接続結果:

- M-15HのGM/admin向けテンプレUI名を「GM向け：テンプレート」へ整理し、保存済みテンプレートselect、テンプレート名入力、テンプレート種別select、新規保存、変更を保存、削除ボタンを追加した。削除表示でも内部処理は `deactivate_template_preset(uuid)` による `is_active=false` の非アクティブ化であり、物理削除ではない。
- 一覧取得は `get_my_template_presets()`、新規保存は `create_template_preset(text, text, text)`、更新は `update_template_preset(uuid, text, text, text, boolean)`、無効化は `deactivate_template_preset(uuid)` を使う。フロントからDB直INSERT / UPDATE / DELETEはしない。
- 保存済みテンプレート選択時は、表示用の一時キーだけをselect値に使い、実IDは画面やDOMへ出さない。RPC戻り値は表示に必要なテンプレート情報だけを許可する。
- `template_name` はtrim後1〜80文字・改行不可、`template_body` はtrim後空欄不可・最大5000文字、`template_type` はDB/RPC上 `call` / `result` / `session_post` / `application` / `other` を許可する。画面上は文脈別に、session-detailで `call` / `result` / `other`、session-postで `session_post` / `other` のみ選べる。
- 置換プレビューとコピーは既存のM-15H処理を維持し、`{{approved_call_list}}` / `{{approved_pc_names}}` の出力形式は変更していない。
- session-detailの独立した「GM向け：承認済み参加者連絡先」UIは削除した。承認済み参加者データの取得と整形は、`{{approved_call_list}}` / `{{approved_pc_names}}` のテンプレ変数置換用に内部利用を継続する。
- `session-post.html` の依頼書フォーム上部に「依頼書テンプレート」UIを追加した。保存対象はタイトル、開始日時、終了日時、申請締切、種別、募集人数min/max、公開状態、募集状態、概要で、管理対象selectや公開確認チェックは保存しない。依頼書テンプレートは `template_body` にフロント専用JSON文字列として保存し、保存済みテンプレート選択だけではフォームへ反映せず、「反映」ボタンで適用する。
- 編集中の依頼書にテンプレートを反映する場合は、未保存の入力内容が失われる旨を確認する。新規依頼書作成中は確認なしで反映できる。
- この工程ではSQL Editor実行、DB構造変更、RPC変更、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## 19. M-15J 将来拡張仕様

M-15Jでは実装を行わず、M-15Iで作った個人テンプレート保存機能を将来どこへ広げるかを整理する。

### mypageテンプレート一元管理

最終的には、`mypage.html` に「テンプレート管理」セクションを追加し、ログインユーザー本人のテンプレートを横断的に作成、編集、削除できるようにする。

目的:

- session-detailやsession-postなど、利用画面ごとに保存UIを散らしすぎない。
- GM用テンプレートとPL用テンプレートを同じ個人管理画面で見渡せるようにする。
- コメント投稿画面では呼び出し中心、mypageでは管理中心という役割分担を作る。

管理対象テンプレート種別:

```text
call
result
session_post
application
other
```

種別ごとの用途と保存形式:

```text
call: GM向け呼び出し用。自由本文 + 変数。
result: GM向けリザルト用。自由本文 + 変数。
session_post: GM向け依頼書フォーム用。template_body にフォーム内容のJSON文字列を保存する。
application: PL向け参加申請コメント用。自由本文 + 変数。
other: 補助用途。文脈をまたいで混ざりやすいため、表示先を慎重に分ける。
```

`session_post` はフォーム項目を復元するための構造化JSONテンプレートであり、自由本文テンプレートとは編集体験を分ける必要がある。mypageで `session_post` を扱う場合、JSON文字列をそのままtextareaに見せるのではなく、将来的には依頼書フォームに近い編集UIで扱うのが望ましい。

初期のmypage実装では、自由本文系の `call` / `result` / `application` / `other` と、JSON系の `session_post` を明確に分ける案を優先する。`session_post` の編集UIが十分に用意できない段階では、一覧表示と削除だけ先に扱い、本文編集はsession-post画面側へ誘導する案も検討する。

### PL申請コメントテンプレート

PLが `session-detail.html` の参加希望コメントフォームから申請コメントを書く際、コメント欄付近にテンプレートselectを置く案を後続候補にする。

利用イメージ:

- コメントフォーム付近に保存済みテンプレートselectを置く。
- 表示対象は `application` / `other` を基本にする。
- 選択だけでは本文を上書きせず、必要に応じて「反映」ボタンでコメント本文欄へ入れる。
- すでにコメント本文が入力されている場合は、上書き確認を出す。
- 初期実装では保存や編集はmypage側に寄せ、コメント欄では呼び出し中心にする。
- 将来的に必要なら、コメント欄からの簡易保存を別工程で検討する。

`application` はPL向け参加申請コメントの自由本文テンプレートとして扱う。使える変数は、GM/admin専用の承認済み参加者情報に依存しないものから始める。未対応変数は既存方針どおりそのまま残す。

### otherの扱い

`other` は便利な逃げ道だが、session-detail、session-post、PL申請コメント、mypage管理をまたいで表示すると混線しやすい。

初期方針:

- session-detailでは `call` / `result` / `other` を表示する。
- session-postでは `session_post` / `other` を表示する。ただし `template_body` が依頼書フォームJSONとして読めるものだけを表示する。
- PL申請コメントでは `application` / `other` を候補にする。ただし自由本文として安全に扱えるものだけを表示する。
- mypageでは全種別を横断管理するが、利用先ごとの注意表示やフィルタを用意する。

将来的に `other` の混線が運用上の問題になった場合は、`template_type` とは別に利用文脈を表す概念を追加するか検討する。ただしM-15JではDB構造変更を急がず、まず既存の種別と本文形式の判定で分ける方針に留める。

### DB/RPC要否の初期見立て

現時点の個人テンプレート作成、更新、削除、一覧取得は、M-15Iで作成済みのRPC 4本で足りる可能性が高い。

初期実装で追加DB/RPCを急がない理由:

- 保存対象は本人テンプレートに限定している。
- admin共通テンプレートや共有テンプレートはまだ後続候補。
- `session_post` は `template_body` のJSON形式で、自由本文系と同じ保存枠に収められている。
- 画面ごとの表示候補は、テンプレート種別と本文形式の判定でまず分けられる。

追加DB/RPCが必要になりうる条件:

- `other` を文脈ごとに厳密に分ける必要が出た。
- admin共通テンプレート、共有テンプレート、並び順、説明文、複製などを扱う。
- mypageから `session_post` をフォームUIとして安全に編集するため、保存形式のバージョン管理や検証を強化したい。

### フロント実装候補の段階

1. M-15J: 将来仕様docs整理。実装なし。
2. M-15J-1: mypageテンプレート管理UIを既存RPC経由で接続する。
3. M-15M候補: session-detailのPL参加希望コメント欄に `application` / `other` テンプレート呼び出しを追加する。
4. M-15N候補: mypageで `session_post` テンプレートをフォーム風に編集できるUIを検討する。
5. M-15O候補: `other` の混線が残る場合、利用文脈の追加設計をpreflightから検討する。

M-15JではSQL Editor実行、DB構造変更、RPC変更、フロント実装、Discord実送信、Edge Function deploy、`updates.json` 変更は行わない。

## 20. M-15J-1 mypageテンプレート管理UI実装結果

M-15J-1では、`mypage.html` のログイン済み表示内に「テンプレート管理」セクションを追加し、本人のテンプレートを横断的に管理できるようにした。未ログイン時は既存の認証表示どおり、この管理UIは描画しない。

追加UI:

- 保存済みテンプレートselect。
- テンプレート名入力。
- 種別select。
- 本文入力欄。
- 新規保存、変更を保存、削除、新規入力に戻すボタン。
- 読み込み、保存、更新、削除、エラー用の状態メッセージ。

対象種別:

```text
call = 呼び出し用
result = リザルト用
session_post = 依頼書用
application = 申請用
other = その他
```

`call` / `result` / `application` / `other` は自由本文テンプレートとして扱う。`session_post` は依頼書フォーム用JSONテンプレートとして扱い、mypageではタイトル、開始日時、終了日時、申請締切、種別、募集人数、公開状態、募集状態、概要をフォーム型UIで編集する。保存時は既存の依頼書テンプレート形式へ変換して `template_body` へ保存する。

`call` / `result` の自由本文テンプレートでは「利用できる変数」ヘルプを表示する。mypage上では置換プレビューは行わず、保存用の説明として、変数名、代入内容、出力例、補足を表示する。

表示する変数:

```text
{{session_title}} = 現在開いているセッションのタイトル
{{approved_call_list}} = 承認済み参加者のDiscordメンション、ユーザー名、PC名の一覧
{{approved_pc_names}} = 承認済み参加者のPC名一覧
```

`application` 用の変数ヘルプは、PL申請コメントテンプレートUIを作る後続工程で検討する。M-15J-1時点では `application` / `other` / `session_post` では変数ヘルプを表示しない。

RPC接続は既存4本のみを使う。

```text
get_my_template_presets()
create_template_preset(text, text, text)
update_template_preset(uuid, text, text, text, boolean)
deactivate_template_preset(uuid)
```

フロントからテンプレート保存テーブルへ直接INSERT / UPDATE / DELETEしない。保存済みテンプレートselectには表示用の一時キーだけを使い、実IDや所有者識別子を画面やDOMへ出さない。RPC結果は表示に必要なテンプレート情報だけを許可し、生データをconsole出力しない。

バリデーション:

- テンプレート名はtrim後1〜80文字。
- テンプレート名に改行は不可。
- 本文はtrim後空欄不可、最大5000文字。
- 本文の改行は許可。
- 種別は `call` / `result` / `session_post` / `application` / `other` のみ。
- `session_post` はフォーム入力から生成した依頼書フォーム用JSON形式のみ保存可能。日時形式、募集人数範囲、タイトルと概要の文字数、JSON化後の本文長を確認する。

この工程ではSQL Editor実行、DB構造変更、RPC変更、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## 21. M-15K PL申請コメントテンプレート呼び出しUI実装結果

M-15Kでは、`session-detail.html` の参加希望コメントフォーム付近に、PL向け申請コメントテンプレートを呼び出すUIを追加した。これはGM/admin向けテンプレート管理UIとは別の、通常PLのコメント入力補助として扱う。

表示条件:

- ログイン済みの通常PL向け参加希望コメントフォームに表示する。
- 未ログイン時や申請不可状態では、既存の投稿不可表示どおり表示しない。
- GM本人として管理中のGMコメントフォームには表示しない。

テンプレート取得と絞り込み:

- 一覧取得は既存RPC `get_my_template_presets()` のみを使う。
- 表示対象は `application` / `other` の保存済みテンプレートのみ。
- `call` / `result` / `session_post` はPL申請コメント欄では表示しない。
- 保存済みテンプレートが0件の場合は、申請用テンプレートがまだない旨を表示し、mypageで作成できる導線を置く。

UIと挙動:

- 保存済みテンプレートselect、反映ボタン、mypageのテンプレート管理への小さな導線を追加した。
- selectで選ぶだけではコメント本文を変更せず、「反映」ボタンで本文欄へ入れる。
- コメント本文がすでに入力済みの場合は上書き確認を出す。キャンセル時は本文を保持し、OK時だけテンプレート本文で置き換える。
- 反映後も通常どおりコメント本文を編集できる。
- この画面ではテンプレートの保存、編集、削除は行わず、管理はmypage側に寄せる。

変数の扱い:

- M-15K時点では、PL申請コメントテンプレート内の変数置換は行わない。
- 未対応変数はそのままコメント本文へ反映される。
- 将来的に `application` 用の変数ヘルプや `{{session_title}}` などの置換が必要になった場合は、実セッション文脈での安全な展開ルールを別工程で検討する。

既存導線との関係:

- 参加希望コメント投稿、辞退、再申請、GMコメント、GM/admin管理用テンプレートUIの既存導線は変更しない。
- 申請コメント投稿は既存の投稿RPC / 既存導線を維持する。
- テンプレート呼び出しでは保存テーブルへの直接INSERT / UPDATE / DELETEを行わない。
- select値には表示用の一時キーだけを使い、内部識別子を画面やDOMへ出さない。RPC結果の生データをconsole出力しない。

この工程ではSQL Editor実行、DB構造変更、RPC変更、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## 22. M-15L テンプレート機能 統合QA・仕様締め

M-15Lでは、テンプレート機能全体の現状仕様、画面別QA観点、確認済み事項、残課題、`other` 混線リスク、次工程候補を `docs/template-feature-qa-result.md` に整理した。

仕様締めの要点:

- mypageは全種別の横断管理を担う。
- session-detail GM/adminは `call` / `result` / `other` を扱う。
- session-postは `session_post` / `other` を扱う。
- session-detail 通常PL申請コメント欄は `application` / `other` を扱う。
- 自由本文系と依頼書フォームJSON系を明確に分ける。
- `other` は文脈依存のため、画面ごとの表示対象制御で混線を抑える。
- 保存系操作は既存RPC経由の方針を維持する。

M-15Lではdocs整理のみを行い、SQL Editor実行、DB構造変更、RPC変更、フロント実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## 23. M-15L-2 統合実ブラウザQA結果

M-15L-2では、テンプレート機能の統合実ブラウザQAを確認した。Codex側ブラウザでは接続環境の問題により未確認だったが、その後ユーザー実ブラウザで補完確認済み。

- ローカル静的サーバーで `mypage.html` がHTTP 200で取得できることは確認した。
- mypageでは、全種別の横断管理、保存、更新、削除、`call` / `result` の変数ヘルプ、`session_post` の依頼書フォーム編集UI、JSON保存・反映、内部情報非露出、console errorなしを確認済み。
- session-detail GM/adminでは、「GM向け：テンプレート」UI、`call` / `result` / `other` のみ表示、`application` / `session_post` 混入なし、承認済み参加者連絡先UI削除済み、`{{approved_call_list}}` / `{{approved_pc_names}}` の置換維持、コピー機能維持、console errorなしを確認済み。
- session-postでは、依頼書テンプレートUI、`session_post` / `other` のみ表示、依頼書テンプレート反映、既存依頼書編集中の確認ポップアップ、キャンセル時の入力保持、console errorなしを確認済み。
- session-detail 通常PLでは、申請コメントテンプレートUI、`application` / `other` のみ表示、`call` / `result` / `session_post` 混入なし、本文空欄時の反映、本文入力済み時の上書き確認、キャンセル時の本文保持、GMコメントフォームには表示しないこと、console errorなしを確認済み。
- 指定の内部識別子、認証系の生値、PC選択・申請関連の内部キーが画面、DOM、consoleに出ていないことを確認済み。

残課題は、`application` 用変数ヘルプ、`application` テンプレートでの変数置換、`other` 混線が強くなった場合の利用文脈追加検討、admin共通 / 共有テンプレート、テンプレート検索・絞り込み、説明文 / 並び順、`session_post` JSON破損時UI改善。

この工程ではQA記録のみを行い、SQL Editor実行、DB/RPC変更、フロント実装、Discord実送信、Edge Function deploy、`updates.json` 変更、commit / pushは行っていない。

## 24. M-15I-1で行わなかったこと

- SQLファイル作成
- SQL Editor実行
- DB構造変更
- RPC作成 / 変更
- GRANT / REVOKE実行
- フロント実装
- Discord実送信
- Edge Function deploy
- `updates.json` 変更
- 認証情報類の出力
- commit / push
