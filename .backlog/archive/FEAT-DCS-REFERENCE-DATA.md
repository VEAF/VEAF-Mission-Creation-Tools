# Lot FEAT-DCS-REFERENCE-DATA — use the dcs-world-schema reference data

Status: ✅ done — 2026-10-08 (#1098) · archived 2026-11-24
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

- [01 — airdromes from the reference data](FEAT-DCS-REFERENCE-DATA.md) · ✅ — positions move to the runways' centre
- [02 — validate liveries against the reference](FEAT-DCS-REFERENCE-DATA.md) · 🚫 — the reference misses zipped liveries
- [03 — callsigns from DCS's own table](FEAT-DCS-REFERENCE-DATA.md) · ✅
- [04 — spotter sight from the unit's sensors](FEAT-DCS-REFERENCE-DATA.md) · 🚫 — optics carry no range, and the blind SAM elements are by design

## Tickets, in full

## FEAT-DCS-REFERENCE-DATA-01 — airdromes from the reference data

Status: ✅ done — 2026-10-08
Type: feat
Files: `veaf_build/dcs_data/reference.py`, `veaf_build/dcs_data/airdromes.py`, `veaf_build/cli.py`, `veaf_libs/data/airdromes.yaml`, `veaf_libs/data/airdrome-positions.yaml`, `.github/workflows/dcs-data-consistency.yml`, `doc/developer/dcs-data.md` (+ `.en.md`), tests

### What

Generate `airdromes.yaml` and `airdrome-positions.yaml` from the reference database of a pinned `dcs-world-schema` release, instead of the runtime dumps under `veaf_build/dcs_data/airbase_dumps/`.
Keep the runtime dump for **TheChannel**, which the reference does not carry.

### Measured (2026-10-08, `v0.5.0`)

- Names and ids: 798 of 798 identical to the dumps; `airdromes.yaml` regenerates with its header changed only.
- Positions: the reference point sits on the runways' centre (median 0 m from the mean of the runway thresholds, on all 13 theatres); `Airbase:getPoint()`, what the dumps held, lands 300 m to 1.4 km away (medians per theatre). The reference's lat/lon match its own `x`/`z` through our projection to 0.1 m.
- The Afghanistan dump had FOB Clark at (0, 0); the reference places it.

### Done

- `veaf_build/dcs_data/reference.py` downloads the SQLite asset at a pinned release and checks its SHA-256. The repository's JSON copy was not used: some of its paths exceed the Windows path limit once checked out.
- The reference wins for a theatre it knows; a dump fills a theatre it lacks. The dumps stay committed: `airfield_freqs` reads airbase names from them.
- `--airdromes` joins the no-flag / `--all` run and the CI drift guard.
- ILS per runway was left out: no consumer yet.

## FEAT-DCS-REFERENCE-DATA-02 — validate liveries against the reference

Status: 🚫 wontfix — 2026-10-08

### What was planned

Ship the stock liveries per unit type with their allowed countries, and have the MCP warn about a livery DCS would not show.

### Why it is not done

The reference database does not read **zipped** liveries, and most module liveries ship zipped.
Measured on 2026-10-08 against `v0.5.0` and the install on DAVID-BUREAU:

| Type | Liveries in the install | In the reference |
|---|---|---|
| `F-16C_50` | 52 (`CoreMods/aircraft/F-16C/Liveries/F-16C_50`, mostly `.zip`) | 2 (`Dark_Viper`, `default`) |
| `FA-18C_hornet` | its folder exists | none mapped to the type |

A warning built on it would fire on most legitimate liveries.
Generating the table from an install instead (as `--payloads` does) was weighed and declined (David, 2026-10-08): a generator reading archives, outside the CI guard, covering only the modules installed where it runs.
The MCP keeps saying the livery is not validated, which stays true.

## FEAT-DCS-REFERENCE-DATA-03 — callsigns from DCS's own table

Status: ✅ done — 2026-10-08
Type: fix
Files: `veaf_mission_mcp/aircraft_identity.py`, tests

### What

Our list of countries whose aircraft carry a numeric callsign held 5 countries, measured on the missions we had; DCS's callsign table marks 10.
A GDR or Belarus flight written by the MCP got a named callsign where the Mission Editor gives a number.

### Measured (2026-10-08)

The Mission Editor's own `isWesternCountry` (`MissionEditor/modules/me_utilities.lua`) lists exactly the ten countries the reference's `numeric` flag marks: Russia, Ukraine, Insurgents, Abkhazia, South Ossetia, China, Belarus, USSR, Yugoslavia, GDR.

### Done

- `NUMERIC_CALLSIGN_COUNTRIES` holds the ten, sourced in the module docstring. A constant rather than a generated table: ten names fixed in the editor's code do not justify a generator.
- Tests: each of the ten gets a number; Kazakhstan still gets a word.

## FEAT-DCS-REFERENCE-DATA-04 — spotter sight from the unit's sensors

Status: 🚫 wontfix — 2026-10-08

### What was planned

Give each spotter the sight range its real sensors allow, from the reference's `sensors` table, instead of the range of the first `SpotterUnitTable` row its attributes match.

### Why it is not done

Both premises were wrong (measured 2026-10-08, `v0.5.0`):

- **Optical sensors carry no range.** All 134 optical sensors (`OPTIC_SENSOR_TV`, `_LLTV`, `_IR`) have a null `detectionRangeKm`; they only carry magnifications. The ranges that exist are radars' and the unit-level `DetectionRange`, which `dcsUnits.yaml` already has as `detection_range_m`.
- **The zero range of `SAM elements` is deliberate.** `veafSkynetIadsHelper.lua` documents it above `SpotterUnitTable`: those units are covered by the last line of defence (a radius drawn once between 10 and 15 km), and a second competing radius would make one of the two settings dead weight.

So `air-defence-spotters-are-blind` describes a design choice, and its workaround (spot with manpads or ordinary vehicles) stands.
