# 01 — forget the role registry with the CAP watchdog

Status: ✅ done — #1080

`veafAircraftSpawn.forgetGroup(groupName)` clears the group's entry in `groupRoles`, `groupOptions` and `groupRoutes`.
`forgetCapWatchdog` (`src/scripts/veaf/veafSpawnAircraft.lua`) calls it, so every path where the watchdog stops watching a group — gone from DCS, no position, landed and destroyed, no controller — also forgets its role.
The other roles have no watchdog: `veafAircraftSpawn.forgetGoneGroups` forgets every group `Group.getByName` no longer answers, and runs on each spawn with a role (`spawnAirplaneGroup`, `spawnHelicopterGroup`, `VeafAircraftSpawn:spawn`).
`dcs_mocks.resetVeafRuntimeState` resets `groupRoutes` along with the other two.

## Acceptance

- Tests through `veafSpawn.startCapWatchdog` (`test/lua/test_veafSpawn.lua`): a CAP that landed and a CAP gone from DCS leave nothing in the three tables; both fail before the fix.
- Test through `spawnCombatAirPatrol` (`test/lua/test_veafAircraftSpawn.lua`): a spawn with a role forgets a group DCS no longer knows and keeps one it does.
- `poetry run test-lua` and `stylua --check` pass; `luacheck` in CI.
