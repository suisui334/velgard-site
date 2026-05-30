-- ============================================================
-- Velgard Supabase Free Prototype
-- 009_profiles_display_name_rpc_draft.sql
--
-- DRAFT ONLY:
-- - M-9 display_name / public_profiles 用の追加SQL草案。
-- - 実行前にSQL Editor上で確認し、必要な範囲だけ段階実行する。
-- - このファイルには実Project URL、API key、secret、実メール、
--   実Discord ID、service role key、DB passwordを書かない。
-- - mypage.html / assets/js/mypageAuthClient.js の実装変更は別工程で扱う。
-- ============================================================

-- ============================================================
-- 1. 事前確認SQL
-- ============================================================

-- 1-1. profiles のカラム確認。
select
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'profiles'
order by ordinal_position;

-- 1-2. profiles.id が auth.users.id を参照する外部キーであることを確認。
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

-- 1-3. display_name の not null / blank拒否制約を確認。
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

-- 1-4. Authユーザーとprofiles行の対応状況を件数だけ確認。
-- 実user_id全文を画面やdocsに転記しないこと。
select
  count(*) as auth_user_count,
  count(p.id) as profiles_count,
  count(*) filter (where p.id is null) as missing_profiles_count
from auth.users au
left join public.profiles p
  on p.id = au.id;

-- 1-5. public_profiles の定義確認。公開列は id / display_name のみに絞る。
select pg_get_viewdef('public.public_profiles'::regclass, true) as public_profiles_definition;

select
  column_name,
  data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'public_profiles'
order by ordinal_position;

-- 1-6. profiles RLS有効確認。
select
  schemaname,
  tablename,
  rowsecurity
from pg_catalog.pg_tables
where schemaname = 'public'
  and tablename = 'profiles';

-- 1-7. profiles の既存policy確認。
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

-- 1-8. 既存関数/RPCとtrigger確認。
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

-- ============================================================
-- 2. profiles自動作成trigger案
-- ============================================================

-- 方針:
-- - auth.users insert時に public.profiles(id, display_name) を作成する。
-- - display_name初期値は user_metadata.display_name があれば使う。
-- - なければ「名無しの冒険者」を使う。
-- - email / discord_user_id / discord_name / role / token は保存しない。
-- - 既存profilesがある場合は上書きしない。

create or replace function public.handle_new_auth_user_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  metadata_display_name text;
  safe_display_name text;
