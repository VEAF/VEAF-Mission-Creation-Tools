# 08 — `_spawn signal` fires the smoke colour

Status: 🔄 fixed — to see in game
Type: fix

From ticket 01, "not done, noted": `spawnSignalFlare` was handed `options.smokeColor`. Red, green and
white share a number in both tables; orange (smoke 3) came out yellow (flare 3), and blue (smoke 4) is
no flare colour at all.

## Done

The parser keeps the colour name as asked (`options.colorName`); the `signal` handler reads it against
`veafSpawn.SIGNAL_FLARE_COLORS` — `red` (the default), `green`, `white`, `yellow`. `orange` and `blue`
are refused with a message naming the four (David's call, 2026-10-03: a message, not a fallback).
Documented in `doc/mission-maker/scripts/veafSpawn(.en).md`.
