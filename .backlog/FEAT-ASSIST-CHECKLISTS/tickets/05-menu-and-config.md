# 05 — radio menu, i18n and `mission.yaml` wiring

**Status:** 🧑 waiting-human — built and tested against the mocks; the definition of done is entirely
about behaviour in game, and nothing has been flown yet.

Makes the assistance reachable by a pilot and switchable by a mission maker. Nothing here is specific to
the F-16C.

## Menu

Through `veafRadio`, an `Assistance` submenu, **per player group** — a global entry would let one pilot
put a highlight in someone else's cockpit.

Idle state, one entry per checklist whose `aircraft` list matches the group's type:

```
Assistance
  Cold start
```

Emit nothing for a group whose aircraft has no checklist: an entry that answers "nothing for your
aircraft" is worse than no entry.

During a session, the entries become:

```
Assistance
  Confirm this step         → veafAssist.confirmStep
  Skip this step            → veafAssist.skipStep
  Hide / show the checklist → veafAssist.togglePicture
  Stop                      → veafAssist.stop
```

`Confirm this step` should only appear when the current step is a confirm-mode one — an inert menu item on
an automatic step invites a pilot to press it and wonder why nothing happens.

The menu is rebuilt as the session state changes, so mind the existing conventions: pagination
([ADR 0013](../../../docs/adr/0013-radio-menu-pagination.md)), and explicit removal of the entries we
added — the menu is rebuilt on every join, and leftovers stack one duplicate per join, which is exactly
the bug `FEAT-COMBATZONE-MENU-COALITION` had to fix.

## Configuration

One block under the unified `modules:` key, per
[ADR 0001](../../../docs/adr/0001-modules-single-source-of-truth.md):

```yaml
modules:
  assist:
    enabled: true
    checklists: [f16c-cold-start]   # which ones this mission activates
```

`checklists` is what drives ticket 02's emission and ticket 03's image generation, so the build cost stays
proportional to actual use. Absent or `enabled: false` → nothing loaded, nothing generated, no images in
the `.miz`.

Resist adding verbosity levels or per-aircraft toggles before anyone has flown it.

Per `CLAUDE.md` §9.7, update `src/defaults/mission-folder/mission.yaml` in the same lot so the shipped
default matches the generated output.

## i18n

FR + EN catalog entries for the menu labels and the module's own messages: session started, step
validated, **step skipped**, checklist complete, no checklist for your aircraft. Step labels themselves
belong to ticket 06.

## Definition of done

- A pilot in a supported aircraft starts and stops assistance from the F10 menu, and the contextual
  entries appear and disappear with the session.
- `enabled: false` costs nothing at build and nothing in game.
- **Two players assisted simultaneously without interference** — the case ticket 04's per-session
  highlight allocation exists for, and the one worth testing in game rather than only in mocks.
- Python-side tests for the config plumbing, following the existing module patterns.

## What was built

The menu is in [`veafAssist.lua`](../../../src/scripts/veaf/veafAssist.lua) (`buildRadioMenu`), the
config plumbing in [`mission_builder_worker.py`](../../../src/python/veaf-tools/mission_builder/mission_builder_worker.py)
(`_resolve_checklists`, `_checklist_resources`) and the activation rule in
[`checklists.py`](../../../src/python/veaf-tools/veaf_libs/checklists.py) (`select_activated`).
Tests: 9 more Lua cases in `test_veafAssist.lua`, plus `test_checklist_activation.py` and
`test_assist_checklists_build.py`.

**A small addition to `veafRadio`, and it is the piece that makes the menu work.** The ticket asks for
an entry only where it applies, and `veafRadio` had no way to express that: a per-group command was
attached for **every** human group. Commands now accept an optional
`groupFilter(unitName, groupId) -> boolean`, consulted once per candidate unit. Three lines in
`_placeCommandOnMenu`, no signature change, and a filter that throws is logged and treated as false so
it cannot take a menu rebuild down with it.

That filter does more than hide the entry from the wrong aircraft: **the whole contextual menu is
expressed with it**. Start entries and in-session entries all live in the tree permanently, and each
decides for itself whether this pilot should see it. Nothing is ever added or removed, so the
duplicate-per-join failure mode of `FEAT-COMBATZONE-MENU-COALITION` cannot happen here — a state change
just calls `veafRadio.refreshRadioMenu()`, which is already debounced.

**Activation rule, as agreed with David:** an explicit `checklists:` list wins and an unknown id fails
the build; with no list, the checklists the mission maker dropped in the mission's own `checklists/`
folder are activated — never the whole shipped catalogue, since every activated checklist costs one
image per step in the `.miz`.

## Known limitation

The `Assistance` submenu itself is global — only its **entries** are per group. A pilot flying an
aircraft with no checklist therefore sees an empty `Assistance` menu rather than no menu at all.
Scoping the submenu itself would mean rendering the whole subtree per group, which is a rewrite of
`veafRadio`'s builder, not a prototype's business.

## Left open — the definition of done is in-game behaviour

None of the four DoD items has been exercised in DCS: starting and stopping from the F10 menu, the
contextual entries appearing and disappearing, `enabled: false` costing nothing, and above all **two
players assisted at once**. The last one is the reason the per-session highlight id exists and the one
the mocks can only pretend to cover.
