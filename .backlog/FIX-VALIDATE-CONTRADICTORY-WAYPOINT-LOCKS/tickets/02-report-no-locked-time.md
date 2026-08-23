# 02 — Report a route with no locked-time waypoint

Status: ⬜ ready

## What

The symmetric case, already understood on the MCP side. DCS refuses to save a route where **no** waypoint
has a locked time: *"Route has no waypoints with locked time!"*.

[`FIX-WAYPOINTS-ETA-LOCKED`](../../archive/FIX-WAYPOINTS-ETA-LOCKED.md) taught `edit_route.py` to relock the
first waypoint when an edit removes the last lock (`_restore_eta_lock`). That protects routes the MCP
edits. It does nothing for a mission whose data came from anywhere else.

## Done when

- [ ] `mission validate` reports a route with no `ETA_locked` waypoint, naming the group
- [ ] The message points at the same repair the MCP already applies — lock the departure
- [ ] The two checks share their route-walking code rather than each finding waypoints their own way
