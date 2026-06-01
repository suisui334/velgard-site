# Supabase M-11E-3 follow-up GM履歴RPC 権限文脈確認計画

作業日: 2026-06-01

## 1. 今回の目的

`get_gm_session_application_history(target_session_id text)` を `session-detail.html` のGM向け履歴UIへ接続する前に、どのAuth文脈で何を確認するかを整理する。

今回の工程では、GM履歴RPCを実行しない。本番フロント実装、SQL Editor実行、DB変更、GM承認 / 却下実装、Discord IDコピー実装、`close_session` 呼び出し、`updates.json` 変更も行わない。

境界線:

- GM/adminには対象セッションの人物単位申請履歴を見せる。
- PLには他人の申請履歴を見せない。
- anonにはRPCを実行させない。

## 2. 確認すべき文脈

| 文脈 | 期待値 | 確認観点 |
| --- | --- | --- |
| anon | 実行不可 | `anon EXECUTE` がないためRPC呼び出しは失敗する。成功や0件返却では扱わない。 |
| 通常PL | 実行不可、または `not allowed` | `authenticated` のexecute grantはあっても、RPC内部の `is_admin()` / `is_session_gm()` 判定で拒否される。 |
| 対象セッションGM | 実行可 | `display_name`、`application_status`、申請日時、更新日時、`canceled_at`、有効コメント数、最終有効コメント日時だけが返る。 |
| admin | 実行可 | 対象GMでなくても管理文脈として読める。 |

追加で見る境界:

- GM AはGM B担当セッションの履歴を読めない。
- PLは自分が申請しているセッションであっても、他人を含むGM履歴RPCは読めない。
- 存在しない、または空のセッションIDは、admin文脈なら0件になり得るが、非GM / 非adminの拒否確認には使わない。

## 3. 既存データで確認できること

### `session-2026-06-08-railway-incident`

公開JSON側には `session-2026-06-08-railway-incident` が存在し、M-10 ID整合検証データにより、公開版mypageから `session-detail.html?id=session-2026-06-08-railway-incident` へ遷移できることを確認済み。

この候補で確認できること:

- 公開JSONとDB側 `public.sessions.id` の突合。
- `session-detail.html` 既存表示の回帰確認。
- 公開コメントRPC、公開人数カウント、本人申請状態表示の既存回帰確認。
- PL向け画面にemail、`user_id`、token、key、`gmUserId` が出ないことの回帰確認。

この候補だけでは不足すること:

- M-10 ID整合検証SQL草案では、DB側 `gm_user_id` は不要としてnullのまま投入する方針だった。
- そのため、この候補だけでは `is_session_gm(target_session_id)` の対象GM文脈確認には不足する。
- GM履歴RPCの対象GM確認に使うには、別工程で既存DB状態を実値非記録で確認するか、専用fixtureとして対象セッションGMを安全に用意する必要がある。

### 既存RLS smoke test seed

`docs/supabase/sql/005_rls_test_seed_draft.sql` と `scripts/supabase-rls-smoke-test.mjs` には、GM履歴RPCの権限文脈確認に使いやすい構造がある。

- `TEST_PLAYER_A_EMAIL` / `TEST_PLAYER_A_PASSWORD`
- `TEST_PLAYER_B_EMAIL` / `TEST_PLAYER_B_PASSWORD`
- `TEST_GM_A_EMAIL` / `TEST_GM_A_PASSWORD`
- `TEST_GM_B_EMAIL` / `TEST_GM_B_PASSWORD`
- `TEST_ADMIN_EMAIL` / `TEST_ADMIN_PASSWORD`
- `rls-test-public-recruiting`: GM A担当のpublic recruitingセッション。
- `rls-test-other-gm-recruiting`: GM B担当のpublic recruitingセッション。

docsに実email、実UUID、実内部IDは記録しない。上記は環境変数名とfixture IDだけを扱う。

既存seed上の想定:

- Player A / Player Bは通常PL文脈として扱える。
- GM A / GM BはGM文脈として扱える。
- Adminはadmin文脈として扱える。
- GM AとGM Bの担当セッションが分かれているため、他GM拒否確認ができる。

## 4. 不足している検証データ

GM履歴RPCの最小権限境界は既存smoke test fixtureで確認できる見込みだが、次は不足または専用fixtureが望ましい。

