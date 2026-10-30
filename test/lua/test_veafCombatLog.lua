--- Tests for veafCombatLog.lua — every shot, hit and kill of a mission written as JSON lines (FEAT-COMBAT-LOG).
--- The Tacview of 2026-10-29 named no shooter and showed none of the AH-64s' gun: the debrief had to guess.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafCombatLog.lua")

--- A DCS unit as the events hand it over: methods only.
local function _unit(name, typeName, player, shells)
  return {
    getName = function()
      return name
    end,
    getTypeName = function()
      return typeName
    end,
    getCoalition = function()
      return coalition.side.BLUE
    end,
    getPlayerName = function()
      return player
    end,
    getGroup = function()
      return {
        getName = function()
          return name .. " group"
        end,
      }
    end,
    getAmmo = function(self)
      return { { count = self.shells, desc = { category = Weapon.Category.SHELL } } }
    end,
    shells = shells,
  }
end

local function _weapon(typeName, target)
  return {
    getTypeName = function()
      return typeName
    end,
    getTarget = function()
      return target
    end,
  }
end

--- The lines written to the test file, parsed.
local function _lines()
  local lines = {}
  local file = io.open(veafCombatLog.path, "r")
  for text in file:lines() do
    table.insert(lines, (veaf.json.parse(text)))
  end
  file:close()
  return lines
end

TestVeafCombatLog = {}

function TestVeafCombatLog:setUp()
  veafCombatLog.close()
  veafCombatLog.burstShells = {}
  dcs_mocks.eventHandlers = {}
  veafCombatLog.Directory = (os.getenv("TEMP") or os.getenv("TMPDIR") or ".") .. "/"
  veafCombatLog.initialize()
end

function TestVeafCombatLog:tearDown()
  veafCombatLog.close()
  os.remove(veafCombatLog.path)
end

function TestVeafCombatLog:test_initialize_opens_a_file_starts_it_and_listens()
  luaunit.assertNotNil(veafCombatLog.file)
  luaunit.assertStrContains(veafCombatLog.path, "veaf-combat-log-")
  luaunit.assertEquals(#dcs_mocks.eventHandlers, 1)
  veafCombatLog.close()
  luaunit.assertEquals(_lines()[1].event, "start")
end

function TestVeafCombatLog:test_a_missile_shot_names_its_shooter_player_weapon_and_target()
  local mig = _unit("MiG-23 #1", "MiG-23MLD")
  local hornet = _unit("Martinho", "FA-18C_hornet", "Martinho")
  dcs_mocks.eventHandlers[1]:onEvent({
    id = world.event.S_EVENT_SHOT,
    time = 120,
    initiator = hornet,
    weapon = _weapon("AIM_120C", mig),
  })
  veafCombatLog.close()
  local line = _lines()[2]
  luaunit.assertEquals(line.event, "shot")
  luaunit.assertEquals(line.t, 120)
  luaunit.assertEquals(line.shooter.player, "Martinho")
  luaunit.assertEquals(line.shooter.group, "Martinho group")
  luaunit.assertEquals(line.weapon, "AIM_120C")
  luaunit.assertEquals(line.target.type, "MiG-23MLD")
  luaunit.assertTrue(line.weapon_object)
end

function TestVeafCombatLog:test_a_hit_without_a_weapon_object_keeps_the_weapon_name()
  -- a gun's shell: DCS may hand over weapon_name and no Weapon object (to be measured in game, R54)
  dcs_mocks.eventHandlers[1]:onEvent({
    id = world.event.S_EVENT_HIT,
    time = 200,
    initiator = _unit("Paluche", "AH-64D_BLK_II", "Paluche"),
    target = _unit("BMP-2 #3", "BMP-2"),
    weapon_name = "M230",
  })
  veafCombatLog.close()
  local line = _lines()[2]
  luaunit.assertEquals(line.event, "hit")
  luaunit.assertEquals(line.weapon, "M230")
  luaunit.assertFalse(line.weapon_object)
  luaunit.assertEquals(line.target.name, "BMP-2 #3")
end

function TestVeafCombatLog:test_a_gun_burst_counts_its_rounds()
  local apache = _unit("Paluche", "AH-64D_BLK_II", "Paluche", 1200)
  dcs_mocks.eventHandlers[1]:onEvent({ id = world.event.S_EVENT_SHOOTING_START, time = 300, initiator = apache })
  apache.shells = 1110
  dcs_mocks.eventHandlers[1]:onEvent({ id = world.event.S_EVENT_SHOOTING_END, time = 303, initiator = apache })
  veafCombatLog.close()
  local lines = _lines()
  luaunit.assertEquals(lines[2].event, "shooting_start")
  luaunit.assertEquals(lines[3].event, "shooting_end")
  luaunit.assertEquals(lines[3].rounds, 90)
end

function TestVeafCombatLog:test_a_kill_and_an_unknown_event()
  dcs_mocks.eventHandlers[1]:onEvent({
    id = world.event.S_EVENT_KILL,
    time = 400,
    initiator = _unit("MAV", "FA-18C_hornet", "MAV"),
    target = _unit("Tor #1", "Tor 9A331"),
    weapon = _weapon("AGM_88C"),
  })
  dcs_mocks.eventHandlers[1]:onEvent({ id = world.event.S_EVENT_BIRTH, time = 401 })
  veafCombatLog.close()
  local lines = _lines()
  luaunit.assertEquals(#lines, 2) -- the birth is not written
  luaunit.assertEquals(lines[2].event, "kill")
  luaunit.assertEquals(lines[2].target.type, "Tor 9A331")
end

function TestVeafCombatLog:test_a_dead_initiator_does_not_break_the_log()
  -- a unit gone between the event and its reading raises on every question
  local gone = setmetatable({}, {
    __index = function()
      return function()
        error("Unit doesn't exist")
      end
    end,
  })
  dcs_mocks.eventHandlers[1]:onEvent({ id = world.event.S_EVENT_HIT, time = 500, initiator = gone, target = gone })
  veafCombatLog.close()
  local line = _lines()[2]
  luaunit.assertEquals(line.event, "hit")
  luaunit.assertNil(line.shooter.name)
end

function TestVeafCombatLog:test_without_io_nothing_is_written_and_nothing_raises()
  veafCombatLog.close()
  os.remove(veafCombatLog.path)
  dcs_mocks.eventHandlers = {}
  local savedIo = io
  io = nil -- luacheck: ignore 121
  veafCombatLog.initialize()
  io = savedIo -- luacheck: ignore 121
  luaunit.assertNil(veafCombatLog.file)
  luaunit.assertEquals(#dcs_mocks.eventHandlers, 0)
  veafCombatLog.path = os.tmpname() -- tearDown removes it
end

local runner = luaunit.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
