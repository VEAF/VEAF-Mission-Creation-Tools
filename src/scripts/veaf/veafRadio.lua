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

--- Version.
veafRadio.Version = "1.2.0"

-- trace level, specific to this module
--veafRadio.LogLevel = "trace"

veaf.loggers.new(veafRadio.Id, veafRadio.LogLevel)

veafRadio.RadioMenuName = "VEAF"

-- constants used to determine how the radio menu is set up
veafRadio.USAGE_ForAll   = 0
veafRadio.USAGE_ForGroup = 1
veafRadio.USAGE_ForUnit  = 2

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
  if not unitName then
    return
  end
  veaf.loggers.get(veafRadio.Id):trace("unitName=%s", unitName)
  if mist.DBs.humansByName[unitName] then -- it's a human unit
    veaf.loggers.get(veafRadio.Id):trace("veafRadio.humanUnits=%s", veafRadio.humanUnits)
    veaf.loggers.get(veafRadio.Id):trace("unitName %s is a human unit", unitName)
    if not veafRadio.humanUnits[unitName] then
      -- add the unit to the human units list and rebuild the radio menu
      veaf.loggers.get(veafRadio.Id):trace("Adding human unit %s", unitName)
      local groupId = event and event.initiator and event.initiator.unitGroupId
      local callsign = event and event.initiator and event.initiator.unitPilotName
      if not callsign then
        callsign = event and event.initiator and event.initiator.unitCallsign
      end
      local unitObject = {name=unitName, spawned=true, groupId=groupId, callsign=callsign}
      veafRadio.humanUnits[unitName] = {}
      veafRadio.humanUnits[unitName].spawned = true
      veafRadio.humanUnits[unitName] = unitObject

      veaf.loggers.get(veafRadio.Id):trace("veafRadio.humanGroups=%s", veafRadio.humanGroups)
      if not veafRadio.humanGroups[groupId] then
        veafRadio.humanGroups[groupId] = {}
        veafRadio.humanGroups[groupId].callsigns = {}
        veafRadio.humanGroups[groupId].units = {}
      end
      
      table.insert(veafRadio.humanGroups[groupId].callsigns, callsign)
      veaf.loggers.get(veafRadio.Id):trace("veafRadio.humanGroups=%s", veafRadio.humanGroups)
      veafRadio.humanGroups[groupId].units[callsign] = unitObject

      -- sort callsigns for each group
      for _, groupData in pairs(veafRadio.humanGroups) do
        table.sort(groupData.callsigns)
      end

      -- refresh the radio menu
      veaf.loggers.get(veafRadio.Id):debug("refreshRadioMenu() following event %s of human unit %s", event.type and event.type.name, unitName)
      veafRadio.refreshRadioMenu()
    end
  end
end


--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafRadio.onEventMarkChange(eventPos, event)
  if veafRadio.executeCommand(eventPos, event.text, event.coalition) then

    -- Delete old mark.
    veaf.loggers.get(veafRadio.Id):trace(string.format("Removing mark # %d.", event.idx))
    trigger.action.removeMark(event.idx)
  end
end

function veafRadio.executeCommand(eventPos, eventText, eventCoalition, bypassSecurity)
  veaf.loggers.get(veafRadio.Id):trace(string.format("veafRadio.executeCommand(%s)", eventText))

  -- Check if marker has a text and the veafRadio.keyphrase keyphrase.
  if eventText ~= nil and eventText:lower():find(veafRadio.Keyphrase) then

    -- Analyse the mark point text and extract the keywords.
    local options = veafRadio.markTextAnalysis(eventText)

    if options then
      veaf.loggers.get(veafRadio.Id):trace(string.format("options.path=%s",veaf.p(options.path)))
      -- Check options commands
      if options.transmit and options.message and options.frequencies and options.name then
        -- transmit a radio message via SRS
        veafRadio.transmitMessage(options.message, options.frequencies, options.modulations, options.name, eventCoalition, eventPos, options.quiet)
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
  veaf.loggers.get(veafRadio.Id):trace("parameters="..veaf.p(parameters))
  local realMethod, realParameters = veaf.safeUnpack(parameters)
  veaf.loggers.get(veafRadio.Id):trace("realMethod="..veaf.p(realMethod))
  veaf.loggers.get(veafRadio.Id):trace("realParameters="..veaf.p(realParameters))
  if veafSecurity.isAuthenticated() then
    realMethod(realParameters)
  else
    veaf.loggers.get(veafRadio.Id):error("Your radio has to be authenticated for '+'' commands")
    trigger.action.outText("Your radio has to be authenticated for '+'' commands", 5)
  end
