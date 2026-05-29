# Supabase F-6 コメント編集・削除 dev プロトタイプ

## 1. 目的

F-6 dev プロトタイプは、コメント編集・論理削除 RPC を本番 `session-detail.html` へ統合する前に、Auth 文脈での操作可否と状態変化を確認するための検証用ページです。

確認すること:

- コメント者が自分の参加希望コメントを編集できる
- コメント者が自分の参加希望コメントを論理削除できる
- GM が自分のセッションに紐づくコメントを編集・論理削除できる
- 他人、他 GM、未ログイン、anon が操作できない
- 論理削除後、公開コメント RPC に削除済みコメントが出ない
- 最後の有効申請コメント削除時、application が `canceled` になるか確認できる
- `canceled` が参加人数に含まれないか確認できる

## 2. 作成ファイル

```text
dev/supabase-comment-edit-delete-prototype.html
dev/supabase-comment-edit-delete-prototype.js
docs/supabase-f6-comment-edit-delete-prototype.md
```

このページは dev 配下限定です。GitHub Pages 本番導線、`session-detail.html`、`calendar.html`、既存本番用 `assets/js` には接続していません。

## 3. 日本語 UI 整理

ユーザー実ブラウザ確認で「項目が多い」「英語表記が多い」「操作順が分かりにくい」という課題が出たため、画面上の主要ラベル、ボタン、説明文を日本語中心に整理しました。

画面上部には、確認手順を以下の5段階として表示しています。

1. 接続する
2. ログインする
3. セッションを選ぶ
4. コメントを編集してみる
5. テスト用コメントだけ削除してみる

また、確認内容を以下の3種類に分けています。

- 通常確認: 表示、ログイン、コメント編集
- 注意確認: テスト用コメントの削除
- 避ける確認: 承認済みの最後の有効コメント削除

削除操作はテスト用コメント限定で行う想定です。承認済み申請の最後の有効コメント削除は、申請取消扱いにつながる可能性があるため原則避けます。

## 4. 対象 RPC

| RPC | 引数 | 用途 |
| --- | --- | --- |
| `update_application_comment` | `target_comment_id uuid`, `comment_body text` | 参加希望コメント本文の編集 |
| `delete_application_comment_and_maybe_cancel` | `target_comment_id uuid` | コメントの論理削除と、必要時の申請取消 |

`close_session` は対象外です。`set_application_status` の追加検証もこの F-6 画面では扱いません。

## 5. 画面構成

画面は以下の領域に分けています。

- 重要な注意
- 確認手順
- 確認の種類
- 接続入力欄
- ログイン入力欄
- ログイン状態
- 公開セッション一覧
- 自分が GM のセッション一覧
- 選択中セッション
- コメント一覧
- 選択中コメント
- コメント編集フォーム
- テスト用コメント削除
- 参加人数 RPC 表示
- 状態変化確認欄
- 操作結果
- エラー表示
- 操作ログ
- 権限確認チェックリスト
- 確認メモ

## 6. 確認メモ欄

画面内に保存しない簡易チェック欄を追加しています。

- ページが開いた
- ログインできた
- セッション一覧が出た
- コメント一覧が出た
- 自分のコメントを編集できた
- テスト用コメントだけ削除できた
- secret 類は画面に出ていない

このチェック欄はブラウザ上で確認を進めるためのメモです。DB や localStorage には保存しません。

## 7. 表示する情報 / 表示しない情報

表示してよい情報:

- `session_id`
- セッションタイトル
- `display_name`
- `comment_id`
- コメント本文
- `application_status`
- `is_application` 相当の補助表示
- `created_at`
- `updated_at`
- `edited_at`
- `deleted_at` の有無または公開 RPC での非表示状態

表示しない情報:

- `user_id` 全文
- `discord_user_id`
- access token
- refresh token
- service role key
- secret key
- password

ログイン状態ではメールアドレスを表示しますが、URL、key、password、token は表示しません。

## 8. 接続・認証情報の扱い

Supabase URL、publishable / anon key、メールアドレス、パスワードは手入力です。

- 入力値を localStorage / sessionStorage / Cookie へ保存しない
- Supabase client は `persistSession: false` で作成する
- service role key、secret key、DB password、Direct connection string らしき値は拒否する
- console へ URL / key / password / token を出さない
- 検証後はログアウトする

## 9. コメント一覧の取得方針

コメント本文は、現行の公開表示 RPC `get_public_session_comments` で取得できる範囲を表示します。

申請状態や `comment_id` は、ログイン中ユーザーに RLS 上見える範囲の `session_applications` から補完します。

注意:

