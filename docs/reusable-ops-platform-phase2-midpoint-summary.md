# Reusable Ops Platform Phase 2 Midpoint Summary

## Background

Phase 2 is the first physical separation track for the reusable TRPG operations
platform. The goal is not to create an independent app yet. The current goal is
to move or extract low-risk pieces first, while keeping authentication,
permissions, RPC contracts, Discord sync, and large page renderers stable.

This summary records the midpoint after Phase 2-M.

## Phase 1 Foundation

Phase 1 prepared configuration entry points before any physical file movement.

- Added the reusable operations configuration entry.
- Connected calendar session type labels, type classes, and selected calendar
  copy to the configuration surface.
- Connected part of session-post, session-detail, and approved gate labels to
  the configuration surface.
- Added the mypage label bridge for normal-script use.
- Kept fallback labels so pages do not fail if configuration is unavailable.
- Completed public rollout checks for the config-based labels.

The important Phase 1 outcome is that display labels and colors started moving
behind configuration while auth, permissions, RPC names, DB columns, and
membership state remained code/DB responsibilities.

## Files Moved Or Added Under Core

The following files now live under `assets/js/core/` and are part of the
reusable operations core candidate surface.

| path | status | role |
| --- | --- | --- |
| `assets/js/core/config/reusableOpsConfig.js` | moved | Shared display/config entry for reusable operations labels, session type labels, and session type class mapping. |
| `assets/js/core/config/reusableOpsMypageLabels.js` | moved | Normal-script bridge for mypage label access. |
| `assets/js/core/calendar/renderCalendar.js` | moved | Calendar renderer. Public delivery and browser checks found no obvious issue after the move. |
| `assets/js/core/session/sessionDisplayHelpers.js` | added | Pure session display formatters and label helpers extracted from `sessionDisplay.js`. |
| `assets/js/core/session/sessionHtmlHelpers.js` | added | Small pure HTML string helpers extracted from `sessionDisplay.js`. |

## Extracted Session Helpers

`assets/js/sessionDisplay.js` remains in place as the compatibility facade.
Existing importers continue to import from `sessionDisplay.js`, while it imports
and re-exports helpers from the core modules.

Extracted pure display helpers include:

- `escapeHtml`
- `formatPlayerCount`
- `formatSessionApplicationDeadline`
- `formatSessionTime`
- `formatSessionTool`
- `formatSessionUpdatedAt`
- `getSessionDisplayTitle`
- `getSessionStatusClass`
- `getSessionStatusLabel`
- `getSessionTitle`
- `getSessionTitleWithoutClosingMark`
- `getSessionTypeLabel`
- `getSessionVisibilityLabel`
- `hasSessionClosingMark`
- `isClosedSession`
- `shouldShowSessionState`

Extracted small HTML helpers include:

- `renderSessionDetailRow`
- `renderSessionDetailArrayRow`
- `renderSessionTags`
- `renderSessionSummary`

Compatibility notes:

- Existing CSS class names were retained to avoid visual changes.
- `sessionDisplay.js` was not moved wholesale.
- `renderSessionDetailContent`, Discord sync, GM/admin management, application
  and comment UI, event handlers, auth/permission checks, RPC calls, and
  internal-id surfaces remain outside the extraction track.

## Public Rollout Checks Completed

Static/public delivery checks completed so far:

- Phase 2-C: `core/config` move public rollout.
- Phase 2-E: calendar renderer move public rollout.
- Phase 2-H: `sessionDisplayHelpers.js` public rollout.
- Phase 2-K: `sessionHtmlHelpers.js` row helper public rollout.

Browser/light visual checks completed so far:

- Calendar renderer move: user-side browser QA found calendar display, month
  navigation, today button, session type labels/colors, closing mark, GM name,
  and session-detail navigation acceptable within the checked scope.
- Summary/tag helper extraction: user-side lightweight visual check found no
  clearly strange display or prominent layout breakage.

These checks do not replace detailed authenticated functional QA.

## Files Not To Move Yet

The following files should not be moved or broadly split yet.

