# FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND — the escort is moved even when the requested spot is free

Status: 🧑 waiting-human — the fix and its tests landed 2026-09-01; **the in-game proof is all that
remains** (ticket 02)

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

## Scope

| # | Ticket | Risk | Status |
|---|---|---|---|
| 01 | Keep the requested bearing when the cloud proves it clear | medium — changes where every FARP escort lands | ✅ |
| 02 | Verify in game that a FARP on open ground does not move | needs DCS | 🧑 |

## What ticket 01 delivered (2026-09-01)

The hypothesis above held, and the geometry behind it is worth stating once: candidates are asked of
`Disposition` with a safe radius of `extent + PLACEMENT_CLEARANCE`, and the group's footprint reaches
`extent` from the wanted spot — so a candidate whose `gap` is at most `PLACEMENT_CLEARANCE` puts every
position the group would occupy inside the clearing that candidate proves. The threshold is not a tuned
number; it is the one the radius was already built from.

The guard is `nearest.gap <= PLACEMENT_CLEARANCE` **and** `allClear(baseAngle, 1)`. Dropping the second
conjunct would place an escort on an apron whenever the ground around it happened to be scenery-clear —
the very defect `FIX-FARP-ESCORT-PLACEMENT` spent five rounds removing — and a test pins it.

Two sides, both proven to fail: reverting the fix turned the two "keeps its bearing" tests red with
`expected: 90, actual: 87.709389957362`, and the two "still moves" tests were red under a deliberate
sabotage of the corrected code (threshold widened tenfold, and the occupancy conjunct removed). The
sabotage table is in [ticket 01](tickets/01-keep-the-bearing-the-cloud-proves-clear.md).

The PRD's note was applied: `no usable point in Disposition's cloud, walking the bearings instead` is
now at **info**, so no one has to set `veafGrass.LogLevel = "debug"` to find out why a group moved.

## Definition of done

- [x] A requested spot that is genuinely clear — of buildings, of forests, of everything — keeps its
      bearing and its distance, with no move at all
- [x] A requested spot that is not clear still moves, and still avoids forests: tier 1 keeps doing what
      it was added for
- [x] Lua tests covering both, driven off the `gap` the cloud returns rather than off the implementation
- [ ] Verified in game: a `-farp` on open ground with nothing within a kilometre produces **no**
      `FARP escort: bearing 0 requested, N used` line with `N ~= 0`
- [x] `stylua --check` clean; `luacheck` is not installed on this workstation and runs in the CI Lua gate

## Note for whoever runs the in-game check

~~`no usable point in Disposition's cloud, walking the bearings instead` is emitted at **debug**
([`veafGrass.lua:439`](../../src/scripts/veaf/veafGrass.lua)) and is therefore invisible at the default
log level~~ — **settled 2026-09-01: that line now logs at info**, so the default log level says why a
group fell through to tier 2. The rest of the protocol is in
[ticket 02](tickets/02-verify-in-game-that-nothing-moves.md), including the two cases that must **still**
move: a run where nothing moves anywhere means the fix went too far.
