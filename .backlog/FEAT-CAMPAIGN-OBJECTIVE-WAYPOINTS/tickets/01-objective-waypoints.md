# 01 — `campaign next` writes the objectives as waypoints; the plan's key/value said plainly

Status: ⬜ ready

- `campaign_manager.next_mission`: write `src/waypoints.yaml` from the mission's objective zones (named by the tasks of `briefing.yaml`, else the campaign's objectives), for the players' side, planes and helicopters; keep a file edited since.
- `waypoints_manager`: decide whether a plan's value means anything; say it in the shipped example and the doc either way.
- Tests on the generated file (zones, order, side, altitudes) and on a second `campaign next` keeping an edited file.
