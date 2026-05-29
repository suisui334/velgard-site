# Supabase F-5 GM承認・却下devプロトタイプ

## 1. 目的

F-5では、GMが自分のセッション申請を確認し、申請状態を `accepted` / `rejected` へ変更できるかをdev配下のローカル専用ページで検証する。

確認すること:

- GMが自分のsession申請を読める
- GMが自分のsession申請を `accepted` / `rejected` に変更できる
- GMが他GMのsession申請を操作できない
- playerが承認・却下操作できない
- 未ログインでは操作できない
- 操作後に参加人数RPCを再読込できる
- `accepted_count` / `pending_count` の変化を確認できる
- `rejected` を人数に含めない

## 2. 作成ファイル

```text
dev/supabase-gm-application-management-prototype.html
dev/supabase-gm-application-management-prototype.js
docs/supabase-f5-gm-application-management-prototype.md
```

必要に応じて以下へ短い参照を追加する。

```text
README.md
docs/task-backlog.md
```

## 3. 本番ページ未接続

F-5 devプロトタイプは以下を変更しない。

- `session-detail.html`
- `calendar.html`
- 既存本番用 `assets/js`
- `data/sessions.json`
- `updates.json`

`dev/` 配下の検証ページは通常ナビゲーションに載せない。

## 4. 対象RPC

対象RPC:

```text
set_application_status
```

呼び出し引数:

```js
await supabase.rpc("set_application_status", {
  target_application_id: applicationId,
  new_status: "accepted"
});
```

却下時:

```js
await supabase.rpc("set_application_status", {
  target_application_id: applicationId,
  new_status: "rejected"
});
```

F-5では `close_session` は呼ばない。

## 5. 画面構成

画面には以下を表示する。

```text
重要な注意
接続入力欄
ログイン入力欄
ログイン状態
public sessions一覧
自分がGMのsession一覧
選択中session
申請一覧
承認ボタン
却下ボタン
再読込ボタン
操作結果
エラー表示
参加人数RPC表示
権限確認チェックリスト
操作ログ
```

## 6. 表示する情報 / 表示しない情報

表示してよいもの:

```text
session_id
session title
display_name
comment body
application_status
created_at
updated_at
edited_at
application_id
```

表示しないもの:

```text
user_id全文
discord_user_id
access_token
refresh_token
service_role
secret key
password
DB password
```

`application_id` は操作対象識別のため表示する。内部 `user_id` は表示しない。

## 7. 操作手順

1. ローカルサーバーを起動する。

```powershell
py -m http.server 4173 -d velgard-site
```

2. devページを開く。

```text
http://127.0.0.1:4173/dev/supabase-gm-application-management-prototype.html
```

3. Supabase URL / publishable・anon key を手入力する。
4. GMテストユーザーでログインする。
5. `sessionsを読む` を押す。
6. `自分がGMのsession一覧` から対象sessionを選ぶ。
7. 申請一覧を確認する。
8. 対象申請の `承認` または `却下` を押す。
9. 確認ダイアログで対象session / display_name / 現在statusを確認して実行する。
10. 操作後、申請一覧と参加人数RPCが再読込されることを確認する。

## 8. session / application取得方針

session:

- public sessionsは `visibility = 'public'` で取得する。
- 自分がGMのsessionは、ログイン中ユーザーの `auth.users.id` と `sessions.gm_user_id` が一致するものを取得する。
- `gm_user_id` は条件に使うが、画面には表示しない。

application:

- `session_applications` から `id` / `session_id` / `status` / `comment_id` / `created_at` / `updated_at` を取得する。
- public sessionでは `get_public_session_comments` の結果と `comment_id` で突き合わせ、display_name / comment bodyを表示する。
- 非public sessionでは、現行public RPCではcomment body / display_nameを取得しない。必要ならGM用RPCまたはviewを後続で設計する。

## 9. 権限確認項目

- GM Aでログインした場合、GM Aのsession申請を読める
- GM Aで、GM Aのsession申請をacceptedにできる
- GM Aで、GM Aのsession申請をrejectedにできる
- GM Aで、GM Bのsession申請を操作できない
- GM Bで、GM Aのsession申請を操作できない
- player Aで承認・却下操作できない
- 未ログインでは操作できない
- 操作後、参加人数RPCが更新される
- accepted_count / pending_count の変化を確認できる
- rejectedを人数に含めない

adminは確認対象に含めてよいが、F-5 UIでは全体管理機能を強く出さない。

## 10. 状態変更テストの注意

F-5はDB状態を変更する。

