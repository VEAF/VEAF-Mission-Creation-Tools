-- Luacheck configuration for VEAF Mission Creation Tools
-- https://luacheck.readthedocs.io/en/stable/config.html
--
-- Run:  luacheck src/scripts/veaf/
-- CI:   lua-ci.yml (luacheck job)

-- Lua 5.1 — matches the DCS World runtime
std = "lua51"

-- StyLua already enforces line length; disable here to avoid duplicate noise
max_line_length = false

-- Warnings to ignore globally
-- 211: unused variable
-- 212: unused argument
-- 213: unused loop variable
-- 231: local variable shadowed by loop variable
-- 311: value assigned to variable is overwritten before use (noisy in complex closures)
-- 312: value assigned to argument is overwritten before use
-- 314: value assigned to field is overwritten before use (veafNamedPoints data tables)
-- 321: accessing uninitialized local (nil-then-accumulate pattern, e.g. veafWeather)
-- 331: value assigned is mutated but never accessed
-- 411: variable is already defined (redefinition in same scope)
-- 412: variable is already defined as an argument (local self = self OOP pattern)
-- 413: variable already defined as loop variable
-- 421: shadowing definition of local variable
-- 422: shadowing definition of argument
-- 431: shadowing upvalue
-- 432: shadowing upvalue argument
-- 512: loop is executed at most once (intentional early-return pattern)
-- 542: empty if branch
-- 581: 'not (x == y)' style suggestion
-- 611: line contains only whitespace
-- 612: line contains trailing whitespace
-- 614: trailing whitespace in a comment
ignore = { "211", "212", "213", "231", "311", "312", "314", "321", "331", "411", "412", "413", "421", "422", "431", "432", "512", "542", "581", "611", "612", "614" }

-- ── DCS World API globals ────────────────────────────────────────────────────
globals = {
  -- Core DCS API
  "coalition", "world", "trigger", "timer", "land", "env", "country",
  "Group", "Unit", "Airbase", "Object", "Spot", "Controller", "AI", "Radio",
  "VoiceChat", "net", "lfs", "StaticObject",
  -- DCS API globals commonly used but often omitted from stub lists
  "coord", "atmosphere", "missionCommands", "log",
  -- Native trigger-action functions of the mission scripting environment, used by
  -- veafAssist. They live in no script — the engine exposes them (verified in game,
  -- .backlog/FEAT-ASSIST-CHECKLISTS/tickets/01-primitives-spike.md).
  "a_cockpit_highlight", "a_cockpit_remove_highlight", "a_cockpit_perform_clickable_action",
  "a_out_picture_u", "a_out_picture_stop", "getValueResourceByKey",
  -- Undocumented native DCS singleton for scenery-aware ground placement, used by
  -- veaf.findSpawnPoint. **Verified in game 2026-08-06**, like the a_* entries above: it exists,
  -- and the points it returns genuinely avoid buildings and forests. Signature measured as
  -- getSimpleZones(centre, radius, spacing, count) returning {x, y, course} — a vec2 plus a
  -- heading. Its radius argument does **not** bound the answers, which is why the call site
  -- filters by distance. See .backlog/FEAT-SCENERY-AWARE-SPAWN/tickets/01-probe-disposition.md.
  -- Still absent from dcs-world-schema, so it stays guarded and pcall-ed at the call site: what
  -- was measured is this DCS version on one theatre, not a contract ED owes us.
  "Disposition",
  -- Community scripts
  "mist", "ctld", "CTLD", "csar", "CSAR", "SkynetIADS", "AIRBOSS",
  -- CTLD 2 managers: the engine's public surface, replacing the v1 ctld.* globals
  "CTLDZoneManager", "CTLDBeaconManager", "CTLDJTACManager",
  -- CTLD 2 config singleton: veaf.isCtldReady() reads its isLoaded flag to tell a started
  -- engine from one still parked on ctld.dontInitialize
  "CTLDConfig",
  "AirWaveZone", "ArtilleryUnitHandler", "DcsDataExport", "dcsUnits",
  "GroundUnitHandler", "sha1", "STTS", "AIEN", "weathermark", "dcsbot", "niod",
  "SkynetIADSAbstractRadarElement",
  -- VEAF module namespaces (camelCase — the module-level table, e.g. veafCombatMission = {})
  "veaf", "veafAirbase", "veafAirbaseRunway", "veafAirbases",
  "veafAirWaves", "veafAssets", "veafAssist", "veafCacheManager", "veafCarrierOperations",
  "veafCasMission", "veafCombatMission", "veafCombatZone", "veafCommands",
  "veafEventHandler", "veafGeo", "veafGrass", "veafGroundAI",
  "veafI18n", "veafInterpreter", "veafMarkers", "veafMath", "veafMissileGuardian",
  "veafMissionDb", "veafMove",
  "veafNamedPoints", "veafQraManager", "veafRadio", "veafRecorder", "veafRemote",
  "veafSanctuary", "veafScheduler", "veafSecurity", "veafShortcuts",
  "veafSkynet", "veafSkynetMonitor",
  "veafDcsSpawner", "veafSpawn", "veafSpawnableAircraftsEditor",
  "veafSunTimes", "veafTime", "veafTransportMission", "veafUnits",
  "veafWeather", "veafWeatherAtis", "veafWeatherData", "veafWeatherUnitSystem",
  "veafHoundElint", "veafServerHook",
  -- VEAF class names (PascalCase — OOP constructors)
  "VeafAirUnitTemplate",
  "VeafAlias", "VeafAliasForCombatMission", "VeafAliasForCombatZone",
  "VeafCache", "VeafCircleOnMap",
  "VeafCombatMission", "VeafCombatMissionElement", "VeafCombatMissionObjective",
  "VeafCombatOperation", "VeafCombatOperationTaskingOrder",
  "VeafCombatZone", "VeafCombatZoneElement", "VeafDrawingOnMap",
  "VeafFog", "VeafGroupSpawn",
  "VeafMG_Guardian", "VeafMG_Protector", "VeafMG_Weapon",
  "VeafQRA", "VeafQRACore", "VeafQRALogistics", "VeafSanctuaryZone", "VeafSquareOnMap",
  "VeafSkynetMonitorDescriptor", "VeafSkynetMonitorTask",
  "VeafSkynetMonitorTaskContacts", "VeafSkynetMonitorTaskDescriptor",
  "VeafDynamicLoader",
  -- Module-level debug / config globals
  "traceMarkerId", "debugMarkers", "vars",
  "_",  -- throwaway variable convention (used in for loops, etc.)
  -- Mission / config globals
  "base", "db", "radioSettings", "SERVER_CONFIG", "settings",
  "Sim", "socket", "waypoints", "logError", "inheritsFrom",
  "_VEAF_SCRIPT_DIR", "VEAF_DYNAMIC_MISSIONPATH", "VEAF_BUILD_VERSION",
  -- Test infrastructure
  "luaunit", "dcs_mocks",
  "TestVeafCacheManager", "TestVeafInterpreter",
}

-- ── Per-path overrides ────────────────────────────────────────────────────────
files["test/lua/**"] = {
  -- Test files may define globals freely
  globals = { "..." },
}
