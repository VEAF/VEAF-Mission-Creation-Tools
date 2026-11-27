# 01 — The waypoint number on the zone page

Status: ✅ done
Type: feature
Files: `mission_briefing/mission_briefing_worker.py`, `veaf_libs/locales/{fr,en}.json`, `test/python/mission_briefing/test_briefing_parity_marteau.py`

`waypoint_numbers(name, picture)` returns `W4/H4` for the waypoint of that name on the players' routes; `objective_notes` uses it in the `Point :` line. Tests: the numbers appear (plane and helicopter routes), the name alone when no route carries it, no line without a label.
