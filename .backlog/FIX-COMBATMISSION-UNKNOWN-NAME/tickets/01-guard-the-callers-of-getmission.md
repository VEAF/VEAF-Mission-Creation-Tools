# 01 — Guard the callers of GetMission

Status: 🧑 waiting-human — the code is merged-ready; R39 is the in-game look

Type: fix · Files: `src/scripts/veaf/veafCombatMission.lua`, `test/lua/test_veafCombatMission.lua`

## What was done

`ActivateMission`, `DesactivateMission`, `GetInformationOnMission` and `CompletionCheck` return when
`GetMission` finds nothing. No warning is added in the callers: `GetMission` already logs the unknown
name at `error` level and puts it on screen, so a second line would say the same thing twice.

`DesactivateMissionNumber` now calls `GetMissionNumber`, like its twin `ActivateMissionNumber`.

## Tests

`TestVeafCombatMissionUnknownName` in `test/lua/test_veafCombatMission.lua`: the four callers with the
bare name of a CAP registered as `TEST-T17 CAP/good/2`, and `DesactivateMissionNumber(1)` reaching the
first registered mission's `desactivate`.
