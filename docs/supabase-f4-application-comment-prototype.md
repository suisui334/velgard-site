# Supabase F-4 参加希望コメント投稿プロトタイプ

## 1. 目的

Supabase Authログイン済み文脈で、参加希望コメント投稿RPC `create_application_comment` をdev配下のローカル専用ページから確認する。

F-4で確認すること:

- Supabase URL / publishable・anon key を手入力して接続できる
- Email / Password でログインできる
- public sessions 一覧を読み取れる
- 申請可能なsessionと申請不可のsessionをUI上で区別できる
- `create_application_comment` で参加希望コメントを投稿できる
- 投稿後に `get_public_session_comments` で公開コメントを再読込できる
- 投稿後に `get_public_session_application_counts` で参加人数を再読込できる
- full / closed / finished / canceled / private / hidden など、申請不可sessionへの投稿失敗を人間向けに表示できる
- user_id全文 / token / discord_user_id を画面に出さない

F-4ではGM承認・却下、〆操作、本番ページ統合は扱わない。

## 2. 作成ファイル

```text
dev/supabase-application-comment-prototype.html
dev/supabase-application-comment-prototype.js
docs/supabase-f4-application-comment-prototype.md
```

必要に応じて以下へ短い参照を追加する。

```text
README.md
docs/task-backlog.md
```

## 3. DBへ書き込むプロトタイプであること

F-4は読み取り専用ではなく、prototype Supabase環境のテストsessionへコメントとapplication状態を書き込む。

注意:

- 本番DBでは実行しない
- 本番サイトへ接続しない
- テストsessionだけを対象にする
- コメント欄に個人情報、実Discord ID、secret類を入れない
- 繰り返し実行すると `session_comments` が増える可能性がある
- 同一ユーザーの複数コメントでも参加人数は `session_applications` の一意ユーザー単位で扱う

## 4. 本番ページへ接続していないこと

F-4 devプロトタイプは以下を変更しない。

- `session-detail.html`
- `calendar.html`
- 既存本番用 `assets/js`
- `data/sessions.json`
- `updates.json`

`dev/` 配下の検証ページは通常ナビゲーションに載せない。

## 5. 接続値・認証情報の扱い

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

これらは localStorage、sessionStorage、Cookieへ明示保存しない。consoleにも出さない。画面上にkey全文やpasswordを表示しない。

禁止するもの:

- service role key
- secret key
- DB password
- Direct connection string
- `postgresql://`
- Discord bot token
- webhook URL

Supabase Authセッション自体は、supabase-jsの内部保持により復元される可能性がある。検証後はログアウトする。

## 6. UI構成

F-4ページは以下を分けて表示する。

```text
重要な注意
接続入力欄
ログイン入力欄
ログイン状態表示
public sessions一覧
選択中session情報
コメント入力欄
投稿ボタン
公開コメントRPC結果
参加人数RPC結果
エラー表示
操作ログ
```

## 7. session選択とcanApply

public sessions一覧では以下を表示する。

```text
id
title
date
status
visibility
gm_name
canApply
```

UI上の簡易判定:

```text
申請可能: visibility = public かつ status = recruiting / tentative
申請不可: full / closed / finished / canceled / private / hidden
```

この判定はUI補助であり、権限ではない。最終判定は `create_application_comment` RPC側に任せる。

private / hidden はpublic sessions一覧に表示しない。既知のテストIDで失敗確認する場合だけ、任意session ID入力欄からRPC失敗確認に使う。

## 8. 使用RPC

投稿時:

```text
create_application_comment(target_session_id, comment_body)
```

投稿後または再読込時:

```text
get_public_session_comments(target_session_id)
get_public_session_application_counts(target_session_id)
```

F-4では以下を呼ばない。

```text
set_application_status
close_session
```

## 9. エラー表示方針

表示するもの:

- 人間向けの概要
- Supabase error の `message`
- 必要に応じて `code` / `hint`

表示しないもの:

- Supabase URL全文
- anon key全文
- access token
- refresh token
- password
- service role key
- secret key
- DB password

## 10. 確認できること

- ログイン済みplayerが申請可能sessionへ参加希望コメントを投稿できる
- 投稿後に公開コメントRPCでコメントが見える
- 投稿後に参加人数RPCを再読込できる
- full / closed / finished / canceled への投稿が失敗として表示される
- private / hidden は一覧に出ない
- user_id / discord_user_id / token が表示されない
- 本番ページへ接続していない

## 11. 確認できないこと

- GM承認 / 却下
- 〆ボタン実処理
- コメント編集
- コメント削除 / 非表示化
- rate limit / abuse対策
- Discord連携
- 本番ページ統合時のUI
- 本番ロール付与運用

## 12. 実ブラウザ確認項目

確認URL例:

```text
http://127.0.0.1:4173/dev/supabase-application-comment-prototype.html
```

確認項目:

- Supabase URL / publishable・anon key を手入力できる
- Email / Password でログインできる
- ログイン状態が表示される
- public sessionsのみ表示される
- private / hidden が一覧に出ない
- recruiting / tentative が申請可能表示になる
- full / closed / finished / canceled が申請不可表示になる
- `create_application_comment` で投稿できる
- 投稿後に公開コメントRPC結果へ反映される
- 投稿後に参加人数RPC結果を再読込できる
- 申請不可sessionへの投稿失敗が人間向けに表示される
- GM操作RPCが呼ばれない
- user_id / token / discord_user_id が表示されない
- URL/key/password/token全文がエラーやログに出ない
- 検証後にログアウトできる

## 13. F-5へ進む条件

F-5へ進む条件:

- F-4 devページで投稿成功と投稿失敗の両方を確認できる
- 公開コメントRPCと参加人数RPCの再読込が安定する
- 参加人数がコメント件数ではなく申請者単位で扱われることを確認できる
- full / closed / finished / canceled がRPC側で拒否される
- private / hidden が一覧に出ない
- secret類が画面、ログ、ファイルに出ない
- 検証後ログアウト運用が確認できる

F-5では、GM承認・却下のdevプロトタイプへ進む前に、GM向けUIの表示範囲、誤操作防止、変更履歴、ロール付与運用を整理する。

## 14. 本番統合前に必要な設計事項

- 本番 `session-detail.html` へ統合するか、別ページで段階導入するか
- 投稿失敗時の利用者向け文言
- 未ログイン時の案内
- 申請済みユーザーの再投稿表示
- pending / accepted / rejected / waitlisted / canceled の表示文言
- コメントの公開範囲と削除・非表示方針
- rate limit / 連投対策
- GM / admin ロール付与運用
- 本番DBとprototype DBの分離
- ロールバック手順
