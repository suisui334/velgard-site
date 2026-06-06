-- 035_prelaunch_db_only_cleanup_apply_draft.sql
-- M-14E-18H prelaunch DB-only cleanup APPLY draft.
--
-- DO NOT RUN.
-- NOT EXECUTED.
-- USER SQL EDITOR APPROVAL REQUIRED.
--
-- This draft is for a future independent SQL apply gate only.
-- Do not execute it until 034_prelaunch_db_only_cleanup_confirm_select_only.sql
-- has been run immediately beforehand and reviewed.
--
-- Scope:
-- - Delete only Supabase rows that look like QA/test/renkei-kakunin cleanup
--   candidates and have no Discord external identifiers.
-- - Do not delete Discord posts.
-- - Do not target rows with discord_message_id, discord_channel_id,
--   discord_thread_id, or discord_post_url.
-- - Do not target static JSON fixture rows.
--
-- Important:
-- - 032 inventory observed 21 DB-only cleanup candidates.
-- - 034 must be rerun before apply; if the 034 count differs, update
--   v_expected_candidate_count after review or do not run this draft.
-- - This direct DELETE is guarded by candidate count, external identifier,
--   QA-like title, and FK cascade checks.
-- - Existing delete_session_post(text) is a per-session user-context RPC and
--   is not a practical bulk SQL Editor cleanup path because auth.uid() is not
--   the same as a logged-in GM/admin browser session in SQL Editor.
-- - Do not write row ids, Discord ids, post URLs, user ids, emails, tokens,
--   secrets, or external target values here.

begin;

do $$
declare
  -- Review and adjust only after running 034 immediately before this apply.
  v_expected_candidate_count integer := 21;
  v_candidate_count integer;
  v_external_identifier_count integer;
  v_non_qa_count integer;
  v_fk_cascade_count integer;
  v_deleted_count integer;
begin
  with candidate_rows as (
    select
      s.id,
      (
        coalesce(s.title, '') ilike '%qa%'
        or coalesce(s.title, '') ilike '%test%'
        or coalesce(s.title, '') like '%QA%'
        or coalesce(s.title, '') like '%TEST%'
        or coalesce(s.title, '') like '%テスト%'
        or coalesce(s.title, '') like '%連携確認%'
      ) as is_qa_like,
      (
        nullif(btrim(coalesce(s.discord_message_id, '')), '') is not null
        or nullif(btrim(coalesce(s.discord_channel_id, '')), '') is not null
        or nullif(btrim(coalesce(s.discord_thread_id, '')), '') is not null
        or nullif(btrim(coalesce(s.discord_post_url, '')), '') is not null
      ) as has_any_external_identifier
    from public.sessions s
    where
      (
        coalesce(s.title, '') ilike '%qa%'
        or coalesce(s.title, '') ilike '%test%'
        or coalesce(s.title, '') like '%QA%'
        or coalesce(s.title, '') like '%TEST%'
        or coalesce(s.title, '') like '%テスト%'
        or coalesce(s.title, '') like '%連携確認%'
      )
      and nullif(btrim(coalesce(s.discord_message_id, '')), '') is null
      and nullif(btrim(coalesce(s.discord_channel_id, '')), '') is null
      and nullif(btrim(coalesce(s.discord_thread_id, '')), '') is null
      and nullif(btrim(coalesce(s.discord_post_url, '')), '') is null
  )
  select
    count(*),
    count(*) filter (where has_any_external_identifier),
    count(*) filter (where not is_qa_like)
  into
    v_candidate_count,
    v_external_identifier_count,
    v_non_qa_count
  from candidate_rows;

  if v_candidate_count <> v_expected_candidate_count then
    raise exception 'prelaunch_cleanup_candidate_count_mismatch' using errcode = 'P0001';
  end if;

  if v_candidate_count <= 0 then
    raise exception 'prelaunch_cleanup_candidate_count_zero' using errcode = 'P0001';
  end if;

  if v_external_identifier_count <> 0 then
    raise exception 'prelaunch_cleanup_external_identifier_detected' using errcode = 'P0001';
  end if;

  if v_non_qa_count <> 0 then
    raise exception 'prelaunch_cleanup_non_qa_candidate_detected' using errcode = 'P0001';
  end if;

  select count(*)
  into v_fk_cascade_count
  from pg_constraint con
  join pg_class rel
    on rel.oid = con.conrelid
  join pg_namespace n
    on n.oid = rel.relnamespace
  where con.contype = 'f'
    and n.nspname = 'public'
    and rel.relname in ('session_applications', 'session_comments')
    and con.confrelid = to_regclass('public.sessions')
    and con.confdeltype = 'c';

  if v_fk_cascade_count < 2 then
    raise exception 'prelaunch_cleanup_fk_cascade_not_confirmed' using errcode = 'P0001';
  end if;

  with candidate_rows as (
    select s.id
    from public.sessions s
    where
      (
        coalesce(s.title, '') ilike '%qa%'
        or coalesce(s.title, '') ilike '%test%'
        or coalesce(s.title, '') like '%QA%'
        or coalesce(s.title, '') like '%TEST%'
        or coalesce(s.title, '') like '%テスト%'
        or coalesce(s.title, '') like '%連携確認%'
      )
      and nullif(btrim(coalesce(s.discord_message_id, '')), '') is null
      and nullif(btrim(coalesce(s.discord_channel_id, '')), '') is null
      and nullif(btrim(coalesce(s.discord_thread_id, '')), '') is null
      and nullif(btrim(coalesce(s.discord_post_url, '')), '') is null
  ),
  deleted_rows as (
    delete from public.sessions s
    using candidate_rows c
    where s.id = c.id
    returning 1
  )
  select count(*)
  into v_deleted_count
  from deleted_rows;

  if v_deleted_count <> v_expected_candidate_count then
    raise exception 'prelaunch_cleanup_deleted_count_mismatch' using errcode = 'P0001';
  end if;
end;
$$;

commit;
