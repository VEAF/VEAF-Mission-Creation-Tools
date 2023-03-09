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
veafRadio.Version = "1.11.1"

-- trace level, specific to this module
--veafRadio.LogLevel = "trace"

veaf.loggers.new(veafRadio.Id, veafRadio.LogLevel)

veafRadio.RadioMenuName = "VEAF"

-- constants used to determine how the radio menu is set up
veafRadio.USAGE_ForAll   = 0
veafRadio.USAGE_ForGroup = 1
veafRadio.USAGE_ForUnit  = 2

-- maximum size for radio menu
veafRadio.MAXIMUM_SIZE = 99999 -- 4200

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
              veafRadio.transmitMessage(options.message, options.frequencies, options.modulations, options.volume, options.name, eventCoalition, eventPos, options.quiet)
              return true
          elseif options.playmp3 and options.path and options.frequencies and options.name then
            -- play a MP3 file via SRS
            veafRadio.playToRadio(options.path, options.frequencies, options.modulations, options.volume, options.name, eventCoalition, eventPos, options.quiet)
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
  switch.volume = "1.0"
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
    elseif key:lower() == "vol" or key:lower() == "volume" then
      -- Set volume.
      veaf.loggers.get(veafRadio.Id):trace(string.format("Keyword volume = %s", tostring(val)))
      switch.volume = val
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

--- Event handler.
veafRadio.eventHandler = {}

