------------------------------------------------------------------
-- VEAF radio menu script library for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Manage the VEAF radio menus in the F10 - Other menu
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

--- veafRadio Table.
veafRadio = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafRadio.Id = "RADIO"

-- trace level, specific to this module
--veafRadio.LogLevel = "trace"

veaf.loggers.new(veafRadio.Id, veafRadio.LogLevel)

veafRadio.RadioMenuName = "VEAF"

-- constants used to determine how the radio menu is set up
veafRadio.USAGE_ForAll = 0
veafRadio.USAGE_ForGroup = 1
veafRadio.USAGE_ForUnit = 2

-- DCS truncates an F10 submenu past this many items; menus over it are paginated
-- automatically at render time (ADR 0013), a "Next page" submenu taking one slot.
veafRadio.MENU_PAGE_SIZE = 10

-- delay for the actual refresh
veafRadio.refreshRadioMenu_DELAY = 1

--- Key phrase to look for in the mark text which triggers the command.
veafRadio.Keyphrase = "_radio"

--- number of seconds between beacons checks
veafRadio.BEACONS_SCHEDULE = 5

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------
veafRadio.skipHelpMenus = true

--- Humans Units (associative array unitName => unit)
veafRadio.humanUnits = {}
veafRadio.humanGroups = {}

--- This structure contains all the radio menus
veafRadio.radioMenu = {}
veafRadio.radioMenu.title = veafRadio.RadioMenuName
veafRadio.radioMenu.dcsRadioMenu = nil
veafRadio.radioMenu.subMenus = {}
veafRadio.radioMenu.commands = {}

--- Counts the size of the radio menu
veafRadio.radioMenuSize = {}

veafRadio.beacons = {}
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRadio.onBirthEvent(event)
  veaf.loggers.get(veafRadio.Id):trace("veafRadio.onBirthEvent(%s)", event)

  -- find the originator unit
  local unitName = event and event.initiator and event.initiator.unitName
  if not unitName and event and event.initiator and event.initiator.getName then
    -- dynamic slot units are DCS objects without mist table properties
    unitName = event.initiator:getName()
  end
  if not unitName then
    return
  end
  veaf.loggers.get(veafRadio.Id):trace("unitName=%s", unitName)
  local isHumanUnit = veaf.mist.isHumanUnit(unitName) or (event.type and event.type.id == world.event.S_EVENT_PLAYER_ENTER_UNIT)
  if isHumanUnit then -- it's a human unit
    veaf.loggers.get(veafRadio.Id):trace("veafRadio.humanUnits=%s", veafRadio.humanUnits)
    veaf.loggers.get(veafRadio.Id):trace("unitName %s is a human unit", unitName)
    if not veafRadio.humanUnits[unitName] then
      -- add the unit to the human units list and rebuild the radio menu
      veaf.loggers.get(veafRadio.Id):trace("Adding human unit %s", unitName)
      local groupId = event and event.initiator and event.initiator.unitGroupId
      if not groupId and event and event.initiator and event.initiator.getGroup then
        -- dynamic slot: get group ID via DCS API
        local grp = event.initiator:getGroup()
        if grp then
          groupId = grp:getID()
        end
      end
      local callsign = event and event.initiator and event.initiator.unitPilotName
      if not callsign then
        callsign = event and event.initiator and event.initiator.unitCallsign
      end
      if not callsign and event and event.initiator and event.initiator.getPlayerName then
        -- dynamic slot: get player name via DCS API
        callsign = event.initiator:getPlayerName()
      end
      local unitObject = { name = unitName, spawned = true, groupId = groupId, callsign = callsign }
      veafRadio.humanUnits[unitName] = {}
      veafRadio.humanUnits[unitName].spawned = true
      veafRadio.humanUnits[unitName] = unitObject

      veaf.loggers.get(veafRadio.Id):trace("veafRadio.humanGroups=%s", veafRadio.humanGroups)
      if not veafRadio.humanGroups[groupId] then
        veafRadio.humanGroups[groupId] = {}
        veafRadio.humanGroups[groupId].callsigns = {}
        veafRadio.humanGroups[groupId].units = {}
      end
      -- The group's side, needed to keep a per-group command inside a coalition-scoped
      -- submenu from being attached for a group that cannot see it
      -- (FEAT-COMBATZONE-MENU-COALITION). Left nil when DCS gives us no coalition.
      if not veafRadio.humanGroups[groupId].coalition and event.initiator.getCoalition then
        veafRadio.humanGroups[groupId].coalition = event.initiator:getCoalition()
      end

      table.insert(veafRadio.humanGroups[groupId].callsigns, callsign)
      veaf.loggers.get(veafRadio.Id):trace("veafRadio.humanGroups=%s", veafRadio.humanGroups)
      veafRadio.humanGroups[groupId].units[callsign] = unitObject

      -- sort callsigns for each group
      for _, groupData in pairs(veafRadio.humanGroups) do
        table.sort(groupData.callsigns)
      end

      -- refresh the radio menu
      veaf.loggers
        .get(veafRadio.Id)
        :debug("refreshRadioMenu() following event %s of human unit %s", event.type and event.type.name, unitName)
      veafRadio.refreshRadioMenu()
    end
  end
end

