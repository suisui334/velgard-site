# World Template Regulation Level Caps Data Pilot Summary

Phase 3-B11 summarizes the second regulation data-module pilot and selects the
next candidate.

This is a docs-only decision record. It does not change implementation, HTML,
CSS, JavaScript, JSON/data, data modules, renderers, regulation copy,
`updates.json`, or reusable ops core behavior.

Baseline:

- `628a8c2 Check regulation level caps rollout`

## Completed Pilot

Second data-module pilot target:

- `levelCaps` row data

Created file:

- `assets/js/world/regulation/levelCapsData.js`

Created export:

- `levelCaps`

Removed source key:

- `data/regulation.json` key `levelCaps`

Import connection:

- `assets/js/renderRegulation.js`

Renderer contract preserved:

- `renderRegulation(root)` still loads `data/regulation.json`
- imported `levelCaps` is attached to the loaded regulation object
- `renderLevelCaps(regulation)` remains the renderer call path
- `renderLevelCaps(regulation)` still reads `regulation.levelCaps`
- `renderLevelCaps(regulation)` still calls
  `renderTable(rows, LEVEL_CAP_COLUMNS)`
- `renderTable()` remains unchanged
- section id remains `level-caps`
- TOC anchor remains `#level-caps`
- `.regulation-table-wrap` and `.regulation-table` remain the table classes
- active TOC behavior was not rewritten

Column contract preserved:

- `LEVEL_CAP_COLUMNS` remains in `assets/js/renderRegulation.js`
- column count remains 11
- header labels remain unchanged
- field mapping remains unchanged
- column definitions were not moved into data

Output/data preserved:

- row count: 14
- row order: `Lv2` through `Lv15`
- row shape: 11 fields
- cell-equivalent count: 154
- all cell-equivalent values are non-empty strings
- module data exactly matched the old `HEAD:data/regulation.json` `levelCaps`
- no checked `undefined`, `[object Object]`, or empty rows

Scope boundaries preserved:

- `data/calendarConfig.json` `levelCaps` remains separate
- calendar-side level-cap date ranges were not merged with regulation
  `levelCaps`
- reward, honor, Sword Shard, growth, magic-angel rulings, and long house rules
  were not split into separate schemas
- reusable ops core was not touched

## Public Rollout Result

Phase 3-B10 confirmed the rollout:

- `docs/world-template-regulation-level-caps-data-module-public-check.md`

Public checks passed:

- public `regulation.html`: HTTP 200
- public `main.js`: HTTP 200
- public `renderRegulation.js`: HTTP 200
- public `levelCapsData.js`: HTTP 200 and exports `levelCaps`
- public `termExplanationsData.js`: HTTP 200
- public `data/regulation.json`: HTTP 200, parse OK, and no `levelCaps` key
- public `dataLoader.js`: HTTP 200
- HTML-referenced regulation CSS: HTTP 200
- cache-bust chain:
  `20260617-regulation-level-caps-data-module`
- checked public 404 count: 0
- checked cache-mixing risks were not observed

Display-equivalent checks passed:

- level-cap rows: 14
- first row: `Lv2`
- last row: `Lv15`
- expected fields per row: 11
- cell-equivalent count: 154
- all checked cell values: non-empty strings
- no checked `undefined`, `[object Object]`, or empty rows
- public renderer keeps `renderLevelCaps(regulation)` before
  `renderTermExplanations(regulation)`

Remaining limited or not-tested QA:

- full browser DOM inspection: `limited`
- desktop/mobile visual review: `not_tested`
- scroll-through active TOC behavior: `limited`
- non-regulation pages: `not_tested`
- authenticated role-specific behavior: `not_tested`
- data-changing workflows, DB/RPC/RLS, Edge Functions, and Discord sync:
  `not_tested`

These remaining items are acceptable for this pilot because the gate was a
world-site static display/data split and did not touch operational behavior.

## What Worked

The level-cap pilot succeeded because:

- the moved data was already repeated row data
- the renderer boundary was compact enough to preserve
  `renderLevelCaps(regulation)`
- `renderTable()` already consumed row/column input
- `LEVEL_CAP_COLUMNS` could stay renderer-owned
- no extra `fetch` path was introduced
- no new async failure branch was introduced
- no row normalization or formula parsing was needed
- GitHub Pages served the module path with HTTP 200
- the public cache-bust chain was inspectable
- rollback would be a small revert or restoring the JSON key and removing the
  import
