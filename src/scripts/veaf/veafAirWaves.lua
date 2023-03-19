------------------------------------------------------------------
-- VEAF Air Waves for DCS World
-- By Zip (2023)
--
-- Features:
-- ---------
-- * Define zones that are defended by waves of AI flights
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafAirWaves = {}

--- Identifier. All output in the log will start with this.
veafAirWaves.Id = "AIRWAVES - "

--- Version.
veafAirWaves.Version = "1.1.0"

-- trace level, specific to this module
--veafAirWaves.LogLevel = "trace"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.loggers.new(veafAirWaves.Id, veafAirWaves.LogLevel)

veafAirWaves.zones = {}

veafAirWaves.WATCHDOG_DELAY = 1

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- AirWave class methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

AirWaveZone = {}
function AirWaveZone.init(object)
  -- technical name (AirWave instance name)
  object.name = nil
  -- description for the messages
  object.description = nil
  -- trigger zone name (if set, we'll use a DCS trigger zone)
  object.triggerZoneName = nil
  -- center (point in the center of the circle, when not using a DCS trigger zone)
  object.zoneCenter = nil
  -- radius (size of the circle, when not using a zone) - in meters
  object.zoneRadius = nil
  -- draw the zone on screen
  object.drawZone = false
  -- default position for respawns (im meters, lat/lon, relative to the zone center)
  object.respawnDefaultOffset = {latDelta=0, lonDelta=0}
  -- radius of the waves groups spawn
  object.respawnRadius = 250
  -- coalitions of the players (only human units from these coalitions will be monitored)
  object.playerCoalitions = {}
  -- player units (if they die, reset the zone)
  object.playerUnitsNames = {}
  -- aircraft groups forming the waves
  object.waves = {}
  -- groups that have been spawned (the current wave)
  object.spawnedGroupsNames = {}
  -- silent means no message is emitted
  object.silent = false
  -- message when the zone is activated
  object.messageStart = veafAirWaves.DEFAULT_MESSAGE_START
  -- event when the zone is activated
  object.onStart = nil
  -- message when a wave is triggered
  object.messageDeploy = veafAirWaves.DEFAULT_MESSAGE_DEPLOY
  -- event  when a wave is triggered
  object.onDeploy = nil
  -- message when a wave is destroyed
  object.messageDestroyed = veafAirWaves.DEFAULT_MESSAGE_DESTROYED
  -- event when a wave is destroyed
  object.onDestroyed = nil
  -- message when all waves are finished
  object.messageWon = veafAirWaves.DEFAULT_MESSAGE_WON
  -- event when all waves are finished
  object.onWon = nil
  -- message when the zone is lost
  object.messageLost = veafAirWaves.DEFAULT_MESSAGE_LOST
  -- event when all players are dead
  object.onLost = nil
  -- message when the zone is deactivated
  object.messageStop = veafAirWaves.DEFAULT_MESSAGE_STOP
  -- event when the zone is deactivated
  object.onStop = nil
  -- delay in seconds between waves of ennemy planes
  object.delayBetweenWaves = 0
  -- if true, the zone will reset when player dies
  object.resetWhenDying = true
  -- human units that are being watched
  object.playerHumanUnits = nil
  -- players in the zone will only be detected below this altitude (in feet)
  object.minimumAltitude = -999999
  -- players in the zone will only be detected above this altitude (in feet)
  object.maximumAltitude = 999999
  -- current wave number
  object.currentWaveIndex = 0
  object.zoneDrawing = nil
end

function veafAirWaves.statusToString(status)
  if status == veafAirWaves.STATUS_READY then return "STATUS_READY" end
  if status == veafAirWaves.STATUS_ACTIVE then return "STATUS_ACTIVE" end
  if status == veafAirWaves.STATUS_NEXTWAVE then return "STATUS_NEXTWAVE" end
  if status == veafAirWaves.STATUS_OVER then return "STATUS_OVER" end
  return ""
end
veafAirWaves.STATUS_READY = 1
veafAirWaves.STATUS_ACTIVE = 2
veafAirWaves.STATUS_NEXTWAVE = 3
veafAirWaves.STATUS_OVER = 4

veafAirWaves.MINIMUM_LIFE_FOR_AI_IN_PERCENT = 10

veafAirWaves.DEFAULT_MESSAGE_START = "Zone %s is online"
veafAirWaves.DEFAULT_MESSAGE_DEPLOY = "Zone %s is deploying wave %s"
veafAirWaves.DEFAULT_MESSAGE_DESTROYED = "Zone %s: wave %s has been destroyed"
veafAirWaves.DEFAULT_MESSAGE_WON = "Zone %s is won (no more waves)"
veafAirWaves.DEFAULT_MESSAGE_LOST = "Zone %s is lost (no more players)"
veafAirWaves.DEFAULT_MESSAGE_STOP = "Zone %s is offline"

function AirWaveZone:new(objectToCopy)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWave:new()")
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self

  -- init the new object
  AirWaveZone.init(objectToCreate)

  return objectToCreate
end

function AirWaveZone:setName(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[]:setName(%s)", veaf.p(value))
  self.name = value
  return veafAirWaves.add(self) -- add the zone to the list as soon as a name is available to index it
end

function AirWaveZone:getName()
  return self.name or self.description
end

function AirWaveZone:setTriggerZone(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setTriggerZone(%s)", veaf.p(self.name), veaf.p(value))
  self.triggerZoneName = value
  local triggerZone = veaf.getTriggerZone(value)
  --veaf.loggers.get(veafAirWaves.Id):trace("triggerZone=%s", veaf.p(triggerZone))
  self:setZoneCenter({ x=triggerZone.x, y=triggerZone.y})
  self:setZoneRadius(triggerZone.radius)
  return self
end

function AirWaveZone:setZoneCenter(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setZoneCenter(%s)", veaf.p(self.name), veaf.p(value))
  self.zoneCenter = value
  return self
end

function AirWaveZone:setZoneCenterFromCoordinates(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setZoneCenterFromCoordinates(%s)", veaf.p(self.name), veaf.p(value))
  local _lat, _lon = veaf.computeLLFromString(value)
  --veaf.loggers.get(veafAirWaves.Id):trace("_lat=%s)", veaf.p(_lat))
  --veaf.loggers.get(veafAirWaves.Id):trace("_lon=%s)", veaf.p(_lon))
  local vec3 = coord.LLtoLO(_lat, _lon)
  --veaf.loggers.get(veafAirWaves.Id):trace("vec3=%s)", veaf.p(vec3))
  return self:setZoneCenter(vec3)
end

function AirWaveZone:setZoneRadius(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setZoneRadius(%s)", veaf.p(self.name), veaf.p(value))
  self.zoneRadius = value
  return self
end

function AirWaveZone:setDrawZone(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setDrawZone(%s)", veaf.p(self.name), veaf.p(value))
  self.drawZone = value or false
  return self
end

function AirWaveZone:setDescription(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setDescription(%s)", veaf.p(self.name), veaf.p(value))
  self.description = value
  return veafAirWaves.add(self) -- add the zone to the list as soon as a description is available to index it
end

function AirWaveZone:getDescription()
  return self.description or self.name
end

---add a wave of ennemy planes
---@param groups any a list of groups or VEAF commands; VEAF commands can be prefixed with [lat, lon], specifying the location of their spawn relative to the center of the zone; default value is set with "setRespawnDefaultOffset"
---@param number any how many of these groups will actually be spawned (can be multiple times the same group!)
---@param bias any shifts the random generator to the right of the list
---@return table self
function AirWaveZone:addRandomWave(groups, number, bias)
  veaf.loggers.get(veafAirWaves.Id):debug(string.format("VeafQRA[%s]:addRandomWave(%s, %s, %s)", veaf.p(self.name), veaf.p(groups), veaf.p(number), veaf.p(bias)))
  return self:addWave({groups, number or 1, bias or 0})
end

function AirWaveZone:addWave(wave)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:addWave(%s)", veaf.p(self.name), veaf.p(wave))
  if not self.waves then
    self.waves = {}
  end
  table.insert(self.waves, wave)
  return self
end

function AirWaveZone:setMessageStart(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageStart()", veaf.p(self.name))
  self.messageStart = value
  return self
end

---Set the onStart callback
---@param value function takes 2 parameters: the zone name (string), the monitored player units (table)
---@return table self
function AirWaveZone:setOnStart(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnStart()", veaf.p(self.name))
  self.onStart = value
  return self
end

function AirWaveZone:setMessageDeploy(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageDeploy()", veaf.p(self.name))
  self.messageDeploy = value
  return self
end

---Set the onDeploy callback
---@param value function takes 3 parameters: the zone name (string), the wave index (int), the monitored player units (table)
---@return table self
function AirWaveZone:setOnDeploy(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnDeploy()", veaf.p(self.name))
  self.onDeploy = value
  return self
end

function AirWaveZone:setMessageDestroyed(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageDestroyed()", veaf.p(self.name))
  self.messageDestroyed = value
  return self
end

---Set the onDestroyed callback
---@param value function takes 3 parameters: the zone name (string), the wave index (int), the monitored player units (table)
---@return table self
function AirWaveZone:setOnDestroyed(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnDestroyed()", veaf.p(self.name))
  self.onDestroyed = value
  return self
end

function AirWaveZone:setMessageWon(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageWon()", veaf.p(self.name))
  self.messageWon = value
  return self
end

---Set the onWon callback
---@param value function takes 2 parameters: the zone name (string), the monitored player units (table)
---@return table self
function AirWaveZone:setOnWon(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnWon()", veaf.p(self.name))
  self.onWon = value
  return self
end

function AirWaveZone:setMessageLost(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageLost()", veaf.p(self.name))
  self.messageLost = value
  return self
end

---Set the onLost callback
---@param value function takes 2 parameters: the zone name (string), the monitored player units (table)
---@return table self
function AirWaveZone:setOnLost(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnLost()", veaf.p(self.name))
  self.onLost = value
  return self
end

function AirWaveZone:setMessageStop(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageStop()", veaf.p(self.name))
  self.messageStop = value
  return self
end

---Set the onStop callback
---@param value function takes 2 parameters: the zone name (string), the monitored player units (table)
---@return table self
function AirWaveZone:setOnStop(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnStop()", veaf.p(self.name))
  self.onStop = value
  return self
end

function AirWaveZone:setSilent(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setSilent(%s)", veaf.p(self.name), veaf.p(value))
  self.silent = value or false
  return self
end

function AirWaveZone:setRespawnRadius(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setRespawnRadius(%s)", veaf.p(self.name), veaf.p(value))
  self.respawnRadius = value
  if self.respawnRadius < 250 then self.respawnRadius = 250 end
  return self
end

---set the default respawn offset (in meters, relative to the zone center)
---@param defaultOffsetLatitude any in meters
---@param defaultOffsetLongitude any in meters
---@return table self
function AirWaveZone:setRespawnDefaultOffset(defaultOffsetLatitude, defaultOffsetLongitude)
    veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setRespawnDefaultOffset(%s, %s)", veaf.p(self.name), veaf.p(defaultOffsetLatitude), veaf.p(defaultOffsetLongitude))
    self.respawnDefaultOffset = { latDelta = defaultOffsetLatitude, lonDelta = defaultOffsetLongitude}
    return self
end

function AirWaveZone:addPlayerCoalition(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:addPlayerCoalition(%s)", veaf.p(self.name), veaf.p(value))
  self.playerCoalitions[value] = value
  return self
end

function AirWaveZone:getPlayerCoalition()
  local result = nil
  for coalition, _ in pairs(self.playerCoalitions) do
    result = coalition
    break
  end
  return result
end

function AirWaveZone:setDelayBeforeNextWave(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setDelayBeforeNextWave(%s)", veaf.p(self.name), veaf.p(value))
  self.delayBeforeNextWave = value
  return self
end

function AirWaveZone:setResetWhenDying()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setResetWhenDying()", veaf.p(self.name))
  self.resetWhenDying = true
  return self
end

function AirWaveZone:setMinimumAltitudeInFeet(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMinimumAltitudeInFeet(%s)", veaf.p(self.name), veaf.p(value))
  self.minimumAltitude = value * 0.3048 -- convert from feet
  return self
end

function AirWaveZone:getMinimumAltitudeInMeters()
  return self.minimumAltitude
end

function AirWaveZone:setMaximumAltitudeInFeet(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMaximumAltitudeInFeet(%s)", veaf.p(self.name), veaf.p(value))
  self.maximumAltitude = value * 0.3048 -- convert from feet
  return self
end

function AirWaveZone:getMaximumAltitudeInMeters()
  return self.maximumAltitude
end

function AirWaveZone:_setState(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:_setState(%s)", veaf.p(self.name), veaf.p(veafAirWaves.statusToString(value)))
  self.state = value
  return self
end

function AirWaveZone:reset()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:reset()", veaf.p(self.name))
  -- no more players, reset the players list
  self.playerUnitsNames = {}
  -- despawn the ennemies
  self:destroyCurrentWave()
  -- reset the wave index
  self.currentWaveIndex = 0

  return self
end

function AirWaveZone:getPlayerUnits()
  if not self.playerHumanUnits then
    --veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:getPlayerUnits() - computing", veaf.p(self.name))
    self.playerHumanUnits = {}
    --veaf.loggers.get(veafAirWaves.Id):trace("playerCoalitions[]=%s", veaf.p(self.playerCoalitions))
    for _, unit in pairs(mist.DBs.humansByName) do
      --veaf.loggers.get(veafAirWaves.Id):trace("unit.unitName=%s", unit.unitName)
      --veaf.loggers.get(veafAirWaves.Id):trace("unit.groupName=%s", unit.groupName)
      --veaf.loggers.get(veafAirWaves.Id):trace("unit.coalition=%s", veaf.p(unit.coalition))
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
          --veaf.loggers.get(veafAirWaves.Id):trace("unit.category=%s", unit.category)
          if unit.category == "plane" then
            veaf.loggers.get(veafAirWaves.Id):trace("adding player unit to zone: %s", unit.unitName)
            table.insert(self.playerHumanUnits, unit.unitName)
          end
        end
      end
    end
  end
  return self.playerHumanUnits
end

function AirWaveZone:check()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:check()", veaf.p(self.name))
  veaf.loggers.get(veafAirWaves.Id):debug("self.state=%s", veaf.p(veafAirWaves.statusToString(self.state)))
  veaf.loggers.get(veafAirWaves.Id):trace("timer.getTime()=%s", veaf.p(timer.getTime()))

  -- whatever the state, monitor the player units if they're defined
  --veaf.loggers.get(veafAirWaves.Id):trace("self.playerUnitsNames=%s", veaf.p(self.playerUnitsNames))
  if self.playerUnitsNames and #self.playerUnitsNames > 0 then
    local atLeastOnePlayerAlive = false
    local atLeastOnePlayerAirborne = false
    for _, _unitName in pairs(self.playerUnitsNames) do
      --veaf.loggers.get(veafAirWaves.Id):trace("_unitName=%s", veaf.p(_unitName))
      local _unit = Unit.getByName(_unitName)
      --veaf.loggers.get(veafAirWaves.Id):trace("_unit=%s", veaf.p(_unit))
      if _unit then 
        atLeastOnePlayerAlive = true
        if _unit:inAir() then
          atLeastOnePlayerAirborne = true
        end
      end
    end
    if not (atLeastOnePlayerAlive and atLeastOnePlayerAirborne) then
      veaf.loggers.get(veafAirWaves.Id):debug("player is dead or despawned in %s", veaf.p(self:getName()))
      if self.state ~= veafAirWaves.STATUS_OVER then
        -- signal that all players have been destroyed
        self:signalLost()
      end
      if self.resetWhenDying then
        self:signalStop()
        -- reset the zone
        self:reset()
        -- zone is ready for the next players
        self:_setState(veafAirWaves.STATUS_READY)
      end
    end
  end

  if self.state == veafAirWaves.STATUS_READY then
    -- zone is ready, check for players entering
    self.playerUnitsNames = {}
    local unitNames = self:getPlayerUnits()
    --veaf.loggers.get(veafAirWaves.Id):trace("unitNames=%s", veaf.p(unitNames))
    local unitsInZone = nil
    local triggerZone = veaf.getTriggerZone(self.triggerZoneName)
    if triggerZone then
      --veaf.loggers.get(veafAirWaves.Id):trace("triggerZone=%s", veaf.p(triggerZone))
      if triggerZone.type == 0 then -- circular
        unitsInZone = mist.getUnitsInZones(unitNames, {self.triggerZoneName})
      elseif triggerZone.type == 2 then -- quad point
        --veaf.loggers.get(veafAirWaves.Id):trace("checking in polygon %s", veaf.p(triggerZone.verticies))
        unitsInZone = mist.getUnitsInPolygon(unitNames, triggerZone.verticies)
      end
    else
      --veaf.loggers.get(veafAirWaves.Id):trace("self.zoneCenter=%s", veaf.p(self.zoneCenter))
      --veaf.loggers.get(veafAirWaves.Id):trace("self.zoneRadius=%s", veaf.p(self.zoneRadius))
      --veaf.loggers.get(veafAirWaves.Id):trace("unitNames=%s", veaf.p(unitNames))
      unitsInZone = veaf.findUnitsInCircle(self.zoneCenter, self.zoneRadius, false, unitNames)
    end
    local nbUnitsInZone = 0
    for _, unit in pairs(unitsInZone) do
      -- check the unit altitude against the ceiling and floor
      if unit:inAir() then -- never count a landed aircraft
        local alt = unit:getPoint().y
        --veaf.loggers.get(veafAirWaves.Id):trace("check the unit altitude against the ceiling and floor")
        --veaf.loggers.get(veafAirWaves.Id):trace("alt=%s", veaf.p(alt))
        --veaf.loggers.get(veafAirWaves.Id):trace("self:getMinimumAltitudeInMeters()=%s", veaf.p(self:getMinimumAltitudeInMeters()))
        --veaf.loggers.get(veafAirWaves.Id):trace("self:getMaximumAltitudeInMeters()=%s", veaf.p(self:getMaximumAltitudeInMeters()))
        if alt >= self:getMinimumAltitudeInMeters() and alt <= self:getMaximumAltitudeInMeters() then
          nbUnitsInZone = nbUnitsInZone + 1
          -- add the unit to the player units list, so that we can monitor it
          table.insert(self.playerUnitsNames, unit:getName())
        end
      end
    end
    --veaf.loggers.get(veafAirWaves.Id):trace("unitsInZone=%s", veaf.p(unitsInZone))
    --veaf.loggers.get(veafAirWaves.Id):trace("#unitsInZone=%s", veaf.p(#unitsInZone))
    veaf.loggers.get(veafAirWaves.Id):trace("nbUnitsInZone=%s", veaf.p(nbUnitsInZone))
    if unitsInZone and nbUnitsInZone > 0 then
      -- reset wave index
      self.currentWaveIndex = 0
      self:_setState(veafAirWaves.STATUS_NEXTWAVE)
    end
  elseif self.state == veafAirWaves.STATUS_NEXTWAVE then
    -- wave has been destroyed, or it's the first time a wave has to be deployed; check if there is a next one and deploy it
    --veaf.loggers.get(veafAirWaves.Id):trace("self.currentWaveIndex=%s", veaf.p(self.currentWaveIndex))
    --veaf.loggers.get(veafAirWaves.Id):trace("#self.waves=%s", veaf.p(#self.waves))
    if self.currentWaveIndex < #self.waves then
      self.currentWaveIndex = self.currentWaveIndex + 1
      if self:deployWave() then
        self:_setState(veafAirWaves.STATUS_ACTIVE)
      end
    else
      self:signalWon()
      self:_setState(veafAirWaves.STATUS_OVER)
    end
  elseif self.state == veafAirWaves.STATUS_ACTIVE then
    -- zone is active, check if the current wave is still alive
    local currentWaveAlive = false
    local currentWaveInAir = false
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
              if unitLifePercent >= veafAirWaves.MINIMUM_LIFE_FOR_AI_IN_PERCENT then
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
        currentWaveAlive = currentWaveAlive or groupAtLeastOneUnitAlive
        currentWaveInAir = currentWaveInAir or groupAtLeastOneUnitInAir
        veaf.loggers.get(veafAirWaves.Id):trace("qraAlive=%s", veaf.p(currentWaveAlive))
        veaf.loggers.get(veafAirWaves.Id):trace("qraInAir=%s", veaf.p(currentWaveInAir))
      end
    end
    if not (currentWaveAlive and currentWaveInAir) then
      -- signal that wave has been destroyed
      self:signalDestroyed()
      -- prepare next wave
      self:_setState(veafAirWaves.STATUS_NEXTWAVE)
    end
  elseif self.state == veafAirWaves.STATUS_OVER then
    -- zone has still to be reset to restart
  end

  mist.scheduleFunction(AirWaveZone.check, {self}, timer.getTime() + veafAirWaves.WATCHDOG_DELAY)
end

function AirWaveZone:chooseGroupsToDeploy()
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:chooseGroupsToDeploy()", veaf.p(self.name))

  local groupsToDeploy = nil
  if self.currentWaveIndex <= #self.waves then
    groupsToDeploy = self.waves[self.currentWaveIndex]
  end
  if groupsToDeploy then
    -- process a random group definition
    local groupsToChooseFrom = groupsToDeploy[1]
    local numberOfGroups = groupsToDeploy[2]
    local bias = groupsToDeploy[3]
    --veaf.loggers.get(veafAirWaves.Id):trace("groupsToChooseFrom=%s", veaf.p(groupsToChooseFrom))
    --veaf.loggers.get(veafAirWaves.Id):trace("numberOfGroups=%s", veaf.p(numberOfGroups))
    --veaf.loggers.get(veafAirWaves.Id):trace("bias=%s", veaf.p(bias))
    if groupsToChooseFrom and type(groupsToChooseFrom) == "table" and numberOfGroups and type(numberOfGroups) == "number" and bias and type(bias) == "number" then
      local result = {}
      for _ = 1, numberOfGroups do
        local group = veaf.randomlyChooseFrom(groupsToChooseFrom, bias)
        veaf.loggers.get(veafAirWaves.Id):trace("group=%s", veaf.p(group))
        table.insert(result, group)
      end
      groupsToDeploy = result
    end
  end
  return groupsToDeploy
end

function AirWaveZone:deployWave()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:deployWave()", veaf.p(self.name))

  local groupsToDeploy = self:chooseGroupsToDeploy()
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
          --veaf.loggers.get(veafAirWaves.Id):trace("coords=%s", veaf.p(coords))
          --veaf.loggers.get(veafAirWaves.Id):trace("command=%s", veaf.p(command))
          if coords then
            latDelta, lonDelta = coords:match("([%+-%d]+),%s*([%+-%d]+)")
          end
        end
        veaf.loggers.get(veafAirWaves.Id):debug("running command [%s]", veaf.p(command))
        --veaf.loggers.get(veafAirWaves.Id):trace("latDelta = [%s]", veaf.p(latDelta))
        --veaf.loggers.get(veafAirWaves.Id):trace("lonDelta = [%s]", veaf.p(lonDelta))
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
        veaf.loggers.get(veafAirWaves.Id):debug("spawning group [%s]", veaf.p(groupName))
        local group = Group.getByName(groupName)
        if not group then
          veaf.loggers.get(veafAirWaves.Id):error("group [%s] does not exist in the mission!", veaf.p(groupName))
        else
          veaf.loggers.get(veafAirWaves.Id):debug("group=%s", veaf.p(group))
          veaf.loggers.get(veafAirWaves.Id):debug("group:getUnits()=%s", veaf.p(group:getUnits()))
          local spawnSpot = {x = zoneCenter.x - self.respawnDefaultOffset.lonDelta, y = zoneCenter.y, z = zoneCenter.z + self.respawnDefaultOffset.latDelta}
          -- Try and set the spawn spot at the place the group has been set in the Mission Editor.
          -- Unfortunately this is sometimes not possible because DCS is not returning the group units for some reason.
          -- When this happens we'll default to the default spawn offset (same as spawning with VEAF commands)
          if not group:getUnit(1) then
            veaf.loggers.get(veafAirWaves.Id):warn("group [%s] does not have any unit!", veaf.p(groupName))
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
    veaf.loggers.get(veafAirWaves.Id):trace("self.spawnedGroupsNames=%s", veaf.p(self.spawnedGroupsNames))
    self:_setState(veafAirWaves.STATUS_ACTIVE)
  end
  self:signalDeploy()
  return (self.spawnedGroupsNames and #self.spawnedGroupsNames > 0)
end

function AirWaveZone:signalStart()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalStart()", veaf.p(self.name))
  if not self.silent then
    local msg = string.format(self.messageStart, self:getDescription())
    for coalition, _ in pairs(self.playerCoalitions) do
      trigger.action.outTextForCoalition(coalition, msg, 15)
    end
  end
  if self.onStart then
    veaf.loggers.get(veafAirWaves.Id):trace("self.playerHumanUnits=%s", veaf.p(self.playerHumanUnits))
    self.onStart(self.name, self.playerUnitsNames)
  end
end

function AirWaveZone:signalDeploy()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalDeploy()", veaf.p(self.name))
  if not self.silent then
    local msg = string.format(self.messageDeploy, self:getDescription(), self.currentWaveIndex)
    for coalition, _ in pairs(self.playerCoalitions) do
      trigger.action.outTextForCoalition(coalition, msg, 15)
    end
  end
  if self.onDeploy then
    self.onDeploy(self.name, self.currentWaveIndex, self.playerUnitsNames)
  end
end

function AirWaveZone:signalDestroyed()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalDestroyed()", veaf.p(self.name))
  if not self.silent then
    local msg = string.format(self.messageDestroyed, self:getDescription(), self.currentWaveIndex)
    for coalition, _ in pairs(self.playerCoalitions) do
      trigger.action.outTextForCoalition(coalition, msg, 15)
    end
  end
  if self.onDestroyed then
    self.onDestroyed(self.name, self.currentWaveIndex, self.playerUnitsNames)
  end
end

function AirWaveZone:signalWon()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalWon()", veaf.p(self.name))
  if not self.silent then
    local msg = string.format(self.messageWon, self:getDescription())
    for coalition, _ in pairs(self.playerCoalitions) do
      trigger.action.outTextForCoalition(coalition, msg, 15)
    end
  end
  if self.onWon then
    self.onWon(self.name, self.playerUnitsNames)
  end
end

function AirWaveZone:signalLost()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalLost()", veaf.p(self.name))
  if not self.silent then
    local msg = string.format(self.messageLost, self:getDescription())
    for coalition, _ in pairs(self.playerCoalitions) do
      trigger.action.outTextForCoalition(coalition, msg, 15)
    end
  end
  if self.onLost then
    self.onLost(self.name, self.playerUnitsNames)
  end
end

function AirWaveZone:signalStop()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalStop()", veaf.p(self.name))
  if not self.silent then
    local msg = string.format(self.messageStop, self:getDescription())
    for coalition, _ in pairs(self.playerCoalitions) do
      trigger.action.outTextForCoalition(coalition, msg, 15)
    end
  end
  if self.onStop then
    self.onStop(self.name, self.playerUnitsNames)
  end
end

function AirWaveZone:start()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:start()", veaf.p(self.name))
  self:_setState(veafAirWaves.STATUS_READY)
  self:check()

  -- draw the zone
  if self.drawZone then
    if self.triggerZoneName then
      self.zoneDrawing = mist.marker.drawZone(self.triggerZoneName, {message=self:getDescription(), readOnly=true})
    else
      self.zoneDrawing = VeafCircleOnMap:new()
      :setName(self:getName())
      :setCoalition(self:getPlayerCoalition())
      :setCenter(self.zoneCenter)
      :setRadius(self.zoneRadius)
      :setLineType("dashed")
      :setColor("white")
      :setFillColor("transparent")
      :draw()
    end
  end

  self:signalStart()
  return self
end

function AirWaveZone:stop()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:stop()", veaf.p(self.name))
  self:reset()
  self:_setState(veafAirWaves.STATUS_STOP)

  -- erase the zone
  if self.zoneDrawing then
    if self.triggerZoneName then
      mist.marker.remove(self.zoneDrawing.markId)
    else
      self.zoneDrawing:erase()
    end
    self.zoneDrawing = nil
  end

  self:signalStop()
  return self
end

function AirWaveZone:destroyCurrentWave()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:destroyCurrentWave()", veaf.p(self.name))
  if self.spawnedGroupsNames then
    for _, _groupName in pairs(self.spawnedGroupsNames) do
      local _group = Group.getByName(_groupName)
      if _group then
        _group:destroy()
      end
    end
  end
  self.spawnedGroupsNames = {}
  return self
end



-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafAirWaves.add(aWaveZone, aName)
  local name = aName or aWaveZone:getName()
  veafAirWaves.zones[name] = aWaveZone
  return aWaveZone
end

function veafAirWaves.get(aNameString)
  return veafAirWaves.zones[aNameString]
end

veaf.loggers.get(veafAirWaves.Id):info(string.format("Loading version %s", veafAirWaves.Version))