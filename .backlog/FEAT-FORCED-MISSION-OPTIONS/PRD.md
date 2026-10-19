# FEAT-FORCED-MISSION-OPTIONS — the mission options a mission maker sets by hand in the editor

Status: 🧑 waiting-human

## Where it comes from

A documentary read of what DCS 2.9.30's Mission Editor and mission engine can do, from the Lua files DCS ships in the clear, crossed with what VMCT and its MCP server expose (2026-10-19, `dcs-re` repository, `ETUDE-editeur-de-mission.md`).
The study's richest finding: the **enforced mission options** (`forcedOptions` in the `.miz`), which every mission maker sets by hand in the editor's *Mission options* panel, and which VMCT cannot set at all — `blank_mission.py` writes `forcedOptions = {}` and nothing else touches it.
David agreed to the study's recommendations on 2026-10-19: one lot for the options, the F10 view per role and the carrier deck lights; the in-game checks the study left open; a page of editor tips.

## What DCS keeps — read in the editor's Lua

- An option is enforceable when `MissionEditor/modules/Options/optionsDb.lua` declares it `:setEnforceable()` (lines 152-222, 242, 473).
- The mission stores the enforced ones flat in `mission.forcedOptions`, DCS key → value: read in 107 real missions under `D:\dev\_VEAF` and `Saved Games` (2026-10-19), e.g. `["labels"] = 0`, `["optionsView"] = "optview_onlyallies"`, `["civTraffic"] = ""`, `["geffect"] = "realistic"`.
- The F10 view per role is `optionsView = "optview_extended"` plus `optionsViewExtended = {[role] = {f10ViewOption = …, visibleUnitLayersMask = {[0..14] = bool}}}` (`me_extendedF10ViewOptions.lua:51-92`, `Options/MissionOptionsView.lua:89, 128-137`).
  Roles: 1 pilot, 2 forward observer, 3 tactical commander, 4 observer, 5 spectator, 6 Airboss/LSO (`me_extendedF10ViewOptions_role_wgt.lua:32-38`).
  Layer bit = row × 3 + column, rows planes, helicopters, ground, naval, weapons, columns allies, enemies, neutral — read in the dialog's layout (`dialogs/me_extendedF10ViewOptions_role_wgt.dlg`, `cb0` at row *planes* column *allies*, `cb14` at *weapons* / *neutral*).
  None of the 107 missions uses it: the shape comes from the editor's code, not from a saved mission, and what DCS does with it in game is not seen yet (ticket 06).
- The carrier lights are a trigger action, `a_set_carrier_illumination_mode(<unit id>, <mode>)`, modes OFF -2, AUTO -1, NAVIGATION 0, LAUNCH 1, RECOVERY 2 (`me_trigrules.lua`, `lightsModes` and `AIRCARRIER_SELECTOR` in `me_predicates.lua:543`).
  The `a_*` functions live in the trigger environment, which a VEAF script reaches through `net.dostring_in("mission", …)` (measured by `veafAssist`, `veafAssist.lua:199-206`).

## What the lot delivers

1. **`mission.forced_options`** (ticket 01): a `mission.yaml` block, applied at every build like `mission.ground_control`, in names a mission maker reads (`labels: none`, `f10_view: fog_of_war`, `external_views: false`…). Absent, the mission's own `forcedOptions` is left alone. `validate` reports an unknown option or value.
2. **The F10 view per role** (ticket 02): `f10_view_by_role` in the same block, a view and the layers to hide for each role.
3. **An MCP action** (ticket 03): `set_forced_options`, merging options into `mission.forced_options` of a mission folder's `mission.yaml`.
4. **Carrier deck lights** (ticket 04): `veafCarrierOperations` sets the carrier's lights to RECOVERY when it starts air operations, and back to AUTO when it stops.
5. **Editor tips** (ticket 05): a mission maker page, FR and EN, on the editor actions VMCT does not wrap and that are worth knowing.
6. **In-game checks** (ticket 06): the options and the F10 view per role as a player sees them, the carrier lights, and three editor actions the study could only read.

## Decided

- **a)** YAML names follow the editor's labels in English snake_case, not the DCS keys: `ground_control` set that precedent, and `easyCommunication` or `RBDAI` tell a mission maker nothing. The table of names lives in the code and in `MISSION_YAML_REFERENCE`.
- **b)** An option the block does not name keeps the mission's value; the block never clears one. Clearing an enforced option is a click in the editor, and rare.
- **c)** The campaign needs no code: `campaign next` copies the template mission folder, so options set in the template's `mission.yaml` reach every mission.
- **d)** Carrier lights: RECOVERY during VEAF air operations, AUTO otherwise; not configurable until someone asks.

## Out of scope

- The study's other findings (failures, shelling, ATC) — either covered (`-shell`, `silence_atc_on_all_airbases`) or not worth a feature; see the tips page.
- Options that are not enforceable (avionics language, units, icons theme): DCS reads them from the player's settings only.
