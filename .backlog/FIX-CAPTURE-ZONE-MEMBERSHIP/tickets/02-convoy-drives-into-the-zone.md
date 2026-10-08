# 02 — The assault convoy drives into the zone, not to its edge

Status: ⬜ ready

- Find why the blue convoy's nine units stopped together 2.04–2.08 km from Poti's centre (zone radius 2 km): its route's last point (`veafSpawn.spawnConvoy` towards the named point "CAMPAIGN Poti"), the road network near the port, `veafGroundAI`'s arrival handling, or the campaign itself. Read the code first; measure in a test mission (a copy of `D:\dev\_VEAF\_campaigns\campaign-kolkhida`, never David's live session) only for what the code cannot settle — prepare the mission and ask David to run it, never launch DCS yourself.
- Make the convoy end its drive well inside the zone (on a road point inside the radius when the centre is off-road, as Poti's port is).
- Lua tests on the destination chosen for a zone whose centre is off the road.
