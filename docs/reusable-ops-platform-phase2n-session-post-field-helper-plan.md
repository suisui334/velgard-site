# Phase 2-N Session Post Field Helper Extraction Plan

## Background

Phase 2 has started separating reusable TRPG operations code into `assets/js/core/`
in small, reversible steps. The current core session files cover display
formatters and small session-detail HTML helpers, while `assets/js/sessionDisplay.js`
remains the compatibility facade.

This audit reviews `assets/js/renderSessionPost.js` to decide whether small
session-post form helpers can be extracted safely.

## Scope

Reviewed files:

- `assets/js/renderSessionPost.js`
- `assets/js/sessionDisplay.js`
- `assets/js/core/session/sessionDisplayHelpers.js`
- `assets/js/core/session/sessionHtmlHelpers.js`
- `assets/js/core/config/reusableOpsConfig.js`
- `assets/js/main.js`
- `session-post.html`

No implementation change was made in this phase.

## Current Responsibilities

`renderSessionPost.js` is still a mixed page module. It contains:

- session-post form shell rendering
- simple text/select/textarea field HTML helpers
- player count field HTML
- Discord mention field HTML
- template preset UI rendering and template preset RPC calls
- form value normalization and payload builders
- create/update/delete RPC calls
- Discord auto-sync calls after create/update/delete
- managed-session select normalization and option rendering
- publication/status hints and result rendering
- auth, posting access, and approved gate entry flow
- event handler registration

Because these responsibilities are tightly colocated, broad extraction from this
file would have a higher blast radius than the previous `sessionDisplay.js`
helper extractions.

## Candidate Classification

| candidate | classification | notes |
| --- | --- | --- |
| `renderTextField` | A / B | Small pure HTML string helper. It escapes label/name/type/options and does not call RPC or touch DOM. Extraction is plausible after deciding whether this belongs under `core/session` or generic `core/form`. |
| `renderSelectField` | A / B | Small pure HTML string helper. It depends on the current option tuple shape and selected-value comparison. Safe candidate if that shape is documented. |
| `renderTextareaField` | A / B | Small pure HTML string helper. It is session-post styled but otherwise simple. |
| `getSessionPostLabel` | B | Thin reusableOpsConfig wrapper. Better to leave until the session-post label surface is stable. |
| `renderPlayerCountFields` | B / C | Mostly display-only, but it hard-codes session-post field names and uses the session-post label wrapper. Extract after the basic field helpers or label fallback policy is settled. |
| `formatPlayerCountLabel` | B | Pure formatter used by managed-session normalization. It can move later, but should be grouped with managed-session display decisions. |
| `renderManagedSessionOption` | C | Small string output, but tied to management select value conventions and session indexes. Keep in place for now. |
| `renderSessionPostTemplateExamples` | C | Display-only shape, but tied to template type normalization and template UI state. Keep with template UI until that boundary is planned. |
| `renderSessionPostTemplatePanel` | C / D | Large UI block with template controls and later event/RPC coupling. Do not extract in a small helper gate. |
| `renderShell` | C | Whole page shell. Too large for helper extraction. |
| `renderDiscordMentionField` | D | UI-only at first glance, but semantically close to Discord notification behavior. Keep out of generic form helpers. |
| `renderResult` | C / D | Displays create result and Discord sync status. Keep with post/save/sync flow. |
| payload builders and validation | D | Close to RPC contracts, DB fields, and save behavior. Extraction is prohibited in this phase. |
| template preset query/create/update/deactivate helpers | D | Direct RPC calls and template persistence behavior. Not a display helper. |
| save/delete/create/update flows | D | RPC and Discord sync behavior. Not eligible for core helper extraction. |
| event handler setup | D | Page behavior and DOM state. Not eligible. |
| auth/access/approved gate logic | D | Auth and permission logic must not be configured or moved in this phase. |

Classification key:

- A: can likely be extracted immediately in a dedicated implementation gate
- B: can be extracted after labels/fallbacks or ownership are clarified
- C: UI block coupling is too strong for now
- D: auth, permission, RPC, DB, Discord, or persistence-adjacent; do not extract
- E: not used here

## Decision

Phase 2-N is documentation-only.

The safest next implementation, if desired, is a very narrow extraction of only
`renderTextField`, `renderSelectField`, and `renderTextareaField` into one of:

- `assets/js/core/session/sessionFormHelpers.js`
- `assets/js/core/form/formFieldHelpers.js`

That implementation should keep all CSS classes, markup, escaping behavior, and
fallback text unchanged, and should leave `renderSessionPost.js` as the page
orchestrator.

## Dependencies To Keep In Place

Do not move or broadly rewrite the following from `renderSessionPost.js` yet:

- session create/update/delete RPC calls
- template preset RPC calls
- Discord auto-sync calls
- Discord mention controls
- payload builders and validation
- publication/status hints
- managed-session select behavior
- auth, approved gate, or posting access logic
- event handler registration

These areas are close to runtime behavior and require separate QA gates.

## Future Extraction Shape

A later implementation gate can use this sequence:

1. Extract only `renderTextField`, `renderSelectField`, and `renderTextareaField`.
2. Keep `renderSessionPost.js` importing those helpers and exporting no new
   public surface.
3. Run `node --check` for the new helper and `renderSessionPost.js`.
4. Verify `session-post.html` still loads with unchanged labels, field layout,
   select values, and fallback behavior.
5. Record that create/edit/save/template/Discord behavior was not changed.

Only after that should `renderPlayerCountFields` or `formatPlayerCountLabel` be
considered.

## Phase 2-O Implementation Follow-Up

Phase 2-O implemented the first narrow extraction from this plan.

Extracted:

- `renderTextField`
- `renderSelectField`
- `renderTextareaField`

Destination:

- `assets/js/core/session/sessionFormHelpers.js`

The destination stayed under `core/session` because the helpers still emit
`session-post-field` CSS classes. `renderSessionPost.js` now imports these
helpers and remains the page renderer/orchestrator.

Still not extracted:

- `renderPlayerCountFields`
- `formatPlayerCountLabel`
- template UI and template RPC behavior
- Discord mention/sync behavior
- payload builders
- save/edit/delete flows
- auth/access/approved gate checks
- event handlers

Detailed result:

- `docs/reusable-ops-platform-phase2o-session-post-field-helper-result.md`

## Phase 2-Q Player Count Follow-Up

Phase 2-Q audited the next conditional candidates:

- `renderPlayerCountFields`
- `formatPlayerCountLabel`

Decision: no implementation in this gate.

`renderPlayerCountFields` is display-only, but its `p_player_min` /
`p_player_max` control names are tied to payload generation, template field
keys, template application, managed-session edit filling, and new-session reset
behavior. It should move only after that contract is explicitly documented and
covered by QA.

`formatPlayerCountLabel` is a pure formatter, but its range/max/min/unset text
should be kept or routed through `reusableOpsConfig` deliberately before moving.

Detailed plan:

- `docs/reusable-ops-platform-phase2q-session-post-player-count-helper-plan.md`

## QA Notes For A Future Gate

If helper extraction is implemented later, check:

- session-post page renders
- title/start/end/deadline/session type/location/status fields remain visible
- player min/max layout remains unchanged
- template panel still renders
- Discord mention field behavior remains unchanged
- create/edit/delete/save flows are not modified
- no `undefined`, `[object Object]`, empty label, raw id, email, token, JWT, or
  internal key appears

Data-changing QA and Discord sync QA must remain separate explicit gates.
