-- 033_prelaunch_session_cleanup_apply_draft.sql
-- M-14E-18E prelaunch session cleanup procedure draft.
--
-- DO NOT RUN.
-- NOT EXECUTED.
-- USER APPROVAL REQUIRED.
--
-- This file intentionally contains no executable cleanup operation.
-- It is a review checklist for a future cleanup gate.
--
-- Important boundaries:
-- - SQL alone cannot delete Discord posts.
-- - Do not mix DB cleanup targets with Discord cleanup targets.
-- - Do not remove Supabase rows that still need Discord-side cleanup unless
--   a reviewed repair/resync/manual procedure exists.
-- - Static JSON data is not removed by DB cleanup. Retire or shrink
--   data/sessions.json in a separate frontend/data review.
-- - Old test-webhook Discord remnants may require Discord-side manual cleanup.
-- - Do not write credential values, auth tokens, project identifiers, row data,
--   Discord ids, post URLs, or external target values here.

-- This harmless SELECT documents the intended future gate steps if the file is
-- accidentally opened in SQL Editor. It does not modify DB state.

select
  'prelaunch_cleanup_apply_draft' as section,
  'not_executable' as status,
  'This draft contains no executable cleanup SQL. Use it only as a reviewed procedure checklist.' as result_value
union all
select
  'step_1_inventory',
  'manual_gate_required',
  'Run the SELECT-only inventory draft and classify rows without exposing raw ids or external ids.'
union all
select
  'step_2_static_json_retirement',
  'manual_gate_required',
  'Decide whether static fixture data remains needed. DB cleanup will not remove static JSON rows.'
union all
select
  'step_3_production_posted_supabase',
  'manual_gate_required',
  'Use reviewed app/Edge Function delete sync for production-webhook posted Supabase rows.'
union all
select
  'step_4_unposted_supabase',
  'manual_gate_required',
  'Use reviewed DB-only delete path for unposted Supabase rows after manual classification.'
union all
select
  'step_5_old_test_or_discord_only',
  'manual_gate_required',
  'Handle old test-webhook or Discord-only remnants on the Discord side or via a separately reviewed repair path.'
union all
select
  'step_6_post_cleanup_readback',
  'manual_gate_required',
  'Recheck calendar, session-detail, mypage/session-post management, and GM/admin sync panel after cleanup.';