function veafRadio.executeCommand(eventPos, eventText, eventCoalition, bypassSecurity)
  veaf.loggers.get(veafRadio.Id):trace(string.format("veafRadio.executeCommand(%s)", eventText))

  -- Check if marker has a text and the veafRadio.keyphrase keyphrase.
  if eventText ~= nil and eventText:lower():find(veafRadio.Keyphrase) then
    -- Analyse the mark point text and extract the keywords.
    local options = veafRadio.markTextAnalysis(eventText)

    if options then
      veaf.loggers.get(veafRadio.Id):trace(string.format("options.path=%s", veaf.p(options.path)))
      -- Check options commands
      if options.transmit and options.message and options.frequencies and options.name then
        -- transmit a radio message via SRS
        veafRadio.transmitMessage(
          options.message,
          options.frequencies,
          options.modulations,
          options.name,
          eventCoalition,
          eventPos,
          options.quiet
        )
        return true
      elseif options.playmp3 and options.path and options.frequencies and options.name then
        -- play a MP3 file via SRS
        veafRadio.playToRadio(options.path, options.frequencies, options.modulations, options.name, eventCoalition, eventPos, options.quiet)
        return true
      end
    else
      -- None of the keywords matched.
      return false
    end
  end
  return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Extract keywords from mark text.
function veafRadio.markTextAnalysis(text)
  veaf.loggers.get(veafRadio.Id):trace(string.format("markTextAnalysis(%s)", text))

  -- Option parameters extracted from the mark text.
  local switch = {}
  switch.transmit = false
  switch.playmp3 = false

  switch.message = nil
  switch.frequencies = "251"
  switch.modulations = "AM"
  switch.name = "SRS"
  switch.quiet = false
  switch.path = nil

  -- Check for correct keywords.
  if text:lower():find(veafRadio.Keyphrase .. " transmit") then
    switch.transmit = true
  elseif text:lower():find(veafRadio.Keyphrase .. " play") then
    switch.playmp3 = true
  else
    return nil
  end

  -- keywords are split by ","
  local keywords = veaf.split(text, ",")

  for _, keyphrase in pairs(keywords) do
    -- Split keyphrase by space. First one is the key and second, ... the parameter(s) until the next comma.
    local str = veaf.breakString(veaf.trim(keyphrase), " ")
    local key = str[1]
    local val = str[2]

    if key:lower() == "message" then
      -- Set message.
      veaf.loggers.get(veafRadio.Id):trace(string.format("Keyword message = %s", tostring(val)))
      switch.message = val
    elseif key:lower() == "path" then
      -- Set path.
      veaf.loggers.get(veafRadio.Id):trace(string.format("Keyword path = %s", tostring(val)))
      switch.path = val
    elseif key:lower() == "name" then
      -- Set name.
      veaf.loggers.get(veafRadio.Id):trace(string.format("Keyword name = %s", tostring(val)))
      switch.name = val
    elseif key:lower() == "quiet" then
      -- Set quiet.
      veaf.loggers.get(veafRadio.Id):trace("Keyword quiet found")
      switch.quiet = true
    elseif key:lower() == "freq" or key:lower() == "freqs" or key:lower() == "frequency" or key:lower() == "frequencies" then
      -- Set frequencies.
      veaf.loggers.get(veafRadio.Id):trace(string.format("Keyword frequencies = %s", tostring(val)))
      switch.frequencies = val
    elseif key:lower() == "mod" or key:lower() == "mods" or key:lower() == "modulation" or key:lower() == "modulations" then
      -- Set modulations.
      veaf.loggers.get(veafRadio.Id):trace(string.format("Keyword modulations = %s", tostring(val)))
      switch.modulations = val
    elseif key:lower() == "path" then
      -- Set path.
      veaf.loggers.get(veafRadio.Id):trace(string.format("Keyword path = %s", tostring(val)))
      switch.path = val
    end
  end

  return switch
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Main event handler (used for PLAYER ENTER UNIT events)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRadio._proxyMethod(parameters)
  veaf.loggers.get(veafRadio.Id):trace("parameters=%s", veaf.lp(parameters))
  local realMethod, realParameters = veaf.safeUnpack(parameters)
  veaf.loggers.get(veafRadio.Id):trace("realMethod=%s", veaf.lp(realMethod))
  veaf.loggers.get(veafRadio.Id):trace("realParameters=%s", veaf.lp(realParameters))
  if veafSecurity.isAuthenticated() then
    realMethod(realParameters)
  else
    veaf.loggers.get(veafRadio.Id):error("Your radio has to be authenticated for '+'' commands")
    trigger.action.outText(veaf.t("radio.auth_required"), 5)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- RadioMenuBuilder — encapsulates DCS missionCommands tree building
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafRadio.RadioMenuBuilder = {}
veafRadio.RadioMenuBuilder.__index = veafRadio.RadioMenuBuilder

--- Creates a new RadioMenuBuilder bound to the given root node.
--- @param root table  root menu node (must have .title, .subMenus, .commands)
function veafRadio.RadioMenuBuilder:new(root)
  local instance = setmetatable({}, self)
  instance._root = root
  return instance
end

--- Creates a submenu node under parent (or root when nil) and returns it.
--- When coalitionSide is given (coalition.side.RED / BLUE), the node and everything
--- below it render through the DCS ForCoalition menu API, so only that side sees them
--- (FEAT-COMBATZONE-MENU-COALITION).
function veafRadio.RadioMenuBuilder:addMenu(label, parent, coalitionSide)
  local subMenu = {
    title = label,
    dcsRadioMenu = nil,
    subMenus = {},
    commands = {},
    coalition = coalitionSide,
  }
  local menu = parent or self._root
  table.insert(menu.subMenus, subMenu)
  return subMenu
end

