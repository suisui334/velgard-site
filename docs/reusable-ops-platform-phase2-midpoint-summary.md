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

- Session-post field helper extraction.
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
