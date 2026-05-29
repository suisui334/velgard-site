-- Supabase Step 5 RLS test queries draft
-- Purpose:
--   Prepare manual RLS verification queries after 005_rls_test_seed_draft.sql.
--
-- DRAFT ONLY:
--   Do not run against production.
--   Do not paste Project URL, API keys, service role keys, JWT secrets,
--   DB passwords, real emails, real Discord IDs, webhook URLs, or bot tokens.
--
-- Important:
--   Supabase SQL Editor commonly runs with a powerful database role and can bypass RLS.
--   SQL Editor is useful for structure checks, function definitions, grants, and views.
--   Final RLS behavior should be verified through Supabase client / API / Auth context.
--
-- Placeholder policy:
--   Replace UUID placeholders inside SQL Editor only.
--   Do not commit a copy after replacement.

-- ============================================================
-- 1. Structure checks after seed
-- ============================================================

select
  id,
  status,
  visibility,
  public.can_apply_to_session(id) as can_apply
from public.sessions
where id like 'rls-test-%'
order by date, id;

select
  *
from public.public_profiles
where id in (
  '<PLAYER_A_ID>'::uuid,
  '<PLAYER_B_ID>'::uuid,
  '<GM_A_ID>'::uuid,
  '<GM_B_ID>'::uuid,
  '<ADMIN_ID>'::uuid
)
order by display_name;

select
  column_name
from information_schema.columns
where table_schema = 'public'
  and table_name = 'public_profiles'
order by ordinal_position;

select
  'public_profiles_no_discord_user_id' as check_name,
  case
    when not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'public_profiles'
        and column_name = 'discord_user_id'
    )
    then 'ok'
    else 'ng'
  end as result;

-- Public count RPC should return only public sessions.
select *
from public.get_public_session_application_counts(null)
where session_id like 'rls-test-%'
order by session_id;

-- Private / hidden target IDs should return no rows from public count RPC.
select *
from public.get_public_session_application_counts('rls-test-private-recruiting');

select *
from public.get_public_session_application_counts('rls-test-hidden-recruiting');

-- Public comment RPC output should not expose internal user_id or discord_user_id.
select *
from public.get_public_session_comments('rls-test-public-recruiting')
limit 0;

-- ============================================================
-- 2. Optional SQL Editor role simulation notes
-- ============================================================
-- The following blocks are drafts for cautious manual testing.
-- They may require adjustment in Supabase because auth.uid() depends on request JWT claims.
-- Treat these as supplemental checks, not final proof.
--
-- Suggested pattern:
--   begin;
--   set local role authenticated;
--   select set_config('request.jwt.claim.sub', '<PLAYER_A_ID>', true);
--   select set_config('request.jwt.claim.role', 'authenticated', true);
--   ...test query...
--   rollback;
--
-- If any block requires disabling RLS, stop. Do not proceed.

-- ============================================================
-- 3. anon checks - draft
-- ============================================================
-- Expected:
--   public session read: success
--   private / hidden session read: no rows or denied
--   user_roles read: denied/no rows
--   public profile view: id/display_name only
--   create_application_comment: denied

-- begin;
-- set local role anon;
--
-- select id, visibility, status
-- from public.sessions
-- where id = 'rls-test-public-recruiting';
--
-- select id, visibility, status
-- from public.sessions
-- where id in ('rls-test-private-recruiting', 'rls-test-hidden-recruiting');
--
-- select *
-- from public.user_roles;
--
-- select *
-- from public.public_profiles;
--
-- select *
-- from public.get_public_session_comments('rls-test-public-recruiting');
--
-- select public.create_application_comment(
--   'rls-test-public-recruiting',
--   'This anon application attempt should fail.'
-- );
--
-- rollback;

-- ============================================================
-- 4. player A checks - draft
-- ============================================================
-- Expected:
--   recruiting / tentative application: success
--   full / closed / finished / canceled application: failure
--   private / hidden application by unrelated player: failure
--   repeated comments: comments can increase, application remains one row
--   set_application_status: failure
--   close_session: failure

