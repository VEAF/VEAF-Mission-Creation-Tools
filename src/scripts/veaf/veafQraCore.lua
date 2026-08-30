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
--
-- This file is the core module extracted from veafQraManager.lua.
-- Warehousing / resupply logic lives in veafQraLogistics.lua (VeafQRALogistics).
------------------------------------------------------------------

veafQraManager = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafQraManager.Id = "QRA"

-- trace level, specific to this module
--veafQraManager.LogLevel = "trace"

veaf.loggers.new(veafQraManager.Id, veafQraManager.LogLevel)

function veafQraManager.statusToString(status)
  return veaf.enumToString(status, {
    [veafQraManager.STATUS_WILLREARM] = "STATUS_WILLREARM",
    [veafQraManager.STATUS_READY] = "STATUS_READY",
    [veafQraManager.STATUS_READY_WAITINGFORMORE] = "STATUS_READY_WAITINGFORMORE",
    [veafQraManager.STATUS_ACTIVE] = "STATUS_ACTIVE",
    [veafQraManager.STATUS_DEAD] = "STATUS_DEAD",
  })
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
-- Default status messages are i18n catalog keys (see veafI18n.lua). They are
-- resolved through veaf.t() at send time, so they localize to the mission
-- language; a mission that overrides them with its own literal text keeps it
-- verbatim (veaf.t() returns an unknown key unchanged before formatting).
veafQraManager.DEFAULT_MESSAGE_START = "qra.msg_start"
veafQraManager.DEFAULT_MESSAGE_DEPLOY = "qra.msg_deploy"
veafQraManager.DEFAULT_MESSAGE_DESTROYED = "qra.msg_destroyed"
veafQraManager.DEFAULT_MESSAGE_READY = "qra.msg_ready"
veafQraManager.DEFAULT_MESSAGE_OUT = "qra.msg_out"
veafQraManager.DEFAULT_MESSAGE_RESUPPLIED = "qra.msg_resupplied"
veafQraManager.DEFAULT_MESSAGE_AIRBASE_DOWN = "qra.msg_airbase_down"
veafQraManager.DEFAULT_MESSAGE_AIRBASE_UP = "qra.msg_airbase_up"
veafQraManager.DEFAULT_MESSAGE_STOP = "qra.msg_stop"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafQraManager.qras = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafQRACore class methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafQRACore = {}
function VeafQRACore.init(object)
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
  object.enemyCoalitions = {}
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
  object.respawnDefaultOffset = { latDelta = 0, lonDelta = 0 }
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
  -- logistics (warehousing / resupply chain)
  object.logistics = VeafQRALogistics:new()
end

function VeafQRACore.ToggleAllSilence(state)
  if state then
    veafQraManager.AllSilence = true
  else
    veafQraManager.AllSilence = false
  end
end

function VeafQRACore:new(objectToCopy)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore:new()")

  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self

  -- init the new object
  VeafQRACore.init(objectToCreate)

  return objectToCreate
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Status message helper
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build a status message string by formatting a template with this QRA's description.
---@param template string  A format string with one %s placeholder for the description.
---@return string
function VeafQRACore:_buildStatusMessage(template)
  return veaf.t(template, self:getDescription())
end

