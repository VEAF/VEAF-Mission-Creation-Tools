# Backlog — VEAF Mission Creation Tools v6

Per-lot backlog. Active lots are directories under `.backlog/<LOT-ID>/`; completed
lots are compacted into `.backlog/archive/<LOT-ID>.md`. Sequencing lives in
[ROADMAP](../ROADMAP.md); this index is the source of truth for **scope and status**.

## Legend

- **Status**: ⬜ ready · 🔄 in-progress · 🧑 waiting-human · ✅ done · 🚫 wontfix

## Active lots

| Lot | Status |
|-----|--------|
| [FIX-CTLD-REPACK-NIL-GROUP](FIX-CTLD-REPACK-NIL-GROUP/PRD.md) — CTLD F10 menu duplicated on dynamic-slot helo on a runtime FARP (`getUnitsInRepackRadius` nil `getGroup`) + analysis doc for the CTLD rewrite | 🔄 |
| [FIX-QRA-DYNSLOT-CATEGORY](FIX-QRA-DYNSLOT-CATEGORY/PRD.md) — QRA triggers on dynamic-slot airplanes regardless of `react_on_helicopters` (#299: `getCategory`→`getCategoryEx`) | ✅ |
| [UX-PLURAL-SWEEP](UX-PLURAL-SWEEP/PRD.md) — natural singular/plural (`tn`) across all ~40 count-bearing CLI messages (FR/EN) | ✅ |
| [UX-PIPELINE-OUTPUT-POLISH](UX-PIPELINE-OUTPUT-POLISH/PRD.md) — `build` pipeline output: indent detail lines under each step + natural singular/plural (`tn`) | ✅ |
| [UX-AIRCRAFT-SKIPPED-REPORT](UX-AIRCRAFT-SKIPPED-REPORT/PRD.md) — `build` names the spawn-data file + reports aircraft skipped because already present | ✅ |
| [FIX-CONVERT-SPAWNABLES-FLAT-FORMAT](FIX-CONVERT-SPAWNABLES-FLAT-FORMAT/PRD.md) — `convert-v5` converts spawnable aircraft from the flat `settings.lua` layout (was: empty `spawnables.yaml`) | ✅ |
| [FEAT-MIGRATE-MISSION-V6](FEAT-MIGRATE-MISSION-V6/PRD.md) — promote `src/mission/` from v5 to v6 on disk | ✅ |
| [FIX-DYNSLOT-TEMPLATE-CATEGORY](FIX-DYNSLOT-TEMPLATE-CATEGORY/PRD.md) — airplane dynamic-slot templates miscategorized as helicopters | 🔄 |
| [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) — broaden the shipped default radio presets | ⬜ |
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
| [FIX-CLEANUP-EXCLUDE-TOOLCHAIN](FIX-CLEANUP-EXCLUDE-TOOLCHAIN/PRD.md) — stop the convert-v5 cleanup from listing `veaf-tools*.exe` as deletable "unrecognized" files | 🔄 |
| [RELEASE](RELEASE/PRD.md) — v6.1.0 release | ⬜ |

## Archived lots

See [`archive/`](archive/). Index rows are added here as lots are archived.
