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

function TestVeafOpposition:test_the_level_never_goes_below_zero()
  veafOpposition.configure({ level = 0 })
  veafOpposition.radioChangeLevel(-1)
  luaunit.assertEquals(veafOpposition.getLevel(), 0)
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
