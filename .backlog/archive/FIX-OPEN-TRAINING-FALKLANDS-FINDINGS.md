# FIX-OPEN-TRAINING-FALKLANDS-FINDINGS — what building the Falklands Open Training v6 found

Status: ✅ done — tickets 01–05 and 07 done, 06 closed without the action (David, 2026-10-14: « on verra bien en jeu ») · archived 2026-11-24

Asked by David on 2026-10-13.
The Falklands Open Training v6 (`VEAF-Open-Training-Mission-Falklands-v6`) was built with veaf-tools 6.29.0 although the map was not supported end to end; its `tools/retours-vmct.md` lists twelve findings.
The data DCS gave (frequencies, parking) was captured in the main checkout and is delivered by tickets 01 and 02, which unblock the map.
Each finding below was checked against `develop` (3b7facc6) before being written down.

Findings 1, 2, 4, 5 and 6 of the report are tickets 01 and 02.
Finding 7 (`add_farp` cites `veaf-tools dcs farp-spot`, absent from the published exe) is **not a defect of `develop`**: the command was added on 2026-10-12 (`a1b9edce`, FIX-FARP-PLACEMENT ticket 03), after the 6.29.0 tag, and ships with the next release.
Finding 3 (the v5 coordinates are in a frame that no longer matches the map) concerns the v5 mission, not the tools.

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Falklands is a supported theatre](FIX-OPEN-TRAINING-FALKLANDS-FINDINGS.md) | ✅ |
| 02 | [Falklands data delivered: frequencies, parking, presets](FIX-OPEN-TRAINING-FALKLANDS-FINDINGS.md) | ✅ |
| 03 | [add_farp: a FARP on a lake, and on a tower frequency](FIX-OPEN-TRAINING-FALKLANDS-FINDINGS.md) | ✅ |
| 04 | [create_combat_zone: a convoy that starts on the road, at a convoy's speed](FIX-OPEN-TRAINING-FALKLANDS-FINDINGS.md) | ✅ |
| 05 | [validate_mission: what a combat zone circle does with the groups around it](FIX-OPEN-TRAINING-FALKLANDS-FINDINGS.md) | ✅ |
| 06 | [A convoy between two places, on the roads](FIX-OPEN-TRAINING-FALKLANDS-FINDINGS.md) | 🚫 |
| 07 | [Ground placement on a theatre with no clear-ground catalogue](FIX-OPEN-TRAINING-FALKLANDS-FINDINGS.md) | ✅ |

Decision left to David: the Falklands elevation grid (`~/.veaf/terrain/Falklands.terrain`, 4.2 MB) is **not delivered** — no theatre ships its grid today, they are swept on each workstation (`terrain-sweep`); see ticket 02.

One branch, one PR.

## Tickets, in full

## 01 — Falklands is a supported theatre

Status: ✅ done

Files: `veaf_libs/data/theatre-defaults.yaml`, `veaf_libs/data/theatre-bounds.yaml`, `test/python/veaf_libs/test_blank_mission.py`, `test/python/veaf_mission_mcp/test_geo.py`.

### What happened

`dcs-maps.yaml`, `airdromes.yaml` and `theatre_offsets.py` knew Falklands, `theatre-defaults.yaml` did not: `scaffold_mission`'s `theatre` enum (built from `supported_theatres()`) refused it, its folder came out without `src/mission/`, and `veaf-tools dcs terrain-sweep Falklands` answered « Unsupported theatre ».
`theatre-bounds.yaml` had no box for it, so `geocode` was not bounded to the map: « San Julian » came back in Jujuy, « Porvenir » in Maule, « Rio Grande » on a bank.

### Done when

- `Falklands` is in `theatre-defaults.yaml` (map centre and zero bullseyes, read in DCS), hence in the `theatre` enum of `scaffold_mission` and in `blank_mission`.
- `theatre-bounds.yaml` has a `falklands` box, lat −56.5..−48, lon −74..−56.
- Tests: the blank mission is generated and listed; the box holds Port Stanley, Ushuaia and Punta Arenas.

## 02 — Falklands data delivered: frequencies, parking, presets

Status: ✅ done

Files: `veaf_libs/data/airfield-frequencies.yaml`, `src/scripts/veaf/veafAirfieldFrequencies.lua`, `src/defaults/mission-folder/src/presets.yaml` (`airports-falklands`), `veaf_build/dcs_data/airfield_freq_dumps/Falklands.json`, `veaf_build/dcs_data/airbase_dumps/parking/Falklands.json`, `veaf_libs/data/parking/Falklands.json`, `known-limitations.yaml`.

### What happened

`describe_airfield_channels` failed (« no airfield frequency is known for theatre 'Falklands' ») and `add_air_group` refused every ramp or runway start (no parking capture).
Both were captured in DCS on the workstation: 26 airfields out of 27 for the frequencies (Cullen, id 28, has none), 350 stands on 27 airfields for the parking.

### Done when

- The three generated files are the output of `veaf-build update-dcs-data --airfield-freqs` from the dump: regenerated here, byte for byte the same, no hand edit.
- The parking dump is slimmed into `veaf_libs/data/parking/`; the known limitation `no-parking-data-outside-three-theatres` lists Falklands among the five theatres that ship one.
- **Not delivered, on purpose**: the elevation grid. No theatre ships one (`~/.veaf/terrain/`, swept per workstation, 4–10 MB each), so the sea and slope checks on Falklands work only where `terrain-sweep Falklands` has run. A decision for David if it should ship.

## 03 — add_farp: a FARP on a lake, and on a tower frequency

Status: ✅ done

Files: `veaf_mission_mcp/add_farp.py`, `veaf_mission_mcp/surface.py`, `veaf_mission_mcp/actions.py` (schema text), tests.

### What happened

Falklands OT, report findings 7–9.
FARP Torres del Paine stood in a lake: its pad and ammo dump read `land.getSurfaceType` = 3 while the 250 m grid said 79 m (the grid knows only the sea, 0 m; an inland lake is ground to it). `add_farp` probes no surface at runtime and says nothing.
The same FARP was put on 128.5, the Franco Bianco tower, and nothing warns; `heliport_frequency` cannot be set afterwards by any action.

### Done when

- The `add_farp` result always says that lakes and rivers are not seen by the grid, and gives the `farp-spot` command that probes the surface in DCS (on `develop` since 2026-10-12; the 6.29.0 exe lacks it).
- `add_farp` warns when the FARP's frequency is the tower of an airfield of the theatre (`veaf_libs/data/airfield-frequencies.yaml`), and says which.
- Tests: a FARP on 128.5 on Falklands warns naming Franco Bianco; on a free frequency it does not; the lake sentence is in the result.

Whether a later action should set the frequency (finding 9's `fix_farp_freq.py`) is a separate question for David.

### Done

`add_farp` warns, naming the airfield, when its frequency is a tower's of the theatre in the same band (`AM`: `vhf` and `uhf`; `FM`: `fm`; same channel within 0.005 MHz).
The result always carries `surface_check`, a field apart from `warnings` so a clean FARP stays silent: lakes and rivers are seen by neither the grid nor the catalogue, and the `farp-spot` command probes them in DCS.
Docs (both languages), the action's description and the authoring skill say so.

## 04 — create_combat_zone: a convoy that starts on the road, at a convoy's speed

Status: ✅ done

Files: `veaf_mission_mcp/add_group.py` (`_build_waypoint`, `_DEFAULT_SPEED_MPS`), `veaf_mission_mcp/composites.py`, tests.

### What happened

Report finding 11 (already seen on the Sinai OT, its entry 13): `create_combat_zone` writes a convoy's first point `Off Road` and every point at 5.6 m/s (`_DEFAULT_SPEED_MPS`, 20 km/h).
`_build_waypoint` makes the first point `Off Road` for every ground group, a convoy included, and that start may be anywhere: the convoy crosses the country to reach its first road.

### Done when

- Measure first what the editor writes for a road convoy (first point `On Road`? speed?) in the missions under `test/`, before changing a constant: nothing here is decided from the report alone.
- A convoy's start is `On Road` when its route follows the roads, at the speed measured; a start that is not on a road is a warning.
- Tests on the waypoint action and the speed.

### Done

Measured first, 2026-10-13, over the 126 vehicle groups of 14 editor-built missions under `D:\dev\_VEAF` whose route has an `On Road` leg: the first point is `On Road` in 85 and `Off Road` in 37; the legs' speed has a median of 16.4 m/s (59 km/h), and 5.6 m/s is 11 % of them.
A ground route with two points or more now starts `On Road` and runs at 16.4 m/s (`_ROAD_SPEED_MPS` in `add_group.py`), for `add_group` and `create_combat_zone` alike; a point may carry its own `speed` (m/s), now in both schemas. A single stationary point stays `Off Road`; a ship keeps its `Turning Point` and its 5.6 m/s; the first point keeps the start speed.
**Not done: « a start that is not on a road is a warning »** — no file holds the roads, only the game does (`land.findPathOnRoads`); it goes with ticket 06.

## 05 — validate_mission: what a combat zone's circle does with the groups around it

Status: ✅ done — the report's premise did not hold for a combat zone; check 1 below built (David, 2026-10-13: « fais comme tu conseilles »)

Files: `veaf_libs/mission_validator.py`, `veaf_libs/locales/*.json`, tests.

### What happened

Report finding 10 says VEAF captures a combat zone **by geometry**, so a permanent group or a QRA inside a zone's circle would be destroyed then recreated: on the Falklands OT, `tools/check_overlap.py` found the Port Stanley SA-15 (1 482 m from the OCA zone's centre, radius 1 500), a radar, a NASAMS, a beacon and the Port Stanley QRA parking.

**Checked against the runtime (2026-10-13), that is not what a combat zone does.** `VeafCombatZone:findUnitsInCombatZone` takes the units of the trigger zone's circle (`veafGeo.getUnitsInCircularZone`: 2D distance to the centre ≤ radius, units and statics, any coalition) **and keeps only the groups whose name starts with the zone's name** (case ignored). The others are left where they stand — never removed, never recreated, never counted — and the log says so once (`N group(s) found inside the zone were ignored`). The module doc says it too (`doc/mission-maker/scripts/veafCombatZone.md`, « The prefix rule »). So the SA-15 and the QRA are untouched.
What does capture by pure geometry is the **campaign** zone (`VeafCampaignZone:groundHolders`: every active ground unit or grounded helicopter in the sphere, any side, with about 4 % slack), and only to decide who holds a neutral zone.

### What a validator could still say, each true in the runtime

1. A group **named for a zone but outside its circle**: the zone picks nothing up and nothing shows in game. The reverse of the prefix rule, and the one silent failure left.
2. Two zones whose names are prefixes of one another (`CZ-A` and `CZ-AB`) with circles that overlap: a group of `CZ-AB-…` in both circles belongs to both.
3. Campaign zones (`modules.CAMPAIGN`): a permanent ground group inside a neutral zone's circle counts as holding it.

None of the three is what the report asked, and the report's check (`check_overlap.py`) would warn on harmless layouts. Check 1 is built; 2 and 3 are not.

### Done

`find_combat_zone_groups_outside_their_circle` (`mission_builder/group_validation.py`), run by `validate_mission_content` and so by `validate` and the build: a **warning** per group whose name starts with a declared combat zone's name (operations excluded, case ignored) and none of whose units is within the zone's circle (2D, edge included; quad-point zones not measured). A group named for no zone is never reported.
It found one on the Falklands OT itself: `combatZone_PortStanley-Z14-1`, 1 078 m from the centre of its zone, outside the circle, hence picked up by nothing.

## 06 — A convoy between two places, on the roads

Status: 🚫 wontfix — closed by David on 2026-10-14 (« on verra bien en jeu »): the action is not built; it comes back if a mission maker misses it

Files: a new MCP action; the road query through dcs-bridge; `doc/developer/mission-editing-mcp.md` and `.en.md`.

### What happened

Report finding 11: the Falklands convoys' routes came from `land.findPathOnRoads` (`tools/roads.py`) and were reshaped by hand (`tools/fix_convoys_on_road.py`).
An action « convoy on the road between A and B » would do it in one call.

### Done when

- **If the bridge is launched** (`dcs-serve` running), an action takes two places or points and a group, asks `land.findPathOnRoads` and writes an `On Road` route at the convoy speed measured in ticket 04.
- **Otherwise, at least**: the MCP catalogue and `mission-editing-mcp` (both languages) say how the route is obtained today — the bridge call, then `edit_route` — so the workaround stops being a private script.

## 07 — Ground placement on a theatre with no clear-ground catalogue

Status: ✅ done

Files: `veaf_libs/data/known-limitations.yaml`, `veaf_mission_mcp/surface.py`, tests.

### What happened

Report finding 12: on Falklands, a `Disposition` probe of the grid positions found 15 vehicles out of 176 at fault — 5 in the water (two beacons, two false units of the Ushuaia naval base, a 4x4) and 10 « blocked » — and `tools/fix_scenery.py` moved them from 25 m to 1 425 m.
No clear-ground catalogue covers the map, and the ground sweep sees neither fresh water nor trees.
It is the case of `marianas-placement-checks-nothing`, one theatre more.

### Done when

- A known-limitation entry for Falklands (`kind: tool`) with the 15/176 measure and the workaround (`clear-ground-sweep Falklands --zones-from <mission>`, then `clear-ground-check`); `docs/agents/dcs-runtime-traps.md` regenerated.
- The « surface not checked » warning names `clear-ground-sweep` too, not only `terrain-sweep`.
- Decide with David whether a catalogue around the 27 Falklands airfields is worth shipping.

### Done

Known limitation `falklands-placement-has-no-clear-ground-catalogue` (`kind: tool`) with the 15/176 measure; `dcs-runtime-traps.md` regenerated (unchanged: it lists the `dcs` kind only).
The « surface not checked » warning now also gives `veaf-tools dcs clear-ground-sweep <theatre> --zones-from <mission>` for the scenery, next to `terrain-sweep` for the sea.
**Left to David:** whether a catalogue around the 27 Falklands airfields is worth shipping (a sweep per place costs about ten seconds in game; the catalogues shipped today cover Caucasus and GermanyCW only).