end

--- Refresh the radio menu, based on stored information
--- This is called from another method that has first changed the radio menu information by adding or removing elements
function veafRadio.refreshRadioMenu(dontDelay)
  veaf.loggers.get(veafRadio.Id):debug(string.format("veafRadio.refreshRadioMenu()"))

  -- delay the refresh if possible
  if not dontDelay then
    if not veafRadio.refreshRadioMenuDelayedScheduling then
      veafRadio.refreshRadioMenuDelayedScheduling = mist.scheduleFunction(veafRadio._refreshRadioMenu,{},timer.getTime()+veafRadio.refreshRadioMenu_DELAY)
    end
  else
    veafRadio._refreshRadioMenu()
  end
end

--- actually refresh the radio menu, based on stored information
function veafRadio._refreshRadioMenu()
  veaf.loggers.get(veafRadio.Id):debug(string.format("veafRadio._refreshRadioMenu()"))
  veafRadio.refreshRadioMenuDelayedScheduling = nil

  -- completely delete the dcs radio menu
  veaf.loggers.get(veafRadio.Id):trace("completely delete the dcs radio menu")
  if veafRadio.radioMenu.dcsRadioMenu then
    missionCommands.removeItem(veafRadio.radioMenu.dcsRadioMenu)
  else
    veaf.loggers.get(veafRadio.Id):info("_refreshRadioMenu() first time : no DCS radio menu yet")
  end

  -- create all the commands and submenus in the dcs radio menu
  veaf.loggers.get(veafRadio.Id):trace("create all the commands and submenus in the dcs radio menu")
  veafRadio.refreshRadioSubmenu(nil, veafRadio.radioMenu)

end

function veafRadio._addCommand(groupId, title, menu, command, parameters)
  if not command.method then
    veaf.loggers.get(veafRadio.Id):error("ERROR - missing method for command " .. title)
  end
  local _title = title
  local _method = command.method
  local _parameters = parameters
  if command.isSecured then
    veaf.loggers.get(veafRadio.Id):trace("adding secured command")

    _method = veafRadio._proxyMethod
    _parameters = {command.method, _parameters}

    if veafSecurity.isAuthenticated() then
      _title = "-" .. title
    else
      _title = "+" .. title
    end
  end

  veaf.loggers.get(veafRadio.Id):trace("_title=%s", veaf.p(_title))
  veaf.loggers.get(veafRadio.Id):trace("_parameters=%s", veaf.p(_parameters))

  if groupId then
    veaf.loggers.get(veafRadio.Id):trace("adding for group %s command %s",groupId or "", _title or "")
    missionCommands.addCommandForGroup(groupId, _title, menu, _method, _parameters)
  else
    veaf.loggers.get(veafRadio.Id):trace("adding for all command %s",_title or "")
    missionCommands.addCommand(_title, menu, _method, _parameters)
  end

end

