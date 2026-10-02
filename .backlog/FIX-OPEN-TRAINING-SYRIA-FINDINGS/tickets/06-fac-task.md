# 06 — edit_route: the FAC task

Status: ⬜ ready (needs an in-game check)

Files: `veaf_mission_mcp/edit_route.py`, `veaf_mission_mcp/actions.py`, `.prompts/new-open-training-mission.*.md`,
`DCS-SESSION-TODO.md`, tests.

## What happened

The Open Training prompt offers laser-designating drones « en orbite avec la tâche FAC », declared in
`modules.ASSETS` with `jtac`/`freq`/`mod`. `edit_route` has a closed task set without FAC, so no permanent
drone could be built; the Syria briefing points the pilots at `-afac` instead.

## Done when

- `add_task task=fac` writes the DCS en-route FAC task with its frequency, modulation, callsign and laser
  code, validated like the other tasks, and combines with `orbit`.
- A DCS session (dcs-serve) confirms an MQ-9 with the task answers on its frequency and lases; until then the
  ticket stays 🧑 and the prompt keeps its fallback.