- `canceled` の申請行を安定して含む専用fixture。
- `rejected` の申請行を安定して含む専用fixture。
- 削除済みコメントだけが残る、または有効コメント0件の申請行fixture。
- GM履歴RPCの `comment_count` が有効コメントのみを数えることを確認するfixture。

既存の共有fixtureをその場で `rejected` / `canceled` に変える確認は、後続テストや公開確認の前提を壊しやすい。必要なら専用seed、または `RUN_DESTRUCTIVE_TESTS=true` と明示的に切り分ける。

## 5. 推奨確認方法

### A. 既存smoke testへ追加

第一候補。

理由:

- `anon` / PL / GM A / GM B / admin のAuth文脈がすでにある。
- `.env.local` の値を標準出力へ出さないsanitizerがある。
- `FORBIDDEN_ENV` でservice roleやsecret系環境変数を拒否している。
- 既存テストが `rls-test-*` fixtureに寄っているため、本番ページの表示や公開JSONに依存しない。
- SQL Editorのowner文脈ではなく、Supabase clientのAuth文脈で確認できる。

追加位置案:

- anon拒否は `AUTH-004` 付近、またはGM履歴ブロックとして後半にまとめる。
- PL拒否はPlayer Aログイン後、`AUTH-011` 以降に追加できる。
- GM A成功とGM Aの他GM拒否は `AUTH-014` / `AUTH-015` 付近に追加しやすい。
- admin成功は `AUTH-019` のadminログイン後に追加する。
- `canceled` / `rejected` / deletedコメント系は専用fixtureがない場合、まずSKIPとして理由を記録する。

### B. dev配下に一時確認ページ / スクリプトを作る

第二候補。

使う場面:

- ユーザー実ブラウザでGM/admin/PLを切り替えながら目視確認したい場合。
- `session-detail.html` 接続前に、履歴RPCの返却列だけを安全に見たい場合。

条件:

- `dev/` 配下限定にする。
- 接続値とログイン情報は手入力にし、保存しない。
- service role、secret key、Direct connection stringらしき入力を拒否する。
- token、email、`user_id`、`application_id`、`comment_id`、Discord IDを画面・console・docsへ出さない。
- 本番 `session-detail.html` へは接続しない。

### C. ブラウザログイン文脈で手動確認

第三候補。

使う場面:

- 既存devプロトタイプや将来の確認ページで、ユーザーが実ブラウザログイン文脈を使って確認する場合。

注意:

- Codex側は今回GM履歴RPCを実行しない。
- 手動確認結果をdocsへ書く場合も、実email、実UUID、内部ID、token、keyは書かない。
- 画面にemailを出す既存devページは、履歴RPCの記録docsへ転記しない。

### D. SQL Editorで直接実行

原則避ける。

理由:

- SQL Editorはowner / editor側の文脈になりやすく、`auth.uid()`、RLS、GRANT、GM判定の挙動確認に向かない。
- GM / PL / anon / adminの境界を確認したい今回の目的とずれる。
- 間違って実データやsecret類をクエリ・結果・docsへ残すリスクが上がる。

## 6. smoke test追加案

追加候補IDは仮。実装時に既存ID体系と重複しないよう調整する。

| ID案 | 文脈 | 期待値 |
| --- | --- | --- |
| `M11E-HIST-001` | anon | `get_gm_session_application_history` を実行できない。 |
| `M11E-HIST-002` | Player A | GM A担当セッションの履歴RPCを読めず、`not allowed` 相当で失敗する。 |
| `M11E-HIST-003` | GM A | GM A担当セッションの履歴RPCを読める。 |
| `M11E-HIST-004` | GM A | GM B担当セッションの履歴RPCを読めない。 |
| `M11E-HIST-005` | Admin | GM A担当セッションの履歴RPCを読める。 |
| `M11E-HIST-006` | 成功系共通 | 返却列に `user_id`、email、`application_id`、`comment_id`、Discord ID、role、token、key、secret類がない。 |
| `M11E-HIST-007` | GM/admin | `pending` / `accepted` など既存fixtureにあるstatusが履歴対象に含まれる。 |
| `M11E-HIST-008` | 専用fixture | `canceled` / `rejected` も履歴対象に含まれる。 |
| `M11E-HIST-009` | 専用fixtureまたはdestructive | 削除済みコメントがあってもRPCが失敗しない。 |
| `M11E-HIST-010` | 専用fixtureまたはdestructive | `comment_count` は有効コメントのみを数える。 |

