# M-14D-4 016 end_at SQL適用結果

## 概要

ユーザーがSupabase SQL Editorで `docs/supabase/sql/016_session_posting_end_at_draft.sql` のapply sectionを実行し、以下の結果で通過した。

```text
Success. No rows returned
```

`016_session_posting_end_at_draft.sql` は適用済みのため、通常運用では同じapply sectionをそのまま再実行しない。
追加修正が必要な場合は、差分SQLとして別工程でレビューする。

このdocs記録工程でCodexはSQL Editorを追加実行していない。
DB変更、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushも行っていない。

## apply前確認

apply前に以下を確認済み。

```text
has_end_at_column = false
create_session_post_function_count = 1
has_p_end_at_argument = false
```

つまり、apply前は `public.sessions.end_at` は未作成、`create_session_post` は1本のみ、`p_end_at` 引数は未導入だった。

## apply後確認

以下を確認済み。

```text
has_end_at_timestamptz = true
create_session_post_function_count = 1
has_p_end_at_argument = true
```

`public.sessions.end_at` は `timestamptz` として追加済み。
`create_session_post(...)` は、旧signatureをdropしてから `p_end_at` 対応版の新signatureを作成したため、関数は1本だけ残っている。

## grant確認

`create_session_post` のgrantは以下のみ確認済み。

- `authenticated EXECUTE`
- `postgres EXECUTE`

`anon EXECUTE` はない。
`postgres EXECUTE` は所有者/管理者側の表示として扱う。

## 関数定義確認

以下を確認済み。

```text
function_count = 1
all_security_definer = true
all_volatile = true
has_p_end_at_argument = true
has_search_path_config = true
returns_session_id = true
returns_discord_sync_status = true
returns_created_at = true
```

`create_session_post(...)` は1本のみで、`security definer = true`、`volatile`、`search_path` 固定あり。
戻り値は `session_id` / `discord_sync_status` / `created_at` のみ。

## 未実施

- Edge Function deployは未実施。
- Discord実送信は未実施。
- secret、webhook URL、token、key、email、user_id全文は記録していない。

## M-14D-5 フォーム追従

フォーム側は `p_end_at` 送信へ切り替え済み。
日跨ぎ終了日時の投稿前ブロックは解除し、終了日時が開始日時以下の場合は投稿前に拒否する。
Supabase sessions表示側は `end_at` を `endAt` へ正規化し、`endAt` を終了日時として優先する。

GM認証文脈のSupabase clientで、日跨ぎ終了日時を含むhidden/draft投稿を1回確認済み。
結果は作成成功、`discord_sync_status = skipped`、作成行は `status = draft` / `visibility = hidden` / `session_type = one-shot`、`end_at` あり、anonからpublic表示対象として見えない。
このhidden draft test rowは削除していない。
public/recruiting投稿、Edge Function deploy、Discord実送信はこの工程では実施しない。
