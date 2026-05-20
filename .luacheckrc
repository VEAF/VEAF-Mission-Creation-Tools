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
-- 211: unused variable (too noisy in DCS scripts)
-- 212: unused argument
-- 213: unused loop variable
-- 542: empty if branch (pattern used intentionally)
ignore = { "211", "212", "213", "542" }

-- ── DCS World API globals ────────────────────────────────────────────────────
globals = {
  -- Core DCS API
  "coalition", "world", "trigger", "timer", "land", "env", "country",
  "Group", "Unit", "Airbase", "Object", "Spot", "Controller", "AI", "Radio",
  "VoiceChat", "net", "lfs", "StaticObject",
  -- DCS API globals commonly used but often omitted from stub lists
  "coord", "atmosphere", "missionCommands", "log",
  -- Community scripts
  "mist", "ctld", "CTLD", "csar", "CSAR", "SkynetIADS", "AIRBOSS",
  "AirWaveZone", "ArtilleryUnitHandler", "DcsDataExport", "dcsUnits",
  "GroundUnitHandler", "sha1", "STTS", "AIEN", "weathermark", "dcsbot", "niod",
  "SkynetIADSAbstractRadarElement",
  -- VEAF module namespaces (camelCase — the module-level table, e.g. veafCombatMission = {})
  "veaf", "veafAirbase", "veafAirbaseRunway", "veafAirbases",
  "veafAirWaves", "veafAssets", "veafCacheManager", "veafCarrierOperations",
  "veafCasMission", "veafCombatMission", "veafCombatZone",
  "veafEventHandler", "veafGrass", "veafGroundAI",
  "veafInterpreter", "veafMarkers", "veafMissileGuardian", "veafMove",
  "veafNamedPoints", "veafQraManager", "veafRadio", "veafRecorder", "veafRemote",
  "veafSanctuary", "veafSecurity", "veafShortcuts",
  "veafSkynet", "veafSkynetMonitor",
  "veafSpawn", "veafSpawnableAircraftsEditor",
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
  "VeafFog",
  "VeafMG_Guardian", "VeafMG_Protector", "VeafMG_Weapon",
  "VeafQRA", "VeafSanctuaryZone", "VeafSquareOnMap",
  "VeafSkynetMonitorDescriptor", "VeafSkynetMonitorTask",
  "VeafSkynetMonitorTaskContacts", "VeafSkynetMonitorTaskDescriptor",
  "VeafDynamicLoader",
  -- Module-level debug / config globals
  "traceMarkerId", "debugMarkers", "vars",
  "_",  -- throwaway variable convention (used in for loops, etc.)
  -- Mission / config globals
  "base", "db", "radioSettings", "SERVER_CONFIG", "settings",
  "Sim", "socket", "waypoints", "logError", "inheritsFrom",
  "_VEAF_SCRIPT_DIR", "VEAF_DYNAMIC_MISSIONPATH",
  -- Test infrastructure
  "luaunit", "dcs_mocks",
  "TestVeafCacheManager", "TestVeafInterpreter",
}

-- ── Per-path overrides ────────────────────────────────────────────────────────
files["test/lua/**"] = {
  -- Test files may define globals freely
  globals = { "..." },
}
