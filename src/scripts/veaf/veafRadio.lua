-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF radio menu script library for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- Manage the VEAF radio menus in the F10 - Other menu
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires the base veaf.lua script library (version 1.0 or higher)
--
-- Load the script:
-- ----------------
-- 1.) Download the script and save it anywhere on your hard drive.
-- 2.) Open your mission in the mission editor.
-- 3.) Add a new trigger:
--     * TYPE   "4 MISSION START"
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of MIST and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of veaf.lua and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of this script and click OK.
--     * ACTION "DO SCRIPT"
--     * set the script command to "veafRadio.initialize()" and click OK.
-- 4.) Save the mission and start it.
-- 5.) Have fun :)
--
-- Basic Usage:
-- ------------
-- TODO
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- veafRadio Table.
veafRadio = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafRadio.Id = "RADIO - "

--- Version.
veafRadio.Version = "1.2.0"

-- trace level, specific to this module
veafRadio.Trace = false

veafRadio.RadioMenuName = "VEAF"

--- Number of seconds between each automatic rebuild of the radio menu
veafRadio.SecondsBetweenRadioMenuAutomaticRebuild = 600 -- 10 minutes ; should not be necessary as the menu is refreshed when a human enters a unit

-- constants used to determine how the radio menu is set up
veafRadio.USAGE_ForAll   = 0
veafRadio.USAGE_ForGroup = 1
veafRadio.USAGE_ForUnit  = 2

-- maximum size for radio menu
veafRadio.MAXIMUM_SIZE = 3500

-- delay for the actual refresh
veafRadio.refreshRadioMenu_DELAY = 2

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------
veafRadio.skipHelpMenus = false

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

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRadio.logError(message)
  veaf.logError(veafRadio.Id .. message)
end

function veafRadio.logInfo(message)
    veaf.logInfo(veafRadio.Id .. message)
end

function veafRadio.logDebug(message)
    veaf.logDebug(veafRadio.Id .. message)
end

function veafRadio.logTrace(message)
  if message and veafRadio.Trace then 
    veaf.logTrace(veafRadio.Id .. message)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Event handler.
veafRadio.eventHandler = {}

--- Handle world events.
function veafRadio.eventHandler:onEvent(Event)

  -- Only interested in S_EVENT_PLAYER_ENTER_UNIT
  if Event == nil or not Event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT  then
      return true
  end

  -- Debug output.
  if Event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then
    veafRadio.logDebug("S_EVENT_PLAYER_ENTER_UNIT")
    veafRadio.logTrace(string.format("Event id        = %s", tostring(Event.id)))
    veafRadio.logTrace(string.format("Event time      = %s", tostring(Event.time)))
    veafRadio.logTrace(string.format("Event idx       = %s", tostring(Event.idx)))
    veafRadio.logTrace(string.format("Event coalition = %s", tostring(Event.coalition)))
    veafRadio.logTrace(string.format("Event group id  = %s", tostring(Event.groupID)))
    if Event.initiator ~= nil then
        local _unitname = Event.initiator:getName()
        veafRadio.logTrace(string.format("Event ini unit  = %s", tostring(_unitname)))
    end
    veafRadio.logTrace(string.format("Event text      = \n%s", tostring(Event.text)))

    -- refresh the radio menu
    -- TODO refresh it only for this player ? Is this even possible ?
    veafRadio.refreshRadioMenu()
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRadio._proxyMethod(parameters)
  veafRadio.logTrace("parameters="..veaf.p(parameters))  
  local realMethod, realParameters = unpack(parameters)
  veafRadio.logTrace("realMethod="..veaf.p(realMethod))  
  veafRadio.logTrace("realParameters="..veaf.p(realParameters))  
  if veafSecurity.isAuthenticated() then
    realMethod(realParameters)
  else
    veafRadio.logError("Your radio has to be authenticated for '+'' commands")
    trigger.action.outText("Your radio has to be authenticated for '+'' commands", 5) 
  end  
end

