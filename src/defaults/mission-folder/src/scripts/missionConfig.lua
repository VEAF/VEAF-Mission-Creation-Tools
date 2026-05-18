-- Mission configuration file for the VEAF framework
-- https://github.com/VEAF/VEAF-Mission-Creation-Tools
--
-- This file is loaded at mission start after veaf-scripts.lua.
-- Call initialize() on each module you want to enable.
-- Modules are listed in recommended initialization order.

-- ── Mission identity ─────────────────────────────────────────────────────────

veaf.config.MISSION_NAME = "My-Mission" -- used in radio menus and log messages
veaf.config.MISSION_EXPORT_PATH = nil -- nil = default DCS Saved Games path

-- Set for era-specific behaviour (MODERN by default).
-- veaf.config.era = veaf.ERA.WW2         -- WW2 | COLD_WAR | MODERN

-- ── Security ─────────────────────────────────────────────────────────────────

if veafSecurity then
  -- All commands are open to all players when SecurityDisabled = true (default).
  -- Set to false and add a password hash to require authentication.
  veaf.SecurityDisabled = true
  -- veaf.SecurityDisabled = false
  -- veafSecurity.password_L9["<SHA1 hash of the password>"] = true
  veafSecurity.initialize()
end

-- ── Radio menus ───────────────────────────────────────────────────────────────

if veafRadio then
  veafRadio.initialize(true) -- true = create help sub-menus
end

-- ── Shortcuts (F10 marker command aliases) ────────────────────────────────────

if veafShortcuts then
  veafShortcuts.initialize()
  -- Example — add a marker alias for a quick SA-11 spawn:
  -- veafShortcuts.AddAlias(
  --     VeafAlias:new()
  --         :setName("-sa11")
  --         :setDescription("SA-11 Gadfly (9K37 Buk) battery")
  --         :setVeafCommand("_spawn group, name sa11")
  --         :setBypassSecurity(true)
  -- )
end

-- ── Named Points (bullseye, airbases, custom POIs) ────────────────────────────

if veafNamedPoints then
  local customPoints = {
    -- {name = "Battle Area Alpha", point = coord.LLtoLO("41.123456", "44.987654")},
  }
  veafNamedPoints.initialize(customPoints)
end

-- ── Spawn (F10 marker commands: units, smoke, JTAC, cargo, FARP) ─────────────

if veafSpawn then
  veafSpawn.initialize()
end

-- ── Optional modules — uncomment the blocks you need ─────────────────────────

-- Carrier Operations (BRC, TACAN, ICLS management)
--[[
if veafCarrierOperations then
  veafCarrierOperations.initialize(true)
end
]]

-- CAS Missions (generated ground threat packages with scoring)
--[[
if veafCasMission then
  veafCasMission.initialize()
end
]]

-- Transport Missions (helicopter / cargo pickup & delivery)
--[[
if veafTransportMission then
  veafTransportMission.initialize()
end
]]

-- Combat Zones (activatable A/G combat areas with scoring)
--[[
if veafCombatZone then
  veafCombatZone.initialize()
end
]]

-- QRA Manager
if veafQraManager then
  veafQraManager.initialize()
  -- VeafQRA.ToggleAllSilence(true)  -- uncomment to mute all QRA radio messages

  -- Example QRA — copy and adapt as needed:
  -- local qraRedNorth = VeafQRA:new()
  --     :setName("QRA-Red-North")
  --     :setTriggerZone("QRA-RED-NORTH")    -- trigger zone name in the DCS mission editor
  --     :setZoneRadius(50000)               -- 50 km radius
  --     :addGroup("RED-F-16 QRA")           -- DCS group name (add more :addGroup() for multi-slot QRA)
  --     :setCoalition(coalition.side.RED)
  --     :setDelayBeforeActivating(30)       -- seconds after first incursion before scramble
  --     :start()
end

-- Grass runways / FARP decoration
--[[
if veafGrass then
  veafGrass.initialize()
end
]]

-- Assets (tankers, AWACS, carriers — state tracking and F10 menus)
--[[
if veafAssets then
  veafAssets.Assets = {
    -- {sort = 1, name = "T1-Arco-1",     description = "Arco-1 (KC-135)",  information = "Tacan 64Y\nU290.50 (20)"},
    -- {sort = 2, name = "A1-Magic",       description = "Magic (E-2D)",     information = "Datalink 315.3\nU282.20 (13)"},
    -- {sort = 3, name = "CSG-74-Stennis", description = "Stennis (CVN-74)", information = "Tacan 10X STS\nICLS 10\nU225 (10)"},
  }
  veafAssets.initialize()
end
]]

-- Move (relocate units via F10 markers)
--[[
if veafMove then
  veafMove.initialize()
end
]]

-- Sanctuary zones (auto-destroy units entering a protected area)
--[[
if veafSanctuary then
  veafSanctuary.initialize()
end
]]

-- Weather display in F10 menu
--[[
if veafWeather then
  veafWeather.initialize()
end
]]

-- Skynet-IADS integration
--[[
if veafSkynet then
  veafSkynet.initialize(
    false, -- includeRedInRadio
    false, -- debugRed
    false, -- includeBlueInRadio
    false -- debugBlue
  )
end
]]

-- Remote interface (NIOD / SLMOD server commands)
--[[
if veafRemote then
  veafRemote.initialize()
end
]]

-- Silence default ATC on all airbases
-- veaf.silenceAtcOnAllAirbases()

-- ── Interpreter and Markers — initialize LAST ─────────────────────────────────
-- Must come after all modules that register F10 marker commands.

if veafInterpreter then
  veafInterpreter.initialize()
end
