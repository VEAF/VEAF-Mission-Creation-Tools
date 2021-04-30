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
veafShortcuts.Version = "1.17.0"

-- trace level, specific to this module
veafShortcuts.Debug = false
veafShortcuts.Trace = false

veafShortcuts.RadioMenuName = "SHORTCUTS"

veafShortcuts.AliasStarter = "-"

veafShortcuts.RemoteCommandParser = "([a-zA-Z0-9:\\.-]+)%s(.*)"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Radio menus paths
veafShortcuts.rootPath = nil

-- Aliases list (table of VeafAlias objects)
veafShortcuts.aliases = {}

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
    if message and veafShortcuts.Debug then 
        veaf.logDebug(veafShortcuts.Id .. message)
    end
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
    -- description
    description,
    -- hidden from HELP
    hidden,
    -- the command that must be substituted to the alias
    veafCommand,
    -- list of parameters that will be randomized if not present
    randomParameters,
    -- if TRUE, security is bypassed
    bypassSecurity,
}
VeafAlias.__index = VeafAlias

function VeafAlias:new()
    local self = setmetatable({}, VeafAlias)
    self.veafCommand = nil
    self.bypassSecurity = false
    self.hidden = false
    self.randomParameters = {}
    self.endsWithComma = true
    self.description = nil
    return self
end

---
--- setters and getters
---

function VeafAlias:setName(value)
    veafShortcuts.logTrace(string.format("VeafAlias[%s]:setName([%s])", self.name or "", value or ""))
    self.name = value
    return self
end

function VeafAlias:getName()
    return self.name
end


function VeafAlias:setVeafCommand(value)
    veafShortcuts.logTrace(string.format("VeafAlias[%s]:setVeafCommand([%s])", self.name, value or ""))
    self.veafCommand = value
    return self
end

function VeafAlias:getVeafCommand()
    return self.veafCommand
end

function VeafAlias:setEndsWithComma(value)
    veafShortcuts.logTrace(string.format("VeafAlias[%s]:setEndsWithComma([%s])", self.name, value or ""))
    self.endsWithComma = value
    return self
end

function VeafAlias:isEndsWithComma()
    return self.endsWithComma
end

function VeafAlias:addRandomParameter(name, low, high)
    veafShortcuts.logTrace(string.format("VeafAlias[%s]:addRandomParameter([%s], %s, %s)", self.name, name or "", low or "", high or ""))
    table.insert(self.randomParameters, { name = name, low = low or 1, high = high or 6})
    return self
end

function VeafAlias:getRandomParameters()
    return self.randomParameters
end

function VeafAlias:dontEndWithComma()
    veafShortcuts.logTrace(string.format("VeafAlias[%s]:dontEndWithComma()", self.name))
    self:setEndsWithComma(false)
    return self
end

function VeafAlias:setDescription(value)
    veafShortcuts.logTrace(string.format("VeafAlias[%s]:setDescription([%s])", self.name, value or ""))
    self.description = value
    return self
end

function VeafAlias:getDescription()
    return self.description
end

function VeafAlias:setBypassSecurity(value)
    veafShortcuts.logTrace(string.format("VeafAlias[%s]:setBypassSecurity([%s])", self.name, tostring(value) or ""))
    self.bypassSecurity = value
    return self
end

function VeafAlias:isBypassSecurity()
    return self.bypassSecurity
end

function VeafAlias:setHidden(value)
    veafShortcuts.logTrace(string.format("VeafAlias[%s]:setHidden([%s])", self.name, tostring(value) or ""))
    self.hidden = value
    return self
end

function VeafAlias:isHidden()
    return self.hidden
end

