# World Template Regulation Data Pilot Summary

Phase 3-B7 summarizes the first regulation data-module pilot and selects the
next candidate. This is a docs-only decision record.

No implementation, HTML, CSS, JavaScript, JSON/data, renderer, or content copy
change is included in this gate.

Baseline:

- `03c3229 Check regulation term data rollout`

## Pilot Scope Completed

The first data-module pilot moved the regulation term explanation cards.

Moved target:

- `termExplanations`

Created file:

- `assets/js/world/regulation/termExplanationsData.js`

Created export:

- `termExplanations`

Removed source key:

- `data/regulation.json` key `termExplanations`

Import connection:

- `assets/js/renderRegulation.js`

Renderer contract preserved:

- `renderRegulation(root)` loads `data/regulation.json`
- imported `termExplanations` is attached to the loaded regulation object
- `renderTermExplanations(regulation)` remains the renderer call path
- `renderTermExplanations(regulation)` still reads
  `regulation.termExplanations`
- section id remains `term-explanations`
- TOC anchor remains `#term-explanations`
- `.regulation-term-grid`, `.regulation-term-card`, and
  `.regulation-callout` remain the DOM/CSS classes
- active TOC behavior was not rewritten

Preserved output:

- card count: 12
- display order: unchanged
- headings: unchanged
- paragraphs: unchanged
- callout count: 1
- callout card index: 7
- no `undefined`, `[object Object]`, empty heading, or empty card in the
  checked public DOM

## Public Rollout Result

Phase 3-B6 confirmed the rollout:

- `docs/world-template-regulation-term-explanations-data-module-public-check.md`

Public checks passed:

- `regulation.html`: HTTP 200
- `regulation.html` cache-bust:
  `20260616-regulation-term-data-module`
- `assets/js/main.js`: HTTP 200 and imports the matching
  `renderRegulation.js` query
- `assets/js/renderRegulation.js`: HTTP 200 and imports the term data module
- `assets/js/world/regulation/termExplanationsData.js`: HTTP 200 and exports
  `termExplanations`
- `data/regulation.json`: HTTP 200, parse OK, and no `termExplanations` key
- public DOM term cards: 12
- public DOM callout count: 1
- public DOM callout card index: 7
- checked cache-mixing risks were not observed

Remaining limited or not-tested QA:

- full desktop/mobile manual visual review: `limited`
- scroll-through active TOC behavior: `limited`
- non-regulation pages: `not_tested`
- authenticated role-specific behavior: `not_tested`
- data-changing workflows, DB/RPC/RLS, Edge Functions, and Discord sync:
  `not_tested`

These remaining items are acceptable for this pilot because the gate was a
world-site display/data split and did not touch operational behavior.

## What Worked

The first pilot succeeded because:

- the moved data was already array-shaped
- the renderer function was isolated enough to keep the call path stable
- no extra `fetch` path was introduced
- no JSON/fetch fallback behavior had to be designed
- GitHub Pages served the new module path with HTTP 200
- the cache-bust chain was easy to inspect
- rollback would be a small revert or restoring the JSON key
- public visible output could be checked by count, order, heading, paragraph,
  and callout comparison

The data-module approach is a good second-pilot mechanism when the target is:

- already a top-level `data/regulation.json` key
- consumed by one small renderer function
- easy to reattach to the loaded regulation object
- easy to compare as visible text or table cells
- independent from auth, membership, RPC, DB, Discord, CSS classes, DOM ids,
  anchors, and active TOC logic

## Data Module Method Evaluation

### Strengths

No additional fetch:

- The page still has one regulation JSON load.
- The split data rides on the ES module graph.
- There is no new async error branch in the renderer.

GitHub Pages friendly:

- Static ES modules are served directly.
- The public rollout check can verify each path with HTTP 200.
- No server routing, function deployment, or database dependency is involved.

Clear cache-bust chain:

- `regulation.html` controls the main module query.
- `assets/js/main.js` controls the `renderRegulation.js` import query.
- `assets/js/renderRegulation.js` controls the `data/regulation.json` query.
- The new module path itself can be checked directly.

