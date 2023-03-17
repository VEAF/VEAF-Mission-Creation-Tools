------------------------------------------------------------------
-- VEAF combat mission functions for DCS World
-- By zip (2020)
--
-- Features:
-- ---------
-- * A combat mission consists in spawning enemy aircrafts
-- * It also contains a mass briefing, optional objectives (timed, number of kills, ...) and can trigger the activation of one or more combat zones
-- * For each mission, a specific radio sub-menu is created, allowing common actions (get mission status, weather, briefing, start and stop the mission, etc.)
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafCombatMission = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafCombatMission.Id = "COMBATMISSION"

--- Version.
veafCombatMission.Version = "2.1.3"

-- trace level, specific to this module
--veafCombatMission.LogLevel = "trace"

veaf.loggers.new(veafCombatMission.Id, veafCombatMission.LogLevel)

--- Number of seconds between each check of the watchdog function
veafCombatMission.SecondsBetweenWatchdogChecks = 30

veafCombatMission.RadioMenuName = "MISSIONS"

veafCombatMission.MinimumSpacingBetweenClones = 300 -- minimum spawn distance between clones of a group

veafCombatMission.RemoteCommandParser = "([[a-zA-Z0-9]+)%s?([^%s]*)%s?(.*)"

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

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafCombatMissionObjective object
-------------------------------------------------------------------------------------------------------------------------------------------------------------
VeafCombatMissionObjective = {}

VeafCombatMissionObjective.FAILED = -1
VeafCombatMissionObjective.SUCCESS = 1
VeafCombatMissionObjective.NOTHING = 0

function VeafCombatMissionObjective:new(objectToCopy)
    local objectToCreate = objectToCopy or {} -- create object if user does not provide one
    setmetatable(objectToCreate, self)
    self.__index = self

    -- init the new object

    -- technical name
    objectToCreate.name = nil
    -- description for the briefing
    objectToCreate.description = nil
    -- message when the objective is completed
    objectToCreate.message = nil
    -- parameters
    objectToCreate.parameters = {}
    -- function that is call when the mission starts
    objectToCreate.onStartupFunction = nil
    -- function that is called when the completion check watchdog runs (should check for objective completion and return one of the FAILED, SUCCESS or NOTHING constants)
    objectToCreate.onCheckFunction = nil

    return objectToCreate
end

function VeafCombatMissionObjective:copy()
    local copy = VeafCombatMissionObjective:new()

    -- copy the attributes
    copy.name = self.name
    copy.description = self.description
    copy.onStartupFunction = self.onStartupFunction
    copy.onCheckFunction = self.onCheckFunction

    -- deep copy the collections
    copy.parameters = {}
    for name, value in pairs(self.parameters) do
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("copying parameter %s : ",tostring(name)))
        copy.parameters[name]=value
    end

    return copy
end

---
--- setters and getters
---

function VeafCombatMissionObjective:setName(value)
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("VeafCombatMissionObjective.setName([%s])",value or ""))
    self.name = value
    return self
end

function VeafCombatMissionObjective:getName()
    return self.name
end

function VeafCombatMissionObjective:setDescription(value)
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("VeafCombatMissionObjective[%s].setDescription([%s])", self:getName() or "", value or ""))
    self.description = value
    return self
end

function VeafCombatMissionObjective:getDescription()
    return self.description
end

function VeafCombatMissionObjective:setMessage(value)
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("VeafCombatMissionObjective[%s].setMessage([%s])", self:getName() or "", value or ""))
    self.message = value
    return self
end

function VeafCombatMissionObjective:getMessage()
    return self.message
end

function VeafCombatMissionObjective:setParameters(value)
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("VeafCombatMissionObjective[%s].setParameters([%s])", self:getName() or "", veaf.p(value or "")))
    self.parameters = value
    return self
end

function VeafCombatMissionObjective:getParameters()
    return self.parameters
end

function VeafCombatMissionObjective:setOnCheck(value)
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("VeafCombatMissionObjective[%s].setOnCheck(some function)",self:getName()))
    self.onCheckFunction = value
    return self
end

function VeafCombatMissionObjective:getOnCheck()
    return self.onCheckFunction
end

function VeafCombatMissionObjective:setOnStartup(value)
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("VeafCombatMissionObjective[%s].setOnStartup(some function)", self:getName()))
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
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("VeafCombatMissionObjective[%s].onCheck([%s])", self:getName() or "", mission:getName() or ""))
    if self.onCheckFunction then
        return self.onCheckFunction(mission, self.parameters)
    else
        return VeafCombatMissionObjective.NOTHING
    end
end

function VeafCombatMissionObjective:onStartup(mission)
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("VeafCombatMissionObjective[%s].onStartup([%s])", self:getName() or "", mission:getName() or ""))
    if self.onStartupFunction then
        return self.onStartupFunction(self.parameters)
    end
