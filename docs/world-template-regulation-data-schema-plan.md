# World Template Regulation Data Schema Plan

Phase 3-B2 documents a future data/json structure for regulation pages. This is
a planning document only. It does not create JSON files, change production
data, edit the renderer, change HTML/CSS/JS, or touch ops-core behavior.

## Background

Phase 3-B1 defined the regulation page as a reusable world-site template
candidate. This document narrows that into a data-schema planning layer: what
could become structured world data, what should remain renderer/layout behavior,
and what must stay Velgard-specific.

The current Velgard regulation page is already mostly data-driven through
`data/regulation.json`, while some structure still lives in
`assets/js/renderRegulation.js`.

Current file responsibilities:

- `regulation.html`: static page shell, page identity, and script/style loading.
- `assets/js/renderRegulation.js`: data loading, DOM rendering, table rendering,
  TOC rendering, active TOC behavior, and block rendering.
- `assets/css/style.css`: regulation page layout, cards, tables, TOC, desktop
  wide layout, and mobile stacking.
- `data/regulation.json`: page copy, schedule, level caps, term cards, adopted
  rulebook list, and section blocks.

## Current Structure Inventory

Current regulation page elements:

- page title
- intro lead
- table of contents / side menu
- term explanation cards
- schedule table
- level-cap table
- reward and excess reward section
- compensation section
- adopted rulebook list
- common rules
- growth-related term cards and table values
- fumble experience rule
- lower-bound growth rule
- long house-rule sections
- individual ruling sections
- GM-facing notes
- player-facing notes
- cautions and callouts
- world-specific race/rule rulings
- future update-history or latest-change links, if added later

Current renderer-owned structure:

- TOC item ids and labels
- level-cap column definitions
- strong paragraph label list
- table wrapper behavior
- active TOC behavior
- section ordering around `schedule`, `level-caps`, `term-explanations`,
  selected data sections, adopted rulebooks, and remaining sections
- CSS class names and DOM shape

## Data/JSON Suitability

### A. Very Good Data/JSON Candidates

These are already close to structured data and should be the first future
schema targets:

- page title, subtitle, page label, and lead
- schedule rows
- level-cap rows
- reward table values
- honor / Sword Shard guide values
- term explanation cards
- short note cards
- callout cards
- individual ruling cards with stable titles and body blocks
- adopted rulebook list
- TOC labels and order, after a renderer boundary review

Reason: these are primarily content. They do not need to know DOM ids, CSS
classes, event handlers, auth state, RPC names, or ops-core state.

### B. Data/JSON Candidates That Need Body-Structure Design

These can become data, but should not be rushed without a clear block schema:

- long house rules
- growth rules
- fumble experience rules
- lower-bound growth rules
- special multi-paragraph rulings
- magic-angel style rulings with subsections and equipment data
- nested subsection groups
- long notes that need heading hierarchy
- rule text that mixes paragraphs, lists, and tables

Reason: raw paragraphs are easy to store, but future worlds need readable
structure. The schema should distinguish headings, paragraphs, lists, callouts,
tables, and detail blocks rather than relying on string matching.

### C. Better Left In HTML/Renderer/CSS For Now

These are behavior or layout concerns and may stay in renderer/CSS until a
dedicated implementation gate:

- desktop wide layout
- mobile stacked layout
- active side-menu behavior
- IntersectionObserver setup
- anchor scrolling behavior
- DOM structure for the side menu
- CSS class assignment
- table wrapper behavior
- section render order logic
- fallback behavior when regulation status is not public

Reason: these are rendering mechanics. They can be made configurable later, but
turning them into data too early would make the schema brittle.

### D. Should Not Become Data Defaults

Do not turn these into reusable schema defaults:

- DOM ids as a public data contract
- CSS class names as content data
- JavaScript hook names
- active-control internal keys
- exact Velgard values as next-world defaults
- auth/membership/RPC/DB/Discord behavior
- storage keys, URL parameters, or ops payload keys
- raw ids, tokens, email addresses, user ids, session ids, or management keys

## Candidate Schema Objects

The following names are planning labels, not implementation commitments.

### `regulationPage`

Role: page-level identity and introduction.

