# Next World Template Adoption Guide

Date: 2026-06-17

Phase: 3-C1 next-world world-template adoption guide.

Baseline commit: `4208cf1 Document regulation data module adoption`

This is a docs-only guide. It does not include implementation, HTML, CSS, JS,
JSON/data, data-module, renderer, regulation copy, world copy, visual design,
gallery image, `updates.json`, SQL, DB/RPC/RLS, Edge Function, Discord, auth,
or secret changes.

## Purpose

This guide explains what can be reused from the Velgard public site when
building a next world site, what must be replaced, what needs a careful gate,
and what must not be copied.

The goal is not to clone Velgard as-is. The reusable target is:

- page skeletons
- data shapes
- renderer patterns
- regulation data-module procedure
- small reusable ops core helpers
- static delivery and rollback discipline

The world-specific target is:

- story, names, rules, images, visual tone, and live operations data for the new
  world

## Adoption Classification

### A. Easy To Reuse

These can usually be reused as structure, with world-specific data swapped in:

- page skeletons for top, world, characters, spots, scenarios/hooks, terms,
  regulation, gallery, campaigns, and tools
- card-list layouts and detail-page patterns
- related-id linking between characters, spots, scenarios, terms, and gallery
- regulation long-form page structure
- regulation TOC / side-menu pattern
- regulation block rendering concepts: paragraphs, callouts, lists, ordered
  lists, details, subsections, and tables
- regulation static data-module method for small isolated data
- public static delivery checks using HTML, main module, renderer, data module,
  and JSON path verification
- the first reusable ops core structure:
  - `assets/js/core/config/`
  - `assets/js/core/calendar/`
  - `assets/js/core/session/`
- extracted display/helpers under reusable ops core
- calendar / session-post / session-detail / mypage operational structure as a
  candidate, when copied behind separate setup and QA gates

Reuse these as patterns, not as proof that every value or label belongs in the
next world.

### B. Replace Per World

These must be authored or reviewed for each world:

- site title, world name, tagline, intro copy, and navigation copy
- `data/site.json` content
- `data/world.json`
- characters and NPC data
- spots, facilities, maps, and related links
- scenarios/hooks and campaign/episode data
- terms data
- regulation copy and rule meanings
- `data/regulation.json` equivalent content
- regulation data modules under `assets/js/world/regulation/`
- gallery images, captions, categories, and asset paths
- world-specific page order and featured links
- proper nouns, races, factions, locations, titles, and rule terms
- OGP/image assets, logo, key visual, and placeholders

Even when the shape is reusable, the values should be treated as new-world
content.

### C. Decide Carefully

These are reusable candidates, but they are not safe copy/paste surfaces:

- `assets/css/style.css`
- `assets/js/main.js`
- `assets/js/sessionData.js`
- `assets/js/mypageAuthClient.js`
- `assets/js/membershipAccessClient.js`
- `assets/js/discordSyncClient.js`
- whole-file `assets/js/sessionDisplay.js`
- whole-file `assets/js/renderSessionPost.js`
- `assets/js/renderSessionDetail.js`
- public asset directory shape
- cache-bust strategy across HTML and JS imports
- `updates.json`
- membership / auth / role management
- Supabase DB / RPC / RLS
- Edge Functions
- Discord sync
- live operation labels that are also stored values or permission keys

Use dedicated gates for these. A visual or copy change should not accidentally
change auth, DB, Discord, or role behavior.

### D. Do Not Copy

Never copy these into a next world template or docs:

- secrets
- Webhooks
- tokens
- JWT values
- raw user ids
- email addresses
- Discord IDs or URLs
- Supabase project-specific secret values
- actual `management_key` values
- live session data
- live member data
- real production operational logs
- private channel identifiers
- any Velgard-specific public setting that the next world should review before
  reusing

Record only boolean/status-style results such as `configured`, `not_configured`,
`HTTP 200`, `not_tested`, or `limited`.

## Recommended Setup Order

1. Decide the world name, site name, high-level page list, and public navigation.

2. Prepare the smallest usable world data:

   - site settings
   - world intro
   - terms
   - regulation shell
   - a few characters
   - a few spots
   - optional scenarios/hooks

3. Build regulation structure before detailed styling.

   Keep the existing HTML/CSS/renderer pattern stable at first. Replace content
   and data shape deliberately, not through broad renderer rewrites.

4. Add regulation data modules only when useful.

   Start with short cards, short notes/callouts, one subsection item, or table
   row data. Avoid long rules, full sections, shared renderers, table columns,
   and standalone JSON/fetch loading.

5. Decide whether to connect the ops platform.

   Calendar, session-post, session-detail, and mypage are useful, but they
   bring auth, membership, session data, and QA responsibilities. Keep them
   off until the world-site shell is understandable.

6. Treat auth, membership, DB/RPC/RLS, Edge Functions, and Discord sync as
   later independent gates.

   Do not copy live connection values. Do not test real data-changing flows as
   part of the world-template setup gate.

