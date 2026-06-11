# Security Definer Search Path Audit

## Purpose

This document prepares the P1 public-readiness cleanup for security definer
functions that do not yet report `search_path=public`.

`security definer` functions run with elevated database privileges. Pinning
`search_path` is a safety belt: it reduces the chance that an elevated function
resolves an unintended same-named table, function, operator, or helper.

This is an inventory and classification step only. It does not execute SQL,
apply DB/RPC/RLS changes, change Dashboard settings, deploy Edge Functions,
send mail, or send Discord messages.

## Current Context

- The 066 public security audit found 55 security definer functions and 38
  functions that did not report `search_path=public`.
- The 067 detail review confirmed that the unsafe anon-executable non-read RPC
  candidates were `rls_auto_enable()` and `set_updated_at()`.
- The 068/069 gate closed direct web-client EXECUTE for those two functions,
  while preserving trigger/internal usage.
- Auth abuse protection with Turnstile is complete.
- comment/application spam guard apply and QA are complete.
- Remaining public-readiness P1 work includes search_path cleanup.

## Why No Apply Draft Yet

The repository contains historical drafts, reviewed apply files, and later
replacement SQL. That history is useful for understanding intent, but it is not
safe to infer the current live database function list from the repository alone.

The 067 result recorded only counts and a few notable function names, not the
full list of 38 signatures. A bulk apply draft would risk replacing old
signatures or touching functions whose current DB body differs from the repo
draft.

Therefore, this gate creates a SELECT-only inventory query first:

- `docs/supabase/sql/072_security_definer_search_path_inventory_select_only.sql`

The 072 query returns function signatures, owner role names, search_path flags,
EXECUTE exposure, trigger-reference counts, broad object-reference hints, and a
priority bucket. It does not return function bodies, row data, user ids, emails,
session ids, activity ids, notification ids, full URLs, project refs, tokens,
keys, or secrets.

## Classification Model

### P0/P1 High Priority

Functions in this group should be reviewed before wider public exposure if 072
reports that they do not pin `search_path=public`.

Criteria:

- Web-client executable by `anon`, `public`, or `authenticated`.
- Accept user input or write/update/delete data.
- Generate notifications or TIMELINE activity.
- Check GM/admin/owner boundaries or call auth context.
- Interact with Discord sync or external posting state.
- Return or modify profile/contact/avatar/session/comment/application data.

Known or likely examples from existing docs and prior gates:

- `get_public_session_application_counts(text)` is read-like and anon-readable,
  but 067 already identified it as a P1 search_path cleanup target.
- Any active `create_*`, `update_*`, `delete_*`, `set_*`, `cancel_*`,
  `close_*`, `mark_*`, `record_*`, `claim_*`, or `finalize_*` RPC returned by
  072 without `search_path=public`.
- Any Discord sync, notification, activity, session post, profile/avatar, player
  character, comment, or application RPC returned by 072 without
  `search_path=public`.

### Medium Priority

Functions in this group are less likely to be directly reachable from the web
client, but should still be cleaned up deliberately.

Criteria:

- Trigger functions.
- Internal updated-at/profile handlers.
- DB-internal helpers whose web-client EXECUTE is closed.
- Functions with trigger references but no direct anon/authenticated EXECUTE.

Known context:

- `set_updated_at()` direct web-client EXECUTE was closed by 068/069, but it may
  still appear as a trigger/internal cleanup candidate if it does not pin
  `search_path=public`.
- Auth profile trigger handlers should be reviewed carefully because signup
  depends on them.

### Low Priority / Hold

Functions in this group should not drive the first apply draft.

Criteria:

- Historical migration helpers or one-off maintenance functions.
- Functions with no web-client EXECUTE and no clear active trigger/use path.
- Duplicate or legacy overloads that might already be superseded.
- Functions where direct EXECUTE is closed and 072 gives no active object hints.

These may still deserve cleanup later, but should not be mixed into the first
public-readiness apply draft.

### Additional Confirmation Needed

Use a separate review before applying changes when 072 reports:

- Multiple overloads or unclear active signature.
- `service_role` / cron / Edge-only usage.
- An anon-readable public read RPC whose behavior is intended but whose
  search_path needs cleanup.
- A function whose repo draft and live DB metadata appear to disagree.
- A function where changing search_path could alter unqualified object
  resolution.

## Proposed Next Gates

1. Run `072_security_definer_search_path_inventory_select_only.sql` once as a
   SELECT-only SQL Editor gate.
2. Record the 072 results without concrete IDs, emails, full URLs, project refs,
   tokens, keys, or secrets.
3. Choose a small apply-draft scope from P0/P1 high-priority functions only.
4. Prepare a narrowly scoped apply draft and post-apply SELECT-only check.
5. Keep trigger/internal and low-priority cleanup for later gates unless 072
   shows unexpected web-client exposure.

## Non-Goals

- No SQL Editor execution in this preparation step.
- No SQL apply.
- No DB/RPC/RLS changes.
- No Dashboard changes.
- No Edge Function deploy.
- No mail or Discord sending.
- No credential or concrete identifier recording.