end

function VeafCombatMissionObjective:configureAsTimedObjective(timeInSeconds)
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("VeafCombatMissionObjective[%s].configureAsTimedObjective()",self:getName()))

    local function onCheck(mission, parameters)
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("VeafCombatMissionObjective.NewTimedObjective.onCheck()"))
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
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("VeafCombatMissionObjective[%s].configureAsKillEnemiesObjective()",self:getName()))

    local function onCheck(mission, parameters)
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("VeafCombatMissionObjective.configureAsKillEnemiesObjective.onCheck()"))
        if mission:isActive() then
            local nbKillsToWin = parameters.nbKillsToWin
            local whatsInAKill = parameters.whatsInAKill
            veaf.loggers.get(veafCombatMission.Id):trace(string.format("nbKillsToWin = %d",nbKillsToWin))
            veaf.loggers.get(veafCombatMission.Id):trace(string.format("whatsInAKill = %d",whatsInAKill))

            local nbLiveUnits, nbDamagedUnits, nbDeadUnits = mission:getRemainingEnemies(whatsInAKill)

            veaf.loggers.get(veafCombatMission.Id):trace(string.format("nbLiveUnits = %d",nbLiveUnits))
            veaf.loggers.get(veafCombatMission.Id):trace(string.format("nbDamagedUnits = %d",nbDamagedUnits))
            veaf.loggers.get(veafCombatMission.Id):trace(string.format("nbDeadUnits = %d",nbDeadUnits))

            if (nbKillsToWin == -1 and nbLiveUnits == 0) or (nbKillsToWin >= 0 and nbDeadUnits >= nbKillsToWin) then
                -- objective is achieved
                veaf.loggers.get(veafCombatMission.Id):trace(string.format("objective is achieved"))
                local msg = string.format(self:getMessage(), nbDeadUnits)
                if not mission:isSilent() then
                    trigger.action.outText(msg, 15)
                end
                return VeafCombatMissionObjective.SUCCESS
            else
                veaf.loggers.get(veafCombatMission.Id):trace(string.format("objective is NOT achieved"))
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
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("VeafCombatMissionObjective[%s].configureAsPreventDestructionOfSceneryObjectsInZone()",self:getName()))

    local function onCheck(mission, parameters)
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("VeafCombatMissionObjective.configureAsPreventDestructionOfSceneryObjectsInZone.onCheck()"))
        if mission:isActive() then

            local zones = parameters.zones
            local objects = parameters.objects
            local failed = false
            local killedObjectsNames = nil

            local killedObjects = mist.getDeadMapObjsInZones(zones)
            ----veaf.loggers.get(veafCombatMission.Id):trace(veaf.serialize("killedObjects", killedObjects))

            for _, object in pairs(killedObjects) do
                veaf.loggers.get(veafCombatMission.Id):trace(string.format("checking id_ = [%s]", object.object.id_))
                if objects[object.object.id_] then
                    veaf.loggers.get(veafCombatMission.Id):trace(string.format("found [%s]", objects[object.object.id_]))
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
                veaf.loggers.get(veafCombatMission.Id):trace(string.format("objective is failed"))
                local msg = string.format(self:getMessage(), killedObjectsNames)
                if not mission:isSilent() then
                    trigger.action.outText(msg, 15)
                end
                return VeafCombatMissionObjective.FAILED
            else
                veaf.loggers.get(veafCombatMission.Id):trace(string.format("objective is NOT failed"))
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
VeafCombatMissionElement = {}

function VeafCombatMissionElement:new(objectToCopy)
    local objectToCreate = objectToCopy or {} -- create object if user does not provide one
    setmetatable(objectToCreate, self)
    self.__index = self

    -- init the new object

    -- name
    objectToCreate.name = nil
    -- groups : a list of group names that compose this element
    objectToCreate.groups = {}
    -- skill ("Average", "Good", "High", "Excellent" or "Random"), defaults to "Random"
    objectToCreate.skill = "Random" -- SPAWN:InitSkill(Skill)
    -- spawn radius in meters (randomness introduced in the respawn mechanism)
    objectToCreate.spawnRadius = 0 -- SPAWN:InitRandomizePosition
    -- spawn chance in percent (xx chances in 100 that the unit is spawned - or the command run)
    objectToCreate.spawnChance = 100
    -- the element can be multiplied to scale the mission
    objectToCreate.scale = 1
    -- if true, the element is scalable
    objectToCreate.scalable = true
    -- init tables (no need to init simple values)

    return objectToCreate
end

