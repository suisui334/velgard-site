# Supabase M-9 display_name SQL実行前レビュー計画

## 1. 目的

この資料は、`docs/supabase/sql/009_profiles_display_name_rpc_draft.sql` をSupabase SQL Editorで実行する前のレビュー計画である。

この工程ではSQLを実行しない。目的は、`display_name` をマイページで扱う前に必要な `profiles` 自動作成trigger、既存ユーザーbackfill、`update_display_name` RPC、`public_profiles` 公開範囲確認について、実行範囲、事前確認、実行順序、検証手順、ロールバック方針を整理すること。

本番 `mypage.html` 実装、`assets/js/mypageAuthClient.js` 実装、表示名フォーム、自分の申請一覧、参加予定、`session-detail.html` 統合、Discord連携、通知、メール送信は対象外とする。

## 2. 実行対象SQLの整理

対象ファイル:

```text
docs/supabase/sql/009_profiles_display_name_rpc_draft.sql
```

実行候補の範囲:

| 区分 | 内容 | 備考 |
| --- | --- | --- |
| 事前確認SQL | `profiles` カラム、外部キー、`display_name` 制約、件数、view、RLS、policy、既存関数・trigger確認 | 先に実行し、結果を見て停止判断する |
| trigger function案 | `public.handle_new_auth_user_profile()` | Authユーザー作成時に `profiles` 行を作成 |
| trigger案 | `on_auth_user_created_create_profile` | `auth.users` の `after insert` trigger |
| 既存ユーザーbackfill案 | `auth.users` にいて `profiles` がないユーザー分だけinsert | 欠損件数が0なら実行不要 |
| RPC案 | `public.update_display_name(new_display_name text)` | 本人が自分の表示名だけを更新 |
| grant/revoke | 新RPCは `public` からrevokeし、`authenticated` にexecute grant | anonは実行不可 |
| 公開view確認 | `public.public_profiles` | 現行viewが `id` / `display_name` のみなら変更不要 |
| security確認 | `profiles` 本体、`public_profiles`、RPC権限確認 | 公開範囲を最小化する |

`009_profiles_display_name_rpc_draft.sql` は既存の `001_core_schema_draft.sql` と `002_rls_grants_draft.sql` を前提にしている。`profiles` は `auth.users(id)` への外部キー、`display_name text not null`、空白拒否制約、`updated_at` を持つ想定である。

## 3. 事前確認SQL

以下はSQL Editorで確認する候補である。この資料作成時点では実行しない。

### 3.1 `profiles` カラム確認

```sql
select
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'profiles'
order by ordinal_position;
```

確認したいこと:

- `id uuid` が存在する
- `display_name text not null` が存在する
- `updated_at timestamptz` が存在する
- `email` やtoken相当の列をこの工程で追加しない

### 3.2 `profiles.id` 外部キー確認

```sql
select
  tc.constraint_name,
  tc.constraint_type,
  kcu.column_name,
  ccu.table_schema as foreign_table_schema,
  ccu.table_name as foreign_table_name,
  ccu.column_name as foreign_column_name
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu
  on tc.constraint_name = kcu.constraint_name
 and tc.table_schema = kcu.table_schema
 and tc.constraint_schema = kcu.constraint_schema
join information_schema.constraint_column_usage ccu
  on ccu.constraint_name = tc.constraint_name
 and ccu.constraint_schema = tc.constraint_schema
where tc.table_schema = 'public'
  and tc.table_name = 'profiles'
  and tc.constraint_type = 'FOREIGN KEY'
order by tc.constraint_name, kcu.ordinal_position;
```

確認したいこと:

- `profiles.id` が `auth.users.id` と対応している
- Authユーザーなしで `profiles` 行だけを作る前提になっていない

### 3.3 `display_name` 制約確認

```sql
select
  conname,
  contype,
  pg_get_constraintdef(oid) as definition
from pg_catalog.pg_constraint
where conrelid = 'public.profiles'::regclass
  and (
    conname = 'profiles_display_name_not_blank'
    or pg_get_constraintdef(oid) ilike '%display_name%'
  )
order by conname;
```

確認したいこと:

- `display_name` に空白拒否の制約がある
- 40文字上限は現行テーブル制約ではなく、trigger初期値とRPC入力検証で扱う