--- Creates a command node under parent (or root when nil) and returns it.
--- The caller may set `groupFilter` on the returned node (see _placeCommandOnMenu) and
--- `sortKey` to override its alphabetical position (see _buildSubtree).
function veafRadio.RadioMenuBuilder:addCommand(label, parent, method, parameters, usage, isSecured)
  local command = {
    title = label,
    method = method,
    parameters = parameters,
    isSecured = isSecured or false,
    usage = usage or veafRadio.USAGE_ForAll,
  }
  local menu = parent or self._root
  table.insert(menu.commands, command)
  return command
end

--- Removes the root DCS menu entry and rebuilds the entire tree from scratch.
function veafRadio.RadioMenuBuilder:rebuild()
  if self._root.dcsRadioMenu then
    -- Coalition-scoped nodes live in their own DCS namespace, so the global removeItem on the
    -- root is not guaranteed to reach them. The menu is rebuilt on every player join, so
    -- anything left behind would stack up one duplicate per join — remove them explicitly
    -- first (FEAT-COMBATZONE-MENU-COALITION). Removing an already-gone item is a no-op.
    self:_removeCoalitionMenus(self._root)
    missionCommands.removeItem(self._root.dcsRadioMenu)
  else
    veaf.loggers.get(veafRadio.Id):info("RadioMenuBuilder:rebuild() first time — no DCS radio menu yet")
  end
  self:build()
end

--- (internal) Depth-first removal of every rendered coalition-scoped submenu under node.
function veafRadio.RadioMenuBuilder:_removeCoalitionMenus(node)
  if not node then
    return
  end
  for _, subMenu in ipairs(node.subMenus or {}) do
    self:_removeCoalitionMenus(subMenu)
  end
  if node.renderedForCoalition and node.dcsRadioMenu then
    veaf.loggers.get(veafRadio.Id):trace("removing coalition %s menu %s", node.renderedForCoalition, veaf.p(node.title))
    missionCommands.removeItemForCoalition(node.renderedForCoalition, node.dcsRadioMenu)
    node.dcsRadioMenu = nil
    node.renderedForCoalition = nil
  end
end

--- Builds the DCS menu tree from the root node without clearing first.
function veafRadio.RadioMenuBuilder:build()
  self:_buildSubtree(nil, self._root)
end

--- (internal) True if the node carries a USAGE_ForUnit command.
--- ForUnit is the only usage that multiplies a single logical command into
--- several DCS entries (one per callsign), so a global page split cannot bound
--- a group's item count — such a node opts out of pagination (see _buildSubtree).
function veafRadio.RadioMenuBuilder:_hasForUnit(node)
  for _, command in ipairs(node.commands) do
    if command.usage == veafRadio.USAGE_ForUnit then
      return true
    end
  end
  return false
end

--- (internal) Places a single logical command onto the given DCS menu, handling
--- the ForAll (global) and per-group / per-unit dispatch. Extracted from
--- _buildSubtree so pagination can target a specific page's DCS menu.
---
--- A command may carry an optional `groupFilter(unitName, groupId) -> boolean`, consulted
--- once per candidate unit: false leaves the entry out for that group. It is what lets a
--- module offer an entry only to the pilots it applies to — an aircraft type that has a
--- checklist, a pilot with a session running — instead of showing everyone an item that
--- answers "nothing for you" (veafAssist). Only per-group / per-unit commands are
--- filtered: a ForAll command has no unit to decide on.
function veafRadio.RadioMenuBuilder:_placeCommandOnMenu(command, dcsMenu, coalitionSide)
  veaf.loggers.get(veafRadio.Id):trace(string.format("command=%s", veaf.p(command)))
  if not command.usage then
    command.usage = veafRadio.USAGE_ForAll
  end
  if command.usage ~= veafRadio.USAGE_ForAll then
    local alreadyDoneGroups = {}
    for groupId, groupData in pairs(veafRadio.humanGroups) do
      veaf.loggers.get(veafRadio.Id):trace(string.format("groupId=%s", veaf.p(groupId)))
      -- In a coalition-scoped subtree, a per-group command must not be attached for a group
      -- of the other side: it cannot see the parent path (FEAT-COMBATZONE-MENU-COALITION).
      -- A group whose coalition DCS never gave us is left in, as before.
      -- Skip the whole group rather than iterate an empty table: this runs for every human
      -- group on every menu rebuild.
      local onThisSide = coalitionSide == nil or groupData.coalition == nil or groupData.coalition == coalitionSide
      if onThisSide then
        for _, callsign in pairs(groupData.callsigns) do
          veaf.loggers.get(veafRadio.Id):trace(string.format("callsign=%s", veaf.p(callsign)))
          local unitData = groupData.units[callsign]
          local unitName = unitData.name
          veaf.loggers.get(veafRadio.Id):trace(string.format("unitName=%s", veaf.p(unitName)))
          local humanUnit = veafRadio.humanUnits[unitName]
          veaf.loggers.get(veafRadio.Id):trace(string.format("humanUnit=%s", veaf.p(humanUnit)))
          local passesFilter = true
          if command.groupFilter then
            local ok, result = pcall(command.groupFilter, unitName, groupId)
            -- A filter that throws must not take the whole menu rebuild down with it.
            passesFilter = ok and result == true
            if not ok then
              veaf.loggers.get(veafRadio.Id):warn("groupFilter for command %s failed: %s", veaf.p(command.title), veaf.p(result))
            end
          end
          if humanUnit and humanUnit.spawned and passesFilter then
            veaf.loggers.get(veafRadio.Id):debug(string.format("add radio command for player unit %s", veaf.p(unitName)))
            local parameters = command.parameters
            if parameters == nil then
              parameters = unitName
            else
              parameters = { command.parameters }
              table.insert(parameters, unitName)
            end
            local _title = command.title
            if command.usage == veafRadio.USAGE_ForUnit then
              _title = callsign .. " - " .. command.title
            end
            if alreadyDoneGroups[groupId] == nil or command.usage == veafRadio.USAGE_ForUnit then
              self:_addDcsCommand(groupId, _title, dcsMenu, command, parameters, coalitionSide)
            end
            alreadyDoneGroups[groupId] = true
          end
        end
      end
    end
  else
    self:_addDcsCommand(nil, command.title, dcsMenu, command, command.parameters, coalitionSide)
  end
