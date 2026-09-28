# FIX-IN-GAME-TEST-FINDINGS — what the first in-game test of an MCP-built mission found

Status: ⬜ ready — opened 2026-09-28.

## Origin

On the evening of 2026-09-28 David loaded `VEAF-Open-Training-Mission-GermanyCW-v6`, built with
`veaf-tools` from `develop` at `5c6f8fec`, as game master in single player, with the dcs-bridge
trigger injected. An agent measured it through `/api/exec` and `dcs.log`, activating combat
zones one by one. It was the first time a mission authored from scratch with the
`veaf-mission-mcp` actions was run in DCS rather than checked in its files.

Most of it held: sanctuaries, carrier operations, CTLD logistic points, draw tags, laser drones.
Two defects did not, and neither can be seen in the mission files.

## The findings

| # | Defect | Measured |
|---|--------|----------|
| [01](tickets/01-statics-without-shape-name.md) | A static placed by `add_group` / `create_combat_zone` carries no `shape_name`, and DCS refuses some types without one | 4 of the mission's objectives never existed: `unknown static shape_name, category Fortification, type: .Command Center` (and `.Ammunition depot`) at mission load |
| [02](tickets/02-combat-zones-initialized-twice.md) | Every combat zone is initialized twice | each zone's startup lines logged twice; Torgau reports « 8 element(s) » for 4 |

01 is the one players meet: a strike zone whose main target is absent, with nothing in the
mission, the build or the validation to say so.

## One lot, one PR

01 lives in `veaf_mission_mcp` and the unit data, 02 in the combat-zone runtime or its generator.

## Out of scope

- The drones' height: CTLD re-routes a JTAC drone to `JTAC_droneAltitude` (3 000 m AGL) whatever
  the mission says. That is CTLD doing what its setting asks; the mission's texts were corrected.

## Definition of Done

- Both tickets closed; the GermanyCW-v6 statics placed by the MCP spawn in DCS without the
  hand-written `shape_name` the mission now carries.