--- Handle world events.
function veafRadio.eventHandler:onEvent(Event)
    local EVENTS = {
  [0] =  "S_EVENT_INVALID",
  [1] =  "S_EVENT_SHOT",
  [2] =  "S_EVENT_HIT",
  [3] =  "S_EVENT_TAKEOFF",
  [4] =  "S_EVENT_LAND",
  [5] =  "S_EVENT_CRASH",
  [6] =  "S_EVENT_EJECTION",
  [7] =  "S_EVENT_REFUELING",
  [8] =  "S_EVENT_DEAD",
  [9] =  "S_EVENT_PILOT_DEAD",
  [10] =  "S_EVENT_BASE_CAPTURED",
  [11] =  "S_EVENT_MISSION_START",
  [12] =  "S_EVENT_MISSION_END",
  [13] =  "S_EVENT_TOOK_CONTROL",
  [14] =  "S_EVENT_REFUELING_STOP",
  [15] =  "S_EVENT_BIRTH",
  [16] =  "S_EVENT_HUMAN_FAILURE",
  [17] =  "S_EVENT_DETAILED_FAILURE",
  [18] =  "S_EVENT_ENGINE_STARTUP",
  [19] =  "S_EVENT_ENGINE_SHUTDOWN",
  [20] =  "S_EVENT_PLAYER_ENTER_UNIT",
  [21] =  "S_EVENT_PLAYER_LEAVE_UNIT",
  [22] =  "S_EVENT_PLAYER_COMMENT",
  [23] =  "S_EVENT_SHOOTING_START",
  [24] =  "S_EVENT_SHOOTING_END",
  [25] =  "S_EVENT_MARK_ADDED",
  [26] =  "S_EVENT_MARK_CHANGE",
  [27] =  "S_EVENT_MARK_REMOVED",
  [28] =  "S_EVENT_KILL",
  [29] =  "S_EVENT_SCORE",
  [30] =  "S_EVENT_UNIT_LOST",
  [31] =  "S_EVENT_LANDING_AFTER_EJECTION"}

  local enabledEvents = {
  ["S_EVENT_INVALID"] = false,
  ["S_EVENT_SHOT"] = false,
  ["S_EVENT_HIT"] = false,
  ["S_EVENT_TAKEOFF"] = false,
  ["S_EVENT_LAND"] = false,
  ["S_EVENT_CRASH"] = false,
  ["S_EVENT_EJECTION"] = false,
  ["S_EVENT_REFUELING"] = false,
  ["S_EVENT_DEAD"] = true,
  ["S_EVENT_PILOT_DEAD"] = true,
  ["S_EVENT_BASE_CAPTURED"] = false,
  ["S_EVENT_MISSION_START"] = false,
  ["S_EVENT_MISSION_END"] = false,
  ["S_EVENT_TOOK_CONTROL"] = true,
  ["S_EVENT_REFUELING_STOP"] = false,
  ["S_EVENT_BIRTH"] = true,
  ["S_EVENT_HUMAN_FAILURE"] = false,
  ["S_EVENT_DETAILED_FAILURE"] = false,
  ["S_EVENT_ENGINE_STARTUP"] = false,
  ["S_EVENT_ENGINE_SHUTDOWN"] = false,
  ["S_EVENT_PLAYER_ENTER_UNIT"] = true,
  ["S_EVENT_PLAYER_LEAVE_UNIT"] = true,
  ["S_EVENT_PLAYER_COMMENT"] = true,
  ["S_EVENT_SHOOTING_START"] = false,
  ["S_EVENT_SHOOTING_END"] = false,
  ["S_EVENT_MARK_ADDED"] = false,
  ["S_EVENT_MARK_CHANGE"] = false,
  ["S_EVENT_MARK_REMOVED"] = false,
  ["S_EVENT_KILL"] = false,
  ["S_EVENT_SCORE"] = false,
  ["S_EVENT_UNIT_LOST"] = true,
  ["S_EVENT_LANDING_AFTER_EJECTION"] = false
  }

  -- Only interested in S_EVENT_BIRTH (S_EVENT_PLAYER_ENTER_UNIT is not fired in MP)
  if Event == nil or not(enabledEvents[EVENTS[Event.id]]) then
      return true
  end

  -- Debug output.
  local _unitname = ""
  veaf.loggers.get(veafRadio.Id):trace(string.format("got event %s", veaf.p(EVENTS[Event.id])))
  --veaf.loggers.get(veafRadio.Id):trace(string.format("Event id        = %s", veaf.p(Event.id)))
  --veaf.loggers.get(veafRadio.Id):trace(string.format("Event time      = %s", veaf.p(Event.time)))
  --veaf.loggers.get(veafRadio.Id):trace(string.format("Event idx       = %s", veaf.p(Event.idx)))
  --veaf.loggers.get(veafRadio.Id):trace(string.format("Event coalition = %s", veaf.p(Event.coalition)))
  --veaf.loggers.get(veafRadio.Id):trace(string.format("Event group id  = %s", veaf.p(Event.groupID)))
  if Event.initiator ~= nil then
    _unitname = Event.initiator:getName()
    veaf.loggers.get(veafRadio.Id):trace(string.format("Event ini unit  = %s", veaf.p(_unitname)))
  end
  veaf.loggers.get(veafRadio.Id):trace(string.format("Event text      = \n%s", veaf.p(Event.text)))

  local refreshRadioMenu = false
  -- human unit birth
  if Event.id == world.event.S_EVENT_BIRTH then
    if _unitname and veafRadio.humanUnits[_unitname] then
    -- a human spawned in this slot ! Yay !
    veaf.loggers.get(veafRadio.Id):trace(string.format("a human spawned in this slot: %s", veaf.p(_unitname)))
    veafRadio.humanUnits[_unitname].spawned = true

      -- refresh the radio menu
      refreshRadioMenu = true
    end
  end

  -- human unit death
  if Event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT then

    if _unitname and veafRadio.humanUnits[_unitname] then
      -- it was a human in this slot !
      if veafRadio.humanUnits[_unitname] then
        veafRadio.humanUnits[_unitname].spawned = false
      end

      -- refresh the radio menu
      refreshRadioMenu = true
    end
  end

  if refreshRadioMenu then
    -- refresh the radio menu
    veafRadio.refreshRadioMenu() -- TODO refresh it only for this player ? Is this even possible ?
    veaf.loggers.get(veafRadio.Id):debug(string.format("refreshRadioMenu() following event %s of human unit %s", veaf.p(EVENTS[Event.id]), veaf.p(_unitname)))
  end
end

