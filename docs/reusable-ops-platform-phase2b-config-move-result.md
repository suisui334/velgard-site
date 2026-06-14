# Reusable Ops Platform Phase 2-B Config Move Result

## Background

Phase 2-A classified the current public site files into reusable operations
platform candidates, Velgard world-site files, shared utilities, and files that
should not be moved first. Phase 2-B starts the physical separation with only
the lowest-risk reusable operations config files.

This gate intentionally avoided moving authentication, membership, session,
Discord sync, data loading, CSS, or renderer files.

## Moved Files

| previous location | new location | note |
| --- | --- | --- |
| `assets/js/reusableOpsConfig.js` | `assets/js/core/config/reusableOpsConfig.js` | ES module config entry point for reusable operations labels, calendar session type display data, approved-gate display copy, and session UI labels. |
| `assets/js/reusableOpsMypageLabels.js` | `assets/js/core/config/reusableOpsMypageLabels.js` | Classic-script mypage label bridge. The public bridge name remains `window.VELGARD_REUSABLE_OPS_MYPAGE`. |

The exported module names and classic-script bridge name were kept unchanged.
Fallback behavior remains in the consuming files.

## Reference Updates

Updated direct config imports:

- `assets/js/membershipAccessClient.js`
- `assets/js/renderCalendar.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/renderSessionPost.js`
- `assets/js/sessionDisplay.js`

Updated module graph cache-bust references so stale modules do not keep
importing the old config path:

- `assets/js/main.js`
- `assets/js/notificationBellClient.js`
- `assets/js/renderAdminCapAnnouncements.js`
- `assets/js/renderCalendar.js`
- `assets/js/renderHome.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/renderSessionPost.js`
- `assets/js/renderTimeline.js`

Updated public HTML cache-bust references for `assets/js/main.js` and the
mypage classic-script bridge path. This keeps calendar, mypage, session-post,
session-detail, timeline, world-site pages, and shared entry pages on the same
module version after the move.

## Files Not Moved

The following files were intentionally left in place:

- `assets/js/main.js`
- `assets/js/mypageAuthClient.js`
- `assets/js/sessionData.js`
- `assets/js/renderSessionPost.js`
- `assets/js/renderSessionDetail.js`
- `assets/js/membershipAccessClient.js`
- `assets/js/discordSyncClient.js`
- `assets/css/style.css`

They still contain auth, membership, session, renderer, CSS, or Discord sync
responsibilities and need separate design/QA gates before any physical move.

## Impact Scope

Expected behavior is unchanged:

- Calendar still reads the same session type labels and display classes.
- Mypage still reads the same section and summary labels through the bridge.
- Session-post and session-detail still use the same fallback labels.
- Approved-gate text still falls back to existing labels when config is not
  available.
- `management_key`, raw user id, email, tokens, JWT values, Discord ids, and
  secrets are not exposed.

No authentication logic, permission checks, RPC names, DB column names,
membership management behavior, or Discord sync behavior was changed.

## QA Notes

Static checks for this gate should confirm:

- No active HTML/JS reference still points at the old root config paths.
- Active HTML/JS references use `assets/js/core/config/`.
- The public bridge name `window.VELGARD_REUSABLE_OPS_MYPAGE` is unchanged.
- The reusable config module exports are unchanged.
- `undefined`, `[object Object]`, empty headings, and empty buttons should not
  appear because consumers still pass explicit fallback labels.

Browser visual QA remains a separate optional gate if public rendering needs to
be checked after deployment/cache propagation.

## Phase 2-C Public Check

Phase 2-C checked the public delivery after the config move. The public
calendar, mypage, session-post, and session-detail HTML all referenced the
Phase 2-B `main.js` cache-bust. Public mypage HTML loaded
`assets/js/core/config/reusableOpsMypageLabels.js`, and public JS referenced
`assets/js/core/config/reusableOpsConfig.js`.

Result:

- `public_core_config_path_ok=true`
- `public_old_root_config_path_present=false`
- `public_cache_bust_fix_needed=false`
- `public_config_bridge_preserved=true`

Detailed result: `docs/reusable-ops-platform-phase2c-config-public-check.md`.

## Next Separation Candidates

Low-risk next candidates:

1. Continue adding display labels to `assets/js/core/config/reusableOpsConfig.js`
   without moving more behavior-heavy files.
2. Produce a `dataLoader.js` responsibility note before moving it.
3. Prepare a world-site config note for gallery category labels and regulation
   display settings.
4. Audit CSS selectors before any `style.css` split.

Still avoid moving first:

- `main.js`
- `mypageAuthClient.js`
- `sessionData.js`
- `renderSessionPost.js`
- `renderSessionDetail.js`
- `sessionDetailApplicationComments.js`
- `discordSyncClient.js`
- `style.css`

## Prohibited Work Confirmed

This gate did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge Function deploy, Discord operation, secret or webhook change,
direct Supabase write addition, `console.*` addition, `updates.json` change,
CSS splitting, independent app extraction, auth/permission logic changes, RPC
or DB-key configuration, or `management_key` display/DOM exposure.

## Phase 2-D Calendar Renderer Move Follow-Up

After the config move and public config-path check, Phase 2-D moved only
`assets/js/renderCalendar.js` into `assets/js/core/calendar/renderCalendar.js`.
This was intentionally narrower than the files listed above as still unsafe to
move first.

The moved calendar renderer still imports `dataLoader.js`, `sessionData.js`,
`membershipAccessClient.js`, `reusableOpsConfig.js`, and `sessionDisplay.js`.
Those dependencies remain unmoved, and no calendar behavior, approved gate,
session loading, auth, RPC, DB, or Discord sync logic was changed.

Detailed result: `docs/reusable-ops-platform-phase2d-calendar-boundary-result.md`.
