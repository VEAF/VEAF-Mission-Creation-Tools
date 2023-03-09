------------------------------------------------------------------
-- VEAF Sanctuary Zone script
-- By zip (2021)
--
-- Features:
-- ---------
-- * This module offers support for creating sanctuary zones in a mission
-- * A sanctuary zone warns and then destroys all the human aircrafts of other coalitions when they loiter in the zone
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafSanctuary = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafSanctuary.Id = "SANCTUARY"

--- Version.
veafSanctuary.Version = "1.6.1"

-- trace level, specific to this module
--veafSanctuary.LogLevel = "trace"

veaf.loggers.new(veafSanctuary.Id, veafSanctuary.LogLevel)

veafSanctuary.RecordAction = true
veafSanctuary.RecordTrace = false
veafSanctuary.RecordTraceTrespassing = false
veafSanctuary.RecordTraceShooting = false

-- delay before the sanctuary zones start reporting
veafSanctuary.DelayForStartup = 0

-- delay between each check of the sanctuary zones
veafSanctuary.DelayBetweenChecks = 15

-- default delay before warning
veafSanctuary.DEFAULT_DELAY_WARNING = 0

-- default message when entering the zone
veafSanctuary.DEFAULT_MESSAGE_WARNING = "Warning, %s : you've entered a sanctuary zone and will be shot in %d seconds if you don't leave IMMEDIATELY"

-- time to display the messages
veafSanctuary.MESSAGE_TIME = 20

-- default delay before instantly killing the offender
veafSanctuary.DEFAULT_DELAY_INSTANT = -1

-- default delay before spawning defenses
veafSanctuary.DEFAULT_DELAY_SPAWN = -1

-- default message when defenses are spawned
veafSanctuary.DEFAULT_MESSAGE_SPAWN = "You've been warned : deploying defense systems"

-- time to start spawning harder defenses
veafSanctuary.HARDER_DEFENSES_AFTER = 75

-- time to start removing the defenses
veafSanctuary.DELETE_DEFENSES_AFTER = 75

-- time before handling weapons
veafSanctuary.DESTROY_WEAPONS_AFTER = 2

-- clean slate
veafSanctuary.FORGIVE_SHOOTER_AFTER = 10 * 60 -- 10 minutes

-- default message to target when weapon launch is detected
veafSanctuary.DEFAULT_MESSAGE_SHOT_TARGET = "Warning, %s : you've been attacked by %s ; we destroyed the missile in the air !"

-- default message to launcher when weapon launch is detected
veafSanctuary.DEFAULT_MESSAGE_SHOT_LAUNCHER = "Warning, %s : you've attacked %s ; we destroyed the missile in the air. Don't do that again or we'll destroy you !"

-- number of offenses (misile launches at players in a zone) that will justify destruction
veafSanctuary.DEFAULT_OFFENSES_BEFORE_DESTRUCTION = 3

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSanctuary.initialized = false
veafSanctuary.spawnedSAMs  = {}
veafSanctuary.humanUnitsToFollow  = {}
veafSanctuary.zonesList  = {}
veafSanctuary.humanUnits = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSanctuary._recordAction(message)
    if message and veafSanctuary.RecordAction then
        local _filename = "sanctuary_zones"
        if veaf.config.MISSION_NAME then
            veaf.loggers.get(veafSanctuary.Id):trace(string.format("veaf.config.MISSION_NAME=%s", veaf.p(veaf.config.MISSION_NAME)))
            _filename = _filename .. "-" .. veaf.config.MISSION_NAME
        end
        if veaf.config.SERVER_NAME then
            veaf.loggers.get(veafSanctuary.Id):trace(string.format("veaf.config.SERVER_NAME=%s", veaf.p(veaf.config.SERVER_NAME)))
            _filename = _filename .. "-" .. veaf.config.SERVER_NAME
        end
        _filename = _filename  .. ".log"
        veaf.loggers.get(veafSanctuary.Id):trace(string.format("_filename=%s", veaf.p(_filename)))

        veaf.writeLineToTextFile(message, _filename)
    end
end