7. Change CSS last and in small steps.

   First confirm the new world renders with existing layouts. Then adapt logo,
   key visual, colors, density, and image ratios behind visual QA.

8. Run static public delivery checks before declaring the template ready.

   Confirm public HTML, JS, JSON/data, image paths, and imports return HTTP 200
   and no obvious broken import/404 appears.

9. Keep authenticated QA and data-changing QA separate.

   Auth role matrix, session create/edit/delete, template save/apply, reset,
   membership approval, Discord sync, DB/RPC/RLS, and Edge Function checks must
   be separate explicit gates.

## Regulation Template Adoption

Use the regulation page as a world-template page, not an ops-core page.

Initial policy:

- do not make large HTML/CSS/renderer changes first
- keep section ids, anchors, CSS classes, and active TOC behavior stable while
  replacing data
- use `data/regulation.json` or the next-world equivalent for the main
  regulation shell
- use data modules under `assets/js/world/regulation/` for small isolated
  targets
- use synchronous imports for data modules
- do not introduce standalone JSON/fetch loading during the first adoption
  pass
- update cache-bust whenever renderer, HTML import chain, or regulation data
  query changes
- verify public `regulation.html`, `main.js`, `renderRegulation.js`, data
  module paths, and `data/regulation.json`
- check stale JSON / cache-mixing risks whenever a JSON key/block/item is moved
  to a module
- use target-scoped duplicate guards for nested moved blocks/items when needed
- rollback by restoring JSON ownership, removing imports/composition, updating
  cache-bust, and rechecking public delivery

Good first regulation data-module targets:

- short term cards
- short notes/callouts
- one subsection item
- one exact block
- table row data only

Avoid in first adoption:

- whole sections
- multiple sections
- long house rules
- magic-angel style special rulings
- full growth-rule clusters
- table columns
- `renderTable()`
- `renderBlock()`
- `renderDataSection()`
- CSS class changes
- DOM id changes
- anchor changes
- active TOC rewrites
- JSON/fetch migration

Detailed regulation procedure:

- `docs/world-template-regulation-data-module-adoption-guide.md`

## Reusable Ops Core Boundary

Reusable ops core is the operations-platform side.

World template is the world-site side.

Current reusable ops core candidates:

- `assets/js/core/config/`
- `assets/js/core/calendar/`
- `assets/js/core/session/`
- small display/config/helper modules already extracted there

Ops-leaning page areas:

- `calendar`
- `session-post`
- `session-detail`
- `mypage`
- membership management
- application/comment flows
- session templates
- Discord sync

World-site page areas:

- top / world
- characters
- spots
- scenarios/hooks
- terms
- regulation
- gallery
- campaigns / episodes

Boundary rules:

- regulation data modules are world template files, not reusable ops core
- ops core should not carry world-specific story text, NPC names, rule copy, or
  gallery assets
- world data should not carry auth decisions, DB/RPC identifiers, Discord
  payload keys, role keys, input names, CSS classes, DOM ids, raw ids, or secret
  values
- changing regulation must not require ops core changes
- changing ops core must not rewrite world copy or regulation meaning
- auth, membership, Discord sync, DB, RPC, and RLS remain separate gates

## File Placement Guide

Current and future placement should keep ownership visible.

### `assets/js/core/config/`

Use for reusable operations display/config entry points.

Good contents:

- reusable ops labels
- safe display fallbacks
- small config accessors

Do not put here:

- world story text
- regulation body copy
- DB/RPC names as configurable content
- role keys or permission logic
- raw ids, secrets, or tokens

### `assets/js/core/calendar/`

Use for reusable calendar rendering and display helpers.

Good contents:

- calendar renderer modules that are proven safe
- safe calendar labels through reusable ops config

Do not put here:

- regulation level-cap row data
- world-specific calendar prose
- auth or membership decision logic beyond already reviewed gates

### `assets/js/core/session/`

Use for reusable session display and form helpers.

Good contents:

- pure display formatters
- small HTML helpers
- session-post field helpers that preserve field contracts
- player-count display helpers

Do not put here:

- full session-post orchestration
- template RPC behavior
- Discord sync behavior
- payload key changes
- input name changes
- auth/role permission logic

### `assets/js/world/regulation/`

Use for regulation world-site data modules.

Good contents:

- one target data module per isolated regulation target
- short card arrays
- note/callout blocks
- subsection item modules
- table row arrays

Do not put here:

- reusable ops helpers
- auth, DB, Discord, or membership code
- broad renderer registries without a separate schema gate
- secrets or live operation values

### `data/`

Use for public static world data and config.

Good contents:

- site settings
- world content
- characters/spots/scenarios/terms/regulation/gallery data
- public calendar config if the ops surface is enabled

Do not put here:

- secrets
- Webhooks
- private IDs
- raw user/member/session records
- Supabase service credentials
- live operational exports

### `assets/data/`

The current Velgard site primarily uses `data/` for public JSON. If a future
world introduces `assets/data/`, define its ownership first.

Acceptable use only after a docs gate:

- generated static assets that must live with front-end assets
- non-secret build artifacts

Do not split public JSON between `data/` and `assets/data/` without a reason.

### `docs/`

Use for adoption plans, specs, QA records, rollback records, and status notes.

Good contents:

- procedures
- schema notes
- checklist results
- boolean/status-only public checks

Do not put here:

- secrets
- raw ids
- emails
- tokens
- JWT values
- Webhook URLs
- live member/session dumps

## Next-World Adoption Checklist

Before a next-world template is considered ready:

- no secrets, Webhooks, tokens, JWT values, raw user ids, emails, Discord IDs,
  or private Supabase values are present
- `updates.json` is not copied blindly
- world/site title, tagline, intro copy, and navigation have been reviewed
- `world`, `characters`, `spots`, `scenarios/hooks`, `terms`, `regulation`,
  and `gallery` data are either replaced or intentionally marked unused
- regulation data-module counts, order, titles, and body text are checked
- moved regulation data appears exactly once
- no `undefined`, `[object Object]`, empty card, empty row, or empty subsection
  appears in checked output
- no broken import, missing data module, 404, or fetch failure is observed
- cache-bust keys match the latest changed HTML/JS/data chain
- public HTML pages return HTTP 200
- public JS renderer paths return HTTP 200
- public JSON/data paths parse where applicable
- image and gallery asset paths are checked
- auth, DB, membership, and Discord are either configured through a separate
  gate or explicitly recorded as `not_configured` / `not_tested`
- `limited` is used for partial visual or DOM checks
- `not_tested` is used for unauthenticated, data-changing, DB/RPC/RLS, Edge,
  Discord, or unrelated-page scopes that were not covered
- docs record what was reused, replaced, deferred, and prohibited

## Rollback And Recovery

If next-world template adoption breaks rendering or ownership:

1. Stop broadening the change.
2. Identify whether the problem is world data, data module import, renderer
   composition, cache-bust, CSS, asset path, or ops connection.
3. For a data-module issue, restore the target JSON key/block/item.
4. Remove the matching data-module import and composition code.
5. Update cache-bust so public delivery cannot keep the broken chain.
6. Re-run local static checks.
7. Re-run public HTTP 200 and DOM checks.
8. Record the reason and recovery result in docs.

Do not recover by touching:

- SQL
- DB/RPC/RLS
- Edge Functions
- Discord production posting or Webhooks
- secrets
- auth/permission logic
- raw ids, emails, tokens, or JWT values

When in doubt, rollback to the last known static world-site state and open a
separate plan for the risky integration.

## Next Candidate Options

Candidate A: detail the world-template adoption checklist.

- Expand this guide into page-by-page checklists for top, world, characters,
  spots, scenarios/hooks, terms, regulation, gallery, and campaigns.

Candidate B: draft a regulation sample data composition.

- Show the minimum next-world regulation data shape, data-module examples, and
  which current Velgard modules are optional.

Candidate C: document characters / spots / terms template structures.

- Record required-looking fields, optional fields, relation ids, image policy,
  and status/category handling for next-world data authors.

Candidate D: document gallery / image asset boundaries.

- Separate reusable gallery behavior from world-specific image categories,
  image paths, captions, generated assets, and OGP/key-visual assets.

Candidate E: separate ops core adoption steps.

- Document when and how to enable calendar, session-post, session-detail,
  mypage, auth, membership, DB/RPC/RLS, and Discord sync for a new world.

Candidate F: create pre-auth / pre-DB / pre-Discord checklist.

- Define stop conditions and status-only records before any live operational
  integration.

Recommended next candidate:

- Candidate B: draft a regulation sample data composition.

Reason:

- Regulation now has the strongest documented template path.
- A concrete sample composition would help the next world start without copying
  Velgard rule text.
- It can remain docs-only and avoid auth, DB, Discord, CSS, and renderer risk.
- Characters/spots/terms can follow after the regulation sample demonstrates
  the expected level of detail.

## Limited And Not Tested

This guide is docs-only and does not add new runtime QA.

Limited:

- visual design suitability for a second world
- full desktop/mobile review
- active TOC scroll-through behavior
- complete gallery/image path review

Not tested:

- actual next-world site rendering
- authenticated flows
- membership approval and role matrix
- session create/edit/delete
- template save/apply
- DB/RPC/RLS
- Edge Functions
- Discord sync
- data-changing workflows

## No Dangerous Work

This guide did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge deploy, Discord operation, secret/Webhook change, direct
Supabase write, debug console logging addition, `updates.json` change,
auth/permission logic change, RPC/DB key configuration, `management_key`
display, or raw id/email/token/JWT display.
