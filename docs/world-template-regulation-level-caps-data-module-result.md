# World Template Regulation Level Caps Data Module Result

Phase 3-B9 moves the regulation `levelCaps` row data to a world-site data
module.

This gate changes only the level-cap row-data ownership and the minimum
cache-bust chain needed to deliver it. It does not introduce JSON/fetch loading,
new async behavior, renderer rewrites, CSS changes, DOM id changes, anchor
changes, active TOC changes, calendar integration, or reusable ops core changes.

Baseline:

- `7fd9721 Document regulation level caps behavior`

## Implementation Summary

Created data module:

- `assets/js/world/regulation/levelCapsData.js`

Export:

- `levelCaps`

Moved data:

- the 14 current `levelCaps` rows
- display order `Lv2` through `Lv15`
- the same 11 row fields
- all values as non-empty strings

Removed JSON key:

- `data/regulation.json` key `levelCaps`

Import connection:

- `assets/js/renderRegulation.js` imports `levelCaps` from
  `./world/regulation/levelCapsData.js`
- `renderRegulation(root)` attaches imported `levelCaps` to the loaded
  regulation object
- `renderLevelCaps(regulation)` continues to read `regulation.levelCaps`

Cache-bust:

- `regulation.html` main module query updated to
  `20260617-regulation-level-caps-data-module`
- `assets/js/main.js` `renderRegulation.js` import query updated to
  `20260617-regulation-level-caps-data-module`
- `assets/js/renderRegulation.js` `REGULATION_DATA_PATH` query updated to
  `20260617-regulation-level-caps-data-module`

## Preserved Contracts

Preserved renderer and table contracts:

- `LEVEL_CAP_COLUMNS` remains in `assets/js/renderRegulation.js`
- `LEVEL_CAP_COLUMNS` content is unchanged
- `renderTable()` is unchanged
- `renderLevelCaps(regulation)` still calls
  `renderTable(rows, LEVEL_CAP_COLUMNS)`
- no row normalization or value conversion was added
- no formula parsing was added
- no standalone JSON/fetch path was added

Preserved DOM and navigation contracts:

- section id remains `level-caps`
- TOC anchor remains `#level-caps`
- active TOC logic is unchanged
- `.regulation-table-wrap` and `.regulation-table` remain the level-cap table
  classes
- regulation CSS is unchanged

Preserved scope boundaries:

- `data/calendarConfig.json` `levelCaps` was not changed
- regulation `levelCaps` and calendar-side level-cap date ranges were not
  merged or synchronized
- reward, honor, Sword Shard, growth, magic-angel rulings, and long house rules
  were not data-module migrated
- reusable ops core was not changed

## Smoke And Snapshot Checks

Static checks:

- `node --check assets/js/renderRegulation.js`: OK
- `node --check assets/js/main.js`: OK
- `node --check assets/js/world/regulation/levelCapsData.js`: OK
- `data/regulation.json` parse: OK
- `data/regulation.json` has `levelCaps` key: false

Data module smoke:

- module import: OK
- exported `levelCaps` type: array
- `levelCaps.length`: 14
- first row `levelCap`: `Lv2`
- last row `levelCap`: `Lv15`
- every row has the same 11 fields: OK
- every field value is a non-empty string: OK
- exact match with old `HEAD:data/regulation.json` `levelCaps`: OK

Diff/scope checks:

- `LEVEL_CAP_COLUMNS` diff: none
- `renderTable()` diff: none
- `data/calendarConfig.json` diff: none
- `assets/css/style.css` diff: none

## Why This Stayed As A Data Module

The data-module approach keeps the B5/B6 pattern:

- no extra fetch
- no new async error branch
- no standalone JSON schema migration yet
- no public renderer rewrite
- a clear cache-bust chain through `regulation.html`, `main.js`,
  `renderRegulation.js`, and the regulation JSON query

Standalone JSON/fetch migration remains a later gate.

## Not Included

This implementation did not change:

- `LEVEL_CAP_COLUMNS`
- `renderTable()`
- table CSS classes
- DOM ids
- anchors
- active TOC behavior
- regulation text meaning
- calendar-side `data/calendarConfig.json`
- reward table data
- honor or Sword Shard table data
- growth rule text
- fumble experience rule text
- lower-bound growth rule text
- magic-angel rulings
- long house rules
- `updates.json`
- auth, membership, RPC, DB/RPC/RLS, Edge Functions, Discord sync, or secrets

## Limited And Not Tested

Not tested in this implementation gate:

- browser DOM rendering: `not_tested`
- desktop/mobile visual review: `not_tested`
- active TOC scroll-through behavior: `not_tested`
- public GitHub Pages delivery: `not_tested`
- non-regulation pages: `not_tested`
- authenticated role-specific behavior: `not_tested`
- data-changing workflows, DB/RPC/RLS, Edge Functions, and Discord sync:
  `not_tested`

These are suitable for the next public rollout check gate.

## Next Step

Recommended next gate:

- public rollout check for the level-cap data module

The rollout check should verify:

- public `regulation.html`: HTTP 200
- public cache-bust chain:
  `20260617-regulation-level-caps-data-module`
- public `renderRegulation.js` imports `levelCapsData.js`
- public `levelCapsData.js`: HTTP 200 and exports `levelCaps`
- public `data/regulation.json`: HTTP 200 and no `levelCaps` key
- public level-cap table renders 14 rows with unchanged headers and cell text
- no broken import path, checked 404, fetch failure, or module-load failure

## Phase 3-B10 Public Rollout Check

Phase 3-B10 verifies the public delivery of this implementation:

- `docs/world-template-regulation-level-caps-data-module-public-check.md`

Confirmed publicly:

- `regulation.html`: HTTP 200
- `main.js`: HTTP 200
- `renderRegulation.js`: HTTP 200
- `levelCapsData.js`: HTTP 200 and exports `levelCaps`
- `data/regulation.json`: HTTP 200, parse OK, and no `levelCaps` key
- cache-bust chain uses `20260617-regulation-level-caps-data-module`
- public `renderRegulation.js` imports `levelCapsData.js`
- public `renderRegulation.js` keeps the
  `renderLevelCaps(regulation)` to `renderTable(rows, LEVEL_CAP_COLUMNS)` path
- public data module keeps 14 rows, first `Lv2`, last `Lv15`, 11 fields, and
  non-empty string values
- checked public 404 count: 0
- checked cache-mixing risks: not observed

Full browser visual review, desktop/mobile review, scroll-through active TOC,
and non-regulation page QA remain limited or not tested in this rollout check.
