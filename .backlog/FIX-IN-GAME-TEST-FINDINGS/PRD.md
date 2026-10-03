# FIX-IN-GAME-TEST-FINDINGS — what the first in-game test of an MCP-built mission found

Status: ✅ done — all five tickets fixed 2026-09-29; verified in game 2026-10-03 (R17) except ticket 03's case of an unguided weapon near a sanctuary, which was not flown — covered by unit tests only

## Origin

On the evening of 2026-09-28 David loaded `VEAF-Open-Training-Mission-GermanyCW-v6`, built with
`veaf-tools` from `develop` at `5c6f8fec`, as game master in single player, with the dcs-bridge
trigger injected. An agent measured it through `/api/exec` and `dcs.log`, activating combat
zones one by one. It was the first time a mission authored from scratch with the
`veaf-mission-mcp` actions was run in DCS rather than checked in its files.

Most of it held: sanctuaries, carrier operations, CTLD logistic points, draw tags, laser drones.
Two defects did not, and neither can be seen in the mission files. Three more showed once the mission
ran on the private1 server with several players.

## The findings

| # | Defect | Measured |
|---|--------|----------|
| [01](tickets/01-statics-without-shape-name.md) | A static placed by `add_group` / `create_combat_zone` carries no `shape_name`, and DCS refuses some types without one | 4 of the mission's objectives never existed: `unknown static shape_name, category Fortification, type: .Command Center` (and `.Ammunition depot`) at mission load |
| [02](tickets/02-combat-zones-initialized-twice.md) | Every combat zone is initialized twice | each zone's startup lines logged twice; Torgau reports « 8 element(s) » for 4 |
| [03](tickets/03-sanctuary-weapon-check-errors.md) | The sanctuary's weapon check raises on a weapon with no target, or already gone | on private1: `…:58320: attempt to index local 'target'` after a CBU-105 and two AGM-88C, `…:58303: Weapon doesn't exist` after an AI 57 mm round |
| [04](tickets/04-ctld-sample-lists-in-every-mission.md) | Every scaffolded mission starts with CTLD's sample `extract` and `logistic` names | 25 + 10 « not found » warnings at start; none of the names exists |
| [05](tickets/05-no-cities-for-recent-theatres.md) | `veafNamedPoints` has no cities for GermanyCW, nor the other recent theatres | `no cities in veafNamedPoints for theatre GermanyCW`; six theatres have a list |

01 is the one players meet: a strike zone whose main target is absent, with nothing in the
mission, the build or the validation to say so.

## One lot, one PR

01 lives in `veaf_mission_mcp` and the unit data, 02 in the combat-zone runtime or its generator, 03
in the sanctuary runtime, 04 in `ctld_config.py`, 05 in `veafNamedPoints` and its data.

## Out of scope

- The drones' height: CTLD re-routes a JTAC drone to `JTAC_droneAltitude` (3 000 m AGL) whatever
  the mission says. That is CTLD doing what its setting asks; the mission's texts were corrected.

## Definition of Done

- The five tickets closed; the GermanyCW-v6 statics placed by the MCP spawn in DCS without the
  hand-written `shape_name` the mission now carries.

## In-game check — 2026-10-03

From `FIX-IN-GAME-SESSION-2026-10-03`.

GermanyCW-v6 from `develop`, the four shapes rewritten by `repair_static_shapes`: no
`unknown static shape_name`, one initialisation of Torgau, Torgau activating with 6 elements (the six
groups the mission now declares), no script error. The unguided weapon near a sanctuary was not run.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**what the first in-game test of an MCP-built mission found.** Opened 2026-09-28 on GermanyCW-v6: statics placed without a `shape_name`, which DCS refuses for some types (four objectives never existed), every combat zone initialized twice, the sanctuary's weapon check raising on a weapon with no target or already gone, CTLD's sample `extract` / `logistic` names in every mission, and no cities for GermanyCW. All five fixed 2026-09-29; the in-game reading is R17 of `DCS-SESSION-TODO.md`
