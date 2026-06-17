# World Template Page Adoption Checklist

Date: 2026-06-17

Phase: 3-C6 page-by-page world-template adoption checklist.

Baseline commit: `a6316a0 Plan scenarios hooks template structures`

This is a docs-only checklist. It does not include implementation, HTML, CSS,
JS, JSON/data, image file, sample data, renderer, world copy, scenario/hook
data, gallery change, ops-core change, `updates.json`, SQL, DB/RPC/RLS, Edge
Function, Discord, Supabase direct write, console logging, auth, membership, or
secret changes.

## Purpose

Phase 3-C1 through C5 documented the next-world adoption path, regulation
sample data, scalable content structures, gallery/image boundaries, and
scenarios/hooks structures.

This checklist turns those plans into a page-by-page adoption guide for a
future world.

Use it to decide:

- which pages can be reused as world-template pages
- which pages are reusable-ops surfaces and require a separate setup gate
- which pages are auxiliary/common and optional
- which values or assets must never be copied into a new world

## Current HTML Inventory

Current root HTML pages:

- `admin-cap-announcements.html`
- `calendar.html`
- `campaign-detail.html`
- `campaigns.html`
- `characters.html`
- `episode-detail.html`
- `gallery.html`
- `hooks.html`
- `index.html`
- `mypage.html`
- `regulation.html`
- `scenario-detail.html`
- `scenarios.html`
- `session-detail.html`
- `session-post.html`
- `spot-detail.html`
- `spots.html`
- `terms.html`
- `timeline.html`
- `tools.html`
- `updates.html`
- `world.html`

Current `main.js` page keys:

- `home`
- `world`
- `campaigns`
- `campaign-detail`
- `episode-detail`
- `regulation`
- `spots`
- `spot-detail`
- `characters`
- `hooks`
- `scenarios`
- `scenario-detail`
- `session-detail`
- `session-post`
- `terms`
- `gallery`
- `updates`
- `tools`
- `calendar`
- `timeline`
- `mypage`
- `admin-cap-announcements`

This inventory is a current Velgard reference. A next world does not need every
page at launch.

## Page Classification

### A. World-Template Pages

These are primarily world-site pages. Reuse the skeleton and renderer patterns,
but replace world-specific data, copy, names, and assets:

- `index.html`
- `world.html`
- `characters.html`
- `spots.html`
- `spot-detail.html`
- `terms.html`
- `scenarios.html`
- `hooks.html`
- `scenario-detail.html`
- `regulation.html`
- `gallery.html`
- `campaigns.html`
- `campaign-detail.html`
- `episode-detail.html`

General rule:

- reuse page skeletons and card/detail patterns
- replace data, prose, images, categories, tags, names, and world-specific ids
- keep renderers and CSS unchanged in the first adoption pass
- move renderer/CSS changes to separate gates

### B. Reusable Ops Core Pages

These are operational surfaces. They should be optional for a next world and
enabled only after separate setup and QA:

- `calendar.html`
- `session-post.html`
- `session-detail.html`
- `mypage.html`
- `timeline.html`
- `admin-cap-announcements.html`

General rule:

- these are close to auth, membership, DB/RPC/RLS, Discord sync, session data,
  comments, applications, or admin operations
- world content can link to them, but does not own their data
- the world-template site should still work when these are disabled or hidden

### C. Auxiliary / Common Pages

These are optional support pages:

- `tools.html`
- `updates.html`

General rule:

- use only when the next world needs them
- `tools` may be world-specific play support or reusable utility
- `updates` must not blindly reuse Velgard `updates.json`

### D. Do Not Copy / Careful Global Values

Never copy these into a next world:

- secrets
- tokens
- JWT values
- Webhook URLs
- raw user ids
- emails
- Discord IDs or URLs
- actual `management_key` values
- Supabase project-specific private configuration
- live member data
- live session operation data
- Velgard-specific images
- Velgard-specific scenario secrets or unreleased GM notes
- Velgard-specific public values that should not become default next-world
  content

## Page Checklist Matrix

### `index.html`

Page type:

- world-template

Ownership boundary:

- world-template owns site identity, hero copy, and public navigation
- reusable ops owns approved-gated links and operational surfaces

Reusable structure:

- thin HTML shell with `data-page="home"`
- shared header/footer mount points
- top hero, logo/key visual modal, and main navigation cards
- recent activity / updates style surface if adopted

