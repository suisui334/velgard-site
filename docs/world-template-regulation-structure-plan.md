# World Template Regulation Structure Plan

Phase 3-B1 documents the regulation page as a future-world site template
candidate. This is a docs-only planning note. It does not change HTML, CSS,
JavaScript, JSON data, SQL, RPC, auth, Discord sync, or reusable ops core code.

## Background

The Velgard regulation page is currently a world-site page, not an ops-core
page. It is still connected to operations because players and GMs use it before
creating sessions, applying to sessions, commenting, and checking campaign
rules.

The reusable target is not Velgard's exact content or visual theme. The target
is the page skeleton, data shape, table/card patterns, long-rule handling, and
navigation behavior that another world site can reuse with different content.

## Current Implementation Shape

Current files and responsibilities:

- `regulation.html`: static page shell and script/style loading.
- `assets/js/renderRegulation.js`: renders regulation data into the page.
- `assets/css/style.css`: contains the current regulation page layout and card
  styles.
- `data/regulation.json`: owns the main regulation content.

Current data shape includes:

- page metadata such as `pageLabel`, `title`, `subtitle`, and `lead`
- `schedule`
- `levelCaps`
- `termExplanations`
- `adoptedRulebooks`
- `sections`

Current renderer concepts include:

- table-of-contents items and active current-section highlighting
- level-cap column definitions
- card-style sections
- term explanation cards
- table wrappers
- block types such as paragraphs, callouts, lists, ordered lists, details,
  subsections, and tables
- special strong-heading treatment for selected long-rule paragraph labels

## Template Parts

The following parts are useful as next-world template building blocks:

- page title and intro lead
- table of contents / side menu
- active menu state that follows scroll position
- term explanation cards
- level-cap tables
- reward, honor, growth, and similar operational tables
- long-form house-rule cards
- individual ruling cards
- caution or note cards
- GM-facing notes
- player-facing notes
- update-history or latest-change navigation, if added later

These parts should remain data-driven where possible. The visual treatment can
change per world.

## Classification

### A. Reusable Structure As-Is

These structures are good future-world skeleton candidates:

- wide desktop reading layout with a main article area and side menu
- mobile stacked layout
- table-of-contents links using section anchors
- active current-position menu behavior
- one-column long-rule card layout
- card-style regulation sections
- card-style term explanations
- table wrappers for horizontally dense rule tables
- callout/list/details/subsection block rendering

### B. Good Candidates For Data/JSON Structure

These should be represented as world data or schema-like documentation before
building another world:

- regulation page metadata
- table-of-contents order and labels
- section ids, titles, and categories
- term explanation cards
- level-cap tables
- reward and honor tables
- growth-rule tables and notes
- long house-rule blocks
- individual ruling cards
- GM notes and player notes
- adopted rulebook lists
- table column definitions
- strong subsection labels inside long-form text

The current hard-coded pieces such as TOC item lists, level-cap column lists,
and strong paragraph labels are good candidates for a future world-site config
or JSON schema. They should not be rushed into reusable ops core.

### C. Velgard-Specific Content

These should remain world-specific data:

- concrete magic-angel rulings and equipment data
- exact reward amounts
- exact Sword Shard / honor-point values
- current fumble experience handling
- current lower-bound growth handling
- abyss-related rulings
- race, item, and house-rule text tied to Velgard
- Velgard dates, terms, labels, and operational conventions
- current logo, colors, spacing, card decoration, and mood

### D. Do Not Generalize Directly

These should not become reusable defaults:

- Velgard-specific proper nouns
- exact campaign numeric values
- campaign-period-specific warnings
- current DOM ids as data contracts
- current CSS class names as data contracts
- auth, membership, RPC, DB, or Discord sync behavior
- ops-core permission labels or internal keys
- any raw id, token, email, user id, session id, or management key surface

## Data Structure Candidates

These are future planning candidates only. Do not create these files or schemas
until a dedicated implementation gate.

### `regulationPage`

Possible fields:

- `id`
- `pageLabel`
- `title`
- `subtitle`
- `lead`
- `updatedAt`
- `versionLabel`
- `introBlocks`

### `regulationToc`

Possible fields:

- `id`
- `label`
- `targetSectionId`
- `order`
- `category`
- `isPrimary`

### `regulationSections`

Possible fields:

- `id`
- `title`
- `category`
- `summary`
- `blocks`
- `tocLabel`
- `anchor`

### `regulationBlocks`

Reusable block types:

- `paragraphs`
- `callout`
- `list`
- `orderedList`
- `details`
- `subsections`
- `table`
- `note`
- `definitionCards`

Possible common fields:

- `type`
- `title`
- `paragraphs`
- `items`
- `columns`
- `rows`
- `caption`
- `notes`

### `regulationTables`

Useful for level caps, rewards, honor, growth, and similar rules:

- `id`
- `title`
- `description`
- `columns`
- `rows`
- `cellNotes`
- `footnotes`

### `termCards`

Possible fields:

- `term`
- `title`
- `paragraphs`
- `examples`
- `relatedSectionIds`

### `houseRules` And `individualRulings`

Possible fields:

