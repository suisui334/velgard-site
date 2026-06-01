# Supabase M-11E-3 GM向け申請履歴RPC SQL適用結果

作業日: 2026-06-01

## 1. 記録範囲

ユーザーがSupabase SQL Editorで `get_gm_session_application_history(target_session_id text)` を作成した結果を記録する。

このdocs記録工程でCodexは、SQL Editor実行、DB変更、GM履歴RPC実行、本番フロント実装、`updates.json` 変更、commit / pushを行っていない。

## 2. 作成済みRPC

```text
get_gm_session_application_history(target_session_id text)
```

用途:

- GM/admin向けの申請履歴RPC。
- `session_applications` を主軸に、対象セッションの人物単位申請状態を返す。
- `canceled` / `rejected` も履歴対象に含める。
- 完全な状態遷移監査ログではなく、現在の `session_applications` 行と有効コメント集計を返す。

## 3. 戻り値

```text
display_name text
application_status text
created_at timestamptz
updated_at timestamptz
canceled_at timestamptz
comment_count integer
last_comment_at timestamptz
```

返さない情報:

- email
- `user_id` 全文
- `application_id`
- `comment_id`
- Discord ID
- token / key / secret類

## 4. 権限仕様

確認済みの仕様:

- `authenticated` のみ実行可能。
- `anon` にはexecute権限なし。
- `public.is_admin()` または `public.is_session_gm(target_session_id)` で許可判定する。
- GM/admin以外はRPC内で拒否する方針。

grant確認結果:

```text
authenticated EXECUTE
postgres EXECUTE
```

`anon EXECUTE` は出ていない。`postgres EXECUTE` はownerまたは管理者側の表示として扱い、クライアント向けの広いgrantとは見なさない。

## 5. SQL Editorで確認済みの前提

確認済み:

- `is_admin()` が存在する。
- `is_session_gm(target_session_id text)` が存在する。
- どちらも `security definer = true`。
- どちらも `search_path=""` が設定されている。
- 同名RPC `get_gm_session_application_history` は事前に存在しなかった。
- 必要カラムが存在する。

必要カラム確認:

```text
profiles.id
profiles.display_name
session_applications.session_id
session_applications.user_id
session_applications.status
session_applications.created_at
session_applications.updated_at
session_applications.canceled_at
session_comments.id
session_comments.session_id
session_comments.user_id
session_comments.created_at
session_comments.deleted_at
sessions.id
```

上記はschema列名の確認であり、実ユーザーIDや実内部IDは記録しない。

## 6. 関数定義確認

作成後に関数定義を確認済み。

確認済み:

- 関数名は `get_gm_session_application_history(text)`。
- `security definer = true`。
- volatilityは `stable`。
- 引数は `target_session_id text`。
- `search_path=""`。
- 戻り値は `display_name` / `application_status` / `created_at` / `updated_at` / `canceled_at` / `comment_count` / `last_comment_at`。

## 7. コメント集計

確認済みの仕様:

- `comment_count` は有効コメント数。
- `last_comment_at` は有効コメントの最新日時。
- 削除済みコメントは有効コメント集計に含めない。
- 削除済みコメントしかない場合でも、`session_applications` 行があれば履歴行は残り得る。

## 8. 未実施

未実施:

- GM文脈でのRPC実行テスト。
- admin文脈でのRPC実行テスト。
- PL文脈での拒否確認。
- anon文脈でのexecute不可確認。
- rollback実行。
- 本番フロント実装。
- GM履歴UI実装。
- `close_session` 呼び出し。

## 9. 再実行注意

`docs/supabase/sql/013_gm_session_application_history_rpc_draft.sql` のRPC作成SQLは適用済み。

通常運用では、同じ作成SQLをそのまま再実行しない。再作成または置換が必要な場合は、既存関数定義、grant、戻り値契約、影響範囲、rollbackを再レビューしてから別工程として扱う。

## 10. 次工程候補

次工程候補:

- SQL適用結果をcommitした後、GM/admin/PL/anon文脈での挙動確認計画を作る。
- または、`session-detail.html` のGM履歴UI状態表示を設計する。

いずれの場合も、secret類、実Project URL/key、email、実内部ID、tokenは記録しない。

## 11. M-11E-4 smoke test足場

2026-06-01に、GM/admin/PL/anon文脈での挙動確認を行うための足場を `scripts/supabase-rls-smoke-test.mjs` へ追加した。

追加範囲:

- anon / 通常PL / 対象GM / 他GM / admin のAuth文脈テスト。
- GM履歴RPCの返却列が契約7列に収まることのチェック。
- `user_id`、email、`application_id`、`comment_id`、Discord ID、role、token、key、secret類が返却行に含まれないことのチェック。
- `canceled` / `rejected` / deletedコメント / `comment_count` active-onlyの確認はfixture不足としてSKIP。

結果記録:

```text
docs/supabase-session-detail-application-history-gm-smoke-test-result.md
```

この追記工程では、GM履歴RPCの手動実行、DB接続を伴う smoke test 本体実行、SQL Editor実行、DB変更、本番フロント実装、`updates.json` 変更、secret類の記録、commit / pushは行っていない。

## 12. M-11E-4 smoke test確認結果

2026-06-01に、ユーザーが通常のRLS smoke testを実行し、GM履歴RPC追加分を確認した。`RUN_DESTRUCTIVE_TESTS` は使用していない。

全体結果:

```text
PASS: 40
FAIL: 0
SKIP: 13
```

GM履歴RPC関連:

- `M11E-HIST-001` から `M11E-HIST-007` はPASS。
- anon / 通常PL / 他GMは拒否できている。
- 対象GM / adminは取得できている。
- 返却列の内部情報非露出チェックはPASS。
- `M11E-HIST-008` から `M11E-HIST-010` は専用fixture不足でSKIP。

`canceled` / `rejected` 履歴やdeletedコメント耐性、`comment_count` active-onlyの詳細確認は、将来fixture整備後に扱う。今回の通常smoke test結果では、GM履歴UI実装へ進める状態とする。