function veafSanctuary.recordAction(message)
    if message then
        local _message = "ACTION  - " .. message
        veaf.loggers.get(veafSanctuary.Id):info(_message)
        veafSanctuary._recordAction(veafSanctuary._recordAction(" INFO    SCRIPTING: VEAF - I - " .. _message))
    end
end

function veafSanctuary.recordTrace(message)
    if message and veafSanctuary.RecordTrace then
        local _message = "SANCTUARY - " .. message
        veaf.loggers.get(veafSanctuary.Id):trace(_message)
        veafSanctuary._recordAction(" INFO    SCRIPTING: VEAF - T - " .. _message)
    end
end

function veafSanctuary.recordTraceShooting(message)
    if message and veafSanctuary.RecordTraceShooting then
        local _message = "SHOOTING - " .. message
        veaf.loggers.get(veafSanctuary.Id):trace(_message)
        veafSanctuary._recordAction(" INFO    SCRIPTING: VEAF - T - " .. _message)
    end
end

function veafSanctuary.recordTraceTrespassing(message)
    if message and veafSanctuary.RecordTraceTrespassing then
        local _message = "TRESPASS - " .. message
        veaf.loggers.get(veafSanctuary.Id):trace(_message)
        veafSanctuary._recordAction(" INFO    SCRIPTING: VEAF - T - " .. _message)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- objects
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafSanctuaryZone = {}

function VeafSanctuaryZone:new(objectToCopy)
    local objectToCreate = objectToCopy or {} -- create object if user does not provide one
    setmetatable(objectToCreate, self)
    self.__index = self

    -- init the new object

    -- name
    objectToCreate.name = nil
    -- coalition that is forbidden to enter the zone
    objectToCreate.protectFromCoalition = nil
    -- if true, missiles fired at units in the zone will be destroyed
    objectToCreate.protectFromMissiles = nil
    -- position on the map
    objectToCreate.position = nil
    -- if set, the zone is a circle of center *position* and of radius *radius*
    objectToCreate.radius = nil
    objectToCreate.radiusSquared = nil
    -- if set, the zone is a polygon - this is a simple list of points
    objectToCreate.polygon = nil
    -- delay before warning - if -1, no warning
    objectToCreate.delayWarning = veafSanctuary.DEFAULT_DELAY_WARNING
    -- warning message
    objectToCreate.messageWarning = veafSanctuary.DEFAULT_MESSAGE_WARNING
    -- delay before instant kill - if -1, no instant kill
    objectToCreate.delayInstant = veafSanctuary.DEFAULT_DELAY_INSTANT
    -- delay before spawn of defense systems - if -1, no spawn
    objectToCreate.delaySpawn = veafSanctuary.DEFAULT_DELAY_SPAWN
    -- spawn message
    objectToCreate.messageSpawn = veafSanctuary.DEFAULT_MESSAGE_SPAWN
    -- message to target when weapon launch is detected
    objectToCreate.messageShotTarget = veafSanctuary.DEFAULT_MESSAGE_SHOT_TARGET
    --message to launcher when weapon launch is detected
    objectToCreate.messageShotLauncher = veafSanctuary.DEFAULT_MESSAGE_SHOT_LAUNCHER
    objectToCreate.spawnedGroups = {}
    objectToCreate.offensesByOffender = {}
    objectToCreate.offensesBeforeDestruction = veafSanctuary.DEFAULT_OFFENSES_BEFORE_DESTRUCTION

    return objectToCreate
end

---
--- setters and getters
---

function VeafSanctuaryZone:setName(value)
    self.name = value
    return self
end

function VeafSanctuaryZone:getName()
    return self.name
end

function VeafSanctuaryZone:setCoalition(value)
    self.coalition = value
    return self
end

function VeafSanctuaryZone:getCoalition()
    return self.coalition
end

function VeafSanctuaryZone:setProtectFromMissiles()
    veaf.loggers.get(veafSanctuary.Id):trace(string.format("VeafSanctuaryZone[%s]:setProtectFromMissiles()", veaf.p(self.name)))
    self.protectFromMissiles = true
    return self
end

function VeafSanctuaryZone:isProtectFromMissiles()
    return self.protectFromMissiles
end

function VeafSanctuaryZone:setPosition(value)
    self.position = value
    return self
end

function VeafSanctuaryZone:getPosition()
    return self.position
end

