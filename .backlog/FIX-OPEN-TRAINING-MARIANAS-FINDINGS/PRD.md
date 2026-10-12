# FIX-OPEN-TRAINING-MARIANAS-FINDINGS — what building the Marianas Open Training v6 through the MCP found

Status: ⬜ ready

Asked by David on 2026-10-12.
The Marianas Open Training v6 (`VEAF-Open-Training-Mission-Marianas-v6`) was built from scratch on 2026-10-11 with the Open Training prompt (`.prompts/new-open-training-mission.fr.md`), the `veaf-mission-mcp` actions of `develop` and the 6.29.0 release, then probed in DCS through dcs-bridge on 2026-10-12.
The prompt asks for a « Retours pour VMCT » block; the mission keeps it in `tools/retours-vmct.md`.
This lot is that block, each finding checked against `develop` (1bc3d423) before being written down.
Three findings of that block are left out on purpose: the refusal of a named airfield by `create_qra` on a theatre without parking data is deliberate (`composites.py`, « a start or an airfield asked for is refused »), the « silent » empty sky of a real-weather variant was the mission's own script discarding the build output (VMCT does warn, `weather.converter.metar_fetch_failed`), and the missing game-master roles are already `FIX-OPEN-TRAINING-CAUCASUS-FINDINGS` ticket 01.

Two findings made a **wrong mission with no warning**, and are first in line:

- `create_qra` with `task: "CAP"` writes the editor's automatic `EngageTargets`, so the build reads the route as « engages air » and flies it as written: one waypoint, no orbit, and the interceptors land at the nearest airfield instead of defending their zone (ticket 01);
- on a theatre with no elevation grid and no clear-ground catalogue, nothing tells the maker that ground units stand in the sea or in the trees: the DCS probe of 2026-10-12 found **57 of 97 vehicles in forest or buildings and one in the water** on MarianaIslands, where every placement action had only said « surface not checked » (ticket 07).

Then what made the work slower or forced a workaround: the carrier recovery tankers taking the tanker callsign families (02), no `loadout_from` on `add_air_group` (03), two defects of the shipped aircraft catalogues — a J-11A template with no weapons and three community mods offered as dynamic slots (04), read and lookup actions that disagree on their parameters or hide what a write needs (05), and no way to make a ground group hold fire and stay put (06).

| # | Ticket | Status |
|---|--------|--------|
| 01 | [create_qra: no automatic EngageTargets on an interceptor](tickets/01-qra-no-engage-task.md) | ⬜ |
| 02 | [add_carrier_group: the recovery tanker leaves the tanker families to the tankers](tickets/02-carrier-tanker-callsign.md) | ⬜ |
| 03 | [add_air_group takes loadout_from](tickets/03-air-group-loadout-from.md) | ⬜ |
| 04 | [Shipped aircraft catalogues: a J-11A with weapons, no mods](tickets/04-shipped-catalogues.md) | ⬜ |
| 05 | [Read and lookup actions: one parameter name, the group id, a place that is not an island](tickets/05-read-actions.md) | ⬜ |
| 06 | [A ground group that holds fire and does not disperse](tickets/06-ground-group-roe.md) | ⬜ |
| 07 | [MarianaIslands terrain data, and a placement warning that says what was not checked](tickets/07-marianas-terrain-data.md) | ⬜ |

Ticket 07 needs DCS (`veaf-tools dcs terrain-sweep`, `capture-map --parking`, `clear-ground-sweep`): its sweeps are David's, the rest is code.
Each ticket that leaves a limitation unfixed adds it to `known-limitations.yaml`; the Open Training prompt loses the workarounds this lot makes unnecessary, in the same lot.

One branch, one PR.