### 3.4 Authユーザーと `profiles` 対応件数確認

```sql
select
  count(*) as auth_user_count,
  count(p.id) as profiles_count,
  count(*) filter (where p.id is null) as missing_profiles_count
from auth.users au
left join public.profiles p
  on p.id = au.id;
```

確認したいこと:

- 欠損件数だけを確認する
- 実user_id全文、実メール、個別ユーザー情報はチャット、README、docsへ転記しない
- `missing_profiles_count = 0` の場合はbackfill本体を実行しない判断が可能

### 3.5 `public_profiles` 定義確認

```sql
select pg_get_viewdef('public.public_profiles'::regclass, true) as public_profiles_definition;

select
  column_name,
  data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'public_profiles'
order by ordinal_position;
```

確認したいこと:

- 公開列が `id` / `display_name` のみ
- `discord_user_id`、`discord_name`、email、role、token相当の列が出ない
- view変更が不要かどうかをここで判断する

### 3.6 `profiles` RLS / policy確認

```sql
select
  schemaname,
  tablename,
  rowsecurity
from pg_catalog.pg_tables
where schemaname = 'public'
  and tablename = 'profiles';

select
  schemaname,
  tablename,
  policyname,
  roles,
  cmd,
  qual,
  with_check
from pg_catalog.pg_policies
where schemaname = 'public'
  and tablename = 'profiles'
order by policyname;
```

確認したいこと:

- `profiles` のRLSが有効
- 本人select / insert / updateとadmin用policyの範囲が想定どおり
- anon向けに `profiles` 本体の直接公開を広げない

### 3.7 既存関数・trigger確認

```sql
select
  n.nspname as function_schema,
  p.proname as function_name,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as result_type
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n
  on n.oid = p.pronamespace
where n.nspname in ('public', 'auth')
  and (
    p.proname in ('handle_new_auth_user_profile', 'update_display_name')
    or p.proname ilike '%profile%'
    or p.proname ilike '%display%'
  )
order by n.nspname, p.proname;

select
  event_object_schema,
  event_object_table,
  trigger_name,
  event_manipulation,
  action_timing,
  action_statement
from information_schema.triggers
where (event_object_schema = 'auth' and event_object_table = 'users')
   or (event_object_schema = 'public' and event_object_table = 'profiles')
order by event_object_schema, event_object_table, trigger_name;
```

確認したいこと:

- 同名または類似のprofile作成triggerが既にない
- `update_display_name` が既に存在する場合は、定義差分を見てから上書き判断する
- `profiles_set_updated_at` など既存triggerとの役割が衝突しない

## 4. `profiles` 自動作成triggerの確認点

`public.handle_new_auth_user_profile()` は、Authユーザー作成時に `public.profiles(id, display_name)` を作成するためのtrigger function案である。

確認すること:

- `security definer` と `set search_path = ''` が指定されている
- 参照テーブルは `public.profiles` のようにschema修飾されている
- `new.raw_user_meta_data ->> 'display_name'` が空でなければ初期値に使う
- 初期値がない場合は `名無しの冒険者` にする
- 40文字を超える初期値は40文字に丸める
- 既存 `profiles` 行がある場合は `on conflict (id) do nothing` で上書きしない
- email、role、Discord ID、token相当の値を保存しない
- `revoke all on function public.handle_new_auth_user_profile() from public;` により直接呼び出しを開かない

実行上の注意:

- `drop trigger if exists on_auth_user_created_create_profile on auth.users;` は同名triggerを置き換える操作である
- 既に別名で同じ役割のtriggerが存在する場合は、二重作成を避けるためここで止める
- trigger作成後の動作確認は新規サインアップ時の `profiles` 自動作成で行う

## 5. 既存ユーザーbackfillの注意点

backfillは、既に `auth.users` に存在するが `public.profiles` 行がないユーザーだけを補完する操作である。

実行前の判断:

- `missing_profiles_count` が0ならbackfill本体は実行しない
- 欠損がある場合も、件数だけを記録し、個別idやメールはdocsへ保存しない
- 既存 `profiles` 行を上書きしないことを確認する

backfill本体の性質:

- `where not exists (...)` と `on conflict (id) do nothing` により既存行を保護する
- 初期 `display_name` はmetadata値または `名無しの冒険者`
- metadata値はtrimし、40文字超は40文字までに丸める
- email、Discord ID、role、token相当の値を保存しない

