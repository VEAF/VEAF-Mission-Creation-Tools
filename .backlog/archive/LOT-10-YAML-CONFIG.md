# Lot 10 — YAML-CONFIG: mission.yaml source de vérité

Status: ✅ done

**Goal**: `mission.yaml` becomes the single source of truth for all mission configuration. Python generates `veaf-config.lua` at build time. `missionConfig.lua` → `mission-script.lua` (custom code only). `convert-v5` actively extracts all recognized patterns.
**Branch**: `feature/yaml-config` → PR → `develop`
**Depends on**: Lot RC (builder infrastructure), Lot 4 (LUA-CONFIG)

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| YAML-001 | Rename `veaf-modules-config.lua` → `veaf-config.lua` and `missionConfig.lua` → `mission-script.lua` everywhere (no compat fallback) | chore | 40 min | — | ✅ |
| YAML-002 | Core YAML schema + generator: `mission:`, `security:`, `settings:`, auto-`initialize()` with typed `init:` params per module | feat | 60 min | YAML-001 | ✅ |
| YAML-003 | YAML schema + generator: `lua_modules.ASSETS.assets:` table + `lua_modules.NAMED_POINTS.custom_points:` | feat | 45 min | YAML-002 | ✅ |
| YAML-004 | YAML schema + generator: `external_modules.skynet:` + `external_modules.ctld:` | feat | 35 min | YAML-002 | ✅ |
| YAML-005 | YAML schema + generator: `qra:` list → `VeafQRA:new():set*():start()` builder chains | feat | 60 min | YAML-002 | ✅ |
| YAML-006 | YAML schema + generator: `cap_missions:` + `combat_missions:` → `addCapMission()` + `VeafCombatMission` builder chains | feat | 90 min | YAML-002 | ✅ |
| YAML-007 | Update `generate-config` command: produce exhaustive commented `mission.yaml` with all known options and defaults | feat | 45 min | YAML-002–006 | ✅ |
| YAML-008 | Update default templates: `mission.yaml` (all new sections commented), `mission-script.lua` (custom-only stub), `test-tools-v6` fixtures | chore | 30 min | YAML-002–006 | ✅ |
| YAML-009 | `convert-v5` — extract core config + Skynet: `MISSION_NAME`, `era`, `SecurityDisabled`, simple `initialize()` params, Skynet params | feat | 60 min | YAML-002, YAML-004 | ✅ |
| YAML-010 | `convert-v5` — extract `veafAssets.Assets = {...}` Lua table → `lua_modules.ASSETS.assets:` YAML | feat | 45 min | YAML-003 | ✅ |
| YAML-011 | `convert-v5` — extract `VeafQRA:new():...:start()` chains → `qra:` YAML entries | feat | 60 min | YAML-005 | ✅ |
| YAML-012 | `convert-v5` — extract `addCapMission()` + `VeafCombatMission:new():...` chains → `cap_missions:` / `combat_missions:` YAML | feat | 75 min | YAML-006 | ✅ |
| YAML-013 | Tests: `test_config_generator.py` (mission, security, auto-init, QRA, CombatMission, Assets) + `test_config_migrator.py` updates (new extraction patterns) | chore | 60 min | YAML-001–012 | ✅ |
| YAML-014 | Docs: update `MISSION_MAKER_GUIDE.md`, `MIGRATION_GUIDE.md` for new YAML → `veaf-config.lua` + `mission-script.lua` workflow | chore | 30 min | YAML-001–012 | ✅ |

**Raw total: 735 min → estimated (×1.15): ~845 min (~14h05)**

<details>
<summary>Ticket details</summary>

**YAML-001 — File renames (no compat fallback)**
- `veaf-modules-config.lua` → `veaf-config.lua`:
  - `mission_builder_worker.py`: all path constants + trigrule strings + `write_lua_modules_config()` → `write_config_lua()`
  - `mission_constants.py`: path tuple
  - `veaf-tools.py`: `generate-config` command messages
- `missionConfig.lua` → `mission-script.lua`:
  - `src/defaults/mission-folder/src/scripts/missionConfig.lua` renamed
  - `veafDynamicConfig.lua`: `"missionConfig.lua"` → `"mission-script.lua"`, remove fallback logic
  - `v5_converter.py`: `MISSIONCONFIG_DEFAULT`, `MISSIONCONFIG_CANDIDATES`, output filename
  - `config_migrator.py`: output filename
  - `mission_builder_worker.py`: static trigrule `veaf_mission_config_map_key` reference
  - `test-tools-v6/src/scripts/missionConfig.lua` renamed

