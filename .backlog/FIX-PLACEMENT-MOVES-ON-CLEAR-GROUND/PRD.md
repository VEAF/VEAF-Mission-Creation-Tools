# FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND — the escort is moved even when the requested spot is free

Status: ⬜ ready

Origin: measured in game 2026-08-28 while running
[`DCS-SESSION-TODO`](../../DCS-SESSION-TODO.md) item 21, the exhaustion count for
[`FIX-PLACEMENT-IGNORES-SCENERY`](../FIX-PLACEMENT-IGNORES-SCENERY/PRD.md) ticket 04. David's call,
same day: a lot of its own.

## What was measured

The item 21 protocol includes an explicit non-regression case: a `-farp` on **open ground, nothing
within a kilometre**. Nothing should move there. Something did:

```
VEAF-GRASS|I|bearingFromSceneryCloud: findClearBearing: scenery-clear bearing 25 at 1.0540926357404x distance
VEAF-GRASS|I|buildFarpUnits: FARP escort: bearing 0 requested, 25 used at 1.0540926357404x distance
```

Bearing 0 was asked for; bearing 25 at 1.12× was used. All four of the item 21 cases moved, including
this one.

## Why

[`veafGrass.findClearBearing`](../../src/scripts/veaf/veafGrass.lua) runs tier 1 — the scenery cloud —
**before testing the requested bearing at all**:

```lua
  local cloudAngle, cloudScale = bearingFromSceneryCloud(baseAngle, positionsFor, own, allClear)
  if cloudAngle then
    return cloudAngle, cloudScale
  end

  -- Tier 2 — walk the bearings, then the distances.
  for _, scale in ipairs(veafGrass.PLACEMENT_DISTANCE_STEPS) do
    -- The original bearing first at every distance, so the group stays where it was aimed when it can.
    if allClear(baseAngle, scale) then
```

`bearingFromSceneryCloud` asks `Disposition` for a cloud of clear points, sorts them by `gap` — their
distance to the spot actually wanted — and returns the nearest one that passes the occupancy probe.
**The wanted spot is never itself a candidate**, so as long as the cloud answers at all, the escort is
moved. Tier 2 states the opposite intent in its own comment, and never gets the chance to act on it.

## Why the obvious fix is wrong

Testing `allClear(baseAngle, 1)` before consulting the cloud would put escorts back in the trees:
`allClear` runs the occupancy probe, which sees units, statics, aprons and buildings — **not forests**.
Forests are only knowable through `Disposition`, and `Disposition` cannot be asked *"is this spot
clear?"*; it only proposes points. That asymmetry is the whole reason tier 1 exists, and it is
documented at length in `findClearBearing`.

## The tenable route

Tier 1 already computes `gap` for every candidate — the distance from the candidate to the wanted spot.
If the best candidate's `gap` is smaller than the clearance the group needs
(`veafGrass.PLACEMENT_CLEARANCE`), then the wanted spot is inside the same clearing that candidate
proves, and it can be kept as-is: `return baseAngle, 1`.

This is a hypothesis with a plausible mechanism, not a verified fix. It needs the same in-game proof
the placement work has always needed.

## Why it matters beyond tidiness

`FIX-PLACEMENT-IGNORES-SCENERY` ticket 04 must prove *"a FARP far from anything is never refused and
**nothing moves**"* before it can ship. That half is currently unprovable, because it is false on
`develop` independently of anything ticket 04 does. **This lot unblocks that proof.**

It also touches the trade `FIX-FARP-ESCORT-PLACEMENT` was careful about: five rounds of changes, four
of them about how aggressively placement refuses ground, and the non-regression — *"c'est bon, rien n'a
bougé"* — mattered more than the reported case. Moving every FARP escort in every existing mission by
a few dozen metres is exactly the outcome that history was guarding against.

## Definition of done

- [ ] A requested spot that is genuinely clear — of buildings, of forests, of everything — keeps its
      bearing and its distance, with no move at all
- [ ] A requested spot that is not clear still moves, and still avoids forests: tier 1 keeps doing what
      it was added for
- [ ] Lua tests covering both, driven off the `gap` the cloud returns rather than off the implementation
- [ ] Verified in game: a `-farp` on open ground with nothing within a kilometre produces **no**
      `FARP escort: bearing 0 requested, N used` line with `N ~= 0`
- [ ] `stylua --check` and `luacheck` clean

## Note for whoever runs the in-game check

`no usable point in Disposition's cloud, walking the bearings instead` is emitted at **debug**
([`veafGrass.lua:439`](../../src/scripts/veaf/veafGrass.lua)) and is therefore invisible at the default
log level — the 2026-08-28 run could not tell why the forest case fell through to tier 2. Set
`veafGrass.LogLevel = "debug"`, or move that line to info as part of this lot.
