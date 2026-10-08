# FEAT-DCS-REFERENCE-DATA-03 — callsigns from DCS's own table

Status: ⬜ ready
Type: fix
Files: `veaf_mission_mcp/aircraft_identity.py`, `veaf_build/dcs_data/`, tests

## What

Derive which countries carry a numeric callsign, and the callsign names offered per country and category, from the reference's `callsigns` table instead of `NUMERIC_CALLSIGN_COUNTRIES`.

## Why

Ours lists 5 countries, measured on the missions we had; DCS's table marks 10 (adds Insurgents, South Ossetia, Belarus, Yugoslavia, GDR).
A GDR or Belarus flight written by the MCP today gets a named callsign where the Mission Editor gives a number.

## Before writing code

Check one of the five added countries in the Mission Editor (a flight of Belarus is enough): the reference's `numeric` must match what the editor writes.
If it does not, the ticket is closed with the measurement.

## Done when

- The numeric countries and the callsign lists come from the generated data.
- Test: a GDR flight gets a numeric callsign; a USA flight still gets a named one.