実行後確認:

```sql
select
  count(*) as auth_user_count,
  count(p.id) as profiles_count,
  count(*) filter (where p.id is null) as missing_profiles_count
from auth.users au
left join public.profiles p
  on p.id = au.id;
```

期待:

- `missing_profiles_count = 0`
- 既存 `profiles.display_name` が上書きされていない

## 6. `update_display_name` RPCの確認点

`public.update_display_name(new_display_name text)` は、ログイン中の本人だけが自分の `display_name` を更新するためのRPC案である。

確認すること:

- `security definer` と `set search_path = ''` が指定されている
- `auth.uid()` がnullなら拒否する
- 入力をtrimし、空文字は拒否する
- 40文字超は拒否する
- `profiles` 行がない場合は本人分だけ作成する
- 既存行がある場合は本人分だけ更新する
- `updated_at` を更新する
- 戻り値は `id` / `display_name` のみ
- email、role、Discord ID、token相当の値を返さない
- `revoke all on function public.update_display_name(text) from public;`
- `grant execute on function public.update_display_name(text) to authenticated;`
- anonにはexecuteを許可しない

注意:

- `SECURITY DEFINER` 関数はRLSだけに頼らず、関数内の `auth.uid()` と `where p.id = auth.uid()` で本人限定を確認する
- `profiles_update_own` / `profiles_insert_own` policyが存在しても、フロント実装はRPC経由へ寄せる方針とする
- 既に同名RPCが存在する場合は、`create or replace` 実行前に既存定義との差分を確認する

## 7. `public_profiles` 最小公開確認

`public_profiles` は、公開してよいプロフィール情報だけを返すviewとして扱う。

確認すること:

- 列が `id` / `display_name` のみ
- `anon` と `authenticated` が `public_profiles` をselectできる
- `profiles` 本体をanonへ直接selectさせない
- `discord_user_id`、`discord_name`、email、role、token相当の値が出ない

権限確認SQL候補:

```sql
select
  has_table_privilege('anon', 'public.public_profiles', 'SELECT') as anon_can_select_public_profiles,
  has_table_privilege('authenticated', 'public.public_profiles', 'SELECT') as authenticated_can_select_public_profiles;
```

現行viewが最小列を満たしている場合、009工程ではview再作成を行わない。

## 8. RLS / security確認

009適用後に確認すること:

```sql
select
  has_table_privilege('anon', 'public.profiles', 'SELECT') as anon_can_select_profiles,
  has_table_privilege('anon', 'public.profiles', 'UPDATE') as anon_can_update_profiles,
  has_function_privilege('anon', 'public.update_display_name(text)', 'EXECUTE') as anon_can_execute_update_display_name,
  has_function_privilege('authenticated', 'public.update_display_name(text)', 'EXECUTE') as authenticated_can_execute_update_display_name;
```

期待:

- anonは `profiles` 本体をselectできない
- anonは `profiles` 本体をupdateできない
- anonは `update_display_name` をexecuteできない
- authenticatedは `update_display_name` をexecuteできる
- 公開表示は `public_profiles` に限定される

運用上の禁止:

- secret key、DB password、Direct connection string、JWTの秘密値、tokenをdocsやチャットに出さない
- 実Project URL / publishable key / anon keyの実値をdocsやチャットに貼らない
- `.env.local` の中身を出さない
- SQL Editor上の実メール、実user_id全文、個別ユーザー情報を転記しない

## 9. 実行順序案

009草案を実行する場合は、一括実行ではなく、以下の単位で止まりながら進める。

### Step M9-SQL-0: 停止条件確認

実行前に確認すること:

- 対象が意図したSupabase環境である
- 009草案をユーザーが確認済み
- SQL Editorで実行する範囲をユーザーが承認済み
- `mypage.html` / `assets/js/mypageAuthClient.js` はまだ変更しない
- secret類や実URL/key/tokenをチャット・docsへ貼っていない

止まる条件:

- 対象環境が判断できない
- 既存 `profiles` / `public_profiles` の定義が草案と大きく違う
- 既に同等のtrigger / RPCが存在し、上書き可否が判断できない
- `profiles` 本体がanon公開されているなど、権限状態に違和感がある

