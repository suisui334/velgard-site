# Supabase F-6 SQL実行前レビュー計画

## 1. 目的

この資料は、`docs/supabase/sql/008_comment_management_rpc_draft.sql` をSupabase SQL Editorで実行する前のレビュー計画である。

この工程ではSQLを実行しない。目的は、コメント編集・論理削除・申請取消RPCをプロトタイプDBへ反映する前に、前提条件、影響範囲、実行順序、検証手順、ロールバック方針を整理すること。

本番サイトへのSupabase接続、`session-detail.html` 統合、devプロトタイプ実装、`close_session`、Discord連携、通知、メール送信は対象外とする。

## 2. 実行対象SQLの整理

対象ファイル:

```text
docs/supabase/sql/008_comment_management_rpc_draft.sql
```

追加・変更予定:

| 区分 | 内容 | 備考 |
| --- | --- | --- |
| カラム追加案 | `session_comments.edited_by` | 任意監査列。`profiles(id)` 参照、nullable |
| カラム追加案 | `session_comments.deleted_by` | 任意監査列。`profiles(id)` 参照、nullable |
| index追加案 | `session_comments_edited_by_idx` | 監査列検索用 |
| index追加案 | `session_comments_deleted_by_idx` | 監査列検索用 |
| RPC追加案 | `update_application_comment(target_comment_id uuid, comment_body text)` | コメント編集 |
| RPC追加案 | `delete_application_comment_and_maybe_cancel(target_comment_id uuid)` | 論理削除と、最後の有効申請コメント削除時の申請取消 |
| grant/revoke | 新RPCは `public` からrevokeし、`authenticated` にexecute grant | anonは実行不可 |
| 既存RPC確認 | `get_public_session_comments` | 削除済みコメントを返さないことを確認 |
| 既存RPC確認 | `get_public_session_application_counts` | `accepted` / `pending` / `waitlisted` 集計を確認 |

既存 `session_applications.status` 制約は、現行草案では `pending` / `accepted` / `rejected` / `waitlisted` / `canceled` を許可している。そのため、原則として制約更新は不要。ただし、実プロトタイプDBが古い草案から作られている可能性があるため、実行前に制約定義を確認する。

`update_application_comment` と `delete_application_comment_and_maybe_cancel` は `SECURITY DEFINER` を使う草案であり、どちらも `set search_path = ''` を固定している。権限判定は、対象コメントから `session_id` / `user_id` を取得し、本人、対象セッションGM、admin のいずれかであることを確認する方針。

## 3. 事前確認SQL

以下はSQL Editorで実行前に確認するためのSQL候補である。この資料作成時点では実行しない。

### 3.1 `session_comments` カラム確認

```sql
select
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'session_comments'
order by ordinal_position;
```

確認したいこと:

- `id`, `session_id`, `user_id`, `body`, `is_application` が存在する
- `updated_at`, `edited_at`, `deleted_at` が存在する
- `edited_by`, `deleted_by` が未存在なら、008草案のALTER対象になる

### 3.2 `session_applications.status` 制約確認

```sql
select
  conname,
  pg_catalog.pg_get_constraintdef(oid) as definition
from pg_catalog.pg_constraint
where conrelid = 'public.session_applications'::regclass
  and conname = 'session_applications_status_check';
```

確認したいこと:

- `canceled` が許可値に含まれている
- 含まれていない場合は、008草案の実行前に別途レビュー済みの制約更新が必要

### 3.3 既存RPC定義確認

```sql
select pg_catalog.pg_get_functiondef('public.create_application_comment(text, text)'::regprocedure);
select pg_catalog.pg_get_functiondef('public.get_public_session_comments(text)'::regprocedure);
select pg_catalog.pg_get_functiondef('public.get_public_session_application_counts(text)'::regprocedure);
select pg_catalog.pg_get_functiondef('public.set_application_status(uuid, text)'::regprocedure);
```

確認したいこと:

