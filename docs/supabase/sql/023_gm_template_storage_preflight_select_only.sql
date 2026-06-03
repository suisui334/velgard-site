-- 023_gm_template_storage_preflight_select_only.sql
-- M-15I-2 select-only preflight for GM template preset storage.
-- Single result-set version for SQL Editor review.
--
-- Catalog inspection only. This file must not change schema, data, or
-- privileges. Do not paste credential values, connection strings, contact
-- values, or internal row values into this file or related notes.

with
expected_columns(column_sort, column_name, expected_udt_name, expected_nullable) as (
  values
    (1, 'id', 'uuid', 'NO'),
    (2, 'owner_user_id', 'uuid', 'NO'),
    (3, 'template_name', 'text', 'NO'),
    (4, 'template_type', 'text', 'NO'),
    (5, 'template_body', 'text', 'NO'),
    (6, 'is_active', 'bool', 'NO'),
    (7, 'created_at', 'timestamptz', 'NO'),
    (8, 'updated_at', 'timestamptz', 'NO')
),
planned_rpc(function_sort, function_label, signature_text) as (
  values
    (1, 'get_my_template_presets', 'public.get_my_template_presets()'),
    (2, 'create_template_preset', 'public.create_template_preset(text, text, text)'),
    (3, 'update_template_preset', 'public.update_template_preset(uuid, text, text, text, boolean)'),
    (4, 'deactivate_template_preset', 'public.deactivate_template_preset(uuid)')
),
template_types(type_sort, template_type, display_label) as (
  values
    (1, 'call', '呼び出し用'),
    (2, 'result', 'リザルト用'),
    (3, 'session_post', '依頼書用'),
    (4, 'application', '申請用'),
    (5, 'other', 'その他')
),
existing_routines(routine_sort, routine_name) as (
  values
    (1, 'get_my_player_characters'),
    (2, 'create_player_character'),
    (3, 'update_player_character'),
    (4, 'set_default_player_character'),
    (5, 'deactivate_player_character'),
    (6, 'get_gm_session_accepted_contacts'),
    (7, 'set_application_status'),
    (8, 'create_session_post'),
    (9, 'update_session_post'),
    (10, 'delete_session_post')
),
similar_tables as (
  select
    row_number() over (order by t.table_schema, t.table_name) as row_sort,
    t.table_schema,
    t.table_name,
    t.table_type
  from information_schema.tables t
  where t.table_schema in ('public', 'auth')
    and (
      t.table_name ilike '%template%'
      or t.table_name ilike '%preset%'
      or t.table_name ilike '%message%'
    )
),
profiles_id_type as (
  select
    c.data_type,
    c.udt_name,
    c.is_nullable,
    c.column_default
  from information_schema.columns c
  where c.table_schema = 'public'
    and c.table_name = 'profiles'
    and c.column_name = 'id'
),
profiles_id_fk as (
  select
    con.conname as constraint_name,
    con.conrelid::regclass::text as source_table,
    a.attname as source_column,
    con.confrelid::regclass::text as referenced_table,
    af.attname as referenced_column,
    pg_catalog.pg_get_constraintdef(con.oid) as definition,
    con.confrelid = to_regclass('auth.users') as references_auth_users
  from pg_catalog.pg_constraint con
  join pg_catalog.pg_attribute a
    on a.attrelid = con.conrelid
   and a.attnum = any(con.conkey)
  join pg_catalog.pg_attribute af
    on af.attrelid = con.confrelid
   and af.attnum = any(con.confkey)
  where con.contype = 'f'
    and con.conrelid = to_regclass('public.profiles')
    and a.attname = 'id'
),
auth_uid_type as (
  select
    pg_catalog.format_type(p.prorettype, null) as result_type
  from pg_catalog.pg_proc p
  where p.oid = to_regprocedure('auth.uid()')
),
updated_at_helpers as (
  select
    row_number() over (order by p.proname, p.oid::regprocedure::text) as row_sort,
    p.oid::regprocedure::text as signature,
    p.proname as routine_name,
    pg_catalog.pg_get_function_result(p.oid) as result_type,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') ilike '%search_path%' as has_search_path_config
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and (
      p.oid = to_regprocedure('public.set_updated_at()')
      or p.proname ilike '%updated_at%'
    )
),
admin_role_helpers as (
  select
    row_number() over (order by p.proname, p.oid::regprocedure::text) as row_sort,
    p.oid::regprocedure::text as signature,
    p.proname as routine_name,
    pg_catalog.pg_get_function_arguments(p.oid) as arguments,
    pg_catalog.pg_get_function_result(p.oid) as result_type,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') ilike '%search_path%' as has_search_path_config
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and (
      p.proname in ('is_admin', 'has_role', 'is_session_gm')
      or p.proname ilike '%admin%'
      or p.proname ilike '%role%'
    )
),
role_tables as (
  select
    row_number() over (order by t.table_name) as row_sort,
    t.table_schema,
    t.table_name,
    t.table_type
  from information_schema.tables t
  where t.table_schema = 'public'
    and (
      t.table_name ilike '%role%'
      or t.table_name in ('user_roles', 'roles')
    )
),
existing_rpc_security as (
  select
    er.routine_sort,
    p.oid::regprocedure::text as signature,
    p.proname as routine_name,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig, ','), '') ilike '%search_path%' as has_search_path_config,
    pg_catalog.pg_get_function_result(p.oid) as result_type
  from existing_routines er
  join pg_catalog.pg_proc p
    on p.proname = er.routine_name
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
),
existing_rpc_privileges as (
  select
    er.routine_sort,
    rp.routine_name,
    string_agg(
      rp.grantee || ':' || rp.privilege_type,
      ', ' order by rp.grantee, rp.privilege_type
    ) as grants_summary
  from existing_routines er
  join information_schema.routine_privileges rp
    on rp.routine_name = er.routine_name
  where rp.routine_schema = 'public'
    and rp.grantee in ('anon', 'authenticated', 'PUBLIC', 'public')
  group by er.routine_sort, rp.routine_name
),
planned_rpc_exact as (
  select
    pr.function_sort,
    pr.function_label,
    pr.signature_text,
    to_regprocedure(pr.signature_text) as resolved_signature
  from planned_rpc pr
),
planned_rpc_name_matches as (
  select
    row_number() over (order by p.proname, p.oid::regprocedure::text) as row_sort,
    p.oid::regprocedure::text as existing_signature,
    p.proname as routine_name,
    pg_catalog.pg_get_function_result(p.oid) as result_type
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'get_my_template_presets',
      'create_template_preset',
      'update_template_preset',
      'deactivate_template_preset'
    )
),
related_policies as (
  select
    row_number() over (order by p.tablename, p.policyname) as row_sort,
    p.tablename,
    p.policyname,
    p.cmd,
    array_to_string(p.roles, ',') as roles_summary
  from pg_catalog.pg_policies p
  where p.schemaname = 'public'
    and p.tablename in ('profiles', 'player_characters', 'gm_template_presets')
),
related_table_privileges as (
  select
    row_number() over (order by tp.table_name, tp.grantee, tp.privilege_type) as row_sort,
    tp.table_name,
    tp.grantee,
    tp.privilege_type
  from information_schema.table_privileges tp
  where tp.table_schema = 'public'
    and tp.table_name in ('profiles', 'player_characters', 'gm_template_presets')
    and tp.grantee in ('anon', 'authenticated', 'PUBLIC', 'public')
),
text_check_constraints as (
  select
    row_number() over (order by con.conrelid::regclass::text, con.conname) as row_sort,
    con.conrelid::regclass::text as table_name,
    con.conname as constraint_name,
    pg_catalog.pg_get_constraintdef(con.oid) as definition
  from pg_catalog.pg_constraint con
  where con.connamespace = 'public'::regnamespace
    and con.contype = 'c'
    and (
      pg_catalog.pg_get_constraintdef(con.oid) ilike '%status%'
      or pg_catalog.pg_get_constraintdef(con.oid) ilike '%type%'
      or pg_catalog.pg_get_constraintdef(con.oid) ilike '%visibility%'
      or pg_catalog.pg_get_constraintdef(con.oid) ilike '%role%'
    )
),
final_rows as (
  select
    10::integer as sort_order,
    '01_table_presence'::text as section,
    'gm_template_presets'::text as check_name,
    'not present before apply is acceptable'::text as expected,
    case
      when to_regclass('public.gm_template_presets') is null then 'pending_create'
      else 'exists'
    end::text as status,
    coalesce(to_regclass('public.gm_template_presets')::text, 'not found')::text as result_value,
    'Confirm whether the planned table name is unused before draft/apply.'::text as notes

  union all

  select
    20 + st.row_sort::integer as sort_order,
    '02_similar_table_names'::text as section,
    st.table_schema || '.' || st.table_name as check_name,
    'review name collisions'::text as expected,
    'info'::text as status,
    st.table_type::text as result_value,
    'Similar table name found in catalog.'::text as notes
  from similar_tables st

  union all

  select
    20::integer as sort_order,
    '02_similar_table_names'::text as section,
    'similar table names'::text as check_name,
    'none or reviewed'::text as expected,
    'none'::text as status,
    'not found'::text as result_value,
    'No template/preset/message-like table names were found.'::text as notes
  where not exists (select 1 from similar_tables)

  union all

  select
    100 + ec.column_sort::integer as sort_order,
    '03_expected_column_contract'::text as section,
    ec.column_name::text as check_name,
    ec.expected_udt_name || ', nullable=' || ec.expected_nullable as expected,
    case
      when to_regclass('public.gm_template_presets') is null then 'pending_create'
      when c.column_name is null then 'missing'
      when c.udt_name = ec.expected_udt_name
        and c.is_nullable = ec.expected_nullable then 'ok'
      else 'review'
    end::text as status,
    coalesce(
      c.udt_name || ', nullable=' || c.is_nullable,
      'not found'
    )::text as result_value,
    'Expected initial column contract for the future table.'::text as notes
  from expected_columns ec
  left join information_schema.columns c
    on c.table_schema = 'public'
   and c.table_name = 'gm_template_presets'
   and c.column_name = ec.column_name

  union all

  select
    200::integer as sort_order,
    '04_profiles_id_type'::text as section,
    'profiles.id'::text as check_name,
    'uuid, not nullable'::text as expected,
    case
      when p.udt_name = 'uuid' and p.is_nullable = 'NO' then 'ok'
      when p.udt_name is null then 'missing'
      else 'review'
    end::text as status,
    coalesce(p.udt_name || ', nullable=' || p.is_nullable, 'not found')::text as result_value,
    'owner_user_id should be compatible with profiles.id.'::text as notes
  from (select 1) seed
  left join profiles_id_type p
    on true

  union all

  select
    210::integer as sort_order,
    '05_profiles_id_auth_users_fk'::text as section,
    'profiles.id foreign key'::text as check_name,
    'references auth.users(id)'::text as expected,
    case
      when count(*) filter (where f.references_auth_users) > 0 then 'ok'
      when count(*) = 0 then 'missing'
      else 'review'
    end::text as status,
    coalesce(
      string_agg(
        f.constraint_name || ' => ' || f.referenced_table || '(' || f.referenced_column || ')',
        ' | ' order by f.constraint_name
      ),
      'not found'
    )::text as result_value,
    'Checks catalog metadata only.'::text as notes
  from profiles_id_fk f

  union all

  select
    220::integer as sort_order,
    '06_auth_uid_type_compatibility'::text as section,
    'profiles.id and auth.uid()'::text as check_name,
    'both uuid'::text as expected,
    case
      when p.udt_name = 'uuid' and a.result_type = 'uuid' then 'ok'
      when p.udt_name is null or a.result_type is null then 'missing'
      else 'review'
    end::text as status,
    coalesce('profiles.id=' || p.udt_name, 'profiles.id=not found')
      || ', '
      || coalesce('auth.uid()=' || a.result_type, 'auth.uid()=not found') as result_value,
    'Confirms type premise for auth.uid() comparisons.'::text as notes
  from (select 1) seed
  left join profiles_id_type p
    on true
  left join auth_uid_type a
    on true

  union all

  select
    300 + u.row_sort::integer as sort_order,
    '07_updated_at_helpers'::text as section,
    u.signature::text as check_name,
    'existing helper can be reused if suitable'::text as expected,
    'info'::text as status,
    'security_definer=' || u.security_definer::text
      || ', search_path=' || u.has_search_path_config::text
      || ', result=' || u.result_type as result_value,
    'Review before choosing updated_at trigger strategy.'::text as notes
  from updated_at_helpers u

  union all

  select
    300::integer as sort_order,
    '07_updated_at_helpers'::text as section,
    'updated_at helper candidates'::text as check_name,
    'existing helper preferred if present'::text as expected,
    'none'::text as status,
    'not found'::text as result_value,
    'Draft SQL may need to create or avoid a trigger helper after review.'::text as notes
  where not exists (select 1 from updated_at_helpers)

  union all

  select
    400 + a.row_sort::integer as sort_order,
    '08_admin_role_helpers'::text as section,
    a.signature::text as check_name,
    'review existing app-role helpers'::text as expected,
    'info'::text as status,
    'args=' || a.arguments
      || ', result=' || a.result_type
      || ', security_definer=' || a.security_definer::text
      || ', search_path=' || a.has_search_path_config::text as result_value,
    'admin is an app-level role, do not treat it as a server credential.'::text as notes
  from admin_role_helpers a

  union all

  select
    400::integer as sort_order,
    '08_admin_role_helpers'::text as section,
    'admin / role helper candidates'::text as check_name,
    'is_admin / has_role candidates if present'::text as expected,
    'none'::text as status,
    'not found'::text as result_value,
    'No matching helper names were found.'::text as notes
  where not exists (select 1 from admin_role_helpers)

  union all

  select
    500 + rt.row_sort::integer as sort_order,
    '09_role_table_candidates'::text as section,
    rt.table_schema || '.' || rt.table_name as check_name,
    'review role table shape if present'::text as expected,
    'info'::text as status,
    rt.table_type::text as result_value,
    'Role-related table candidate found.'::text as notes
  from role_tables rt

  union all

  select
    500::integer as sort_order,
    '09_role_table_candidates'::text as section,
    'role table candidates'::text as check_name,
    'existing role table if present'::text as expected,
    'none'::text as status,
    'not found'::text as result_value,
    'No role-like table names were found.'::text as notes
  where not exists (select 1 from role_tables)

  union all

  select
    600 + s.routine_sort::integer as sort_order,
    '10_existing_rpc_security_tendency'::text as section,
    s.signature::text as check_name,
    'security definer and explicit search_path are preferred'::text as expected,
    case
      when s.security_definer and s.has_search_path_config then 'ok'
      else 'review'
    end::text as status,
    'security_definer=' || s.security_definer::text
      || ', search_path=' || s.has_search_path_config::text
      || ', result=' || s.result_type as result_value,
    'Existing RPC tendency for draft alignment.'::text as notes
  from existing_rpc_security s

  union all

  select
    600::integer as sort_order,
    '10_existing_rpc_security_tendency'::text as section,
    'existing RPC sample'::text as check_name,
    'at least one comparable RPC'::text as expected,
    'none'::text as status,
    'not found'::text as result_value,
    'No comparable existing RPC names were found.'::text as notes
  where not exists (select 1 from existing_rpc_security)

  union all

  select
    700 + p.routine_sort::integer as sort_order,
    '11_existing_rpc_execute_privileges'::text as section,
    p.routine_name::text as check_name,
    'authenticated usually allowed, anon/public reviewed per RPC'::text as expected,
    'info'::text as status,
    p.grants_summary::text as result_value,
    'Use this to align EXECUTE grants in draft SQL.'::text as notes
  from existing_rpc_privileges p

  union all

  select
    700::integer as sort_order,
    '11_existing_rpc_execute_privileges'::text as section,
    'existing RPC execute grants'::text as check_name,
    'grant tendency should be visible'::text as expected,
    'none'::text as status,
    'not found'::text as result_value,
    'No matching routine privilege rows were found.'::text as notes
  where not exists (select 1 from existing_rpc_privileges)

  union all

  select
    800 + p.function_sort::integer as sort_order,
    '12_planned_rpc_signature_collisions'::text as section,
    p.function_label::text as check_name,
    'no existing exact signature before draft'::text as expected,
    case
      when p.resolved_signature is null then 'ok'
      else 'collision'
    end::text as status,
    coalesce(p.resolved_signature::text, 'not found')::text as result_value,
    p.signature_text::text as notes
  from planned_rpc_exact p

  union all

  select
    850 + n.row_sort::integer as sort_order,
    '13_planned_rpc_name_collisions'::text as section,
    n.routine_name::text as check_name,
    'no same-name routine before draft'::text as expected,
    'collision'::text as status,
    n.existing_signature::text as result_value,
    'Same name exists with some signature, review before draft.'::text as notes
  from planned_rpc_name_matches n

  union all

  select
    850::integer as sort_order,
    '13_planned_rpc_name_collisions'::text as section,
    'planned RPC names'::text as check_name,
    'no same-name routine before draft'::text as expected,
    'ok'::text as status,
    'not found'::text as result_value,
    'No same-name planned RPC was found.'::text as notes
  where not exists (select 1 from planned_rpc_name_matches)

  union all

  select
    900 + p.row_sort::integer as sort_order,
    '14_related_rls_policies'::text as section,
    p.tablename || '.' || p.policyname as check_name,
    'review related policy style'::text as expected,
    'info'::text as status,
    'cmd=' || p.cmd || ', roles=' || p.roles_summary as result_value,
    'Related RLS policy metadata only.'::text as notes
  from related_policies p

  union all

  select
    900::integer as sort_order,
    '14_related_rls_policies'::text as section,
    'related policy candidates'::text as check_name,
    'existing related policy if present'::text as expected,
    'none'::text as status,
    'not found'::text as result_value,
    'No related policy rows were found.'::text as notes
  where not exists (select 1 from related_policies)

  union all

  select
    950 + tp.row_sort::integer as sort_order,
    '15_related_table_privileges'::text as section,
    tp.table_name || ':' || tp.grantee as check_name,
    'review related table grants'::text as expected,
    'info'::text as status,
    tp.privilege_type::text as result_value,
    'Related table privilege metadata only.'::text as notes
  from related_table_privileges tp

  union all

  select
    950::integer as sort_order,
    '15_related_table_privileges'::text as section,
    'related table privileges'::text as check_name,
    'existing related grants if present'::text as expected,
    'none'::text as status,
    'not found'::text as result_value,
    'No related table privilege rows were found.'::text as notes
  where not exists (select 1 from related_table_privileges)

  union all

  select
    1000 + c.row_sort::integer as sort_order,
    '16_existing_text_check_constraints'::text as section,
    c.table_name || '.' || c.constraint_name as check_name,
    'review fixed text value style'::text as expected,
    'info'::text as status,
    c.definition::text as result_value,
    'Useful for choosing CHECK constraint style in draft SQL.'::text as notes
  from text_check_constraints c

  union all

  select
    1000::integer as sort_order,
    '16_existing_text_check_constraints'::text as section,
    'text check constraints'::text as check_name,
    'existing examples if present'::text as expected,
    'none'::text as status,
    'not found'::text as result_value,
    'No related CHECK constraint examples were found.'::text as notes
  where not exists (select 1 from text_check_constraints)

  union all

  select
    1100 + tt.type_sort::integer as sort_order,
    '17_initial_template_type_candidates'::text as section,
    tt.template_type::text as check_name,
    'fixed DB value with Japanese UI label'::text as expected,
    'candidate'::text as status,
    tt.display_label::text as result_value,
    'Initial type candidate for later draft validation.'::text as notes
  from template_types tt
)
select
  sort_order,
  section,
  check_name,
  expected,
  status,
  result_value,
  notes
from final_rows
order by sort_order, section, check_name;
