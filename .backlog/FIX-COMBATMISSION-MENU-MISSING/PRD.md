# FIX-COMBATMISSION-MENU-MISSING — the MISSIONS radio menu is never built

Status: 🧑 waiting-human

## Origin

On 2026-10-05 the bridge recette of the v6 demo mission (`VEAF/VEAF-Demo-Mission-v6`, new `tools/recette_pont.py`) checked every « VEAF > … » menu path its guided tour cites against the running mission.
The tour's « CAP à la demande et raid sur Senaki » step sends the player to **F10 > Other > VEAF > MISSIONS**: that menu does not exist.

David wants the fix in **6.28.0**, whose release is under way (`release/6.28.0`, PR #1084).

## The defect

`lua_config_generator.py`, branch `elif mod_id == "COMBATMISSION":`, emits `veafCombatMission.initialize()` **before** every `addCapMission(...)` and `AddMissionsWithSkillAndScale(...)`.
`initialize()` calls `buildRadioMenu()`, which returns without building anything while `missionsDict` is empty (« don't create an empty menu »).
The missions are registered right after, and nothing rebuilds the menu: `VeafCombatMission:updateRadioMenu` returns early while `veafCombatMission.rootPath` is nil.

So **any mission declaring `cap_missions` or `combat_missions` in `mission.yaml` has no MISSIONS menu**.
Missions still start by marker (`-airstart <name>`), and an activation from elsewhere calls `buildRadioMenu()` and makes the menu appear late — which is how this hid.
The order dates from `f959bd346` (2026-05-19), present since `published-v6.1.0-rc2`.

## Measured

Demo mission, test build `6.27.0+28c606b3`, FR, loaded in DCS, probed over dcs-bridge at t ≈ 5 min:

- `veaf.length(veafCombatMission.missionsDict)` = 32, no `MISSIONS` entry under `veafRadio._builder._root.subMenus`, `veafCombatMission.rootPath` = nil;
- `veafCombatMission.buildRadioMenu(); veafRadio.refreshRadioMenu()` → the `MISSIONS` menu is there.

The generated `veaf-config.lua` of the demo (l. 152-157):

```lua
if veafCombatMission then
    veafCombatMission.initialize()
    veafCombatMission.addCapMission("CAP MiG-29S Gudauta FL250", ...)
    ...
    veafCombatMission.AddMissionsWithSkillAndScale(
```

## Tickets

| # | Ticket |
|---|--------|
| [01](tickets/01-initialize-after-missions.md) | Emit `initialize()` after the missions it builds the menu from |

## Definition of done

- A generator test that fails before the fix: `initialize()` comes after every `addCapMission` / `AddMissionsWithSkillAndScale`, and is still emitted with no mission.
- `CHANGELOG.md` entry in the 6.28.0 section, one PR into `release/6.28.0`.
- In DCS: the demo rebuilt with the fix shows F10 > VEAF > MISSIONS at start; the demo's `python tools/recette_pont.py --menus` finds its CAP and raid paths.