Replace per world:

- site title and short title
- tagline and lead text
- hero/key visual image
- logo
- background image
- home navigation labels and destinations
- OGP/favicons/title metadata
- world-specific copy

Dangerous surfaces:

- `renderHome.js` hard-coded `homeNavItems`
- approved-gated navigation behavior inherited from `main.js`
- OGP/favicons/hero image changes
- `data/site.json` public URL or meta fields

Related data/json:

- `data/site.json`
- optional activity data through operational surfaces if enabled

Related JS:

- `assets/js/renderHome.js`
- `assets/js/main.js`

Related CSS/assets:

- `assets/css/style.css`
- `assets/images/common/`

Cache-bust target:

- `index.html` main-module query
- `assets/js/main.js`
- `assets/js/renderHome.js`
- CSS and image assets when changed behind a separate gate

Minimum next-world check:

- page HTTP 200
- title/heading/site name replaced
- Velgard copy and image paths removed or intentionally marked placeholder
- no broken hero/logo image
- no gated ops link required for initial world browsing

Rollback:

- restore previous `data/site.json` and hero/logo references
- restore `renderHome.js` nav changes if any
- update cache-bust and re-check public page

### `world.html`

Page type:

- world-template

Ownership boundary:

- world-template owns world prose, sections, images, and anchors

Reusable structure:

- sectioned long-form world guide
- page title/lead
- optional table of contents and subsections

Replace per world:

- all world prose
- geography, history, factions, culture, species, religion, technology
- section ids and titles
- images or diagrams

Dangerous surfaces:

- anchor ids used by links
- long prose changes bundled with renderer/CSS changes
- images that are not rights-cleared for the next world

Related data/json:

- `data/world.json`

Related JS:

- `assets/js/renderWorld.js`

Related CSS/assets:

- `assets/css/style.css`
- image paths referenced from world data

Cache-bust target:

- `world.html`
- `assets/js/main.js`
- `assets/js/renderWorld.js`
- `data/world.json` fetch query if changed

Minimum next-world check:

- page HTTP 200
- headings and sections match the new world
- no Velgard place/faction/lore remains
- missing images do not break layout
- anchors resolve

Rollback:

- restore previous world data
- remove new image references
- update cache-bust and re-check public page

### `characters.html`

Page type:

- world-template

Ownership boundary:

- world-template owns public NPC/character data
- ops/user profile data is not owned here

Reusable structure:

- scalable card/list page
- optional filters
- image modal
- related spot links

Replace per world:

- NPC names, roles, races, affiliations, regions, summaries, descriptions
- images and thumbnails
- categories/tags/faction labels
- relation ids

Dangerous surfaces:

- `official === true` behavior
- filters that assume Velgard regions
- portrait images and rights
- relation ids pointing to missing spots

Related data/json:

- `data/characters.json`
- `data/spots.json`

Related JS:

- `assets/js/renderCharacters.js`

Related CSS/assets:

- `assets/css/style.css`
- `assets/images/characters/`
- character placeholder in `data/site.json`

Cache-bust target:

- `characters.html`
- `assets/js/main.js`
- `assets/js/renderCharacters.js`
- changed data/image assets behind their own gate

Minimum next-world check:

- 0 records, few records, and larger lists are valid states
- missing images use fallback or image-free layout
- no Velgard NPC names remain
- filters do not render broken options
- related links resolve or hide

Rollback:

- restore character data and image paths
- remove broken relation ids
- update cache-bust and re-check public page

### `spots.html` / `spot-detail.html`

Page type:

- world-template

Ownership boundary:

- world-template owns public spot/facility/map data
- calendar/session-detail may link later but do not own spot data

Reusable structure:

- spot card list
- category filters
- detail page
- maps, related gallery, related NPC/scenario/term links

Replace per world:

- places, regions, facilities, maps, summaries, descriptions
- images and map gallery ids
- related characters/scenarios/terms
- categories and organization labels

Dangerous surfaces:

- missing detail records for visible spots
- relation ids pointing to missing characters, scenarios, terms, or gallery
  images
- map images and gallery shared ids
- `relatedScenarioIds` should not imply live sessions

Related data/json:

- `data/spots.json`
- `data/spotDetails.json`
- `data/gallery.json`
- `data/characters.json`
- `data/scenarios.json`
- `data/terms.json`

Related JS:

- `assets/js/renderSpots.js`
- `assets/js/renderSpotDetail.js`

Related CSS/assets:

- `assets/css/style.css`
- `assets/images/locations/`
- `assets/images/facilities/`
- `assets/images/maps/`
- spot/gallery placeholders in `data/site.json`

Cache-bust target:

- `spots.html`
- `spot-detail.html`
- `assets/js/main.js`
- `assets/js/renderSpots.js`
- `assets/js/renderSpotDetail.js`
- changed data/image assets behind their own gate

Minimum next-world check:

- list page HTTP 200
- detail route with a valid id works
- invalid/missing id shows a safe not-found state
- maps and gallery images either resolve or sections hide
- no Velgard place names or maps remain

Rollback:

- restore spots/detail data
- remove broken relation ids and image paths
- update cache-bust and re-check list/detail pages

### `terms.html`

Page type:

- world-template

Ownership boundary:

- world-template owns public dictionary terms

Reusable structure:

- term list/dictionary
- categories
- search/filter
- term anchors
- related spot/character links

Replace per world:

- terms, readings, categories, summaries, related ids
- world-specific terminology

Dangerous surfaces:

- anchor ids used by external links
- categories hard-coded by current data assumptions
- related ids pointing to missing records

Related data/json:

- `data/terms.json`
- related spot/character data when linked

Related JS:

- `assets/js/renderTerms.js`

Related CSS/assets:

- `assets/css/style.css`

Cache-bust target:

- `terms.html`
- `assets/js/main.js`
- `assets/js/renderTerms.js`
- `data/terms.json` fetch query if changed

Minimum next-world check:

- 0/few/many terms do not break layout
- search/filter behaves with one or many categories
- anchors resolve
- no Velgard-specific terms remain unless intentionally re-authored

Rollback:

- restore terms data
- remove broken relation ids
- update cache-bust and re-check page

### `scenarios.html` / `hooks.html` / `scenario-detail.html`

Page type:

- world-template

Ownership boundary:

- world-template owns public hooks and scenario proposals
- live session recruitment remains ops-owned

Reusable structure:

- scenario/hook cards
- category filter
- image modal
- detail page
- release status display
- public TXT/PDF release link structure when explicitly used

Replace per world:

- scenario/hook names, public premises, categories, genres, images
- related spots/NPCs/terms
- release files and metadata

Dangerous surfaces:

- `hooks.html` compatibility route
- `data/hooks.json` versus active `data/scenarios.json`
- GM-secret or spoiler content in public GitHub Pages data
- `textUrl` / `pdfUrl` public file paths
- relation ids pointing to missing records
- confusion with `session-post` and `session-detail`

Related data/json:

- `data/scenarios.json`
- `data/hooks.json`
- `data/spots.json`
- `data/characters.json`
- image/gallery data when linked

Related JS:

- `assets/js/renderScenarios.js`
- `assets/js/renderScenarioDetail.js`
- `assets/js/main.js`

Related CSS/assets:

- `assets/css/style.css`
- `assets/images/hooks/`
- hook placeholder in `data/site.json`

Cache-bust target:

- `scenarios.html`
- `hooks.html`
- `scenario-detail.html`
- `assets/js/main.js`
- `assets/js/renderScenarios.js`
- `assets/js/renderScenarioDetail.js`
- changed data/release files/images behind their own gate

Minimum next-world check:

- public-safe info only
- GM-secret info is not in public data
- hooks/scenarios compatibility decision is recorded
- 0 visible records have an empty state
- detail id works or not-found is safe
- no Velgard scenario premises or images remain

Rollback:

- restore scenarios/hooks data
- remove release file links
- remove broken relation ids
- update cache-bust and re-check list/detail pages

### `regulation.html`

Page type:

- world-template

Ownership boundary:

- world-template owns rules, regulation prose, sample data, and data modules
- reusable ops may link to it but does not own its data

Reusable structure:

- long-form regulation page
- active TOC / anchors
- sections and block renderer
- tables, lists, callouts, details
- data module pattern for small isolated public data

Replace per world:

- all regulation prose and rule meanings
- level caps, rewards, honor/Sword Shard guidance, growth rules
- term cards, note cards, callouts, special rulings
- data modules under `assets/js/world/regulation/`