Possible fields:

- `id`
- `pageLabel`
- `title`
- `subtitle`
- `summary`
- `lead`
- `updatedAt`
- `versionLabel`
- `introBlocks`

Velgard-specific values: title copy, lead copy, dates, and summary text.

Reusable: field shape and role.

Keep in HTML/renderer: document metadata, script loading, style loading, and
site shell wiring.

Notes: page metadata can be data-driven later, but production HTML meta tags
need a separate SEO/OGP review before moving.

### `regulationNav`

Role: TOC / side-menu labels and order.

Possible fields:

- `id`
- `label`
- `anchor`
- `targetSectionId`
- `order`
- `group`
- `isPrimary`

Velgard-specific values: labels and section choices.

Reusable: side-menu structure and active-section pattern.

Keep in HTML/renderer: active tracking behavior and DOM/CSS implementation.

Notes: anchors should be stable within a world, but should not be treated as
ops-core contracts.

### `regulationSections`

Role: top-level content sections rendered as cards or article blocks.

Possible fields:

- `id`
- `title`
- `tocLabel`
- `sectionType`
- `summary`
- `blocks`
- `tags`
- `audience`

Velgard-specific values: titles, body, rule categories, and exact text.

Reusable: section/block relationship and category concept.

Keep in HTML/renderer: card DOM shape, active menu behavior, and CSS classes.

Notes: current `sections` in `data/regulation.json` are already close to this.

### `regulationCards`

Role: reusable card units for terms, cautions, notes, and short rulings.

Possible fields:

- `id`
- `title`
- `summary`
- `body`
- `paragraphs`
- `notes`
- `tags`
- `audience`
- `relatedSectionIds`

Velgard-specific values: card titles and bodies.

Reusable: card shape and relationships.

Keep in HTML/renderer: visual decoration, card grid/stack behavior, and card
CSS classes.

Notes: this may be a generalized layer over current `termExplanations` and
short callouts.

### `regulationTables`

Role: shared structure for level caps, rewards, honor, growth, schedules, and
other tabular rules.

Possible fields:

- `id`
- `title`
- `description`
- `columns`
- `rows`
- `notes`
- `footnotes`
- `caption`

Velgard-specific values: rows, labels, and numeric values.

Reusable: `columns`/`rows` shape, table notes, and footnotes.

Keep in HTML/renderer: table DOM, scroll wrapper, and responsive behavior.

Notes: current level-cap columns are still renderer-owned; moving them to data
should be a separate low-risk gate.

### `levelCaps`

Role: level-by-level cap and progression data.

Possible fields:

- `level`
- `label`
- `fixedExperience`
- `minGrowth`
- `minReward`
- `minHonor`
- `maxGrowth`
- `maxReward`
- `growthPerSession`
- `rankLimit`
- `rewardAmount`
- `honorGuide`
- `notes`

Velgard-specific values: all current numeric values and rank labels.

Reusable: level-row concept and table shape.

Keep in HTML/renderer: column visibility, table layout, and responsive styling.

Notes: a future world might not use the same columns. Columns should be data or
config before trying to reuse this table across worlds.

### `rewardRules`

Role: reward, excess reward, compensation, and GM reward notes.

Possible fields:

- `id`
- `title`
- `rewardTableRef`
- `paragraphs`
- `examples`
- `gmNotes`
- `playerNotes`
- `blocks`

Velgard-specific values: formulas, values, examples, and operation text.

Reusable: reward rule grouping and example/callout structure.

Keep in HTML/renderer: example card layout and table rendering.

Notes: formulas should remain text until a separate rules-engine decision is
made. Do not encode them as executable logic in the template.

### `growthRules`

Role: growth, fumble experience, lower-bound growth, and related progression
rules.

Possible fields:

- `id`
- `title`
- `ruleType`
- `paragraphs`
- `tableRefs`
- `gmNotes`
- `playerNotes`
- `restrictions`

Velgard-specific values: current fumble experience and lower-bound growth
operation.

Reusable: grouping by rule type and note/audience structure.

Keep in HTML/renderer: heading hierarchy and section card rendering.

Notes: keep rules as content. Do not connect these to session-post validation
or character-sheet automation without a separate gate.