function VeafCombatMissionElement:copy()
    local copy = VeafCombatMissionElement:new()

    -- copy the attributes
    copy.name = self.name
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
    copy.spawnPoints = {}
    for groupName, spawnPoint in pairs(self.spawnPoints) do
        copy.spawnPoints[groupName] = spawnPoint
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
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("VeafCombatMissionElement[%s]:setGroups(%s)",veaf.p(self.name), veaf.p(value)))
    self.groups = value
    self.spawnPoints = {}
    for _, groupName in pairs(self.groups) do
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("processing groupName=%s",veaf.p(groupName)))
        local _group = Group.getByName(groupName)
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("_group=%s",veaf.p(_group)))
        if _group then
            local _unit1 = _group:getUnit(1)
            veaf.loggers.get(veafCombatMission.Id):trace(string.format("_unit1=%s",veaf.p(_unit1)))
            if _unit1 then
                veaf.loggers.get(veafCombatMission.Id):trace(string.format("_unit1:getPoint()=%s",veaf.p(_unit1:getPoint())))
                self.spawnPoints[groupName] = _unit1:getPoint()
            end
        end
    end
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

VeafCombatMission = {
    -- mission name (technical)
    name = nil,
    -- mission name (human-friendly)
    friendlyName = nil,
    -- mission briefing
    briefing = nil,
    -- secured :  if true, the radio menu will be secured
    secured = false,
    -- list of objectives
    objectives = {},
    -- list of the elements defined in the mission
    elements = {},
    -- mission is active
    active = false,
    -- mission is a training mission
    training = false,
    -- DCS groups that have been spawned (for cleaning up later)
    spawnedGroups = {},
    --- Radio menus paths
    radioMarkersPath = nil,
    radioTargetInfoPath = nil,
    radioRootPath = nil,
    -- the watchdog function checks for mission objectives completion
    watchdogFunctionId = nil,
    -- if false, the mission will not appear in the radio menu
    radioMenuEnabled = false,
    -- if true, no message will be displayed when activating/deactivating the mission
    hidden = false,
    -- same as hidden but only valid for one activation of the mission (will be reset to *hidden* at next start)
    silent = false,
    spawnedUnitsCountByGroup = {},
    spawnedNamesIndex = {}
}

function VeafCombatMission:new(objectToCopy)
    local objectToCreate = objectToCopy or {} -- create object if user does not provide one
    setmetatable(objectToCreate, self)
    self.__index = self
    
    -- init the new object
    
    -- mission name (technical)
    objectToCreate.name = nil
    -- mission name (human-friendly)
    objectToCreate.friendlyName = nil
    -- mission briefing
    objectToCreate.briefing = nil
    -- secured :  if true, the radio menu will be secured
    objectToCreate.secured = false
    -- list of objectives
    objectToCreate.objectives = {}
    -- list of the elements defined in the mission
    objectToCreate.elements = {}
    -- mission is active
    objectToCreate.active = false
    -- mission is a training mission
    objectToCreate.training = false
    -- DCS groups that have been spawned (for cleaning up later)
    objectToCreate.spawnedGroups = {}
    --- Radio menus paths
    objectToCreate.radioMarkersPath = nil
    objectToCreate.radioTargetInfoPath = nil
    objectToCreate.radioRootPath = nil
    -- the watchdog function checks for mission objectives completion
    objectToCreate.watchdogFunctionId = nil
    -- if false, the mission will not appear in the radio menu
    objectToCreate.radioMenuEnabled = false
    -- if true, no message will be displayed when activating/deactivating the mission
    objectToCreate.hidden = false
    -- same as hidden but only valid for one activation of the mission (will be reset to *hidden* at next start)
    objectToCreate.silent = false
    objectToCreate.spawnedUnitsCountByGroup = {}
    objectToCreate.spawnedNamesIndex = {}

    return objectToCreate
end

function VeafCombatMission:copy(newSkill, newScale)
    local copy = VeafCombatMission:new()

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
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("VeafCombatMission[%s]:addSpawnedGroup(%s)",self.name or "", group:getName() or ""))
    if not self.spawnedGroups then
        self.spawnedGroups = {}
    end
    table.insert(self.spawnedGroups, group)

    -- count units in group
    self.spawnedUnitsCountByGroup[group:getName()] = #group:getUnits()
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("%s units in group [%s]",tostring(self.spawnedUnitsCountByGroup[group:getName()]), tostring(group:getName())))

    return self
end

function VeafCombatMission:getSpawnedGroups()
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("VeafCombatMission[%s]:getSpawnedGroups()",self.name or ""))
    for _, group in pairs(self.spawnedGroups) do
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("spawnedGroups[%s]",group:getName()))
    end
    return self.spawnedGroups
end

function VeafCombatMission:clearSpawnedGroups()
    self.spawnedGroups = {}
    return self
end

function VeafCombatMission:addObjective(objective)
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("VeafCombatMission[%s]:addObjective(%s)",self.name or "", objective:getName() or ""))
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
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("VeafCombatMission[%s]:scheduleWatchdogFunction()",self.name or ""))
    self.watchdogFunctionId = mist.scheduleFunction(veafCombatMission.CompletionCheck,{self.name},timer.getTime()+veafCombatMission.SecondsBetweenWatchdogChecks)
    return self