| file | reason to keep in place |
| --- | --- |
| `assets/js/main.js` | Central route/bootstrap file. Splitting it affects every page and cache-bust chain. |
| `assets/js/sessionData.js` | Holds session loading/data-normalization behavior and the static JSON retirement boundary. High blast radius. |
| `assets/js/sessionDisplay.js` | Still hosts large UI blocks and acts as the compatibility facade for extracted helpers. Move only after more renderer boundaries are stable. |
| `assets/js/mypageAuthClient.js` | Contains auth, membership status, profile, templates, membership management UI, and RPC-adjacent logic. |
| `assets/js/renderSessionPost.js` | Hosts session-post form, template UI, save flow, validation, and Discord-adjacent post behavior. |
| `assets/js/renderSessionDetail.js` | Hosts session-detail page behavior and connects with application/comment and management surfaces. |
| `assets/js/membershipAccessClient.js` | Close to membership status and approved gate behavior. |
| `assets/js/discordSyncClient.js` | Close to Discord sync state and external posting control. |
| `assets/css/style.css` | Mixed global, world-site, and operations styles. Splitting it has broad visual risk. |

## Risk-Based Next Candidates

### Low Risk

- Additional small pure HTML helper extraction after public checks.
- Pure session formatter cleanup where no DOM, event, auth, RPC, or Discord
  behavior is involved.
- `reusableOpsConfig` label coverage audit for remaining hard-coded display
  text.
- Documentation consolidation and dependency maps.
- Public rollout checks after each cache-bust chain change.

### Medium Risk

- Additional session-post field/helper extraction beyond the three basic field
  renderers.
- Small session-detail sub-block extraction, excluding actions and role checks.
- Regulation template structure detailing for tables, term cards, long-form
  cards, and side menu behavior.
- Regulation-specific CSS organization notes or tiny page-scoped cleanup.

### High Risk

- Splitting `main.js`.
- Moving `sessionData.js`.
- Splitting `mypageAuthClient.js`.
- Splitting `style.css`.
- Separating Discord sync modules from session-post/detail flows.
- Any DB/RPC/RLS-adjacent restructuring.

High-risk items should stay behind explicit gates with rollback and QA plans.

## QA Status

| QA type | status | notes |
| --- | --- | --- |
| Static delivery checks | partially complete | Completed for config move, calendar renderer move, pure session helper move, and row helper move. Summary/tag helper static public delivery can be checked in a future gate if stricter evidence is needed. |
| Light visual checks | partially complete | Calendar move and summary/tag helper extraction have user-side lightweight checks recorded. |
| Authenticated browser QA | limited / not complete | Role-specific session-detail, session-post, calendar, approved gate, Discord sync panel, GM/admin UI, and application/comment surfaces remain separate gates. |
| Data-changing QA | not in this track | Any test that creates, edits, deletes, closes sessions, posts comments, changes applications, or touches Discord sync must stay behind explicit gates. |

## Immediate Recommendations

1. Prefer a Phase 2-N static public rollout check for
   `20260615-session-summary-tags-extract` before extracting more helpers.
2. Keep `sessionDisplay.js` as the facade until all small helper extractions
   have public checks.
3. Do not split `main.js`, `sessionData.js`, `mypageAuthClient.js`, or
   `style.css` without a dedicated migration plan.
4. Continue separating documentation-only planning from implementation gates.
5. For the next implementation gate, prefer a tiny pure helper extraction over
   a page renderer move.

## Result

Phase 2 midpoint status: healthy but intentionally conservative.

The project now has a visible reusable operations core directory and several
small session helpers extracted, while high-risk auth/RPC/Discord/UI-block
surfaces remain stable in their original files.

## Phase 2-N Follow-Up: Session Post Field Helper Audit

Phase 2-N reviewed `assets/js/renderSessionPost.js` for small form helper
extraction candidates.

Result: documentation-only. No helper was moved in this gate.

Findings:

- `renderTextField`, `renderSelectField`, and `renderTextareaField` are the
  safest future extraction candidates.
- `renderPlayerCountFields`, `formatPlayerCountLabel`, and managed-session
  option rendering need more label/fallback or ownership decisions before
  moving.
- Template UI, Discord mention UI, result rendering, payload builders,
  validation, RPC calls, save/delete flows, auth/access checks, and event
  registration remain out of scope for core helper extraction.
- `renderSessionPost.js` should remain the page orchestrator for now because it
  still combines form rendering, templates, persistence, Discord sync, and
  access flow.

Detailed plan:

- `docs/reusable-ops-platform-phase2n-session-post-field-helper-plan.md`

## Phase 2-O Follow-Up: Session Post Field Helper Extraction

Phase 2-O implemented the narrow extraction identified in Phase 2-N.

Moved to `assets/js/core/session/sessionFormHelpers.js`:

- `renderTextField`
- `renderSelectField`
- `renderTextareaField`

