------------------------------------------------------------------
-- VEAF spawn ownership for DCS World
-- By zip (2026)
--
-- Features:
-- ---------
-- * Remembers, for each pilot, what his markers spawned (FEAT-SPAWN-OWNERSHIP-DESPAWN)
-- * An F10 menu lets him remove it: all of it at once, or one marker's spawn at a time
--
-- Part of veafSpawn, loaded by veafSpawn.lua. Combat zones and combat missions are not concerned:
-- they spawn through their own calls, never through a pilot's marker, and clean their own groups.
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

--- Seconds between two checks for the groups that no longer exist.
veafSpawn.OWNERSHIP_PRUNE_DELAY = 30

--- The longest part of the marker text an item's label shows, before the mission time.
veafSpawn.OWNERSHIP_LABEL_LENGTH = 24

--- What each pilot spawned from a marker, by player name: a list of items, oldest first,
--- `{ id = <number>, label = <string>, names = { <group or static name>, ... } }`. One item per marker:
--- a convoy, a multiplier or a repeat puts several groups in it. An owner with no item left is removed.
veafSpawn.ownedSpawns = {}
veafSpawn.ownedSpawnsCounter = 0

--- The "My spawns" menu, under the spawn menu.
veafSpawn.ownershipMenu = nil

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Recording
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local function nonEmpty(value)
  if type(value) == "string" and value ~= "" then
    return value
  end
  return nil
end

--- The player who wrote a marker, as the security layer reads it: the mark panel's author, then the
--- event's, then the player in the unit that placed it. nil when nothing names him.
function veafSpawn.markerAuthor(event)
  if not event then
    return nil
  end
  for _, panel in pairs(world.getMarkPanels() or {}) do
    if panel.idx == event.idx and nonEmpty(panel.author) then
      return panel.author
    end
  end
  if nonEmpty(event.author) then
    return event.author
  end
  local initiator = event.initiator
  if initiator and initiator.getPlayerName then
    return nonEmpty(initiator:getPlayerName())
  end
  return nil
end

--- What an item is called in the menu: the first line of the marker text, shortened, and the mission time.
function veafSpawn.ownershipLabel(text)
  local line = tostring(text or ""):match("^%s*([^\n]*)"):gsub("%s+$", "")
  if #line > veafSpawn.OWNERSHIP_LABEL_LENGTH then
    line = line:sub(1, veafSpawn.OWNERSHIP_LABEL_LENGTH - 1) .. "..."
  end
  local seconds = math.floor(timer.getAbsTime())
  return string.format("%s %02d:%02d", line, math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60)
end

--- veafCommands' marker spawn listener: watches what this marker spawns, and files it under its author.
--- The item is created with the first group, so a marker that spawned nothing leaves nothing; a group
--- spawned later — an alias delay, a repeat — joins the same item.
function veafSpawn.recordMarkerSpawns(spawnedGroups, event)
  local owner = veafSpawn.markerAuthor(event)
  if not owner then
    return
  end
  local label = veafSpawn.ownershipLabel(event and event.text)
  local item = nil
  veaf.registerSpawnedGroupsHook(spawnedGroups, function(name)
    if not item then
      veafSpawn.ownedSpawnsCounter = veafSpawn.ownedSpawnsCounter + 1
      item = { id = veafSpawn.ownedSpawnsCounter, label = label, names = {} }
    end
    -- Back in the owner's list if a prune removed the item between two groups of a repeat.
    local items = veafSpawn.ownedSpawns[owner] or {}
    veafSpawn.ownedSpawns[owner] = items
    local listed = false
    for _, other in ipairs(items) do
      listed = listed or other == item
    end
    if not listed then
      table.insert(items, item)
    end
    for _, known in ipairs(item.names) do
      if known == name then
        return
      end
    end
    table.insert(item.names, name)
    veaf.loggers.get(veafSpawn.Id):debug("%s spawned %s (%s)", veaf.p(owner), veaf.p(name), veaf.p(label))
    veafSpawn.refreshOwnershipMenu()
  end)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- What still exists
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local function alive(object)
  return object ~= nil and object:isExist() == true
