# Supabase Step 11 RLS smoke test FAIL修正計画

## 1. 目的

Auth文脈RLSスモークテストで出たFAILを、追加SQL実行前に整理するための修正計画です。

この段階では、まだSupabase上で追加SQLを実行しません。GitHub Pages本体へのSupabase接続コードも追加しません。

## 2. 現在のFAIL概要

| テストID | 内容 | 主要エラー | 推定原因 |
| --- | --- | --- | --- |
| AUTH-001 | anon session select | `permission denied for table sessions` / `42501` | `sessions` のData API向け `SELECT` grant不足 |
| AUTH-006 | player A application select | `permission denied for table session_applications` / `42501` | `session_applications` のauthenticated向け `SELECT` grant不足 |
| AUTH-011 | player A other GM application select | `permission denied for table session_applications` / `42501` | 同上 |
| AUTH-014 | GM status update | `set_application_status(new_status)` が見つからない | 前段のapplication ID未取得により `target_application_id` がRPC引数から落ちた可能性 |
| AUTH-019 | admin session select | `permission denied for table sessions` / `42501` | `sessions` のauthenticated向け `SELECT` grant不足 |

## 3. SQL修正草案

修正候補は `docs/supabase/sql/007_rls_smoke_fix_grants_draft.sql` に分離しています。

中心となる修正：

```sql
grant select on table public.sessions to anon, authenticated;
grant select on table public.session_applications to authenticated;
```

意図：

- `sessions` は `anon` / `authenticated` がData API経由でSELECTできるようにする。
- private / hidden の漏洩は、既存RLS policyで引き続き防ぐ。
- `session_applications` は `authenticated` がData API経由でSELECTできるようにする。
- applicationの見える範囲は、既存RLS policyで本人 / 対象GM / admin に制限する。
- `session_comments` は直接SELECTを広げない。
- 公開コメント表示は `get_public_session_comments()` 経由を維持する。

## 4. スクリプト修正

`scripts/supabase-rls-smoke-test.mjs` では、以下を修正済みです。

- `.env.local` の明示読み込みを維持。
- Supabase error object の `message` / `code` / `details` / `hint` / `status` / `name` 表示を維持。
- application ID / comment ID が取れていない場合、後続RPCへ `undefined` を渡さない。
- `requireId()` で、前段のapplication/comment作成またはSELECT失敗が分かるFAILにする。
- `set_application_status()` のRPC引数名はSQL定義通り `target_application_id` / `new_status` を使う。

## 5. SQL実行前チェック

`007_rls_smoke_fix_grants_draft.sql` を実行する前に、以下を確認します。

- Step 4-1〜4-4は実行済み。
- Step 5 seedは実行済み。
- 現在のFAILが `42501` のGRANT不足中心である。
- `session_comments` の直接SELECT grantを追加しようとしていない。
- Project URL / API key / password / secret類をSQLやdocsに書いていない。
- 本番DBではなくプロトタイプDBである。

## 6. SQL実行後チェック

SQL Editorで `007_rls_smoke_fix_grants_draft.sql` を実行した後、同ファイル内の確認SELECTで以下を見ます。

- `sessions` に `anon` / `authenticated` の `SELECT` が付いている。
- `session_applications` に `authenticated` の `SELECT` が付いている。
- `session_comments` に不用意な直接SELECT grantが増えていない。
- `sessions` / `session_applications` / `session_comments` のRLSが有効。
- 関連RLS policiesが残っている。

## 7. 再実行手順

SQL実行後、ローカルで再度実行します。

```powershell
npm.cmd run supabase:rls:smoke
```

期待：

- AUTH-001 / AUTH-006 / AUTH-011 / AUTH-019 の `42501` は解消する。
- AUTH-014 は前段でapplication IDが取れれば正しい引数でRPCへ進む。
- 新しいFAILが出た場合は、エラー詳細を見て次の修正計画を作る。

## 8. まだやらないこと

- Supabase本番サイト接続
- `assets/js` へのSupabase client追加
- `session-detail.html` への実投稿処理追加
- service role keyの利用
- Edge Functions / Discord bot / Webhook
- Git commit / push

## 9. 本番接続停止条件

RLS smoke test が全件PASSするまで、本番サイトへ接続しません。

特に以下が残る場合は、本番接続へ進みません。

- private / hidden sessionが漏れる。
- public RPCが内部 `user_id` / `discord_user_id` を返す。
- playerが他人のコメントや申請を操作できる。
- GMが他GMのsessionを操作できる。
- `full` / `closed` / `finished` / `canceled` へ申請できる。

