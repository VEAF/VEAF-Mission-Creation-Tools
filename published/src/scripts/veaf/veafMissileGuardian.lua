------------------------------------------------------------------
-- VEAF missile guardian functions for DCS World
-- By zip (2020)
--
-- Features:
-- ---------
-- * GUARDIAN objects that are configured to warn and protect specific units (helos, airplanes) of weapons fired in their direction
-- * ANGEL objects following these weapons, warning their targets (distance, aspect, danger) and optionnaly destroy weapons in the air before impact (training, protection)
-- * Works with all current and future maps (Caucasus, NTTR, Normandy, PG, ...)
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafMissileGuardian = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafMissileGuardian.Id = "MISSILEGUARDIAN"

--- Version.
veafMissileGuardian.Version = "0.0.1"

-- trace level, specific to this module
--veafMissileGuardian.LogLevel = "trace"

veaf.loggers.new(veafMissileGuardian.Id, veafMissileGuardian.LogLevel)

--- Number of seconds between each check of the WIDE ZONE watchdog function
veafMissileGuardian.SecondsBetweenWideZoneWatchdogChecks = 5
--- Number of seconds between each check of the DANGER ZONE watchdog function
veafMissileGuardian.SecondsBetweenDangerZoneWatchdogChecks = 0.5

veafMissileGuardian.RadioMenuName = "GUARDIAN"

veafMissileGuardian.RemoteCommandParser = "([[a-zA-Z0-9]+)%s?([^%s]*)%s?(.*)"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Radio menus paths
veafMissileGuardian.rootPath = nil

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafMG_Weapon object ; represents a weapon in flight, detected by a Guardian and managed by an Protector
-------------------------------------------------------------------------------------------------------------------------------------------------------------
VeafMG_Weapon =
{
    -- technical name
    name = nil,
    -- DCS weapon object
    dcsWeapon = nil,
    -- shooter
    shooter = nil,
    -- shooter name (if the shooter unit gets destroyed, keep its name)
    shooterName = nil,
}
VeafMG_Weapon.__index = VeafMG_Weapon

function VeafMG_Weapon:new()
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("VeafMG_Weapon:new()"))
    local self = setmetatable({}, VeafMG_Weapon)
    self.name = nil
    self.dcsWeapon = nil
    self.shooter = nil
    self.shooterName = nil
    return self
end

function VeafMG_Weapon:copy()
    local copy = VeafMG_Weapon:new()

    -- copy the attributes
    copy.name = self.name
    copy.dcsWeapon = self.dcsWeapon
    copy.shooter = self.shooter
    copy.shooterName = self.shooterName

    return copy
end

---
--- setters and getters
---

function VeafMG_Weapon:setName(value)
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("VeafMG_Weapon.setName([%s])",value or ""))
    self.name = value
    return self
end

function VeafMG_Weapon:getName()
    return self.name
end

function VeafMG_Weapon:setDcsWeapon(value)
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("VeafMG_Weapon[%s].setDcsWeapon()",self:getName() or ""))
    self.dcsWeapon = value
    if self.dcsWeapon then
        self.shooter = self.dcsWeapon:getLauncher()
        self.shooterName = veafMissileGuardian.getUnitName(self.shooter)
    end
    return self
end

function VeafMG_Weapon:getDcsWeapon()
    return self.dcsWeapon
end

function VeafMG_Weapon:getShooter()
    return self.shooter
end

function VeafMG_Weapon:getShooterName()
    return self.shooterName
end

---
--- other methods
---

function VeafMG_Weapon:getCurrentPosition()
    local _result = nil
    if self:getDcsWeapon() then 
        _result = self:getDcsWeapon():getPoint()
    end
    return _result
end

function VeafMG_Weapon:getCurrentTarget()
    local _result = nil
    if self:getDcsWeapon() then 
        _result = self:getDcsWeapon():getTarget()
    end
    return _result
end