**YAML-002 — Core schema + generator**
New `mission.yaml` sections:
```yaml
mission:
  name: "My-Mission"          # veaf.config.MISSION_NAME
  export_path: null           # veaf.config.MISSION_EXPORT_PATH
  era: MODERN                 # veaf.config.era  (WW2 | COLD_WAR | MODERN)
security:
  disabled: true              # veaf.SecurityDisabled
  # password_hashes: ["sha1"]
settings:                     # dict → veaf.config.KEY = value
  DEFAULT_GROUND_SPEED_KPH: 25
```
`lua_modules` gains a typed `init:` sub-section per known module (hardcoded mapping in generator):
- `RADIO.init.help_menus: bool` → positional arg of `veafRadio.initialize(bool)`
- `CARRIER.init.include_carrier_operations_radio: bool`
- (all other modules: `initialize()` with no args when `init:` absent)

Generator (`generate_config_lua()` in `lua_module_scanner.py`) updated to:
1. Emit mission identity block
2. Emit security block
3. Emit `veaf.config.XXX = ...` from `settings:`
4. For each module with `enable: true`: emit `veaf.setConfig()` calls then auto-`if veafXxx then veafXxx.initialize(...) end`
5. Initialization order is fixed (recommended VEAF order, `veafInterpreter` always last)
`mission_builder_worker.py`: `write_config_lua()` passes all new YAML sections to generator.

**YAML-003 — Assets + NamedPoints**
```yaml
lua_modules:
  ASSETS:
    enable: true
    assets:
      - sort: 1
        name: "CSG-74 Stennis"
        description: "Stennis (CVN)"
        information: "Tacan 10X\nICLS 10"
        linked: null     # optional
        jtac: null       # optional (laser code int)
        freq: null       # optional (float)
        mod: null        # optional ("am" | "fm")
  NAMED_POINTS:
    enable: true
    custom_points:
      - name: "Battle Area Alpha"
        lat: "41.123456"
        lon: "44.987654"
```
Generator: emit `veafAssets.Assets = { {...}, ... }` before `veafAssets.initialize()`. Emit `local customPoints = { {name=..., point=coord.LLtoLO(...)} }` passed to `veafNamedPoints.initialize(customPoints)`.

**YAML-004 — External modules (Skynet, CTLD)**
```yaml
external_modules:
  skynet:
    enabled: false
    include_red_in_radio: false
    debug_red: false
    include_blue_in_radio: false
    debug_blue: false
  ctld:
    enabled: false
    hover_pickup: true
    enable_crates: true
    # ... other ctld.xxx keys
```
Generator: emit `if veafSkynet then veafSkynet.initialize(false, false, false, false) end`.
For CTLD: emit `ctld.xxx = value` property assignments (not `ctld.initialize()` — the script loading stays in `mission-script.lua`). CTLD emitted only if `ctld.enabled: true`.

**YAML-005 — QRA schema + generator**
```yaml
qra:
  silence_all: true             # VeafQRA.ToggleAllSilence(true)
  definitions:
    - name: QRA_Minevody
      coalition: RED            # coalition.side.RED
      enemy_coalitions: [BLUE]
      trigger_zone: QRA_Minevody
      zone_radius: null         # optional (metres)
      delay_before_rearming: 10
      delay_before_activating: 60
      react_on_helicopters: true
      airport_link: null        # optional (airbase name)
      groups_by_enemy_count:
        - enemy_count: 1
          groups: ["QRA_Minevody-1", "QRA_Minevody-2"]
          random_pick: 1
      simple_groups: []         # alternative to groups_by_enemy_count: flat :addGroup() calls
```
Generator: emit `veafQraManager.initialize()`, optional `VeafQRA.ToggleAllSilence(bool)`, then for each definition a `VeafQRA:new()` builder chain ending in `:start()`. Coalition values mapped `RED` → `coalition.side.RED`.

**YAML-006 — CombatMission schema + generator**
```yaml
cap_missions:
  - group_name: "training-radar-tu22-FL300"
    menu_name: "WEST - Tu22 FL300"
    briefing: "Russian TU-22 patrols at FL300..."
    default: false
    activated: true
combat_missions:
  - name: Intercept-Kraznodar-1
    friendly_name: "Intercept a transport / KRAZNODAR - MINVODY"
    secured: true
    radio_menu_enabled: true
    briefing: |
      A Russian transport plane is taking off from Kraznodar...
    elements:
      - name: OnDemand-Intercept-Transport-Krasnodar-Mineral-Transport
        groups: ["OnDemand-Intercept-Transport-Krasnodar-Mineral-Transport"]
        scalable: false
```
Generator: emit `veafCombatMission.initialize()`, then `addCapMission()` calls, then `AddMissionsWithSkillAndScale(VeafCombatMission:new():...:addElement(VeafCombatMissionElement:new():...):...)` chains. Multi-line briefings emitted as Lua long strings (`[[...]]`).

