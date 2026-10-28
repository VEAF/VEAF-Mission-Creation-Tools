# 05 — Step-by-step flight plan, deployment page

Status: ✅ done

The flight plan becomes step sheets, one per waypoint: its number and name, coordinates, altitude, heading and distance from the previous point, highest ground on the leg, and what is done there (new optional `waypoint_notes`, by waypoint name), with a thumbnail of the overview. A new optional `deployment` text makes a "deployment and coordination" page.

Done when: the behaviour is covered by a test, and the action's documentation says it.

## Result

`route_steps` shared by the kneeboard flight card and the step sheets; one card per waypoint with the leg from the previous point, DMS, DDM, altitude, the `waypoint_notes` text (a name the route lacks is warned) and a thumbnail of the overview. `deployment` page after the flow. Tests: `TestTheSheets`, `test_the_deployment_and_the_waypoint_notes_reach_the_deck`.
