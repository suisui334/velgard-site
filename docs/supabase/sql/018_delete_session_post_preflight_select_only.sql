-- 018_delete_session_post_preflight_select_only.sql
-- M-14D-13B select-only preflight for delete_session_post RPC design.
-- Paste this whole file into SQL Editor before reviewing the RPC draft.
-- This file is read-only catalog inspection. It must not change schema, data, or privileges.

select
  to_regrole('anon') as anon_role,
  to_regrole('authenticated') as authenticated_role;

select
  to_regclass('public.sessions') as sessions_table;

select
  con.conname,
  pg_get_constraintdef(con.oid) as definition
from pg_constraint con
where con.conrelid = to_regclass('public.sessions')
  and con.contype = 'p'
order by con.conname;

select
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'sessions'
  and column_name in (
    'id',
    'gm_user_id',
    'visibility',
    'status',
    'discord_message_id',
    'discord_channel_id',
    'discord_thread_id',
    'discord_post_url',
    'discord_sync_status',
    'discord_last_action',
    'discord_sync_requested_at',
    'discord_synced_at'
  )
order by ordinal_position;

with expected_tables(table_schema, table_name, purpose) as (
  values
    ('public', 'session_applications', 'application rows'),
    ('public', 'session_comments', 'application comments'),
    ('public', 'profiles', 'profile contact source'),
    ('public', 'public_profiles', 'public profile display'),
    ('public', 'session_application_history', 'application history candidate'),
    ('public', 'session_application_events', 'application history candidate'),
    ('public', 'application_history', 'application history candidate'),
    ('public', 'session_histories', 'session history candidate')
)
select
  e.table_schema,
  e.table_name,
  e.purpose,
  to_regclass(format('%I.%I', e.table_schema, e.table_name)) as regclass_value,
  case
    when to_regclass(format('%I.%I', e.table_schema, e.table_name)) is null then false
    else true
  end as table_exists
from expected_tables e
order by e.table_name;

select
  c.table_schema,
  c.table_name,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable
from information_schema.columns c
join information_schema.tables t
  on t.table_schema = c.table_schema
 and t.table_name = c.table_name
where c.table_schema = 'public'
  and c.column_name = 'session_id'
  and t.table_type = 'BASE TABLE'
order by c.table_schema, c.table_name;

with session_fks as (
  select
    con.oid,
    con.conname,
    con.conrelid,
    con.confrelid,
    con.conkey,
    con.confkey,
    con.confdeltype
  from pg_constraint con
  where con.contype = 'f'
    and con.confrelid = to_regclass('public.sessions')
)
select
  f.conname,
  f.conrelid::regclass as referencing_table,
  (
    select array_agg(att.attname order by cols.ord)
    from unnest(f.conkey) with ordinality as cols(attnum, ord)
    join pg_attribute att
      on att.attrelid = f.conrelid
     and att.attnum = cols.attnum
  ) as referencing_columns,
  f.confrelid::regclass as referenced_table,
  (
    select array_agg(att.attname order by cols.ord)
    from unnest(f.confkey) with ordinality as cols(attnum, ord)
    join pg_attribute att
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
  pg_get_constraintdef(f.oid) as definition
from session_fks f
order by f.conrelid::regclass::text, f.conname;

with session_fks as (
  select
    con.confdeltype
  from pg_constraint con
  where con.contype = 'f'
    and con.confrelid = to_regclass('public.sessions')
)
select
  case confdeltype
    when 'a' then 'NO ACTION'
    when 'r' then 'RESTRICT'
    when 'c' then 'CASCADE'
    when 'n' then 'SET NULL'
    when 'd' then 'SET DEFAULT'
    else confdeltype::text
  end as on_delete_action,
  count(*) as fk_count
from session_fks
group by confdeltype
order by on_delete_action;

select
  p.oid::regprocedure as signature,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer,
  p.provolatile as volatility
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'delete_session_post',
    'update_session_post',
    'has_role',
    'is_admin',
    'is_session_gm'
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
    'delete_session_post',
    'update_session_post',
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
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
left join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
  on true
left join pg_roles r
  on r.oid = acl.grantee
where n.nspname = 'public'
  and p.proname in (
    'delete_session_post',
    'update_session_post',
    'has_role',
    'is_admin',
    'is_session_gm'
  )
order by p.proname, p.oid::regprocedure::text, grantee, acl.privilege_type;