end

--- (internal) Recursively builds DCS submenus and commands for a node.
--- Menus with more than veafRadio.MENU_PAGE_SIZE children are paginated at
--- render time: the overflow is distributed across "Next page" submenus created
--- on the fly in the DCS projection only — the logical tree is untouched, so the
--- references modules hold stay valid (ADR 0013). Opt out with
--- veafRadio.doNotPaginate(menu); a node with a ForUnit command opts out
--- automatically (see _hasForUnit).
function veafRadio.RadioMenuBuilder:_buildSubtree(parentNode, node)
  veaf.loggers.get(veafRadio.Id):debug("RadioMenuBuilder:_buildSubtree %s", veaf.lp(veaf.ifnn(node, "title")))

  if not node or not node.title then
    return
  end

  -- A coalition-scoped node scopes everything below it: a global child under a scoped
  -- parent has no coherent meaning in DCS (FEAT-COMBATZONE-MENU-COALITION).
  local coalitionSide = node.coalition or (parentNode and parentNode.coalition)
  node.renderedForCoalition = coalitionSide

  local parentDcsMenu = parentNode and parentNode.dcsRadioMenu
  if coalitionSide then
    node.dcsRadioMenu = missionCommands.addSubMenuForCoalition(coalitionSide, node.title, parentDcsMenu)
  else
    node.dcsRadioMenu = missionCommands.addSubMenu(node.title, parentDcsMenu)
  end

  -- Entries render in alphabetical order, which is the right default when a menu is a
  -- list to browse. A module whose entries have an intended sequence — veafAssist's
  -- "confirm the step" before "skip the step" — sets `sortKey` on them instead, so the
  -- order does not depend on how the labels happen to sort, in French or in any other
  -- language they get translated to.
  local function compareByOrder(a, b)
    local left = a.sortKey or a.title
    local right = b.sortKey or b.title
    if left and right then
      return left < right
    else
      return false
    end
  end
  table.sort(node.commands, compareByOrder)
  table.sort(node.subMenus, compareByOrder)

  -- Pagination decision (ADR 0013): each command / submenu counts as one item.
  local total = #node.commands + #node.subMenus
  local paginate = total > veafRadio.MENU_PAGE_SIZE and not node.noPagination
  if paginate and self:_hasForUnit(node) then
    veaf.loggers.get(veafRadio.Id):warn(
      "radio menu '%s' has ForUnit commands and more than %d items; pagination disabled (would overflow per group)",
      node.title,
      veafRadio.MENU_PAGE_SIZE
    )
    paginate = false
  end

  -- Place children on the current page, spilling into "Next page" submenus.
  -- A full page holds (MENU_PAGE_SIZE - 1) items plus the "Next page" entry.
  local currentDcsMenu = node.dcsRadioMenu
  local placedOnPage = 0
  local function advancePageIfFull()
    if paginate and placedOnPage >= veafRadio.MENU_PAGE_SIZE - 1 then
      -- A page of a scoped menu must be scoped too, or the overflow would be world-visible.
      if coalitionSide then
        currentDcsMenu = missionCommands.addSubMenuForCoalition(coalitionSide, veaf.t("radio.next_page"), currentDcsMenu)
      else
        currentDcsMenu = missionCommands.addSubMenu(veaf.t("radio.next_page"), currentDcsMenu)
      end
      placedOnPage = 0
    end
  end

  for _, command in ipairs(node.commands) do
    advancePageIfFull()
    self:_placeCommandOnMenu(command, currentDcsMenu, coalitionSide)
    placedOnPage = placedOnPage + 1
  end

  for _, subMenu in ipairs(node.subMenus) do
    advancePageIfFull()
    self:_buildSubtree({ dcsRadioMenu = currentDcsMenu, coalition = coalitionSide }, subMenu)
    placedOnPage = placedOnPage + 1
  end
end

--- (internal) Adds a single DCS command, handling secured and per-group / per-coalition dispatch.
function veafRadio.RadioMenuBuilder:_addDcsCommand(groupId, title, dcsParent, command, parameters, coalitionSide)
  if not command.method then
    veaf.loggers.get(veafRadio.Id):error("ERROR - missing method for command " .. title)
  end
  local _title = title
  local _method = command.method
  local _parameters = parameters
  if command.isSecured then
    veaf.loggers.get(veafRadio.Id):trace("adding secured command")
    _method = veafRadio._proxyMethod
    _parameters = { command.method, _parameters }
    if veafSecurity.isAuthenticated() then
      _title = "-" .. title
    else
      _title = "+" .. title
    end
  end
  veaf.loggers.get(veafRadio.Id):trace("_title=%s", veaf.lp(_title))
  veaf.loggers.get(veafRadio.Id):trace("_parameters=%s", veaf.lp(_parameters))
  -- Per-group wins over per-coalition: it is the narrower scope, and the group has already
  -- been filtered to the right side by _placeCommandOnMenu.
  if groupId then
    veaf.loggers.get(veafRadio.Id):trace("adding for group %s command %s", groupId or "", _title or "")
    missionCommands.addCommandForGroup(groupId, _title, dcsParent, _method, _parameters)
  elseif coalitionSide then
    veaf.loggers.get(veafRadio.Id):trace("adding for coalition %s command %s", coalitionSide, _title or "")
    missionCommands.addCommandForCoalition(coalitionSide, _title, dcsParent, _method, _parameters)
  else
    veaf.loggers.get(veafRadio.Id):trace("adding for all command %s", _title or "")
    missionCommands.addCommand(_title, dcsParent, _method, _parameters)
  end