### Step M9-SQL-1: 事前確認SQL

実行する候補:

- `profiles` カラム確認
- `profiles.id` 外部キー確認
- `display_name` 制約確認
- Authユーザーと `profiles` 対応件数確認
- `public_profiles` 定義・列確認
- `profiles` RLS / policy確認
- 既存関数・trigger確認

次へ進む条件:

- `profiles` が想定どおり存在する
- `public_profiles` が `id` / `display_name` のみ
- `missing_profiles_count` が把握できている
- 同等trigger / RPCの重複がない、または置き換え方針が明確

### Step M9-SQL-2: 自動作成trigger作成

対象:

- `public.handle_new_auth_user_profile()`
- `on_auth_user_created_create_profile`

次へ進む条件:

- 関数作成が成功
- trigger作成が成功
- 直接execute権限を広げていない

止まる条件:

- `auth.users` へのtrigger作成で権限エラーが出る
- 既存triggerとの重複が判明する
- `public.profiles` へのinsertが既存制約に合わない

### Step M9-SQL-3: backfill要否判断と実行

判断:

- `missing_profiles_count = 0` ならbackfill本体は実行しない
- `missing_profiles_count > 0` の場合だけ、補完insertを実行する

実行後:

- 対応件数確認SQLを再実行する
- `missing_profiles_count = 0` を確認する
- 個別idやメールは記録しない

### Step M9-SQL-4: `update_display_name` RPC作成

対象:

- `public.update_display_name(new_display_name text)`
- `revoke all ... from public`
- `grant execute ... to authenticated`

次へ進む条件:

- RPC作成が成功
- anon execute不可
- authenticated execute可
- 戻り値が `id` / `display_name` のみ

### Step M9-SQL-5: 公開範囲・権限確認

確認すること:

- `public_profiles` は `id` / `display_name` のみ
- `public_profiles` はanon / authenticatedがselect可能
- `profiles` 本体はanon select不可
- `profiles` 本体はanon update不可
- `update_display_name` はanon execute不可
- `update_display_name` はauthenticated execute可

### Step M9-SQL-6: 実行結果の記録

実行後に別docsへ結果を整理する場合の候補:

```text
docs/supabase-mypage-display-name-sql-execution-result.md
```

記録する内容:

- 実行したSQL範囲
- 事前確認結果の要約
- backfill実行有無と欠損件数の変化
- trigger / RPC / 権限確認結果
- SQL Editor実行者がユーザーであること
- secret類、実URL/key/token、実メール、実user_id全文を記録していないこと

## 10. ロールバック方針

この方針はM-9 SQL適用直後の戻し方を整理するものであり、本番DBでの作業では事前バックアップと別レビューを必須にする。

### 10.1 triggerを戻す場合

```sql
drop trigger if exists on_auth_user_created_create_profile on auth.users;
drop function if exists public.handle_new_auth_user_profile();
```

注意:

- triggerをdropすると、以後の新規Authユーザーに `profiles` 行が自動作成されなくなる
- 既に作成された `profiles` 行は消えない

### 10.2 `update_display_name` RPCを戻す場合

```sql
drop function if exists public.update_display_name(text);
```

注意:

- RPCをdropすると、マイページ実装から表示名更新が呼べなくなる
- 既に更新済みの `display_name` は戻らない
- 戻す必要がある場合は、対象者本人確認と値の扱いを別途決める

### 10.3 backfill済みデータの扱い

backfillで作られた `profiles` 行は、単純な関数dropでは戻らない。

推奨:

- 原則としてbackfill済みの `profiles` 行は残す
- `profiles` は将来の申請・参加予定・コメント表示でも必要な基礎行であるため、削除をロールバックの第一選択にしない

どうしても戻す場合:

- SQL Editor内で対象件数と対象idを慎重に確認する
- 実user_id全文をdocsやチャットへ転記しない
- 既存 `profiles` 行を巻き込んで削除しない
- 関連テーブルの外部キー影響を確認する

### 10.4 view / RLSを戻す場合

009草案では、現行 `public_profiles` が最小列ならview変更は不要である。

もし実行中にviewやRLSの不整合が見つかった場合:

- 009の範囲に混ぜず、別SQL草案としてレビューする
- `profiles` 本体をanon公開する方向には戻さない
- 公開範囲は `public_profiles` の最小列に限定する

