# 01 — An air start carries its heading on a second waypoint

Status: ✅ done

Files: `veaf_mission_mcp/player_slot.py`, `veaf_mission_mcp/actions.py` (description), `known-limitations.yaml`, the MCP page, tests.

## What happened

An A-10C II slot, air start, `heading_deg: 180`, flew north (Marianas, 2026-10-12). Its single `Turning Point` gave DCS no direction, and the unit's `heading` is not what orients an air start.

## Measured

- The Marianas v5, saved by the Mission Editor: 13 air starts with two points or more, unit `heading` equal to the bearing of the second point and `psi` its opposite; 10 with one point, every one at heading 0.
- After the fix, a slot asked for 180° appeared with its nose at 180.3°, tracking 180.5°, 128 m/s (Caucasus, through the bridge, 10 s after spawning).

## Done

- An air start gets a second `Turning Point` 10 km ahead on the heading, at the same altitude and speed, its ETA the flying time and not locked, as the editor writes a later point; the unit gets `psi`, the opposite of the heading. A ground start is unchanged: its stand orients it.
- Tests: the bearing of the second point is the heading (0, 90, 180, 300°), the second point's shape, `psi`; a ground start keeps one point.