function VeafAlias:execute(remainingCommand, position, coalition, markId, bypassSecurity, spawnedGroups)
    local function logDebug(message)
        veafShortcuts.logDebug(message)
        return true
    end

    veafShortcuts.logTrace(string.format("markId=[%s]",veaf.p(markId)))

    local command = self:getVeafCommand()
    for _, parameter in pairs(self:getRandomParameters()) do
        veafShortcuts.logTrace(string.format("randomizing [%s]",parameter.name or ""))
        local value = math.random(parameter.low, parameter.high)
        veafShortcuts.logTrace(string.format("got [%d]",value))
        command = string.format("%s, %s %d",command, parameter.name, value)
    end
    if self:isEndsWithComma() then
        veafShortcuts.logTrace("adding a comma")
        command = command .. ", "
    end

    local _bypassSecurity = bypassSecurity or self:isBypassSecurity()

    local command = command .. (remainingCommand or "")
    veafShortcuts.logTrace(string.format("command = [%s]",command or ""))
    if logDebug("checking in veafShortcuts") and veafShortcuts.executeCommand(position, command, coalition, markId, _bypassSecurity, spawnedGroups) then
        return true
    elseif logDebug("checking in veafSpawn") and veafSpawn.executeCommand(position, command, coalition, markId, _bypassSecurity, spawnedGroups) then
        return true
    elseif logDebug("checking in veafNamedPoints") and veafNamedPoints.executeCommand(position, {text=command, coalition=-1}, _bypassSecurity) then
        return true
    elseif logDebug("checking in veafCasMission") and veafCasMission.executeCommand(position, command, coalition, _bypassSecurity) then
        return true
    elseif logDebug("checking in veafSecurity") and veafSecurity.executeCommand(position, command, _bypassSecurity) then
        return true
    elseif logDebug("checking in veafMove") and veafMove.executeCommand(position, command, _bypassSecurity) then
        return true
    elseif logDebug("checking in veafRadio") and veafRadio.executeCommand(position, command, coalition, _bypassSecurity) then
        return true
    elseif logDebug("checking in veafRemote") and veafRemote.executeCommand(position, command, coalition) then
        return true
    else
        return false
    end
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

    -- find the desired alias in the aliases list
    local alias = nil

    for _, a in pairs(veafShortcuts.aliases) do
        if a:getName():lower() == aliasName:lower() then
            alias = a
            break
        end
    end
    
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
    table.insert(veafShortcuts.aliases, alias)
    return alias
end

-- execute an alias command
function veafShortcuts.ExecuteAlias(aliasName, delay, remainingCommand, position, coalition, markId, bypassSecurity, spawnedGroups)
    veafShortcuts.logDebug(string.format("veafShortcuts.ExecuteAlias([%s],[%s],[%s],[%s],[%s])", veaf.p(aliasName), veaf.p(delay), veaf.p(remainingCommand), veaf.p(position), veaf.p(coalition)))
    veafShortcuts.logTrace(string.format("markId=[%s]",veaf.p(markId)))
    veafShortcuts.logTrace(string.format("bypassSecurity=[%s]",veaf.p(bypassSecurity)))

    local alias = veafShortcuts.GetAlias(aliasName)
    if alias then 
        veafShortcuts.logTrace(string.format("found VeafAlias[%s]",alias:getName() or ""))
        if delay and delay ~= "" then
            mist.scheduleFunction(VeafAlias.execute, {alias, remainingCommand, position, coalition, markId, bypassSecurity, spawnedGroups}, timer.getTime() + delay)
        else
            alias:execute(remainingCommand, position, coalition, markId, bypassSecurity, spawnedGroups)
        end
        return true
    else
        veafShortcuts.logError(string.format("veafShortcuts.ExecuteAlias : cannot find alias [%s]",aliasName or ""))
        return false
    end
    return false
end

function veafShortcuts.GetWeatherAtCurrentPosition(unitName)
    veafNamedPoints.logDebug(string.format("veafShortcuts.GetWeatherAtCurrentPosition(unitName=%s)",unitName))
    local unit = veafRadio.getHumanUnitOrWingman(unitName)
    if unit then
        local weatherReport = veaf.weatherReport(unit:getPosition().p, nil, true) -- include LASTE
        veaf.outTextForUnit(unitName, weatherReport, 30)
    end
end

function veafShortcuts.GetWeatherAtClosestPoint(unitName)
    veafNamedPoints.logDebug(string.format("veafShortcuts.GetWeatherAtClosestPoint(unitName=%s)",unitName))
    local unit = veafRadio.getHumanUnitOrWingman(unitName)
    if unit then
        local weatherReport = veaf.weatherReport(unit:getPosition().p, nil, true) -- include LASTE
        veaf.outTextForUnit(unitName, weatherReport, 30)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafShortcuts.onEventMarkChange(eventPos, event)

    -- choose by default the coalition opposing the player who triggered the event
    local invertedCoalition = 1
    if event.coalition == 1 then
        invertedCoalition = 2
    end

    veafSpawn.logTrace(string.format("event.idx  = %s", veaf.p(event.idx)))

    if veafShortcuts.executeCommand(eventPos, event.text, invertedCoalition, event.idx) then 
        
        -- Delete old mark.
        veafShortcuts.logTrace(string.format("Removing mark # %d.", event.idx))
        trigger.action.removeMark(event.idx)

    end
