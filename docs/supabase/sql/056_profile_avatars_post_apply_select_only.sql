-- 056_profile_avatars_post_apply_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Confirm 055 profile avatar/storage preparation after an approved apply gate.
-- - Return boolean/status style results only.
-- - Do not return real user ids, avatar object paths, emails, tokens, full URLs, or secrets.

with role_refs as (
  select
    to_regrole('anon') as anon_role,
    to_regrole('authenticated') as authenticated_role
),
profiles_columns as (
  select
    count(*) filter (where column_name = 'avatar_path') as avatar_path_count,
    count(*) filter (where column_name = 'avatar_updated_at') as avatar_updated_at_count,
    bool_or(column_name = 'avatar_path' and data_type = 'text') as avatar_path_is_text,
    bool_or(column_name = 'avatar_updated_at' and data_type = 'timestamp with time zone') as avatar_updated_at_is_timestamptz
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'profiles'
),
profiles_constraints as (
  select
    count(*) filter (
      where conname = 'profiles_avatar_path_safe_check'
        and pg_get_constraintdef(oid) ilike '%avatar_path%'
        and pg_get_constraintdef(oid) ilike '%png%'
        and pg_get_constraintdef(oid) ilike '%webp%'
    ) as avatar_constraint_count
  from pg_constraint
  where conrelid = to_regclass('public.profiles')
),
public_profiles_columns as (
  select
    count(*) filter (where column_name = 'id') as id_count,
    count(*) filter (where column_name = 'display_name') as display_name_count,
    count(*) filter (where column_name = 'avatar_path') as avatar_path_count,
    count(*) filter (where column_name = 'avatar_updated_at') as avatar_updated_at_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'public_profiles'
),
bucket_summary as (
  select
    count(*) filter (where id = 'avatars') as bucket_count,
    bool_or(id = 'avatars' and public is true) as bucket_public_read,
    bool_or(id = 'avatars' and file_size_limit <= 1048576) as bucket_size_limit_ready,
    bool_or(id = 'avatars' and allowed_mime_types @> array['image/png', 'image/jpeg', 'image/webp']) as bucket_mime_types_ready
  from storage.buckets
),
policy_summary as (
  select
    count(*) filter (where policyname = 'avatars_public_read') as public_read_policy_count,
    count(*) filter (where policyname = 'avatars_owner_insert') as owner_insert_policy_count,
    count(*) filter (where policyname = 'avatars_owner_update') as owner_update_policy_count,
    count(*) filter (where policyname = 'avatars_owner_delete') as owner_delete_policy_count
  from pg_policies
  where schemaname = 'storage'
    and tablename = 'objects'
),
function_rows as (
  select
    p.oid,
    p.proname,
    pg_get_function_identity_arguments(p.oid) as identity_args,
    pg_get_function_result(p.oid) as result_shape,
    p.prosecdef,
    coalesce(array_to_string(p.proconfig, ','), '') as function_config,
    pg_get_functiondef(p.oid) as function_def
  from pg_proc p
  join pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'update_my_avatar_path',
      'clear_my_avatar_path',
      'get_public_session_comments'
    )
),
function_summary as (
  select
    count(*) filter (where proname = 'update_my_avatar_path' and identity_args = 'new_avatar_path text') as update_avatar_count,
    count(*) filter (where proname = 'clear_my_avatar_path' and identity_args = '') as clear_avatar_count,
    count(*) filter (where proname = 'get_public_session_comments' and identity_args = 'target_session_id text') as comment_rpc_count,
    bool_or(proname = 'update_my_avatar_path' and prosecdef) as update_avatar_security_definer,
    bool_or(proname = 'clear_my_avatar_path' and prosecdef) as clear_avatar_security_definer,
    bool_or(proname = 'get_public_session_comments' and prosecdef) as comment_rpc_security_definer,
    bool_or(proname = 'update_my_avatar_path' and function_config ilike '%search_path%') as update_avatar_search_path,
    bool_or(proname = 'clear_my_avatar_path' and function_config ilike '%search_path%') as clear_avatar_search_path,
    bool_or(proname = 'get_public_session_comments' and function_config ilike '%search_path%') as comment_rpc_search_path,
    bool_or(proname = 'update_my_avatar_path' and function_def ilike '%auth.uid()%') as update_avatar_auth_uid_pattern,
    bool_or(proname = 'clear_my_avatar_path' and function_def ilike '%auth.uid()%') as clear_avatar_auth_uid_pattern,
    bool_or(proname = 'get_public_session_comments' and result_shape ilike '%avatar_path%') as comment_rpc_returns_avatar_path,
    bool_or(proname = 'get_public_session_comments' and result_shape ilike '%avatar_updated_at%') as comment_rpc_returns_avatar_updated_at
  from function_rows
),
function_privileges as (
  select
    fr.proname,
    fr.identity_args,
    has_function_privilege((select authenticated_role from role_refs), fr.oid, 'EXECUTE') as authenticated_execute,
    has_function_privilege((select anon_role from role_refs), fr.oid, 'EXECUTE') as anon_execute
  from function_rows fr
),
output_rows as (
  select 10 as sort_order, 'profiles_avatar_path_column'::text as check_name,
    case when pc.avatar_path_count = 1 and pc.avatar_path_is_text then 'ok' else 'review' end as status,
    concat('count=', pc.avatar_path_count, ',text=', coalesce(pc.avatar_path_is_text, false)) as result_value,
    'profiles.avatar_path should exist as text and store an object key, not a full URL.'::text as note
  from profiles_columns pc

  union all
  select 20, 'profiles_avatar_updated_at_column',
    case when pc.avatar_updated_at_count = 1 and pc.avatar_updated_at_is_timestamptz then 'ok' else 'review' end,
    concat('count=', pc.avatar_updated_at_count, ',timestamptz=', coalesce(pc.avatar_updated_at_is_timestamptz, false)),
    'profiles.avatar_updated_at should exist for cache/display refresh.'
  from profiles_columns pc

  union all
  select 30, 'profiles_avatar_path_constraint',
    case when pc.avatar_constraint_count >= 1 then 'ok' else 'review' end,
    pc.avatar_constraint_count::text,
    'A safety constraint should restrict avatar path shape and allowed extensions.'
  from profiles_constraints pc

  union all
  select 40, 'public_profiles_avatar_columns',
    case
      when ppc.id_count = 1
       and ppc.display_name_count = 1
       and ppc.avatar_path_count = 1
       and ppc.avatar_updated_at_count = 1
      then 'ok' else 'review'
    end,
    concat(
      'id=', ppc.id_count,
      ',display_name=', ppc.display_name_count,
      ',avatar_path=', ppc.avatar_path_count,
      ',avatar_updated_at=', ppc.avatar_updated_at_count
    ),
    'public_profiles should expose only public display identity fields plus avatar metadata.'
  from public_profiles_columns ppc

  union all
  select 50, 'avatars_bucket_exists',
    case when bs.bucket_count = 1 then 'ok' else 'review' end,
    bs.bucket_count::text,
    'The avatars storage bucket should exist after 055.'
  from bucket_summary bs

  union all
  select 60, 'avatars_bucket_public_read',
    case when bs.bucket_public_read then 'ok' else 'review' end,
    coalesce(bs.bucket_public_read, false)::text,
    'MVP assumes avatars are public display assets.'
  from bucket_summary bs

  union all
  select 70, 'avatars_bucket_file_and_mime_limits',
    case when bs.bucket_size_limit_ready and bs.bucket_mime_types_ready then 'ok' else 'review' end,
    concat(
      'size_limit_ready=', coalesce(bs.bucket_size_limit_ready, false),
      ',mime_types_ready=', coalesce(bs.bucket_mime_types_ready, false)
    ),
    'The bucket should allow png/jpeg/webp and an approximately 1MB limit.'
  from bucket_summary bs

  union all
  select 80, 'avatars_storage_policies_present',
    case
      when ps.public_read_policy_count = 1
       and ps.owner_insert_policy_count = 1
       and ps.owner_update_policy_count = 1
       and ps.owner_delete_policy_count = 1
      then 'ok' else 'review'
    end,
    concat(
      'read=', ps.public_read_policy_count,
      ',insert=', ps.owner_insert_policy_count,
      ',update=', ps.owner_update_policy_count,
      ',delete=', ps.owner_delete_policy_count
    ),
    'Storage policies should allow public read and owner-only write/update/delete by object path prefix.'
  from policy_summary ps

  union all
  select 90, 'avatar_metadata_rpcs_exist',
    case when fs.update_avatar_count = 1 and fs.clear_avatar_count = 1 then 'ok' else 'review' end,
    concat('update=', fs.update_avatar_count, ',clear=', fs.clear_avatar_count),
    'Authenticated users should have dedicated RPCs to record and clear avatar metadata.'
  from function_summary fs

  union all
  select 100, 'avatar_metadata_rpcs_security',
    case
      when fs.update_avatar_security_definer
       and fs.clear_avatar_security_definer
       and fs.update_avatar_search_path
       and fs.clear_avatar_search_path
       and fs.update_avatar_auth_uid_pattern
       and fs.clear_avatar_auth_uid_pattern
      then 'ok' else 'review'
    end,
    concat(
      'update_secdef=', coalesce(fs.update_avatar_security_definer, false),
      ',clear_secdef=', coalesce(fs.clear_avatar_security_definer, false),
      ',update_search_path=', coalesce(fs.update_avatar_search_path, false),
      ',clear_search_path=', coalesce(fs.clear_avatar_search_path, false),
      ',auth_uid_patterns=', coalesce(fs.update_avatar_auth_uid_pattern, false), '/', coalesce(fs.clear_avatar_auth_uid_pattern, false)
    ),
    'Avatar metadata RPCs should be security definer, have search_path, and require auth.uid().'
  from function_summary fs

  union all
  select 110, 'avatar_metadata_rpc_privileges',
    case
      when coalesce(bool_and(fp.authenticated_execute) filter (where fp.proname in ('update_my_avatar_path', 'clear_my_avatar_path')), false)
       and not coalesce(bool_or(fp.anon_execute) filter (where fp.proname in ('update_my_avatar_path', 'clear_my_avatar_path')), false)
      then 'ok' else 'review'
    end,
    concat(
      'authenticated=',
      coalesce(bool_and(fp.authenticated_execute) filter (where fp.proname in ('update_my_avatar_path', 'clear_my_avatar_path')), false),
      ',anon=',
      coalesce(bool_or(fp.anon_execute) filter (where fp.proname in ('update_my_avatar_path', 'clear_my_avatar_path')), false)
    ),
    'Avatar metadata RPCs should be executable by authenticated users only.'
  from function_privileges fp

  union all
  select 120, 'comment_rpc_avatar_shape',
    case
      when fs.comment_rpc_count = 1
       and fs.comment_rpc_security_definer
       and fs.comment_rpc_search_path
       and fs.comment_rpc_returns_avatar_path
       and fs.comment_rpc_returns_avatar_updated_at
      then 'ok' else 'review'
    end,
    concat(
      'count=', fs.comment_rpc_count,
      ',secdef=', coalesce(fs.comment_rpc_security_definer, false),
      ',search_path=', coalesce(fs.comment_rpc_search_path, false),
      ',avatar_path=', coalesce(fs.comment_rpc_returns_avatar_path, false),
      ',avatar_updated_at=', coalesce(fs.comment_rpc_returns_avatar_updated_at, false)
    ),
    'Public comment display RPC should include public avatar metadata without exposing private identifiers.'
  from function_summary fs

  union all
  select 130, 'comment_rpc_privileges',
    case
      when coalesce(bool_or(fp.authenticated_execute) filter (where fp.proname = 'get_public_session_comments'), false)
       and coalesce(bool_or(fp.anon_execute) filter (where fp.proname = 'get_public_session_comments'), false)
      then 'ok' else 'review'
    end,
    concat(
      'authenticated=',
      coalesce(bool_or(fp.authenticated_execute) filter (where fp.proname = 'get_public_session_comments'), false),
      ',anon=',
      coalesce(bool_or(fp.anon_execute) filter (where fp.proname = 'get_public_session_comments'), false)
    ),
    'Public comment display should remain callable by anon and authenticated users.'
  from function_privileges fp

  union all
  select 140, 'post_apply_ready_for_avatar_frontend_qa',
    case
      when pc.avatar_path_count = 1
       and pc.avatar_updated_at_count = 1
       and ppc.avatar_path_count = 1
       and ppc.avatar_updated_at_count = 1
       and bs.bucket_count = 1
       and fs.update_avatar_count = 1
       and fs.clear_avatar_count = 1
       and fs.comment_rpc_returns_avatar_path
       and fs.comment_rpc_returns_avatar_updated_at
      then 'ok' else 'review'
    end,
    (
      pc.avatar_path_count = 1
      and pc.avatar_updated_at_count = 1
      and ppc.avatar_path_count = 1
      and ppc.avatar_updated_at_count = 1
      and bs.bucket_count = 1
      and fs.update_avatar_count = 1
      and fs.clear_avatar_count = 1
      and fs.comment_rpc_returns_avatar_path
      and fs.comment_rpc_returns_avatar_updated_at
    )::text,
    'If true, proceed to a separate frontend/avatar UI QA gate.'
  from profiles_columns pc
  cross join public_profiles_columns ppc
  cross join bucket_summary bs
  cross join function_summary fs
)
select
  check_name,
  status,
  result_value,
  note
from output_rows
order by sort_order;
