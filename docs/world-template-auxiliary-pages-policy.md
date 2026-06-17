# World Template Auxiliary Pages Policy

Date: 2026-06-17
Phase: 3-C10
Baseline: `dd56374 Document ops static dry run checklist`

This note documents how `tools` and `updates` should be treated when the
Velgard site is reused as a next-world template. It is docs-only. It does not
change HTML, CSS, JS, data files, renderers, `updates.json`, auth, DB/RPC/RLS,
Edge Functions, Discord sync, secrets, or live operational data.

## Current Inventory

Tools page:

- page: `tools.html`
- page key: `data-page="tools"`
- renderer: `assets/js/renderTools.js`
- shared router: `assets/js/main.js`
- data: `data/randomTables.json`
- CSS: `assets/css/style.css`
- current module cache chain:
  - `tools.html` loads `assets/js/main.js?v=20260615-calendar-core-move`
  - `main.js` imports `renderTools.js?v=20260529-calendar-date-tools-history`
  - `renderTools.js` loads
    `data/randomTables.json?v=20260529-calendar-date-tools-history`

Current `data/randomTables.json` shape:

- top-level keys: `version`, `description`, `tables`
- table count: 15
- visible table count: 13
- hidden helper table count: 2
- current table types: `branch`, `table`
- current dice forms handled by the renderer: `1d36`, `1d12`, `1d2`, `2D6`
- client-side history key: `velgard.tools.rollHistory`
- local browser state only; no DB, auth, or Discord write path is used by the
  current tool renderer.

Updates page:

- page: `updates.html`
- page key: `data-page="updates"`
- renderer: `assets/js/renderUpdates.js`
- shared router: `assets/js/main.js`
- data: `data/updates.json`
- CSS: `assets/css/style.css`
- current module cache chain:
  - `updates.html` loads `assets/js/main.js?v=20260615-calendar-core-move`
  - `renderUpdates.js` loads `data/updates.json`

Current `data/updates.json` shape:

- current format: array
- current entry count: 41
- current fields observed: `date`, `title`, `description`, `target`, `tags`
- current renderer accepts `description` or `body`
- current renderer uses `target` and `tags` for card metadata
- no `status` field is present in current entries, so every current entry is
  rendered after the visibility helper fallback.

## Auxiliary Page Position

### `tools`

`tools` is an auxiliary function page. It sits between the world-template side
and reusable utility space, but it is not currently a live ops page.

Treat it as public-only auxiliary content when:

- the tool runs entirely in the client
- it uses public JSON or local browser state only
- it does not require auth, membership, DB/RPC/RLS, Edge Functions, Discord,
  or external private APIs
- it can fail safely with an empty state or visible static error

Treat it as world-specific when:

- the tool text contains setting-specific rules, references, labels, or links
- random table contents are tied to Velgard, SW2.5-specific house rules, a
  particular regulation page, or a specific GM operation style
- local storage keys, copy text, or table names would confuse users in another
  world

### `updates`

`updates` is an auxiliary announcement and changelog page.

The display structure is reusable, but the current `data/updates.json` is
Velgard operational history. For a next world, the content should normally be
reset or newly created. Do not copy the current history as production history
for another world.

## Tools Template Policy

Reusable structure:

- page shell with site header/footer and `main.js` routing
- random table selector
- client-side roll action
- result card
- copy button
- history list
- history copy/reset controls
- empty history state
- public JSON loading through `loadJson`
- CSS classes for `tools-section`, `tool-panel`, `tool-result`,
  `tool-history`, `tool-result-card`, and copy/history controls

Replace per world:

- page title, meta description, OGP copy, and visible lead text
- random table titles, labels, result text, and branch labels
- any references to Velgard-specific rules or regulation links
- any SW2.5-only tool explanation when the next world does not use the same
  assumptions
- local storage key, if the next world must not share browser history with a
  copied site under the same origin

Careful-gate items:

- tools that submit data to session-post, session-detail, DB, or RPCs
- tools that depend on auth or membership state
- tools that invoke external APIs
- tools that post to Discord or prepare production Discord payloads
- tools that consume private files or private URLs
- tools that expose GM-only tables, unreleased contents, or user-specific data

Do not copy:

- private GM random tables
- unreleased scenario or campaign spoilers
- tables containing personal information or private operational state
- Discord result records, Webhook details, token-like values, or private URLs
- Velgard-specific table contents unless a next-world GM explicitly rewrites
  and approves them as public content.

## Updates Template Policy

Reusable structure:

- page shell with site header/footer and `main.js` routing
- public changelog list
- date-descending sort
- update card structure
- date, metadata tags, title, and body/description fields
- empty state for zero entries

Replace per world:

- all current Velgard update entries
- production dates from the current site
- current feature names when they are not used in the next world
- current announcement copy
- links, images, or references tied to Velgard pages or assets

Careful or do-not-copy items:

- live operation logs
- membership or session-internal notes
- Discord post results
- GitHub, Supabase, or Discord actual ids
- secret-adjacent information
- private rollout notes
- update history that belongs only to Velgard.

Updates should remain public information. If a message is not safe for every
visitor to read, it does not belong in public GitHub Pages data.

## `updates.json` Handling

For this phase:

- `data/updates.json` is not changed.

For a next world:

- reset or create a new updates dataset
- use the current schema as a display reference only
- do not reuse Velgard operational history as production history
- keep sample entries clearly labeled as placeholders if docs include examples
- write only public-safe information
- do not include secrets, private ids, raw user data, private URLs, or internal
  operation records
- support zero entries or one small launch notice as valid initial states

## Data Structure Ideas

These are documentation-only pseudo structures. They are not new files and are
not implementation commitments.

```js
const tools = [
  {
    id: "sample-tool",
    title: "Tool name",
    category: "dice | utility | reference",
    summary: "Short public explanation",
    isWorldSpecific: false,
    relatedRegulation: null,
    visibility: "public"
  }
];
```

```js
const updates = [
  {
    id: "sample-update",
    date: "YYYY-MM-DD",
    category: "site | world | ops",
    title: "Public update title",
    body: ["Public-safe update text"],
    tags: [],
    visibility: "public"
  }
];
```

Notes:

- `id` is an internal key, not display copy.
- `category` is a display grouping value, not a DB enum.
- CSS classes and DOM ids stay with renderer/CSS ownership.
- actual secret values, raw user data, and private operation ids must not be
  stored in these data structures.
- next-world values must be written for that world, not copied from Velgard.

## Reusable Ops Core Boundary

`tools` and `updates` are auxiliary pages.

- They can support a world-template site without being reusable ops core.
- A fully client-side tool can be reused as world-template auxiliary structure.
- A tool that reaches auth, DB/RPC/RLS, Edge Functions, Discord, or session
  operations becomes a separate ops gate.
- `updates` is operational history, but it is not the DB/RPC/Discord activity
  log.
- Do not auto-write session operation results or Discord sync results into
  `updates.json`.
- Do not change `updates.json` without an explicit update-history task.

## Introduction Checklist

Before enabling `tools` in a next world:

- confirm each tool is world-independent or rewritten for the new world
- confirm no private GM-only table is exposed
- confirm no DB/auth/Discord dependency exists unless a separate gate approves
  it
- confirm public JSON parses
- confirm table ids are unique
- confirm result and branch text are public-safe
- confirm the page works with zero or few tables if supported
- confirm no visible `undefined`, `[object Object]`, or empty result shell
- confirm public HTTP 200 and no broken imports
- record `limited`, `not_tested`, or `not_connected` scopes honestly.

Before enabling `updates` in a next world:

- confirm `updates.json` was not copied as Velgard production history
- confirm the update list is reset or rewritten for the next world
- confirm zero updates does not break the page
- confirm update dates, titles, descriptions, targets, and tags are public-safe
- confirm no secret values, private ids, tokens, raw user data, or private URLs
  are present
- confirm public HTTP 200 and no broken imports
- record whether desktop/mobile visual review was `completed` or `limited`.

## Rollback And Recovery

If a next-world auxiliary page introduction fails:

1. Disable or hide the specific tool or update entry that caused the issue.
2. Restore the prior auxiliary data file if it was changed.
3. Revert renderer/CSS changes if a separate gate changed them.
4. Update cache-bust if a rollback touches delivered HTML or JS.
5. Re-check public HTTP 200 and broken imports.
6. Re-check visible output for `undefined`, `[object Object]`, empty cards, and
   broken images if image links are involved.
7. Record the rollback reason in docs.
8. Do not use auth, DB/RPC/RLS, Discord, Edge Functions, or secrets to recover
   an auxiliary-page content mistake.

## Next Candidate Options

Candidate A: OGP / favicon / hero image rollout gate.

- Document site identity asset replacement, cache-bust, public preview checks,
  and rollback for a next world.

Candidate B: authenticated QA matrix plan.

- Define approved/unapproved/owner/admin/member-manager QA only after auth
  connection is explicitly approved.

Candidate C: DB/RPC/RLS gate checklist.

- Define SELECT-only, SQL apply, RLS, RPC, write QA, and rollback separation
  before database work.

Candidate D: optional auxiliary implementation review.

- Review whether a specific client-only tool should be kept, removed, or
  rewritten for a next world.

Recommended next candidate:

- Candidate A: OGP / favicon / hero image rollout gate.

Reason:

- Several page-adoption docs now flag OGP, favicon, and hero assets as careful
  identity assets.
- This remains docs-only and world-template scoped.
- It should happen before live auth, DB/RPC/RLS, Edge, Discord, or write QA
  gates for a next world.

## Limited And Not Tested

Limited:

- current inventory was static file inspection only
- no browser interaction was performed for tools
- no public HTTP sweep was run
- no desktop/mobile visual review was performed
- current random table content was classified at the policy level, not
  reviewed line-by-line for next-world suitability

Not tested:

- actual next-world rendering
- empty `data/randomTables.json` behavior in browser
- empty `data/updates.json` behavior in browser
- auth-connected auxiliary behavior
- DB/RPC/RLS behavior
- Edge Functions
- Discord sync or posting
- production update workflow

## No Dangerous Work

This phase did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge deploy, Discord operation, secret/Webhook change, direct
Supabase write, debug logging addition, `updates.json` change,
auth/permission logic change, membership logic change, RPC/DB key
configuration, CSS class/DOM id/anchor change, `management_key` display, raw
id/email/token/JWT display, HTML change, CSS change, JS change, JSON/data
change, sample data creation, renderer change, tool behavior change, or update
history change.
