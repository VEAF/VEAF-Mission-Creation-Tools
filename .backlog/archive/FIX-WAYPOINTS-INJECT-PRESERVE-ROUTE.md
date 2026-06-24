# Lot FIX-WAYPOINTS-INJECT-PRESERVE-ROUTE — waypoint injection wipes the takeoff

Status: ✅ done

**Goal**: Taking a player slot in a built mission showed the DCS native message **"YOUR FLIGHT IS DELAYED TO START, PLEASE WAIT"** and the slot could not be taken. Root cause: the waypoints injector rebuilt each matched group's route from scratch with **only** the injected waypoints, wiping the original `TakeOffParking` point — the default `waypoints.yaml` example matches `all_blue_planes`, so a human A-10C2 lost its parking departure and got an airborne first waypoint (ETA in the future) → DCS delays the flight. Per David: injection must **append** waypoints to the end of the existing route, and **replace in place only a waypoint of the same name** — never wipe the route.

This lot also **reverts FIX-DEFAULTS-AIRCRAFT-ROSTER** (#438): emptying the default spawnables/dynamic-slot-templates was a misdiagnosis — injecting those late-activation/dyn-spawn groups is normal and intended; they were not the cause of the message.

**Branch**: `fix/waypoints-injection-preserve-route` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-WAYPOINTS-INJECT-PRESERVE-ROUTE-001 | `_inject_waypoints_into_group`: start from the group's existing route; append each injected waypoint at the end, replacing in place only a same-named waypoint; never recreate the route (takeoff/landing preserved); keep the ETA-locked guard and renumber `num`. Revert #438. Regression tests (takeoff preserved + append, replace-by-name). Verified end-to-end on the reporter's `test.miz`. | `waypoints_injector/waypoints_injector_worker.py`, `test/python/waypoints_injector/test_waypoints_injector_worker.py` | fix | ✅ |

### Future note (not in this lot)
- Prevent spawnable (`veafSpawn-`) and dynamic-slot template groups from being **selectable** in the DCS slot list (they appear as choosable slots today). To investigate.