**YAML-007 — generate-config command**
`veaf-tools generate-config --mission <folder>`: produces a fully-commented `mission.yaml` at the mission folder root. Every known option listed with its type, default value, and a one-line comment. Sections: `mission:`, `security:`, `settings:`, `global_log_level:`, `lua_modules:` (all known modules with all `init:` params), `external_modules:`, `qra:` (example entry), `cap_missions:` / `combat_missions:` (example entries).

**YAML-008 — Template updates**
- `src/defaults/mission-folder/mission.yaml`: add all new sections with commented examples.
- `src/defaults/mission-folder/src/scripts/mission-script.lua`: stripped to custom-code stub with commented examples for QRA, CombatMission, community script loading (e.g. CTLD.lua).
- `test-tools-v6/mission.yaml`: updated to use new sections.
- `test-tools-v6/src/scripts/mission-script.lua`: migrated from `missionConfig.lua`.

**YAML-009 — convert-v5: core + Skynet extraction**
`config_migrator.py` extended to extract from `missionConfig.lua`:
- `veaf.config.MISSION_NAME = "..."` → `mission.name:`
- `veaf.config.MISSION_EXPORT_PATH = ...` → `mission.export_path:`
- `veaf.config.era = veaf.ERA.XXX` → `mission.era:`
- `veaf.SecurityDisabled = true/false` → `security.disabled:`
- `veafSecurity.password_L9["hash"] = true` → `security.password_hashes: [hash]`
- `veaf.DEFAULT_GROUND_SPEED_KPH = N` → `settings.DEFAULT_GROUND_SPEED_KPH:`
- `veafRadio.initialize(true/false)` → `lua_modules.RADIO.init.help_menus:`


- `veafSkynet.initialize(a, b, c, d)` → `external_modules.skynet:` params
`v5_converter.py`: emit these sections in the generated `mission.yaml`.

**YAML-010 — convert-v5: Assets extraction**
Regex + Lua table parser for `veafAssets.Assets = { {...}, {...} }`. Extract each table entry (sort, name, description, information, linked?, jtac?, freq?, mod?) into `lua_modules.ASSETS.assets:` YAML list. Multi-line `information` strings (with `\n`) handled correctly.

**YAML-011 — convert-v5: QRA extraction**
Parse `VeafQRA:new()` method chains:
- Detect block pattern `VeafQRA:new()\n:setName(...)\n:...\n:start()`
- Extract each `:setXxx(...)` call to the corresponding YAML field
- Handle `setRandomGroupsToDeployByEnemyQuantity(count, {groups}, pick)` → `groups_by_enemy_count:` entry
- Handle `VeafQRA.ToggleAllSilence(bool)` → top-level `qra.silence_all:`
- Remaining unrecognized chained calls: warn + keep in `mission-script.lua`

**YAML-012 — convert-v5: CombatMission extraction**
- `veafCombatMission.addCapMission(g, m, b, def, act)` → `cap_missions:` entries
- `VeafCombatMission:new():...:addElement(VeafCombatMissionElement:new():...):...` chains → `combat_missions:` entries
- Long-string briefings `[[...]]` extracted to YAML multi-line `|` strings
- `VeafCombatMissionElement` fields: `name`, `groups`, `scalable`, `spawned`

**YAML-013 — Tests**
New `test/python/test_config_generator.py`:
- `test_mission_identity()`: `mission:` section → correct Lua output
- `test_security_block()`: password hashes + `SecurityDisabled`
- `test_auto_initialize_no_init_section()`: `enable: true` without `init:` → `initialize()` emitted
- `test_radio_init_params()`: `RADIO.init.help_menus: true` → `veafRadio.initialize(true)`
- `test_assets_table()`: assets list → correct Lua table literal
- `test_qra_builder_chain()`: QRA definition → correct `VeafQRA:new():set*():start()` output
- `test_combat_mission_briefing()`: multi-line briefing → `[[...]]` long string

Extend `test_config_migrator.py` (or `test_v5_converter.py`) with cases for the new extraction patterns.

**YAML-014 — Docs**
`MISSION_MAKER_GUIDE.md`: update "Module configuration" section to describe YAML → `veaf-config.lua` flow, new sections (`mission:`, `security:`, `settings:`, `qra:`, etc.), and `mission-script.lua` role.
`MIGRATION_GUIDE.md`: update convert-v5 section to reflect active extraction + renamed output files.

</details>
