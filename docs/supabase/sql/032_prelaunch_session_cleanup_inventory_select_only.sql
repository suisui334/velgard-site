-- 032_prelaunch_session_cleanup_inventory_select_only.sql
-- M-14E-18E prelaunch session cleanup inventory.
--
-- SELECT ONLY.
-- DO NOT APPLY.
-- NO DELETE.
-- NOT EXECUTED.
--
-- Purpose:
-- - Classify prelaunch session cleanup candidates without exposing row ids,
--   Discord ids, post URLs, user ids, email addresses, tokens, or secrets.
-- - Return aggregate boolean/status/count/result_value style rows only.
--
-- Safety:
-- - No CREATE / ALTER / DROP / INSERT / UPDATE / DELETE / GRANT / REVOKE /
--   COMMENT / TRUNCATE / CALL / DO statements.
-- - This query does not delete DB rows and does not delete Discord posts.
-- - Run only in a separate SELECT-only inventory gate.

with session_rows as (
  select
    coalesce(nullif(btrim(s.visibility), ''), '(null)') as visibility_value,
    coalesce(nullif(btrim(s.status), ''), '(null)') as status_value,
    coalesce(nullif(btrim(s.discord_sync_status), ''), '(null)') as discord_sync_status_value,
    coalesce(nullif(btrim(s.discord_last_action), ''), '(null)') as discord_last_action_value,
    nullif(btrim(coalesce(s.discord_message_id, '')), '') is not null as has_discord_message_id,
    nullif(btrim(coalesce(s.discord_channel_id, '')), '') is not null as has_discord_channel_id,
    nullif(btrim(coalesce(s.discord_thread_id, '')), '') is not null as has_discord_thread_id,
    nullif(btrim(coalesce(s.discord_post_url, '')), '') is not null as has_discord_post_url,
    nullif(btrim(coalesce(s.discord_sync_error, '')), '') is not null as has_discord_sync_error,
    (
      coalesce(s.title, '') ilike '%qa%'
      or coalesce(s.title, '') ilike '%test%'
      or coalesce(s.title, '') like '%QA%'
      or coalesce(s.title, '') like '%TEST%'
      or coalesce(s.title, '') like '%テスト%'
      or coalesce(s.title, '') like '%連携確認%'
    ) as has_qa_like_title
  from public.sessions s
),
summary_rows as (
  select 10 as sort_group, 'sessions' as section, 'total_rows' as check_name,
    'ok' as status, count(*)::text as result_value, count(*)::bigint as count_value,
    'Supabase session rows visible to SQL inventory.' as note
  from session_rows
  union all
  select 11, 'sessions', 'public_visibility_rows', 'ok', count(*)::text, count(*)::bigint,
    'Rows with visibility = public.'
  from session_rows
  where visibility_value = 'public'
  union all
  select 12, 'sessions', 'draft_status_rows', 'ok', count(*)::text, count(*)::bigint,
    'Rows with status = draft.'
  from session_rows
  where status_value = 'draft'
  union all
  select 13, 'sessions', 'hidden_or_private_visibility_rows', 'ok', count(*)::text, count(*)::bigint,
    'Rows with visibility = hidden/private or equivalent.'
  from session_rows
  where visibility_value in ('hidden', 'private')
  union all
  select 14, 'sessions', 'qa_like_title_rows', 'review', count(*)::text, count(*)::bigint,
    'Rows whose title looks like QA/test/renkei-kakunin. Titles are not returned.'
  from session_rows
  where has_qa_like_title
  union all
  select 15, 'discord_columns', 'discord_message_id_saved_rows', 'ok', count(*)::text, count(*)::bigint,
    'Rows with a saved external post identifier. Identifier values are not returned.'
  from session_rows
  where has_discord_message_id
  union all
  select 16, 'discord_columns', 'discord_channel_id_saved_rows', 'ok', count(*)::text, count(*)::bigint,
    'Rows with a saved channel identifier. Identifier values are not returned.'
  from session_rows
  where has_discord_channel_id
  union all
  select 17, 'discord_columns', 'discord_thread_id_saved_rows', 'ok', count(*)::text, count(*)::bigint,
    'Rows with a saved thread identifier. Identifier values are not returned.'
  from session_rows
  where has_discord_thread_id
  union all
  select 18, 'discord_columns', 'discord_post_url_saved_rows', 'ok', count(*)::text, count(*)::bigint,
    'Rows with a saved post URL. URL values are not returned.'
  from session_rows
  where has_discord_post_url
),
status_rows as (
  select 30 as sort_group, 'status_count' as section, status_value as check_name,
    'ok' as status, count(*)::text as result_value, count(*)::bigint as count_value,
    'Aggregate count by public.sessions.status.' as note
  from session_rows
  group by status_value
),
visibility_rows as (
  select 40 as sort_group, 'visibility_count' as section, visibility_value as check_name,
    'ok' as status, count(*)::text as result_value, count(*)::bigint as count_value,
    'Aggregate count by public.sessions.visibility.' as note
  from session_rows
  group by visibility_value
),
discord_status_rows as (
  select 50 as sort_group, 'discord_sync_status_count' as section, discord_sync_status_value as check_name,
    'ok' as status, count(*)::text as result_value, count(*)::bigint as count_value,
    'Aggregate count by discord_sync_status.' as note
  from session_rows
  group by discord_sync_status_value
),
discord_action_rows as (
  select 60 as sort_group, 'discord_last_action_count' as section, discord_last_action_value as check_name,
    'ok' as status, count(*)::text as result_value, count(*)::bigint as count_value,
    'Aggregate count by discord_last_action.' as note
  from session_rows
  group by discord_last_action_value
),
cleanup_candidate_rows as (
  select 80 as sort_group, 'cleanup_candidate' as section, 'production_webhook_posted_supabase_candidate' as check_name,
    'review' as status, count(*)::text as result_value, count(*)::bigint as count_value,
    'Rows that look posted and may be eligible for current auto-delete sync after manual classification.' as note
  from session_rows
  where has_discord_message_id
    and has_discord_channel_id
    and discord_sync_status_value = 'posted'
  union all
  select 81, 'cleanup_candidate', 'unposted_supabase_db_delete_candidate', 'review',
    count(*)::text, count(*)::bigint,
    'Rows without external post identifiers. These may use DB-only delete after manual classification.'
  from session_rows
  where not has_discord_message_id
  union all
  select 82, 'cleanup_candidate', 'possible_old_test_webhook_or_manual_review_candidate', 'review',
    count(*)::text, count(*)::bigint,
    'Rows with external post identifiers but incomplete/failed/QA-like state. Manual ownership review required.'
  from session_rows
  where has_discord_message_id
    and (
      not has_discord_channel_id
      or has_discord_sync_error
      or has_qa_like_title
      or discord_sync_status_value in ('failed', 'pending', 'skipped')
    )
  union all
  select 83, 'cleanup_candidate', 'manual_confirmation_required_total', 'review',
    count(*)::text, count(*)::bigint,
    'Rows that should not be bulk-cleaned without source/ownership confirmation.'
  from session_rows
  where has_qa_like_title
    or has_discord_sync_error
    or (has_discord_message_id and not has_discord_channel_id)
)
select section, check_name, status, result_value, count_value, note
from summary_rows
union all
select section, check_name, status, result_value, count_value, note from status_rows
union all
select section, check_name, status, result_value, count_value, note from visibility_rows
union all
select section, check_name, status, result_value, count_value, note from discord_status_rows
union all
select section, check_name, status, result_value, count_value, note from discord_action_rows
union all
select section, check_name, status, result_value, count_value, note from cleanup_candidate_rows
order by section, check_name;
