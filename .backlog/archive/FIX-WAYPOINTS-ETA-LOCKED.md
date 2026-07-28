# Lot FIX-WAYPOINTS-ETA-LOCKED — injected routes have no locked-ETA waypoint

Status: ✅ done

**Goal**: `inject-waypoints` rebuilds each player aircraft's route from a `waypoints.yaml` flight plan (matched by aircraft type, so a catch-all plan rewrites every human slot). Every `WaypointDefinition` defaults to `ETA_locked=false` and the flight plans don't set it, so the injected route has **no** waypoint with a locked ETA — DCS then refuses to save the mission with *"Route has no waypoints with locked time!"* on every affected group. Fix: after building the route, if no waypoint is locked, lock the first one (its departure), as DCS itself does. Verified end-to-end on the demo mission (F18 Stennis 1, Yak 52 CTLD, test-QRA, … all now have a locked first waypoint). Note: the separate *"Invalid frequency 243 MHz"* error is user config — `presets.yaml` presets the UHF guard frequency (243.0), which DCS reserves; not a build bug.

**Branch**: `fix/WAYPOINTS-ETA-LOCKED` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-WP-ETA-001 | In `_inject_waypoints_into_group`, lock the first waypoint when the flight plan locked none, so DCS accepts the route. Respect an explicit lock on any waypoint. Regression tests. | `waypoints_injector/waypoints_injector_worker.py`, `test/python/` | fix | ✅ |