end

function VeafCombatMission:unscheduleWatchdogFunction()
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("VeafCombatMission[%s]:unscheduleWatchdogFunction()",self.name or ""))
    if self.watchdogFunctionId then
        veaf.loggers.get(veafCombatMission.Id):debug(string.format("mist.removeFunction()"))
        mist.removeFunction(self.watchdogFunctionId)
        self.watchdogFunctionId = nil
    end
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
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("VeafCombatMission[%s]:initialize()",self.name or ""))

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

function VeafCombatMission:getRemainingEnemiesString()
    local nbLiveUnits, nbDamagedUnits, nbDeadUnits = self:getRemainingEnemies()
    return string.format("%d alive (%d damaged), %d dead", nbLiveUnits, nbDamagedUnits, nbDeadUnits)
end

function VeafCombatMission:getRemainingEnemies(whatsInAKill)
    local whatsInAKill = whatsInAKill or 0.01
    local nbLiveUnits = 0
    local nbDamagedUnits = 0
    local nbDeadUnits = 0
    for _, group in pairs(self:getSpawnedGroups()) do
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("processing group [%s]",group:getName()))
        local groupLiveUnits = 0
        local groupDamagedUnits = 0
        if group and group:getUnits() then
            for _, unit in pairs(group:getUnits()) do
                veaf.loggers.get(veafCombatMission.Id):trace(string.format("processing unit [%s]",unit:getName()))
                veaf.loggers.get(veafCombatMission.Id):trace(string.format("veaf.getUnitLifeRelative(unit) = %f",veaf.getUnitLifeRelative(unit)))
                if veaf.getUnitLifeRelative(unit) == 1.0 then
                    veaf.loggers.get(veafCombatMission.Id):trace(string.format("unit[%s] is alive",unit:getName()))
                    groupLiveUnits = groupLiveUnits + 1
                elseif veaf.getUnitLifeRelative(unit) > whatsInAKill then
                    veaf.loggers.get(veafCombatMission.Id):trace(string.format("unit[%s] is damaged (%d %%)",unit:getName(), veaf.getUnitLifeRelative(unit)*100 ))
                    groupDamagedUnits = groupDamagedUnits + 1
                    groupLiveUnits = groupLiveUnits + 1
                else
                    veaf.loggers.get(veafCombatMission.Id):trace(string.format("unit[%s] is dead",unit:getName()))
                    -- should never come to that, Moose do not return dead units in getUnits()
                end
            end
        else
            groupLiveUnits = 0
        end
        local groupDeadUnits = (self.spawnedUnitsCountByGroup[group:getName()] or 0) - groupLiveUnits
        if groupDeadUnits < 0 then -- should never happen but who knows ? This is DCS !
            groupDeadUnits = 0
        end

        veaf.loggers.get(veafCombatMission.Id):trace(string.format("groupLiveUnits = %d",groupLiveUnits))
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("groupDamagedUnits = %d",groupDamagedUnits))
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("groupDeadUnits = %d",groupDeadUnits))

        nbLiveUnits = nbLiveUnits + groupLiveUnits
        nbDamagedUnits = nbDamagedUnits + groupDamagedUnits
        nbDeadUnits = nbDeadUnits + groupDeadUnits
    end

    veaf.loggers.get(veafCombatMission.Id):trace(string.format("nbLiveUnits = %d",nbLiveUnits))
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("nbDamagedUnits = %d",nbDamagedUnits))
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("nbDeadUnits = %d",nbDeadUnits))

    return nbLiveUnits, nbDamagedUnits, nbDeadUnits
end

