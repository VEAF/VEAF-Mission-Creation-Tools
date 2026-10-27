--- The F10 menu in multiplayer: commands bound to a pilot still in his unit, menus reserved to some
--- groups, menus split per pilot (FEAT-BFR-V6-SUPPORT tickets 03 to 05, from BFR's `veafPatches.lua`).
---
--- Run:  lua test/lua/test_veafRadio_pilots.lua

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
dofile(src .. "/veafEventHandler.lua")
dofile(src .. "/veafSecurity.lua")
dofile(src .. "/veafRadio.lua")

local API = {
  "addSubMenu",
  "addSubMenuForCoalition",
  "addSubMenuForGroup",
  "addCommand",
  "addCommandForCoalition",
  "addCommandForGroup",
  "removeItem",
  "removeItemForCoalition",
  "removeItemForGroup",
}

local function noop() end

TestRadioPilots = {}

function TestRadioPilots:setUp()
  dcs_mocks.reset()
  self._orig = { humanGroups = veafRadio.humanGroups, humanUnits = veafRadio.humanUnits }
  self.calls = {}
  local this = self
  for _, name in ipairs(API) do
    self._orig[name] = missionCommands[name]
    missionCommands[name] = function(...)
      local args = { ... }
      table.insert(this.calls, { kind = name, args = args })
      return { kind = name, title = name:find("For") and args[2] or args[1] }
    end
  end
  veafRadio.humanGroups = {}
  veafRadio.humanUnits = {}
  self.savedRefresh = veafRadio.refreshRadioMenu
  veafRadio.refreshRadioMenu = noop
  self.root = { title = "Root", subMenus = {}, commands = {} }
  self.builder = veafRadio.RadioMenuBuilder:new(self.root)
end

function TestRadioPilots:tearDown()
  for name, value in pairs(self._orig) do
    if name == "humanGroups" or name == "humanUnits" then
      veafRadio[name] = value
    else
      missionCommands[name] = value
    end
  end
  veafRadio.refreshRadioMenu = self.savedRefresh
end

--- A pilot takes a slot, the way DCS tells it.
local function birth(unitName, groupId, playerName)
  dcs_mocks.addUnit(unitName)
  veafRadio.onBirthEvent({
    type = { id = world.event.S_EVENT_PLAYER_ENTER_UNIT, name = "S_EVENT_PLAYER_ENTER_UNIT" },
    initiator = { unitName = unitName, unitGroupId = groupId, unitPilotName = playerName },
  })
end

local function leave(unitName)
  veafRadio.onLeaveEvent({
    type = { id = world.event.S_EVENT_PLAYER_LEAVE_UNIT, name = "S_EVENT_PLAYER_LEAVE_UNIT" },
    initiator = { unitName = unitName },
  })
end

function TestRadioPilots:_callsOfKind(kind)
  local found = {}
  for _, call in ipairs(self.calls) do
    if call.kind == kind then
      table.insert(found, call)
    end
  end
  return found
end

--- The labels of the entries rendered for a group, menus and commands, in order.
function TestRadioPilots:_groupLabels(groupId)
  local labels = {}
  for _, call in ipairs(self.calls) do
    if (call.kind == "addSubMenuForGroup" or call.kind == "addCommandForGroup") and call.args[1] == groupId then
      table.insert(labels, call.args[2])
    end
  end
  return labels
end

-- -----------------------------------------------------------------------
-- 03 — a group's commands are bound to a pilot still in his unit
-- -----------------------------------------------------------------------

function TestRadioPilots:test_a_group_command_binds_to_the_first_pilot()
  birth("unit A", 1, "Alpha")
  birth("unit B", 1, "Bravo")
  self.builder:addCommand("Info", nil, noop, nil, veafRadio.USAGE_ForGroup)
  self.builder:rebuild()
  local commands = self:_callsOfKind("addCommandForGroup")
  luaunit.assertEquals(#commands, 1)
  luaunit.assertEquals(commands[1].args[5], "unit A")
end

function TestRadioPilots:test_when_the_first_pilot_leaves_his_wingman_gets_the_command()
  birth("unit A", 1, "Alpha")
  birth("unit B", 1, "Bravo")
  self.builder:addCommand("Info", nil, noop, nil, veafRadio.USAGE_ForGroup)
  self.builder:rebuild()
  dcs_mocks.removeUnit("unit A")
  leave("unit A")
  self.calls = {}
  self.builder:rebuild()
  -- the command for group 1, not the inert one parking the id its removal freed
  local commands = {}
  for _, call in ipairs(self:_callsOfKind("addCommandForGroup")) do
    if call.args[1] == 1 then
      table.insert(commands, call)
    end
  end
  luaunit.assertEquals(#commands, 1)
  luaunit.assertEquals(commands[1].args[5], "unit B")
end

function TestRadioPilots:test_a_unit_gone_without_an_event_is_not_bound_either()
  birth("unit A", 1, "Alpha")
  birth("unit B", 1, "Bravo")
  self.builder:addCommand("Info", nil, noop, nil, veafRadio.USAGE_ForGroup)
  dcs_mocks.removeUnit("unit A")
  self.builder:rebuild()
  luaunit.assertEquals(self:_callsOfKind("addCommandForGroup")[1].args[5], "unit B")
end

function TestRadioPilots:test_the_last_pilot_leaving_removes_the_group_and_its_commands()
  birth("unit A", 1, "Alpha")
  self.builder:addCommand("Info", nil, noop, nil, veafRadio.USAGE_ForGroup)
  self.builder:rebuild()
  leave("unit A")
  luaunit.assertNil(veafRadio.humanGroups[1])
  luaunit.assertNil(veafRadio.humanUnits["unit A"])
  self.calls = {}
  self.builder:rebuild()
  luaunit.assertEquals(#self:_callsOfKind("removeItemForGroup"), 1)
end

function TestRadioPilots:test_a_returning_pilot_is_registered_again()
  birth("unit A", 1, "Alpha")
  leave("unit A")
  birth("unit A", 1, "Alpha")
  luaunit.assertNotNil(veafRadio.humanUnits["unit A"])
  luaunit.assertEquals(veafRadio.humanGroups[1].callsigns, { "Alpha" })
end

function TestRadioPilots:test_the_late_crash_of_an_abandoned_aircraft_spares_the_pilot_back_in_the_slot()
  birth("unit A", 1, "Alpha")
  Unit.getByName("unit A").id_ = 2 -- the aircraft he took again
  veafRadio.onLeaveEvent({
    type = { id = world.event.S_EVENT_CRASH, name = "S_EVENT_CRASH" },
    initiator = { unitName = "unit A" },
    dcsInitiator = { id_ = 1 }, -- the one he ejected from
  })
  luaunit.assertNotNil(veafRadio.humanUnits["unit A"])
end

function TestRadioPilots:test_the_death_of_the_aircraft_in_the_slot_forgets_its_pilot()
  birth("unit A", 1, "Alpha")
  Unit.getByName("unit A").id_ = 2
  veafRadio.onLeaveEvent({
    type = { id = world.event.S_EVENT_DEAD, name = "S_EVENT_DEAD" },
    initiator = { unitName = "unit A" },
    dcsInitiator = { id_ = 2 },
  })
  luaunit.assertNil(veafRadio.humanUnits["unit A"])
end

function TestRadioPilots:test_leaving_an_unknown_unit_does_nothing()
  local refreshed = false
  veafRadio.refreshRadioMenu = function()
    refreshed = true
  end
  leave("AI unit")
  luaunit.assertFalse(refreshed)
end

function TestRadioPilots:test_a_pilot_without_a_callsign_is_registered_under_his_unit()
  dcs_mocks.addUnit("unit C")
  veafRadio.onBirthEvent({
    type = { id = world.event.S_EVENT_PLAYER_ENTER_UNIT },
    initiator = { unitName = "unit C", unitGroupId = 3 },
  })
  luaunit.assertEquals(veafRadio.humanGroups[3].callsigns, { "unit C" })
end

function TestRadioPilots:test_each_unit_is_looked_up_once_per_rebuild()
  birth("unit A", 1, "Alpha")
  birth("unit B", 1, "Bravo")
  for i = 1, 10 do
    self.builder:addCommand("Info " .. i, nil, noop, nil, veafRadio.USAGE_ForGroup)
  end
  local lookups = 0
  local getByName = Unit.getByName
  Unit.getByName = function(name)
    lookups = lookups + 1
    return getByName(name)
  end
  self.builder:rebuild()
  Unit.getByName = getByName
  luaunit.assertEquals(lookups, 2)
end

-- `veaf.outTextForGroup` used to fall back on every player when the unit did not resolve.
function TestRadioPilots:test_a_message_for_a_unit_that_is_gone_reaches_nobody()
  veaf.outTextForGroup("unit gone", "Carrier info", 10)
  veaf.outTextForUnit("unit gone", "Carrier info", 10)
  luaunit.assertEquals(#dcs_mocks.messages, 0)
end

-- -----------------------------------------------------------------------
-- 04 — a submenu reserved to some groups
-- -----------------------------------------------------------------------

local function carrierPilotsOnly(unitName)
  return unitName == "hornet"
end

function TestRadioPilots:test_a_reserved_submenu_is_shown_to_the_groups_it_admits_only()
  birth("hornet", 1, "Alpha")
  birth("viper", 2, "Bravo")
  local carrier = veafRadio.addSubMenuForGroups("Carrier", self.root, carrierPilotsOnly)
  self.builder:addCommand("Status", carrier, noop, "CVN-74")
  self.builder:rebuild()
  luaunit.assertEquals(self:_groupLabels(1), { "CARRIER", "Status" })
  luaunit.assertEquals(self:_groupLabels(2), {})
  luaunit.assertEquals(#self:_callsOfKind("addSubMenu"), 1) -- the root only
  luaunit.assertEquals(#self:_callsOfKind("addCommand"), 0)
end

function TestRadioPilots:test_a_forall_command_under_it_keeps_its_parameters()
  birth("hornet", 1, "Alpha")
  local carrier = veafRadio.addSubMenuForGroups("Carrier", self.root, carrierPilotsOnly)
  self.builder:addCommand("Status", carrier, noop, "CVN-74")
  self.builder:rebuild()
  luaunit.assertEquals(self:_callsOfKind("addCommandForGroup")[1].args[5], "CVN-74")
end

function TestRadioPilots:test_nested_menus_follow_the_group()
  birth("hornet", 1, "Alpha")
  local carrier = veafRadio.addSubMenuForGroups("Carrier", self.root, carrierPilotsOnly)
  local deck = veafRadio.addSubMenu("Deck", carrier)
  self.builder:addCommand("Lights", deck, noop)
  self.builder:rebuild()
  luaunit.assertEquals(self:_groupLabels(1), { "CARRIER", "Deck", "Lights" })
end

function TestRadioPilots:test_a_throwing_filter_hides_the_menu_and_spares_the_rebuild()
  birth("hornet", 1, "Alpha")
  veafRadio.addSubMenuForGroups("Carrier", self.root, function()
    error("boom")
  end)
  self.builder:rebuild()
  luaunit.assertEquals(self:_groupLabels(1), {})
end

function TestRadioPilots:test_a_reserved_menu_respects_its_coalition()
  birth("hornet", 1, "Alpha")
  veafRadio.humanGroups[1].coalition = coalition.side.BLUE
  veafRadio.addSubMenuForGroups("Carrier", self.root, carrierPilotsOnly, coalition.side.RED)
  self.builder:rebuild()
  luaunit.assertEquals(self:_groupLabels(1), {})
end

-- -----------------------------------------------------------------------
-- 05 — a submenu split per pilot
-- -----------------------------------------------------------------------

function TestRadioPilots:test_each_pilot_of_a_group_gets_his_own_submenu()
  birth("unit A", 1, "Alpha")
  birth("unit B", 1, "Bravo")
  local perPilot = veafRadio.addSubMenuPerPilot("Landing", self.root)
  self.builder:addCommand("Request", perPilot, noop, "grade", veafRadio.USAGE_ForGroup)
  self.builder:rebuild()
  luaunit.assertEquals(self:_groupLabels(1), { "LANDING", "Alpha", "Request", "Bravo", "Request" })
  local commands = self:_callsOfKind("addCommandForGroup")
  luaunit.assertEquals(commands[1].args[5], { "grade", "unit A" })
  luaunit.assertEquals(commands[2].args[5], { "grade", "unit B" })
end

function TestRadioPilots:test_a_pilot_alone_gets_the_entries_directly()
  birth("unit A", 1, "Alpha")
  local perPilot = veafRadio.addSubMenuPerPilot("Landing", self.root)
  self.builder:addCommand("Request", perPilot, noop, nil, veafRadio.USAGE_ForUnit)
  self.builder:rebuild()
  luaunit.assertEquals(self:_groupLabels(1), { "LANDING", "Request" })
  luaunit.assertEquals(self:_callsOfKind("addCommandForGroup")[1].args[5], "unit A")
end

function TestRadioPilots:test_a_pilot_leaving_takes_his_submenu_with_him()
  birth("unit A", 1, "Alpha")
  birth("unit B", 1, "Bravo")
  local perPilot = veafRadio.addSubMenuPerPilot("Landing", self.root)
  self.builder:addCommand("Request", perPilot, noop, nil, veafRadio.USAGE_ForGroup)
  birth("unit C", 1, "Charlie")
  self.builder:rebuild()
  leave("unit C")
  self.calls = {}
  self.builder:rebuild()
  -- Charlie's submenu and command go; Alpha's and Bravo's stay where they are.
  luaunit.assertEquals(#self:_callsOfKind("removeItemForGroup"), 2)
  luaunit.assertEquals(#self:_callsOfKind("addSubMenuForGroup"), 0)
end

os.exit(luaunit.LuaUnit.run())