- `create_application_comment` が `session_comments` と `session_applications` を分離して扱っている
- `get_public_session_comments` が `c.deleted_at is null` を含む
- `get_public_session_comments` が `user_id`, `discord_user_id`, email, role を返さない
- `get_public_session_application_counts` がコメント件数ではなく `session_applications` を基準にしている
- `set_application_status` がGM/admin相当の権限判定に寄せられている

### 3.4 既存grant確認

```sql
select
  table_schema,
  table_name,
  grantee,
  privilege_type
from information_schema.table_privileges
where table_schema = 'public'
  and table_name in ('session_comments', 'session_applications')
  and grantee in ('anon', 'authenticated')
order by table_name, grantee, privilege_type;
```

確認したいこと:

- `session_comments` / `session_applications` に不用意な直接 `UPDATE` / `DELETE` が開いていない
- コメント編集・削除・申請取消はRPC経由に寄せる

### 3.5 既存RLS確認

```sql
select
  schemaname,
  tablename,
  rowsecurity
from pg_catalog.pg_tables
where schemaname = 'public'
  and tablename in ('session_comments', 'session_applications');

select
  schemaname,
  tablename,
  policyname,
  roles,
  cmd
from pg_catalog.pg_policies
where schemaname = 'public'
  and tablename in ('session_comments', 'session_applications')
order by tablename, policyname;
```

確認したいこと:

- RLSが有効
- 既存の閲覧・作成方針と、F-6 RPC中心の更新方針が矛盾しない

## 4. 実行順序案

008草案を実行する場合は、一括実行ではなく、以下の単位で止まりながら進める。

### Step F6-SQL-0: 停止条件確認

実行前に確認すること:

- 対象がプロトタイプSupabase環境である
- 本番DBではない
- Project URL / API key / secret類をチャットやdocsへ貼っていない
- `session-detail.html` / `calendar.html` / 本番 `assets/js` を変更していない
- 008草案をユーザーが確認済み

止まる条件:

- 本番DBかどうか判断できない
- RLSや既存RPC定義が想定と違う
- `session_applications.status` に `canceled` が含まれていない

### Step F6-SQL-1: 現行制約・カラム確認

実行する候補:

- `session_comments` カラム確認
- `session_applications_status_check` 確認
- 既存RPC定義確認
- 既存grant/RLS確認

次へ進む条件:

- `edited_by` / `deleted_by` の有無が分かる
- `canceled` の許可状況が分かる
- 既存公開RPCが内部IDやDiscord IDを返さない方針を維持している

### Step F6-SQL-2: 必要なALTER TABLE

対象:

```sql
alter table public.session_comments
  add column if not exists edited_by uuid references public.profiles(id) on delete set null,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;
```

実行理由:

- 008草案のRPCが `edited_by` / `deleted_by` を更新するため、関数作成前に必要

止まる条件:

- `profiles(id)` 参照に失敗する
- 既存テーブル定義が草案と大きく異なる

### Step F6-SQL-3: index作成

対象:

```sql
create index if not exists session_comments_edited_by_idx
  on public.session_comments(edited_by);

create index if not exists session_comments_deleted_by_idx
  on public.session_comments(deleted_by);
```

次へ進む条件:

- index作成が成功
- 既存同名indexがある場合も `if not exists` で安全に通る

### Step F6-SQL-4: status制約更新の要否判断

原則:

- `canceled` が既存制約に含まれていれば何もしない
- 含まれていなければ、008草案とは別の制約更新SQLとしてレビューする

このStepでは、制約更新を008に混ぜない方針を推奨する。

### Step F6-SQL-5: `update_application_comment` 作成

確認すること:

- `security definer`
- `set search_path = ''`
- `auth.uid()` null拒否
- 対象コメントの本人 / GM / admin 判定
- 空文字と4000字超過拒否
- 削除済みコメント編集拒否
- `revoke all` / `grant execute to authenticated`

次へ進む条件:

- 関数作成成功
- execute権限が `authenticated` のみ

### Step F6-SQL-6: `delete_application_comment_and_maybe_cancel` 作成

確認すること:

