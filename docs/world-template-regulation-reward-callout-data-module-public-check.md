# World Template Regulation Reward Callout Data Module Public Check

Phase 3-B14 verifies the public rollout of the Phase 3-B13 reward callout data
module split.

This is a public delivery check. It does not change implementation, HTML, CSS,
JavaScript, JSON/data, renderers, regulation copy, `updates.json`, or reusable
ops core behavior.

Baseline:

- `21cb352 Extract regulation reward callout data`

Public base:

- `https://suisui334.github.io/velgard-site/`

Expected cache-bust:

- `20260617-regulation-reward-callout-data-module`

## Public Static Delivery

Checked public files on GitHub Pages:

| Public file | Result |
| --- | --- |
| `regulation.html` | HTTP 200 |
| `assets/js/main.js?v=20260617-regulation-reward-callout-data-module` | HTTP 200 |
| `assets/js/renderRegulation.js?v=20260617-regulation-reward-callout-data-module` | HTTP 200 |
| `assets/js/world/regulation/rewardCalloutBlocksData.js` | HTTP 200 |
| `data/regulation.json?v=20260617-regulation-reward-callout-data-module` | HTTP 200 |
| `data/regulation.json` | HTTP 200 |
| `assets/css/style.css?v=20260615-regulation-wide-layout` | HTTP 200 |

Public file equivalence:

- public `regulation.html` matched local `HEAD` after line-ending normalization
- public `main.js` matched local `HEAD` after line-ending normalization
- public `renderRegulation.js` matched local `HEAD` after line-ending
  normalization
- public `rewardCalloutBlocksData.js` matched local `HEAD` after line-ending
  normalization
- public `data/regulation.json` matched local `HEAD` after line-ending
  normalization

Checked broken public path / fetch failures:

- checked 404 count: 0
- checked fetch failure count: 0

## Cache-Bust Chain

Confirmed:

- public `regulation.html` references
  `assets/js/main.js?v=20260617-regulation-reward-callout-data-module`
- public `main.js` imports
  `./renderRegulation.js?v=20260617-regulation-reward-callout-data-module`
- public `renderRegulation.js` loads
  `data/regulation.json?v=20260617-regulation-reward-callout-data-module`
- public `renderRegulation.js` imports
  `./world/regulation/rewardCalloutBlocksData.js`

Cache-mixing risks checked:

- new `data/regulation.json` plus old `renderRegulation.js`: not observed
- old `regulation.html` plus new `renderRegulation.js`: not observed
- new `renderRegulation.js` plus missing `rewardCalloutBlocksData.js`: not
  observed
- old `data/regulation.json` plus new `renderRegulation.js` causing duplicate
  callout display: not observed in public DOM

## Public Renderer Checks

Public `renderRegulation.js` confirmed:

- imports `rewardCalloutBlocksData.js`
- contains `withRewardCalloutBlocks(sectionData)`
- contains stale-data duplicate filtering through `isMovedRewardCalloutBlock`
- inserts `...rewardCalloutBlocks` into the render copy of the reward section
- keeps the `renderBlock(block)` `type === "callout"` branch present
- keeps `renderDataSection(sectionData)` present
- keeps `renderTable()` and level-cap rendering untouched in this gate

Because public `renderRegulation.js` matched local `HEAD`, this also confirms
the public renderer has the same stale JSON duplicate-display guard as Phase
3-B13.

## Public Data Module Checks

Public `rewardCalloutBlocksData.js` confirmed:

- exports `rewardCalloutBlocks`
- imported/evaluated as an array in the static smoke check
- block count: 1
- block type: `callout`
- title: `超過報酬の例`
- paragraph count: 4
- every paragraph is a non-empty plain string
- no `undefined` text in the exported block data
- no `[object Object]` text in the exported block data

The public data module matched local `HEAD` after line-ending normalization.

## Public Regulation JSON Checks

