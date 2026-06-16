# World Template Regulation Reward Callout Spec

Phase 3-B12 freezes the current behavior of the selected short-note candidate
before any future data-module implementation.

This is a docs-only gate. It does not change implementation, HTML, CSS,
JavaScript, JSON/data, data modules, renderers, regulation copy, `updates.json`,
or reusable ops core behavior.

Baseline:

- `6050b06 Summarize regulation level caps pilot`

## Current Data Contract

Current definition:

- file: `data/regulation.json`
- top-level area: `sections`
- section id: `reward`
- section title: `報酬・超過報酬`
- section index: 0 in the current `sections` array
- block index inside the reward section: 1
- block type: `callout`
- current title: `超過報酬の例`

Current reward section block order:

| Block index | Type | Role |
| --- | --- | --- |
| 0 | `paragraphs` | reward and excess-reward explanation body |
| 1 | `callout` | excess-reward example note |

Current callout fields:

| Field | Type | Current role |
| --- | --- | --- |
| `type` | string | block renderer selector; current value is `callout` |
| `title` | string | callout heading; current value is `超過報酬の例` |
| `paragraphs` | array of strings | callout body paragraphs |

Current body format:

- `paragraphs` is an array
- each item is a plain string
- current paragraph count: 4
- no HTML string is used
- no markdown syntax is interpreted
- no explicit newline field is used
- no current strong-label string from `STRONG_PARAGRAPHS` is used
- each string is rendered as a separate `<p>` by `appendParagraphs`

Current required-looking fields:

- `type`
- `title`
- `paragraphs`

Current optional-looking fields:

- none in this production block

Empty/undefined state:

- current block has no missing fields
- current block has no empty fields
- current `paragraphs` array has no empty string entries

Content ownership:

- the exact title and paragraph text are Velgard-specific
- the shape `{ type, title, paragraphs }` is generic and reusable for future
  world-site short notes
- the current block is content data, not reusable ops core behavior

## Renderer Contract

Renderer function:

- function: `renderBlock(block)`
- file: `assets/js/renderRegulation.js`

Renderer inputs:

- a block object from a section's `blocks` array
- this callout uses `block.type`, `block.title`, and `block.paragraphs`

Reward section call path:

1. `renderRegulation(root)` loads and composes the `regulation` object.
2. `renderRegulation(root)` builds `sections` from `regulation.sections`.
3. `renderRegulation(root)` renders selected early sections with:
   `["reward", "compensation"].forEach(...)`.
4. `renderDataSection(sections.get("reward"))` creates the `reward` section.
5. `renderDataSection(sectionData)` iterates `sectionData.blocks`.
6. `renderBlock(block)` handles the `type: "callout"` block.

Generated DOM for the current callout:

- `section.section.regulation-section#reward`
- `article.article-box`
- `h2` with the reward section title
- first reward `div.regulation-block` for reward paragraphs
- then `div.regulation-callout`
- inside the callout:
  - `h3` when `block.title` is present
  - one `<p>` per present paragraph

CSS classes involved:

- `.regulation-section`
- `.article-box`
- `.regulation-block`
- `.regulation-callout`

DOM id and anchor contract:

- callout block itself has no DOM id
- parent section id is `reward`
- TOC anchor is `#reward`
- TOC label source is `TOC_ITEMS` in `assets/js/renderRegulation.js`
- active TOC observer target remains `.regulation-section[id]`

Current CSS:

- `.regulation-callout` shares card-like base styling with
  `.regulation-term-card` and `.regulation-subsection`
- `.regulation-callout h3` and `.regulation-callout h4` have heading spacing
- `.regulation-callout` has a left border and background treatment

Empty or missing behavior:

- if `renderBlock(block)` receives `undefined`, `null`, or a non-object, it
  returns an empty fragment
- if `block.title` is missing or empty, no heading is appended
- if `block.paragraphs` is missing, not an array, or empty, no paragraphs are
  appended
- even if title and paragraphs are empty, the callout branch currently appends
  an empty `div.regulation-callout`
- current production data does not hit the empty-callout case

Shared renderer status:

- the current reward callout uses the shared `renderBlock(block)` branch for
  `type === "callout"`
