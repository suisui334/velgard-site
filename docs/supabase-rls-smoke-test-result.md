# Supabase RLSスモークテスト結果整理

## 1. 概要

Step 11 のGRANT修正後、Supabase Auth文脈RLSスモークテストは通過した。

- 実行対象: `scripts/supabase-rls-smoke-test.mjs`
- 実行コマンド: `npm.cmd run supabase:rls:smoke`
- 結果: `PASS 19 / FAIL 0 / SKIP 1`
- 関連修正: `docs/supabase/sql/007_rls_smoke_fix_grants_draft.sql`

`SKIP 1` は意図的なもの。`AUTH-018` はGMが自分のセッションを実際に `closed` にする破壊的な成功系テストであり、`RUN_DESTRUCTIVE_TESTS=true` ではないため未実行として扱う。

## 2. 確認できたこと

今回のスモークテストで、以下を確認した。

- `anon` が public session を読める。
- `anon` が private / hidden session を読めない。
- `public_profiles` に `discord_user_id` が出ない。
- public comment RPC に内部 `user_id` / `discord_user_id` が出ない。
- player が `recruiting` / `tentative` へ申請コメントできる。
- player が `full` / `closed` / `finished` / `canceled` へ申請できない。
- player が private / hidden session へ申請できない。
- player がGM操作を実行できない。
- player が他人コメントを編集できない。
- GMが自分のsession申請を管理できる。
- GMが他GM sessionを管理できない。
- adminが検証用prototype rowsを確認できる。
- 参加人数はコメント件数ではなく、`session_applications` の一意ユーザー単位で扱う。

## 3. 007 grant fixで対応したこと

Step 11では、RLS policy自体ではなくData API向けのテーブル権限不足に対応した。

修正内容:

```sql
grant select on table public.sessions to anon, authenticated;
grant select on table public.session_applications to authenticated;
```

境界:

- `session_comments` の直接 `SELECT` は広げていない。
- 公開コメント表示は引き続きRPC経由とする。
- private / hidden session の漏洩防止はRLS policyと公開RPCの絞り込みで守る。
- GitHub Pages本体へのSupabase接続コードは追加していない。

## 4. 意図的SKIP

`AUTH-018` は現時点では問題なしとして扱う。

理由:

- GM所有sessionを実際に `closed` へ変更する破壊的テストである。
- 初期スモークテストでは `RUN_DESTRUCTIVE_TESTS=true` を明示した場合のみ実行する方針。
- 現時点では、失敗系と権限境界の確認を優先する。

将来この成功系を確認する場合は、必ずプロトタイプデータであることを確認し、`RUN_DESTRUCTIVE_TESTS=true` の指定が意図的であることを確認してから実行する。

## 5. 本番接続前の未確認事項

RLSスモークテスト通過後も、以下はまだ未確認・未実装である。

- `RUN_DESTRUCTIVE_TESTS=true` での `close_session` 成功系。
- 実フロントUIからのコメント投稿処理。
- 実フロントUI上のエラー表示と再試行案内。
- rate limit / abuse対策。
- 連投対策。
- 本番用ユーザー管理とGM権限付与手順。
- admin復旧手順。
- 本番データのバックアップとrollback手順。
- Discord bot / Webhook / Edge Functions連携。
- 参加申請コメントの最終的な公開範囲説明。

## 6. 現在の停止ポイント

この結果は、本番サイト接続を許可するものではない。

本番接続へ進む前に、`docs/supabase-production-connection-checklist.md` を使って、フロント連携方式・認証UI・失敗時UI・公開範囲・ロール運用を決める。