end

veafRadio._builder = veafRadio.RadioMenuBuilder:new(veafRadio.radioMenu)

--- Refresh the radio menu, based on stored information
--- This is called from another method that has first changed the radio menu information by adding or removing elements
function veafRadio.refreshRadioMenu(dontDelay)
  veaf.loggers.get(veafRadio.Id):debug(string.format("veafRadio.refreshRadioMenu()"))

  -- delay the refresh if possible
  if not dontDelay then
    if not veafRadio.refreshRadioMenuDelayedScheduling then
      veafRadio.refreshRadioMenuDelayedScheduling =
        mist.scheduleFunction(veafRadio._refreshRadioMenu, {}, timer.getTime() + veafRadio.refreshRadioMenu_DELAY)
    end
  else
    veafRadio._refreshRadioMenu()
  end
end

--- actually refresh the radio menu, based on stored information
function veafRadio._refreshRadioMenu()
  veaf.loggers.get(veafRadio.Id):debug(string.format("veafRadio._refreshRadioMenu()"))
  if not veafRadio.dontCreateMenus then
    veafRadio.refreshRadioMenuDelayedScheduling = nil
    veafRadio._builder:rebuild()
  end
end

function veafRadio.refreshRadioSubmenu(parentRadioMenu, radioMenu)
  veafRadio._builder:_buildSubtree(parentRadioMenu, radioMenu)
end

function veafRadio.addCommandToMainMenu(title, method)
  return veafRadio._addCommandToMainMenu(title, method, false)
end

function veafRadio.addSecuredCommandToMainMenu(title, method)
  return veafRadio._addCommandToMainMenu(title, method, true)
end

function veafRadio._addCommandToMainMenu(title, method, isSecured)
  return veafRadio._addCommandToSubmenu(title, nil, method, nil, nil, isSecured)
end

function veafRadio.addCommandToSubmenu(title, radioMenu, method, parameters, usage)
  return veafRadio._addCommandToSubmenu(title, radioMenu, method, parameters, usage, false)
end

function veafRadio.addSecuredCommandToSubmenu(title, radioMenu, method, parameters, usage)
  return veafRadio._addCommandToSubmenu(title, radioMenu, method, parameters, usage, true)
end

function veafRadio._addCommandToSubmenu(title, radioMenu, method, parameters, usage, isSecured)
  veaf.loggers.get(veafRadio.Id):debug(string.format("_addCommandToSubmenu(%s)", veaf.p(title)))
  return veafRadio._builder:addCommand(title, radioMenu, method, parameters, usage, isSecured)
end

function veafRadio.delCommand(radioMenu, title)
  for count = 1, #radioMenu.commands do
    local command = radioMenu.commands[count]
    if command.title == title then
      table.remove(radioMenu.commands, count)
      return true
    end
  end

  return false
end

function veafRadio.addMenu(title)
  return veafRadio.addSubMenu(title, nil)
end

--- Adds a submenu. When coalitionSide is set (coalition.side.RED / BLUE), the submenu and
--- everything under it is only shown to that coalition (FEAT-COMBATZONE-MENU-COALITION).
function veafRadio.addSubMenu(title, radioMenu, coalitionSide)
  return veafRadio._builder:addMenu(title, radioMenu, coalitionSide)
end

--- Opt a menu out of automatic render-time pagination (ADR 0013).
--- The menu then renders all its children directly, even past MENU_PAGE_SIZE.
function veafRadio.doNotPaginate(radioMenu)
  if not radioMenu then
    veaf.loggers.get(veafRadio.Id):error("veafRadio.doNotPaginate() radioMenu parameter is nil !")
    return
  end
  radioMenu.noPagination = true
  return radioMenu
end

function veafRadio.clearSubmenu(subMenu)
  if not subMenu then
    veaf.loggers.get(veafRadio.Id):error("veafRadio.clearSubmenu() subMenu parameter is nil !")
    return
  end
  veaf.loggers.get(veafRadio.Id):debug(string.format("veafRadio.clearSubmenu(%s)", subMenu.title))
  subMenu.subMenus = {}
  subMenu.commands = {}
end

function veafRadio.delSubmenu(subMenu, radioMenu)
  if not subMenu then
    veaf.loggers.get(veafRadio.Id):error("veafRadio.delSubmenu() subMenu parameter is nil !")
    return
  end
  local menu = veafRadio.radioMenu
  if radioMenu then
    menu = radioMenu
  end
  veaf.arrayRemoveWhen(menu.subMenus, function(t, i, j)
    -- Return true to keep the value, or false to discard it.
    --veaf.loggers.get(veafRadio.Id):trace("searching for " .. subMenu.title)
    local v = menu.subMenus[i]
    --veaf.loggers.get(veafRadio.Id):trace("checking " .. v.title)
    if v == subMenu or v.title == subMenu then
      --veaf.loggers.get(veafRadio.Id):trace("found ! removing " .. v.title)
      return false
    else
      --veaf.loggers.get(veafRadio.Id):trace("keeping " .. v.title)
      return true
    end
  end)
end

