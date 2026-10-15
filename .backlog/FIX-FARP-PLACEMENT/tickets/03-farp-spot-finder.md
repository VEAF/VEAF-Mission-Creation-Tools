# 03 — An in-game finder for a flat, clear FARP spot

Status: 🧑 waiting-human

Files: `veaf_tools` (a `dcs` subcommand next to `clear-ground-check`), the dcs-bridge client, docs, tests on the Lua it sends.

## What happened

With no grid and no catalogue (MarianaIslands), the only way to find a usable FARP spot was a probe written for the mission and run through dcs-bridge: `VEAF-Open-Training-Mission-Marianas-v6/tools/find_farp_spot.py`. For each point of a 50 m grid within a radius, it asks DCS for the surface type (ground), for the small `Disposition.getSimpleZones` query (a free 5 m spot within 20 m — the only reliable use of that call, known limitation `disposition-getsimplezones-is-a-lottery`) at the centre and at 8 points 40 m around, and for `land.getHeight` at those points; it keeps the points whose 9 tests pass and whose height range is under 3 m. On Merizo it found exactly one spot within 1.2 km.

## Done when

- `veaf-tools dcs farp-spot <x> <y> [--radius m] [--max-drop m]` lists the flat and clear spots nearest first, through the bridge, from a running mission.
- It runs in slices that each stay under the bridge's call timeout (the mission's script splits the grid into 300 m bands).
- `add_farp`'s warning (ticket 01) points to it when the theatre has no data to check the pad.
- Tests: the Lua it builds is the expected one; the parser of its answer.

## Done so far (2026-10-12, #1125)

- `veaf-tools dcs farp-spot <theatre> --at x,y [--radius] [--max-drop] [--limit] [--report]`, on the empty survey mission like `scenery-objects`. The point is an option, not two arguments: click reads `-22300` in a positional slot as an unknown option (measured: « No such option: -2 »), and Marianas coordinates are negative.
- The band chunk was executed in Lua 5.1 against mocks (water, a blocked ring point, the radius, the error path); the CLI is driven end to end against a fake DCS.

## Left

- One run against DCS around Merizo: it should find the spot the mission's probe found, some 1.2 km away (2.5 m over 80 m).
