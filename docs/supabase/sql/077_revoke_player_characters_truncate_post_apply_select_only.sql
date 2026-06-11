-- 077_revoke_player_characters_truncate_post_apply_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Confirm the separately approved 076 player character TRUNCATE revoke.
-- - Verify public.player_characters still exists.
-- - Verify public, anon, and authenticated no longer have direct TRUNCATE on
--   public.player_characters.
-- - Verify direct INSERT/UPDATE/DELETE grants were not introduced for the
--   same app table.
--
-- Safety:
-- - SELECT-only.
-- - Do not return row contents, concrete user ids, emails, session ids,
--   activity ids, notification ids, full URLs, project refs, tokens, keys, or
--   secrets.

with target_table as (
  select
    to_regclass('public.player_characters') as table_oid
),
target_write_grants as (
  select
    tp.table_schema,
    tp.table_name,
    tp.grantee,
    tp.privilege_type
  from information_schema.table_privileges tp
  where tp.table_schema = 'public'
    and tp.table_name = 'player_characters'
    and tp.grantee in ('PUBLIC', 'anon', 'authenticated')
    and tp.privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
),
summary_counts as (
  select
    (select table_oid is not null from target_table) as target_exists,
    count(*) filter (where grantee = 'PUBLIC' and privilege_type = 'TRUNCATE') as public_truncate_count,
    count(*) filter (where grantee = 'anon' and privilege_type = 'TRUNCATE') as anon_truncate_count,
    count(*) filter (where grantee = 'authenticated' and privilege_type = 'TRUNCATE') as authenticated_truncate_count,
    count(*) filter (where privilege_type = 'TRUNCATE') as truncate_grant_count,
    count(*) filter (where privilege_type in ('INSERT', 'UPDATE', 'DELETE')) as non_truncate_write_count,
    count(*) as direct_write_grant_count
  from target_write_grants
),
detail_rows as (
  select
    100 + row_number() over (order by grantee, privilege_type) as sort_order,
    'player_characters_direct_write_detail_' || lpad((row_number() over (order by grantee, privilege_type))::text, 3, '0') as check_name,
    'review'::text as status,
    concat(table_schema, '.', table_name, ':', grantee, ':', privilege_type) as result_value,
    'Any listed grant is a direct app-table write privilege that should be reviewed before membership gate work continues.'::text as note
  from target_write_grants
),
summary_rows as (
  select
    10 as sort_order,
    'player_characters_table_exists'::text as check_name,
    case when target_exists then 'ok' else 'review' end as status,
    target_exists::text as result_value,
    'Expected public.player_characters to remain present after 076.'::text as note
  from summary_counts

  union all
  select
    20,
    'player_characters_truncate_grants_closed',
    case
      when public_truncate_count = 0
       and anon_truncate_count = 0
       and authenticated_truncate_count = 0
       and truncate_grant_count = 0
      then 'ok'
      else 'review'
    end,
    concat(
      'public=', public_truncate_count,
      ',anon=', anon_truncate_count,
      ',authenticated=', authenticated_truncate_count,
      ',total=', truncate_grant_count
    ),
    'After 076, public/anon/authenticated should have zero direct TRUNCATE grants on public.player_characters.'
  from summary_counts

  union all
  select
    30,
    'player_characters_non_truncate_direct_write_grants',
    case when non_truncate_write_count = 0 then 'ok' else 'review' end,
    non_truncate_write_count::text,
    'INSERT/UPDATE/DELETE direct grants on this app table should not be introduced by the TRUNCATE revoke gate.'
  from summary_counts

  union all
  select
    40,
    'storage_expected_exceptions_out_of_scope',
    'info',
    'not_checked_by_077',
    '075 classified Storage write grants as expected exceptions. 076/077 only target public.player_characters TRUNCATE.'

  union all
  select
    50,
    'post_apply_ready_for_membership_schema_design',
    case
      when target_exists
       and truncate_grant_count = 0
       and non_truncate_write_count = 0
      then 'ok'
      else 'review'
    end,
    case
      when target_exists
       and truncate_grant_count = 0
       and non_truncate_write_count = 0
      then 'true'
      else 'false'
    end,
    'If true, the player character direct TRUNCATE grants are closed and membership schema/helper design can proceed separately.'
  from summary_counts
)
select
  check_name,
  status,
  result_value,
  note
from (
  select sort_order, check_name, status, result_value, note from summary_rows
  union all
  select sort_order, check_name, status, result_value, note from detail_rows
) combined_rows
order by sort_order, check_name;
