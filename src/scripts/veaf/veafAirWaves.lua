------------------------------------------------------------------
-- VEAF Quick Reaction Alert for DCS World
-- https://en.wikipedia.org/wiki/Quick_Reaction_Alert
-- By Zip (2020) and Rex (2022)
--
-- Features:
-- ---------
-- * Define zones that are defended by an AI flight
-- * Default behavior: when an ennemy aircraft enters the zone, QRA patrol is spawned; then, when it is destroyed, the zone is not defended anymore; when all enemy aircrafts have left the zone, it resets and can respawn a new QRA
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------


-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
VeafAirWavesManager = {}

--- Identifier. All output in the log will start with this.
VeafAirWavesManager.Id = "AIRWAVES - "

--- Version.
VeafAirWavesManager.Version = "0.0.1"

-- trace level, specific to this module
VeafAirWavesManager.Trace = true

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.loggers.new(VeafAirWavesManager.Id, VeafAirWavesManager.LogLevel)

VeafAirWavesManager.zones = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- AirWave class methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

AirWaveZone =
{
    -- technical name (AirWave instance name)
    name = nil,
    -- description for the briefing
    description = nil,
    -- trigger zone name (if set, we'll use a DCS trigger zone)
    triggerZoneCenter = nil,
    -- center (point in the center of the circle, when not using a DCS trigger zone)
    zoneCenter = nil,
    -- radius (size of the circle, when not using a zone)
    zoneRadius = nil,
    -- radius of the waves groups spawn
    respawnRadius = 250,
    -- coalitions of the players
    playerCoalitions = {},
    -- aircraft groups forming the waves
    waves = {},
    -- groups that have been spawned (the current wave)
    spawnedGroups = {},
    -- silent means no message is emitted
    silent = VeafAirWavesManager.AllSilence,
    -- message when the zone is activated
    messageStart = VeafAirWavesManager.DEFAULT_MESSAGE_START,
    -- event when the zone is activated
    onStart = nil,
    -- message when a wave is triggered
    messageDeploy = VeafAirWavesManager.DEFAULT_MESSAGE_DEPLOY,
    -- event  when a wave is triggered
    onDeploy = nil,
    -- message when a wave is destroyed
    messageDestroyed = VeafAirWavesManager.DEFAULT_MESSAGE_DESTROYED,
    -- event when a wave is destroyed
    onDestroyed = nil,
    -- message when all waves are finished
    messageFinished = VeafAirWavesManager.DEFAULT_MESSAGE_FINISHED,
    -- event when all waves are finished
    onFinished = nil,
    -- message when the zone is deactivated
    messageStop = VeafAirWavesManager.DEFAULT_MESSAGE_STOP,
    -- event when the zone is deactivated
    onStop = nil,
    -- delay before activating the zone
    delayBeforeActivating = -1,
    -- delay in seconds between waves of ennemy planes
    delayBetweenWaves = 0,
    -- if true, the zone will reset when player dies
    resetWhenDying = true,
    -- human units that are being watched
    playerHumanUnits = nil,
    -- players in the zone will only be detected below this altitude (in feet)
    minimumAltitude = 999999,
    -- players in the zone will only be detected above this altitude (in feet)
    maximumAltitude = 0
}

VeafAirWavesManager.STATUS_READY = 1
VeafAirWavesManager.STATUS_ACTIVE = 2
VeafAirWavesManager.STATUS_NEXTWAVE = 3
VeafAirWavesManager.STATUS_DEAD = 3

function AirWaveZone:new(object)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWave:new()")
    local o = object or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function AirWaveZone:setName(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWave[]:setName(%s)", veaf.p(value))
    self.name = value
    return VeafAirWavesManager.add(self) -- add the zone to the list as soon as a name is available to index it
end

function AirWaveZone:getName()
    return self.name or self.description
  end
  
function AirWaveZone:setTriggerZone(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setTriggerZone(%s)", veaf.p(self.name), veaf.p(value))
    self.triggerZone = value
    local triggerZone = veaf.getTriggerZone(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("triggerZone=%s", veaf.p(triggerZone))
    return self
end

function AirWaveZone:setZoneCenter(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setZoneCenter(%s)", veaf.p(self.name), veaf.p(value))
    self.zoneCenter = value
    return self
end    

function AirWaveZone:setZoneCenterFromCoordinates(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setZoneCenterFromCoordinates(%s)", veaf.p(self.name), veaf.p(value))
    local _lat, _lon = veaf.computeLLFromString(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("_lat=%s)", veaf.p(_lat))
    veaf.loggers.get(VeafAirWavesManager.Id):trace("_lon=%s)", veaf.p(_lon))
    local vec3 = coord.LLtoLO(_lat, _lon)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("vec3=%s)", veaf.p(vec3))
    return self:setZoneCenter(vec3)
end

function AirWaveZone:setZoneRadius(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setZoneRadius(%s)", veaf.p(self.name), veaf.p(value))
    self.zoneRadius = value
    return self
end

function AirWaveZone:setDescription(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setDescription(%s)", veaf.p(self.name), veaf.p(value))
    self.description = value
    return VeafAirWavesManager.add(self) -- add the zone to the list as soon as a description is available to index it
end

function AirWaveZone:getDescription()
    return self.description or self.name
end

function AirWaveZone:addWave(wave)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:addWave(%s)", veaf.p(self.name), veaf.p(wave))
    if not self.waves then
        self.waves = {wave}
    else
        table.insert(self.waves, wave)
    end
    return self
end

function AirWaveZone:setMessageStart(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setMessageStart(%s)", veaf.p(self.name), veaf.p(value))
    self.messageStart = value
    return self
end

function AirWaveZone:setOnStart(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setOnStart()", veaf.p(self.name))
    self.onStart = value
    return self
end

function AirWaveZone:setMessageDeploy(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setMessageDeploy(%s)", veaf.p(self.name), veaf.p(value))
    self.messageDeploy = value
    return self
end

function AirWaveZone:setOnDeploy(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setOnDeploy()", veaf.p(self.name))
    self.onDeploy = value
    return self
end

function AirWaveZone:setMessageDestroyed(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setMessageDestroyed(%s)", veaf.p(self.name), veaf.p(value))
    self.messageDestroyed = value
    return self
end

function AirWaveZone:setOnDestroyed(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setOnDestroyed()", veaf.p(self.name))
    self.onDestroyed = value
    return self
end

function AirWaveZone:setMessageFinished(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setMessageFinished(%s)", veaf.p(self.name), veaf.p(value))
    self.messageFinished = value
    return self
end

function AirWaveZone:setOnFinished(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setOnFinished()", veaf.p(self.name))
    self.onFinished = value
    return self
end

function AirWaveZone:setMessageStop(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setMessageStop(%s)", veaf.p(self.name), veaf.p(value))
    self.messageStop = value
    return self
end

function AirWaveZone:setOnStop(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setOnStop()", veaf.p(self.name))
    self.onStop = value
    return self
end

function AirWaveZone:setSilent(pSilent)
    
    local vSilent = pSilent
    if vSilent then 
        vSilent = true
    else
        vSilent = false
    end

    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setSilent(%s)", veaf.p(self.name), veaf.p(vSilent))
    self.silent = pSilent
    return self
end

function AirWaveZone:setRespawnRadius(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setRespawnRadius(%s)", veaf.p(self.name), veaf.p(value))
    self.respawnRadius = value
    if self.respawnRadius < 250 then self.respawnRadius = 250 end
    return self
end

function AirWaveZone:addPlayerCoalition(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:addPlayerCoalition(%s)", veaf.p(self.name), veaf.p(value))
    self.playerCoalitions[value] = value
    return self
end

function AirWaveZone:setDelayBeforeNextWave(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setDelayBeforeNextWave(%s)", veaf.p(self.name), veaf.p(value))
    self.delayBeforeNextWave = value
    return self
end

function AirWaveZone:setResetWhenDying()
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setResetWhenDying()", veaf.p(self.name))
    self.resetWhenDying = true
    return self
end

function AirWaveZone:setDelayBeforeActivating(value)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setDelayBeforeActivating(%s)", veaf.p(self.name), veaf.p(value))
    self.delayBeforeActivating = value
    return self
end

function AirWaveZone:setMinimumAltitudeInFeet(value)
  veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setMinimumAltitudeInFeet(%s)", veaf.p(self.name), veaf.p(value))
  self.minimumAltitude = value * 0.3048 -- convert from feet
  return self
end

function AirWaveZone:getMinimumAltitudeInMeters()
  veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:getMinimumAltitudeInMeters()=%s", veaf.p(self.name), veaf.p(self.minimumAltitude))
  return self.minimumAltitude
end

function AirWaveZone:setMaximumAltitudeInFeet(value)
  veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setMaximumAltitudeInFeet(%s)", veaf.p(self.name), veaf.p(value))
  self.maximumAltitude = value * 0.3048 -- convert from feet
  return self
end

function AirWaveZone:getMaximumAltitudeInMeters()
  veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:getMaximumAltitudeInMeters()=%s", veaf.p(self.name), veaf.p(self.maximumAltitude))
  return self.maximumAltitude
end

function AirWaveZone:getPlayerUnits()
    if not self.playerHumanUnits then
        veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:getPlayerUnits() - computing", veaf.p(self.name))
        self.playerHumanUnits = {}
        veaf.loggers.get(VeafAirWavesManager.Id):trace("playerCoalitions[]=%s", veaf.p(self.playerCoalitions))
        for _, unit in pairs(mist.DBs.humansByName) do
            --veaf.loggers.get(veafAirWaves.Id):trace("unit=%s", unit)
            veaf.loggers.get(VeafAirWavesManager.Id):trace("unit.unitName=%s", unit.unitName)
            veaf.loggers.get(VeafAirWavesManager.Id):trace("unit.groupName=%s", unit.groupName)
            veaf.loggers.get(VeafAirWavesManager.Id):trace("unit.coalition=%s", veaf.p(unit.coalition))
            local coalitionId = 0
            if unit.coalition then
                if unit.coalition:lower() == "red" then
                    coalitionId = coalition.side.RED
                elseif unit.coalition:lower() == "blue" then
                    coalitionId = coalition.side.BLUE
                end
            end                    
            if self.playerCoalitions[coalitionId] then
                if unit.category then
                    veaf.loggers.get(VeafAirWavesManager.Id):trace("unit.category=%s", unit.category)
                    if unit.category == "plane" then
                        veaf.loggers.get(VeafAirWavesManager.Id):trace("adding unit to enemy human units for QRA")
                        table.insert(self.playerHumanUnits, unit.unitName)
                    end
                end
            end
        end
    end
    return self.playerHumanUnits
end

function AirWaveZone:check()
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:check()", veaf.p(self.name))
    veaf.loggers.get(VeafAirWavesManager.Id):trace("self.state=%s", veaf.p(self.state))
    veaf.loggers.get(VeafAirWavesManager.Id):trace("timer.getTime()=%s", veaf.p(timer.getTime()))

    --scheduled state application is attempted regardless of airportlink checks etc. to take into account user requested states which go through scheduled_states as well
    --Stop scheduled is checked before even running the check function as it has the highest priority
    self:applyScheduledState()

    if self.state ~= VeafAirWavesManager.STATUS_STOP then

        --if the QRA is linked to an airbase. Airport is checked before even trying to deploy a group and check warehousing which has a lower priority
        if self.airportLink then
            veaf.loggers.get(VeafAirWavesManager.Id):trace("Checking Airport link : %s", veaf.p(self.airportLink))
            self:checkAirport()
            self:applyScheduledState()
        end

        if self.state ~= VeafAirWavesManager.STATUS_NOAIRBASE then
 
            --if warehousing is activated. Warehousing is checked before even trying to deploy a group
            if self.QRAcount ~= -1 then
                veaf.loggers.get(VeafAirWavesManager.Id):trace("Checking Warehousing...")
                veaf.loggers.get(VeafAirWavesManager.Id):trace("QRACount : %s", veaf.p(self.QRAcount))
                self:checkWarehousing()
                self:applyScheduledState()
            end

            if self.state ~= VeafAirWavesManager.STATUS_OUT then
                local unitNames = self:getPlayerUnits()
                veaf.loggers.get(VeafAirWavesManager.Id):trace("unitNames=%s", veaf.p(unitNames))
                local unitsInZone = nil
                local triggerZone = veaf.getTriggerZone(self.triggerZone)
                if triggerZone then
                    veaf.loggers.get(VeafAirWavesManager.Id):trace("triggerZone=%s", veaf.p(triggerZone))
                    if triggerZone.type == 0 then -- circular
                        unitsInZone = mist.getUnitsInZones(unitNames, {self.triggerZone})
                    elseif triggerZone.type == 2 then -- quad point
                        veaf.loggers.get(VeafAirWavesManager.Id):trace("checking in polygon %s", veaf.p(triggerZone.verticies))
                        unitsInZone = mist.getUnitsInPolygon(unitNames, triggerZone.verticies)
                    end
                else
                    unitsInZone = veaf.findUnitsInCircle(self.zoneCenter, self.zoneRadius, false, unitNames)
                end
                local nbUnitsInZone = 0
                for _, unit in pairs(unitsInZone) do
                    -- check the unit altitude against the ceiling and floor
                    if unit:inAir() then -- never count a landed aircraft
                        local alt = unit:getPoint().y
                        veaf.loggers.get(VeafAirWavesManager.Id):trace("check the unit altitude against the ceiling and floor")
                        veaf.loggers.get(VeafAirWavesManager.Id):trace("alt=%s", veaf.p(alt))
                        if alt < self:getMinimumAltitudeInMeters() or alt > self:getMaximumAltitudeInMeters() then
                            nbUnitsInZone = nbUnitsInZone + 1
                        end
                    end
                end
                veaf.loggers.get(VeafAirWavesManager.Id):trace("unitsInZone=%s", veaf.p(unitsInZone))
                veaf.loggers.get(VeafAirWavesManager.Id):trace("#unitsInZone=%s", veaf.p(#unitsInZone))
                veaf.loggers.get(VeafAirWavesManager.Id):trace("nbUnitsInZone=%s", veaf.p(nbUnitsInZone))
                veaf.loggers.get(VeafAirWavesManager.Id):trace("state=%s", veaf.p(self.state))
                if (self.state == VeafAirWavesManager.STATUS_READY) and (unitsInZone and nbUnitsInZone > 0) then
                    veaf.loggers.get(VeafAirWavesManager.Id):debug("self.state set to veafAirWaves.STATUS_READY_WAITINGFORMORE at timer.getTime()=%s", veaf.p(timer.getTime()))
                    self.state = VeafAirWavesManager.STATUS_READY_WAITINGFORMORE
                    self.timeSinceReady = timer.getTime()
                elseif (self.state == VeafAirWavesManager.STATUS_READY_WAITINGFORMORE) and (unitsInZone and nbUnitsInZone > 0) and (timer.getTime() - self.timeSinceReady > self.delayBeforeActivating) then
                    -- trigger the QRA
                    self:deploy(nbUnitsInZone)
                    self.timeSinceReady = -1
                elseif (self.state == VeafAirWavesManager.STATUS_DEAD) and (self.noNeedToLeaveZoneBeforeRearming or (not unitsInZone or nbUnitsInZone == 0)) then
                    -- rearm the QRA after a delay (if set)
                    if self.delayBeforeNextWave > 0 then
                        mist.scheduleFunction(AirWaveZone.rearm, {self}, timer.getTime()+self.delayBeforeNextWave)
                        self.state = VeafAirWavesManager.STATUS_WILLREARM
                    else
                        self:rearm()
                    end
                elseif (self.state == VeafAirWavesManager.STATUS_ACTIVE) then
                    local qraAlive = false
                    local inAir = false
                    for _, groupName in pairs(self.spawnedGroups) do
                        local group = Group.getByName(groupName)
                        if group then
                            qraAlive = true
                            local units = group:getUnits()
                            if units then
                                for _,unit in pairs(units) do
                                    if unit and unit:inAir() then
                                        inAir = true
                                    end
                                end
                            end
                        end
                    end
                    if not qraAlive then
                        -- signal QRA destroyed
                        self:destroyed()
                    elseif (self.resetWhenDying and nbUnitsInZone == 0) or inAir == false then 
                        -- QRA reset
                        self:rearm()
                    end
                end
            end
        end
    
        mist.scheduleFunction(AirWaveZone.check, {self}, timer.getTime() + VeafAirWavesManager.WATCHDOG_DELAY) 
    end
end

function AirWaveZone:setScheduledState(scheduledState)
    --priority level 1
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:setScheduledState(%s)", veaf.p(self.name), veaf.p(scheduledState))
    if scheduledState == VeafAirWavesManager.STATUS_STOP then
        self.scheduled_state = VeafAirWavesManager.STATUS_STOP
        veaf.loggers.get(VeafAirWavesManager.Id):trace("QRA STOP scheduled")
    --priority level 2
    elseif scheduledState == VeafAirWavesManager.STATUS_NOAIRBASE and self.scheduled_state ~= VeafAirWavesManager.STATUS_STOP then
        self.scheduled_state = VeafAirWavesManager.STATUS_NOAIRBASE
        veaf.loggers.get(VeafAirWavesManager.Id):trace("QRA NOAIRBASE scheduled")
    --priority level 3
    elseif scheduledState == VeafAirWavesManager.STATUS_OUT and self.scheduled_state ~= VeafAirWavesManager.STATUS_STOP and self.scheduled_state ~= VeafAirWavesManager.STATUS_NOAIRBASE then
        self.scheduled_state = VeafAirWavesManager.STATUS_OUT
        veaf.loggers.get(VeafAirWavesManager.Id):trace("QRA OUT scheduled")
    end
    return self
end

function AirWaveZone:applyScheduledState()
    if self.scheduled_state and self.state ~= VeafAirWavesManager.STATUS_ACTIVE then
        veaf.loggers.get(VeafAirWavesManager.Id):trace("QRA taking scheduled status : %s", veaf.p(self.scheduled_state))
        self.state = self.scheduled_state
    end
end

function AirWaveZone:checkAirport()
    local QRA_airportObject = veaf.getAirbaseForCoalition(self.airportLink, self.coalition)
    local airport_life_percent = nil
    if QRA_airportObject then
        airport_life_percent = veaf.getAirbaseLife(self.airportLink, true)
    end

    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s] is linked to airbase %s", veaf.p(self.name), veaf.p(self.airportLink))

    if not QRA_airportObject or airport_life_percent < self.airportMinLifePercent then
        veaf.loggers.get(VeafAirWavesManager.Id):trace("QRA lost it's airbase")
        self:setScheduledState(VeafAirWavesManager.STATUS_NOAIRBASE)
        if not self.silent and not self.noAB_announced then
            local msg = string.format(self.messageAirbaseDown, self:getDescription())
            for coalition, _ in pairs(self.ennemyCoalitions) do
                trigger.action.outTextForCoalition(coalition, msg, 15) 
            end
        end
        if self.onAirbaseDown then
            self.onAirbaseDown(QRA_airportObject)
        end
        self.noAB_announced = true
        
    elseif self.state == VeafAirWavesManager.STATUS_NOAIRBASE then
        veaf.loggers.get(VeafAirWavesManager.Id):trace("QRA has it's airbase %s", veaf.p(QRA_airportObject:getName()))
        if not self.silent then
            local msg = string.format(self.messageAirbaseUp, self:getDescription())
            for coalition, _ in pairs(self.ennemyCoalitions) do
                trigger.action.outTextForCoalition(coalition, msg, 15) 
            end
        end
        if self.onAirbaseUp then
            self.onAirbaseUp(QRA_airportObject)
        end

        self.noAB_announced = false
        self.state = VeafAirWavesManager.STATUS_DEAD --QRA that have just been recommisionned act as if they were dead since they need to be rearmed after a delay
        if self.scheduled_state == VeafAirWavesManager.STATUS_NOAIRBASE then self.scheduled_state = nil end --make sure you reset the scheduled state if you are within the bounds of this method
    end
end

function AirWaveZone:chooseGroupsToDeploy(nbUnitsInZone)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:chooseGroupsToDeploy(%s)", veaf.p(self.name), veaf.p(nbUnitsInZone))
    local biggestNumberLowerThanUnitsInZone = -1
    local groupsToDeploy = nil
    for enemyNb, groups in pairs(self.groupsToDeployByPlayerQuantity) do
        if nbUnitsInZone >= enemyNb then 
            biggestNumberLowerThanUnitsInZone = enemyNb
            groupsToDeploy = groups
        end 
    end
    if groupsToDeploy then
        -- process a random group definition
        local groupsToChooseFrom = groupsToDeploy[1]
        local numberOfGroups = groupsToDeploy[2]
        local bias = groupsToDeploy[3] 
        veaf.loggers.get(VeafAirWavesManager.Id):trace("groupsToChooseFrom=%s", veaf.p(groupsToChooseFrom))
        veaf.loggers.get(VeafAirWavesManager.Id):trace("numberOfGroups=%s", veaf.p(numberOfGroups))
        veaf.loggers.get(VeafAirWavesManager.Id):trace("bias=%s", veaf.p(bias))
        if groupsToChooseFrom and type(groupsToChooseFrom) == "table" and numberOfGroups and type(numberOfGroups) == "number" and bias and type(bias) == "number" then
        local result = {}
            for _ = 1, numberOfGroups do
                local group = veaf.randomlyChooseFrom(groupsToChooseFrom, bias)
                veaf.loggers.get(VeafAirWavesManager.Id):trace("group=%s", veaf.p(group))
                table.insert(result, group)
            end
            groupsToDeploy = result
        end
    end
    return groupsToDeploy
end

function AirWaveZone:deploy(nbUnitsInZone)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:deploy()", veaf.p(self.name))
    veaf.loggers.get(VeafAirWavesManager.Id):trace("nbUnitsInZone=[%s]", veaf.p(nbUnitsInZone))
    if self.minimumNbEnemyPlanes ~= -1 and self.minimumNbEnemyPlanes > nbUnitsInZone then
        veaf.loggers.get(VeafAirWavesManager.Id):trace("not enough enemies in zone, min=%s", veaf.p(self.minimumNbEnemyPlanes))
        return
    end

    if not self.silent then
        local msg = string.format(self.messageDeploy, self:getDescription())
        for coalition, _ in pairs(self.ennemyCoalitions) do
            trigger.action.outTextForCoalition(coalition, msg, 15)
        end
    end
    local groupsToDeploy = self:chooseGroupsToDeploy(nbUnitsInZone)
    self.spawnedGroups = {}
    if groupsToDeploy then
        for _, groupName in pairs(groupsToDeploy) do
            local group = Group.getByName(groupName)
            local spawnSpot = group:getUnit(1):getPoint()
            local vars = {}
            vars.point = mist.getRandPointInCircle(spawnSpot, self.respawnRadius)
            vars.point.z = vars.point.y 
            vars.point.y = spawnSpot.y
            vars.gpName = groupName
            vars.action = 'clone'
            vars.route = mist.getGroupRoute(groupName, 'task')
            local newGroup = mist.teleportToPoint(vars) -- respawn with radius
            table.insert(self.spawnedGroups, newGroup.name)
        end
        veaf.loggers.get(VeafAirWavesManager.Id):trace("self.spawnedGroups=%s", veaf.p(self.spawnedGroups))
        self.state = VeafAirWavesManager.STATUS_ACTIVE
    end
    if self.onDeploy then
        self.onDeploy(nbUnitsInZone)
    end
end

function AirWaveZone:destroyed()
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:destroyed()", veaf.p(self.name))
    if not self.silent then
        local msg = string.format(self.messageDestroyed, self:getDescription())
        for coalition, _ in pairs(self.ennemyCoalitions) do
            trigger.action.outTextForCoalition(coalition, msg, 15)
        end
    end
    if self.onDestroyed then
        self.onDestroyed()
    end
    self.state = VeafAirWavesManager.STATUS_DEAD

    if self.QRAcount > 0 then
        veaf.loggers.get(VeafAirWavesManager.Id):trace("QRA will now see one of it's aicraft groups removed")
        self.QRAcount = self.QRAcount - 1
    end
end

function AirWaveZone:rearm(silent)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:rearm()", veaf.p(self.name))
    if not self.silent and not silent then
        local msg = string.format(self.messageReady, self:getDescription())
        for coalition, _ in pairs(self.ennemyCoalitions) do
            trigger.action.outTextForCoalition(coalition, msg, 15) 
        end
    end
    if self.spawnedGroups then 
        for _, groupName in pairs(self.spawnedGroups) do
            local group = Group.getByName(groupName)
            if group then
                group:destroy()
            end
        end
    end
    if self.onReady then
        self.onReady()
    end
    self.state = VeafAirWavesManager.STATUS_READY
end

function AirWaveZone:start()
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:start()", veaf.p(self.name))
    self.scheduled_state = nil --make sure you reset the scheduled state if you are within the bounds of this method
    self:rearm()
    self:check()

    if not self.silent then
        local msg = string.format(self.messageStart, self:getDescription())
        for coalition, _ in pairs(self.ennemyCoalitions) do
            trigger.action.outTextForCoalition(coalition, msg, 15)
        end
    end
    if self.onStart then
        self.onStart()
    end

    return self
end

function AirWaveZone:stop(silent)
    veaf.loggers.get(VeafAirWavesManager.Id):trace("AirWaveZone[%s]:stop()", veaf.p(self.name))
    self:setScheduledState(VeafAirWavesManager.STATUS_STOP)

    if not self.silent and not silent then
        local msg = string.format(self.messageStop, self:getDescription())
        for coalition, _ in pairs(self.ennemyCoalitions) do
            trigger.action.outTextForCoalition(coalition, msg, 15) 
        end
    end
    if self.onStop then
        self.onStop()
    end

    return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------


function VeafAirWavesManager.ToggleAllSilence(state)
    if state then 
        VeafAirWavesManager.AllSilence = true
    else
        VeafAirWavesManager.AllSilence = false
    end
end

function VeafAirWavesManager.add(aQraObject, aName) 
  local name = aName or aQraObject:getName()
  VeafAirWavesManager.qras[name] = aQraObject
  return aQraObject
end

function VeafAirWavesManager.get(aNameString)
  return VeafAirWavesManager.qras[aNameString]
end