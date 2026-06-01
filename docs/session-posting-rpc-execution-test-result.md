# M-14D-1 create_session_post hidden draft 実行テスト結果

## 概要

`dev/run-create-session-post-test.mjs` を使い、SQL Editorではなく認証済みSupabase clientから `create_session_post(...)` の最小実行テストを行った。

通常実行ではSKIPされることを確認済み。明示フラグ付きでGM文脈のhidden draft作成テストを1回実行した。

## 実行条件

実行時の条件:

- `RUN_CREATE_SESSION_POST_TEST=true`
- `CREATE_SESSION_POST_CONFIRM=hidden-draft`
- `CREATE_SESSION_POST_ACTOR=gm`

作成対象は `visibility = hidden` / `status = draft` のため、public募集としては作成しない。Discord同期対象にもならない。

## 結果

確認済み:

- `ok: true`
- `actor: gm`
- `discord_sync_status: skipped`
- `created_row.status: draft`
- `created_row.visibility: hidden`
- `created_row.session_type: one-shot`
- `created_row.application_deadline_present: true`
- `created_row.discord_sync_status: skipped`
- `public_visible_to_anon: false`

戻り値は `session_id` / `discord_sync_status` / `created_at` のみを扱う方針。docsには作成された `session_id` の実値は記録しない。

## テストデータ

hidden draft test row は作成済みで、削除していない。削除するか検証データとして残すかは、後続工程で判断する。

## 未実施・安全確認

- SQL Editorで `create_session_post(...)` を直接実行していない。
- CodexはSQL Editorを追加実行していない。
- DB構造変更は行っていない。
- Edge Function deployは行っていない。
- Discord実送信は行っていない。
- public募集は作成していない。
- token / key / email / user_id全文 / credential類の実値はdocsへ記録していない。
- `updates.json` は変更していない。
- commit / pushは行っていない。

## スクリプト

使用したスクリプト:

```text
dev/run-create-session-post-test.mjs
```

このスクリプトはcommit対象候補。ただし、実行には明示フラグが必要で、通常実行ではSKIPする。
