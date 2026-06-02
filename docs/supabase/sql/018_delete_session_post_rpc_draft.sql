-- 018_delete_session_post_rpc_draft.sql
-- M-14D-13B 完全削除 delete_session_post RPC草案
--
-- DRAFT ONLY:
-- - SQL Editorではまだ実行しない。
-- - DB構造変更、RPC作成/置換、GRANT/REVOKE、実データ削除は行わない。
-- - フロントからDBへ直接DELETEしない。完全削除はRPC経由に限定する。
-- - External credential values or connection values must not be written here.
-- - RPC戻り値に email、user_id全文、gm_user_id、Discord credential類を含めない。
--
-- Important:
-- - M-14D-13A時点の soft delete = visibility hidden / status canceled はQA済み。
-- - 今後 hidden / canceled は「中止として残す」操作として扱う。
-- - 削除ボタンは完全削除に変更する。
-- - この草案は preflight のFK/関連テーブル確認結果をレビューするまでAPPLYしない。
-- - SQL Editor apply時は docs/supabase/sql/018_delete_session_post_apply_reviewed.sql
--   を使い、このdraft全文を貼らない。

-- ============================================================
-- SECTION 1: PREFLIGHT NOTE
-- ============================================================

-- SQL Editor preflight must use this dedicated select-only file:
-- docs/supabase/sql/018_delete_session_post_preflight_select_only.sql
--
-- Check before applying:
-- - public.sessions primary key.
-- - public.sessions.id data type.
-- - Foreign keys referencing public.sessions.
-- - ON DELETE action for each related table.
-- - Tables with session_id column.
-- - Application/comment/contact/history table existence.
-- - Existing delete_session_post routine conflict.
-- - Existing helper routines has_role(text), is_admin(), is_session_gm(text).
-- - Existing update_session_post routine privileges.
-- - anon / authenticated / PUBLIC routine privileges.
--
-- Stop and revise this draft if:
-- - public.sessions.id is not text.
-- - public.sessions primary key is not the id used by public routes.
-- - helper routines are missing or no longer match the auth policy.
-- - delete_session_post already exists with an incompatible signature.
-- - related rows use RESTRICT / NO ACTION and must be handled explicitly.
-- - related rows use CASCADE but the product decision is to retain them.
-- - Discord deletion sync must happen atomically before DB deletion.
--
-- M-14D-13B preflight result:
-- - session_applications.session_id references sessions(id) ON DELETE CASCADE.
-- - session_comments.session_id references sessions(id) ON DELETE CASCADE.
-- - Public base tables with a session_id column are session_applications and
--   session_comments only.
-- - Therefore deleting one public.sessions row also deletes its application
--   rows and application comment rows by database constraint.

-- ============================================================
-- SECTION 2: APPLY DRAFT
-- DO NOT RUN UNTIL PREFLIGHT RESULT IS REVIEWED.
-- THIS SECTION CREATES/REPLACES RPC AND CHANGES GRANTS.
-- ============================================================

create or replace function public.delete_session_post(
  p_session_id text
)
returns table (
  deleted_session_id text,
  deleted_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_target_session_id text;
  v_deleted_session_id text;
  v_deleted_at timestamptz := now();
begin
  if v_actor is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  v_target_session_id := nullif(trim(coalesce(p_session_id, '')), '');
  if v_target_session_id is null then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  select s.id
  into v_deleted_session_id
  from public.sessions as s
  where s.id = v_target_session_id
  for update;

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  if not (
    coalesce(public.is_admin(), false)
    or coalesce(public.is_session_gm(v_deleted_session_id), false)
  ) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  -- Full deletion policy:
  -- - Static JSON sessions are outside public.sessions and cannot be targeted here.
  -- - M-14D-13B preflight confirmed that session_applications.session_id and
  --   session_comments.session_id both use ON DELETE CASCADE.
  -- - This draft relies on those constraints, so application rows and application
  --   comment rows for the target session are removed together with the session.
  -- - The UI confirmation must clearly say that applications and comments are
  --   deleted as well.
  -- - This RPC does not send Discord messages or call Edge Functions.
  delete from public.sessions as s
  where s.id = v_target_session_id;

  deleted_session_id := v_deleted_session_id;
  deleted_at := v_deleted_at;
  return next;
end;
$$;

comment on function public.delete_session_post(text) is
  'GM/admin用セッション依頼書完全削除RPC草案。p_session_idはpublic.sessions.idに合わせてtext。戻り値に内部user id、email、Discord credential類を含めない。';

revoke execute on function public.delete_session_post(text) from public;
revoke execute on function public.delete_session_post(text) from anon;
grant execute on function public.delete_session_post(text) to authenticated;

-- ============================================================
-- SECTION 3: POST-APPLY CHECK
-- RUN ONLY AFTER SECTION 2 HAS BEEN REVIEWED AND APPLIED.
-- ============================================================

select
  p.oid::regprocedure as signature,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'delete_session_post'
order by p.oid::regprocedure::text;

select
  routine_name,
  specific_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and routine_name = 'delete_session_post'
order by specific_name, grantee, privilege_type;

-- Expected:
-- - delete_session_post(text) exists once.
-- - security_definer = true.
-- - authenticated has EXECUTE.
-- - anon and PUBLIC do not have EXECUTE.
-- - Return columns are deleted_session_id and deleted_at only.
-- - No email, full user_id, gm_user_id, token, key, secret, or Discord credential
--   values are returned.

-- Smoke test notes for a later step:
-- - anon is rejected.
-- - unauthenticated call is rejected.
-- - normal PL is rejected.
-- - another GM is rejected.
-- - owner GM can delete a test Supabase session.
-- - admin can delete a test Supabase session.
-- - static JSON sessions are not DB targets.
-- - deleted session disappears from draft list, admin targets, calendar, and detail.
-- - related session_applications and session_comments rows are removed by
--   ON DELETE CASCADE.
-- - If Discord metadata existed, no Discord real send happens in this RPC.

-- Rollback draft, not for this step:
--
-- revoke execute on function public.delete_session_post(text) from public;
-- revoke execute on function public.delete_session_post(text) from anon;
-- drop function if exists public.delete_session_post(text);
