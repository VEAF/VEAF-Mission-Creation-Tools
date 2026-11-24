# FIX-COMBATMISSION-UNKNOWN-NAME — an unknown combat mission name raises a Lua error

Status: ✅ done — merged in #1060, seen in game 2026-10-03 (R39, session d) · archived 2026-11-24
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
| 01 | [Guard the callers of GetMission](FIX-COMBATMISSION-UNKNOWN-NAME.md) | fix | ✅ |

## Definition of done

- [x] A failing luaunit test for each of the four callers with an unknown name, and for
      `DesactivateMissionNumber` — all five raised exactly the DCS error before the fix
- [x] The callers return without raising; the unknown name is still reported by `GetMission`
- [x] `DesactivateMissionNumber` uses `GetMissionNumber`
- [x] Seen in game — R39 (2026-10-03)

## Tickets, in full

## 01 — Guard the callers of GetMission

Status: ✅ done — R39 run 2026-10-03: activate, deactivate, describe and completion check on `TEST-T17 CAP` each show "introuvable !" with no Lua error; deactivating number 9999 is silent

Type: fix · Files: `src/scripts/veaf/veafCombatMission.lua`, `test/lua/test_veafCombatMission.lua`

### What was done

`ActivateMission`, `DesactivateMission`, `GetInformationOnMission` and `CompletionCheck` return when
`GetMission` finds nothing. No warning is added in the callers: `GetMission` already logs the unknown
name at `error` level and puts it on screen, so a second line would say the same thing twice.

`DesactivateMissionNumber` now calls `GetMissionNumber`, like its twin `ActivateMissionNumber`.

### Tests

`TestVeafCombatMissionUnknownName` in `test/lua/test_veafCombatMission.lua`: the four callers with the
bare name of a CAP registered as `TEST-T17 CAP/good/2`, and `DesactivateMissionNumber(1)` reaching the
first registered mission's `desactivate`.
