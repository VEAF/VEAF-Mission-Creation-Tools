# FIX-COMBATMISSION-UNKNOWN-NAME — an unknown combat mission name raises a Lua error

Status: ✅ done — merged in #1060, seen in game 2026-10-03 (R39, session d)
[`DCS-SESSION-TODO.md` item **R39**](../../DCS-SESSION-TODO.md)

Measured in DCS on 2026-10-03 (session `dcs-session-2026-10-03c`, GermanyCW):
`veafCombatMission.ActivateMission("TEST-T17 CAP", true)` raised
`attempt to index local 'mission' (a nil value)`.

## Why

An on-demand CAP declared through `cap_missions:` is registered **per variant**, as
`<name>/<skill>/<size>` (`TEST-T17 CAP/good/2`), so its bare name is not in
`veafCombatMission.missionsDict`. `GetMission` already reports an unknown name — an `error` log line
and an on-screen "mission not found" message, both naming it — and returns `nil`. Four callers then
indexed that `nil` without a check: `ActivateMission`, `DesactivateMission`,
`GetInformationOnMission` and `CompletionCheck`.

`DesactivateMissionNumber` had a worse variant of the same family: it looked its **number** up with
`GetMission`, which calls `name:lower()`, so it raised `attempt to index local 'name' (a number value)`
on every call, whatever the number.

## Scope

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | [Guard the callers of GetMission](tickets/01-guard-the-callers-of-getmission.md) | fix | ✅ |

## Definition of done

- [x] A failing luaunit test for each of the four callers with an unknown name, and for
      `DesactivateMissionNumber` — all five raised exactly the DCS error before the fix
- [x] The callers return without raising; the unknown name is still reported by `GetMission`
- [x] `DesactivateMissionNumber` uses `GetMissionNumber`
- [x] Seen in game — R39 (2026-10-03)
