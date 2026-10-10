--- Tests for the MISSIONS radio menu of veafCombatMission.lua, against the real veafRadio menu tree.
---
--- FIX-COMBATMISSION-MENU-MISSING ticket 02: since #1085 the generated `veaf-config.lua` calls
--- `veafCombatMission.initialize()` after its CAP missions, so `rootPath` is set when the mission's own
--- `mission-script.lua` declares its scripted missions. Each of those went through
--- `mission:initialize()` → `updateRadioMenu()` with no submenu of its own yet, and veafRadio put the
--- "Activate mission" command at the **root** of the VEAF menu — 25 of them on the Caucasus Open
--- Training in 6.29.0, measured in game on 2026-10-10.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
dofile(src .. "/veafDcsSpawner.lua")
dofile(src .. "/veafI18n.lua")
dofile(src .. "/veafSecurity.lua")
dofile(src .. "/veafRadio.lua")
dofile(src .. "/veafCombatMission.lua")

-- initialize() registers the module with veafRemote, which these tests do not load.
veafRemote = veafRemote or { registerRemoteModule = function() end }
veaf.DO_NOT_EXPORT_JSON_FILES = true

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- A mission with a radio menu, the way a mission-script.lua declares one: initialized by the
--- script itself, then added — so `updateRadioMenu()` runs twice before the module builds anything.
local function declare(name)
  local mission = VeafCombatMission:new():setName(name):setRadioMenuEnabled(true):setSecured(false):initialize()
  return veafCombatMission.AddMission(mission)
end

--- Every command under `menu`, at any depth.
local function allCommands(menu, into)
  into = into or {}
  for _, command in pairs(menu.commands or {}) do
    table.insert(into, command)
  end
  for _, subMenu in pairs(menu.subMenus or {}) do
    allCommands(subMenu, into)
  end
  return into
end

--- The MISSIONS submenus at the root of the VEAF menu.
local function missionsMenus()
  local found = {}
  for _, subMenu in pairs(veafRadio.radioMenu.subMenus) do
    if subMenu.title == veaf.t(veafCombatMission.RadioMenuName) then
      table.insert(found, subMenu)
    end
  end
  return found
end

--- Whether the MISSIONS menu offers to activate the mission called `name`.
local function canActivateFromMissions(name)
  if not veafCombatMission.rootPath then
    return false
  end
  for _, command in pairs(allCommands(veafCombatMission.rootPath)) do
    if command.method == veafCombatMission.ActivateMission and command.parameters == name then
      return true
    end
  end
  return false
end

--- Run what the scheduler has queued, far enough ahead for any deferred rebuild.
local function letTimePass()
  dcs_mocks.runScheduled(timer.getTime() + 60)
end

-- ---------------------------------------------------------------------------
-- TestCombatMissionDeclaredAfterInitialize
-- ---------------------------------------------------------------------------
TestCombatMissionDeclaredAfterInitialize = {}

function TestCombatMissionDeclaredAfterInitialize:setUp()
  dcs_mocks.scheduledTasks = {}
  timer.setTime(0)
  veafRadio.dontCreateMenus = true
  veafRadio.radioMenu.subMenus = {}
  veafRadio.radioMenu.commands = {}
  veafCombatMission.rootPath = nil
  veafCombatMission.missionsDict = {}
  veafCombatMission.missionsList = {}
  veafCombatMission._initialized = nil
  veafCombatMission._radioMenuRebuildScheduled = nil
  self.savedBuild = veafCombatMission.buildRadioMenu
  self.builds = 0
  local build = self.savedBuild
  veafCombatMission.buildRadioMenu = function()
    self.builds = self.builds + 1
    return build()
  end
end

function TestCombatMissionDeclaredAfterInitialize:tearDown()
  veafCombatMission.buildRadioMenu = self.savedBuild
end