end

function veafShortcuts.executeCommand(eventPos, eventText, eventCoalition, markId, bypassSecurity, spawnedGroups)
    veafShortcuts.logDebug(string.format("veafShortcuts.executeCommand(eventText=[%s])", eventText))

    -- Check if marker has a text and contains an alias
    if eventText ~= nil then
        
        -- Analyse the mark point text and extract the keywords.
        local alias, delay, remainder = veafShortcuts.markTextAnalysis(eventText)

        if alias then
            -- do the magic
            return veafShortcuts.ExecuteAlias(alias, delay, remainder, eventPos, eventCoalition, markId, bypassSecurity, spawnedGroups)
        end
        return false
    end

    -- None of the keywords matched.
    return false
end

--- Extract keywords from mark text.
function veafShortcuts.markTextAnalysis(text)
    if text then 
  
        veafShortcuts.logTrace(string.format("veafShortcuts.markTextAnalysis(text=[%s])", text))
    
        -- check for the alias starter
        if text:sub(1,1) == veafShortcuts.AliasStarter then
            veafShortcuts.logTrace("found veafShortcuts.AliasStarter")

            -- extract alias and remainder
            local alias, delay, remainder = text:match("(-[^!^ ^,]+)!?(%d*)(.*)")
            veafShortcuts.logTrace(string.format("alias=[%s]", veaf.p(alias)))
            veafShortcuts.logTrace(string.format("delay=[%s]", veaf.p(delay)))
            veafShortcuts.logTrace(string.format("remainder=[%s]", veaf.p(remainder)))
            if alias then
                veafShortcuts.logTrace(string.format("alias = [%s]", alias))
                return alias, delay, remainder
            end
        end

    end
    return nil
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafShortcuts.helpAllAliases(unitName)
    local text = 'List of all aliases:\n'
            
    for _, a in pairs(veafShortcuts.aliases) do
        if not a:isHidden() then
            local line = a:getName()
            if a:getDescription() then
                line = line .. " -> " .. a:getDescription()
            end
            text = text .. line .. "\n"
        end
    end
    veaf.outTextForUnit(unitName, text, 30)
end

