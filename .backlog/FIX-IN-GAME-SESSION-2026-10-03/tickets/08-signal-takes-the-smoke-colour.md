# 08 — `_spawn signal` fires the smoke colour

Status: ✅ done — verified in game 2026-10-03
Type: fix

From ticket 01, "not done, noted": `spawnSignalFlare` was handed `options.smokeColor`. Red, green and
white share a number in both tables; orange (smoke 3) came out yellow (flare 3), and blue (smoke 4) is
no flare colour at all.

## Done

The parser keeps the colour name as asked (`options.colorName`); the `signal` handler reads it against
`veafSpawn.SIGNAL_FLARE_COLORS` — `red` (the default), `green`, `white`, `yellow`. `orange` and `blue`
are refused with a message naming the four (David's call, 2026-10-03: a message, not a fallback).
Documented in `doc/mission-maker/scripts/veafSpawn(.en).md`.

## Seen in game (2026-10-03, second pass)

`dcs.log` reads `spawnSignalFlare(color = 1 / 0 / 2 / 3)` for red, green, white, yellow; `orange` and
`blue` each produced the message *« Pas de fusée orange / blue dans DCS »* and nothing in the sky.
David saw the flares go up, several colours, at 400 m (at 1.5 km in daylight he saw none).
