# Regulation Sample Data Plan

Date: 2026-06-17

Phase: 3-C2 regulation sample data composition plan.

Baseline commit: `9a4f42a Document next world template adoption`

This is a docs-only plan. It does not create sample data files, data modules,
JSON files, renderer code, HTML, CSS, JS, or production content. It does not
change `updates.json`, SQL, DB/RPC/RLS, Edge Functions, Discord, auth, or
secrets.

## Purpose

Regulation sample data is a next-world template draft.

It is not a copy of Velgard production values.

The goal is to show what a new world should prepare first so the regulation
page can render meaningful rules without forcing a large renderer or CSS
rewrite.

Initial assumptions:

- use the existing regulation page skeleton where possible
- keep HTML, CSS, and renderer behavior stable at first
- keep JSON/fetch migration out of the initial adoption gate
- use static data modules only for small isolated targets
- start with short cards, short notes, and table row data
- leave long rulings and complex special rules for later gates
- keep regulation data on the world-site template side, not reusable ops core

## Initial Regulation Set

### Required Candidates

These should be prepared before a next-world regulation page is considered
usable:

- page title
- intro / lead explanation
- basic policy cards
- term explanation cards
- level-cap table
- reward table
- honor / Sword Shard table
- growth-rule overview
- GM-facing notes
- player-facing notes

Purpose:

- give players enough information to understand participation expectations
- give GMs enough guidance to run early sessions
- prove the page skeleton, TOC, cards, notes, and tables all render
- avoid long special rulings during initial setup

### Optional Candidates

These can be added after the required set renders safely:

- special race rulings
- world-specific item rulings
- fumble experience rule
- lower-bound growth rule
- general skill rule
- original skill rule
- individual house-rule cards
- caution cards

Add these one at a time when their current position, renderer path, and visible
output can be checked.

### Deferred Candidates

Keep these out of the first sample data pass:

- long house rules
- complex special rulings
- magic-angel style multi-step rulings
- rules that span multiple sections
- rules that require active TOC or anchor structure changes
- rules that require CSS class additions
- rules that require `renderBlock()`, `renderDataSection()`, or `renderTable()`
  changes
- rules that require table-column migration

These should wait for dedicated structure, renderer, or visual QA gates.

## Pseudo Composition

Do not create this as a production file in this phase.

This is an illustrative placeholder composition only:

```js
const regulationSampleComposition = {
  regulationPage,
  regulationSections,
  termExplanations,
  levelCaps,
  rewardRules,
  honorRules,
  growthRules,
  noteCards,
  calloutBlocks,
  specialRulings,
  gmNotes,
  playerNotes
};
```

All sample values in future examples must be labeled as placeholders. Do not
copy Velgard concrete values into a next-world sample unless that world
explicitly chooses and reviews them.

## Structure Notes

### `regulationPage`

Role:

- page identity and introduction

Expected fields:

- `pageLabel`
- `title`
- `subtitle`
- `lead`
- optional `summary`
- optional `updatedAt`
- optional `versionLabel`

Minimum required fields:

- `title`
- `lead`

Optional fields:

- `pageLabel`
- `subtitle`
- `summary`
- `updatedAt`
- `versionLabel`

Data-module fit:

- low. Keep page-level metadata in `data/regulation.json` or the next-world
  equivalent until a page-metadata gate exists.

World-specific values:

- all visible text, update labels, and version labels

Replace per world:

- world name, rules summary, intro tone, and date/version wording

Renderer responsibility:

- page heading DOM
- existing CSS classes
- page shell integration
- section placement

### `regulationSections`

Role:

- main long-form section list and block container

Expected fields:

- `id`
- `title`
- `blocks`
- optional `lead`
- optional `summary`
- optional `tocLabel`
- optional `audience`

Minimum required fields:

- `id`
- `title`
- `blocks`

Optional fields:

- `lead`
- `summary`
- `tocLabel`
- `audience`

Data-module fit:

- medium to low. Do not move whole sections during initial adoption. Move only
  one small nested block or item when the position is exact.

World-specific values:

- all ids, titles, body copy, and order decisions

Replace per world:

- section list, rule categories, body content, and section order

Renderer responsibility:

- `renderDataSection()`
- `renderBlock()`
- section DOM
- section anchors and CSS classes
- active TOC integration

### `termExplanations`

Role:

- short glossary / rule explanation cards

Expected fields:

- `term`
- `paragraphs`
- optional `exampleTitle`
- optional `exampleParagraphs`

Minimum required fields:

- `term`
- `paragraphs`

Optional fields:

- `exampleTitle`
- `exampleParagraphs`
- future tags only after a schema gate

Data-module fit:

- high. This is a good first module when cards are short and count/order can be
  checked.

JSON ownership:

- may move to `assets/js/world/regulation/termExplanationsData.js` when the
  initial cards are stable

World-specific values:

- every term and paragraph

Replace per world:

- glossary terms, rule explanations, examples

Renderer responsibility:

- card grid DOM
- existing term-card CSS classes
- optional callout rendering
- `#term-explanations` anchor behavior if reused

### `levelCaps`

Role:

- progression / level cap row data

Expected fields:

- world-specific level label
- experience or milestone label
- growth guidance
- reward guidance
- honor / shard guidance where used
- rank or availability limits where used
- optional notes

Minimum required fields:

- a level or milestone label
- enough row values to match the current table columns

Optional fields:

- notes
- date or period labels
- reward/honor guidance if the world uses them

Data-module fit:

- high for row data only.

JSON ownership:

- row data may move to `assets/js/world/regulation/levelCapsData.js`
- table columns should remain renderer-owned until a separate column gate

World-specific values:

- all values, especially levels, dates, rewards, honor, and rank limits

Replace per world:

- all numbers, periods, labels, and progression policy

Renderer responsibility:

- table DOM
- table wrapper
- column definitions until a separate gate
- `renderTable()`
- section anchor and TOC behavior

### `rewardRules`

Role:

- reward policy, reward rows, and short reward notes

Expected fields:

- `id`
- `title`
- `paragraphs`
- optional `rows`
- optional `notes`
- optional `callouts`

Minimum required fields:

- `title`
- either `paragraphs` or `rows`

Optional fields:

- examples
- GM notes
- player notes
- callout blocks

Data-module fit:

- medium. Short callout blocks and row data are good candidates. Whole reward
  sections are not first-pass candidates.

JSON ownership:

- keep the reward section shell in `data/regulation.json`
- move one short note/block or row array only when scoped

World-specific values:

- reward amounts, formulas, examples, and operation notes

Replace per world:

- all reward values and explanatory text

Renderer responsibility:

- block rendering
- table rendering
- section placement
- CSS classes and anchors

### `honorRules`

Role:

- honor point, Sword Shard, reputation, or equivalent reward guidance

Expected fields:

- `id`
- `title`
- `paragraphs`
- optional `rows`
- optional `notes`

Minimum required fields:

- `title`
- guidance text or table rows

Optional fields:

- examples
- GM notes
- player notes

Data-module fit:

- medium for row data or short cards. Keep table-column movement separate.

JSON ownership:

- can remain in `data/regulation.json` at first
- may use `assets/js/world/regulation/honorRulesData.js` later for a narrow
  target

World-specific values:

- all honor/Sword Shard equivalents and values

Replace per world:

- terminology, row values, examples, and notes

Renderer responsibility:

- table/list/callout DOM
- column definitions until a separate gate
- section anchors

### `growthRules`

Role:

- growth, advancement, fumble experience, lower-bound growth, or equivalent
  progression rules

Expected fields:

- `id`
- `title`
- `paragraphs`
- optional `items`
- optional `notes`
- optional `tableRef`

Minimum required fields:

- `title`
- `paragraphs`

Optional fields:

- lists
- short notes
- related term ids
- table references

Data-module fit:

- low to medium. Short notes can move, but whole growth-rule clusters should
  stay in JSON until body structure is designed.

JSON ownership:

- keep overview text in `data/regulation.json` initially
- move only one short note or item if it is isolated

World-specific values:

- all growth and advancement rules

Replace per world:

- formulas, limits, examples, and GM/PL guidance

Renderer responsibility:

- paragraph/list/subsection rendering
- long-body readability
- anchors and TOC

### `noteCards`

Role:

- short guidance cards that are not tied to a specific table

Expected fields:

- `title`
- `paragraphs`
- optional `audience`
- optional `severity`

Minimum required fields:

- `title`
- `paragraphs`

Optional fields:

- `audience`
- `severity`
- `relatedSectionId`

Data-module fit:

- high when one card or one card group is isolated.

JSON ownership:

- may live in `data/regulation.json` first
- may move to target-specific data modules later

World-specific values:

- all titles and paragraphs

Replace per world:

- GM guidance, player guidance, cautions, and operational notes

Renderer responsibility:

- card/callout DOM
- CSS class selection
- section placement

### `calloutBlocks`

Role:

- highlighted notes inside sections

Expected fields:

- `type`
- `title`
- `paragraphs`

Minimum required fields:

- `type`
- `title`
- `paragraphs`

Optional fields:

- future severity or audience fields only after a schema gate

Data-module fit:

- high for one exact block when insertion position is clear.

JSON ownership:

- parent section should remain in `data/regulation.json`
- one exact block can move to a module such as
  `assets/js/world/regulation/rewardCalloutBlocksData.js`

World-specific values:

- all note text

Replace per world:

- title, paragraphs, and section placement

Renderer responsibility:

- `renderBlock()` callout branch
- `.regulation-callout`
- parent section anchor
- duplicate-display guard if stale JSON is possible

### `specialRulings`

Role:

- world-specific special cases, races, items, or rule exceptions

Expected fields:

- `id`
- `title`
- `summary`
- `blocks`
- optional `subsections`
- optional `tables`
- optional `sourceRefs`

Minimum required fields:

- `id`
- `title`
- concise summary or blocks

Optional fields:

- source references
- subsections
- tables
- notes

Data-module fit:

- low for long or complex rulings. Short isolated rulings may move later.

JSON ownership:

- keep in `data/regulation.json` during initial adoption

World-specific values:

- nearly all content

Replace per world:

- every special ruling; do not copy Velgard-specific rulings as defaults

Renderer responsibility:

- long-body readability
- heading hierarchy
- list/table/callout rendering
- TOC and anchor behavior

### `gmNotes`

Role:

- GM-facing operation guidance

Expected fields:

- `title`
- `paragraphs`
- optional `relatedSectionId`
- optional `audience`

Minimum required fields:

- `title`
- `paragraphs`

Optional fields:

- `relatedSectionId`
- `audience`
- priority or visibility labels only after a schema gate

Data-module fit:

- high for short notes.

JSON ownership:

- can start in `data/regulation.json`
- can move one note at a time when stable

World-specific values:

- all GM-facing guidance and procedures

Replace per world:

- GM instructions, rulings, and operational expectations

Renderer responsibility:

- note/callout/subsection DOM
- audience styling if already supported
- no auth visibility decisions

### `playerNotes`

Role:

- player-facing participation guidance

Expected fields:

- `title`
- `paragraphs`
- optional `relatedSectionId`
- optional `audience`

Minimum required fields:

- `title`
- `paragraphs`

Optional fields:

- `relatedSectionId`
- `audience`
- priority labels only after a schema gate

Data-module fit:

- high for short notes.

JSON ownership:

- can start in `data/regulation.json`
- can move one note at a time when stable

World-specific values:

- all player guidance and participation expectations

Replace per world:

- player instructions, warnings, and examples

Renderer responsibility:

- note/callout/subsection DOM
- no auth, membership, or role-gate behavior

## Data Module Placement

Existing Velgard module examples:

```text
assets/js/world/regulation/termExplanationsData.js
assets/js/world/regulation/levelCapsData.js
assets/js/world/regulation/rewardCalloutBlocksData.js
assets/js/world/regulation/generalSkillNoteSubsectionsData.js
assets/js/world/regulation/originalGeneralSkillBonusSubsectionsData.js
```

Possible next-world module names:

```text
assets/js/world/regulation/termExplanationsData.js
assets/js/world/regulation/levelCapsData.js
assets/js/world/regulation/rewardRulesData.js
assets/js/world/regulation/honorRulesData.js
assets/js/world/regulation/growthNotesData.js
assets/js/world/regulation/specialRulingsData.js
```

Placement policy:

- do not create every module at the start
- begin with the main `data/regulation.json` equivalent and split only when a
  target is stable
- move one target per gate
- keep one file to one target or a very close target group
- split when ownership is unclear
- keep data modules as synchronous imports
- keep JSON/fetch migration behind a separate gate
- keep renderer rewrites behind a separate gate
- keep table column movement behind a separate gate

## Sample Value Policy

Do not copy Velgard concrete values into a next-world sample.

World-specific values include:

- reward amounts
- honor/Sword Shard values
- level cap dates or periods
- level cap labels
- growth formulas
- special ruling text
- proper nouns
- rulebook/source references
- GM operation notes
- player-facing cautions

When sample values are needed in docs, label them as placeholders.

Example placeholder wording:

```text
PLACEHOLDER_LEVEL_LABEL
PLACEHOLDER_REWARD_AMOUNT
PLACEHOLDER_WORLD_TERM
PLACEHOLDER_GM_NOTE
```

Do not treat placeholders as production recommendations. Before public release,
GM/admin reviewers must confirm that every visible value is intentional for the
new world.

## Renderer Boundary

Data owns:

- visible text
- short card records
- short note/callout blocks
- table row values
- section and block content

Renderer owns:

- DOM structure
- CSS class assignment
- DOM ids
- anchors
- active TOC behavior
- `renderBlock()`
- `renderDataSection()`
- `renderTable()`
- table column definitions until a separate gate
- section order logic until a separate gate

Initial adoption should prefer data that can be passed into existing renderer
shapes. Do not change display structure just to make sample data look cleaner.
Preserve display order and compare output before/after when moving data into a
module.

## Introduction Checklist

Use this checklist when preparing next-world regulation sample data:

