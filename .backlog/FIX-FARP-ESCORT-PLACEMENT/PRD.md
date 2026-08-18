# FIX-FARP-ESCORT-PLACEMENT — the FARP escort lands on whatever is already there

Status: ⬜ ready

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

- [ ] An `-farp` next to a static FARP puts its escort on clear ground, close to the FARP
- [ ] The same call far from anything is unchanged (regression — 150 m is correct there)
- [ ] An unknown FARP type no longer silently falls back to 75 m
- [ ] Verified in game on the mission that reproduced it, `test/veaf-tools/verify-mission-a`