function VeafSanctuaryZone:setRadius(value)
    self.radius = value
    if value ~= nil then
        self.radiusSquared = value * value
    else
        self.radiusSquared = nil
    end
    return self
end

function VeafSanctuaryZone:getRadius()
    return self.radius
end

function VeafSanctuaryZone:setPolygon(value)
    self.polygon = value
    return self
end

function VeafSanctuaryZone:setPolygonFromUnitsInSequence(unitNamePrefix, markPositions)
    veaf.loggers.get(veafSanctuary.Id):trace(string.format("VeafSanctuaryZone[%s]:setPolygonFromUnitsInSequence(%s, %s)", veaf.p(self.name), veaf.p(unitNamePrefix), veaf.p(markPositions)))

    local unitNames = {}
    local sequence = 0
    while true do
        sequence = sequence + 1
        local unitName = string.format("%s #%03d", unitNamePrefix, sequence)
        --veaf.loggers.get(veafSanctuary.Id):trace(string.format("unitName=%s", veaf.p(unitName)))
        local unit = Unit.getByName(unitName)
        if not unit then
            local group = Group.getByName(unitName)
            if group then
                unit = group:getUnit(1)
            end
        end
        --veaf.loggers.get(veafSanctuary.Id):trace(string.format("unit=%s", veaf.p(veaf.ifnn(unit, "getID"))))
        if not unit then
            return self:setPolygonFromUnits(unitNames, markPositions)
        else
            table.insert(unitNames, unitName)
        end
    end
end

function VeafSanctuaryZone:setPolygonFromUnits(unitNames, markPositions)

    -- Color of the line marking the zone ({r, g, b, a})
    local LINE_COLOR = {0/255, 255/255, 100/255, 255/255}
    local LINE_TYPE = VeafDrawingOnMap.LINE_TYPE.twodashes

    veaf.loggers.get(veafSanctuary.Id):debug(string.format("VeafSanctuaryZone[%s]:setPolygonFromUnits()", veaf.p(self.name)))
    veaf.loggers.get(veafSanctuary.Id):trace(string.format("markPositions = %s", veaf.p(markPositions)))
    local polygon = veaf.getPolygonFromUnits(unitNames)
    if polygon and #polygon > 0 then
        veaf.loggers.get(veafSanctuary.Id):trace(string.format("polygon = %s", veaf.p(polygon)))
        self:setPolygon(polygon)
        if markPositions then
            local drawing = VeafDrawingOnMap:new()
            :setName(self:getName())
            :setColor(LINE_COLOR)
            :setLineType(LINE_TYPE)
            :addPoints(self:getPolygon())
            :draw()
        end
    end
    return self
end

function VeafSanctuaryZone:getPolygon()
    return self.polygon
end

function VeafSanctuaryZone:setDelayWarning(value)
    self.delayWarning = value
    return self
end

function VeafSanctuaryZone:getDelayWarning()
    return self.delayWarning
end

function VeafSanctuaryZone:setOffensesBeforeDestruction(value)
    self.offensesBeforeDestruction = value
    return self
end

function VeafSanctuaryZone:getOffensesBeforeDestruction()
    return self.offensesBeforeDestruction
end

function VeafSanctuaryZone:setMessageWarning(value)
    self.messageWarning = value
    return self
end

function VeafSanctuaryZone:getMessageWarning()
    return self.messageWarning
end

function VeafSanctuaryZone:setMessageShotTarget(value)
    self.messageShotTarget = value
    return self
end

function VeafSanctuaryZone:getMessageShotTarget()
    return self.messageShotTarget
end

function VeafSanctuaryZone:setMessageShotLauncher(value)
    self.messageShotLauncher = value
    return self
end

function VeafSanctuaryZone:getMessageShotLauncher()
    return self.messageShotLauncher
end

function VeafSanctuaryZone:setDelayInstant(value)
    self.delayInstant = value
    return self
end

function VeafSanctuaryZone:getDelayInstant()
    return self.delayInstant
end

function VeafSanctuaryZone:setDelaySpawn(value)
    self.delaySpawn = value
    return self
end

function VeafSanctuaryZone:getDelaySpawn()
    return self.delaySpawn
end

