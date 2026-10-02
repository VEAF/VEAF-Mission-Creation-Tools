# FIX-OPEN-TRAINING-SYRIA-FINDINGS — what building the Syria Open Training v6 through the MCP found

Status: ⬜ ready

Asked by David on 2026-10-02. The Syria Open Training v6 was built from scratch with the Open Training
prompt (`.prompts/new-open-training-mission.fr.md`), the `veaf-mission-mcp` actions and the tools of
`develop` (6.26.0.2). The prompt asks for a « Retours pour VMCT » block; this lot is that block, every
finding checked against the code of `develop` before it was written down. Two findings are left out on
purpose — `scaffold_mission` / `build_mission` only serve a release, and `capabilities` reported a stale
version until `poetry install` — because they come from testing an unreleased `develop`, not from the
tools.

Three findings made a **wrong mission with no warning**, and are first in line:

- `add_air_group` built eight tanker and AWACS escorts **with no weapons**, and gave the second tanker of
  a family another family's callsign (Texaco 2 → `Shell11`, Arco 2 → `Texaco21`): the group name is
  never read (ticket 01);
- `set_unit_properties` wrote `str(dict)` as a CLSID when given `add_air_group`'s pylon shape, and
  wrote the callsign word without its digits (ticket 02);
- `create_qra` writes every group into `simple_groups` on top of the scramble levels: harmless when a
  level-1 rule overwrites it (the runtime replaces level 1), but every group scrambles at the first
  intruder as soon as the lowest level is above 1 (ticket 03).

Then what made the work slower or forced a workaround: a battery placed in the sea with no warning
although the elevation grid exists (04), a FARP without its ammunition dump (05), no FAC task (06), a
geocoder that gets banned by Nominatim and returns a street in Amman for « Al-Kiswah » (07), no weapon
ranges to check the air-defence distances against (08), no loadout for the types the catalogue lacks
(09), `${METAR}` printed raw with manual weather (10), and four small ones (11 to 14).

Sources: the session that built the mission, its build logs, `tools/verify.py` of the mission folder.

| # | Ticket | Status |
|---|--------|--------|
| 01 | [add_air_group: callsign from the group name, no armed task without a loadout](tickets/01-air-group-callsign-and-loadout.md) | ⬜ |
| 02 | [set_unit_properties: callsign word plus digits, one pylon shape, a non-string CLSID refused](tickets/02-unit-properties-callsign-and-pylons.md) | ⬜ |
| 03 | [create_qra: no simple_groups next to the scramble levels](tickets/03-qra-no-simple-groups.md) | ⬜ |
| 04 | [Placement checks the surface where the elevation grid exists](tickets/04-surface-check-at-authoring.md) | ⬜ |
| 05 | [add_farp places its ammunition dump](tickets/05-farp-ammo-dump.md) | ⬜ |
| 06 | [edit_route: the FAC task](tickets/06-fac-task.md) | ⬜ |
| 07 | [geocode: one request a second, and a place rather than a street](tickets/07-geocode-pace-and-place.md) | ⬜ |
| 08 | [Weapon ranges in the unit database](tickets/08-threat-ranges.md) | ⬜ |
| 09 | [DCS default loadouts by name](tickets/09-dcs-default-loadouts.md) | ⬜ |
| 10 | [${METAR} for a manual-weather variant](tickets/10-metar-for-manual-weather.md) | ⬜ |
| 11 | [The mission-folder .gitignore covers the MCP backups and the presets report](tickets/11-gitignore-template.md) | ⬜ |
| 12 | [A circular sanctuary from mission.yaml](tickets/12-sanctuary-circle-yaml.md) | ⬜ |
| 13 | [An ASSETS entry shown to one coalition](tickets/13-assets-per-coalition.md) | ⬜ |
| 14 | [list_catalog fits in an agent's tool result](tickets/14-compact-catalog.md) | ⬜ |

Riskier than the rest, said in advance: 06 (a DCS task whose behaviour needs an in-game check), 09 (a
new data set from the datamine) and 13 (Lua, radio menus per coalition).

Each ticket that leaves a limitation unfixed adds it to `known-limitations.yaml` (`kind: tool`); the
Open Training prompt loses the workarounds this lot makes unnecessary, in the same lot.
