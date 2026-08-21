# FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT — the 50 m default dispersion has been unreachable since 2023

Status: 🧑 waiting-human

Written, unit-tested and shipped in 6.15.15. Waiting on one in-game look — 50 m of dispersion can drop a
unit into scenery, which no unit test can answer. Item 18 of
[DCS-SESSION-TODO.md](../../DCS-SESSION-TODO.md).

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

## What reviving it wakes up

Noted 2026-08-21. A dead default meant a zero teleport delta, which is why
[`FIX-COMBATZONE-SPAWN-ROUTE-OFFSET`](../FIX-COMBATZONE-SPAWN-ROUTE-OFFSET/PRD.md) — `spawnElement` sets
none of MiST's `offsetRoute`/`offsetWP1` — has been **invisible** for the same three years: there was no
displacement for the route to fail to follow. This fix supplies one, so a scattered group with a route
now walks back to an undisplaced waypoint 1 before starting its leg.

Not a reason to hold this lot: the leg is walked, not lost, and the 50 m default is the documented
intent. But the two want to ship close together, and item 18 of the session will see both at once.

**Corrected 2026-08-21, after the route lot measured where the delta comes from:** "invisible for three
years" is too strong. MiST measures the delta against the mission table's unit 1 while the zone's element
takes its position from the first unit it *met*, so a group met out of editor order carried a delta with
no dispersion at all — see
[`FIX-COMBATZONE-SPAWN-REFERENCE-UNIT`](../FIX-COMBATZONE-SPAWN-REFERENCE-UNIT/PRD.md). Reviving the
default makes the route defect systematic rather than making it appear.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Decide the default from whether the tag was written](tickets/01-decide-the-default-from-the-tag.md) | ✅ |
| 02 | [Say what a group with no tag does, and look at it in game](tickets/02-document-it-and-look-at-it-in-game.md) | 🧑 |

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
- [ ] Checked in game on a zone with a multi-unit group, since 50 m of dispersion can put a unit inside
      scenery — item 18 of `DCS-SESSION-TODO.md`
