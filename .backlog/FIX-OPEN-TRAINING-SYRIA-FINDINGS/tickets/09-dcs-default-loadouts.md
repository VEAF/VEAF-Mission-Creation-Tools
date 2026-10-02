# 09 — DCS default loadouts by name

Status: ✅ done

Files: `veaf_build` (`update-dcs-data`), a new `veaf_libs/data/payloads.yaml`, `veaf_mission_mcp/aircraft_payload.py`,
`veaf_mission_mcp/oracle.py`, tests.

## What happened

`loadout_from` copies a `veafSpawn-*` template, and the shipped catalogue has none for MiG-29, Su-27, Su-30,
MiG-31, Su-24, F-16 (AI), Tu-22M3 or F-15E. The Syria mission needed all of them: their pylons were read from
DCS's `UnitPayloads/*.lua`, the loadouts the Mission Editor offers by name.

## Done when

- The datamine's default payloads ship as `payloads.yaml` (type → payload name → pylons).
- `add_air_group`, `create_qra` and `create_cap_mission` accept a DCS payload by name in a `payload`
  parameter beside `loadout_from` (David, 2026-10-02 — not a `dcs:` prefix inside `loadout_from`); an
  unknown name is refused with the type's list.
- A read-only `list_payloads(type)` action.

## Measured while doing it (2026-10-02)

**The datamine has no payload files**: its tree holds `_G/db/Units`, `_G/Pylons`, the weapons tables — no
`UnitPayloads` (checked at the pinned ref). The loadouts the editor lists by name live in an install's
`MissionEditor/data/scripts/UnitPayloads/*.lua` (62 files here, 45 with at least one loadout, 613
loadouts). So `payloads.yaml` is generated from an install, the way `--airfield-freqs` and `--cities`
read theirs: `veaf-build update-dcs-data --payloads --dcs-path <DCS>`, committed, outside `--all` and
the CI drift guard (CI has no DCS). Keyed by the file's `unitType`, not its name (`F-16C.lua` holds
`F-16C bl.52d`); `Su-30.lua` repeats a name, the first loadout is kept.