begin
  metadata_display_name := nullif(trim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), '');
  safe_display_name := coalesce(metadata_display_name, '名無しの冒険者');

  if char_length(safe_display_name) > 40 then
    safe_display_name := left(safe_display_name, 40);
  end if;

  if length(trim(safe_display_name)) = 0 then
    safe_display_name := '名無しの冒険者';
  end if;

  insert into public.profiles (
    id,
    display_name
  )
  values (
    new.id,
    safe_display_name
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

revoke all on function public.handle_new_auth_user_profile() from public;

drop trigger if exists on_auth_user_created_create_profile on auth.users;

create trigger on_auth_user_created_create_profile
after insert on auth.users
for each row execute function public.handle_new_auth_user_profile();

-- ============================================================
-- 3. 既存ユーザーbackfill案
-- ============================================================

-- 実行前確認:
-- - missing_profiles_count が0でない場合だけbackfillを検討する。
-- - 実user_id全文はチャット、README、docsへ転記しない。
select
  count(*) filter (where p.id is null) as missing_profiles_count
from auth.users au
left join public.profiles p
  on p.id = au.id;

-- backfill本体:
-- - 既存profilesがある場合は上書きしない。
-- - user_metadata.display_name があれば使う。
-- - なければ「名無しの冒険者」を使う。
-- - email / discord_user_id / discord_name / role / token は保存しない。
insert into public.profiles (
  id,
  display_name
)
select
  au.id,
  case
    when nullif(trim(coalesce(au.raw_user_meta_data ->> 'display_name', '')), '') is null
      then '名無しの冒険者'
    when char_length(trim(au.raw_user_meta_data ->> 'display_name')) > 40
      then left(trim(au.raw_user_meta_data ->> 'display_name'), 40)
    else trim(au.raw_user_meta_data ->> 'display_name')
  end as display_name
from auth.users au
where not exists (
  select 1
  from public.profiles p
  where p.id = au.id
)
on conflict (id) do nothing;

-- backfill後確認:
select
  count(*) as auth_user_count,
  count(p.id) as profiles_count,
  count(*) filter (where p.id is null) as missing_profiles_count
from auth.users au
left join public.profiles p
  on p.id = au.id;

-- ============================================================
-- 4. update_display_name RPC案
-- ============================================================

-- 方針:
-- - authenticatedユーザー本人だけが自分のdisplay_nameを更新できる。
-- - auth.uid() がnullなら拒否する。
-- - 空文字、40文字超を拒否する。
-- - profiles行がない場合は本人分だけ作成する。
-- - 戻り値は id / display_name のみに限定する。
-- - email / token / role / discord_user_id は返さない。

create or replace function public.update_display_name(
  new_display_name text
)
returns table (
  id uuid,
  display_name text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  clean_display_name text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  clean_display_name := nullif(trim(coalesce(new_display_name, '')), '');

  if clean_display_name is null then
    raise exception 'display name is blank';
  end if;

  if char_length(clean_display_name) > 40 then
    raise exception 'display name is too long';
  end if;

  return query
  insert into public.profiles as p (
    id,
    display_name
  )
  values (
    auth.uid(),
    clean_display_name
  )
  on conflict (id) do update
  set
    display_name = excluded.display_name,
    updated_at = now()
  where p.id = auth.uid()
  returning p.id, p.display_name;
end;
$$;

revoke all on function public.update_display_name(text) from public;
grant execute on function public.update_display_name(text) to authenticated;

-- ============================================================
-- 5. public_profiles確認
-- ============================================================

-- 現行viewが id / display_name のみならview変更は不要。
select
  column_name,
  data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'public_profiles'
order by ordinal_position;

select
  has_table_privilege('anon', 'public.public_profiles', 'SELECT') as anon_can_select_public_profiles,
  has_table_privilege('authenticated', 'public.public_profiles', 'SELECT') as authenticated_can_select_public_profiles;

-- ============================================================
-- 6. RLS / security方針確認
-- ============================================================

-- profiles本体をanon公開しない。
-- public_profilesのみ最小公開する。
-- 本人の表示名更新は update_display_name RPCへ寄せる。
select
  has_table_privilege('anon', 'public.profiles', 'SELECT') as anon_can_select_profiles,
  has_table_privilege('anon', 'public.profiles', 'UPDATE') as anon_can_update_profiles,
  has_function_privilege('anon', 'public.update_display_name(text)', 'EXECUTE') as anon_can_execute_update_display_name,
  has_function_privilege('authenticated', 'public.update_display_name(text)', 'EXECUTE') as authenticated_can_execute_update_display_name;

-- ============================================================
-- 7. テスト観点
-- ============================================================

-- SQL EditorでSQLを適用した後、別途anon/authenticated clientで確認する。
-- - 未ログインで update_display_name が拒否される。
-- - 本人が自分のdisplay_nameを更新できる。
-- - 空文字が拒否される。
-- - 40文字超が拒否される。
-- - public_profilesからid/display_nameのみ読める。
-- - profiles本体にemail/token/roleが出ない。
-- - 既存ユーザーbackfill後にprofilesが作られる。
-- - 新規signUp後にprofilesが自動作成される。
--
-- 注意:
-- - 実メール、実パスワード、実Project URL、API key、tokenは記録しない。
-- - mypage.htmlへの実装統合は、このSQL草案の実行と検証が終わった後の別工程にする。
