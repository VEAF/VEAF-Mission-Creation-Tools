--- What a player may type after a security-bypassing shortcut (FEAT-BFR-V6-SUPPORT ticket 01).
---
--- A bypassing shortcut (`-jtac`, `-smoke`, `-tacan`…) skips the mission password because its effect is
--- harmless. The text typed after it must only tune that effect: each shortcut declares the options it
--- admits, with a strict value form, and anything else is refused whole.
---
--- Run:  lua test/lua/test_veafShortcuts_bypass.lua

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
dofile(src .. "/veafSpawn.lua")
dofile(src .. "/veafShortcuts.lua")

local POSITION = { x = 0, y = 0, z = 0 }
local MARK_ID = 77
local AUTHOR_UNIT_ID = 4242

-- The marker's author, as `world.getMarkPanels` describes him.
local function authorPanels()
  return {
    {
      idx = MARK_ID,
      author = "Pilot 1",
      groupID = 12,
      initiator = {
        getName = function()
          return "Pilot 1 unit"
        end,
        getID = function()
          return AUTHOR_UNIT_ID
        end,
      },
    },
  }
end

TestBypassShortcuts = {}

function TestBypassShortcuts:setUp()
  dcs_mocks.reset()
  veafShortcuts.aliases = {}
  veafShortcuts.buildDefaultList()
  self.savedGetMarkPanels = world.getMarkPanels
  world.getMarkPanels = authorPanels
  self.savedSpawnExecute = veafSpawn.executeCommand
  self.savedSpawnUnit = veafSpawn.spawnUnit
  self.savedSecurityDisabled = veaf.SecurityDisabled
  veaf.SecurityDisabled = nil
  self.passwordChecks = 0
  self.savedCheckL9 = veafSecurity.checkSecurity_L9
  self.savedCheckL1 = veafSecurity.checkSecurity_L1
  veafSecurity.checkSecurity_L9 = function()
    self.passwordChecks = self.passwordChecks + 1
    return false
  end
  veafSecurity.checkSecurity_L1 = veafSecurity.checkSecurity_L9
  -- What reached the spawn module, and with which security flag.
  self.reached = {}
  veafSpawn.executeCommand = function(_, command, _, _, bypassSecurity)
    table.insert(self.reached, { command = command, bypass = bypassSecurity })
    return true
  end
end

function TestBypassShortcuts:tearDown()
  world.getMarkPanels = self.savedGetMarkPanels
  veafSpawn.executeCommand = self.savedSpawnExecute
  veafSpawn.spawnUnit = self.savedSpawnUnit
  veafSecurity.checkSecurity_L9 = self.savedCheckL9
  veafSecurity.checkSecurity_L1 = self.savedCheckL1
  veaf.SecurityDisabled = self.savedSecurityDisabled
end

--- A marker dropped by a pilot.
local function marker(text)
  return veafShortcuts.executeCommand(POSITION, text, coalition.side.RED, MARK_ID, false)
end

