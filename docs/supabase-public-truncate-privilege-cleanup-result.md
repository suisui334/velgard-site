# public schema TRUNCATE権限整理結果

## 概要

M-14C / `015_session_posting_rpc_draft.sql` のpreflight中に、`public.sessions` だけでなく、public schema内の複数テーブルで `anon` / `authenticated` に `TRUNCATE` 権限が見えていた。

ユーザーがSupabase SQL Editorで、`anon` / `authenticated` からpublic schema全テーブルの `TRUNCATE` 権限だけをrevokeした。

## 実行結果

実行結果:

```text
Success. No rows returned
```

今回整理したのは `TRUNCATE` 権限のみ。`SELECT` / `INSERT` / `UPDATE` / `DELETE` 権限は今回触っていない。

## 確認結果

`information_schema.table_privileges` で、public schema内の `anon` / `authenticated` に残る `TRUNCATE` 権限を確認した。

確認結果:

```text
0 rows
```

これにより、`anon` / `authenticated` に見えていたpublic schemaテーブルの `TRUNCATE` 権限は0件になった。

## 対象外

`postgres` などの管理者系ロール側の権限は今回の整理対象外。管理者系ロールの権限表示は、通常の管理・所有者文脈として扱う。

## 未実行・未変更

- `015_session_posting_rpc_draft.sql` のapplyはまだ未実行。
- CodexはSQL Editorを追加実行していない。
- CodexはDB変更を行っていない。
- Edge Function deployは行っていない。
- Discord実送信は行っていない。
- credential値は記録していない。
- `updates.json` は変更していない。
- commit / pushは行っていない。