function VeafCombatMission:getInformation()
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("VeafCombatMission[%s]:getInformation()",self.name or ""))
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
        message = message .. "ENEMIES : " ..self:getRemainingEnemiesString() .."\n"

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
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("VeafCombatMission[%s]:activate(%s)",self:getName(), tostring(silent)))

    -- don't start twice
    if self:isActive() then
        return nil
    end

    self:setActive(true)
    self:setSilent(self:isHidden() or silent)

    for _, missionElement in pairs(self.elements) do
        veaf.loggers.get(veafCombatMission.Id):debug(string.format("processing element [%s]",missionElement:getName()))
        local chance = math.random(0, 100)
        if chance <= missionElement:getSpawnChance() then
            -- spawn the element
            veaf.loggers.get(veafCombatMission.Id):debug(string.format("chance hit (%d <= %d)",chance, missionElement:getSpawnChance()))
            for _, groupName in pairs(missionElement:getGroups()) do
                local _spawnPoint = missionElement.spawnPoints[groupName]
                veaf.loggers.get(veafCombatMission.Id):trace(string.format("_spawnPoint=%s",veaf.p(_spawnPoint)))
                local _spawnRadius = missionElement:getSpawnRadius()
                if (missionElement:getScale() > 1 and _spawnRadius < veafCombatMission.MinimumSpacingBetweenClones) then
                    _spawnRadius = veafCombatMission.MinimumSpacingBetweenClones
                end
                veaf.loggers.get(veafCombatMission.Id):trace(string.format("_spawnRadius=%s",veaf.p(_spawnRadius)))

                local vars = {}
                vars.gpName = groupName
                vars.action = 'clone'
                vars.point = _spawnPoint
                vars.radius = _spawnRadius
                vars.disperse = false
                vars.route = mist.getGroupRoute(groupName, 'task')
                --veaf.loggers.get(veafCombatMission.Id):trace(string.format("vars=%s",veaf.p(vars)))

                for i=1,missionElement:getScale() do
                    if not self.spawnedNamesIndex[groupName] then
                        self.spawnedNamesIndex[groupName] = 1
                    else
                        self.spawnedNamesIndex[groupName] = self.spawnedNamesIndex[groupName] + 1
                    end
                    local spawnedGroupName = string.format("%s #%04d", groupName, self.spawnedNamesIndex[groupName])
                    veaf.loggers.get(veafCombatMission.Id):trace(string.format("spawnedGroupName=%s",veaf.p(spawnedGroupName)))
                    local _group = mist.teleportToPoint(vars, true)
                    if _group then
                        for _, unit in pairs(_group.units) do
                            unit.skill = missionElement:getSkill()
                        end
                    end
                    _group.groupName = spawnedGroupName
                    if _group then
                        for _, unit in pairs(_group.units) do
                            local unitName = unit.unitName
                            veaf.loggers.get(veafCombatMission.Id):trace(string.format("unitName=%s",veaf.p(unitName)))
                            if not self.spawnedNamesIndex[unitName] then
                                self.spawnedNamesIndex[unitName] = 1
                            else
                                self.spawnedNamesIndex[unitName] = self.spawnedNamesIndex[unitName] + 1
                            end
                            local spawnedUnitName = string.format("%s #%04d", unitName, self.spawnedNamesIndex[unitName])
                            unit.groupName = spawnedUnitName
                            veaf.loggers.get(veafCombatMission.Id):trace(string.format("spawnedUnitName=%s",veaf.p(spawnedUnitName)))
                        end
                    end
                    veaf.loggers.get(veafCombatMission.Id):trace(string.format("_group=%s",veaf.p(_group)))
                    local _spawnedGroup = mist.dynAdd(_group)
                    if _spawnedGroup then
                        veaf.loggers.get(veafCombatMission.Id):trace(string.format("_spawnedGroup.name=%s",veaf.p(_spawnedGroup.name)))
                        local _dcsSpawnedGroup = Group.getByName(_spawnedGroup.name)
                        veaf.loggers.get(veafCombatMission.Id):trace(string.format("_spawnedGroup.name=%s",veaf.p(_dcsSpawnedGroup:getName())))
                        for _, unit in pairs(_dcsSpawnedGroup:getUnits()) do
                            veaf.loggers.get(veafCombatMission.Id):trace(string.format("_spawnedGroup.unit.name=%s",veaf.p(unit:getName())))
                        end

                        self:addSpawnedGroup(_dcsSpawnedGroup)
                        -- add the group to the Hound Elint, if there is one
                        if veafHoundElint then
                            veaf.loggers.get(veafCombatMission.Id):debug(string.format("veafHoundElint.addPlatformToSystem(%s)",veaf.p(_dcsSpawnedGroup:getName())))
                            veafHoundElint.addPlatformToSystem(_dcsSpawnedGroup)
                        end
                    end
                end
            end
        else
            veaf.loggers.get(veafCombatMission.Id):debug(string.format("chance missed (%d > %d)",chance, missionElement:getSpawnChance()))
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
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("VeafCombatMission[%s]:desactivate()",self.name or ""))
    self:setActive(false)
    self:unscheduleWatchdogFunction()

    for _, group in pairs(self:getSpawnedGroups()) do
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("trying to destroy group [%s]",group:getName()))
        group:destroy()
    end
    self:clearSpawnedGroups()

    -- refresh the radio menu
    self:updateRadioMenu()

    return self
end

