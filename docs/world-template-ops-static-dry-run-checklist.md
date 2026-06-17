# World Template Ops Static Dry-Run Checklist

Date: 2026-06-17

Phase: 3-C9 ops core static connection dry-run checklist docs.

Baseline commit: `d057ed5 Document pre ops connection checklist`

This is a docs-only checklist. It does not include implementation, HTML, CSS,
JS, JSON/data, sample data, auth connection, DB connection, RPC/RLS change,
SQL Editor execution, SQL apply, Edge Function deploy, Discord operation,
secret/Webhook change, direct Supabase write, real post/edit/delete, real
application/comment write, membership approval/rejection/manager grant,
cleanup apply, debug logging addition, `updates.json` change, permission logic
change, or raw id/email/token/JWT/management key display.

## Purpose

Ops core static dry-run is the Stage 2 bridge after public world-template
checks and before auth / DB / RPC / RLS / Discord / Edge Function work.

It is used to confirm:

- ops page HTML is served
- page renderers and imports are reachable
- cache-bust chains are understandable
- reusable ops config imports are intact
- helper modules are available
- unconnected or gated states are documented
- world-template ownership stays separate
- missing auth / DB / Discord dependencies are identified before risky gates

It is not proof that live operation is ready.

Dry-run does not perform:

- real data changes
- DB writes
- SQL execution
- SQL apply
- RLS changes
- RPC changes
- Edge deploy
- Discord send/edit/delete
- real session posting
- real session editing/deletion
- real participation applications
- real comment posting
- membership approval/rejection/manager changes

Unconnected areas should be recorded as `not_connected`, `not_tested`,
`requires_auth`, `requires_db`, `requires_discord`, or
`requires_separate_gate`.

## Current Ops / Auxiliary Inventory

Primary ops core static dry-run candidates:

- `calendar.html`
- `session-post.html`
- `session-detail.html`
- `mypage.html`
- `timeline.html`

Auxiliary candidate:

- `tools.html`

Strict admin / separate-gate candidate:

- `admin-cap-announcements.html`

Current `main.js` renderer keys:

- `calendar` -> `assets/js/core/calendar/renderCalendar.js`
- `session-post` -> `assets/js/renderSessionPost.js`
- `session-detail` -> `assets/js/renderSessionDetail.js`
- `mypage` -> `assets/js/renderMypage.js`
- `timeline` -> `assets/js/renderTimeline.js`
- `tools` -> `assets/js/renderTools.js`
- `admin-cap-announcements` -> `assets/js/renderAdminCapAnnouncements.js`

Current shared surfaces visible from static inspection:

- `assets/js/core/config/reusableOpsConfig.js`
- `assets/js/core/calendar/renderCalendar.js`
- `assets/js/core/session/sessionDisplayHelpers.js`
- `assets/js/core/session/sessionHtmlHelpers.js`
- `assets/js/core/session/sessionFormHelpers.js`
- `assets/js/core/session/sessionPlayerCountHelpers.js`
- `assets/js/sessionDisplay.js` compatibility facade
- `assets/js/sessionData.js`
- `assets/js/membershipAccessClient.js`
- `assets/js/mypageAuthClient.js`
- `assets/js/discordSyncClient.js`
- `assets/js/supabaseBrowserClient.js`

These files are current Velgard references. A next world should not assume all
ops pages are enabled at launch.

## Dry-Run Rules

### Allowed In Static Dry-Run

- HTML HTTP 200 checks
- public JS HTTP 200 checks
- public JSON/data HTTP 200 and parse checks
- broken import / missing module checks
- cache-bust chain inspection
- config import/export inspection
- helper import/export inspection
- static or fixture display review
- empty-state review
- gated/unconnected-state review
- visible `undefined` / `[object Object]` checks
- broken image checks
- public data secret review
- docs status recording

### Not Allowed In Static Dry-Run

- SQL execution
- SQL apply
- DB write
- RPC write operation
- RLS change
- Edge Function deploy
- Discord production post/edit/delete
- Discord dry run that calls a live function
- secret or Webhook setting
- real session post
- real session edit
- real session delete
- real participation application
- real comment post/edit/delete
- membership approval/rejection
- manager grant/revoke
- cleanup apply
- bulk data change

If a check requires one of these, record the check as
`requires_separate_gate`.

## Page Dry-Run Checklist

### `calendar`

Current files:

- `calendar.html`
- `assets/js/main.js`
- `assets/js/core/calendar/renderCalendar.js`
- `assets/js/core/config/reusableOpsConfig.js`
- `assets/js/sessionData.js`
- `assets/js/sessionDisplay.js`
- `assets/js/membershipAccessClient.js`
- `data/calendarConfig.json`

Dry-run checks:

- `calendar.html` returns HTTP 200.
- `calendar.html` uses the expected `main.js` cache-bust chain.
- public `main.js` imports `core/calendar/renderCalendar.js`.
- public calendar renderer imports reusable ops config.
- public calendar renderer imports membership access and session display paths
  without a broken import.
- `data/calendarConfig.json` returns HTTP 200 and parses.
- static / fixture / empty state does not visibly break.
- unapproved or not-connected approved gate state is recorded.
- calendar-side `levelCaps` remains separate from regulation-side
  `levelCaps`.
- no DB write or live session operation is attempted.

Can be checked before DB:

- static delivery
- config import/export
- calendar config parse
- static sessions fallback if present
- approved-gate notice rendering, when visible without logging in
- absence of obvious broken imports and visible `undefined`

Requires later gates:

- authenticated approved-member calendar behavior
- DB-backed session merge behavior
- live session operation links
- role-specific visibility
- data-changing workflows

Recommended dry-run status:

- `completed` for static delivery only when checked
- `limited` for visual review
- `requires_auth` for approved-member behavior
- `requires_db` for DB-backed sessions

### `session-post`

Current files:

- `session-post.html`
- `assets/js/main.js`
- `assets/js/renderSessionPost.js`
- `assets/js/sessionDisplay.js`
- `assets/js/core/session/sessionFormHelpers.js`
- `assets/js/core/session/sessionPlayerCountHelpers.js`
- `assets/js/core/config/reusableOpsConfig.js`
- `assets/js/supabaseBrowserClient.js`
- `assets/js/membershipAccessClient.js`
- `assets/js/discordSyncClient.js`

Dry-run checks:

- `session-post.html` returns HTTP 200.
- `session-post.html` uses the expected `main.js` cache-bust chain.
- public `main.js` imports `renderSessionPost.js`.
- public `renderSessionPost.js` imports session display, form helpers,
  player-count helpers, reusable ops config, membership access, and Discord
  sync paths without a broken import.
- form helper exports are reachable.
- reusable ops config exports used by session-post are reachable.
- auth-unconnected and approved-unconnected behavior is recorded.
- submit, save, edit, template, delete, and Discord controls are not exercised.
- input names and payload fields are not changed.
- no real post/edit/delete operation is attempted.

Can be checked before DB/RPC:

- static delivery
- import chain
- initial gated/unconnected state
- helper export availability
- visible form shell only if safely rendered without approval
- visible `undefined` / `[object Object]` absence

Requires later gates:

- actual new post create
- managed edit restore
- delete flow
- template save/apply/delete
- GM/admin permission behavior
- Discord sync
- payload/RPC correctness

Recommended dry-run status:

- `not_connected` when auth/RPC are intentionally unavailable
- `requires_auth` for form access behind approved gate
- `requires_db` for create/edit/delete/template operations
- `requires_discord` for sync behavior

### `session-detail`

Current files:

- `session-detail.html`
- `assets/js/main.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/sessionData.js`
- `assets/js/sessionDisplay.js`
- `assets/js/sessionDetailApplicationComments.js`
- `assets/js/core/config/reusableOpsConfig.js`
- `assets/js/supabaseBrowserClient.js`
- `assets/js/membershipAccessClient.js`
- `assets/js/discordSyncClient.js`

Dry-run checks:

- `session-detail.html` returns HTTP 200.
- `session-detail.html` uses the expected `main.js` cache-bust chain.
- public `main.js` imports `renderSessionDetail.js`.
- public `renderSessionDetail.js` imports session data, session display facade,
  application/comment module, membership access, reusable ops config, Supabase
  browser client, and Discord sync paths without a broken import.
- static display or not-found / gated state is documented without recording
  real session ids.
- real session URL values are not written into docs.
- participation applications are not submitted.
- comments are not posted, edited, or deleted.
- GM management controls are not exercised.
- Discord sync is not exercised.

Can be checked before DB:

- static delivery
- import chain
- safe missing-id or not-found display
- membership gate notice if visible without login
- no obvious `undefined` / `[object Object]`

Requires later gates:

- authenticated approved-member detail behavior
- application/comment reads from DB
- application/comment writes
- GM approve/reject behavior
- owner/admin controls
- Discord sync panel
- real session-id route coverage

Recommended dry-run status:

- `limited` for static route display
- `requires_auth` for approved-member detail access
- `requires_db` for live applications/comments/management
- `requires_discord` for sync panel behavior

### `mypage`

Current files:

- `mypage.html`
- `assets/js/main.js`
- `assets/js/renderMypage.js`
- `assets/js/mypageAuthClient.js`
- `assets/js/core/config/reusableOpsMypageLabels.js`
- `assets/js/supabaseBrowserClient.js`

Current boundary:

- `renderMypage.js` renders a static shell and calls
  `window.VELGARD_MYPAGE_AUTH.init(root)` only if the normal-script auth client
  is present.
