# Lot FIX-CONVERT-V5-OPERATION-SUBZONES — convert-v5 loses a combat operation's sub-zones

Status: ✅ done

**Goal**: A v5 combat **operation** chains sub-zones declared as locals, e.g. (VEAF-Demo-Mission `backup_v5`):
```lua
local gori = VeafCombatZone:new():setMissionEditorZoneName("subCombatZone_gori"):setFriendlyName("Mission Gori"):setBriefing("..."):initialize()
...
veafCombatZone.AddZone(VeafCombatOperation:new():setMissionEditorZoneName("goriOperation")
    :addTaskingOrder(gori)
    :addTaskingOrder(arashenda, { gori:getMissionEditorZoneName(), otarasheni:getMissionEditorZoneName() }))
```
`convert-v5` (`config_migrator`) **(a)** doesn't extract the `local <var> = VeafCombatZone:new()` sub-zones — `_CZ_ZONE_START_RE` requires `veafCombatZone.AddZone(` — so they never become `combat_zones`; **(b)** `_parse_combat_operation:1490` captures `addTaskingOrder(<var>)` as `zone_var: <var>` (the Lua variable name) and never resolves it to the real `missionEditorZoneName`. The generator then emits `addTaskingOrder(veafCombatZone.GetZone("gori"))`; at runtime `GetZone` looks up `zonesDict` and finds nothing (the zone is `subCombatZone_gori`, and it was never AddZone-d) → the operation can't find its trigger zone. Confirmed: the generator already *expects* a resolved `zone_name` ("If we have resolved zone_names, use them"), and `addTaskingOrder(zone, …)` needs a real zone **object** (`GetZone` of an AddZone-d zone).

**Fix (two parts)**: (1) extract the `local <var> = VeafCombatZone:new()…` sub-zones referenced by an operation as `combat_zones` (type zone) with their `zone_name`/`friendly_name`/`briefing`, so `GetZone` resolves them; (2) build a `var → missionEditorZoneName` map and resolve `zone_var`/`dependencies_vars` → `zone_name`/`dependencies` in the operation's tasking_orders. **DCS runtime validation required** (the runtime executes the trigrules) — David tests in-game before merge.

**Workaround (immediate, for an already-migrated mission.yaml)**: add the sub-zones as `combat_zones` (`type: zone`, `zone_name: subCombatZone_<x>`, friendly_name/briefing) **and** set `zone_name`/`dependencies` on the operation's tasking_orders.

**Branch**: `fix/convert-v5-operation-subzones` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-CONVERT-V5-OPERATION-SUBZONES-001 | Extract `local <var> = VeafCombatZone:new()` sub-zones as combat_zones + resolve operation tasking_orders `zone_var`/`dependencies_vars` to the real `missionEditorZoneName`. Characterization test on the gori operation. DCS runtime validation by David. | `mission_builder/config_migrator.py`, `test/python/` | fix | ✅ (#507) |
