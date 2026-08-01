# 05 — radio menu, i18n and `mission.yaml` wiring

**Status:** ⬜ ready — depends on 03 and 04.

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
