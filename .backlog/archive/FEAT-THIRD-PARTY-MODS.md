# Lot FEAT-THIRD-PARTY-MODS — strip third-party mod requirements at build

Status: ✅ done (merged #571, released in 6.9.1)

Branch: `feature/third-party-mods` → PR → `develop`

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

---

## FEAT-THIRD-PARTY-MODS-001 — Default list + stripper

Status: ✅ done
Type: feat
Files: `mission_builder/`, `mission_builder/data/`, `test/python/`

### What to build

- A bundled data file `mission_builder/data/third_party_mods.json` holding the VEAF default
  list of third-party aircraft mod ids, initialised from the v5 hack:
  `Hercules`, `UH-60L`, `A-4E-C`, `T-45`, `AM2`, `FlankerEx by Codename Flanker`,
  `Bronco-OV-10A`. Loaded via `veaf_libs.bundled_data.read_bundled_text` (same pattern as
  `placeholder_groups.json`).
- A pure function (e.g. `strip_third_party_mods(mission_content, extra_mods) -> list[str]`)
  that removes every id in `(default ∪ extra_mods)` from
  `mission_content["requiredModules"]` (a `{modId: modName}` dict) and returns the list of
  ids actually removed. No-op when the table is absent/empty or holds none of the ids.

### Acceptance criteria

- [ ] Removes listed mods, keeps unlisted ones.
- [ ] Union: `extra_mods` adds to the default, does not replace it.
- [ ] Safe when `requiredModules` is missing, empty, or a non-dict — no crash.
- [ ] Returns exactly the ids removed (for the build log).
- [ ] TDD; ruff + mypy clean.

---

## FEAT-THIRD-PARTY-MODS-002 — Wire into the build

Status: ✅ done
Type: feat
Files: `mission_builder/mission_builder_worker.py`, mission.yaml schema, `test/python/`

### What to build

- Read `mission.third_party_mods` (optional list, default empty) from the loaded
  `mission.yaml` during the build.
- Call `strip_third_party_mods` (from ticket 001) on the mission table in the existing
  read → mutate → write sequence of `mission_builder_worker.py`, before `write_mission`.
- Log the removed mod ids (VEAF logger, i18n message; use `tn` for singular/plural if the
  count is surfaced).
- If a mission.yaml schema/validation declares the `mission:` block fields, add
  `third_party_mods` as an optional list there so a populated field doesn't fail validation.

### Acceptance criteria

- [ ] With no `mission.third_party_mods`, the VEAF default list is still applied.
- [ ] A mod listed only in `mission.third_party_mods` is stripped (union with default).
- [ ] `mission.yaml` carrying `third_party_mods` validates cleanly.
- [ ] Build logs which mods were stripped.
- [ ] TDD on the worker path; ruff + mypy clean.

### Blocked by

FEAT-THIRD-PARTY-MODS-001.

---

## FEAT-THIRD-PARTY-MODS-003 — Doc + defaults lockstep + changelog

Status: ✅ done
Type: docs
Files: `doc/`, `src/defaults/mission-folder/mission.yaml`, `CHANGELOG.md`, `pyproject.toml`

### What to build

- Document `mission.third_party_mods` in the mission.yaml documentation (FR + EN): what it
  is (DCS third-party aircraft mods to make non-blocking), that it unions with a VEAF default
  list, and the effect (mission loads without the mod; the slot is just unavailable).
- Add a commented `third_party_mods` example to `src/defaults/mission-folder/mission.yaml`
  under the `mission:` block (defaults lockstep).
- CHANGELOG `[Unreleased]` entry; PATCH version bump in `pyproject.toml` + `poetry install`.

### Acceptance criteria

- [ ] Doc updated FR + EN, mentioning the VEAF default list and the union semantics.
- [ ] Commented example present in the shipped default `mission.yaml`.
- [ ] CHANGELOG + version bump done.

### Blocked by

FEAT-THIRD-PARTY-MODS-001, FEAT-THIRD-PARTY-MODS-002.
