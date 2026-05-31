# Supabase M-11D-2 本人申請辞退RPC SQL草案 設計

作業日: 2026-06-01

## 1. 目的

本人が自分の参加申請を、コメントを削除せずに取り下げるためのRPC設計とSQL草案を作成する。

今回の工程では、SQL Editor実行、DB変更、本番フロント実装、申請辞退RPC実行、GM履歴RPC実装、`close_session` 呼び出し、`updates.json` 変更は行わない。

## 2. 調査したファイル

- `docs/supabase-session-detail-application-withdraw-history-plan.md`
- `docs/supabase-session-detail-application-comment-delete-result.md`
- `docs/supabase-session-detail-application-comment-edit-delete-plan.md`
- `docs/supabase-session-detail-application-comment-post-result.md`
- `docs/supabase-session-detail-application-comment-post-plan.md`
- `docs/supabase-mypage-applications-list-result.md`
- `docs/supabase-f5-gm-application-management-prototype.md`
- `docs/supabase-f6-comment-edit-delete-prototype.md`
- `docs/supabase/sql/001_core_schema_draft.sql`
- `docs/supabase/sql/002_rls_grants_draft.sql`
- `docs/supabase/sql/003_rpc_draft.sql`
- `docs/supabase/sql/008_comment_management_rpc_draft.sql`
- `scripts/supabase-rls-smoke-test.mjs`
- `assets/js/sessionDetailApplicationComments.js`
- `assets/js/mypageAuthClient.js`
- `README.md`
- `docs/task-backlog.md`

## 3. status調査結果

`session_applications.status` は `pending` / `accepted` / `rejected` / `waitlisted` / `canceled` を許容する。

`withdrawn` は未定義。`finished` は `sessions.status` 側の値であり、`session_applications.status` にはない。

人数集計では `accepted` / `pending` / `waitlisted` が数えられ、`canceled` と `rejected` は集計対象外。`mypageAuthClient.js` も `pending` / `waitlisted` / `accepted` のみを取得するため、`canceled` は参加申請中/参加予定に出ない。

## 4. canceled / withdrawn 方針

短期採用は `canceled`。

理由:

- 既存CHECK制約に含まれている。
- 既存のコメント削除RPCも最後の有効申請コメント削除時に `canceled` を使う。
- 公開人数カウントとmypage表示から自然に除外される。
- `create_application_comment` は `canceled` から `pending` に戻す再申請を想定している。

`withdrawn` 新設は今回は保留する。新設するとCHECK制約、投稿RPC、削除RPC、人数集計、mypage、session-detail、RLS smoke test、rollbackの広い更新が必要になるため。

## 5. RPC名比較

| 案 | 形 | 評価 |
| --- | --- | --- |
| A | `cancel_my_session_application(target_session_id text)` | 既存 `canceled` status と揃う。本人操作であることが明確。短期採用に向く。 |
| B | `withdraw_session_application(target_session_id text)` | UI文言の「取り下げ」に近い。将来 `withdrawn` status を作る場合は自然だが、現行statusは `canceled`。 |
| C | `withdraw_session_application(target_session_id text, reason_comment_body text default null)` | 辞退理由コメント同時投稿まで扱えるが、投稿RPCとの責務が混ざる。初回草案では重い。 |

採用案は案Aのシンプル版。辞退コメント同時投稿は別工程にする。

## 6. 採用RPC仕様

RPC:

```text
cancel_my_session_application(target_session_id text)
```

仕様:

- `authenticated` のみ実行可。
- `auth.uid()` の本人 `session_applications` 行だけを対象にする。
- 対象 `session_id` が存在することを確認する。
- 自分の申請行がない場合は失敗する。
- `pending` / `waitlisted` / `accepted` は `canceled` に変更できる。
- `rejected` は辞退対象外として失敗する。
- すでに `canceled` の場合は安全に現在値を返す。
- `session_comments` は削除も編集もしない。
- 戻り値は `session_id` / `application_status` / `canceled_at` / `updated_at` に絞る。
- `user_id`、email、`application_id`、`comment_id`、Discord ID、token、secret類は返さない。

## 7. accepted 辞退の扱い

短期方針では `accepted` も本人辞退可能にする。

承認後に参加予定から外れるケースは現実にあり得るため、本人がGM操作を待たずに辞退できる方がPL向け導線として自然。ただし `canceled` だけでは「申請中から辞退」か「承認後辞退」かを後から区別できない。

今回すぐ補助カラムや履歴テーブルは増やさない。将来GM履歴で必要になったら、`session_application_events`、`canceled_by`、`canceled_reason`、または承認後辞退を識別できる補助設計を別工程で検討する。

## 8. コメント削除RPCとの違い

