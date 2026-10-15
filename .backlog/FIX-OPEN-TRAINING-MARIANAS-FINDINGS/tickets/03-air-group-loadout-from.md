# 03 — add_air_group takes loadout_from

Status: ✅ done

Files: `veaf_mission_mcp/actions.py` (`add_air_group` schema), `veaf_mission_mcp/add_air_group.py`, `veaf_mission_mcp/composites.py` (`_loadout`, to reuse), tests.

## What happened

`create_qra` and `create_cap_mission` take `loadout_from` (a group of the mission or of the aircraft catalogues); `add_air_group` does not, and refuses it (`unknown parameter(s) loadout_from`).
Escorts of module aircraft (J-11A, F-16C) have no DCS named payload (`list_payloads`), so `loadout_from` is the only sourced way to arm them; the Marianas batch stopped at its first red escort and the pylons had to be copied by hand.

## Done when

- `add_air_group` takes `loadout_from`, resolved by the same `_loadout` as the composites (mission first, then the folder's catalogues, then the shipped ones); one of `pylons`, `payload`, `loadout_from` at most.
- Tests: an escort armed from a `veafSpawn-*` template of the catalogue; two loadouts given at once refused.

## Done

The composites' `_loadout` and its two finders moved to `aircraft_payload.resolve_flight_loadout`, shared by `add_air_group` (a `.miz` target looks in the mission and the shipped catalogues).
