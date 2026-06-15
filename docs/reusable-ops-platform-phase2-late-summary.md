# Reusable Ops Platform Phase 2 Late Summary

## Background

This document summarizes Phase 2-N through Phase 2-V of the reusable TRPG
operations platform separation track.

The Phase 2 midpoint summary recorded the early physical separation work:

- core config files moved under `assets/js/core/config/`
- the calendar renderer moved under `assets/js/core/calendar/`
- pure session display helpers and small session-detail HTML helpers moved
  under `assets/js/core/session/`

The late Phase 2 work focused on `assets/js/renderSessionPost.js`, especially
small display helpers around session-post fields and player-count rendering.

This summary is documentation-only. It records the current boundary after the
session-post helper extractions and their public rollout checks.

## Phase 2-N: Session Post Field Helper Audit

Phase 2-N audited `assets/js/renderSessionPost.js` for small helper extraction
candidates.

Immediate extraction candidates:

- `renderTextField`
- `renderSelectField`
- `renderTextareaField`

Conditional candidates:

- `renderPlayerCountFields`
- `formatPlayerCountLabel`

Excluded or deferred surfaces:

- save and edit flows
- template RPC and template application behavior
- Discord mention and Discord sync
- auth and approved gate behavior
- payload generation
- event handlers

Result:

- documentation-only
- no helper was moved
- `renderSessionPost.js` stayed the session-post page orchestrator

Detailed plan:

- `docs/reusable-ops-platform-phase2n-session-post-field-helper-plan.md`

## Phase 2-O/P: Basic Session Post Field Helpers

Phase 2-O extracted the three basic session-post field helpers.

Extracted:

- `renderTextField`
- `renderSelectField`
- `renderTextareaField`

Destination:

- `assets/js/core/session/sessionFormHelpers.js`

Why `core/session`:

- these helpers still emit `session-post-field` markup and are not generic
  cross-site form components yet

Public rollout checked in Phase 2-P:

- public helper fetch: `ok`
- public `renderSessionPost.js` import: `ok`
- `session-post.html` and `main.js` cache-bust chain: `ok`
- `calendar.html` and `session-detail.html`: served

Not tested:

- authenticated role-specific session-post UI
- data-changing create/edit/delete flows
- template operation QA
- Discord sync QA

Detailed docs:

- `docs/reusable-ops-platform-phase2o-session-post-field-helper-result.md`
- `docs/reusable-ops-platform-phase2p-session-post-field-helper-public-check.md`

## Phase 2-Q/R: Player Count Boundary And Behavior Spec

Phase 2-Q reviewed the player-count helpers:

- `renderPlayerCountFields`
- `formatPlayerCountLabel`

Both were classified as `B`: extractable later, but only after the current
contract was fixed.

Phase 2-R documented the player-count behavior before implementation.

Fixed contract:

- the field names are `p_player_min` and `p_player_max`
- the names are connected to payload generation, template save/apply, managed
  edit restore, and reset behavior
- both controls are numeric inputs with `min="0"`
- no required/placeholder/max/id/custom input class/value attribute is part of
  the current contract
- `formatPlayerCountLabel` keeps the documented range, same-value range,
  min-only, max-only, zero, missing, raw numeric string, and invalid raw
  string fallback behavior

Decision:

- extract `formatPlayerCountLabel` first
- move `renderPlayerCountFields` only in a dedicated gate
- do not put payload keys, RPC names, DB column names, or permission logic into
  `reusableOpsConfig`

Detailed docs:

- `docs/reusable-ops-platform-phase2q-session-post-player-count-helper-plan.md`
- `docs/reusable-ops-platform-phase2r-player-count-behavior-spec.md`

## Phase 2-S/T: Player Count Label Helper

Phase 2-S extracted only:

- `formatPlayerCountLabel`

Destination:

- `assets/js/core/session/sessionPlayerCountHelpers.js`

Local check:

- 13-case smoke test: `ok`

Public rollout checked in Phase 2-T:

- public helper fetch: `ok`
- public helper export: `ok`
- public `renderSessionPost.js` import: `ok`
- public `session-post.html` and `main.js` cache-bust chain: `ok`
- `renderPlayerCountFields` remained unmoved at that point

Preserved:

- Phase 2-R fallback matrix
- player-count field names and attributes
- payload generation
- template save/apply behavior
- managed-session edit restore
- reset behavior
- Discord sync
- auth/permission/RPC/DB behavior

Not tested:

- authenticated operation
- data-changing session-post/template/Discord flows

Detailed docs:

- `docs/reusable-ops-platform-phase2s-player-count-label-helper-result.md`
- `docs/reusable-ops-platform-phase2t-player-count-label-helper-public-check.md`