`delete_application_comment_and_maybe_cancel(target_comment_id uuid)` は、発言を公開コメント一覧から消すための論理削除RPC。最後の有効申請コメントを削除した場合に、整合維持として申請statusが `canceled` になり得る。

`cancel_my_session_application(target_session_id text)` は、コメントを残したまま参加意思だけを取り下げるRPC。コメント本文は履歴・連絡として残る。辞退コメント投稿は、既存投稿UIまたは将来の別RPCで扱う。

## 9. RLS / security definer 方針

`session_applications` への直接UPDATEを広げず、RPC経由に寄せる。

`cancel_my_session_application` は `security definer` とし、`set search_path = ''` を明示する。RLSを迂回できるRPCなので、関数内で必ず `auth.uid()` を確認し、`sa.user_id = auth.uid()` で対象行を絞る。

`auth.uid() is null` は拒否する。本人以外の申請は、`target_session_id` だけでは更新できない。

## 10. grant方針

- `revoke all on function public.cancel_my_session_application(text) from public`
- `revoke all on function public.cancel_my_session_application(text) from anon`
- `revoke all on function public.cancel_my_session_application(text) from authenticated`
- `grant execute on function public.cancel_my_session_application(text) to authenticated`

anon / public には実行権限を付与しない。
`authenticated` は一度revokeしてから再grantし、適用後の権限状態を読みやすくする。`information_schema.routine_privileges` ではownerまたは管理者ロールが表示される場合があるが、anon / PUBLICへの広いgrantでなければ問題扱いしない。

## 11. SQL草案

作成ファイル:

```text
docs/supabase/sql/012_session_application_cancel_my_rpc_draft.sql
```

含めた内容:

- preflight確認
- 既存status制約確認
- `withdrawn` 未定義確認
- 既存関数名衝突確認
- RLS policy / 直接UPDATE grant確認
- `create or replace function public.cancel_my_session_application(target_session_id text)`
- apply sectionの `begin` / `commit`
- grant / revoke
- post-apply確認
- rollback草案
- 停止条件
- SQL Editor未実行注意
- secret実値禁止注意

## 12. RLS smoke test案

- anonは辞退RPCを実行できない。
- authenticated本人は自分の `pending` 申請を `canceled` にできる。
- authenticated本人は自分の `waitlisted` 申請を `canceled` にできる。
- authenticated本人は自分の `accepted` 申請を `canceled` にできる。
- authenticated本人は他人申請を `canceled` にできない。
- 存在しないsessionでは失敗する。
- 申請行がない場合は失敗する。
- `rejected` は辞退対象外として失敗する。
- すでに `canceled` の場合は安全に扱う。
- `canceled` 後、申請中/承認済み人数から除外される。
- `canceled` 後、コメントは残る。
- `canceled` 後、mypageの参加申請中/参加予定に出ない。
- 戻り値やログに `user_id`、email、`application_id`、`comment_id`、token、secret類が出ない。

破壊的な成功系は専用fixtureと `RUN_DESTRUCTIVE_TESTS=true` の運用を分ける。

## 13. 設計作成工程での未実行事項

- SQL Editorは実行していない。
- DB変更はしていない。
- 申請辞退RPCは実行していない。
- 本番フロント実装はしていない。
- GM履歴RPCは実装していない。
- `updates.json` は変更していない。
- secret類、実Project URL、実key、実email、実user_id全文は記録していない。

## 14. SQL適用結果追記

2026-06-01に、ユーザーがSupabase SQL Editorで `cancel_my_session_application(target_session_id text)` を作成した。

結果docs:

```text
docs/supabase-session-detail-application-withdraw-rpc-result.md
```

適用結果:

- status制約に `canceled` が含まれることを確認済み。
- `session_applications` の必要列を確認済み。
- 同名RPCが作成前に存在しないことを確認済み。
- RPC作成本体を実行し、成功。
- 関数定義は `cancel_my_session_application(text)`、`security definer = true`、引数 `target_session_id text`。
- 戻り値は `session_id / application_status / canceled_at / updated_at`。
- grant確認では `authenticated EXECUTE` と `postgres EXECUTE` が出ており、`anon EXECUTE` は出ていない。
- `postgres EXECUTE` はownerまたは管理者側の表示として扱い、anon / PUBLICへの広いgrantとは見なさない。

注意:

- `docs/supabase/sql/012_session_application_cancel_my_rpc_draft.sql` のRPC作成SQLは適用済みのため、通常運用では同じ作成SQLをそのまま再実行しない。
- RPC実行テストはまだ行っていない。
- rollbackは未実行。
- このdocs追記工程でCodexはSQL Editorを実行していない。
- このdocs追記工程でCodexはDB変更、RPC実行、本番フロント実装、`updates.json` 変更、commit / pushを行っていない。
