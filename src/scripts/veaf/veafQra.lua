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

veafQra = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafQra.Id = "QRA"

--- Version.
veafQra.Version = "1.0.1"

-- trace level, specific to this module
--veafQra.LogLevel = "trace"

veaf.loggers.new(veafQra.Id, veafQra.LogLevel)

VeafQRA.STATUS_WILLREARM = 0
VeafQRA.STATUS_READY = 1
VeafQRA.STATUS_READY_WAITINGFORMORE = 1.5
VeafQRA.STATUS_ACTIVE = 2
VeafQRA.STATUS_DEAD = 3

--scheduled states
VeafQRA.STATUS_OUT = 4
VeafQRA.STATUS_NOAIRBASE = 5
VeafQRA.STATUS_STOP = 6

VeafQRA.WATCHDOG_DELAY = 5

VeafQRA.DEFAULT_airbaseMinLifePercent = 0.9

VeafQRA.AllSilence = false --value to set all spawned QRAs to silent if true. By default it's false but this value can be set in the missionConfig
VeafQRA.DEFAULT_MESSAGE_START = "%s is online"
VeafQRA.DEFAULT_MESSAGE_DEPLOY = "%s is deploying"
VeafQRA.DEFAULT_MESSAGE_DESTROYED = "%s has been destroyed"
VeafQRA.DEFAULT_MESSAGE_READY = "%s is ready"
VeafQRA.DEFAULT_MESSAGE_OUT = "%s is out of aircrafts"
VeafQRA.DEFAULT_MESSAGE_RESUPPLIED = "%s has been resupplied"
VeafQRA.DEFAULT_MESSAGE_AIRBASE_DOWN = "%s lost it's airbase"
VeafQRA.DEFAULT_MESSAGE_AIRBASE_UP = "%s now has an airbase"
VeafQRA.DEFAULT_MESSAGE_STOP = "%s is offline"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafQra.qras = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafQRA class methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafQRA =
{
    -- technical name (QRA instance name)
    name = nil,
    -- trigger zone name (if set, we'll use a DCS trigger zone)
    triggerZoneCenter = nil,
    -- center (point in the center of the circle, when not using a DCS trigger zone)
    zoneCenter = nil,
    -- radius (size of the circle, when not using a zone)
    zoneRadius = nil,
    -- description for the briefing
    description = nil,
    -- aircraft groups forming the QRA
    groups = nil,
    -- aircraft groups forming the QRA, in a table by enemy quantity (i.e. if this number of enemies are in the zone, spawn these groups)
    groupsToDeployByEnemyQuantity = nil,
    -- coalition for the QRA
    coalition = nil,
    -- coalitions the QRA is defending against
    ennemyCoalitions = nil,
    -- message when the QRA is started
    messageStart = nil,
    -- event when the QRA is started
    onStart = nil,
    -- message when the QRA is triggered
    messageDeploy = nil,
    -- event when the QRA is triggered
    onDeploy = nil,
    -- message when the QRA is destroyed
    messageDestroyed = nil,
    -- event when the QRA is destroyed
    onDestroyed = nil,
    -- message when the QRA is ready
    messageReady = nil,
    -- event when the QRA is ready
    onReady = nil,
    -- message when the QRA is out of aircrafts
    messageOut = nil,
    -- event when the QRA is out of aircrafts
    onOut = nil,
    -- message when the QRA has been resupplied and will start operations against
    messageResupplied = nil,
    -- event when the QRA has been resupplied and will start operations against
    onResupplied = nil,
    -- message when the QRA has lost the airbase it operates from
    messageAirbaseDown = nil,
    -- event when the QRA has lost the airbase it operates from
    onAirbaseDown = nil,
    -- message when the QRA has retrieved the airbase it operates from and will start operations again
    messageAirbaseUp = nil,
    -- event when the QRA has retrieved the airbase it operates from and will start operations again
    onAirbaseUp = nil,
    -- message when the QRA is stopped
    messageStop = nil,
    -- event when the QRA is stopped
    onStop = nil,
	    -- silent means no message is emitted
    silent = nil,
    -- radius of the defenders groups spawn
    respawnRadius = nil,
    -- reacts when helicopters enter the zone
    reactOnHelicopters = nil,
    -- delay before activating
    delayBeforeActivating = -1,
    -- delay before rearming
    delayBeforeRearming = -1,
    -- the enemy does not have to leave the zone before the QRA is rearmed
    noNeedToLeaveZoneBeforeRearming = false,
    -- reset the QRA immediately if all the enemy units leave the zone
    resetWhenLeavingZone = false,
    -- maximum number of QRA ready for action at once, -1 indicates infinite
    QRAmaxCount = -1,
    -- number of groups of aircrafts that can be spawned for this QRA in total, -1 indicates infinite.
    QRAcount = -1,
    -- delay in minutes before the QRA counter is increased by one, simulating some sort of logistic chain of aircrafts.
    delayBeforeQRAresupply = 0,
    -- maximum number of resupplies at a given time, simulating some sort of warehousing, -1 indicates infinite. Is decremented every time a resupply happens. 0 indicates no resupply.
    QRAresupplyMax = -1,
    -- minimum QRAcount that will trigger a resupply, -1 indicates as soon as an aircraft is lost
    QRAminCountforResupply = -1,
    -- how many aircraft groups are resupplied at once   
    resupplyAmount = 1,
    -- indicator to know if the QRA is being resupplied or not
    isResupplying = false,
    -- name of the airport to which the QRA is linked, QRAs will be deployed only if this is set and the airport is captured by the QRA's coalition or if this is not set
    airportLink = nil,
    -- minimum linked airbase life percentage (from 0 to 1) for the QRA to have it's airbase available
    airportMinLifePercent = nil,
    -- boolean to know if the status OUT was announced or not
    outAnnounced = false,
    -- boolean to know if the status NOAIRBASE was announced or not
    noAB_announced = false,
    -- minimum number of enemies in the zone to trigger deployment; updated automatically by setGroupsToDeployByEnemyQuantity
    minimumNbEnemyPlanes = -1,
    -- planes in the zone will only be detected below this altitude (in meters)
    minimumAltitude = 999999
    -- planes in the zone will only be detected above this altitude (in meters)
    maximumAltitude = 0,
    timer = nil,
    state = nil,
    scheduled_state = nil,
    _enemyHumanUnits = nil
}
VeafQRA.__index = VeafQRA

function VeafQRA.ToggleAllSilence(state)
    if state then 
        VeafQRA.AllSilence = true
    else
        VeafQRA.AllSilence = false
    end
end

function VeafQRA:new()
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA:new()"))
    local self = setmetatable({}, VeafQRA)
    self.name = nil
    self.zoneCenter = nil
    self.zoneRadius = nil
    self.description = nil
    self.groupsToDeployByEnemyQuantity = {}
    self.spawnedGroups = {}
    self.coalition = nil
    self.ennemyCoalitions = {}
    self.messageStart = VeafQRA.DEFAULT_MESSAGE_START
    self.messageDeploy = VeafQRA.DEFAULT_MESSAGE_DEPLOY
    self.messageDestroyed = VeafQRA.DEFAULT_MESSAGE_DESTROYED
    self.messageReady = VeafQRA.DEFAULT_MESSAGE_READY
    self.messageOut = VeafQRA.DEFAULT_MESSAGE_OUT
    self.messageResupplied = VeafQRA.DEFAULT_MESSAGE_RESUPPLIED
    self.messageAirbaseDown = VeafQRA.DEFAULT_MESSAGE_AIRBASE_DOWN
    self.messageAirbaseUp = VeafQRA.DEFAULT_MESSAGE_AIRBASE_UP
    self.messageStop = VeafQRA.DEFAULT_MESSAGE_STOP
    self.silent = VeafQRA.AllSilence
    self.respawnRadius = 250
    self.reactOnHelicopters = false
    self.delayBeforeRearming = -1
    self.delayBeforeActivating = -1
    self.noNeedToLeaveZoneBeforeRearming = false
    self.resetWhenLeavingZone = false
    self.QRAmaxCount = -1
    self.QRAcount = -1
    self.delayBeforeQRAresupply = 0
    self.QRAresupplyMax = -1
    self.QRAminCountforResupply = -1
    self.resupplyAmount = 1
    self.isResupplying = false
    self.airportLink = nil
    self.airportMinLifePercent = VeafQRA.DEFAULT_airbaseMinLifePercent
    self.outAnnounced = false
    self.noAB_announced = false
    self.minimumNbEnemyPlanes = -1
    
    self._enemyHumanUnits = nil
    self.timeSinceReady = -1
    self.state = nil
    self.scheduled_state = nil
    return self
end

function VeafQRA:setName(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[]:setName(%s)", veaf.p(value)))
    self.name = value
    return veafQra.add(self) -- add the QRA to the QRA list as soon as a name is available to index it
end

function VeafQRA:setTriggerZone(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setTriggerZone(%s)", veaf.p(self.name), veaf.p(value)))
    self.triggerZone = value
    local triggerZone = veaf.getTriggerZone(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("triggerZone=%s", veaf.p(triggerZone)))
    return self
end

function VeafQRA:setZoneCenter(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setZoneCenter(%s)", veaf.p(self.name), veaf.p(value)))
    self.zoneCenter = value
    return self
end    

function VeafQRA:setZoneCenterFromCoordinates(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setZoneCenterFromCoordinates(%s)", veaf.p(self.name), veaf.p(value)))
    local _lat, _lon = veaf.computeLLFromString(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("_lat=%s)", veaf.p(_lat)))
    veaf.loggers.get(VeafQRA.Id):trace(string.format("_lon=%s)", veaf.p(_lon)))
    local vec3 = coord.LLtoLO(_lat, _lon)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("vec3=%s)", veaf.p(vec3)))
    return self:setZoneCenter(vec3)
end

function VeafQRA:setZoneRadius(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setZoneRadius(%s)", veaf.p(self.name), veaf.p(value)))
    self.zoneRadius = value
    return self
end

function VeafQRA:setDescription(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setDescription(%s)", veaf.p(self.name), veaf.p(value)))
    self.description = value
    return veafQra.add(self) -- add the QRA to the QRA list as soon as a name is available to index it
end

function VeafQRA:getDescription()
    return self.description or self.name
end

function VeafQRA:getName()
  return self.name or self.description
end

function VeafQRA:addGroup(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:addGroup(%s)", veaf.p(self.name), veaf.p(value)))
    if not self.groupsToDeployByEnemyQuantity[1] then
        self.groupsToDeployByEnemyQuantity[1] = {}
    end
    table.insert(self.groupsToDeployByEnemyQuantity[1], value)
    return self
end

function VeafQRA:addRandomGroup(groups, number, bias)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:addRandomGroup(%s, %s, %s)", veaf.p(self.name), veaf.p(groups), veaf.p(number), veaf.p(bias)))
    return self:addGroup({groups, number or 1, bias or 0})
end

function VeafQRA:setGroupsToDeployByEnemyQuantity(enemyNb, groupsToDeploy)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setGroupsToDeployByEnemyQuantity(%s) -> %s", veaf.p(self.name), veaf.p(enemyNb), veaf.p(groupsToDeploy)))
    self.groupsToDeployByEnemyQuantity[enemyNb] = groupsToDeploy
    if self.minimumNbEnemyPlanes == -1 or self.minimumNbEnemyPlanes > enemyNb then
        self.minimumNbEnemyPlanes = enemyNb
        veaf.loggers.get(VeafQRA.Id):trace(string.format("setting minimumNbEnemyPlanes to %s", veaf.p(self.minimumNbEnemyPlanes)))
    end
    return self
end

function VeafQRA:setRandomGroupsToDeployByEnemyQuantity(enemyNb, groups, number, bias)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setRandomGroupsToDeployByEnemyQuantity(%s, %s, %s, %s)", veaf.p(self.name), veaf.p(enemyNb), veaf.p(groups), veaf.p(number), veaf.p(bias)))
    return self:setGroupsToDeployByEnemyQuantity(enemyNb, {groups, number or 1, bias or 0})
end

function VeafQRA:setCoalition(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setCoalition(%s)", veaf.p(self.name), veaf.p(value)))
    self.coalition = value
    return self
end

function VeafQRA:addEnnemyCoalition(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:addEnnemyCoalition(%s)", veaf.p(self.name), veaf.p(value)))
    self.ennemyCoalitions[value] = value
    return self
end

function VeafQRA:setMessageStart(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageStart(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageStart = value
    return self
end

function VeafQRA:setOnStart(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setOnStart()", veaf.p(self.name)))
    self.onStart = value
    return self
end

function VeafQRA:setMessageDeploy(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageDeploy(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageDeploy = value
    return self
end

function VeafQRA:setOnDeploy(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setOnDeploy()", veaf.p(self.name)))
    self.onDeploy = value
    return self
end

function VeafQRA:setMessageDestroyed(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageDestroyed(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageDestroyed = value
    return self
end

function VeafQRA:setOnDestroyed(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setOnDestroyed()", veaf.p(self.name)))
    self.onDestroyed = value
    return self
end

function VeafQRA:setMessageReady(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageReady(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageReady = value
    return self
end

function VeafQRA:setOnReady(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setOnReady()", veaf.p(self.name)))
    self.onReady = value
    return self
end

function VeafQRA:setMessageOut(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageOut(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageOut = value
    return self
end

function VeafQRA:setOnOut(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setOnOut()", veaf.p(self.name)))
    self.onOut = value
    return self
end

function VeafQRA:setMessageResupplied(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageResupplied(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageResupplied = value
    return self
end

function VeafQRA:setOnResupplied(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setOnResupplied()", veaf.p(self.name)))
    self.onResupplied = value
    return self
end

function VeafQRA:setMessageAirbaseDown(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageAirbaseDown(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageAirbaseDown = value
    return self
end

function VeafQRA:setOnAirbaseDown(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setOnAirbaseDown()", veaf.p(self.name)))
    self.onAirbaseDown = value
    return self
end

function VeafQRA:setMessageAirbaseUp(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageAirbaseUp(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageAirbaseUp = value
    return self
end

function VeafQRA:setOnAirbaseUp(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setOnAirbaseUp()", veaf.p(self.name)))
    self.onAirbaseUp = value
    return self
end

function VeafQRA:setMessageStop(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageStop(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageStop = value
    return self
end

function VeafQRA:setOnStop(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setOnStop()", veaf.p(self.name)))
    self.onStop = value
    return self
end

function VeafQRA:setSilent(pSilent)
    
    local vSilent = pSilent
    if vSilent then 
        vSilent = true
    else
        vSilent = false
    end

    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setSilent(%s)", veaf.p(self.name), veaf.p(vSilent)))
    self.silent = pSilent
    return self
end

--TODO, warehousing for each group within a QRA and not just the whole QRA
function VeafQRA:setQRAcount(count)

    if count and type(count) == 'number' and count >= -1 then 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setQRAcount(%s)", veaf.p(self.name), veaf.p(count)))
        self.QRAcount = count
    end
    return self
end

function VeafQRA:setQRAmaxCount(maxCount)

    if maxCount and type(maxCount) == 'number' and maxCount >= -1 then 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setQRAmaxCount(%s)", veaf.p(self.name), veaf.p(maxCount)))
        self.QRAmaxCount = maxCount
    end
    return self
end

function VeafQRA:setQRAresupplyDelay(resupplyDelay)

    if resupplyDelay and type(resupplyDelay) == 'number' and resupplyDelay >= 0 then 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setQRAresupplyDelay(%s)", veaf.p(self.name), veaf.p(resupplyDelay)))
        self.delayBeforeQRAresupply = resupplyDelay
    end
    return self
end

function VeafQRA:setQRAmaxResupplyCount(maxResupplyCount)

    if maxResupplyCount and type(maxResupplyCount) == 'number' and maxResupplyCount >= -1 then 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setQRAmaxResupplyCount(%s)", veaf.p(self.name), veaf.p(maxResupplyCount)))
        self.QRAresupplyMax = maxResupplyCount
    end
    return self
end

function VeafQRA:setQRAminCountforResupply(minCountforResupply)

    if minCountforResupply and type(minCountforResupply) == 'number' and minCountforResupply >= -1 and minCountforResupply ~= 0 then 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setQRAminCountforResupply(%s)", veaf.p(self.name), veaf.p(minCountforResupply)))
        self.QRAminCountforResupply = minCountforResupply
    end
    return self
end

function VeafQRA:setResupplyAmount(resupplyAmount)

    if resupplyAmount and type(resupplyAmount) == 'number' and resupplyAmount >= 1 then 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setResupplyAmount(%s)", veaf.p(self.name), veaf.p(resupplyAmount)))
        self.resupplyAmount = resupplyAmount
    end
    return self
end

function VeafQRA:setAirportLink(airport_name)

    if airport_name and type(airport_name) == 'string' and Airbase.getByName(airport_name) then 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setAirportLink(%s)", veaf.p(self.name), veaf.p(airport_name)))
        self.airportLink = airport_name
    end
    return self
end

function VeafQRA:setAirportMinLifePercent(value)

    if value and value >= 0 and value <= 1 then 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setAirportMinLifePercent(%s)", veaf.p(self.name), veaf.p(value)))
        self.airportMinLifePercent = value
    end
    return self
end

function VeafQRA:setReactOnHelicopters()
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setReactOnHelicopters()", veaf.p(self.name)))
    self.reactOnHelicopters = true
    return self
end

function VeafQRA:setRespawnRadius(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setRespawnRadius(%s)", veaf.p(self.name), veaf.p(value)))
    self.respawnRadius = value
    if self.respawnRadius < 250 then self.respawnRadius = 250 end
    return self
end

function VeafQRA:setDelayBeforeRearming(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setDelayBeforeRearming(%s)", veaf.p(self.name), veaf.p(value)))
    self.delayBeforeRearming = value
    return self
end

function VeafQRA:setNoNeedToLeaveZoneBeforeRearming()
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setNoNeedToLeaveZoneBeforeRearming()", veaf.p(self.name)))
    self.noNeedToLeaveZoneBeforeRearming = true
    return self
end

function VeafQRA:setResetWhenLeavingZone()
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setResetWhenLeavingZone()", veaf.p(self.name)))
    self.resetWhenLeavingZone = true
    return self
end

function VeafQRA:setDelayBeforeActivating(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setDelayBeforeActivating(%s)", veaf.p(self.name), veaf.p(value)))
    self.delayBeforeActivating = value
    return self
end

function VeafQRA:setMinimumAltitude(value)
  veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMinimumAltitude(%s)", veaf.p(self.name), veaf.p(value)))
  self.minimumAltitude = value
  return self
end

function VeafQRA:getMinimumAltitude()
  veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:getMinimumAltitude()", veaf.p(self.name)))
  return self.minimumAltitude
end

function VeafQRA:setMaximumAltitude(value)
  veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMaximumAltitude(%s)", veaf.p(self.name), veaf.p(value)))
  self.maximumAltitude = value
  return self
end

function VeafQRA:getMaximumAltitude()
  veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:getMaximumAltitude()", veaf.p(self.name)))
  return self.maximumAltitude
end

function VeafQRA:_getEnemyHumanUnits()
    --veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:_getEnemyHumanUnits() - computing", veaf.p(self.name)))
    if not self._enemyHumanUnits then
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:_getEnemyHumanUnits() - computing", veaf.p(self.name)))
        self._enemyHumanUnits = {}
        veaf.loggers.get(VeafQRA.Id):trace(string.format("ennemyCoalitions[]=%s", veaf.p(self.ennemyCoalitions)))
        for _, unit in pairs(mist.DBs.humansByName) do
            --veaf.loggers.get(VeafQRA.Id):trace("unit=%s", unit)
            veaf.loggers.get(VeafQRA.Id):trace("unit.unitName=%s", unit.unitName)
            veaf.loggers.get(VeafQRA.Id):trace("unit.groupName=%s", unit.groupName)
            veaf.loggers.get(VeafQRA.Id):trace(string.format("unit.coalition=%s", veaf.p(unit.coalition)))
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
                    veaf.loggers.get(VeafQRA.Id):trace("unit.category=%s", unit.category)
                    if     (unit.category == "plane")
                        or (unit.category == "helicopter" and self.reactOnHelicopters)
                    then
                        veaf.loggers.get(VeafQRA.Id):trace("adding unit to enemy human units for QRA")
                        table.insert(self._enemyHumanUnits, unit.unitName)
                    end
                end
            end
        end
    end
    return self._enemyHumanUnits
end

function VeafQRA:check()
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:check()", veaf.p(self.name)))
    veaf.loggers.get(VeafQRA.Id):trace(string.format("self.state=%s", veaf.p(self.state)))
    veaf.loggers.get(VeafQRA.Id):trace(string.format("timer.getTime()=%s", veaf.p(timer.getTime())))

    --scheduled state application is attempted regardless of airportlink checks etc. to take into account user requested states which go through scheduled_states as well
    --Stop scheduled is checked before even running the check function as it has the highest priority
    self:applyScheduledState()

    if self.state ~= VeafQRA.STATUS_STOP then

        --if the QRA is linked to an airbase. Airport is checked before even trying to deploy a group and check warehousing which has a lower priority
        if self.airportLink then
            veaf.loggers.get(VeafQRA.Id):trace(string.format("Checking Airport link : %s", veaf.p(self.airportLink)))
            self:checkAirport()
            self:applyScheduledState()
        end

        if self.state ~= VeafQRA.STATUS_NOAIRBASE then
 
            --if warehousing is activated. Warehousing is checked before even trying to deploy a group
            if self.QRAcount ~= -1 then
                veaf.loggers.get(VeafQRA.Id):trace(string.format("Checking Warehousing..."))
                veaf.loggers.get(VeafQRA.Id):trace(string.format("QRACount : %s", veaf.p(self.QRAcount)))
                self:checkWarehousing()
                self:applyScheduledState()
            end

            if self.state ~= VeafQRA.STATUS_OUT then
                local unitNames = self:_getEnemyHumanUnits()
                veaf.loggers.get(VeafQRA.Id):trace(string.format("unitNames=%s", veaf.p(unitNames)))
                local unitsInZone = nil
                local triggerZone = veaf.getTriggerZone(self.triggerZone)
                if triggerZone then
                    veaf.loggers.get(VeafQRA.Id):trace(string.format("triggerZone=%s", veaf.p(triggerZone)))
                    if triggerZone.type == 0 then -- circular
                        unitsInZone = mist.getUnitsInZones(unitNames, {self.triggerZone})
                    elseif triggerZone.type == 2 then -- quad point
                        veaf.loggers.get(VeafQRA.Id):trace(string.format("checking in polygon %s", veaf.p(triggerZone.verticies)))
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
                    veaf.loggers.get(VeafQRA.Id):debug(string.format("check the unit altitude against the ceiling and floor ; alt=%s", veaf.p(alt)))
                    if alt < self:getMinimumAltitude() or alt > self:getMaximumAltitude() then
                      nbUnitsInZone = nbUnitsInZone + 1
                    end
                end
                veaf.loggers.get(VeafQRA.Id):trace(string.format("unitsInZone=%s", veaf.p(unitsInZone)))
                veaf.loggers.get(VeafQRA.Id):trace(string.format("#unitsInZone=%s", veaf.p(#unitsInZone)))
                veaf.loggers.get(VeafQRA.Id):trace(string.format("nbUnitsInZone=%s", veaf.p(nbUnitsInZone)))
                veaf.loggers.get(VeafQRA.Id):trace(string.format("state=%s", veaf.p(self.state)))
                if (self.state == VeafQRA.STATUS_READY) and (unitsInZone and nbUnitsInZone > 0) then
                    veaf.loggers.get(VeafQRA.Id):debug(string.format("self.state set to VeafQRA.STATUS_READY_WAITINGFORMORE at timer.getTime()=%s", veaf.p(timer.getTime())))
                    self.state = VeafQRA.STATUS_READY_WAITINGFORMORE
                    self.timeSinceReady = timer.getTime()
                elseif (self.state == VeafQRA.STATUS_READY_WAITINGFORMORE) and (unitsInZone and nbUnitsInZone > 0) and (timer.getTime() - self.timeSinceReady > self.delayBeforeActivating) then
                    -- trigger the QRA
                    self:deploy(nbUnitsInZone)
                    self.timeSinceReady = -1
                elseif (self.state == VeafQRA.STATUS_DEAD) and (self.noNeedToLeaveZoneBeforeRearming or (not unitsInZone or nbUnitsInZone == 0)) then
                    -- rearm the QRA after a delay (if set)
                    if self.delayBeforeRearming > 0 then
                        mist.scheduleFunction(VeafQRA.rearm, {self}, timer.getTime()+self.delayBeforeRearming)
                        self.state = VeafQRA.STATUS_WILLREARM
                    else
                        self:rearm()
                    end
                elseif (self.state == VeafQRA.STATUS_ACTIVE) then
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
                    elseif (self.resetWhenLeavingZone and nbUnitsInZone == 0) or inAir == false then 
                        -- QRA reset
                        self:rearm()
                    end
                end
            end
        end
    
        mist.scheduleFunction(VeafQRA.check, {self}, timer.getTime() + VeafQRA.WATCHDOG_DELAY) 
    end
end

function VeafQRA:setScheduledState(scheduledState)
    --priority level 1
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setScheduledState(%s)", veaf.p(self.name), veaf.p(scheduledState)))
    if scheduledState == VeafQRA.STATUS_STOP then
        self.scheduled_state = VeafQRA.STATUS_STOP
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA STOP scheduled"))
    --priority level 2
    elseif scheduledState == VeafQRA.STATUS_NOAIRBASE and self.scheduled_state ~= VeafQRA.STATUS_STOP then
        self.scheduled_state = VeafQRA.STATUS_NOAIRBASE
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA NOAIRBASE scheduled"))
    --priority level 3
    elseif scheduledState == VeafQRA.STATUS_OUT and self.scheduled_state ~= VeafQRA.STATUS_STOP and self.scheduled_state ~= VeafQRA.STATUS_NOAIRBASE then
        self.scheduled_state = VeafQRA.STATUS_OUT
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA OUT scheduled"))
    end
    return self
end

function VeafQRA:applyScheduledState()
    if self.scheduled_state and self.state ~= VeafQRA.STATUS_ACTIVE then
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA taking scheduled status : %s", veaf.p(self.scheduled_state)))
        self.state = self.scheduled_state
    end
end

function VeafQRA:checkAirport()
    local QRA_airportObject = veaf.getAirbaseForCoalition(self.airportLink, self.coalition)
    local airport_life_percent = nil
    if QRA_airportObject then
        airport_life_percent = veaf.getAirbaseLife(self.airportLink, true)
    end

    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s] is linked to airbase %s", veaf.p(self.name), veaf.p(self.airportLink)))

    if not QRA_airportObject or airport_life_percent < self.airportMinLifePercent then
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA lost it's airbase"))
        self:setScheduledState(VeafQRA.STATUS_NOAIRBASE)
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
        
    elseif self.state == VeafQRA.STATUS_NOAIRBASE then
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA has it's airbase %s", veaf.p(QRA_airportObject:getName())))
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
        self.state = VeafQRA.STATUS_DEAD --QRA that have just been recommisionned act as if they were dead since they need to be rearmed after a delay
        if self.scheduled_state == VeafQRA.STATUS_NOAIRBASE then self.scheduled_state = nil end --make sure you reset the scheduled state if you are within the bounds of this method
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
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s] resupply state is %s", veaf.p(self.name), veaf.p(self.isResupplying)))
    
    --if a resupply is not already on the way and if there are aircrafts in stock and if the available aircraft count is below the threshold or if an aircraft was just lost and the resupply mode indicates to resupply whenever an aircraft is lost
    if not self.isResupplying and self.QRAresupplyMax ~= 0 and (self.QRAcount < self.QRAminCountforResupply or (self.QRAcount < self.QRAmaxCount or (self.QRAmaxCount == -1 and self.state == VeafQRA.STATUS_DEAD)) and self.QRAminCountforResupply == -1) then
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA has %s/%s aircraft groups available", veaf.p(self.QRAcount), veaf.p(self.QRAmaxCount)))
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA has %s aircraft groups ready for resupply (-1 for infinite)", veaf.p(self.QRAresupplyMax)))   
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA resupply asks for %s aircraft groups", veaf.p(self.resupplyAmount)))
        local resupplyAmount = self.resupplyAmount
        --take into account the maximum number of QRA groups as to not oversupply it
        if self.QRAmaxCount ~= -1 and resupplyAmount > self.QRAmaxCount - self.QRAcount then
            resupplyAmount = self.QRAmaxCount - self.QRAcount
            veaf.loggers.get(VeafQRA.Id):trace(string.format("There are only %s available aircraft group slots for this QRA", veaf.p(self.QRAmaxCount - self.QRAcount)))
        end

        --take into account the maximum number of QRA groups that can be supplied by the stock
        if self.QRAresupplyMax ~= -1 and resupplyAmount > self.QRAresupplyMax then
            resupplyAmount = self.QRAresupplyMax
            veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA can only be resupplied by %s aircraft groups", veaf.p(self.QRAresupplyMax)))
        end
        
        veaf.loggers.get(VeafQRA.Id):trace(string.format("%s aircraft groups will be handled for resupply", veaf.p(resupplyAmount)))
        if resupplyAmount > 0 then
            self.isResupplying = true
            if self.delayBeforeQRAresupply > 0 then
                veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA will be resupplied in %s seconds", veaf.p(self.delayBeforeQRAresupply)))
                mist.scheduleFunction(VeafQRA.resupply, {self, resupplyAmount}, timer.getTime()+self.delayBeforeQRAresupply)
            else
                veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA is being resupplied..."))
                self:resupply(resupplyAmount)
            end
        end
    end

    if self.QRAcount == 0 then
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA is out of aircraft groups"))
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

        self:setScheduledState(VeafQRA.STATUS_OUT)
    end
end

function VeafQRA:resupply(resupplyAmount)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:resupply(%s)", veaf.p(self.name), veaf.p(resupplyAmount)))

    --if the QRA can still operate, then execute the resupply, the list would need to be expanded if new scheduled status blocking operations were added
    if self.scheduled_state ~= VeafQRA.STATUS_NOAIRBASE and self.scheduled_state ~= VeafQRA.STATUS_STOP then
        if resupplyAmount and type(resupplyAmount) == 'number' and resupplyAmount > 0 then
            veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA is going to be resupplied, old count is : %s", veaf.p(self.QRAcount)))
            self.QRAcount = self.QRAcount + resupplyAmount
            veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA was resupplied, new count is : %s", veaf.p(self.QRAcount)))
            
            veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA previously had %s aircraft groups ready for resupply (-1 for infinite)", veaf.p(self.QRAresupplyMax)))
            if self.QRAresupplyMax ~= -1 then
                self.QRAresupplyMax = self.QRAresupplyMax - resupplyAmount
                if self.QRAresupplyMax < 0 then
                    self.QRAresupplyMax = 0
                end
            end
            veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA now only has %s aircraft groups ready for resupply (-1 for infinite)", veaf.p(self.QRAresupplyMax)))

            if self.state == VeafQRA.STATUS_OUT then
                veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA now has at least one aircraft group ready for action, resuming service..."))
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
                self.state = VeafQRA.STATUS_DEAD --QRA that have just arrived act as if the QRA had just died, they need to be rearmed
                if self.scheduled_state == VeafQRA.STATUS_OUT then self.scheduled_state = nil end --make sure you reset the scheduled state if you are within the bounds of this method
            end
        end
    else
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA is no longer operating, resupply did not take place"))
    end

    self.isResupplying = false
end

function VeafQRA:chooseGroupsToDeploy(nbUnitsInZone)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:chooseGroupsToDeploy(%s)", veaf.p(self.name), veaf.p(nbUnitsInZone)))
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
        veaf.loggers.get(VeafQRA.Id):trace(string.format("groupsToChooseFrom=%s", veaf.p(groupsToChooseFrom)))
        veaf.loggers.get(VeafQRA.Id):trace(string.format("numberOfGroups=%s", veaf.p(numberOfGroups)))
        veaf.loggers.get(VeafQRA.Id):trace(string.format("bias=%s", veaf.p(bias)))
        if groupsToChooseFrom and type(groupsToChooseFrom) == "table" and numberOfGroups and type(numberOfGroups) == "number" and bias and type(bias) == "number" then
        local result = {}
            for _ = 1, numberOfGroups do
                local group = veaf.randomlyChooseFrom(groupsToChooseFrom, bias)
                veaf.loggers.get(VeafQRA.Id):trace(string.format("group=%s", veaf.p(group)))
                table.insert(result, group)
            end
            groupsToDeploy = result
        end
    end
    return groupsToDeploy
end

function VeafQRA:deploy(nbUnitsInZone)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:deploy()", veaf.p(self.name)))
    veaf.loggers.get(VeafQRA.Id):trace(string.format("nbUnitsInZone=[%s]", veaf.p(nbUnitsInZone)))
    if self.minimumNbEnemyPlanes ~= -1 and self.minimumNbEnemyPlanes > nbUnitsInZone then
        veaf.loggers.get(VeafQRA.Id):trace(string.format("not enough enemies in zone, min=%s", veaf.p(self.minimumNbEnemyPlanes)))
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
        veaf.loggers.get(VeafQRA.Id):trace(string.format("self.spawnedGroups=%s", veaf.p(self.spawnedGroups)))
        self.state = VeafQRA.STATUS_ACTIVE
    end
    if self.onDeploy then
        self.onDeploy(nbUnitsInZone)
    end
end

function VeafQRA:destroyed()
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:destroyed()", veaf.p(self.name)))
    if not self.silent then
        local msg = string.format(self.messageDestroyed, self:getDescription())
        for coalition, _ in pairs(self.ennemyCoalitions) do
            trigger.action.outTextForCoalition(coalition, msg, 15)
        end
    end
    if self.onDestroyed then
        self.onDestroyed()
    end
    self.state = VeafQRA.STATUS_DEAD

    if self.QRAcount > 0 then
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA will now see one of it's aicraft groups removed"))
        self.QRAcount = self.QRAcount - 1
    end
end

function VeafQRA:rearm(silent)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:rearm()", veaf.p(self.name)))
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
    self.state = VeafQRA.STATUS_READY
end

function VeafQRA:start()
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:start()", veaf.p(self.name)))
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

function VeafQRA:stop(silent)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:stop()", veaf.p(self.name)))
    self:setScheduledState(VeafQRA.STATUS_STOP)

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

function veafQra.add(aQraObject) 
  veafQra.qras[aQraObject.getName()] = aQraObject
  return aQraObject
end

function veafQra.get(aNameString)
  return veafQra.qras[aNameString]
end