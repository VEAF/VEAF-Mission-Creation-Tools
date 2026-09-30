# FIX-FARP-ESCORT-PLACEMENT — the FARP escort lands on whatever is already there

Status: ✅ done — shipped in 6.15.33, **both cases verified in game 2026-08-24** · archived 2026-09-28

## Verified, both halves

- **The reported case** — a `-farp` ~150 m from `StaticFarpAlpha`: *"c'est bon, tout est en dehors du farp
  statique"*. Escort, tents, props and both windsocks clear of the platform.
- **The non-regression** — a `-farp` in open ground, far from anything: *"c'est bon, rien n'a bougé"*.
  Everything on the requested bearing at the requested distance, no refusal in the log.

The second mattered more than the first. Five rounds of changes went into this placement code, four of
them adjusting how aggressively it refuses ground; a fix that quietly moved every FARP in every existing
mission would have been a worse outcome than the defect.

## Five defects, not one

Only the first was the one suspected when the lot was reopened. Each was found by measuring, and four
became visible only once the placement logged its decisions.

| # | Defect | How it was found |
|---|---|---|
| 1 | A FARP is an **airbase**, not a static, so the units-and-statics probe could never see it | `veafAirbases.lua:191` and the DCS log's `NO ATC COMM HELIPAD` |
| 2 | `searchObjects` matches an object's **position**, so a 12 m sphere misses a platform an escort stands on the edge of | reading the API contract |
| 3 | The size was guessed twice — 80 m (below the 84 m outermost pad) then 84 m from `getParking()` (bounds the pads, not the apron) | `getDesc().box` on a running DCS: **±129.5 m**, a 259 m square |
| 4 | With the exclusion finally apron-sized, a group with no clear bearing kept the **original** angle — pointing at a pad | `findClearBearing: no clear bearing at this distance, keeping 0` |
| 5 | The FARP **avoided itself**: its own props are inside its own apron by design | `refusing a spot 129m/0m inside [FARP FU2149-11.924]` |

Plus the windsock, which went through no clear-ground search at all and sits 120 m out on a FARP.

## Two decisions worth keeping

**#232's arbitration was revised, by David, on evidence.** It was keep-the-distance-move-the-bearing,
because the escort serves the FARP and the crew wants it close. That held while the exclusion was small;
against a real 259 m apron it *guarantees* landing inside it. The search now walks out to 1.5× then 2×,
always trying the requested bearing first at each distance — so a nearer bearing beats a further one, and
a group with clear ground does not move at all.

**The windsock's bearing is free**, also David's call: nothing reads its position, unlike the escort or
the pads. That is why it can be moved anywhere while the escort cannot.

## What measurement settled, so nobody repeats it

- `Airbase:getDesc().box` **exists and is the answer** — ±129.5 m for a FARP.
- `Airbase:getParking()` **works on a FARP** (4 spots, furthest 84 m) but bounds the pads only.
  `vTerminalPos` is present even though the vendored DCS API schema does not list it.
- `land.getSurfaceType` returns `LAND` everywhere out to 260 m around a FARP. The apron is **not** in the
  terrain data; probing the ground for it is a dead end.

## The lesson that is not about FARPs

Four of the five defects are indistinguishable from outside: "still on the FARP" looks identical whether
the probe saw nothing, saw it and was calibrated too tight, or worked perfectly and fell back to the
original angle. Three rounds were spent adding *size* to a problem that was structural, each costing a
DCS reload, because nothing said which. The placement now logs its decisions at info — and that is what
found defects 4 and 5 within minutes of each other.


## What shipped this time (6.15.33)

`veafGrass.isSpotOccupied` now answers two questions instead of one:

- **units and statics within `clearance`** — unchanged, and `world.searchObjects` is right for it;
- **landing platforms within their footprint** — `veafGrass.getLandingPlatforms()` reads
  `world.getAirbases()` and keeps `Airbase.Category.HELIPAD` plus the FARPs DCS miscategorises as
  `SHIP` (the same remediation `veafAirbases.lua:191` has always applied). An airdrome is deliberately
  *not* a platform to avoid: excluding a runway-sized radius around every airfield would move FARPs that
  were placed perfectly well.

The list is read **once per bearing search**, in `findClearBearing`, not per candidate position: a full
turn is 24 bearings and each tests every position the group occupies, so probing inside would be hundreds
of calls per FARP. Pinned by a test that counts the calls.

