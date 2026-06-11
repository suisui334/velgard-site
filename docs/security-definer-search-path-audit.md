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
- The 073 exact-path review found no P0, no `$user`, no `pg_temp`, and no fully
  missing search_path. The remaining search_path work is complete/hold unless a
  future RPC change touches an individual function.

## 072 Result Summary

The user ran `072_security_definer_search_path_inventory_select_only.sql` once
as a SELECT-only SQL Editor gate. No SQL apply, DB/RPC/RLS change, Dashboard
change, Edge deploy, mail sending, Discord sending, or credential recording was
performed.

Summary:

- `security_definer=55`
- `search_path_public=17`
- `needs_review=38`
- `missing_any_search_path=0`
- `p0=0`
- `p1=36`
- `p2=2`
- `high_web=35`
- `additional_confirmation=1`
- `trigger_internal=1`
- `low=1`

Interpretation:

- No P0 row was reported.
- No security definer function is completely missing a search_path setting.
- The 38 review rows are not `search_path=public`, but `has_any_search_path`
  was true, so this is not treated as immediate dangerous exposure.
- The next step is to inspect the exact configured path values before choosing
  any apply scope.
- Bulk-editing all 38 functions remains explicitly out of scope.

## 073 Result Summary

The user ran `073_security_definer_search_path_exact_select_only.sql` once as a
SELECT-only SQL Editor gate. No additional SQL Editor execution, SQL apply,
DB/RPC/RLS change, Dashboard change, Edge deploy, mail sending, Discord
sending, or credential recording was performed in this recording step.

Summary:

- `security_definer=55`
- `search_path_public=17`
- `needs_review=38`
- `missing_any_search_path=0`
- `p0=0`
- `$user` path count: 0
- `pg_temp` path count: 0
- `safe_empty_path_candidate=37`
- `needs_manual_review=1`

Interpretation:

- The 37 `search_path=""` functions are treated as safe empty-path candidates.
  This is a strict pattern when function bodies use schema-qualified references,
  and it is not a dangerous path by itself.
- The 36 P1 web-facing RPC rows were also safe empty-path candidates in the
  exact-path review, so a bulk apply to force `search_path=public` is not needed.
- The only manual-review function was `rls_auto_enable()` with
  `search_path=pg_catalog`.
- `rls_auto_enable()` has direct EXECUTE closed for `public`, `anon`,
  `authenticated`, and `service_role`, and it has no trigger references, so it
  can remain low-priority historical/supporting cleanup.
- `handle_new_auth_user_profile()` was classified as trigger/internal, uses the
  safe empty-path candidate pattern, and has external EXECUTE closed.

Conclusion:

- No additional search_path apply draft is prepared now.
- The public-readiness P1 search_path item is considered complete/hold:
  no P0, no dangerous path, and no bulk cleanup needed.
- Future changes to individual `security definer` functions should still verify
  the function's `search_path` and schema qualification as part of that gate.

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

After 072, a second SELECT-only diagnostic was prepared:

- `docs/supabase/sql/073_security_definer_search_path_exact_select_only.sql`

The 073 query classifies exact configured path values into:

- `safe_public_path`
- `safe_empty_path_candidate`
- `needs_manual_review`
- `dangerous_or_untrusted_path`

It also reports whether `$user`, `pg_temp`, or other non-public schemas appear
in the configured path, plus anon/authenticated/public/service-role EXECUTE
flags, trigger reference count, priority bucket, and broad non-secret object
hints.

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

## Operational Follow-Up

1. Do not run a bulk search_path cleanup apply for the 38 review rows.
2. When changing a specific `security definer` function, confirm its
   `search_path`, schema-qualified references, EXECUTE grants, and caller
   surface in that same gate.
3. Keep `rls_auto_enable()` as low-priority historical/supporting cleanup unless
   a future diagnostic shows renewed external EXECUTE exposure.
4. Keep trigger/internal functions on a cautious per-function review path rather
   than mixing them into web-facing RPC cleanup.

## Non-Goals

- No SQL Editor execution in this preparation step.
- No SQL apply.
- No DB/RPC/RLS changes.
- No Dashboard changes.
- No Edge Function deploy.
- No mail or Discord sending.
- No credential or concrete identifier recording.