Dangerous surfaces:

- active TOC
- anchors and DOM ids
- CSS class names
- `renderBlock()`, `renderDataSection()`, `renderTable()`
- column definitions
- stale JSON/cache mixing after data-module moves
- calendar-side `levelCaps` should not be unified casually

Related data/json:

- `data/regulation.json`
- `assets/js/world/regulation/*Data.js`

Related JS:

- `assets/js/renderRegulation.js`
- `assets/js/main.js`

Related CSS/assets:

- `assets/css/style.css`

Cache-bust target:

- `regulation.html`
- `assets/js/main.js`
- `assets/js/renderRegulation.js`
- data module import chain
- `data/regulation.json` fetch query

Minimum next-world check:

- page HTTP 200
- cache-bust chain is consistent
- no broken data module import
- public DOM has expected counts/order for moved targets
- no `undefined`, `[object Object]`, duplicate moved blocks, or missing blocks
- active TOC/anchors remain stable

Rollback:

- remove data-module import
- restore JSON key/block/item
- remove composition helper
- update cache-bust
- re-run local and public checks

### `gallery.html`

Page type:

- world-template

Ownership boundary:

- world-template owns gallery metadata and images
- ops/user-uploaded avatars are not gallery assets

Reusable structure:

- gallery grid
- filter/search
- modal with previous/next and swipe
- image fallback
- relation ids from spots/gallery

Replace per world:

- gallery images, captions/descriptions, categories, credits, alt policy
- key visual, maps, location/facility images, scenario images
- OGP/favicons/hero assets behind separate gates

Dangerous surfaces:

- Velgard images copied into a new world
- `categoryLabels` / `categoryOrder` hard-coded in `renderGallery.js`
- gallery ids referenced by spot details
- broken image paths
- rights-unclear external images

Related data/json:

- `data/gallery.json`
- `data/site.json`
- spot detail gallery ids

Related JS:

- `assets/js/renderGallery.js`

Related CSS/assets:

- `assets/css/style.css`
- `assets/images/`

Cache-bust target:

- `gallery.html`
- `assets/js/main.js`
- `assets/js/renderGallery.js`
- changed data/image assets behind their own gate

Minimum next-world check:

- gallery can be empty without broken UI
- every referenced image path exists
- alt/caption/credit policy is recorded
- no Velgard-specific images remain
- no broken modal image

Rollback:

- restore gallery data/image refs
- return to placeholders or image-free layout
- update cache-bust and re-check public page

### `campaigns.html` / `campaign-detail.html` / `episode-detail.html`

Page type:

- world-template optional

Ownership boundary:

- world-template owns public campaign/episode articles
- live session history remains ops-owned if introduced later

Reusable structure:

- campaign list
- campaign detail
- episode detail
- related spot/NPC links
- optional episode images

Replace per world:

- campaign names, episode titles, summaries, logs, images, related ids
- public story recap text

Dangerous surfaces:

- mixing public campaign recap with private session notes
- relation ids pointing to missing spots/characters
- implying live session scheduling state from story entries

Related data/json:

- `data/campaigns.json`
- `data/episodes.json`
- `data/spots.json`
- `data/characters.json`

Related JS:

- `assets/js/renderCampaigns.js`
- `assets/js/renderCampaignDetail.js`
- `assets/js/renderEpisodeDetail.js`

Related CSS/assets:

- `assets/css/style.css`
- gallery/episode images if used

Cache-bust target:

- `campaigns.html`
- `campaign-detail.html`
- `episode-detail.html`
- `assets/js/main.js`
- campaign/episode renderers
- changed data/images behind their own gate

Minimum next-world check:

- optional pages can be hidden or empty
- no private session log leaks
- relation links resolve or hide
- images resolve or fallback

Rollback:

- restore campaign/episode data
- remove broken relation ids/image refs
- update cache-bust and re-check pages

### `tools.html`

Page type:

- auxiliary / common

Ownership boundary:

- auxiliary world/play support
- not core world lore and not live ops

Reusable structure:

- random table selector
- roll result
- copy buttons
- local history via `localStorage`

Replace per world:

- random tables and result text
- labels if the tool is world-specific

Dangerous surfaces:

- localStorage key compatibility
- copy behavior
- tables that include private GM-only entries
- treating tools as ops-core without a separate decision