function VeafMG_Weapon:getCurrentEnergy()
    local _result = nil
    if self:getDcsWeapon() then 
        local _mass = 250 -- let's say the missile weights 250kg
        local _vector = self:getDcsWeapon():getVelocity()
        local _absVelocity = mist.vec.mag(_vector)
        local _kinetic = (_mass / 2) * _absVelocity * _absVelocity
        local _alt = self:getDcsWeapon():getPoint().z
        local _potential = _mass * 9.81 * _alt
        _result = _kinetic + _potential
    end
    return _result
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafMG_Guardian object
-- The Guardian observes units and reacts if one of them fires a weapon by encapsulating it into a VeafMG_Weapon and passing it to a VeafMG_Protector for observation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
VeafMG_Guardian =
{
    -- technical name
    name = nil,
    -- human-friendly name
    friendlyName = nil,
    -- list of units that should be protected from missiles
    protectedUnits = nil,
    -- polygon describing a zone when the units should be to be protected
    protectedZone = nil,
}
VeafMG_Guardian.__index = VeafMG_Guardian

VeafMG_Guardian.WARNING_MESSAGE = "Warning, %s : you've been attacked by %s and a missile is in the air"
VeafMG_Guardian.WARNING_MESSAGE_TIME = 10

function VeafMG_Guardian:new()
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("VeafMG_Guardian:new()"))
    local self = setmetatable({}, VeafMG_Guardian)
    self.name = nil
    self.friendlyName = nil
    self.protectedUnits = {}
    self.protectedZone = {}
    return self
end

function VeafMG_Guardian:copy()
    local copy = VeafMG_Guardian:new()

    -- copy the attributes
    copy.name = self.name
    copy.friendlyName = self.friendlyName
        
    -- deep copy the collections
    copy.protectedUnits = {}
    for unitName, value in pairs(self.protectedUnits) do
        copy.protectedZone[unitName] = value
    end

    copy.protectedZone = {}
    for _, value in pairs(self.protectedZone) do
        table.insert(copy.protectedZone, value)
    end

    return copy
end

---
--- setters and getters
---

function VeafMG_Guardian:setName(value)
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("VeafMG_Guardian[]:setName([%s])",value or ""))
    self.name = value
    return self
end

function VeafMG_Guardian:getName()
    return self.name
end

function VeafMG_Guardian:setFriendlyName(value)
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("VeafMG_Guardian[%s]:setFriendlyName()",self:getName() or ""))
    self.friendlyName = value
    return self
end

function VeafMG_Guardian:getFriendlyName()
    return self.friendlyName
end

function VeafMG_Guardian:addProtectedUnit(value)
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("VeafMG_Guardian[%s]:addProtectedUnit()",self:getName() or ""))
    if type(value) ~= "string" then
        value = value:getName()
    end
    self.protectedUnits[value] = "protected"
    return self
end

function VeafMG_Guardian:setProtectedZone(value)
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("VeafMG_Guardian[%s]:setProtectedZone()",self:getName() or ""))
    self.protectedZone = value
    return self
end

---
--- other methods
---

--- event handler
function VeafMG_Guardian:onEvent(event)
    -- only react to S_EVENT_SHOT events
    if event and event.id == world.event.S_EVENT_SHOT then
        veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("VeafMG_Protector:onEvent(S_EVENT_SHOT) : %s", veaf.p(event)))
        
        if event.weapon then
            -- check if the target is one of the protected units
            local _target = event.weapon:getTarget()
            if _target then
                local _targetName = _target:getName()
                veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("_targetName = %s", veaf.p(_targetName)))
                if self.protectedUnits[_targetName] then 
                    -- check if the target is in the protected zone
                    local _inZone = mist.pointInPolygon(_target:getPoint(), self.protectedZone)
                    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("_inZone = %s", veaf.p(_inZone)))
                    if _inZone then 
                        -- encapsulate the event weapon
                        local _weapon = VeafMG_Weapon:new():setDcsWeapon(event.weapon)

                        -- message the target unit
                        local _groupId = _target:getGroup():getID()
                        local _playername = _target:getPlayerName()
                        if _playername then
                            veaf.loggers.get(veafMissileGuardian.Id):debug(string.format("Issuing a warning to unit %s", veaf.p(_playername)))
                            trigger.action.outTextForGroup(_groupId, string.format(VeafMG_Guardian.WARNING_MESSAGE, _playername, _weapon:getShooterName()), VeafMG_Guardian.WARNING_MESSAGE_TIME)
                        end

                        -- pass the weapon to the large-scale protector
                        veafMissileGuardian.getLargeScaleProtector():setWeapon(_weapon)    
                    end
                end
            end
        end
    end
