# Phase 2-X Reusable Ops Config Label Gap Plan

## Background

Phase 1 introduced `reusableOpsConfig`, and Phase 2 moved the config files into
`assets/js/core/config/`. Later Phase 2 work extracted small session display,
HTML, and session-post form helpers into `assets/js/core/session/`.

This Phase 2-X audit reviews display labels that still remain hard-coded in
operations-facing pages and modules. It does not change implementation.

Goal:

- identify labels that can move safely toward `reusableOpsConfig`
- separate labels that require fallback/behavior specs first
- keep DB/RPC/permission/internal identifiers out of config

## Investigated Files

Primary files reviewed:

- `assets/js/core/config/reusableOpsConfig.js`
- `assets/js/core/config/reusableOpsMypageLabels.js`
- `assets/js/membershipAccessClient.js`
- `assets/js/mypageAuthClient.js`
- `assets/js/renderSessionPost.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/sessionDisplay.js`
- `assets/js/core/session/sessionDisplayHelpers.js`
- `assets/js/core/session/sessionHtmlHelpers.js`
- `assets/js/core/session/sessionFormHelpers.js`
- `assets/js/core/session/sessionPlayerCountHelpers.js`
- `assets/js/core/calendar/renderCalendar.js`
- `assets/js/main.js`
- `calendar.html`
- `session-detail.html`
- `session-post.html`
- `mypage.html`

## Current Config Surface

`assets/js/core/config/reusableOpsConfig.js` currently contains:

- site/world display names
- calendar button labels
- session type labels, color names, and calendar classes
- membership approved-gate labels
- mypage section and summary labels
- mypage membership status and membership action labels
- session-post/detail/session-display labels

Connected module-script users:

- `assets/js/core/calendar/renderCalendar.js`
- `assets/js/membershipAccessClient.js`
- `assets/js/renderSessionPost.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/core/session/sessionDisplayHelpers.js`

`assets/js/core/config/reusableOpsMypageLabels.js` currently bridges a smaller
subset into the normal-script mypage client:

- mypage section labels
- mypage summary labels

Connected normal-script user:

- `assets/js/mypageAuthClient.js`

## Already Connected

Already routed through config or bridge:

- calendar session type label and calendar class
- selected calendar button labels
- membership approved-gate title, lead, heading, and navigation labels
- mypage primary section labels
- mypage primary summary labels
- selected session-post labels such as title, date, visibility, status,
  player count, result, and gate text
- selected session-detail gate labels
- session type label used by session display helpers

Fallback policy already exists:

- module callers use helper functions with explicit fallback strings
- mypage normal-script callers use `window.VELGARD_REUSABLE_OPS_MYPAGE` with
  local fallback strings

## A. Immediately Configurable Candidates

These are display-only labels with low behavior risk.

| area | examples | suggested destination |
| --- | --- | --- |
| `main.js` account/top navigation copy | account link title/aria, back-to-top label | `reusableOpsConfig.site` or `reusableOpsConfig.navigation` |
| calendar static panel labels | selected-day panel title, empty day message, load-error empty message, detail link label, session count aria text | `reusableOpsConfig.calendar.labels` |
| calendar result-card field labels | real date, Laxia date, status, milestone, season, moon phase labels | `reusableOpsConfig.calendar.resultLabels` if kept in reusable ops |
| calendar session meta labels | time, GM, session type, detail link | `reusableOpsConfig.calendar.sessionPanelLabels` |
| session-post static field helper sublabels | player count `min` / `max` sublabels | `reusableOpsConfig.session.playerCountLabels` |
| session-post page meta labels already using fallback | remaining simple headings that already call `getSessionPostLabel` | add missing keys to existing `session.labels` only if duplication is found |

Implementation note:

- do not move CSS classes, DOM ids, input names, or data attributes into config
- only text content should move

## B. Configurable After Fallback/Behavior Spec

These are display labels, but they need current behavior or fallback output
documented before moving.

| area | examples | reason to spec first |
| --- | --- | --- |
| session status display labels | draft, tentative, recruiting, full, closed, finished, canceled | maps DB/status enum keys to labels; labels can move, enum keys must not |
| session visibility labels | hidden, private, public | maps DB enum keys to labels; needs fallback contract |
| player-count formatter wording | range, max-only, min-only, unset labels | Phase 2-R fixed behavior; config move should be a separate label gate |
| calendar date-conversion labels | year/month/day, weekday names, before/after/outside-period messages | part reusable calendar UI, part Velgard/Laxia calendar vocabulary |
| HTML page title/description/meta text | `calendar.html`, `session-post.html`, `session-detail.html`, `mypage.html` metadata | may belong to world-site template config rather than reusable ops config |
| mypage schedule/application cards | GM schedule, pending application, accepted participation labels and empty states | normal-script bridge needs expansion and fallback review |
| mypage PC/profile labels | PC name, default/active labels, Discord ID help text | display-only but normal-script and auth/profile-adjacent |
| session-post template panel display copy | template panel headings, empty states, example labels | template behavior is nearby; copy can move after a template-copy spec |
| session-detail non-action display copy | page lead, missing session, no data, static-data notices | close to loading/error flow; fallback should be documented |

## C. Strong UI-Block Coupling: Do Not Move Yet

These are display strings, but they sit inside dense UI blocks with event
handlers, auth checks, RPC results, payload behavior, or Discord-adjacent
surfaces.

