# M-15I テンプレート保存機能 仕様設計

## 1. 目的

M-15Hで追加したGM/admin向けテンプレ変数置換UIを土台に、GMやPLが自分用のテンプレート本文を保存し、依頼書、呼び出し、リザルト、申請などで再利用できるようにする。

固定テンプレートを配布するのではなく、ユーザーが自由本文に変数を差し込める方式を採用する。

## 2. スコープ

M-15I-1では仕様設計のみを行う。SQLファイル作成、SQL Editor実行、DB構造変更、RPC作成、フロント実装、commit / pushは行わない。

初期実装の対象は「ログインユーザー本人の個人テンプレート」に絞る。admin共通テンプレート、公開共有テンプレート、テンプレート配布機能は後続拡張候補とする。

## 3. M-15Hとの関係

M-15Hの `session-detail.html` には、GM/admin管理領域に「GM向け：呼び出しテンプレート」があり、テンプレ入力、変数置換プレビュー、置換結果コピーまで実装済み。

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

M-15I初期のフロント接続は、まずGM/admin管理領域のテンプレUIに限定する方針を推奨する。

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
template_name: 1〜60文字
template_body: 1〜4000文字
```

`template_name` は空欄不可。改行は不可。前後空白は保存前にtrimする。

`template_body` は自由本文だが空欄不可。M-15Hの参加希望コメント上限が4000文字であるため、初期テンプレ本文も4000文字上限に合わせる案を推奨する。

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

想定テーブル名は `template_presets` または `user_template_presets` を候補とする。

初期推奨は `template_presets`。理由は、将来admin共通テンプレートに拡張する場合でも、`owner_user_id` と将来の `scope` で広げやすいため。

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
- 種別フィルタ
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
- `template_presets` / `user_template_presets` など既存テーブル名との衝突有無。
- 既存text CHECK制約の書き方。

M-15I-3 RPC draftでは、テーブル作成案、RLS案、RPC案、GRANT / REVOKE案、戻り値列、rollback案をまとめる。ただし実行しない草案として扱う。

M-15I-4 apply_reviewedでは、レビュー済みのAPPLY専用SQLだけを分離する。SQL Editorで実行する場合はapply専用ファイルのみを使う方針にする。

M-15I-5ではユーザーがSQL Editorで手動適用し、Codexは実行しない。

M-15I-6ではフロント接続のみ行い、フロントからDB直UPDATE / DELETEをしない。

## 19. 今回行わないこと

- SQLファイル作成
- SQL Editor実行
- DB構造変更
- RPC作成 / 変更
- GRANT / REVOKE実行
- フロント実装
- Discord実送信
- Edge Function deploy
- `updates.json` 変更
- secret類の出力
- commit / push
