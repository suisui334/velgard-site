# World Gallery Image Assets Guide

Date: 2026-06-17

Phase: 3-C4 gallery / image asset boundary guide.

Baseline commit: `a5af636 Plan scalable world content templates`

This is a docs-only guide. It does not include implementation, HTML, CSS, JS,
JSON/data, image file, renderer, OGP, favicon, hero image, `updates.json`, SQL,
DB/RPC/RLS, Edge Function, Discord, Supabase direct write, console logging,
auth, or secret changes.

## Purpose

Gallery and image assets are easy to over-copy when a second world is created
from the Velgard public site.

This guide separates:

- reusable gallery and image-display structure
- world-specific assets and image metadata
- careful-gate assets such as OGP, favicon, hero, map, and shared images
- assets and URLs that must not be copied

The goal is to let a next world launch even when images are missing or sparse,
without copying Velgard-specific images or mixing image ownership into reusable
ops core.

## Observed Velgard Inventory

The current Velgard site uses these gallery and image surfaces:

- page: `gallery.html`
- renderer: `assets/js/renderGallery.js`
- shared image helpers: `imageOrPlaceholder()` and `imageFallbackAttr()` in
  `assets/js/dataLoader.js`
- gallery data: `data/gallery.json`
- site-level image settings: `data/site.json`
- image-bearing world data:
  - `data/characters.json`
  - `data/spots.json`
  - `data/spotDetails.json`
  - `data/world.json`
  - `data/hooks.json`
  - `data/scenarios.json`
  - `data/campaigns.json`
  - `data/episodes.json`
- image directories:
  - `assets/images/common/`
  - `assets/images/characters/`
  - `assets/images/facilities/`
  - `assets/images/gallery/`
  - `assets/images/hooks/`
  - `assets/images/keyvisual/`
  - `assets/images/locations/`
  - `assets/images/maps/`
  - `assets/images/spots/`

Current `data/gallery.json` is a list-style gallery dataset with 41 images:

- `key-visual`: 2
- `locations`: 14
- `facilities`: 9
- `scenarios`: 7
- `maps`: 9

Current `data/site.json` owns:

- `keyvisual`
- `logoImage`
- `theme.backgroundImage`
- placeholders for `keyvisual`, `spot`, `character`, `hook`, and `gallery`
- `meta.ogImage`
- `meta.favicon`
- `meta.faviconLarge`
- `meta.appleTouchIcon`

This inventory is a current-state reference only. It is not a rule that the
next world must use the same categories, counts, names, or assets.

## Asset Classification

### A. Reusable Template Structure

These can be reused as structure:

- `gallery.html` as a thin page shell with `#app`
- gallery card grid structure
- category filter, search input, and count display pattern
- thumbnail-to-modal flow
- modal dialog, previous/next navigation, keyboard navigation, and swipe
  pattern
- data-driven gallery item shape with id, category, title, image, and
  description-like text
- related-id pattern where spots can reference gallery item ids
- character, spot, scenario, and gallery renderers using shared image fallback
  helpers
- placeholder lookup via `site.placeholders`
- CSS responsibility for image ratios, grids, modals, and responsive behavior

Reuse these as behavior and structure. Do not treat Velgard's concrete image
paths or categories as reusable content.

### B. Replace Per World

These should be replaced or re-authored for each world:

- character portraits and standees
- top key visual
- logo and banners
- background image
- map images
- spot and facility images
- gallery images
- world-specific icons
- race, NPC, faction, place, and artifact images
- gallery captions and descriptions
- image categories and category labels
- image filenames and directory naming conventions
- OGP image content, after a separate public-sharing check

If an image names, depicts, or implies Velgard lore, it is world-specific even
when the layout around it is reusable.

### C. Careful-Gate Assets

These should not be casually copied or changed in the same pass as content
data:

- CSS background images
- favicon files
- OGP images
- top-page hero / key visual assets
- map images
- images shared by gallery and spot-detail pages
- placeholder images
- image paths that are strongly coupled to data ids
- `gallery-hook-*` compatibility ids and hook/scenario image paths
- file moves that require cache-bust or renderer updates
- external image URLs

Handle these behind a small explicit gate with path checks and public HTTP
checks.

### D. Do Not Copy

Do not copy these into another world:

- Velgard-specific NPC images
- Velgard-specific backgrounds, maps, spot images, facility images, and gallery
  images
- assets that are rights-specific, generated for a different setting, or
  content-specific to Velgard
- non-public production materials
- personal information or hidden campaign information embedded in images
- Discord-sourced or external-service-sourced images without rights and
  stability review
- image data containing secret, token, JWT, private URL, raw user id, email,
  Discord ID/URL, Webhook URL, or actual `management_key` values

## Data-Side Fields

Image-bearing data may use fields like:

- `image`
- `thumbnail`
- `alt`
- `caption`
- `credit`
- `category`
- `tags`
- `relatedCharacter`
- `relatedSpot`
- `relatedScenario`
- `relatedGalleryIds`
- `mapGalleryIds`
- `relatedFacilityGalleryIds`
- `isPlaceholder`
- `visibility`

Recommended data-side responsibilities:

- identify the image path or omit it
- provide world-specific title/caption/description text
- provide alt text when the visible title is not enough
- store credit or rights notes when they must be displayed or audited
- store relation ids between gallery, characters, spots, and scenarios
- mark placeholder or draft images clearly when needed
- keep publication state explicit if a future world has private or draft images

Data should not own CSS classes, DOM ids, active navigation state, modal
behavior, layout breakpoints, or JS hooks.

## Renderer And CSS Responsibilities

Renderer and CSS should continue to own:

- image card markup
- gallery grid layout
- optional masonry or carousel behavior if introduced later
- modal / lightbox UI
- focus, keyboard, swipe, and close behavior
- fallback image rendering
- alt fallback when a data-specific alt is absent
- broken image handling
- image size, crop, ratio, and object-fit rules
- lazy loading policy if introduced
- CSS classes, DOM ids, data attributes, and JS hooks
- empty-state rendering for zero visible images

Changing gallery category configuration, modal behavior, image ratios, or
fallback policy is a renderer/CSS gate. It should not be bundled with a
world-specific image data swap.

## Next-World Image Introduction Order

Use this order when preparing a next world:

1. Make the site work with no new images.
2. Confirm characters, spots, and gallery can render with missing images or
   placeholders.
3. Add only the primary site identity images: logo, key visual, and background,
   if ready.
4. Connect a small number of character, spot, and gallery image paths.
5. Check broken image icons and HTTP 404s.
6. Add alt, caption, and credit policy for every public image type.
7. Expand gallery categories gradually.
8. Treat OGP, favicon, hero image, and large map images as separate gates.
9. Run public HTTP 200 checks before treating image rollout as complete.

Do not block an early next-world site on a full gallery. Sparse image coverage
is acceptable if missing-image behavior is deliberate.

## Missing Image Policy

For a next world, these states should be valid:

- gallery has zero records
- characters have no portraits
- spots have no images
- map images are not ready
- gallery category has one or zero visible entries
- caption, credit, tags, and relations are absent

Recommended behavior:

- if `image` is missing, use a neutral placeholder or an image-free card layout
- if a placeholder is used, keep it generic and world-neutral
- if `alt` is missing, fall back to visible title/name when appropriate
- if `caption` is missing, hide the caption area
- if `credit` is missing, hide the credit area unless a rights gate requires it
- if category/tag is missing, show no filter chip or use a neutral category only
  when that is already a template convention
- if gallery has zero visible items, show an empty state rather than broken grid
  spacing
- if spot detail relation ids are missing, hide related image sections

Do not render broken image icons, `undefined`, `[object Object]`, empty cards,
or empty modal shells as public content.

## Reusable Ops Core Boundary

Gallery and image assets are world-template content.

They do not belong in reusable ops core.

Boundary rules:

- keep gallery, world images, character images, spot images, maps, OGP, favicon,
  logo, and placeholders outside `assets/js/core/`
- do not couple image data to calendar, session-post, session-detail, mypage,
  membership, Discord sync, DB, or RPC ownership
- session-post or session-detail may link to world images later, but world
  template owns the image assets and metadata
- do not store secret, token, JWT, Webhook URL, private URL, raw user id, email,
  Discord ID/URL, or actual `management_key` values in image data
- external image URLs need a separate rights, stability, performance, and
  privacy check
