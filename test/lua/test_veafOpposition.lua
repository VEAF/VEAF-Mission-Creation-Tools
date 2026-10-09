--- Tests for veafOpposition.lua — the opposition level (FEAT-OPPOSITION-SCALES-WITH-PLAYERS ticket 02):
--- counted from the players connected or airborne, followed with a hysteresis, changed by command.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafI18n.lua")
dofile(src .. "/veafCommands.lua")
dofile(src .. "/veafOpposition.lua")

veaf.config.language = "en"

--- `count` blue players, the first `airborne` of them in the air.
local function _players(count, airborne)
  local units = {}
  for i = 1, count do
    table.insert(units, {
      isExist = function()
        return true
      end,
      inAir = function()
        return i <= (airborne or 0)
      end,
    })
  end
  coalition.getPlayers = function(side)
    return side == coalition.side.BLUE and units or {}
  end
end

--- What `getAmmo` returns for a load: a list of missile types, from the four below.
local MISSILES = {
  AIM120 = { guidance = Weapon.GuidanceType.RADAR_ACTIVE },
  AIM7 = { guidance = Weapon.GuidanceType.RADAR_SEMI_ACTIVE },
  AIM9 = { guidance = Weapon.GuidanceType.IR },
  MAVERICK = { guidance = Weapon.GuidanceType.TV, missileCategory = Weapon.MissileCategory.OTHER },
}

local function _ammo(load)
  local ammo = {}
  for _, name in ipairs(load) do
    local missile = MISSILES[name]
    table.insert(ammo, {
      count = 2,
      desc = {
        typeName = name,
        category = Weapon.Category.MISSILE,
        missileCategory = missile.missileCategory or Weapon.MissileCategory.AAM,
        guidance = missile.guidance,
      },
    })
  end
  return ammo
end

--- Blue players described one by one: `{ air = bool, load = { "AIM120", ... } }`.
local function _flights(flights)
  local units = {}
  for _, flight in ipairs(flights) do
    local unit = {
      load = flight.load or {},
      isExist = function()
        return true
      end,
      inAir = function()
        return flight.air
      end,
    }
    function unit:getAmmo()
      return _ammo(self.load)
    end
    table.insert(units, unit)
  end
  coalition.getPlayers = function(side)
    return side == coalition.side.BLUE and units or {}
  end
  return units
end

TestVeafOpposition = {}

function TestVeafOpposition:setUp()
  dcs_mocks.reset()
  self.savedGetPlayers = coalition.getPlayers
  veafOpposition.configure({})
  veafOpposition.scheduled = false
end

function TestVeafOpposition:tearDown()
  coalition.getPlayers = self.savedGetPlayers
end

function TestVeafOpposition:test_no_block_no_level()
  veafOpposition.enabled = false
  veafOpposition.level = nil
  luaunit.assertFalse(veafOpposition.isEnabled())
  luaunit.assertNil(veafOpposition.getLevel())
end

function TestVeafOpposition:test_the_level_set_at_generation()
  veafOpposition.configure({ level = 6 })
  luaunit.assertTrue(veafOpposition.isEnabled())
  luaunit.assertEquals(veafOpposition.getLevel(), 6)
end

function TestVeafOpposition:test_counts_the_players_connected()
  _players(5, 2)
  veafOpposition.follow = veafOpposition.FOLLOW_PLAYERS
  luaunit.assertEquals(veafOpposition.measure(), 5)
end

function TestVeafOpposition:test_counts_the_players_airborne()
  _players(5, 2)
  veafOpposition.follow = veafOpposition.FOLLOW_AIRBORNE
  luaunit.assertEquals(veafOpposition.measure(), 2)
end

function TestVeafOpposition:test_counts_only_the_players_coalition()
  _players(5, 0)
  veafOpposition.configure({ playersCoalition = coalition.side.RED, follow = veafOpposition.FOLLOW_PLAYERS })
  luaunit.assertEquals(veafOpposition.measure(), 0)
end

function TestVeafOpposition:test_a_rise_is_taken_at_once()
  veafOpposition.configure({ level = 4 })
  luaunit.assertTrue(veafOpposition.follows(5, 100))
  luaunit.assertEquals(veafOpposition.getLevel(), 5)
end

