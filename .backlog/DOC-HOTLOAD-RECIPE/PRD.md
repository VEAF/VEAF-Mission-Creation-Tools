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

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Developer page: the hotload recipe](tickets/01-hotload-recipe-page.md) | ✅ |

## Out of scope

- Any build code: no `hotload:` key, no vendored copy of dcs-hotload.
- Reloading VEAF modules with hotload: its own README forbids reloading code that owns live objects.

## Closing

The recipe is checked against a mocked `lfs`/`env` under DCS's own `luae.exe`, not in game.
David closed the lot without an in-game test (2026-11-09); merged in #1257.