- `security definer`
- `set search_path = ''`
- `auth.uid()` null拒否
- 対象コメントの本人 / GM / admin 判定
- 論理削除
- 削除対象が `is_application = true` の場合のみ申請取消判定
- 最後の有効申請コメント削除時のみ `session_applications.status = 'canceled'`
- `revoke all` / `grant execute to authenticated`

注意:

- accepted申請を最後の有効コメント削除で `canceled` にできるため、UI側では強い確認ダイアログが必要

### Step F6-SQL-7: 公開RPC・集計RPC検証

確認すること:

- `get_public_session_comments` が削除済みコメントを返さない
- `get_public_session_comments` が内部 `user_id` / `discord_user_id` を返さない
- `get_public_session_application_counts` が `canceled` を人数に含めない
- 直接テーブル更新権限が広がっていない

### Step F6-SQL-8: ローカルRLS smoke test更新と実行

008実行後は、既存 `scripts/supabase-rls-smoke-test.mjs` にF-6用ケースを追加してからAuth文脈で再確認する。

このレビュー計画作成時点では、スクリプト変更は行わない。

## 5. リスク整理

| リスク | 内容 | 対策 |
| --- | --- | --- |
| status制約不整合 | 古いDBで `canceled` が許可されていない可能性 | 実行前に制約確認。必要なら別migrationとしてレビュー |
| audit列追加の影響 | `edited_by` / `deleted_by` 追加で既存行に影響が出る可能性 | nullableで追加し、既存行を壊さない |
| 既存公開RPC互換性 | 削除済みコメントが公開RPCに出ると運用上危険 | `c.deleted_at is null` を確認 |
| 内部情報漏洩 | 公開RPCから `user_id` / `discord_user_id` が漏れる危険 | 公開RPCの戻り値を確認 |
| accepted誤取消 | 承認済み申請の最後のコメント削除で `canceled` になる | UIに強い確認。実行後テストで挙動確認 |
| 複数コメント時の人数ズレ | 有効コメントが残っているのに申請を取消す危険 | `is_application = true` かつ有効申請コメント数0の時のみ取消 |
| GM権限判定ミス | 他GMセッションのコメントを操作できる危険 | `public.is_session_gm(session_id)` 前提をRLS smoke testへ追加 |
| admin過剰権限 | adminが全件操作可能になる | dev検証では確認対象、本番運用では管理者付与手順を別途整理 |
| `SECURITY DEFINER` リスク | 所有者権限でRLSを迂回しすぎる危険 | `search_path` 固定、入力検証、対象行から権限判定 |
| grantしすぎ | anonやauthenticatedへ直接UPDATE/DELETEが開く危険 | 直接UPDATE/DELETE grantを開かずRPCに限定 |

## 6. ロールバック方針

この方針はプロトタイプDB向けであり、本番DBでは事前バックアップと別レビューを必須にする。

### 6.1 新規RPCをdropする場合

```sql
drop function if exists public.update_application_comment(uuid, text);
drop function if exists public.delete_application_comment_and_maybe_cancel(uuid);
```

注意:

- drop前にdevプロトタイプやsmoke testが対象RPCを呼んでいないか確認する
- 実行済みのコメント編集・論理削除データは戻らない

### 6.2 追加カラムを戻す場合

推奨:

- 原則として `edited_by` / `deleted_by` は残してよい
- nullable監査列であり、残しても既存表示には影響しにくい

どうしても戻す場合の草案:

```sql
drop index if exists public.session_comments_edited_by_idx;
drop index if exists public.session_comments_deleted_by_idx;

alter table public.session_comments
  drop column if exists edited_by,
  drop column if exists deleted_by;
```

注意:

- audit情報を失う
- 既存RPCが列を参照している場合、先にRPCをdropまたは修正する必要がある

### 6.3 status制約を戻す場合

`canceled` を含める制約がすでに運用前提になっているため、戻すことは推奨しない。

もし古い制約へ戻す必要がある場合:

- `session_applications.status = 'canceled'` の既存行をどう扱うか決める
- `pending` へ戻すのか、別途退避するのかを決める
- 既存 `cancel_application` / `set_application_status` / count RPCとの整合を確認する

