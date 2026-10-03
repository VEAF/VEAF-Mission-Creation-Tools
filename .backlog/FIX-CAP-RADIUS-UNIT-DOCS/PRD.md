# FIX-CAP-RADIUS-UNIT-DOCS — `-cap` `capradius` is in nautical miles, not metres

Status: ✅ done — merged in #1056 (2026-10-03)

## Problem

`veafSpawn.spawnCombatAirPatrol` reads `capRadius` and `distance` in **nautical miles**
(`(capRadius or 60) * 1852`, `(distance or 20) * 1852`); the marker parser hands both through
unchanged (`veaf.markerRules.number`). The pages said metres: "rayon d'orbite CAP (mètres)" /
"CAP orbit radius (meters)", and the example `_spawn cap, name Su-27, alt 25000, capradius 20000`
asked for a 20 000 NM zone. `distance` was described as "distance from marker"; it is the length of
the race-track leg. The API reference had both in metres.

The helicopter `capradius` (FEAT-HELICOPTER-SPAWN) is a different consumer of the same key and is
in metres — left as is, and now pointed out from the CAP options.

## Tickets

- [01 — correct the units in the CAP docs](tickets/01-cap-units-in-docs.md)

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**`-cap` `capradius` is in nautical miles.** The code multiplies it by 1852 (60 NM by default) and the pages said metres, with an example asking for a 20 000 NM zone; `distance`, the race-track leg (20 NM), was described as a distance from the marker. Docs only