Renderer stability:

- The existing renderer can keep reading `regulation.<key>`.
- The merge point is local to `renderRegulation(root)`.
- DOM structure, CSS classes, section ids, and TOC behavior can stay untouched.

Rollback:

- Reverting the pilot commit restores the old ownership.
- A fallback can also keep the current reader and disable the imported data.

### Cautions

Cache mixing is the main risk when removing a key from `data/regulation.json`.

Dangerous combinations include:

- new `data/regulation.json` plus old renderer
- old HTML/main cache-bust plus new renderer
- new renderer plus a missing module path

Future gates must explicitly verify the full public chain before considering
the split complete.

Module cache policy needs to be considered per gate:

- A first-time new module path is naturally fresh.
- If an existing data module is edited later, the importing path may need a
  query or another explicit cache-bust strategy.
- Future module gates should decide whether data-module imports should also
  carry a version query.

Data modules are less editor-friendly than standalone JSON:

- They are still source files.
- They are not the final form for non-developer world editors.
- Standalone JSON remains a later separate migration gate.

## Candidate Re-Evaluation

| Candidate | Classification | Evaluation |
| --- | --- | --- |
| Level-cap table | A. Next pilot candidate | `levelCaps` is already a top-level array in `data/regulation.json`, rendered by `renderLevelCaps(regulation)`, and can move as row data while leaving `LEVEL_CAP_COLUMNS` and `renderTable()` unchanged. It is dense, so QA must compare all cells. |
| Reward amount table | B. Later candidate | Reward amounts are currently the `rewardAmount` column inside `levelCaps`. Moving them alone would split one public table and risk semantic/layout drift. Handle after level-cap rows or table column modeling. |
| Sword Shard / honor guide table | B. Later candidate | `minHonor` and `swordShardGuide` are also columns inside `levelCaps`. Standalone migration should wait for table-shape review. |
| Short note cards | B. Later candidate | Callout/note blocks are simple but scattered inside `sections`. They are good after one table-style module or after a shared block/card extraction spec. |
| Individual ruling cards | B/C. Depends on body shape | Short rulings can become card/block data later, but mixed paragraphs/lists/subsections make this riskier than a top-level table array. |
| Fumble experience card | D. No standalone pilot | This content is already part of the moved `termExplanations` module. Do not split it into a second special case. |
| Lower-bound growth card | D. No standalone pilot | This content is already part of the moved `termExplanations` module. Keep it inside the existing card group unless a future card schema changes the whole group. |
| Magic-angel ruling card | C. Keep fixed for now | It is long, Velgard-specific, and mixes internal headings, equipment-style rows, and special exceptions. It should wait for a long-body block schema. |
| Long house rules | C. Keep fixed for now | These need a stable block schema for headings, lists, callouts, details, and tables before module extraction. |

Classification notes:

- A means suitable for the next implementation pilot if scoped narrowly.
- B means viable after another pilot or a dedicated schema review.
- C means keep in the current JSON/renderer shape for now.
- D means do not make it an independent pilot target.

## Selected Next Candidate

Selected candidate:

- Level-cap table row data

Scope:

- move only `levelCaps` rows
- do not move `LEVEL_CAP_COLUMNS`
- do not split reward, honor, or Sword Shard columns into separate tables
- do not change table rendering

Why this candidate:

- It is the clearest table-shaped next step.
- `levelCaps` is already a top-level `data/regulation.json` key.
- The row shape is stable and repeated.
- `renderLevelCaps(regulation)` is a compact renderer boundary.
- `renderTable()` already supports row/column input.
- The public output can be checked by row count, column count, header labels,
  and every cell value.
- A rollback can restore the JSON key or revert the implementation commit.
- Future worlds are likely to need some form of progression/cap table, even if
  their columns differ.

Known risk:

- The table is wide and dense, so visual and text comparison must be stricter
  than the term-card pilot.
