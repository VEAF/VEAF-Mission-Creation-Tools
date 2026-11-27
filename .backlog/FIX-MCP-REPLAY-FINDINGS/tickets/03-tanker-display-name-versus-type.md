# 03 — `add_air_group` and a unit's display name

Status: ✅ done
Type: measure, then fix
Files: `src/python/veaf-tools/veaf_mission_mcp/` (`add_air_group` and its validation), `veaf_libs/data/dcsUnits.yaml` (read), tests

Measure first: on a scratch mission folder, call `add_air_group` with `unit_type: "KC-135MPRS"` and read the built group. Does the action resolve the display name to the type `KC135MPRS`, or write a wrong type that DCS ignores?
- If it resolves: say so in the action's description and the guide, and stop.
- If it writes the wrong type: validate `unit_type` against the catalogue and answer with the closest valid type (`did you mean KC135MPRS`), in both profiles.
Also check, with `inspect_built_mission`, that the built `.miz` of the replay holds the maximum visibility (80 000 m) and report the value (point 1 of the PRD).
Tests for whichever branch applies; the measured values go into the ticket.

## Measured 2026-11-27

- `add_air_group(unit_type="KC-135MPRS")` on a scratch Caucasus `.miz` (Kobuleti, parking-cold): **the display name is written as is** (`type = "KC-135MPRS"`), which DCS ignores. The action answered with two warnings — "not in the DCS unit database" and "No fuel capacity known" — neither naming the right type. `KC135MPRS` gave no warning.
- Branch taken: the wrong type is written, so the warning now ends with `did you mean 'KC135MPRS'?` (a display name that matches one type exactly is the only suggestion; otherwise up to three close spellings). The warning stays a warning, not a refusal: third-party mods are legitimately absent from the catalogue. One choke point (`air_category_for_type_verbose`) serves `add_air_group`, its composite form and `player_slot`, in both profiles.
- Visibility (point 1 of the PRD): the replay's `versions.yaml` holds `visibility: 9000.0`; the built `.miz` (`Marteau-du-Golan-3_20261127.miz`) holds `["visibility"] = { ["distance"] = 80000 }`. Confirmed: 80 000 m is written.
