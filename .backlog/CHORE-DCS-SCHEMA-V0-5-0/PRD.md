# CHORE-DCS-SCHEMA-V0-5-0 — take dcs-world-schema v0.5.0

Status: ✅ done — 2026-10-06

The drift watch reported `YoloWingPixie/dcs-world-schema` `v0.4.0` → `v0.5.0` (released 2026-10-04) on #1076.
A routine verbatim sync, done the way `FIX-CAP-SIDE-TEMPLATES` ticket 02 took `v0.4.0`.

## What v0.5.0 changes for this repository

Nothing in the scripting API.
Upstream added reference data read from an exact `_G` dump (weapon and aircraft flight models, more sensor, mobility and ballistics fields) and stopped rounding numbers to 14 significant digits.

## Measured (2026-10-06)

- `dcs-world-api.lua`, the LuaLS annotations `.luarc.json` loads, is **byte-identical** to `v0.4.0`.
- `dcs-world-api-schema.json` is the published asset byte for byte (SHA-256 `56b1366005d4d0b7…`).
  The structural diff touches 50 entries, all under `types.Entity.*`: 22 types added, 1 removed (`CenteredScanVolume`), 27 with changed fields.
  No function, namespace or `country.*` table moves.
- `audit-dcs-mocks` gives the same report on `v0.4.0` and `v0.5.0`.
- The vendored `LICENSE` said `Zach Shepard` where the `LICENSE` of both the `v0.4.0` and `v0.5.0` tags says `YoloWingPixie`: the previous bump did not take it from the tag. Replaced with the `v0.5.0` one, verbatim.

## Tickets

- [01 — vendor v0.5.0](tickets/01-vendor-v0-5-0.md)