実装時の補助方針:

- `assertNoSensitiveColumns` はGM履歴RPC用に `email`、`application_id`、`comment_id` も明示的に禁止するとよい。
- 成功系は返却行が配列であること、各行のキーが契約7列に収まることを確認する。
- 既存の共有fixtureだけで確認できない状態は、無理に状態変更せずSKIP理由を残す。
- 破壊的または状態変更が重い確認は `RUN_DESTRUCTIVE_TESTS=true` または専用seedへ寄せる。

## 7. 直接実行してよい確認 / まだ避ける確認

今回直接実行してよい確認:

- ローカルファイル調査。
- 既存docs、SQL草案、smoke test、devプロトタイプの読み取り。
- 新規docs作成。
- `docs/task-backlog.md` への短い記録追加。
- `git status --short`、`git log --oneline -8`、`git diff --stat`、`git diff --check`。

今回まだ避ける確認:

- GM履歴RPCの実呼び出し。
- `scripts/supabase-rls-smoke-test.mjs` の実行。
- SQL Editor実行。
- DB変更。
- 本番 `session-detail.html` へのGM履歴UI実装。
- GM承認 / 却下実装。
- Discord IDコピー実装。
- `close_session` 呼び出し。

## 8. UI実装前の最低合格条件

M-11E-4以降へ進む前に、少なくとも次を確認する。

- GM/adminのみGM履歴RPCを取得できる。
- PL/anonはGM履歴RPCを取得できない。
- GM AはGM B担当セッションの履歴を取得できない。
- 返却列に内部ID、連絡先情報、role、token、key、secret類がない。
- `canceled` / `rejected` が履歴対象として扱える見通しがある。
- 削除済みコメントがあってもRPCが壊れない見通しがある。
- `comment_count` は有効コメントのみを数える方針が崩れていない。
- 既存PL向け画面、公開コメント一覧、公開人数カウント、本人申請状態表示に影響しない。
- SQL Editor owner文脈ではなく、Auth文脈クライアントまたはsmoke testで境界を確認する。

## 9. まだやらないこと

- SQL Editor実行。
- DB変更。
- GM履歴RPC実行。
- 本番フロント実装。
- GM承認 / 却下実装。
- Discord IDコピー実装。
- `close_session` 呼び出し。
- `updates.json` 変更。
- secret類、実Project URL/key、email、実UUID、内部ID実値の記録。
- `git add .`、commit、push。

## 10. 次工程候補

推奨順:

1. この計画を正本として、`scripts/supabase-rls-smoke-test.mjs` にGM履歴RPCの権限文脈テストを追加する。
2. 専用fixtureが不足する `canceled` / `rejected` / deletedコメント / 有効コメント0件の扱いは、SKIPまたは専用seed設計として分ける。
3. smoke testでGM/admin/PL/anon境界を確認してから、`session-detail.html` のGM履歴UI状態表示へ進む。

このdocs作成工程では、RPC実行、SQL Editor実行、DB変更、本番フロント実装、`updates.json` 変更、secret類の記録、commit / pushは行っていない。

## 11. M-11E-4 smoke test実装追記

2026-06-01に、この計画をもとに `scripts/supabase-rls-smoke-test.mjs` へGM履歴RPCのAuth文脈確認を追加した。

実装した観点:

- `M11E-HIST-001`: anonのRPC実行不可。
- `M11E-HIST-002`: 通常PLの履歴取得不可。
- `M11E-HIST-003`: 対象GMの履歴取得可。
- `M11E-HIST-004`: 他GMセッション履歴の取得不可。
- `M11E-HIST-005`: adminの履歴取得可。
- `M11E-HIST-006`: 返却列の内部情報非露出チェック。
- `M11E-HIST-007`: smoke test内で更新した現在status行の確認。
- `M11E-HIST-008` から `M11E-HIST-010`: `canceled` / `rejected` / deletedコメント / `comment_count` active-onlyはfixture不足としてSKIP。

実装結果は次に分離した。

```text
docs/supabase-session-detail-application-history-gm-smoke-test-result.md
```

このM-11E-4工程では、DB接続を伴う smoke test 本体実行、SQL Editor実行、DB変更、GM履歴RPC手動実行、本番フロント実装、`updates.json` 変更、secret類の記録、commit / pushは行っていない。構文確認として `node --check scripts/supabase-rls-smoke-test.mjs` のみ実行し、成功した。