end

function VeafMG_Guardian:start()
    -- register event handler
    world.addEventHandler(self)
end

function VeafMG_Guardian:stop()
    -- deregister event handler
    world.removeEventHandler(self)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafMG_Protector object
-- Responsible for observing and reporting VeafMG_Weapons behavior, and protecting the registered units by destroying the weapons in flight when needed
-------------------------------------------------------------------------------------------------------------------------------------------------------------
VeafMG_Protector =
{
    -- technical name
    name = nil,
    -- seconds between watchdog checks
    secondsBetweenWatchdogChecks = nil,
    -- weapon we're trying to protect from
    weapon = nil,
}
VeafMG_Protector.__index = VeafMG_Protector

function VeafMG_Protector:new()
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("VeafMG_Protector:new()"))
    local self = setmetatable({}, VeafMG_Protector)
    self.name = nil
    self.secondsBetweenWatchdogChecks = nil
    self.weapon = nil
    return self
end

function VeafMG_Protector:copy()
    local copy = VeafMG_Protector:new()

    -- copy the attributes
    copy.name = self.name
    copy.secondsBetweenWatchdogChecks = self.secondsBetweenWatchdogChecks
    copy.weapon = self.weapon
        
    -- deep copy the collections
    -- copy.parameters = {}
    -- for name, value in pairs(self.parameters) do
    --     veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("copying parameter %s : ",tostring(name)))
    --     copy.parameters[name]=value
    -- end

    return copy
end

---
--- setters and getters
---

function VeafMG_Protector:setName(value)
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("VeafMG_Protector[]:setName([%s])",value or ""))
    self.name = value
    return self
end

function VeafMG_Protector:getName()
    return self.name
end

function VeafMG_Protector:setSecondsBetweenWatchdogChecks(value)
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("VeafMG_Protector[%s]:setSecondsBetweenWatchdogChecks()",self:getName() or ""))
    self.secondsBetweenWatchdogChecks = value
    return self
end

function VeafMG_Protector:getSecondsBetweenWatchdogChecks()
    return self.secondsBetweenWatchdogChecks
end

function VeafMG_Protector:setWeapon(value)
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("VeafMG_Protector[%s]:setWeapon()",self:getName() or ""))
    self.weapon = value
    return self
end

---
--- other methods
---
---

function VeafMG_Protector:start()
    -- schedule the watchdog function
end

function VeafMG_Protector:stop()
    -- unschedule the watchdog function
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- local functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafMissileGuardian.getUnitName(unit)
    return unit:getName() -- TODO make this useful (add the player name if possible)
end

function veafMissileGuardian.getLargeScaleProtector()
    -- TODO
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- global functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- add a new guardian
function veafMissileGuardian.AddGuardian(guardian)
    veaf.loggers.get(veafMissileGuardian.Id):debug(string.format("veafMissileGuardian.AddGuardian([%s])",guardian:getName() or ""))
    return guardian
end

