# FIX-SPAWNAIRCRAFT-UNGUARDED-GROUP — the same crash, on the aircraft spawn path

Status: ✅ done

Origin: found by the sweep of `FIX-COMBATMISSION-UNGUARDED-GROUP` (PR #872), which fixed the
identical defect in the combat mission. Verified independently on `develop`.

## The defect

`veafSpawnAircraft.lua` guards the VEAF object and then dereferences the DCS one five times
without checking it:

```lua
local _spawnedGroup = veaf.addGroup(newGroup)
if not _spawnedGroup then
  ...
  return nil                                   -- the VEAF table is guarded
end
...
local _dcsSpawnedGroup = Group.getByName(_spawnedGroup.name)
:trace(... veaf.lp(_dcsSpawnedGroup, ...))     -- nil-tolerant, by luck
:debug(... _dcsSpawnedGroup:getName())         -- line 1157 — raises on nil
for index, unit in pairs(_dcsSpawnedGroup:getUnits()) do   -- raises too
...
local controller = _dcsSpawnedGroup:getController()        -- line 1161 — NOT a log line
```

## Worse than its twin, for two reasons

The combat-mission version crashed only on trace lines: removing the logs would have removed the
crash. Here `getController()` is **functional code** — the guard is needed whatever happens to the
logging.

And this sits on the **aircraft spawn path**: `-spawn` of a CAP, a tanker, anything a player
summons from a marker in flight. The combat mission's version needed a mission to activate; this
one needs somebody to type a command.

## The detail worth keeping

The line immediately above already uses `veaf.lp`, which tolerates `nil` — the safe idiom was
right there and the next line did not use it. That is a copied pattern rather than an oversight
invented twice, which is also why a sweep found it.

## Definition of done

- [x] A `Group.getByName` returning `nil` no longer raises anywhere in this path
- [x] It says so — at `warning`, naming the group; a spawn that half-succeeded is worth a line
- [x] What the code does next is decided rather than defaulted: without a controller there is no
      route, no task and no behaviour, so returning early may well be the honest answer. Say which
      you chose
- [x] A test drives the nil case through the DCS mocks and fails without the fix — check it by
      removing the guard, as #872 did
- [x] `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean

## What was decided

**The function warns and returns `nil`.** Its twin carried on, because the combat mission had other
elements to activate and only *tracking* was lost. Here there is nothing to carry on with:
everything past the guard needs the DCS object. Without a controller `PROHIBIT_AA` is never applied,
and the CAP watchdog — what makes this a patrol rather than a group flying a straight line, since it
re-tasks the group onto targets — repeats the very same `Group.getByName` on its first tick and
stops. Scheduling it would have been a no-op with a misleading log, and announcing "a CAP has been
spawned" would have claimed something DCS cannot confirm.

So the failure is reported the way the function's two branches above already report theirs, and
nothing is handed back. The submission itself still happened and the aircraft may well be flying;
what VEAF cannot do is call it a CAP. The caller costs nothing either way — `veafSpawn.executeCommand`
already guards this same lookup before using the name it gets.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Guard the DCS group on the spawn path](tickets/01-guard-spawn-path.md) | fix |

## The rest of the sweep, not in this lot

PR #872 listed other unguarded dereferences, each deserving its own look:
`veafCasMission.lua:1042` (chained, right after a `veaf.addGroup` whose return is discarded — and
`addGroup` returns `false` on an unknown country or an empty unit list), `veafSpawnAircraft.lua`
216/255/706, `veafCarrierOperations.lua:107`, `veaf.lua:2199-2207`, `veafAirbases.lua:105` through
`veafWeather.lua:1258`, `veafSkynetIadsHelper.lua:348-350`, plus two guards testing the wrong
variable (`veafSanctuary.lua:767`, `veafMove.lua:856/864`). Left out on purpose: this lot is the
one that is functional code on a player-reachable path.
