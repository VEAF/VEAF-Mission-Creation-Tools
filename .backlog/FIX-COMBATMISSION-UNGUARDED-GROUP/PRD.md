# FIX-COMBATMISSION-UNGUARDED-GROUP — an activation that can crash on its own log line

Status: ⬜ ready

Origin: found while delivering `FIX-COMBATMISSION-SPAWNCHANCE-OFFSET` (PR #864). Verified on
`develop`.

## The defect

`veafCombatMission.lua`, around line 923:

```lua
local _spawnedGroup = veaf.addGroup(_group)
if _spawnedGroup then
  veaf.loggers.get(...):trace(... veaf.p(_spawnedGroup.name))
  local _dcsSpawnedGroup = Group.getByName(_spawnedGroup.name)
  veaf.loggers.get(...):trace(... veaf.p(_dcsSpawnedGroup:getName()))   -- no guard
  for _, unit in pairs(_dcsSpawnedGroup:getUnits()) do                  -- no guard
```

The `if _spawnedGroup then` guards the VEAF object; it says nothing about what `Group.getByName`
returns. If DCS answers `nil` for a group created moments earlier, the activation raises on a
**trace line** — the mission loses its combat mission for the sake of a log.

Not theoretical: it is what forced the tests of #864 to record the cloned name in the DCS mocks
rather than let `getByName` answer naturally.

## Definition of done

- [ ] An activation where `Group.getByName` returns `nil` completes instead of raising
- [ ] It says something — a group that vanished between creation and lookup is worth a warning, not
      a shrug
- [ ] The trace lines keep working when the group is there
- [ ] A test drives the nil case through the mocks and fails without the fix
- [ ] `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean

## Look around while you are there

The same pattern — a `trace` call dereferencing the result of a DCS lookup that was never checked —
may well appear elsewhere in this file or its siblings. A trace line is the last place anyone
expects a crash, which is exactly why they survive. Sweep the file and report what you find, even
what you choose to leave.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Guard the group lookup](tickets/01-guard-group-lookup.md) | fix |
