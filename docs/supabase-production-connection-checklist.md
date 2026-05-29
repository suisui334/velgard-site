# Supabase本番接続前チェックリスト

## 1. 目的

このチェックリストは、ヴェルガルド公開サイトをSupabaseへ接続する前の停止条件を整理するもの。

Auth文脈RLSスモークテストは `PASS 19 / FAIL 0 / SKIP 1` まで通過したが、これは本番UI接続の準備が完了したことを意味しない。

## 2. まだ本番接続しない条件

以下が1つでも未解決なら、公開中のGitHub PagesサイトへSupabase接続コードを入れない。

- 本番用接続方式が未確定。
- フロントで使うkeyが publishable / anon 相当であることを未確認。
- フロントで `service_role` やsecret keyを使わないことを未確認。
- 本番用テーブルとプロトタイプテーブルの分離方針が未確定。
- エラー時のUIが未設計。
- 投稿失敗時の利用者向け案内が未設計。
- コメント投稿の荒らし対策・連投対策が未設計。
- GM / admin 権限付与運用が未確定。
- Discord ID公開/非公開の境界が未確認。
- 投稿内容の公開範囲が未確認。
- rollback手順が未整理。
- バックアップ方針が未整理。

## 3. 接続前に決めること

本番接続コードを書く前に、以下を決める。

- 既存 `session-detail.html` に直接組み込むか。
- まず別ページまたは開発用ブランチで試すか。
- static `data/sessions.json` とSupabase `sessions` のどちらを正本にするか。
- 静的モックとDBデータの切り替え方式。
- Supabase取得失敗時に静的表示へフォールバックするか。
- 参加申請コメント投稿後の表示。
- `pending` / `accepted` / `rejected` / `waitlisted` / `canceled` の表示文言。
- GM承認・却下画面の場所。
- admin操作をどこまでフロントに出すか。
- 認証UIをどう導入するか。
- ログアウトとアカウント切り替えをどう扱うか。
- 参加申請コメントが公開欄であることを利用者へどう伝えるか。

## 4. 推奨次工程

次工程では、いきなり本番公開ページへ接続しない。

推奨:

```text
案B：Supabase連携のフロント設計書を先に作る
```

理由:

- 現在の公開サイトは安定している。
- 直接 `session-detail.html` に接続すると影響範囲が広い。
- 認証、投稿失敗、表示切り替え、fallback、ロール別UIを先に決める必要がある。

代替:

```text
案A：ローカル専用の開発用HTML/JSで投稿UIプロトタイプを作る
```

この場合も、GitHub Pages本体へ混ぜない。secretや実値は入れない。

## 5. 本番接続前の最低確認

本番接続ブランチを作る前に、以下を確認する。

- RLSスモークテスト結果が `PASS 19 / FAIL 0 / SKIP 1` 以上で維持されている。
- 意図的SKIPの内容を説明できる。
- 本番コードが `service_role` keyを必要としない。
- secret、DB password、token、private keyをcommitしない。
- `.env.local` がGit管理対象外のまま。
- `node_modules/` がGit管理対象外のまま。
- public RPCが内部 `user_id` を返さない。
- public RPCが `discord_user_id` を返さない。
- unrelated user が private / hidden session を読めない。
- `full` / `closed` / `finished` / `canceled` は新規申請不可。
- コメント件数を参加人数として扱っていない。
- バックアップ手順がある。
- rollback手順がある。
- admin復旧手順がある。

## 6. まだ対象外

以下は、現時点では公開サイト未実装。

- GitHub Pages本体からSupabaseへの接続。
- `session-detail.html` からの実コメント投稿。
- 実コメント編集UI。
- GM承認・却下UI。
- admin管理UI。
- Discord bot / Webhook同期。
- Edge Functions。
- 本番ロール管理運用。
- 荒らし対策。

## 7. 停止ルール

Supabase連携の実装中に、secret keyの露出、RLS無効化、RLS迂回、ブラウザからの `service_role` 利用が必要になった場合は、ただちに実装を止めて設計へ戻る。