-- function veafRadio.eventHandler:onEvent(Event)
--   local EVENTS = {
--   [0] =  "S_EVENT_INVALID",
--   [1] =  "S_EVENT_SHOT",
--   [2] =  "S_EVENT_HIT",
--   [3] =  "S_EVENT_TAKEOFF",
--   [4] =  "S_EVENT_LAND",
--   [5] =  "S_EVENT_CRASH",
--   [6] =  "S_EVENT_EJECTION",
--   [7] =  "S_EVENT_REFUELING",
--   [8] =  "S_EVENT_DEAD",
--   [9] =  "S_EVENT_PILOT_DEAD",
--   [10] =  "S_EVENT_BASE_CAPTURED",
--   [11] =  "S_EVENT_MISSION_START",
--   [12] =  "S_EVENT_MISSION_END",
--   [13] =  "S_EVENT_TOOK_CONTROL",
--   [14] =  "S_EVENT_REFUELING_STOP",
--   [15] =  "S_EVENT_BIRTH",
--   [16] =  "S_EVENT_HUMAN_FAILURE",
--   [17] =  "S_EVENT_DETAILED_FAILURE",
--   [18] =  "S_EVENT_ENGINE_STARTUP",
--   [19] =  "S_EVENT_ENGINE_SHUTDOWN",
--   [20] =  "S_EVENT_PLAYER_ENTER_UNIT",
--   [21] =  "S_EVENT_PLAYER_LEAVE_UNIT",
--   [22] =  "S_EVENT_PLAYER_COMMENT",
--   [23] =  "S_EVENT_SHOOTING_START",
--   [24] =  "S_EVENT_SHOOTING_END",
--   [25] =  "S_EVENT_MARK_ADDED",
--   [26] =  "S_EVENT_MARK_CHANGE",
--   [27] =  "S_EVENT_MARK_REMOVED",
--   [28] =  "S_EVENT_KILL",
--   [29] =  "S_EVENT_SCORE",
--   [30] =  "S_EVENT_UNIT_LOST",
--   [31] =  "S_EVENT_LANDING_AFTER_EJECTION"}

--   local _unitname = ""
--   veaf.loggers.get(veafRadio.Id):info("GOT AN EVENT")
--   veaf.loggers.get(veafRadio.Id):info(string.format("Event id        = %s - %s", tostring(Event.id), EVENTS[Event.id]))
--   veaf.loggers.get(veafRadio.Id):info(string.format("Event time      = %s", tostring(Event.time)))
--   veaf.loggers.get(veafRadio.Id):info(string.format("Event idx       = %s", tostring(Event.idx)))
--   veaf.loggers.get(veafRadio.Id):info(string.format("Event coalition = %s", tostring(Event.coalition)))
--   veaf.loggers.get(veafRadio.Id):info(string.format("Event group id  = %s", tostring(Event.groupID)))
--   if Event.initiator ~= nil then
--     _unitname = Event.initiator:getName()
--     veaf.loggers.get(veafRadio.Id):info(string.format("Event ini unit  = %s", tostring(_unitname)))
--   end
--   veaf.loggers.get(veafRadio.Id):info(string.format("Event text      = \n%s", tostring(Event.text)))
  
