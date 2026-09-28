--- Tests for the `veaf.Diagnostics` switch and the combat zone lines it turns on.
---
--- FIX-COMBATZONE-DEAD-UNIT-HAS-NO-GROUP ticket 03. The 2026-09-26 sortie left a question the log could
--- not answer: what the zone's info panel held right after activation. Everything the zone knows about
--- its own content logs below `info`, and the server runs at `info`. `veaf.Diagnostics` writes that
--- knowledge at `info`, marked `DIAG|`, so a watched session can be read live with one filter.
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
dofile(src .. "/veafCombatZone.lua")

veaf.config.language = "en"

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Collect every line written through `env.info`, and restore it afterwards.
local function captureInfo(test)
  test._envInfo = env.info
  test.lines = {}
  local lines = test.lines
  env.info = function(text)
    table.insert(lines, tostring(text))
  end
end

local function restoreInfo(test)
  env.info = test._envInfo
end

--- The `DIAG|` lines captured, and whether one of them contains every fragment given.
local function diagLines(test)
  local found = {}
  for _, line in ipairs(test.lines) do
    if line:find("DIAG|", 1, true) then
      table.insert(found, line)
    end
  end
  return found
end

local function hasDiag(test, ...)
  local fragments = { ... }
  for _, line in ipairs(diagLines(test)) do
    local all = true
    for _, fragment in ipairs(fragments) do
      if not line:find(fragment, 1, true) then
        all = false
      end
    end
    if all then
      return true
    end
  end
  return false
end

--- A live group of red units of the given types.
local function redGroup(name, types)
  local units = {}
  for _, typeName in ipairs(types) do
    table.insert(units, {
      getCoalition = function()
        return 1
      end,
      getTypeName = function()
        return typeName
      end,
    })
  end
  dcs_mocks.addGroup(name, {
    getUnits = function()
      return units
    end,
  })
end

-- ---------------------------------------------------------------------------
-- The switch itself
-- ---------------------------------------------------------------------------
TestVeafDiagSwitch = {}

function TestVeafDiagSwitch:setUp()
  captureInfo(self)
  self._diag = veaf.Diagnostics
end

function TestVeafDiagSwitch:tearDown()
  veaf.Diagnostics = self._diag
  restoreInfo(self)
end

function TestVeafDiagSwitch:test_off_by_default()
  luaunit.assertFalse(veaf.Diagnostics)
end

