-- 034_prelaunch_db_only_cleanup_confirm_select_only.sql
-- M-14E-18H prelaunch DB-only cleanup confirmation.
--
-- SELECT ONLY.
-- DO NOT DELETE.
-- NO MUTATION.
-- NOT EXECUTED.
--
-- Purpose:
-- - Reconfirm Supabase DB-only cleanup candidates before any apply gate.
-- - Return only aggregate count/status/result_value rows.
-- - Do not return session ids, Discord ids, post URLs, user ids, emails,
--   tokens, secrets, or row data.
--
-- Candidate definition:
-- - Supabase row in public.sessions.
-- - Title looks like QA/test/renkei-kakunin.
-- - No discord_message_id.
-- - No discord_channel_id.
-- - No discord_thread_id.
-- - No discord_post_url.
--
-- Reference:
-- - 032 inventory observed 21 DB-only cleanup candidates.
-- - Treat this query result as the source of truth immediately before apply.

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
candidate_rows as (
  select *
  from classified
  where is_qa_like
    and not has_any_external_identifier
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
  select 10 as sort_group, 'db_only_cleanup' as section, 'candidate_count' as check_name,
    case when count(*) = 21 then 'ok' else 'review' end as status,
    count(*)::text as result_value,
    count(*)::bigint as count_value,
    'DB-only cleanup candidate count. 032 reference was 21; use this latest count before apply.' as note
  from candidate_rows
  union all
  select 11, 'db_only_cleanup', 'candidate_matches_032_reference',
    case when count(*) = 21 then 'ok' else 'review' end,
    (count(*) = 21)::text,
    count(*)::bigint,
    'True only when current candidate count equals the 032 inventory reference.'
  from candidate_rows
  union all
  select 12, 'db_only_cleanup', 'external_identifier_in_candidate_count',
    case when count(*) = 0 then 'ok' else 'stop' end,
    count(*)::text,
    count(*)::bigint,
    'Must be 0. Candidates must not include external Discord identifiers.'
  from candidate_rows
  where has_any_external_identifier
  union all
  select 13, 'db_only_cleanup', 'non_qa_candidate_count',
    case when count(*) = 0 then 'ok' else 'stop' end,
    count(*)::text,
    count(*)::bigint,
    'Must be 0. Candidates must all match QA/test/renkei-kakunin title pattern.'
  from candidate_rows
  where not is_qa_like
  union all
  select 20, 'excluded', 'discord_identifier_rows',
    'review',
    count(*)::text,
    count(*)::bigint,
    'Rows with any Discord external identifier. Excluded from DB-only cleanup.'
  from classified
  where has_any_external_identifier
  union all
  select 21, 'excluded', 'non_qa_rows',
    'review',
    count(*)::text,
    count(*)::bigint,
    'Rows that do not match QA/test/renkei-kakunin title pattern. Excluded from cleanup draft.'
  from classified
  where not is_qa_like
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
candidate_status_rows as (
  select 100 as sort_group, 'candidate_status_count' as section, status_value as check_name,
    'ok' as status,
    count(*)::text as result_value,
    count(*)::bigint as count_value,
    'Aggregate candidate count by sessions.status.' as note
  from candidate_rows
  group by status_value
),
candidate_visibility_rows as (
  select 110 as sort_group, 'candidate_visibility_count' as section, visibility_value as check_name,
    'ok' as status,
    count(*)::text as result_value,
    count(*)::bigint as count_value,
    'Aggregate candidate count by sessions.visibility.' as note
  from candidate_rows
  group by visibility_value
),
candidate_sync_status_rows as (
  select 120 as sort_group, 'candidate_discord_sync_status_count' as section, discord_sync_status_value as check_name,
    'ok' as status,
    count(*)::text as result_value,
    count(*)::bigint as count_value,
    'Aggregate candidate count by discord_sync_status.' as note
  from candidate_rows
  group by discord_sync_status_value
),
candidate_last_action_rows as (
  select 130 as sort_group, 'candidate_discord_last_action_count' as section, discord_last_action_value as check_name,
    'ok' as status,
    count(*)::text as result_value,
    count(*)::bigint as count_value,
    'Aggregate candidate count by discord_last_action.' as note
  from candidate_rows
  group by discord_last_action_value
)
select section, check_name, status, result_value, count_value, note
from summary_rows
union all
select section, check_name, status, result_value, count_value, note from candidate_status_rows
union all
select section, check_name, status, result_value, count_value, note from candidate_visibility_rows
union all
select section, check_name, status, result_value, count_value, note from candidate_sync_status_rows
union all
select section, check_name, status, result_value, count_value, note from candidate_last_action_rows
order by section, check_name;