- visible output could be checked by row count, order, header mapping, and
  every cell-equivalent value

The main improvement over the first pilot is that the same data-module pattern
worked for table-shaped row data, not only for repeated card data.

## Updated Data Module Evaluation

Two completed pilots:

- `termExplanations`
- `levelCaps`

Updated strengths:

- The page still performs one regulation JSON load.
- Split data rides on the ES module graph.
- GitHub Pages serves the data modules directly.
- Public rollout checks can verify HTML, main module, renderer, data module,
  and JSON with HTTP 200.
- The renderer can keep reading `regulation.<key>` after the import is attached
  at `renderRegulation(root)`.
- DOM ids, anchors, CSS classes, and active TOC behavior can stay untouched.
- The approach now works for both card data and table row data.

Updated cautions:

- Removing a key from `data/regulation.json` always requires cache-mixing
  checks.
- Dangerous public combinations remain:
  - new JSON plus old renderer
  - old HTML/main cache-bust plus new renderer
  - new renderer plus missing data module
- Column definitions and shared renderers should stay separate gates.
- Data modules are source files, not the final non-developer editing model.
- Standalone JSON/fetch migration remains a later decision.
- Module import cache policy should be considered whenever an existing data
  module is edited.

Decision:

- Use the data-module approach for one more small, isolated content group.
- Do not use it yet for long rules, special rulings, table column definitions,
  or shared renderer behavior.

## Candidate Re-Evaluation

| Candidate | Classification | Evaluation |
| --- | --- | --- |
| Reward amount table | D. Do not split now | Reward amounts are already the `rewardAmount` cells inside `levelCapsData.js`. Splitting them into a standalone module would duplicate or fragment the level-cap table semantics. |
| Sword Shard / honor table | D. Do not split now | `minHonor` and `swordShardGuide` are already cells inside `levelCapsData.js`. A standalone split should wait for a future table-column schema decision. |
| Short note cards | A. Next pilot candidate | Current production data has one simple `type: "callout"` block in the `reward` section. It is small, data-shaped, renderer-supported by `renderBlock(block)`, and easy to compare by title and paragraph text. |
| Individual ruling cards | B/C. Later candidate | Some rulings are short, but current rules are mixed through subsection groups and may contain paragraphs, lists, or nested details. They need a block-shape inventory first. |
| Fumble experience card | D. No standalone pilot | The current fumble experience content is already part of the moved `termExplanations` module as a term card. Do not split it into a second special case. |
| Lower-bound growth card | D. No standalone pilot | The lower-bound growth explanation is already part of the moved `termExplanations` module. Keep it with the term-card group unless a future card schema changes the whole group. |
| Magic-angel ruling card | C. Keep fixed for now | It is long, Velgard-specific, and tied to subsection text. It should wait for a long-body/special-ruling schema. |
| Long house rules | C. Keep fixed for now | Long rules need a stable block schema for headings, paragraphs, lists, callouts, and tables before module extraction. |
| Growth rules overall | C. Keep fixed for now | Growth-related content is split between `termExplanations`, `levelCaps`, and longer section text. Moving it as a whole would cross current pilot boundaries. |

Classification notes:

- A means suitable for the next implementation pilot if scoped narrowly.
- B means viable after another pilot or a dedicated schema review.
- C means keep in the current structure for now.
- D means do not make it an independent pilot target.

## Selected Next Candidate

Selected candidate:

- Short note card: `reward` section callout block

Current production location:

- `data/regulation.json`
- section id: `reward`
- section title: `報酬・超過報酬`
- current block index: 1
- block type: `callout`
- current title: `超過報酬の例`
- current paragraph count: 4
- current block keys:
  - `type`
  - `title`
  - `paragraphs`

Current renderer path:

- `assets/js/renderRegulation.js`
- `renderRegulation(root)` builds a `sections` map from `regulation.sections`
- `renderDataSection(sections.get("reward"))`
- `renderBlock(block)`
- `block.type === "callout"` branch
- output class: `.regulation-callout`

Why this candidate:

