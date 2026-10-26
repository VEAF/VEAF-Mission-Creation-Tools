# 11 — `validate_mission` and dynamic slots

Status: ✅ done

Martinho's session: `validate_mission` warned "`waypoints.yaml` est configuré mais la mission n'a aucun groupe d'aéronefs où injecter des waypoints" on a mission whose dynamic-slot template did receive the route (`routes_on_player_groups: 1` in the build report, the route read back from the `.miz`). The warning is wrong for a mission of dynamic slots only, and the AI reported it.

Fix: the check counts the dynamic-slot templates of the mission (the groups the waypoints injector gives a route to) as aircraft groups to inject into.

Done when: a test with a dynamic-slot template and no flight gives no such warning; one with neither still does.

## Result

Fix: `_check_presets_waypoints` skips the "no aircraft" warning when the mission offers dynamic slots, as the presets check beside it already did. The test fails without the fix (checked) and the case with no aircraft at all still warns.
