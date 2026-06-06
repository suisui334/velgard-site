-- 037_prelaunch_final_session_reset_apply_draft.sql
-- M-14E-18K prelaunch final session reset APPLY draft.
--
-- DO NOT RUN.
-- NOT EXECUTED.
-- USER SQL EDITOR APPROVAL REQUIRED.
-- DISCORD SIDE CLEANUP MUST BE DECIDED FIRST.
--
-- This draft is for a future independent SQL apply gate only.
-- Do not execute it until 036_prelaunch_final_session_reset_confirm_select_only.sql
-- has been run immediately beforehand and reviewed.
--
-- Scope:
-- - Delete the remaining public.sessions rows only after Discord-side cleanup
--   or an explicit manual decision has been made.
-- - DB deletion does not delete Discord posts.
-- - Old test-webhook posts and Discord-only posts cannot be deleted by SQL.
-- - Do not target static JSON fixture rows.
--
-- Important:
-- - The post-cleanup inventory observed 3 remaining Supabase session rows.
-- - 2 rows had Discord external identifiers and need Discord-side cleanup
--   decision before this DB reset.
-- - 1 row had no Discord external identifiers.
-- - This direct DELETE is guarded by remaining count, external-identifier
--   count, no-external count, and FK cascade checks.
-- - Do not write row ids, Discord ids, post URLs, user ids, emails, tokens,
--   secrets, or external target values here.
--
-- Manual safety:
-- - Keep v_discord_side_cleanup_decided as false until the user has explicitly
--   decided how to handle the Discord-side posts.
-- - The draft will raise an error while this value remains false.

begin;

do $$
declare
  -- Set to true only inside a separately approved final reset gate.
  v_discord_side_cleanup_decided boolean := false;

  v_expected_remaining_count integer := 3;
  v_expected_external_identifier_count integer := 2;
  v_expected_no_external_identifier_count integer := 1;

  v_remaining_count integer;
  v_external_identifier_count integer;
  v_no_external_identifier_count integer;
  v_fk_cascade_count integer;
  v_deleted_count integer;
begin
  if not v_discord_side_cleanup_decided then
    raise exception 'prelaunch_final_reset_discord_side_cleanup_not_decided' using errcode = 'P0001';
  end if;

  with classified as (
    select
      s.id,
      (
        nullif(btrim(coalesce(s.discord_message_id, '')), '') is not null
        or nullif(btrim(coalesce(s.discord_channel_id, '')), '') is not null
        or nullif(btrim(coalesce(s.discord_thread_id, '')), '') is not null
        or nullif(btrim(coalesce(s.discord_post_url, '')), '') is not null
      ) as has_any_external_identifier
    from public.sessions s
  )
  select
    count(*),
    count(*) filter (where has_any_external_identifier),
    count(*) filter (where not has_any_external_identifier)
  into
    v_remaining_count,
    v_external_identifier_count,
    v_no_external_identifier_count
  from classified;

  if v_remaining_count <> v_expected_remaining_count then
    raise exception 'prelaunch_final_reset_remaining_count_mismatch' using errcode = 'P0001';
  end if;

  if v_external_identifier_count <> v_expected_external_identifier_count then
    raise exception 'prelaunch_final_reset_external_identifier_count_mismatch' using errcode = 'P0001';
  end if;

  if v_no_external_identifier_count <> v_expected_no_external_identifier_count then
    raise exception 'prelaunch_final_reset_no_external_identifier_count_mismatch' using errcode = 'P0001';
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
    raise exception 'prelaunch_final_reset_fk_cascade_not_confirmed' using errcode = 'P0001';
  end if;

  with deleted_rows as (
    delete from public.sessions s
    where exists (
      select 1
      from public.sessions guard
      where guard.id = s.id
    )
    returning 1
  )
  select count(*)
  into v_deleted_count
  from deleted_rows;

  if v_deleted_count <> v_expected_remaining_count then
    raise exception 'prelaunch_final_reset_deleted_count_mismatch' using errcode = 'P0001';
  end if;
end;
$$;

select
  'final_reset' as section,
  'deleted_count' as check_name,
  'ok' as status,
  '3' as result_value,
  3::bigint as count_value,
  'Final reset deleted the reviewed remaining session rows. No ids or URLs returned.' as note;

commit;