--   if Event.id == 15 and _unitname and veafRadio.humanUnits[_unitname] then
--     -- refresh the radio menu
--     veafRadio.refreshRadioMenu() -- TODO refresh it only for this player ? Is this even possible ?
--     -- debug with logInfo message to check if this mechanism is working
--     veaf.loggers.get(veafRadio.Id):info(string.format("refreshRadioMenu() following event S_EVENT_BIRTH of human unit %s", tostring(_unitname)))
--   end
-- end

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

  local radioMeasures = {
       nbMenus = 0
      ,maxNbMenusInGroups = 0
      ,nbCommands = 0
      ,maxNbCommandsInGroups = 0
  }
  
  veafRadio.radioMenuSize = {}
  veafRadio.addSizeForAll(string.len(veafRadio.RadioMenuName))
  
  -- create all the commands and submenus in the dcs radio menu
  veaf.loggers.get(veafRadio.Id):trace("create all the commands and submenus in the dcs radio menu")
  veafRadio.refreshRadioSubmenu(nil, veafRadio.radioMenu, radioMeasures)        

  -- warn if the size starts to get too big
  local maxSize = 0
  local maxGroup = -1
  for group, size in pairs(veafRadio.radioMenuSize) do
    if maxSize < size then 
      maxSize = size 
      maxGroup = group
    end
    if veafRadio.MAXIMUM_SIZE > 0 and size >= veafRadio.MAXIMUM_SIZE  then
      veafRadio.reportRadioMenuSizeBreached("veafRadio._refreshRadioMenu()", group, size)
    end
  end

  veaf.loggers.get(veafRadio.Id):debug(string.format("veafRadio._refreshRadioMenu() max(veafRadio.radioMenuSize)=%d,%d",maxSize, maxGroup))
  veaf.loggers.get(veafRadio.Id):trace("radioMeasures="..veaf.p(radioMeasures))

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

  ----veaf.loggers.get(veafRadio.Id):trace(routines.utils.oneLineSerialize({_title = _title}))
  ----veaf.loggers.get(veafRadio.Id):trace(routines.utils.oneLineSerialize({_method = _method}))
  ----veaf.loggers.get(veafRadio.Id):trace(routines.utils.oneLineSerialize({_parameters = _parameters}))
  
  if groupId then
    --veaf.loggers.get(veafRadio.Id):trace(string.format("adding for group %s command %s",groupId or "", _title or ""))
    missionCommands.addCommandForGroup(groupId, _title, menu, _method, _parameters)
  else
    --veaf.loggers.get(veafRadio.Id):trace(string.format("adding for all command %s",_title or ""))
    missionCommands.addCommand(_title, menu, _method, _parameters)
  end

end

function veafRadio.refreshRadioSubmenu(parentRadioMenu, radioMenu, radioMeasures)
  veaf.loggers.get(veafRadio.Id):trace("veafRadio.refreshRadioSubmenu "..radioMenu.title)

  
  local trace = false
  
  local measures_addMenu = function(group) 
    radioMeasures.nbMenus = radioMeasures.nbMenus + 1
    if group ~= nil then 
      if radioMeasures.maxNbMenusInGroups < radioMeasures.nbMenus then 
        radioMeasures.maxNbMenusInGroups = radioMeasures.nbMenus
      end
    end
  end
  
  local measures_addCommand = function(group) 
    radioMeasures.nbCommands = radioMeasures.nbCommands + 1
    if group ~= nil then 
      if radioMeasures.maxNbCommandsInGroups < radioMeasures.nbCommands then 
        radioMeasures.maxNbCommandsInGroups = radioMeasures.nbCommands
      end
    end
  end

  -- warn if the size starts to get too big
  for group, size in pairs(veafRadio.radioMenuSize) do
    if veafRadio.MAXIMUM_SIZE > 0 and size >= veafRadio.MAXIMUM_SIZE then
      veafRadio.reportRadioMenuSizeBreached(string.format("veafRadio.refreshRadioSubmenu()",radioMenu.title), group, size)
    end
  end

  -- create the radio menu in DCS
  veafRadio.addSizeForAll(string.len(radioMenu.title))
  if parentRadioMenu then
    radioMenu.dcsRadioMenu = missionCommands.addSubMenu(radioMenu.title, parentRadioMenu.dcsRadioMenu)
  else
    radioMenu.dcsRadioMenu = missionCommands.addSubMenu(radioMenu.title)
  end
  measures_addMenu()
  
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
                --veaf.loggers.get(veafRadio.Id):debug(string.format("checking if unit %s is spawned",veaf.p(unitName)))
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
                        veafRadio.addSizeForGroup(groupId, string.len(_title))
                        veafRadio._addCommand(groupId, _title, radioMenu.dcsRadioMenu, command, parameters)
                        measures_addCommand(groupId)
                    end
                    alreadyDoneGroups[groupId] = true
                end
            end
        end
    else
        veafRadio.addSizeForAll(string.len(command.title))
        veafRadio._addCommand(nil, command.title, radioMenu.dcsRadioMenu, command, command.parameters)
        measures_addCommand()
    end
  end  
  
  -- recurse to create the submenus in the radio menu
  for count = 1,#radioMenu.subMenus do
    local subMenu = radioMenu.subMenus[count]
    veafRadio.refreshRadioSubmenu(radioMenu, subMenu, radioMeasures)
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

