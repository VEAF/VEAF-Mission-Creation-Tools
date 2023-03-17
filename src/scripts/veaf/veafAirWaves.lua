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
veafAirWaves.Version = "1.0.2"

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

AirWaveZone = {
  -- technical name (AirWave instance name)
  name = nil,
  -- description for the briefing
  description = nil,
  -- trigger zone name (if set, we'll use a DCS trigger zone)
  triggerZoneName = nil,
  -- center (point in the center of the circle, when not using a DCS trigger zone)
  zoneCenter = nil,
  -- radius (size of the circle, when not using a zone)
  zoneRadius = nil,
  -- radius of the waves groups spawn
  respawnRadius = 250,
  -- coalitions of the players
  playerCoalitions = {},
  -- player units (if they die, reset the zone)
  playerUnitsNames = {},
  -- aircraft groups forming the waves
  waves = {},
  -- groups that have been spawned (the current wave)
  spawnedGroupsNames = {},
  -- silent means no message is emitted
  silent = false,
  -- message when the zone is activated
  messageStart = veafAirWaves.DEFAULT_MESSAGE_START,
  -- event when the zone is activated
  onStart = nil,
  -- message when a wave is triggered
  messageDeploy = veafAirWaves.DEFAULT_MESSAGE_DEPLOY,
  -- event  when a wave is triggered
  onDeploy = nil,
  -- message when a wave is destroyed
  messageDestroyed = veafAirWaves.DEFAULT_MESSAGE_DESTROYED,
  -- event when a wave is destroyed
  onDestroyed = nil,
  -- message when all waves are finished
  messageWon = veafAirWaves.DEFAULT_MESSAGE_WON,
  -- event when all waves are finished
  onWon = nil,
  -- message when all players are dead
  messageLost = veafAirWaves.DEFAULT_MESSAGE_LOST,
  -- event when all players are dead
  onLost = nil,
  -- message when the zone is deactivated
  messageStop = veafAirWaves.DEFAULT_MESSAGE_STOP,
  -- event when the zone is deactivated
  onStop = nil,
  -- delay in seconds between waves of ennemy planes
  delayBetweenWaves = 0,
  -- if true, the zone will reset when player dies
  resetWhenDying = true,
  -- human units that are being watched
  playerHumanUnits = nil,
  -- players in the zone will only be detected below this altitude (in feet)
  minimumAltitude = 999999,
  -- players in the zone will only be detected above this altitude (in feet)
  maximumAltitude = 0,
  -- current wave number
  currentWaveIndex = 0
}

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

veafAirWaves.DEFAULT_MESSAGE_START = "AirWaves zone %s is online"
veafAirWaves.DEFAULT_MESSAGE_DEPLOY = "AirWaves zone %s is deploying wave %s"
veafAirWaves.DEFAULT_MESSAGE_DESTROYED = "AirWaves zone %s: wave %s has been destroyed"
veafAirWaves.DEFAULT_MESSAGE_WON = "AirWaves zone %s is over (no more waves)"
veafAirWaves.DEFAULT_MESSAGE_LOST = "AirWaves zone %s is lost (no more players)"
veafAirWaves.DEFAULT_MESSAGE_STOP = "AirWaves zone %s is offline"

function AirWaveZone:new(objectToCopy)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWave:new()")
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self
  
  -- init the new object
  
  -- technical name (AirWave instance name)
  objectToCreate.name = nil
  -- description for the briefing
  objectToCreate.description = nil
  -- trigger zone name (if set, we'll use a DCS trigger zone)
  objectToCreate.triggerZoneCenter = nil
  -- center (point in the center of the circle, when not using a DCS trigger zone)
  objectToCreate.zoneCenter = nil
  -- radius (size of the circle, when not using a zone)
  objectToCreate.zoneRadius = nil
  -- radius of the waves groups spawn
  objectToCreate.respawnRadius = 250
  -- coalitions of the players
  objectToCreate.playerCoalitions = {}
  -- player units (if they die, reset the zone)
  objectToCreate.playerUnitsNames = {}
  -- aircraft groups forming the waves
  objectToCreate.waves = {}
  -- groups that have been spawned (the current wave)
  objectToCreate.spawnedGroupsNames = {}
  -- silent means no message is emitted
  objectToCreate.silent = false
  -- message when the zone is activated
  objectToCreate.messageStart = veafAirWaves.DEFAULT_MESSAGE_START
  -- event when the zone is activated
  objectToCreate.onStart = nil
  -- message when a wave is triggered
  objectToCreate.messageDeploy = veafAirWaves.DEFAULT_MESSAGE_DEPLOY
  -- event  when a wave is triggered
  objectToCreate.onDeploy = nil
  -- message when a wave is destroyed
  objectToCreate.messageDestroyed = veafAirWaves.DEFAULT_MESSAGE_DESTROYED
  -- event when a wave is destroyed
  objectToCreate.onDestroyed = nil
  -- message when all waves are finished
  objectToCreate.messageWon = veafAirWaves.DEFAULT_MESSAGE_WON
  -- event when all waves are finished
  objectToCreate.onWon = nil
  -- message when all players are dead
  objectToCreate.messageLost = veafAirWaves.DEFAULT_MESSAGE_LOST
  -- event when all players are dead
  objectToCreate.onLost = nil
  -- message when the zone is deactivated
  objectToCreate.messageStop = veafAirWaves.DEFAULT_MESSAGE_STOP
  -- event when the zone is deactivated
  objectToCreate.onStop = nil
  -- delay in seconds between waves of ennemy planes
  objectToCreate.delayBetweenWaves = 0
  -- if true, the zone will reset when player dies
  objectToCreate.resetWhenDying = true
  -- human units that are being watched
  objectToCreate.playerHumanUnits = nil
  -- players in the zone will only be detected below this altitude (in feet)
  objectToCreate.minimumAltitude = -9999999
  -- players in the zone will only be detected above this altitude (in feet)
  objectToCreate.maximumAltitude = 9999999
  -- current wave number
  objectToCreate.currentWaveIndex = 0

  return objectToCreate
end

function AirWaveZone:setName(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[]:setName(%s)", veaf.p(value))
  self.name = value
  return veafAirWaves.add(self) -- add the zone to the list as soon as a name is available to index it
end

function AirWaveZone:getName()
  return self.name or self.description
end

function AirWaveZone:setTriggerZone(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setTriggerZone(%s)", veaf.p(self.name), veaf.p(value))
  self.triggerZoneName = value
  local triggerZone = veaf.getTriggerZone(value)
  veaf.loggers.get(veafAirWaves.Id):trace("triggerZone=%s", veaf.p(triggerZone))
  self:setZoneCenter({ x=triggerZone.x, y=triggerZone.y})
  self:setZoneRadius(triggerZone.radius)
  return self
end

function AirWaveZone:setZoneCenter(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setZoneCenter(%s)", veaf.p(self.name), veaf.p(value))
  self.zoneCenter = value
  return self
end

function AirWaveZone:setZoneCenterFromCoordinates(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setZoneCenterFromCoordinates(%s)", veaf.p(self.name), veaf.p(value))
  local _lat, _lon = veaf.computeLLFromString(value)
  veaf.loggers.get(veafAirWaves.Id):trace("_lat=%s)", veaf.p(_lat))
  veaf.loggers.get(veafAirWaves.Id):trace("_lon=%s)", veaf.p(_lon))
  local vec3 = coord.LLtoLO(_lat, _lon)
  veaf.loggers.get(veafAirWaves.Id):trace("vec3=%s)", veaf.p(vec3))
  return self:setZoneCenter(vec3)
end

function AirWaveZone:setZoneRadius(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setZoneRadius(%s)", veaf.p(self.name), veaf.p(value))
  self.zoneRadius = value
  return self
end

function AirWaveZone:setDescription(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setDescription(%s)", veaf.p(self.name), veaf.p(value))
  self.description = value
  return veafAirWaves.add(self) -- add the zone to the list as soon as a description is available to index it
end

function AirWaveZone:getDescription()
  return self.description or self.name
end

function AirWaveZone:addRandomWave(groups, number, bias)
  veaf.loggers.get(veafAirWaves.Id):trace(string.format("VeafQRA[%s]:addRandomWave(%s, %s, %s)", veaf.p(self.name), veaf.p(groups), veaf.p(number), veaf.p(bias)))
  return self:addWave({groups, number or 1, bias or 0})
end

function AirWaveZone:addWave(wave)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:addWave(%s)", veaf.p(self.name), veaf.p(wave))
  if not self.waves then
    self.waves = {}
  end
  table.insert(self.waves, wave)
  return self
end

function AirWaveZone:setMessageStart(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setMessageStart(%s)", veaf.p(self.name), veaf.p(value))
  self.messageStart = value
  return self
end

function AirWaveZone:setOnStart(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setOnStart()", veaf.p(self.name))
  self.onStart = value
  return self
end

function AirWaveZone:setMessageDeploy(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setMessageDeploy(%s)", veaf.p(self.name), veaf.p(value))
  self.messageDeploy = value
  return self
end

function AirWaveZone:setOnDeploy(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setOnDeploy()", veaf.p(self.name))
  self.onDeploy = value
  return self
end

function AirWaveZone:setMessageDestroyed(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setMessageDestroyed(%s)", veaf.p(self.name), veaf.p(value))
  self.messageDestroyed = value
  return self
end

function AirWaveZone:setOnDestroyed(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setOnDestroyed()", veaf.p(self.name))
  self.onDestroyed = value
  return self
end

function AirWaveZone:setMessageWon(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setMessageWon(%s)", veaf.p(self.name), veaf.p(value))
  self.messageWon = value
  return self
end

function AirWaveZone:setOnWon(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setOnWon()", veaf.p(self.name))
  self.onWon = value
  return self
end

function AirWaveZone:setMessageStop(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setMessageStop(%s)", veaf.p(self.name), veaf.p(value))
  self.messageStop = value
  return self
end

function AirWaveZone:setOnStop(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setOnStop()", veaf.p(self.name))
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
  
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setSilent(%s)", veaf.p(self.name), veaf.p(vSilent))
  self.silent = pSilent
  return self
end

function AirWaveZone:setRespawnRadius(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setRespawnRadius(%s)", veaf.p(self.name), veaf.p(value))
  self.respawnRadius = value
  if self.respawnRadius < 250 then self.respawnRadius = 250 end
  return self
end

function AirWaveZone:addPlayerCoalition(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:addPlayerCoalition(%s)", veaf.p(self.name), veaf.p(value))
  self.playerCoalitions[value] = value
  return self
end

function AirWaveZone:setDelayBeforeNextWave(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setDelayBeforeNextWave(%s)", veaf.p(self.name), veaf.p(value))
  self.delayBeforeNextWave = value
  return self
end

function AirWaveZone:setResetWhenDying()
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setResetWhenDying()", veaf.p(self.name))
  self.resetWhenDying = true
  return self
end

function AirWaveZone:setMinimumAltitudeInFeet(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setMinimumAltitudeInFeet(%s)", veaf.p(self.name), veaf.p(value))
  self.minimumAltitude = value * 0.3048 -- convert from feet
  return self
end

function AirWaveZone:getMinimumAltitudeInMeters()
  return self.minimumAltitude
end

function AirWaveZone:setMaximumAltitudeInFeet(value)
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:setMaximumAltitudeInFeet(%s)", veaf.p(self.name), veaf.p(value))
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
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:check()", veaf.p(self.name))
  veaf.loggers.get(veafAirWaves.Id):trace("self.state=%s", veaf.p(veafAirWaves.statusToString(self.state)))
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
      -- signal that all players have been destroyed
      self:signalLost()
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
      unitsInZone = veaf.findUnitsInCircle(self.zoneCenter, self.zoneRadius, false, unitNames)
    end
    local nbUnitsInZone = 0
    for _, unit in pairs(unitsInZone) do
      -- check the unit altitude against the ceiling and floor
      if unit:inAir() then -- never count a landed aircraft
        local alt = unit:getPoint().y
        --veaf.loggers.get(veafAirWaves.Id):trace("check the unit altitude against the ceiling and floor")
        --veaf.loggers.get(veafAirWaves.Id):trace("alt=%s", veaf.p(alt))
        if alt >= self:getMinimumAltitudeInMeters() and alt <= self:getMaximumAltitudeInMeters() then
          nbUnitsInZone = nbUnitsInZone + 1
          -- add the unit to the player units list, so that we can monitor it
          table.insert(self.playerUnitsNames, unit:getName())
        end
      end
    end
    --veaf.loggers.get(veafAirWaves.Id):trace("unitsInZone=%s", veaf.p(unitsInZone))
    veaf.loggers.get(veafAirWaves.Id):trace("#unitsInZone=%s", veaf.p(#unitsInZone))
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
    local inAir = false
    for _, groupName in pairs(self.spawnedGroupsNames) do
      local group = Group.getByName(groupName)
      if group then
        currentWaveAlive = true
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
    if not (currentWaveAlive and inAir) then
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
    veaf.loggers.get(veafAirWaves.Id):trace("groupsToChooseFrom=%s", veaf.p(groupsToChooseFrom))
    veaf.loggers.get(veafAirWaves.Id):trace("numberOfGroups=%s", veaf.p(numberOfGroups))
    veaf.loggers.get(veafAirWaves.Id):trace("bias=%s", veaf.p(bias))
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

  if not self.silent then
    local msg = string.format(self.messageDeploy, self:getDescription(), self.currentWaveIndex)
    for coalition, _ in pairs(self.playerCoalitions) do
      trigger.action.outTextForCoalition(coalition, msg, 15)
    end
  end
  local groupsToDeploy = self:chooseGroupsToDeploy()
  self.spawnedGroupsNames = {}
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
      if newGroup then
        table.insert(self.spawnedGroupsNames, newGroup.name)
      end
    end
    --veaf.loggers.get(veafAirWaves.Id):trace("self.spawnedGroupsNames=%s", veaf.p(self.spawnedGroupsNames))
    self:_setState(veafAirWaves.STATUS_ACTIVE)
  end
  if self.onDeploy then
    self.onDeploy()
  end
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
    self.onStart()
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
    self.onDeploy()
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
    self.onDestroyed()
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
    self.onWon()
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
    self.onLost()
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
    self.onStop()
  end
end

function AirWaveZone:start()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:start()", veaf.p(self.name))
  self:_setState(veafAirWaves.STATUS_READY)
  self:check()
  self:signalStart()
  return self
end

function AirWaveZone:stop()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:stop()", veaf.p(self.name))
  self:reset()
  self:_setState(veafAirWaves.STATUS_STOP)
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