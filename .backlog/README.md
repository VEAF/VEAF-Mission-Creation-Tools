# Backlog — VEAF Mission Creation Tools v6

Per-lot backlog. Active lots are directories under `.backlog/<LOT-ID>/`; completed
lots are compacted into `.backlog/archive/<LOT-ID>.md`. Sequencing lives in
[ROADMAP](../ROADMAP.md); this index is the source of truth for **scope and status**.

## Legend

- **Status**: ⬜ ready · 🔄 in-progress · 🧑 waiting-human · ✅ done · 🚫 wontfix

## Active lots

| Lot | Status |
|-----|--------|
| [FEAT-THIRD-PARTY-MODS](FEAT-THIRD-PARTY-MODS/PRD.md) — port the v5 per-mission `build.cmd` hack into the v6 build: strip selected third-party aircraft mods from the `.miz`'s `requiredModules` so a pilot without the paid/community mod can still load the mission (the slot is just unavailable). Data-driven — a bundled VEAF default list, unioned with an overridable `mission.third_party_mods` field | ⬜ |
| [FEAT-PRESETS-PRIORITY-COLOR](FEAT-PRESETS-PRIORITY-COLOR/PRD.md) — channel `priority` (universal kneeboard highlight; consumed by the AJS-37 layout to fill FR22 Special 1/2/3 + FR24 H) & `color` (kneeboard CH-cell grouping); AJS-37 key-based Group 100–139 packer with Group-100 recycle + `{priority}` specials; per-type kneeboards in `KNEEBOARD/<type>/IMAGES/` with grey headers + Viggen pilot labels. Extends [ADR 0012](../docs/adr/0012-channel-priority-colour-and-ajs37-packing.md); breaks 0003 iso-functionality for the AJS-37. Driver: Viggen (Tripack). convert-v5 out of scope | ✅ |
| [FIX-CONVERTV5-PRESETS-OUTPUT](FIX-CONVERTV5-PRESETS-OUTPUT/PRD.md) — cleaner generated `presets.yaml` (David's test feedback): uniform **integer** channel keys (was `'01'` strings in `channel_lists` vs `12` ints in overrides, with PyYAML octal-quoting `'01'` but not `08`), and **header comments** on the plan + faithful files (`_yaml_dump` gains an optional header) | ✅ |
| [FEAT-AIRFIELD-FREQS-DATA](FEAT-AIRFIELD-FREQS-DATA/PRD.md) — lot 2/3 of the convert-v5 preset-aliasing plan: extend `veaf-build update-dcs-data` to parse `Mods/terrains/<Theatre>/Radio.lua` into a bundled, versioned `airfield-frequencies.yaml` (`theatre → airfield → {uhf,vhf,fm}`), the data source for the freq→airfield reverse-lookup. Prerequisite for FEAT-CONVERTV5-FREQ-ALIASING | ✅ |
| [FEAT-CONVERTV5-FREQ-ALIASING](FEAT-CONVERTV5-FREQ-ALIASING/PRD.md) — lot 3/3 (extends ADR 0010): `convert-v5` replaces hardcoded preset frequencies with readable aliases — airfields (`Gudauta`, from lot 2) and VEAF flight/tactical conventions (`Archer`, `Guard`…) — via a `freq+band → alias` reverse-lookup, inserting the catalog into both output files; unmatched freqs stay raw. Includes the aircraft type-alias annex (`AH-64D → AH-64D_BLK_II`). Needs lot 2 | ✅ |
| [FEAT-RADIO-YAML-MENUS](FEAT-RADIO-YAML-MENUS/PRD.md) — declare F10 radio menus in YAML without Lua ([ADR 0011](../docs/adr/0011-radio-yaml-menus.md)). Two mechanisms sharing one action vocabulary (`qra.*`, `airwave.*`, `flag.*`, `message`, `lua`): a per-module `radio_menu` shortcut (QRA + AirWaves — the only triggerable subsystems with no standard menu) and a free `modules.RADIO.user_menus` Mission-Master tree, both optionally restricted to a DCS group. `lua` action references a maker function (build fails if absent). Reported by Tripack | ✅ |
| [DOC-TRIPACK-FEEDBACK](DOC-TRIPACK-FEEDBACK/PRD.md) — doc-only (direct commits): document the auto-managed carrier Pedro (rescue helo) & S3B-Tanker groups (naming convention `<carrier> Pedro` / `<carrier> S3B-Tanker`) in `veafCarrierOperations.md`; fix the stale `mission.yaml → qra:` reference in `veafQraManager.md` (QRA-in-YAML already works via `modules.QRA`). Reported by Tripack | ✅ |
| [FEAT-PRESETS-KNEEBOARD-TOGGLE](FEAT-PRESETS-KNEEBOARD-TOGGLE/PRD.md) — make `pipeline.presets` polymorphic (scalar *or* `{enabled, kneeboards}`) so kneeboard PNG generation can be disabled globally while keeping radio injection; add a discoverable "Configurer le pipeline" section to the MM GUIDE. Per-plate selection dropped. Reported by Tripack + David | ✅ |
| [FIX-MISSILEGUARDIAN-INIT-CRASH](FIX-MISSILEGUARDIAN-INIT-CRASH/PRD.md) — `MISSILEGUARDIAN: true` crashed VEAF start-up (`veafMissileGuardian.initialize()` called the never-defined `dumpMissionsList`), aborting `veaf-config.lua` and silently disabling the central F10 marker dispatcher (dead `_spawn`/shortcut aliases despite `SHORTCUTS: true`), plus CTLD/CSAR init. Also stopped auto-enabling the module (2021 WIP relic): removed from the `full` tier → opt-in only. Reported by Tripack | ✅ |
| [ENRICH-PREPARE-TEMPLATE](ENRICH-PREPARE-TEMPLATE/PRD.md) — `prepare --template` now emits the same rich `mission.yaml` preamble as `convert-v5` (YAML guide, `global_log_level`, `mission:`, `security:`, `pipeline:`) via shared helpers; `generate-config` output unchanged. Reported by Tripack | ✅ |
| [FIX-MIG15-PRIMARY-FREQ](FIX-MIG15-PRIMARY-FREQ/PRD.md) — build wrongly rejects the MiG-15bis HF primary frequency (RSI-6K 3.75 MHz, below the 30 MHz floor); the safety net is now spec-aware (`is_strict` + in-spec) while still catching ADF promotion (Yak-52 0.625 MHz). Reported by Tripack | ✅ |
| [FIX-EVENTHANDLER-UNITCATEGORY](FIX-EVENTHANDLER-UNITCATEGORY/PRD.md) — dynamic-slot airplane still ignored by the QRA unless `react_on_helicopters` true: `completeUnitFromName` populated `unitCategory` with `getCategory()` (Object.Category UNIT=1 collides with HELICOPTER), bypassing the #299 fix | ✅ |
| [FEAT-LUA-BUILD-STAMP](FEAT-LUA-BUILD-STAMP/PRD.md) — single build stamp (`6.7.x+<sha>`) in the DCS log instead of 33 unreliable per-module versions; retires the hand-maintained `.Version` constants | ✅ |
| [FIX-CTLD-REPACK-NIL-GROUP](FIX-CTLD-REPACK-NIL-GROUP/PRD.md) — CTLD F10 menu duplicated on dynamic-slot helo on a runtime FARP (`getUnitsInRepackRadius` nil `getGroup`) + analysis doc for the CTLD rewrite | ✅ |
| [FIX-QRA-DYNSLOT-CATEGORY](FIX-QRA-DYNSLOT-CATEGORY/PRD.md) — QRA triggers on dynamic-slot airplanes regardless of `react_on_helicopters` (#299: `getCategory`→`getCategoryEx`) | ✅ |
| [UX-PLURAL-SWEEP](UX-PLURAL-SWEEP/PRD.md) — natural singular/plural (`tn`) across all ~40 count-bearing CLI messages (FR/EN) | ✅ |
| [UX-PIPELINE-OUTPUT-POLISH](UX-PIPELINE-OUTPUT-POLISH/PRD.md) — `build` pipeline output: indent detail lines under each step + natural singular/plural (`tn`) | ✅ |
| [UX-AIRCRAFT-SKIPPED-REPORT](UX-AIRCRAFT-SKIPPED-REPORT/PRD.md) — `build` names the spawn-data file + reports aircraft skipped because already present | ✅ |
| [FIX-CONVERT-SPAWNABLES-FLAT-FORMAT](FIX-CONVERT-SPAWNABLES-FLAT-FORMAT/PRD.md) — `convert-v5` converts spawnable aircraft from the flat `settings.lua` layout (was: empty `spawnables.yaml`) | ✅ |
| [FEAT-MIGRATE-MISSION-V6](FEAT-MIGRATE-MISSION-V6/PRD.md) — promote `src/mission/` from v5 to v6 on disk | ✅ |
| [FIX-DYNSLOT-TEMPLATE-CATEGORY](FIX-DYNSLOT-TEMPLATE-CATEGORY/PRD.md) — airplane dynamic-slot templates miscategorized as helicopters | ✅ |
| [FEAT-RADIO-PRESET-PROJECTION](FEAT-RADIO-PRESET-PROJECTION/PRD.md) — per-type radio-preset projection (preset plan model): role-based `channel_lists` + VEAF `dcs-radio-layouts.yaml` + generator-overlay packer; convert-v5 generates a plan by default (ADR 0010). Phase 1 core + phase 2 convert-v5 | ✅ |
| [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) — broaden the shipped default radio presets (fold into / sequence after FEAT-RADIO-PRESET-PROJECTION phase 1) | ⬜ |
| [FEAT-EXPORT-BFR-PARSER](FEAT-EXPORT-BFR-PARSER/PRD.md) — `export` as the safe mission parser for the BFR plugin (`.miz`/folder, JSON array-ness contract) | ✅ |
| [TOOLING-DCS-MOCK-COVERAGE](TOOLING-DCS-MOCK-COVERAGE/PRD.md) — audit DCS-mock coverage against a vendored API schema | ✅ |
| [FIX-DCS-MOCKS-COMPLETION](FIX-DCS-MOCKS-COMPLETION/PRD.md) — fill the 10 DCS-mock gaps surfaced by `audit-dcs-mocks` | ✅ |
| [VENDORED-DRIFT-WATCH](VENDORED-DRIFT-WATCH/PRD.md) — scheduled drift-watch (manifest + check + cron→issue) for all vendored artifacts | ✅ |
| [FIX-CONVERTV5-ICAO-MESSAGE](FIX-CONVERTV5-ICAO-MESSAGE/PRD.md) — reword the `convert-v5` empty-ICAO notice (conversion succeeded + lightest fix first) | ✅ |
| [FIX-V5-NUDGE-FALSE-POSITIVE](FIX-V5-NUDGE-FALSE-POSITIVE/PRD.md) — stop the migrate_from_v5 nudge firing on already-promoted v6 missions (key discriminant) | ✅ |
| [FIX-CLI-UTF8-ASK-STREAMING](FIX-CLI-UTF8-ASK-STREAMING/PRD.md) — UTF-8 stdout (stop truncating `ask`/reports on Windows) + live `ask` streaming | ✅ |
| [FIX-BUILD-PROFILES](FIX-BUILD-PROFILES/PRD.md) — case-insensitive `--profile` (canonical name) + orphan warning gated on the base+profiles union | ✅ |
| [CONVERT-V5-UX](CONVERT-V5-UX/PRD.md) — triage leftover v5 files (tooling→backup, regenerable→delete, unrecognized→inform) + drop the misleading annotated-missionConfig report block + remove the leftover "missionConfig.lua edits" report noise | ✅ |
| [DOC-GUIDE-ANCHORS](DOC-GUIDE-ANCHORS/PRD.md) — fix the `mission.yaml` `# Doc:` deep links (trailing slash + stable explicit FR/EN anchors via `attr_list`) | ✅ |
| [FIX-CONVERT-WEATHER-I18N](FIX-CONVERT-WEATHER-I18N/PRD.md) — route 3 hardcoded-English convert-v5 weather/waypoints warnings through `t()` (FR/EN) | ✅ |
| [FIX-CLEANUP-EXCLUDE-TOOLCHAIN](FIX-CLEANUP-EXCLUDE-TOOLCHAIN/PRD.md) — stop the convert-v5 cleanup from listing `veaf-tools*.exe` as deletable "unrecognized" files | ✅ |
| [FEAT-CROSSPLATFORM-BINARIES](FEAT-CROSSPLATFORM-BINARIES/PRD.md) — ship standalone `veaf-tools` Linux/macOS binaries as extra release assets (per-OS CI jobs; Windows flow unchanged) + expose `veaf-tools.exe` as a direct asset | ✅ |
| [UPDATER-CROSSPLATFORM](UPDATER-CROSSPLATFORM/PRD.md) — port `veaf-tools-updater` to Linux/macOS (download per-OS binary assets, `chmod +x`, direct self-update; Windows path unchanged) | ✅ |
| [RELEASE](RELEASE/PRD.md) — v6.1.0 release | ⬜ |
| [FIX-PYINSTALLER-RADIO-LAYOUT-DATA](FIX-PYINSTALLER-RADIO-LAYOUT-DATA/PRD.md) — `veaf-tools.spec` was missing `dcs-radio-layouts.yaml` in `datas`, breaking `convert-v5` radio-preset conversion in the packaged `.exe` only. Reported by David | ✅ |
| [FIX-VEAF-BUILD-RADIO-LAYOUT-DATA](FIX-VEAF-BUILD-RADIO-LAYOUT-DATA/PRD.md) — the real fix: `veaf-tools.spec` is dead code, the actual build pipeline (`veaf_build/worker.py`) had the same missing `dcs-radio-layouts.yaml` entry. Reported by David | ✅ |
| [FEAT-CONVERTV5-PLAN-PRESETS](FEAT-CONVERTV5-PLAN-PRESETS/PRD.md) — convert-v5 emits two preset files: `presets.yaml` (simplified plan exploiting `channel_lists`, default/loaded) + `presets.v5.yaml` (faithful iso-functional copy, reference). Lets the maker actually use the crystallisation. Reported by David (ADR 0010) | ✅ |

## Archived lots

See [`archive/`](archive/). Index rows are added here as lots are archived.