-- begin;
-- set local role authenticated;
-- select set_config('request.jwt.claim.sub', '<PLAYER_A_ID>', true);
-- select set_config('request.jwt.claim.role', 'authenticated', true);
--
-- select public.create_application_comment(
--   'rls-test-public-recruiting',
--   'Player A application comment draft.'
-- ) as player_a_comment_1;
--
-- select public.create_application_comment(
--   'rls-test-public-recruiting',
--   'Player A additional comment draft. Application count should not increase.'
-- ) as player_a_comment_2;
--
-- select public.create_application_comment(
--   'rls-test-public-tentative',
--   'Player A tentative application comment draft.'
-- ) as player_a_tentative_comment;
--
-- -- These should fail.
-- select public.create_application_comment('rls-test-public-full', 'Should fail: full.');
-- select public.create_application_comment('rls-test-public-closed', 'Should fail: closed.');
-- select public.create_application_comment('rls-test-public-finished', 'Should fail: finished.');
-- select public.create_application_comment('rls-test-public-canceled', 'Should fail: canceled.');
-- select public.create_application_comment('rls-test-private-recruiting', 'Should fail: private.');
-- select public.create_application_comment('rls-test-hidden-recruiting', 'Should fail: hidden.');
--
-- -- Replace placeholder IDs with values observed inside SQL Editor only.
-- select public.edit_comment('<PLAYER_A_COMMENT_ID>'::uuid, 'Player A edited comment draft.');
-- select public.edit_comment('<PLAYER_B_COMMENT_ID>'::uuid, 'Should fail: editing another player comment.');
--
-- select public.cancel_application('rls-test-public-recruiting');
--
-- -- These should fail for a player.
-- select public.set_application_status('<PLAYER_A_APPLICATION_ID>'::uuid, 'accepted');
-- select public.close_session('rls-test-public-recruiting');
--
-- select *
-- from public.get_public_session_application_counts('rls-test-public-recruiting');
--
-- rollback;

-- ============================================================
-- 5. player B setup/checks - draft
-- ============================================================
-- Use player B to create another application comment, then confirm player A cannot edit it.
-- Keep actual generated UUIDs inside SQL Editor only.

-- begin;
-- set local role authenticated;
-- select set_config('request.jwt.claim.sub', '<PLAYER_B_ID>', true);
-- select set_config('request.jwt.claim.role', 'authenticated', true);
--
-- select public.create_application_comment(
--   'rls-test-public-recruiting',
--   'Player B application comment draft.'
-- ) as player_b_comment;
--
-- rollback;

-- ============================================================
-- 6. GM A checks - draft
-- ============================================================
-- Expected:
--   GM A can manage applications for GM A sessions.
--   GM A cannot manage other GM sessions.
--   GM A can close own recruiting/full sessions.
--   GM A cannot close finished/canceled sessions.

-- begin;
-- set local role authenticated;
-- select set_config('request.jwt.claim.sub', '<GM_A_ID>', true);
-- select set_config('request.jwt.claim.role', 'authenticated', true);
--
-- select public.set_application_status('<PLAYER_A_APPLICATION_ID>'::uuid, 'accepted');
--
-- -- Should fail if the application belongs to rls-test-other-gm-recruiting.
-- select public.set_application_status('<OTHER_GM_SESSION_APPLICATION_ID>'::uuid, 'accepted');
--
-- select public.close_session('rls-test-public-recruiting');
--
-- -- These should fail.
-- select public.close_session('rls-test-other-gm-recruiting');
-- select public.close_session('rls-test-public-finished');
-- select public.close_session('rls-test-public-canceled');
--
-- rollback;

-- ============================================================
-- 7. Admin checks - draft
-- ============================================================
-- Expected:
--   admin can inspect/manage all prototype rows.
--   Still do not use service role key in frontend.

-- begin;
-- set local role authenticated;
-- select set_config('request.jwt.claim.sub', '<ADMIN_ID>', true);
-- select set_config('request.jwt.claim.role', 'authenticated', true);
--
-- select *
-- from public.sessions
-- where id like 'rls-test-%'
-- order by id;
--
-- select *
-- from public.session_applications
-- where session_id like 'rls-test-%'
-- order by session_id, created_at;
--
-- rollback;

-- ============================================================
-- 8. Final manual review queries
-- ============================================================

select
  schemaname,
  tablename,
  policyname,
  roles,
  cmd
from pg_catalog.pg_policies
where schemaname = 'public'
  and tablename in (
    'profiles',
    'user_roles',
    'sessions',
    'session_comments',
    'session_applications'
  )
order by tablename, policyname;

select
  routine_schema,
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name in (
    'get_public_session_application_counts',
    'get_public_session_comments',
    'create_application_comment',
    'edit_comment',
    'cancel_application',
    'set_application_status',
    'close_session'
  )
  and grantee in ('anon', 'authenticated', 'public')
order by routine_name, grantee, privilege_type;
