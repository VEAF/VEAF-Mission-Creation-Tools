# FIX-CONVERT-V5-PARITY — a converted v5 mission behaves as it did in v5, or says what changed

Status: ⬜ ready

Origin: Sharko (BFR) converted parts of SeaShepherd with 6.37.0 and filed, in French, on 2026-11-22: [#1300](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1300), [#1301](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1301), [#1302](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1302), [#1303](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1303).
The runtime and docs findings of the same report are [FIX-BFR-PORT-FINDINGS](../FIX-BFR-PORT-FINDINGS/PRD.md).
Follows [FIX-CONVERT-V5-SILENT-LOSSES](../FIX-CONVERT-V5-SILENT-LOSSES/PRD.md) (6.15), whose rule still holds: what v6 cannot express is said.
This lot adds the other half: what v6 *adds* by default, a converted mission must not get silently.

Lot opened 2026-11-23, after each claim was re-read against `develop` (6.38.0, `5d06d123`); David validated the recommendations the same day.

## What was verified

- **#1300, point 1** — `VeafQRA.ToggleAllSilence(true)` is extracted (`config_migrator.py:1109-1120`) but only emitted when QRAs are defined in YAML (`v5_converter.py:1623`).
- **#1300, point 3** — community scripts are detected by the mere presence of their file in `published/src/scripts/community/` (`v5_converter.py:1130-1137`). v5 copied files there whether the mission loaded them or not: the code already refuses this test for MiST for that very reason (DROP-MIST ticket 08), not for AIEN. In v6 AIEN is off unless asked (shipped `mission.yaml`: `AIEN: false`; templates: `full` tier only), so a converted mission gets an AI enhancement it never had.
- **#1300, points 2, 4, 5** (empty `dynamic-slot-templates.yaml` and default `warehouses.yaml` opening dynamic slots; `DO_NOT_EXPORT_JSON_FILES`; no `mission.language`) — Sharko's measurements on his part, not re-measured. His message adds the BULLSEYE waypoint step (182 groups), 6 weather variants and 145 kneeboard pages, all v6 pipeline steps a v5 mission did not have.
- **#1301** — not reproduced; the repro is precise (a 149-character folder, a 139-character deepest file).
- **#1302** — `mission_builder_worker.py:2175`: `mission_path = output_mission.parent`, the output folder, not the mission folder.
- **#1303** — `check_lua_syntax` is only called on `veaf-config.lua` (`lua_config_generator.py:2626`), never on `custom_scripts`.

## Tickets

1. [01 — Conversion writes a v5-parity configuration](tickets/01-v5-parity-configuration.md) (#1300)
2. [02 — A conversion that cannot finish writes nothing, and the build refuses it](tickets/02-long-path-conversion.md) (#1301)
3. [03 — `VEAF_DYNAMIC_MISSIONPATH` is the mission folder](tickets/03-dynamic-missionpath.md) (#1302)
4. [04 — `validate` and `build` check the syntax of `custom_scripts`](tickets/04-custom-scripts-syntax.md) (#1303)

Done when: the four tickets are done, the conversion guide (FR and EN) describes the parity block, and each issue gets an answer naming the release that carries its fix.