-- check if there are still units in mission
function VeafCombatMission:completionCheck()
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("VeafCombatMission[%s]:completionCheck()",self.name or ""))

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
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("VeafCombatMission[%s]:updateRadioMenu(%s)",self.name or "", tostring(inBatch)))

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
        veaf.loggers.get(veafCombatMission.Id):trace("reset the radio submenu")
        veafRadio.clearSubmenu(self.radioRootPath)
    end

    -- populate the radio menu
    veaf.loggers.get(veafCombatMission.Id):trace("populate the radio menu")
    -- global commands
    veafRadio.addCommandToSubmenu("Get info", self.radioRootPath, veafCombatMission.GetInformationOnMission, self.name, veafRadio.USAGE_ForAll)
    if self:isActive() then
        -- mission is active, set up accordingly (desactivate mission, get information, pop smoke, etc.)
        veaf.loggers.get(veafCombatMission.Id):trace("mission is active")
        if self:isSecured() then
            veafRadio.addSecuredCommandToSubmenu('Desactivate mission', self.radioRootPath, veafCombatMission.DesactivateMission, self.name, veafRadio.USAGE_ForAll)
        else
            veafRadio.addCommandToSubmenu('Desactivate mission', self.radioRootPath, veafCombatMission.DesactivateMission, self.name, veafRadio.USAGE_ForAll)
        end
    else
        -- mission is not active, set up accordingly (activate mission)
        veaf.loggers.get(veafCombatMission.Id):trace("mission is not active")
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
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("veafCombatMission.GetMissionNumber([%s])",tostring(number)))
    local mission = veafCombatMission.missionsList[number]
    return mission
end

function veafCombatMission.GetMission(name)
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("veafCombatMission.GetMission([%s])",name or ""))
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("Searching for mission with name [%s]", name))
    local mission = veafCombatMission.missionsDict[name:lower()]
    if not mission then
        local message = string.format("VeafCombatMission [%s] was not found !",name)
        veaf.loggers.get(veafCombatMission.Id):error(message)
        trigger.action.outText(message,5)
    end
    return mission
end

-- add a mission
function veafCombatMission.AddMission(mission)
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("veafCombatMission.AddMission([%s])",mission:getName() or ""))
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("Adding mission [%s]", mission:getName()))
    mission:initialize()
    table.insert(veafCombatMission.missionsList, mission)
    veafCombatMission.missionsDict[mission:getName():lower()] = mission
    return mission
end

-- add a mission and create copies with different skills
function veafCombatMission.AddMissionsWithSkillAndScale(mission, includeOriginal, skills, scales)
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("veafCombatMission.AddMissionsWithSkill([%s])",mission:getName() or ""))
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("skills=%s",veaf.p(skills)))
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("scales=%s",veaf.p(scales)))

    if (mission:isRadioMenuEnabled() and includeOriginal) then
        veafCombatMission.AddMission(mission)
    end

    local skills = skills or  {"Average", "Good", "High", "Excellent", "Random"}
    local scales = scales or {1, 2, 3, 4}

    for _, scale in pairs(scales) do
        for _, skill in pairs(skills) do
            local copy = mission:copy(skill, scale)--:setRadioMenuEnabled(false)
            copy:setName(mission:getName().."/"..skill.."/"..scale)
            copy:setFriendlyName(mission:getFriendlyName())
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
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("veafCombatMission.ActivateMission([%s])",name or ""))
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
    veafCombatMission.buildRadioMenu()
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
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("veafCombatMission.DesactivateMission([%s])",name or ""))
    local mission = veafCombatMission.GetMission(name)
    mission:desactivate()
    if not silent and not mission:isSilent() then
        trigger.action.outText("VeafCombatMission "..mission:getFriendlyName().." has been desactivated.", 10)
    end
    veafCombatMission.buildRadioMenu()
end

-- print information about a mission
function veafCombatMission.GetInformationOnMission(parameters)
    local name, unitName = veaf.safeUnpack(parameters)
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("veafCombatMission.GetInformationOnMission([%s])",name or ""))
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
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("veafCombatMission.CompletionCheck([%s])",name or ""))
    local mission = veafCombatMission.GetMission(name)
    mission:completionCheck()
end


-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------
local function _groupMissions()
    local missionGroups = {}
    local activeGroups = {}

    for _, mission in pairs(veafCombatMission.missionsDict) do
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("grouping missionName=%s", mission:getName()))
        if mission:isRadioMenuEnabled() then
            local regex = ("^([^/]+)/([^/]+)/(.+)$")
            local name, skill, scale = mission:getName():match(regex)
            veaf.loggers.get(veafCombatMission.Id):trace(string.format("name=%s, skill=%s, scale=%s", tostring(name), tostring(skill), tostring(scale)))
            local groupName = name
            if not groupName then groupName = mission:getName() end
            if not(missionGroups[groupName]) then
                missionGroups[groupName] = {}
                --veaf.loggers.get(veafCombatMission.Id):trace(string.format("creating group %s", groupName))
            end
            table.insert(missionGroups[groupName], mission)
            if mission:isActive() then
                veaf.loggers.get(veafCombatMission.Id):trace(string.format("mission %s is active", mission:getName()))
                veaf.loggers.get(veafCombatMission.Id):trace(string.format("activating group %s", groupName))
                if not(activeGroups[groupName]) then
                    activeGroups[groupName] = {}
                end
                if skill then
                    veaf.loggers.get(veafCombatMission.Id):trace(string.format("activating skill %s", skill))
                    if not(activeGroups[groupName][skill]) then
                        activeGroups[groupName][skill] = {}
                    end
                    if scale then
                        veaf.loggers.get(veafCombatMission.Id):trace(string.format("activating scale %s", scale))
                        activeGroups[groupName][skill][scale] = true
                    end
                end
            end
        end
    end
    --veaf.loggers.get(veafCombatMission.Id):trace(string.format("missionGroups=%s",veaf.p(missionGroups)))
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("activeGroups=%s",veaf.p(activeGroups)))
    return missionGroups, activeGroups
