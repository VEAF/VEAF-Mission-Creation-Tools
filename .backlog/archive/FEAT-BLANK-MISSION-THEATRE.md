# Lot FEAT-BLANK-MISSION-THEATRE — synthesize a blank mission per theatre

Status: ✅ done (001-004 delivered, merged via PR #582; Caucasus DCS-load-verified by David. **005: extended to 9 theatres** (Caucasus, Afghanistan, GermanyCW, MarianaIslands(+WWII), Normandy, PersianGulf, SinaiMap, Syria) — `theatre-defaults.yaml` now **extracted from the calibration missions in VEAF/dcs-maps** `data/maps/*.miz` (MIT), parsed with our own `read_miz`, no code change. **DCS-load-verified by David on Caucasus + Normandy (WW2) + Syria (modern)** — the skeleton holds across maps/eras. The 5 maps dcs-maps lacks (Nevada/Kola/Falklands/TheChannel/Iraq) get a blank when Mitch adds them.)

Branch: `feature/blank-mission-theatre` → PR → `feature/mcp-mission-editor` (stacked on wave 9; reaches `develop` via the umbrella PR #575)

## Context

Starting a mission today requires the maker to supply a `.miz` **created in DCS** for the target
theatre: `prepare`'s next-steps message says literally *"place/extract your .miz into src/mission,
then validate and build."* Nothing ships a blank, and the wave-9 `scaffold_mission` produces a
folder whose `src/mission/` is empty — so the composites (`create_combat_zone`, …) have nothing to
edit until the maker hand-makes a mission in the ME.

A DCS `mission` lua carries **theatre-specific** values (theatre name, per-coalition bullseye, map
centre/zoom, default date/time/weather). **Decision (with David)**: rather than vendor real
ME-saved `.miz` per map, **synthesize** a minimal-but-valid blank in Python from a generic mission
skeleton plus a small per-theatre constants table (theatre name + a reference bullseye/centre, as
lightweight data — not `.miz` assets). Wire theatre selection into **`prepare --theatre`** (the
shared scaffolding primitive); `scaffold_mission` forwards a `theatre` parameter to it, so both the
CLI maker and the MCP get it from one implementation.

Independent of the wave-10 coordinate projection: the blank uses per-theatre reference constants
directly; projection is for *user* coordinate input, not for authoring the blank.

## Goal

`veaf-tools prepare --theatre <name>` lays down a ready-to-build `src/mission/` for that theatre,
so a fresh folder builds and accepts the composites with **zero DCS round-trip**.

## Tickets

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FEAT-BLANK-MISSION-THEATRE-001 | **Blank-mission generator**: `veaf_libs/blank_mission.py` — a generic DCS mission skeleton (complete enough to load: coalitions/countries stubs, triggers, map, date/time, weather) + a per-theatre constants table under `veaf_libs/data/theatre-defaults.yaml` (theatre name, reference bullseye, map centre). Emits the exploded `src/mission/` set (`mission`, `options`, `warehouses`, `theatre`, `l10n/DEFAULT/{dictionary,mapResource}`). Reuses `write_miz`/`create_miz` serialization where possible. TDD: generated output parses via `read_miz`, carries the right theatre + a bullseye, and builds. | `veaf_libs/blank_mission.py`, `veaf_libs/data/theatre-defaults.yaml`, `test/python/` | feat | ✅ |
| FEAT-BLANK-MISSION-THEATRE-002 | **`prepare --theatre <name>` + `--list-theatres`**: after copying the defaults, generate the theatre blank into `src/mission/` (skip/confirm if already populated, honouring `--force`). Unknown theatre → clear error listing the supported set. Localized FR/EN. TDD on the CLI path. | `veaf_tools/commands/prepare.py`, locales, `test/python/` | feat | ✅ |
| FEAT-BLANK-MISSION-THEATRE-003 | **`scaffold_mission(theatre=...)`**: forward an optional `theatre` to the `prepare` subprocess (`--theatre`). Backward compatible (omitted → today's behaviour, empty `src/mission/`). TDD on the forwarded arg. Depends on wave-9 `scaffold_mission` being merged. | `veaf_mission_mcp/scaffold.py`, `veaf_mission_mcp/actions.py`, `test/python/` | feat | ✅ |
| FEAT-BLANK-MISSION-THEATRE-004 | **Doc + defaults + CHANGELOG + bump**: prepare doc (FR/EN) + mission-maker guide + MCP catalogue/skill note (`scaffold_mission` can pick a theatre); CHANGELOG; version bump. | `doc/`, `CHANGELOG.md`, `pyproject.toml` | docs | ✅ |
| FEAT-BLANK-MISSION-THEATRE-005 | **Extend to all dcs-maps theatres**: regenerate `theatre-defaults.yaml` from the VEAF/dcs-maps `data/maps/*.miz` calibration missions (parsed with `read_miz`) — 9 theatres with real map centre + per-coalition bullseye. Generator unchanged; pure data. TDD: generates for a second theatre (Normandy). | `veaf_libs/data/theatre-defaults.yaml`, `test/python/` | feat | ✅ |

## Out of Scope

- Vendoring real ME-saved `.miz` per theatre (explicitly rejected — synthesize instead).
- Theatre-accurate map centre/zoom or realistic default weather beyond a sane, loadable default.
- Any coordinate conversion of the bullseye (uses the per-theatre reference constant directly;
  the wave-10 projection is for user input, not the blank).

## Open points

- **Minimal loadable skeleton**: the exact set of `mission` keys DCS needs to open a mission
  without error is empirical — ticket 001 pins it down against a real DCS load (manual check by
  David) and captures the skeleton as the generator's template.
- **Theatre constants**: seed the supported set (Caucasus, Syria, PersianGulf, MarianaIslands,
  Normandy, Sinai, Afghanistan — those already in projection/airfield data); the table grows by
  data as new maps are added.

---

## FEAT-BLANK-MISSION-THEATRE-001 — Blank-mission generator

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_libs/blank_mission.py`, `src/python/veaf-tools/veaf_libs/data/theatre-defaults.yaml`, `test/python/veaf_libs/test_blank_mission.py`

### What to build

A pure-Python generator that synthesizes a minimal, loadable DCS blank mission for a given theatre,
without any DCS round-trip:

- A **generic mission skeleton** — the set of `mission` keys DCS needs to open a mission without
  error (coalitions/countries stubs, `triggers`/`trig`/`trigrules`, `map`, `date`, `start_time`,
  `weather`, `result`, …), theatre-agnostic.
- A **per-theatre constants table** (`veaf_libs/data/theatre-defaults.yaml`): theatre name, a
  reference bullseye (DCS `x`/`y`), and map centre. Lightweight data, not a `.miz` asset.
- `generate_blank_mission(theatre) -> ...` emits the exploded `src/mission/` set: `mission`,
  `options`, `warehouses`, `theatre` (name), `l10n/DEFAULT/{dictionary,mapResource}`. Reuse the
  existing `write_miz`/`create_miz`/luadata serialization rather than hand-rolling Lua text.

### Acceptance criteria

- [ ] `read_miz` (or the folder reader) parses the generated output; `theatre` matches the request.
- [ ] The generated `mission` carries a per-coalition bullseye from the constants table.
- [ ] `veaf-tools build` succeeds on a folder using the generated `src/mission/` (empty of groups).
- [ ] Unknown theatre → clear error naming the supported set.
- [ ] ruff + mypy clean (full-tree; new module typed from the start — no exclusion).

### Open point

The exact minimal loadable key set is empirical — pin it against a real DCS load (manual check by
David) and freeze it as the skeleton. Start from an existing test mission's structure for reference.

---

## FEAT-BLANK-MISSION-THEATRE-002 — `prepare --theatre` + `--list-theatres`

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_tools/commands/prepare.py`, `veaf_libs/locales/{en,fr}.json`, `test/python/`

### What to build

Extend `prepare` so it can lay down a theatre blank:

- `--theatre <name>` — after copying the defaults, generate the theatre blank (ticket 001) into the
  folder's `src/mission/`. If `src/mission/` is already populated, follow the same
  ask/`--force`/`NEVER_OVERWRITE` policy the default-file copy uses.
- `--list-theatres` — print the supported set (from the constants table), mirroring
  `--list-templates`.
- Unknown theatre → clear localized error naming the supported set (before copying anything).
- No `--theatre` → today's behaviour unchanged (empty `src/mission/`, the next-steps hint still
  tells the maker to supply their own `.miz`).

### Acceptance criteria

- [ ] `prepare --theatre caucasus` on an empty folder produces a buildable `src/mission/`.
- [ ] `--list-theatres` lists the supported set.
- [ ] Unknown theatre → localized error, nothing written.
- [ ] `--theatre` composes with `--template` (both applied).
- [ ] FR + EN locale keys; TDD on the CLI path; ruff + mypy clean.

### Blocked by

FEAT-BLANK-MISSION-THEATRE-001.

---

## FEAT-BLANK-MISSION-THEATRE-003 — `scaffold_mission(theatre=...)`

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/scaffold.py`, `veaf_mission_mcp/actions.py`, `test/python/veaf_mission_mcp/test_scaffold.py`

### What to build

Add an optional `theatre` parameter to `scaffold_mission`, forwarded to the `prepare` subprocess as
`--theatre <name>`. When omitted, behaviour is unchanged (empty `src/mission/`, the maker supplies
their own `.miz`). Expose `theatre` in the action's parameter schema (optional).

So a from-scratch flow becomes: the LLM asks the maker for the **theatre** (and template), calls
`scaffold_mission(target_folder, template, theatre)`, and gets a folder that already builds and
accepts the composites.

### Acceptance criteria

- [ ] `theatre` given → `prepare` subprocess receives `--theatre <name>` (asserted in the mocked run).
- [ ] `theatre` omitted → no `--theatre` flag; existing tests still pass unchanged.
- [ ] Schema advertises `theatre` as optional; ruff + mypy clean.

### Blocked by

FEAT-BLANK-MISSION-THEATRE-002, and wave-9 `scaffold_mission` (FEAT-MCP-MISSION-EDITOR-029) merged.

---

## FEAT-BLANK-MISSION-THEATRE-004 — Doc + CHANGELOG + bump

Status: ✅ done
Type: docs
Files: `doc/mission-maker/`, `doc/developer/mission-editing-mcp.md` (+ `.en.md`), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (+ `.en.md`), `plugin/skills/veaf-mission-authoring/SKILL.md`, `CHANGELOG.md`, `pyproject.toml`

### What to build

- **Mission-maker guide / prepare doc** (FR + EN): document `prepare --theatre` / `--list-theatres`,
  and that a fresh folder no longer needs a hand-made `.miz` for the supported theatres.
- **MCP developer doc + catalogue + skill**: note that `scaffold_mission` accepts a `theatre`, and
  that the assistant should ask the maker which theatre (alongside the template) when starting from
  scratch.
- **CHANGELOG** under the current umbrella section; **bump** `pyproject.toml`.

### Acceptance criteria

- [ ] FR + EN docs in sync.
- [ ] Skill instructs asking theatre + template before scaffolding from scratch.
- [ ] CHANGELOG entry; version bumped; `poetry install` run.

### Blocked by

FEAT-BLANK-MISSION-THEATRE-001, 002, 003.

---

## FEAT-BLANK-MISSION-THEATRE-005 — Extend blank-mission to all dcs-maps theatres

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_libs/data/theatre-defaults.yaml`, `test/python/veaf_libs/test_blank_mission.py`

### What was built

Regenerated `theatre-defaults.yaml` from the calibration missions in
[VEAF/dcs-maps](https://github.com/VEAF/dcs-maps) `data/maps/*.miz` (MIT, Mitch), downloaded and
parsed with our own `read_miz` — extracting each theatre's real **map centre + zoom** and
**per-coalition bullseye** (not fabricated). Keys are the exact DCS `theatre` string.

**9 theatres**: Caucasus, Afghanistan, GermanyCW, MarianaIslands, MarianaIslandsWWII, Normandy,
PersianGulf, SinaiMap, Syria. The generator (`blank_mission.py`) is unchanged — pure data.

The 5 maps dcs-maps does not ship (Nevada, Kola, Falklands, TheChannel, Iraq) will get a blank when
Mitch adds them (coordinate conversion already covers all 14 via the projection export).

### Acceptance criteria

- [x] `supported_theatres()` returns the 9 dcs-maps theatres (DCS-spelled).
- [x] `generate_blank_mission` works for a second theatre (Normandy) — parses, correct theatre, no groups.
- [x] Caucasus test no longer pins the demo bullseye literal (tracks the vendored data).
- [x] ruff + mypy clean.

### Note

Values extracted once from the calibration missions; the `.miz` themselves are **not** vendored —
only the numeric constants. Regenerate by re-parsing updated dcs-maps missions.
