# Lot FEAT-DCS-REFERENCE-DATA — use the dcs-world-schema reference data

Status: 🔄 in-progress
Branch: feature/dcs-reference-data → PR → develop

## Problem Statement

Since `v0.4.0`, `YoloWingPixie/dcs-world-schema` attaches to each release a database read from DCS itself (`v0.5.0`: DCS 2.9.30.28536), shipped as SQLite, a Python wheel, an npm package and a Lua 5.1 package.
It holds 798 airbases with their beacons and navaids, 3 077 liveries with the countries allowed to use them, 92 per-country callsign tables, 244 sensors (radars with a range, optics without), the threats, the weapons and the AI options and tasks.

Several of our own data files and validations are hand-captured or missing where this database already answers:

- `airdromes.yaml` and `airdrome-positions.yaml` need DCS running to dump `world.getAirbases()` by hand, theatre by theatre.
- The MCP takes a livery id without checking it (`set_unit_properties.py`: "no skin inventory ships here").
- `aircraft_identity.NUMERIC_CALLSIGN_COUNTRIES` is a list measured on the missions we had, not DCS's own table.
- `veafSkynet.SpotterUnitTable` gives every unit a sight range from its first matching attribute, which makes air-defence vehicles blind (`air-defence-spotters-are-blind`).

## Measured (2026-10-08, `v0.5.0` SQLite asset)

- **Airbases**: name and id identical to `airdromes.yaml` for all 798 airbases of 13 theatres. **TheChannel is absent** from the reference (12 airbases in ours).
  The reference also carries the reference point, magnetic variation, longest runway, and the ILS / TACAN / VOR of each runway; `airfield-frequencies.yaml` has TACAN (from `Beacons.lua`) but no ILS.
- **Callsigns**: the reference marks **10** countries as numeric (Russia, Ukraine, Insurgents, Abkhazia, South Ossetia, Belarus, China, Yugoslavia, USSR, GDR); ours lists **5** (Russia, USSR, Ukraine, China, Abkhazia).
- **Sensors**: DCS gives the Shilka (`TKN-3B day`) and the Osa (`Karat visir`) optics; the blindness is our table's, not DCS's. The Strela-10M3 and the ZU-23 Ural have no sensor at all.
- **Not in the reference**: named loadouts (`UnitPayloads`) — `payloads.yaml` keeps reading an install.

## Out of scope

- Replacing the Quaggles datamine for the whole of `update-dcs-data`: the reference lacks payloads and TheChannel, and depends on a single maintainer.

## Tickets

- [01 — airdromes from the reference data](tickets/01-airdromes-from-reference.md) · ✅ — positions move to the runways' centre
- [02 — validate liveries against the reference](tickets/02-validate-liveries.md) · 🚫 — the reference misses zipped liveries
- [03 — callsigns from DCS's own table](tickets/03-callsigns-from-reference.md) · ✅
- [04 — spotter sight from the unit's sensors](tickets/04-spotter-sight-from-sensors.md) · 🚫 — optics carry no range, and the blind SAM elements are by design
