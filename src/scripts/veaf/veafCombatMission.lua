-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF combat mission functions for DCS World
-- By zip (2020)
--
-- Features:
-- ---------
-- * A combat mission consists in spawning enemy aircrafts
-- * It also contains a mass briefing, optional objectives (timed, number of kills, ...) and can trigger the activation of one or more combat zones
-- * For each mission, a specific radio sub-menu is created, allowing common actions (get mission status, weather, briefing, start and stop the mission, etc.)
-- * Works with all current and future maps (Caucasus, NTTR, Normandy, PG, ...)
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also require Moose (MiST is not able to properly spawn and manage aircraft groups)
-- * It also requires the base veaf.lua script library (version 1.0 or higher)
-- TODO
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
--     * OPEN --> Browse to the location of Moose and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of veaf.lua and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of this script and click OK.
--     * ACTION "DO SCRIPT"
--     * set the script command to "veafCombatMission.initialize()" and click OK.
-- 4.) Save the mission and start it.
-- 5.) Have fun :)
--
-- Basic Usage:
-- ------------
-- TODO
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafCombatMission = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafCombatMission.Id = "COMBAT MISSION - "

--- Version.
veafCombatMission.Version = "1.4.1"

-- trace level, specific to this module
veafCombatMission.Trace = true

--- Number of seconds between each check of the watchdog function
veafCombatMission.SecondsBetweenWatchdogChecks = 30

veafCombatMission.RadioMenuName = "MISSIONS"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Radio menus paths
veafCombatMission.rootPath = nil

-- Missions list (table of VeafCombatMission objects)
veafCombatMission.missionsList = {}

-- Missions dictionary (map of VeafCombatMission objects by mission name)
veafCombatMission.missionsDict = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafCombatMission.logError(message)
    veaf.logError(veafCombatMission.Id .. message)
end

function veafCombatMission.logInfo(message)
    veaf.logInfo(veafCombatMission.Id .. message)
end

function veafCombatMission.logDebug(message)
    veaf.logDebug(veafCombatMission.Id .. message)
end

function veafCombatMission.logTrace(message)
    if message and veafCombatMission.Trace then 
        veaf.logTrace(veafCombatMission.Id .. message)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafCombatMissionObjective object
-------------------------------------------------------------------------------------------------------------------------------------------------------------
VeafCombatMissionObjective =
{
    -- technical name
    name = nil,
    -- description for the briefing
    description = nil,
    -- message when the objective is completed
    message = nil,
    -- parameters
    parameters = {},
    -- function that is call when the mission starts
    onStartupFunction = nil,
    -- function that is called when the completion check watchdog runs (should check for objective completion and return one of the FAILED, SUCCESS or NOTHING constants)
    onCheckFunction = nil
}
VeafCombatMissionObjective.__index = VeafCombatMissionObjective

VeafCombatMissionObjective.FAILED = -1
VeafCombatMissionObjective.SUCCESS = 1
VeafCombatMissionObjective.NOTHING = 0

function VeafCombatMissionObjective.new()
    veafCombatMission.logTrace(string.format("VeafCombatMissionObjective.new()"))

    local self = setmetatable({}, VeafCombatMissionObjective)
    self.__index = self
    self.name = nil
    self.description = nil
    self.parameters = {}
    self.onStartupFunction = nil
    self.onCheckFunction = nil
    return self
end

function VeafCombatMissionObjective:copy()
    local copy = VeafCombatMissionObjective.new()

    -- copy the attributes
    copy.name = self.name
    copy.description = self.description
    copy.onStartupFunction = self.onStartupFunction
    copy.onCheckFunction = self.onCheckFunction
        
    -- deep copy the collections
    copy.parameters = {}
    for name, value in pairs(self.parameters) do
        veafCombatMission.logTrace(string.format("copying parameter %s : ",tostring(name)))
        copy.parameters[name]=value
    end

    return copy
end

---
--- setters and getters
---

function VeafCombatMissionObjective:setName(value)
    veafCombatMission.logTrace(string.format("VeafCombatMissionObjective.setName([%s])",value or ""))
    self.name = value
    return self
end

function VeafCombatMissionObjective:getName()
    return self.name
end

function VeafCombatMissionObjective:setDescription(value)
    veafCombatMission.logTrace(string.format("VeafCombatMissionObjective[%s].setDescription([%s])", self:getName() or "", value or ""))
    self.description = value
    return self
end

function VeafCombatMissionObjective:getDescription()
    return self.description
end

function VeafCombatMissionObjective:setMessage(value)
    veafCombatMission.logTrace(string.format("VeafCombatMissionObjective[%s].setMessage([%s])", self:getName() or "", value or ""))
    self.message = value
    return self
end

function VeafCombatMissionObjective:getMessage()
    return self.message
end