### `houseRules`

Role: general house rules that can contain paragraphs, lists, callouts, and
tables.

Possible fields:

- `id`
- `title`
- `category`
- `blocks`
- `audience`
- `tags`
- `relatedTerms`

Velgard-specific values: all body text and categories tied to the current
world.

Reusable: block-based long-rule structure.

Keep in HTML/renderer: block DOM, list styling, and heading presentation.

Notes: long house rules are safe to store as data once block structure is
stable.

### `specialRulings`

Role: complex individual rulings such as magic-angel style multi-section rules.

Possible fields:

- `id`
- `title`
- `category`
- `summary`
- `blocks`
- `subsections`
- `tables`
- `equipmentData`
- `notes`
- `sourceRefs`

Velgard-specific values: the concrete ruling, equipment data, source names,
and exception text.

Reusable: ability to host a long special ruling with internal headings and
tables.

Keep in HTML/renderer: strong-heading rendering and long-section readability.

Notes: this should be migrated last. It has the highest risk of unreadable
output if paragraph/table structure is not designed carefully.

### `gmNotes`

Role: notes aimed at GMs.

Possible fields:

- `id`
- `title`
- `text`
- `blocks`
- `relatedSectionId`
- `visibility`
- `priority`

Velgard-specific values: note content and operational conventions.

Reusable: audience-targeted note structure.

Keep in HTML/renderer: visual note style and positioning.

Notes: `visibility` here means content organization only. It must not become an
auth or membership control.

### `playerNotes`

Role: notes aimed at players.

Possible fields:

- `id`
- `title`
- `text`
- `blocks`
- `relatedSectionId`
- `priority`

Velgard-specific values: note content and player instructions.

Reusable: audience-targeted note structure.

Keep in HTML/renderer: note style.

Notes: player notes can link from ops pages, but they should not carry ops
permissions.

## Pseudo Structure Example

This is illustrative only and should not be added as a production file yet.

```json
{
  "regulationPage": {
    "id": "velgard-regulation",
    "pageLabel": "REGULATION",
    "title": "Regulation",
    "summary": "World-specific campaign rules",
    "introBlocks": []
  },
  "regulationNav": [
    {
      "id": "level-caps",
      "label": "Level Caps",
      "anchor": "level-caps",
      "order": 20
    }
  ],
  "regulationSections": [
    {
      "id": "sample-rule",
      "title": "Sample Rule",
      "sectionType": "houseRule",
      "blocks": [
        {
          "type": "paragraphs",
          "paragraphs": ["Rule text"]
        },
        {
          "type": "table",
          "columns": [
            { "key": "level", "label": "Level" },
            { "key": "value", "label": "Value" }
          ],
          "rows": [
            { "level": "1", "value": "Example" }
          ]
        }
      ]
    }
  ]
}
```

## Generic Structure Versus Velgard Content

### Generic Structure

- tables
- cards
- notes
- long-form rulings
- TOC / side menu
- anchors
- section categories
- PC/mobile layout policy
- block types for paragraphs, lists, details, callouts, subsections, and tables

### Velgard-Specific Content

- magic-angel rulings
- reward amounts
- Sword Shard / honor-point values
- fumble experience operation
- lower-bound growth operation
- race-specific and house-rule text
- current GM/PL notes
- current adopted rulebook list
- current dates and campaign progression values

## Implementation Steps For A Future Gate

### Step 1: Freeze The Schema In Docs

Do not touch the current HTML, CSS, JS, or data. Decide field names, block
types, table shapes, and TOC relationships in docs first.

Completion: schema proposal is reviewable without any production change.

### Step 2: Choose A Small Table Candidate

Pick one low-risk table or card group, such as a schedule table or one short
term-card set. Avoid the magic-angel long ruling and other complex sections.

Completion: one exact pilot target and fallback plan are defined.

### Step 3: Build A Small Renderer Comparison

Create a separate implementation gate to render the selected data and compare
it with the current output. Keep current public behavior as the baseline.

Completion: output equivalence can be checked before replacing production
rendering.

### Step 4: Move Low-Risk Cards