Related data/json:

- `data/randomTables.json`

Related JS:

- `assets/js/renderTools.js`

Related CSS/assets:

- `assets/css/style.css`

Cache-bust target:

- `tools.html`
- `assets/js/main.js`
- `assets/js/renderTools.js`
- `data/randomTables.json` fetch query if changed

Minimum next-world check:

- page can be disabled if not needed
- visible tables contain public-safe text
- roll/copy works if enabled
- no `undefined` result text

Rollback:

- restore random table data
- clear/ignore localStorage if needed
- update cache-bust and re-check page

### `updates.html`

Page type:

- auxiliary / common

Ownership boundary:

- public site update history
- not reusable ops core and not live activity timeline

Reusable structure:

- update cards sorted by date
- tags and target labels
- empty state

Replace per world:

- every update entry
- dates and target labels
- title/description copy

Dangerous surfaces:

- blindly copying `updates.json`
- using old Velgard release history as next-world history
- confusing static update history with `timeline`

Related data/json:

- `data/updates.json`

Related JS:

- `assets/js/renderUpdates.js`

Related CSS/assets:

- `assets/css/style.css`

Cache-bust target:

- `updates.html`
- `assets/js/main.js`
- `assets/js/renderUpdates.js`
- `data/updates.json` fetch path if changed

Minimum next-world check:

- page HTTP 200 if enabled
- update entries are next-world-specific
- no stale Velgard dates/history unless intentionally retained as migration
  notes
- empty updates list is valid

Rollback:

- restore update data
- update cache-bust and re-check public page

### `calendar.html`

Page type:

- reusable ops core

Ownership boundary:

- ops owns calendar rendering and session schedule display
- world-template may link to calendar but does not own session operations

Reusable structure:

- calendar renderer under `assets/js/core/calendar/`
- safe label config through reusable ops config
- session summaries and selected date panels

Replace or configure per world:

- `calendarConfig.json` if calendar is enabled
- session data source
- public/private gate policy
- labels only behind reusable ops gates

Dangerous surfaces:

- auth/approved gate
- session data
- DB/RPC-backed session merging
- calendar-side `levelCaps`
- accidental unification with regulation `levelCaps`
- Discord or notification adjacency

Related data/json:

- `data/calendarConfig.json`
- `data/sessions.json`

Related JS:

- `assets/js/core/calendar/renderCalendar.js`
- `assets/js/sessionData.js`
- `assets/js/sessionDisplay.js`
- membership access modules

Related CSS/assets:

- `assets/css/style.css`

Cache-bust target:

- `calendar.html`
- `assets/js/main.js`
- `assets/js/core/calendar/renderCalendar.js`
- relevant core config/helper modules

Minimum next-world check:

- only enable if ops surface is wanted
- unauthenticated/unapproved state is documented
- static config/data parse
- no session data from Velgard copied blindly
- regulation `levelCaps` not merged without a separate gate

Rollback:

- disable nav link or page
- restore calendar config/session data
- update cache-bust and re-check public page

### `session-post.html`

Page type:

- reusable ops core

Ownership boundary:

- ops owns live session posting, editing, templates, payloads, auth, DB/RPC,
  and Discord-adjacent controls

Reusable structure:

- page shell and form layout
- small field helpers under `assets/js/core/session/`
- player-count helper/labels

Replace or configure per world:

- only after deciding to enable live ops
- labels/config behind ops gates
- runtime config and DB/RPC setup behind separate approvals

Dangerous surfaces:

- create/update/delete operations
- Supabase direct writes or RPCs
- auth/approved/owner/admin logic
- Discord mention/sync options
- template save/apply
- input names and payload keys

Related data/json:

- static `data/sessions.json` may be read as fallback/managed context
- DB/RPC data when enabled

Related JS:

- `assets/js/renderSessionPost.js`
- `assets/js/core/session/sessionFormHelpers.js`
- `assets/js/core/config/reusableOpsConfig.js`
- Supabase/browser/access clients

Related CSS/assets:

- `assets/css/style.css`

Cache-bust target:

- `session-post.html`
- `assets/js/main.js`
- `assets/js/renderSessionPost.js`
- core session/config helpers

Minimum next-world check:

- leave disabled or gated until ops setup is approved
- no live DB/Discord operations without explicit gate
- no field names/payload keys changed casually
- data-changing QA is separate

