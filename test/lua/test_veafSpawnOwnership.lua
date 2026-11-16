--- What each pilot spawned from his markers, and the F10 menu to remove it (FEAT-SPAWN-OWNERSHIP-DESPAWN).
---
--- Run:  lua test/lua/test_veafSpawnOwnership.lua

local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/dcsUnits.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
dofile(src .. "/veafDcsSpawner.lua")
dofile(src .. "/veafI18n.lua")
dofile(src .. "/veafEventHandler.lua")
dofile(src .. "/veafMarkers.lua")
dofile(src .. "/veafCommands.lua")
dofile(src .. "/veafSecurity.lua")
dofile(src .. "/veafRadio.lua")
dofile(src .. "/veafGrass.lua")
dofile(src .. "/veafSpawn.lua")

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

--- A marker event as veafCommands receives it.
local function markerEvent(text, idx, author)
  return { text = text, idx = idx, author = author, coalition = coalition.side.BLUE }
end

--- A spawned group that DCS still knows, recording its destruction.
local function liveGroup(name, destroyed)
  dcs_mocks.addGroup(name, {
    destroy = function()
      table.insert(destroyed, name)
      dcs_mocks.removeGroup(name)
    end,
  })
end

TestSpawnOwnership = {}

function TestSpawnOwnership:setUp()
  dcs_mocks.reset()
  dcs_mocks.clearUnitsAndGroups()
  veafSpawn.ownedSpawns = {}
  veafSpawn.ownedSpawnsCounter = 0
  self.destroyed = {}
  self.saved = {
    getMarkPanels = world.getMarkPanels,
    staticGetByName = StaticObject.getByName,
    getStaticObjects = coalition.getStaticObjects,
    refreshRadioMenu = veafRadio.refreshRadioMenu,
    builder = veafRadio._builder,
    humanGroups = veafRadio.humanGroups,
    humanUnits = veafRadio.humanUnits,
    rootPath = veafSpawn.rootPath,
    ownershipMenu = veafSpawn.ownershipMenu,
    listener = veafCommands.markerSpawnListener,
    casMission = veafCasMission,
  }
  self.panels = {}
  local this = self
  world.getMarkPanels = function()
    return this.panels
  end
  self.statics = {}
  StaticObject.getByName = function(name)
    return this.statics[name]
  end
  coalition.getStaticObjects = function(side)
    local found = {}
    for _, static in pairs(this.statics) do
      if static._side == side then
        table.insert(found, static)
      end
    end
    return found
  end
  self.calls = {}
  self.missionCommands = {}
  for _, name in ipairs(API) do
    self.missionCommands[name] = missionCommands[name]
    missionCommands[name] = function(...)
      local args = { ... }
      table.insert(this.calls, { kind = name, args = args })
      return { kind = name, title = name:find("For") and args[2] or args[1] }
    end
  end
  self.refreshes = 0
  veafRadio.refreshRadioMenu = function()
    this.refreshes = this.refreshes + 1
  end
  veafRadio.humanGroups = {}
  veafRadio.humanUnits = {}
  self.root = { title = "Root", subMenus = {}, commands = {} }
  veafRadio._builder = veafRadio.RadioMenuBuilder:new(self.root)
  veafSpawn.rootPath = veafRadio._builder:addMenu("SPAWN")
  veafSpawn.ownershipMenu = nil
  veafSpawn.initializeOwnership()
  veafCasMission = nil
end

function TestSpawnOwnership:tearDown()
  world.getMarkPanels = self.saved.getMarkPanels
  StaticObject.getByName = self.saved.staticGetByName
  coalition.getStaticObjects = self.saved.getStaticObjects
  veafRadio.refreshRadioMenu = self.saved.refreshRadioMenu
  veafRadio._builder = self.saved.builder
  veafRadio.humanGroups = self.saved.humanGroups
  veafRadio.humanUnits = self.saved.humanUnits
  veafSpawn.rootPath = self.saved.rootPath
  veafSpawn.ownershipMenu = self.saved.ownershipMenu
  veafCommands.markerSpawnListener = self.saved.listener
  veafCasMission = self.saved.casMission
  for name, fn in pairs(self.missionCommands) do
    missionCommands[name] = fn
  end
end