### 6.4 `canceled` に変更済みデータの扱い

F-6 RPC実行後に `canceled` へ変わった行は、単純な関数dropでは戻らない。

戻す場合は、対象session / user / commentの操作ログを確認し、手動で `pending` などへ戻すか、再seedでプロトタイプ状態を作り直す。

## 7. 実行後検証項目

実行後は、最低限以下を確認する。

| No | ケース | 期待結果 |
| --- | --- | --- |
| 1 | 本人が自分のコメントを編集 | 成功 |
| 2 | 本人が他人のコメントを編集 | 失敗 |
| 3 | GMが自分のsessionコメントを編集 | 成功 |
| 4 | GMが他GM sessionコメントを編集 | 失敗 |
| 5 | 本人が自分のコメントを削除 | 成功 |
| 6 | GMが自分のsessionコメントを削除 | 成功 |
| 7 | 未ログインで編集・削除 | 失敗 |
| 8 | 最後の有効な申請コメントを削除 | `session_applications.status = 'canceled'` |
| 9 | 有効申請コメントが残る状態で削除 | application状態を維持 |
| 10 | accepted申請の最後のコメントを削除 | `canceled` になることを確認し、UI確認必須として扱う |
| 11 | 削除済みコメントの公開RPC表示 | 表示されない |
| 12 | 参加人数RPC | `canceled` を人数に含めない |
| 13 | 非申請コメント削除 | application状態を変えない |

## 8. RLS smoke test更新要否

F-6 RPC追加後は、`scripts/supabase-rls-smoke-test.mjs` の更新が必要。

追加したいテスト:

- `update_application_comment` を本人が実行できる
- `update_application_comment` を他人コメントに対して実行できない
- GMが自分のsessionコメントを編集できる
- GMが他GM sessionコメントを編集できない
- `delete_application_comment_and_maybe_cancel` を本人が実行できる
- 他人コメント削除が失敗する
- GMが自分のsessionコメントを削除できる
- GMが他GM sessionコメントを削除できない
- 削除済みコメントが `get_public_session_comments` に出ない
- 最後の有効申請コメント削除時にapplicationが `canceled` になる
- 有効申請コメントが残る場合はapplication状態が維持される
- 参加人数RPCが `canceled` を人数に含めない

注意:

- これらはDB状態変更を伴うため、テストデータの再seedまたは対象sessionを分ける
- accepted申請の取消テストは破壊的なので、通常smoke testでは明示フラグ制にする案がよい
- この工程ではスクリプト変更を行わない

## 9. 本番接続前の停止条件

F-6 SQL実行後も、以下が完了するまで本番接続へ進まない。

- F-6 RPCのAuth文脈テスト成功
- 削除済みコメントが公開RPCに出ないことの確認
- accepted申請削除時のUX確認
- コメント編集・削除devプロトタイプ確認
- 本番 `session-detail.html` 統合設計
- 誤操作時の戻し方の整理
- 本番GM/admin付与運用の確認

## 10. 今回まだ扱わないもの

- Supabase SQL Editorでの実行
- 本番 `session-detail.html` 実装
- 本番 `calendar.html` 実装
- devプロトタイプ実装
- Discord OAuth
- Discord通知
- メール通知
- Edge Functions
- `close_session`
- GM/admin本番管理画面
- Git commit / push

## 11. 実行結果

F-6 SQLの実行結果は以下に分離する。

```text
docs/supabase-f6-sql-execution-result.md
```

ユーザーがSupabase SQL Editorで実行済み。Codex自身はSQL Editorを実行していない。

確認済み:

- `edited_by` / `deleted_by` カラム追加済み
- `update_application_comment` 作成済み
- `delete_application_comment_and_maybe_cancel` 作成済み
- 操作RPCのexecute権限は `authenticated` のみ
- `anon` は操作RPCを実行不可
- `canceled` は既存status制約に含まれている

次工程では、RLS smoke test更新とAuth文脈での編集・削除・取消テストを行う。