--- Refresh the radio menu, based on stored information
--- This is called from another method that has first changed the radio menu information by adding or removing elements
function veafRadio.refreshRadioMenu(dontDelay)
  veafRadio.logDebug(string.format("veafRadio.refreshRadioMenu()"))

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
  veafRadio.logDebug(string.format("veafRadio._refreshRadioMenu()"))
  veafRadio.refreshRadioMenuDelayedScheduling = nil

  -- completely delete the dcs radio menu
  veafRadio.logTrace("completely delete the dcs radio menu")
  if veafRadio.radioMenu.dcsRadioMenu then
    missionCommands.removeItem(veafRadio.radioMenu.dcsRadioMenu)
  else
    veafRadio.logInfo("_refreshRadioMenu() first time : no DCS radio menu yet")
  end
  
  veafRadio.radioMenuSize = {}
  veafRadio.addSizeForAll(string.len(veafRadio.RadioMenuName))
  
  -- create all the commands and submenus in the dcs radio menu
  veafRadio.logTrace("create all the commands and submenus in the dcs radio menu")
  veafRadio.refreshRadioSubmenu(nil, veafRadio.radioMenu)        

  -- warn if the size starts to get too big
  local maxSize = 0
  for group, size in pairs(veafRadio.radioMenuSize) do
    if maxSize < size then maxSize = size end
    if size >= veafRadio.MAXIMUM_SIZE then
      veafRadio.reportRadioMenuSizeBreached("veafRadio._refreshRadioMenu()", group, size)
    end
  end
  veafRadio.logDebug(string.format("veafRadio._refreshRadioMenu() max(veafRadio.radioMenuSize)=%d",maxSize))

end

function veafRadio._addCommand(groupId, title, menu, command, parameters) 
  if not command.method then
    veafRadio.logError("ERROR - missing method for command " .. title)
  end
  local _title = title
  local _method = command.method
  local _parameters = parameters
  if command.isSecured then
    veafRadio.logTrace("adding secured command")
    
    _method = veafRadio._proxyMethod
    _parameters = {command.method, _parameters}

    if veafSecurity.isAuthenticated() then
      _title = "-" .. title
    else
      _title = "+" .. title
    end
  end

  ----veafRadio.logTrace(routines.utils.oneLineSerialize({_title = _title}))
  ----veafRadio.logTrace(routines.utils.oneLineSerialize({_method = _method}))
  ----veafRadio.logTrace(routines.utils.oneLineSerialize({_parameters = _parameters}))
  
  if groupId then
    veafRadio.logTrace(string.format("adding for group %s command %s",groupId or "", _title or ""))
    missionCommands.addCommandForGroup(groupId, _title, menu, _method, _parameters)
  else
    veafRadio.logTrace(string.format("adding for all command %s",_title or ""))
    missionCommands.addCommand(_title, menu, _method, _parameters)
  end

end

function veafRadio.refreshRadioSubmenu(parentRadioMenu, radioMenu)
  veafRadio.logTrace("veafRadio.refreshRadioSubmenu "..radioMenu.title)

  if veafRadio.skipHelpMenus and radioMenu.title:upper():find("HELP") then
    veafRadio.logDebug("veafRadio.refreshRadioSubmenu - skipping "..radioMenu.title)
    return
  end

  local trace = false

  -- warn if the size starts to get too big
  for group, size in pairs(veafRadio.radioMenuSize) do
    if size >= veafRadio.MAXIMUM_SIZE then
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
  
  -- create the commands in the radio menu
  for count = 1,#radioMenu.commands do
    local command = radioMenu.commands[count]

    if veafRadio.skipHelpMenus then veafRadio.logTrace(string.format("command.title=[%s]",command.title)) end
    if veafRadio.skipHelpMenus and command.title:upper():find("HELP") then
      veafRadio.logDebug("veafRadio.refreshRadioSubmenu - skipping "..command.title)
    else
      if not command.usage then
        command.usage = veafRadio.USAGE_ForAll
      end
      if command.usage ~= veafRadio.USAGE_ForAll then
        
        -- build menu for each player group
        local alreadyDoneGroups = {}
        for groupId, groupData in pairs(veafRadio.humanGroups) do
          for _, callsign in pairs(groupData.callsigns) do
            local unitData = groupData.units[callsign]
            local unitName = unitData.name
  
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
              veafRadio._addCommand(groupId, _title, radioMenu.dcsRadioMenu, command, parameters, trace)
            end
            alreadyDoneGroups[groupId] = true
          end
        end
      else
        veafRadio.addSizeForAll(string.len(command.title))
        veafRadio._addCommand(nil, command.title, radioMenu.dcsRadioMenu, command, command.parameters, trace)
      end
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
    veafRadio.logError("veafRadio.clearSubmenu() subMenu parameter is nil !")
    return
  end
  veafRadio.logDebug(string.format("veafRadio.clearSubmenu(%s)",subMenu.title))
  subMenu.subMenus = {}
  subMenu.commands = {}