function VeafCombatMissionObjective:setParameters(value)
    veafCombatMission.logTrace(string.format("VeafCombatMissionObjective[%s].setParameters([%s])", self:getName() or "", veaf.p(value or "")))
    self.parameters = value
    return self
end

function VeafCombatMissionObjective:getParameters()
    return self.parameters
end

function VeafCombatMissionObjective:setOnCheck(value)
    veafCombatMission.logTrace(string.format("VeafCombatMissionObjective[%s].setOnCheck(some function)",self:getName()))
    self.onCheckFunction = value
    return self
end

function VeafCombatMissionObjective:getOnCheck()
    return self.onCheckFunction
end

function VeafCombatMissionObjective:setOnStartup(value)
    veafCombatMission.logTrace(string.format("VeafCombatMissionObjective[%s].setOnStartup(some function)", self:getName()))
    self.onStartupFunction = value
    return self
end

function VeafCombatMissionObjective:getOnStartup()
    return self.onStartupFunction
end

---
--- other methods
---

function VeafCombatMissionObjective:onCheck(mission)
    veafCombatMission.logTrace(string.format("VeafCombatMissionObjective[%s].onCheck([%s])", self:getName() or "", mission:getName() or ""))
    if self.onCheckFunction then
        return self.onCheckFunction(mission, self.parameters)
    else
        return VeafCombatMissionObjective.NOTHING
    end
end

function VeafCombatMissionObjective:onStartup(mission)
    veafCombatMission.logTrace(string.format("VeafCombatMissionObjective[%s].onStartup([%s])", self:getName() or "", mission:getName() or ""))
    if self.onStartupFunction then
        return self.onStartupFunction(self.parameters)
    end
end

function VeafCombatMissionObjective:configureAsTimedObjective(timeInSeconds)
    veafCombatMission.logTrace(string.format("VeafCombatMissionObjective[%s].configureAsTimedObjective()",self:getName()))

    local function onCheck(mission, parameters)
        veafCombatMission.logTrace(string.format("VeafCombatMissionObjective.NewTimedObjective.onCheck()"))
        local timeout = parameters.timeout
        local startTime = parameters.startTime
        if timer.getTime() > startTime + timeout then 
            return VeafCombatMissionObjective.FAILED
        else
            return VeafCombatMissionObjective.NOTHING
        end
    end

    return self
        :setParameters({timeout=timeInSeconds})
        :setOnStartup(
            function(parameters) 
                parameters["startTime"] = timer.getTime()
            end
        )
        :setOnCheck(onCheck)
end

function VeafCombatMissionObjective:configureAsKillEnemiesObjective(nbKillsToWin, whatsInAKill)
    veafCombatMission.logTrace(string.format("VeafCombatMissionObjective[%s].configureAsKillEnemiesObjective()",self:getName()))

    local function onCheck(mission, parameters)
        veafCombatMission.logTrace(string.format("VeafCombatMissionObjective.configureAsKillEnemiesObjective.onCheck()"))
        if mission:isActive() then
            local nbKillsToWin = parameters.nbKillsToWin
            local whatsInAKill = parameters.whatsInAKill
            veafCombatMission.logTrace(string.format("nbKillsToWin = %d",nbKillsToWin))
            veafCombatMission.logTrace(string.format("whatsInAKill = %d",whatsInAKill))

            local nbDeadUnits = 0
            local nbLiveUnits = 0

            for _, group in pairs(mission:getSpawnedGroups()) do
                veafCombatMission.logTrace(string.format("processing group [%s]",group:GetName()))
                if group:GetUnits() then
                    for _, unit in pairs(group:GetUnits()) do
                        veafCombatMission.logTrace(string.format("unit:GetLifeRelative() = %f",unit:GetLifeRelative()))
                        if unit:GetLifeRelative() == 1.0 then
                            veafCombatMission.logTrace(string.format("unit[%s] is alive",unit:GetName()))
                            nbLiveUnits = nbLiveUnits + 1
                        elseif unit:GetLifeRelative()*100 > whatsInAKill then
                            veafCombatMission.logTrace(string.format("unit[%s] is damaged (%d %%)",unit:GetName(), unit:GetLifeRelative()*100 ))
                            nbLiveUnits = nbLiveUnits + 1
                        else
                            veafCombatMission.logTrace(string.format("unit[%s] is dead",unit:GetName()))
                            nbDeadUnits = nbDeadUnits + 1
                        end
                    end
                else -- this is a bug but let's say that if there are no units in a group we count one kill
                    nbDeadUnits = nbDeadUnits + 1
                end
            end
            
            veafCombatMission.logTrace(string.format("nbLiveUnits = %d",nbLiveUnits))
            veafCombatMission.logTrace(string.format("nbDeadUnits = %d",nbDeadUnits))
        
            if (nbKillsToWin == -1 and nbLiveUnits == 0) or (nbKillsToWin >= 0 and nbDeadUnits >= nbKillsToWin) then 
                -- objective is achieved
                veafCombatMission.logTrace(string.format("objective is achieved"))
                local msg = string.format(self:getMessage(), nbDeadUnits)
                if not mission:isSilent() then
                    trigger.action.outText(msg, 15)
                end
                return VeafCombatMissionObjective.SUCCESS
            else
                veafCombatMission.logTrace(string.format("objective is NOT achieved"))
                return VeafCombatMissionObjective.NOTHING
            end
        end
        return VeafCombatMissionObjective.NOTHING
    end

    return self
            :setParameters({nbKillsToWin=nbKillsToWin or -1, whatsInAKill=whatsInAKill or 0})
            :setOnCheck(onCheck)
