# Supabase M-11E-4 GM履歴RPC RLS smoke test実装結果

作業日: 2026-06-01

## 1. 記録範囲

`scripts/supabase-rls-smoke-test.mjs` に、`get_gm_session_application_history(target_session_id text)` のAuth文脈確認を追加した。

この工程では、SQL Editor実行、DB変更、GM履歴RPCの手動実行、本番フロント実装、GM承認 / 却下実装、Discord IDコピー実装、`close_session` 呼び出し、`updates.json` 変更、commit / pushは行っていない。

## 2. 追加したsmoke test観点

追加ID:

- `M11E-HIST-001`: anonはGM履歴RPCを実行できない。
- `M11E-HIST-002`: 通常PLはGM A担当セッションのGM履歴RPCを読めない。
- `M11E-HIST-003`: GM Aは自分の担当セッションのGM履歴RPCを読める。
- `M11E-HIST-004`: GM AはGM B担当セッションのGM履歴RPCを読めない。
- `M11E-HIST-005`: adminはGM履歴RPCを読める。
- `M11E-HIST-006`: 成功系の返却列に内部情報がないことを確認する。
- `M11E-HIST-007`: smoke test内で更新した現在の申請status行を履歴で確認する。
- `M11E-HIST-008`: `canceled` / `rejected` 履歴行はfixture不足としてSKIPする。
- `M11E-HIST-009`: deletedコメント耐性はfixture不足としてSKIPする。
- `M11E-HIST-010`: `comment_count` の有効コメントのみ集計はfixture不足としてSKIPする。

## 3. 文脈別の扱い

- anon: `anon EXECUTE` がない前提で、RPC呼び出しが失敗することを期待する。
- 通常PL: `authenticated` grantはあっても、RPC内部のGM/admin判定で拒否されることを期待する。
- 対象GM: `rls-test-public-recruiting` をGM A担当fixtureとして使い、履歴行を取得できることを期待する。
- 他GM: GM Aから `rls-test-other-gm-recruiting` を読めないことを期待する。
- admin: admin文脈で `rls-test-public-recruiting` の履歴行を取得できることを期待する。

## 4. 返却列チェック

GM履歴RPC専用に `assertGmHistoryRows` を追加した。

許可する列:

```text
display_name
application_status
created_at
updated_at
canceled_at
comment_count
last_comment_at
```

禁止する列:

```text
user_id
email
application_id
comment_id
discord_id
discord_user_id
discord_name
role
token
access_token
refresh_token
jwt
key
secret
gmUserId
discordUserId
```

成功系では配列であること、各行の列が契約7列に収まること、`application_status` が既知statusであること、`comment_count` が整数であることを確認する。

## 5. canceled / rejected / deletedコメント耐性

既存の共有fixtureだけでは、`canceled` / `rejected` の安定した申請行、deletedコメントだけが絡む履歴行、active/deleted混在時の `comment_count` 検証を安全に固定できない。

そのため、今回はDB seedを追加せず、次をSKIPとして明記した。

- `M11E-HIST-008`: dedicated canceled/rejected fixture不足。
- `M11E-HIST-009`: dedicated deleted-comment history fixture不足。
- `M11E-HIST-010`: active/deleted混在fixture不足。

## 6. 構文確認

M-11E-4実装時点では、Codex側でDB接続を伴う smoke test 本体は実行していない。

実行した構文確認:

```powershell
node --check scripts/supabase-rls-smoke-test.mjs
```

結果:

```text
OK
```

## 7. 通常smoke test実行結果

2026-06-01に、ユーザーが通常のRLS smoke testを実行し、GM履歴RPC追加分を含めて確認した。

実行コマンド:

```powershell
node scripts/supabase-rls-smoke-test.mjs
```

`RUN_DESTRUCTIVE_TESTS` は使用していない。

結果:

```text
Supabase RLS smoke test summary
PASS: 40
FAIL: 0
SKIP: 13
```

GM履歴RPC関連のPASS:

```text
M11E-HIST-001 anon cannot call GM session application history RPC
M11E-HIST-002 player A cannot read GM session application history
M11E-HIST-003 gm A can read own session application history
M11E-HIST-004 gm A cannot read gm B session application history
M11E-HIST-005 admin can read GM session application history
M11E-HIST-006 GM history rows do not expose internal fields
M11E-HIST-007 GM history includes current application status rows
```

確認できたこと:

- anon / 通常PL / 他GMはGM履歴RPCを取得できない。
- 対象GM / adminはGM履歴RPCを取得できる。
- GM履歴RPCの返却行に内部情報が含まれない。
- GM履歴UI実装へ進める最低限の権限境界は確認できた。

GM履歴RPC関連のSKIP:

```text
M11E-HIST-008 canceled and rejected application history rows
M11E-HIST-009 deleted comments do not break GM history
M11E-HIST-010 comment_count counts active comments only
```

SKIP理由は専用fixture不足。今回の通常smoke testでは問題扱いしない。

`canceled` / `rejected` 履歴やdeletedコメント耐性、`comment_count` のactive-only詳細確認は、将来fixture整備後に扱う。

## 8. まだ行っていないこと

- SQL Editor実行。
- DB変更。
- 本番 `session-detail.html` へのGM履歴UI実装。
- GM履歴RPCの手動実行。
- GM承認 / 却下実装。
- Discord IDコピー実装。
- secret類、実Project URL/key、email、実内部ID、tokenの記録。

## 9. 次工程候補

通常smoke testで `M11E-HIST-001` から `M11E-HIST-007` がPASSしたため、次工程としてGM履歴UI実装へ進める状態。

`canceled` / `rejected` / deletedコメント / `comment_count` active-only検証は、共有fixtureを書き換えずに確認できる専用seedを別工程で設計する。
