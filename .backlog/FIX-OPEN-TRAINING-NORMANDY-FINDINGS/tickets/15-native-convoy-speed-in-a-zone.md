# 15 — A native convoy in a combat zone drives at 5.1 m/s whatever speed its route says

Status: ⬜ ready (investigate, then fix)
Type: investigate
Files: `src/scripts/veaf/veafCombatZone.lua`, `src/scripts/veaf/veafDcsSpawner.lua` (l. 315, 504-508), `src/scripts/veaf/veafGroundAI.lua`, `veaf_mission_mcp/create_combat_zone.py`

## What happens

Measured in DCS on 2026-10-13 on the Normandy test mission (LOCAL_TEST build), three convoys activated through `veafCombatZone.ActivateZone`. Route written in the mission table (checked in the built `.miz`): every point `On Road`, `speed = 11.1` m/s, `speed_locked = true`. Units alive in the group: the first convoy had a `flak38` (`speedMax` 0 — ticket 04); it was removed and the three groups rebuilt with only mobile vehicles (`Pz_IV_H` 10.6, `Sd_Kfz_251` 14.7, `Blitz_36-6700A` 25, `Sd_Kfz_234_2_Puma` 25 m/s). Re-measured on the rebuilt mission, `ConvoiCoutances`, `Unit:getVelocity()` of every unit at 40, 85 and 130 s: the lead vehicles hold **5.1 m/s** (the other units start one after another and then follow at 4.9-7 m/s). Over 120 s the leader of each convoy covered 571, 737 and 572 m: 4.8-6.1 m/s, i.e. about 18 km/h, below every unit's `speedMax`.

5.14 m/s is exactly 10 knots; the Sinai Open Training measured 2-3 m/s against 5.6 written (FIX-OPEN-TRAINING-SINAI retours 13, « 20 km/h »). Whatever it is, the speed in the route is not what the group drives at once the zone respawns it: either the respawn (`VeafGroupSpawn:respawn()` → `veafDcsSpawner.addGroup`, lines 315 and 504-508, `unit.speed = unit.speed or defaults.speed`) writes its own speed on the units and points, or the ground AI re-tasks the group.

## What ships

1. Find where the speed is overwritten: dump the group table `veafDcsSpawner.addGroup` hands to `coalition.addGroup` for a native convoy (log it at `trace`), and compare with the mission's.
2. Keep the route's speed for a native vehicle group respawned by a zone, as the route is already kept.
3. A test that spawns a convoy zone and asserts the table passed to `coalition.addGroup` keeps the route speed.

## Done when

A convoy route written at 11.1 m/s is driven at about that speed on a road in DCS (probe `tools/probe_zones.py convois` of the Normandy folder: ≥ 8 m/s for the leader).