end

function veafCombatMission._buildMissionRadioMenu(menu, title, element)
    local missions = element.missions
    if #missions == 1 then
        -- one simple mission
        local mission = missions[1]
        if mission:isActive() then title = "* "..title end
        mission.radioRootPath = veafRadio.addSubMenu(title, menu)
        mission:updateRadioMenu(true)
    else
        -- group by skill and scale
        veaf.loggers.get(veafCombatMission.Id):trace("group by skill and scale")
        local skills = {}
        for _, mission in pairs(missions) do
            local regex = ("^([^/]+)/([^/]+)/(%d+)$")
            local name, skill, scale = mission:getName():match(regex)
            veaf.loggers.get(veafCombatMission.Id):trace(string.format("missionName=[%s], name=%s, skill=%s, scale=%s", tostring(mission:getName()), tostring(name), tostring(skill), tostring(scale)))
            if not skills[skill] then
                skills[skill] = {}
            end
            skills[skill][scale] = mission
        end

        veaf.loggers.get(veafCombatMission.Id):trace(string.format("skills=%s", veaf.p(skills)))

        -- create the radio menus
        local title = title
        if element.activeGroups then title = "* "..title end
        local missionPath = veafRadio.addSubMenu(title, menu)
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("  %s", title))
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
            veaf.loggers.get(veafCombatMission.Id):trace(string.format("    %s", skill))
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
                veaf.loggers.get(veafCombatMission.Id):trace(string.format("      %s", scale))
                mission.radioRootPath = scalePath
                mission:updateRadioMenu(true)
            end
        end
    end
end

--- Build the initial radio menu
function veafCombatMission.buildRadioMenu()
    veaf.loggers.get(veafCombatMission.Id):debug("buildRadioMenu()")

    -- don't create an empty menu
    if veaf.length(veafCombatMission.missionsDict) == 0 then
        return
    end

    if veafCombatMission.rootPath then
        veafRadio.clearSubmenu(veafCombatMission.rootPath)
    else
        veafCombatMission.rootPath = veafRadio.addMenu(veafCombatMission.RadioMenuName)
    end
    if not(veafRadio.skipHelpMenus) then
        veafRadio.addCommandToSubmenu("HELP", veafCombatMission.rootPath, veafCombatMission.help, nil, veafRadio.USAGE_ForGroup)
    end
    veafRadio.addCommandToSubmenu("List available", veafCombatMission.rootPath, veafCombatMission.listAvailableMissions, nil, veafRadio.USAGE_ForAll)
    veafRadio.addCommandToSubmenu("List active", veafCombatMission.rootPath, veafCombatMission.listActiveMissions, nil, veafRadio.USAGE_ForAll)

    local missions = {}
    local missionGroups, activeGroups = _groupMissions()
    for groupName, missionsInGroup in pairs(missionGroups) do
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("processing groupName=%s",groupName))
        missions[groupName] = {title=missionsInGroup[1]:getRadioMenuName(), sort=missionsInGroup[1]:getFriendlyName(), missions=missionsInGroup, activeGroups=activeGroups[groupName]}
    end
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("missions=%s",veaf.p(missions)))
    --veaf.loggers.get(veafCombatMission.Id):trace(string.format("#missions=%d",#missions))
    veafRadio.addPaginatedRadioElements(veafCombatMission.rootPath, veafCombatMission._buildMissionRadioMenu, missions)
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
    local sortedMissions = {}
    local groupedMissions = _groupMissions()
    for groupName, missionsInGroup in pairs(groupedMissions) do
        table.insert(sortedMissions, groupName)
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
    local sortedMissions = {}
    for _, mission in pairs(veafCombatMission.missionsDict) do
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

-- add a standard CAP mission with a single group
function veafCombatMission.addCapMission(missionName, missionDescription, missionBriefing, secured, radioMenuEnabled, skills, scales, spawnRadius)
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("veafCombatMission.addCapMission(%s)",tostring(missionName)))

    local groupName = "OnDemand-"..missionName
    local spawnRadius = spawnRadius
    if spawnRadius == nil then spawnRadius = 20000 end
    local secured = secured
    if secured == nil then secured = true end
    local radioMenuEnabled = radioMenuEnabled
    if radioMenuEnabled == nil then radioMenuEnabled = false end
    local skills = skills
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("checking skills"))
    if not skills then
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("skills is nil"))
        if radioMenuEnabled then
            skills = {"Good", "Excellent"}
        else
            skills = nil
        end
    end
    local scales = scales
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("checking scales"))
    if not scales then
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("scales is nil"))
        if radioMenuEnabled then
            scales = {1, 2}
        else
            scales = nil
        end
    end

    veaf.loggers.get(veafCombatMission.Id):trace(string.format("skills=(%s)", veaf.p(skills)))
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("scales=(%s)", veaf.p(scales)))

    veafCombatMission.AddMissionsWithSkillAndScale(
		VeafCombatMission:new()
		:setSecured(secured)
		:setRadioMenuEnabled(radioMenuEnabled)
		:setName(missionName)
		:setFriendlyName(missionDescription)
		:setBriefing(missionBriefing)
		:addElement(
			VeafCombatMissionElement:new()
			:setName(groupName)
            :setGroups({groupName})
            :setSkill("Random")
            :setScalable(true)
            :setSpawnRadius(spawnRadius)
		)
		:addObjective(
			VeafCombatMissionObjective:new()
			:setName("Kill all the ennemies")
			:setDescription("you must kill all of the ennemies")
			:setMessage("%d ennemies destroyed !")
			:configureAsKillEnemiesObjective()
		)
		:initialize()
    ,false, skills, scales)