| area | examples | reason |
| --- | --- | --- |
| mypage membership management UI | manager grant/revoke messages, status change messages, load failures, review-note validation | close to membership RPC guards and manager/admin boundaries |
| mypage auth forms | login/signup/password reset/CAPTCHA messages | auth flow and validation-adjacent |
| mypage avatar UI | upload/remove/save errors and prompts | storage operation-adjacent |
| mypage template management UI | save/delete/apply errors and prompts | template RPC and form serialization nearby |
| session-post validation/save/delete messages | save errors, delete confirmation, public-save confirmation, permission messages | validation, event handlers, and data-changing flows nearby |
| session-post Discord mention UI | Discord notify labels, midnight warning, mention validation | Discord notification behavior nearby |
| session-detail owner/GM/admin controls | delete/close/reopen prompts, permission check messages, sync update notices | owner/admin checks and Discord sync nearby |
| sessionDisplay Discord sync panel | sync status/action labels, error labels, link labels | external sync status and Discord action surfaces nearby |
| application/comment UI copy | read-only messages, application/comment panel copy | approved gate and comment/application RPC behavior nearby |

## D. Config Prohibited Values

Do not move these into `reusableOpsConfig` even if they appear as strings:

- DB column names
- Supabase select column lists
- RPC names
- RPC argument names
- enum/status stored values
- role or permission values
- auth/membership decision strings
- CSS class names
- DOM ids
- `data-*` attribute names
- form input names such as `p_player_min` and `p_player_max`
- storage keys
- URL parameter keys
- Discord action keys
- Discord payload keys
- `management_key`
- raw `user_id`
- email fields
- token/JWT-related values

Display labels for enum values may be configurable later, but the enum keys
themselves are not config.

## E. Deferred / Boundary Unclear

The following need a separate ownership decision before config work:

| area | question |
| --- | --- |
| world/site metadata in HTML | likely belongs to world-site template config, not reusable ops config |
| Laxia/Velgard calendar vocabulary | reusable calendar structure vs Velgard-specific world calendar terms need separation |
| default template examples and Discord message bodies | may be reusable ops starter content, world-specific starter content, or user-editable examples |
| Discord sync panel labels | reusable operations label surface, but too close to external side effects for this phase |
| regulation template labels | world-site template side, not reusable operations core |

## Normal Script / Module Script Boundary

Module scripts can import `reusableOpsConfig.js` directly.

Current direct module users:

- `membershipAccessClient.js`
- `renderSessionPost.js`
- `renderSessionDetail.js`
- `core/calendar/renderCalendar.js`
- `core/session/sessionDisplayHelpers.js`

Normal scripts cannot import the module without converting their loading model.
`mypageAuthClient.js` remains a normal script, so it currently reads from:

- `window.VELGARD_REUSABLE_OPS_MYPAGE`

Bridge constraints:

- keep the bridge small
- add only low-risk display labels first
- keep local fallbacks in `mypageAuthClient.js`
- do not route auth, RPC names, DB columns, role keys, or `management_key`
  through the bridge

## Suggested Next Safe Gates

Low-risk implementation candidate:

1. Add a small `navigation` or `commonLabels` group for:
   - account link aria/title
   - back-to-top label
   - generic detail link label if duplication remains

Low-risk audit candidate:

2. Calendar label gap pass:
   - selected-day panel title
   - empty/load-error copy
   - session meta labels
   - date conversion labels

Medium-risk spec candidate:

3. Session status/visibility display label spec:
   - document current fallback behavior
   - move only display labels in a later implementation gate

Medium-risk mypage candidate:

4. Extend `reusableOpsMypageLabels` only for mypage display-only panel labels:
   - schedule/application empty states
   - PC/profile headings
   - template panel headings

Keep separate:

5. Membership management action/error labels, Discord sync labels, auth forms,
   template RPC messages, and session data-changing prompts.

## Result

Phase 2-X result: documentation-only label gap inventory.

No implementation change, JS change, CSS change, HTML change, data change,
file move, SQL Editor execution, SQL apply, DB/RPC/RLS mutation, Edge deploy,
Discord operation, direct Supabase write, debug console logging addition,
`updates.json` change, auth/permission logic change, RPC/DB key
configuration, `management_key` display, or raw id/email/token/JWT display was
performed.

## Phase 2-Y Follow-Up: Minimal A-Class Label Connection

Phase 2-Y implemented the first narrow follow-up from the `A` classification.

Connected only low-risk calendar labels:

- selected-day session-count aria prefix
- selected-day detail link label
- selected-day load-error empty message
- selected-day empty message
- selected-day sessions panel heading
- selected-day `time` meta label
- selected-day `GM` meta label

The labels now live under:

- `REUSABLE_OPS_CONFIG.calendar.labels`

Runtime usage was limited to:

- `assets/js/core/calendar/renderCalendar.js`

The implementation kept local fallback strings at every call site and updated
only the affected calendar cache-bust chain to `20260616-calendar-safe-labels`.

Still not touched:

- `mypageAuthClient.js` and the normal-script bridge
- session-post/detail labels
- membership management labels
- Discord sync labels
- status/visibility labels
- player-count wording
- DB/RPC/enum/status/role values, CSS classes, DOM ids, input names, storage
  keys, URL parameter keys, Discord payload keys, `management_key`, or raw
  id/email/token/JWT-related values

Detailed result:

- `docs/reusable-ops-platform-phase2y-config-label-minimal-result.md`
