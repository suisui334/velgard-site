-- 019_player_characters_preflight_select_only.sql
-- M-15B select-only preflight for player character and application PC name design.
-- Use this file only for catalog inspection before reviewing the draft.
-- This file must not change schema, data, privileges, or stored values.

select
  to_regrole('anon') as anon_role,
  to_regrole('authenticated') as authenticated_role,
  to_regclass('auth.users') as auth_users_table,
  to_regclass('public.profiles') as profiles_table,
  to_regclass('public.sessions') as sessions_table,
  to_regclass('public.session_applications') as session_applications_table,
  to_regclass('public.player_characters') as player_characters_table;

select
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'profiles'
  and c.column_name in (
    'id',
    'display_name',
    'discord_handle',
    'created_at',
    'updated_at'
  )
order by c.ordinal_position;

select
  con.conname,
  con.contype,
  con.conrelid::regclass as source_table,
  con.confrelid::regclass as target_table,
  pg_catalog.pg_get_constraintdef(con.oid) as definition
from pg_catalog.pg_constraint con
where con.conrelid = to_regclass('public.profiles')
  and (
    con.contype in ('p', 'f', 'u')
    or pg_catalog.pg_get_constraintdef(con.oid) ilike '%auth.users%'
  )
order by con.contype, con.conname;

select
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'session_applications'
order by c.ordinal_position;

select
  con.conname,
  pg_catalog.pg_get_constraintdef(con.oid) as definition
from pg_catalog.pg_constraint con
where con.conrelid = to_regclass('public.session_applications')
  and con.contype = 'p'
order by con.conname;

select
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'session_applications'
  and c.column_name in (
    'id',
    'session_id',
    'user_id',
    'status',
    'comment_id',
    'selected_character_id',
    'pc_name_snapshot',
    'created_at',
    'updated_at',
    'canceled_at'
  )
order by c.ordinal_position;

select
  con.conname,
  con.contype,
  pg_catalog.pg_get_constraintdef(con.oid) as definition
from pg_catalog.pg_constraint con
where con.conrelid = to_regclass('public.session_applications')
order by con.contype, con.conname;

with application_fks as (
  select
    con.oid,
    con.conname,
    con.conrelid,
    con.confrelid,
    con.conkey,
    con.confkey,
    con.confdeltype
  from pg_catalog.pg_constraint con
  where con.contype = 'f'
    and con.conrelid = to_regclass('public.session_applications')
)
select
  f.conname,
  f.conrelid::regclass as referencing_table,
  (
    select array_agg(att.attname order by cols.ord)
    from unnest(f.conkey) with ordinality as cols(attnum, ord)
    join pg_catalog.pg_attribute att
      on att.attrelid = f.conrelid
     and att.attnum = cols.attnum
  ) as referencing_columns,
  f.confrelid::regclass as referenced_table,
  (
    select array_agg(att.attname order by cols.ord)
    from unnest(f.confkey) with ordinality as cols(attnum, ord)
    join pg_catalog.pg_attribute att
      on att.attrelid = f.confrelid
     and att.attnum = cols.attnum
  ) as referenced_columns,
  case f.confdeltype
    when 'a' then 'NO ACTION'
    when 'r' then 'RESTRICT'
    when 'c' then 'CASCADE'
    when 'n' then 'SET NULL'
    when 'd' then 'SET DEFAULT'
    else f.confdeltype::text
  end as on_delete_action,
  pg_catalog.pg_get_constraintdef(f.oid) as definition
from application_fks f
order by f.conname;

select
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'player_characters'
order by c.ordinal_position;

select
  con.conname,
  con.contype,
  pg_catalog.pg_get_constraintdef(con.oid) as definition
from pg_catalog.pg_constraint con
where con.conrelid = to_regclass('public.player_characters')
order by con.contype, con.conname;

select
  schemaname,
  tablename,
  indexname,
  indexdef
from pg_catalog.pg_indexes
where schemaname = 'public'
  and tablename in ('player_characters', 'session_applications')
  and (
    tablename = 'player_characters'
    or indexdef ilike '%selected_character_id%'
    or indexdef ilike '%pc_name_snapshot%'
  )
order by tablename, indexname;

with expected_functions(function_name, regprocedure_text) as (
  values
    ('has_role', 'public.has_role(text)'),
    ('is_admin', 'public.is_admin()'),
    ('is_session_gm', 'public.is_session_gm(text)'),
    ('get_my_player_characters', 'public.get_my_player_characters()'),
    ('create_player_character', 'public.create_player_character(text, boolean)'),
    ('update_player_character', 'public.update_player_character(uuid, text, boolean, boolean)'),
    ('delete_player_character', 'public.delete_player_character(uuid)'),
    ('deactivate_player_character', 'public.deactivate_player_character(uuid)'),
    ('set_default_player_character', 'public.set_default_player_character(uuid)'),
    ('update_my_application_character', 'public.update_my_application_character(text, uuid)')
)
select
  e.function_name,
  e.regprocedure_text,
  to_regprocedure(e.regprocedure_text) as regprocedure_value
from expected_functions e
order by e.function_name, e.regprocedure_text;

select
  p.oid::regprocedure as signature,
  p.proname as routine_name,
  pg_catalog.pg_get_function_arguments(p.oid) as arguments,
  pg_catalog.pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer,
  p.provolatile as volatility,
  p.proconfig as function_config
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'has_role',
    'is_admin',
    'is_session_gm',
    'get_my_player_characters',
    'create_player_character',
    'update_player_character',
    'delete_player_character',
    'deactivate_player_character',
    'set_default_player_character',
    'update_my_application_character',
    'create_application_comment',
    'get_gm_session_accepted_contacts'
  )
order by p.proname, p.oid::regprocedure::text;

select
  routine_name,
  specific_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name in (
    'get_my_player_characters',
    'create_player_character',
    'update_player_character',
    'delete_player_character',
    'deactivate_player_character',
    'set_default_player_character',
    'update_my_application_character',
    'create_application_comment',
    'get_gm_session_accepted_contacts',
    'has_role',
    'is_admin',
    'is_session_gm'
  )
  and grantee in ('anon', 'authenticated', 'PUBLIC', 'public')
order by routine_name, specific_name, grantee, privilege_type;

select
  p.oid::regprocedure as signature,
  coalesce(r.rolname, 'PUBLIC') as grantee,
  acl.privilege_type,
  acl.is_grantable
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n
  on n.oid = p.pronamespace
left join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
  on true
left join pg_catalog.pg_roles r
  on r.oid = acl.grantee
where n.nspname = 'public'
  and p.proname in (
    'get_my_player_characters',
    'create_player_character',
    'update_player_character',
    'delete_player_character',
    'deactivate_player_character',
    'set_default_player_character',
    'update_my_application_character',
    'create_application_comment',
    'get_gm_session_accepted_contacts'
  )
order by p.proname, p.oid::regprocedure::text, grantee, acl.privilege_type;

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
  and tablename in (
    'profiles',
    'session_applications',
    'session_comments',
    'player_characters'
  )
order by tablename, policyname;

select
  table_schema,
  table_name,
  grantee,
  privilege_type
from information_schema.table_privileges
where table_schema in ('public', 'auth')
  and table_name in (
    'users',
    'profiles',
    'session_applications',
    'player_characters'
  )
  and grantee in ('anon', 'authenticated', 'PUBLIC', 'public')
order by table_schema, table_name, grantee, privilege_type;
