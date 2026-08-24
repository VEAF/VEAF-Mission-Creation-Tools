# 01 — Decide the default from whether the tag was written, not from the value it left behind

Status: ✅ done
Type: fix

David's arbitration, 2026-08-21: **restore the default**, and route it through
`DefaultSpawnRadiusForUnits` rather than a literal 50.

## The defect

`VeafCombatZoneElement:new` sets `spawnRadius = 0` (`veafCombatZone.lua:272`), and the code applying
the per-category default asks whether one was stated by looking at the value:

```lua
if not element:getSpawnRadius() then
  element:setSpawnRadius(veafCombatZone.DefaultSpawnRadiusForUnits) -- 50
end
```

`not 0` is **false** in Lua, so the branch never runs. `DefaultSpawnRadiusForUnits = 50` has been dead
since `5fd8257b` (2023-03-04), which introduced the `= 0`; the constant itself dates from `5a43cc20`
(2020-05-16). Every group a combat zone spawns therefore appears exactly on its recorded position, with
no dispersion.

## Why not simply make the constructor's default nil

Tempting — `alarmState` already uses nil for "not stated" — and wrong here, for two reasons found by
reading the consumers:

- `spawnElement` does `if zoneElement:getSpawnRadius() > 0` (`veafCombatZone.lua:1353`). A nil radius
  raises *attempt to compare nil with number*, and `buildCommandElement` applies no default at all, so
  every `#command` element would reach that line with nil.
- `#spawnradius=0` has to keep meaning **no dispersion**. Any scheme that treats 0 as "unstated" takes
  that away from the mission maker.

## The shape

The builder already knows whether the tag was written — it holds the collected tags — so the question
is answered from the tag's *presence*, not from the value left in the element:

```lua
if not tags.spawnRadius then
  element:setSpawnRadius(group.isStatic and veafCombatZone.DefaultSpawnRadiusForStatics or veafCombatZone.DefaultSpawnRadiusForUnits)
end
```

Exact, local, and it removes the misleading `if not element:getSpawnRadius()` guard entirely. The
constructor keeps `spawnRadius = 0`, so no consumer can ever see nil.

**`#command` elements stay at 0**, as they are today. A command element is a one-shot trigger that runs
a VEAF command *at its position*; scattering that position by 50 m would move what the command spawns,
which is a different behaviour change and not the one being asked for.

## Definition of done

- [x] A group with no `#spawnradius` gets `DefaultSpawnRadiusForUnits`
- [x] A static with no `#spawnradius` gets `DefaultSpawnRadiusForStatics`
- [x] `#spawnradius=0` still means no dispersion
- [x] `#spawnradius=200` still wins
- [x] A `#command` element still gets no dispersion
- [x] The Lua test asserts the **applied** radius, not just the constant — the gap that let this live
      for three years