- `session_comments` を直接 SELECT しない
- 公開 RPC が返さない内部 `user_id`、Discord ID、email は表示しない
- 非公開 / 非表示セッションのコメント本文は現行公開 RPC では取得できない
- GM 向けに非公開 / 非表示を含む本文管理が必要なら、将来 GM 用 RPC / view を別途検討する

## 10. 編集操作方針

編集は `update_application_comment` を使います。

```js
await supabase.rpc("update_application_comment", {
  target_comment_id: commentId,
  comment_body: body
});
```

画面側で行うこと:

- 空文字は送らない
- 4000字超過は送らない
- 操作前に対象セッション / コメントを明示する
- 本人用編集と GM 用編集を UI 上で分ける
- 成功後にコメント一覧と参加人数 RPC を再読込する
- 成功後に `edited_at` の変化を確認できるようにする
- 失敗時は Supabase error の message / code / hint 相当を安全に表示する

## 11. 削除操作方針

削除は `delete_application_comment_and_maybe_cancel` を使います。

```js
await supabase.rpc("delete_application_comment_and_maybe_cancel", {
  target_comment_id: commentId
});
```

削除は論理削除です。物理削除ではありません。

画面側で行うこと:

- 必ず確認ダイアログを挟む
- 「これはテスト用コメントです」チェックボックスを入れるまで削除ボタンを押せない
- 削除対象セッション / コメントを明示する
- 削除後はこの画面では戻さない前提であることを表示する
- 承認済み申請の最後の有効コメント削除は強く警告する
- 成功後にコメント一覧と参加人数 RPC を再読込する
- 削除 RPC 戻り値の `application_status`、`application_canceled`、`active_application_comment_count` を表示する
- 削除済みコメントが公開コメント一覧に出ないことを確認する

## 12. 権限確認項目

画面上のチェックリストで、以下を確認します。

- 本人が自分のコメントを編集できる
- 本人が他人のコメントを編集できない
- GM が自分のセッションコメントを編集できる
- GM が他 GM セッションコメントを編集できない
- 未ログインでは編集できない
- 本人が自分のコメントを削除できる
- 本人が他人のコメントを削除できない
- GM が自分のセッションコメントを削除できる
- GM が他 GM セッションコメントを削除できない
- 未ログインでは削除できない
- 削除済みコメントは編集できない
- 削除済みコメントは公開コメント一覧に出ない
- `canceled` は参加人数に含まれない

## 13. 状態変更テストの注意

F-6 dev プロトタイプは DB 状態を変更します。

- テスト DB 限定
- 本番 DB で実行しない
- 論理削除は元に戻さない前提
- 削除成功テストは対象コメントを慎重に選ぶ
- 承認済み申請の最後の有効コメント削除は原則避ける
- 必要なら再 seed または手動復旧を行う
- 操作前後の申請状態と参加人数 RPC を確認する

## 14. 既知の制限

- 現行の `get_public_session_comments` は公開表示用 RPC であり、非公開 / 非表示セッションのコメント本文取得には使わない。
- 公開 RPC が `is_application` / `deleted_at` を返さない場合、画面では「公開 RPC では未返却」または「公開 RPC に出ない」と表示する。
- `session_applications.comment_id` から操作対象を特定できるが、内部 `user_id` は表示しない。
- GM 向けに非公開 / 非表示を含む安全なコメント本文管理を行うには、将来 GM 用 RPC / view の追加検討が必要。
- 削除成功系は状態変更が重いため、ユーザー実ブラウザ確認では対象コメントを慎重に選ぶ。

## 15. 本番統合前の残課題

- `session-detail.html` 統合前 UX 設計
- PL 向け表示と GM 向け操作 UI の切り分け
- コメント編集・削除の文言確定
- 承認済み申請削除時の運用確定
- GM 用 RPC / view の要否判断
- 論理削除後の復旧運用
- F-6 dev 確認結果 docs 記録
- RLS smoke test `FAIL 0` の維持確認

## 16. まだ扱わないもの

- 本番 `session-detail.html` 実装
- 本番 `calendar.html` 実装
- Discord OAuth
- Discord通知
- メール通知
- Edge Functions
- `close_session`
- GM/admin本番管理画面
- `RUN_DESTRUCTIVE_TESTS=true` の自動実行

## 17. F-7 UX設計への接続

F-6 devプロトタイプで確認したコメント編集・論理削除の挙動は、`docs/supabase-f7-session-detail-integration-ux-plan.md` に引き継ぐ。
F-7では、本番 `session-detail.html` へ実装する前に、PL / GM / 未ログインの表示分岐、申請状態文言、削除警告、段階統合方針を整理する。
F-7時点でも、本番ページ接続、追加SQL実行、`close_session`、Discord連携は扱わない。