- `mypageAuthClient.js` remains a normal-script / auth-adjacent boundary and
  should not be split or rewritten in a static dry-run.

Dry-run checks:

- `mypage.html` returns HTTP 200.
- `mypage.html` uses the expected CSS and `main.js` cache-bust chain.
- normal script loading order is documented if checked.
- `renderMypage.js` imports and renders without a broken module path.
- auth-unconnected fallback text is visible or documented.
- profile, membership, manager, templates, and applications are recorded as
  `not_tested` when auth is not connected.
- raw user ids, emails, actual management keys, JWT values, and tokens are not
  displayed or recorded.
- no mypage auth client split or behavior change is performed.

Can be checked before auth:

- static shell delivery
- fallback text
- absence of visible raw private values in public shell
- main module path

Requires later gates:

- login/logout
- profile display/update
- membership state
- membership management
- template management
- applications list
- role/manager behavior

Recommended dry-run status:

- `completed` for static shell only when checked
- `not_connected` for auth client behavior if not configured
- `requires_auth` for profile/membership/manager UI
- `requires_db` for membership/application/template data

### `timeline`

Current files:

- `timeline.html`
- `assets/js/main.js`
- `assets/js/renderTimeline.js`
- `assets/js/activityTimelineDisplay.js`
- `assets/js/membershipAccessClient.js`
- `assets/js/supabaseBrowserClient.js`

Current boundary:

- timeline is ops-leaning because it is tied to activity records,
  membership-gated display, target paths, and DB/RPC-backed activity data.
- it is not the same as static `updates`.

Dry-run checks:

- `timeline.html` returns HTTP 200.
- `timeline.html` uses the expected `main.js` cache-bust chain.
- public `main.js` imports `renderTimeline.js`.
- public timeline renderer imports membership access and timeline display
  helper paths without a broken import.
- unauthenticated/unapproved state is documented if visible.
- empty state is documented when no client or no items are available.
- target paths are not assumed valid without DB-backed data.
- no live timeline RPC or data-changing operation is exercised.

Can be checked before DB:

- static delivery
- import chain
- membership gate notice
- no obvious broken import or visible `undefined`

Requires later gates:

- approved-member timeline read
- DB/RPC activity data
- target path correctness for live activity
- notification generation
- role-specific visibility

Recommended dry-run status:

- `requires_auth` for approved view
- `requires_db` for live activity data
- `limited` for static gate/empty-state display

### `tools`

Current files:

- `tools.html`
- `assets/js/main.js`
- `assets/js/renderTools.js`
- `data/randomTables.json`

Current boundary:

- tools is auxiliary/common.
- it can be world-specific play support or a reusable public utility.
- current tool behavior reads public random table data and uses browser local
  storage for local history.
- it should not be treated as auth, DB, or Discord work unless a future gate
  changes it.

Dry-run checks:

- `tools.html` returns HTTP 200.
- `tools.html` uses the expected `main.js` cache-bust chain.
- public `main.js` imports `renderTools.js`.
- public `renderTools.js` imports `dataLoader.js` and loads
  `data/randomTables.json`.
- `data/randomTables.json` returns HTTP 200 and parses.
- empty or hidden table behavior is documented if applicable.
- world-specific random table text is reviewed for next-world suitability.
- no auth/DB/Discord dependency is introduced.

Can be checked before auth/DB/Discord:

- static delivery
- public JSON parse
- visible table selector and empty state
- local-only roll behavior if browser dry-run is intentionally allowed
- absence of visible `undefined`

Requires later gates:

- cloud-synced tool history
- account-specific tool data
- DB-backed custom tables

Recommended dry-run status:

- `completed` if public-only static behavior is checked
- `limited` if browser interaction is not checked
- `not_connected` for any future account/cloud feature

### `admin-cap-announcements`

Current files:

- `admin-cap-announcements.html`
- `assets/js/main.js`
- `assets/js/renderAdminCapAnnouncements.js`
- `assets/js/adminCapAnnouncementClient.js`

Current boundary:

- strict ops/admin surface.
- close to admin auth, RPCs, Edge/Discord announcement workflows, target
  channels, and production posting.
- should remain disabled or separate-gate unless explicitly adopted.

Dry-run checks:

- static page HTTP 200 may be checked only if the page is intentionally in
  scope.
- import chain may be checked without running admin actions.
- no admin action, scheduling, send, edit, delete, Edge, or Discord workflow is
  exercised.
- no channel id, message id, Webhook URL, token, or secret value is recorded.

Recommended status:

- `requires_separate_gate`
- `not_tested`

## Status Recording Format

Use conservative status words:

- `completed`
- `limited`
- `not_tested`
- `not_connected`
- `blocked`
- `requires_auth`
- `requires_db`
- `requires_discord`
- `requires_separate_gate`

