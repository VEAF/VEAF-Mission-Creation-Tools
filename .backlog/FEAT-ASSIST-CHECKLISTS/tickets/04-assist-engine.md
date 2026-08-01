# 04 — `veafAssist.lua`, the engine

**Status:** ✅ done — 2026-08-01, except the two ticket 01 probes, which need a live DCS (see below).

New runtime module following the house pattern (`veafAssist = {}`, `.Id = "ASSIST"`,
`veaf.loggers.new(...)`, constants in caps, i18n keys resolved through `veaf.t()` at send time — see
[veafSanctuary.lua](../../../src/scripts/veaf/veafSanctuary.lua)).

## First thing, before writing the loop

Settle the two probes left open in [ticket 01](01-primitives-spike.md): does
`Unit:getDrawArgumentValue(arg)` report cockpit switch state for a player-flown aircraft, and is
`a_out_picture_u` reachable from the mission environment. The check mechanism rests on the first, the
display on the second. Record both answers back in ticket 01.

Fallback for the check: the native predicate `c_player_unit_argument_in_range`, if it too is exposed.

## The loop

Per player being assisted, on a timer (a couple of seconds):

1. Resolve the player's unit; drop the session quietly if the unit is gone.
2. Walk the steps, find the first one whose check fails — **skipped steps are treated as passed**.
3. `a_cockpit_highlight(id, step.element)` if the step has an element. Re-highlight **only when the
   target step changes**: ED's own `update_checklist` guards on exactly this, and re-issuing every tick is
   wasteful and visually unstable.
4. Display state `k` of the checklist image, duration 0, `clearView` true.
5. Nothing left → clear the highlight, `a_out_picture_stop`, completion message, end the session.

The two output channels have distinct roles, per the PRD: **the image is the dashboard**, **short texts
carry events** (validated, skipped, complete). Never rebuild an image for a message.

## The check registry

`veafAssist.registerCheck(name, fn)`. Two checks registered by default:

| Name | Behaviour |
|---|---|
| `argument` | `Unit:getDrawArgumentValue(arg)` within the window |
| `confirm` | satisfied by a pilot confirmation recorded for that step |

A check is `fn(unit, step, session) → boolean`. Keep the signature stable: it is the bomb-run lot's only
extension point, and changing it later means touching every registered check.

## Public surface

| Function | Role |
|---|---|
| `veafAssist.registerChecklist(def)` | declare a checklist (what ticket 02 emits) |
| `veafAssist.registerCheck(name, fn)` | add a named check |
| `veafAssist.start(unitName, checklistId)` | begin a session |
| `veafAssist.confirmStep(unitName)` | pilot confirms the current step |
| `veafAssist.skipStep(unitName)` | pilot skips it — emits the "skipped" text |
| `veafAssist.togglePicture(unitName)` | hide / show the image |
| `veafAssist.stop(unitName)` | end, clearing highlight and picture |
| `veafAssist.initialize()` | module init |

## Cases to handle

- Player leaves the slot or dies mid-session → stop, no error spam.
- **Two players assisted at once** → per-session state, and a highlight id allocated per assisted unit. A
  single shared id would make two cockpits fight over it.
- Aircraft type with no checklist → one clear message, not one per tick.
- `a_cockpit_highlight` or `a_out_picture_u` missing → detect once at init, log, refuse to start rather
  than throwing every tick.
- Starting a checklist while one is already running for that pilot → replace it, clearing the previous
  highlight and picture first.

## Tests

`test/lua/test_veafAssist.lua`, luaunit, against the DCS mocks. The mocks need
`Unit:getDrawArgumentValue` plus stubs for `a_cockpit_highlight`, `a_cockpit_remove_highlight`,
`a_out_picture_u` and `a_out_picture_stop` — adding them belongs to this ticket and lines up with
`TOOLING-DCS-MOCK-COVERAGE`.

Cover: step advances when the argument enters the window and not before; **already-satisfied steps are
ticked at start** (a pilot who pre-flipped a switch is not asked for it); `confirm` only advances a
confirm-mode step; `skip` advances and emits the text; highlight re-issued only on target change; the
displayed image index tracks the progress state; completion clears highlight and picture; two concurrent
sessions do not share a highlight id; unknown checklist id is inert.

## Definition of done

- Module + tests green under `poetry run test-lua`, `luacheck` and `stylua --check` clean.
- Lua coverage floor bumped per the ratchet policy.
- Both ticket 01 probes answered in writing.

## What was built

[`veafAssist.lua`](../../../src/scripts/veaf/veafAssist.lua), 30 tests in
[`test_veafAssist.lua`](../../../test/lua/test_veafAssist.lua), 95 % line coverage. The mocks gained
`Unit:getDrawArgumentValue`, the four cockpit primitives and `getValueResourceByKey`, each recording its
calls so a test asserts what the engine asked of the cockpit. Lua coverage floor 69 → 70.

**One design point the ticket did not anticipate: a passed step stays passed.** The described loop —
"walk the steps, find the first one whose check fails" — re-evaluates everything on every tick, and that
breaks on any sequence where a control passes *through* a position. ED's own cold start does exactly that:
MAIN PWR goes OFF → BATT → MAIN PWR, so the moment the pilot reaches MAIN PWR the BATT step stops being
satisfied and the engine would send them back to it, forever. The engine therefore latches: steps already
satisfied are ticked **when the session opens** (which is the "usable half-way through" behaviour the PRD
asked for), and from then on only the current step is evaluated, and stays ticked once passed.

Two smaller calls: the highlight is re-issued when the **boxed element** changes, not merely when the step
index does — consecutive steps on the same switch would otherwise flicker the box for nothing; and an
unknown `check.type` never passes and warns once, rather than throwing on every tick.

## Left open — needs a live DCS

Both ticket 01 probes are still open, and both need David's DCS running with `dcs-serve` up:

1. **Does `Unit:getDrawArgumentValue(arg)` report cockpit switch state for a player-flown aircraft?** The
   whole `argument` check rests on it. The engine calls it through `pcall` and treats a non-number as "not
   satisfied", so a negative answer degrades to "nothing ever auto-validates" rather than an error storm —
   but the feature would then need the `c_player_unit_argument_in_range` fallback.
2. **Is `a_out_picture_u` reachable from the mission environment?** Detected at init; the module refuses
   to start without it.

One thing the ticket listed as unknown is now **answered from ED's own source** rather than a probe:
`me_trigrules.lua:979` documents `seconds = 0` as *"if the picture display time is 0, show until
`a_out_picture_stop` is called (DCSCORE-2754)"*, and gives the full signature —
`a_out_picture_u(unitId, file, seconds, clearview, startDelay, horzAlignment, vertAlignment, size,
sizeUnits)`. The persistent-checklist design holds.

Still open too, and not blocking: whether a highlight is visible to a **second** player.
