# Phase 2-S Player Count Label Helper Extraction Result

## Background

Phase 2-R fixed the current session-post player-count behavior before moving
anything. Phase 2-S used that behavior spec as the source of truth and
extracted only `formatPlayerCountLabel`.

## Implemented Scope

Added:

- `assets/js/core/session/sessionPlayerCountHelpers.js`

Extracted:

- `formatPlayerCountLabel`

Updated:

- `assets/js/renderSessionPost.js`
  - imports `formatPlayerCountLabel` from the new core helper
  - no longer defines the local formatter
- `assets/js/main.js`
  - updates the `renderSessionPost.js` cache-bust to
    `20260616-player-count-label-helper`
- `session-post.html`
  - updates the main module cache-bust to
    `20260616-player-count-label-helper`

## Preserved Behavior

The helper body was moved without changing the output rules fixed in Phase
2-R:

- finite min and max -> `min〜max名`
- finite same min/max -> same range shape, for example `3〜3名`
- finite max only -> `最大N名`
- finite min only -> `最低N名`
- missing, non-finite, direct raw numeric strings, and direct invalid strings
  -> `未設定`

## Explicitly Not Changed

This phase did not move or alter:

- `renderPlayerCountFields`
- `p_player_min` / `p_player_max` input names
- player-count input ids, classes, attributes, or markup
- payload generation
- template save/apply behavior
- managed-session edit restore
- reset behavior
- Discord mention or sync behavior
- create/update/delete RPC flows
- auth, approved, owner, or admin logic
- event handler registration
- DB/RPC/RLS contracts

## Local Smoke Test

Command shape:

- `node --input-type=module -`

Checked 13 cases against the Phase 2-R matrix:

- min/max both present
- min/max same value
- min only
- max only
- both missing
- both `null`
- both `undefined`
- empty strings
- zero range
- zero min-only
- zero max-only
- direct numeric strings
- direct invalid strings

Result:

- `player count label smoke ok: 13`

## QA Notes

Static checks for this implementation should include:

- `node --check assets/js/core/session/sessionPlayerCountHelpers.js`
- `node --check assets/js/renderSessionPost.js`
- `node --check assets/js/main.js`
- import path search for `sessionPlayerCountHelpers.js`
- confirmation that `renderPlayerCountFields` remains in
  `assets/js/renderSessionPost.js`
- confirmation that `p_player_min` / `p_player_max` still appear only in the
  existing form/template/payload/edit/reset paths

Browser/public rollout remains a separate follow-up gate.

## Next Candidates

Low-risk next step:

- public rollout check for the new helper path and session-post cache-bust

Conditional later step:

- dedicated `renderPlayerCountFields` extraction gate, but only with
  template, managed edit, reset, and payload QA included