After table rendering is stable, move short cards or callouts into the new
shape. Keep fallbacks and public rollout checks.

Completion: cards render the same visible content from the new shape.

### Step 5: Move Long And Special Rulings Last

Only after block, heading, table, and callout handling is stable should long
house rules and special rulings move.

Completion: long sections remain readable on desktop and mobile, with no loss
of headings, lists, notes, or tables.

## Reusable Ops Core Boundary

Regulation data/json belongs to the world-site template side.

Allowed connection:

- `calendar`, `session-post`, `session-detail`, and `mypage` may link to
  regulation pages.
- ops pages may reference regulation as user guidance.

Not allowed in regulation schema:

- auth state
- membership status
- RPC names or arguments
- DB table/column contracts
- Discord sync actions or payload keys
- storage keys
- input names
- DOM ids
- CSS class names as content data
- internal keys such as management keys
- raw ids, user ids, email addresses, tokens, or JWTs

Regulation structure changes must not break reusable ops core. Future
regulation schema work should remain behind world-site implementation gates and
public display QA.

## Next Candidates

1. Draft a renderer-constant audit for `renderRegulation.js`:
   - TOC item labels and order
   - level-cap column definitions
   - strong paragraph labels
2. Choose one low-risk data pilot:
   - schedule table
   - term explanation cards
   - adopted rulebook list
3. Define visible-output comparison criteria before any implementation.
4. Keep magic-angel and other long special rulings as final migration
   candidates.

## Phase 3-B3 First Pilot Selection

Phase 3-B3 selects the first candidate for a future data/json implementation
gate:

- `docs/world-template-regulation-data-pilot-plan.md`

Selected pilot:

- term explanation cards

Reason:

- the current `termExplanations` data is already an array of repeated card
  records
- the renderer is isolated in `renderTermExplanations(regulation)`
- output can be compared by card count, order, headings, paragraphs, and
  optional example callouts
- it avoids long special rulings, level-cap column migration, reward value
  changes, TOC/active behavior, CSS class changes, DOM id changes, and ops-core
  behavior

The pilot plan keeps magic-angel rulings, reward/honor values, level-cap column
definitions, TOC behavior, and all auth/RPC/DB/Discord concerns out of the
first data/json implementation gate.

## Phase 3-B4 Term Explanations Spec

Phase 3-B4 documents the current behavior of the selected pilot target:

- `docs/world-template-regulation-term-explanations-spec.md`

The spec records the current data fields, card count, optional callout behavior,
DOM/class structure, empty-data behavior, comparison checklist, and future
implementation options. It recommends a world-site data module as the first
implementation direction because it avoids adding another JSON fetch during the
initial pilot.

## Phase 3-B5 Term Explanations Data Module

Phase 3-B5 creates the first production data-module split:

- `assets/js/world/regulation/termExplanationsData.js`
- `docs/world-template-regulation-term-explanations-data-module-result.md`

This confirms that small regulation card data can move to a world-site module
without changing the renderer shape, CSS classes, section anchor, active TOC
logic, or reusable ops core. It is still not a general JSON schema migration:
standalone JSON files, fetch fallback design, table schema work, and long-rule
migration remain later gates.

## Phase 3-B6 Term Explanations Public Rollout

Phase 3-B6 confirms the first production data-module split on public delivery:

- `docs/world-template-regulation-term-explanations-data-module-public-check.md`

Confirmed public facts:

- the B5 cache-bust chain is live on `regulation.html` and `main.js`
- `renderRegulation.js` imports the term data module
- `termExplanationsData.js` is available publicly
- `data/regulation.json` no longer carries `termExplanations`
- the public DOM still renders 12 term cards and one callout on card index 7

This supports the schema-plan assumption that small repeated card groups can be
split first while table schema, long-body schema, and JSON/fetch behavior remain
behind later gates.

## Phase 3-B7 Pilot Summary And Level-Cap Row Candidate

Phase 3-B7 records the first pilot summary and next-candidate decision:

- `docs/world-template-regulation-data-pilot-summary.md`

The first data-module pilot supports the schema-plan approach, but also adds
two constraints:

- when a top-level key is removed from `data/regulation.json`, public
  cache-mixing checks are mandatory