- Because `rewardAmount`, `minHonor`, and `swordShardGuide` are embedded in the
  same table, the next pilot must not treat those as separate schemas.
- Column definitions are still renderer-owned. Moving them is a later
  renderer-constant audit, not part of the next pilot.

## Current Code/Data Mapping

Existing data:

- `data/regulation.json`
- key: `levelCaps`
- current row count: 14
- current row keys:
  - `levelCap`
  - `fixedExperience`
  - `minGrowth`
  - `minReward`
  - `minHonor`
  - `maxGrowth`
  - `maxReward`
  - `growthPerSession`
  - `rankLimit`
  - `rewardAmount`
  - `swordShardGuide`

Existing renderer:

- `assets/js/renderRegulation.js`
- `LEVEL_CAP_COLUMNS`
- `renderLevelCaps(regulation)`
- `renderTable(rows, columns)`
- `renderRegulation(root)` appends `renderLevelCaps(regulation)` before
  `renderTermExplanations(regulation)`

Current section/DOM contracts to preserve:

- section id: `level-caps`
- TOC anchor: `#level-caps`
- table wrapper class: `.regulation-table-wrap`
- table class: `.regulation-table`
- existing header labels and row order
- existing section order before `term-explanations`

## Proposed Next Module Shape

Do not create this file in B7. This is a future implementation target.

Expected module path:

- `assets/js/world/regulation/levelCapsData.js`

Expected export:

- `levelCaps`

Expected ownership change:

- remove `levelCaps` from `data/regulation.json`
- import `levelCaps` in `assets/js/renderRegulation.js`
- attach `levelCaps` to the loaded regulation object beside
  `termExplanations`

Expected connection pattern:

```js
const regulation = {
  ...await loadJson(REGULATION_DATA_PATH),
  termExplanations,
  levelCaps
};
```

Renderer behavior to preserve:

- `renderLevelCaps(regulation)` keeps reading `regulation.levelCaps`
- `LEVEL_CAP_COLUMNS` remains in `renderRegulation.js`
- `renderTable()` remains unchanged
- no row normalization or value rewriting
- no formula parsing
- no executable rule logic

## Cache-Bust Targets For The Next Pilot

Review and update only the affected public chain:

- `regulation.html` main module query
- `assets/js/main.js` import query for `renderRegulation.js`
- `assets/js/renderRegulation.js` `REGULATION_DATA_PATH` query for
  `data/regulation.json`
- public availability of
  `assets/js/world/regulation/levelCapsData.js`

Future implementation gate should explicitly decide whether the imported data
module path itself carries a version query. If it does not, the rollout check
must still verify the new module path with HTTP 200.

Do not update `updates.json` unless a separate content-release gate explicitly
requires it.

## QA For The Next Pilot

Static checks:

- `node --check assets/js/renderRegulation.js`
- `data/regulation.json` parse OK
- data module import smoke OK
- `levelCaps.length === 14`
- row keys match the current set
- row data matches the previous JSON key exactly
- `renderLevelCaps(regulation)` call path remains
- `LEVEL_CAP_COLUMNS` unchanged
- `renderTable()` unchanged

Public delivery checks:

- public `regulation.html`: HTTP 200
- public cache-bust chain uses the new key
- public `renderRegulation.js`: HTTP 200
- public `renderRegulation.js` imports `levelCapsData.js`
- public `levelCapsData.js`: HTTP 200 and exports `levelCaps`
- public `data/regulation.json`: HTTP 200 and no `levelCaps` key
- no broken import path or checked public 404
- no module-load or regulation-data fetch failure

DOM/display checks:

- `#level-caps` exists
- level-cap table row count remains 14
- header labels remain unchanged
- cell text remains unchanged
- `#term-explanations` still renders 12 cards after the level-cap table
- no `undefined`, `[object Object]`, empty headers, or empty cells appear
- TOC link to `#level-caps` remains
- active TOC behavior has no obvious regression
- desktop/mobile table readability is at least lightly checked

