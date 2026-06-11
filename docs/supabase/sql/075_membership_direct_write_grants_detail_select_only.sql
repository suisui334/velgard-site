-- 075_membership_direct_write_grants_detail_select_only.sql
-- SELECT ONLY / NO MUTATION
--
-- Purpose:
-- - Follow up 074 membership access control inventory.
-- - Identify the two direct write grants reported by
--   direct_write_grants_current_summary.
-- - Classify whether they are app-table web writes that must be closed before
--   membership gates, expected exceptions, or non-app surfaces.
--
-- Safety:
-- - SELECT-only.
-- - Do not return row contents, concrete user ids, emails, session ids, full
--   URLs, project refs, tokens, keys, or secrets.

with target_tables(table_schema, table_name, surface_class) as (
  values
    ('public', 'profiles', 'core_profile'),
    ('public', 'user_roles', 'core_role'),
    ('public', 'profile_roles', 'core_role'),
    ('public', 'roles', 'core_role'),
    ('public', 'sessions', 'session_post'),
    ('public', 'session_comments', 'comment_application'),
    ('public', 'session_applications', 'comment_application'),
    ('public', 'player_characters', 'player_character'),
    ('public', 'template_presets', 'template'),
    ('public', 'user_notifications', 'notification'),
    ('public', 'activity_events', 'activity'),
    ('public', 'community_memberships', 'membership_future'),
    ('public', 'community_membership_events', 'membership_future'),
    ('storage', 'objects', 'storage'),
    ('storage', 'buckets', 'storage')
),
direct_write_grants as (
  select
    tp.table_schema,
    tp.table_name,
    tp.grantee,
    tp.privilege_type,
    coalesce(tt.surface_class, 'non_tracked_surface') as surface_class,
    case
      when tp.table_schema = 'storage' then true
      else false
    end as is_storage_surface,
    case
      when tp.table_schema = 'public'
       and tp.table_name in (
         'profiles',
         'user_roles',
         'profile_roles',
         'roles',
         'sessions',
         'session_comments',
         'session_applications',
         'player_characters',
         'template_presets',
         'user_notifications',
         'activity_events'
       )
      then true
      else false
    end as is_core_app_surface
  from information_schema.table_privileges tp
  left join target_tables tt
    on tt.table_schema = tp.table_schema
   and tt.table_name = tp.table_name
  where tp.grantee in ('anon', 'authenticated')
    and tp.privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
    and (
      tp.table_schema = 'public'
      or tp.table_schema = 'storage'
    )
),
classified_grants as (
  select
    *,
    case
      when is_core_app_surface then 'review_app_table_write'
      when is_storage_surface then 'ok_expected_exception'
      when table_schema <> 'public' then 'info_non_app_surface'
      else 'block_before_membership_gate'
    end as grant_classification
  from direct_write_grants
),
summary_counts as (
  select
    count(*) as direct_write_grant_count,
    count(*) filter (where grant_classification = 'review_app_table_write') as app_table_write_count,
    count(*) filter (where grant_classification = 'ok_expected_exception') as expected_exception_count,
    count(*) filter (where grant_classification = 'block_before_membership_gate') as block_before_membership_gate_count,
    count(*) filter (where grant_classification = 'info_non_app_surface') as non_app_surface_count
  from classified_grants
),
summary_rows as (
  select
    10 as sort_order,
    'membership_direct_write_grants_summary'::text as check_name,
    case
      when app_table_write_count = 0 and block_before_membership_gate_count = 0 then 'ok'
      else 'review'
    end as status,
    concat(
      'direct_write_grants=', direct_write_grant_count,
      ',app_table_write=', app_table_write_count,
      ',expected_exception=', expected_exception_count,
      ',block_before_membership_gate=', block_before_membership_gate_count,
      ',non_app_surface=', non_app_surface_count
    ) as result_value,
    'Count-only follow-up for 074 direct_write_grants=2. Review nonzero app table or block-before-gate counts before membership schema apply.'::text as note
  from summary_counts

  union all
  select
    20,
    'membership_direct_write_grants_next_step',
    case
      when app_table_write_count > 0 or block_before_membership_gate_count > 0 then 'review'
      else 'ok'
    end,
    case
      when app_table_write_count > 0 or block_before_membership_gate_count > 0 then 'review_before_membership_apply'
      else 'safe_to_continue_membership_schema_design'
    end,
    'If only expected exceptions are present, continue membership schema/helper design. If app table writes exist, prepare a separate revoke review gate first.'
  from summary_counts
),
detail_rows as (
  select
    100 + row_number() over (
      order by
        case
          when grant_classification = 'block_before_membership_gate' then 0
          when grant_classification = 'review_app_table_write' then 1
          when grant_classification = 'ok_expected_exception' then 2
          else 3
        end,
        table_schema,
        table_name,
        grantee,
        privilege_type
    ) as sort_order,
    'membership_direct_write_grant_detail_' || lpad(row_number() over (
      order by
        case
          when grant_classification = 'block_before_membership_gate' then 0
          when grant_classification = 'review_app_table_write' then 1
          when grant_classification = 'ok_expected_exception' then 2
          else 3
        end,
        table_schema,
        table_name,
        grantee,
        privilege_type
    )::text, 3, '0') as check_name,
    case
      when grant_classification in ('review_app_table_write', 'block_before_membership_gate') then 'review'
      else 'info'
    end as status,
    concat(table_schema, '.', table_name, ':', grantee, ':', privilege_type) as result_value,
    concat(
      'classification=', grant_classification,
      ',surface=', surface_class,
      ',core_app_surface=', is_core_app_surface,
      ',storage_surface=', is_storage_surface
    ) as note
  from classified_grants
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
) rows
order by sort_order, check_name;