- data modules are useful for another small pilot, but they are still not the
  final standalone JSON/editing model

Selected next schema candidate:

- `levelCaps` row data only

This is a table-shaped candidate, but the next gate must not move table column
definitions yet. `LEVEL_CAP_COLUMNS` remains renderer-owned until a separate
renderer-constant audit decides otherwise. Reward, honor, Sword Shard, growth,
and rank-limit values also remain cells in the same level-cap row shape for the
next pilot.

Long house rules, magic-angel rulings, complex growth rules, and standalone
reward/honor table schemas remain later candidates.

## Phase 3-B8 Level-Cap Current Behavior Spec

Phase 3-B8 freezes the current behavior of the selected second data-module
candidate:

- `docs/world-template-regulation-level-caps-spec.md`

Schema-plan impact:

- `levelCaps` remains a world-site template data candidate.
- The current production row data is 14 rows by 11 string fields.
- `LEVEL_CAP_COLUMNS` remains renderer-owned for the next gate.
- `renderTable()` remains renderer/layout behavior, not content data.
- Regulation `levelCaps` must remain separate from calendar-side
  `data/calendarConfig.json` level-cap date ranges.
- No reusable ops core, auth, membership, DB/RPC/RLS, Edge Function, or Discord
  behavior is part of this schema candidate.

The next implementation gate may use a world-site data module for the row array,
but standalone JSON/fetch migration and table-column schema migration remain
separate later decisions.

## Phase 3-B9 Level-Cap Data Module

Phase 3-B9 moves the selected row array to a world-site data module:

- `docs/world-template-regulation-level-caps-data-module-result.md`

Schema-plan impact:

- `levelCaps` row data is now owned by
  `assets/js/world/regulation/levelCapsData.js`
- `data/regulation.json` no longer owns the `levelCaps` key
- the first table-shaped data-module split kept the existing row shape exactly
- table column definitions remain renderer-owned
- table renderer behavior remains renderer/layout behavior
- calendar-side `data/calendarConfig.json` level-cap date ranges remain
  separate

This supports one more small data-module step, but it still does not approve a
general standalone JSON/fetch migration or long-body schema migration.

## Phase 3-B10 Level-Cap Public Rollout

Phase 3-B10 confirms the public static delivery of the `levelCaps` data module:

- `docs/world-template-regulation-level-caps-data-module-public-check.md`

Schema-plan impact:

- the second small data-module split is publicly available
- public `levelCapsData.js` exports the row array
- public `data/regulation.json` no longer carries `levelCaps`
- the public renderer still owns columns and table rendering
- the table-shaped pilot remains separate from calendar-side level-cap date
  ranges

The rollout supports the data-module approach for small, isolated world-site
data, but standalone JSON/fetch migration, table-column schema migration, and
long-body schema migration remain later decisions.

## Phase 3-B11 Two-Pilot Summary And Next Schema Candidate

Phase 3-B11 summarizes the first two data-module pilots:

- `docs/world-template-regulation-level-caps-data-pilot-summary.md`

Schema-plan impact:

- card-shaped data and table-row data have both passed implementation and
  public static delivery checks
- `data/regulation.json` now excludes `termExplanations` and `levelCaps`
- `termExplanationsData.js` and `levelCapsData.js` are world-site template data
  modules
- renderer-owned column definitions and shared renderers remain outside data
  modules
- cache-mixing checks remain mandatory when a JSON key or block is removed

Selected next schema candidate:

- short note card data
- concrete first target: the `reward` section `type: "callout"` block

This candidate tests a third shape: a small block nested under `sections`.
The next gate must keep the target narrow and avoid a general block registry,
long-rule schema, table-column schema, or standalone JSON/fetch migration.

## Phase 3-B12 Reward Callout Current Behavior Spec

Phase 3-B12 freezes the current behavior of the selected nested-block
candidate:

- `docs/world-template-regulation-reward-callout-spec.md`

Schema-plan impact:

- short note/callout data remains a world-site template candidate
- the first target is a single `reward` section block, not the whole section
- the current shape is `{ type, title, paragraphs }`
- `renderBlock(block)` remains renderer-owned
- `renderDataSection(sectionData)` remains renderer-owned
- section ids, anchors, CSS classes, and active TOC behavior remain outside
  content data