- It is the smallest remaining unmoved content group in the candidate list.
- It is already structured as a single block object.
- It uses an existing renderer branch.
- It has no dedicated DOM id.
- It does not require moving `renderBlock()`.
- It does not require changing `renderTable()` or any column definitions.
- It is easy to compare by block count, title, paragraph count, and text.
- A rollback can restore the block in `data/regulation.json` or revert the
  implementation commit.
- Future worlds are likely to need short notes/callouts.

Known risks:

- The block is nested under `sections`, not a top-level JSON key.
- The first implementation must avoid a generic section-merging rewrite.
- The first implementation must move only this one callout block, not the whole
  reward section.
- The implementation must not change the `reward` section id, TOC anchor, or
  reward paragraphs.

## Proposed Next Module Shape

Do not create this file in B11. This is a future implementation target.

Expected module path:

- `assets/js/world/regulation/rewardCalloutBlocksData.js`

Expected export:

- `rewardCalloutBlocks`

Expected data shape:

```js
export const rewardCalloutBlocks = [
  {
    type: "callout",
    title: "Current callout title",
    paragraphs: [
      "Current paragraph 1",
      "Current paragraph 2"
    ]
  }
];
```

Expected ownership change:

- remove only the current `reward` section callout block from
  `data/regulation.json`
- import `rewardCalloutBlocks` in `assets/js/renderRegulation.js`
- attach or inject the imported block at the existing `renderRegulation(root)`
  merge point before the `sections` map is rendered
- keep `renderDataSection(sectionData)` and `renderBlock(block)` behavior
  unchanged

Expected connection approach:

- keep the `reward` section in `data/regulation.json`
- keep the existing reward paragraphs in `data/regulation.json`
- rebuild only the loaded `reward` section's `blocks` array with the imported
  callout block in the same position
- do not create a generic block registry yet

## Cache-Bust Targets For The Next Pilot

Review and update only the affected public chain:

- `regulation.html` main module query
- `assets/js/main.js` import query for `renderRegulation.js`
- `assets/js/renderRegulation.js` `REGULATION_DATA_PATH` query for
  `data/regulation.json`
- public availability of
  `assets/js/world/regulation/rewardCalloutBlocksData.js`

If the imported data module path does not carry a query, the rollout check must
still verify that the new module path is HTTP 200.

Do not update `updates.json` unless a separate content-release gate explicitly
requires it.

## QA For The Next Pilot

Static checks:

- `node --check assets/js/renderRegulation.js`
- `node --check assets/js/world/regulation/rewardCalloutBlocksData.js`
- `data/regulation.json` parse OK
- data module import smoke OK
- moved callout block count remains 1
- callout title remains unchanged
- callout paragraph count remains 4
- callout text matches the previous JSON block exactly
- `renderBlock(block)` callout branch unchanged
- `.regulation-callout` class unchanged
- `reward` section id and TOC anchor unchanged

Public delivery checks:

- public `regulation.html`: HTTP 200
- public cache-bust chain uses the new key
- public `renderRegulation.js`: HTTP 200
- public `renderRegulation.js` imports `rewardCalloutBlocksData.js`
- public `rewardCalloutBlocksData.js`: HTTP 200 and exports
  `rewardCalloutBlocks`
- public `data/regulation.json`: HTTP 200 and the selected callout block is no
  longer duplicated in JSON
- no broken import path or checked public 404
- no module-load or regulation-data fetch failure

Display checks:

- `#reward` section still exists
- `#reward` TOC anchor remains
- reward paragraphs remain before the callout
- callout count in the reward section remains 1
- callout title remains unchanged
- callout paragraphs remain unchanged
- `.regulation-callout` remains
- no `undefined`, `[object Object]`, empty title, or empty callout appears
- `levelCaps` table still renders 14 rows
- `termExplanations` still renders 12 cards

## Rollback

Rollback options:

1. Revert the implementation commit.
2. Restore the callout block inside `data/regulation.json`, remove the module
   import, and return the `reward` section blocks to the previous shape.

Rollback should not affect calendar, mypage, session-post, session-detail,
membership, Discord sync, or any reusable ops core behavior.

## Out Of Scope For The Next Pilot

The first short-note implementation gate must not include:

