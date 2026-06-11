-- 076_revoke_player_characters_truncate_apply_draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
--
-- Purpose:
-- - Close the direct TRUNCATE grants found by the 075 membership access
--   control inventory follow-up.
-- - Target only public.player_characters TRUNCATE privileges exposed to
--   web-client roles.
--
-- Scope:
-- - Revoke TRUNCATE on public.player_characters from public, anon, and
--   authenticated.
--
-- Review notes:
-- - The 075 SELECT-only diagnostic classified Storage direct write grants as
--   expected exceptions and found two app-table review grants:
--   public.player_characters:anon:TRUNCATE and
--   public.player_characters:authenticated:TRUNCATE.
-- - TRUNCATE is not needed by the web client for player character features.
-- - This draft does not change INSERT, UPDATE, DELETE, SELECT, table
--   definitions, RLS policies, RPCs, Storage grants, membership schema, or
--   approved-member gates.
--
-- Safety:
-- - No DROP, CREATE, ALTER, UPDATE, DELETE, INSERT, CASCADE, table definition
--   change, function replacement, policy change, or Storage policy change.
-- - No real user id, email, token, URL, project ref, Discord id, or secret.

revoke truncate on table public.player_characters from public;
revoke truncate on table public.player_characters from anon;
revoke truncate on table public.player_characters from authenticated;