end

function VeafCombatMissionObjective:configureAsPreventDestructionOfSceneryObjectsInZone(zones, objects)
    veafCombatMission.logTrace(string.format("VeafCombatMissionObjective[%s].configureAsPreventDestructionOfSceneryObjectsInZone()",self:getName()))

    local function onCheck(mission, parameters)
        veafCombatMission.logTrace(string.format("VeafCombatMissionObjective.configureAsPreventDestructionOfSceneryObjectsInZone.onCheck()"))
        if mission:isActive() then
            
            local zones = parameters.zones
            local objects = parameters.objects
            local failed = false
            local killedObjectsNames = nil

            local killedObjects = mist.getDeadMapObjsInZones(zones)
            ----veafCombatMission.logTrace(veaf.serialize("killedObjects", killedObjects))
            
            for _, object in pairs(killedObjects) do
                veafCombatMission.logTrace(string.format("checking id_ = [%s]", object.object.id_))
                if objects[object.object.id_] then
                    veafCombatMission.logTrace(string.format("found [%s]", objects[object.object.id_]))
                    if killedObjectsNames then
                        killedObjectsNames = killedObjectsNames .. ", " .. objects[object.object.id_]
                    else
                        killedObjectsNames = objects[object.object.id_]
                    end
                    failed = true
                end
            end

            if failed then 
                -- objective is failed
                veafCombatMission.logTrace(string.format("objective is failed"))
                local msg = string.format(self:getMessage(), killedObjectsNames)
                if not mission:isSilent() then
                    trigger.action.outText(msg, 15)
                end
                return VeafCombatMissionObjective.FAILED
            else
                veafCombatMission.logTrace(string.format("objective is NOT failed"))
                return VeafCombatMissionObjective.NOTHING
            end
        end
        return VeafCombatMissionObjective.NOTHING
    end

    return self
            :setParameters({zones=zones, objects=objects})
            :setOnCheck(onCheck)
end
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafCombatMissionElement object
-------------------------------------------------------------------------------------------------------------------------------------------------------------
VeafCombatMissionElement =
{
    -- name
    name,
    -- groups : a list of group names that compose this element
    groups,
    --  coalition (0 = neutral, 1 = red, 2 = blue)
    coalition, -- SPAWN:InitCoalition(Coalition)
    -- skill ("Average", "Good", "High", "Excellent" or "Random"), defaults to "Random"
    skill, -- SPAWN:InitSkill(Skill)
    -- spawn radius in meters (randomness introduced in the respawn mechanism)
    spawnRadius, -- SPAWN:InitRandomizePosition
    -- spawn chance in percent (xx chances in 100 that the unit is spawned - or the command run)
    spawnChance,
    -- the element can be multiplied to scale the mission
    scale,
    -- if true, the element is scalable
    scalable,
}
VeafCombatMissionElement.__index = VeafCombatMissionElement

function VeafCombatMissionElement.new ()
    local self = setmetatable({}, VeafCombatMissionElement)
    self.__index = self
    self.name = nil
    self.groups = nil
    self.coalition = nil
    self.skill = "Random"
    self.spawnRadius = 0
    self.spawnChance = 100
    self.scale = 1
    self.scalable = false
    return self
end

function VeafCombatMissionElement:copy()
    local copy = VeafCombatMissionElement.new()

    -- copy the attributes
    copy.name = self.name
    copy.coalition = self.coalition
    copy.skill = self.skill
    copy.spawnRadius = self.spawnRadius
    copy.spawnChance = self.spawnChance
    copy.scale = self.scale
    copy.scalable = self.scalable
    
    -- deep copy the collections
    copy.groups = {}
    for _, group in pairs(self.groups) do
        table.insert(copy.groups, group)
    end

    return copy
end

---
--- setters and getters
---

function VeafCombatMissionElement:setName(value)
    self.name = value
    return self
end

function VeafCombatMissionElement:getName()
    return self.name
end

function VeafCombatMissionElement:setGroups(value)
    self.groups = value
    return self
end

function VeafCombatMissionElement:getGroups()
    return self.groups
end

function VeafCombatMissionElement:setSkill(value)
    self.skill = value
    return self
end

function VeafCombatMissionElement:getSkill()
    return self.skill
