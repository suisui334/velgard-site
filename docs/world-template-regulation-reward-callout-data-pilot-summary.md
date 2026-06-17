# World Template Regulation Reward Callout Data Pilot Summary

Phase 3-B15 summarizes the third regulation data-module pilot and selects the
next candidate.

This is a docs-only decision record. It does not change implementation, HTML,
CSS, JavaScript, JSON/data, data modules, renderers, regulation copy,
`updates.json`, or reusable ops core behavior.

Baseline:

- `da56e7c Check regulation reward callout rollout`

## Completed Pilot

Third data-module pilot target:

- `reward` section `type: "callout"` block
- title: `超過報酬の例`

Created file:

- `assets/js/world/regulation/rewardCalloutBlocksData.js`

Created export:

- `rewardCalloutBlocks`

Removed source block:

- `data/regulation.json` `sections[].id === "reward"` block index 1
- block type: `callout`
- title: `超過報酬の例`

Import connection:

- `assets/js/renderRegulation.js`

Renderer contract preserved:

- `renderRegulation(root)` still loads `data/regulation.json`
- imported `rewardCalloutBlocks` is inserted into the render copy of the
  `reward` section
- `renderDataSection(sectionData)` remains the section renderer call path
- `renderBlock(block)` remains the block renderer call path
- `renderBlock(block)` `type === "callout"` branch was not changed
- section id remains `reward`
- TOC anchor remains `#reward`
- `.regulation-callout` remains the callout CSS class
- callout itself still has no DOM id
- active TOC behavior was not rewritten

Preserved output:

- callout display count: 1
- display order: after the reward paragraph block, equivalent to former block
  index 1
- title: `超過報酬の例`
- paragraph count: 4
- paragraph text: unchanged
- reward section paragraph block: unchanged
- no checked `undefined`, `[object Object]`, empty heading, or empty callout
- public `termExplanations` cards: 12
- public `levelCaps` rows: 14

Stale JSON mitigation:

- `renderRegulation.js` now filters the moved reward callout by type/title in
  the render copy before inserting the module-owned block
- this prevents duplicate public display if stale JSON still contains the moved
  callout while the new renderer is live

## Public Rollout Result

Phase 3-B14 confirmed the rollout:

- `docs/world-template-regulation-reward-callout-data-module-public-check.md`

Public checks passed:

- public `regulation.html`: HTTP 200
- public `main.js`: HTTP 200
- public `renderRegulation.js`: HTTP 200
- public `rewardCalloutBlocksData.js`: HTTP 200 and exports
  `rewardCalloutBlocks`
- public `data/regulation.json`: HTTP 200, parse OK, and no selected reward
  callout block
- public JSON keeps the `reward` section and reward paragraph block
- cache-bust chain:
  `20260617-regulation-reward-callout-data-module`
- checked public 404 count: 0
- checked fetch failure count: 0
- browser error log entries checked in the pass: 0

Public DOM checks passed:

- `#reward` section exists
- TOC link `#reward` exists
- target reward callout count: 1
- reward callout count: 1
- callout title remains `超過報酬の例`
- callout paragraph count remains 4
- `.regulation-callout` remains present
- callout itself has no DOM id
- no duplicate reward callout display was observed
- no checked `undefined`, `[object Object]`, or empty reward callout was
  observed

Remaining limited or not-tested QA:

- full desktop/mobile manual visual review: `limited`
- scroll-through active TOC behavior: `limited`
- non-regulation pages: `not_tested`
- authenticated role-specific behavior: `not_tested`
- data-changing workflows, DB/RPC/RLS, Edge Functions, and Discord sync:
  `not_tested`

These remaining items are acceptable for this pilot because the gate was a
world-site static display/data split and did not touch operational behavior.

## What Worked

The reward callout pilot succeeded because:

- the moved target was a single block object
- the existing shared renderer already understood `type: "callout"`
- the parent section could remain in `data/regulation.json`
- the merge point stayed local to `renderRegulation(root)`
- `renderBlock()` and `renderDataSection()` did not need to change
- no extra `fetch` path was introduced
- no new async failure branch was introduced
- no text normalization or HTML interpretation was needed
- GitHub Pages served the new module path with HTTP 200
- public DOM output could be checked by count, order, title, paragraph count,
  CSS class, and anchor

The main improvement over the first two pilots is that the same data-module
pattern worked for one nested section block, not only top-level regulation keys.

## Updated Data Module Evaluation

Three completed pilots:

- `termExplanations`
- `levelCaps`
- `rewardCalloutBlocks`

Updated strengths:

- The page still performs one regulation JSON load.
- Split data rides on the ES module graph.
- GitHub Pages serves each data module directly.
- Public rollout checks can verify HTML, main module, renderer, data module,
  JSON, and DOM state with explicit status/count checks.
- The renderer can remain mostly unchanged when the merge point is kept local.
- DOM ids, anchors, CSS classes, and active TOC behavior can stay untouched.
- The approach has now worked for repeated cards, table row data, and one
  nested section block.

