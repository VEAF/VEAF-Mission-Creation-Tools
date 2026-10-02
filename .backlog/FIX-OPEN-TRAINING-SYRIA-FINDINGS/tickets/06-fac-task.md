# 06 — add_air_group: a laser drone through the AFAC group task

Status: ✅ done

Files: `veaf_mission_mcp/add_air_group.py`, `veaf_mission_mcp/actions.py` (description), tests.

## What happened

The Syria findings asked for an en-route FAC task in `edit_route`, on the belief that no permanent laser
drone could be built. **That premise was wrong** (the Syria session, 2026-10-02): GermanyCW-v6 built two,
lasing checked in game on 2026-09-28 (its `docs/journal-v6.md` §11 and §12). Measured in its mission file:
an MQ-9 whose **group task is `AFAC`**, one waypoint carrying `SetUnlimitedFuel` then an `Orbit` in a
`Circle` at the group's altitude and speed, and the JTAC itself declared in `modules.ASSETS` (`jtac`,
`freq`, `mod`) — CTLD lases, not a DCS task. The MCP could already write each piece (`add_air_group`
takes any task, `edit_route` has `orbit` and `set_unlimited_fuel`), but nothing put them together, and
the Open Training prompt asked for « la tâche FAC ».

Three facts from the in-game check, for the description: CTLD moves the drone to `JTAC_droneAltitude`
(3 000 m AGL) whatever is written; the JTAC designates vehicles only; it lases within 10 km.

## Done when

- `add_air_group task: "AFAC"` writes the GermanyCW-v6 first point: `SetUnlimitedFuel`, then a `Circle`
  orbit at the group's altitude and speed.
- The action description says the JTAC comes from `modules.ASSETS` and names the three facts.
- Test: the first point's task list equals the measured shape.
