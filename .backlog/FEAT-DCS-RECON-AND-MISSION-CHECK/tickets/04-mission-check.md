# 04 — mission-check: menus, zones, missions, routes

Status: 🔄 in progress

`veaf-tools dcs mission-check` on the test build the user launched:

- a. the F10 tree VEAF built (`veafRadio.radioMenu`), every empty label reported with its path;
- b. every combat zone and combat mission (CAP variants `<name>/<skill>/<scale>` included) activated and deactivated through the scripting state, units counted each time, every one left as it was found; operations are reported, not toggled (they cascade to their zones);
- c. every ground group with a route of more than one waypoint seen moving (speed > 0) within 60 s — the check that found the column frozen by an "On Road" route with no road;
- d. one line per check, a verdict at the end, exit code 1 on a failure.

Done when: the Lua builders and every parser are unit-tested, and the report's verdict follows the lines.