end

function VeafCombatMissionElement:setCoalition(value)
    self.coalition = value
    return self
end

function VeafCombatMissionElement:getCoalition()
    return self.coalition
end

function VeafCombatMissionElement:setSpawnRadius(value)
    self.spawnRadius = tonumber(value)
    return self
end

function VeafCombatMissionElement:getSpawnRadius()
    return self.spawnRadius
end

function VeafCombatMissionElement:setSpawnChance(value)
    self.spawnChance = tonumber(value)
    return self
end

function VeafCombatMissionElement:getSpawnChance()
    return self.spawnChance
end

function VeafCombatMissionElement:setScale(value)
    self.scale = tonumber(value)
    return self
end

function VeafCombatMissionElement:getScale()
    return self.scale
end

function VeafCombatMissionElement:setScalable(value)
    self.scalable = value
    return self
end

function VeafCombatMissionElement:isScalable()
    return self.scalable
end

---
--- other methods
---

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafCombatMission object
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafCombatMission = 
{
    -- mission name (technical)
    name,
    -- mission name (human-friendly)
    friendlyName,
    -- mission briefing
    briefing,
    -- secured :  if true, the radio menu will be secured
    secured,
    -- list of objectives
    objectives,
    -- list of the elements defined in the mission
    elements,
    -- mission is active
    active,
    -- mission is a training mission
    training,
    -- DCS groups that have been spawned (for cleaning up later)
    spawnedGroups,
    --- Radio menus paths
    radioMarkersPath,
    radioTargetInfoPath,
    radioRootPath,
    -- the watchdog function checks for mission objectives completion
    watchdogFunctionId,
    -- if false, the mission will not appear in the radio menu
    radioMenuEnabled,
    -- if true, no message will be displayed when activating/deactivating the mission
    hidden,
    -- same as hidden but only valid for one activation of the mission (will be reset to *hidden* at next start)
    silent,
}
VeafCombatMission.__index = VeafCombatMission

function VeafCombatMission.new ()
    local self = setmetatable({}, VeafCombatMission)
    self.__index = self
    self.name = nil
    self.friendlyName = nil
    self.secured = false
    self.briefing = nil
    self.objectives = {}
    self.elements = {}
    self.active = false
    self.training = false
    self.spawnedGroups = {}
    self.radioMarkersPath = nil
    self.radioTargetInfoPath = nil
    self.radioRootPath = nil
    self.watchdogFunctionId = nil
    self.hidden = false
    self.radioMenuEnabled = true
    self.silent = false
    return self
end

function VeafCombatMission:copy(newSkill, newScale)
    local copy = VeafCombatMission.new()

    -- copy the attributes
    copy.name = self.name
    copy.friendlyName = self.friendlyName
    copy.secured = self.secured
    copy.briefing = self.briefing
    copy.active = self.active
    copy.training = self.training
    copy.hidden = self.hidden
    copy.radioMenuEnabled = self.radioMenuEnabled
    copy.silent = self.silent

    -- deep copy the collections
    for _, objective in pairs(self.objectives) do
        copy:addObjective(objective:copy())
    end
    for _, element in pairs(self.elements) do
        local elementCopy = element:copy()
        if element:isScalable() and newScale then
            elementCopy:setScale(newScale)
        end
        if newSkill then
            elementCopy:setSkill(newSkill)
        end
        copy:addElement(elementCopy)
    end

    return copy
end

---
--- setters and getters
---

function VeafCombatMission:setName(value)
    self.name = value
    return self
end

function VeafCombatMission:getName()
    return self.name
end

function VeafCombatMission:setSecured(value)
    self.secured = value
    return self
end

function VeafCombatMission:isSecured()
    return self.secured
end

function VeafCombatMission:getRadioMenuName()
    return self:getFriendlyName()
end

function VeafCombatMission:setFriendlyName(value)
    self.friendlyName = value
    return self
end

function VeafCombatMission:getFriendlyName()
    return self.friendlyName
end

function VeafCombatMission:setBriefing(value)
    self.briefing = value
    return self
end

function VeafCombatMission:getBriefing()
    return self.briefing
end

function VeafCombatMission:isActive()
    return self.active
end

function VeafCombatMission:setActive(value)
    self.active = value
    return self
end

function VeafCombatMission:isTraining()
    return self.training
end

function VeafCombatMission:setTraining(value)
    self.training = value
    return self
end

function VeafCombatMission:addElement(value)
    table.insert(self.elements, value)
    return self
end

function VeafCombatMission:addSpawnedGroup(group)
    veafCombatMission.logDebug(string.format("VeafCombatMission[%s]:addSpawnedGroup(%s)",self.name or "", group:GetName() or ""))
    if not self.spawnedGroups then 
        self.spawnedGroups = {}
    end
    table.insert(self.spawnedGroups, group)
    return self
end