--- Send a status message to all enemy coalitions, unless the QRA is silent.
---@param template string  A format string with one %s placeholder for the description.
function VeafQRACore:_sendStatusMessage(template)
  if not self.silent then
    local msg = self:_buildStatusMessage(template)
    for coalition, _ in pairs(self.enemyCoalitions) do
      trigger.action.outTextForCoalition(coalition, msg, 15)
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Identity / zone setters and getters
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function VeafQRACore:setName(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[]:setName(%s)", veaf.lp(value))
  self.name = value
  return veafQraManager.add(self) -- add the QRA to the QRA list as soon as a name is available to index it
end

function VeafQRACore:setTriggerZone(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setTriggerZone(%s)", veaf.lp(self.name), veaf.lp(value))
  self.triggerZoneName = value
  return self
end

function VeafQRACore:setZoneCenter(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setZoneCenter(%s)", veaf.lp(self.name), veaf.lp(value))
  self.zoneCenter = value
  return self
end

function VeafQRACore:setZoneCenterFromCoordinates(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setZoneCenterFromCoordinates(%s)", veaf.lp(self.name), veaf.lp(value))
  local _lat, _lon = veaf.computeLLFromString(value)
  ---@diagnostic disable-next-line: param-type-mismatch
  local vec3 = coord.LLtoLO(_lat, _lon)
  return self:setZoneCenter(vec3)
end

function VeafQRACore:setZoneRadius(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setZoneRadius(%s)", veaf.lp(self.name), veaf.lp(value))
  self.zoneRadius = value
  return self
end

function VeafQRACore:setDescription(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setDescription(%s)", veaf.lp(self.name), veaf.lp(value))
  self.description = value
  return veafQraManager.add(self) -- add the QRA to the QRA list as soon as a name is available to index it
end

function VeafQRACore:getDescription()
  return self.description or self.name
end

function VeafQRACore:getName()
  return self.name or self.description
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Group configuration setters
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function VeafQRACore:addGroup(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:addGroup(%s)", veaf.lp(self.name), veaf.lp(value))
  if not self.groupsToDeployByEnemyQuantity[1] then
    self.groupsToDeployByEnemyQuantity[1] = {}
  end
  table.insert(self.groupsToDeployByEnemyQuantity[1], value)
  return self
end

function VeafQRACore:addRandomGroup(groups, number, bias)
  veaf.loggers
    .get(veafQraManager.Id)
    :debug("VeafQRACore[%s]:addRandomGroup(%s, %s, %s)", veaf.lp(self.name), veaf.lp(groups), veaf.lp(number), veaf.lp(bias))
  return self:addGroup({ groups, number or 1, bias or 0 })
end

function VeafQRACore:setGroupsToDeployByEnemyQuantity(enemyNb, groupsToDeploy)
  veaf.loggers
    .get(veafQraManager.Id)
    :debug("VeafQRACore[%s]:setGroupsToDeployByEnemyQuantity(%s) -> %s", veaf.lp(self.name), veaf.lp(enemyNb), veaf.lp(groupsToDeploy))
  self.groupsToDeployByEnemyQuantity[enemyNb] = groupsToDeploy
  if self.minimumNbEnemyPlanes == -1 or self.minimumNbEnemyPlanes > enemyNb then
    self.minimumNbEnemyPlanes = enemyNb
  end
  return self
end

function VeafQRACore:setRandomGroupsToDeployByEnemyQuantity(enemyNb, groups, number, bias)
  veaf.loggers.get(veafQraManager.Id):debug(
    "VeafQRACore[%s]:setRandomGroupsToDeployByEnemyQuantity(%s, %s, %s, %s)",
    veaf.lp(self.name),
    veaf.lp(enemyNb),
    veaf.lp(groups),
    veaf.lp(number),
    veaf.lp(bias)
  )
  return self:setGroupsToDeployByEnemyQuantity(enemyNb, { groups, number or 1, bias or 0 })
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Coalition setters
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function VeafQRACore:setCoalition(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setCoalition(%s)", veaf.lp(self.name), veaf.lp(value))
  self.coalition = value
  return self
end

function VeafQRACore:addEnnemyCoalition(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:addEnnemyCoalition(%s)", veaf.lp(self.name), veaf.lp(value))
  self.enemyCoalitions[value] = value
  return self
end

function VeafQRACore:getEnnemyCoalition()
  local result = nil
  for coalition, _ in pairs(self.enemyCoalitions) do
    result = coalition
    break
  end
  return result
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Message / event setters
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function VeafQRACore:setMessageStart(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setMessageStart(%s)", veaf.lp(self.name), veaf.lp(value))
  self.messageStart = value
  return self
end

function VeafQRACore:setOnStart(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setOnStart()", veaf.lp(self.name))
  self.onStart = value
  return self
end

function VeafQRACore:setMessageDeploy(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setMessageDeploy(%s)", veaf.lp(self.name), veaf.lp(value))
  self.messageDeploy = value
  return self
end

function VeafQRACore:setOnDeploy(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setOnDeploy()", veaf.lp(self.name))
  self.onDeploy = value
  return self
end

function VeafQRACore:setMessageDestroyed(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setMessageDestroyed(%s)", veaf.lp(self.name), veaf.lp(value))
  self.messageDestroyed = value
  return self
end

function VeafQRACore:setOnDestroyed(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setOnDestroyed()", veaf.lp(self.name))
  self.onDestroyed = value
  return self
end

function VeafQRACore:setMessageReady(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setMessageReady(%s)", veaf.lp(self.name), veaf.lp(value))
  self.messageReady = value
  return self
end

function VeafQRACore:setOnReady(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setOnReady()", veaf.lp(self.name))
  self.onReady = value
  return self
end

function VeafQRACore:setMessageOut(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setMessageOut(%s)", veaf.lp(self.name), veaf.lp(value))
  self.messageOut = value
  return self
end

function VeafQRACore:setOnOut(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setOnOut()", veaf.lp(self.name))
  self.onOut = value
  return self
end

function VeafQRACore:setMessageResupplied(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setMessageResupplied(%s)", veaf.lp(self.name), veaf.lp(value))
  self.messageResupplied = value
  return self
end

function VeafQRACore:setOnResupplied(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setOnResupplied()", veaf.lp(self.name))
  self.onResupplied = value
  return self
end

function VeafQRACore:setMessageAirbaseDown(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setMessageAirbaseDown(%s)", veaf.lp(self.name), veaf.lp(value))
  self.messageAirbaseDown = value
  return self
end

function VeafQRACore:setOnAirbaseDown(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setOnAirbaseDown()", veaf.lp(self.name))
  self.onAirbaseDown = value
  return self
end

function VeafQRACore:setMessageAirbaseUp(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setMessageAirbaseUp(%s)", veaf.lp(self.name), veaf.lp(value))
  self.messageAirbaseUp = value
  return self
end

function VeafQRACore:setOnAirbaseUp(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setOnAirbaseUp()", veaf.lp(self.name))
  self.onAirbaseUp = value
  return self
end

function VeafQRACore:setMessageStop(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setMessageStop(%s)", veaf.lp(self.name), veaf.lp(value))
  self.messageStop = value
  return self
end

function VeafQRACore:setOnStop(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setOnStop()", veaf.lp(self.name))
  self.onStop = value
  return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Behavior setters
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function VeafQRACore:setSilent(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setSilent(%s)", veaf.lp(self.name), veaf.lp(value))
  self.silent = value or false
  return self
end

function VeafQRACore:setDrawZone(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setDrawZone(%s)", veaf.lp(self.name), veaf.lp(value))
  self.drawZone = value or false
  return self
end

function VeafQRACore:setAirportLink(airport_name)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setAirportLink(%s)", veaf.lp(self.name), veaf.lp(airport_name))
  if airport_name and type(airport_name) == "string" and Airbase.getByName(airport_name) then
    self.airportLink = airport_name
  end
  return self
end

function VeafQRACore:setAirportMinLifePercent(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setAirportMinLifePercent(%s)", veaf.lp(self.name), veaf.lp(value))
  if value and value >= 0 and value <= 1 then
    self.airportMinLifePercent = value
  end
  return self
end

function VeafQRACore:setReactOnHelicopters(value)
  -- Honor the argument: a bare legacy call (no arg) keeps the historical "enable" meaning,
  -- but an explicit value (e.g. :setReactOnHelicopters(false)) is respected.
  if value == nil then
    value = true
  end
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setReactOnHelicopters(%s)", veaf.lp(self.name), value)
  self.reactOnHelicopters = value
  return self
end

---set the default respawn offset (in meters, relative to the zone center)
---@param defaultOffsetLatitude any in meters
---@param defaultOffsetLongitude any in meters
---@return table self
function VeafQRACore:setRespawnDefaultOffset(defaultOffsetLatitude, defaultOffsetLongitude)
  veaf.loggers.get(veafQraManager.Id):debug(
    "VeafQRACore[%s]:setRespawnDefaultOffset(%s, %s)",
    veaf.lp(self.name),
    veaf.lp(defaultOffsetLatitude),
    veaf.lp(defaultOffsetLongitude)
  )
  self.respawnDefaultOffset = { latDelta = defaultOffsetLatitude, lonDelta = defaultOffsetLongitude }
  return self
end

function VeafQRACore:setRespawnRadius(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setRespawnRadius(%s)", veaf.lp(self.name), veaf.lp(value))
  self.respawnRadius = value
  if self.respawnRadius < 250 then
    self.respawnRadius = 250
  end
  return self
end

function VeafQRACore:setDelayBeforeRearming(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setDelayBeforeRearming(%s)", veaf.lp(self.name), veaf.lp(value))
  self.delayBeforeRearming = value
  return self
end

function VeafQRACore:setNoNeedToLeaveZoneBeforeRearming()
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setNoNeedToLeaveZoneBeforeRearming()", veaf.lp(self.name))
  self.noNeedToLeaveZoneBeforeRearming = true
  return self
end

function VeafQRACore:setResetWhenLeavingZone()
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setResetWhenLeavingZone()", veaf.lp(self.name))
  self.resetWhenLeavingZone = true
  return self
end

function VeafQRACore:setDelayBeforeActivating(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setDelayBeforeActivating(%s)", veaf.lp(self.name), veaf.lp(value))
  self.delayBeforeActivating = value
  return self
end

function VeafQRACore:setMinimumAltitudeInFeet(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setMinimumAltitudeInFeet(%s)", veaf.lp(self.name), veaf.lp(value))
  self.minimumAltitude = value * 0.3048 -- convert from feet
  return self
end

function VeafQRACore:getMinimumAltitudeInMeters()
  return self.minimumAltitude
end

function VeafQRACore:setMaximumAltitudeInFeet(value)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setMaximumAltitudeInFeet(%s)", veaf.lp(self.name), veaf.lp(value))
  self.maximumAltitude = value * 0.3048 -- convert from feet
  return self
end

function VeafQRACore:getMaximumAltitudeInMeters()
  return self.maximumAltitude
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Logistics proxy setters (delegate to self.logistics, return self for chaining)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--TODO, warehousing for each group within a QRA and not just the whole QRA
function VeafQRACore:setQRAcount(count)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setQRAcount(%s)", veaf.lp(self.name), veaf.lp(count))
  self.logistics:setQRAcount(count)
  return self
end

function VeafQRACore:setQRAmaxCount(maxCount)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setQRAmaxCount(%s)", veaf.lp(self.name), veaf.lp(maxCount))
  self.logistics:setQRAmaxCount(maxCount)
  return self
end

function VeafQRACore:setQRAresupplyDelay(resupplyDelay)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setQRAresupplyDelay(%s)", veaf.lp(self.name), veaf.lp(resupplyDelay))
  self.logistics:setQRAresupplyDelay(resupplyDelay)
  return self
end

function VeafQRACore:setQRAmaxResupplyCount(maxResupplyCount)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setQRAmaxResupplyCount(%s)", veaf.lp(self.name), veaf.lp(maxResupplyCount))
  self.logistics:setQRAmaxResupplyCount(maxResupplyCount)
  return self
end

function VeafQRACore:setQRAminCountforResupply(minCountforResupply)
  veaf.loggers
    .get(veafQraManager.Id)
    :debug("VeafQRACore[%s]:setQRAminCountforResupply(%s)", veaf.lp(self.name), veaf.lp(minCountforResupply))
  self.logistics:setQRAminCountforResupply(minCountforResupply)
  return self
end

function VeafQRACore:setResupplyAmount(resupplyAmount)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setResupplyAmount(%s)", veaf.lp(self.name), veaf.lp(resupplyAmount))
  self.logistics:setResupplyAmount(resupplyAmount)
  return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Detection methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function VeafQRACore:humanBornEvent(unit)
  veaf.loggers.get(veafQraManager.Id):trace("VeafQRACore[%s]:humanBornEvent(%s)", self.name, unit)

  if not self._enemyHumanUnits then
    return -- do this later ^^
  end

  local coalitionId = 0
  if unit.unitCoalition then
    coalitionId = unit.unitCoalition
  elseif unit.getCoalition then
    -- dynamic slot: unit is a DCS object, use API
    coalitionId = unit:getCoalition()
  end
  if self.enemyCoalitions[coalitionId] then
    veaf.loggers
      .get(veafQraManager.Id)
      :trace("VeafQRACore[%s]:humanBornEvent() - unit being born is an enemy (coalition %s)", self.name, coalitionId)
    local unitCategory = unit.unitCategory
    if unitCategory == nil then
      -- Dynamic slot: the unit is a DCS object, query the API. We MUST use getCategoryEx()
      -- (returns a Unit.Category: AIRPLANE=0 / HELICOPTER=1 / …) and NOT getCategory(),
      -- which returns an Object.Category whose UNIT value (1) collides with
      -- Unit.Category.HELICOPTER (1) — that made every dynamic slot look like a helicopter,
      -- so airplane slots only triggered the QRA when reactOnHelicopters was true (#299).
      if unit.getCategoryEx then
        unitCategory = unit:getCategoryEx()
      elseif unit.getDesc then
        unitCategory = unit:getDesc().category
      end
    end
    if unitCategory then
      if (unitCategory == Unit.Category.AIRPLANE) or (unitCategory == Unit.Category.HELICOPTER and self.reactOnHelicopters) then
        local unitNameToCheck = unit.unitName
        if unitNameToCheck == nil and unit.getName then
          -- dynamic slot: unit is a DCS object, use API
          unitNameToCheck = unit:getName()
        end
        -- check if the unit is already in the list
        for _, existingUnitName in pairs(self._enemyHumanUnits) do
          if existingUnitName == unitNameToCheck then
            return
          end
        end
        veaf.loggers.get(veafQraManager.Id):trace("adding unit to enemy human units for QRA")
        table.insert(self._enemyHumanUnits, unitNameToCheck)
      end
    end
  end
end

function VeafQRACore:_getEnemyHumanUnits()
  if not self._enemyHumanUnits then
    veaf.loggers.get(veafQraManager.Id):trace("VeafQRACore[%s]:_getEnemyHumanUnits() - computing", veaf.lp(self.name))
    self._enemyHumanUnits = {}
    for _, unit in pairs(veaf.mist.getAllHumanUnitData()) do
      local coalitionId = 0
      if unit.coalition then
        if unit.coalition:lower() == "red" then
          coalitionId = coalition.side.RED
        elseif unit.coalition:lower() == "blue" then
          coalitionId = coalition.side.BLUE
        end
      end
      if self.enemyCoalitions[coalitionId] then
        if unit.category then
          if (unit.category == "plane") or (unit.category == "helicopter" and self.reactOnHelicopters) then
            veaf.loggers.get(veafQraManager.Id):trace("adding unit to enemy human units for QRA")
            table.insert(self._enemyHumanUnits, unit.unitName)
          end
        end
      end
    end
  end
  return self._enemyHumanUnits
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- State management
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function VeafQRACore:check()
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:check()", veaf.lp(self.name))
  veaf.loggers.get(veafQraManager.Id):debug("self.state=%s", veaf.lp(veafQraManager.statusToString(self.state)))
  veaf.loggers.get(veafQraManager.Id):trace("timer.getTime()=%s", veaf.lp(timer.getTime()))

  --scheduled state application is attempted regardless of airportlink checks etc. to take into account user requested states which go through scheduled_states as well
  --Stop scheduled is checked before even running the check function as it has the highest priority
  self:applyScheduledState()

  if self.state ~= veafQraManager.STATUS_STOP then
    --if the QRA is linked to an airbase. Airport is checked before even trying to deploy a group and check warehousing which has a lower priority
    if self.airportLink then
      veaf.loggers.get(veafQraManager.Id):trace("Checking Airport link : %s", veaf.lp(self.airportLink))
      self:checkAirport()
      self:applyScheduledState()
    end

    if self.state ~= veafQraManager.STATUS_NOAIRBASE then
      --if warehousing is activated. Warehousing is checked before even trying to deploy a group
      if self.logistics:isActive() then
        veaf.loggers.get(veafQraManager.Id):trace("Checking Warehousing...")
        veaf.loggers.get(veafQraManager.Id):trace("QRACount : %s", veaf.lp(self.logistics:getQRAcount()))
        self.logistics:checkWarehousing(self)
        self:applyScheduledState()
      end

      if self.state ~= veafQraManager.STATUS_OUT then
        local unitNames = self:_getEnemyHumanUnits()
        local unitsInZone = nil
        local triggerZone = veaf.getTriggerZone(self.triggerZoneName)

        if not veaf.isNullOrEmpty(self.triggerZoneName) and triggerZone == nil then
          veaf.loggers.get(veafQraManager.Id):error("QRA has a non-existant zone: " .. self.triggerZoneName)
        end
        unitsInZone = {}
        if triggerZone then
          -- `or {}`, deliberately: a QRA that cannot read its zone must not scramble, which is what an
          -- empty list already gives. The error naming the zone is in the log either way.
          unitsInZone = veaf.getUnitsInTriggerZone(self.triggerZoneName, unitNames, veafQraManager.Id) or {}
        elseif self.zoneCenter then
          unitsInZone = veaf.findUnitsInCircle(self.zoneCenter, self.zoneRadius, false, unitNames)
        else
          veaf.loggers.get(veafQraManager.Id):error("QRA [%s] has no zone defined, cannot check for units in zone", self.name)
          return
        end
        veaf.loggers.get(veafQraManager.Id):trace("unitsInZone=%s", unitsInZone)
        local nbUnitsInZone = 0
        for _, unit in pairs(unitsInZone) do
          -- check the unit altitude against the ceiling and floor
          if unit:isExist() and unit:inAir() then -- never count a landed aircraft
            local alt = unit:getPoint().y
            if alt >= self:getMinimumAltitudeInMeters() and alt <= self:getMaximumAltitudeInMeters() then
              nbUnitsInZone = nbUnitsInZone + 1
            end
          end
        end
        veaf.loggers.get(veafQraManager.Id):trace("nbUnitsInZone=%s", nbUnitsInZone)
        if (self.state == veafQraManager.STATUS_READY) and (unitsInZone and nbUnitsInZone > 0) then
          veaf.loggers
            .get(veafQraManager.Id)
            :debug("self.state set to veafQraManager.STATUS_READY_WAITINGFORMORE at timer.getTime()=%s", timer.getTime())
          self.state = veafQraManager.STATUS_READY_WAITINGFORMORE
          self.timeSinceReady = timer.getTime()
        elseif
          (self.state == veafQraManager.STATUS_READY_WAITINGFORMORE)
          and (unitsInZone and nbUnitsInZone > 0)
          and (timer.getTime() - self.timeSinceReady > self.delayBeforeActivating)
        then
          -- trigger the QRA
          self:deploy(nbUnitsInZone)
          self.timeSinceReady = -1
        elseif
          (self.state == veafQraManager.STATUS_DEAD) and (self.noNeedToLeaveZoneBeforeRearming or (not unitsInZone or nbUnitsInZone == 0))
        then
          -- rearm the QRA after a delay (if set)
          if self.delayBeforeRearming > 0 then
            veaf.scheduleFunction(function(qra)
              veaf.safeCall(VeafQRACore.rearm, qra)
            end, { self }, timer.getTime() + self.delayBeforeRearming)
            self.state = veafQraManager.STATUS_WILLREARM
          else
            self:rearm()
          end
        elseif self.state == veafQraManager.STATUS_ACTIVE then
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
                for _, unit in pairs(units) do
                  if unit and unit:isExist() then
                    local unitLife = unit:getLife()
                    local unitLife0 = 0
                    if unit.getLife0 then -- statics have no life0
                      unitLife0 = unit:getLife0()
                    end
                    local unitLifePercent = unitLife
                    if unitLife0 > 0 then
                      unitLifePercent = 100 * unitLife / unitLife0
                    end
                    if unitLifePercent >= veafQraManager.MINIMUM_LIFE_FOR_QRA_IN_PERCENT then
                      groupAtLeastOneUnitAlive = true
                    end
                    if
                      category == 0 --[[airplanes]]
                      or category == 1 --[[helicopters]]
                    then
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
              veaf.loggers.get(veafQraManager.Id):trace("qraAlive=%s", veaf.lp(qraAlive))
              veaf.loggers.get(veafQraManager.Id):trace("qraInAir=%s", veaf.lp(qraInAir))
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

    veaf.scheduleFunction(function(qra)
      veaf.safeCall(VeafQRACore.check, qra)
    end, { self }, timer.getTime() + veafQraManager.WATCHDOG_DELAY)
  end
end

function VeafQRACore:setScheduledState(scheduledState)
  --priority level 1
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setScheduledState(%s)", veaf.lp(self.name), veaf.lp(scheduledState))
  if scheduledState == veafQraManager.STATUS_STOP then
    self.scheduled_state = veafQraManager.STATUS_STOP
    veaf.loggers.get(veafQraManager.Id):debug("QRA STOP scheduled")
    --priority level 2
  elseif scheduledState == veafQraManager.STATUS_NOAIRBASE and self.scheduled_state ~= veafQraManager.STATUS_STOP then
    self.scheduled_state = veafQraManager.STATUS_NOAIRBASE
    veaf.loggers.get(veafQraManager.Id):debug("QRA NOAIRBASE scheduled")
    --priority level 3
  elseif
    scheduledState == veafQraManager.STATUS_OUT
    and self.scheduled_state ~= veafQraManager.STATUS_STOP
    and self.scheduled_state ~= veafQraManager.STATUS_NOAIRBASE
  then
    self.scheduled_state = veafQraManager.STATUS_OUT
    veaf.loggers.get(veafQraManager.Id):debug("QRA OUT scheduled")
  end
  return self
end

function VeafQRACore:applyScheduledState()
  if self.scheduled_state and self.state ~= veafQraManager.STATUS_ACTIVE then
    veaf.loggers.get(veafQraManager.Id):debug("QRA taking scheduled status : %s", veaf.lp(self.scheduled_state))
    self.state = self.scheduled_state
  end
end

function VeafQRACore:checkAirport()
  local QRA_airportObject = veaf.getAirbaseForCoalition(self.airportLink, self.coalition)
  local airport_life_percent = nil
  if QRA_airportObject then
    airport_life_percent = veaf.getAirbaseLife(self.airportLink, true)
  end

  veaf.loggers.get(veafQraManager.Id):trace("VeafQRACore[%s] is linked to airbase %s", veaf.lp(self.name), veaf.lp(self.airportLink))

  if not QRA_airportObject or airport_life_percent < self.airportMinLifePercent then
    veaf.loggers.get(veafQraManager.Id):trace("QRA lost it's airbase")
    self:setScheduledState(veafQraManager.STATUS_NOAIRBASE)
    if not self.silent and not self.noAB_announced then
      self:_sendStatusMessage(self.messageAirbaseDown)
    end
    if self.onAirbaseDown then
      self.onAirbaseDown(QRA_airportObject)
    end
    self.noAB_announced = true
  elseif self.state == veafQraManager.STATUS_NOAIRBASE then
    veaf.loggers.get(veafQraManager.Id):trace("QRA has it's airbase %s", veaf.lp(QRA_airportObject:getName()))
    if not self.silent then
      self:_sendStatusMessage(self.messageAirbaseUp)
    end
    if self.onAirbaseUp then
      self.onAirbaseUp(QRA_airportObject)
    end

    self.noAB_announced = false
    self.state = veafQraManager.STATUS_DEAD --QRA that have just been recommisionned act as if they were dead since they need to be rearmed after a delay
    if self.scheduled_state == veafQraManager.STATUS_NOAIRBASE then
      self.scheduled_state = nil
    end --make sure you reset the scheduled state if you are within the bounds of this method
  end
end

--- Delegate warehousing check to the logistics object.
function VeafQRACore:checkWarehousing()
  self.logistics:checkWarehousing(self)
end

--- Delegate resupply to the logistics object.
function VeafQRACore:resupply(resupplyAmount)
  self.logistics:resupply(self, resupplyAmount)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Spawn / despawn methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function VeafQRACore:chooseGroupsToDeploy(nbUnitsInZone)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:chooseGroupsToDeploy(%s)", veaf.lp(self.name), veaf.lp(nbUnitsInZone))
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
    if
      groupsToChooseFrom
      and type(groupsToChooseFrom) == "table"
      and numberOfGroups
      and type(numberOfGroups) == "number"
      and bias
      and type(bias) == "number"
    then
      local result = {}
      for _ = 1, numberOfGroups do
        local group = veaf.randomlyChooseFrom(groupsToChooseFrom, bias)
        veaf.loggers.get(veafQraManager.Id):trace("group=%s", veaf.lp(group))
        table.insert(result, group)
      end
      groupsToDeploy = result
    end
  end
  return groupsToDeploy
end

function VeafQRACore:deploy(nbUnitsInZone)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:deploy()", veaf.lp(self.name))
  veaf.loggers.get(veafQraManager.Id):trace("nbUnitsInZone=[%s]", veaf.lp(nbUnitsInZone))
  if self.minimumNbEnemyPlanes ~= -1 and self.minimumNbEnemyPlanes > nbUnitsInZone then
    veaf.loggers.get(veafQraManager.Id):trace("not enough enemies in zone, min=%s", veaf.lp(self.minimumNbEnemyPlanes))
    return
  end

  self:_sendStatusMessage(self.messageDeploy)

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
          veaf.loggers.get(veafQraManager.Id):trace("coords=%s", veaf.lp(coords))
          veaf.loggers.get(veafQraManager.Id):trace("command=%s", veaf.lp(command))
          if coords then
            latDelta, lonDelta = coords:match("([%+-%d]+),%s*([%+-%d]+)")
          end
        end
        veaf.loggers.get(veafQraManager.Id):debug("running command [%s]", veaf.lp(command))
        veaf.loggers.get(veafQraManager.Id):trace("latDelta = [%s]", veaf.lp(latDelta))
        veaf.loggers.get(veafQraManager.Id):trace("lonDelta = [%s]", veaf.lp(lonDelta))
        local position = { x = zoneCenter.x - lonDelta, y = zoneCenter.y, z = zoneCenter.z + latDelta }
        local randomPosition = veaf.getRandomPointInCircle(position, self.respawnRadius)
        local spawnedGroupsNames = {}
        veafInterpreter.execute(command, randomPosition, self.coalition, nil, spawnedGroupsNames)
        for _, newGroupName in pairs(spawnedGroupsNames) do
          table.insert(self.spawnedGroupsNames, newGroupName)
        end
      else
        -- this is a DCS group
        local groupName = groupNameOrCommand
        veaf.loggers.get(veafQraManager.Id):debug("spawning group [%s]", veaf.lp(groupName))
        local group = Group.getByName(groupName)
        if not group then
          veaf.loggers.get(veafQraManager.Id):error("group [%s] does not exist in the mission!", veaf.p(groupName))
        else
          veaf.loggers.get(veafQraManager.Id):debug("group=%s", veaf.lp(group))
          veaf.loggers.get(veafQraManager.Id):debug("group:getUnits()=%s", veaf.lp(group:getUnits()))
          local spawnSpot = {
            x = zoneCenter.x - self.respawnDefaultOffset.lonDelta,
            y = zoneCenter.y,
            z = zoneCenter.z + self.respawnDefaultOffset.latDelta,
          }
          -- Try and set the spawn spot at the place the group has been set in the Mission Editor.
          -- Unfortunately this is sometimes not possible because DCS is not returning the group units for some reason.
          -- When this happens we'll default to the default spawn offset (same as spawning with VEAF commands)
          if not group:getUnit(1) then
            veaf.loggers.get(veafQraManager.Id):warn("group [%s] does not have any unit!", veaf.p(groupName))
          else
            spawnSpot = group:getUnit(1):getPoint()
          end
          local vars = {}
          vars.point = veaf.getRandomPointInCircle(spawnSpot, self.respawnRadius)
          vars.point.z = vars.point.y
          vars.point.y = spawnSpot.y
          vars.gpName = groupName
          vars.action = "clone"
          vars.route = veaf.getGroupRoute(groupName)
          local newGroup = mist.teleportToPoint(vars) -- respawn with radius
          if newGroup then
            table.insert(self.spawnedGroupsNames, newGroup.name)
          end
        end
      end
    end
    veaf.loggers.get(veafQraManager.Id):trace("self.spawnedGroups=%s", veaf.lp(self.spawnedGroupsNames))
    self.state = veafQraManager.STATUS_ACTIVE
  end
  if self.onDeploy then
    self.onDeploy(nbUnitsInZone)
  end
end

function VeafQRACore:destroyed()
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:destroyed()", veaf.lp(self.name))
  self:_sendStatusMessage(self.messageDestroyed)
  if self.onDestroyed then
    self.onDestroyed()
  end
  self.state = veafQraManager.STATUS_DEAD
  self.logistics:onQRADestroyed()
end

function VeafQRACore:rearm(silent)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:rearm()", veaf.lp(self.name))
  if not silent then
    self:_sendStatusMessage(self.messageReady)
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

function VeafQRACore:start()
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:start()", veaf.lp(self.name))
  self.scheduled_state = nil --make sure you reset the scheduled state if you are within the bounds of this method
  self:rearm()
  self:check()

  -- draw the zone
  if self.drawZone then
    if self.triggerZoneName then
      self.zoneDrawing = veaf.drawTriggerZone(self.triggerZoneName, { message = self:getDescription() })
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

  self:_sendStatusMessage(self.messageStart)
  if self.onStart then
    self.onStart()
  end

  return self
end

function VeafQRACore:stop(silent)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:stop()", veaf.lp(self.name))
  self:setScheduledState(veafQraManager.STATUS_STOP)

  -- just in case, despawn the spawned groups
  if self.spawnedGroupsNames then
    for _, groupName in pairs(self.spawnedGroupsNames) do
      local group = Group.getByName(groupName)
      if group then
        group:destroy()
      end
    end
  end

  -- erase the zone
  if self.zoneDrawing then
    if self.triggerZoneName then
      veaf.removeDrawing(self.zoneDrawing.markId)
    else
      self.zoneDrawing:erase()
    end
    self.zoneDrawing = nil
  end

  if not silent then
    self:_sendStatusMessage(self.messageStop)
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

---
--- called from veafEventHandler when a unit is created
function veafQraManager.eventHandler(event)
  -- find the originator unit
  local unitName = veafEventHandler.unitNameFromEvent(event)
  if not unitName then
    return
  end

  local isHumanUnit = veaf.mist.isHumanUnit(unitName) or (event.type and event.type.id == world.event.S_EVENT_PLAYER_ENTER_UNIT)
  if isHumanUnit then -- it's a human unit
    local unit = event.initiator
    if unit ~= nil then
      -- handle the event on all QRAs
      for _, qra in pairs(veafQraManager.qras) do
        qra:humanBornEvent(unit)
      end
    end
  end
end

function veafQraManager.initialize()
  veaf.loggers.get(veafQraManager.Id):debug("veafQraManager.initialize()")
  veafEventHandler.addCallback("veafQraManager.eventHandler", { "S_EVENT_BIRTH", "S_EVENT_PLAYER_ENTER_UNIT" }, veafQraManager.eventHandler)
end

veaf.loggers.get(veafQraManager.Id):info(veaf.loggers.get(veafQraManager.Id):getVersionInfo())

veaf.registerModule(veafQraManager.Id, veafQraManager.initialize, { enable = true }, 130)

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Backward compatibility alias
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- VeafQRA is an alias for VeafQRACore. Existing missions using VeafQRA:new() continue to work.
VeafQRA = VeafQRACore

--- ToggleAllSilence is also accessible via the old name.
VeafQRA.ToggleAllSilence = VeafQRACore.ToggleAllSilence
