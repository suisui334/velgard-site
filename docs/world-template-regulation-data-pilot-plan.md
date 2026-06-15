# World Template Regulation Data Pilot Plan

Phase 3-B3 selects the first candidate for a future regulation data/json pilot.
This is a docs-only planning note. It does not change HTML, CSS, JavaScript,
JSON data, regulation copy, renderer behavior, SQL, DB/RPC/RLS, Discord sync,
or reusable ops core code.

## Goal

Phase 3-B1 documented the reusable regulation page structure. Phase 3-B2
documented candidate data schema objects. Phase 3-B3 chooses the safest first
pilot before any implementation gate.

The pilot should be small, reversible, easy to compare with the current page,
and independent from auth, DB, Discord, active menu behavior, DOM ids, CSS
classes, and ops-core contracts.

## Candidate Evaluation

| Candidate | Classification | Reason |
| --- | --- | --- |
| Term explanation cards | A. Best first pilot | Existing `termExplanations` are already array-shaped data, render through one isolated renderer, use repeated card markup, have no per-card event handlers, and are easy to compare by card count, order, heading, and paragraphs. |
| Short note cards | B. Good after one pilot | Callout/note structures are simple, but they are scattered inside section blocks. A shared card schema should be proven with term cards first. |
| Fumble experience card | B. Good after card schema is stable | It is part of term explanations and can ride on the term-card pilot, but treating it alone would make a world-specific rule look like a schema driver. |
| Lower-bound growth card | B. Good after card schema is stable | It is also term-card-like, but the content is tied to Velgard's progression rules. It should be handled through the general card pattern. |
| Level-cap table | B. Good second or later pilot | Rows are data-like, but current column definitions live in `renderRegulation.js`. The table is wide and dense, so visible-output comparison is stricter. |
| Reward amount table | B. Needs table-shape decision | Values are currently part of the level-cap table rather than a separate table. Splitting them risks changing semantics or layout. |
| Sword Shard / honor guide table | B. Needs table-shape decision | Like reward amount, it is currently embedded in the level-cap table and should wait until table column modeling is reviewed. |
| Individual ruling cards | B/C. Depends on length | Short individual rulings can become data cards later, but many current rulings mix paragraphs, lists, and nested sections. |
| Magic-angel ruling card | C. Keep fixed for now | This is long, highly Velgard-specific, includes internal headings and equipment data, and is most likely to suffer readability regressions. |
| TOC / active menu behavior | D. Do not data-pilot | It is renderer behavior and page navigation infrastructure, not content data. |
| DOM ids, CSS classes, JS hooks | D. Do not data-pilot | These are implementation contracts and should not become reusable content data. |

## Selected First Pilot

Selected candidate:

- Term explanation cards

Current source:

- `data/regulation.json`
- `termExplanations`

Current renderer:

- `assets/js/renderRegulation.js`
- `renderTermExplanations(regulation)`

Current CSS:

- `.regulation-term-grid`
- `.regulation-term-card`
- `.regulation-callout`

Why this is the safest first pilot:

- It is already a list of repeated card records.
- It does not need active TOC changes.
- It does not need section anchor changes.
- It does not need DOM id or CSS class changes.
- It has no auth, membership, RPC, DB, Discord, or ops-core dependency.
- It supports simple visible-output checks:
  - card count
  - card order
  - heading text
  - paragraph count
  - optional example callout title/body
- It is useful for future worlds because most world sites need glossary or rule
  explanation cards.
- It can be rolled back or guarded with a fallback to the current
  `termExplanations` shape.

## Existing Page Area

The pilot maps to the current term explanations section:

- page section id: `term-explanations`
- current data key: `termExplanations`
- current render function: `renderTermExplanations`
- current card fields:
  - `term`
  - `paragraphs`
  - `exampleTitle`
  - `exampleParagraphs`

The pilot should not alter:

- `schedule`
- `levelCaps`
- reward values
- honor / Sword Shard values
- adopted rulebook list
- long section blocks
- magic-angel ruling
- TOC item ids or labels
- active current-section behavior