end

function veafCombatMission.dumpMissionsList(export_path)

    local jsonify = function(key, value)
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("jsonify(%s)", veaf.p(value)))
        if veaf.json then
            return veaf.json.stringify(veafCombatMission.missionsDict[value])
        else
            return ""
        end
    end

    -- sort the missions alphabetically
    local sortedMissions = {}
    for _, mission in pairs(veafCombatMission.missionsDict) do
        table.insert(sortedMissions, mission:getName())
    end
    table.sort(sortedMissions)

    local _filename = "CombatMissionsList.json"
    if veaf.config.MISSION_NAME then
        _filename = "CombatMissionsList_" .. veaf.config.MISSION_NAME .. ".json"
    end
    veaf.exportAsJson(sortedMissions, "combatMissions", jsonify, _filename, export_path)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- remote interface
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- execute command from the remote interface
function veafCombatMission.executeCommandFromRemote(parameters)
    veaf.loggers.get(veafCombatMission.Id):debug(string.format("veafCombatMission.executeCommandFromRemote()"))
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("parameters= %s", veaf.p(parameters)))
    local _pilot, _pilotName, _unitName, _command = unpack(parameters)
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("_pilot= %s", veaf.p(_pilot)))
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("_pilotName= %s", veaf.p(_pilotName)))
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("_unitName= %s", veaf.p(_unitName)))
    veaf.loggers.get(veafCombatMission.Id):trace(string.format("_command= %s", veaf.p(_command)))
    if not _pilot or not _command then
        return false
    end

    if _command then
        -- parse the command
        local _action, _missionName, _parameters = _command:match(veafCombatMission.RemoteCommandParser)
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("_action=%s",veaf.p(_action)))
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("_missionName=%s",veaf.p(_missionName)))
        veaf.loggers.get(veafCombatMission.Id):trace(string.format("_parameters=%s",veaf.p(_parameters)))
        if _action and _action:lower() == "list" then
            veaf.loggers.get(veafCombatMission.Id):info(string.format("[%s] is listing air missions)",veaf.p(_pilot.name)))
            veafCombatMission.listAvailableMissions()
            return true
        elseif _action and _action:lower() == "start" and _missionName then
            local _silent = _parameters and _parameters:lower() == "silent"
            veaf.loggers.get(veafCombatMission.Id):info(string.format("[%s] is starting air mission [%s] %s)",veaf.p(_pilot.name), veaf.p(_missionName), veaf.p(_parameters)))
            veafCombatMission.ActivateMission(_missionName, _silent)
            return true
        elseif _action and _action:lower() == "stop" then
            local _silent = _parameters and _parameters:lower() == "silent"
            veaf.loggers.get(veafCombatMission.Id):info(string.format("[%s] is stopping air mission [%s] %s)",veaf.p(_pilot.name), veaf.p(_missionName), veaf.p(_parameters)))
            veafCombatMission.DesactivateMission(_missionName, _silent)
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafCombatMission.initialize()
    veaf.loggers.get(veafCombatMission.Id):info("Initializing module")
    veafCombatMission.buildRadioMenu()
    veafCombatMission.dumpMissionsList(veaf.config.MISSION_EXPORT_PATH)
end

veaf.loggers.get(veafCombatMission.Id):info(string.format("Loading version %s", veafCombatMission.Version))

