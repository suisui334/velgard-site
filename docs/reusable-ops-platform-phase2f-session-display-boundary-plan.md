# Reusable Ops Platform Phase 2-F Session Display Boundary Plan

## Background

Phase 2-D moved the calendar renderer to
`assets/js/core/calendar/renderCalendar.js`. Phase 2-E confirmed public
delivery for the moved renderer. After that rollout, the calendar was checked
in a browser with an approved signed-in session.

This gate records that browser QA result and audits whether
`assets/js/sessionDisplay.js` can move into the reusable operations core.

No file movement or implementation change was performed in this gate.

## Calendar Browser QA Result

User-side browser QA after the calendar renderer core move:

| check_name | status | result_value | note |
| --- | --- | --- | --- |
| `approved_calendar_display` | `pass` | `visible=true` | Calendar displayed correctly while signed in as an approved user. |
| `calendar_month_navigation` | `pass` | `month_move_ok=true` | Month movement worked. |
| `calendar_today_button` | `pass` | `today_button_ok=true` | The today button worked. |
| `calendar_session_type_labels_colors` | `pass` | `labels_and_colors_ok=true` | Session type labels and color classes were preserved. |
| `calendar_closed_and_gm_display` | `pass` | `no_breakage=true` | Closed-session mark and GM-name display were fine where applicable. |
| `calendar_session_detail_link` | `pass` | `detail_navigation_ok=true` | Session-detail navigation worked. |
| `calendar_bad_label_markers` | `pass` | `bad_markers=false` | No visible `undefined`, `[object Object]`, empty heading, or empty label was observed. |
| `calendar_sensitive_values_recorded` | `pass` | `recorded=false` | No real id, JWT, email, user id, session id, or similar value was recorded. |

Conclusion:

- `calendar_core_move_browser_qa=true`
- `calendar_renderer_move_ready_for_next_boundary_audit=true`

## sessionDisplay.js Responsibility

`assets/js/sessionDisplay.js` is a shared session display module. It currently
combines several kinds of responsibility:

- basic HTML escaping through `escapeHtml`
- session status and visibility labels
- session type label lookup via `reusableOpsConfig`
- closed-session helpers using the `closed` status and the leading `〆` mark
- session title formatting
- session date/time/deadline/tool/player-count formatting
- updated-at formatting
- session tag rendering
- generic detail row rendering
- Discord sync status and last-action display labels
- Discord sync panel HTML for session-detail management
- session-detail manage row HTML, including edit/close/delete controls
- session summary HTML
- read-only participation-comment panel HTML
- full session-detail content HTML

This makes it a reusable-ops candidate, but not a small pure utility yet.

## Import And Dependency Map

Imports used by `sessionDisplay.js`:

- `assets/js/core/config/reusableOpsConfig.js`
  - `getOpsSessionLabel`
  - `getOpsSessionTypeLabel`

Known importers of `sessionDisplay.js`:

- `assets/js/core/calendar/renderCalendar.js`
  - imports title, status, time, player-count, tag, closed-session, and
    escaping helpers.
- `assets/js/renderSessionPost.js`
  - imports `escapeHtml`, `getSessionStatusLabel`, and
    `getSessionTypeLabel`.
- `assets/js/renderSessionDetail.js`
  - imports `escapeHtml`, title/closing helpers,
    `renderSessionDiscordSyncPanel`, and `renderSessionDetailContent`.
- `assets/js/renderAdminCapAnnouncements.js`
  - imports `escapeHtml`.

Current dependency direction:

- `core/calendar/renderCalendar.js` already imports back upward to
  `../../sessionDisplay.js`.
- If `sessionDisplay.js` moved to `assets/js/core/session/sessionDisplay.js`,
  `renderCalendar.js` could import it by a shorter core-relative path.
- Root modules such as `renderSessionPost.js`, `renderSessionDetail.js`, and
  `renderAdminCapAnnouncements.js` would need path and cache-bust updates.

## Core Move Classification

Decision for this gate:

`sessionDisplay.js` is classification **D: core-oriented, but should be split
before moving**.

Reason:

- The pure helper portions are good reusable core candidates.
- The module also renders session-detail management HTML, Discord sync panel
  HTML, and participation-comment panel HTML.
- Those panels touch owner/GM/admin management, Discord sync display, comment
  application UI, and approved-gate-adjacent surfaces.
- Moving the whole file now would be a broad runtime dependency change for
  calendar, session-post, session-detail, and admin-cap announcement rendering.