- テストDB限定で実行する
- 本番DBで実行しない
- 操作前に対象sessionとapplicationを確認する
- 操作後はDB状態が変わる
- 同じ申請に対して再操作した場合の挙動を確認する
- 必要なら再seedまたは手動で状態を戻す
- 本番導入前に「承認済みを取り消す」設計も別途検討する

## 11. 既知の制限

- 非public sessionのコメント本文とdisplay_nameは、現行のpublic comments RPCでは取得しない。
- 非public sessionのGM向け申請一覧を本文つきで安全に出すには、将来的にGM用RPCまたはviewが必要になる可能性がある。
- F-5では `waitlisted` / `canceled` 操作UIは主対象にしない。
- F-5では `close_session` を扱わない。
- 操作ログはdev画面上の簡易表示であり、DB監査ログではない。

## 12. 本番統合前の残課題

- GM向け申請一覧専用RPC / viewの必要性判断
- 誤操作時の戻し方
- 本番GM付与運用
- admin復旧手順
- 操作履歴 / 監査ログ
- 承認済み取り消し設計
- waitlisted / canceled の扱い
- 本番UIでの確認ダイアログ文言
- RLS smoke test再実行
- rollback / backup手順

## 13. 実ブラウザ確認結果

F-5 dev GM承認・却下プロトタイプは、ユーザー実ブラウザ確認済み。

確認済み:

- ページ表示: OK
- 接続: OK
- GMログイン: OK
- public sessions表示: OK
- 自分がGMのsession表示: OK
- 申請一覧表示: OK
- `accepted` 変更: OK
- `rejected` 変更: OK
- 参加人数RPC再読込: OK
- player / 未ログイン操作不可: OK
- secret類の画面表示なし: OK
- エラーなし

この確認では、本番ページ接続、Supabase追加SQL、`close_session` 呼び出しは行っていない。

## 14. F-5 devプロトタイプの位置づけ

このdevプロトタイプは本番UIの完成形ではない。

位置づけ:

- 権限、RPC、RLS、状態変更を確認するための検証足場
- `set_application_status` による `accepted` / `rejected` 変更の確認用
- 本番GM管理画面の完成形ではない
- 本番では専用GM一覧ページを前面に出すより、`session-detail.html` 側への統合を想定する

## 15. 本番UI方針

本番統合時は、以下を基本方針にする。

- `session-detail.html` のセッション詳細ページに参加希望コメント欄を統合する
- GMのみ、参加希望コメント一覧上で承認・却下などの管理操作が見える
- PLには自分の投稿、申請状態、必要な案内だけを見せる
- GM操作は、選択中セッションのコメント一覧上で行う
- 専用GM一覧ページを作る場合も、まずは補助的な管理導線として扱う

## 16. コメントと参加申請の正本方針

本番統合時の基本方針:

- コメント投稿 = 参加申請の意思表示
- コメントしたユーザーは自動的に参加申請扱いになる
- 参加人数はコメント件数ではなく、`session_id + user_id` の一意ユーザー単位で数える
- 同一ユーザーが複数コメントしても申請人数は1人分
- 人数集計は `session_applications` を基準にする

## 17. コメント編集・削除方針

本番統合時の初期方針:

- コメント者は自分のコメントを編集できる
- コメント者は自分のコメントを削除できる
- GMは管理権限でコメント編集・削除できる想定
- コメント削除時、そのユーザーの有効な参加申請が残らない場合は申請人数から外れる

削除と申請取消の暫定方針:

- 本番初期案では、最後の有効コメントを削除した場合、そのユーザーの参加申請は取消扱いとし、人数から除外する
- 将来的に `cancelled` / `withdrawn` などの明示ステータスを持たせるかは別途検討する

## 18. データ設計上の注意

- `session_comments` はコメント本文を扱う
- `session_applications` は `session_id + user_id` 単位の申請状態を扱う
- 人数集計は `session_applications` を基準とする
- コメント件数を人数として扱わない
- `rejected` / `cancelled` / `withdrawn` 相当は参加人数に含めない

## 19. 本番統合前の追加残課題

- GM用の安全なコメント・申請管理RPC / viewの要否
- コメント編集RPC
- コメント削除RPC
- 削除時に申請を取り下げるRPC
- 承認済みを取り消す操作
- 申請取消ステータス `cancelled` / `withdrawn` の要否
- `session-detail.html` への段階統合方針
- GMにのみ操作UIを表示する条件
- PLに見せる申請状態表示
- 誤操作時の戻し方
