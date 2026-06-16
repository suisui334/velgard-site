# World Template Regulation Term Explanations Data Module Result

Phase 3-B5 implements the first regulation data pilot selected in Phase 3-B3
and specified in Phase 3-B4. The target is limited to the term explanation
cards.

This implementation does not introduce JSON/fetch loading, a new renderer,
active TOC changes, CSS changes, DOM id changes, anchor changes, regulation
copy edits, SQL, DB/RPC/RLS changes, Discord sync changes, or reusable ops core
changes.

## Implemented Scope

Created data module:

- `assets/js/world/regulation/termExplanationsData.js`

Export:

- `termExplanations`

Import source:

- `assets/js/renderRegulation.js`

The data module contains the current 12 `termExplanations` card records exactly
as they existed in `data/regulation.json` before this gate.

`data/regulation.json` no longer owns the `termExplanations` key. Other
regulation data remains in the JSON file.

## Renderer Connection

`renderRegulation(root)` now imports the data module and merges it into the
loaded regulation object:

- load existing `data/regulation.json`
- attach `termExplanations` from the world-site data module
- pass the resulting object to the existing renderer flow

`renderTermExplanations(regulation)` itself was not rewritten. It still reads
`regulation.termExplanations` and preserves the same DOM/class behavior.

Preserved renderer contracts:

- section id: `term-explanations`
- section anchor and TOC active behavior
- `.regulation-term-grid`
- `.regulation-term-card`
- `.regulation-callout`
- paragraph rendering through existing `appendParagraphs()`
- callout rendering conditions

## Cache-Bust Updates

Updated cache-bust key:

- `20260616-regulation-term-data-module`

Affected references:

- `regulation.html` main module query
- `assets/js/main.js` import of `renderRegulation.js`
- `assets/js/renderRegulation.js` query for `data/regulation.json`

No `updates.json` change was made.

## Snapshot / Smoke Result

Local module smoke check:

- `termExplanations.length === 12`: ok
- data module content matches the previous HEAD `data/regulation.json`
  `termExplanations`: ok
- title list matches previous data: ok
- callout count remains 1: ok
- callout remains on card index 7: ok
- no missing or empty `paragraphs` arrays: ok

Additional static checks:

- JSON parse for `data/regulation.json`: ok
- data module import via Node module smoke: ok

## Preserved Current Behavior

The following Phase 3-B4 fixed facts remain unchanged:

- term explanation card count remains 12
- display order remains the current data order
- headings and paragraph text remain unchanged
- one optional callout remains on the same card
- CSS class names remain unchanged
- DOM id and anchor remain unchanged
- active TOC behavior is not rewritten
- renderer-owned section heading is not moved into data

## Why Data Module, Not JSON

The first pilot uses a data module because it:

- avoids adding a second fetch path
- avoids new asynchronous fallback handling
- keeps GitHub Pages delivery simple
- lets the team test world-site data separation without changing renderer
  timing
- keeps rollback straightforward

JSON-file migration remains a later separate gate after this module split is
confirmed publicly.

## Out Of Scope

This gate did not touch:

- whole regulation page data migration
- level-cap table data migration
- reward or honor values
- fumble/lower-bound growth rules
- long house rules
- magic-angel ruling text or equipment data
- TOC item definitions
- active side-menu logic
- CSS class names
- DOM ids or anchors
- reusable ops core
- auth, membership, RPC, DB, Discord sync, or secrets

## QA Notes

Required next check:

- public rollout confirmation that the new module path is HTTP 200
- public `renderRegulation.js` imports the new module
- regulation page still renders the term explanation section with 12 cards
- no `undefined`, `[object Object]`, empty heading, or empty card appears

Authenticated or data-changing QA is not required for this world-site data
module split because it does not touch auth, membership, RPC, DB, or Discord
sync.

## Phase 3-B6 Public Rollout Check

Phase 3-B6 completed the public rollout check:

- `docs/world-template-regulation-term-explanations-data-module-public-check.md`

Public result:

- `regulation.html`: HTTP 200
- `regulation.html` cache-bust:
  `20260616-regulation-term-data-module`
- `assets/js/main.js`: HTTP 200 and imports
  `renderRegulation.js?v=20260616-regulation-term-data-module`
- `assets/js/renderRegulation.js`: HTTP 200 and imports
  `./world/regulation/termExplanationsData.js`
- `assets/js/world/regulation/termExplanationsData.js`: HTTP 200 and exports
  `termExplanations`
- `data/regulation.json`: HTTP 200, parse OK, and no `termExplanations` key
- public DOM term cards: 12
- public DOM callout count: 1
- public DOM callout card index: 7
- public DOM headings, paragraphs, and callout content matched the public data
  module
- no checked public 404, module-load failure, or regulation-data fetch failure
  was found

Visual QA remains limited to DOM-level browser verification for this gate. Full
desktop/mobile visual review and scroll-through active TOC QA remain separate
checks.

## Next Candidates

1. Decide whether to keep the module pattern for a second
   short card group.
2. Keep standalone JSON-file migration as a separate later gate.