function veafRadio.refreshRadioSubmenu(parentRadioMenu, radioMenu)
  veaf.loggers.get(veafRadio.Id):debug("veafRadio.refreshRadioSubmenu %s", veaf.p(veaf.ifnn(radioMenu, "title")))

  if not radioMenu or not radioMenu.title then
    return
  end

  -- create the radio menu in DCS
  if parentRadioMenu then
    radioMenu.dcsRadioMenu = missionCommands.addSubMenu(radioMenu.title, parentRadioMenu.dcsRadioMenu)
  else
    radioMenu.dcsRadioMenu = missionCommands.addSubMenu(radioMenu.title)
  end

  -- create the commands in the radio menu
  for count = 1,#radioMenu.commands do
    local command = radioMenu.commands[count]
    veaf.loggers.get(veafRadio.Id):trace(string.format("command=%s",veaf.p(command)))

    if not command.usage then
      command.usage = veafRadio.USAGE_ForAll
    end
    if command.usage ~= veafRadio.USAGE_ForAll then

      -- build menu for each player group
      local alreadyDoneGroups = {}
      for groupId, groupData in pairs(veafRadio.humanGroups) do
        veaf.loggers.get(veafRadio.Id):trace(string.format("groupId=%s",veaf.p(groupId)))
        for _, callsign in pairs(groupData.callsigns) do
          veaf.loggers.get(veafRadio.Id):trace(string.format("callsign=%s",veaf.p(callsign)))
          local unitData = groupData.units[callsign]
          local unitName = unitData.name
          veaf.loggers.get(veafRadio.Id):trace(string.format("unitName=%s",veaf.p(unitName)))
          local humanUnit =  veafRadio.humanUnits[unitName]
          veaf.loggers.get(veafRadio.Id):trace(string.format("humanUnit=%s",veaf.p(humanUnit)))
          if humanUnit and humanUnit.spawned then
            veaf.loggers.get(veafRadio.Id):debug(string.format("add radio command for player unit %s",veaf.p(unitName)))
            -- add radio command by player unit or group
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
              veafRadio._addCommand(groupId, _title, radioMenu.dcsRadioMenu, command, parameters)
            end
            alreadyDoneGroups[groupId] = true
          end
        end
      end
    else
      veafRadio._addCommand(nil, command.title, radioMenu.dcsRadioMenu, command, command.parameters)
    end
  end

  -- recurse to create the submenus in the radio menu
  for count = 1,#radioMenu.subMenus do
    local subMenu = radioMenu.subMenus[count]
    veafRadio.refreshRadioSubmenu(radioMenu, subMenu)
  end

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
  veaf.loggers.get(veafRadio.Id):debug(string.format("_addCommandToSubmenu(%s)",veaf.p(title)))
  local command = {}
  command.title = title
  command.method = method
  command.parameters = parameters
  command.isSecured = isSecured
  command.usage = usage
  if command.usage == nil then command.usage = veafRadio.USAGE_ForAll end
  local menu = veafRadio.radioMenu
  if radioMenu then
    menu = radioMenu
  end

  -- add command to menu
  table.insert(menu.commands, command)

  return command
end

function veafRadio.delCommand(radioMenu, title)
  for count = 1,#radioMenu.commands do
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

function veafRadio.addSubMenu(title, radioMenu)

  local subMenu = {}
  subMenu.title = title
  subMenu.dcsRadioMenu = nil
  subMenu.subMenus = {}
  subMenu.commands = {}

  local menu = veafRadio.radioMenu
  if radioMenu then
    menu = radioMenu
  end

  -- add subMenu to menu
  table.insert(menu.subMenus, subMenu)

  return subMenu
end

function veafRadio.clearSubmenu(subMenu)
  if not subMenu then
    veaf.loggers.get(veafRadio.Id):error("veafRadio.clearSubmenu() subMenu parameter is nil !")
    return
  end
  veaf.loggers.get(veafRadio.Id):debug(string.format("veafRadio.clearSubmenu(%s)",subMenu.title))
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
  end);
end

-- build a paginated submenu (internal paginating method)
local function _buildRadioMenuPage(menu, titles, elementsByTitle, addCommandToSubmenuMethod, pageSize, startIndex)
  veaf.loggers.get(veafRadio.Id):trace(string.format("_buildRadioMenuPage(pageSize=%s, startIndex=%s)",tostring(pageSize), tostring(startIndex)))

  local titlesCount = #titles
  veaf.loggers.get(veafRadio.Id):trace(string.format("titlesCount = %d",titlesCount))

  local pageSize = pageSize
  if not pageSize then
    pageSize = 10
  end

  local endIndex = titlesCount
  if endIndex - startIndex >= pageSize then
    endIndex = startIndex + pageSize - 2
  end
  veaf.loggers.get(veafRadio.Id):trace(string.format("endIndex = %d",endIndex))
  veaf.loggers.get(veafRadio.Id):trace(string.format("adding commands from %d to %d",startIndex, endIndex))
  for index = startIndex, endIndex do
    local title = titles[index]
    veaf.loggers.get(veafRadio.Id):trace(string.format("titles[%d] = %s",index, title))
    local element = elementsByTitle[title]
    addCommandToSubmenuMethod(menu, title, element)
  end
  if endIndex < titlesCount then
    veaf.loggers.get(veafRadio.Id):trace("adding next page menu")
    local nextPageMenu = veafRadio.addSubMenu("Next page", menu)
    _buildRadioMenuPage(nextPageMenu, titles, elementsByTitle, addCommandToSubmenuMethod, 10, endIndex+1)
  end