### The footprint radius is an estimate, and says so

`veafGrass.PLATFORM_FOOTPRINT_RADIUS_METRES = 80`. DCS exposes no extent for an airbase — `Airbase` has
`getParking()` and `getRunways()` and nothing else, and whether a FARP even reports parking spots is
unverified. So the number is reasoned: the DCS `FARP` model is roughly 50 m across and 80 m covers it
with margin.

What makes it safe to get wrong generously: this module already places the escort at 150 m, the tent at
200 m and the windsock at 50 m from the FARP it is building, so 80 m around a *pre-existing* platform
excludes its surroundings and nothing else. An over-tight value shows up as an escort still landing on a
platform; an over-wide one as an escort nudged one bearing further. The second is cheap.

### Why the tests are new rather than extended

The old ones stubbed `isSpotOccupied` and asserted the bearing search around it, so they proved the search
reacts to an occupied spot while nothing proved a real FARP *is* one — a true test on a false premise,
which is how the broken fix passed review. The new ones drive `world.getAirbases` and assert on the
geometry: a spot 60 m from a platform's centre is occupied, one at 150 m is not, and the easting is read
from the right axis (a mission-table `y` against a runtime `z` measures nothing and raises nothing).

Verified by mutation: removing the platform check makes the suite fail, restoring it makes it pass.

## Still to confirm in game

The two cases from the session plan, unchanged:

- `-farp` **~150 m from the static FARP** → the escort must be on clear ground, and `dcs.log` should show
  `findClearBearing: moved from … to …`;
- `-farp` in **open ground, far from anything** → identical to before, 150 m on the FARP's heading, **no**
  message in the log. That non-regression matters more than the fix: the original bearing is tried first
  precisely so working missions do not move.


## Measured 2026-08-22: it still lands on the static FARP

David dropped a `-farp` next to the static FARP and everything came up on it, exactly as before the fix
(screenshot in the session log). Two causes, both readable in the code without needing another flight,
and the second one would have survived a fix for the first.

**1. A FARP is not a static.** `veafGrass.isSpotOccupied` probes
`world.searchObjects` over `Object.Category.UNIT` and `Object.Category.STATIC` only. This repo's own
`veafAirbases.lua:191` shows what a FARP actually is — an **airbase**, reached through
`world.getAirbases()`, categorised `Airbase.Category.HELIPAD` (with a remediation for the ones DCS
miscategorises as `SHIP`). The DCS log agrees: `NO ATC COMM HELIPAD + StaticFarpAlpha-1`. So the probe
was never going to see the one object the whole lot is about. The comment above it — *"a static FARP
placed in the editor is a static, not scenery"* — reasoned about the wrong distinction: the choice was
not static-versus-scenery but static-versus-**airbase**.

**2. `searchObjects` matches positions, not footprints.** `PLACEMENT_CLEARANCE` is **12 m** and a FARP's
footprint is several tens of metres. An object is returned when *its position* falls inside the sphere,
so an escort placed on the **edge** of a FARP — the actual complaint in #232 — leaves the FARP's centre
well outside a 12 m sphere. Even as a static it would have gone undetected.

That second cause is why the first was invisible in review: the unit tests stub `isSpotOccupied` and
assert the bearing search around it, so they prove the search reacts to an occupied spot. Nothing proved
that a real static FARP *is* an occupied spot. The test was true and the premise was false.

## What a working fix needs

- Ask `world.getAirbases()` and reject a position within a FARP-sized radius of a `HELIPAD` (and of the
  `SHIP`-miscategorised FARPs `veafAirbases` already remediates), rather than probing for statics
- Pick that radius from the platform's real extent, not from `PLACEMENT_CLEARANCE` — 12 m is a clearance
  between vehicles, not the size of a landing pad
- Keep the units-and-statics probe for what it is good at: another group already parked there
- A test that fails on the real geometry — a FARP centre 60 m from an escort position must read as
  occupied. Stubbing `isSpotOccupied` cannot catch this class, which is how it shipped broken


Written, unit-tested and shipped in 6.15.11. Waiting on the in-game confirmation on
`test/veaf-tools/verify-mission-a`, the mission that reproduced it — see
[DCS-SESSION-TODO.md](../../DCS-SESSION-TODO.md).

