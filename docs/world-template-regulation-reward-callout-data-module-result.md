# World Template Regulation Reward Callout Data Module Result

Phase 3-B13 moves the selected reward callout block into a world-site data
module.

Baseline:

- `490c697 Document regulation reward callout behavior`

## Scope

Moved target:

- `data/regulation.json` `sections[].id === "reward"` block index 1
- block type: `callout`
- title: `超過報酬の例`

Created file:

- `assets/js/world/regulation/rewardCalloutBlocksData.js`

Created export:

- `rewardCalloutBlocks`

Removed source block:

- the single `reward` section callout block with title `超過報酬の例`

Import connection:

- `assets/js/renderRegulation.js`

Connection method:

- `renderRegulation(root)` still loads `data/regulation.json`
- `rewardCalloutBlocks` is imported from the world-site data module
- the loaded `reward` section is copied for rendering with the imported
  callout block inserted after the first reward paragraph block
- if stale section data still contains the moved callout block, the render copy
  omits that duplicate before inserting the module-owned block
- `renderDataSection(sectionData)` still receives section-shaped data
- `renderBlock(block)` still handles the `type: "callout"` branch

## Preserved Behavior

Preserved data contract:

- `rewardCalloutBlocks.length === 1`
- block type remains `callout`
- title remains `超過報酬の例`
- `paragraphs.length === 4`
- paragraphs remain a plain string array
- paragraph text exactly matches the old `HEAD:data/regulation.json` block
- `data/regulation.json` still contains the `reward` section
- `data/regulation.json` still contains the reward paragraph block
- only the selected callout block was removed from the JSON section

Preserved renderer and display contracts:

- `renderBlock()` callout branch was not changed
- `renderDataSection()` was not changed
- `renderTable()` was not changed
- `LEVEL_CAP_COLUMNS` was not changed
- CSS classes were not changed
- no DOM id was added to the callout
- parent section id remains `reward`
- TOC anchor remains `#reward`
- active TOC control was not changed
- `termExplanationsData.js` and `levelCapsData.js` were not changed

Cache-bust updated to:

- `20260617-regulation-reward-callout-data-module`

Updated chain:

- `regulation.html` main module query
- `assets/js/main.js` import query for `renderRegulation.js`
- `assets/js/renderRegulation.js` `REGULATION_DATA_PATH`

## Smoke And Snapshot Checks

Static checks:

- `node --check assets/js/renderRegulation.js`: OK
- `node --check assets/js/main.js`: OK
- `node --check assets/js/world/regulation/rewardCalloutBlocksData.js`: OK
- `data/regulation.json` parse: OK

Data checks:

- data module import: OK
- `rewardCalloutBlocks.length`: 1
- `rewardCalloutBlocks[0].type`: `callout`
- title: `超過報酬の例`
- paragraph count: 4
- paragraph values: non-empty plain strings
- exact match with old `HEAD:data/regulation.json` target block: OK
- current `data/regulation.json` reward section exists: true
- current `data/regulation.json` reward section block count: 1
- current `data/regulation.json` reward callout count: 0
- current `data/regulation.json` reward first block type: `paragraphs`

No checked `undefined`, `[object Object]`, empty-title, or empty-callout path was
introduced by the data shape.

## Why Data Module, Not Fetch

The implementation keeps the same static regulation JSON load and uses the ES
module graph for the split callout data. This avoids:

- an additional `fetch`
- new async error handling
- JSON/fetch fallback behavior
- a public routing or server dependency

This matches the earlier `termExplanations` and `levelCaps` pilot pattern.

## Not Moved

The implementation does not move or change:

- the whole `reward` section
- reward section paragraphs
- compensation blocks
- all callouts globally
- reward amount data
- `renderBlock()`
- `renderDataSection()`
- `renderTable()`
- `LEVEL_CAP_COLUMNS`
- `termExplanationsData.js`
- `levelCapsData.js`
- CSS class names
- DOM ids
- anchors
- active TOC behavior
- `updates.json`
- calendar, session-post, session-detail, mypage, membership, Discord sync, DB,
  RPC, RLS, Edge Functions, auth, or secrets

## Limited And Not Tested

Limited or not tested in this implementation gate:

- public rollout check: `not_tested`
- browser DOM render check: `not_tested`
- desktop/mobile visual review: `not_tested`
- active TOC scroll-through behavior: `not_tested`
- non-regulation pages: `not_tested`
- authenticated role-specific behavior: `not_tested`
- data-changing workflows, DB/RPC/RLS, Edge Functions, and Discord sync:
  `not_tested`

These are left to a separate rollout-check gate because this phase is the
implementation split only.

## Next Candidate

Next recommended gate:

- public rollout check for the reward callout data-module split

That check should verify the public cache-bust chain, public availability of
`rewardCalloutBlocksData.js`, public `data/regulation.json` without the moved
callout block, and rendered reward-section output.