end

-- build a paginated submenu (main method)
function veafRadio.addPaginatedRadioElements(radioMenu, addCommandToSubmenuMethod, elements, titleAttribute, sortAttribute)
  veaf.loggers.get(veafRadio.Id):trace(string.format("veafRadio.addPaginatedRadioElements() : elements=%s",veaf.p(elements)))

  if not addCommandToSubmenuMethod then
    veaf.loggers.get(veafRadio.Id):error("veafRadio.addPaginatedRadioMenu : addCommandToSubmenuMethod is mandatory !")
    return
  end

  local pageSize = 10 - #radioMenu.commands

  local sortedElements = {}
  local sortAttribute = sortAttribute or "sort"
  local titleAttribute = titleAttribute or "title"
  for name, element in pairs(elements) do
    local sortValue = element[sortAttribute]
    if not sortValue then sortValue = name end
    table.insert(sortedElements, {element=element, sort=sortValue, title=name})
  end
  local compare = function(a,b)
    if not(a) then
      a = {}
    end
    if not(a["sort"]) then
      a["sort"] = 0
    end
    if not(b) then
      b = {}
    end
    if not(b["sort"]) then
      b["sort"] = 0
    end

    return a["sort"] < b["sort"]
  end
  table.sort(sortedElements, compare)

  local sortedTitles = {}
  local elementsByTitle = {}
  for i = 1, #sortedElements do
    local title = sortedElements[i].element[titleAttribute]
    if not title then title = sortedElements[i].title end
    table.insert(sortedTitles, title)
    elementsByTitle[title] = sortedElements[i].element
  end
  veaf.loggers.get(veafRadio.Id):trace("sortedTitles="..veaf.p(sortedTitles))

  _buildRadioMenuPage(radioMenu, sortedTitles, elementsByTitle, addCommandToSubmenuMethod, pageSize, 1)
  --veafRadio.refreshRadioMenu()
end

-- build a paginated submenu (main method)
function veafRadio.addPaginatedRadioMenu(title, radioMenu, addCommandToSubmenuMethod, elements, titleAttribute, sortAttribute)
  veaf.loggers.get(veafRadio.Id):trace(string.format("veafRadio.addPaginatedRadioMenu(title=%s)",title))

  local firstPagePath = veafRadio.addSubMenu(title, radioMenu)
  veafRadio.addPaginatedRadioElements(firstPagePath, addCommandToSubmenuMethod, elements, titleAttribute, sortAttribute)
  return firstPagePath
end

