# Reusable Ops Platform Phase 2-I Session UI Helper Plan

## Background

Phase 2-G extracted pure session display helpers into:

- `assets/js/core/session/sessionDisplayHelpers.js`

Phase 2-H confirmed the public rollout of that helper extraction. This Phase
2-I audit reviews the remaining session UI helper surface and identifies which
small HTML row/helper functions can move later without moving the whole
`sessionDisplay.js` module.

This gate is docs-only. It does not change implementation, imports, CSS,
DB/RPC/RLS, auth, approved/owner/admin checks, Discord sync, direct Supabase
writes, or `management_key` handling.

## Files Reviewed

- `assets/js/sessionDisplay.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/renderSessionPost.js`
- `assets/js/core/session/sessionDisplayHelpers.js`
- `assets/js/core/calendar/renderCalendar.js`
- `assets/js/main.js`
- Adjacent session-detail application/comment rendering was lightly checked as
  an exclusion surface because it owns many DOM/event/RPC flows.

## Candidate Classification

| candidate | current file | classification | reason |
| --- | --- | --- | --- |
| `renderSessionDetailRow(label, value, options)` | `assets/js/sessionDisplay.js` | A | Small pure HTML string helper. It escapes label/value, skips empty values, and has no DOM mutation, event binding, auth, RPC, or Discord dependency. |
| `renderSessionDetailArrayRow(label, values)` | `assets/js/sessionDisplay.js` | A | Thin pure wrapper around `renderSessionDetailRow`. Good first candidate after row-helper public QA is planned. |
| `renderSessionTags(tags)` | `assets/js/sessionDisplay.js` | B | Small pure HTML string helper, but the class name is calendar-flavored. Move only after deciding whether `calendar-session-tags` is acceptable in core or should be renamed behind a compatibility class. |
| `renderSessionSummary(session)` | `assets/js/sessionDisplay.js` | B | Small pure HTML string helper, but it uses modal/detail CSS classes. It can move after summary block naming and fallback labels are settled. |
| basic `detailBlocks` construction inside `renderSessionDetailContent` | `assets/js/sessionDisplay.js` | B | Detail/requirements sections are simple, but currently embedded in the larger detail renderer. Extract only after row/tag helpers are stable. |
| `renderSessionBadges(sessions)` | `assets/js/core/calendar/renderCalendar.js` | B | Small calendar badge renderer for date cells. It depends on calendar route/class helpers and GM/closed-title display. Candidate after a calendar-specific helper module boundary is defined. |
| `renderTextField`, `renderSelectField`, `renderTextareaField` | `assets/js/renderSessionPost.js` | B | Small pure form-field HTML helpers. They are session-post class-specific and use form names/labels, so they should move only after a `sessionFormFields` boundary is defined. |
| `renderPlayerCountFields` | `assets/js/renderSessionPost.js` | B | Small form group, but more session-post-specific than the generic field helpers. Good later candidate if field helpers move first. |
| `renderBackLinks(date)` and `calendarHref(date)` | `assets/js/renderSessionDetail.js` | B | Small navigation helpers. They are safe-looking, but route labels and page links are app/site navigation concerns, so move only after route helper conventions are set. |
| `renderSessionCard(session)` | `assets/js/core/calendar/renderCalendar.js` | C | Larger card renderer that combines detail links, type classes, state labels, meta rows, summary, tags, and actions. Split smaller helpers first. |
| `renderSessionDetailContent(session, options)` | `assets/js/sessionDisplay.js` | C | Main detail content renderer. It combines rows, summary, detail blocks, management row, supplemental rows, and application panel selection. Do not move before its child helpers are separated. |
| `renderShell`, `renderNotFound`, `renderSessionPage` | `assets/js/renderSessionDetail.js` | C | Page-level rendering, document title, back links, and detail content composition. Keep in page renderer. |
| `renderSessionPostTemplatePanel` | `assets/js/renderSessionPost.js` | C | Template management UI block with controls, preset state, and later event handling. Not a small row helper. |
| `renderManagedSessionOption` | `assets/js/renderSessionPost.js` | C | Small string helper but tied to edit-mode state, managed session selection, and index-based UI state. Avoid as an early extraction. |
| `renderResult(target, result)` | `assets/js/renderSessionPost.js` | C | Mutates DOM via `target.innerHTML`; keep in session-post renderer. |
| `renderSessionDiscordSyncPanel(session)` | `assets/js/sessionDisplay.js` | D | Whole Discord sync panel. It exposes sync status display and must stay with a dedicated Discord-sync display gate. |
| `getDiscordSyncStatusLabel`, `getDiscordLastActionLabel`, `getDiscordSyncFields` | `assets/js/sessionDisplay.js` | D | Smaller than the panel, but still Discord-sync specific. Extract only under a Discord sync adapter/display gate, not a generic session row helper gate. |
| `renderSessionDetailManageRow(session, options)` | `assets/js/sessionDisplay.js` | D | Management buttons, data attributes, and permission-adjacent UI. Do not extract in a generic helper gate. |
| `renderSessionApplicationPanel(session)` | `assets/js/sessionDisplay.js` | D | Participation/comment panel shell. Adjacent to auth state, RPC-backed comment UI, and approved gate behavior. |
| `showDiscordSyncPanel`, `hideDiscordSyncPanel`, `configureClosingMarkControl` | `assets/js/renderSessionDetail.js` | D | DOM mutation, button state, event binding, owner/GM operation flow, or Discord panel wiring. |
| session-detail application/comment row builders | `assets/js/sessionDetailApplicationComments.js` | D | Dense DOM creation with RPC calls, edit/delete/withdraw/GM action flows, avatar preview, templates, and events. Keep out of this extraction track. |
| `renderMembershipGateNotice` | `assets/js/membershipAccessClient.js` | D | Approved gate/auth membership surface. Not a session UI helper extraction target. |