## Rollback

Rollback options:

1. Revert the implementation commit.
2. Restore `levelCaps` in `data/regulation.json`, remove the module import,
   and return `renderRegulation(root)` to the previous merge shape.

Because the next pilot should not touch ops-core behavior, rollback should not
affect calendar, mypage, session-post, session-detail, membership, or Discord
sync.

## Out Of Scope For The Next Pilot

The first level-cap implementation gate must not include:

- moving `LEVEL_CAP_COLUMNS`
- splitting reward values into a new table
- splitting honor or Sword Shard values into a new table
- changing level-cap values
- changing reward, honor, growth, or rank-limit meanings
- changing `renderTable()`
- changing table CSS classes
- changing section id `level-caps`
- changing anchors or TOC behavior
- moving long house rules
- moving magic-angel rulings
- moving fumble/lower-bound growth into a separate schema
- JSON/fetch migration
- renderer rewrite
- `updates.json` change
- auth, membership, RPC, DB/RPC/RLS, Edge Function, Discord, or secret changes

## Final Decision

Proceed to a future Phase 3-B8 planning/spec gate for:

- level-cap table row data module

Do not implement it directly from this B7 summary. The next gate should first
freeze the current `levelCaps` row behavior and comparison checklist, similar
to the Phase 3-B4 term-card behavior spec.

## Phase 3-B8 Level-Cap Behavior Spec

Phase 3-B8 freezes the current `levelCaps` row-data behavior before any
implementation:

- `docs/world-template-regulation-level-caps-spec.md`

Fixed facts:

- current source is `data/regulation.json` key `levelCaps`
- current row count is 14
- current display order is `Lv2` through `Lv15`
- current row shape is 11 non-empty string fields
- current `LEVEL_CAP_COLUMNS` count is 11
- `renderLevelCaps(regulation)` still calls
  `renderTable(rows, LEVEL_CAP_COLUMNS)`
- section id remains `level-caps`
- TOC anchor remains `#level-caps`
- table classes remain `.regulation-table-wrap` and `.regulation-table`

The recommended next implementation remains narrow:

- move only the `levelCaps` row array to
  `assets/js/world/regulation/levelCapsData.js`
- export `levelCaps`
- keep `LEVEL_CAP_COLUMNS` and `renderTable()` in
  `assets/js/renderRegulation.js`
- do not merge regulation level caps with calendar-side
  `data/calendarConfig.json` level-cap date ranges
- do not introduce standalone JSON/fetch loading

Phase 3-B8 is docs-only and does not include implementation, HTML, CSS,
JavaScript, JSON/data, renderer, regulation copy, `updates.json`, or reusable
ops core changes.

## Phase 3-B9 Level-Cap Data Module

Phase 3-B9 implements the selected second pilot:

- `docs/world-template-regulation-level-caps-data-module-result.md`

Implementation summary:

- created `assets/js/world/regulation/levelCapsData.js`
- exported `levelCaps`
- moved the 14 `levelCaps` rows unchanged
- removed only the `levelCaps` key from `data/regulation.json`
- imported `levelCaps` in `assets/js/renderRegulation.js`
- kept `renderLevelCaps(regulation)` and `renderTable()` behavior unchanged
- kept `LEVEL_CAP_COLUMNS` in `assets/js/renderRegulation.js`
- updated the regulation cache-bust chain to
  `20260617-regulation-level-caps-data-module`

Confirmed by smoke/snapshot checks:

- data module import OK
- row count remains 14
- order remains `Lv2` through `Lv15`
- row shape remains 11 non-empty string fields
- module data exactly matches the old `HEAD:data/regulation.json`
  `levelCaps`
- current `data/regulation.json` parses and has no `levelCaps` key
- `LEVEL_CAP_COLUMNS`, `renderTable()`, `data/calendarConfig.json`, and
  `assets/css/style.css` were unchanged

Public delivery and browser DOM checks remain for a later rollout-check gate.

## Phase 3-B10 Level-Cap Public Rollout Check

