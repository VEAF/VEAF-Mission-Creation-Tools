# FIX-COMBATZONE-SPAWN-REFERENCE-UNIT — a zone measures a group's displacement against the wrong unit

Status: ⬜ ready

Found on 2026-08-21 while shipping
[`FIX-COMBATZONE-SPAWN-ROUTE-OFFSET`](../FIX-COMBATZONE-SPAWN-ROUTE-OFFSET/PRD.md), which needed to know
where the teleport delta actually comes from. Split out rather than folded in: it moves **where groups
appear**, which the route lot deliberately did not.

## The mismatch, read in the code

Two sides disagree about which unit represents a group.

| Side | Which unit | Source |
|---|---|---|
| The zone's element position | the **first unit the zone met** | `veafCombatZone.buildGroupElement(plainUnits[1], …)`, order from `pairs()` over `mist.getUnitsInZones` |
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

## What is proven and what is not

**Proven, by reading the code:** the two sides read different units, and the delta is applied to the
whole group. Neither is in doubt.

**Not measured:** how often the orders actually differ in game. `group:getUnits()` returns a sequence
and `pairs()` walks a sequence's array part in order in practice, so the two may coincide most of the
time — but this repository has already concluded that this order is not promised, which is exactly why
[`FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY`](../FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY/PRD.md) made tag reading
sort unit names alphabetically instead of trusting the encounter order. That lot fixed the tags and left
the **position** on the encounter order.

So: a real mismatch, of unmeasured frequency. Worth measuring before choosing a fix — a log line naming
both units when they differ would answer it in one mission.

## Options, none picked

1. **Take the position from the mission table's unit 1** — the same unit MiST uses, making the delta
   exactly the dispersion. Cheapest, and the delta becomes what everyone assumed it was.
2. **Pass `vars.groupData`** so the zone controls both sides of the subtraction rather than relying on
   them agreeing.
3. **Sort like the tags do** — alphabetical by unit name — for consistency with `#tag` reading. Fixes the
   *unpredictability* without making the delta equal the dispersion, so it is the weakest of the three.

Option 1 looks right, and it changes where existing missions' groups appear — which is why this is a lot
and not a line.

## Definition of done

- [ ] Measure it first: log both units when the element's position unit is not the mission table's unit 1
- [ ] Decide from the measurement, then implement
- [ ] Lua tests over the vars `spawnElement` builds, as its neighbours do
- [ ] Say so in the `veafCombatZone` doc if a group's spawn position visibly moves, both languages
