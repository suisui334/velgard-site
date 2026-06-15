# Phase 2-U Player Count Field Helper Extraction Result

## Background

Phase 2-R fixed the session-post player-count field contract, and Phase 2-S/T
extracted and checked only `formatPlayerCountLabel`.

Phase 2-U extracted the remaining player-count field renderer in a dedicated
gate.

## Implemented Scope

Extracted:

- `renderPlayerCountFields`

Destination:

- `assets/js/core/session/sessionFormHelpers.js`

Updated:

- `assets/js/renderSessionPost.js`
  - imports `renderPlayerCountFields` from `sessionFormHelpers.js`
  - passes the same label expression:
    `getSessionPostLabel("playerCount", "募集人数")`
  - no longer defines the local renderer
- `assets/js/main.js`
  - updates the `renderSessionPost.js` cache-bust to
    `20260616-player-count-field-helper`
- `session-post.html`
  - updates the main module cache-bust to
    `20260616-player-count-field-helper`

## Snapshot Confirmation

Local snapshot check result:

- `player count field snapshot ok`

The snapshot confirmed the rendered HTML remains exactly the same shape as the
Phase 2-R contract:

- wrapper classes: `session-post-field session-post-player-field`
- `role="group"`
- `aria-labelledby="session-post-player-count-label"`
- label class/id: `session-post-player-label` /
  `session-post-player-count-label`
- input container class: `session-post-player-inputs`
- visible sublabels: `min` / `max`
- minimum input: `type="number" name="p_player_min" min="0"`
- maximum input: `type="number" name="p_player_max" min="0"`

The snapshot also checked that the rendered helper did not introduce:

- `required`
- `placeholder`
- `value=`
- `max=`

## Import Cycle Check

Local module import check result:

- `module import ok`

Checked modules:

- `assets/js/core/session/sessionFormHelpers.js`
- `assets/js/renderSessionPost.js`

No import cycle was detected by this runtime import check.

## Explicitly Not Changed

This phase did not change:

- `formatPlayerCountLabel`
- `p_player_min` / `p_player_max` names, ids, classes, or attributes
- payload generation
- template save/apply behavior
- managed-session edit restore
- reset behavior
- Discord mention or sync behavior
- create/update/delete RPC flows
- auth, approved, owner, or admin logic
- event handler registration
- DB/RPC/RLS contracts

## QA Notes

Static checks for this implementation should include:

- `node --check assets/js/core/session/sessionFormHelpers.js`
- `node --check assets/js/renderSessionPost.js`
- `node --check assets/js/main.js`
- snapshot check for `renderPlayerCountFields`
- module import check for import-cycle regression
- search confirming `renderPlayerCountFields` is imported from
  `sessionFormHelpers.js`
- search confirming `p_player_min` / `p_player_max` remain in the existing
  form/template/payload/edit/reset paths

Browser/public rollout remains a separate follow-up gate.

## Phase 2-V Public Check

Phase 2-V confirmed the public static delivery chain after this extraction.

Confirmed:

- public `session-post.html` uses the
  `20260616-player-count-field-helper` cache-bust
- public `main.js` imports the matching `renderSessionPost.js`
- public `renderSessionPost.js` imports `renderPlayerCountFields` from
  `assets/js/core/session/sessionFormHelpers.js`
- public `renderSessionPost.js` imports `formatPlayerCountLabel` from
  `assets/js/core/session/sessionPlayerCountHelpers.js`
- public `sessionFormHelpers.js` is served and exports
  `renderPlayerCountFields`
- public `sessionPlayerCountHelpers.js` is served and exports
  `formatPlayerCountLabel`
- `p_player_min` / `p_player_max` still render with `type="number"` and
  `min="0"`
- the player-count block did not gain `required`, `placeholder`, `value=`, or
  `max=`

Detailed result:

- `docs/reusable-ops-platform-phase2v-player-count-field-helper-public-check.md`

## Next Candidates

Low-risk next step:

- user-side lightweight browser visual check for the updated
  `sessionFormHelpers.js` cache-bust and session-post player-count field
  rendering path

Conditional later step:

- authenticated session-post UI check, including template apply, managed edit,
  reset, and payload behavior, as a separate explicit gate