-- prepare humans units
function veafRadio.buildHumanUnits()

    veafRadio.humanUnits = {}

    -- build menu for each player
    for name, unit in pairs(mist.DBs.humansByName) do
        -- not already in units list ?
        if veafRadio.humanUnits[unit.unitName] == nil then
            veaf.loggers.get(veafRadio.Id):trace(string.format("human player found name=%s, unitName=%s, groupId=%s", name, unit.unitName,unit.groupId))
            local callsign = unit.callsign
            if type(callsign) == "table" then callsign = callsign["name"] end
            if type(callsign) == "number" then callsign = "" .. callsign end
            local unitObject = {name=unit.unitName, groupId=unit.groupId, callsign=callsign}
            veafRadio.humanUnits[unit.unitName] = unitObject
            veaf.loggers.get(veafRadio.Id):trace(string.format("veafRadio.humanUnits[%s]=\n%s",unit.unitName,veaf.p(veafRadio.humanUnits[unit.unitName])))
            if not veafRadio.humanGroups[unit.groupId] then 
              veafRadio.humanGroups[unit.groupId] = {}
              veafRadio.humanGroups[unit.groupId].callsigns = {}
              veafRadio.humanGroups[unit.groupId].units = {}
            end
            table.insert(veafRadio.humanGroups[unit.groupId].callsigns,callsign)
            veafRadio.humanGroups[unit.groupId].units[callsign] = unitObject
        end
    end

    -- sort callsigns for each group
    for _, groupData in pairs(veafRadio.humanGroups) do
      table.sort(groupData.callsigns)
    end
end

function veafRadio.addSizeForGroup(groupId, sizeToAdd)
  if not veafRadio.radioMenuSize then
    veafRadio.radioMenuSize = {}
  end
  if not veafRadio.radioMenuSize[groupId] then
    veafRadio.radioMenuSize[groupId] = 0
  end
  veafRadio.radioMenuSize[groupId] = veafRadio.radioMenuSize[groupId] + sizeToAdd
end

function veafRadio.addSizeForAll(sizeToAdd)
  for groupId, _ in pairs(veafRadio.humanGroups) do
    veafRadio.addSizeForGroup(groupId, sizeToAdd)
  end
end

function veafRadio.reportRadioMenuSizeBreached_reset()
  veafRadio.reportRadioMenuSizeBreached_ALREADYDONE = false
end

function veafRadio.reportRadioMenuSizeBreached(text, group, size)
  if not veafRadio.reportRadioMenuSizeBreached_ALREADYDONE then
    local message = string.format("%s - Maximum radio menu size reached : [%s]%d / %d",text or "", tostring(group), size, veafRadio.MAXIMUM_SIZE)
    veaf.loggers.get(veafRadio.Id):warn(string.format("%s - Maximum radio menu size reached : [%s]%d / %d",text or "", tostring(group), size, veafRadio.MAXIMUM_SIZE))
    trigger.action.outText(string.format("Maximum radio menu size reached : [%s]%d / %d",tostring(group), size, veafRadio.MAXIMUM_SIZE),5)
    veafRadio.reportRadioMenuSizeBreached_ALREADYDONE = true
    mist.scheduleFunction(veafRadio.reportRadioMenuSizeBreached_reset,{},timer.getTime()+60)
  end
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

function veafRadio.startBeacon(name, firstRunDelay, secondsBetweenRepeats, frequencies, modulations, message, mp3, volume, coalition)
  veaf.loggers.get(veafRadio.Id):debug(string.format("startBeacon(name=%s, firstRunDelay=%s, secondsBetweenRepeats=%s, coalition=%s, frequencies=%s, modulations=%s, volume=%s, message=%s, mp3=%s)", tostring(name), tostring(firstRunDelay), tostring(secondsBetweenRepeats), tostring(coalition), tostring(frequencies), tostring(modulations), tostring(volume), tostring(message), tostring(mp3)))
  
  local beacon = veafRadio.beacons[name:lower()]
  if not beacon then beacon = {} end
  beacon.name = name
  beacon.secondsBetweenRepeats = secondsBetweenRepeats
  beacon.nextRun = timer.getTime()+firstRunDelay
  beacon.frequencies = frequencies
  beacon.modulations = modulations
  beacon.volume = volume
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
        veafRadio.transmitMessage(beacon.message, beacon.frequencies, beacon.modulations, beacon.volume, beacon.name, beacon.coalition, nil, true)
      elseif beacon.mp3 then
        veafRadio.playToRadio(beacon.mp3, beacon.frequencies, beacon.modulations, beacon.volume, beacon.name, beacon.coalition, nil, true)
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

