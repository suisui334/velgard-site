# Supabase F-6 コメント編集・削除devプロトタイプ設計書

## 1. 目的

F-6 devプロトタイプは、コメント編集・削除RPCを本番 `session-detail.html` に統合する前の検証足場である。

確認したいこと:

- コメント者が自分の参加希望コメントを編集できる
- コメント者が自分の参加希望コメントを削除できる
- GMが自分のsessionに紐づくコメントを編集・削除できる
- 他人、他GM、未ログイン、anonが編集・削除できない
- 削除時に `session_applications` の状態が想定どおり変化する
- 削除済みコメントが公開コメント一覧に出ない
- `canceled` が参加人数に含まれない

このプロトタイプは本番UIの完成形ではない。RLS / RPC / 状態変更の挙動を、dev配下のローカル専用ページで確認するためのもの。

## 2. 対象RPC

対象:

| RPC | 引数 | 用途 |
| --- | --- | --- |
| `update_application_comment` | `target_comment_id uuid`, `comment_body text` | コメント本文の編集 |
| `delete_application_comment_and_maybe_cancel` | `target_comment_id uuid` | コメントの論理削除と、必要時の申請取消 |

対象外:

- `close_session`
- `set_application_status` の追加検証
- Discord連携
- 通知
- 本番 `session-detail.html` 統合

## 3. devプロトタイプ方針

F-6はdev配下に新規分離する。

候補ファイル:

```text
dev/supabase-comment-edit-delete-prototype.html
dev/supabase-comment-edit-delete-prototype.js
docs/supabase-f6-comment-edit-delete-prototype.md
```

既存F-4 / F-5を直接肥大化させない。

理由:

- PL投稿UI、GM承認UI、コメント編集削除UIは責務が違う
- 削除操作は状態変更が重い
- RLS / RPCの検証を切り分けやすい
- 本番統合前に安全に確認できる

## 4. 画面構成案

F-6 devプロトタイプでは、次のセクションを置く。

```text
重要な注意
接続入力欄
ログイン入力欄
ログイン状態
public sessions一覧
自分がGMのsessions一覧
選択中session
コメント一覧
自分のコメント編集フォーム
自分のコメント削除ボタン
GM用コメント編集ボタン
GM用コメント削除ボタン
操作結果
エラー表示
参加人数RPC表示
状態変化確認欄
権限チェックリスト
```

表示してよいもの:

- `session_id`
- session title
- `display_name`
- `comment_id`
- comment body
- `application_status`
- `is_application`
- `created_at`
- `updated_at`
- `edited_at`
- `deleted_at` の有無

表示してはいけないもの:

- `user_id` 全文
- `discord_user_id`
- email
- access token
- refresh token
- service role key
- secret key
- password

`comment_id` は操作対象識別に必要なため、表示または内部保持してよい。

現行の `get_public_session_comments` は、公開表示用に絞られたRPCであり、`user_id` / Discord ID / emailを返さない。一方で、`is_application` や `deleted_at` を返さない可能性がある。その場合、F-6 dev初期版では「公開RPCで確認できる範囲」と「追加RPC / viewが必要な範囲」を画面上とdocsに分けて記録する。

## 5. 接続・認証情報の扱い

F-4 / F-5と同じく、接続値は手入力にする。

入力欄:

```text
Supabase URL
Publishable / anon key
Email
Password
```

保存禁止:

- Supabase URL / keyをlocalStorageへ保存しない
- Supabase URL / keyをsessionStorageへ保存しない
- Email / PasswordをlocalStorageへ保存しない
- Email / PasswordをsessionStorageへ保存しない
- Cookieへ保存しない
- consoleへURL / key / password / tokenを出さない
- 画面にkey全文やpasswordを表示しない

Supabase Authセッション保持は、supabase-jsの通常挙動として発生しうる。検証後は必ずログアウトする。

## 6. 編集操作方針

編集操作では、次を守る。

