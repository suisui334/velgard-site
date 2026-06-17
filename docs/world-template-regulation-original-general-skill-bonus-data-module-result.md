# Regulation Original General Skill Bonus Data Module Result

Date: 2026-06-17

Phase: 3-B17 regulation low-risk data module candidate selection,
implementation, smoke check, and public rollout check.

Implementation commit: `975deb3 Extract regulation original general skill bonus data`

## Selected Candidate

Selected target:

- `data/regulation.json`
- `sections[].id === "original-general-skills"`
- section title: `オリジナル一般技能`
- block index: 2
- block type: `subsections`
- item index: 2
- item title: `オリジナル一般技能による「技能レベルボーナス」`

Selection reason:

- one subsection item only
- simple shape: `title` plus one plain-string paragraph
- no `type`, `items`, or nested `sections`
- existing `renderBlock(block)` `subsections` branch can render it unchanged
- current position is unambiguous: `original-general-skills` block index 2,
  item index 2
- rollback is straightforward by restoring the item to `data/regulation.json`
- it does not involve table columns, long rules, active TOC, DOM ids, auth,
  DB/RPC/RLS, Discord, or reusable ops core

Rejected for this gate:

- whole-section moves
- multiple item moves
- table rows or column definitions
- magic-angel rulings
- long house rules
- growth-rule clusters
- generic subsection registries

## Current Behavior Snapshot

Current data shape before the move:

- fields: `title`, `paragraphs`
- `paragraphs` count: 1
- paragraph values are plain strings
- no HTML string conversion
- no empty or undefined values

Renderer path:

- `renderRegulation(root)` loads `data/regulation.json`
- `withRegulationDataModules(sectionData)` composes module-owned data
- `renderDataSection(sectionData)` renders the parent section
- `renderBlock(block)` handles `block.type === "subsections"`
- each subsection item renders as `article.regulation-subsection`
- item title renders as `h3`
- paragraph renders through `appendParagraphs`

DOM and CSS behavior:

- parent section id remains `original-general-skills`
- TOC anchor remains `#original-general-skills`
- active TOC continues to use `.regulation-section[id]`
- target item itself has no DOM id
- subsection class remains `.regulation-subsection`
- subsection group class remains `.regulation-subsections`

The text is Velgard-specific, while the `title` plus `paragraphs` subsection
shape is reusable for future world-site templates.

## Implementation

New data module:

- `assets/js/world/regulation/originalGeneralSkillBonusSubsectionsData.js`

Export:

- `originalGeneralSkillBonusSubsections`

Removed from `data/regulation.json`:

- only the `original-general-skills` subsection item
  `オリジナル一般技能による「技能レベルボーナス」`

Kept in `data/regulation.json`:

- the `original-general-skills` section
- the parent `subsections` block
- the sibling subsection items `有用な判定` and `有用でない判定`
- the other blocks in `original-general-skills`
- all unrelated regulation data

`assets/js/renderRegulation.js` now imports:

- `originalGeneralSkillBonusSubsections` from
  `./world/regulation/originalGeneralSkillBonusSubsectionsData.js`

Composition behavior:

- applies only to section id `original-general-skills`
- applies only to block index 2 when `block.type === "subsections"`
- filters stale JSON items with the moved title
- inserts the module item at item index 2
- current JSON plus module composes back to the old item array
- stale JSON plus module still composes to one target item, not two

Unchanged:

- `renderBlock(block)` body
- `renderDataSection(sectionData)` body
- `renderTable()`
- table column definitions
- CSS classes
- DOM ids
- anchors
- active TOC logic
- `termExplanationsData.js`
- `levelCapsData.js`
- `rewardCalloutBlocksData.js`
- `generalSkillNoteSubsectionsData.js`
- calendar `levelCaps`
- reusable ops core

Cache-bust key:

- `20260617-regulation-original-general-skill-bonus-data-module`

Updated chain:

- `regulation.html` main module query
- `assets/js/main.js` `renderRegulation.js` import query
- `assets/js/renderRegulation.js` `REGULATION_DATA_PATH`

No JSON/fetch migration was introduced. The static module pattern remains the
same as the previous regulation data-module pilots.

## Local Smoke And Snapshot Checks

Result: passed.