end

function veafRadio.delSubmenu(subMenu, radioMenu)
  if not subMenu then 
    veafRadio.logError("veafRadio.delSubmenu() subMenu parameter is nil !")
    return
  end
  local menu = veafRadio.radioMenu
  if radioMenu then
     menu = radioMenu 
  end
  veaf.arrayRemoveWhen(menu.subMenus, function(t, i, j)
    -- Return true to keep the value, or false to discard it.
    veafRadio.logTrace("searching for " .. subMenu.title)
    local v = menu.subMenus[i]
    veafRadio.logTrace("checking " .. v.title)
    if v == subMenu then
      veafRadio.logTrace("found ! removing " .. v.title)
      return false
    else
      veafRadio.logTrace("keeping " .. v.title)
      return true
    end
  end);
end

-- prepare humans units
function veafRadio.buildHumanUnits()

    veafRadio.humanUnits = {}

    -- build menu for each player
    for name, unit in pairs(mist.DBs.humansByName) do
        -- not already in units list ?
        if veafRadio.humanUnits[unit.unitName] == nil then
            veafRadio.logTrace(string.format("human player found name=%s, unitName=%s, groupId=%s", name, unit.unitName,unit.groupId))
            local callsign = unit.callsign
            if type(callsign) == "table" then callsign = callsign["name"] end
            if type(callsign) == "number" then callsign = "" .. callsign end
            local unitObject = {name=unit.unitName, groupId=unit.groupId, callsign=callsign}
            veafRadio.humanUnits[unit.unitName] = unitObject
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

function veafRadio.radioRefreshWatchdog()
  veafRadio.logDebug("veafRadio.radioRefreshWatchdog()")
  -- refresh the menu
  veafRadio.refreshRadioMenu()

  veafRadio.logDebug("veafRadio.radioRefreshWatchdog() - rescheduling in "..veafRadio.SecondsBetweenRadioMenuAutomaticRebuild)
  -- reschedule
  mist.scheduleFunction(veafRadio.radioRefreshWatchdog,{},timer.getTime()+veafRadio.SecondsBetweenRadioMenuAutomaticRebuild)
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
    veafRadio.logError(string.format("%s - Maximum radio menu size reached : [%s]%d / %d",text or "", tostring(group), size, veafRadio.MAXIMUM_SIZE))
    trigger.action.outText(string.format("Maximum radio menu size reached : [%s]%d / %d",tostring(group), size, veafRadio.MAXIMUM_SIZE),5)
    veafRadio.reportRadioMenuSizeBreached_ALREADYDONE = true
    mist.scheduleFunction(veafRadio.reportRadioMenuSizeBreached_reset,{},timer.getTime()+60)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafRadio.initialize(skipHelpMenus)
    veafRadio.skipHelpMenus = skipHelpMenus or false

    -- Build the initial radio menu
    veafRadio.buildHumanUnits()
    veafRadio.refreshRadioMenu()
    --veafRadio.radioRefreshWatchdog()

    -- Add "player enter unit" event handler.
    world.addEventHandler(veafRadio.eventHandler)
end

veafRadio.logInfo(string.format("Loading version %s", veafRadio.Version))