-- Sort the elements by their sort attribute and add each one to the menu via the
-- caller's build method. Pagination is NOT done here: the render step
-- (RadioMenuBuilder:_buildSubtree) paginates every menu automatically (ADR 0013).
-- The name is kept for API stability (callers: veafAssets, veafCombatMission).
function veafRadio.addPaginatedRadioElements(radioMenu, addCommandToSubmenuMethod, elements, titleAttribute, sortAttribute)
  veaf.loggers.get(veafRadio.Id):trace(string.format("veafRadio.addPaginatedRadioElements() : elements=%s", veaf.p(elements)))

  if not addCommandToSubmenuMethod then
    veaf.loggers.get(veafRadio.Id):error("veafRadio.addPaginatedRadioMenu : addCommandToSubmenuMethod is mandatory !")
    return
  end

  local sortedElements = {}
  local sortAttribute = sortAttribute or "sort"
  local titleAttribute = titleAttribute or "title"
  for name, element in pairs(elements) do
    local sortValue = element[sortAttribute]
    if not sortValue then
      sortValue = name
    end
    table.insert(sortedElements, { element = element, sort = sortValue, title = name })
  end
  local compare = function(a, b)
    if not a then
      a = {}
    end
    if not a["sort"] then
      a["sort"] = 0
    end
    if not b then
      b = {}
    end
    if not b["sort"] then
      b["sort"] = 0
    end

    return a["sort"] < b["sort"]
  end
  table.sort(sortedElements, compare)

  local sortedTitles = {}
  local elementsByTitle = {}
  for i = 1, #sortedElements do
    local title = sortedElements[i].element[titleAttribute]
    if not title then
      title = sortedElements[i].title
    end
    table.insert(sortedTitles, title)
    elementsByTitle[title] = sortedElements[i].element
  end
  veaf.loggers.get(veafRadio.Id):trace("sortedTitles=%s", veaf.lp(sortedTitles))

  for _, title in ipairs(sortedTitles) do
    addCommandToSubmenuMethod(radioMenu, title, elementsByTitle[title])
  end
end

-- build a paginated submenu (main method)
function veafRadio.addPaginatedRadioMenu(title, radioMenu, addCommandToSubmenuMethod, elements, titleAttribute, sortAttribute)
  veaf.loggers.get(veafRadio.Id):trace(string.format("veafRadio.addPaginatedRadioMenu(title=%s)", title))

  local firstPagePath = veafRadio.addSubMenu(title, radioMenu)
  veafRadio.addPaginatedRadioElements(firstPagePath, addCommandToSubmenuMethod, elements, titleAttribute, sortAttribute)
  return firstPagePath
end

function veafRadio.getHumanUnitOrWingman(unitName)
  local result = Unit.getByName(unitName)
  if not result then
    local unitData = veafRadio.humanUnits[unitName]
    veaf.loggers.get(veafRadio.Id):trace(string.format("unitData=%s", veaf.p(unitData)))
    if unitData and unitData.groupId then
      local mistGroup = veaf.mist.getGroupById(unitData.groupId)
      veaf.loggers.get(veafRadio.Id):trace(string.format("mistGroup=%s", veaf.p(mistGroup)))
      if mistGroup then
        local group = Group.getByName(mistGroup.groupName)
        if group then
          veaf.loggers.get(veafRadio.Id):trace(string.format("group=%s", veaf.p(group)))
          veaf.loggers.get(veafRadio.Id):trace(string.format("group:getUnits()=%s", veaf.p(group:getUnits())))
          for _, groupUnit in pairs(group:getUnits()) do
            if not result then
              result = groupUnit
            end
          end
        end
      end
    end
  end
  if result then
    veaf.loggers.get(veafRadio.Id):trace(string.format("result=%s", veaf.p(result)))
    veaf.loggers.get(veafRadio.Id):trace(string.format("result:getName()=%s", veaf.p(result:getName())))
  end
  return result
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- radio beacons
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRadio.startBeacon(name, firstRunDelay, secondsBetweenRepeats, frequencies, modulations, message, mp3, coalition)
  veaf.loggers.get(veafRadio.Id):debug(
    "startBeacon(name=%s, firstRunDelay=%s, secondsBetweenRepeats=%s, coalition=%s, frequencies=%s, modulations=%s, message=%s, mp3=%s)",
    veaf.lp(name),
    veaf.lp(firstRunDelay),
    veaf.lp(secondsBetweenRepeats),
    veaf.lp(coalition),
    veaf.lp(frequencies),
    veaf.lp(modulations),
    veaf.lp(message),
    veaf.lp(mp3)
  )

  local beacon = veafRadio.beacons[name:lower()]
  if not beacon then
    beacon = {}
  end
  beacon.name = name
  beacon.secondsBetweenRepeats = secondsBetweenRepeats
  beacon.nextRun = timer.getTime() + firstRunDelay
  beacon.frequencies = frequencies
  beacon.modulations = modulations
  beacon.coalition = coalition
  beacon.message = message
  beacon.mp3 = mp3

  veaf.loggers.get(veafRadio.Id):debug(string.format("adding beacon %s", tostring(name)))
  veafRadio.beacons[name:lower()] = beacon
end

