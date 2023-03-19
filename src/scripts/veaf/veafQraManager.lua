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

veafQraManager = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafQraManager.Id = "QRA"

--- Version.
veafQraManager.Version = "1.2.0"

-- trace level, specific to this module
--veafQraManager.LogLevel = "trace"

veaf.loggers.new(veafQraManager.Id, veafQraManager.LogLevel)

function veafQraManager.statusToString(status)
    if status == veafQraManager.STATUS_WILLREARM then return "STATUS_WILLREARM" end
    if status == veafQraManager.STATUS_READY then return "STATUS_READY" end
    if status == veafQraManager.STATUS_READY_WAITINGFORMORE then return "STATUS_READY_WAITINGFORMORE" end
    if status == veafQraManager.STATUS_ACTIVE then return "STATUS_ACTIVE" end
    if status == veafQraManager.STATUS_DEAD then return "STATUS_DEAD" end
    return ""
  end
veafQraManager.STATUS_WILLREARM = 0
veafQraManager.STATUS_READY = 1
veafQraManager.STATUS_READY_WAITINGFORMORE = 1.5
veafQraManager.STATUS_ACTIVE = 2
veafQraManager.STATUS_DEAD = 3

--scheduled states
veafQraManager.STATUS_OUT = 4
veafQraManager.STATUS_NOAIRBASE = 5
veafQraManager.STATUS_STOP = 6

veafQraManager.WATCHDOG_DELAY = 5

veafQraManager.MINIMUM_LIFE_FOR_QRA_IN_PERCENT = 10

veafQraManager.DEFAULT_airbaseMinLifePercent = 0.9