## 11. 実行後検証

SQL適用後は、最低限以下を確認する。

| No | ケース | 期待結果 |
| --- | --- | --- |
| 1 | 未ログインで `update_display_name` 実行 | 失敗 |
| 2 | ログイン中の本人が妥当な表示名へ更新 | 成功 |
| 3 | 空文字または空白だけの表示名 | 失敗 |
| 4 | 40文字超の表示名 | 失敗 |
| 5 | `profiles` 行がない本人がRPC実行 | 本人分だけ作成または更新成功 |
| 6 | 新規サインアップ後 | `profiles` 行が自動作成される |
| 7 | `public_profiles` select | `id` / `display_name` のみ返る |
| 8 | anonで `profiles` 本体select | 失敗または不可 |
| 9 | anonで `profiles` 本体update | 失敗または不可 |
| 10 | anonで `update_display_name` execute | 失敗または不可 |
| 11 | authenticatedで `update_display_name` execute | 成功 |
| 12 | 公開RPC / viewの戻り値 | email、role、Discord ID、token相当が出ない |

検証時の注意:

- 実メール、実パスワード、実Project URL、key、tokenを画面、console、docsへ出さない
- テスト用ユーザーの表示名を変える場合は、元の値へ戻せるようSQL Editor内またはテスト手順内で完結させる
- ユーザー実ブラウザ確認は、マイページ実装工程へ進んだ後に別途行う

## 12. RLS smoke test更新要否

009 SQL適用後は、`scripts/supabase-rls-smoke-test.mjs` の更新が必要。

既存スクリプトには `public_profiles` が内部列を返さない確認はあるが、`update_display_name` RPC、trigger、backfillの確認はまだ入っていない。

追加したいテスト候補:

- anonが `update_display_name` を実行できない
- authenticatedユーザーが自分の `display_name` を更新できる
- 空文字が拒否される
- 40文字超が拒否される
- 更新後の `public_profiles` が `id` / `display_name` のみ返す
- `profiles` 本体にanonで直接アクセスできない
- テスト後に表示名を元へ戻す
- 新規サインアップtriggerは、専用の使い捨てテストユーザー設計ができるまで通常smoke testへ入れない
- backfillはSQL Editor実行時の件数確認で扱い、通常smoke testでは実行しない

注意:

- 表示名更新は既存fixtureの状態を変えるため、実行後復元を必須にする
- 使い捨てユーザー作成を伴うテストは運用負荷があるため、別fixtureまたは手動確認に分離する
- この工程ではスクリプト変更を行わない

## 13. まだ扱わないもの

- Supabase SQL Editorでの実行
- `mypage.html` 変更
- `assets/js/mypageAuthClient.js` 変更
- display_nameフォーム実装
- 自分の申請一覧
- 参加予定セッション表示
- `session-detail.html` 投稿統合
- GM操作
- Discord連携
- 通知
- メール送信
- Edge Functions
- `updates.json` 変更
- Git commit / push

## 14. 次工程

このレビュー計画を確認した後の次工程候補:

1. ユーザーがレビュー計画と009草案を確認する。
2. SQL Editorで実行する範囲を決める。
3. ユーザーがSupabase SQL Editorで事前確認SQLから段階実行する。
4. 実行結果を `docs/supabase-mypage-display-name-sql-result.md` へ整理する。
5. RLS smoke test更新計画または実装へ進む。
6. SQLとRLS確認が安定してから、`mypage.html` / `assets/js/mypageAuthClient.js` のdisplay_name実装へ進む。

## 15. 反映結果

M-9 display_name SQLの反映結果は、以下に分離する。

```text
docs/supabase-mypage-display-name-sql-result.md
```

確認済み:

- `handle_new_auth_user_profile` が存在する。
- `update_display_name(new_display_name text)` が存在する。
- `update_display_name` は `anon` execute不可。
- `update_display_name` は `authenticated` execute可。
- `public_profiles` は `id` / `display_name` のみ。
- `auth_users_without_profile` は `0`。
- `profiles` 自動作成trigger と `update_display_name` RPC は追加済みまたは既存反映済み扱い。

M-9 SQLについて、追加SQLはこれ以上実行しない。次工程は `mypage.html` のdisplay_name表示・編集フロント実装とする。