The future implementation may use a world-site data module for this one block,
but general block registries, long-rule schemas, and standalone JSON/fetch
migration remain separate later decisions.

## Phase 3-B13 Reward Callout Data Module

Phase 3-B13 implements the selected nested-block data-module split:

- `docs/world-template-regulation-reward-callout-data-module-result.md`

Schema-plan impact:

- short note/callout data can move as a single world-site data module
- `rewardCalloutBlocksData.js` owns the selected callout block
- `data/regulation.json` keeps the parent `reward` section and reward
  paragraph block
- `renderBlock(block)` and `renderDataSection(sectionData)` remain
  renderer-owned
- the implementation does not introduce a general block registry
- the implementation does not approve standalone JSON/fetch migration
- long-rule schemas, all-callout extraction, and renderer/schema separation
  remain later gates

Public static delivery still needs a separate rollout-check gate.

## Phase 3-B14 Reward Callout Public Rollout

Phase 3-B14 confirms public static delivery and browser DOM output for the
selected nested-block data module:

- `docs/world-template-regulation-reward-callout-data-module-public-check.md`

Schema-plan impact:

- nested short-note data has now passed implementation and public rollout
  checks
- public JSON ownership matches the source split: parent `reward` section in
  JSON, selected callout block in `rewardCalloutBlocksData.js`
- public renderer can compose nested module data without changing
  `renderBlock()` or `renderDataSection()`
- stale JSON duplicate-display protection was confirmed in public
  `renderRegulation.js`
- general block registries, long-rule schemas, and standalone JSON/fetch
  migration remain later gates

## Phase 3-B15 Reward Callout Pilot Summary

Phase 3-B15 summarizes the first three data-module pilots:

- `docs/world-template-regulation-reward-callout-data-pilot-summary.md`

Schema-plan impact:

- the data-module method now covers three shapes:
  - repeated cards
  - table rows
  - one nested section block
- nested item moves are plausible, but should be proven with one small
  subsection item before any general registry
- table-column schemas remain separate from row data ownership
- reward amount, honor, and Sword Shard values should remain inside
  `levelCapsData.js` until a table/column schema gate is opened
- long-rule schemas and magic-angel rulings remain later gates

Selected next schema candidate:

- one short note subsection item under `general-skills`
- concrete first target:
  `注釈2：『制限』について`

The future implementation may use a world-site data module for this one
subsection item, but whole-section moves, all-subsection registries, and
standalone JSON/fetch migration remain separate later decisions.

## Phase 3-B16 General Skill Note Data Module

Phase 3-B16 proved one nested subsection item can be moved without introducing
a generic subsection registry:

- `docs/world-template-regulation-general-skill-note-data-module-result.md`

Schema-plan impact:

- `generalSkillNoteSubsectionsData.js` owns exactly one `title` plus
  `paragraphs` subsection item
- the parent `general-skills` section and `subsections` block remain JSON-owned
- the renderer composes module data back into the existing block before calling
  `renderDataSection(sectionData)`
- stale JSON duplicate protection can remain title-scoped for isolated nested
  items
- no new block schema, table schema, or fetch lifecycle was introduced

Do not generalize this into an all-subsection registry until at least one
separate schema gate defines ownership, duplicate keys, ordering, and rollback
behavior.

## Phase 3-B17 Original General Skill Bonus Data Module

Phase 3-B17 moved one `original-general-skills` subsection item while keeping
the schema boundary narrow:

- `docs/world-template-regulation-original-general-skill-bonus-data-module-result.md`

Schema-plan impact:

- `originalGeneralSkillBonusSubsectionsData.js` owns exactly one `title` plus
  `paragraphs` subsection item
- the parent `original-general-skills` section and target `subsections` block
  remain JSON-owned
- composition is section-scoped and block-index-scoped, not a generic registry
- stale JSON duplicate protection remains title-scoped for this isolated item
- no new block schema, table schema, or fetch lifecycle was introduced

This reinforces that one-off subsection modules are workable, but it does not
approve an all-subsection registry or section-wide extraction.
