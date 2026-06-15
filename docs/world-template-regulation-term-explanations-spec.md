# World Template Regulation Term Explanations Spec

Phase 3-B4 freezes the current `termExplanations` behavior before any future
regulation data/json pilot. This is a docs-only specification. It does not
change HTML, CSS, JavaScript, JSON data, renderer behavior, regulation copy, SQL,
DB/RPC/RLS, Discord sync, or reusable ops core code.

## Source

Current data source:

- `data/regulation.json`
- key: `termExplanations`

Current renderer:

- `assets/js/renderRegulation.js`
- function: `renderTermExplanations(regulation)`

Current page shell:

- `regulation.html`
- target root: `main#app`

Current styling:

- `assets/css/style.css`
- `.regulation-term-grid`
- `.regulation-term-card`
- `.regulation-callout`

## Current Data Shape

`termExplanations` is currently an array of 12 card records.

Current fields:

- `term`
- `paragraphs`
- `exampleTitle`
- `exampleParagraphs`

Observed field counts:

- `term`: 12 / 12 records
- `paragraphs`: 12 / 12 records
- `exampleTitle`: 1 / 12 records
- `exampleParagraphs`: 1 / 12 records

Required-looking fields:

- `term`
- `paragraphs`

Optional-looking fields:

- `exampleTitle`
- `exampleParagraphs`

The current data has:

- 12 cards
- 0 empty `term` values
- 0 missing or empty `paragraphs` arrays
- 1 card with an example/callout
- no HTML string rendering contract
- no nested table/list data inside `termExplanations`
- no ids per card
- no tags per card
- no audience field

## Current Display Order

Current card order is the array order in `data/regulation.json`:

1. `レベルキャップ`
2. `固定経験点`
3. `下限成長`
4. `下限報酬`
5. `下限名誉点`
6. `上限成長`
7. `上限報酬`
8. `冒険者ランク上限`
9. `報酬金額`
10. `超過報酬`
11. `剣の欠片目安`
12. `ピンゾロ経験点の獲得・成長の方式について`

Future pilots must preserve this order unless a separate content/design gate
explicitly changes it.

## Paragraph And Callout Behavior

The renderer treats `paragraphs` as an array.

Current behavior:

- each present paragraph becomes one `<p>`
- strings are assigned via `textContent`
- HTML markup inside strings is not interpreted
- line breaks are represented by separate array entries, not raw HTML
- empty, null, undefined, or whitespace-only paragraph values are filtered out
- `STRONG_PARAGRAPHS` can make exact paragraph strings bold, but the current
  term cards do not rely on HTML strings for emphasis

Callout behavior:

- a callout appears when `exampleTitle` is present, or when
  `exampleParagraphs` is a non-empty array
- `exampleTitle`, when present, renders as an `<h4>`
- `exampleParagraphs` renders through the same paragraph helper as normal body
  text
- the current data has one callout record, attached to the `上限報酬` card

## Renderer Contract

`renderTermExplanations(regulation)` currently receives the full regulation data
object and reads `regulation.termExplanations`.

DOM shape:

```text
section.section.regulation-section#term-explanations
  article.article-box
    h2
    div.regulation-term-grid
      article.regulation-term-card
        h3
        p...
        div.regulation-callout
          h4
          p...
```

Generated classes:

- `section regulation-section`
- `article-box`
- `regulation-term-grid`
- `regulation-term-card`
- `regulation-callout`

Generated id:

- `term-explanations` on the outer section

The section heading is renderer-owned today:

- `renderTermExplanations()` calls `createSection("term-explanations", "...")`

The term section is inserted into `article.regulation-main` after schedule and
level caps, and before reward/compensation sections.

## TOC / Anchor / Active State Relationship

The term section participates in the regulation TOC through the static
renderer-owned `TOC_ITEMS` entry for `term-explanations`.

Current behavior:

- `renderToc()` creates an anchor link to `#term-explanations`
- `watchRegulationToc(layout)` observes `.regulation-section[id]`
- active state is applied to the matching TOC link

Future term-card data pilots must not change:

- section id `term-explanations`
- anchor target
- TOC link behavior
- active side-menu behavior