Rollback:

- disable nav link/page
- restore renderer/helper/config changes
- do not rollback through DB/Discord shortcuts
- update cache-bust and re-check page state

### `session-detail.html`

Page type:

- reusable ops core

Ownership boundary:

- ops owns live session detail, applications, comments, owner/admin controls,
  and Discord sync panel

Reusable structure:

- session detail page shell
- session display helpers
- detail row/tag/summary helpers

Replace or configure per world:

- only after deciding to enable live session operations
- static session data, if used, must be next-world-specific
- role/approval behavior behind ops gates

Dangerous surfaces:

- application/comment flows
- GM/admin controls
- edit/delete/close buttons
- Discord sync panel
- raw IDs and management keys
- auth/membership logic

Related data/json:

- `data/sessions.json`
- DB/RPC data when enabled

Related JS:

- `assets/js/renderSessionDetail.js`
- `assets/js/sessionDisplay.js`
- `assets/js/sessionData.js`
- `assets/js/core/session/*`
- Supabase/browser/comment/application clients

Related CSS/assets:

- `assets/css/style.css`

Cache-bust target:

- `session-detail.html`
- `assets/js/main.js`
- `assets/js/renderSessionDetail.js`
- session display/helper modules

Minimum next-world check:

- page may remain disabled until ops is enabled
- static detail id works only with next-world-safe sessions
- no raw ids/email/token/JWT/management key exposure
- no data-changing QA without explicit gate

Rollback:

- disable nav/link or restore static fallback
- restore session data or renderer changes
- update cache-bust and re-check public page

### `mypage.html`

Page type:

- reusable ops core

Ownership boundary:

- ops owns auth, membership, profile, templates, and account UI

Reusable structure:

- account page shell
- membership and profile panels
- label bridge through current normal-script boundary

Replace or configure per world:

- only after deciding to enable auth/membership
- runtime config and auth provider setup behind separate gates
- labels/config behind ops gates

Dangerous surfaces:

- `mypageAuthClient.js` normal-script boundary
- Supabase runtime config
- auth session restore
- profile/avatar data
- membership status and role handling
- real user data

Related data/json:

- no simple world-template data source
- Supabase/auth data when enabled

Related JS:

- `assets/js/renderMypage.js`
- `assets/js/mypageAuthClient.js`
- `assets/js/membershipAccessClient.js`
- Supabase/browser clients

Related CSS/assets:

- `assets/css/style.css`

Cache-bust target:

- `mypage.html`
- `assets/js/main.js`
- `assets/js/renderMypage.js`
- `assets/js/mypageAuthClient.js`
- related config/bridge modules

Minimum next-world check:

- disabled/unconfigured state is explicit
- no real user data copied
- no auth connection without separate gate
- no token/JWT/email/raw id exposure

Rollback:

- return to unconfigured/disabled state
- restore runtime config placeholders
- update cache-bust and re-check page

### `timeline.html`

Page type:

- reusable ops core

Ownership boundary:

- ops owns activity timeline, membership gate, RPC data, and target paths

Reusable structure:

- activity card list
- membership-gated page
- empty/error state

Replace or configure per world:

- only if the next world enables activity timeline
- target labels and paths behind ops gates

Dangerous surfaces:

- Supabase RPC `get_activity_timeline`
- approved membership gate
- activity visibility rules
- target paths to session-detail/session-post
- live comments/applications/session events

Related data/json:

- no static world-template data source
- DB/RPC data when enabled

Related JS:

- `assets/js/renderTimeline.js`
- `assets/js/activityTimelineDisplay.js`
- `assets/js/membershipAccessClient.js`
- Supabase browser client

Related CSS/assets:

- `assets/css/style.css`

Cache-bust target:

- `timeline.html`
- `assets/js/main.js`
- `assets/js/renderTimeline.js`
- activity/membership helper modules

Minimum next-world check:

- leave disabled unless ops and membership are enabled
- unapproved/unconfigured states are safe
- no live activity data copied
- no private target paths exposed

Rollback:

- disable page/nav
- restore timeline renderer/config changes
- update cache-bust and re-check gated state

### `admin-cap-announcements.html`

Page type:

- reusable ops admin surface

Ownership boundary:

