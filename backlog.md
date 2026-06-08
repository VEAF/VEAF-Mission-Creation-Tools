# Backlog — VEAF Mission Creation Tools v6

## Calibration Table

| Lot | Estimated (min) | Actual (min) | Ratio | Note |
|-----|----------------|--------------|-------|------|
| *(no lot completed yet)* | | | | Initial factor: 1.15 |
| Lot 6 — BONUS | 210 | — | — | LUA-006 + TOOL-004 + LUA-007 |

## Legend

- **Effort**: estimated Copilot time in minutes (excludes user decisions and review)
- **Type**: `feat` / `fix` / `chore`
- **Status**: `⬜` to do · `🔄` in progress · `✅` done

> Completed lots (> 3 days ago) are moved to [backlog-archive.md](backlog-archive.md).

---

## Summary

| Lot | Estimate | Status |
|-----|----------|--------|
| Phase 0 — Restart | ~3h | [archived](backlog-archive.md) |
| Phase 0b — GitHub cleanup | ~25 min | ⬜ |
| Lot RADIO-SPECS — DCS radio frequency validation | ~3h | ⬜ |
| Lot 1 — INFRA | ~4h15 | [archived](backlog-archive.md) |
| Lot 2 — CLI | ~2h35 | [archived](backlog-archive.md) |
| Lot 3 — TUI | ~2h20 | [archived](backlog-archive.md) |
| Lot 4 — LUA-CONFIG | ~6h | [archived](backlog-archive.md) |
| Lot 5 — RELEASE | ~1h30 | ⬜ |
| Lot 6 — BONUS | ~3h30 | [archived](backlog-archive.md) |
| Lot 7 — LUA FIXES | ~5h45 | [archived](backlog-archive.md) |
| Lot 8 — LUA-QUALITY | ~3h35 | [archived](backlog-archive.md) |
| Lot RC — v6.1.0 RC fixes | ~1h35 | [archived](backlog-archive.md) |
| Lot 9 — LUA-REFACTOR | ~11h30 | [archived](backlog-archive.md) |
| Lot 10 — YAML-CONFIG | ~14h | [archived](backlog-archive.md) |
| Lot 11 — I18N | ~7h10 | [archived](backlog-archive.md) |
| Lot 12 — QUALITY | ~16h35 | [archived](backlog-archive.md) |
| Lot 13 — DISCUSS | ~13h50 | [archived](backlog-archive.md) |
| Lot 14 — ARCH-COMMANDS | ~7h30 | [archived](backlog-archive.md) |
| Lot 15 — DOC | ~6h | [archived](backlog-archive.md) |
| Lot UPDATER-FIX | ~65 min | [archived](backlog-archive.md) |
| Lot 16 — LUA-COVERAGE | ~17h15 | [archived](backlog-archive.md) |
| Lot 17 — USER-CONFIG | ~3h | [archived](backlog-archive.md) |
| Lot 18 — VERSIONING | ~1h45 | [archived](backlog-archive.md) |
| Lot 19 — MIGRATOR | ~2h30 | [archived](backlog-archive.md) |
| Lot 20 — DEEPENING | ~7h | [archived](backlog-archive.md) |
| Lot 21 — TYPING | ~20 min | [archived](backlog-archive.md) |
| Lot 22 — TEST-LAYOUT | ~55 min | [archived](backlog-archive.md) |
| Lot 23 — DOC-YAML | ~8h20 | [archived](backlog-archive.md) |
| Lot 24 — DOC-REVIEW | ~2h45 | ⬜ (REV-002 pending) |
| Lot 25 — EXT-YAML | ~2h | [archived](backlog-archive.md) |
| Lot FIX-SORT — LUADATA FIX | ~15 min | [archived](backlog-archive.md) |
| Lot 26 — IMC-FEEDBACK | ~2h40 | [archived](backlog-archive.md) |
| Lot FIX-BUNDLE — VEAFCOMMANDS MISSING | ~10 min | [archived](backlog-archive.md) |
| Lot FIX-ASSETS-NEWLINE — ASSETS newline in Lua string | ~20 min | [archived](backlog-archive.md) |
| Lot FIX-WEATHER-ALIAS — missions.yaml + versions.yaml coexistence | ~25 min | [archived](backlog-archive.md) |
| Lot FIX-MISSIONCONFIG-BAK — remove unused .bak extension | ~20 min | [archived](backlog-archive.md) |
| Lot FIX-README-COPY — stop copying presets.md into src/ | ~10 min | [archived](backlog-archive.md) |
| Lot FIX-AIRCRAFT-ORPHAN — missing orphan-file warning for aircraft-templates.yaml | ~15 min | [archived](backlog-archive.md) |
| Lot DOC-DEV-MODE — document dev_mode + scripts_path | ~30 min | [archived](backlog-archive.md) |
| Lot FEAT-PROFILES — build profiles in mission.yaml | ~3h | [archived](backlog-archive.md) |
| Lot FEAT-MODULE-UX — module categories, mandatory modules, dependencies | ~2h | [archived](backlog-archive.md) |
| Lot FEAT-GITIGNORE — VEAF MCT .gitignore template in defaults | ~25 min | [archived](backlog-archive.md) |
| Lot FIX-OLDSCRIPTS — detect residual .lua files in src/scripts/ | ~45 min | [archived](backlog-archive.md) |
| Lot FIX-MARKERS-INIT — add missing `veafMarkers.initialize()` | ~5 min | [archived](backlog-archive.md) |
| Lot FIX-MISSING-INIT — missing `initialize()` on 4 Lua modules | ~20 min | [archived](backlog-archive.md) |
| Lot 27 — DOC-FR-MERGE | ~6h | [archived](backlog-archive.md) |
| Lot FIX-YAML-SYNTAX — unhandled YAML error in build and mission_builder_worker | ~15 min | [archived](backlog-archive.md) |
| Lot FIX-MANDATORY-ENABLE — block enable on mandatory modules | ~20 min | [archived](backlog-archive.md) |
| Lot FEAT-CUSTOM-SCRIPTS — custom_scripts section in mission.yaml | ~45 min | ✅ |
| Lot FIX-REMOVE-CONVERT — remove the `convert` command | ~20 min | [archived](backlog-archive.md) |
| Lot FIX-MISSIONCONFIG-REFS — references to `missionConfig.lua` in doc and code | ~30 min | [archived](backlog-archive.md) |
| Lot FEAT-DCS-BRIDGE — Optional dcs-bridge.lua injection | ~1h30 | [archived](backlog-archive.md) |
| Lot FIX-MANDATORY-YAML — YAML generators: emit `{}` for mandatory modules instead of `enable: true` | ~35 min | [archived](backlog-archive.md) |
| Lot CMT-YAML-DOCS — doc comments and links in generated `mission.yaml` files | ~45 min | [archived](backlog-archive.md) |
| Lot FIX-AIRCRAFT-DUPLICATE — Duplicate aircraft groups in "add" injection mode | ~20 min | [archived](backlog-archive.md) |
| Lot FIX-I18N-CONVERT-V5 — Hardcoded English messages in convert-v5 | ~30 min | ✅ |
| **Total** | **~179h15** | |

