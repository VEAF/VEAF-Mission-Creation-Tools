# DOC-HOTLOAD-RECIPE — load dcs-hotload in a VMCT-built mission

Status: ✅ done · archived 2026-11-24

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
| 01 | [Developer page: the hotload recipe](DOC-HOTLOAD-RECIPE.md) | ✅ |
| 02 | [Rewrite the page for one copy per mission, fix the profile example](DOC-HOTLOAD-RECIPE.md) | ✅ |

## Out of scope

- Any build code: no `hotload:` key, no vendored copy of dcs-hotload.
- Reloading VEAF modules with hotload: its own README forbids reloading code that owns live objects.

## Closing

The recipe is checked against a mocked `lfs`/`env` under DCS's own `luae.exe`, not in game.
David closed the lot without an in-game test (2026-11-09); merged in #1257.
Ticket 02 reopened it on 2026-11-11: the rewritten boot script was checked under `luae.exe` against the real `dcs-hotload.lua` 3.1.0, and `hotload-setup.py` 3.1.0 was run on a VMCT-built `.miz` embedding it; the profile example was checked by building a test mission with and without `--profile DEV`. Still not tested in game.

## Tickets, in full

## 01 — Developer page: the hotload recipe

Status: ✅ done

A new page `doc/developer/hotload.md` and `hotload.en.md`, in the `nav` with its `nav_translations` entry, linked from the `custom_scripts` section of the `mission.yaml` reference.

### Done when

- The page holds the boot script `hotload-boot.lua`, which does nothing when dcs-hotload is absent or `io`/`lfs` are locked, and its `custom_scripts` block.
- It states the load order: `veaf-config.lua` → `mission-script.lua` → `custom_scripts`, so the VEAF modules are loaded when the boot script runs.
- It gives the per-mission variant, the root built from the mission's `sortie`.
- It warns that unlocking `io`/`lfs` in `MissionScripting.lua` applies to the whole DCS install.
- It states the two reservations: the F10 root holds ten entries and hotload takes one; VEAF modules are not reloaded with hotload.
- It says the recipe has not been tested in game yet.
- The boot script, extracted from the page, runs under `C:\jeux\DCS World\bin\luae.exe` against a mocked `lfs`/`env` with hotload present, absent, failing, and with `lfs` locked.
- `poetry run docs-check`, the support bot's page index and `test_backlog_status_consistency` pass.

## 02 — Rewrite the page for one copy per mission, fix the profile example

Status: ✅ done

Rewrite `doc/developer/hotload.md` and `hotload.en.md` to follow dcs-hotload's own model, as its author Flogas proposed on 2026-11-11: one copy of hotload in the mission folder, booted by the `custom_scripts` boot script from `VEAF_DYNAMIC_MISSIONPATH`, with no VMCT code.
And fix the `FgDebug.lua` example of `doc/MISSION_YAML_REFERENCE.md` (+ `.en.md`), which claimed a script declared only in a profile stays out of the default build.

### Done when

- Install: the release zip extracted into the mission folder, `dcs-hotload\` next to `mission.yaml`, and `user-f10\` (and the mailbox folders) created in it.
- Unlock: `hotload-setup.py unlock --dcs`, with the install-wide security warning kept.
- `status`: what it reports on a VMCT mission (`--miz <name>_<date>.miz`, the build dates its output in the mission folder), and that it cannot see our boot script, measured on a built `.miz`; `patch-miz` is not to be run.
- The boot script builds the copy's path from `VEAF_DYNAMIC_MISSIONPATH`, with or without a trailing `/` or `\`, sets `Hotload.root` to it, loads `dcs-hotload.lua`, and leaves nothing on screen when it fails: a `HOTLOAD: not booted:` line in `dcs.log`, as hotload's own trigger guard writes. The page says hotload runs in a dynamic build only, with nothing to remove from a static one. The `PER_MISSION` toggle and its section are gone.
- Load order, the no-reload rule for VEAF modules and the ten-entry F10 root are kept.
- The boot script, extracted from each page, runs under `C:\jeux\DCS World\bin\luae.exe` with the real `dcs-hotload.lua` 3.1.0: variable ending with `/`, `\` or neither, variable nil or empty, no `dcs-hotload\` folder, `io`/`lfs` locked in a static and a dynamic build, a raising `dcs-hotload.lua`, and no `user-f10\`; the "what was checked" table gives those cases.
- The `FgDebug.lua` example declares it in the base with `generate_load_trigger: false` and in the profile without; a real build of a test mission shows it loaded with `--profile DEV` only, in both the static triggers and the generated `veafDynamicConfig.lua`.
- `poetry run docs-check` and `test_backlog_status_consistency` pass.
