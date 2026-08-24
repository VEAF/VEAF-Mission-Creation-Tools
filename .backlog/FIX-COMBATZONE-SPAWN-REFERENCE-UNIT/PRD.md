# FIX-COMBATZONE-SPAWN-REFERENCE-UNIT — a zone measures a group's displacement against the wrong unit

Status: ✅ done — shipped in 6.15.21

Found on 2026-08-21 while shipping
[`FIX-COMBATZONE-SPAWN-ROUTE-OFFSET`](../FIX-COMBATZONE-SPAWN-ROUTE-OFFSET/PRD.md), which needed to know
where the teleport delta actually comes from. Split out rather than folded in: it moves **where groups
appear**, which the route lot deliberately did not.

## The mismatch, read in the code

Two sides disagree about which unit represents a group.

| Side | Which unit | Source |
|---|---|---|
| The zone's element position | the **first unit the zone met** | `veafCombatZone.buildGroupElement(plainUnits[1], …)`, fed by `mist.getUnitsInZones`, which returns only the units **inside** the zone |
| MiST's displacement delta | the mission table's **unit 1** | `diff = newCoord - newGroupData.units[1]`, `mist.lua:4470`, over `mist.getGroupData(gpName)` |

`spawnElement` passes the first as `vars.point`. MiST subtracts the second from it, then applies the
result to **every** unit of the group.

When the two are the same unit, the delta is the dispersion and nothing else — the intended behaviour.
When they are not, the delta carries the **spacing between those two units** on top of it, and the whole
group is translated by it. A four-truck convoy spaced 30 m apart can therefore come up some 90 m from
where it was drawn, with `#spawnradius=0` written and no dispersion asked for.

`initialize` states the first half as a deliberate choice — *"a group's element takes its position and
coalition from the first of its units, as it always has"* — which it is. What nobody had noticed is that
MiST does not use the same unit as its origin, so the choice is not free.

## Measured, and the diagnosis in the paragraph above was wrong

This PRD was written saying the encounter order comes from `pairs()` and is therefore a lottery. **It is
not.** Read end to end, every step preserves order:

| Step | Ordering |
|---|---|
| `veaf.getUnitsNamesOfCoalition` | `table.insert` over `pairs(group:getUnits())` — a sequence, walked in array order |
| `mist.getUnitsInZones` | `for k = 1, #unit_names`, appending to `in_zone_units` — indexed, order-preserving |
| `findUnitsInCombatZone`, `initialize` | `table.insert` in encounter order |

So a group's units arrive **in editor order**. The mismatch has a single, deterministic trigger, and it
is not randomness:

> **`getUnitsInZones` only returns units inside the zone.** A group straddling the trigger zone's edge
> with its unit 1 *outside* hands over unit 2 as "the first one".

The group is still handled whole — one unit inside is enough for the zone to adopt, destroy and respawn
the entire group — so nothing warns that its anchor just moved a truck-length down the road.

**Measured rather than reasoned about**, by a test written before the fix: `buildGroupElement` handed
unit 2 of a convoy spaced 30 m apart produced an element at **1030** where unit 1 sits at **1000**. That
test failed on the unfixed tree and passes now.

`pairs()` over `group:getUnits()` remains a theoretical second source — the order of a sequence's array
part is an implementation property, not a promise — but it is not what makes this defect reachable.

## What shipped: option 1, expressed where it is testable

The position now comes from the group's **unit 1**, via a named helper
`veafCombatZone.referencePositionOf(unit, group)` rather than inline in `initialize`. Two reasons for the
helper, neither of them tidiness: the choice becomes a pure function a test can exercise directly (the
defect lived in a choice made inside `initialize`, which no test reached), and the reason it exists sits
next to the code that would otherwise look arbitrary.

It reads `Group.getByName(name):getUnit(1)` — the **runtime** unit 1 — rather than
`mist.getGroupData(name).units[1]`, which is the table MiST actually subtracts. Same unit, and it keeps
the position in runtime vec3 form, so nothing has to convert between the mission-table `{x, y}` and
runtime `{x, y, z}` conventions (`docs/agents/dcs-coordinates.md`). A conversion that produces no error
when wrong is not worth adding for an identical result.

A static is skipped: it is its own group of one, so the first unit met *is* unit 1, and there is no
`Group` to ask. When DCS hands back no unit 1, the helper falls back on the unit it was given and says so
in the log — an element with no position spawns nothing, which is worse than spawning thirty metres off.

Options 2 (`vars.groupData`) and 3 (sort like the tags) were not taken: 2 makes the zone own MiST's whole
group table to fix one coordinate, and 3 only makes the *wrong* anchor predictable.

## Definition of done

- [x] Measure it first — done by test rather than by an in-game log line: the trigger is deterministic
      (unit 1 outside the zone), so a mission was not needed to establish it
- [x] Decide from the measurement, then implement — option 1, anchored on unit 1
- [x] Lua tests — 8, one of which failed before the fix and passes after
- [x] Say so in the `veafCombatZone` doc, both languages
