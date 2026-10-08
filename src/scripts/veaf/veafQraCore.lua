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
  -- name of a unit the zone follows (#186); a trigger zone linked to a unit in the editor follows it too
  object.followUnitName = nil
  -- names of the airbases, ships, groups or statics the QRA depends on (#183); see veafReactiveZone.checkLinks
  object.links = {}
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
  -- the tier scrambled is chosen from the opposition level when it is higher than the enemies in the zone
  object.scaleWithOpposition = false
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
    -- the one-entry shortcut of `links` (#183): same rule, same messages
    self:addLink(airport_name)
  end
  return self
end

--- Make the QRA depend on an airbase, FARP, ship, group or static (#183).
---
--- An airbase or FARP captured, or under the minimum life, pauses the QRA until it is retaken; a ship,
--- group or static destroyed stops it for good.
---@param name string
---@return table self
function VeafQRACore:addLink(name)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:addLink(%s)", veaf.lp(self.name), veaf.lp(name))
  if name and type(name) == "string" then
    for _, existing in ipairs(self.links) do
      if existing == name then
        return self
      end
    end
    table.insert(self.links, name)
  end
  return self
end

--- Make the zone follow a unit, a carrier for instance (#186).
---@param unitName string
---@return table self
function VeafQRACore:setFollowUnit(unitName)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setFollowUnit(%s)", veaf.lp(self.name), veaf.lp(unitName))
  self.followUnitName = unitName
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

--- Choose the tier from the opposition level (veafOpposition) when it is higher than the enemies in the
--- zone: a pair entering the zone of a QRA sized for six players gets the six-player tier. The trigger
--- itself stays on the zone — nobody in it, no scramble.
function VeafQRACore:setScaleWithOpposition()
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:setScaleWithOpposition()", veaf.lp(self.name))
  self.scaleWithOpposition = true
  return self
end

--- The count the tier is chosen from: the enemies in the zone, or the opposition level when it is higher
--- and the QRA scales with it.
function VeafQRACore:tierCount(nbUnitsInZone)
  local level = self.scaleWithOpposition and veafOpposition and veafOpposition.getLevel()
  if level and level > nbUnitsInZone then
    return level
  end
  return nbUnitsInZone
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
    --if the QRA is linked to airbases or other entities. Links are checked before even trying to deploy a group and check warehousing which has a lower priority
    if #self.links > 0 then
      veaf.loggers.get(veafQraManager.Id):trace("Checking links : %s", veaf.lp(self.links))
      self:checkLinks()
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
        -- `or {}`, deliberately: a QRA that cannot read its zone must not scramble, which is what an
        -- empty list already gives. The error naming the zone is in the log either way.
        local unitsInZone = veafReactiveZone.findUnitsInZone(self, unitNames, veafQraManager.Id) or {}
        veaf.loggers.get(veafQraManager.Id):trace("unitsInZone=%s", unitsInZone)
        -- airborne, between the floor and the ceiling: never a landed aircraft
        local nbUnitsInZone = #veafReactiveZone.filterAirborne(self, unitsInZone)
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
          if veafReactiveZone.hasPendingSpawns(self.spawnedGroupsNames) then
            -- a deferred command has not spawned its group yet: neither dead nor landed (#1078)
            veaf.loggers.get(veafQraManager.Id):trace("QRA [%s] waits for a deferred spawn", veaf.lp(self.name))
          elseif not qraAlive then
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

--- Check what the QRA depends on (#183) and move it accordingly.
---
--- A lost ship, group or static stops the QRA for good. A captured or damaged airbase pauses it
--- (STATUS_NOAIRBASE) until it is retaken — the `airport_link` behaviour, messages and callbacks
--- unchanged.
function VeafQRACore:checkLinks()
  local state, culprit = veafReactiveZone.checkLinks(self, self.coalition, self.airportMinLifePercent, veafQraManager.Id)
  veaf.loggers.get(veafQraManager.Id):trace("VeafQRACore[%s] links are %s (%s)", veaf.lp(self.name), veaf.lp(state), veaf.lp(culprit))

  if state == veafReactiveZone.LINKS_LOST then
    if self.scheduled_state ~= veafQraManager.STATUS_STOP then
      veaf.loggers.get(veafQraManager.Id):info("QRA [%s] lost [%s] for good and stops", veaf.p(self.name), veaf.p(culprit))
      self:stop()
      -- now, even when airborne: applyScheduledState leaves ACTIVE alone, and the next tick would
      -- find the despawned groups dead and announce the QRA destroyed after announcing it offline
      self.state = veafQraManager.STATUS_STOP
    end
    return
  end

  if state == veafReactiveZone.LINKS_PAUSED then
    -- remembered, so that the "airbase up" callback is handed the airbase that came back
    self._pausedByLink = culprit
    local QRA_airportObject = veaf.getAirbaseForCoalition(culprit, self.coalition)
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
    local QRA_airportObject = self._pausedByLink and veaf.getAirbaseForCoalition(self._pausedByLink, self.coalition)
    veaf.loggers.get(veafQraManager.Id):trace("QRA has it's airbase %s", veaf.lp(self._pausedByLink))
    if not self.silent then
      self:_sendStatusMessage(self.messageAirbaseUp)
    end
    if self.onAirbaseUp then
      self.onAirbaseUp(QRA_airportObject)
    end

    self.noAB_announced = false
    self._pausedByLink = nil
    self.state = veafQraManager.STATUS_DEAD --QRA that have just been recommisionned act as if they were dead since they need to be rearmed after a delay
    if self.scheduled_state == veafQraManager.STATUS_NOAIRBASE then
      self.scheduled_state = nil
    end --make sure you reset the scheduled state if you are within the bounds of this method
  end
end

--- The name this check had while only an airbase could be linked; kept for missions that call it.
function VeafQRACore:checkAirport()
  self:checkLinks()
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
  -- compared, not taken in `pairs()` order: that order is the hash's, and tiers set 5, 1, 3 iterate
  -- 1, 5, 3 in Lua 5.1 — 6 enemies got tier 3 (FEAT-OPPOSITION-SCALES-WITH-PLAYERS)
  local biggestNumberLowerThanUnitsInZone = -1
  local groupsToDeploy = nil
  for enemyNb, groups in pairs(self.groupsToDeployByEnemyQuantity) do
    if nbUnitsInZone >= enemyNb and enemyNb > biggestNumberLowerThanUnitsInZone then
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
      groupsToDeploy = veafReactiveZone.pickDistinctGroups(groupsToChooseFrom, numberOfGroups, bias)
    end
  end
  return groupsToDeploy
end

function VeafQRACore:deploy(nbUnitsInZone)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRACore[%s]:deploy()", veaf.lp(self.name))
  veaf.loggers.get(veafQraManager.Id):trace("nbUnitsInZone=[%s]", veaf.lp(nbUnitsInZone))
  -- the gate counts what the tier is chosen from: a QRA scaling with the opposition whose lowest tier is
  -- 3 still answers a pair when the mission is sized for six
  if self.minimumNbEnemyPlanes ~= -1 and self.minimumNbEnemyPlanes > self:tierCount(nbUnitsInZone) then
    veaf.loggers.get(veafQraManager.Id):trace("not enough enemies in zone, min=%s", veaf.lp(self.minimumNbEnemyPlanes))
    return
  end

  self:_sendStatusMessage(self.messageDeploy)

  local groupsToDeploy = self:chooseGroupsToDeploy(self:tierCount(nbUnitsInZone))
  self.spawnedGroupsNames = {}
  if groupsToDeploy then
    -- the spawn shared with the air-wave zones: commands, editor groups, offsets (FEAT-AIRWAVES-QRA-MERGE)
    self.spawnedGroupsNames = veafReactiveZone.deployGroups(self, groupsToDeploy, self.coalition, veafQraManager.Id)
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
  veafReactiveZone.destroyGroups(self.spawnedGroupsNames)
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
    veafReactiveZone.draw(self, self:getEnnemyCoalition(), self:getDescription())
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
  veafReactiveZone.destroyGroups(self.spawnedGroupsNames)

  -- erase the zone
  veafReactiveZone.erase(self)

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