-- activate a guardian
function veafMissileGuardian.ActivateGuardian(name, silent)
    veaf.loggers.get(veafMissileGuardian.Id):debug(string.format("veafMissileGuardian.ActivateGuardian([%s])",name or ""))
    local guardian = veafMissileGuardian.GetGuardian(name)
    local result = guardian:activate(silent)
    if not silent and not guardian:isSilent() then
        if result then
            trigger.action.outText("VeafMG_Guardian "..guardian:getFriendlyName().." has been activated.", 10)
        else
            trigger.action.outText("VeafMG_Guardian "..guardian:getFriendlyName().." was already active.", 10)
        end
    end
    veafMissileGuardian.buildRadioMenu()
end

-- desactivate a guardian
function veafMissileGuardian.DesactivateGuardian(name, silent)
    veaf.loggers.get(veafMissileGuardian.Id):debug(string.format("veafMissileGuardian.DesactivateGuardian([%s])",name or ""))
    local guardian = veafMissileGuardian.GetGuardian(name)
    local result = guardian:desactivate(silent)
    if not silent and not guardian:isSilent() then
        if result then
            trigger.action.outText("VeafMG_Guardian "..guardian:getFriendlyName().." has been desactivated.", 10)
        else
            trigger.action.outText("VeafMG_Guardian "..guardian:getFriendlyName().." was already inactive.", 10)
        end
    end
    veafMissileGuardian.buildRadioMenu()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafMissileGuardian._buildMissionRadioMenu(menu, title, element)
    local missions = element.missions
    if #missions == 1 then
        -- one simple mission
        local mission = missions[1]
        if mission:isActive() then title = "* "..title end
        mission.radioRootPath = veafRadio.addSubMenu(title, menu)
        mission:updateRadioMenu(true)
    else
        -- group by skill and scale
        veaf.loggers.get(veafMissileGuardian.Id):trace("group by skill and scale")
        local skills = {}
        for _, mission in pairs(missions) do
            local regex = ("^([^/]+)/([^/]+)/(%d+)$")
            local name, skill, scale = mission:getName():match(regex)
            veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("missionName=[%s], name=%s, skill=%s, scale=%s", tostring(mission:getName()), tostring(name), tostring(skill), tostring(scale)))
            if not skills[skill] then 
                skills[skill] = {} 
            end
            skills[skill][scale] = mission 
        end
        
        veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("skills=%s", veaf.p(skills)))
        
        -- create the radio menus
        local title = title
        if element.activeGroups then title = "* "..title end
        local missionPath = veafRadio.addSubMenu(title, menu)
        veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("  %s", title))
        local skillsNames = {}
        for skill, _ in pairs(skills) do
            table.insert(skillsNames, skill)
        end
        table.sort(skillsNames)
        for _, skill in pairs(skillsNames) do
            local scales = skills[skill]
            local skillTitle = skill
            if element.activeGroups and element.activeGroups[skill] then skillTitle = "* "..skillTitle end
            local skillPath = veafRadio.addSubMenu(skillTitle, missionPath)
            veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("    %s", skill))
            local scalesNames = {}
            for scale, _ in pairs(scales) do
                table.insert(scalesNames, scale)
            end
            table.sort(scalesNames)
            for _, scale in pairs(scalesNames) do
                local mission = scales[scale]
                local scaleTitle = "scale "..scale
                if element.activeGroups and element.activeGroups[skill] and element.activeGroups[skill][scale] then scaleTitle = "* "..scaleTitle end
                local scalePath = veafRadio.addSubMenu(scaleTitle, skillPath)
                veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("      %s", scale))
                mission.radioRootPath = scalePath
                mission:updateRadioMenu(true)
            end
        end
    end
end

--- Build the initial radio menu
function veafMissileGuardian.buildRadioMenu()
    veaf.loggers.get(veafMissileGuardian.Id):debug("buildRadioMenu()")
    if veafMissileGuardian.rootPath then 
        veafRadio.clearSubmenu(veafMissileGuardian.rootPath)
    else
        veafMissileGuardian.rootPath = veafRadio.addMenu(veafMissileGuardian.RadioMenuName)
    end
    if not(veafRadio.skipHelpMenus) then
        veafRadio.addCommandToSubmenu("HELP", veafMissileGuardian.rootPath, veafMissileGuardian.help, nil, veafRadio.USAGE_ForGroup)
    end
    veafRadio.refreshRadioMenu()