function VeafSanctuaryZone:setMessageSpawn(value)
    self.messageSpawn = value
    return self
end

function VeafSanctuaryZone:getMessageSpawn()
    return self.messageSpawn
end

function VeafSanctuaryZone:addSpawnedGroups(spawnedGroupsNames)
    for _, groupName in pairs(spawnedGroupsNames) do
        self.spawnedGroups[groupName] = timer.getTime()
    end
    return self
end

function VeafSanctuaryZone:getSpawnedGroups()
    return self.spawnedGroups
end

---
--- business methods
---

function VeafSanctuaryZone:deployDefenses(position, unit, timeInZone)
    veaf.loggers.get(veafSanctuary.Id):trace(string.format("VeafSanctuaryZone[%s]:deployDefenses()", veaf.p(self.name)))
    veaf.loggers.get(veafSanctuary.Id):trace(string.format("position=%s", veaf.p(position)))
    -- compute the position of the unit in 20 seconds
    local positionIn20s = mist.vec.add(position, mist.vec.scalarMult(unit:getVelocity(), 20))
    veaf.loggers.get(veafSanctuary.Id):trace(string.format("positionIn20s=%s", veaf.p(positionIn20s)))
    -- compute the position of the unit in 40 seconds, 
    local positionIn40s = mist.vec.add(position, mist.vec.scalarMult(unit:getVelocity(), 40))
    veaf.loggers.get(veafSanctuary.Id):trace(string.format("positionIn40s=%s", veaf.p(positionIn40s)))
    -- compute a heading towards the unit
    local heading = mist.utils.round(mist.utils.toDegree(mist.getHeading(unit)), 0)
    veaf.loggers.get(veafSanctuary.Id):trace(string.format("heading=%s", veaf.p(heading)))
    local heading1 = heading*math.random(70,130)/100
    veaf.loggers.get(veafSanctuary.Id):trace(string.format("heading1=%s", veaf.p(heading1)))
    local heading1S = string.format(", hdg %s", tostring(veaf.invertHeading(heading1)))
    veaf.loggers.get(veafSanctuary.Id):trace(string.format("heading1S=%s", veaf.p(heading1S)))
    local heading2 = heading*math.random(70,130)/100
    veaf.loggers.get(veafSanctuary.Id):trace(string.format("heading2=%s", veaf.p(heading2)))
    local heading2S = string.format(", hdg %s", tostring(veaf.invertHeading(heading2)))
    veaf.loggers.get(veafSanctuary.Id):trace(string.format("heading2S=%s", veaf.p(heading2S)))

    if veafShortcuts then
        local ship1 = "-burke"
        local ship2 = "-ticonderoga"
        local sam1 = "-roland"
        local sam2 = "-patriot"
        if self:getCoalition() == 1 then
            -- red side units
            ship1 = "-rezky"
            ship2 = "-pyotr"
            sam1 = "-roland"
            sam2 = "-patriot"
        end

        local spawnedGroupsNames = {}
        local surfaceType = land.getSurfaceType(mist.utils.makeVec2(position))
        veaf.loggers.get(veafSanctuary.Id):trace(string.format("surfaceType=%s", veaf.p(surfaceType)))
        if surfaceType == 2 or surfaceType == 3 then
            -- this is water
            veafShortcuts.ExecuteAlias(ship1, "radius 2000, multiplier 2, skynet false"..heading1S, positionIn20s, self:getCoalition(), nil, true, spawnedGroupsNames)
            veafShortcuts.ExecuteAlias(ship1, "radius 3000, multiplier 2, skynet false"..heading2S, positionIn40s, self:getCoalition(), nil, true, spawnedGroupsNames)
        else
            -- this is land    
            veafShortcuts.ExecuteAlias(sam1, "radius 2000, multiplier 2, skynet false"..heading1S, positionIn20s, self:getCoalition(), nil, true, spawnedGroupsNames)
            veafShortcuts.ExecuteAlias(sam1, "radius 2000, multiplier 2, skynet false"..heading2S, positionIn20s, self:getCoalition(), nil, true, spawnedGroupsNames)
        end
        self:addSpawnedGroups(spawnedGroupsNames)
        veaf.loggers.get(veafSanctuary.Id):trace(string.format("spawnedGroupsNames = %s", veaf.p(spawnedGroupsNames)))
        if timeInZone > veafSanctuary.HARDER_DEFENSES_AFTER then
            if surfaceType == 2 or surfaceType == 3 then
                -- this is water
                veafShortcuts.ExecuteAlias(ship2, "radius 3000, multiplier 2, skynet false"..heading1S, positionIn20s, self:getCoalition(), nil, true, spawnedGroupsNames)
                veafShortcuts.ExecuteAlias(ship2, "radius 4000, multiplier 2, skynet false"..heading2S, positionIn40s, self:getCoalition(), nil, true, spawnedGroupsNames)
            else
                -- this is land    
                veafShortcuts.ExecuteAlias(sam2, "radius 3000, skynet false"..heading1S, positionIn20s, self:getCoalition(), nil, true, spawnedGroupsNames)
                veafShortcuts.ExecuteAlias(sam2, "radius 4000, skynet false"..heading2S, positionIn40s, self:getCoalition(), nil, true, spawnedGroupsNames)
            end
            self:addSpawnedGroups(spawnedGroupsNames)
            veaf.loggers.get(veafSanctuary.Id):trace(string.format("spawnedGroupsNames = %s", veaf.p(spawnedGroupsNames)))
        end
    end
