-- 020_application_pc_snapshot_preflight_select_only.sql
-- M-15F select-only preflight for application PC name snapshot review.
-- Catalog inspection only. No schema, data, or privilege changes.

select
  to_regrole('anon') as anon_role,
  to_regrole('authenticated') as authenticated_role,
  to_regclass('public.profiles') as profiles_table,
  to_regclass('public.sessions') as sessions_table,
  to_regclass('public.session_comments') as session_comments_table,
  to_regclass('public.session_applications') as session_applications_table,
  to_regclass('public.player_characters') as player_characters_table;

select
  c.table_name,
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
    'comment_id',
    'status',
    'selected_character_id',
    'pc_name_snapshot',
    'created_at',
    'updated_at',
    'canceled_at'
  )
order by c.ordinal_position;

select
  c.table_name,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'session_comments'
  and c.column_name in (
    'id',
    'session_id',
    'user_id',
    'body',
    'is_application',
    'created_at',
    'updated_at',
    'edited_at',
    'deleted_at'
  )
order by c.ordinal_position;

select
  c.table_name,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name = 'player_characters'
  and c.column_name in (
    'id',
    'owner_user_id',
    'pc_name',
    'is_default',
    'is_active',
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
where con.conrelid in (
    to_regclass('public.session_applications'),
    to_regclass('public.player_characters')
  )
order by con.conrelid::regclass::text, con.contype, con.conname;

with application_fk_rows as (
  select
    con.conname,
    con.conrelid::regclass as referencing_table,
    con.confrelid::regclass as referenced_table,
    case con.confdeltype
      when 'a' then 'NO ACTION'
      when 'r' then 'RESTRICT'
      when 'c' then 'CASCADE'
      when 'n' then 'SET NULL'
      when 'd' then 'SET DEFAULT'
      else con.confdeltype::text
    end as on_delete_action,
    pg_catalog.pg_get_constraintdef(con.oid) as definition
  from pg_catalog.pg_constraint con
  where con.contype = 'f'
    and con.conrelid = to_regclass('public.session_applications')
)
select
  conname,
  referencing_table,
  referenced_table,
  on_delete_action,
  definition
from application_fk_rows
order by conname;

select
  schemaname,
  tablename,
  indexname,
  indexdef
from pg_catalog.pg_indexes
where schemaname = 'public'
  and tablename in ('session_applications', 'player_characters')
order by tablename, indexname;

with expected_routines(function_name, regprocedure_text) as (
  values
    ('has_role', 'public.has_role(text)'),
    ('is_admin', 'public.is_admin()'),
    ('is_session_gm', 'public.is_session_gm(text)'),
    ('can_apply_to_session', 'public.can_apply_to_session(text)'),
    ('create_application_comment', 'public.create_application_comment(text, text)'),
    ('cancel_my_session_application', 'public.cancel_my_session_application(text)'),
    ('get_gm_session_accepted_contacts', 'public.get_gm_session_accepted_contacts(text)'),
    ('get_my_player_characters', 'public.get_my_player_characters()'),
    ('create_player_character', 'public.create_player_character(text, boolean)'),
    ('update_player_character', 'public.update_player_character(uuid, text, boolean, boolean)'),
    ('set_default_player_character', 'public.set_default_player_character(uuid)'),
    ('deactivate_player_character', 'public.deactivate_player_character(uuid)')
)
select
  e.function_name,
  e.regprocedure_text,
  to_regprocedure(e.regprocedure_text) as regprocedure_value
from expected_routines e
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
    'can_apply_to_session',
    'create_application_comment',
    'cancel_my_session_application',
    'get_gm_session_accepted_contacts',
    'get_my_player_characters',
    'create_player_character',
    'update_player_character',
    'set_default_player_character',
    'deactivate_player_character',
    'set_application_status',
    'update_application_comment',
    'delete_application_comment_and_maybe_cancel'
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
    'has_role',
    'is_admin',
    'is_session_gm',
    'can_apply_to_session',
    'create_application_comment',
    'cancel_my_session_application',
    'get_gm_session_accepted_contacts',
    'get_my_player_characters',
    'create_player_character',
    'update_player_character',
    'set_default_player_character',
    'deactivate_player_character',
    'set_application_status',
    'update_application_comment',
    'delete_application_comment_and_maybe_cancel'
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
    'create_application_comment',
    'cancel_my_session_application',
    'get_gm_session_accepted_contacts',
    'set_application_status',
    'update_application_comment',
    'delete_application_comment_and_maybe_cancel'
  )
order by p.proname, p.oid::regprocedure::text, grantee, acl.privilege_type;

select
  con.conname,
  pg_catalog.pg_get_constraintdef(con.oid) as definition
from pg_catalog.pg_constraint con
where con.conrelid = to_regclass('public.session_applications')
  and con.conname in (
    'session_applications_status_check',
    'session_applications_session_id_user_id_key'
  )
order by con.conname;

select
  p.oid::regprocedure as signature,
  p.proname as routine_name,
  pg_catalog.pg_get_function_arguments(p.oid) as arguments,
  pg_catalog.pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer,
  p.proconfig as function_config
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'create_application_comment',
    'cancel_my_session_application',
    'get_gm_session_accepted_contacts'
  )
order by p.proname, p.oid::regprocedure::text;

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
where table_schema = 'public'
  and table_name in (
    'session_applications',
    'session_comments',
    'player_characters'
  )
  and grantee in ('anon', 'authenticated', 'PUBLIC', 'public')
order by table_name, grantee, privilege_type;