- `id`
- `title`
- `category`
- `audience`
- `blocks`
- `severity`
- `relatedTerms`

### `gmNotes` And `playerNotes`

Possible fields:

- `id`
- `audience`
- `text`
- `relatedSectionId`
- `visibleInSummary`

## Layout Policy

Recommended next-world layout policy:

- Desktop should use the page width generously.
- Long regulations should use a one-column reading flow rather than two-column
  cards.
- The side menu / table of contents is useful on desktop.
- The active current-section state is worth reusing.
- Mobile should remain vertically stacked.
- Cards may remain as the visual unit, but readability is more important than
  decorative density.
- Tables should prioritize scanability and horizontal safety.
- Long-rule sections should have clear heading levels inside the card.

## Ops Boundary

Regulation belongs to the world-site template side.

Reusable ops platform side:

- `calendar`
- `mypage`
- `session-post`
- `session-detail`
- membership management
- application/comment flows
- templates
- Discord sync

World-site side:

- `world`
- `characters`
- `spots`
- `terms`
- `regulation`
- `gallery`

Connection points:

- `session-post` may link to regulation before posting a session.
- `mypage` may link to regulation for participation or account guidance.
- `session-detail` may link to regulation for player expectations.
- `calendar` may lead users toward rules that explain participation timing.

Boundary rules:

- regulation renderer/data changes should not require ops-core changes
- ops auth, membership, RPC, DB, and Discord behavior should not be embedded in
  regulation data
- future independent ops tooling should be able to run without the Velgard
  regulation content
- future world sites can reuse the regulation display pattern without importing
  ops permissions or database contracts

## Migration Roadmap

### Phase W-R0: Documentation Freeze

Purpose: keep the current Velgard structure understandable before refactoring.

Work:

- document the current renderer/data/page structure
- document reusable and world-specific parts
- keep implementation unchanged

Risk: low.

Completion: this document and related docs identify the template structure.

### Phase W-R1: Schema Draft

Purpose: draft a regulation data schema without changing production data.

Work:

- define section, block, table, term-card, and note shapes
- map current `data/regulation.json` fields to candidate shapes
- decide how TOC and strong subsection labels should become data

Risk: low to medium.

Completion: docs-only schema proposal exists.

### Phase W-R2: Renderer Boundary Review

Purpose: separate what is content config from what is renderer behavior.

Work:

- review `renderRegulation.js` constants
- decide which constants can move to data/config
- keep layout and active menu behavior stable

Risk: medium. Renderer changes affect public display.

Completion: implementation gate is ready with exact affected files and QA.

### Phase W-R3: Data-Driven Pilot

Purpose: move one small regulation structure into data/config.

Work:

- choose one low-risk item such as TOC labels or a small term-card field
- keep fallbacks
- verify public display

Risk: medium.

Completion: public page output remains unchanged.

### Phase W-R4: Next-World Trial

Purpose: confirm the template works with a second world draft.

Work:

- create a non-production sample data set
- verify page skeleton, cards, tables, and TOC behavior
- do not force Velgard visual design onto the new world

Risk: medium to high, depending on site split approach.

Completion: a second-world sample can render from the documented structure.

## Next Candidates

1. Draft a docs-only `regulation` JSON schema proposal.
2. Audit `renderRegulation.js` constants that are world data rather than
   renderer behavior.
3. Record a public browser QA result for the current regulation layout if not
   already done.
4. Review world-site config boundaries for `terms`, `gallery`, and
   `characters` after regulation structure is stable.

## Phase 3-B2 Data Schema Detail

Phase 3-B2 expands the data/json planning layer:

- `docs/world-template-regulation-data-schema-plan.md`

The schema plan keeps implementation unchanged and records:

- current regulation page element inventory
- data/json suitability groups
- candidate data objects such as `regulationPage`, `regulationNav`,
  `regulationSections`, `regulationCards`, `regulationTables`, `levelCaps`,
  `rewardRules`, `growthRules`, `houseRules`, `specialRulings`, `gmNotes`, and
  `playerNotes`
- generic structure versus Velgard-specific content
- staged implementation order that starts with docs, then small tables, then
  low-risk cards, and leaves long/special rulings for last
- the boundary that regulation data remains world-site template data and should
  not absorb auth, membership, RPC, DB, Discord, DOM id, CSS class, input name,
  or internal-key contracts

## Phase 3-B3 First Data Pilot Selection

Phase 3-B3 chooses the safest first pilot before implementation:

- `docs/world-template-regulation-data-pilot-plan.md`

Selected pilot:

- term explanation cards

The term-card pilot is preferred because it is already close to data, has a
small repeated structure, is easy to compare visually/textually, and does not
require TOC, active menu, CSS class, DOM id, level-cap table, reward value,
special ruling, or ops-core changes.

## Phase 3-B4 Term Explanations Behavior Freeze

Phase 3-B4 freezes the current term-card behavior:

- `docs/world-template-regulation-term-explanations-spec.md`

The spec keeps term explanation cards on the world-site template side and
records that future work should preserve the `term-explanations` section id,
card order, paragraph text, optional callout behavior, current CSS classes, TOC
active behavior, and ops-core separation.