Recording rules:

- do not overstate dry-run results as production pass
- describe exactly what was checked
- record static delivery separately from authenticated or DB behavior
- record public-only and private/ops scopes separately
- record reasons for `blocked`
- do not write secret values
- do not write raw user ids, emails, JWT values, tokens, actual management
  keys, channel ids, message ids, or private URLs
- minimize URLs and ids in docs; use status-only records for sensitive systems

Example style:

```text
calendar static delivery: completed
calendar approved-member behavior: requires_auth
calendar DB-backed sessions: requires_db
calendar Discord behavior: not_applicable
```

## Advancement Conditions

### Ready To Consider Auth Gate

Proceed only when:

- public-only world-template pages are still intact
- ops page static imports are not broken
- auth-required pages are classified
- approved-gate target pages are classified
- unauthenticated and unapproved displays are defined
- raw user ids and emails will not be displayed
- profile-safe fields are defined
- mypage, membership, and manager UI scope is decided
- authenticated QA matrix is planned as a separate gate

### Ready To Consider DB / RPC / RLS Gate

Proceed only when:

- static ops pages do not show obvious broken imports
- DB-required features are classified
- static-only features are classified
- SELECT-only checks are separated from write checks
- SQL apply is a separate gate
- RLS changes are separate gates
- RPC additions or changes are separate gates
- rollback is documented before apply
- DB write QA is planned separately

### Ready To Consider Discord / Edge Gate

Proceed only when:

- DB/RPC prerequisites are understood
- Discord sync is explicitly needed
- dry-run and production operations are separated
- Webhook/secret values will not be recorded in docs
- duplicate-post prevention is defined
- failed-sync retry and rollback policies are defined
- production post, edit, and delete are separate gates
- Edge deploy is a separate gate

## Rollback And Recovery During Dry-Run

If static dry-run finds a problem:

1. Identify whether the issue is HTML delivery, import path, cache-bust, config
   export, helper export, public JSON/data, or gated/unconnected state.
2. Keep the fix static if a future implementation gate approves it.
3. Do not use auth, DB, Discord, Edge, or secrets to work around a static
   delivery issue.
4. Do not write secret values into docs while diagnosing.
5. Mark unresolved issues as `blocked` with a short reason.
6. Re-check public-only world-template pages if shared `main.js` or shared CSS
   is affected by any future fix.
7. After rollback or repair, re-run HTTP 200 and broken import checks.
8. Keep any data-changing, auth, DB/RPC/RLS, Edge, and Discord checks as
   separate gates.

## Next Candidate Options

Candidate A: OGP / favicon / hero image rollout gate.

- Document site identity image replacement, cache-bust, public preview checks,
  and rollback for a next world.

Candidate B: tools / updates auxiliary page policy.

- Decide whether tools and updates are world-template, reusable utility, or
  disabled for a next world.

Candidate C: authenticated QA matrix plan.

- Define approved/unapproved/owner/admin/member-manager QA only after auth
  connection is explicitly approved.

Candidate D: DB/RPC/RLS gate checklist.

- Define SELECT-only, SQL apply, RLS, RPC, write QA, and rollback separation
  before database work.

Recommended next candidate:

- Candidate B: tools / updates auxiliary page policy.

Reason:

- `tools` is included in this dry-run as an auxiliary page, but its ownership
  remains between world-template and reusable utility.
- `updates` was already marked as auxiliary/common and should not blindly copy
  Velgard history into a next world.
- This can remain docs-only and avoid auth, DB/RPC/RLS, Edge, Discord, and
  data-changing workflows.

## Limited And Not Tested

This checklist is docs-only and does not add runtime QA.

Limited:

- page/import inventory was static
- no public HTTP sweep was run in this phase
- no browser dry-run was performed
- no cache-bust chain was validated against public GitHub Pages in this phase
- no role matrix was exercised

Not tested:

- authenticated calendar/session-post/session-detail/mypage/timeline behavior
- DB/RPC/RLS reads and writes
- real session post/edit/delete
- template save/apply/delete
- participation application writes
- comment writes
- membership approval/rejection/manager changes
- Edge Function deploy
- Discord dry run
- Discord production post/edit/delete
- secret configuration

## No Dangerous Work

This checklist did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge deploy, Discord operation, secret/Webhook change, direct
Supabase write, debug logging addition, `updates.json` change,
auth/permission logic change, membership logic change, RPC/DB key
configuration, CSS class/DOM id/anchor change, `management_key` display, raw
id/email/token/JWT display, HTML change, CSS change, JS change, JSON/data
change, sample data creation, auth connection, DB connection, real post/edit/
delete, application/comment write, membership approval/rejection/manager grant,
cleanup apply, or Discord connection.