## Empty Or Missing Data Behavior

If `regulation.termExplanations` is not an array:

- the renderer uses an empty array
- it still creates the `term-explanations` section
- it still appends an empty `.regulation-term-grid`

If an item has a missing `term`:

- the renderer still creates an empty `<h3>`
- this is not present in current production data
- future implementations should avoid producing empty headings

If an item has missing or non-array `paragraphs`:

- no body paragraphs render
- this is not present in current production data

If `exampleTitle` is missing and `exampleParagraphs` is empty or missing:

- no callout renders

## Dependencies And Non-Dependencies

Current dependencies:

- `createSection`
- `create`
- `appendParagraphs`
- `isPresent`
- `STRONG_PARAGRAPHS` through `appendParagraphs`
- CSS classes listed above
- TOC item and active observer through the shared section id

Current non-dependencies:

- no event handlers in term cards
- no auth state
- no approved/member/owner/admin checks
- no Supabase RPC calls
- no DB writes
- no Discord sync
- no reusable ops core import
- no `management_key`
- no raw id, user id, email, token, or JWT surface

## Difference Comparison Checklist

Any future pilot implementation must compare:

- card count remains 12
- card order remains unchanged
- each card heading remains unchanged
- paragraph count per card remains unchanged
- paragraph text remains unchanged
- the single callout remains on the same card
- callout title remains unchanged
- callout paragraph count/text remains unchanged
- `.regulation-term-grid` remains present
- `.regulation-term-card` remains present per card
- `.regulation-callout` remains present only where expected
- section id remains `term-explanations`
- TOC link and active state remain functional
- no new `undefined`, `[object Object]`, empty heading, or empty card appears
- desktop term-card layout remains readable
- mobile term-card layout remains readable
- reward, level-cap, adopted rulebooks, common-rules, and magic-angel sections
  are not changed

## Future Implementation Options

### Option A: Data Module

Example future path:

- `assets/js/world/regulation/termExplanationsData.js`

Characteristics:

- avoids introducing a new `fetch`
- keeps data import failure behavior simpler
- keeps the renderer mostly synchronous after the main regulation JSON is loaded
- is GitHub Pages friendly
- is a good first pilot if the goal is to test separation without changing
  fetch/cache behavior

Tradeoff:

- this is not pure JSON
- future non-developer editing is less direct than JSON

### Option B: JSON File

Example future path:

- `assets/data/regulation/term-explanations.json`

Characteristics:

- clearest expression of data/json separation
- easier to document as a world data asset
- aligns with future multi-world data replacement

Tradeoff:

- adds another fetch or data-loading path
- needs explicit fallback behavior
- needs cache-bust design
- adds another public delivery check
- is slightly heavier for the first pilot

## Recommended First Implementation Direction

Recommendation:

- use Option A, data module, for the first implementation gate

Reason:

- the current renderer already loads `data/regulation.json` asynchronously
- adding another JSON fetch would increase failure and cache-bust surface
- a data module lets the team test separation while preserving the current
  page behavior and rollback simplicity
- once the shape is stable, a later gate can decide whether to convert the
  module into a standalone JSON asset

If the implementation gate chooses JSON anyway, it should explicitly define:

- fallback when the JSON fetch fails
- cache-bust string
- public HTTP 200 check
- normalized text comparison against current output

## Ops Core Boundary

`termExplanations` belongs to the world-site template side.

It must not move into:

- `assets/js/core/config`
- `assets/js/core/calendar`
- `assets/js/core/session`
- reusable ops auth/membership logic
- Discord sync logic
- DB/RPC wrappers

Allowed relationship:

- ops pages can link to regulation for user guidance
- regulation can describe rules that users need before using ops pages

Not allowed:

- term-card data must not encode auth, membership, RPC, DB, Discord action,
  input name, CSS class, DOM id, storage key, or internal-key contracts

## Next Candidates

1. Create a dedicated implementation gate for the data-module pilot.
2. Before implementation, define a normalized text snapshot for the current
   `term-explanations` section.
3. Keep JSON-file migration, level-cap table migration, and magic-angel ruling
   migration behind later separate gates.
