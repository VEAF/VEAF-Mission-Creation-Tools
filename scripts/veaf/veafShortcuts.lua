-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF shortcuts supporting functions for DCS World
-- By zip (2020)
--
-- Features:
-- ---------
-- * This module offers support for commands aliases and radio menu shortcuts
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires all the veaf scripts !
--
-- Basic Usage:
-- ------------
-- TODO
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafShortcuts = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafShortcuts.Id = "SHORTCUTS - "

--- Version.
veafShortcuts.Version = "1.0.0"

-- trace level, specific to this module
veafShortcuts.Trace = false

veafShortcuts.RadioMenuName = "SHORTCUTS"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Radio menus paths
veafShortcuts.rootPath = nil

-- Aliases list (table of VeafAlias objects)
veafShortcuts.aliasesList = {}

-- Aliases dictionary (map of VeafAlias objects by alias name)
veafShortcuts.aliasesDict = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafShortcuts.logError(message)
    veaf.logError(veafShortcuts.Id .. message)
end

function veafShortcuts.logInfo(message)
    veaf.logInfo(veafShortcuts.Id .. message)
end

function veafShortcuts.logDebug(message)
    veaf.logDebug(veafShortcuts.Id .. message)
end

function veafShortcuts.logTrace(message)
    if message and veafShortcuts.Trace then 
        veaf.logTrace(veafShortcuts.Id .. message)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafAlias object
-------------------------------------------------------------------------------------------------------------------------------------------------------------
VeafAlias =
{
    -- name
    name,
    -- the command that must be substituted to the alias
    veafCommand,
    -- if TRUE, security is bypassed
    bypassSecurity,
}
VeafAlias.__index = VeafAlias

function VeafAlias.new ()
    local self = setmetatable({}, VeafAlias)
    self.__index = self
    self.veafCommand = nil
    self.bypassSecurity = false
    return self
end

---
--- setters and getters
---

function VeafAlias:setName(value)
    self.Name = value
    return self
end

function VeafAlias:getName()
    return self.Name
end


function VeafAlias:setVeafCommand(value)
    self.veafCommand = tonumber(value)
    return self
end

function VeafAlias:getVeafCommand()
    return self.veafCommand
end

function VeafAlias:setBypassSecurity(value)
    self.bypassSecurity = value
    return self
end

function VeafAlias:isBypassSecurity()
    return self.bypassSecurity
end

---
--- other methods
---

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- global functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- search for an alias
function veafShortcuts.GetAlias(aliasName)
    veafShortcuts.logDebug(string.format("veafShortcuts.GetAlias([%s])",aliasName or ""))
    veafShortcuts.logDebug(string.format("Searching for alias with name [%s]", aliasName))
    local alias = veafShortcuts.aliasesDict[aliasName]
    if not alias then 
        local message = string.format("VeafAlias [%s] was not found !",aliasName)
        veafShortcuts.logError(message)
        trigger.action.outText(message,5)
    end
    return alias
end

-- add an alias
function veafShortcuts.AddAlias(alias)
    veafShortcuts.logDebug(string.format("veafShortcuts.AddAlias([%s])",alias:getName() or ""))
    veafShortcuts.logInfo(string.format("Adding alias [%s]", alias:getName()))
    table.insert(veafShortcuts.aliasesList, alias)
    veafShortcuts.aliasesDict[alias:getName()] = alias
    return alias
end

-- execute an alias command
function veafShortcuts.ExecuteAlias(aliasName)
    veafShortcuts.logDebug(string.format("veafShortcuts.ExecuteAlias([%s])",aliasName or ""))
    local alias = veafShortcuts.GetAlias(aliasName)
    alias:execute()
    return alias
end

function veafShortcuts.GetWeatherAtCurrentPosition(unitName)
    veafNamedPoints.logDebug(string.format("veafNamedPoints.getAtcAtClosestPoint(unitName=%s)",unitName))
    local unit = Unit.getByName(unitName)
    if unit then
        local weatherReport = veaf.weatherReport(unit:getPosition().p, nil, true) -- include LASTE
        veaf.outTextForUnit(unitName, weatherReport, 30)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafShortcuts.buildRadioMenu()
    veafShortcuts.logDebug("buildRadioMenu()")
    veafShortcuts.rootPath = veafRadio.addMenu(veafShortcuts.RadioMenuName)
    
    local localWeather = veafRadio.addSubMenu("Local weather", veafShortcuts.rootPath)
    veafRadio.addCommandToSubmenu("Local weather" , localWeather, atcClosestPath, nil, veafRadio.USAGE_ForUnit)    

    -- this one needs veafNamedPoints.lua
    local atcClosestPath = veafRadio.addSubMenu("ATC on closest point", veafShortcuts.rootPath)
    veafRadio.addCommandToSubmenu("ATC on closest point" , atcClosestPath, veafNamedPoints.getAtcAtClosestPoint, nil, veafRadio.USAGE_ForUnit)    
    
    veafRadio.refreshRadioMenu()
end


-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafShortcuts.initialize()
    veafShortcuts.logInfo("Initializing module")
    veafShortcuts.buildRadioMenu()
end

veafShortcuts.logInfo(string.format("Loading version %s", veafShortcuts.Version))
