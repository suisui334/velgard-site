-- 036_prelaunch_final_session_reset_confirm_select_only.sql
-- M-14E-18K prelaunch final session reset confirmation.
--
-- SELECT ONLY.
-- DO NOT DELETE.
-- NO MUTATION.
-- NOT EXECUTED.
--
-- Purpose:
-- - Reconfirm the remaining public.sessions rows before a final prelaunch reset.
-- - Return only aggregate boolean/status/count/result_value style rows.
-- - Do not return session ids, Discord ids, post URLs, user ids, emails,
--   tokens, secrets, or row data.
--
-- Important:
-- - DB deletion does not delete Discord posts.
-- - Rows with Discord external identifiers require Discord-side cleanup or
--   explicit manual decision before the DB final reset.
-- - Old test-webhook or Discord-only posts may need manual Discord cleanup.

with session_rows as (
  select
    coalesce(s.title, '') as title_value,
    coalesce(nullif(btrim(s.visibility), ''), '(null)') as visibility_value,
    coalesce(nullif(btrim(s.status), ''), '(null)') as status_value,
    coalesce(nullif(btrim(s.discord_sync_status), ''), '(null)') as discord_sync_status_value,
    coalesce(nullif(btrim(s.discord_last_action), ''), '(null)') as discord_last_action_value,
    nullif(btrim(coalesce(s.discord_message_id, '')), '') is not null as has_discord_message_id,
    nullif(btrim(coalesce(s.discord_channel_id, '')), '') is not null as has_discord_channel_id,
    nullif(btrim(coalesce(s.discord_thread_id, '')), '') is not null as has_discord_thread_id,
    nullif(btrim(coalesce(s.discord_post_url, '')), '') is not null as has_discord_post_url
  from public.sessions s
),
classified as (
  select
    *,
    (
      title_value ilike '%qa%'
      or title_value ilike '%test%'
      or title_value like '%QA%'
      or title_value like '%TEST%'
      or title_value like '%テスト%'
      or title_value like '%連携確認%'
    ) as is_qa_like,
    (
      has_discord_message_id
      or has_discord_channel_id
      or has_discord_thread_id
      or has_discord_post_url
    ) as has_any_external_identifier
  from session_rows
),
fk_rows as (
  select
    rel.relname as child_table_name,
    con.confdeltype
  from pg_constraint con
  join pg_class rel
    on rel.oid = con.conrelid
  join pg_namespace n
    on n.oid = rel.relnamespace
  where con.contype = 'f'
    and n.nspname = 'public'
    and rel.relname in ('session_applications', 'session_comments')
    and con.confrelid = to_regclass('public.sessions')
),
summary_rows as (
  select 10 as sort_group, 'final_reset' as section, 'remaining_session_count' as check_name,
    case when count(*) = 3 then 'ok' else 'stop' end as status,
    count(*)::text as result_value,
    count(*)::bigint as count_value,
    'Expected 3 remaining Supabase session rows before final reset.' as note
  from classified
  union all
  select 11, 'final_reset', 'external_identifier_rows',
    case when count(*) = 2 then 'review' else 'stop' end,
    count(*)::text,
    count(*)::bigint,
    'Expected 2 rows with Discord external identifiers. Values are not returned.'
  from classified
  where has_any_external_identifier
  union all
  select 12, 'final_reset', 'no_external_identifier_rows',
    case when count(*) = 1 then 'review' else 'stop' end,
    count(*)::text,
    count(*)::bigint,
    'Expected 1 row without Discord external identifiers.'
  from classified
  where not has_any_external_identifier
  union all
  select 13, 'final_reset', 'qa_like_title_rows',
    'review',
    count(*)::text,
    count(*)::bigint,
    'Rows whose title looks like QA/test/renkei-kakunin. Titles are not returned.'
  from classified
  where is_qa_like
  union all
  select 14, 'final_reset', 'non_qa_rows',
    'review',
    count(*)::text,
    count(*)::bigint,
    'Rows that do not match QA/test/renkei-kakunin title pattern.'
  from classified
  where not is_qa_like
  union all
  select 15, 'final_reset', 'discord_side_cleanup_required',
    case when count(*) filter (where has_any_external_identifier) > 0 then 'review' else 'ok' end,
    (count(*) filter (where has_any_external_identifier) > 0)::text,
    count(*) filter (where has_any_external_identifier)::bigint,
    'True means Discord-side cleanup or manual decision is needed before DB reset.'
  from classified
  union all
  select 30, 'fk_check', 'session_applications_sessions_cascade',
    case when count(*) filter (where child_table_name = 'session_applications' and confdeltype = 'c') > 0 then 'ok' else 'stop' end,
    (count(*) filter (where child_table_name = 'session_applications' and confdeltype = 'c') > 0)::text,
    count(*) filter (where child_table_name = 'session_applications' and confdeltype = 'c')::bigint,
    'True when session_applications references sessions with ON DELETE CASCADE.'
  from fk_rows
  union all
  select 31, 'fk_check', 'session_comments_sessions_cascade',
    case when count(*) filter (where child_table_name = 'session_comments' and confdeltype = 'c') > 0 then 'ok' else 'stop' end,
    (count(*) filter (where child_table_name = 'session_comments' and confdeltype = 'c') > 0)::text,
    count(*) filter (where child_table_name = 'session_comments' and confdeltype = 'c')::bigint,
    'True when session_comments references sessions with ON DELETE CASCADE.'
  from fk_rows
),
status_rows as (
  select 100 as sort_group, 'status_count' as section, status_value as check_name,
    'ok' as status,
    count(*)::text as result_value,
    count(*)::bigint as count_value,
    'Aggregate count by public.sessions.status.' as note
  from classified
  group by status_value
),
visibility_rows as (
  select 110 as sort_group, 'visibility_count' as section, visibility_value as check_name,
    'ok' as status,
    count(*)::text as result_value,
    count(*)::bigint as count_value,
    'Aggregate count by public.sessions.visibility.' as note
  from classified
  group by visibility_value
),
sync_status_rows as (
  select 120 as sort_group, 'discord_sync_status_count' as section, discord_sync_status_value as check_name,
    'ok' as status,
    count(*)::text as result_value,
    count(*)::bigint as count_value,
    'Aggregate count by discord_sync_status.' as note
  from classified
  group by discord_sync_status_value
),
last_action_rows as (
  select 130 as sort_group, 'discord_last_action_count' as section, discord_last_action_value as check_name,
    'ok' as status,
    count(*)::text as result_value,
    count(*)::bigint as count_value,
    'Aggregate count by discord_last_action.' as note
  from classified
  group by discord_last_action_value
)
select section, check_name, status, result_value, count_value, note
from summary_rows
union all
select section, check_name, status, result_value, count_value, note from status_rows
union all
select section, check_name, status, result_value, count_value, note from visibility_rows
union all
select section, check_name, status, result_value, count_value, note from sync_status_rows
union all
select section, check_name, status, result_value, count_value, note from last_action_rows
order by section, check_name;
