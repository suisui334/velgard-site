# Phase 2-Q Session Post Player Count Helper Extraction Plan

## Background

Phase 2-O extracted the three basic session-post field helpers:

- `renderTextField`
- `renderSelectField`
- `renderTextareaField`

Phase 2-P confirmed the public delivery chain for those helpers. This audit
reviews the next conditional candidates:

- `renderPlayerCountFields`
- `formatPlayerCountLabel`

No implementation change was made in this phase.

## `renderPlayerCountFields`

Current role:

- renders the paired player-count inputs in the session-post form
- uses the configured session label for `playerCount`
- emits `session-post-field`, `session-post-player-field`,
  `session-post-player-label`, and `session-post-player-inputs`
- hard-codes the form control names `p_player_min` and `p_player_max`
- hard-codes the visible sublabels `min` and `max`
- sets `type="number"` and `min="0"` on both inputs

Dependency notes:

- The `p_player_min` / `p_player_max` names are read by `buildSessionPayload`.
- The same names are part of `SESSION_POST_TEMPLATE_FIELD_KEYS`.
- Template application writes back to these fields.
- Managed-session edit mode fills these controls from normalized session rows.
- New-session reset clears these controls.
- Discord sync does not directly depend on this helper, but it receives the
  saved session payload/result after create or update.
- The helper does not register events, call RPCs, or inspect auth/permission
  state.

Classification: `B`.

It can probably move later, but should not be moved before the player-count
field-name contract and fallback label policy are documented. It is more
session-post-specific than the three basic field helpers.

Preferred future destination:

- `assets/js/core/session/sessionFormHelpers.js`

Keep it in `core/session`, not generic `core/form`, because it emits
session-post-specific class names and form control names.

## `formatPlayerCountLabel`

Current role:

- formats normalized `playerMin` / `playerMax` values for managed-session
  display
- returns a range label when both values exist
- returns a max-only label when only max exists
- returns a min-only label when only min exists
- returns the existing unset fallback when neither value exists

Dependency notes:

- It is pure string formatting and has no DOM, RPC, auth, or Discord sync
  dependency.
- It is currently used inside `normalizeManagedSession`.
- Its output is user-facing copy and should eventually be label/config aware.
- Existing behavior for `0`, `null`, `undefined`, and non-finite values must be
  preserved if moved.
- It may have reuse value beyond session-post, but the wording is currently
  tied to Japanese display labels and managed-session display.

Classification: `B`.

The function is technically easy to move, but the wording should be settled
first. A future implementation can either keep the exact current fallback text
in a helper or route the words through `reusableOpsConfig` after a separate
label audit.

Preferred future destination:

- `assets/js/core/session/sessionDisplayHelpers.js` if treated as a display
  formatter
- or `assets/js/core/session/sessionFormHelpers.js` if kept close to
  session-post form/managed-session display

`sessionDisplayHelpers.js` is slightly more natural once wording/fallbacks are
stable.

## Decision

Phase 2-Q is documentation-only.

Do not extract either helper yet. The next implementation should wait until:

1. the `p_player_min` / `p_player_max` form-name contract is documented as an
   intentional session-post payload boundary;
2. `min` / `max` sublabels and player-count unset/range wording are either
   explicitly kept as current text or moved into `reusableOpsConfig`;
3. template application and managed-session edit-mode QA are included in the
   check plan.

## Explicitly Unchanged

No change was made to:

- post create/update/delete payload generation
- template field persistence or application
- managed-session edit-mode form filling
- Discord mention or Discord sync behavior
- auth, approved gate, owner, admin, or posting access logic
- event handler registration
- DB/RPC/RLS contracts

## Future QA For An Implementation Gate

If either helper is moved later, verify:

- session-post form still shows the player count field
- `min` / `max` inputs keep `name="p_player_min"` and `name="p_player_max"`
- both inputs remain numeric and keep `min="0"`
- template application still restores player min/max
- managed-session edit mode still fills player min/max
- new-session mode still clears player min/max
- managed-session option labels still show the same player-count wording
- no `undefined`, `[object Object]`, empty label, raw id, email, token, JWT, or
  internal key appears

Data-changing create/edit/delete and Discord sync QA remain separate explicit
gates.