end

function veafMissileGuardian.listGuardians() 
    -- sort the missions alphabetically
    local sortedMissions = {}
    table.sort(sortedMissions)
    
    local text =
    'List of all available guardians:\n'

    for _, missionName in pairs(sortedMissions) do
        text = text .. " - " .. missionName .. "\n"
    end
    
    trigger.action.outText(text, 20)
end

function veafMissileGuardian.listActiveMissions() 
    -- sort the missions alphabetically
    local sortedMissions = {}
    for _, mission in pairs(veafMissileGuardian.missionsDict) do
        if mission:isActive() then
            table.insert(sortedMissions, mission:getName() .. ' : ' .. mission:getRemainingEnemiesString())
        end
    end
    table.sort(sortedMissions)
    
    local text =
    'No active combat mission !'

    if #sortedMissions > 0 then
        text =
        'List of active combat missions:\n'

        for _, missionName in pairs(sortedMissions) do
            text = text .. " - " .. missionName .. "\n"
        end
    end    

    trigger.action.outText(text, 20)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- remote interface
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- execute command from the remote interface
function veafMissileGuardian.executeCommandFromRemote(parameters)
    veaf.loggers.get(veafMissileGuardian.Id):debug(string.format("veafMissileGuardian.executeCommandFromRemote()"))
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("parameters= %s", veaf.p(parameters)))
    local _pilot, _pilotName, _unitName, _command = unpack(parameters)
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("_pilot= %s", veaf.p(_pilot)))
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("_pilotName= %s", veaf.p(_pilotName)))
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("_unitName= %s", veaf.p(_unitName)))
    veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("_command= %s", veaf.p(_command)))
    if not _pilot or not _command then 
        return false
    end

    if _command then
        -- parse the command
        local _action, _missionName, _parameters = _command:match(veafMissileGuardian.RemoteCommandParser)
        veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("_action=%s",veaf.p(_action)))
        veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("_guardianName=%s",veaf.p(_missionName)))
        veaf.loggers.get(veafMissileGuardian.Id):trace(string.format("_parameters=%s",veaf.p(_parameters)))
        if _action and _action:lower() == "list" then 
            veaf.loggers.get(veafMissileGuardian.Id):info(string.format("[%s] is listing air missions)",veaf.p(_pilot.name)))
            veafMissileGuardian.listAvailableMissions()
            return true
        elseif _action and _action:lower() == "start" and _missionName then 
            local _silent = _parameters and _parameters:lower() == "silent"
            veaf.loggers.get(veafMissileGuardian.Id):info(string.format("[%s] is starting air mission [%s] %s)",veaf.p(_pilot.name), veaf.p(_missionName), veaf.p(_parameters)))
            veafMissileGuardian.ActivateMission(_missionName, _silent)
            return true
        elseif _action and _action:lower() == "stop" then 
            local _silent = _parameters and _parameters:lower() == "silent"
            veaf.loggers.get(veafMissileGuardian.Id):info(string.format("[%s] is stopping air mission [%s] %s)",veaf.p(_pilot.name), veaf.p(_missionName), veaf.p(_parameters)))
            veafMissileGuardian.DesactivateMission(_missionName, _silent)
            return true
        end
    end               
    return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafMissileGuardian.initialize()
    veaf.loggers.get(veafMissileGuardian.Id):info("Initializing module")
    veafMissileGuardian.buildRadioMenu()
    veafMissileGuardian.dumpMissionsList(veaf.config.MISSION_EXPORT_PATH)
end

veaf.loggers.get(veafMissileGuardian.Id):info(string.format("Loading version %s", veafMissileGuardian.Version))

