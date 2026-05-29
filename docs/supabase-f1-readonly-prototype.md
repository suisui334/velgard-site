# Supabase F-1 ローカル読み取り専用プロトタイプ

## 1. 目的

Supabase連携を公開サイト本体へ入れる前に、ローカル専用ページで読み取りだけを確認する。

この工程の目的は以下。

- public session の読み取りができるか確認する
- 公開コメント表示RPCが内部情報を返さないか確認する
- 参加人数RPCが public session の範囲で読めるか確認する
- GitHub Pages公開版の `session-detail.html` / `calendar.html` / 既存 `assets/js` を壊さない
- 投稿、Authログイン、本番接続の前に、読み取り専用の影響範囲を切り分ける

## 2. 作成ファイル

```text
dev/supabase-readonly-prototype.html
dev/supabase-readonly-prototype.js
docs/supabase-f1-readonly-prototype.md
```

`dev/` 配下は検証用であり、サイトの通常導線やナビゲーションからリンクしない。

## 3. 本番ページへ接続していないこと

F-1では以下を行わない。

- `session-detail.html` へのSupabase接続追加
- `calendar.html` へのSupabase接続追加
- 既存本番用 `assets/js` へのSupabase client追加
- コメント投稿RPCの呼び出し
- Authログイン処理
- Supabase上での追加SQL実行
- GitHub Pages公開ページへの組み込み

## 4. 接続値の扱い

`dev/supabase-readonly-prototype.html` では、接続値を手入力する。

入力するもの:

- Supabase URL
- publishable / anon key

禁止するもの:

- service role key
- secret key
- DB password
- JWT secret
- Discord bot token
- webhook URL

入力値は localStorage に保存しない。スクリプトは接続値を `console.log` へ出さず、エラー表示でもURLや長いtoken風文字列を伏せる。

## 5. 読み取り対象

### public sessions

Supabase `sessions` から以下の列を読み取る。

```text
id
title
date
status
visibility
gm_name
```

確認したいこと:

- `visibility = public` のsessionだけが表示される
- private / hidden session が混ざらない
- `full` / `closed` / `finished` / `canceled` も公開sessionとして読める
- 申請可否はここでは更新せず、表示確認に留める

### public comment RPC

以下のRPCを呼ぶ。

```text
get_public_session_comments
```

表示対象は以下に限定する。

```text
comment_id
session_id
display_name
body
application_status
created_at
updated_at
edited_at
```

`user_id`、`discord_user_id`、`email`、`role` は表示しない。

### application count RPC

以下のRPCを呼ぶ。

```text
get_public_session_application_counts
```

表示対象は以下。

```text
session_id
accepted_count
pending_count
waitlisted_count
```

参加人数はコメント件数ではなく `session_applications` の一意ユーザー単位で数える方針を維持する。

## 6. 使い方

ローカルサーバーで開く。

```powershell
py -m http.server 4173 -d velgard-site
```

確認URL:

```text
http://127.0.0.1:4173/dev/supabase-readonly-prototype.html
```

手順:

1. Supabase URL と publishable / anon key を入力する
2. テスト用 public session id を確認する
3. 「読み取りテスト実行」を押す
4. public sessions、公開コメントRPC、参加人数RPCの表示を見る
5. エラー欄に secret 類や接続値全文が出ていないことを確認する

## 7. 確認できること

- public session の読み取り
- private / hidden が public sessions 一覧に混ざらないこと
- 公開コメントRPCが内部 `user_id` / `discord_user_id` を返さないこと
- 参加人数RPCが読み取れること
- 読み取り専用のSupabase接続が本番ページから分離されていること

## 8. 確認できないこと

- Authログイン後のRLS挙動
- コメント投稿
- コメント編集
- 申請キャンセル
- GM承認 / 却下
- 〆ボタン
- 本番ページ統合時のUI
- レート制限や連投対策
- Discord同期

これらはStep 10のローカルAuth文脈RLSスモークテスト、または今後のF-2以降で扱う。

## 9. F-2へ進む条件

F-2へ進む条件:

- F-1で public sessions が読める
- 公開コメントRPCに内部 `user_id` / `discord_user_id` が出ない
- 参加人数RPCで private / hidden の情報が漏れない
- service role / secret key を使わずに確認できる
- GitHub Pages公開ページへ接続コードを入れていない
- 投稿UIやAuth UIの影響範囲を別途設計できている

推奨される次工程は、まだ本番統合ではなく、読み取り専用プロトタイプの実ブラウザ確認である。
