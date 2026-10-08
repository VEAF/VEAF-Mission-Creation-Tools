# FEAT-DCS-REFERENCE-DATA-04 — spotter sight from the unit's sensors

Status: 🚫 wontfix — 2026-10-08

## What was planned

Give each spotter the sight range its real sensors allow, from the reference's `sensors` table, instead of the range of the first `SpotterUnitTable` row its attributes match.

## Why it is not done

Both premises were wrong (measured 2026-10-08, `v0.5.0`):

- **Optical sensors carry no range.** All 134 optical sensors (`OPTIC_SENSOR_TV`, `_LLTV`, `_IR`) have a null `detectionRangeKm`; they only carry magnifications. The ranges that exist are radars' and the unit-level `DetectionRange`, which `dcsUnits.yaml` already has as `detection_range_m`.
- **The zero range of `SAM elements` is deliberate.** `veafSkynetIadsHelper.lua` documents it above `SpotterUnitTable`: those units are covered by the last line of defence (a radius drawn once between 10 and 15 km), and a second competing radius would make one of the two settings dead weight.

So `air-defence-spotters-are-blind` describes a design choice, and its workaround (spot with manpads or ordinary vehicles) stands.