function VeafCombatMission:getSpawnedGroups()
    veafCombatMission.logDebug(string.format("VeafCombatMission[%s]:getSpawnedGroups()",self.name or ""))
    for _, group in pairs(self.spawnedGroups) do
        veafCombatMission.logTrace(string.format("spawnedGroups[%s]",group:GetName()))
    end
    return self.spawnedGroups
end

function VeafCombatMission:clearSpawnedGroups()
    self.spawnedGroups = {}
    return self
end

function VeafCombatMission:addObjective(objective)
    veafCombatMission.logDebug(string.format("VeafCombatMission[%s]:addObjective(%s)",self.name or "", objective:getName() or ""))
    if not self.objectives then 
        self.objectives = {}
    end
    table.insert(self.objectives, objective)
    return self
end

function VeafCombatMission:isHidden()
    return self.hidden
end

function VeafCombatMission:setHidden(value)
    self.hidden = value
    return self
end

function VeafCombatMission:isSilent()
    return self.silent
end

function VeafCombatMission:setSilent(value)
    self.silent = value
    return self
end

function VeafCombatMission:isRadioMenuEnabled()
    return self.radioMenuEnabled
end

function VeafCombatMission:setRadioMenuEnabled(value)
    self.radioMenuEnabled = value
    return self
end

function VeafCombatMission:setAllElementsSkill(skill)
    for _, element in self.elements do
        element:setSkill(skill)
    end
    return self
end
---
--- other methods
---

function VeafCombatMission:scheduleWatchdogFunction()
    veafCombatMission.logDebug(string.format("VeafCombatMission[%s]:scheduleWatchdogFunction()",self.name or ""))
    self.watchdogFunctionId = mist.scheduleFunction(veafCombatMission.CompletionCheck,{self.name},timer.getTime()+veafCombatMission.SecondsBetweenWatchdogChecks)
    return self
end

function VeafCombatMission:unscheduleWatchdogFunction()
    veafCombatMission.logDebug(string.format("VeafCombatMission[%s]:unscheduleWatchdogFunction()",self.name or ""))
    if self.watchdogFunctionId then
        veafCombatMission.logDebug(string.format("mist.removeFunction()"))
        mist.removeFunction(self.watchdogFunctionId)
        self.watchdogFunctionId = nil
    end
    return self
end

function VeafCombatMission:addObjective(value)
    table.insert(self.objectives, value)
    return self
end

function VeafCombatMission:getObjectives()
    return self.objectives
end

function VeafCombatMission:addDefaultObjectives()
    -- TODO
    return self
end

function VeafCombatMission:initialize()
    veafCombatMission.logDebug(string.format("VeafCombatMission[%s]:initialize()",self.name or ""))

    -- check parameters
    if not self.name then 
        return self 
    end
    if not self.friendlyName then 
        self:setFriendlyName(self.name)
    end
    if #self.objectives == 0 then
        self:addDefaultObjectives()
    end

    -- refresh the radio menu
    self:updateRadioMenu()

    return self
end

