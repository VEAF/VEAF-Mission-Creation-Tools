# 05 — `dcs scenery-objects` + `offer_scenery_lookup`: find a map object's id

Status: 🧑 waiting-human (code done; the in-game check below needs DCS)

Files: `veaf_libs/scenery_lookup.py` (new), `veaf_tools/commands/clear_ground.py`,
`veaf_tools/command_tree.py`, `veaf_tools/app.py`, `veaf_mission_mcp/actions.py`, the locales,
`doc/CLI_REFERENCE*.md`, `doc/mission-maker/GUIDE*.md`, `doc/developer/mission-editing-mcp*.md`.

The ids `scenery_targets` takes exist only inside DCS. The command reuses the `clear-ground-check`
session (dcs-serve, empty survey mission, instructions, waiting) and runs `world.searchObjects` over
`Object.Category.SCENERY` around each `--around x,y[,radius]` point; the MCP action, like
`offer_clear_ground_check`, launches nothing and returns the command.

## Done when

- One line per object: point, id (`getName`, the number the register keys on), type, position,
  distance to the point; sorted by point then distance; `--report` writes them as JSON.
- Mission `y` is sent as DCS `z`; a malformed point or a non-positive radius stops the command; an
  answer that is not the expected format raises instead of becoming an empty list.
- The command is machine-only (not in the TUI wizard), listed under `dcs`.

## To check in DCS

On Syria, around a known bridge: the command lists it, and the id it gives is the one the
destroyed-scenery register records when the bridge is destroyed (ticket 04's check, same object).
