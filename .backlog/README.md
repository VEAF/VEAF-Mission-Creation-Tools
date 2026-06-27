# Backlog — VEAF Mission Creation Tools v6

Per-lot backlog. Active lots are directories under `.backlog/<LOT-ID>/`; completed
lots are compacted into `.backlog/archive/<LOT-ID>.md`. Sequencing lives in
[ROADMAP](../ROADMAP.md); this index is the source of truth for **scope and status**.

## Legend

- **Status**: ⬜ ready · 🔄 in-progress · 🧑 waiting-human · ✅ done · 🚫 wontfix

## Active lots

| Lot | Status |
|-----|--------|
| [FEAT-MIGRATE-MISSION-V6](FEAT-MIGRATE-MISSION-V6/PRD.md) — promote `src/mission/` from v5 to v6 on disk | ✅ |
| [FIX-DYNSLOT-TEMPLATE-CATEGORY](FIX-DYNSLOT-TEMPLATE-CATEGORY/PRD.md) — airplane dynamic-slot templates miscategorized as helicopters | 🔄 |
| [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) — broaden the shipped default radio presets | ⬜ |
| [FEAT-EXPORT-BFR-PARSER](FEAT-EXPORT-BFR-PARSER/PRD.md) — `export` as the safe mission parser for the BFR plugin (`.miz`/folder, JSON array-ness contract) | ✅ |
| [TOOLING-DCS-MOCK-COVERAGE](TOOLING-DCS-MOCK-COVERAGE/PRD.md) — audit DCS-mock coverage against a vendored API schema | ✅ |
| [VENDORED-DRIFT-WATCH](VENDORED-DRIFT-WATCH/PRD.md) — scheduled drift-watch (manifest + check + cron→issue) for all vendored artifacts | ⬜ |
| [FIX-CONVERTV5-ICAO-MESSAGE](FIX-CONVERTV5-ICAO-MESSAGE/PRD.md) — reword the `convert-v5` empty-ICAO notice (conversion succeeded + lightest fix first) | ✅ |
| [RELEASE](RELEASE/PRD.md) — v6.1.0 release | ⬜ |

## Archived lots

See [`archive/`](archive/). Index rows are added here as lots are archived.
