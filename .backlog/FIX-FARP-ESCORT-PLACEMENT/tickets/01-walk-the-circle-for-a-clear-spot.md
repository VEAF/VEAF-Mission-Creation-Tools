# 01 — Walk the escort around the circle until the ground is clear

Status: ✅ done
Type: fix

Closes [#232](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/232) (Sharko, 2023),
reproduced in game by David on 2026-08-17.

## The defect

`-farp` spawns the FARP plus an escort group, whose position is computed from a **fixed distance and
bearing** with no test of whether that spot is free
([`veafGrass.lua:1267-1270`](../../../src/scripts/veaf/veafGrass.lua:1267)).

Placed beside a static FARP — which is **the nominal use**, since the static FARP is what unlocks
spawning on it once the zone is captured — the escort lands on its pads. Measured: David's marker was
~150 m from the static FARP, and the trucks came down on it, the lead `M 818` close enough to a helipad
that a helicopter landing there meets it.

## The fix, as arbitrated by David

**Keep the radius, move the bearing.** Walk around the circle until the ground is clear. Not "increase
the radius": that pushes the escort away from the FARP it serves, and in a campaign the crew wants it
close.

## What had to be decided while implementing

**What counts as occupied — `veaf.findSpawnPoint` cannot answer this.** Checked rather than assumed, as
the PRD asked. Two reasons it does not fit: its scenery-aware tier avoids *buildings and forests* via
`Disposition`, not mission objects, so a static FARP placed in the editor is invisible to it; and it
**moves a point within a circle**, which is the opposite of keeping the radius and changing the bearing.
There is no `world.searchObjects` anywhere in this repository, so occupancy is new ground here.

**The escort is a group, not a point.** Five vehicles at 6 m spacing occupy a ~30 m segment
perpendicular to the bearing. Testing the origin alone would move the group so its tail still overlaps,
so **every unit position** is tested for a candidate bearing, and a bearing is accepted only if all of
them are clear.

**The original bearing is tried first.** A FARP that is already well placed does not move, so this
cannot regress a working mission — the walk only happens when the ground is actually occupied.

**Failure keeps the FARP.** If no bearing on the circle is clear, the original one is used and the
reason is logged. A FARP that refuses to exist because it is crowded would be worse than one whose
escort is tight.

## Same pattern, same fix

The tent, the other props and the windsock are placed by the identical formula at their own distances
(`tentDistance`, `otherDistance`, `windsockDistance`). The PRD said: if they overlap too, they are the
same fix. They can, so they get it — and since the original bearing is tried first, a FARP with nothing
in its way is byte-for-byte where it was.

Consequence worth stating: the tent and the escort may end up on **different** bearings, where before
they shared one. That is the price of not putting anything on top of an obstacle, and it is deliberate.

## Deliberately left out, so it is not mistaken for an oversight

**The windsock is not moved.** The PRD named the tent and the other props, not the windsock; it was
never measured as overlapping; it is a single small object; and its geometry is constrained by a second
windsock at 90° on the `FARP` type. Moving it would be a guess with a regression risk and no reported
symptom.

**The `Invisible FARP` markers are not moved either** — those two vehicles sit 25 m out precisely to
show where an otherwise invisible FARP is. Displacing them would defeat their purpose.

## Definition of done

- [x] An `-farp` next to a static FARP puts its escort on clear ground, close to the FARP
- [x] The same call far from anything is unchanged (regression — 150 m is correct there)
- [x] Every unit of the escort is clear, not just its origin
- [x] A crowded FARP still gets built
- [x] Lua tests, with the occupancy probe mocked
