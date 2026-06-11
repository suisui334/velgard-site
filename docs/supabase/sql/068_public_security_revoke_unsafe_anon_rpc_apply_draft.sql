-- 068_public_security_revoke_unsafe_anon_rpc_apply_draft.sql
-- DO NOT RUN / NOT EXECUTED / USER SQL EDITOR APPROVAL REQUIRED
--
-- Purpose:
-- - Close P0 candidate web-client EXECUTE exposure found by the 067 public
--   security detail audit.
-- - Target only public.rls_auto_enable() and public.set_updated_at().
-- - These functions are helper/trigger-style functions and should not be
--   directly executable by anon or authenticated web-client roles.
--
-- Scope:
-- - Revoke EXECUTE from public, anon, and authenticated for:
--   - public.rls_auto_enable()
--   - public.set_updated_at()
--
-- Review notes:
-- - public.set_updated_at() is used by table triggers; trigger execution does
--   not require web-client EXECUTE grants.
-- - public.rls_auto_enable() is an internal/schema helper and should not be a
--   public web-client RPC.
-- - This draft does not change function bodies, triggers, tables, RLS policies,
--   Storage policies, or any read RPCs.
-- - get_public_session_application_counts(text), security definer search_path
--   cleanup, Auth/Dashboard hardening, and comment/application cooldown or URL
--   guards remain separate P1/P0 follow-up gates.
--
-- Safety:
-- - No DROP, CREATE, ALTER, UPDATE, DELETE, INSERT, TRUNCATE, or CASCADE.
-- - No function body replacement.
-- - No real user id, email, token, URL, project ref, Discord id, or secret.

begin;

revoke execute on function public.rls_auto_enable() from public;
revoke execute on function public.rls_auto_enable() from anon;
revoke execute on function public.rls_auto_enable() from authenticated;

revoke execute on function public.set_updated_at() from public;
revoke execute on function public.set_updated_at() from anon;
revoke execute on function public.set_updated_at() from authenticated;

commit;
