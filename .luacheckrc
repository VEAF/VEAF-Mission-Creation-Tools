-- Luacheck configuration for VEAF Mission Creation Tools
-- https://luacheck.readthedocs.io/en/stable/config.html
--
-- Run:  luacheck src/scripts/veaf/
-- CI:   lua-ci.yml (luacheck job)

-- Lua 5.1 — matches the DCS World runtime
std = "lua51"

-- Match .stylua.toml column_width
max_line_length = 140

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
  -- Community scripts
  "mist", "ctld", "CTLD", "csar", "CSAR", "SkynetIADS", "AIRBOSS",
  "AirWaveZone", "ArtilleryUnitHandler", "DcsDataExport", "dcsUnits",
  "GroundUnitHandler", "sha1", "STTS", "AIEN", "weathermark", "dcsbot", "niod",
  "SkynetIADSAbstractRadarElement",
  -- VEAF globals
  "veaf", "veafAirbase", "veafAirbaseRunway", "veafAirbases",
  "VeafAirUnitTemplate", "veafAirWaves",
  "VeafAlias", "VeafAliasForCombatMission", "VeafAliasForCombatZone",
  "veafAssets", "VeafCache", "veafCacheManager", "veafCarrierOperations",
  "veafCasMission", "VeafCircleOnMap",
  "VeafCombatMission", "VeafCombatMissionElement", "VeafCombatMissionObjective",
  "VeafCombatOperation", "VeafCombatOperationTaskingOrder",
  "VeafCombatZone", "VeafCombatZoneElement", "VeafDrawingOnMap",
  "veafEventHandler", "VeafFog", "veafGrass", "veafGroundAI",
  "veafInterpreter", "veafMarkers",
  "VeafMG_Guardian", "VeafMG_Protector", "VeafMG_Weapon",
  "veafMissileGuardian", "veafMove", "veafNamedPoints",
  "VeafQRA", "veafQraManager", "veafRadio", "veafRecorder", "veafRemote",
  "veafSanctuary", "VeafSanctuaryZone", "veafSecurity", "veafShortcuts",
  "veafSkynet", "veafSkynetMonitor",
  "VeafSkynetMonitorDescriptor", "VeafSkynetMonitorTask",
  "VeafSkynetMonitorTaskContacts", "VeafSkynetMonitorTaskDescriptor",
  "veafSpawn", "veafSpawnableAircraftsEditor", "VeafSquareOnMap",
  "veafSunTimes", "veafTime", "veafTransportMission", "veafUnits",
  "veafWeather", "veafWeatherAtis", "veafWeatherData", "veafWeatherUnitSystem",
  "VeafDynamicLoader", "veafHoundElint", "veafServerHook",
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