function veafRadio._runBeacons()
  --veaf.loggers.get(veafRadio.Id):trace("_runBeacons()")

  local now = timer.getTime()
  --veaf.loggers.get(veafRadio.Id):debug(string.format("now = %s", tostring(now)))
  for name, beacon in pairs(veafRadio.beacons) do
    --veaf.loggers.get(veafRadio.Id):trace(string.format("checking %s supposed to run at %s", tostring(beacon.name), tostring(beacon.nextRun)))
    if beacon.nextRun <= now then
      --veaf.loggers.get(veafRadio.Id):trace(string.format("running beacon %s", tostring(name)))
      if beacon.message then
        veafRadio.transmitMessage(beacon.message, beacon.frequencies, beacon.modulations, beacon.name, beacon.coalition, nil, true)
      elseif beacon.mp3 then
        veafRadio.playToRadio(beacon.mp3, beacon.frequencies, beacon.modulations, beacon.name, beacon.coalition, nil, true)
      end
      beacon.nextRun = now + beacon.secondsBetweenRepeats
    end
  end

  --veaf.loggers.get(veafRadio.Id):trace(string.format("rescheduling in %s seconds", tostring(veafRadio.BEACONS_SCHEDULE)))
  mist.scheduleFunction(veafRadio._runBeacons, {}, timer.getTime() + veafRadio.BEACONS_SCHEDULE)
end
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- radio utilities
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- transmit a radio message or play a mp3 file via SRS
function veafRadio._transmitViaSRS(message, file, frequencies, modulations, name, coalition, eventPos)
  veaf.loggers.get(veafRadio.Id):debug(
    "transmitMessage(name=%s, coalition=%s, frequencies=%s, modulations=%s, message=%s, file=%s)",
    veaf.lp(name),
    veaf.lp(coalition),
    veaf.lp(frequencies),
    veaf.lp(modulations),
    veaf.lp(message),
    veaf.lp(file)
  )
  local posOption = ""
  if eventPos then
    veaf.loggers.get(veafRadio.Id):trace(string.format("eventPos=%s", veaf.p(eventPos)))
    local lat, lon, alt = coord.LOtoLL(eventPos)
    posOption = string.format("-L %d -O %d -A %d", lat, lon, alt)
  end

  local contentOption = ""
  if message then
    contentOption = string.format('-t "%s"', message)
  elseif file then
    contentOption = string.format('-i "%s"', file)
  else
    veaf.loggers.get(veafRadio.Id):error("no message nor file for veafRadio._transmitViaSRS()!")
    return
  end

  local l_os = os
  if not l_os and SERVER_CONFIG and SERVER_CONFIG.getModule then
    l_os = SERVER_CONFIG.getModule("os")
  end

  if l_os and STTS then
    local cmd = string.format(
      'start /min "%s" "%s\\%s" %s -f %s -m %s -c %s -p %s -n "%s" %s',
      STTS.DIRECTORY,
      STTS.DIRECTORY,
      STTS.EXECUTABLE,
      contentOption,
      frequencies,
      modulations,
      coalition,
      STTS.SRS_PORT,
      name,
      posOption
    )
    veaf.loggers.get(veafRadio.Id):trace(string.format("executing os command %s", cmd))
    local result = l_os.execute(cmd)
    if result == nil then
      veaf.loggers.get(veafRadio.Id):warn(string.format("Nil result after executing os command %s", cmd))
    end
    return result
  end
end

-- transmit a radio message via SRS
function veafRadio.transmitMessage(message, frequencies, modulations, name, coalition, eventPos, quiet)
  veaf.loggers.get(veafRadio.Id):debug(
    "transmitMessage(name=%s, coalition=%s, frequencies=%s, modulations=%s, message=%s)",
    veaf.lp(name),
    veaf.lp(coalition),
    veaf.lp(frequencies),
    veaf.lp(modulations),
    veaf.lp(message)
  )
  if eventPos then
    veaf.loggers.get(veafRadio.Id):trace(string.format("eventPos=%s", veaf.p(eventPos)))
  end

  veafRadio._transmitViaSRS(message, nil, frequencies, modulations, name, coalition, eventPos)

  if not quiet and coalition then
    trigger.action.outTextForCoalition(coalition, string.format("%s (%s) : %s", name, frequencies, message), 30)
  end
end

-- play a MP3 file via SRS
function veafRadio.playToRadio(pathToMP3, frequencies, modulations, name, coalition, eventPos, quiet)
  veaf.loggers.get(veafRadio.Id):debug(
    "playToRadio(name=%s, coalition=%s, frequencies=%s, modulations=%s, pathToMP3=%s)",
    veaf.lp(name),
    veaf.lp(coalition),
    veaf.lp(frequencies),
    veaf.lp(modulations),
    veaf.lp(pathToMP3)
  )
  if eventPos then
    veaf.loggers.get(veafRadio.Id):trace(string.format("eventPos=%s", veaf.p(eventPos)))
  end

  veafRadio._transmitViaSRS(nil, pathToMP3, frequencies, modulations, name, coalition, eventPos)

  if not quiet and coalition then
    trigger.action.outTextForCoalition(coalition, veaf.t("radio.playing_format", name, frequencies, pathToMP3), 30)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- user menus
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRadio.createUserMenu(configuration, groupId)
  veaf.loggers.get(veafRadio.Id):debug("veafRadio.createUserMenu(groupId=%s, configuration=%s)", veaf.lp(groupId), veaf.lp(configuration))

  -- Accept a DCS group NAME (string) as well as a numeric group id. YAML-declared
  -- menus reference the Mission Master group by name (ADR 0011); resolve it to an
  -- id here. An unknown name falls back to a global menu (logged, not fatal).
  if type(groupId) == "string" then
    local group = Group.getByName(groupId)
    if group then
      groupId = group:getID()
    else
      veaf.loggers.get(veafRadio.Id):warn("createUserMenu: no group named %s, menu will be global", veaf.p(groupId))
      groupId = nil
    end
  end

  local function _recursivelyCreateMenu(configuration, parentMenu)
    veaf.loggers
      .get(veafRadio.Id)
      :trace("_recursivelyCreateMenu(configuration=%s, parentMenu=%s)", veaf.lp(configuration), veaf.lp(parentMenu))
    local result

    for _, item in pairs(configuration) do
      local itemType = item[1]
      veaf.loggers.get(veafRadio.Id):trace("itemType = [%s]", veaf.lp(itemType))
      local name = item[2]
      veaf.loggers.get(veafRadio.Id):trace("name = [%s]", veaf.lp(name))
      if itemType == "menu" then
        -- this is a menu with a content
        local content = item[3]
        veaf.loggers.get(veafRadio.Id):trace("content = [%s]", veaf.lp(content))

        veaf.loggers.get(veafRadio.Id):trace("creating menu name=%s", veaf.lp(name))
        if groupId ~= nil then
          result = missionCommands.addSubMenuForGroup(groupId, name, parentMenu)
        else
          result = missionCommands.addSubMenu(name, parentMenu)
        end
        -- recurse if needed
        if content ~= nil and #content > 0 then
          _recursivelyCreateMenu(content, result)
        end
      else
        -- this is a command with a function
        local aFunction = item[3]
        veaf.loggers.get(veafRadio.Id):trace("aFunction = [%s]", veaf.lp(aFunction))
        local parameters = item[4]
        veaf.loggers.get(veafRadio.Id):trace("parameters = [%s]", veaf.lp(parameters))

        veaf.loggers.get(veafRadio.Id):trace("creating command name=%s", veaf.lp(name))
        if groupId ~= nil then
          missionCommands.addCommandForGroup(groupId, name, parentMenu, aFunction, parameters)
        else
          missionCommands.addCommand(name, parentMenu, aFunction, parameters)
        end
      end
    end
  end

  _recursivelyCreateMenu(configuration, nil)