- The file currently contains both low-risk formatting helpers and higher-risk
  UI block renderers. A physical move before splitting would make later
  responsibility boundaries harder to see.

Therefore, do not move `sessionDisplay.js` yet.

## Recommended Pre-Work Before Moving

Before a physical move, split responsibilities in place:

1. Identify pure helpers:
   - `escapeHtml`
   - status/visibility/type label helpers
   - title and closing-mark helpers
   - time/deadline/tool/player-count/updated-at formatters
   - simple tag/detail-row renderers
2. Keep session-detail UI block renderers separate:
   - `renderSessionDiscordSyncPanel`
   - session manage row renderer
   - participation-comment panel renderer
   - `renderSessionDetailContent`
3. Add a docs-only export map before implementation:
   - which functions are used by calendar
   - which functions are used by session-post
   - which functions are used by session-detail
   - which functions are only session-detail management UI
4. Move only the pure helper subset first if a future gate chooses to proceed.
5. Move the session-detail UI block renderers only after session-detail and
   Discord sync QA gates are available.

## Future Move Procedure

Suggested future path if the split is accepted:

1. Create `assets/js/core/session/sessionDisplay.js` or
   `assets/js/core/session/sessionFormatters.js` for pure helpers.
2. Update only the helper importers first:
   - `assets/js/core/calendar/renderCalendar.js`
   - `assets/js/renderSessionPost.js`
   - `assets/js/renderAdminCapAnnouncements.js`
3. Leave session-detail panel renderers in the root module until their
   responsibilities are separated.
4. Run syntax checks for all changed JS.
5. Update HTML/module cache-bust only where needed.
6. Verify calendar, session-post, session-detail, approved gate, GM management,
   Discord sync panel display, and admin-cap announcements.

## Move-Time QA Points

If a future gate moves any part of `sessionDisplay.js`, verify:

- calendar renders
- session type labels and colors remain unchanged
- closed-session `〆` display remains unchanged
- GM name display remains unchanged
- session-detail page renders
- session-detail management row appears only for allowed users
- close/close-remove labels and overdue note remain correct
- Discord sync panel display remains intact
- session-post form status/type labels remain intact
- admin cap announcement rendering still escapes text correctly
- no `undefined`, `[object Object]`, empty label, raw id, email, token, JWT, or
  `management_key` appears

## Files Not Moved

This gate did not move:

- `assets/js/sessionDisplay.js`
- `assets/js/main.js`
- `assets/js/sessionData.js`
- `assets/js/renderSessionPost.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/mypageAuthClient.js`
- `assets/js/membershipAccessClient.js`
- `assets/js/discordSyncClient.js`
- `assets/css/style.css`

## Prohibited Work Confirmed

This gate did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge Function deploy, Discord operation, secret or webhook change,
direct Supabase write addition, `console.*` addition, `updates.json` change,
auth/permission logic change, RPC/DB-key configuration, `management_key`
display/DOM exposure, raw user id/email/token/JWT display, file movement, CSS
split, or independent app extraction.

## Phase 2-G Follow-Up

Phase 2-G implemented the first minimal split based on this plan.

- Created `assets/js/core/session/sessionDisplayHelpers.js`.
- Moved only pure helper functions: escaping, session status/visibility/type
  labels, title/closing-mark helpers, time/deadline/tool/player-count
  formatters, and updated-at formatting.
- Kept `assets/js/sessionDisplay.js` in place and re-exported the existing
  public helper API for compatibility.
- Left Discord sync panel rendering, session-detail management row rendering,
  participation-comment panel rendering, and `renderSessionDetailContent` in
  `sessionDisplay.js`.
- Did not change auth, approved gate logic, owner/admin checks, RPC/DB/RLS
  contracts, Discord sync behavior, or `management_key` handling.

Detailed result:

- `docs/reusable-ops-platform-phase2g-session-helper-extraction-result.md`

## Phase 2-H Public Rollout Follow-Up

Phase 2-H verified the public delivery surface after the Phase 2-G helper
split. The new `assets/js/core/session/sessionDisplayHelpers.js` path is
served, and `sessionDisplay.js` publicly imports it through the compatibility
facade.

The active public entry points for calendar, session-post, session-detail, and
admin cap announcements use the `20260615-session-helper-extract` cache-bust.
No broken import path was found. Authenticated UI behavior remains a separate
QA gate.

Detailed result:

- `docs/reusable-ops-platform-phase2h-session-helper-public-check.md`