*Initial calibration factor: 1.15 — recalculate after each completed lot.*

---

## Lot FEAT-CUSTOM-SCRIPTS — custom_scripts section in mission.yaml

**Goal**: Allow declaring custom Lua scripts in `mission.yaml` to suppress warnings and control the generation of the DCS load trigger.

**Branch**: `feature/custom-scripts` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CUSTOM-001 | Add `CustomScript` dataclass + parse `custom_scripts` in `__init__` | `mission_builder_worker.py` | feat | 10 min | 🔄 |
| CUSTOM-002 | Update warning logic (declared = info, unknown = warning with hint) | `mission_builder_worker.py` | feat | 10 min | 🔄 |
| CUSTOM-003 | Filter load triggers according to `generate_load_trigger` | `mission_builder_worker.py` | feat | 10 min | 🔄 |
| CUSTOM-004 | TDD tests (warnings + trigger resolution) | `test_mission_builder_defaults.py` | test | 10 min | 🔄 |
| CUSTOM-005 | Document the section in the default `mission.yaml` | `src/defaults/mission-folder/mission.yaml` | doc | 5 min | 🔄 |

---

## Lot 24 — DOC-REVIEW: Klogg profile (REV-002)

**Goal**: Commit the VEAF Klogg profile to the repo to ease DCS log reading.

