# Reusable Ops Platform Phase 2-E Calendar Public Check

## Background

Phase 2-D moved the calendar renderer from `assets/js/renderCalendar.js` to
`assets/js/core/calendar/renderCalendar.js`. Phase 2-E checks whether public
delivery reflects that move and whether active old-path references remain.

This was a public asset and documentation check. No implementation change was
needed.

## Scope

Checked public delivery for:

- `calendar.html`
- public `main.js`
- public `assets/js/core/calendar/renderCalendar.js`
- public dependencies imported by the moved renderer
- active local HTML/JS references

This gate did not perform authenticated calendar operation QA. The approved
calendar UI requires an approved signed-in session, so month navigation,
today-button operation, session card visual inspection, and session-detail click
through remain optional browser QA after deployment/cache propagation.

## Public Asset Check

| check_name | status | result_value | note |
| --- | --- | --- | --- |
| `public_calendar_html_cache_bust` | `pass` | `calendar_core_move=true` | Public calendar HTML references the `20260615-calendar-core-move` `main.js` cache-bust. |
| `public_main_import_new_renderer` | `pass` | `new_calendar_path=true` | Public `main.js` imports `core/calendar/renderCalendar.js`. |
| `public_main_old_renderer_path` | `pass` | `old_calendar_path=false` | Public `main.js` does not reference `assets/js/renderCalendar.js` or `./renderCalendar.js`. |
| `public_new_renderer_status` | `pass` | `status=200` | The moved renderer path is publicly available. |
| `public_old_renderer_status` | `pass` | `status=404` | The old root renderer path is no longer served for the checked cache-bust. |
| `public_new_renderer_export` | `pass` | `renderCalendar_export=true` | Public moved renderer contains the `renderCalendar` export marker. |
| `public_new_renderer_dependencies` | `pass` | `dependency_statuses=200` | Public `dataLoader.js`, `sessionData.js`, `membershipAccessClient.js`, `sessionDisplay.js`, and reusable config are reachable. |
| `public_static_bad_label_markers` | `pass` | `undefined=false; object_object=false` | Checked fetched public JS/HTML for literal `undefined` and `[object Object]` markers. |

Conclusion:

- `public_calendar_renderer_new_path_ok=true`
- `public_calendar_renderer_old_path_present=false`
- `public_calendar_renderer_cache_bust_fix_needed=false`
- `public_calendar_renderer_dependency_fetch_ok=true`

## Local Reference Check

Active local HTML/JS state:

- `assets/js/main.js` imports
  `./core/calendar/renderCalendar.js?v=20260615-calendar-core-move`.
- Active HTML files load
  `assets/js/main.js?v=20260615-calendar-core-move`.
- Active HTML/JS has no runtime reference to `assets/js/renderCalendar.js` or
  `./renderCalendar.js`.

Historical docs still mention the old path as part of earlier records. Those
are not runtime references and were left unchanged.

## Display Compatibility Notes

Expected behavior remains unchanged:

- Calendar rendering still enters through `main.js`.
- Session type labels and color classes still resolve through
  `reusableOpsConfig`.
- Closed-session display, GM name display, today display, and session-detail
  href generation are unchanged in code.
- Approved-member gate behavior is unchanged.
- Session loading and merge behavior are unchanged.
- Mypage, session-post, and session-detail module paths were not changed by
  this gate.

Authenticated full-calendar UI operation was not re-run in this gate. If a
client sees stale calendar behavior after deployment, the first suspects are
browser cache and public CDN propagation, because public static paths now point
to the moved renderer.

## Inventory

Moved file confirmed:

- `assets/js/core/calendar/renderCalendar.js`

Reference updates confirmed:

- `assets/js/main.js`
- HTML entry pages that load `assets/js/main.js`

Additional cache-bust fix:

- `cache_bust_additional_fix_needed=false`

## Next Separation Candidates

Possible follow-ups:

1. Browser QA with an approved account for calendar month navigation, today
   button, session card colors, closed-session marks, GM display, and
   session-detail links.
2. Docs-only responsibility audit for `dataLoader.js`.
3. Continue label extraction inside `assets/js/core/config/`.
4. CSS selector responsibility audit before any CSS split.

Still do not move yet:

- `assets/js/main.js`
- `assets/js/sessionData.js`
- `assets/js/sessionDisplay.js`
- `assets/js/mypageAuthClient.js`
- `assets/js/renderSessionPost.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/sessionDetailApplicationComments.js`
- `assets/js/membershipAccessClient.js`
- `assets/js/discordSyncClient.js`
- `assets/css/style.css`

## Prohibited Work Confirmed

This gate did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge Function deploy, Discord operation, secret or webhook change,
direct Supabase write addition, `console.*` addition, `updates.json` change,
`main.js` large refactor, `sessionData.js` movement, `sessionDisplay.js`
movement, `mypageAuthClient.js` movement, `renderSessionPost.js` movement,
`renderSessionDetail.js` movement, CSS splitting, independent app extraction,
auth/permission logic changes, RPC/DB-key configuration, `management_key`
display/DOM exposure, or raw user id/email/token display.
