# FIX-BFR-PORT-FINDINGS — what BFR's port of three V5 missions found in the runtime and the docs

Status: ✅ done — shipped in 6.39.0 (2026-11-23)

Origin: Sharko (BFR) ported SeaShepherd, Bluestorm and SandBlast from VEAF V5 to VMCT V6 and filed what he met, in French, on 2026-11-22: [#1296](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1296), [#1297](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1297), [#1298](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1298), [#1299](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1299), [#1304](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1304), [#1305](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1305), [#1306](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1306), [#1308](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1308).
The conversion and build findings of the same report (#1300 to #1303) are [FIX-CONVERT-V5-PARITY](../FIX-CONVERT-V5-PARITY/PRD.md).
The CTLD findings (VEAF/CTLD#308 to #310, and VMCT #1307) are fixed by CTLD 2.1.0 and land with its vendoring.

Lot opened 2026-11-23, after each claim was re-read against `develop` (6.38.0, `5d06d123`); David validated the recommendations below the same day.

## What was verified

- **#1296** — `skynet-iads-compiled.lua` sets `logger.debugOutput.warnings = true` (~l.1119) and `printOutput` calls `trigger.action.outText(output, 4)` (l.1132-1139): set-up warnings reach every player's screen. "Log only in 5.103.3" is Sharko's claim, not re-measured.
- **#1297** — `veaf-config.lua` runs before `custom_scripts`, so a module it initializes is already up when the layer loads. Sharko's workaround (`initialized_by_mission`, then `initialize(true, false)` from the layer) works; only the docs are missing.
- **#1298** — under a parent rendered per group or per pilot, `_buildSubtree` (`veafRadio.lua`, ~l.870-902) only asks `groupFilter`; a node's `coalitionSide` is never compared to the group's coalition.
- **#1299 / #1305** — `veafRadio.delSubmenu` compares `v == subMenu or v.title == subMenu` (`veafRadio.lua:1305`): by title, it misses as soon as the label is translated. Removing by the handle (`veaf.ctldRootPath`, `<module>.rootPath`) works in every language.
- **#1304** — the per-pilot label is `unitPilotName` only when `veafRemote` (the server hook) knows the unit; otherwise the DCS callsign cached at birth. The `getPlayerName()` fallback (`veafRadio.lua:145-148`) is dead: `event.initiator` is a data table there.
- **#1306** — `doc/MISSION_YAML_REFERENCE.md` has no `last_line_of_defence`, `welcomeBrief` nor `radio_menu_coalition`; `custom-script-layer.md` still says "rc13 / 47 events"; `doc/CLI_REFERENCE.md:316` puts the conversion report in the mission folder, `convert_v5.py:245` writes it into `backup_v5/`.
- **#1308** — before `32ca2051` (2026-10-08) each drawn group was cloned (`deployEditorGroup`, `veafAircraftSpawn.lua:1325`), so "4 of [A, B]" sent 4 groups; the draw without replacement (`pickDistinctGroups`, `veafReactiveZone.lua:229-245`) sends 2. The comment and the CHANGELOG line that justify it are wrong.
- **#1247** is already fixed (`1983edb0`, 2026-11-04; nested filter evaluated at `veafRadio.lua:877-893`): close it, no ticket.

## Tickets

1. [01 — Skynet set-up warnings off the players' screens](tickets/01-skynet-warnings-off-screen.md) (#1296)
2. [02 — A node's coalition holds under a per-group parent](tickets/02-coalition-under-scoped-parent.md) (#1298)
3. [03 — The per-pilot label falls back to the player's name](tickets/03-per-pilot-label-player-name.md) (#1304)
4. [04 — A QRA draw keeps its count when it exceeds the list](tickets/04-qra-draw-keeps-count.md) (#1308)
5. [05 — Docs: load order, root-menu handles, mission.yaml keys, report path](tickets/05-docs.md) (#1297, #1299, #1305, #1306)

## Decisions (David, 2026-11-23)

- **#1299 / #1305: no new `mission.yaml` key.** The handle already removes a root menu in every language; the lot documents it.
- **#1308: restore the count**, rather than documenting the loss as Sharko suggested: a converted mission keeps its QRA strength.

Done when: the five tickets are done, #1247 is closed, and each issue gets an answer naming the release that carries its fix.