end

-- helper functions for user menus
local spawnCapFunction = function() end

function veafRadio.menu(name, ...)
  return {
    "menu",
    name,
    { ... },
  }
end

function veafRadio.command(name, aFunction, parameters)
  return {
    "command",
    name,
    aFunction,
    parameters,
  }
end

function veafRadio.mainmenu(...)
  return { ... }
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRadio.initialize(skipHelpMenus, dontCreateMenus)
  -- Find the path of the SRS radio configuration script
  -- We're going to need it to define :
  --  STTS.DIRECTORY
  --- STTS.SRS_PORT
  local srsConfigPath = nil

  local l_lfs = lfs
  if not l_lfs and SERVER_CONFIG and SERVER_CONFIG.getModule then
    l_lfs = SERVER_CONFIG.getModule("lfs")
  end

  if l_lfs then
    srsConfigPath = l_lfs.writedir() .. "\\DCS-SimpleRadio-Standalone\\SRS_for_scripting_config.lua"
    veaf.loggers.get(veafRadio.Id):debug(string.format("srsConfigPath = %s", tostring(srsConfigPath)))
    --local test = l_lfs.currentdir()
    --veaf.loggers.get(veafRadio.Id):debug(string.format("test = %s", tostring(test)))
    if srsConfigPath then
      local fileAttrs = l_lfs.attributes(srsConfigPath)
      if fileAttrs then
        -- execute the script
        local file = loadfile(srsConfigPath)
        if file then
          file()
          veaf.loggers.get(veafRadio.Id):info("SRS configuration file loaded")
          if STTS and veaf.isEnabled("stts") then
            STTS.MP3_FOLDER = l_lfs.writedir() .. "\\..\\..\\Music"
            veaf.loggers.get(veafRadio.Id):trace(string.format("STTS.SRS_PORT = %s", tostring(STTS.SRS_PORT)))
            veaf.loggers.get(veafRadio.Id):trace(string.format("STTS.DIRECTORY = %s", tostring(STTS.DIRECTORY)))
            veaf.loggers.get(veafRadio.Id):trace(string.format("STTS.EXECUTABLE = %s", tostring(STTS.EXECUTABLE)))
          end
        else
          veaf.loggers.get(veafRadio.Id):warn(string.format("Error while loading SRS configuration file [%s]", srsConfigPath))
        end
      else
        veaf.loggers
          .get(veafRadio.Id)
          :debug(string.format("SRS configuration file not found [%s] - SRS integration disabled", srsConfigPath))
      end
    end
  end

  veafRadio.skipHelpMenus = skipHelpMenus or false
  veafRadio.dontCreateMenus = dontCreateMenus or false

  -- Build the initial radio menu
  veafRadio.refreshRadioMenu(false)
  --mist.scheduleFunction(veafRadio._refreshRadioMenu,{},timer.getTime()+15) --TODO check if this is still needed (commented out when added the BIRTH event handler)

  -- add marker change event handler
  veafCommands.registerCommandHandler(function(pos, event, bypass, fromMarker, groups, route)
    -- veafRadio uses raw (non-inverted) coalition — pass event.coalition directly
    return veafRadio.executeCommand(pos, event.text, event.coalition, bypass)
  end, veafCommands.PRIORITY_RADIO)

  -- add human birth event handler
  veafEventHandler.addCallback("veafRadio.eventHandler", { "S_EVENT_BIRTH", "S_EVENT_PLAYER_ENTER_UNIT" }, veafRadio.onBirthEvent)

  -- start the beacons
  veafRadio._runBeacons()
end

veaf.loggers.get(veafRadio.Id):info(veaf.loggers.get(veafRadio.Id):getVersionInfo())

veaf.registerModule(veafRadio.Id, function()
  local cfg = veaf.getConfig(veafRadio.Id)
  veafRadio.initialize(cfg.skipHelpMenus, cfg.dontCreateMenus)
end, { enable = true, skipHelpMenus = false, dontCreateMenus = false }, 30)
