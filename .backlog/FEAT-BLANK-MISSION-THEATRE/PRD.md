# Lot FEAT-BLANK-MISSION-THEATRE — synthesize a blank mission per theatre

Status: ✅ done (001-004 delivered, merged via PR #582; Caucasus DCS-load-verified by David. **005: extended to 9 theatres** (Caucasus, Afghanistan, GermanyCW, MarianaIslands(+WWII), Normandy, PersianGulf, SinaiMap, Syria) — `theatre-defaults.yaml` now **extracted from the calibration missions in VEAF/dcs-maps** `data/maps/*.miz` (MIT), parsed with our own `read_miz`, no code change. The 5 maps dcs-maps lacks (Nevada/Kola/Falklands/TheChannel/Iraq) get a blank when Mitch adds them.)

Branch: `feature/blank-mission-theatre` → PR → `feature/mcp-mission-editor` (stacked on wave 9; reaches `develop-v6` via the umbrella PR #575)

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
