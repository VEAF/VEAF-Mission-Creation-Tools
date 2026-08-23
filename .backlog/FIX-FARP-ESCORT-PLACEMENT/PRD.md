# FIX-FARP-ESCORT-PLACEMENT — the FARP escort lands on whatever is already there

Status: ⬜ ready — **the shipped fix does not work**, measured in game 2026-08-22

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