- コメント本文を編集できる
- 空文字は送らない
- 4000字超過は送らない
- 操作前に対象コメントを明示する
- 操作前に確認対象sessionとcommentを表示する
- 成功後にコメント一覧を再読込する
- 成功後に `edited_at` が変わることを確認する
- 失敗時は人間向けエラーを表示する

権限確認:

- 本人は自分のコメントを編集できる
- 本人は他人のコメントを編集できない
- GMは自分のsessionのコメントを編集できる
- GMは他GM sessionのコメントを編集できない
- 未ログイン / anonは編集できない
- 削除済みコメントは編集できない

## 7. 削除操作方針

削除は論理削除であり、物理削除ではない。

削除操作では、次を守る。

- 削除前に必ず確認ダイアログを挟む
- 削除対象コメントを明示する
- 論理削除であることを画面に明記する
- 成功後にコメント一覧を再読込する
- 削除済みコメントが公開RPCに出ないことを確認する
- 最後の有効申請コメント削除時にapplicationが `canceled` になることを確認する
- `accepted` 済み申請の最後の有効コメント削除は重い操作として警告する

推奨警告文:

```text
このコメントを削除します。最後の有効な参加希望コメントの場合、参加申請が取消扱いになる可能性があります。よろしいですか？
```

accepted済み申請向け警告:

```text
この申請は承認済みです。最後の有効コメントを削除すると、申請が取消扱いになる可能性があります。対象と状態を確認してください。
```

## 8. 権限確認項目

docsと画面上のチェックリストに含める項目:

- 本人が自分のコメントを編集できる
- 本人が他人のコメントを編集できない
- GMが自分のsessionコメントを編集できる
- GMが他GM sessionコメントを編集できない
- 未ログインでは編集できない
- 本人が自分のコメントを削除できる
- 本人が他人のコメントを削除できない
- GMが自分のsessionコメントを削除できる
- GMが他GM sessionコメントを削除できない
- 未ログインでは削除できない
- 削除済みコメントは編集できない
- 削除済みコメントは公開コメント一覧に出ない
- `canceled` は参加人数に含まれない

## 9. 状態変更テストの注意

F-6 devプロトタイプはDB状態を変更する。

注意:

- テストDB限定
- 本番DBで実行しない
- 削除は論理削除だが元には戻さない前提
- 削除成功テストは対象コメントを慎重に選ぶ
- `accepted` 済み申請の最後の有効コメント削除は原則避ける
- 必要なら再seedまたは手動復旧を行う
- 操作前後のapplication statusと人数RPCを画面上で確認する

## 10. 本番統合前の条件

本番 `session-detail.html` 統合前に必要な条件:

- F-6 devプロトタイプ確認完了
- RLS smoke test `FAIL 0` 維持
- コメント編集・削除のUI文言確定
- 削除時の確認ダイアログ文言確定
- `accepted` 済み申請削除時の運用決定
- `session-detail.html` 統合前UX設計
- PL向け表示とGM向け表示の切り分け
- 追加RPC / viewが必要か判断する

## 11. F-6 devプロトタイプではまだ扱わないもの

F-6 devプロトタイプでは、以下を扱わない。

- 本番 `session-detail.html` 実装
- 本番 `calendar.html` 実装
- Discord OAuth
- Discord通知
- メール通知
- Edge Functions
- `close_session`
- GM/admin本番管理画面
- `RUN_DESTRUCTIVE_TESTS=true` の自動実行

## 12. 次工程候補

次工程候補:

1. F-6 devコメント編集・削除プロトタイプ設計書のcommit / push
2. dev配下にF-6コメント編集・削除プロトタイプを実装
3. ユーザー実ブラウザ確認
4. 確認結果docs記録
5. 本番 `session-detail.html` 統合前UX設計

実装ファイルは `dev/supabase-comment-edit-delete-prototype.html` / `dev/supabase-comment-edit-delete-prototype.js`、実装メモは `docs/supabase-f6-comment-edit-delete-prototype.md` に分離する。