function TestBypassShortcuts:assertReached(command)
  luaunit.assertEquals(#self.reached, 1)
  luaunit.assertEquals(self.reached[1].command, command)
end

function TestBypassShortcuts:assertRefused()
  luaunit.assertEquals(#self.reached, 0)
  local told = dcs_mocks.messagesContaining("")
  luaunit.assertEquals(#told, 1)
  -- to the marker's author only, never to everyone
  luaunit.assertEquals(told[1].fn, "outTextForUnit")
  luaunit.assertEquals(told[1].target, AUTHOR_UNIT_ID)
end

-- -----------------------------------------------------------------------
-- The defect, end to end through the real spawn parser
-- -----------------------------------------------------------------------

function TestBypassShortcuts:test_trailing_spawn_options_spawn_nothing()
  veafSpawn.executeCommand = self.savedSpawnExecute
  local spawned = {}
  veafSpawn.spawnUnit = function(_, _, name, _, country)
    table.insert(spawned, { name = name, country = country })
  end

  marker("-jtac, name S-300PS 40B6M tr, country RUSSIA, multiplier 3")

  luaunit.assertEquals(#spawned, 0)
end

function TestBypassShortcuts:test_bare_jtac_still_spawns_its_jeep_without_password()
  veafSpawn.executeCommand = self.savedSpawnExecute
  local spawned = {}
  veafSpawn.spawnUnit = function(_, _, name, _, country)
    table.insert(spawned, { name = name, country = country })
  end

  marker("-jtac")

  luaunit.assertEquals(self.passwordChecks, 0)
  luaunit.assertEquals(#spawned, 1)
  luaunit.assertEquals(spawned[1].country, "USA")
end

-- -----------------------------------------------------------------------
-- Admitted: the documented uses
-- -----------------------------------------------------------------------

function TestBypassShortcuts:test_jtac_laser_code_is_admitted()
  marker("-jtac, laser 1511")
  self:assertReached("_spawn jtac, , laser 1511")
  luaunit.assertTrue(self.reached[1].bypass)
end

function TestBypassShortcuts:test_jtac_frequency_and_modulation_are_admitted()
  marker("-jtac, freq 133.5, mod FM")
  self:assertReached("_spawn jtac, , freq 133.5, mod FM")
end

function TestBypassShortcuts:test_smoke_colour_is_admitted()
  marker("-smoke, color red")
  self:assertReached("_spawn smoke, color white, shells 1, radius 1, , color red")
end

function TestBypassShortcuts:test_tacan_settings_are_admitted()
  marker("-tacan, channel 37, band Y, code TST, radius 200")
  self:assertReached("_spawn tacan, band X, channel 99, , channel 37, band Y, code TST, radius 200")
end

function TestBypassShortcuts:test_light_altitude_is_admitted()
  marker("-light, alt 2000, radius 800")
  luaunit.assertEquals(#self.reached, 1)
end

function TestBypassShortcuts:test_afac_flag_without_value_is_admitted()
  marker("-afac, immortal, hdg 90, speed 200")
  luaunit.assertEquals(#self.reached, 1)
end

function TestBypassShortcuts:test_point_name_is_admitted()
  -- `-point` goes to veafNamedPoints, which the spawn module sees first and declines here.
  veafSpawn.executeCommand = function()
    return false
  end
  local named
  local savedNamedPoints = veafNamedPoints
  veafNamedPoints = {
    executeCommand = function(_, event)
      named = event.text
      return true
    end,
  }
  marker("-point Bravo 2")
  veafNamedPoints = savedNamedPoints
  luaunit.assertEquals(named, "_name point Bravo 2")
end

-- -----------------------------------------------------------------------
-- Refused, whole, and said to the author only
-- -----------------------------------------------------------------------

function TestBypassShortcuts:test_unit_type_and_country_are_refused()
  marker("-jtac, name S-300PS 40B6M tr, country RUSSIA, multiplier 3")
  self:assertRefused()
end

function TestBypassShortcuts:test_one_bad_option_refuses_the_good_ones_too()
  marker("-smoke, color red, shells 50")
  self:assertRefused()
end

function TestBypassShortcuts:test_a_value_out_of_its_form_is_refused()
  marker("-jtac, laser 15111")
  self:assertRefused()
end

function TestBypassShortcuts:test_an_unknown_colour_is_refused()
  marker("-smoke, color pink")
  self:assertRefused()
end

function TestBypassShortcuts:test_tacan_cannot_name_the_unit_it_replaces()
  marker("-tacan, unitname Carrier")
  self:assertRefused()
end

function TestBypassShortcuts:test_tacan_radius_is_bounded()
  marker("-tacan, radius 1000")
  self:assertRefused()
end

function TestBypassShortcuts:test_a_command_keyword_is_refused_even_inside_a_value()
  marker("-smoke, color red _spawn unit")
  self:assertRefused()
end

function TestBypassShortcuts:test_a_point_name_holding_a_comma_is_refused()
  marker("-point Bravo, password secret")
  self:assertRefused()
end

function TestBypassShortcuts:test_a_point_name_holding_a_keyword_is_refused()
  marker("-point x _spawn unit, name T-72B")
  self:assertRefused()
end

function TestBypassShortcuts:test_a_bypassing_shortcut_with_no_list_admits_nothing()
  marker("-beacon, side red")
  self:assertRefused()
end

function TestBypassShortcuts:test_a_bare_bypassing_shortcut_with_no_list_still_runs()
  marker("-beacon")
  luaunit.assertEquals(#self.reached, 1)
end

function TestBypassShortcuts:test_the_refused_text_is_never_logged()
  marker("-jtac, name T-72B, password hunter2")
  self:assertRefused()
  luaunit.assertEquals(#dcs_mocks.findLog("hunter2"), 0)
  luaunit.assertEquals(#dcs_mocks.findLog("T%-72B"), 0)
  luaunit.assertTrue(#dcs_mocks.findLog("%-jtac") > 0)
end

function TestBypassShortcuts:test_a_delayed_marker_is_refused_when_it_runs()
  marker("-jtac!5, country RUSSIA")
  dcs_mocks.runScheduled(10)
  luaunit.assertEquals(#self.reached, 0)
end

function TestBypassShortcuts:test_an_author_who_cannot_be_found_is_not_shown_anything()
  world.getMarkPanels = function()
    return {}
  end
  marker("-jtac, country RUSSIA")
  luaunit.assertEquals(#self.reached, 0)
  luaunit.assertEquals(#dcs_mocks.messagesContaining(""), 0)
end

-- -----------------------------------------------------------------------
-- Unchanged
-- -----------------------------------------------------------------------

function TestBypassShortcuts:test_a_script_call_is_not_filtered()
  veafShortcuts.executeCommand(POSITION, "-jtac, name LUV HMMWV Jeep, country FRANCE", coalition.side.BLUE, nil, true)
  self:assertReached("_spawn jtac, , name LUV HMMWV Jeep, country FRANCE")
end

function TestBypassShortcuts:test_a_mission_with_security_disabled_is_not_filtered()
  veaf.SecurityDisabled = true
  marker("-jtac, country FRANCE")
  self:assertReached("_spawn jtac, , country FRANCE")
end

function TestBypassShortcuts:test_a_shortcut_that_does_not_bypass_security_is_not_filtered()
  marker("-samLR, side blue")
  luaunit.assertEquals(#self.reached, 1)
  luaunit.assertFalse(self.reached[1].bypass)
end

-- -----------------------------------------------------------------------
-- A mission's own bypassing shortcut declares its own list
-- -----------------------------------------------------------------------

function TestBypassShortcuts:test_a_custom_shortcut_declares_its_options()
  veafShortcuts.AddAlias(
    VeafAlias:new()
      :setName("-mysmoke")
      :setVeafCommand("_spawn smoke")
      :setBypassSecurity(true)
      :setAllowedOptions({ color = "color", shells = "^[1-3]$" })
  )
  marker("-mysmoke, color blue, shells 3")
  luaunit.assertEquals(#self.reached, 1)
  self.reached = {}
  marker("-mysmoke, shells 4")
  luaunit.assertEquals(#self.reached, 0)
end

function TestBypassShortcuts:test_getAllowedOptions_returns_the_declared_list()
  local alias = VeafAlias:new():setAllowedOptions({ color = "color" })
  luaunit.assertEquals(alias:getAllowedOptions(), { color = "color" })
  luaunit.assertNil(VeafAlias:new():getAllowedOptions())
end

os.exit(luaunit.LuaUnit.run())