--- A player takes a slot: `units` is `{ { unitName, playerName }, ... }`, all in group `groupName`.
function TestSpawnOwnership:seat(groupName, groupId, units)
  local unitObjects = {}
  local group
  for _, seat in ipairs(units) do
    local playerName = seat[2]
    dcs_mocks.addUnit(seat[1], {
      getPlayerName = function()
        return playerName
      end,
      getGroup = function()
        return group
      end,
    })
    table.insert(unitObjects, Unit.getByName(seat[1]))
  end
  dcs_mocks.addGroup(groupName, {
    _id = groupId,
    getUnits = function()
      return unitObjects
    end,
  })
  group = Group.getByName(groupName)
  for _, seat in ipairs(units) do
    veafRadio.onBirthEvent({
      type = { id = world.event.S_EVENT_PLAYER_ENTER_UNIT, name = "S_EVENT_PLAYER_ENTER_UNIT" },
      initiator = { unitName = seat[1], unitGroupId = groupId, unitPilotName = seat[2] },
    })
  end
end

--- A pilot's marker spawned these groups.
function TestSpawnOwnership:spawnFromMarker(author, text, groupNames)
  local groups = {}
  veafSpawn.recordMarkerSpawns(groups, markerEvent(text, 1, author))
  for _, name in ipairs(groupNames) do
    liveGroup(name, self.destroyed)
    veaf.collectSpawnedGroup(groups, name)
  end
  return groups
end

--- The labels rendered for a group id, in the order they were created.
function TestSpawnOwnership:labelsFor(groupId)
  local labels = {}
  for _, call in ipairs(self.calls) do
    if (call.kind == "addCommandForGroup" or call.kind == "addSubMenuForGroup") and call.args[1] == groupId then
      table.insert(labels, call.args[2])
    end
  end
  return labels
end

function TestSpawnOwnership:rebuild()
  self.calls = {}
  veafRadio._builder:rebuild()
end

local function contains(list, value)
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Ticket 01: recording
-- ---------------------------------------------------------------------------

function TestSpawnOwnership:test_initialization_listens_to_markers()
  luaunit.assertIs(veafCommands.markerSpawnListener, veafSpawn.recordMarkerSpawns)
end