- moving the entire `reward` section
- moving reward paragraphs
- changing reward text
- moving compensation blocks
- moving all callouts globally
- moving individual rulings
- moving long house rules
- moving magic-angel rulings
- moving growth rules
- changing `renderBlock()`
- changing `renderDataSection()`
- changing `renderTable()`
- changing `LEVEL_CAP_COLUMNS`
- changing CSS classes
- changing section id `reward`
- changing anchors or active TOC behavior
- changing `levelCapsData.js`
- changing `termExplanationsData.js`
- standalone JSON/fetch migration
- renderer rewrite
- `updates.json` change
- auth, membership, RPC, DB/RPC/RLS, Edge Function, Discord, or secret changes

## Final Decision

Proceed to a future behavior/spec gate for:

- short note card data module
- concrete first target: `reward` section `type: "callout"` block

Do not implement it directly from this B11 summary. The next gate should first
freeze the current callout behavior, output, comparison checklist, and exact
merge approach.

## Phase 3-B12 Reward Callout Behavior Spec

Phase 3-B12 freezes the current behavior of the selected short-note target:

- `docs/world-template-regulation-reward-callout-spec.md`

Fixed facts:

- current source is `data/regulation.json`
- current section id is `reward`
- current block type is `callout`
- current block index in the reward section is 1
- current title is `超過報酬の例`
- current body is a `paragraphs` array with 4 strings
- current block fields are `type`, `title`, and `paragraphs`
- current renderer is the shared `renderBlock(block)` branch for
  `type === "callout"`
- output class remains `.regulation-callout`
- parent section anchor remains `#reward`

Recommended future implementation remains narrow:

- move only this one reward callout block to
  `assets/js/world/regulation/rewardCalloutBlocksData.js`
- export `rewardCalloutBlocks`
- keep the reward section paragraphs in `data/regulation.json`
- keep `renderBlock()` and `renderDataSection()` unchanged
- do not introduce JSON/fetch loading

Phase 3-B12 is docs-only and does not include implementation, HTML, CSS,
JavaScript, JSON/data, renderer, regulation copy, `updates.json`, or reusable
ops core changes.

## Phase 3-B13 Reward Callout Data Module

Phase 3-B13 implements the selected short-note data-module split:

- `docs/world-template-regulation-reward-callout-data-module-result.md`

Implementation summary:

- created `assets/js/world/regulation/rewardCalloutBlocksData.js`
- exported `rewardCalloutBlocks`
- moved only the selected `reward` section `type: "callout"` block
- removed only that callout block from `data/regulation.json`
- kept the `reward` section and reward paragraph block in
  `data/regulation.json`
- inserted the imported callout block back at reward block index 1 for
  rendering
- kept `renderBlock()` and `renderDataSection()` unchanged
- kept CSS classes, DOM ids, anchors, active TOC behavior,
  `termExplanationsData.js`, and `levelCapsData.js` unchanged

Confirmed by smoke/snapshot checks:

- data module import OK
- moved block count remains 1
- block type remains `callout`
- title remains `超過報酬の例`
- paragraph count remains 4
- module block exactly matches the old `HEAD:data/regulation.json` target block
- current `data/regulation.json` parses and keeps the `reward` section without
  the moved callout block

Public delivery and browser DOM checks remain for a later rollout-check gate.

## Phase 3-B14 Reward Callout Public Rollout Check

Phase 3-B14 confirms the public delivery of the reward callout data module:

- `docs/world-template-regulation-reward-callout-data-module-public-check.md`

Public checks passed:

- public `regulation.html`: HTTP 200 and expected cache-bust
- public `main.js`: HTTP 200 and matching `renderRegulation.js` import
- public `renderRegulation.js`: HTTP 200 and imports
  `rewardCalloutBlocksData.js`
- public `rewardCalloutBlocksData.js`: HTTP 200 and exports
  `rewardCalloutBlocks`
- public `data/regulation.json`: HTTP 200, parse OK, and no selected reward
  callout block
- public JSON keeps the `reward` section and reward paragraph block
- public DOM renders `超過報酬の例` exactly once
- public DOM keeps 4 paragraphs, `.regulation-callout`, parent id `reward`,
  and TOC link `#reward`
- public DOM still has 12 term cards and 14 level-cap rows
- checked broken path / fetch failure / browser error log count: 0

Remaining limited or not-tested QA:

- full desktop/mobile manual visual review: `limited`
- scroll-through active TOC behavior: `limited`
- non-regulation pages and authenticated/data-changing workflows:
  `not_tested`
