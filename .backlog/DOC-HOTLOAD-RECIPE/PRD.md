# DOC-HOTLOAD-RECIPE — load dcs-hotload in a VMCT-built mission

Status: ✅ done

Origin: David's study of [MacFlorent/dcs-hotload](https://github.com/MacFlorent/dcs-hotload), 2026-11-09, and the choice of its author, Flogas, the same day.

## The need

dcs-hotload runs Lua in a live DCS mission from the F10 menu or a file mailbox, re-read from disk on every run, without a network port.
Its author wants to use it in missions built with VMCT.
It loads through a `dofile` of a file on disk, and that path belongs to one machine: written in the mission sources, it breaks the mission on a server or for a player who does not have it.

## Decision (David and Flogas, 2026-11-09)

Option A, a recipe with no VMCT code: a boot script declared in `custom_scripts` loads dcs-hotload from `Saved Games\DCS\Scripts\dcs-hotload\` when it is there and `io` and `lfs` are unlocked, and does nothing otherwise.
The same `.miz` goes everywhere.

Option B, a `hotload:` key in `mission.yaml` injected by the build in `--dev-mode` only, is **not** done.

## Revision: one copy per mission (2026-11-11)

Flogas reviewed the page: the recipe works, but one install per machine mixes every mission's F10 entries and mailbox, and it is not hotload's model.
hotload's model (its README and `bin/hotload-setup.py`, 3.1.0) is one `dcs-hotload/` copy extracted into the mission folder, unlocked with `hotload-setup.py unlock`, checked with `status`, booted by a MISSION START trigger that `patch-miz` adds.
VMCT regenerates the `.miz` on every build, so `patch-miz` is not used: the boot script in `custom_scripts` stays, and its code is hotload's own trigger guard (`loadfile`, a `HOTLOAD: not booted:` line in `dcs.log` where it cannot load).
After a second review, the boot finds the copy from `VEAF_DYNAMIC_MISSIONPATH` (Flogas's suggestion) instead of a hard-coded path: only a dynamic build sets it, to the mission folder on the building machine, so hotload runs in a dynamic build only, and no profile or blanking is needed for a static one.
Chosen by David on Flogas's proposals; still no VMCT code.
The same review found the `mission.yaml` reference's `FgDebug.lua` profile example wrong (an undeclared `src/scripts/*.lua` is loaded anyway); ticket 02 fixes it too.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Developer page: the hotload recipe](tickets/01-hotload-recipe-page.md) | ✅ |
| 02 | [Rewrite the page for one copy per mission, fix the profile example](tickets/02-per-mission-copy.md) | ✅ |

## Out of scope

- Any build code: no `hotload:` key, no vendored copy of dcs-hotload.
- Reloading VEAF modules with hotload: its own README forbids reloading code that owns live objects.

## Closing

The recipe is checked against a mocked `lfs`/`env` under DCS's own `luae.exe`, not in game.
David closed the lot without an in-game test (2026-11-09); merged in #1257.
Ticket 02 reopened it on 2026-11-11: the rewritten boot script was checked under `luae.exe` against the real `dcs-hotload.lua` 3.1.0, and `hotload-setup.py` 3.1.0 was run on a VMCT-built `.miz` embedding it; the profile example was checked by building a test mission with and without `--profile DEV`. Still not tested in game.