end

function VeafSanctuaryZone:cleanupDefenses()
    veaf.loggers.get(veafSanctuary.Id):trace(string.format("VeafSanctuaryZone[%s]:cleanupDefenses()", veaf.p(self.name)))
    local oldestTimeToKeep = timer.getTime() - veafSanctuary.DELETE_DEFENSES_AFTER
    for name, time in pairs(self:getSpawnedGroups()) do
        if time < oldestTimeToKeep then
            local group = Group.getByName(name)
            if group then
                group:destroy()
                self:getSpawnedGroups()[name] = nil
            end
        end
    end
end

function VeafSanctuaryZone:isPositionInZone(position)
    local inZone = false
    if self:getPolygon() then
        veaf.loggers.get(veafSanctuary.Id):trace("polygon mode")
        inZone = mist.pointInPolygon(position, self:getPolygon())
    elseif self:getPosition() then
        veaf.loggers.get(veafSanctuary.Id):trace("circle and radius mode")
        local distanceFromCenter = ((position.x - self:getPosition().x)^2 + (position.z - self:getPosition().z)^2)^0.5
        veaf.loggers.get(veafSanctuary.Id):trace(string.format("distanceFromCenter=%d, radius=%d", distanceFromCenter, self:getRadius()))
        inZone = distanceFromCenter < self:getRadius()
    end
    return inZone
end

function VeafSanctuaryZone:forgive(playerName)
    veaf.loggers.get(veafSanctuary.Id):trace(string.format("VeafSanctuaryZone[%s]:forgive(%s)", veaf.p(self.name), veaf.p(playerName)))
    self.offensesByOffender[playerName] = 0
end