Updated cautions:

- Removing a top-level key or nested block from `data/regulation.json` always
  requires cache-mixing checks.
- Dangerous public combinations remain:
  - new JSON plus old renderer
  - old HTML/main cache-bust plus new renderer
  - new renderer plus missing data module
  - old JSON plus new renderer causing duplicate nested-block display
- Nested-block moves may need stale JSON duplicate-display guards.
- Column definitions and shared renderers should stay separate gates.
- Data modules are source files, not the final non-developer editing model.
- Standalone JSON/fetch migration remains a later decision.
- Module import cache policy should be considered whenever an existing data
  module is edited.

Decision:

- The data-module approach remains usable for one more small, isolated
  regulation content group.
- Do not use it yet for long rules, special rulings, table column definitions,
  whole sections, or shared renderer behavior.

## Candidate Re-Evaluation

| Candidate | Classification | Evaluation |
| --- | --- | --- |
| Reward amount table | C. Keep in existing structure for now | `rewardAmount` is already a column inside `levelCapsData.js`. Splitting it into a standalone table would duplicate or fragment the level-cap table and needs a separate table/column schema decision first. |
| Sword Shard / honor table | C. Keep in existing structure for now | `minHonor` and `swordShardGuide` are already columns inside `levelCapsData.js`. A standalone split should wait for a table-column schema decision and should not be bundled with another move. |
| Short note card additional candidate | A. Next pilot candidate | Current `general-skills` contains short note-like subsection items. A single note item can test one nested item move while keeping `renderBlock()` and `renderDataSection()` unchanged. |
| Individual ruling card | B. Later candidate | Short rulings can move after one subsection-item pilot, but many current rulings are mixed into longer subsection groups. They need a behavior/spec gate first. |
| Fumble experience card | D. Do not split now | Current fumble experience content is already part of `termExplanationsData.js`. Splitting it again would fragment the term-card group. |
| Lower-bound growth card | D. Do not split now | Current lower-bound growth content is already part of `termExplanationsData.js`. Keep it with the term-card group unless a future card schema changes the whole group. |
| Magic-angel ruling card | C. Keep fixed for now | The current magic-angel ruling is long, Velgard-specific, and has 51 paragraphs in a subsection item. It should wait for a long-body/special-ruling schema. |
| Long house rules | C. Keep fixed for now | Long rules need a stable block schema for headings, paragraphs, lists, details, callouts, and tables before module extraction. |
| Growth rules overall | C. Keep fixed for now | Growth-related content is already split across `termExplanationsData.js`, `levelCapsData.js`, and longer section text. Moving it as a whole would cross current pilot boundaries. |

Classification notes:

- A means suitable for the next implementation pilot if scoped narrowly.
- B means viable after another pilot or a dedicated schema review.
- C means keep in the current structure for now.
- D means do not make it an independent pilot target.

## Selected Next Candidate

Selected candidate:

- Short note subsection item

Concrete first target:

- section id: `general-skills`
- block index: 0
- block type: `subsections`
- subsection item index: 7
- title: `注釈2：『制限』について`

Why this candidate:

- It is one small subsection item, not a whole section.
- It has a simple current shape: `title` plus one paragraph.
- It uses the existing `renderBlock(block)` `type === "subsections"` branch.
- It does not require moving `renderBlock()` or `renderDataSection()`.
- It does not require changing `renderTable()` or column definitions.
- It is not already owned by `termExplanationsData.js` or `levelCapsData.js`.
- It has no dedicated DOM id.
- It is easy to compare by item count, item index, title, paragraph count,
  paragraph text, CSS class, and section anchor.
- A rollback can restore the item in `data/regulation.json` or revert the
  implementation commit.
- Future worlds are likely to need small note/ruling subsection items.

Known risks:

- The item is nested inside a `subsections` block, one level deeper than the
  reward callout block.
- The first implementation must avoid a generic section or subsection registry.
- The first implementation must move only the selected item, not the whole
  `general-skills` section.
- If stale JSON still contains the moved item, the renderer may need a
  duplicate-display guard similar to the reward callout pilot.

## Proposed Next Module Shape

Do not create this file in B15. This is a future implementation target.

Expected module path:

- `assets/js/world/regulation/generalSkillNoteSubsectionsData.js`

Expected export:

- `generalSkillNoteSubsections`

Expected data shape:

```js
export const generalSkillNoteSubsections = [
  {
    title: "注釈2：『制限』について",
    paragraphs: [
      "Current paragraph"
    ]
  }
];
```

Expected ownership change:

- remove only the current `general-skills` subsection item with title
  `注釈2：『制限』について` from `data/regulation.json`
- import `generalSkillNoteSubsections` in
  `assets/js/renderRegulation.js`
- inject the imported item back at the same subsection item position before
  `renderDataSection(sections.get("general-skills"))`