**Context**: All other REV-* tickets from Lot 24 are archived. REV-002 is waiting for the user to provide the `.conf` file.

**Branch**: `fix/doc-review-klogg` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| REV-002 | Commit the Klogg profile provided by the user to `tools/klogg/veaf.conf`; update the "Reading the log" section in `GUIDE.md` and `GUIDE.fr.md` to point to this file | `tools/klogg/veaf.conf`, `doc/mission-maker/GUIDE.md`, `doc/mission-maker/GUIDE.fr.md` | chore | 20 min | ⬜ |

---

## Phase 0b — GitHub cleanup

Close issues identified during triage. **Verify each one before closing.**
Direct commits on `develop-v6` (no feature branch needed — no code change).

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| CLOSE-001 | Close WONTFIX issues: #55, #146, #147, #180, #193, #246 | chore | 15 min | ⬜ |
| CLOSE-002 | Close STALE issues: #9, #19, #41, #167 | chore | 10 min | ⬜ |

<details>
<summary>Issues to close</summary>

**WONTFIX — Already implemented or out of scope**

| # | Title | Reason |
|---|-------|--------|
| #55 | Faire un système de zone de combat dynamique | Already implemented → `veafCombatZone` |
| #146 | CTLD JTAC 9-line | External project (CTLD/Ciribob) |
| #147 | CTLD JTAC Ask for wind/speed correction | External project (CTLD/Ciribob) |
| #180 | AirWaves - forcer à rester dans la zone | Both tasks already checked ✅ in the issue |
| #193 | CTLD - gestion d'emport multiple de caisses | Requires upstream PR to CTLD, out of scope |
| #246 | CTLD - orientation des unités Patriot | CTLD external bug, out of scope |

**STALE — No activity, too vague, or superseded**

| # | Title | Reason |
|---|-------|--------|
| #9 | Marker command to build a transport mission interception | 2018, no activity since 2021, too vague |
| #19 | Idée - spawn facile avec inventaire des unités par coalition | 2020, informal idea, no spec |
| #41 | Tester spawn humains CASE 1 téléportés à la bonne position | 2021, vague, no activity |
| #167 | Tester gRPC | 2023 tech spike, no follow-up planned |

</details>

---

## Lot 5 — RELEASE: v6.1.0

**Goal**: Merge v6 to master and publish the official release.
**From**: `develop-v6` directly

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| REL-001 | Finalize `CHANGELOG.md` for v6.1.0 | chore | 20 min | Lots 1–4 | ⬜ |
| REL-002 | Write `RELEASE_NOTES.md` for v6.1.0 | chore | 20 min | REL-001 | ⬜ |
| REL-003 | Squash merge `develop-v6` → `master` | chore | 15 min | REL-002 | ⬜ |
| REL-004 | Tag `v6.1.0` + publish GitHub (`veaf-build publish`) | chore | 30 min | REL-003 | ⬜ |

**Estimated total: ~85 min (~1h30)**

---

## Lot RADIO-SPECS — DCS radio frequency validation in inject-presets

**Goal**: Extract DCS aircraft radio frequency specs from `dcs-lua-datamine`, bundle them as a YAML data file, validate preset frequencies at inject time, and publish a human-readable reference doc.
**Branch**: `feature/radio-specs-validation`

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| RADIO-001 | Extraction script: fetch `panelRadio` from dcs-lua-datamine and generate `dcs-radio-specs.yaml` | feat | 45 min | ⬜ |
| RADIO-002 | Bundle `dcs-radio-specs.yaml` as package data; load via `importlib.resources` | feat | 15 min | ⬜ |
| RADIO-003 | `RadioFrequencyValidator`: validate preset frequencies against aircraft specs, warn on mismatch | feat | 45 min | ⬜ |
| RADIO-004 | Integrate validator into `PresetsInjectorWorker.process_groups()` | feat | 20 min | ⬜ |
| RADIO-005 | Generate `doc/mission-maker/dcs-radio-specs.md` (human-readable Markdown table) from the YAML | feat | 30 min | ⬜ |
| RADIO-006 | Unit tests for validator (valid/invalid frequency, unknown aircraft, partial ranges) | feat | 45 min | ⬜ |

**Estimated total: ~3h**

---

