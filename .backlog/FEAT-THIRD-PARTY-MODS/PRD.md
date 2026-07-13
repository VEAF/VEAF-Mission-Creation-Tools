# Lot FEAT-THIRD-PARTY-MODS — strip third-party mod requirements at build

Status: ✅ done (merged #571, released in 6.9.1)

Branch: `feature/third-party-mods` → PR → `develop-v6`

## Context

In v5, each mission's own `build.cmd` stripped selected third-party aircraft mods from the
`.miz`'s `requiredModules` table, so a pilot **without** those paid/community mods could
still **load** the mission (they just can't take those specific slots). It was done with a
hardcoded block of `powershell -File replace.ps1 … "\[\"Hercules\"\] = \"Hercules\","` calls
— one per mod, copied by hand into every mission's `build.cmd` (e.g.
`VEAF-Open-Training-Mission-Caucasus-v5/build.cmd` lines 185-204: Hercules, UH-60L, A-4E-C,
T-45, AM2, `FlankerEx by Codename Flanker` (SU-30), Bronco-OV-10A). Because it lived in the
mission repos, not the toolkit, it was **never ported to v6**.

This lot ports the behaviour properly into the v6 build (`mission_builder`), as a data-driven
step instead of a hardcoded per-mission hack.

## Design (validated with David)

- A **bundled VEAF default list** of known third-party aircraft mods (initialised from the v5
  hack: Hercules, UH-60L, A-4E-C, T-45, AM2, `FlankerEx by Codename Flanker`, Bronco-OV-10A),
  applied automatically at build.
- **Overridable** via a new `mission.yaml` field **`mission.third_party_mods`** (a list). The
  field name deliberately says *mods* (DCS third-party add-ons), not *modules* (which in VEAF
  means capabilities under the `modules:` block — see `CONTEXT.md`). The field is **unioned**
  with the default list (it *adds* mods to strip — the common case being "I use a third-party
  aircraft not yet in the VEAF default"). No removal mechanism in v1 (the v5 hack had none;
  add later if a real need appears).
- At build, `mission_builder` removes every listed mod (default ∪ config) from the `.miz`'s
  `mission_content["requiredModules"]`, logging what was removed.

Deliberately **not** done: touching the units themselves (they stay — a pilot without the mod
sees the mission and just can't take that slot), nor blindly clearing `requiredModules` (a
genuinely required map/terrain mod is protected because it isn't in the list).

## User Stories

1. As a mission maker, I want a pilot who lacks a third-party aircraft mod to still load my
   mission, without me hand-editing a `build.cmd` — the VEAF default handles the common mods.
2. As a mission maker using a third-party aircraft not in the VEAF default, I want to list it
   in `mission.yaml` (`mission.third_party_mods`) so its requirement is stripped too.

## Tickets

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FEAT-THIRD-PARTY-MODS-001 | **Default list + stripper**: bundled `mission_builder/data/third_party_mods.json` (VEAF default list) + a pure function that removes a set of mod ids from a `requiredModules` dict, unioning the default with a passed-in list. TDD (removes listed, keeps others, empty/absent table, union). | `mission_builder/`, `mission_builder/data/`, `test/python/` | feat | ✅ |
| FEAT-THIRD-PARTY-MODS-002 | **Wire into the build**: read `mission.third_party_mods` from `mission.yaml`, call the stripper during the mission read→mutate→write in `mission_builder_worker.py`, log removed mods. Declare the optional field in the mission.yaml schema/validation if one exists. TDD on the worker path. | `mission_builder/mission_builder_worker.py`, schema, `test/python/` | feat | ✅ |
| FEAT-THIRD-PARTY-MODS-003 | **Doc + defaults lockstep + changelog**: document `mission.third_party_mods` in the `mission.yaml` doc (FR/EN), add a commented example to `src/defaults/mission-folder/mission.yaml`, CHANGELOG entry, version bump. | `doc/`, `src/defaults/mission-folder/mission.yaml`, `CHANGELOG.md`, `pyproject.toml` | docs | ✅ |

## Out of Scope

- Removing units/groups that depend on a stripped mod (they stay by design).
- A removal/opt-out mechanism for the default list (add later if needed).
- Any change to how `requiredModules` is produced by DCS (we only prune it at build).