`assets/js/renderSessionPost.js` now imports those helpers and remains the
session-post page orchestrator. The helper destination is session-scoped rather
than generic form-scoped because the emitted markup still uses
`session-post-field` class names.

Not changed:

- player count fields
- template UI and template RPC behavior
- payload builders and validation
- create/update/delete RPC flows
- Discord mention and Discord sync behavior
- auth/access/approved gate logic
- event handler registration

Detailed result:

- `docs/reusable-ops-platform-phase2o-session-post-field-helper-result.md`

## Phase 2-P Follow-Up: Session Post Field Helper Public Check

Phase 2-P checked the public delivery chain after the session-post field helper
extraction.

Confirmed:

- public `session-post.html` has the
  `20260615-session-post-field-helper-extract` main-module cache-bust
- public `main.js` imports the updated `renderSessionPost.js`
- public `renderSessionPost.js` imports the new `sessionFormHelpers.js`
- public `sessionFormHelpers.js` is served and exports `renderTextField`,
  `renderSelectField`, and `renderTextareaField`
- public `calendar.html` and `session-detail.html` returned `status=200`

Not tested:

- authenticated role-specific session-post UI
- data-changing create/edit/delete flows
- template operation QA
- Discord sync QA

Detailed result:

- `docs/reusable-ops-platform-phase2p-session-post-field-helper-public-check.md`

## Phase 2-Q Follow-Up: Session Post Player Count Helper Audit

Phase 2-Q reviewed the next player-count candidates after the basic field
helper rollout.

Reviewed:

- `renderPlayerCountFields`
- `formatPlayerCountLabel`

Decision: documentation-only. No helper was moved.

Summary:

- `renderPlayerCountFields` is mostly a display helper, but its
  `p_player_min` / `p_player_max` input names are part of the session-post
  payload, template field, template application, managed edit, and reset
  contract.
- `formatPlayerCountLabel` is pure string formatting, but player-count range,
  min-only, max-only, and unset wording should be deliberately kept or
  configured before extraction.
- Both are classified as `B`: extractable later after fallback/config and QA
  planning.

Detailed plan:

- `docs/reusable-ops-platform-phase2q-session-post-player-count-helper-plan.md`

## Phase 2-R Follow-Up: Player Count Behavior Spec

Phase 2-R kept the gate documentation-only and fixed the current player-count
behavior before any extraction.

Added:

- `docs/reusable-ops-platform-phase2r-player-count-behavior-spec.md`

Recorded:

- `renderPlayerCountFields` emits two numeric controls named `p_player_min` and
  `p_player_max`
- both controls currently have `min="0"` and no `required`, `placeholder`,
  `max`, custom class, id, or initial value
- the field names are part of payload generation, template save/apply, managed
  edit restore, and new-session reset behavior
- `formatPlayerCountLabel` keeps the current range, same-value range,
  min-only, max-only, zero, missing, and raw-string fallback behavior
- Discord sync does not depend on the renderer directly, but the saved payload
  still carries these values through create/update flows

Decision:

- `formatPlayerCountLabel` may be the first future extraction candidate if the
  exact output contract is preserved.
- `renderPlayerCountFields` should move only in a dedicated gate with
  template, edit, reset, and payload QA.

No JS, CSS, data, file move, SQL, DB/RPC/RLS, Discord, auth, permission, or
runtime behavior change was made.

## Phase 2-S Follow-Up: Player Count Label Helper Extraction

Phase 2-S extracted only `formatPlayerCountLabel` into:

- `assets/js/core/session/sessionPlayerCountHelpers.js`

`assets/js/renderSessionPost.js` remains the session-post orchestrator and now
imports the helper. The session-post cache-bust chain was updated to
`20260616-player-count-label-helper`.

Preserved:

- Phase 2-R player-count fallback matrix
- `renderPlayerCountFields` in place
- `p_player_min` / `p_player_max` markup and field-name contract
- payload generation, template save/apply, managed edit restore, reset,
  Discord sync, auth, permission, RPC, and DB behavior

Local smoke test:

- 13 cases passed

Detailed result:

- `docs/reusable-ops-platform-phase2s-player-count-label-helper-result.md`

## Phase 2-T Follow-Up: Player Count Label Helper Public Check

Phase 2-T confirmed the public static delivery chain after the player-count
label helper extraction.

Confirmed:

- public `session-post.html`, `main.js`, `renderSessionPost.js`, and
  `sessionPlayerCountHelpers.js` returned HTTP 200