Origin: [#232](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/232), Sharko, 2023.
**Reproduced in game by David on 2026-08-17**, on the verification mission built for it — screenshot
on the issue.

## The defect

`-farp` spawns the FARP plus an escort group — five vehicles blue (`Hummer`, `M978 HEMTT Tanker`, two
`M 818`, `Hummer`), six red. Their position is computed from a **fixed distance** and nothing else
(`veafGrass.lua:1266-1270`):

```lua
local unitsOrigin = {
  x = farp.x + unitsDistance * math.cos(mist.utils.toRadian(angle)),
  y = farp.y + unitsDistance * math.sin(mist.utils.toRadian(angle)),
}
```

`unitsDistance` is **150 m** for a FARP type (`:1082-1086`, `"Invisible FARP"` included) and 75 m
otherwise. There is **no test of whether that spot is free**.

A DCS static FARP is about 150 m across. So calling `-farp` beside one puts the escort straight onto
its pads — measured: David's marker was ~150 m from the static FARP, and the trucks came down on it,
the lead `M 818` close enough to a helipad that a helicopter landing there meets it.

## What the reproduction corrected

Two wrong readings, both mine, worth recording so nobody re-derives them:

- I first read the four-helipad object in the screenshot as VEAF's own construction and concluded the
  escort was landing inside its *own* footprint. **Wrong**: those pads are the static FARP; `-farp`
  builds an *invisible* one plus the grass mat.
- I therefore claimed the issue's title ("when a static FARP already exists") was misleading and the
  defect would show far from anything too. **Also wrong**: 150 m is a fine distance in open ground.
  The static FARP's presence is exactly the trigger, as the report said in 2023.

## The use case, from David — and it makes this the *nominal* path

A static FARP is placed in the mission **on purpose**: it unlocks spawning on that FARP once the zone
is captured, in a dynamic campaign. `-farp` is then run on top of it to build it out.

So "`-farp` beside a static FARP" is not an edge case someone stumbled into — it is **how the feature
is used**. That raises the bar for the fix: it has to work well there, not merely stop overlapping.

## The fix, as arbitrated by David

**Walk the escort around the circle** until the position is free — keep the radius, move the bearing.
Not "increase the radius": that pushes the escort away from the FARP it serves, and in a campaign the
crew wants it close.

Things to settle while implementing:

- **What counts as occupied.** `veaf.findSpawnPoint` (`FEAT-SCENERY-AWARE-SPAWN`) avoids *scenery*,
  not mission objects — check whether it can answer this at all before building on it, rather than
  assuming it because the name fits.
- **The escort is a group, not a point.** Five vehicles at 6 m spacing need a clear arc, not a clear
  point; testing the origin alone would move the group so its tail still overlaps.
- **A second defect beside this one**: the type list at `:1082` enumerates four strings, so any FARP
  type outside it silently falls back to 75 m — the same shape as the missing `else` of
  `FIX-COMBATZONE-ZONE-TYPE-SILENT`. Fix or report it, do not leave it mute.
- The tent and the other props use the same pattern at their own distances (`tentDistance`,
  `otherDistance`); if they overlap too, they are the same fix.

## Definition of done

- [x] An `-farp` next to a static FARP puts its escort on clear ground, close to the FARP
- [x] The same call far from anything is unchanged (regression — 150 m is correct there): the original bearing is tried first
- [x] An unknown FARP type no longer silently falls back to 75 m — and `FARP_T`, which **was** falling back, is fixed (ticket 02)
- [ ] Verified in game on the mission that reproduced it, `test/veaf-tools/verify-mission-a`

---

## Tickets, in full

## 01 — Walk the escort around the circle until the ground is clear

Status: ✅ done
Type: fix

Closes [#232](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/232) (Sharko, 2023),
reproduced in game by David on 2026-08-17.

### The defect

`-farp` spawns the FARP plus an escort group, whose position is computed from a **fixed distance and
bearing** with no test of whether that spot is free
([`veafGrass.lua:1267-1270`](../../src/scripts/veaf/veafGrass.lua:1267)).

Placed beside a static FARP — which is **the nominal use**, since the static FARP is what unlocks
spawning on it once the zone is captured — the escort lands on its pads. Measured: David's marker was
~150 m from the static FARP, and the trucks came down on it, the lead `M 818` close enough to a helipad
that a helicopter landing there meets it.

### The fix, as arbitrated by David

**Keep the radius, move the bearing.** Walk around the circle until the ground is clear. Not "increase
the radius": that pushes the escort away from the FARP it serves, and in a campaign the crew wants it
close.

### What had to be decided while implementing

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

### Same pattern, same fix

The tent, the other props and the windsock are placed by the identical formula at their own distances
(`tentDistance`, `otherDistance`, `windsockDistance`). The PRD said: if they overlap too, they are the
same fix. They can, so they get it — and since the original bearing is tried first, a FARP with nothing
in its way is byte-for-byte where it was.

Consequence worth stating: the tent and the escort may end up on **different** bearings, where before
they shared one. That is the price of not putting anything on top of an obstacle, and it is deliberate.

### Deliberately left out, so it is not mistaken for an oversight

**The windsock is not moved.** The PRD named the tent and the other props, not the windsock; it was
never measured as overlapping; it is a single small object; and its geometry is constrained by a second
windsock at 90° on the `FARP` type. Moving it would be a guess with a regression risk and no reported
symptom.

**The `Invisible FARP` markers are not moved either** — those two vehicles sit 25 m out precisely to
show where an otherwise invisible FARP is. Displacing them would defeat their purpose.

### Definition of done

- [x] An `-farp` next to a static FARP puts its escort on clear ground, close to the FARP
- [x] The same call far from anything is unchanged (regression — 150 m is correct there)
- [x] Every unit of the escort is clear, not just its origin
- [x] A crowded FARP still gets built
- [x] Lua tests, with the occupancy probe mocked

---

## 02 — One predicate for "is this a FARP platform", instead of four copies

Status: ✅ done
Type: fix

The second defect the PRD named — *"the type list at `:1082` enumerates four strings, so any FARP type
outside it silently falls back to 75 m"* — and it is not hypothetical.

### The list exists four times, and it has already diverged

| Where | Types listed |
|---|---|
| [`veafGrass.lua:204`](../../src/scripts/veaf/veafGrass.lua:204) — recognising FARP units | `SINGLE_HELIPAD`, `FARP_SINGLE_01`, `FARP`, `Invisible FARP`, **`FARP_T`** |
| [`veafGrass.lua:241`](../../src/scripts/veaf/veafGrass.lua:241) — recognising FARP airbases | the same **four**, without `FARP_T` |
| [`veafGrass.lua:1082`](../../src/scripts/veaf/veafGrass.lua:1082) — tent / escort / prop distances | the same **four** |
| [`veafGrass.lua:1200`](../../src/scripts/veaf/veafGrass.lua:1200) — windsock distance and angle | the same **four** |

Commit `a454c577` (2025-08-08, *"adds FARP_T to the list of recognized FARP unit types"*) added the
fifth type to **one** list.

### What that produces today, measured by reading

A `FARP_T` is recognised as a FARP unit (204) and `buildFarpUnits` runs for it — then falls through every
type test inside, so it is laid out as if it were not a FARP at all:

| | a FARP platform | a `FARP_T` today |
|---|---|---|
| escort distance | 150 m | **75 m** |
| tent distance | 200 m | **100 m** |
| other props | 130 m | **85 m** |
| windsock | 120 m, 0° | **50 m, 45°** |

So the escort is placed at half the intended distance, on top of the pads. Same defect as ticket 01,
reached by a different route — which is why both belong to this lot.

### What ships

- **`veafGrass.isFarpPlatformType(typeName)`** — the list, once. Used at all four sites.
- `FARP_T` is in it, since it was already recognised as a FARP everywhere except where it mattered.
- **It stops being mute.** A type that is *not* in the list but whose name contains `FARP` or `HELIPAD`
  logs a warning naming the type and saying the default distances are being used. That is the shape
  `FIX-COMBATZONE-ZONE-TYPE-SILENT` is about: a missing `else` that guesses instead of reporting. A
  guess and a warning is not the same as a guess.

Not a refactor for tidiness: the four copies **are** the defect, and leaving three of them would leave
the next type to diverge again.

### Behaviour change to announce

A `FARP_T` in an existing mission moves: its escort goes from 75 m to 150 m, and its windsock from
50 m/45° to 120 m/0°. That is the fix, not a side effect — but it is visible, so the changelog says so.

### Definition of done

- [x] One predicate, used at all four sites
- [x] `FARP_T` gets FARP distances
- [x] An unrecognised FARP-looking type warns instead of silently using the default distances
- [x] Lua tests for the predicate, for `FARP_T`, and for the warning path

---
