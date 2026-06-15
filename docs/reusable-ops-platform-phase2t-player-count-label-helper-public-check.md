# Phase 2-T Player Count Label Helper Public Check

## Background

Phase 2-S extracted only `formatPlayerCountLabel` into:

- `assets/js/core/session/sessionPlayerCountHelpers.js`

`renderPlayerCountFields` stayed in `assets/js/renderSessionPost.js`, and the
`p_player_min` / `p_player_max` field contract was not changed.

This phase checked the public delivery chain after that extraction.

## Public Delivery Checks

Result: `ok`.

| check | status | result |
| --- | --- | --- |
| `session-post.html` public fetch | `ok` | HTTP 200 |
| `session-post.html` main-module cache-bust | `ok` | `20260616-player-count-label-helper` present |
| public `assets/js/main.js` fetch | `ok` | HTTP 200 |
| public `main.js` imports session-post with latest cache-bust | `ok` | latest import present |
| public `assets/js/renderSessionPost.js` fetch | `ok` | HTTP 200 |
| public `renderSessionPost.js` imports `sessionPlayerCountHelpers.js` | `ok` | latest helper import present |
| public `renderSessionPost.js` no longer defines local `formatPlayerCountLabel` | `ok` | local definition absent |
| public `renderSessionPost.js` still contains `renderPlayerCountFields` | `ok` | renderer remains local |
| public `renderSessionPost.js` keeps `p_player_min` numeric input contract | `ok` | `name` and `min="0"` present |
| public `renderSessionPost.js` keeps `p_player_max` numeric input contract | `ok` | `name` and `min="0"` present |
| public `assets/js/core/session/sessionPlayerCountHelpers.js` fetch | `ok` | HTTP 200 |
| public helper exports `formatPlayerCountLabel` | `ok` | export present |
| `calendar.html` public fetch | `ok` | HTTP 200 |
| `session-detail.html` public fetch | `ok` | HTTP 200 |

No broken import path or helper-path 404 was detected in the public static
delivery check.

## Static Display Scope

The static check confirms that the active public files needed by
session-post, calendar, and session-detail are served and that session-post is
using the extracted helper path.

Confirmed from public JS:

- `renderPlayerCountFields` is still local to `assets/js/renderSessionPost.js`
- `p_player_min` and `p_player_max` still appear with `min="0"`
- `formatPlayerCountLabel` is imported from the core helper
- the old local `formatPlayerCountLabel` definition is gone from the public
  session-post module

Not tested in this gate:

- authenticated role-specific session-post UI
- create/edit/delete operations
- template save/apply operation QA
- Discord sync operation QA
- reset and managed edit browser operation QA

Reason:

- these require authenticated sessions or real data-changing operations and
  should stay behind separate explicit gates.

## Unchanged Boundaries

This phase did not change:

- `renderPlayerCountFields`
- `p_player_min` / `p_player_max` names, ids, classes, or attributes
- payload generation
- template save/apply behavior
- edit restore behavior
- reset behavior
- Discord sync behavior
- auth, approved, owner, or admin logic
- RPC/DB contracts

## Next Candidates

Follow-up completed:

- Phase 2-U extracted `renderPlayerCountFields`.
- Phase 2-V checked the public delivery chain after that extraction.

Detailed result:

- `docs/reusable-ops-platform-phase2v-player-count-field-helper-public-check.md`

Conditional later step:

- authenticated session-post UI check, including template apply, managed edit,
  reset, and payload behavior, as a separate explicit gate
