# Regulation General Skill Note Data Module Result

Date: 2026-06-17

Phase: 3-B16 regulation general-skills note item data module spec,
implementation, smoke check, and public rollout check.

Implementation commit: `f48cfab Extract regulation general skill note data`

## Scope

Moved target:

- `data/regulation.json`
- `sections[].id === "general-skills"`
- section title: `一般技能`
- block index: 0
- block type: `subsections`
- item index: 7
- item title: `注釈2：『制限』について`

New data module:

- `assets/js/world/regulation/generalSkillNoteSubsectionsData.js`
- export: `generalSkillNoteSubsections`

Removed from `data/regulation.json`:

- only the selected `general-skills` subsection item with title
  `注釈2：『制限』について`

Kept in `data/regulation.json`:

- the `general-skills` section
- the parent `subsections` block
- all other `general-skills` subsection items
- all other regulation sections and data

## Current Behavior Snapshot

Data shape before the move:

- object with fields `title` and `paragraphs`
- no `type` field
- no `items` field
- no `sections` field
- `paragraphs` is a plain-string array with 1 entry
- no HTML string conversion
- no empty or undefined values

Renderer path:

- `renderRegulation(root)` loads `data/regulation.json`
- section data is looked up from `sections`
- `renderDataSection(sectionData)` creates the `general-skills` section
- `renderBlock(block)` handles `block.type === "subsections"`
- each item renders as `article.regulation-subsection`
- item title renders as `h3`
- item paragraphs render through `appendParagraphs`

DOM and CSS behavior:

- parent section id remains `general-skills`
- TOC anchor remains `#general-skills`
- active TOC continues to use `.regulation-section[id]`
- the note item itself has no DOM id
- subsection class remains `.regulation-subsection`
- subsection group class remains `.regulation-subsections`

The item is Velgard-specific text, but the `title` plus `paragraphs` subsection
shape is reusable for future world-site templates.

## Implementation

`assets/js/renderRegulation.js` now imports:

- `generalSkillNoteSubsections` from
  `./world/regulation/generalSkillNoteSubsectionsData.js`

The renderer composes only the loaded `general-skills` subsection block before
existing rendering:

- stale JSON items with the same moved title are filtered out
- the imported item is inserted at item index 7
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
- calendar `levelCaps`
- reusable ops core

Cache-bust key:

- `20260617-regulation-general-skill-note-data-module`

Updated chain:

- `regulation.html` main module query
- `assets/js/main.js` `renderRegulation.js` import query
- `assets/js/renderRegulation.js` `REGULATION_DATA_PATH`

No JSON/fetch migration was introduced. The data module follows the previous
static module pattern so GitHub Pages can serve it as a normal JS asset.

## Local Smoke And Snapshot Checks

Result: passed.

- `node --check assets/js/renderRegulation.js`: OK
- `node --check assets/js/main.js`: OK
- `node --check assets/js/world/regulation/generalSkillNoteSubsectionsData.js`: OK
- `data/regulation.json` parse: OK
- data module import: OK
- `generalSkillNoteSubsections.length`: 1
- title: `注釈2：『制限』について`
- paragraph count: 1
- module item matches old `HEAD:data/regulation.json` target exactly
- current JSON target count: 0
- current JSON keeps the `general-skills` section
- current JSON keeps the parent `subsections` block
- other `general-skills` subsection items match old HEAD exactly
- composed current data target count: 1
- composed current target index: 7
- composed current items match old HEAD exactly
- composed stale JSON target count: 1
- composed stale JSON target index: 7
- composed stale JSON items match old HEAD exactly
- `git diff --check`: OK before implementation commit
- `updates.json` / `deno.lock` / `supabase/.temp`: no diff
- `console.*` additions: none in the implementation diff
- direct Supabase write additions: none in the implementation diff

## Public Rollout Check

Result: passed after GitHub Pages reflected `f48cfab`.

Static public delivery:

- public `regulation.html`: HTTP 200
- public `regulation.html` references
  `20260617-regulation-general-skill-note-data-module`
- public `main.js`: HTTP 200
- public `main.js` imports `renderRegulation.js` with the new cache-bust
- public `renderRegulation.js`: HTTP 200
- public `renderRegulation.js` imports
  `generalSkillNoteSubsectionsData.js`
- public `renderRegulation.js` contains the narrow duplicate-display guard
- public `generalSkillNoteSubsectionsData.js`: HTTP 200
- public module exports `generalSkillNoteSubsections`
- public module item count: 1
- public module title: `注釈2：『制限』について`
- public module paragraph count: 1
- public `data/regulation.json`: HTTP 200
- public `data/regulation.json` parse: OK
- public JSON keeps `general-skills`
- public JSON has 7 remaining parent JSON items
- public JSON target count: 0
- checked public 404 count: 0

Public DOM check:

- regulation page renders
- `#general-skills` exists
- TOC link to `#general-skills` exists
- `#general-skills .regulation-subsection` count: 8
- target item count: 1
- target item index: 7
- target title unchanged
- target paragraph count: 1
- target paragraph text matches the public module
- target item class: `regulation-subsection`
- target item has no DOM id
- no `undefined`
- no `[object Object]`
- empty subsection count: 0
- reward callout `超過報酬の例` count: 1
- level cap table rows: 14
- term explanation cards using `.regulation-term-card`: 12
- browser error logs: none

Cache-mix risk:

- new public JSON plus old renderer was not observed after rollout
- old public HTML plus new renderer was not observed after rollout
- new renderer plus missing module was initially observed during Pages
  propagation, then resolved to HTTP 200 before completion
- stale JSON plus new renderer is covered by the title-scoped duplicate guard

## Limited / Not Tested

Limited:

- visual inspection was DOM-level and single viewport; full desktop/mobile
  scroll-through was not repeated
- active TOC was checked by anchor/link existence and absence of browser errors;
  detailed scroll-state behavior was not exhaustively tested
- regulation sections outside the target and the three prior module targets were
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

- `general-skills` section-wide data module
- all other `general-skills` notes and items
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

- summarize this fourth pilot before selecting another data target

Candidate direction:

- do not broaden to a generic nested-item registry yet
- if continuing, pick one more tiny item/block only after a spec gate
- keep long-rule and table-column decisions behind separate gates