veafQraManager.AllSilence = false --value to set all spawned QRAs to silent if true. By default it's false but this value can be set in the missionConfig
veafQraManager.DEFAULT_MESSAGE_START = "%s is online"
veafQraManager.DEFAULT_MESSAGE_DEPLOY = "%s is deploying"
veafQraManager.DEFAULT_MESSAGE_DESTROYED = "%s has been destroyed"
veafQraManager.DEFAULT_MESSAGE_READY = "%s is ready"
veafQraManager.DEFAULT_MESSAGE_OUT = "%s is out of aircrafts"
veafQraManager.DEFAULT_MESSAGE_RESUPPLIED = "%s has been resupplied"
veafQraManager.DEFAULT_MESSAGE_AIRBASE_DOWN = "%s lost it's airbase"
veafQraManager.DEFAULT_MESSAGE_AIRBASE_UP = "%s now has an airbase"
veafQraManager.DEFAULT_MESSAGE_STOP = "%s is offline"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafQraManager.qras = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafQRA class methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafQRA = {}
function VeafQRA.init(object)
    -- technical name (QRA instance name)
    object.name = nil
    -- trigger zone name (if set, we'll use a DCS trigger zone)
    object.triggerZoneName = nil
    -- center (point in the center of the circle, when not using a DCS trigger zone)
    object.zoneCenter = nil
    -- radius (size of the circle, when not using a zone)
    object.zoneRadius = nil
    -- draw the zone on screen
    object.drawZone = false
    -- description for the briefing
    object.description = nil
    -- aircraft groups forming the QRA
    object.groups = {}
    -- aircraft groups forming the QRA, in a table by enemy quantity (i.e. if this number of enemies are in the zone, spawn these groups)
    object.groupsToDeployByEnemyQuantity = {}
    -- coalition for the QRA
    object.coalition = nil
    -- coalitions the QRA is defending against
    object.ennemyCoalitions = {}
    -- message when the QRA is started
    object.messageStart = veafQraManager.DEFAULT_MESSAGE_START
    -- event when the QRA is started
    object.onStart = nil
    -- message when the QRA is triggered
    object.messageDeploy = veafQraManager.DEFAULT_MESSAGE_DEPLOY
    -- event when the QRA is triggered
    object.onDeploy = nil
    -- message when the QRA is destroyed
    object.messageDestroyed = veafQraManager.DEFAULT_MESSAGE_DESTROYED
    -- event when the QRA is destroyed
    object.onDestroyed = nil
    -- message when the QRA is ready
    object.messageReady = veafQraManager.DEFAULT_MESSAGE_READY
    -- event when the QRA is ready
    object.onReady = nil
    -- message when the QRA is out of aircrafts
    object.messageOut = veafQraManager.DEFAULT_MESSAGE_OUT
    -- event when the QRA is out of aircrafts
    object.onOut = nil
    -- message when the QRA has been resupplied and will start operations against
    object.messageResupplied = veafQraManager.DEFAULT_MESSAGE_RESUPPLIED
    -- event when the QRA has been resupplied and will start operations against
    object.onResupplied = nil
    -- message when the QRA has lost the airbase it operates from
    object.messageAirbaseDown = veafQraManager.DEFAULT_MESSAGE_AIRBASE_DOWN
    -- event when the QRA has lost the airbase it operates from
    object.onAirbaseDown = nil
    -- message when the QRA has retrieved the airbase it operates from and will start operations again
    object.messageAirbaseUp = veafQraManager.DEFAULT_MESSAGE_AIRBASE_UP
    -- event when the QRA has retrieved the airbase it operates from and will start operations again
    object.onAirbaseUp = nil
    -- message when the QRA is stopped
    object.messageStop = veafQraManager.DEFAULT_MESSAGE_STOP
    -- event when the QRA is stopped
    object.onStop = nil
	-- silent means no message is emitted
    object.silent = veafQraManager.AllSilence
    -- default position for respawns (im meters, lat/lon, relative to the zone center)
    object.respawnDefaultOffset = {latDelta=0, lonDelta=0}
    -- radius of the defenders groups spawn
    object.respawnRadius = 250
    -- reacts when helicopters enter the zone
    object.reactOnHelicopters = false
    -- delay before activating
    object.delayBeforeActivating = -1
    -- delay before rearming
    object.delayBeforeRearming = -1
    -- the enemy does not have to leave the zone before the QRA is rearmed
    object.noNeedToLeaveZoneBeforeRearming = false
    -- reset the QRA immediately if all the enemy units leave the zone
    object.resetWhenLeavingZone = false
    -- maximum number of QRA ready for action at once, -1 indicates infinite
    object.QRAmaxCount = -1
    -- number of groups of aircrafts that can be spawned for this QRA in total, -1 indicates infinite.
    object.QRAcount = -1
    -- delay in minutes before the QRA counter is increased by one, simulating some sort of logistic chain of aircrafts.
    object.delayBeforeQRAresupply = 0
    -- maximum number of resupplies at a given time, simulating some sort of warehousing, -1 indicates infinite. Is decremented every time a resupply happens. 0 indicates no resupply.
    object.QRAresupplyMax = -1
    -- minimum QRAcount that will trigger a resupply, -1 indicates as soon as an aircraft is lost
    object.QRAminCountforResupply = -1
    -- how many aircraft groups are resupplied at once   
    object.resupplyAmount = 1
    -- indicator to know if the QRA is being resupplied or not
    object.isResupplying = false
    -- name of the airport to which the QRA is linked, QRAs will be deployed only if this is set and the airport is captured by the QRA's coalition or if this is not set
    object.airportLink = nil
    -- minimum linked airbase life percentage (from 0 to 1) for the QRA to have it's airbase available
    object.airportMinLifePercent = veafQraManager.DEFAULT_airbaseMinLifePercent
    -- boolean to know if the status OUT was announced or not
    object.outAnnounced = false
    -- boolean to know if the status NOAIRBASE was announced or not
    object.noAB_announced = false
    -- minimum number of enemies in the zone to trigger deployment; updated automatically by setGroupsToDeployByEnemyQuantity
    object.minimumNbEnemyPlanes = -1
    -- planes in the zone will only be detected below this altitude (in feet)
    object.minimumAltitude = -999999
    -- planes in the zone will only be detected above this altitude (in feet)
    object.maximumAltitude = 999999
    object.timer = nil
    object.state = nil
    object.scheduled_state = nil
    object._enemyHumanUnits = nil
    object.spawnedGroupsNames = {}
end

function VeafQRA.ToggleAllSilence(state)
    if state then
        veafQraManager.AllSilence = true
    else
        veafQraManager.AllSilence = false
    end
end

function VeafQRA:new(objectToCopy)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA:new()")

    local objectToCreate = objectToCopy or {} -- create object if user does not provide one
    setmetatable(objectToCreate, self)
    self.__index = self

    -- init the new object
    VeafQRA.init(objectToCreate)

    return objectToCreate
end

function VeafQRA:setName(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[]:setName(%s)", veaf.p(value))
    self.name = value
    return veafQraManager.add(self) -- add the QRA to the QRA list as soon as a name is available to index it
end

function VeafQRA:setTriggerZone(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setTriggerZone(%s)", veaf.p(self.name), veaf.p(value))
    self.triggerZoneName = value
    return self
end

function VeafQRA:setZoneCenter(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setZoneCenter(%s)", veaf.p(self.name), veaf.p(value))
    self.zoneCenter = value
    return self
end

function VeafQRA:setZoneCenterFromCoordinates(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setZoneCenterFromCoordinates(%s)", veaf.p(self.name), veaf.p(value))
    local _lat, _lon = veaf.computeLLFromString(value)
    local vec3 = coord.LLtoLO(_lat, _lon)
    return self:setZoneCenter(vec3)
end

function VeafQRA:setZoneRadius(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setZoneRadius(%s)", veaf.p(self.name), veaf.p(value))
    self.zoneRadius = value
    return self
end

function VeafQRA:setDescription(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setDescription(%s)", veaf.p(self.name), veaf.p(value))
    self.description = value
    return veafQraManager.add(self) -- add the QRA to the QRA list as soon as a name is available to index it
end

function VeafQRA:getDescription()
    return self.description or self.name
end

function VeafQRA:getName()
  return self.name or self.description
end

function VeafQRA:addGroup(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:addGroup(%s)", veaf.p(self.name), veaf.p(value))
    if not self.groupsToDeployByEnemyQuantity[1] then
        self.groupsToDeployByEnemyQuantity[1] = {}
    end
    table.insert(self.groupsToDeployByEnemyQuantity[1], value)
    return self
end

function VeafQRA:addRandomGroup(groups, number, bias)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:addRandomGroup(%s, %s, %s)", veaf.p(self.name), veaf.p(groups), veaf.p(number), veaf.p(bias))
    return self:addGroup({groups, number or 1, bias or 0})
end

function VeafQRA:setGroupsToDeployByEnemyQuantity(enemyNb, groupsToDeploy)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setGroupsToDeployByEnemyQuantity(%s) -> %s", veaf.p(self.name), veaf.p(enemyNb), veaf.p(groupsToDeploy))
    self.groupsToDeployByEnemyQuantity[enemyNb] = groupsToDeploy
    if self.minimumNbEnemyPlanes == -1 or self.minimumNbEnemyPlanes > enemyNb then
        self.minimumNbEnemyPlanes = enemyNb
    end
    return self
end

function VeafQRA:setRandomGroupsToDeployByEnemyQuantity(enemyNb, groups, number, bias)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setRandomGroupsToDeployByEnemyQuantity(%s, %s, %s, %s)", veaf.p(self.name), veaf.p(enemyNb), veaf.p(groups), veaf.p(number), veaf.p(bias))
    return self:setGroupsToDeployByEnemyQuantity(enemyNb, {groups, number or 1, bias or 0})
end

function VeafQRA:setCoalition(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setCoalition(%s)", veaf.p(self.name), veaf.p(value))
    self.coalition = value
    return self
end

function VeafQRA:addEnnemyCoalition(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:addEnnemyCoalition(%s)", veaf.p(self.name), veaf.p(value))
    self.ennemyCoalitions[value] = value
    return self
end

function VeafQRA:getEnnemyCoalition()
    local result = nil
    for coalition, _ in pairs(self.ennemyCoalitions) do
      result = coalition
      break
    end
    return result
end

function VeafQRA:setMessageStart(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setMessageStart(%s)", veaf.p(self.name), veaf.p(value))
    self.messageStart = value
    return self
end

function VeafQRA:setOnStart(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setOnStart()", veaf.p(self.name))
    self.onStart = value
    return self
end

function VeafQRA:setMessageDeploy(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setMessageDeploy(%s)", veaf.p(self.name), veaf.p(value))
    self.messageDeploy = value
    return self
end

function VeafQRA:setOnDeploy(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setOnDeploy()", veaf.p(self.name))
    self.onDeploy = value
    return self
end

function VeafQRA:setMessageDestroyed(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setMessageDestroyed(%s)", veaf.p(self.name), veaf.p(value))
    self.messageDestroyed = value
    return self
end

function VeafQRA:setOnDestroyed(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setOnDestroyed()", veaf.p(self.name))
    self.onDestroyed = value
    return self
end

function VeafQRA:setMessageReady(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setMessageReady(%s)", veaf.p(self.name), veaf.p(value))
    self.messageReady = value
    return self
end

function VeafQRA:setOnReady(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setOnReady()", veaf.p(self.name))
    self.onReady = value
    return self
end

function VeafQRA:setMessageOut(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setMessageOut(%s)", veaf.p(self.name), veaf.p(value))
    self.messageOut = value
    return self
end

function VeafQRA:setOnOut(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setOnOut()", veaf.p(self.name))
    self.onOut = value
    return self
end

function VeafQRA:setMessageResupplied(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setMessageResupplied(%s)", veaf.p(self.name), veaf.p(value))
    self.messageResupplied = value
    return self
end

function VeafQRA:setOnResupplied(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setOnResupplied()", veaf.p(self.name))
    self.onResupplied = value
    return self
end

function VeafQRA:setMessageAirbaseDown(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setMessageAirbaseDown(%s)", veaf.p(self.name), veaf.p(value))
    self.messageAirbaseDown = value
    return self
end

function VeafQRA:setOnAirbaseDown(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setOnAirbaseDown()", veaf.p(self.name))
    self.onAirbaseDown = value
    return self
end

function VeafQRA:setMessageAirbaseUp(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setMessageAirbaseUp(%s)", veaf.p(self.name), veaf.p(value))
    self.messageAirbaseUp = value
    return self
end

function VeafQRA:setOnAirbaseUp(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setOnAirbaseUp()", veaf.p(self.name))
    self.onAirbaseUp = value
    return self
end

function VeafQRA:setMessageStop(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setMessageStop(%s)", veaf.p(self.name), veaf.p(value))
    self.messageStop = value
    return self
end

function VeafQRA:setOnStop(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setOnStop()", veaf.p(self.name))
    self.onStop = value
    return self
end

function VeafQRA:setSilent(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setSilent(%s)", veaf.p(self.name), veaf.p(value))
    self.silent = value or false
    return self
end

function VeafQRA:setDrawZone(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setDrawZone(%s)", veaf.p(self.name), veaf.p(value))
    self.drawZone = value or false
    return self
end

--TODO, warehousing for each group within a QRA and not just the whole QRA
function VeafQRA:setQRAcount(count)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setQRAcount(%s)", veaf.p(self.name), veaf.p(count))
    if count and type(count) == 'number' and count >= -1 then
        self.QRAcount = count
    end
    return self
end

function VeafQRA:setQRAmaxCount(maxCount)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setQRAmaxCount(%s)", veaf.p(self.name), veaf.p(maxCount))
    if maxCount and type(maxCount) == 'number' and maxCount >= -1 then
        self.QRAmaxCount = maxCount
    end
    return self
end

function VeafQRA:setQRAresupplyDelay(resupplyDelay)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setQRAresupplyDelay(%s)", veaf.p(self.name), veaf.p(resupplyDelay))
    if resupplyDelay and type(resupplyDelay) == 'number' and resupplyDelay >= 0 then
        self.delayBeforeQRAresupply = resupplyDelay
    end
    return self
end

function VeafQRA:setQRAmaxResupplyCount(maxResupplyCount)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setQRAmaxResupplyCount(%s)", veaf.p(self.name), veaf.p(maxResupplyCount))
    if maxResupplyCount and type(maxResupplyCount) == 'number' and maxResupplyCount >= -1 then
        self.QRAresupplyMax = maxResupplyCount
    end
    return self
end

function VeafQRA:setQRAminCountforResupply(minCountforResupply)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setQRAminCountforResupply(%s)", veaf.p(self.name), veaf.p(minCountforResupply))
    if minCountforResupply and type(minCountforResupply) == 'number' and minCountforResupply >= -1 and minCountforResupply ~= 0 then
        self.QRAminCountforResupply = minCountforResupply
    end
    return self
end

function VeafQRA:setResupplyAmount(resupplyAmount)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setResupplyAmount(%s)", veaf.p(self.name), veaf.p(resupplyAmount))
    if resupplyAmount and type(resupplyAmount) == 'number' and resupplyAmount >= 1 then
        self.resupplyAmount = resupplyAmount
    end
    return self
end

function VeafQRA:setAirportLink(airport_name)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setAirportLink(%s)", veaf.p(self.name), veaf.p(airport_name))
    if airport_name and type(airport_name) == 'string' and Airbase.getByName(airport_name) then
        self.airportLink = airport_name
    end
    return self
end

function VeafQRA:setAirportMinLifePercent(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setAirportMinLifePercent(%s)", veaf.p(self.name), veaf.p(value))
    if value and value >= 0 and value <= 1 then
        self.airportMinLifePercent = value
    end
    return self
end

function VeafQRA:setReactOnHelicopters()
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setReactOnHelicopters()", veaf.p(self.name))
    self.reactOnHelicopters = true
    return self
end

---set the default respawn offset (in meters, relative to the zone center)
---@param defaultOffsetLatitude any in meters
---@param defaultOffsetLongitude any in meters
---@return table self
function VeafQRA:setRespawnDefaultOffset(defaultOffsetLatitude, defaultOffsetLongitude)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setRespawnDefaultOffset(%s, %s)", veaf.p(self.name), veaf.p(defaultOffsetLatitude), veaf.p(defaultOffsetLongitude))
    self.respawnDefaultOffset = { latDelta = defaultOffsetLatitude, lonDelta = defaultOffsetLongitude}
    return self
end

function VeafQRA:setRespawnRadius(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setRespawnRadius(%s)", veaf.p(self.name), veaf.p(value))
    self.respawnRadius = value
    if self.respawnRadius < 250 then self.respawnRadius = 250 end
    return self
end

function VeafQRA:setDelayBeforeRearming(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setDelayBeforeRearming(%s)", veaf.p(self.name), veaf.p(value))
    self.delayBeforeRearming = value
    return self
end

function VeafQRA:setNoNeedToLeaveZoneBeforeRearming()
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setNoNeedToLeaveZoneBeforeRearming()", veaf.p(self.name))
    self.noNeedToLeaveZoneBeforeRearming = true
    return self
end

function VeafQRA:setResetWhenLeavingZone()
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setResetWhenLeavingZone()", veaf.p(self.name))
    self.resetWhenLeavingZone = true
    return self
end

function VeafQRA:setDelayBeforeActivating(value)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setDelayBeforeActivating(%s)", veaf.p(self.name), veaf.p(value))
    self.delayBeforeActivating = value
    return self
end

function VeafQRA:setMinimumAltitudeInFeet(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setMinimumAltitudeInFeet(%s)", veaf.p(self.name), veaf.p(value))
  self.minimumAltitude = value * 0.3048 -- convert from feet
  return self
end

function VeafQRA:getMinimumAltitudeInMeters()
  return self.minimumAltitude
end

function VeafQRA:setMaximumAltitudeInFeet(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setMaximumAltitudeInFeet(%s)", veaf.p(self.name), veaf.p(value))
  self.maximumAltitude = value * 0.3048 -- convert from feet
  return self
end

function VeafQRA:getMaximumAltitudeInMeters()
  return self.maximumAltitude
end

function VeafQRA:_getEnemyHumanUnits()
    if not self._enemyHumanUnits then
        veaf.loggers.get(veafQraManager.Id):trace("VeafQRA[%s]:_getEnemyHumanUnits() - computing", veaf.p(self.name))
        self._enemyHumanUnits = {}
        for _, unit in pairs(mist.DBs.humansByName) do
            local coalitionId = 0
            if unit.coalition then
                if unit.coalition:lower() == "red" then
                    coalitionId = coalition.side.RED
                elseif unit.coalition:lower() == "blue" then
                    coalitionId = coalition.side.BLUE
                end
            end
            if self.ennemyCoalitions[coalitionId] then
                if unit.category then
                    if     (unit.category == "plane")
                        or (unit.category == "helicopter" and self.reactOnHelicopters)
                    then
                        veaf.loggers.get(veafQraManager.Id):trace("adding unit to enemy human units for QRA")
                        table.insert(self._enemyHumanUnits, unit.unitName)
                    end
                end
            end
        end
    end
    return self._enemyHumanUnits
end

function VeafQRA:check()
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:check()", veaf.p(self.name))
    veaf.loggers.get(veafQraManager.Id):debug("self.state=%s", veaf.p(veafQraManager.statusToString(self.state)))
    veaf.loggers.get(veafQraManager.Id):trace("timer.getTime()=%s", veaf.p(timer.getTime()))

    --scheduled state application is attempted regardless of airportlink checks etc. to take into account user requested states which go through scheduled_states as well
    --Stop scheduled is checked before even running the check function as it has the highest priority
    self:applyScheduledState()

    if self.state ~= veafQraManager.STATUS_STOP then

        --if the QRA is linked to an airbase. Airport is checked before even trying to deploy a group and check warehousing which has a lower priority
        if self.airportLink then
            veaf.loggers.get(veafQraManager.Id):trace("Checking Airport link : %s", veaf.p(self.airportLink))
            self:checkAirport()
            self:applyScheduledState()
        end

        if self.state ~= veafQraManager.STATUS_NOAIRBASE then

            --if warehousing is activated. Warehousing is checked before even trying to deploy a group
            if self.QRAcount ~= -1 then
                veaf.loggers.get(veafQraManager.Id):trace("Checking Warehousing...")
                veaf.loggers.get(veafQraManager.Id):trace("QRACount : %s", veaf.p(self.QRAcount))
                self:checkWarehousing()
                self:applyScheduledState()
            end

            if self.state ~= veafQraManager.STATUS_OUT then
                local unitNames = self:_getEnemyHumanUnits()
                local unitsInZone = nil
                local triggerZone = veaf.getTriggerZone(self.triggerZoneName)
                if triggerZone then
                    if triggerZone.type == 0 then -- circular
                        unitsInZone = mist.getUnitsInZones(unitNames, {self.triggerZoneName})
                    elseif triggerZone.type == 2 then -- quad point
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
                        if alt >= self:getMinimumAltitudeInMeters() and alt <= self:getMaximumAltitudeInMeters() then
                            nbUnitsInZone = nbUnitsInZone + 1
                        end
                    end
                end
                if (self.state == veafQraManager.STATUS_READY) and (unitsInZone and nbUnitsInZone > 0) then
                    veaf.loggers.get(veafQraManager.Id):debug(string.format("self.state set to veafQraManager.STATUS_READY_WAITINGFORMORE at timer.getTime()=%s", veaf.p(timer.getTime())))
                    self.state = veafQraManager.STATUS_READY_WAITINGFORMORE
                    self.timeSinceReady = timer.getTime()
                elseif (self.state == veafQraManager.STATUS_READY_WAITINGFORMORE) and (unitsInZone and nbUnitsInZone > 0) and (timer.getTime() - self.timeSinceReady > self.delayBeforeActivating) then
                    -- trigger the QRA
                    self:deploy(nbUnitsInZone)
                    self.timeSinceReady = -1
                elseif (self.state == veafQraManager.STATUS_DEAD) and (self.noNeedToLeaveZoneBeforeRearming or (not unitsInZone or nbUnitsInZone == 0)) then
                    -- rearm the QRA after a delay (if set)
                    if self.delayBeforeRearming > 0 then
                        mist.scheduleFunction(VeafQRA.rearm, {self}, timer.getTime()+self.delayBeforeRearming)
                        self.state = veafQraManager.STATUS_WILLREARM
                    else
                        self:rearm()
                    end
                elseif (self.state == veafQraManager.STATUS_ACTIVE) then
                    local qraAlive = false
                    local qraInAir = false
                    for _, groupName in pairs(self.spawnedGroupsNames) do
                        local group = Group.getByName(groupName)
                        if group then
                            local groupAtLeastOneUnitAlive = false
                            local groupAtLeastOneUnitInAir = false
                            local category = group:getCategory()
                            local units = group:getUnits()
                            if units then
                                for _,unit in pairs(units) do
                                    if unit then
                                        local unitLife = unit:getLife()
                                        local unitLife0 = unit:getLife0()
                                        local unitLifePercent = 100 * unitLife / unitLife0
                                        if unitLifePercent >= veafQraManager.MINIMUM_LIFE_FOR_QRA_IN_PERCENT then
                                            groupAtLeastOneUnitAlive = true
                                        end
                                        if category == 0 --[[airplanes]] or category == 1 --[[helicopters]] then
                                            -- check if at least one unit is still airborne
                                            if unit:inAir() then
                                                groupAtLeastOneUnitInAir = true
                                            end
                                        else
                                            -- consider that ground units have never landed
                                            groupAtLeastOneUnitInAir = true
                                        end
                                    end
                                end
                            end
                            qraAlive = qraAlive or groupAtLeastOneUnitAlive
                            qraInAir = qraInAir or groupAtLeastOneUnitInAir
                            veaf.loggers.get(veafQraManager.Id):trace("qraAlive=%s", veaf.p(qraAlive))
                            veaf.loggers.get(veafQraManager.Id):trace("qraInAir=%s", veaf.p(qraInAir))
                        end
                    end
                    if not qraAlive then
                        -- signal QRA destroyed
                        self:destroyed()
                    elseif (self.resetWhenLeavingZone and nbUnitsInZone == 0) or not qraInAir then
                        -- QRA reset
                        self:rearm()
                    end
                end
            end
        end

        mist.scheduleFunction(VeafQRA.check, {self}, timer.getTime() + veafQraManager.WATCHDOG_DELAY)
    end
end

function VeafQRA:setScheduledState(scheduledState)
    --priority level 1
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:setScheduledState(%s)", veaf.p(self.name), veaf.p(scheduledState))
    if scheduledState == veafQraManager.STATUS_STOP then
        self.scheduled_state = veafQraManager.STATUS_STOP
        veaf.loggers.get(veafQraManager.Id):debug("QRA STOP scheduled")
    --priority level 2
    elseif scheduledState == veafQraManager.STATUS_NOAIRBASE and self.scheduled_state ~= veafQraManager.STATUS_STOP then
        self.scheduled_state = veafQraManager.STATUS_NOAIRBASE
        veaf.loggers.get(veafQraManager.Id):debug("QRA NOAIRBASE scheduled")
    --priority level 3
    elseif scheduledState == veafQraManager.STATUS_OUT and self.scheduled_state ~= veafQraManager.STATUS_STOP and self.scheduled_state ~= veafQraManager.STATUS_NOAIRBASE then
        self.scheduled_state = veafQraManager.STATUS_OUT
        veaf.loggers.get(veafQraManager.Id):debug("QRA OUT scheduled")
    end
    return self
end

function VeafQRA:applyScheduledState()
    if self.scheduled_state and self.state ~= veafQraManager.STATUS_ACTIVE then
        veaf.loggers.get(veafQraManager.Id):debug("QRA taking scheduled status : %s", veaf.p(self.scheduled_state))
        self.state = self.scheduled_state
    end
end

function VeafQRA:checkAirport()
    local QRA_airportObject = veaf.getAirbaseForCoalition(self.airportLink, self.coalition)
    local airport_life_percent = nil
    if QRA_airportObject then
        airport_life_percent = veaf.getAirbaseLife(self.airportLink, true)
    end

    veaf.loggers.get(veafQraManager.Id):trace("VeafQRA[%s] is linked to airbase %s", veaf.p(self.name), veaf.p(self.airportLink))

    if not QRA_airportObject or airport_life_percent < self.airportMinLifePercent then
        veaf.loggers.get(veafQraManager.Id):trace("QRA lost it's airbase")
        self:setScheduledState(veafQraManager.STATUS_NOAIRBASE)
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

    elseif self.state == veafQraManager.STATUS_NOAIRBASE then
        veaf.loggers.get(veafQraManager.Id):trace("QRA has it's airbase %s", veaf.p(QRA_airportObject:getName()))
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
        self.state = veafQraManager.STATUS_DEAD --QRA that have just been recommisionned act as if they were dead since they need to be rearmed after a delay
        if self.scheduled_state == veafQraManager.STATUS_NOAIRBASE then self.scheduled_state = nil end --make sure you reset the scheduled state if you are within the bounds of this method
    end
end

    -- -- maximum number of QRA ready for action at once, -1 indicates infinite
    -- QRAmaxCount = -1
    -- -- number of groups of aircrafts that can be spawned for this QRA in total, -1 indicates infinite
    -- QRAcount = -1
    -- -- delay in minutes before the QRA counter is increased by one, simulating some sort of logistic chain of aircrafts.
    -- delayBeforeQRAresupply = 0
    -- -- maximum number of resupplies at a given time, simulating some sort of warehousing, -1 indicates infinite. Is decremented every time a resupply happens if not equal to -1 originally. 0 indicated no resupply.
    -- QRAresupplyMax = -1
    -- -- minimum QRAcount that will trigger a resupply, -1 indicates as soon as an aircraft is lost
    -- QRAminCountforResupply = -1
    -- -- how many aircraft groups are resupplied at once   
    --resupplyAmount = 1
    -- -- indicator to know if the QRA is being resupplied or not
    --isResupplying = false

function VeafQRA:checkWarehousing()
    veaf.loggers.get(veafQraManager.Id):trace("VeafQRA[%s] resupply state is %s", veaf.p(self.name), veaf.p(self.isResupplying))

    --if a resupply is not already on the way and if there are aircrafts in stock and if the available aircraft count is below the threshold or if an aircraft was just lost and the resupply mode indicates to resupply whenever an aircraft is lost
    if not self.isResupplying and self.QRAresupplyMax ~= 0 and (self.QRAcount < self.QRAminCountforResupply or (self.QRAcount < self.QRAmaxCount or (self.QRAmaxCount == -1 and self.state == veafQraManager.STATUS_DEAD)) and self.QRAminCountforResupply == -1) then
        veaf.loggers.get(veafQraManager.Id):trace("QRA has %s/%s aircraft groups available", veaf.p(self.QRAcount), veaf.p(self.QRAmaxCount))
        veaf.loggers.get(veafQraManager.Id):trace("QRA has %s aircraft groups ready for resupply (-1 for infinite)", veaf.p(self.QRAresupplyMax))
        veaf.loggers.get(veafQraManager.Id):trace("QRA resupply asks for %s aircraft groups", veaf.p(self.resupplyAmount))
        local resupplyAmount = self.resupplyAmount
        --take into account the maximum number of QRA groups as to not oversupply it
        if self.QRAmaxCount ~= -1 and resupplyAmount > self.QRAmaxCount - self.QRAcount then
            resupplyAmount = self.QRAmaxCount - self.QRAcount
            veaf.loggers.get(veafQraManager.Id):trace("There are only %s available aircraft group slots for this QRA", veaf.p(self.QRAmaxCount - self.QRAcount))
        end

        --take into account the maximum number of QRA groups that can be supplied by the stock
        if self.QRAresupplyMax ~= -1 and resupplyAmount > self.QRAresupplyMax then
            resupplyAmount = self.QRAresupplyMax
            veaf.loggers.get(veafQraManager.Id):trace("QRA can only be resupplied by %s aircraft groups", veaf.p(self.QRAresupplyMax))
        end

        veaf.loggers.get(veafQraManager.Id):trace("%s aircraft groups will be handled for resupply", veaf.p(resupplyAmount))
        if resupplyAmount > 0 then
            self.isResupplying = true
            if self.delayBeforeQRAresupply > 0 then
                veaf.loggers.get(veafQraManager.Id):trace("QRA will be resupplied in %s seconds", veaf.p(self.delayBeforeQRAresupply))
                mist.scheduleFunction(VeafQRA.resupply, {self, resupplyAmount}, timer.getTime()+self.delayBeforeQRAresupply)
            else
                veaf.loggers.get(veafQraManager.Id):trace("QRA is being resupplied...")
                self:resupply(resupplyAmount)
            end
        end
    end

    if self.QRAcount == 0 then
        veaf.loggers.get(veafQraManager.Id):trace("QRA is out of aircraft groups")
        if not self.silent and not self.outAnnounced then
            local msg = string.format(self.messageOut, self:getDescription())
            for coalition, _ in pairs(self.ennemyCoalitions) do
                trigger.action.outTextForCoalition(coalition, msg, 15)
            end
            self.outAnnounced = true
        end
        if self.onOut then
            self.onOut()
        end

        self:setScheduledState(veafQraManager.STATUS_OUT)
    end
end

function VeafQRA:resupply(resupplyAmount)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:resupply(%s)", veaf.p(self.name), veaf.p(resupplyAmount))

    --if the QRA can still operate, then execute the resupply, the list would need to be expanded if new scheduled status blocking operations were added
    if self.scheduled_state ~= veafQraManager.STATUS_NOAIRBASE and self.scheduled_state ~= veafQraManager.STATUS_STOP then
        if resupplyAmount and type(resupplyAmount) == 'number' and resupplyAmount > 0 then
            veaf.loggers.get(veafQraManager.Id):trace("QRA is going to be resupplied, old count is : %s", veaf.p(self.QRAcount))
            self.QRAcount = self.QRAcount + resupplyAmount
            veaf.loggers.get(veafQraManager.Id):trace("QRA was resupplied, new count is : %s", veaf.p(self.QRAcount))

            veaf.loggers.get(veafQraManager.Id):trace("QRA previously had %s aircraft groups ready for resupply (-1 for infinite)", veaf.p(self.QRAresupplyMax))
            if self.QRAresupplyMax ~= -1 then
                self.QRAresupplyMax = self.QRAresupplyMax - resupplyAmount
                if self.QRAresupplyMax < 0 then
                    self.QRAresupplyMax = 0
                end
            end
            veaf.loggers.get(veafQraManager.Id):trace("QRA now only has %s aircraft groups ready for resupply (-1 for infinite)", veaf.p(self.QRAresupplyMax))

            if self.state == veafQraManager.STATUS_OUT then
                veaf.loggers.get(veafQraManager.Id):trace("QRA now has at least one aircraft group ready for action, resuming service...")
                if not self.silent then
                    local msg = string.format(self.messageResupplied, self:getDescription())
                    for coalition, _ in pairs(self.ennemyCoalitions) do
                        trigger.action.outTextForCoalition(coalition, msg, 15)
                    end
                end
                if self.onResupplied then
                    self.onResupplied()
                end

                self.outAnnounced = false
                self.state = veafQraManager.STATUS_DEAD --QRA that have just arrived act as if the QRA had just died, they need to be rearmed
                if self.scheduled_state == veafQraManager.STATUS_OUT then self.scheduled_state = nil end --make sure you reset the scheduled state if you are within the bounds of this method
            end
        end
    else
        veaf.loggers.get(veafQraManager.Id):trace("QRA is no longer operating, resupply did not take place")
    end

    self.isResupplying = false
end

function VeafQRA:chooseGroupsToDeploy(nbUnitsInZone)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:chooseGroupsToDeploy(%s)", veaf.p(self.name), veaf.p(nbUnitsInZone))
    local biggestNumberLowerThanUnitsInZone = -1
    local groupsToDeploy = nil
    for enemyNb, groups in pairs(self.groupsToDeployByEnemyQuantity) do
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
        if groupsToChooseFrom and type(groupsToChooseFrom) == "table" and numberOfGroups and type(numberOfGroups) == "number" and bias and type(bias) == "number" then
        local result = {}
            for _ = 1, numberOfGroups do
                local group = veaf.randomlyChooseFrom(groupsToChooseFrom, bias)
                veaf.loggers.get(veafQraManager.Id):trace("group=%s", veaf.p(group))
                table.insert(result, group)
            end
            groupsToDeploy = result
        end
    end
    return groupsToDeploy
end

function VeafQRA:deploy(nbUnitsInZone)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:deploy()", veaf.p(self.name))
    veaf.loggers.get(veafQraManager.Id):trace("nbUnitsInZone=[%s]", veaf.p(nbUnitsInZone))
    if self.minimumNbEnemyPlanes ~= -1 and self.minimumNbEnemyPlanes > nbUnitsInZone then
        veaf.loggers.get(veafQraManager.Id):trace("not enough enemies in zone, min=%s", veaf.p(self.minimumNbEnemyPlanes))
        return
    end

    if not self.silent then
        local msg = string.format(self.messageDeploy, self:getDescription())
        for coalition, _ in pairs(self.ennemyCoalitions) do
            trigger.action.outTextForCoalition(coalition, msg, 15)
        end
    end
    local groupsToDeploy = self:chooseGroupsToDeploy(nbUnitsInZone)
    self.spawnedGroupsNames = {}
    if groupsToDeploy then
        local zoneCenter = {}
        if self.triggerZoneName then
            local triggerZone = veaf.getTriggerZone(self.triggerZoneName)
            zoneCenter.x = triggerZone.x
            zoneCenter.z = triggerZone.y
            zoneCenter.y = 0
        elseif self.zoneCenter then
            zoneCenter = self.zoneCenter
        end
        for _, groupNameOrCommand in pairs(groupsToDeploy) do
            -- check if this is a DCS group or a VEAF command
            if veaf.startsWith(groupNameOrCommand, "[") or veaf.startsWith(groupNameOrCommand, "-") then
                -- this is a command
                local command = groupNameOrCommand
                local latDelta = self.respawnDefaultOffset.latDelta
                local lonDelta = self.respawnDefaultOffset.lonDelta
                if veaf.startsWith(groupNameOrCommand, "[") then
                    -- extract relative coordinates and the actual command
                    local coords
                    coords, command = groupNameOrCommand:match("%[(.*)%](.*)")
                    veaf.loggers.get(veafQraManager.Id):trace("coords=%s", veaf.p(coords))
                    veaf.loggers.get(veafQraManager.Id):trace("command=%s", veaf.p(command))
                    if coords then
                        latDelta, lonDelta = coords:match("([%+-%d]+),%s*([%+-%d]+)")
                    end
                end
                veaf.loggers.get(veafQraManager.Id):debug("running command [%s]", veaf.p(command))
                veaf.loggers.get(veafQraManager.Id):trace("latDelta = [%s]", veaf.p(latDelta))
                veaf.loggers.get(veafQraManager.Id):trace("lonDelta = [%s]", veaf.p(lonDelta))
                local position = {x = zoneCenter.x - lonDelta, y = zoneCenter.y, z = zoneCenter.z + latDelta}
                local randomPosition = mist.getRandPointInCircle(position, self.respawnRadius)
                local spawnedGroupsNames = {}
                veafInterpreter.execute(command, randomPosition, self.coalition, nil, spawnedGroupsNames)
                for _, newGroupName in pairs(spawnedGroupsNames) do
                    table.insert(self.spawnedGroupsNames, newGroupName)
                end
            else
                -- this is a DCS group
                local groupName = groupNameOrCommand
                veaf.loggers.get(veafQraManager.Id):debug("spawning group [%s]", veaf.p(groupName))
                local group = Group.getByName(groupName)
                if not group then
                    veaf.loggers.get(veafQraManager.Id):error("group [%s] does not exist in the mission!", veaf.p(groupName))
                else
                    veaf.loggers.get(veafQraManager.Id):debug("group=%s", veaf.p(group))
                    veaf.loggers.get(veafQraManager.Id):debug("group:getUnits()=%s", veaf.p(group:getUnits()))
                    local spawnSpot = {x = zoneCenter.x - self.respawnDefaultOffset.lonDelta, y = zoneCenter.y, z = zoneCenter.z + self.respawnDefaultOffset.latDelta}
                    -- Try and set the spawn spot at the place the group has been set in the Mission Editor.
                    -- Unfortunately this is sometimes not possible because DCS is not returning the group units for some reason.
                    -- When this happens we'll default to the default spawn offset (same as spawning with VEAF commands)
                    if not group:getUnit(1) then
                        veaf.loggers.get(veafQraManager.Id):warn("group [%s] does not have any unit!", veaf.p(groupName))
                    else
                        spawnSpot =  group:getUnit(1):getPoint()
                    end
                    local vars = {}
                    vars.point = mist.getRandPointInCircle(spawnSpot, self.respawnRadius)
                    vars.point.z = vars.point.y
                    vars.point.y = spawnSpot.y
                    vars.gpName = groupName
                    vars.action = 'clone'
                    vars.route = mist.getGroupRoute(groupName, 'task')
                    local newGroup = mist.teleportToPoint(vars) -- respawn with radius
                    if newGroup then
                        table.insert(self.spawnedGroupsNames, newGroup.name)
                    end
                end
            end
        end
        veaf.loggers.get(veafQraManager.Id):trace("self.spawnedGroups=%s", veaf.p(self.spawnedGroupsNames))
        self.state = veafQraManager.STATUS_ACTIVE
    end
    if self.onDeploy then
        self.onDeploy(nbUnitsInZone)
    end
end

function VeafQRA:destroyed()
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:destroyed()", veaf.p(self.name))
    if not self.silent then
        local msg = string.format(self.messageDestroyed, self:getDescription())
        for coalition, _ in pairs(self.ennemyCoalitions) do
            trigger.action.outTextForCoalition(coalition, msg, 15)
        end
    end
    if self.onDestroyed then
        self.onDestroyed()
    end
    self.state = veafQraManager.STATUS_DEAD

    if self.QRAcount > 0 then
        veaf.loggers.get(veafQraManager.Id):trace("QRA will now see one of it's aicraft groups removed")
        self.QRAcount = self.QRAcount - 1
    end
end

function VeafQRA:rearm(silent)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:rearm()", veaf.p(self.name))
    if not self.silent and not silent then
        local msg = string.format(self.messageReady, self:getDescription())
        for coalition, _ in pairs(self.ennemyCoalitions) do
            trigger.action.outTextForCoalition(coalition, msg, 15)
        end
    end
    if self.spawnedGroupsNames then
        for _, groupName in pairs(self.spawnedGroupsNames) do
            local group = Group.getByName(groupName)
            if group then
                group:destroy()
            end
        end
    end
    if self.onReady then
        self.onReady()
    end
    self.state = veafQraManager.STATUS_READY
end

function VeafQRA:start()
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:start()", veaf.p(self.name))
    self.scheduled_state = nil --make sure you reset the scheduled state if you are within the bounds of this method
    self:rearm()
    self:check()

    -- draw the zone
    if self.drawZone then
        if self.triggerZoneName then
            self.zoneDrawing = mist.marker.drawZone(self.triggerZoneName, {message=self:getDescription(), readOnly=true})
        else
            self.zoneDrawing = VeafCircleOnMap:new()
            :setName(self:getName())
            :setCoalition(self:getEnnemyCoalition())
            :setCenter(self.zoneCenter)
            :setRadius(self.zoneRadius)
            :setLineType("dashed")
            :setColor("white")
            :setFillColor("transparent")
            :draw()
        end
    end

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

function VeafQRA:stop(silent)
    veaf.loggers.get(veafQraManager.Id):debug("VeafQRA[%s]:stop()", veaf.p(self.name))
    self:setScheduledState(veafQraManager.STATUS_STOP)

    -- just in case, despawn the spawned groups
    if self.spawnedGroupsNames then
        for _, groupName in pairs(self.spawnedGroupsNames) do
            local group = Group.getByName(groupName)
            if group then group:destroy() end
        end
    end

    -- erase the zone
    if self.zoneDrawing then
        if self.triggerZoneName then
            mist.marker.remove(self.zoneDrawing.markId)
        else
            self.zoneDrawing:erase()
        end
        self.zoneDrawing = nil
    end

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

function veafQraManager.add(aQraObject, aName)
  local name = aName or aQraObject:getName()
  veafQraManager.qras[name] = aQraObject
  return aQraObject
end

function veafQraManager.get(aNameString)
  return veafQraManager.qras[aNameString]
end

veaf.loggers.get(veafQraManager.Id):info(string.format("Loading version %s", veafQraManager.Version))