- `node --check assets/js/renderRegulation.js`: OK
- `node --check assets/js/main.js`: OK
- `node --check assets/js/world/regulation/originalGeneralSkillBonusSubsectionsData.js`: OK
- `data/regulation.json` parse: OK
- data module import: OK
- `originalGeneralSkillBonusSubsections.length`: 1
- title: `オリジナル一般技能による「技能レベルボーナス」`
- paragraph count: 1
- module item matches old `HEAD:data/regulation.json` target exactly
- source section remains present
- parent block type remains `subsections`
- old item count: 3
- current JSON item count: 2
- current JSON target count: 0
- sibling items match old HEAD exactly
- composed current target count: 1
- composed current target index: 2
- composed current items match old HEAD exactly
- composed stale JSON target count: 1
- composed stale JSON target index: 2
- composed stale JSON items match old HEAD exactly
- `git diff --check`: OK before implementation commit
- `updates.json` / `deno.lock` / `supabase/.temp`: no diff
- `console.*` additions: none in the implementation diff
- direct Supabase write additions: none in the implementation diff

## Public Rollout Check

Result: passed after GitHub Pages reflected `975deb3`.

Static public delivery:

- public `regulation.html`: HTTP 200
- public `regulation.html` references
  `20260617-regulation-original-general-skill-bonus-data-module`
- public `main.js`: HTTP 200
- public `main.js` imports `renderRegulation.js` with the new cache-bust
- public `renderRegulation.js`: HTTP 200
- public `renderRegulation.js` imports
  `originalGeneralSkillBonusSubsectionsData.js`
- public `renderRegulation.js` contains the narrow duplicate-display guard
- public `originalGeneralSkillBonusSubsectionsData.js`: HTTP 200
- public module exports `originalGeneralSkillBonusSubsections`
- public module item count: 1
- public module title: `オリジナル一般技能による「技能レベルボーナス」`
- public module paragraph count: 1
- public `data/regulation.json`: HTTP 200
- public `data/regulation.json` parse: OK
- public JSON keeps `original-general-skills`
- public JSON has 2 remaining parent subsection items in block index 2
- public JSON target count: 0
- checked public 404 count: 0

Public DOM check:

- regulation page renders
- `#original-general-skills` exists
- TOC link to `#original-general-skills` exists
- `#original-general-skills .regulation-subsection` count: 3
- target item count: 1
- target item index: 2
- target title unchanged
- target paragraph count: 1
- target paragraph text matches the public module
- target item class: `regulation-subsection`
- target item has no DOM id
- no `undefined`
- no `[object Object]`
- empty subsection count: 0
- term explanation cards: 12
- level cap table rows: 14
- reward callout `超過報酬の例` count: 1
- general-skills note `注釈2：『制限』について` count: 1
- browser error logs: none

Cache-mix risk:

- old public HTML / JS / JSON and missing module were observed during Pages
  propagation before rollout completed
- after rollout, new public HTML / JS / JSON / module were all aligned
- new renderer plus missing module was not observed after final rollout
- stale JSON plus new renderer is covered by the title-scoped duplicate guard

## Limited / Not Tested

Limited:

- visual inspection was DOM-level and single viewport; full desktop/mobile
  scroll-through was not repeated
- active TOC was checked by anchor/link existence and absence of browser errors;
  detailed scroll-state behavior was not exhaustively tested
- regulation sections outside the target and existing module-owned targets were
  checked only for obvious DOM-level side effects

Not tested:

- regulation pages in authenticated-only flows
- regulation-unrelated pages beyond the public DOM side-effect checks listed
  above
- DB / RPC / RLS behavior
- Edge Functions
- Discord sync or webhook behavior
- auth / membership / mypage / session-post workflows

## Out Of Scope Kept Untouched

- `original-general-skills` section-wide data module
- other original-general-skills blocks or items
- `general-skills` section-wide data module
- reward table data
- level cap data
- honor / Sword Shard data
- growth rules
- fumble experience rules
- lower-bound growth rules
- magic-angel rulings
- long house rules
- `renderBlock()` rewrite
- `renderDataSection()` rewrite
- `renderTable()` changes
- column definition changes
- active TOC changes
- CSS class changes
- DOM id changes
- anchor changes
- `updates.json`
- SQL / DB / RPC / RLS / Edge / Discord / secret changes

## Next Candidate

Recommended next step:

- summarize the fifth pilot before selecting more regulation data

Candidate direction:

- avoid generic subsection registries until a separate schema gate exists
- avoid additional item moves in the same section without a new spec gate
- keep long-rule and table-column decisions behind separate gates
