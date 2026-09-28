# FIX-OPEN-TRAINING-PROMPT-FINDINGS — what applying the 28/09 Open Training prompt to a mission found

Status: 🔄 in-progress — opened 2026-09-28; all six tickets done, PR under review.

## Origin

On 2026-09-28 the Open Training prompt gained the rules learnt from the hand-made Caucasus v5
Open Training (`4fdb8ab6`): a player-versus-player arena and sanctuaries, a carrier group, laser
drones, a non-combat helicopter zone with radio beacons, draw tags on the zones. An agent applied
them to `VEAF-Open-Training-Mission-GermanyCW-v6` the same day
(VEAF/VEAF-Open-Training-Mission-GermanyCW-v6#1), with the `veaf-mission-mcp` actions of
`develop` and `veaf-tools` 6.25.0.3.

Several pieces had no action and were written by script on the Lua table, as the prompt tells the
agent to do and to report. This lot is that report. Every figure was measured on that mission or
on `develop` at `8bc1a1fe`.

## The findings

| # | Defect | Measured |
|---|--------|----------|
| [01](tickets/01-air-slots-without-countermeasures.md) | `add_air_group` and `add_player_slot` build aircraft with no chaff, no flare, no callsign, and tail numbers that repeat from one group to the next | `aircraft_payload.py:48` writes `"flare": 0, "chaff": 0`; 92 arena slots fixed by script |
| [02](tickets/02-no-carrier-authoring.md) | Nothing places a working carrier: no ATC tasks on a ship, no deck slot, no ship warehouse | the CSG-74 Stennis group, 6 deck slots and its warehouse copied from the Caucasus v5 by script |
| [03](tickets/03-carrier-deck-offers-every-template.md) | The build opens a carrier's deck to every dynamic template of its side | 51 types on the Stennis, B-52H and CH-47 included; the unit data has no carrier-capability field |
| [04](tickets/04-no-radio-beacon-action.md) | No action makes a unit transmit a sound, or embeds the sound in the mission | three beacons and an SOS copied from the v5 "Mountain Hike", `mapResource` written by hand |
| [05](tickets/05-mission-parameter-five-names.md) | The mission is named by five different parameters across the catalogue | 42 of 47 actions: `miz_path` 17, `target` 9, `mission_yaml_path` 6, `folder_path` 6, `mission_path` 4 |
| [06](tickets/06-measure-late-activated-sanctuary-vertices.md) | The prompt says sanctuary vertices are late-activated units; nobody has checked DCS gives their position | `veaf.getPolygonFromUnits` reads `Unit.getByName(...):getPosition()`; the v5 used active ships |

Tickets 01 and 02 change what players fly: 01 puts pilots in a fight with no countermeasures, 02
is a whole feature the prompt asks for and the tools cannot build.

## Dismissed

- **The ammo dump a `-farp` spawns is not a CTLD logistic point.** Suspected because CTLD looks
  for `logisticUnitTypes` once, at `ctld.initialize()`, before the interpreter spawns the FARP
  (`veafInterpreter.DelayForStartup = 1`). Refuted by the code: `veafGrass` registers every FARP
  it builds with `CTLDZoneManager:registerFOBAsLogistic` (`veafGrass.lua`, "add FARP to CTLD FOBs
  and logistic units"). The prompt's advice to place a `FARP Ammo Dump Coating` beside a FARP is
  therefore only needed for an editor-placed FARP (`add_farp`), not for one spawned by `-farp`.

## One lot, one PR

One lot, as David prefers. 01, 02 and 04 live in `veaf_mission_mcp`, 03 in
`warehouses_injector` and the unit data, 05 across the catalogue. 06 is a measurement in DCS, and
may end in a one-line change to the prompt.

## Out of scope

- The briefing generator of the GermanyCW-v6 mission (`gather.py`, `gen_readme.py`): mission-side
  tooling, outside this repository.
- Carrier operations at runtime (`veafCarrierOperations`): not exercised yet, the mission has not
  flown; a defect found in game gets its own ticket.

## Definition of Done

- Every ticket closed, or measured and closed with its answer.
- The GermanyCW-v6 mission's scripts that stood in for a missing action can be replaced by the new
  actions, and a rebuild produces the same mission.
