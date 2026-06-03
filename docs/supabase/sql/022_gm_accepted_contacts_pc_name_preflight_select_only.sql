-- 022_gm_accepted_contacts_pc_name_preflight_select_only.sql
-- M-15G preflight for adding PC names to GM accepted participant contacts.
--
-- SELECT-only. Do not paste secrets, real user IDs, emails, Discord IDs,
-- application IDs, selected_character_id values, tokens, keys, or passwords
-- into this file or related notes.
--
-- This file avoids function body expansion and inspects only catalog
-- contracts, grants, constraints, columns, and aggregate counts.

select
  to_regclass('public.sessions') as sessions_table,
  to_regclass('public.profiles') as profiles_table,
  to_regclass('public.session_applications') as session_applications_table,
  to_regclass('public.player_characters') as player_characters_table,
  to_regprocedure('public.get_gm_session_accepted_contacts(text)') as accepted_contacts_rpc;

select
  c.table_name,
  c.column_name,
  c.data_type,
  c.is_nullable
from information_schema.columns c
where c.table_schema = 'public'
  and (
    (c.table_name = 'profiles'
      and c.column_name in ('id', 'display_name', 'discord_handle'))
    or (c.table_name = 'sessions'
      and c.column_name in ('id', 'gm_user_id'))
    or (c.table_name = 'session_applications'
      and c.column_name in (
        'id',
        'session_id',
        'user_id',
        'status',
        'selected_character_id',
        'pc_name_snapshot'
      ))
    or (c.table_name = 'player_characters'
      and c.column_name in ('id', 'owner_user_id', 'pc_name', 'is_active', 'is_default'))
  )
order by c.table_name, c.ordinal_position;

select
  con.conname,
  con.contype,
  pg_catalog.pg_get_constraintdef(con.oid) as definition
from pg_catalog.pg_constraint con
where con.conrelid = to_regclass('public.session_applications')
  and (
    con.conname = 'session_applications_status_check'
    or pg_catalog.pg_get_constraintdef(con.oid) ilike '%session_id%'
    or pg_catalog.pg_get_constraintdef(con.oid) ilike '%user_id%'
    or pg_catalog.pg_get_constraintdef(con.oid) ilike '%selected_character_id%'
  )
order by con.contype, con.conname;

select
  'session_applications_status_check' as check_name,
  pg_catalog.pg_get_constraintdef(con.oid) as definition,
  pg_catalog.pg_get_constraintdef(con.oid) ilike '%accepted%' as includes_accepted
from pg_catalog.pg_constraint con
where con.conrelid = to_regclass('public.session_applications')
  and con.conname = 'session_applications_status_check';

with function_targets(function_label, signature_text) as (
  values
    ('get_gm_session_accepted_contacts', 'public.get_gm_session_accepted_contacts(text)'),
    ('has_role', 'public.has_role(text)'),
    ('is_admin', 'public.is_admin()'),
    ('is_session_gm', 'public.is_session_gm(text)')
)
select
  ft.function_label,
  ft.signature_text,
  to_regprocedure(ft.signature_text) as resolved_signature,
  p.prosecdef as security_definer,
  p.proconfig as function_config,
  pg_catalog.pg_get_function_arguments(p.oid) as arguments,
  pg_catalog.pg_get_function_result(p.oid) as result_type
from function_targets ft
left join pg_catalog.pg_proc p
  on p.oid = to_regprocedure(ft.signature_text)
order by ft.function_label;

select
  r.routine_name,
  p.parameter_name,
  p.data_type,
  p.udt_name,
  p.parameter_mode,
  p.ordinal_position
from information_schema.routines r
join information_schema.parameters p
  on p.specific_schema = r.specific_schema
 and p.specific_name = r.specific_name
where r.specific_schema = 'public'
  and r.routine_name = 'get_gm_session_accepted_contacts'
order by p.ordinal_position;

with expected_grants(grantee, expected_execute) as (
  values
    ('authenticated', true),
    ('anon', false),
    ('public', false)
),
actual_grants as (
  select
    lower(rp.grantee) as grantee,
    true as actual_execute
  from information_schema.routine_privileges rp
  where rp.routine_schema = 'public'
    and rp.routine_name = 'get_gm_session_accepted_contacts'
    and rp.privilege_type = 'EXECUTE'
)
select
  eg.grantee,
  eg.expected_execute,
  coalesce(ag.actual_execute, false) as actual_execute,
  coalesce(ag.actual_execute, false) = eg.expected_execute as ok
from expected_grants eg
left join actual_grants ag
  on ag.grantee = eg.grantee
order by eg.grantee;

select
  rp.routine_name,
  rp.grantee,
  rp.privilege_type
from information_schema.routine_privileges rp
where rp.routine_schema = 'public'
  and rp.routine_name in (
    'get_gm_session_accepted_contacts',
    'has_role',
    'is_admin',
    'is_session_gm'
  )
order by rp.routine_name, rp.grantee, rp.privilege_type;

select
  count(*) as accepted_application_count,
  count(*) filter (
    where nullif(trim(sa.pc_name_snapshot), '') is not null
  ) as accepted_with_pc_name_snapshot_count,
  count(*) filter (
    where nullif(trim(sa.pc_name_snapshot), '') is null
  ) as accepted_without_pc_name_snapshot_count,
  count(*) filter (
    where sa.selected_character_id is not null
  ) as accepted_with_selected_character_count,
  count(*) filter (
    where s.gm_user_id is not null
      and sa.user_id = s.gm_user_id
  ) as accepted_rows_matching_session_gm_count
from public.session_applications sa
join public.sessions s
  on s.id = sa.session_id
where sa.status = 'accepted';
