# Reusable Ops Platform Phase 2 Completion Summary

## Background

Phase 2 moved the reusable TRPG operations platform extraction from planning
into a conservative first physical separation. The work focused on files and
helpers that could move without changing DB/RPC contracts, auth behavior,
Discord sync, payload generation, or large page renderers.

This document closes Phase 2 as a completed stage. It is documentation-only and
does not introduce implementation changes.

## Phase 2 Completed Work

Phase 2 completed the following tracks:

- moved reusable operations config files into `assets/js/core/config/`
- moved the calendar renderer into `assets/js/core/calendar/`
- extracted pure session display helpers into `assets/js/core/session/`
- extracted session-detail row and array-row helpers
- extracted session tags and summary helpers
- extracted session-post text/select/textarea field helpers
- documented player-count behavior before moving it
- extracted the player-count label formatter
- extracted the player-count field renderer
- connected the first small calendar `A` classified labels to
  `reusableOpsConfig`
- checked public static delivery after each physical move or cache-bust chain
  change
- recorded design decisions and deferred risks in docs

Phase 2 deliberately stayed within small display/config/helper surfaces.

## Current Core Structure

### `assets/js/core/config/`

`assets/js/core/config/reusableOpsConfig.js`

- shared display/config entry for reusable operations labels
- covers session type labels/classes, selected calendar labels, membership
  gate labels, mypage labels, and selected session labels
- now includes `calendar.labels` and `getCalendarLabel()`
- does not contain auth decisions, DB/RPC keys, enum stored values, role keys,
  DOM ids, CSS classes, input names, Discord payload keys, `management_key`, or
  raw id/email/token/JWT-related values

`assets/js/core/config/reusableOpsMypageLabels.js`

- small normal-script bridge for mypage labels
- allows `mypageAuthClient.js` to keep its current loading model
- intentionally avoids converting mypage to module script during Phase 2

### `assets/js/core/calendar/`

`assets/js/core/calendar/renderCalendar.js`

- calendar renderer now lives under the core path
- uses `reusableOpsConfig` for session type labels/classes, buttons, and the
  first small safe calendar label group
- still depends on existing session data/display and membership gate modules
- should not be treated as an independent calendar app yet

### `assets/js/core/session/`

`assets/js/core/session/sessionDisplayHelpers.js`

- pure display formatters and label helpers originally extracted from
  `sessionDisplay.js`
- handles session titles, status/visibility labels, type labels, time/deadline
  formatting, closing marks, and similar display-only formatting

`assets/js/core/session/sessionHtmlHelpers.js`

- small HTML-string helpers originally extracted from `sessionDisplay.js`
- currently includes:
  - `renderSessionDetailRow`
  - `renderSessionDetailArrayRow`
  - `renderSessionTags`
  - `renderSessionSummary`

`assets/js/core/session/sessionFormHelpers.js`

- small session-post field HTML helpers
- currently includes:
  - `renderTextField`
  - `renderSelectField`
  - `renderTextareaField`
  - `renderPlayerCountFields`
- remains session-scoped because the helpers still emit session-post markup and
  field names

`assets/js/core/session/sessionPlayerCountHelpers.js`

- player-count display formatter module
- currently exports `formatPlayerCountLabel`
- preserves the Phase 2-R fallback matrix

## Facades Kept In Place

### `assets/js/sessionDisplay.js`

`sessionDisplay.js` remains a compatibility facade.

Reasons:

- existing import/export paths continue to work
- large UI blocks still remain in this file
- Discord sync panel rendering, session-detail management blocks, and
  application/comment UI are not safe to move as part of Phase 2
- it is still imported by calendar, session-post, session-detail, and admin cap
  announcement rendering
- keeping it in place allows small helper extraction without forcing a broad
  import rewrite

### `assets/js/renderSessionPost.js`

`renderSessionPost.js` remains the session-post page orchestrator.

Reasons:

- it owns form orchestration, validation, template behavior, payload
  generation, event handlers, auth/access checks, and Discord-adjacent UI
- only small field helpers and player-count helpers were extracted
- create/update/delete and template RPC flows were intentionally left untouched
- the file remains the safety boundary for data-changing session-post behavior

## Phase 2 Completion Conditions

Phase 2 can be treated as complete because:

- initial `core/config`, `core/calendar`, and `core/session` separation is in
  place
- small display-only and HTML-helper extractions are complete for the selected
  safe surfaces
- session-post field helper extraction is complete for the safe helper subset
- player-count label and field helpers were moved only after behavior specs
  and local checks
- the first minimal calendar label config connection is complete
- public static delivery checks were recorded after each relevant move
- large renderers, auth/RPC/DB behavior, Discord sync, payload generation, and
  CSS splitting were not changed
- untested browser and data-changing QA scopes are explicitly marked as
  `not_tested` or separate gates
- further work should start as Phase 3 rather than extending Phase 2

## Intentionally Deferred To Phase 3 Or Later

The following are intentionally not Phase 2 completion requirements:

- splitting `assets/js/main.js`
- moving `assets/js/sessionData.js`
- moving all of `assets/js/sessionDisplay.js`
- moving all of `assets/js/renderSessionPost.js`
- splitting `assets/js/renderSessionDetail.js`
- splitting `assets/js/mypageAuthClient.js`
- splitting `assets/js/membershipAccessClient.js`
- splitting `assets/js/discordSyncClient.js`
- splitting `assets/css/style.css`
- separating Discord sync flows
- DB/RPC/RLS restructuring
- authenticated role-specific browser QA
- real session create/edit/delete QA
- template save/apply QA
- reset/edit restore browser QA
- Discord sync QA

These require dedicated Phase 3 planning, QA gates, and rollback notes.

## QA Status

### Completed

Completed checks across Phase 2:

- `node --check` for changed JS in implementation gates
- local module import smoke checks
- player-count fallback smoke test
- player-count field snapshot check
- helper HTTP 200 checks
- public import/export checks
- public cache-bust chain checks
- public config/helper path checks
- docs records for each decision gate

### Limited

Limited checks:

- user-side lightweight visual checks after selected helper moves
- recorded as `no_obvious_issue_observed` where applicable
- these are not full authenticated functional QA results

### Not Tested

Remain `not_tested` or separate gates:

- authenticated role-specific operation
- real data-changing QA
- session creation
- session editing
- session deletion
- template save/apply
- reset/edit restore real browser operation
- Discord sync
- owner/admin/approved/unapproved role matrix after each helper move

These should not be recorded as `pass` until dedicated QA gates run them.

## Phase 3 Candidate Routes

### Phase 3-A: Low-Risk Continuation

Purpose:

- continue small, reversible, display-only refactors

Candidates:

- connect a few more Phase 2-X `A` labels to `reusableOpsConfig`
- keep each label group behind a small cache-bust/public-check gate
- add more docs for fallback behavior
- audit additional pure formatters

Risk:

- low, if each gate stays small and fallback-first

### Phase 3-B: Regulation / World Template Track

Purpose:

- advance the world-site template track separately from reusable ops core

Candidates:

- detail the regulation template structure
- inventory regulation JSON block patterns
- decide which regulation page structure is reusable across worlds
- audit regulation-specific CSS without splitting global CSS yet
- continue world-site template planning

Risk:

- low to medium, depending on whether implementation is included

### Phase 3-C: QA Strengthening

Purpose:

- turn static and limited checks into structured functional confidence

Candidates:

- authenticated browser QA plan
- role-based QA matrix for approved/unapproved/owner/admin
- non-data-changing QA scope definition
- explicit gates for data-changing create/edit/delete/template/Discord tests

Risk:

- medium, because authenticated sessions and real data operations need careful
  stopping conditions

### Phase 3-D: Medium/High-Risk Split Preparation

Purpose:

- prepare larger separation work without doing it prematurely

Candidates:

- audit remaining `renderSessionDetail.js` helper candidates
- audit remaining `renderSessionPost.js` structure
- investigate `mypageAuthClient.js` split points
- investigate `style.css` split points
- plan `main.js` routing/bootstrap separation

Risk:

- medium to high; implementation should not start without dedicated plans

## Phase 2 Completion Result

Phase 2 status: complete for the initial reusable ops core separation scope.

The project now has a small but real `assets/js/core/` structure for config,
calendar, and session helpers, while preserving the existing page orchestrators
and riskier auth/RPC/Discord/data-changing surfaces.

No implementation change, file move, JS change, CSS change, HTML change, data
change, SQL Editor execution, SQL apply, DB/RPC/RLS mutation, Edge deploy,
Discord operation, direct Supabase write, debug console logging addition,
`updates.json` change, auth/permission logic change, RPC/DB key configuration,
CSS class/DOM id/input name configuration, `management_key` display, or raw
id/email/token/JWT display was performed for this completion summary.

## Phase 3-A1 Follow-Up

Phase 3-A1 started the low-risk continuation route after Phase 2 completion.

Implemented only a second very small `A` classified label group:

- `session.playerCountLabels.min`
- `session.playerCountLabels.max`

Runtime usage is limited to `assets/js/core/session/sessionFormHelpers.js`.
The visible output remains `min` / `max`, and the previous strings are still
local fallbacks.

Not changed:

- calendar labels
- `mypageAuthClient.js` or the normal-script bridge
- Discord sync labels
- GM/admin controls
- application/comment UI
- membership management UI
- status/visibility enum labels
- player-count formatter wording
- DB/RPC/enum/status/role/CSS class/DOM id/input name surfaces

Detailed result:

- `docs/reusable-ops-platform-phase3a1-config-label-minimal-result.md`

## Phase 3-A2 Follow-Up

Phase 3-A2 checked public static delivery for the Phase 3-A1 player-count
sublabel config connection.

Confirmed:

- public `session-post.html` follows
  `20260616-session-post-player-count-labels`
- public `main.js`, `renderSessionPost.js`, `sessionFormHelpers.js`, and
  `reusableOpsConfig.js` follow the expected import/export chain
- public `sessionFormHelpers.js` still exports `renderPlayerCountFields`
- public `reusableOpsConfig.js` contains `session.playerCountLabels` and
  exports `getOpsSessionPlayerCountLabel`
- public player-count inputs keep `name="p_player_min"`,
  `name="p_player_max"`, and `min="0"`
- no new implementation or label configuration was performed

Detailed result:

- `docs/reusable-ops-platform-phase3a2-session-player-count-label-public-check.md`
