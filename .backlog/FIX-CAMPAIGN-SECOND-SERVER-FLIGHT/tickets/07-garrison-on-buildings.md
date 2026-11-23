# 07 — Garrison units on roofs

Status: ✅ done
Type: fix

## Found

"Un véhicule sur un bâtiment à Alep" (a player, ~21:17 UTC).
`veafCampaign.placeGarrisonGroup` draws a point with `veaf.findPointInZone`, places the group with `veafCasMission.placeGroup`, and only checks the **concrete** (`isOnConcrete`): nothing against buildings or trees.
The repository's scenery-aware placement (`veafUnits.settleGroup`, FIX-PLACEMENT-IGNORES-SCENERY ticket 12, small `Disposition` queries 25 m apart — see `docs/agents/dcs-runtime-traps.md`) is not used for campaign garrisons.
Positions are recorded in the state: the same vehicle comes back on the same roof at every reinforcement and every wake.

## To do

- Campaign garrisons settle through `settleGroup` when they are **drawn** (not at each respawn: the recorded positions then stay clear).
- A test on the draw path; the in-game check on an urban zone (Aleppo) written.
- The garrisons already recorded in the Oronte save keep their roofs until redrawn: say so in the release note, and redraw them with ticket 12's procedure.

## Done when

A garrison drawn in a town has no unit inside a building's footprint in the next evening's check.

## Done

- Read on the code: the draw path **does** settle each group (`veafCasMission.placeGroup` calls `veafUnits.settleGroup`), but as one rigid body, within 300 m, against what `Disposition` sees; in a town it finds no clearing for a whole group and leaves it where it is.
- `veafCampaign.isOnBuilding`: each drawn unit's spot is asked of `world.searchObjects` through `veafGrass.isSpotOccupied` (units, statics and **scenery**, which holds the buildings), within `GARRISON_BUILDING_CLEARANCE` (15 m).
  `placeGarrisonGroup` draws another point when a unit lands on a building, as it does on the concrete; `drawGarrison` drops a unit still on one after the tries, so what is recorded stands clear.
- Only at the draw, not at each respawn: the recorded positions stay clear.
- Limit: a search matches an object's position, so a building wider than 30 m can hide its centre from the probe.
- Tests: a drawn unit on a building is dropped; a group landing on one is placed again.
- The garrisons already in the Oronte save keep their roofs until redrawn: ticket 12's procedure redraws the red ones; said in the CHANGELOG.

## In-game check

After the redraw, at Aleppo (game master slot, F10 map zoomed, or Tacview 3D): no garrison vehicle inside a building's footprint.