function VeafSanctuaryZone:handleWeapon(weapon)
    veafSanctuary.recordTraceShooting(string.format("VeafSanctuaryZone[%s]:handleWeapon()", veaf.p(self.name)))
    veafSanctuary.recordTraceShooting(string.format("weapon=%s", veaf.p(veaf.ifnns(weapon, {"getID", "getName", "getTypeName"}))))
    if not weapon then
        return
    end
    if self:isProtectFromMissiles() then
        -- check if the missile was shot by a human from the other coalition
        local launcherUnit = weapon:getLauncher()
        veafSanctuary.recordTraceShooting(string.format("launcherUnit=%s", veaf.p(veaf.ifnns(launcherUnit, {"getID", "getName", "getTypeName", "getPlayerName", "getCoalition"}))))
        if launcherUnit and launcherUnit:getCoalition() ~= self:getCoalition() then
            local launcherPlayername = launcherUnit:getPlayerName()
            -- TODO debug - REMOVE LATER
            -- if not launcherPlayername or launcherPlayername == "" then
            --      launcherPlayername = "AI-launcher" 
            -- end
            -- TODO debug - REMOVE LATER
            if launcherPlayername and launcherPlayername ~= "" then
                -- check if the target is a human from our coalition
                local target = weapon:getTarget()
                local targetUnit = Unit.getByName(target:getName())
                veafSanctuary.recordTraceShooting(string.format("targetUnit=%s", veaf.p(veaf.ifnns(targetUnit, {"getID", "getName", "getTypeName", "getPlayerName", "getCoalition"}))))
                if targetUnit and targetUnit:getCoalition() == self:getCoalition() then
                    local targetPlayername = targetUnit:getPlayerName()
                    -- if the target is AI, then protect it anyway (protect assets, prevent bases bombing)
                    if not targetPlayername or targetPlayername == "" then
                        targetPlayername = "AI-target"
                    end
                    -- TODO debug - REMOVE LATER
                   veafSanctuary.recordTraceShooting(string.format("targetPlayername=%s", veaf.p(targetPlayername)))
                    if targetPlayername and targetPlayername ~= "" then
                        -- check if the target is in the zone
                        local position = targetUnit:getPosition().p
                        veafSanctuary.recordTraceShooting(string.format("position=%s", veaf.p(position)))
                        local inZone = self:isPositionInZone(position)
                        if inZone then
                            -- destroy the weapon with flak  - :destroy() does not work for human players and weapons in MP
                            veafSpawn.destroyObjectWithFlak(weapon, 1)
                            -- warn the target
                            local message = string.format(self:getMessageShotTarget(), targetPlayername, launcherPlayername)
                            veafSanctuary.recordAction(string.format("Issuing a warning to target : %s", message))
                            trigger.action.outTextForGroup(targetUnit:getGroup():getID(), message, veafSanctuary.MESSAGE_TIME)
                            -- count the offence
                            local count = self.offensesByOffender[launcherPlayername]
                            if not self.offensesByOffender[launcherPlayername] then
                                self.offensesByOffender[launcherPlayername] = 1
                            else
                                self.offensesByOffender[launcherPlayername] = self.offensesByOffender[launcherPlayername] + 1
                            end
                            veafSanctuary.recordTraceShooting(string.format("self.offensesByOffender[launcherPlayername]=%s", veaf.p(self.offensesByOffender[launcherPlayername])))
                            if self.offensesByOffender[launcherPlayername] >= self:getOffensesBeforeDestruction() then
                                -- destroy the offender
                                local message = string.format("Instantly killing unit %s, too many offenses agains players in zone %s", launcherPlayername, self:getName())
                                trigger.action.outTextForCoalition(self:getCoalition(), message, veafSanctuary.MESSAGE_TIME)
                                veafSanctuary.recordAction(message)
                                -- flak the plane - :destroy() does not work for human players and weapons in MP
                                veafSpawn.destroyObjectWithFlak(launcherUnit, 2, 2)
                                -- forgive the player in 10 minutes (let him get out of trouble and don't kill him straight if he comes back)
                                mist.scheduleFunction(VeafSanctuaryZone.forgive, {self, launcherPlayername}, timer.getTime() + veafSanctuary.FORGIVE_SHOOTER_AFTER)
                            else
                                -- warn the launcher
                                local message = string.format(self:getMessageShotLauncher(), launcherPlayername, targetPlayername)
                                veafSanctuary.recordAction(string.format("Issuing a warning to shooter : %s", message))
                                trigger.action.outTextForGroup(launcherUnit:getGroup():getID(), message, veafSanctuary.MESSAGE_TIME)
                            end
                        end
                    end
                end
            end
        end
    end
end

function VeafSanctuaryZone:handleUnit(unit, data)
    veafSanctuary.recordTraceTrespassing(string.format("VeafSanctuaryZone[%s]:handleUnit()", veaf.p(self.name)))

    if not(unit) then
        return
    end

    local coalition = unit:getCoalition()
    if coalition == self:getCoalition() then
        veafSanctuary.recordTraceTrespassing(string.format("We're not concerned by this unit"))
        return -- we're not concerned by this unit
    end

    local position = unit:getPosition().p
    veafSanctuary.recordTraceTrespassing(string.format("position=%s", veaf.p(position)))
    local inZone = self:isPositionInZone(position)
    veafSanctuary.recordTraceTrespassing(string.format("inZone=%s", veaf.p(inZone)))

    -- let's decide what we do
    if inZone then
        local firstInZone = data.firstInZone
        if firstInZone < 0 then
            firstInZone = timer.getTime()
            data.firstInZone = firstInZone
        end
        local unitname = unit:getName()
        local playername = unit:getPlayerName()
        local callsign = unit:getCallsign()
        local timeInZone = timer.getTime() - firstInZone
        veafSanctuary.recordTraceTrespassing(string.format("unitname=%s, playername=%s, callsign=%s", veaf.p(unitname), veaf.p(playername), veaf.p(callsign)))

        local message = string.format("Unit %s is in the %s zone since %d seconds", playername, self:getName(), timeInZone)
        trigger.action.outTextForCoalition(self:getCoalition(), message, veafSanctuary.MESSAGE_TIME)
        veafSanctuary.recordAction(message)
        local groupId = unit:getGroup():getID()
        if self:getDelayInstant() > -1 and timeInZone >= self:getDelayInstant() then
            -- insta-death !
            local message = string.format("Instantly killing unit %s, in zone %s since %d seconds", playername, self:getName(), timeInZone)
            trigger.action.outTextForCoalition(self:getCoalition(), message, veafSanctuary.MESSAGE_TIME)
            veafSanctuary.recordAction(message)
            -- flak the plane - :destroy() does not work for human players and weapons in MP
            veafSpawn.destroyObjectWithFlak(unit, 2, 2)
        elseif self:getDelaySpawn() > -1 and timeInZone >= self:getDelaySpawn() then
            -- spawn defense systems
            self:deployDefenses(position, unit, timeInZone)

            local message = string.format("Spawning defense systems to fend off unit %s, in zone %s since %d seconds", playername, self:getName(), timeInZone)
            veafSanctuary.recordAction(string.format("Issuing a warning to protected coalition : %s", message))
            trigger.action.outTextForCoalition(self:getCoalition(), message, veafSanctuary.MESSAGE_TIME)

            local message = string.format("CRITICAL: %s - %s", playername, self:getMessageSpawn())
            veafSanctuary.recordAction(string.format("Issuing a warning to trespasser : %s", message))
            trigger.action.outTextForGroup(groupId, message, veafSanctuary.MESSAGE_TIME)
        elseif self:getDelayWarning() > -1 and timeInZone >= self:getDelayWarning() then
            -- simple warning
            local delay = self:getDelayInstant()
            if delay < 0 or (self:getDelaySpawn() > 0 and self:getDelaySpawn() < delay) then
                delay = self:getDelaySpawn()
            end
            local message = string.format(self:getMessageWarning(), playername, delay - timeInZone)
            veafSanctuary.recordAction(string.format("Issuing a warning to trespasser : %s", message))
            trigger.action.outTextForGroup(groupId, message, veafSanctuary.MESSAGE_TIME)
        end
    elseif data.firstInZone >= 0 then
        local playername = unit:getPlayerName()
        -- reset the counter
        local message = string.format("%s got out of the zone", veaf.p(playername))
        veafSanctuary.recordAction(message)
        data.firstInZone = -1
    end

end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- core functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- add a zone
function veafSanctuary.addZone(zone)
    veaf.loggers.get(veafSanctuary.Id):trace(string.format("addZone(%s)", veaf.p(zone:getName())))
    table.insert(veafSanctuary.zonesList, zone)
    return zone
end

-- add a zone from a DCS trigger zone
function veafSanctuary.addZoneFromTriggerZone(triggerZoneName)
    veaf.loggers.get(veafSanctuary.Id):trace(string.format("addZoneFromTriggerZone(%s)", veaf.p(triggerZoneName)))
    local triggerZone = trigger.misc.getZone(triggerZoneName)
    if triggerZoneName then
        local zone = VeafSanctuaryZone:new():setName(triggerZoneName):setRadius(triggerZone.radius):setPosition(triggerZone.point)
        return veafSanctuary.addZone(zone)
    end
end

-- Handle world events.
veafSanctuary.eventHandler = {}
function veafSanctuary.eventHandler:onEvent(event)

    if event == nil or event.id == nil then
        return
    end

    if not(
           event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT
        or event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT
        or event.id == world.event.S_EVENT_BIRTH
        or event.id == world.event.S_EVENT_DEAD
        or event.id == world.event.S_EVENT_SHOT
        ) then
        return
    end

    if (event.id == world.event.S_EVENT_SHOT) then -- process shooting events
        veafSanctuary.recordTraceShooting("S_EVENT_SHOT !")
        -- process all zones
        for _, zone in pairs(veafSanctuary.zonesList) do
            veaf.loggers.get(veafSanctuary.Id):trace(string.format("zone:getName()=%s", veaf.p(zone:getName())))
            mist.scheduleFunction(VeafSanctuaryZone.handleWeapon, {zone, event.weapon}, timer.getTime() + veafSanctuary.DESTROY_WEAPONS_AFTER)
        end
    else -- process human players events
        if not event.initiator then
            return
        end

        local eventId = event.id
        if veaf.EVENTMETA[event.id] then
            eventId = veaf.EVENTMETA[event.id].Text
        end

        local _unitname = event.initiator:getName()
        --veaf.loggers.get(veafSanctuary.Id):trace(string.format("event initiator unit  = %s", veaf.p(_unitname)))
        if event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT
        or event.id == world.event.S_EVENT_BIRTH and _unitname and veafSanctuary.humanUnits[_unitname]
        then
            veafSanctuary.recordTrace(string.format("event=%s",veaf.p(eventId)))
            if (not veafSanctuary.humanUnitsToFollow[_unitname]) then
                -- register the human unit in the follow-up list when the human gets in the unit
                veafSanctuary.recordTrace(string.format("registering human unit to follow: %s", veaf.p(_unitname)))
                veafSanctuary.humanUnitsToFollow[_unitname] = { firstInZone = -1}
            end
        elseif event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT
        or     event.id == world.event.S_EVENT_DEAD and _unitname and veafSanctuary.humanUnits[_unitname]
        then
            veafSanctuary.recordTrace(string.format("event=%s",veaf.p(eventId)))
            if (veafSanctuary.humanUnitsToFollow[_unitname]) then
                -- unregister the human unit from the follow-up list when the human gets in the unit
                veafSanctuary.recordTrace(string.format("deregistering human unit to follow: %s", veaf.p(_unitname)))
                veafSanctuary.humanUnitsToFollow[_unitname] = nil
            end
        end
    end
end

-- main loop
function veafSanctuary.loop()
    veaf.loggers.get(veafSanctuary.Id):debug("veafSanctuary.loop()")

    -- process all zones
    for _, zone in pairs(veafSanctuary.zonesList) do
        veaf.loggers.get(veafSanctuary.Id):trace(string.format("zone:getName()=%s", veaf.p(zone:getName())))

        zone:cleanupDefenses()

        -- browse all the human units and check if they're in a zone
        for name, data in pairs(veafSanctuary.humanUnitsToFollow) do
            veaf.loggers.get(veafSanctuary.Id):trace(string.format("name=%s", veaf.p(name)))
            local unit = Unit.getByName(name)
            if unit then
                zone:handleUnit(unit, data)
            else
                -- stop following this unit, it's been destroyed
                veafSanctuary.humanUnitsToFollow[name] = nil
            end
        end
    end

    mist.scheduleFunction(veafSanctuary.loop, {}, timer.getTime() + veafSanctuary.DelayBetweenChecks)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSanctuary.initialize()
    veafSanctuary.recordAction("Initializing module")

    -- prepare humans units
    veafSanctuary.humanUnits = {}
    for name, _ in pairs(mist.DBs.humansByName) do
        --veaf.loggers.get(veafSanctuary.Id):trace(string.format("mist.DBs.humansByName[%s]=??", veaf.p(name)))
        veafSanctuary.humanUnits[name] = true
    end

    --- Add the event handler.
    world.addEventHandler(veafSanctuary.eventHandler)

    -- Start the main loop
    mist.scheduleFunction(veafSanctuary.loop, {}, timer.getTime() + veafSanctuary.DelayForStartup)

    veafSanctuary.initialized = true
    veaf.loggers.get(veafSanctuary.Id):info(string.format("Sanctuary system has been initialized"))
end

veaf.loggers.get(veafSanctuary.Id):info(string.format("Loading version %s", veafSanctuary.Version))
