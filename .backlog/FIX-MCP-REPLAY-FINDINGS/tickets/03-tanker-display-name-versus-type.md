# 03 — `add_air_group` and a unit's display name

Status: ⬜ ready
Type: measure, then fix
Files: `src/python/veaf-tools/veaf_mission_mcp/` (`add_air_group` and its validation), `veaf_libs/data/dcsUnits.yaml` (read), tests

Measure first: on a scratch mission folder, call `add_air_group` with `unit_type: "KC-135MPRS"` and read the built group. Does the action resolve the display name to the type `KC135MPRS`, or write a wrong type that DCS ignores?
- If it resolves: say so in the action's description and the guide, and stop.
- If it writes the wrong type: validate `unit_type` against the catalogue and answer with the closest valid type (`did you mean KC135MPRS`), in both profiles.
Also check, with `inspect_built_mission`, that the built `.miz` of the replay holds the maximum visibility (80 000 m) and report the value (point 1 of the PRD).
Tests for whichever branch applies; the measured values go into the ticket.