Classification key:

- A: likely safe to extract directly into a core helper module.
- B: likely extractable after naming/fallback/class boundary cleanup.
- C: too coupled to a UI block or page renderer for this early split.
- D: too close to auth, permission, RPC, Discord sync, or management actions.
- E: not enough information yet.

## Recommended Future Module Names

Do not create these modules in this gate. Suggested future split names:

- `assets/js/core/session/sessionHtmlHelpers.js`
  - `renderSessionDetailRow`
  - `renderSessionDetailArrayRow`
  - possibly `renderSessionTags`
- `assets/js/core/session/sessionUiRows.js`
  - session detail metadata rows and simple detail/requirements blocks, if the
    project wants a row-oriented naming convention.
- `assets/js/core/session/sessionBadges.js`
  - calendar date-cell session badges only after calendar route/class
    dependencies are isolated.
- `assets/js/core/session/sessionFormFields.js`
  - session-post field helpers after confirming field class names and form
    names should remain stable.

The lowest-risk first implementation gate is `sessionHtmlHelpers.js` with only
`renderSessionDetailRow` and `renderSessionDetailArrayRow`. Add
`renderSessionTags` only if keeping the existing `calendar-session-tags` class
inside core is accepted.

## Suggested Future Extraction Order

1. Extract `renderSessionDetailRow` and `renderSessionDetailArrayRow`.
2. Optionally extract `renderSessionTags` after deciding CSS class naming.
3. Optionally extract `renderSessionSummary` and simple detail/requirements
   section helpers.
4. Audit `renderTextField`, `renderSelectField`, and `renderTextareaField` for
   a session-post form-field helper module.
5. Only after those smaller splits, revisit `renderSessionDetailContent`.

## Keep In Place For Now

Do not extract in the next low-risk gate:

- Discord sync panel and sync status helpers
- session-detail management row
- close/close-remove button wiring
- application/comment panel and comment list rendering
- GM history and GM application action rendering
- template preset management UI
- page shells and root renderers
- any helper that creates event listeners, calls RPCs, reads auth state, or
  handles internal ids

## QA Points For A Future Extraction Gate

If a later gate extracts small HTML helpers, verify:

- calendar renders
- session-post renders
- session-detail renders
- session tags still render
- session-detail metadata rows still skip empty values
- session type labels and colors remain unchanged
- closed-session mark and GM-name display remain unchanged
- approved gate still behaves the same
- Discord sync panel display remains unchanged
- application/comment UI remains unchanged
- no `undefined`, `[object Object]`, empty label, raw id, email, token, JWT, or
  `management_key` appears

## Result

Phase 2-I result: docs-only audit completed.

No implementation change, file move, import/export change, CSS change, SQL
Editor execution, DB/RPC/RLS mutation, Edge deploy, Discord operation, direct
Supabase write, `console.*` addition, `updates.json` change, auth/permission
logic change, RPC/DB key configuration, `management_key` display, or raw
id/email/token/JWT display was performed.

## Phase 2-J Implementation Follow-Up

Phase 2-J implemented the narrow first extraction recommended by this audit.

- Created `assets/js/core/session/sessionHtmlHelpers.js`.
- Moved only `renderSessionDetailRow` and
  `renderSessionDetailArrayRow`.
- Kept `assets/js/sessionDisplay.js` as the compatibility facade and
  re-export source for existing importers.
- Did not extract `renderSessionTags`, `renderSessionSummary`, field helpers,
  Discord sync panel, management row, application/comment UI, or any
  auth/RPC/event-adjacent helper.

Detailed result:

- `docs/reusable-ops-platform-phase2j-session-row-helper-result.md`

## Phase 2-K Public Check Follow-Up

Phase 2-K checked public delivery after the row helper extraction.

- Public `session-detail.html`, `session-post.html`, and `calendar.html`
  reference `main.js` with `20260615-session-row-helper-extract`.
- Public `sessionDisplay.js` imports
  `assets/js/core/session/sessionHtmlHelpers.js`.
- Public `assets/js/core/session/sessionHtmlHelpers.js` is served
  successfully and exports both row helpers.
- No broken row-helper import path or required cache-bust repair was found.
- Authenticated role-specific browser operation was not performed by Codex in
  this gate and remains a separate QA gate.

Detailed result:

- `docs/reusable-ops-platform-phase2k-session-row-helper-public-check.md`

## Phase 2-L Follow-Up

Phase 2-L reviewed and extracted the next two small helper candidates:

- `renderSessionTags`
- `renderSessionSummary`

Both moved into `assets/js/core/session/sessionHtmlHelpers.js`, while
`sessionDisplay.js` remains the compatibility facade and re-exports them.

Compatibility note:

- Existing CSS class names such as `calendar-session-tags` and
  `calendar-session-modal-summary-block` were kept to avoid display changes.
- A future class-name cleanup should be handled as a separate visual/CSS gate.

Detailed result:

- `docs/reusable-ops-platform-phase2l-session-summary-tags-plan.md`