-- transmit a radio message via SRS
function veafRadio.transmitMessage(message, frequencies, modulations, volume, name, coalition, eventPos, quiet)
  veaf.loggers.get(veafRadio.Id):debug(string.format("transmitMessage(name=%s, coalition=%s, frequencies=%s, modulations=%s, volume=%s, message=%s)", tostring(name), tostring(coalition), tostring(frequencies), tostring(modulations), tostring(volume), tostring(message)))
  if eventPos then 
    veaf.loggers.get(veafRadio.Id):trace(string.format("eventPos=%s",veaf.p(eventPos)))
  end

  local l_os = os
  if not l_os and SERVER_CONFIG and SERVER_CONFIG.getModule then
      l_os = SERVER_CONFIG.getModule("os")
  end

  if l_os and STTS then
    message = message:gsub("\"","\\\"")
    local cmd = string.format("start /min \"%s\" \"%s\\%s\" \"%s\" %s %s %s %s \"%s\" %s", STTS.DIRECTORY, STTS.DIRECTORY, STTS.EXECUTABLE, message, frequencies, modulations, coalition, STTS.SRS_PORT, name, volume )
    veaf.loggers.get(veafRadio.Id):trace(string.format("executing os command %s", cmd))
    local result = l_os.execute(cmd)
    if result == nil then
      veaf.loggers.get(veafRadio.Id):warn(string.format("Nil result after executing os command %s", cmd))
    end
    return result
  end

  if not quiet and coalition then
    trigger.action.outTextForCoalition(coalition, string.format("%s (%s) : %s", name, frequencies, message), 30)
  end
end

-- play a MP3 file via SRS
function veafRadio.playToRadio(pathToMP3, frequencies, modulations, volume, name, coalition, eventPos, quiet)
  veaf.loggers.get(veafRadio.Id):debug(string.format("playToRadio(name=%s, coalition=%s, frequencies=%s, modulations=%s, volume=%s, pathToMP3=%s)", tostring(name), tostring(coalition), tostring(frequencies), tostring(modulations), tostring(volume), tostring(pathToMP3)))
  if eventPos then 
    veaf.loggers.get(veafRadio.Id):trace(string.format("eventPos=%s",veaf.p(eventPos)))
  end

  local l_os = os
  if not l_os and SERVER_CONFIG and SERVER_CONFIG.getModule then
      l_os = SERVER_CONFIG.getModule("os")
  end

  if l_os and STTS then
    
    local pathToMP3 = pathToMP3
    if pathToMP3 and not(pathToMP3:find("\\")) then
      pathToMP3 = STTS.MP3_FOLDER .. "\\" .. pathToMP3
    end

    if pathToMP3 and not(pathToMP3:find(".mp3")) then
      pathToMP3 = pathToMP3 .. ".mp3"
    end

    local cmd = string.format("start /min \"%s\" \"%s\\%s\" \"%s\" %s %s %s %s \"%s\" %s", STTS.DIRECTORY, STTS.DIRECTORY, STTS.EXECUTABLE, pathToMP3, frequencies, modulations, coalition,STTS.SRS_PORT, name, volume )
    veaf.loggers.get(veafRadio.Id):trace(string.format("executing os command %s", cmd))
    l_os.execute(cmd)
  end

  if not quiet then
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
    veafRadio.buildHumanUnits()
    veafRadio.refreshRadioMenu(false)
    mist.scheduleFunction(veafRadio._refreshRadioMenu,{},timer.getTime()+15)
    
    -- Add "player unit birth" event handler.
    world.addEventHandler(veafRadio.eventHandler)

    -- add marker change event handler
    veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafRadio.onEventMarkChange)

    -- start the beacons
    veafRadio._runBeacons()
end

veaf.loggers.get(veafRadio.Id):info(string.format("Loading version %s", veafRadio.Version))