Public `data/regulation.json` confirmed:

- HTTP 200
- parse OK
- reward section exists
- reward section block count: 1
- reward section remaining block types:
  - `paragraphs`
- target reward callout count in JSON: 0
- reward paragraph block remains present
- top-level `termExplanations` key: absent
- top-level `levelCaps` key: absent

The non-query `data/regulation.json` path was also checked:

- HTTP 200
- parse OK
- target reward callout count in JSON: 0
- matched local `HEAD` after line-ending normalization

This confirms the JSON ownership change is live publicly and not only visible
through the cache-busted renderer path.

## Public DOM Check

The public `regulation.html` page was loaded in the browser and inspected after
page load.

Confirmed:

- app root rendered
- `#reward` section exists
- `#reward .article-box` exists
- reward section direct children are:
  - index 0: `h2`
  - index 1: `div.regulation-block`
  - index 2: `div.regulation-callout`
- target reward callout count: 1
- reward callout count: 1
- callout title: `超過報酬の例`
- callout paragraph count: 4
- callout paragraph text matches the public data module values
- `.regulation-callout` class is present
- callout itself has no DOM id
- parent section id remains `reward`
- TOC link `#reward` exists
- no `undefined` text was observed in the checked body text
- no `[object Object]` text was observed in the checked body text
- no empty reward callout was observed
- `termExplanations` cards: 12
- `levelCaps` table rows: 14
- browser error log entries checked in this pass: 0

## CSS And Anchor Checks

Public CSS confirmed:

- `.regulation-callout`: present
- `.regulation-section`: present
- `.toc a.toc-link-active`: present

Anchor and active TOC related checks:

- parent section id `reward`: present
- TOC link `#reward`: present
- active TOC implementation was not changed in this gate

## Limited And Not Tested

Limited or not tested in this gate:

- full desktop/mobile manual visual review: `limited`
- scroll-through active TOC behavior: `limited`
- non-regulation pages: `not_tested`
- authenticated role-specific behavior: `not_tested`
- data-changing workflows, DB/RPC/RLS, Edge Functions, and Discord sync:
  `not_tested`

Reason:

- this gate focused on public static delivery, module availability, cache-bust
  consistency, JSON state, and browser DOM output for the reward section
- no implementation, auth, data-changing, or operations behavior was touched

## Result

Phase 3-B14 public rollout check passed for the checked static delivery and
browser DOM path.

Observed public state:

- `rewardCalloutBlocksData.js` is publicly available
- public `renderRegulation.js` imports the module
- public `renderRegulation.js` includes the stale JSON duplicate guard
- public `data/regulation.json` no longer carries the selected reward callout
  block
- public reward section still renders `超過報酬の例` exactly once
- public reward callout still has 4 paragraphs
- no checked broken import path, fetch failure, or 404 was observed
- no duplicate callout display was observed

## Next Step

Recommended next gate:

- summarize the reward callout data-module pilot and decide whether to stop the
  Phase 3-B pilot series or choose another small regulation data candidate

Keep out of scope until a separate gate:

- reward section-wide data migration
- all-callout registry
- reward amount table migration
- long rule or magic-angel data migration
- standalone JSON/fetch migration
- renderer rewrite
- reusable ops core integration

## Phase 3-B15 Follow-Up

Phase 3-B15 summarizes the reward callout pilot and selects the next candidate:

- `docs/world-template-regulation-reward-callout-data-pilot-summary.md`

Decision:

- the reward callout pilot is complete through public rollout
- data modules have now succeeded for repeated cards, table rows, and one
  nested section block
- reward amount, honor, and Sword Shard values should not be split out of
  `levelCapsData.js` without a separate table/column schema gate
- the next candidate should be one small subsection item, not a whole section
  or long-rule group
- selected next target:
  `general-skills` subsection item `注釈2：『制限』について`

The next gate should be a behavior/spec freeze for that subsection item before
any implementation.