function veafRadio.getHumanUnitOrWingman(unitName)
  local result = Unit.getByName(unitName)
  if not result then
    local unitData = veafRadio.humanUnits[unitName]
    veaf.loggers.get(veafRadio.Id):trace(string.format("unitData=%s",veaf.p(unitData)))
    if unitData and unitData.groupId then
      local mistGroup = mist.DBs.groupsById[unitData.groupId]
      veaf.loggers.get(veafRadio.Id):trace(string.format("mistGroup=%s",veaf.p(mistGroup)))
      if mistGroup then
        local group = Group.getByName(mistGroup.groupName)
        if group then
          veaf.loggers.get(veafRadio.Id):trace(string.format("group=%s",veaf.p(group)))
          veaf.loggers.get(veafRadio.Id):trace(string.format("group:getUnits()=%s",veaf.p(group:getUnits())))
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
    veaf.loggers.get(veafRadio.Id):trace(string.format("result=%s",veaf.p(result)))
    veaf.loggers.get(veafRadio.Id):trace(string.format("result:getName()=%s",veaf.p(result:getName())))
  end
  return result
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- radio beacons
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRadio.startBeacon(name, firstRunDelay, secondsBetweenRepeats, frequencies, modulations, message, mp3, coalition)
  veaf.loggers.get(veafRadio.Id):debug("startBeacon(name=%s, firstRunDelay=%s, secondsBetweenRepeats=%s, coalition=%s, frequencies=%s, modulations=%s, message=%s, mp3=%s)", veaf.p(name), veaf.p(firstRunDelay), veaf.p(secondsBetweenRepeats), veaf.p(coalition), veaf.p(frequencies), veaf.p(modulations), veaf.p(message), veaf.p(mp3))

  local beacon = veafRadio.beacons[name:lower()]
  if not beacon then beacon = {} end
  beacon.name = name
  beacon.secondsBetweenRepeats = secondsBetweenRepeats
  beacon.nextRun = timer.getTime()+firstRunDelay
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
  mist.scheduleFunction(veafRadio._runBeacons,{},timer.getTime()+veafRadio.BEACONS_SCHEDULE)
end
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- radio utilities
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- transmit a radio message or play a mp3 file via SRS
function veafRadio._transmitViaSRS(message, file, frequencies, modulations, name, coalition, eventPos)
  veaf.loggers.get(veafRadio.Id):debug("transmitMessage(name=%s, coalition=%s, frequencies=%s, modulations=%s, message=%s, file=%s)", veaf.p(name), veaf.p(coalition), veaf.p(frequencies), veaf.p(modulations), veaf.p(message), veaf.p(file))
  local posOption = ""
  if eventPos then
    veaf.loggers.get(veafRadio.Id):trace(string.format("eventPos=%s",veaf.p(eventPos)))
    local lat, lon, alt = coord.LOtoLL(eventPos)
    posOption = string.format("-L %d -O %d -A %d", lat, lon, alt)
  end

  local contentOption = ""
  if message then
    contentOption = string.format("-t \"%s\"", message)
  elseif file then
    contentOption = string.format("-i \"%s\"", file)
  else
    veaf.loggers.get(veafRadio.Id):error("no message nor file for veafRadio._transmitViaSRS()!")
    return
  end

  local l_os = os
  if not l_os and SERVER_CONFIG and SERVER_CONFIG.getModule then
    l_os = SERVER_CONFIG.getModule("os")
  end

  if l_os and STTS then
    local cmd = string.format("start /min \"%s\" \"%s\\%s\" %s -f %s -m %s -c %s -p %s -n \"%s\" %s", STTS.DIRECTORY, STTS.DIRECTORY, STTS.EXECUTABLE, contentOption, frequencies, modulations, coalition, STTS.SRS_PORT, name, posOption)
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
  veaf.loggers.get(veafRadio.Id):debug("transmitMessage(name=%s, coalition=%s, frequencies=%s, modulations=%s, message=%s)", veaf.p(name), veaf.p(coalition), veaf.p(frequencies), veaf.p(modulations), veaf.p(message))
  if eventPos then
    veaf.loggers.get(veafRadio.Id):trace(string.format("eventPos=%s",veaf.p(eventPos)))
  end

  veafRadio._transmitViaSRS(message, nil, frequencies, modulations, name, coalition, eventPos)

  if not quiet and coalition then
    trigger.action.outTextForCoalition(coalition, string.format("%s (%s) : %s", name, frequencies, message), 30)
  end
end