- world name and site name are replaced
- regulation title and lead are replaced
- term explanation cards are written for the new world
- level-cap table values are marked as placeholder or production-reviewed
- reward table values are world-specific
- honor / Sword Shard equivalent values are world-specific
- growth overview is short and understandable
- GM-facing notes and player-facing notes are separated
- short special rulings are added before long special rulings
- long rulings are deferred
- Velgard-specific proper nouns are not present unless intentionally reused
- CSS classes are not added casually
- DOM ids are not added casually
- anchors are not changed casually
- active TOC behavior is not changed
- cache-bust targets are identified before public rollout
- public `regulation.html` is checked with HTTP 200
- public JS/data/module paths are checked with HTTP 200 where applicable
- no broken import, checked 404, or fetch failure is observed
- no `undefined`, `[object Object]`, empty card, empty row, or empty subsection
  appears in checked output
- `limited` visual/DOM checks are recorded as `limited`
- untested auth, DB/RPC/RLS, Edge, Discord, and data-changing workflows are
  recorded as `not_tested`

## Rollback And Recovery

If sample data adoption fails:

1. Stop adding more sample data.
2. Identify whether the issue is JSON shape, module import, renderer
   composition, cache-bust, CSS/anchor side effect, or public delivery.
3. If a data module caused the issue, remove the module import.
4. Restore the moved key/block/item to `data/regulation.json` or the
   next-world equivalent.
5. Remove the target-specific composition hook from `renderRegulation.js`.
6. Update cache-bust so public delivery cannot keep a mixed chain.
7. Re-run local static checks.
8. Re-run public HTTP 200 and DOM checks.
9. Record the rollback reason, affected target, and final status in docs.

Do not recover by touching:

- secrets
- Webhooks
- Discord production posting
- auth/permission logic
- DB/RPC/RLS
- Edge Functions
- direct Supabase writes
- raw ids, emails, tokens, or JWT values

## Reusable Ops Core Boundary

Regulation sample data is world-template data.

It does not belong in reusable ops core.

Keep separate:

- `calendar`
- `session-post`
- `session-detail`
- `mypage`
- membership
- Discord sync
- auth
- DB/RPC/RLS
- Edge Functions

The regulation `levelCaps` table and calendar-side `levelCaps` date ranges are
not unified at this stage. They may share concepts, but they are separate
surfaces until a dedicated cross-page schema gate exists.

Prepare regulation sample data before connecting auth, DB, RPC, or Discord for
a new world. Ops-core changes must remain a separate workflow with separate QA.

## Next Candidate Options

Candidate A: characters / spots / terms template structures.

- Record field expectations, optional fields, related-id policy, category
  policy, and image reference boundaries.

Candidate B: gallery / image asset boundary guide.

- Separate reusable gallery behavior from world-specific image categories,
  paths, captions, key visuals, and OGP assets.

Candidate C: world-template adoption checklist detail.

- Turn the C1 checklist into page-by-page readiness checklists.

Candidate D: pre-auth / pre-DB / pre-Discord checklist.

- Define what must be true before a next world connects live operational
  surfaces.

Candidate E: regulation sample output QA plan.

- Define a future visual/DOM QA checklist for sample regulation data once a
  real second-world draft exists.

Recommended next candidate:

- Candidate A: characters / spots / terms template structures.

Reason:

- Regulation now has a sample data plan.
- Characters, spots, and terms are the next core world-site data sets needed
  before gallery polish or ops integration.
- This can remain docs-only and keep auth, DB, Discord, CSS, and renderer
  changes out of scope.

## Phase 3-C3 Content Structures Follow-Up

Phase 3-C3 completes that next docs-only candidate:

- `docs/world-template-content-structures-plan.md`

Regulation-sample impact:

- regulation remains the rule-page template, while characters, spots, and terms
  now have their own scalable world-content structure plan
- future regulation records can link to terms, characters, or spots without
  moving those datasets into regulation ownership
- related links remain optional and should not break when the linked content
  area is still sparse or unpublished
- reusable ops core remains separate from all four world-template content areas

## Limited And Not Tested

This plan is docs-only and does not add new runtime QA.

Limited:

- visual suitability of the sample structure
- desktop/mobile regulation layout for a future world
- active TOC scroll-through behavior
- exact long-rule readability

Not tested:

- actual sample data file rendering
- public second-world deployment
- auth flows
- calendar/session-post/mypage integration
- DB/RPC/RLS
- Edge Functions
- Discord sync
- data-changing workflows

## No Dangerous Work

This plan did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge deploy, Discord operation, secret/Webhook change, direct
Supabase write, debug console logging addition, `updates.json` change,
auth/permission logic change, RPC/DB key configuration, `management_key`
display, or raw id/email/token/JWT display.