## Proposed Data Shape

This is illustrative only. Do not create or apply this data file yet.

```js
{
  id: "term-explanations",
  title: "Term Explanations",
  sectionType: "definitionCards",
  cards: [
    {
      id: "reward-amount",
      title: "Reward Amount",
      cardType: "term",
      body: [
        "The visible text remains the current production text.",
        "The current GM note remains unchanged."
      ],
      example: null,
      tags: ["reward"]
    },
    {
      id: "excess-reward",
      title: "Excess Reward",
      cardType: "term",
      body: ["Existing description text"],
      example: {
        title: "Example",
        body: ["Existing example text"]
      },
      tags: ["reward", "example"]
    }
  ]
}
```

Mapping from current shape:

- `term` -> `title`
- `paragraphs` -> `body`
- `exampleTitle` -> `example.title`
- `exampleParagraphs` -> `example.body`

The initial implementation gate may also choose a lighter approach:

- keep `termExplanations` as the production shape
- add a renderer that can accept both current and future card fields
- use current fields as the fallback baseline

## Expected Renderer Responsibility

For the first implementation gate, the renderer should only:

- read the selected card collection
- preserve the current section heading
- preserve the current card order
- render the same card title and body text
- render optional example callouts when present
- reuse current CSS classes
- keep the current table of contents and anchor behavior unchanged

The renderer should not:

- create new CSS classes
- change DOM ids
- change anchors
- change active TOC behavior
- rewrite section ordering
- interpret rule text as executable logic
- touch auth, membership, RPC, DB, Discord sync, or ops-core code

## Existing CSS Use

The pilot should reuse existing styles:

- `.regulation-term-grid`
- `.regulation-term-card`
- `.regulation-callout`

No CSS split or style rewrite should be part of the first pilot.

## Cache-Bust Targets For A Future Implementation

If a later implementation changes production renderer/data loading, review only
the affected chain:

- `assets/js/renderRegulation.js`
- `assets/js/main.js` if the imported renderer query changes
- `regulation.html` if the main module query changes
- `data/regulation.json` query in `renderRegulation.js` if the data path or
  cache key changes

Do not update `updates.json` for this pilot unless a separate content-release
gate explicitly requires it.

## QA For A Future Implementation

Minimum static/visual checks:

- term explanation section appears
- card count is unchanged
- card order is unchanged
- each title is unchanged
- each paragraph is unchanged
- example callout title/body are unchanged where present
- no `undefined`, `[object Object]`, or empty card title appears
- desktop layout still uses the current term-card layout
- mobile stacking is not broken
- TOC link to `term-explanations` still works
- active side-menu behavior remains unchanged
- reward/level-cap/magic-angel sections are untouched

Optional comparison:

- capture the rendered `term-explanations` HTML before/after and compare
  normalized text content
- compare screenshots for desktop and mobile regulation page sections

## Rollback Plan

For a later implementation gate, rollback should be simple:

- revert the pilot commit, or
- keep the current `termExplanations` reader as fallback and disable the new
  shape reader.

Because this candidate does not touch ops-core behavior, rollback should not
affect calendar, mypage, session-post, session-detail, membership, or Discord
sync.

## Out Of Scope For The First Pilot

The first implementation gate must not include:

- whole regulation page data migration
- long house-rule migration
- magic-angel ruling migration
- level-cap column migration
- reward value changes
- honor / Sword Shard value changes
- TOC / active-control rewrite
- CSS class changes
- DOM id changes
- anchor changes
- existing text meaning changes
- `updates.json` change
- auth, membership, RPC, DB, Discord, or ops-core changes

## Next Candidates After The Pilot

If term explanation cards pass the first implementation gate, the next safest
candidates are:

1. Short callout/note cards that already use `type: "callout"`.
2. Adopted rulebook list, if list rendering is isolated and text comparison is
   easy.
3. Schedule table, if table column configuration is reviewed first.
4. Level-cap table columns, only after a renderer-constant audit.

Keep reward values, honor values, long special rulings, and magic-angel data for
later gates.
