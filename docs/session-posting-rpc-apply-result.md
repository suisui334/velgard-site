# M-14C 依頼書投稿RPC SQL適用結果

## 概要

ユーザーがSupabase SQL Editorで `docs/supabase/sql/015_session_posting_rpc_draft.sql` のapply sectionを実行し、以下の結果で通過した。

```text
Success. No rows returned
```

このdocs記録工程でCodexはSQL Editorを追加実行していない。DB変更、Edge Function deploy、Discord実送信、フロント実装、`updates.json` 変更、commit / pushも行っていない。

## 追加列

`public.sessions` に以下の列が追加済み。

- `session_type`
- `application_deadline`
- `discord_sync_status`
- `discord_last_action`
- `discord_message_id`
- `discord_channel_id`
- `discord_thread_id`
- `discord_sync_requested_at`
- `discord_synced_at`
- `discord_sync_error`
- `discord_post_url`

確認済みの型・初期値:

- `application_deadline` は `timestamptz`
- `session_type` は `text` / not null / default `'one-shot'`
- `discord_sync_status` は `text` / not null / default `'not_requested'`

## 制約

以下の制約を確認済み。

- `sessions_session_type_check`
- `sessions_discord_sync_status_check`
- `sessions_discord_last_action_check`
- `sessions_discord_sync_error_length_check`

## RPC

`create_session_post(...)` を確認済み。

- `security definer = true`
- volatilityは `volatile`
- 戻り値は `session_id` / `discord_sync_status` / `created_at`
- grantは `authenticated EXECUTE` と `postgres EXECUTE`
- `anon EXECUTE` はなし

`postgres EXECUTE` は管理者/所有者文脈として扱う。

## 未実施

- M-14D-1で、GM文脈のhidden draft最小実行テストは実施済み。
- public募集作成テスト、通常PL/anon拒否テスト、admin文脈テストは未実施。
- Edge Function deployは未実施。
- Discord実送信は未実施。
- フロント実装は未実施。
- credential類の実値は記録していない。

## M-14D-1 hidden draft実行テスト

`dev/run-create-session-post-test.mjs` を使い、GM認証文脈で `create_session_post(...)` を1回実行した。SQL Editorでの直接実行ではなく、Supabase client経由。

確認結果:

- 通常実行ではSKIP。
- `RUN_CREATE_SESSION_POST_TEST=true` / `CREATE_SESSION_POST_CONFIRM=hidden-draft` / `CREATE_SESSION_POST_ACTOR=gm` で実行。
- `discord_sync_status` は `skipped`。
- 作成行は `status = draft` / `visibility = hidden` / `session_type = one-shot`。
- `application_deadline` は存在する。
- anonからpublic表示対象としては見えない。
- hidden draft test row は削除していない。
- Discord実送信なし。
- token / key / email / user_id全文 / credential類の実値は記録していない。

詳細は `docs/session-posting-rpc-execution-test-result.md`。

## 運用注意

`015_session_posting_rpc_draft.sql` のapply sectionは適用済みのため、通常運用では同じapply sectionをそのまま再実行しない。追加修正が必要な場合は、差分SQLとして別工程でレビューする。

## M-14D-4 016 end_at apply result

ユーザーが `docs/supabase/sql/016_session_posting_end_at_draft.sql` のapply sectionをSupabase SQL Editorで実行し、`Success. No rows returned` で通過済み。
`public.sessions.end_at timestamptz` が追加され、`create_session_post(...)` は `p_end_at` 対応版に差し替わった。
旧signatureをdropしてから新signatureを作成したため、`create_session_post` は1本だけ。
grantは `authenticated EXECUTE` と `postgres EXECUTE` のみで、`anon EXECUTE` はない。

関数定義は `security definer = true`、`volatile`、`search_path` 固定あり、戻り値は `session_id` / `discord_sync_status` / `created_at` のみ。
`016_session_posting_end_at_draft.sql` も適用済みのため、通常運用では同じapply sectionをそのまま再実行しない。
詳細は `docs/session-posting-end-at-apply-result.md`。