function TestSpawnOwnership:test_a_marker_spawn_is_recorded_under_the_marker_author()
  self.panels = { { idx = 1, author = "Zip" } }

  self:spawnFromMarker(nil, "-sa6", { "SA-6 #1" })

  local items = veafSpawn.ownedSpawns["Zip"]
  luaunit.assertEquals(#items, 1)
  luaunit.assertEquals(items[1].names, { "SA-6 #1" })
  luaunit.assertStrContains(items[1].label, "-sa6")
end

function TestSpawnOwnership:test_the_mark_panel_wins_over_the_event()
  self.panels = { { idx = 1, author = "Zip" } }

  self:spawnFromMarker("Someone else", "-sa6", { "SA-6 #1" })

  luaunit.assertNotNil(veafSpawn.ownedSpawns["Zip"])
  luaunit.assertNil(veafSpawn.ownedSpawns["Someone else"])
end

function TestSpawnOwnership:test_the_event_author_is_used_without_a_panel()
  self:spawnFromMarker("Zip", "-sa6", { "SA-6 #1" })

  luaunit.assertNotNil(veafSpawn.ownedSpawns["Zip"])
end

function TestSpawnOwnership:test_the_initiator_names_the_author_as_a_last_resort()
  local groups = {}
  local event = markerEvent("-sa6", 1, nil)
  event.initiator = {
    getPlayerName = function()
      return "Zip"
    end,
  }
  veafSpawn.recordMarkerSpawns(groups, event)
  liveGroup("SA-6 #1", self.destroyed)
  veaf.collectSpawnedGroup(groups, "SA-6 #1")

  luaunit.assertNotNil(veafSpawn.ownedSpawns["Zip"])
end

function TestSpawnOwnership:test_a_marker_without_an_author_is_nobody_s()
  self:spawnFromMarker(nil, "-sa6", { "SA-6 #1" })

  luaunit.assertEquals(veafSpawn.ownedSpawns, {})
end

function TestSpawnOwnership:test_a_marker_that_spawned_nothing_leaves_no_item()
  veafSpawn.recordMarkerSpawns({}, markerEvent("-tacan", 1, "Zip"))

  luaunit.assertNil(veafSpawn.ownedSpawns["Zip"])
end

--- An alias delay or a repeat spawns after the marker is gone: the late group joins the same item.
function TestSpawnOwnership:test_a_late_group_joins_its_marker_s_item()
  local groups = self:spawnFromMarker("Zip", "-convoy", { "Convoy #1" })
  liveGroup("Convoy #2", self.destroyed)
  veaf.collectSpawnedGroup(groups, "Convoy #2")

  local items = veafSpawn.ownedSpawns["Zip"]
  luaunit.assertEquals(#items, 1)
  luaunit.assertEquals(items[1].names, { "Convoy #1", "Convoy #2" })
end

function TestSpawnOwnership:test_two_markers_are_two_items()
  self:spawnFromMarker("Zip", "-sa6", { "SA-6 #1" })
  self:spawnFromMarker("Zip", "-armor", { "Armor #1" })

  local items = veafSpawn.ownedSpawns["Zip"]
  luaunit.assertEquals(#items, 2)
  luaunit.assertStrContains(items[2].label, "-armor")
end

function TestSpawnOwnership:test_the_label_keeps_the_first_line_shortened_and_the_mission_time()
  dcs_mocks.currentTime = 14 * 3600 + 32 * 60 + 10

  local label = veafSpawn.ownershipLabel("_spawn group, name a-very-long-group-name-indeed\nsecond line")

  luaunit.assertEquals(label, "_spawn group, name a-ve... 14:32")
  luaunit.assertEquals(veafSpawn.ownershipLabel("  -sa6  "), "-sa6 14:32")
end

function TestSpawnOwnership:test_a_destroyed_group_drops_out_and_its_empty_item_with_it()
  self:spawnFromMarker("Zip", "-convoy", { "Convoy #1", "Convoy #2" })
  self:spawnFromMarker("Zip", "-sa6", { "SA-6 #1" })
  dcs_mocks.removeGroup("Convoy #1")
  dcs_mocks.removeGroup("SA-6 #1")

  luaunit.assertTrue(veafSpawn.pruneOwnedSpawns())

  local items = veafSpawn.ownedSpawns["Zip"]
  luaunit.assertEquals(#items, 1)
  luaunit.assertEquals(items[1].names, { "Convoy #2" })
end

function TestSpawnOwnership:test_an_owner_with_nothing_left_is_forgotten()
  self:spawnFromMarker("Zip", "-sa6", { "SA-6 #1" })
  dcs_mocks.removeGroup("SA-6 #1")

  veafSpawn.pruneOwnedSpawns()

  luaunit.assertNil(veafSpawn.ownedSpawns["Zip"])
end

function TestSpawnOwnership:test_a_static_counts_as_alive()
  self.statics["FARP Zip"] = {
    _side = coalition.side.BLUE,
    isExist = function()
      return true
    end,
  }
  local groups = {}
  veafSpawn.recordMarkerSpawns(groups, markerEvent("-farp", 1, "Zip"))
  veaf.collectSpawnedGroup(groups, "FARP Zip")

  luaunit.assertFalse(veafSpawn.pruneOwnedSpawns())
  luaunit.assertEquals(#veafSpawn.ownedSpawns["Zip"], 1)
end

function TestSpawnOwnership:test_the_prune_is_scheduled_again()
  veafSpawn.pruneOwnedSpawnsLoop()

  local found = false
  for _, task in pairs(dcs_mocks.scheduledTasks) do
    if task.time == dcs_mocks.currentTime + veafSpawn.OWNERSHIP_PRUNE_DELAY then
      found = true
    end
  end
  luaunit.assertTrue(found, "the check runs again by itself")
end

-- ---------------------------------------------------------------------------
-- Ticket 02: the F10 menu
-- ---------------------------------------------------------------------------

function TestSpawnOwnership:test_the_owner_s_group_sees_his_items_and_no_other_group_does()
  self:seat("Viper", 11, { { "Viper-1", "Zip" } })
  self:seat("Hog", 12, { { "Hog-1", "Other" } })
  self:spawnFromMarker("Zip", "-sa6", { "SA-6 #1" })

  self:rebuild()

  local viper = self:labelsFor(11)
  luaunit.assertTrue(contains(viper, veaf.t("menu.spawn.mine")))
  luaunit.assertTrue(contains(viper, "Zip"))
  luaunit.assertTrue(contains(viper, veaf.t("menu.spawn.mine_remove_all")))
  luaunit.assertTrue(contains(viper, veafSpawn.ownedSpawns["Zip"][1].label))
  luaunit.assertEquals(self:labelsFor(12), {})
end

--- The F10 menu cannot tell which occupant clicked: each one's items show, under his name (Q4).
function TestSpawnOwnership:test_each_occupant_s_items_show_under_his_name()
  self:seat("Viper", 11, { { "Viper-1", "Zip" }, { "Viper-2", "Wingman" } })
  self:spawnFromMarker("Zip", "-sa6", { "SA-6 #1" })
  self:spawnFromMarker("Wingman", "-armor", { "Armor #1" })

  self:rebuild()

  local viper = self:labelsFor(11)
  luaunit.assertTrue(contains(viper, "Zip"))
  luaunit.assertTrue(contains(viper, "Wingman"))
end

--- Q2: the pilot, not his slot. He keeps his list in another aircraft.
function TestSpawnOwnership:test_the_items_follow_the_pilot_to_another_slot()
  self:spawnFromMarker("Zip", "-sa6", { "SA-6 #1" })
  self:seat("Hog", 12, { { "Hog-1", "Zip" } })

  self:rebuild()

  luaunit.assertTrue(contains(self:labelsFor(12), "Zip"))
end

--- DCS recycles menu ids: removing one item must touch that entry only.
function TestSpawnOwnership:test_removing_an_item_changes_only_its_entry()
  self:seat("Viper", 11, { { "Viper-1", "Zip" } })
  self:spawnFromMarker("Zip", "-sa6", { "SA-6 #1" })
  self:spawnFromMarker("Zip", "-armor", { "Armor #1" })
  self:rebuild()
  local item = veafSpawn.ownedSpawns["Zip"][1]

  veafSpawn.removeOwnedSpawn({ { owner = "Zip", id = item.id }, "Viper-1" })
  self:rebuild()

  local removed, added = 0, 0
  for _, call in ipairs(self.calls) do
    if call.kind == "removeItemForGroup" then
      removed = removed + 1
    elseif call.kind == "addCommandForGroup" and call.args[1] == 11 then
      added = added + 1
    end
  end
  luaunit.assertEquals(removed, 1, "only the removed item's entry leaves")
  luaunit.assertEquals(added, 0, "nothing is recreated")
end

function TestSpawnOwnership:test_removing_an_item_destroys_its_groups_and_says_so()
  self:seat("Viper", 11, { { "Viper-1", "Zip" } })
  self:spawnFromMarker("Zip", "-convoy", { "Convoy #1", "Convoy #2" })
  self:spawnFromMarker("Zip", "-sa6", { "SA-6 #1" })
  local item = veafSpawn.ownedSpawns["Zip"][1]

  veafSpawn.removeOwnedSpawn({ { owner = "Zip", id = item.id }, "Viper-1" })

  luaunit.assertEquals(self.destroyed, { "Convoy #1", "Convoy #2" })
  luaunit.assertEquals(#veafSpawn.ownedSpawns["Zip"], 1)
  luaunit.assertTrue(#dcs_mocks.messagesContaining(item.label) > 0)
  luaunit.assertTrue(self.refreshes > 0, "the menu follows")
end

--- Q8: a partly destroyed group goes whole.
function TestSpawnOwnership:test_a_partly_destroyed_group_is_destroyed_whole()
  self:seat("Viper", 11, { { "Viper-1", "Zip" } })
  self:spawnFromMarker("Zip", "-sa6", { "SA-6 #1" })

  veafSpawn.removeOwnedSpawn({ { owner = "Zip", id = veafSpawn.ownedSpawns["Zip"][1].id }, "Viper-1" })

  luaunit.assertEquals(self.destroyed, { "SA-6 #1" })
end

function TestSpawnOwnership:test_remove_all_destroys_every_item_of_the_owner_only()
  self:seat("Viper", 11, { { "Viper-1", "Zip" }, { "Viper-2", "Wingman" } })
  self:spawnFromMarker("Zip", "-sa6", { "SA-6 #1" })
  self:spawnFromMarker("Zip", "-armor", { "Armor #1" })
  self:spawnFromMarker("Wingman", "-cas", { "CAS #1" })

  veafSpawn.removeAllOwnedSpawns({ { owner = "Zip" }, "Viper-2" })

  luaunit.assertEquals(self.destroyed, { "SA-6 #1", "Armor #1" })
  luaunit.assertNil(veafSpawn.ownedSpawns["Zip"])
  luaunit.assertEquals(#veafSpawn.ownedSpawns["Wingman"], 1)
end

--- Q6: nobody else through this menu. A stale screen in a group the owner left is refused.
function TestSpawnOwnership:test_a_group_without_the_owner_is_refused()
  self:seat("Hog", 12, { { "Hog-1", "Other" } })
  self:spawnFromMarker("Zip", "-sa6", { "SA-6 #1" })

  veafSpawn.removeAllOwnedSpawns({ { owner = "Zip" }, "Hog-1" })
  veafSpawn.removeOwnedSpawn({ { owner = "Zip", id = veafSpawn.ownedSpawns["Zip"][1].id }, "Hog-1" })

  luaunit.assertEquals(self.destroyed, {})
  luaunit.assertEquals(#veafSpawn.ownedSpawns["Zip"], 1)
end

function TestSpawnOwnership:test_an_item_already_gone_is_said_and_dropped()
  self:seat("Viper", 11, { { "Viper-1", "Zip" } })
  self:spawnFromMarker("Zip", "-sa6", { "SA-6 #1" })
  local id = veafSpawn.ownedSpawns["Zip"][1].id
  dcs_mocks.removeGroup("SA-6 #1")

  veafSpawn.removeOwnedSpawn({ { owner = "Zip", id = id }, "Viper-1" })

  luaunit.assertNil(veafSpawn.ownedSpawns["Zip"])
  luaunit.assertTrue(#dcs_mocks.messagesContaining(veaf.t("spawn.mine_gone", "")) > 0)
end

--- A FARP or a FOB is a static with companions named after it: they leave with it.
function TestSpawnOwnership:test_a_farp_leaves_with_its_companions()
  self:seat("Viper", 11, { { "Viper-1", "Zip" } })
  local destroyed = self.destroyed
  local function static(name, side)
    self.statics[name] = {
      _side = side or coalition.side.BLUE,
      getName = function()
        return name
      end,
      isExist = function()
        return true
      end,
      destroy = function()
        table.insert(destroyed, name)
      end,
    }
  end
  static("FARP Zip")
  static("FARP FARP Zip unit #1")
  static("FARP Zip Watchtower #002")
  static("Somebody else's tent", coalition.side.RED)
  local groups = {}
  veafSpawn.recordMarkerSpawns(groups, markerEvent("-farp", 1, "Zip"))
  veaf.collectSpawnedGroup(groups, "FARP Zip")

  veafSpawn.removeOwnedSpawn({ { owner = "Zip", id = veafSpawn.ownedSpawns["Zip"][1].id }, "Viper-1" })

  table.sort(destroyed)
  luaunit.assertEquals(destroyed, { "FARP FARP Zip unit #1", "FARP Zip", "FARP Zip Watchtower #002" })
end

--- A CAS target ends through its own cleanup, or its watchdog would announce it destroyed.
function TestSpawnOwnership:test_a_cas_target_ends_through_the_cas_cleanup()
  self:seat("Viper", 11, { { "Viper-1", "Zip" } })
  local cleaned = 0
  veafCasMission = {
    casGroupName = "Blue CAS",
    isRunning = function()
      return true
    end,
    cleanupAfterMission = function()
      cleaned = cleaned + 1
      dcs_mocks.removeGroup("Blue CAS")
    end,
  }
  self:spawnFromMarker("Zip", "-cas", { "Blue CAS" })

  veafSpawn.removeOwnedSpawn({ { owner = "Zip", id = veafSpawn.ownedSpawns["Zip"][1].id }, "Viper-1" })

  luaunit.assertEquals(cleaned, 1)
  luaunit.assertEquals(self.destroyed, {})
end

os.exit(luaunit.LuaUnit.run())
