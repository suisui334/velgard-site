-- 054_signup_auth_profile_preflight_select_only.sql
-- SELECT ONLY / NO MUTATION
-- Purpose: inspect signup-related Auth/profile wiring without returning emails, ids, tokens, URLs, or secrets.

with function_rows as (
  select
    p.oid,
    p.proname,
    p.prosecdef,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config,
    pg_get_functiondef(p.oid) as function_definition
  from pg_proc p
  join pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('handle_new_auth_user_profile', 'update_display_name')
),
function_summary as (
  select
    count(*) filter (where proname = 'handle_new_auth_user_profile') as profile_handler_count,
    bool_or(proname = 'handle_new_auth_user_profile' and prosecdef) as profile_handler_security_definer,
    bool_or(proname = 'handle_new_auth_user_profile' and function_config ilike '%search_path%') as profile_handler_has_search_path,
    bool_or(
      proname = 'handle_new_auth_user_profile'
      and function_definition ilike '%raw_user_meta_data%'
      and function_definition ilike '%display_name%'
    ) as profile_handler_reads_display_name_metadata,
    bool_or(
      proname = 'handle_new_auth_user_profile'
      and function_definition ilike '%public.profiles%'
      and function_definition ilike '%display_name%'
    ) as profile_handler_targets_profiles_display_name,
    count(*) filter (where proname = 'update_display_name') as update_display_name_count
  from function_rows
),
trigger_summary as (
  select
    count(*) as profile_trigger_count,
    bool_or(t.tgenabled <> 'D') as profile_trigger_enabled
  from pg_trigger t
  join pg_class c
    on c.oid = t.tgrelid
  join pg_namespace n
    on n.oid = c.relnamespace
  join pg_proc p
    on p.oid = t.tgfoid
  join pg_namespace pn
    on pn.oid = p.pronamespace
  where n.nspname = 'auth'
    and c.relname = 'users'
    and pn.nspname = 'public'
    and p.proname = 'handle_new_auth_user_profile'
    and not t.tgisinternal
),
profiles_table_summary as (
  select
    count(*) as profiles_table_count,
    bool_or(c.relrowsecurity) as profiles_rls_enabled
  from pg_class c
  join pg_namespace n
    on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'profiles'
    and c.relkind in ('r', 'p')
),
profiles_column_summary as (
  select
    count(*) filter (where column_name = 'id') as profile_id_column_count,
    count(*) filter (where column_name = 'display_name') as display_name_column_count,
    bool_or(column_name = 'display_name' and is_nullable = 'NO') as display_name_not_nullable
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'profiles'
),
profiles_constraint_summary as (
  select
    count(*) filter (
      where contype = 'c'
        and pg_get_constraintdef(oid) ilike '%display_name%'
    ) as display_name_check_count,
    count(*) filter (
      where contype = 'f'
        and confrelid = to_regclass('auth.users')
    ) as profiles_auth_relation_count
  from pg_constraint
  where conrelid = to_regclass('public.profiles')
),
public_profiles_summary as (
  select
    count(*) as public_profile_column_count,
    count(*) filter (where column_name = 'id') as public_profile_id_count,
    count(*) filter (where column_name = 'display_name') as public_profile_display_name_count,
    count(*) filter (where column_name not in ('id', 'display_name')) as public_profile_extra_column_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'public_profiles'
),
profile_count_summary as (
  select
    count(*) as auth_user_count,
    count(p.id) as profile_count,
    count(*) filter (where p.id is null) as auth_users_without_profile_count
  from auth.users au
  left join public.profiles p
    on p.id = au.id
),
checks as (
  select 10 as sort_order, 'profile_handler_exists' as check_name,
    case when fs.profile_handler_count = 1 then 'ok' else 'review' end as status,
    fs.profile_handler_count::text as result_value,
    'Expected one public profile handler for new Auth users.' as note
  from function_summary fs

  union all
  select 20, 'profile_handler_security_definer',
    case when fs.profile_handler_security_definer then 'ok' else 'review' end,
    coalesce(fs.profile_handler_security_definer, false)::text,
    'Profile handler should run with definer privileges.'
  from function_summary fs

  union all
  select 30, 'profile_handler_has_search_path',
    case when fs.profile_handler_has_search_path then 'ok' else 'review' end,
    coalesce(fs.profile_handler_has_search_path, false)::text,
    'Profile handler should set search_path.'
  from function_summary fs

  union all
  select 40, 'profile_handler_reads_display_name_metadata',
    case when fs.profile_handler_reads_display_name_metadata then 'ok' else 'review' end,
    coalesce(fs.profile_handler_reads_display_name_metadata, false)::text,
    'Profile handler should read display_name from Auth metadata.'
  from function_summary fs

  union all
  select 50, 'profile_handler_targets_profiles_display_name',
    case when fs.profile_handler_targets_profiles_display_name then 'ok' else 'review' end,
    coalesce(fs.profile_handler_targets_profiles_display_name, false)::text,
    'Profile handler should populate public.profiles display_name.'
  from function_summary fs

  union all
  select 60, 'profile_trigger_exists',
    case when ts.profile_trigger_count >= 1 then 'ok' else 'review' end,
    ts.profile_trigger_count::text,
    'Expected an enabled trigger on Auth users that calls the profile handler.'
  from trigger_summary ts

  union all
  select 70, 'profile_trigger_enabled',
    case when ts.profile_trigger_enabled then 'ok' else 'review' end,
    coalesce(ts.profile_trigger_enabled, false)::text,
    'Disabled trigger can make signup appear to succeed without a profile row.'
  from trigger_summary ts

  union all
  select 80, 'profiles_table_exists',
    case when pts.profiles_table_count = 1 then 'ok' else 'review' end,
    pts.profiles_table_count::text,
    'Profiles table must exist for post-signup profile setup.'
  from profiles_table_summary pts

  union all
  select 90, 'profiles_rls_enabled',
    case when pts.profiles_rls_enabled then 'ok' else 'review' end,
    coalesce(pts.profiles_rls_enabled, false)::text,
    'RLS is expected; signup profile setup relies on the handler.'
  from profiles_table_summary pts

  union all
  select 100, 'profiles_display_name_column_ready',
    case when pcs.display_name_column_count = 1 and pcs.display_name_not_nullable then 'ok' else 'review' end,
    concat('display_name_count=', pcs.display_name_column_count, ',not_nullable=', coalesce(pcs.display_name_not_nullable, false)),
    'display_name should exist and be non-null.'
  from profiles_column_summary pcs

  union all
  select 110, 'profiles_display_name_check_present',
    case when pcs.display_name_check_count >= 1 then 'ok' else 'review' end,
    pcs.display_name_check_count::text,
    'A display_name constraint exists; failed handler normalization can break signup.'
  from profiles_constraint_summary pcs

  union all
  select 120, 'profiles_auth_relation_present',
    case when pcs.profiles_auth_relation_count >= 1 then 'ok' else 'review' end,
    pcs.profiles_auth_relation_count::text,
    'Profiles should be tied to Auth users.'
  from profiles_constraint_summary pcs

  union all
  select 130, 'public_profiles_minimal_columns',
    case
      when pps.public_profile_id_count = 1
        and pps.public_profile_display_name_count = 1
        and pps.public_profile_extra_column_count = 0
        then 'ok'
      else 'review'
    end,
    concat('column_count=', pps.public_profile_column_count, ',extra=', pps.public_profile_extra_column_count),
    'Public profile view should stay minimal.'
  from public_profiles_summary pps

  union all
  select 140, 'auth_users_without_profile_count',
    case when pcs.auth_users_without_profile_count = 0 then 'ok' else 'review' end,
    pcs.auth_users_without_profile_count::text,
    'Count only; no emails or ids are returned.'
  from profile_count_summary pcs

  union all
  select 150, 'update_display_name_rpc_exists',
    case when fs.update_display_name_count = 1 then 'ok' else 'review' end,
    fs.update_display_name_count::text,
    'Post-signup profile editing RPC existence check.'
  from function_summary fs

  union all
  select 160, 'auth_dashboard_signup_settings',
    'manual_check_required',
    'not_checked_by_sql',
    'Confirm public signup, email confirmation, Site URL, and redirect allowlist in Dashboard without recording real values.'
)
select
  check_name,
  status,
  result_value,
  note
from checks
order by sort_order;
