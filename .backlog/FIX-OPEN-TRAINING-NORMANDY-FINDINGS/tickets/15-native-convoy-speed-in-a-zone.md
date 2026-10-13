# 15 — A native convoy in a combat zone drives at 5.1 m/s whatever speed its route says

Status: 🚫 wontfix — not a defect: measured in DCS, the convoy reaches its written speed after about three minutes
Type: investigate
Files: `src/scripts/veaf/veafCombatZone.lua`, `src/scripts/veaf/veafDcsSpawner.lua` (l. 315, 504-508), `src/scripts/veaf/veafGroundAI.lua`, `veaf_mission_mcp/create_combat_zone.py`

## What happens

Measured in DCS on 2026-10-13 on the Normandy test mission (LOCAL_TEST build), three convoys activated through `veafCombatZone.ActivateZone`. Route written in the mission table (checked in the built `.miz`): every point `On Road`, `speed = 11.1` m/s, `speed_locked = true`. Units alive in the group: the first convoy had a `flak38` (`speedMax` 0 — ticket 04); it was removed and the three groups rebuilt with only mobile vehicles (`Pz_IV_H` 10.6, `Sd_Kfz_251` 14.7, `Blitz_36-6700A` 25, `Sd_Kfz_234_2_Puma` 25 m/s). Re-measured on the rebuilt mission, `ConvoiCoutances`, `Unit:getVelocity()` of every unit at 40, 85 and 130 s: the lead vehicles hold **5.1 m/s** (the other units start one after another and then follow at 4.9-7 m/s). Over 120 s the leader of each convoy covered 571, 737 and 572 m: 4.8-6.1 m/s, i.e. about 18 km/h, below every unit's `speedMax`.

5.14 m/s is exactly 10 knots; the Sinai Open Training measured 2-3 m/s against 5.6 written (FIX-OPEN-TRAINING-SINAI retours 13, « 20 km/h »). Whatever it is, the speed in the route is not what the group drives at once the zone respawns it: either the respawn (`VeafGroupSpawn:respawn()` → `veafDcsSpawner.addGroup`, lines 315 and 504-508, `unit.speed = unit.speed or defaults.speed`) writes its own speed on the units and points, or the ground AI re-tasks the group.

## What ships

1. Find where the speed is overwritten: dump the group table `veafDcsSpawner.addGroup` hands to `coalition.addGroup` for a native convoy (log it at `trace`), and compare with the mission's.
2. Keep the route's speed for a native vehicle group respawned by a zone, as the route is already kept.
3. A test that spawns a convoy zone and asserts the table passed to `coalition.addGroup` keeps the route speed.

## Measured instead of fixed

Measured in DCS on 2026-10-13, Normandy test mission, scripts of the branch (dev mode); nothing was changed in the end.

- A convoy zone's leader holds 4-6 m/s for the first two minutes and the **rear vehicles start at 0 m/s** (units 3 to 9 at 0.0-2.2 m/s after 20 s, 100-210 m behind the leader). At about 60 s the column is 460 m long and still ragged; at about 200 s every vehicle of `combatZone_ConvoiLisieux` runs at **10.0-11.1 m/s**, spaced 30 m apart. The probe read the speed 15, 75 and 135 s after activation: it measured the column forming up, not a cap.
- One `Blitz_36-6700A` alone on the same route, spawned through `veaf.addGroup`, reaches **9.3 m/s after 15 s and 11.1 m/s after 45 s** — with the route's speeds locked and without.
- So the route's speed is not overwritten, the road does not cap it, and the lock hypothesis of this ticket (`speed_locked` lost by `getGroupRoute`) was tested and is **false**: a locked route sent to the running convoy changed nothing, and the code written for it was removed.

What remains true: a convoy spawned in a zone takes about three minutes to drive at its speed, because its vehicles start in a column that DCS unwinds slowly; and the WW2 anti-aircraft guns cannot move (ticket 04), which does slow a convoy that holds one for good.

The Normandy folder's `tools/probe_zones.py convois` reads at 15, 75 and 135 s: it should read after four minutes (it would then have shown 10-11 m/s).
