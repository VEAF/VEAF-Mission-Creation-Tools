# FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT — the 50 m default dispersion has been unreachable since 2023

Status: ✅ done · archived 2026-09-28

Verified in game on 2026-08-22, item 18 of `DCS-SESSION-TODO.md`: *« tout est comme prévu »*. The 50 m default dispersion applies and drops nothing into scenery, which is the one thing no unit test could answer.

Written, unit-tested and shipped in 6.15.15. Waiting on one in-game look — 50 m of dispersion can drop a
unit into scenery, which no unit test can answer. Item 18 of
[DCS-SESSION-TODO.md](../../DCS-SESSION-TODO.md).

Found on 2026-08-21 while writing the tests for
[FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY](FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY.md), split out rather
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

## What reviving it wakes up

Noted 2026-08-21. A dead default meant a zero teleport delta, which is why
[`FIX-COMBATZONE-SPAWN-ROUTE-OFFSET`](FIX-COMBATZONE-SPAWN-ROUTE-OFFSET.md) — `spawnElement` sets
none of MiST's `offsetRoute`/`offsetWP1` — has been **invisible** for the same three years: there was no
displacement for the route to fail to follow. This fix supplies one, so a scattered group with a route
now walks back to an undisplaced waypoint 1 before starting its leg.

Not a reason to hold this lot: the leg is walked, not lost, and the 50 m default is the documented
intent. But the two want to ship close together, and item 18 of the session will see both at once.

**Corrected 2026-08-21, after the route lot measured where the delta comes from:** "invisible for three
years" is too strong. MiST measures the delta against the mission table's unit 1 while the zone's element
takes its position from the first unit it *met*, so a group met out of editor order carried a delta with
no dispersion at all — see
[`FIX-COMBATZONE-SPAWN-REFERENCE-UNIT`](FIX-COMBATZONE-SPAWN-REFERENCE-UNIT.md). Reviving the
default makes the route defect systematic rather than making it appear.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Decide the default from whether the tag was written](FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT.md) | ✅ |
| 02 | [Say what a group with no tag does, and look at it in game](FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT.md) | 🧑 |

## The decision taken

**Option 1 — restore the default**, David 2026-08-21, *"on implémente les 50 m (enfin la constante)"*:
the behaviour comes back, and it comes back through `DefaultSpawnRadiusForUnits` rather than a literal
50, so the constant finally means something.

## And neither of the two one-line fixes this PRD proposed

The PRD offered `spawnRadius = nil` in the constructor or `== nil` in the guards. Reading the consumers
ruled both out:

- **`nil` in the constructor** breaks `spawnElement`, which does `if zoneElement:getSpawnRadius() > 0`
  (`veafCombatZone.lua:1353`) — *attempt to compare nil with number*. And `buildCommandElement` applies
  no radius default at all, so **every** `#command` element would arrive there with nil. That is a crash
  in the nominal path, not an edge case.
- **`== nil`, or any test on the value**, cannot tell "unstated" from `#spawnradius=0`. A mission maker
  who wants a group pinned to an exact spot would lose the only way of saying so.

What ships instead: the **builder** decides, from whether the tag was *written*. It holds the collected
tags, so the question has an exact local answer, and the misleading `if not element:getSpawnRadius()`
guard disappears rather than being patched:

```lua
if not tags.spawnRadius then
  element:setSpawnRadius(group.isStatic and veafCombatZone.DefaultSpawnRadiusForStatics or veafCombatZone.DefaultSpawnRadiusForUnits)
end
```

The constructor keeps `spawnRadius = 0`, so no consumer can ever see nil, and `#spawnradius=0` keeps
meaning "no dispersion".

**`#command` elements are left un-scattered on purpose.** The command runs *at its position*; giving it
50 m of dispersion would move whatever it spawns, which is a different change from the one asked for.
An explicitly written `#spawnradius=` still applies to them.

## What the options were

## Definition of done

- [x] The constant and the behaviour agree, whichever way round
- [x] A Lua test asserts the **applied** radius, not just the constant
- [x] The documentation states what a group with no `#spawnradius=` does
- [x] Checked in game on a zone with a multi-unit group, since 50 m of dispersion can put a unit inside
      scenery — item 18 of `DCS-SESSION-TODO.md`

---

## Tickets, in full

## 01 — Decide the default from whether the tag was written, not from the value it left behind

Status: ✅ done
Type: fix

David's arbitration, 2026-08-21: **restore the default**, and route it through
`DefaultSpawnRadiusForUnits` rather than a literal 50.

### The defect

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

### Why not simply make the constructor's default nil

Tempting — `alarmState` already uses nil for "not stated" — and wrong here, for two reasons found by
reading the consumers:

- `spawnElement` does `if zoneElement:getSpawnRadius() > 0` (`veafCombatZone.lua:1353`). A nil radius
  raises *attempt to compare nil with number*, and `buildCommandElement` applies no default at all, so
  every `#command` element would reach that line with nil.
- `#spawnradius=0` has to keep meaning **no dispersion**. Any scheme that treats 0 as "unstated" takes
  that away from the mission maker.

### The shape

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

### Definition of done

- [x] A group with no `#spawnradius` gets `DefaultSpawnRadiusForUnits`
- [x] A static with no `#spawnradius` gets `DefaultSpawnRadiusForStatics`
- [x] `#spawnradius=0` still means no dispersion
- [x] `#spawnradius=200` still wins
- [x] A `#command` element still gets no dispersion
- [x] The Lua test asserts the **applied** radius, not just the constant — the gap that let this live
      for three years

---

## 02 — Say what a group with no tag does, and look at it in game

Status: 🧑 waiting-human
Type: fix

Depends on [01](FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT.md).

### Documentation

Both `veafCombatZone.md` pages describe `#spawnradius=N` and say nothing about its absence — which was
harmless while the default was dead and is not any more. They need:

- what a group with no tag gets (`DefaultSpawnRadiusForUnits`), and what a static gets (0);
- that `#spawnradius=0` is how you ask for no dispersion;
- that a `#command` object is never scattered;
- a note that this **changes where existing missions' zone groups appear**, since three years of
  missions were built against no dispersion at all.

### In game

The one thing a unit test cannot answer: 50 m of dispersion can drop a unit into scenery — a building,
a treeline, a slope. `verify-mission-a` holds two multi-unit groups at a documented empty-desert anchor,
which is the cheapest place to look.

### Definition of done

- [x] Both language pages state the default, the `0` escape hatch and the `#command` exception
- [x] `poetry run docs-check` passes
- [x] `DCS-SESSION-TODO.md` carries the in-game item
- [ ] Looked at in game: a zone's groups are scattered and nothing lands inside scenery

---
