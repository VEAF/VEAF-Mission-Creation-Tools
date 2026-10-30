# 01 — The module writes every shot, hit and kill

Status: ✅ done — 2026-10-30 (PR #1222)

`veafCombatLog` (module `COMBATLOG`): `S_EVENT_SHOT`, `S_EVENT_HIT`, `S_EVENT_KILL`, `S_EVENT_SHOOTING_START` and `S_EVENT_SHOOTING_END`, with the shooter (unit, type, group, coalition, player), the weapon and the target; a gun burst's rounds from the shells carried at its start and end. File `veaf-combat-log-<date>-<time>.jsonl` in `VEAF_EXPORT_DIR` or the DCS write folder.

On the way: the DCS mocks' event ids now match the vendored schema (17 to 31 were off, `S_EVENT_KILL` was missing).

Done when: `test_veafCombatLog.lua` covers each event, a burst's rounds, a vanished shooter, and a scripting environment without `io`.