- ops/admin owns cap announcement scheduling, RPCs, Edge/Discord integration,
  and admin-only behavior

Reusable structure:

- admin page shell
- schedule/list/edit form structure
- status labels and filtering

Replace or configure per world:

- only if the next world explicitly adopts this admin workflow
- target channel and copy policy behind a separate admin/Discord gate

Dangerous surfaces:

- admin auth checks
- RPC names
- Discord posting/scheduling
- Edge Function dependencies
- target channel values
- payload preview and allowed mentions
- secrets/Webhooks

Related data/json:

- DB/RPC data only when enabled

Related JS:

- `assets/js/renderAdminCapAnnouncements.js`
- `assets/js/adminCapAnnouncementClient.js`
- Supabase/browser clients

Related CSS/assets:

- `assets/css/style.css`

Cache-bust target:

- `admin-cap-announcements.html`
- `assets/js/main.js`
- `assets/js/renderAdminCapAnnouncements.js`
- admin client modules

Minimum next-world check:

- keep disabled unless an explicit admin/Discord gate approves it
- no Webhook, token, channel id, or raw Discord value is copied
- no production Discord operation during world-template setup

Rollback:

- disable page/nav
- restore admin renderer/client changes
- do not use live Discord or DB changes as recovery
- update cache-bust and re-check disabled state

## Recommended Adoption Order

1. Prepare `index.html`, `world.html`, and `terms.html` with minimal
   next-world content.
2. Add `characters.html`, `spots.html`, and `spot-detail.html` only to the
   needed scale.
3. Add `regulation.html` skeleton and sample data.
4. Add public-safe `scenarios.html`, `hooks.html`, and `scenario-detail.html`
   data only after GM-secret review.
5. Add `gallery.html` after image ownership, rights, paths, alt, caption, and
   credit policy are clear.
6. Decide whether `campaigns.html`, `campaign-detail.html`, and
   `episode-detail.html` are needed.
7. Decide whether `tools.html` is useful for the world or should stay disabled.
8. Create next-world `updates.html` entries only after launch history exists.
9. Enable `calendar.html`, `session-post.html`, `session-detail.html`,
   `mypage.html`, `timeline.html`, or `admin-cap-announcements.html` only
   behind reusable ops gates.
10. Treat auth, membership, DB/RPC/RLS, Edge Functions, and Discord sync as
    independent gates.
11. Before public launch, check HTTP 200, broken imports, broken images,
    missing data, and visible `undefined` / `[object Object]` text.

## Cross-Page Launch Checklist

For every enabled page:

- public HTML returns HTTP 200
- page title, heading, and lead are next-world-specific
- no Velgard-specific proper noun remains unintentionally
- data files parse
- data can be empty where the page allows it
- related ids resolve or optional blocks hide
- image paths exist or fallback/image-free layout is documented
- no broken image icon or 404 is visible
- no broken import or module-load failure is visible
- no `undefined`, `[object Object]`, empty card, or empty modal shell appears
- cache-bust chain is current after any HTML/JS/data-module change
- auth/DB/Discord surfaces are documented as disabled, limited, or not tested
- `limited` and `not_tested` scopes are recorded honestly

## Rollback And Recovery

If a page adoption step fails:

1. Revert the affected page data.
2. Revert image references or return to placeholders.
3. Revert renderer/CSS changes if a separate gate changed them.
4. Remove or hide broken related links.
5. Restore prior cache-bust or update to a new rollback cache-bust.
6. Re-run public HTTP 200 and broken import/image checks.
7. Record the rollback reason and final state in docs.
8. Do not use secrets, DB changes, Discord operations, auth changes, or live
   data mutations as a shortcut to recover a world-template page.

## Next Candidate Options

Candidate A: campaigns / episodes template structure.

- Document campaign and episode ownership, scale-variable structures, relation
  ids, public recap policy, and separation from live session history.

Candidate B: pre-auth / pre-DB / pre-Discord checklist.

- Define exact stop conditions before enabling reusable ops pages for a next
  world.

Candidate C: OGP / favicon / hero image rollout gate.

- Document public-sharing image checks, cache-bust, and rollback for site
  identity assets.

Candidate D: tools / updates auxiliary page policy.

- Decide whether auxiliary pages stay world-template, reusable utility, or
  optional/disabled for a next world.

Recommended next candidate:

- Candidate A: campaigns / episodes template structure.

Reason:

- campaigns and episodes are current world-template pages but have not yet had
  a dedicated scalable structure plan
- they can remain docs-only and continue the world-template track without
  touching auth, DB, Discord, renderer, CSS, or live session operations
- clarifying campaign recap versus live session history will reduce confusion
  before reusable ops pages are connected

## Phase 3-C7 Campaigns / Episodes Structure Follow-Up

Phase 3-C7 completes the recommended campaigns / episodes template structure:

- `docs/world-template-campaigns-episodes-structure-plan.md`

Page-adoption impact:

- `campaigns.html`, `campaign-detail.html`, and `episode-detail.html` remain
  optional world-template pages
- campaign and episode data is public story/recap content, not live session
  operation data
- the plan records the current `data/campaigns.json` / `data/episodes.json`
  fields and renderer path as a reference, not as next-world production values
- one-shot worlds may omit these pages or keep them hidden without blocking the
  rest of the world-template launch
- GM-secret information, private session logs, member data, and operation
  state must stay out of public campaign/episode data
- session-post, session-detail, calendar, timeline, auth, DB/RPC/RLS, and
  Discord sync remain reusable ops gates

Recommended next docs-only candidate after C7:

- pre-auth / pre-DB / pre-Discord checklist.

## Phase 3-C8 Pre-Ops Connection Checklist Follow-Up

Phase 3-C8 completes the recommended pre-ops connection checklist:

- `docs/world-template-pre-ops-connection-checklist.md`

Page-adoption impact:

- page adoption now has an explicit stop line between public world-template
  launch and operational connection
- world-template pages should pass public-only checks before calendar,
  session-post, session-detail, mypage, timeline, or admin surfaces are enabled
- ops pages can be reviewed in a static/dry state before auth, DB/RPC/RLS,
  Edge, or Discord gates
- auth-required and approved-gated pages must be classified before connection
- SQL, RPC/RLS, Edge deploy, Discord production operations, membership
  permission changes, and data-changing QA remain independent gates
- secret values, raw user data, Discord ids, Webhooks, tokens, and actual
  management keys stay out of docs and public data

Recommended next docs-only candidate after C8:

- ops core static connection dry-run checklist.

## Phase 3-C9 Ops Static Dry-Run Checklist Follow-Up

Phase 3-C9 completes the recommended ops core static dry-run checklist:

- `docs/world-template-ops-static-dry-run-checklist.md`

Page-adoption impact:

- `calendar`, `session-post`, `session-detail`, `mypage`, and `timeline` have
  page-specific dry-run scopes before auth, DB/RPC/RLS, Edge, or Discord work
- `tools` is documented as an auxiliary/public candidate rather than a live
  ops surface
- `admin-cap-announcements` remains strict admin / separate-gate territory
- dry-run may check HTTP 200, broken imports, cache-bust, config/helper
  imports, empty states, fixture display, and unconnected/gated states
- dry-run must not perform real posts, edits, deletes, applications, comments,
  SQL, DB writes, Edge deploy, Discord production operations, membership
  approvals, or manager grants

Recommended next docs-only candidate after C9:

- tools / updates auxiliary page policy.

## Limited And Not Tested

This checklist is docs-only and does not add runtime QA.

Limited:

- page inventory was static
- page/data/renderer mapping was based on current files and grep inspection
- CSS ownership was treated as global `assets/css/style.css`, not line-by-line
  audited
- public HTTP checks were not run in this phase

Not tested:

- actual next-world rendering
- desktop/mobile visual behavior
- empty-state browser behavior for every page
- authenticated flows
- calendar/session-post/session-detail/mypage/timeline/admin operations
- DB/RPC/RLS
- Edge Functions
- Discord sync or posting
- data-changing workflows

## No Dangerous Work

This checklist did not perform SQL Editor execution, SQL apply, DB/RPC/RLS
mutation, Edge deploy, Discord operation, secret/Webhook change, direct
Supabase write, debug console logging addition, `updates.json` change,
auth/permission logic change, membership logic change, RPC/DB key
configuration, CSS class/DOM id/anchor change, `management_key` display, raw
id/email/token/JWT display, HTML change, CSS change, JS change, JSON/data
change, image change, renderer change, world copy change, scenario/hook data
change, gallery change, or ops-core change.