--- What the generated veaf-config.lua does: a CAP mission, then initialize().
function TestCombatMissionDeclaredAfterInitialize:_configWithOneMission()
  declare("CAP-From-Config")
  veafCombatMission.initialize()
  luaunit.assertNotNil(veafCombatMission.rootPath, "the config's mission builds the MISSIONS menu")
  self.builds = 0
end

function TestCombatMissionDeclaredAfterInitialize:test_a_mission_declared_after_initialize_leaves_no_command_at_the_veaf_root()
  self:_configWithOneMission()
  declare("Interception-VIP")
  luaunit.assertEquals(#veafRadio.radioMenu.commands, 0)
  letTimePass()
  luaunit.assertEquals(#veafRadio.radioMenu.commands, 0)
end

function TestCombatMissionDeclaredAfterInitialize:test_a_mission_declared_after_initialize_appears_under_missions_after_the_deferred_rebuild()
  self:_configWithOneMission()
  declare("Interception-VIP")
  luaunit.assertFalse(canActivateFromMissions("Interception-VIP"), "not before the deferred rebuild")
  letTimePass()
  luaunit.assertTrue(canActivateFromMissions("Interception-VIP"))
  luaunit.assertTrue(canActivateFromMissions("CAP-From-Config"))
  luaunit.assertEquals(#missionsMenus(), 1)
end

function TestCombatMissionDeclaredAfterInitialize:test_a_burst_of_three_declarations_rebuilds_the_menu_once()
  self:_configWithOneMission()
  declare("Interception-VIP")
  declare("Attaque-Gudauta")
  declare("Vague-Tu-160")
  luaunit.assertEquals(self.builds, 0, "nothing is rebuilt while the script is still declaring")
  letTimePass()
  luaunit.assertEquals(self.builds, 1)
  luaunit.assertTrue(canActivateFromMissions("Vague-Tu-160"))
end

--- A config with COMBATMISSION enabled and no mission: initialize() builds nothing, and the
--- missions the script declares afterwards still get their menu.
function TestCombatMissionDeclaredAfterInitialize:test_missions_declared_after_an_empty_initialize_get_a_missions_menu()
  veafCombatMission.initialize()
  luaunit.assertNil(veafCombatMission.rootPath)
  declare("Interception-VIP")
  letTimePass()
  luaunit.assertEquals(#veafRadio.radioMenu.commands, 0)
  luaunit.assertTrue(canActivateFromMissions("Interception-VIP"))
end

--- The generator's order: missions first, initialize() after. Nothing is deferred then —
--- initialize() builds the menu itself.
function TestCombatMissionDeclaredAfterInitialize:test_missions_declared_before_initialize_schedule_no_rebuild()
  declare("CAP-From-Config")
  declare("Other-From-Config")
  luaunit.assertNil(next(dcs_mocks.scheduledTasks))
  veafCombatMission.initialize()
  luaunit.assertEquals(self.builds, 1)
  luaunit.assertTrue(canActivateFromMissions("Other-From-Config"))
end

--- The workaround the Caucasus Open Training carries in its mission-script.lua until a release
--- ships this fix: rootPath set to nil around the declarations, restored, then a rebuild. With the
--- fix it must stay harmless — one MISSIONS menu, nothing at the root, every mission present.
function TestCombatMissionDeclaredAfterInitialize:test_the_caucasus_workaround_stays_harmless()
  self:_configWithOneMission()
  local savedRootPath = veafCombatMission.rootPath
  veafCombatMission.rootPath = nil
  declare("Interception-VIP")
  declare("Attaque-Gudauta")
  veafCombatMission.rootPath = savedRootPath
  veafCombatMission.buildRadioMenu()
  letTimePass()
  luaunit.assertEquals(#veafRadio.radioMenu.commands, 0)
  luaunit.assertEquals(#missionsMenus(), 1)
  luaunit.assertIs(veafCombatMission.rootPath, savedRootPath)
  luaunit.assertTrue(canActivateFromMissions("Interception-VIP"))
  luaunit.assertTrue(canActivateFromMissions("Attaque-Gudauta"))
end

os.exit(luaunit.LuaUnit.run())