function TestVeafDiagSwitch:test_off_writes_nothing()
  veaf.Diagnostics = false
  veaf.diag(veafCombatZone.Id, "zone %s", "X")
  luaunit.assertEquals(#diagLines(self), 0)
end

function TestVeafDiagSwitch:test_on_writes_a_marked_info_line_with_its_values()
  veaf.Diagnostics = true
  veaf.diag(veafCombatZone.Id, "zone %s holds %s", "X", 3)
  luaunit.assertTrue(hasDiag(self, "zone X holds 3"))
end

function TestVeafDiagSwitch:test_a_multi_line_value_stays_on_one_marked_line()
  -- dcs.log writes an embedded newline as it is, and only the first line carries the prefix: a filter
  -- on DIAG| would keep the panel's header and drop the list it exists to show.
  veaf.Diagnostics = true
  veaf.diag(veafCombatZone.Id, "panel: %s", "ENEMIES: 3\n2 T-72B\n1 Shilka")
  luaunit.assertTrue(hasDiag(self, "ENEMIES: 3", "2 T-72B", "1 Shilka"))
  for _, line in ipairs(self.lines) do
    luaunit.assertNil(line:find("\n", 1, true), "no newline may reach the log")
  end
end

function TestVeafDiagSwitch:test_on_writes_even_when_the_module_logs_below_info()
  -- The server runs its modules at info or less; a diagnostic that obeys a module's `warning` level
  -- would be missing exactly where it was switched on to be read.
  veaf.Diagnostics = true
  local logger = veaf.loggers.get(veafCombatZone.Id)
  local saved = logger.getEffectiveLevel
  logger.getEffectiveLevel = function()
    return 1
  end
  veaf.diag(veafCombatZone.Id, "still here")
  logger.getEffectiveLevel = saved
  luaunit.assertTrue(hasDiag(self, "still here"))
end

-- ---------------------------------------------------------------------------
-- What a combat zone says with the switch on
-- ---------------------------------------------------------------------------
TestVeafDiagCombatZone = {}

function TestVeafDiagCombatZone:setUp()
  captureInfo(self)
  self._diag = veaf.Diagnostics
  veaf.Diagnostics = true
  self._findUnit = veafUnits.findUnit
  -- Not under test, and it drives a DCS controller the mocks do not model.
  self._readyForCombat = veaf.readyForCombat
  veaf.readyForCombat = function() end
  veafUnits.findUnit = function(typeName)
    if typeName == "T-72B" or typeName == "Ural-375" then
      return { vehicle = true, naval = false, infantry = false }
    end
    return nil
  end
  veafCombatZone.zonesDict = {}
  veafCombatZone.zonesList = {}
  dcs_mocks.clearUnitsAndGroups()
  self.z = VeafCombatZone:new():setFriendlyName("Wahner"):setMissionEditorZoneName("CZ_WAHNER"):setShowZonePositionInfo(false)
  self.z:disableJunkCleanup()
end

function TestVeafDiagCombatZone:tearDown()
  veafUnits.findUnit = self._findUnit
  veaf.readyForCombat = self._readyForCombat
  veaf.Diagnostics = self._diag
  dcs_mocks.clearUnitsAndGroups()
  restoreInfo(self)
end

function TestVeafDiagCombatZone:test_the_panel_says_what_each_group_holds()
  redGroup("[r]-India#1", { "T-72B", "T-72B" })
  self.z:setActive(true):addSpawnedGroup("[r]-India#1"):addSpawnedGroup("[r]-Gone#2")

  self.z:getInformation(nil)

  luaunit.assertTrue(hasDiag(self, "CZ_WAHNER", "[r]-India#1", "2 alive", "T-72B"))
  luaunit.assertTrue(hasDiag(self, "CZ_WAHNER", "[r]-Gone#2", "not found"), "a group DCS no longer knows must be named")
end

function TestVeafDiagCombatZone:test_the_panel_names_a_unit_it_does_not_count()
  -- The one silent drop in the tally: a type veafUnits cannot resolve is left out of the list.
  redGroup("[r]-Odd#3", { "Mystery Tank" })
  self.z:setActive(true):addSpawnedGroup("[r]-Odd#3")

  self.z:getInformation(nil)

  luaunit.assertTrue(hasDiag(self, "Mystery Tank", "not counted"))
end

function TestVeafDiagCombatZone:test_the_panel_logs_the_text_it_sends()
  redGroup("[r]-India#1", { "T-72B" })
  self.z:setActive(true):addSpawnedGroup("[r]-India#1")

  local text = self.z:getInformation(nil)

  -- Compared folded, as veaf.diag writes it: the panel is several lines long.
  luaunit.assertTrue(hasDiag(self, "panel text", (text:gsub("\r?\n", " / ")):sub(1, 40)))
end

function TestVeafDiagCombatZone:test_the_watchdog_says_what_it_counted_and_decided()
  redGroup("[r]-India#1", { "T-72B" })
  self.z:setActive(true):addSpawnedGroup("[r]-India#1")

  self.z:completionCheck()

  luaunit.assertTrue(hasDiag(self, "CZ_WAHNER", "[r]-India#1", "1 alive"))
  luaunit.assertTrue(hasDiag(self, "CZ_WAHNER", "enemies=1", "not complete"))
end

function TestVeafDiagCombatZone:test_the_watchdog_says_when_the_zone_completes()
  self.z:setActive(true)

  self.z:completionCheck()

  luaunit.assertTrue(hasDiag(self, "CZ_WAHNER", "enemies=0", "complete"))
  luaunit.assertTrue(hasDiag(self, "CZ_WAHNER", "deactivated"))
end

function TestVeafDiagCombatZone:test_an_activation_request_is_logged_with_its_outcome()
  veafCombatZone.AddZone(self.z)
  self.z:setActive(true)

  veafCombatZone.ActivateZone("CZ_WAHNER", true)

  luaunit.assertTrue(hasDiag(self, "CZ_WAHNER", "activation requested", "already active"))
end

function TestVeafDiagCombatZone:test_an_accepted_activation_request_says_so()
  veafCombatZone.AddZone(self.z)
  self._schedule = veaf.scheduleFunction
  veaf.scheduleFunction = function() end -- the activation itself is not under test

  veafCombatZone.ActivateZone("CZ_WAHNER", true)
  veaf.scheduleFunction = self._schedule

  luaunit.assertTrue(hasDiag(self, "CZ_WAHNER", "activation requested", "activating in 1 s"))
end

function TestVeafDiagCombatZone:test_an_activation_request_for_an_unknown_zone_says_so()
  veafCombatZone.ActivateZone("NO_SUCH_ZONE", true)

  luaunit.assertTrue(hasDiag(self, "NO_SUCH_ZONE", "unknown zone"))
end

function TestVeafDiagCombatZone:test_a_panel_request_names_the_pilot_who_asked()
  veafCombatZone.AddZone(self.z)
  self.z:setActive(true)

  veafCombatZone.GetInformationOnZone({ "CZ_WAHNER", "Ramstein_A-10C II_46-1" })

  luaunit.assertTrue(hasDiag(self, "CZ_WAHNER", "panel requested by Ramstein_A-10C II_46-1"))
end

function TestVeafDiagCombatZone:test_each_element_spawn_is_logged_with_its_group()
  -- A stub for the spawn chain, which is not what is under test: the element spawns as a named group.
  local savedSpawn = VeafGroupSpawn
  local builder
  builder = setmetatable({}, {
    __index = function(_, key)
      if key == "respawn" then
        return function()
          redGroup("[r]-Bravo#7", { "Ural-375" })
          return { name = "[r]-Bravo#7" }
        end
      end
      return function()
        return builder
      end
    end,
  })
  VeafGroupSpawn = {
    new = function()
      return builder
    end,
  }
  local element = VeafCombatZoneElement:new():setName("CZ_WAHNER-cible-1"):setDcsGroup(true):setSpawnRadius(0)
  element:setPosition({ x = 0, y = 0, z = 0 }):setCoalition(1)
  self.z:setActive(true)

  self.z:spawnElement(element, true)
  VeafGroupSpawn = savedSpawn

  luaunit.assertTrue(hasDiag(self, "CZ_WAHNER", "CZ_WAHNER-cible-1", "[r]-Bravo#7", "1 alive"))
end

function TestVeafDiagCombatZone:test_a_failed_element_spawn_is_logged()
  local savedSpawn = VeafGroupSpawn
  local builder
  builder = setmetatable({}, {
    __index = function(_, key)
      if key == "respawn" then
        return function()
          return nil
        end
      end
      return function()
        return builder
      end
    end,
  })
  VeafGroupSpawn = {
    new = function()
      return builder
    end,
  }
  local element = VeafCombatZoneElement:new():setName("CZ_WAHNER-cible-2"):setDcsGroup(true):setSpawnRadius(0)
  element:setPosition({ x = 0, y = 0, z = 0 }):setCoalition(1)
  self.z:setActive(true)

  self.z:spawnElement(element, true)
  VeafGroupSpawn = savedSpawn

  luaunit.assertTrue(hasDiag(self, "CZ_WAHNER", "CZ_WAHNER-cible-2", "FAILED"))
end

os.exit(luaunit.LuaUnit.run())
