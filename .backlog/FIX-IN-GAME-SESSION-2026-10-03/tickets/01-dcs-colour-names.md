# 01 — smoke and flare colours are named the way DCS names them

Status: ✅ done
Type: fix

## Measured

`_spawn smoke, color red` asked from a marker on 2026-10-03: the confirmation came, no smoke, and
`dcs.log` read `VEAF-SCHEDULER|E| error in scheduled function: Parameter #2 (color) missed`.
`spawnSmoke` had received `color=[nil]`.

DCS names its colours with a capital and nothing else, read in game the same day:

| enum | keys |
|---|---|
| `trigger.smokeColor` | `Blue=4 Green=0 Orange=3 Red=1 White=2` |
| `trigger.flareColor` | `Green=0 Red=1 White=2 Yellow=3` |

Eleven sites wrote `RED`, `GREEN`, `WHITE`, `ORANGE`, `BLUE` — `nil` in DCS:

- `veafSpawnParser.lua`: every `color` option and the three smoke shortcuts — every coloured smoke
  or flare asked from a marker;
- `veafSpawnObjects.lua`: the green smoke and the red flares of `-farp` and of the FOB/beacon spawn;
- `veafSpawnGround.lua`: the start, end and group smokes of a convoy.

The combat-zone smoke wrote `Red` and worked (seen by David the same day).

## Why nothing caught it

The parser test asserted `r.smokeColor == trigger.smokeColor.RED`: `nil == nil`. The smoke mock was
right; the flare mock was wrong twice over (`RED = 0, GREEN = 1`, upper case and swapped).

## Done

- the sites use the DCS names; the flare mock carries the measured table;
- the parser and flare tests assert the DCS names, so they now compare against a number;
- the mocked `trigger.action.smoke` and `signalFlare` refuse a nil colour, as DCS does, so a colour
  that goes missing at runtime fails the suite too;
- `test/python/test_lua_names_that_exist.py` sweeps `src/scripts/veaf/` for any
  `trigger.smokeColor.X` / `trigger.flareColor.X` whose key DCS does not define. It failed on the 15
  uses before the fix.

## Not done, noted

`spawnSignalFlare` is handed `options.smokeColor`: a smoke colour used as a flare colour. Red, green
and white have the same number in both tables; orange (3) comes out yellow, blue (4) is no flare
colour at all.