function VeafCombatMission:getInformation()
    veafCombatMission.logDebug(string.format("VeafCombatMission[%s]:getInformation()",self.name or ""))
    local message =      "COMBAT MISSION "..self:getFriendlyName().." \n\n"
    if (self:getBriefing()) then
        message = message .. "BRIEFING: \n"
        message = message .. self:getBriefing()
        message = message .. "\n\n"
    end
    if (self:getObjectives() and #self:getObjectives() > 0) then
        message = message .. "OBJECTIVES: \n"
        for _, objective in pairs(self:getObjectives()) do
            message = message .. " - " .. objective:getDescription() .. "\n"
        end
        message = message .. "\n\n"
    end
    if self:isActive() then

        -- generate information dispatch

        -- TODO count remaining enemies
        local nbDeadUnits = 0
        local nbLiveUnits = 0

        for _, group in pairs(self:getSpawnedGroups()) do
            veafCombatMission.logTrace(string.format("processing group [%s]",group:GetName()))
            if group:GetUnits() then
                for _, unit in pairs(group:GetUnits()) do
                    veafCombatMission.logTrace(string.format("processing unit [%s]",unit:GetName()))
                    veafCombatMission.logTrace(string.format("unit:GetLifeRelative() = %f",unit:GetLifeRelative()))
                    if unit:GetLifeRelative() == 1.0 then
                        veafCombatMission.logTrace(string.format("unit[%s] is alive",unit:GetName()))
                        nbLiveUnits = nbLiveUnits + 1
                    elseif unit:GetLifeRelative() > 0 then
                        veafCombatMission.logTrace(string.format("unit[%s] is damaged (%d %%)",unit:GetName(), unit:GetLifeRelative()*100 ))
                        nbLiveUnits = nbLiveUnits + 1
                    else
                        veafCombatMission.logTrace(string.format("unit[%s] is dead",unit:GetName()))
                        nbDeadUnits = nbDeadUnits + 1
                    end
                end
            else -- this is a bug but let's say that if there are no units in a group we count one kill
                nbDeadUnits = nbDeadUnits + 1
            end
        end

        veafCombatMission.logTrace(string.format("nbLiveUnits = %d",nbLiveUnits))
        veafCombatMission.logTrace(string.format("nbDeadUnits = %d",nbDeadUnits))

        message = message .. string.format("ENEMIES : %d alive, %d dead\n", nbLiveUnits, nbDeadUnits)

        if self:isTraining() then 
            -- TODO find the position of the enemies
        end

    else
        message = message .. "mission is not yet active."
    end

    return message
end

-- activate the mission
function VeafCombatMission:activate(silent)
    veafCombatMission.logTrace(string.format("VeafCombatMission[%s]:activate(%s)",self:getName(), tostring(silent)))
    
    -- don't start twice
    if self:isActive() then 
        return nil
    end

    self:setActive(true)
    self:setSilent(self:isHidden() or silent)

    for _, missionElement in pairs(self.elements) do
        veafCombatMission.logTrace(string.format("processing element [%s]",missionElement:getName()))
        local chance = math.random(0, 100)
        if chance <= missionElement:getSpawnChance() then
            -- spawn the element
            veafCombatMission.logTrace(string.format("chance hit (%d <= %d)",chance, missionElement:getSpawnChance()))
            for _, groupName in pairs(missionElement:getGroups()) do
                local spawn = SPAWN:New(groupName)
                                    :InitSkill(missionElement:getSkill())
                                    :InitCoalition(missionElement:getCoalition())
                local spawnRadius = missionElement:getSpawnRadius()
                if (missionElement:getScale() > 1 and spawnRadius < 150) then
                    spawnRadius = 150 
                end
                spawn = spawn:InitRandomizePosition(true, spawnRadius, nil)
                for i=1,missionElement:getScale() do
                    local group = spawn:Spawn()
                    self:addSpawnedGroup(group)
                end
            end
        else 
            veafCombatMission.logTrace(string.format("chance missed (%d > %d)",chance, missionElement:getSpawnChance()))
        end
    end

    -- start all the objectives
    for _, objective in pairs(self.objectives) do
        objective:onStartup(self)
    end

    -- start the completion watchdog
    self:scheduleWatchdogFunction()

    -- refresh the radio menu
    self:updateRadioMenu()

    return self
end

-- desactivate the mission
function VeafCombatMission:desactivate()
    veafCombatMission.logDebug(string.format("VeafCombatMission[%s]:desactivate()",self.name or ""))
    self:setActive(false)
    self:unscheduleWatchdogFunction()

    for _, group in pairs(self:getSpawnedGroups()) do
        veafCombatMission.logTrace(string.format("trying to destroy group [%s]",group:GetName()))
        group:Destroy(false)
    end
    self:clearSpawnedGroups()

    -- refresh the radio menu
    self:updateRadioMenu()

    return self
end

-- check if there are still units in mission
function VeafCombatMission:completionCheck()
    veafCombatMission.logDebug(string.format("VeafCombatMission[%s]:completionCheck()",self.name or ""))

    VeafCombatMissionObjective.FAILED = -1
    VeafCombatMissionObjective.SUCCESS = 1
    VeafCombatMissionObjective.NOTHING = 0

    local reschedule = true

    -- check all the objectives
    for _, objective in pairs(self.objectives) do
        local result = objective:onCheck(self)
        if result == VeafCombatMissionObjective.FAILED then
            -- mission is failed
            local message = string.format([[
Objective not met : %s
The mission %s will now end.
You can replay by starting it again, in the radio menu.]], objective:getDescription(), self:getFriendlyName())
            if not self:isSilent() then 
                trigger.action.outText(message, 15)
            end
            self:desactivate()
            reschedule = false
        elseif result == VeafCombatMissionObjective.SUCCESS then
            -- mission is won
            local message = string.format([[
All objectives were met !
The mission %s is a success ! It will now end.
You can replay by starting it again, in the radio menu.]], self:getFriendlyName())
            if not self:isSilent() then 
                trigger.action.outText(message, 15) 
            end
            self:desactivate()
            reschedule = false
        end
    end

    if reschedule then
        -- reschedule
        self:scheduleWatchdogFunction()
    end
end

-- updates the radio menu according to the mission state
function VeafCombatMission:updateRadioMenu(inBatch)
    veafCombatMission.logDebug(string.format("VeafCombatMission[%s]:updateRadioMenu(%s)",self.name or "", tostring(inBatch)))

    -- do not update the radio menu for a mission that has no menu
    if not self:isRadioMenuEnabled() then
        return self
    end
    
    -- do not update the radio menu if not yet initialized
    if not veafCombatMission.rootPath then
        return self
    end

    -- reset the radio menu
    if self.radioRootPath then
        veafCombatMission.logTrace("reset the radio submenu")
        veafRadio.clearSubmenu(self.radioRootPath)
    else
        veafCombatMission.logTrace("add the radio submenu")
        self.radioRootPath = veafRadio.addSubMenu(self:getRadioMenuName(), veafCombatMission.rootPath)
    end

    -- populate the radio menu
    veafCombatMission.logTrace("populate the radio menu")
    -- global commands
    veafRadio.addCommandToSubmenu("Get info", self.radioRootPath, veafCombatMission.GetInformationOnMission, self.name, veafRadio.USAGE_ForGroup)
    if self:isActive() then
        -- mission is active, set up accordingly (desactivate mission, get information, pop smoke, etc.)
        veafCombatMission.logTrace("mission is active")
        if self:isSecured() then
            veafRadio.addSecuredCommandToSubmenu('Desactivate mission', self.radioRootPath, veafCombatMission.DesactivateMission, self.name, veafRadio.USAGE_ForAll)
        else
            veafRadio.addCommandToSubmenu('Desactivate mission', self.radioRootPath, veafCombatMission.DesactivateMission, self.name, veafRadio.USAGE_ForAll)
        end
    else
        -- mission is not active, set up accordingly (activate mission)
        veafCombatMission.logTrace("mission is not active")
        if self:isSecured() then
            veafRadio.addSecuredCommandToSubmenu('Activate mission', self.radioRootPath, veafCombatMission.ActivateMission, self.name, veafRadio.USAGE_ForAll)
        else
            veafRadio.addCommandToSubmenu('Activate mission', self.radioRootPath, veafCombatMission.ActivateMission, self.name, veafRadio.USAGE_ForAll)
        end
    end

    if not inBatch then veafRadio.refreshRadioMenu() end
    return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- global functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafCombatMission.GetMissionNumber(number)
    veafCombatMission.logDebug(string.format("veafCombatMission.GetMissionNumber([%s])",tostring(number)))
    local mission = veafCombatMission.missionsList[number]
    return mission
end

function veafCombatMission.GetMission(name)
    veafCombatMission.logDebug(string.format("veafCombatMission.GetMission([%s])",name or ""))
    veafCombatMission.logDebug(string.format("Searching for mission with name [%s]", name))
    local mission = veafCombatMission.missionsDict[name]
    if not mission then 
        local message = string.format("VeafCombatMission [%s] was not found !",name)
        veafCombatMission.logError(message)
        trigger.action.outText(message,5)
    end
    return mission
end

-- add a mission
function veafCombatMission.AddMission(mission)
    veafCombatMission.logDebug(string.format("veafCombatMission.AddMission([%s])",mission:getName() or ""))
    veafCombatMission.logInfo(string.format("Adding mission [%s]", mission:getName()))
    mission:initialize()
    table.insert(veafCombatMission.missionsList, mission)
    veafCombatMission.missionsDict[mission:getName()] = mission
    return mission
end

-- add a mission and create copies with different skills
function veafCombatMission.AddMissionsWithSkillAndScale(mission, skills, scales)
    veafCombatMission.logDebug(string.format("veafCombatMission.AddMissionsWithSkill([%s])",mission:getName() or ""))
    
    if (mission:isRadioMenuEnabled()) then
        veafCombatMission.AddMission(mission)
    end

    local skills = skills or  {"Average", "Good", "High", "Excellent", "Random"}
    local scales = scales or {1, 2, 3, 4}
    
    for _, scale in pairs(scales) do
        for _, skill in pairs(skills) do 
            local copy = mission:copy(skill, scale):setRadioMenuEnabled(false)
            copy:setName(mission:getName().."/"..skill.."/"..scale)
            copy:setFriendlyName(mission:getFriendlyName().."/"..skill.."/"..scale)
            veafCombatMission.AddMission(copy)
        end
    end

    return mission
end

-- activate a mission by number
function veafCombatMission.ActivateMissionNumber(number, silent)
    local mission = veafCombatMission.GetMissionNumber(number)
    if mission then 
        veafCombatMission.ActivateMission(mission:getName(), silent)
    end
end

-- activate a mission
function veafCombatMission.ActivateMission(name, silent)
    veafCombatMission.logDebug(string.format("veafCombatMission.ActivateMission([%s])",name or ""))
    local mission = veafCombatMission.GetMission(name)
    local result = mission:activate(silent)
    if not silent and not mission:isSilent() then
        if result then
            trigger.action.outText("VeafCombatMission "..mission:getFriendlyName().." has been activated.", 10)
            mist.scheduleFunction(veafCombatMission.GetInformationOnMission,{{name}},timer.getTime()+1)
        else
            trigger.action.outText("VeafCombatMission "..mission:getFriendlyName().." was already active.", 10)
        end
    end
end

-- desactivate a mission by number
function veafCombatMission.DesactivateMissionNumber(number, silent)
    local mission = veafCombatMission.GetMission(number)
    if mission then 
        veafCombatMission.DesactivateMission(mission:getName(), silent)
    end
end

-- desactivate a mission
function veafCombatMission.DesactivateMission(name, silent)
    veafCombatMission.logDebug(string.format("veafCombatMission.DesactivateMission([%s])",name or ""))
    local mission = veafCombatMission.GetMission(name)
    mission:desactivate()
    if not silent and not mission:isSilent() then
        trigger.action.outText("VeafCombatMission "..mission:getFriendlyName().." has been desactivated.", 10)
    end
end

-- print information about a mission
function veafCombatMission.GetInformationOnMission(parameters)
    local name, unitName = unpack(parameters)
    veafCombatMission.logDebug(string.format("veafCombatMission.GetInformationOnMission([%s])",name or ""))
    local mission = veafCombatMission.GetMission(name)
    local text = mission:getInformation()
    if unitName then
        veaf.outTextForUnit(unitName, text, 30)
    else
        trigger.action.outText(text, 30)
    end
end

-- call the completion watchdog methods
function veafCombatMission.CompletionCheck(name)
    veafCombatMission.logDebug(string.format("veafCombatMission.CompletionCheck([%s])",name or ""))
    local mission = veafCombatMission.GetMission(name)
    mission:completionCheck()
end


-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafCombatMission.buildRadioMenu()
    veafCombatMission.logDebug("buildRadioMenu()")
    veafCombatMission.rootPath = veafRadio.addMenu(veafCombatMission.RadioMenuName)
    veafRadio.addCommandToSubmenu("HELP", veafCombatMission.rootPath, veafCombatMission.help, nil, veafRadio.USAGE_ForGroup)
    veafRadio.addCommandToSubmenu("List available", veafCombatMission.rootPath, veafCombatMission.listAvailableMissions, nil, veafRadio.USAGE_ForAll)
    veafRadio.addCommandToSubmenu("List active", veafCombatMission.rootPath, veafCombatMission.listActiveMissions, nil, veafRadio.USAGE_ForAll)
    
    -- sort the missions alphabetically
    names = {}
    sortedMissions = {}
    for _, mission in pairs(veafCombatMission.missionsDict) do
        table.insert(sortedMissions, {name=mission:getName(), sort=mission:getFriendlyName()})
    end
    function compare(a,b)
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
    table.sort(sortedMissions, compare)
    for i = 1, #sortedMissions do
        table.insert(names, sortedMissions[i].name)
    end

    veafAssets.logTrace("veafCombatMission.buildRadioMenu() - dumping names")
    for i = 1, #names do
        veafCombatMission.logTrace("veafCombatMission.buildRadioMenu().names -> " .. names[i])
    end
    
    for _, missionName in pairs(names) do
        local mission = veafCombatMission.GetMission(missionName)
        mission:updateRadioMenu(true)
    end
    
    veafRadio.refreshRadioMenu()
end

function veafCombatMission.help(unitName)
    local text =
        'Combat missions are defined by the mission maker, and listed here\n' ..
        'You can start and stop them at will,\n' ..
        'as well as ask for information about their status.'

    veaf.outTextForUnit(unitName, text, 30)
end

function veafCombatMission.listAvailableMissions() 
    -- sort the missions alphabetically
    sortedMissions = {}
    missions = {}
    for _, mission in pairs(veafCombatMission.missionsDict) do
        local missionName = mission:getName()
        veafCombatMission.logTrace(string.format("missionName=%s", missionName))
        missionName = missionName:gsub("/Random/%d", "/<Skill>/<Scale>")
        missionName = missionName:gsub("/Average/%d", "/<Skill>/<Scale>")
        missionName = missionName:gsub("/Good/%d", "/<Skill>/<Scale>")
        missionName = missionName:gsub("/High/%d", "/<Skill>/<Scale>")
        missionName = missionName:gsub("/Excellent/%d", "/<Skill>/<Scale>")
        veafCombatMission.logTrace(string.format("missionName=%s", missionName))
        if not(missions[missionName]) then
            missions[missionName] = true
            table.insert(sortedMissions, missionName)
        end
    end
    table.sort(sortedMissions)
    
    local text =
    'List of all available combat missions:\n'

    for _, missionName in pairs(sortedMissions) do
        text = text .. " - " .. missionName .. "\n"
    end
    
    trigger.action.outText(text, 20)
end

function veafCombatMission.listActiveMissions() 
    -- sort the missions alphabetically
    sortedMissions = {}
    for _, mission in pairs(veafCombatMission.missionsDict) do
        if mission:isActive() then
            table.insert(sortedMissions, mission:getName())
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
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafCombatMission.initialize()
    veafCombatMission.logInfo("Initializing module")
    veafCombatMission.buildRadioMenu()
end

veafCombatMission.logInfo(string.format("Loading version %s", veafCombatMission.Version))