--- Build the initial radio menu
function veafShortcuts.buildRadioMenu()
    veafShortcuts.logDebug("buildRadioMenu()")
    
    --if veafRadio.skipHelpMenus then return end -- completely skip the menu since there are only help elements
    
    veafShortcuts.rootPath = veafRadio.addMenu(veafShortcuts.RadioMenuName)
    
    --if not(veafRadio.skipHelpMenus) then
        veafRadio.addCommandToSubmenu("HELP - all aliases", veafShortcuts.rootPath, veafShortcuts.helpAllAliases, nil, veafRadio.USAGE_ForAll)
    --end

    -- these ones need veafNamedPoints.lua
    --veafRadio.addCommandToSubmenu("Weather on closest point" , veafShortcuts.rootPath, veafNamedPoints.getWeatherAtClosestPoint, nil, veafRadio.USAGE_ForGroup)    
    --veafRadio.addCommandToSubmenu("ATC on closest point" , veafShortcuts.rootPath, veafNamedPoints.getAtcAtClosestPoint, nil, veafRadio.USAGE_ForGroup)    
    
    veafRadio.refreshRadioMenu()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- default aliases list
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafShortcuts.buildDefaultList()
    -- generic sam groups
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-samLR")
            :setDescription("Random long range SAM battery")
            :setVeafCommand("_spawn samgroup, skynet true")
            :addRandomParameter("defense", 4, 5)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-samSR")
            :setDescription("Random short range SAM battery")
            :setVeafCommand("_spawn samgroup, skynet true")
            :addRandomParameter("defense", 2, 3)
            :setBypassSecurity(false)
    )
    -- specific air defenses groups and units  
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa2")
            :setDescription("SA-2 Guideline (S-75 Dvina) battery")
            :setVeafCommand("_spawn group, name sa2, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa3")
            :setDescription("SA-3 Goa (S-125 Neva/Pechora) battery")
            :setVeafCommand("_spawn group, name sa3, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa6")
            :setDescription("SA-6 Gainful (2K12 Kub) battery")
            :setVeafCommand("_spawn group, name sa6, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa8")
            :setDescription("SA-8 Osa (9K33 Osa) sam vehicle")
            :setVeafCommand("_spawn unit, name Osa 9A33 ln, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa9")
            :setDescription("SA-9 Strela-1 (9K31 Strela-1) sam vehicle")
            :setVeafCommand("_spawn unit, name Strela-1 9P31, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa10")
            :setDescription("SA-10 Grumble (S-300) battery")
            :setVeafCommand("_spawn group, name sa10, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa11")
            :setDescription("SA-11 Gadfly (9K37 Buk) battery")
            :setVeafCommand("_spawn group, name sa11, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa13")
            :setDescription("SA-13 Strela (9A35M3) sam vehicle")
            :setVeafCommand("_spawn unit, name Strela-10M3, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa15")
            :setDescription("SA-15 Gauntlet (9K330 Tor) sam vehicle")
            :setVeafCommand("_spawn unit, name sa15, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa18")
            :setDescription("SA-18 manpad soldier")
            :setVeafCommand("_spawn unit, name SA-18 Igla-S manpad")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sa19")
            :setDescription("SA-19 Tunguska (2K22 Tunguska) sam vehicle")
            :setVeafCommand("_spawn unit, name 2S6 Tunguska, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-shilka")
            :setDescription("ZSU-23-4 Shilka AAA vehicle")
            :setVeafCommand("_spawn unit, name ZSU-23-4 Shilka, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-zu23")
            :setDescription("ZU-23 AAA vehicle")
            :setVeafCommand("_spawn unit, name Ural-375 ZU-23, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-manpads")
            :setDescription("mutiple SA-18 manpad soldier peppered in a wide radius")
            :setVeafCommand("_spawn unit, name SA-18 Igla-S manpad, radius 5000, skynet true")
            :addRandomParameter("multiplier", 3, 6)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-roland")
            :setDescription("Roland battery with EWR (US by default)")
            :setVeafCommand("_spawn group, name roland, country USA, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-rolandnoew")
            :setDescription("Roland battery without EWR (US by default)")
            :setVeafCommand("_spawn group, name roland-noew, country USA, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-patriot")
            :setDescription("Patriot battery (US by default)")
            :setVeafCommand("_spawn group, name patriot, country USA, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-burke")
            :setDescription("USS Arleigh Burke IIa destroyer (US by default)")
            :setVeafCommand("_spawn unit, name USS_Arleigh_Burke_IIa, country USA, skynet true")
            :setBypassSecurity(false)
    )  
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-perry")
            :setDescription("O.H. Perry destroyer (US by default)")
            :setVeafCommand("_spawn unit, name PERRY, country USA, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-ticonderoga")
            :setDescription("Ticonderoga frigate (US by default)")
            :setVeafCommand("_spawn unit, name TICONDEROG, country USA, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-rezky")
            :setDescription("FF 1135M Rezky frigate (RU by default)")
            :setVeafCommand("_spawn unit, name REZKY, country RUSSIA, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-pyotr")
            :setDescription("CGN 1144.2 Pyotr Velikiy (RU by default)")
            :setVeafCommand("_spawn unit, name PIOTR, country RUSSIA, skynet true")
            :setBypassSecurity(false)
    )

    -- shortcuts to commands
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-point")
            :setDescription("Name a point on the map")
            :setVeafCommand("_name point")
            :dontEndWithComma() -- !! don't end with a comma, because we'd break setting the point name 
            :setBypassSecurity(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-login")
            :setDescription("Unlock the system")
            :setHidden(true)
            :setVeafCommand("_auth")
            :dontEndWithComma() -- !! don't end with a comma, because we'd break setting the password 
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-logout")
            :setDescription("Lock the system")
            :setHidden(true)
            :setVeafCommand("_auth logout")
            :setBypassSecurity(true)
    )
    -- shortcuts to specific groups
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-mortar")
            :setDescription("Mortar team")
            :setVeafCommand("_spawn group, name mortar, country USA")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-arty")
            :setDescription("M-109 artillery battery")
            :setVeafCommand("_spawn group, name M-109, country USA")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-cargoships")
            :setDescription("Cargo ships")
            :setVeafCommand("_spawn group, name cargoships-nodef, country RUSSIA, offroad, speed 60, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-escortedcargoships")
            :setDescription("Cargo ships (escorted)")
            :setVeafCommand("_spawn group, name cargoships-escorted, country RUSSIA, offroad, speed 60, skynet true")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-combatships")
            :setDescription("Combat ships")
            :setVeafCommand("_spawn group, name combatships, country RUSSIA, offroad, speed 60, skynet true")
            :setBypassSecurity(false)
    )
    -- shortcuts to dynamic groups
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-sam")
            :setDescription("Random SAM battery")
            :setVeafCommand("_spawn samgroup, skynet true")
            :addRandomParameter("defense", 1, 5)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-armor")
            :setDescription("Dynamic armor group")
            :setVeafCommand("_spawn armorgroup")
            :addRandomParameter("defense", 1, 3)
            :addRandomParameter("armor", 2, 4)
            :addRandomParameter("size", 4, 8)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-infantry")
            :setDescription("Dynamic infantry section")
            :setVeafCommand("_spawn infantrygroup")
            :addRandomParameter("defense", 0, 5)
            :addRandomParameter("armor", 0, 5)
            :addRandomParameter("size", 4, 8)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-transport")
            :setDescription("Dynamic transport company")
            :setVeafCommand("_spawn transportgroup")
            :addRandomParameter("defense", 0, 3)
            :addRandomParameter("size", 10, 25)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-combat")
            :setDescription("Dynamic combat group")
            :setVeafCommand("_spawn combatgroup")
            :addRandomParameter("defense", 1, 3)
            :addRandomParameter("armor", 2, 4)
            :addRandomParameter("size", 1, 4)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-cas")
            :setDescription("Generate a random CAS group for training")
            :setVeafCommand("_cas, disperse")
            :setBypassSecurity(false)
    )
    -- radio shortcuts
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-send")
            :setDescription("Send radio message - needs \"MESSAGE\"")
            :setVeafCommand("_radio transmit, message")
            :dontEndWithComma() -- !! don't end with a comma, because we'd break setting the message content 
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-play")
            :setDescription("Play sound over radio - needs \"FILENAME\"")
            :setVeafCommand("_radio play, path")
            :dontEndWithComma() -- !! don't end with a comma, because we'd break setting the message content 
            :setBypassSecurity(false)
    )
    -- other shortcuts
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-convoy")
            :setDescription("Convoy - needs \", dest POINTNAME\"")
            :setVeafCommand("_spawn convoy")
            :addRandomParameter("defense", 0, 3)
            :addRandomParameter("armor", 0, 4)
            :addRandomParameter("size", 6, 15)
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-jtac")
            :setDescription("JTAC humvee")
            :setVeafCommand("_spawn jtac")
            :setBypassSecurity(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-shell")
            :setDescription("Artillery shelling of a zone with high-yield HE")
            :setVeafCommand("_spawn bomb")
            :addRandomParameter("shells", 25, 40)
            :addRandomParameter("radius", 350, 500)
            :addRandomParameter("power", 100, 300)
            :setHidden(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-shells")
            :setDescription("Artillery shelling of a small zone with low-yield HE")
            :setVeafCommand("-shell")
            :addRandomParameter("shells", 2, 5)
            :addRandomParameter("radius", 200, 500)
            :addRandomParameter("power", 10, 50)
            :addRandomParameter("multiplier", 5, 10)
            :setHidden(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-light")
            :setDescription("Illumination by artillery shelling of a zone")
            :setVeafCommand("_spawn flare, radius 1000")
            :addRandomParameter("shells", 20, 30)
            :setBypassSecurity(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-smoke")
            :setDescription("Spawn a single white smoke")
            :setVeafCommand("_spawn smoke, color white, shells 1, radius 1")
            :setBypassSecurity(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-tankerhere")
            :setDescription("move a tanker to a specific location ; must follow with the tanker group name ; can also set speed, alt, hdg and distance")
            :setVeafCommand("_move tanker, teleport, name")
            :dontEndWithComma()
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-tanker")
            :setDescription("alias for '-tankerhere'")
            :setVeafCommand("-tankerhere")
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-tankerlow")
            :setDescription("sets the closest tanker to FL120 at 200 KIAS")
            :setVeafCommand("_move tankermission, alt 12000, speed 250")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-tankerhigh")
            :setDescription("sets the closest tanker to FL220 at 300 KIAS")
            :setVeafCommand("_move tankermission, alt 22000, speed 450")
            :setBypassSecurity(false)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-tacan")
            :setDescription("create a portable TACAN beacon")
            :setVeafCommand("_spawn tacan, band X, channel 99")
            :setBypassSecurity(true)
    )
    veafShortcuts.AddAlias(
        VeafAlias:new()
            :setName("-farp")
            :setDescription("create a new FARP")
            :setVeafCommand("_spawn farp, side blue, radius 0")
            :setBypassSecurity(false)
    )
end

function veafShortcuts.dumpAliasesList(export_path)

    local jsonify = function(key, value)
        veafShortcuts.logTrace(string.format("jsonify(%s)", veaf.p(value)))
        if json then
            return json.stringify(veafShortcuts.GetAlias(value))
        else
            return ""
        end
    end

    -- sort the aliases alphabetically
    sortedAliases = {}
    for _, alias in pairs(veafShortcuts.aliases) do
        table.insert(sortedAliases, alias:getName())
    end
    table.sort(sortedAliases)
    veafShortcuts.logTrace(string.format("sortedAliases=%s", veaf.p(sortedAliases)))

    local _filename = "AliasesList.json"
    if veaf.config.MISSION_NAME then
        _filename = "AliasesList_" .. veaf.config.MISSION_NAME .. ".json"
    end
    veaf.exportAsJson(sortedAliases, "aliases", jsonify, _filename, export_path or veaf.config.MISSION_EXPORT_PATH)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- remote interface
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- execute command from the remote interface
function veafShortcuts.executeCommandFromRemote(parameters)
    veafShortcuts.logDebug(string.format("veafShortcuts.executeCommandFromRemote()"))
    veafShortcuts.logTrace(string.format("parameters= %s", veaf.p(parameters)))
    local _pilot, _pilotName, _unitName, _command = unpack(parameters)
    veafShortcuts.logTrace(string.format("_pilot= %s", veaf.p(_pilot)))
    veafShortcuts.logTrace(string.format("_pilotName= %s", veaf.p(_pilotName)))
    veafShortcuts.logTrace(string.format("_unitName= %s", veaf.p(_unitName)))
    veafShortcuts.logTrace(string.format("_command= %s", veaf.p(_command)))
    if not _pilot or not _command then 
        return false
    end

    if _command then
        -- parse the command
        local _coords, _alias = _command:match(veafShortcuts.RemoteCommandParser)
        veafShortcuts.logTrace(string.format("_coords=%s",veaf.p(_coords)))
        veafShortcuts.logTrace(string.format("_alias=%s",veaf.p(_alias)))
        if _coords and _alias then
            local _coa = coalition.side.BLUE
            local _unit = Unit.getByName(_unitName)
            if _unit then 
                _coa = _unit:getCoalition()
            end
            local _lat, _lon = veaf.computeLLFromString(_coords)
            veafShortcuts.logTrace(string.format("_lat=%s",veaf.p(_lat)))
            veafShortcuts.logTrace(string.format("_lon=%s",veaf.p(_lon)))
            if _lat and _lon then 
                local _pos = coord.LLtoLO(_lat, _lon)
                veafShortcuts.logTrace(string.format("_pos=%s",veaf.p(_pos)))
                veafShortcuts.logTrace(string.format("_coa=%s",veaf.p(_coa)))
                veafShortcuts.logInfo(string.format("[%s] is running an alias at position [%s] for coalition [%s] : [%s]",veaf.p(_pilot.name), veaf.p(_pos), veaf.p(_coa), veaf.p(_alias)))
                veafShortcuts.executeCommand(_pos, _alias, _coa, _pilot.name)
                return true
            end
        end
    end
    return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafShortcuts.initialize()
    veafShortcuts.logInfo("Initializing module")
    veafShortcuts.buildDefaultList()
    veafShortcuts.buildRadioMenu()
    veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafShortcuts.onEventMarkChange)
    veafShortcuts.dumpAliasesList()
end

veafShortcuts.logInfo(string.format("Loading version %s", veafShortcuts.Version))

