# 02 — The assault convoy drives into the zone, not to its edge

Status: 🧑 waiting-human — the halt is to be measured in DCS

- Find why the blue convoy's nine units stopped together 2.04–2.08 km from Poti's centre (zone radius 2 km): its route's last point (`veafSpawn.spawnConvoy` towards the named point "CAMPAIGN Poti"), the road network near the port, `veafGroundAI`'s arrival handling, or the campaign itself. Read the code first; measure in a test mission (a copy of `D:\dev\_VEAF\_campaigns\campaign-kolkhida`, never David's live session) only for what the code cannot settle — prepare the mission and ask David to run it, never launch DCS yourself.
- Make the convoy end its drive well inside the zone (on a road point inside the radius when the centre is off-road, as Poti's port is).
- Lua tests on the destination chosen for a zone whose centre is off the road.

## Found from the code (2026-10-08)

- The route already ends at the centre. `veaf.generateVehiclesRoute` drives on the road to `END`, the road point nearest the named point "CAMPAIGN Poti" (`land.getClosestPointOnRoads`), then off road (`Diamond`) to `T_END`, the centre itself. Since `END` is the nearest road point to the centre, no road point lies closer: "a road point inside the radius" exists only if `END` is already inside.
- Nothing in VMCT stops a convoy there. The campaign never re-routes it; `veafSpawn.convoyArrivalWatchdog` only watches multi-point itineraries; `veafGroundAI` logged no contact for the blue convoy before 17:37:43, 50 s after the halt was measured, and its alerted state does not stop a convoy.
- So the halt at 2.04–2.08 km is on the DCS side, and the code cannot say which: `END` lying ~2.04 km from the centre with the column pausing there before its off-road leg (on the earlier run it did go on, to 0–90 m), or the column blocked — the 24-unit garrison wrongly drawn at the capture was spawned across Poti 40 s before the measurement.
- What this lot changes regardless: a convoy halted at the edge now becomes the garrison (ticket 01), no garrison is spawned under it any more, and a convoy in contact drives into the zone (ticket 04). Each departure now logs `its road ends N m from [<zone>]'s centre (radius R), then <action> to the centre`.

## To measure in DCS

Test mission (a copy of *Kolkhida* mission 1, built from this branch, `assault_seconds: 30`): `D:\dev\_VEAF\tmp\fix-capture-zone-membership\Kolkhida-capture-test_20261008.miz`. Its `mission-script.lua` logs a `PROBE Poti` line every 15 s and a `PROBE VERDICT` line once the blue convoy has stood still for a minute.