- user-uploaded avatars and profile images are ops/user-data concerns, not
  gallery template assets

## Introduction Checklist

Before publishing image data for a next world:

- image paths referenced by data exist
- public image URLs return HTTP 200 where applicable
- no broken image icon or 404 is visible in public pages
- `alt` is present or a renderer fallback is documented
- caption and credit policy is decided
- Velgard-specific images are not reused
- image filenames match the next world and do not leak private notes
- OGP, favicon, logo, background, and hero images are reviewed separately
- gallery with zero records does not break
- characters and spots without images do not break
- gallery category/filter UI works with zero, one, or many categories
- shared gallery/spot-detail image ids resolve or hidden sections stay hidden
- no secret, token, JWT, private URL, raw id, email, Discord URL/ID, Webhook, or
  actual `management_key` value is stored in data or docs
- public HTML, JS, JSON/data, and image paths return HTTP 200
- any incomplete visual pass is recorded as `limited`
- auth, DB/RPC/RLS, Edge, Discord, and data-changing workflows are recorded as
  `not_tested` unless a separate explicit gate covers them

## Rollback And Recovery

If image introduction fails:

1. Remove or revert the affected image references from data.
2. Restore previous JSON/data entries if they were changed.
3. Stop using added image files until rights/path/display issues are resolved.
4. Return to placeholder or image-free rendering.
5. Revert renderer/CSS changes if a separate gate changed them.
6. Update cache-bust if public stale assets could remain.
7. Re-run public checks for HTML, JS, JSON/data, and image HTTP 200 status.
8. Record the rollback reason in docs.
9. Do not use secret, DB, Discord, auth, or live data changes as a workaround.

## Next Candidate Options

Candidate A: scenarios / hooks template structure.

- Decide whether the next world should expose `scenarios`, `hooks`, or both.
- Record field ownership, image policy, gallery id compatibility, and display
  states without moving assets or changing renderers.

Candidate B: page-by-page world-template adoption checklist.

- Turn top, world, characters, spots, scenarios, terms, regulation, gallery,
  campaigns, and tools readiness into a launch checklist.

Candidate C: OGP / favicon / hero image gate.

- Document a separate public-sharing and cache-bust procedure for site identity
  images.

Candidate D: pre-auth / pre-DB / pre-Discord checklist.

- Define stop conditions before connecting operational surfaces.

Recommended next candidate:

- Candidate A: scenarios / hooks template structure.

Reason:

- gallery currently includes scenario/hook images and compatibility ids
- scenarios/hooks sit between world content and ops-facing session ideas
- a docs-only structure plan can clarify ownership before any renderer,
  category, image-path, DB, Discord, or auth work

## Phase 3-C6 Page Adoption Checklist Follow-Up

Phase 3-C6 adds the page-by-page adoption checklist:

- `docs/world-template-page-adoption-checklist.md`

Gallery/image impact:

- gallery is classified as a world-template page
- index, world, characters, spots, scenarios/hooks, campaigns/episodes, and
  gallery all keep image ownership on the world-template side
- OGP, favicon, hero, map, and shared gallery/spot images remain careful-gate
  assets
- reusable ops pages may link to world images later, but do not own gallery
  assets
- page adoption now requires broken-image / 404 / fallback checks before public
  launch

Recommended next docs-only candidate after C6:

- campaigns / episodes template structure.

## Limited And Not Tested

This guide is docs-only and does not add runtime QA.

Limited:

- current image inventory review was static
- no desktop/mobile visual inspection was performed in this phase
- no public image HTTP sweep was performed in this phase
- CSS image-ratio behavior was identified as a boundary, not verified visually

Not tested:

- public next-world rendering
- gallery zero-state rendering in a live browser
- all broken-image fallback paths
- OGP rendering in Discord or external previews
- authenticated flows
- DB/RPC/RLS
- Edge Functions
- Discord sync
- user-uploaded avatar flows
- data-changing workflows

## No Dangerous Work

This guide did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge deploy, Discord operation, secret/Webhook change, direct
Supabase write, debug console logging addition, `updates.json` change,
auth/permission logic change, RPC/DB key configuration, `management_key`
display, raw id/email/token/JWT display, image addition, image deletion, image
rename, HTML change, CSS change, JS change, JSON/data change, or renderer
change.