-- play a MP3 file via SRS
function veafRadio.playToRadio(pathToMP3, frequencies, modulations, name, coalition, eventPos, quiet)
  veaf.loggers.get(veafRadio.Id):debug("playToRadio(name=%s, coalition=%s, frequencies=%s, modulations=%s, pathToMP3=%s)", veaf.p(name), veaf.p(coalition), veaf.p(frequencies), veaf.p(modulations), veaf.p(pathToMP3))
  if eventPos then
    veaf.loggers.get(veafRadio.Id):trace(string.format("eventPos=%s",veaf.p(eventPos)))
  end

  veafRadio._transmitViaSRS(nil, pathToMP3, frequencies, modulations, name, coalition, eventPos)

  if not quiet and coalition then
    trigger.action.outTextForCoalition(coalition, string.format("%s (%s) : playing %s", name, frequencies, pathToMP3), 30)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- user menus
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRadio.createUserMenu(configuration, groupId)
  veaf.loggers.get(veafRadio.Id):debug("veafRadio.createUserMenu(groupId=%s, configuration=%s)",veaf.p(groupId), veaf.p(configuration))

  local function _recursivelyCreateMenu(configuration, parentMenu)
    veaf.loggers.get(veafRadio.Id):trace("_recursivelyCreateMenu(configuration=%s, parentMenu=%s)",veaf.p(configuration), veaf.p(parentMenu))
    local result

    for _, item in pairs(configuration) do
      local itemType = item[1]
      veaf.loggers.get(veafRadio.Id):trace("itemType = [%s]",veaf.p(itemType))
      local name = item[2]
      veaf.loggers.get(veafRadio.Id):trace("name = [%s]",veaf.p(name))
      if itemType == "menu" then
        -- this is a menu with a content
        local content = item[3]
        veaf.loggers.get(veafRadio.Id):trace("content = [%s]",veaf.p(content))

        veaf.loggers.get(veafRadio.Id):trace("creating menu name=%s",veaf.p(name))
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
        veaf.loggers.get(veafRadio.Id):trace("aFunction = [%s]",veaf.p(aFunction))
        local parameters = item[4]
        veaf.loggers.get(veafRadio.Id):trace("parameters = [%s]",veaf.p(parameters))

        veaf.loggers.get(veafRadio.Id):trace("creating command name=%s",veaf.p(name))
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
local spawnCapFunction = function () end


function veafRadio.menu(name, ...)
  return {
    "menu", name, {...}
  }
end

function veafRadio.command(name, aFunction, parameters)
  return {
    "command", name, aFunction, parameters
  }
end

function veafRadio.mainmenu(...)
  return { ... }
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRadio.initialize(skipHelpMenus)
  -- Find the path of the SRS radio configuration script
  -- We're going to need it to define :
  --  STTS.DIRECTORY
  --- STTS.SRS_PORT
  local srsConfigPath=nil

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
      -- execute the script
      local file = loadfile(srsConfigPath)
      if file then
        file()
        veaf.loggers.get(veafRadio.Id):info("SRS configuration file loaded")
        if STTS then
          STTS.MP3_FOLDER = l_lfs.writedir() .."\\..\\..\\Music"
          veaf.loggers.get(veafRadio.Id):trace(string.format("STTS.SRS_PORT = %s", tostring(STTS.SRS_PORT)))
          veaf.loggers.get(veafRadio.Id):trace(string.format("STTS.DIRECTORY = %s", tostring(STTS.DIRECTORY)))
          veaf.loggers.get(veafRadio.Id):trace(string.format("STTS.EXECUTABLE = %s", tostring(STTS.EXECUTABLE)))
        end
      else
        veaf.loggers.get(veafRadio.Id):warn(string.format("Error while loading SRS configuration file [%s]",srsConfigPath))
      end
    end
  end

  veafRadio.skipHelpMenus = skipHelpMenus or false

  -- Build the initial radio menu
  veafRadio.refreshRadioMenu(false)
  --mist.scheduleFunction(veafRadio._refreshRadioMenu,{},timer.getTime()+15) --TODO check if this is still needed (commented out when added the BIRTH event handler)

  -- add marker change event handler
  veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafRadio.onEventMarkChange)

  -- add human birth event handler
  veafEventHandler.addCallback("veafRadio.eventHandler", {"S_EVENT_BIRTH", "S_EVENT_PLAYER_ENTER_UNIT"}, veafRadio.onBirthEvent)

  -- start the beacons
  veafRadio._runBeacons()
end

veaf.loggers.get(veafRadio.Id):info(string.format("Loading version %s", veafRadio.Version))

