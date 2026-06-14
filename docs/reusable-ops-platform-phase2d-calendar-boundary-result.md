# Reusable Ops Platform Phase 2-D Calendar Boundary Result

## Background

Phase 2-B moved reusable operations config files into `assets/js/core/config/`.
Phase 2-C confirmed that the public site was loading those moved config paths.
Phase 2-D tests the next low-risk physical boundary by checking whether the
calendar renderer can move into the reusable operations core without moving
the larger entry point, data, session display, auth, membership, or Discord
sync files.

## Decision

`renderCalendar.js` was moved.

| previous location | new location | result |
| --- | --- | --- |
| `assets/js/renderCalendar.js` | `assets/js/core/calendar/renderCalendar.js` | moved |

Reason:

- The active runtime reference was limited to `assets/js/main.js`.
- The renderer already exposes a single `renderCalendar(...)` entry point.
- The required import changes were narrow relative-path updates.
- `main.js`, `sessionData.js`, `sessionDisplay.js`, `membershipAccessClient.js`,
  and CSS did not need to move.

## Reference Updates

Updated:

- `assets/js/main.js`
  - imports `./core/calendar/renderCalendar.js?v=20260615-calendar-core-move`
- `assets/js/core/calendar/renderCalendar.js`
  - imports `../../dataLoader.js`
  - imports `../../sessionData.js`
  - imports `../../membershipAccessClient.js`
  - imports `../config/reusableOpsConfig.js`
  - imports `../../sessionDisplay.js`

All HTML files that load `assets/js/main.js` were updated to the
`20260615-calendar-core-move` cache-bust so public clients do not keep the
older module graph.

## Dependency Notes

`renderCalendar.js` is more separable than session-post/detail, but it is not
fully standalone yet.

It still depends on:

- `dataLoader.js` for JSON loading.
- `sessionData.js` for merged session loading.
- `membershipAccessClient.js` for approved-member gate display.
- `reusableOpsConfig.js` for session type labels, calendar classes, and button
  labels.
- `sessionDisplay.js` for title/status/time/player-count display helpers.

These dependencies were left in place. The move is a physical boundary step,
not a logic split.

## Local Static Check

| check_name | status | result_value | note |
| --- | --- | --- | --- |
| `render_calendar_node_check` | `pass` | `node --check assets/js/core/calendar/renderCalendar.js` | Syntax check passed. |
| `main_node_check` | `pass` | `node --check assets/js/main.js` | Syntax check passed. |
| `old_calendar_path_active_refs` | `pass` | `active_html_js_refs=0` | Active HTML/JS no longer imports `./renderCalendar.js` or `assets/js/renderCalendar.js`. |
| `new_calendar_path_active_refs` | `pass` | `main_import=1` | `main.js` imports the moved renderer. |
| `main_cache_bust_updated` | `pass` | `html_refs_updated=true` | Shared `main.js` cache-bust was updated across HTML entry pages. |

## Expected Display Compatibility

Expected behavior remains unchanged:

- Calendar rendering still goes through `main.js`.
- Calendar session type labels and colors still resolve through
  `reusableOpsConfig`.
- Closed-session display, GM name display, today navigation, and
  session-detail links are unchanged.
- Approved-member gate behavior is unchanged.
- Session loading is unchanged.
- Discord sync code is untouched.

Browser/public visual QA remains a separate optional gate after deployment if a
client sees stale assets or rendering issues.

## Files Not Moved

The following files were intentionally not moved:

- `assets/js/main.js`
- `assets/js/sessionData.js`
- `assets/js/sessionDisplay.js`
- `assets/js/mypageAuthClient.js`
- `assets/js/renderSessionPost.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/membershipAccessClient.js`
- `assets/js/discordSyncClient.js`
- `assets/css/style.css`

## Next Candidates

Potentially lower-risk follow-ups:

1. Public rollout check for the moved calendar renderer after deployment/cache
   propagation.
2. Docs-only responsibility audit for `dataLoader.js`.
3. CSS selector responsibility audit before any CSS split.
4. Continue label extraction inside `assets/js/core/config/`.

Still avoid moving next without a dedicated design gate:

- `main.js`
- `sessionData.js`
- `sessionDisplay.js`
- `renderSessionPost.js`
- `renderSessionDetail.js`
- `sessionDetailApplicationComments.js`
- `mypageAuthClient.js`
- `discordSyncClient.js`
- `style.css`

## Prohibited Work Confirmed

This gate did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge Function deploy, Discord operation, secret or webhook change,
direct Supabase write addition, `console.*` addition, `updates.json` change,
CSS splitting, independent app extraction, auth/permission logic changes,
approved-gate logic changes, owner/admin logic changes, RPC/DB-key
configuration, `management_key` display/DOM exposure, or raw user id/email/token
display.