## Phase 2-U/V: Player Count Field Helper

Phase 2-U extracted only:

- `renderPlayerCountFields`

Destination:

- `assets/js/core/session/sessionFormHelpers.js`

Local checks:

- player-count field snapshot: `ok`
- module import / import-cycle smoke: `ok`

Public rollout checked in Phase 2-V:

- public `sessionFormHelpers.js` fetch: `ok`
- public `renderPlayerCountFields` export: `ok`
- public `renderSessionPost.js` core import: `ok`
- public `sessionPlayerCountHelpers.js` fetch/export: `ok`
- public `session-post.html` and `main.js` cache-bust chain: `ok`
- public `calendar.html` and `session-detail.html`: served

Preserved:

- `p_player_min`
- `p_player_max`
- `min="0"`
- no added `required`
- no added `placeholder`
- no added `value=`
- no added `max=`
- payload generation
- template save/apply behavior
- reset behavior
- Discord sync
- auth/RPC/DB behavior

Not tested:

- authenticated role-specific session-post operation
- actual browser form operation after login
- template save/apply
- managed edit restore
- reset operation
- data-changing create/edit/delete
- Discord sync

Detailed docs:

- `docs/reusable-ops-platform-phase2u-player-count-field-helper-result.md`
- `docs/reusable-ops-platform-phase2v-player-count-field-helper-public-check.md`

## Current Core Structure

### `assets/js/core/config/`

`assets/js/core/config/reusableOpsConfig.js`

- shared display/config entry for reusable operations labels
- currently covers session type labels/classes and selected reusable copy
- keeps display configuration separate from auth, role, RPC, and DB contracts

`assets/js/core/config/reusableOpsMypageLabels.js`

- normal-script bridge for mypage label access
- allows `mypageAuthClient.js` to read selected labels without module
  conversion
- preserves fallback behavior

### `assets/js/core/calendar/`

`assets/js/core/calendar/renderCalendar.js`

- calendar renderer moved into the reusable core path
- public delivery and browser checks have been recorded
- still depends on session data and display helpers from existing boundaries

### `assets/js/core/session/`

`assets/js/core/session/sessionDisplayHelpers.js`

- pure session display formatters and label helpers extracted from
  `sessionDisplay.js`
- examples include title, time, status, visibility, session type, and closing
  mark helpers

`assets/js/core/session/sessionHtmlHelpers.js`

- small pure HTML string helpers extracted from `sessionDisplay.js`
- currently includes detail rows, array rows, tags, and summary helpers

`assets/js/core/session/sessionFormHelpers.js`

- small session-post field HTML helpers
- currently includes text/select/textarea field helpers and
  `renderPlayerCountFields`
- remains session-scoped because the markup uses session-post CSS classes

`assets/js/core/session/sessionPlayerCountHelpers.js`

- player-count display formatter module
- currently exports `formatPlayerCountLabel`
- preserves the Phase 2-R fallback matrix

## Files Still Not To Move Broadly

The following files should still avoid whole-file moves or large splits.

| file | reason |
| --- | --- |
| `assets/js/main.js` | Central route/bootstrap file. Splitting it affects every page and cache-bust chain. |
| `assets/js/sessionData.js` | Close to session loading, normalization, and static JSON retirement boundaries. |
| `assets/js/sessionDisplay.js` | Still acts as the compatibility facade and retains larger UI blocks. |
| `assets/js/renderSessionPost.js` | Still owns form orchestration, validation, templates, payload generation, event handlers, and Discord-adjacent behavior. |
| `assets/js/renderSessionDetail.js` | Close to session-detail behavior, management surfaces, applications, and comments. |
| `assets/js/mypageAuthClient.js` | Close to auth, membership, templates, profile, and management RPC surfaces. |
| `assets/js/membershipAccessClient.js` | Close to approved gate and membership status behavior. |
| `assets/js/discordSyncClient.js` | Close to external sync state and Discord operation boundaries. |
| `assets/css/style.css` | Mixed global, operations, world-site, and theme styles. Broad split risk remains high. |

## QA Status

### Completed

Static/public checks completed for the late Phase 2 track:

- helper HTTP 200 checks
- import/export checks
- cache-bust checks
- local `node --check` for changed JS in implementation gates
- local smoke/snapshot checks for player-count helpers
- public delivery checks for session-post helper modules

### Limited

Limited checks recorded:

- user-side lightweight visual checks for earlier session helper extraction
- no obvious visual regression observed in those limited scopes

Use `limited` or `no_obvious_issue_observed` for these checks. They are not
full functional QA.

### Not Tested / Separate Gates

The following remain `not_tested` or separate explicit gates:

- authenticated role-specific operation
- real session creation
- real session editing
- real session deletion
- template save/apply operation
- reset/edit restore browser operation
- Discord sync
- any QA that changes DB state

Do not record these as `pass` until a dedicated QA gate runs them.

## Next Candidates By Risk

### Low Risk

- docs consolidation
- `reusableOpsConfig` unconnected label audit
- public rollout checks after any cache-bust chain change
- regulation template structure detailing
- additional pure formatter investigation

### Medium Risk

- remaining small helper audit inside `renderSessionPost.js`
- additional tiny session-detail UI helper extraction
- regulation-specific CSS/structure audit
- authenticated browser QA planning

### High Risk

- splitting `main.js`
- moving `sessionData.js`
- moving `renderSessionPost.js` wholesale
- splitting `mypageAuthClient.js`
- splitting `style.css`
- separating Discord sync flows
- DB/RPC-adjacent restructuring

High-risk items need dedicated migration plans, rollback notes, and explicit QA
gates.

## Result

Phase 2 late status: stable and still conservative.

The reusable operations core now has config, calendar, session display,
session HTML, session form, and player-count helper surfaces. The project has
kept large page orchestrators, auth/RPC/Discord flows, payload generation, and
CSS splitting outside the physical separation track.

No implementation change, file move, JS change, CSS change, data change, SQL
Editor execution, SQL apply, DB/RPC/RLS mutation, Edge deploy, Discord
operation, direct Supabase write, debug console logging addition,
`updates.json` change, auth/permission logic change, `management_key` display,
or raw id/email/token/JWT display was performed for this summary.

## Phase 2-X Follow-Up: Config Label Gap Audit

Phase 2-X completed the low-risk documentation-only audit for unconnected
`reusableOpsConfig` label candidates.

Outcome:

- identified immediately configurable labels such as small navigation labels
  and low-risk calendar panel labels
- marked session status/visibility and player-count wording as configurable
  only after fallback/behavior specs
- kept membership management, auth, template RPC, Discord, session-post
  save/delete, and session-detail owner/admin messages out of immediate config
  work because they are UI-block or side-effect adjacent
- reaffirmed that DB columns, RPC names, enum stored values, DOM ids, CSS
  classes, input names, role keys, Discord payload keys, `management_key`, and
  raw id/email/token/JWT surfaces must not move into config
- clarified the normal-script bridge boundary for `mypageAuthClient.js`

Detailed plan:

- `docs/reusable-ops-platform-phase2x-config-label-gap-plan.md`

## Phase 2-Y Follow-Up: Minimal Safe Label Connection

Phase 2-Y connected a very small subset of the Phase 2-X `A` classified labels.

Connected:

- `REUSABLE_OPS_CONFIG.calendar.labels.sessionCountAriaPrefix`
- `REUSABLE_OPS_CONFIG.calendar.labels.detailLink`
- `REUSABLE_OPS_CONFIG.calendar.labels.sessionsLoadError`
- `REUSABLE_OPS_CONFIG.calendar.labels.sessionsEmpty`
- `REUSABLE_OPS_CONFIG.calendar.labels.selectedSessionsTitle`
- `REUSABLE_OPS_CONFIG.calendar.labels.time`
- `REUSABLE_OPS_CONFIG.calendar.labels.gm`

Runtime usage:

- `assets/js/core/calendar/renderCalendar.js`

Cache-bust:

- `20260616-calendar-safe-labels`

Preserved:

- explicit fallback strings at every call site
- displayed calendar text
- auth, role, RPC, DB, Discord, payload, CSS class, DOM id, input name, and
  `management_key` boundaries
- the normal-script mypage bridge boundary

Not touched:

- `mypageAuthClient.js`
- session-post/detail labels
- membership management labels
- status/visibility labels
- player-count wording
- Discord sync labels

Detailed result:

- `docs/reusable-ops-platform-phase2y-config-label-minimal-result.md`

## Phase 2-Z Calendar Safe Label Rollout Check

Phase 2-Z checked public static delivery after the Phase 2-Y calendar label
connection.

Confirmed:

- public `calendar.html` references `main.js?v=20260616-calendar-safe-labels`
- public `main.js` imports the matching calendar renderer
- public `core/calendar/renderCalendar.js` imports `getCalendarLabel`
- public `renderCalendar.js` imports the matching `reusableOpsConfig.js`
- public `core/config/reusableOpsConfig.js` contains `calendar.labels`
- public `reusableOpsConfig.js` exports `getCalendarLabel`
- public `session-post.html` and `session-detail.html` are still served

No implementation or cache-bust repair was needed. Authenticated browser
operation and data-changing behavior remain separate explicit QA gates.

Detailed result:

- `docs/reusable-ops-platform-phase2z-calendar-safe-labels-public-check.md`
