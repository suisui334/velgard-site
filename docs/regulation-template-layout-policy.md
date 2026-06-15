# Regulation Template Layout Policy

## Background

Recent regulation page work updated both content and layout:

- Added GM notes for reward amount and Sword Shard guidance.
- Updated reward amount and Sword Shard table values.
- Added and expanded the fumble experience note card.
- Added the note that `〈勇者の証〉` cannot be used for lower-bound growth.
- Split `魔動天使の使用制限` into an independent card.
- Bolded the route headings inside the angel rule text.
- Added angel weapon and armor data.
- Clarified Route A by excluding `鎧4【天衣無縫】` from the fourth-stage Angel Order exception.
- Improved the desktop regulation page direction toward wide content, single-column cards, and a right-side current-position menu.

These changes are content updates for Velgard, but they also clarify how a future world-site template should handle rule pages.

## Template Position

`regulation` belongs to the world-site side, not the reusable ops core.

It is still strongly connected to the ops platform because `mypage`, `session-post`, and `session-detail` may guide users to rule expectations before play, posting, or participation. The page itself should remain with each world site if the ops platform becomes independent, but its page skeleton and data/rendering pattern are reusable.

## Layout Policy

For desktop:

- Prioritize readability and referenceability over decorative density.
- Use a wider content area than a narrow centered card stack.
- Prefer a single vertical column for long rule cards.
- Keep card styling, spacing, and headings, but avoid two-column layouts for long rules.
- Use a side or table-of-contents menu.
- Highlight the current section in the menu when possible.
- Keep anchor navigation so users can jump to specific rules.

For mobile:

- Keep a vertical stacked layout.
- Do not force a fixed side menu.
- Keep long cards readable without horizontal scrolling.

## Reusable Structure For Future Worlds

The following structure can be reused in future world sites:

- Term/explanation cards.
- Level cap tables.
- Reward, honor, growth, and similar operational tables.
- Long-form house rule cards.
- Individual ruling cards such as the angel rule.
- Table-of-contents or side menu.
- Active current-position menu state.
- Mobile vertical stacking.
- Desktop wide-reading layout.
- JSON-managed regulation data.

The reusable target is the page structure, data model, and navigation pattern. It is not a fixed design skin.

## Velgard-Specific Content

The following should remain world-specific data and should not move into reusable ops core:

- Concrete `魔動天使` rulings.
- Reward amount values.
- Sword Shard and honor-point values.
- Fumble experience handling text.
- Lower-bound growth handling text.
- Abyss-related rulings.
- Velgard-specific terms and operational rules.
- Current color, spacing, card decoration, and visual tone.

## Ops Boundary

Reusable ops platform side:

- `calendar`
- `mypage`
- `session-post`
- `session-detail`
- membership management
- application/comment flows
- templates
- notifications/timeline
- Discord sync

World-site side:

- `world`
- `characters`
- `spots`
- `terms`
- `regulation`
- `gallery`

Connection points:

- `session-post` can link to regulation for posting and play rules.
- `mypage` can link to regulation for account or participation guidance.
- `session-detail` can link to regulation for participation expectations.
- Regulation data and renderer patterns can be reused by another world site without being part of the ops core.

## Current Ops Extraction Status

- Phase 1-A to 1-E: `reusableOpsConfig` entry points, key label connections, and public checks are complete.
- Phase 2-B/C: config files moved to `assets/js/core/config/` and public rollout was checked.
- Phase 2-D/E: `renderCalendar.js` moved to `assets/js/core/calendar/`; public rollout and browser QA were checked.
- Phase 2-F: `sessionDisplay.js` was audited and kept in place rather than moved as a whole.
- Phase 2-G: pure helpers were extracted from `sessionDisplay.js` to `assets/js/core/session/sessionDisplayHelpers.js`.
- Regulation layout/content work is a world-site template track, separate from the reusable ops core extraction track.

## Next Candidates

1. Phase 2-G public rollout check:
   - Confirm that the extracted `sessionDisplayHelpers.js` causes no public-side regression in calendar, session-post, or session-detail.
2. Regulation layout browser QA:
   - Confirm desktop wide layout, single-column cards, right-side active menu, and mobile stacking on the public site.
3. Regulation template structure detail:
   - Document the JSON structure for tables, term cards, long-form rule cards, and table-of-contents behavior for future world sites.

## Phase 3-B1 Structure Detail

Phase 3-B1 expands this policy into a structure-level regulation template plan:

- `docs/world-template-regulation-structure-plan.md`

The detailed plan treats regulation as a world-site template page, not an ops
core page. It separates reusable page skeletons from Velgard-specific rule
content, records future data/JSON candidates, and keeps auth, membership, RPC,
DB, and Discord sync outside the regulation template boundary.

Key additions:

- reusable parts: page title, lead, TOC/side menu, active menu state, term cards,
  tables, long-rule cards, individual ruling cards, GM/PL notes, and caution
  blocks
- data candidates: `regulationPage`, `regulationToc`, `regulationSections`,
  `regulationBlocks`, `regulationTables`, `termCards`, `houseRules`,
  `gmNotes`, and `playerNotes`
- layout stance: wide desktop reading area, one-column long rules, side menu
  with active state, and mobile vertical stacking
- boundary stance: regulation data and renderer patterns can be reused by a
  future world site, but ops-core permissions, auth, RPC, DB, Discord sync, DOM
  ids, CSS classes, and internal keys should not be turned into regulation data