- public `session-post.html` uses the
  `20260616-player-count-label-helper` main-module cache-bust
- public `main.js` imports `renderSessionPost.js` with the same cache-bust
- public `renderSessionPost.js` imports the new helper and does not keep the
  old local formatter definition
- public `renderPlayerCountFields` stays in `renderSessionPost.js`
- public `calendar.html` and `session-detail.html` returned HTTP 200

Authenticated operation and data-changing QA remain separate gates.

Detailed result:

- `docs/reusable-ops-platform-phase2t-player-count-label-helper-public-check.md`

## Phase 2-U Follow-Up: Player Count Field Helper Extraction

Phase 2-U extracted only `renderPlayerCountFields` into:

- `assets/js/core/session/sessionFormHelpers.js`

`assets/js/renderSessionPost.js` remains the session-post orchestrator and now
passes the same configured label into the helper. The session-post cache-bust
chain was updated to `20260616-player-count-field-helper`.

Preserved:

- `p_player_min` / `p_player_max` names and attributes
- Phase 2-R player-count field HTML contract
- payload generation, template save/apply, managed edit restore, reset,
  Discord sync, auth, permission, RPC, and DB behavior

Local checks:

- player-count field snapshot: ok
- module import / import-cycle smoke: ok

Detailed result:

- `docs/reusable-ops-platform-phase2u-player-count-field-helper-result.md`

## Phase 2-V Follow-Up: Player Count Field Helper Public Check

Phase 2-V checked the public delivery chain after the
`renderPlayerCountFields` extraction.

Confirmed:

- public `session-post.html` has the
  `20260616-player-count-field-helper` main-module cache-bust
- public `main.js` imports the matching `renderSessionPost.js`
- public `renderSessionPost.js` imports `renderPlayerCountFields` from
  `assets/js/core/session/sessionFormHelpers.js`
- public `sessionFormHelpers.js` is served and exports
  `renderPlayerCountFields`
- public `sessionPlayerCountHelpers.js` is served and exports
  `formatPlayerCountLabel`
- public `calendar.html` and `session-detail.html` are still served
- the public player-count block keeps `p_player_min`, `p_player_max`, and
  `min="0"` without adding required/placeholder/value/max attributes

Not tested:

- authenticated role-specific session-post operation
- template save/apply
- managed edit restore
- reset operation
- data-changing create/edit/delete
- Discord sync

Detailed result:

- `docs/reusable-ops-platform-phase2v-player-count-field-helper-public-check.md`

## Phase 2-W Late Summary

Phase 2-W added a documentation-only late summary for the session-post helper
extraction track after the midpoint summary.

Covered range:

- Phase 2-N session-post helper audit
- Phase 2-O/P basic field helper extraction and public rollout
- Phase 2-Q/R player-count boundary audit and behavior spec
- Phase 2-S/T `formatPlayerCountLabel` extraction and public rollout
- Phase 2-U/V `renderPlayerCountFields` extraction and public rollout

The summary also refreshes:

- current `assets/js/core/` structure
- files that should not move yet
- completed, limited, and not-tested QA scopes
- next candidates by risk

Detailed summary:

- `docs/reusable-ops-platform-phase2-late-summary.md`

## Phase 2-X Follow-Up: Reusable Ops Config Label Gap Audit

Phase 2-X audited remaining hard-coded display labels around the reusable ops
surface without changing implementation.

Recorded:

- current `reusableOpsConfig` and `reusableOpsMypageLabels` coverage
- labels already connected to config
- A/B/C/D/E classification for unconnected label candidates
- normal-script vs module-script config access boundary
- values that must not be configured, such as DB/RPC keys, enum stored values,
  DOM ids, CSS classes, input names, role keys, `management_key`, and raw
  id/email/token/JWT-related values

Detailed plan:

- `docs/reusable-ops-platform-phase2x-config-label-gap-plan.md`

## Phase 2 Completion Follow-Up

The midpoint summary remains useful as the record for Phase 2-A through
Phase 2-M. Phase 2-N through Phase 2-Z continued the same conservative
approach, and Phase 2-AA now closes the full Phase 2 track.

Current completion reference:

- `docs/reusable-ops-platform-phase2-completion-summary.md`

Phase 2 completion does not mean the entire reusable platform extraction is
finished. It means the initial `core/config`, `core/calendar`, and
`core/session` helper separation is complete, while larger page orchestrators,
auth/RPC/DB behavior, Discord sync, CSS splitting, and authenticated
data-changing QA remain Phase 3 or later work.