function TestVeafOpposition:test_a_drop_waits_for_the_count_to_hold()
  veafOpposition.configure({ level = 6, lowerAfter = 300 })
  luaunit.assertFalse(veafOpposition.follows(5, 100))
  luaunit.assertFalse(veafOpposition.follows(5, 399))
  luaunit.assertEquals(veafOpposition.getLevel(), 6)
  luaunit.assertTrue(veafOpposition.follows(5, 400))
  luaunit.assertEquals(veafOpposition.getLevel(), 5)
end

function TestVeafOpposition:test_a_player_who_comes_back_cancels_the_drop()
  veafOpposition.configure({ level = 6, lowerAfter = 300 })
  veafOpposition.follows(5, 100)
  veafOpposition.follows(6, 200)
  luaunit.assertFalse(veafOpposition.follows(5, 450), "the clock restarted when the count came back")
  luaunit.assertEquals(veafOpposition.getLevel(), 6)
end

function TestVeafOpposition:test_a_change_is_said_to_everybody()
  veafOpposition.configure({ level = 4 })
  veafOpposition.follows(6, 0)
  luaunit.assertEquals(#dcs_mocks.messagesContaining("sized for 6 aircraft"), 1)
  luaunit.assertEquals(dcs_mocks.messages[1].fn, "outText")
end

function TestVeafOpposition:test_the_beat_follows_the_players()
  _players(3, 0)
  veafOpposition.configure({ level = 1, follow = veafOpposition.FOLLOW_PLAYERS })
  veafOpposition.check()
  luaunit.assertEquals(veafOpposition.getLevel(), 3)
  luaunit.assertTrue(veafOpposition.scheduled, "and comes back")
end

function TestVeafOpposition:test_a_fixed_level_does_not_beat()
  _players(3, 0)
  veafOpposition.configure({ level = 1 })
  veafOpposition.check()
  luaunit.assertEquals(veafOpposition.getLevel(), 1)
  luaunit.assertFalse(veafOpposition.scheduled)
end

function TestVeafOpposition:test_the_command_fixes_the_level_and_stops_following()
  _players(2, 0)
  veafOpposition.configure({ follow = veafOpposition.FOLLOW_PLAYERS })
  luaunit.assertTrue(veafOpposition.handleMarker(nil, { text = "_opposition 7" }))
  luaunit.assertEquals(veafOpposition.getLevel(), 7)
  luaunit.assertEquals(veafOpposition.follow, veafOpposition.FOLLOW_OFF)
end

function TestVeafOpposition:test_the_command_follows_and_counts_at_once()
  _players(4, 1)
  luaunit.assertTrue(veafOpposition.handleMarker(nil, { text = "_opposition airborne" }))
  luaunit.assertEquals(veafOpposition.follow, veafOpposition.FOLLOW_AIRBORNE)
  luaunit.assertEquals(veafOpposition.getLevel(), 1)
  luaunit.assertTrue(veafOpposition.scheduled)
end

function TestVeafOpposition:test_an_empty_server_at_start_keeps_the_generated_level()
  _players(0, 0)
  veafOpposition.configure({ level = 6, follow = veafOpposition.FOLLOW_PLAYERS })
  veafOpposition.buildRadioMenu, self.savedBuild = function() end, veafOpposition.buildRadioMenu
  local savedHandlers = veafCommands.commandHandlers
  veafOpposition.initialize()
  veafCommands.commandHandlers = savedHandlers
  veafOpposition.buildRadioMenu = self.savedBuild
  luaunit.assertEquals(veafOpposition.getLevel(), 6)
end

function TestVeafOpposition:test_the_command_alone_says_the_level()
  veafOpposition.configure({ level = 3 })
  veafOpposition.handleMarker(nil, { text = "_opposition" })
  luaunit.assertEquals(#dcs_mocks.messagesContaining("sized for 3 aircraft"), 1)
end

function TestVeafOpposition:test_an_unknown_argument_gives_the_usage()
  veafOpposition.configure({ level = 3 })
  luaunit.assertTrue(veafOpposition.handleMarker(nil, { text = "_opposition lots" }))
  luaunit.assertEquals(veafOpposition.getLevel(), 3)
  luaunit.assertEquals(#dcs_mocks.messagesContaining("_opposition <number>"), 1)
end

function TestVeafOpposition:test_other_markers_are_not_its_business()
  luaunit.assertFalse(veafOpposition.handleMarker(nil, { text = "RDV ici" }))
end

function TestVeafOpposition:test_only_the_players_armed_for_air_to_air_count()
  _flights({
    { air = true, load = { "AIM120", "AIM9" } }, -- a fighter on CAP
    { air = true, load = { "AIM7" } }, -- a Fox 1 counts too
    { air = true, load = { "AIM9", "MAVERICK" } }, -- a bomb truck with its self-defence missiles
    { air = true, load = {} }, -- a helicopter
    { air = false, load = { "AIM120" } }, -- on the ground
  })
  veafOpposition.follow = veafOpposition.FOLLOW_AIR_TO_AIR
  luaunit.assertEquals(veafOpposition.measure(), 2)
end

function TestVeafOpposition:test_the_count_follows_what_the_pilot_carries_now()
  local units = _flights({ { air = true, load = { "MAVERICK" } } })
  veafOpposition.follow = veafOpposition.FOLLOW_AIR_TO_AIR
  luaunit.assertEquals(veafOpposition.measure(), 0)
  units[1].load = { "AIM120" } -- rearmed for CAP
  luaunit.assertEquals(veafOpposition.measure(), 1)
end

function TestVeafOpposition:test_a_unit_that_cannot_say_its_ammo_does_not_count()
  local units = _flights({ { air = true } })
  units[1].getAmmo = function()
    error("gone")
  end
  luaunit.assertFalse(veafOpposition.armedForAirToAir(units[1]))
end

function TestVeafOpposition:test_the_command_follows_the_cap()
  _flights({ { air = true, load = { "AIM120" } }, { air = true, load = { "AIM9" } } })
  luaunit.assertTrue(veafOpposition.handleMarker(nil, { text = "_opposition air_to_air" }))
  luaunit.assertEquals(veafOpposition.follow, veafOpposition.FOLLOW_AIR_TO_AIR)
  luaunit.assertEquals(veafOpposition.getLevel(), 1)
end

function TestVeafOpposition:test_a_level_from_the_menu_is_fixed_in_one_click()
  _flights({})
  veafOpposition.configure({ level = 6, follow = veafOpposition.FOLLOW_PLAYERS })
  veafOpposition.radioSetLevel(2)
  luaunit.assertEquals(veafOpposition.getLevel(), 2)
  luaunit.assertEquals(veafOpposition.follow, veafOpposition.FOLLOW_OFF)
end

function TestVeafOpposition:test_the_menu_offers_one_entry_per_level_and_every_mode()
  local commands, menus = {}, {}
  local savedRadio = veafRadio
  veafRadio = {
    USAGE_ForAll = 0,
    addMenu = function(title)
      return { title = title }
    end,
    addSubMenu = function(title)
      local menu = { title = title }
      table.insert(menus, menu)
      return menu
    end,
    addCommandToSubmenu = function() end,
    addSecuredCommandToSubmenu = function(title, path, method, parameters)
      table.insert(commands, { title = title, path = path.title, method = method, parameters = parameters })
    end,
    refreshRadioMenu = function() end,
  }
  veafOpposition.buildRadioMenu()
  veafRadio = savedRadio
  local levels, modes = {}, {}
  for _, command in ipairs(commands) do
    if command.method == veafOpposition.radioSetLevel then
      table.insert(levels, command.parameters)
    elseif command.method == veafOpposition.radioFollow then
      table.insert(modes, command.parameters)
    end
  end
  luaunit.assertEquals(levels, { 1, 2, 3, 4, 5, 6, 7, 8 })
  luaunit.assertEquals(modes, veafOpposition.FOLLOW_MODES)
  luaunit.assertEquals(#modes, 4)
end

function TestVeafOpposition:test_the_command_is_for_senior_pilots()
  local savedHandlers = veafCommands.commandHandlers
  local savedBuild = veafOpposition.buildRadioMenu
  veafCommands.commandHandlers = {}
  veafOpposition.buildRadioMenu = function() end
  veafOpposition.initialize()
  local entry = veafCommands.commandHandlers[1]
  veafCommands.commandHandlers = savedHandlers
  veafOpposition.buildRadioMenu = savedBuild
  luaunit.assertEquals(entry.security, "SENIOR_PILOT")
  luaunit.assertEquals(entry.keyphrase, "_opposition")
end

os.exit(luaunit.LuaUnit.run())