- keep `renderDataSection(sectionData)` and `renderBlock(block)` behavior
  unchanged

Expected connection approach:

- keep the `general-skills` section in `data/regulation.json`
- keep the `subsections` block in `data/regulation.json`
- keep all other general-skill subsection items in `data/regulation.json`
- rebuild only the loaded `general-skills` subsection block's `items` array
  with the imported item in the same position
- add a narrow stale JSON duplicate guard if needed
- do not create a generic block or subsection registry yet

## Cache-Bust Targets For The Next Pilot

Review and update only the affected public chain:

- `regulation.html` main module query
- `assets/js/main.js` import query for `renderRegulation.js`
- `assets/js/renderRegulation.js` `REGULATION_DATA_PATH` query for
  `data/regulation.json`
- public availability of
  `assets/js/world/regulation/generalSkillNoteSubsectionsData.js`

If the imported data module path does not carry a query, the rollout check must
still verify that the new module path is HTTP 200.

Do not update `updates.json` unless a separate content-release gate explicitly
requires it.

## QA For The Next Pilot

Static checks:

- `node --check assets/js/renderRegulation.js`
- `node --check assets/js/world/regulation/generalSkillNoteSubsectionsData.js`
- `data/regulation.json` parse OK
- data module import smoke OK
- moved subsection item count remains 1
- item title remains `注釈2：『制限』について`
- paragraph count remains 1
- paragraph text matches the previous JSON item exactly
- `renderBlock(block)` `subsections` branch unchanged
- `.regulation-subsection` class unchanged
- `general-skills` section id and TOC anchor unchanged

Public delivery checks:

- public `regulation.html`: HTTP 200
- public cache-bust chain uses the new key
- public `renderRegulation.js`: HTTP 200
- public `renderRegulation.js` imports the new data module
- public data module: HTTP 200 and exports
  `generalSkillNoteSubsections`
- public `data/regulation.json`: HTTP 200 and the selected subsection item is
  no longer duplicated in JSON
- no broken import path or checked public 404
- no module-load or regulation-data fetch failure

Display checks:

- `#general-skills` section still exists
- `#general-skills` TOC anchor remains
- selected note item appears once
- selected note item remains after the preceding general-skill items
- title remains `注釈2：『制限』について`
- paragraph remains unchanged
- `.regulation-subsection` remains
- no `undefined`, `[object Object]`, empty title, or empty note card appears
- reward callout still renders once
- `levelCaps` table still renders 14 rows
- `termExplanations` still renders 12 cards

## Rollback

Rollback options:

1. Revert the future implementation commit.
2. Restore the subsection item inside `data/regulation.json`, remove the module
   import, and return the `general-skills` subsection items to the previous
   shape.

Rollback should not affect calendar, mypage, session-post, session-detail,
membership, Discord sync, or any reusable ops core behavior.

## Out Of Scope For The Next Pilot

The first subsection-item implementation gate must not include:

- moving the entire `general-skills` section
- moving the whole `subsections` block
- moving multiple general-skill items at once
- changing general-skill text
- moving reward amount, honor, or Sword Shard values out of
  `levelCapsData.js`
- changing `renderBlock()`
- changing `renderDataSection()`
- changing `renderTable()`
- changing `LEVEL_CAP_COLUMNS`
- changing CSS classes
- changing section id `general-skills`
- changing anchors or active TOC behavior
- changing `rewardCalloutBlocksData.js`
- changing `levelCapsData.js`
- changing `termExplanationsData.js`
- standalone JSON/fetch migration
- renderer rewrite
- `updates.json` change
- auth, membership, RPC, DB/RPC/RLS, Edge Function, Discord, or secret changes

## Final Decision

Proceed to a future behavior/spec gate for:

- short note subsection item data module
- concrete first target:
  `general-skills` subsection item `注釈2：『制限』について`

Do not implement it directly from this B15 summary. The next gate should first
freeze the current subsection item behavior, output, comparison checklist, and
exact merge approach.

## Phase 3-B16 Follow-Up: General Skill Note Pilot

Phase 3-B16 completed the selected follow-up as one combined spec,
implementation, smoke, and public rollout gate:

- `docs/world-template-regulation-general-skill-note-data-module-result.md`

Outcome:

- added `assets/js/world/regulation/generalSkillNoteSubsectionsData.js`
- export name: `generalSkillNoteSubsections`
- moved only the `general-skills` subsection item
  `注釈2：『制限』について`
- kept the parent `general-skills` section and `subsections` block in
  `data/regulation.json`
- kept all sibling subsection items in `data/regulation.json`
- inserted the module item back at index 7 before existing rendering
- added a narrow stale JSON duplicate guard for that item title
- kept `renderBlock()` and `renderDataSection()` bodies unchanged
- public DOM confirmed the item appears once at index 7

This confirms the data-module pattern has now covered repeated cards, table
rows, one section block, and one nested subsection item without adding fetches
or moving shared renderer behavior.