Phase 3-B10 confirms the public delivery of the second data-module pilot:

- `docs/world-template-regulation-level-caps-data-module-public-check.md`

Public checks passed for the static delivery path:

- `regulation.html`: HTTP 200
- `main.js`: HTTP 200
- `renderRegulation.js`: HTTP 200
- `levelCapsData.js`: HTTP 200 and exports `levelCaps`
- `data/regulation.json`: HTTP 200, parse OK, and no `levelCaps` key
- cache-bust chain:
  `20260617-regulation-level-caps-data-module`
- checked broken path / 404 count: 0
- checked cache-mixing risk: not observed

Display-equivalent checks passed:

- level-cap rows: 14
- order: `Lv2` through `Lv15`
- row shape: 11 expected fields
- cell values: non-empty strings
- no `undefined`, `[object Object]`, or empty rows in the checked data path
- public renderer keeps `renderLevelCaps(regulation)` before
  `renderTermExplanations(regulation)`

Browser visual review, desktop/mobile review, scroll-through active TOC, and
non-regulation page QA remain limited or not tested.

## Phase 3-B11 Level-Cap Pilot Summary And Next Candidate

Phase 3-B11 summarizes the second data-module pilot and selects the next
candidate:

- `docs/world-template-regulation-level-caps-data-pilot-summary.md`

Summary:

- `termExplanations` proved the data-module pattern for repeated card data
- `levelCaps` proved the data-module pattern for table-shaped row data
- both pilots avoided an extra fetch and kept GitHub Pages delivery simple
- both pilots required explicit cache-mixing checks after removing a key from
  `data/regulation.json`
- renderer behavior, DOM ids, anchors, CSS classes, and active TOC behavior
  remained stable

Updated constraints:

- column definitions remain separate gates
- shared renderers remain separate gates
- reward amount and honor/Sword Shard values should not be split out of
  `levelCapsData.js`
- standalone JSON/fetch migration remains out of scope

Selected next candidate:

- short note card
- first concrete target: the `reward` section `type: "callout"` block

The next gate should be a behavior/spec freeze for that callout block before
any implementation. It should not move the whole reward section, change
`renderBlock()`, or introduce a generic block registry.

## Phase 3-B12 Reward Callout Behavior Spec

Phase 3-B12 completes the pre-implementation spec gate for the selected short
note:

- `docs/world-template-regulation-reward-callout-spec.md`

Fixed scope:

- target is only the `reward` section `type: "callout"` block
- current title is `超過報酬の例`
- current body is 4 plain string paragraphs
- current renderer is `renderBlock(block)`
- current CSS class is `.regulation-callout`
- parent section id and anchor remain `reward` / `#reward`

The next implementation gate should move only this block's data. It should not
move the whole reward section, reward paragraphs, `renderBlock()`, CSS classes,
anchors, `termExplanationsData.js`, `levelCapsData.js`, or reusable ops core.

## Phase 3-B13 Reward Callout Data Module

Phase 3-B13 implements the third small data-module pilot:

- `docs/world-template-regulation-reward-callout-data-module-result.md`

Summary:

- `assets/js/world/regulation/rewardCalloutBlocksData.js` owns the selected
  reward callout block
- export name is `rewardCalloutBlocks`
- `data/regulation.json` keeps the `reward` section and reward paragraph block
- `data/regulation.json` no longer contains the selected reward callout block
- `renderRegulation(root)` inserts the imported callout block at the existing
  reward block index for rendering
- `renderBlock()` and `renderDataSection()` remain renderer-owned and unchanged
- JSON/fetch migration remains out of scope

Confirmed local checks:

- module import OK
- block count: 1
- type/title/4 paragraphs match the old JSON block exactly
- current `data/regulation.json` parse OK
- current reward section exists without the moved callout block

Next gate:

- public rollout check for the reward callout data module and cache-bust chain

## Phase 3-B14 Reward Callout Public Rollout Check

Phase 3-B14 confirms the third data-module pilot on public delivery:

- `docs/world-template-regulation-reward-callout-data-module-public-check.md`

Summary:

- the public cache-bust chain uses
  `20260617-regulation-reward-callout-data-module`
- public `renderRegulation.js` imports `rewardCalloutBlocksData.js`
- public `rewardCalloutBlocksData.js` exports one `rewardCalloutBlocks` block
- public `data/regulation.json` keeps the `reward` section but no longer owns
  the moved callout block
- public DOM renders the `超過報酬の例` callout exactly once with 4 paragraphs
- stale JSON duplicate-display guard is present in public
  `renderRegulation.js`

This confirms the data-module pattern has now passed public checks for:

- repeated card data
- table row data
- one nested callout block

Next recommended gate:

- summarize the reward callout pilot and decide whether to stop Phase 3-B pilots
  or choose one more small regulation data target

## Phase 3-B15 Reward Callout Pilot Summary

Phase 3-B15 summarizes the third data-module pilot and selects the next
candidate:

- `docs/world-template-regulation-reward-callout-data-pilot-summary.md`

Summary:

- `termExplanations` proved repeated card data
- `levelCaps` proved table row data
- `rewardCalloutBlocks` proved one nested section block
- all three pilots avoided extra fetches
- all three pilots kept DOM ids, anchors, CSS classes, active TOC behavior, and
  reusable ops core outside the data move
- nested block moves may need stale JSON duplicate-display guards

Updated constraints:

- shared renderers remain separate gates
- column definitions remain separate gates
- reward amount, honor, and Sword Shard values should not be split out of
  `levelCapsData.js` until a table/column schema gate exists
- long rules and magic-angel rulings remain too heavy for the next pilot

Selected next candidate:

- short note subsection item
- first concrete target:
  `general-skills` subsection item `注釈2：『制限』について`

The next gate should freeze this subsection item before implementation. It
should not move the whole `general-skills` section, change `renderBlock()`,
change `renderDataSection()`, introduce a generic registry, or touch reusable
ops core.

## Phase 3-B16 General Skill Note Data Module

Phase 3-B16 completed the selected nested subsection-item pilot:

- `docs/world-template-regulation-general-skill-note-data-module-result.md`

Summary:

- `generalSkillNoteSubsectionsData.js` now owns the single note item
  `注釈2：『制限』について`
- `data/regulation.json` no longer contains that item, but still owns
  `general-skills`, the parent `subsections` block, and all sibling items
- `renderRegulation.js` imports the module and composes it back at item index 7
- stale JSON duplicate-display protection is scoped to the moved item title
- local smoke confirmed the composed current and stale data both match the old
  item array exactly
- public static delivery and DOM checks passed after GitHub Pages rollout

Updated evaluation:

- data modules now work for four shapes: repeated cards, table rows, one nested
  section block, and one nested subsection item
- nested-item moves remain safe only when the target item and insert position
  are unambiguous
- generic registries, whole-section moves, and long-rule schemas should remain
  separate gates

## Phase 3-B17 Original General Skill Bonus Data Module

Phase 3-B17 selected and completed one more low-risk subsection-item pilot:

- `docs/world-template-regulation-original-general-skill-bonus-data-module-result.md`

Selected target:

- `original-general-skills`
- block index 2
- item index 2
- title: `オリジナル一般技能による「技能レベルボーナス」`

Summary:

- `originalGeneralSkillBonusSubsectionsData.js` owns the single target item
- `data/regulation.json` still owns the parent section, parent block, and
  sibling items
- `renderRegulation.js` composes the item back only for
  `original-general-skills` block index 2
- stale JSON duplicate-display protection is scoped to the moved title
- local snapshot confirmed current and stale composition both match old HEAD
- public static delivery and DOM checks passed

Updated evaluation:

- data modules now cover repeated cards, table rows, one nested section block,
  one general-skills nested subsection item, and one original-general-skills
  nested subsection item
- no generic registry has been introduced
- further moves should first summarize whether more small pilots are still
  useful