end

--- True while a group or a static of this name exists. A FARP is both: its static and its escort group.
function veafSpawn.ownedObjectExists(name)
  return alive(Group.getByName(name)) or alive(StaticObject.getByName(name))
end

--- Drops the groups that no longer exist, the items left empty, the owners left with nothing (Q8).
--- @return boolean true when something was dropped (the menu is then refreshed)
function veafSpawn.pruneOwnedSpawns()
  local changed = false
  for owner, items in pairs(veafSpawn.ownedSpawns) do
    for i = #items, 1, -1 do
      local names = items[i].names
      for j = #names, 1, -1 do
        if not veafSpawn.ownedObjectExists(names[j]) then
          table.remove(names, j)
          changed = true
        end
      end
      if #names == 0 then
        table.remove(items, i)
        changed = true
      end
    end
    if #items == 0 then
      veafSpawn.ownedSpawns[owner] = nil
    end
  end
  if changed then
    veafSpawn.refreshOwnershipMenu()
  end
  return changed
end

--- The prune, every OWNERSHIP_PRUNE_DELAY seconds for the whole mission.
function veafSpawn.pruneOwnedSpawnsLoop()
  veafSpawn.pruneOwnedSpawns()
  veaf.scheduleFunction(veafSpawn.pruneOwnedSpawnsLoop, {}, timer.getTime() + veafSpawn.OWNERSHIP_PRUNE_DELAY)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Removing
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Destroys one recorded name, and what DCS spawned with it under a derived name.
function veafSpawn.destroyOwnedObject(name)
  -- The CAS target ends through the CAS module's own cleanup: destroyed from here, its watchdog would
  -- announce it destroyed, and the CAS mission would stay running for nothing.
  if veafCasMission and veafCasMission.isRunning() and name == veafCasMission.casGroupName then
    veafCasMission.cleanupAfterMission()
    return
  end
  local group = Group.getByName(name)
  if alive(group) then
    -- A partly destroyed group goes whole (Q8).
    group:destroy()
  end
  local static = StaticObject.getByName(name)
  if alive(static) then
    static:destroy()
    -- A FARP's tents, markers and windsocks are named "FARP <name> unit #N" (veafGrass.buildFarpUnits),
    -- a FOB's tower "<name> Watchtower #N" (veafSpawn.spawnFob).
    local prefixes = { "FARP " .. name .. " unit #", name .. " Watchtower #" }
    for _, side in pairs(coalition.side) do
      for _, other in ipairs(coalition.getStaticObjects(side) or {}) do
        local otherName = alive(other) and other:getName()
        for _, prefix in ipairs(prefixes) do
          if otherName and otherName:sub(1, #prefix) == prefix then
            other:destroy()
            break
          end
        end
      end
    end
  end
end

--- True when `owner` sits in the group of `unitName`: the menu cannot tell who clicked, only the group (Q4).
function veafSpawn.ownerIsInGroupOf(owner, unitName)
  local unit = unitName and Unit.getByName(unitName)
  if not unit then
    return false
  end
  local group = unit:getGroup()
  local units = group and group:getUnits() or { unit }
  for _, other in ipairs(units) do
    if other.getPlayerName and other:getPlayerName() == owner then
      return true
    end
  end
  return false
end

--- Removes items of `owner`; `id` nil removes them all. Answers the clicking group.
local function removeOwned(owner, id, unitName)
  if not veafSpawn.ownerIsInGroupOf(owner, unitName) then
    -- A screen left open after the owner left the group: only he may remove his spawns (Q6).
    veaf.outTextForGroup(unitName, veaf.t("spawn.mine_not_yours", owner), 10)
    return
  end
  local items = veafSpawn.ownedSpawns[owner] or {}
  local removed, gone, kept = {}, {}, {}
  for _, item in ipairs(items) do
    if id == nil or item.id == id then
      local existing = false
      for _, name in ipairs(item.names) do
        if veafSpawn.ownedObjectExists(name) then
          existing = true
          veafSpawn.destroyOwnedObject(name)
        end
      end
      table.insert(existing and removed or gone, item.label)
    else
      table.insert(kept, item)
    end
  end
  veafSpawn.ownedSpawns[owner] = #kept > 0 and kept or nil
  if #removed > 0 then
    veaf.outTextForGroup(unitName, veaf.t("spawn.mine_removed", table.concat(removed, ", ")), 10)
  end
  if #gone > 0 then
    veaf.outTextForGroup(unitName, veaf.t("spawn.mine_gone", table.concat(gone, ", ")), 10)
  end
  veafSpawn.refreshOwnershipMenu()
end

--- Menu callback: `{ { owner, id }, unitName }`.
function veafSpawn.removeOwnedSpawn(parameters)
  removeOwned(parameters[1].owner, parameters[1].id, parameters[2])
end

--- Menu callback: `{ { owner }, unitName }`.
function veafSpawn.removeAllOwnedSpawns(parameters)
  removeOwned(parameters[1].owner, nil, parameters[2])
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- The F10 menu
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The player in a unit, nil when none.
local function playerOf(unitName)
  local unit = unitName and Unit.getByName(unitName)
  return unit and unit.getPlayerName and unit:getPlayerName() or nil
end

--- Fills "My spawns" again from the recorded items, then asks for a render. The builder touches in DCS
--- only the entries that changed — DCS recycles the id of a removed entry (`f10-menu-entry-id-is-recycled`)
--- — so the labels and parameters of the entries that stay must not move: no count in a label.
function veafSpawn.refreshOwnershipMenu()
  local menu = veafSpawn.ownershipMenu
  if not menu then
    return
  end
  veafRadio.clearSubmenu(menu)
  local owners = {}
  for owner in pairs(veafSpawn.ownedSpawns) do
    table.insert(owners, owner)
  end
  table.sort(owners)
  for _, owner in ipairs(owners) do
    -- One menu per owner, named after him and shown to the groups he sits in: in a two-seater or a
    -- flight, each occupant's spawns under his own name (Q4).
    local ownerMenu = veafRadio.addSubMenuForGroups(owner, menu, function(unitName)
      return playerOf(unitName) == owner
    end)
    local removeAll = veafRadio.addCommandToSubmenu(
      veaf.t("menu.spawn.mine_remove_all"),
      ownerMenu,
      veafSpawn.removeAllOwnedSpawns,
      { owner = owner },
      veafRadio.USAGE_ForGroup
    )
    removeAll.sortKey = ""
    for _, item in ipairs(veafSpawn.ownedSpawns[owner]) do
      local command = veafRadio.addCommandToSubmenu(
        item.label,
        ownerMenu,
        veafSpawn.removeOwnedSpawn,
        { owner = owner, id = item.id },
        veafRadio.USAGE_ForGroup
      )
      command.sortKey = string.format("%08d", item.id)
    end
  end
  veafRadio.refreshRadioMenu()
end

--- Called by veafSpawn.initialize, after the spawn menu is built.
function veafSpawn.initializeOwnership()
  veafCommands.markerSpawnListener = veafSpawn.recordMarkerSpawns
  if veafSpawn.rootPath then
    -- The tenth entry of the spawn menu: it still fits on one page (veafRadio.MENU_PAGE_SIZE).
    -- Shown only to a group where a pilot has something to remove.
    veafSpawn.ownershipMenu = veafRadio.addSubMenuForGroups(veaf.t("menu.spawn.mine"), veafSpawn.rootPath, function(unitName)
      local player = playerOf(unitName)
      return player ~= nil and veafSpawn.ownedSpawns[player] ~= nil
    end)
  end
  veaf.scheduleFunction(veafSpawn.pruneOwnedSpawnsLoop, {}, timer.getTime() + veafSpawn.OWNERSHIP_PRUNE_DELAY)
end
