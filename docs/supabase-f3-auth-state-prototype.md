# Supabase F-3 ログイン状態表示プロトタイプ

## 1. 目的

Supabase Authのログイン状態を、dev配下のローカル専用ページで確認する。

F-3で確認すること:

- Supabase URL / publishable・anon key を手入力して接続できる
- メール / パスワードでログインできる
- 現在ログイン中かどうかを表示できる
- ログアウトできる
- 再読込後のセッション復元を確認できる
- `public_profiles` から `display_name` を取得できる

F-3では、投稿処理、参加申請RPC、GM操作RPC、本番ページ統合は扱わない。

## 2. 作成ファイル

```text
dev/supabase-auth-state-prototype.html
dev/supabase-auth-state-prototype.js
docs/supabase-f3-auth-state-prototype.md
```

必要に応じて以下へ短い参照を追加する。

```text
README.md
docs/task-backlog.md
```

## 3. 本番ページへ接続していないこと

F-3 devプロトタイプは以下を変更しない。

- `session-detail.html`
- `calendar.html`
- 既存本番用 `assets/js`
- `data/sessions.json`
- `updates.json`

`dev/` 配下の検証ページは通常導線に載せない。

## 4. 接続値・認証情報の扱い

入力するもの:

```text
Supabase URL
publishable / anon key
Email
Password
```

保存しないもの:

- Supabase URL
- publishable / anon key
- Email
- Password

これらは localStorage、sessionStorage、Cookieへ保存しない。consoleにも出さない。画面上にもkey全文やpasswordを表示しない。

禁止するもの:

- service role key
- secret key
- DB password
- Direct connection string
- `postgresql://`
- Discord bot token
- webhook URL

## 5. Supabase Authセッションの扱い

F-3では再読込後のセッション復元を確認するため、supabase-jsのAuthセッション保持は有効にする。

注意:

- これは接続値やpasswordを保存するという意味ではない
- supabase-jsが内部的にAuthセッションを保持する可能性がある
- 検証後は必ずログアウトする
- ログアウトできない場合は、同じURL/keyを再入力してからログアウトを試す

## 6. 状態表示の方針

画面に表示してよいもの:

- 未ログイン / ログイン済み
- メールアドレス
- `public_profiles.display_name`
- セッション復元確認の有無

画面に表示しないもの:

- access token
- refresh token
- JWT
- user_id全文
- discord_user_id
- service role
- secret
- password

F-3ではuser_idは表示しない。

## 7. public_profiles表示名確認

ログイン後、現在のユーザーに対応する `public_profiles.display_name` を取得する。

実装上はユーザーIDを内部的に条件へ使うが、画面には表示しない。

取得に失敗した場合は、エラー欄に人間が読めるメッセージだけを出す。tokenやkeyは出さない。

## 8. 確認できること

- メール / パスワードログイン
- ログアウト
- 再読込後のセッション復元
- `public_profiles.display_name` 取得
- user_id / discord_user_id / tokenを表示しないこと
- devページだけでAuth状態確認が完結すること

## 9. 確認できないこと

- 参加希望コメント投稿
- コメント編集
- 申請キャンセル
- GM承認 / 却下
- 〆ボタン
- 本番ページ統合時のUI
- Discord OAuth
- レート制限や連投対策

## 10. 実ブラウザ確認項目

確認URL例:

```text
http://127.0.0.1:4173/dev/supabase-auth-state-prototype.html
```

確認項目:

- Supabase URL / publishable・anon key を手入力できる
- Email / Password を手入力できる
- ログインできる
- ログイン済み状態が表示される
- メールアドレスが表示される
- `public_profiles.display_name` が表示される
- user_id / discord_user_id / tokenが表示されない
- ログアウトできる
- 再読込後、同じURL/keyを入れて状態確認するとセッション復元を確認できる
- 投稿RPCが呼ばれない
- GM操作RPCが呼ばれない
- エラー表示にURL/key/password/token全文が出ない

## 11. F-4へ進む条件

F-4へ進む条件:

- F-3 devプロトタイプでログイン / ログアウトが安定する
- 再読込後のセッション復元を確認できる
- `public_profiles.display_name` を取得できる
- token / user_id / discord_user_id が画面に出ない
- 検証後ログアウトの運用が確認できる
- 投稿UIのエラー表示、未ログイン時表示、投稿成功時表示を設計できている

F-4では、まだ本番統合ではなく、dev配下で参加希望コメント投稿プロトタイプへ進む。
