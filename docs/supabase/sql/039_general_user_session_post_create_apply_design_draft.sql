-- DO NOT RUN / NOT EXECUTABLE APPLY / REVIEW REQUIRED
-- Purpose: design notes for allowing logged-in non-GM users to make session posts.
-- This file intentionally does not contain a complete replacement function.
-- A full apply draft must be generated from the current DB function body after
-- 038 preflight confirms the live definition.
--
-- Do not run this file in SQL Editor.
-- Do not add real IDs, tokens, URLs, or user data.

-- Current finding from repo-side draft review:
-- - public.create_session_post grants EXECUTE to authenticated.
-- - public.create_session_post is security definer with search_path set.
-- - the body still raises gm_or_admin_required unless has_role('gm') or is_admin().
-- - the body only accepts initial status draft / tentative / recruiting.
--
-- Desired policy candidate:
-- - keep auth.uid() required.
-- - allow any authenticated user to make a new session post.
-- - set gm_user_id to auth.uid() exactly as the current function does.
-- - keep update/delete/close/edit permissions limited to owner GM context or admin.
-- - keep initial status limited to draft / tentative / recruiting unless a separate
--   reviewed policy decides that past-session creation is allowed.
-- - keep public draft rejection.
-- - keep discord sync status pending only for public tentative/recruiting makes.
--
-- Required full apply draft shape for the next gate:
-- 1. drop/recreate public.create_session_post with the exact live signature.
-- 2. remove only the gm/admin role gate from the make path.
-- 3. keep login_required, input validation, gm_user_id assignment, grants, and revokes.
-- 4. do not alter update_session_post/delete_session_post.
-- 5. do not change RLS policies unless preflight proves function-owner behavior is insufficient.
--
-- Apply gate stop conditions:
-- - 038 result does not match this finding.
-- - live create_session_post body differs in a way that cannot be safely patched.
-- - authenticated EXECUTE is missing.
-- - anon/PUBLIC EXECUTE is present unexpectedly.
-- - a direct table policy change is needed.
-- - any secret, token, URL, or real ID appears in the SQL.

select
  'design_only_not_executable' as status,
  'prepare full create_session_post replacement after 038 preflight' as next_step;