- there is no reward-specific callout renderer
- the same CSS class name is also used for the optional example inside
  `renderTermExplanations(regulation)`, but that term-card example is rendered
  by a separate branch and uses `h4` for its title
- current `data/regulation.json` has only one `type: "callout"` block

Event and ops distance:

- `renderBlock(block)` attaches no event handler for callout blocks
- the callout does not read auth state
- the callout does not call RPC, DB, Supabase writes, Edge Functions, or
  Discord sync

## Comparison Checklist For A Future Move

Future reward-callout data-module implementation should compare:

- reward section remains present
- reward section id remains `reward`
- TOC anchor remains `#reward`
- reward section block order remains:
  - reward paragraphs first
  - callout second
- callout count in the reward section remains 1
- callout type remains `callout`
- callout title remains `超過報酬の例`
- paragraph count remains 4
- each paragraph text remains unchanged
- paragraphs remain separate paragraphs
- no HTML interpretation or markup change appears
- `.regulation-callout` remains the callout class
- no new DOM id is introduced for the callout
- active TOC behavior has no obvious regression
- reward paragraphs have no side effect
- compensation and later sections have no side effect
- no `undefined`, `[object Object]`, empty heading, or empty callout appears
- desktop and mobile display have no meaningful visual regression

## Recommended Future Implementation

Recommended scope:

- Move only the reward section `type: "callout"` block to a world-site data
  module.

Expected module:

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

Expected connection:

- import `rewardCalloutBlocks` in `assets/js/renderRegulation.js`
- keep `reward` section metadata and reward paragraphs in `data/regulation.json`
- remove only the selected callout block from `data/regulation.json`
- attach or inject the imported callout block at the existing
  `renderRegulation(root)` merge point
- preserve the callout's current block index after the reward paragraphs
- keep `renderDataSection(sectionData)` unchanged
- keep `renderBlock(block)` unchanged

Suggested first implementation shape:

- avoid a generic block registry
- avoid moving all callouts
- avoid moving the whole reward section
- rebuild only the loaded `reward` section's `blocks` array with the imported
  callout appended at the current position

Do not introduce:

- standalone JSON/fetch loading
- new renderer
- renderer rewrite
- text normalization
- HTML string interpretation
- formula parsing
- executable reward logic

Cache-bust and public delivery targets for the implementation gate:

- `regulation.html` main module query
- `assets/js/main.js` import query for `renderRegulation.js`
- `assets/js/renderRegulation.js` `REGULATION_DATA_PATH` query for
  `data/regulation.json`
- public availability of
  `assets/js/world/regulation/rewardCalloutBlocksData.js`

## First Implementation Out Of Scope

The first reward-callout data-module implementation must not touch:

- the entire `reward` section
- reward section paragraphs
- reward text meaning
- compensation blocks
- all callout blocks globally
- `termExplanationsData.js`
- `levelCapsData.js`
- reward amount table or level-cap table values
- Sword Shard / honor values
- growth rules
- fumble experience rule text
- lower-bound growth rule text
- magic-angel rulings
- long house rules
- `renderBlock()`
- `renderDataSection()`
- `renderTable()`
- `LEVEL_CAP_COLUMNS`
- active TOC control
- CSS class names
- DOM ids
- anchors
- `updates.json`
- auth, membership, RPC, DB/RPC/RLS, Edge Functions, Discord sync, or secrets

## Reusable Ops Core Boundary

The reward callout block belongs to the world-site template side.

Boundary rules:

- do not move the reward callout into reusable ops core
- do not connect it to `calendar`, `session-post`, `session-detail`, or
  `mypage`
- do not connect it to auth or membership state
- do not connect it to Discord sync
- do not connect it to DB, RPC, or RLS
- regulation data work must not break calendar, session-post, mypage,
  session-detail, membership, or Discord-related behavior

## Limited And Not Tested

This B12 gate is docs-only.

Limited or not tested:

- rendered DOM comparison: `not_tested`
- desktop/mobile visual review: `not_tested`
- active TOC scroll-through behavior: `not_tested`
- non-regulation pages: `not_tested`
- authenticated role-specific behavior: `not_tested`
- data-changing workflows, DB/RPC/RLS, Edge Functions, and Discord sync:
  `not_tested`

These are acceptable here because the gate freezes current behavior in docs and
does not change production assets.
