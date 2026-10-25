# 02 — Two plan waypoints with the same name

Status: ✅ done

The assistant declared `COAST_OUT` and `COAST_IN` in `waypoints.yaml`, both with `name: "COAST"`, and listed both in the plan.
`_inject_waypoints_into_group` (`waypoints_injector/waypoints_injector_worker.py`) indexes points by name to replace a re-injected point in place (so a rebuild does not double the route), and that index also catches the second point of the same plan: it replaced the first, silently, and the route lost a point.

Keep the replacement for points that were already in the group's route before this injection; two points of the same plan with the same `name` are a build error naming both keys, the plan and the name.
`validate_mission` reports the same thing before the build.

Done when: a plan with two same-named points fails the build and the validation with that message; a rebuild of a valid plan still does not double the route; tests for both.

## Result

Fix: `duplicate_cockpit_names` finds the plans listing two waypoints with one cockpit name (the `name:`, or the key); the injector only replaces a point that was already in the route, once: two injected points sharing a name are both kept, which is the fix of the loss.
Changed after the review of #1189: the first version also refused such a plan at build time. With the injector fixed nothing is lost any more, and the refusal would have broken a legitimate plan such as `[HOME, IP, TGT, HOME]`; so `read_yaml` and `validate` now **warn** (two points nobody can tell apart in the cockpit or the briefing), the same key listed twice is not reported, and only `set_route` still refuses a repeated name.
Tests: `TestDuplicateCockpitNames`, `test_validate_waypoint_names.py`, `test_two_injected_points_with_one_name_are_both_kept`.
