# FEAT-DCS-REFERENCE-DATA-03 — callsigns from DCS's own table

Status: ✅ done — 2026-10-08
Type: fix
Files: `veaf_mission_mcp/aircraft_identity.py`, tests

## What

Our list of countries whose aircraft carry a numeric callsign held 5 countries, measured on the missions we had; DCS's callsign table marks 10.
A GDR or Belarus flight written by the MCP got a named callsign where the Mission Editor gives a number.

## Measured (2026-10-08)

The Mission Editor's own `isWesternCountry` (`MissionEditor/modules/me_utilities.lua`) lists exactly the ten countries the reference's `numeric` flag marks: Russia, Ukraine, Insurgents, Abkhazia, South Ossetia, China, Belarus, USSR, Yugoslavia, GDR.

## Done

- `NUMERIC_CALLSIGN_COUNTRIES` holds the ten, sourced in the module docstring. A constant rather than a generated table: ten names fixed in the editor's code do not justify a generator.
- Tests: each of the ten gets a number; Kazakhstan still gets a word.
