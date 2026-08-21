# FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT — the 50 m default dispersion has been unreachable since 2023

Status: ⬜ ready

Found on 2026-08-21 while writing the tests for
[FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY](../FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY/PRD.md), split out rather
than folded in: it changes where every group of every combat zone appears, which is a behaviour change
needing DCS, not a tag-reading fix.

## The defect

A zone element is created with `spawnRadius = 0` (`veafCombatZone.lua:154`), and the code that applies
the per-category default asks whether one was stated like this:

```lua
if not element:getSpawnRadius() then
  element:setSpawnRadius(veafCombatZone.DefaultSpawnRadiusForUnits) -- 50
end
```

**`not 0` is false in Lua.** The branch is never taken, so `DefaultSpawnRadiusForUnits = 50` is dead and
every group a combat zone spawns appears exactly on its recorded position, with no dispersion at all.
`#spawnradius=` still works — it is the only thing that does.

## Dated, not guessed

| Fact | Source |
|---|---|
| `DefaultSpawnRadiusForUnits = 50` exists | `5a43cc20`, 2020-05-16 |
| `objectToCreate.spawnRadius = 0` introduced | `5fd8257b`, 2023-03-04 |

So the default worked for the first three years and has been dead for the last three. Nothing caught it
because `test_defaultSpawnRadii` asserts the **constant**, never its application — the test and the
defect coexist happily.

## What has to be decided

Fixing it is one line (`spawnRadius = nil` in the constructor, or `== nil` in the two guards), but the
consequence is not one line: every existing mission's combat-zone groups start appearing up to 50 m
away from where they do today. That is the *documented* behaviour and arguably what a mission maker
expects, but three years of missions have been built and flown against 0.

Options, in order of preference:

1. **Restore the default.** Honest, matches the documentation, and dispersion is the point of the
   feature. Needs saying in the changelog loudly, since a battery placed against a treeline may move.
2. **Make the constant match reality** (`DefaultSpawnRadiusForUnits = 0`) and drop the dead branch.
   Cheapest, honest about what ships, and loses a feature nobody has had since 2023.
3. Leave it and document nothing — rejected, it is the current state and it is a lie in the code.

## Definition of done

- [ ] The constant and the behaviour agree, whichever way round
- [ ] A Lua test asserts the **applied** radius, not just the constant
- [ ] The documentation states what a group with no `#spawnradius=` does
- [ ] If option 1: checked in game on a zone with a multi-unit group, since 50 m of dispersion can put
      a unit inside scenery
