# Phase 2-R Player Count Field Behavior Spec

## Background

Phase 2-Q classified both `renderPlayerCountFields` and
`formatPlayerCountLabel` as `B`: likely extractable later, but only after the
current display and fallback behavior is fixed in documentation.

This phase is documentation-only. No implementation change, helper extraction,
file move, import/export change, CSS change, data change, SQL Editor execution,
SQL apply, DB/RPC/RLS mutation, Edge deploy, Discord operation, direct
Supabase write, debug console logging addition, `updates.json` change,
auth/permission logic change, `management_key` display, or raw
id/email/token/JWT display was performed.

## `renderPlayerCountFields` Current Contract

The helper currently generates one player-count group with two numeric inputs.

Group wrapper:

- element: `div`
- classes: `session-post-field session-post-player-field`
- role: `group`
- `aria-labelledby`: `session-post-player-count-label`

Main label:

- element: `span`
- class: `session-post-player-label`
- id: `session-post-player-count-label`
- visible text: `getSessionPostLabel("playerCount", "募集人数")`

Input container:

- element: `div`
- class: `session-post-player-inputs`

Minimum input:

- visible sublabel: `min`
- input type: `number`
- `name`: `p_player_min`
- `min`: `0`
- no `id`
- no custom `class`
- no `required`
- no `placeholder`
- no `max`
- no initial `value` attribute

Maximum input:

- visible sublabel: `max`
- input type: `number`
- `name`: `p_player_max`
- `min`: `0`
- no `id`
- no custom `class`
- no `required`
- no `placeholder`
- no `max`
- no initial `value` attribute

Supplement text:

- none.

CSS dependencies:

- `session-post-field`
- `session-post-player-field`
- `session-post-player-label`
- `session-post-player-inputs`

These classes are session-post-specific, so a future extraction should stay
under `core/session`, not generic `core/form`, unless the markup is redesigned
in a separate gate.

## Payload And Form Dependencies

The `p_player_min` and `p_player_max` control names are part of the
session-post payload boundary.

`buildSessionPayload(form)` reads the controls through `getValue()` and
`nullableInteger()`:

- empty value -> `null`
- integer text -> integer
- non-integer text -> `NaN`, then `invalid-player-count`
- decimal text -> `NaN`, then `invalid-player-count`

The current JavaScript payload layer does not compare min/max and does not
enforce non-negative values beyond the browser input attribute. The normal UI
uses `min="0"`, while downstream RPC/table constraints are responsible for the
authoritative negative/range guard.

Payload keys:

- `p_player_min`
- `p_player_max`

These keys must not be renamed during helper extraction.

## Template Dependencies

The same control names are included in `SESSION_POST_TEMPLATE_FIELD_KEYS`.

Template save collects:

- `p_player_min`
- `p_player_max`

Template apply writes:

- `setFormValue(form, "p_player_min", fields.p_player_min)`
- `setFormValue(form, "p_player_max", fields.p_player_max)`

Any future extraction of `renderPlayerCountFields` must preserve these control
names and the empty-string behavior, otherwise saved templates may stop
round-tripping player-count values.

## Managed Edit Dependencies

Managed-session edit mode restores player-count values through
`fillFormFromManagedSession()`.

Current restore behavior:

- finite `session.playerMin` -> string value
- non-finite / unset `session.playerMin` -> empty string
- finite `session.playerMax` -> string value
- non-finite / unset `session.playerMax` -> empty string

`resetFormForNewSession()` clears both controls back to empty strings.

`normalizeManagedSession(row)` reads `row.player_min` and `row.player_max`
through `toNumberOrNull()` before storing `playerMin` / `playerMax`.

`normalizeManagedSessionFromUpdate(previousSession, payload, result)` feeds the
same payload values back into the managed-session memory model after a save.

## Discord Sync Distance

`renderPlayerCountFields` does not call Discord sync code and does not format
Discord text directly.

However, create/update flows pass the session payload through the save path
before Discord sync wrappers are called. Therefore, future extraction must not
alter:

- payload key names
- `null` versus empty-string conversion
- numeric integer conversion
- min/max semantic meaning

Discord operation QA remains a separate explicit gate.

## `formatPlayerCountLabel` Current Output

Current implementation:

- finite min and finite max -> `${min}〜${max}名`
- finite max only -> `最大${max}名`
- finite min only -> `最低${min}名`
- otherwise -> `未設定`

Current behavior cases:

| Case | Current output |
| --- | --- |
| min=`2`, max=`5` as numbers | `2〜5名` |
| min=`3`, max=`3` as numbers | `3〜3名` |
| min=`2`, max=`null` | `最低2名` |
| min=`null`, max=`5` | `最大5名` |
| min/max both missing | `未設定` |
| min/max both `null` | `未設定` |
| min/max both `undefined` | `未設定` |
| min/max both empty strings | `未設定` |
| min=`0`, max=`0` as numbers | `0〜0名` |
| min=`0`, max=`null` | `最低0名` |
| min=`null`, max=`0` | `最大0名` |
| raw string min=`"2"`, max=`"5"` passed directly | `未設定` |
| raw invalid min=`"abc"`, max=`"5"` passed directly | `未設定` |

Important normalization note:

- normal managed-session rows are normalized by `toNumberOrNull()` before
  calling `formatPlayerCountLabel`
- numeric strings from rows can become finite numbers before display
- invalid strings from rows become `null`
- negative finite values would still be displayed by the formatter if they
  reached it, though normal UI and DB/RPC guards should prevent that state

## Extraction Decision

Recommended next step:

1. Extract `formatPlayerCountLabel` first only if this exact output contract is
   intentionally preserved.
2. Keep the wording hard-coded for the first extraction, or introduce
   `reusableOpsConfig` wording in a separate label gate. Do not combine both
   changes.
3. Move `renderPlayerCountFields` only in a dedicated implementation gate that
   includes template apply, managed edit restore, reset, and payload checks.

Preferred future destinations:

- `formatPlayerCountLabel`: `assets/js/core/session/sessionDisplayHelpers.js`
- `renderPlayerCountFields`: `assets/js/core/session/sessionFormHelpers.js`

Do not place `p_player_min`, `p_player_max`, RPC names, DB column names, or
permission logic into `reusableOpsConfig`.

## Compatibility Conditions For Any Future Move

Future extraction must preserve:

- wrapper classes and `role="group"`
- `aria-labelledby="session-post-player-count-label"`
- main label fallback `募集人数`
- visible sublabels `min` and `max`
- input names `p_player_min` and `p_player_max`
- input type `number`
- input `min="0"`
- no added `required`, `placeholder`, `max`, or initial `value` unless a
  separate UI behavior gate approves it
- empty input -> payload `null`
- non-integer input -> `invalid-player-count`
- template save/apply round trip
- managed edit restore
- new-session reset clearing
- managed-session option player-count wording

Data-changing create/edit/delete QA, template operation QA, and Discord sync QA
remain separate explicit gates.
