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
veafAirWaves.Id = "AIRWAVES"

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
  object.respawnDefaultOffset = { latDelta = 0, lonDelta = 0 }
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
  -- message when the zone is waiting for more players
  object.messageWaitForHumans = veafAirWaves.DEFAULT_MESSAGE_WAIT_FOR_HUMANS
  -- event when the zone is waiting for more players
  object.onWaitForHumans = nil
  -- message when a wave will be triggered
  object.messageWaitToDeploy = veafAirWaves.DEFAULT_MESSAGE_WAIT_TO_DEPLOY
  -- event when a wave will be triggered
  object.onWaitToDeploy = nil
  -- message when a wave is triggered
  object.messageDeploy = veafAirWaves.DEFAULT_MESSAGE_DEPLOY
  -- message to each players in the zone when a wave is triggered
  object.messageDeployPlayers = veafAirWaves.DEFAULT_MESSAGE_DEPLOY_PLAYERS
  -- event when a wave is triggered
  object.onDeploy = nil
  -- message when a player is outside of zone
  object.messageOutsideOfZone = veafAirWaves.DEFAULT_MESSAGE_OUTSIDE_OF_ZONE_PLAYERS
  -- event when a player is outside of zone
  object.onOutsideOfZone = nil
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
  -- default delay in seconds between waves of enemy planes
  object.delayBetweenWaves = 0
  -- the delay after this wave, and before the next one (either set in the wave definition, or it's the default delayBetweenWaves)
  object.delayBeforeNextWave = nil
  -- the time when the next wave is supposed to spawn (used to know when to actually spawn when in the STATUS_WAITING_FOR_NEXTWAVE state)
  object.timeOfNextWave = nil
  -- delay in seconds between the first human in zone and the actual activation of the zone
  object.delayBeforeActivation = 0
  -- the time when the zones is supposed to be activated (used to know when to actually activate when in the STATUS_WAITING_FOR_MORE_HUMANS state)
  object.timeOfActivation = nil
  -- if true, the zone will reset when player dies
  object.resetWhenDying = true
  -- human units that are being watched
  object.playerHumanUnits = nil
  -- names of the human units that are being watched
  object.playerHumanUnitsNames = nil
  -- IA units that are being watched
  object.unitsInZone = {}
  -- players in the zone will only be detected below this altitude (in feet)
  object.minimumAltitude = -999999
  -- players in the zone will only be detected above this altitude (in feet)
  object.maximumAltitude = 999999
  -- players staying out of the zone for more that this number of seconds will be destroyed
  object.maxSecondsOutsideOfZonePlayers = veafAirWaves.MAX_SECONDS_OUTSIDE_OF_ZONE_PLAYERS
  -- IA staying out of the zone for more that this number of seconds will be destroyed
  object.maxSecondsOutsideOfZoneIA = veafAirWaves.MAX_SECONDS_OUTSIDE_OF_ZONE_IA
  -- the function that decides if a wave is dead or not (as a set of groups and units)
  object.isEnemyWaveDeadCallback = AirWaveZone.isEnemyWaveDead
  -- the function that decides if IA ennemy groups are dead (individually)
  object.isEnemyGroupDeadCallback = AirWaveZone.isEnemyGroupDead
  -- the minimum percentage of life that an AI unit is supposed to have to be considered alive
  object.minimumLifeForAiInPercent = veafAirWaves.MINIMUM_LIFE_FOR_AI_IN_PERCENT
  -- the function that handles crippled enemy units
  object.handleCrippledEnemyUnitCallback = AirWaveZone.handleCrippledEnemyUnit
  -- current wave number
  object.currentWaveIndex = 0
  -- the drawing object that has been used to draw the zone
  object.zoneDrawing = nil
  -- the scheduled state of the :check() function
  object.checkFunctionSchedule = nil
  -- the time humans exited the zone
  object.timestampsOutOfZone = {}
end

veafAirWaves.STATUS_STOP = 0
veafAirWaves.STATUS_READY = 1
veafAirWaves.STATUS_WAITING_FOR_MORE_HUMANS = 1.5
veafAirWaves.STATUS_ACTIVE = 2
veafAirWaves.STATUS_WAITING_FOR_NEXTWAVE = 2.5
veafAirWaves.STATUS_NEXTWAVE = 3
veafAirWaves.STATUS_OVER = 4

function veafAirWaves.statusToString(status)
  return veaf.enumToString(status, {
    [veafAirWaves.STATUS_STOP] = "STATUS_STOP",
    [veafAirWaves.STATUS_READY] = "STATUS_READY",
    [veafAirWaves.STATUS_WAITING_FOR_MORE_HUMANS] = "STATUS_WAITING_FOR_MORE_HUMANS",
    [veafAirWaves.STATUS_ACTIVE] = "STATUS_ACTIVE",
    [veafAirWaves.STATUS_WAITING_FOR_NEXTWAVE] = "STATUS_WAITING_FOR_NEXTWAVE",
    [veafAirWaves.STATUS_NEXTWAVE] = "STATUS_NEXTWAVE",
    [veafAirWaves.STATUS_OVER] = "STATUS_OVER",
  })
end

veafAirWaves.MINIMUM_LIFE_FOR_AI_IN_PERCENT = 0

veafAirWaves.MAX_SECONDS_OUTSIDE_OF_ZONE_PLAYERS = nil -- no outside of zone mechanism by default for players
veafAirWaves.MAX_SECONDS_OUTSIDE_OF_ZONE_IA = 30
-- Default messages are i18n catalog keys (see veafI18n.lua), resolved through
-- veaf.t() at send time so they localize to the mission language; a mission
-- overriding them with its own literal keeps it verbatim (veaf.t() returns an
-- unknown key unchanged before formatting).
veafAirWaves.DEFAULT_MESSAGE_START = "airwaves.msg_start"
veafAirWaves.DEFAULT_MESSAGE_WAIT_FOR_HUMANS = "airwaves.msg_wait_for_humans"
veafAirWaves.DEFAULT_MESSAGE_WAIT_TO_DEPLOY = "airwaves.msg_wait_to_deploy"
veafAirWaves.DEFAULT_MESSAGE_DEPLOY = "airwaves.msg_deploy"
veafAirWaves.DEFAULT_MESSAGE_DEPLOY_PLAYERS = "airwaves.msg_deploy_players"
veafAirWaves.DEFAULT_MESSAGE_OUTSIDE_OF_ZONE_PLAYERS = "airwaves.msg_outside_of_zone"
veafAirWaves.DEFAULT_MESSAGE_DESTROYED = "airwaves.msg_destroyed"
veafAirWaves.DEFAULT_MESSAGE_WON = "airwaves.msg_won"
veafAirWaves.DEFAULT_MESSAGE_LOST = "airwaves.msg_lost"
veafAirWaves.DEFAULT_MESSAGE_STOP = "airwaves.msg_stop"

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
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[]:setName(%s)", veaf.lp(value))
  self.name = value
  return veafAirWaves.add(self) -- add the zone to the list as soon as a name is available to index it
end

function AirWaveZone:getName()
  return self.name or self.description
end

function AirWaveZone:setTriggerZone(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setTriggerZone(%s)", veaf.lp(self.name), veaf.lp(value))
  self.triggerZoneName = value
  local triggerZone = veaf.getTriggerZone(value)
  if triggerZone then
    self:setZoneCenter({ x = triggerZone.x, y = triggerZone.y })
    self:setZoneRadius(triggerZone.radius)
  elseif self.zoneCenter then
    -- The trigger zone is optional when a center (and radius) is already
    -- configured (e.g. via setZoneCenterFromCoordinates): keep the existing
    -- center/radius and only warn instead of erroring.
    veaf.loggers.get(veafAirWaves.Id):warn(
      "AirWaveZone[%s]:setTriggerZone(): trigger zone [%s] does not exist; keeping configured center/radius",
      veaf.p(self.name),
      veaf.p(value)
    )
  else
    veaf.loggers
      .get(veafAirWaves.Id)
      :error("AirWaveZone[%s]:setTriggerZone(): trigger zone [%s] does not exist", veaf.p(self.name), veaf.p(value))
  end
  return self
end

function AirWaveZone:setZoneCenter(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setZoneCenter(%s)", veaf.lp(self.name), veaf.lp(value))
  self.zoneCenter = value
  return self
end

function AirWaveZone:setZoneCenterFromCoordinates(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setZoneCenterFromCoordinates(%s)", veaf.lp(self.name), veaf.lp(value))
  local _lat, _lon = veaf.computeLLFromString(value)
  ---@diagnostic disable-next-line: param-type-mismatch
  local vec3 = coord.LLtoLO(_lat, _lon)
  return self:setZoneCenter(vec3)
end

function AirWaveZone:setZoneRadius(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setZoneRadius(%s)", veaf.lp(self.name), veaf.lp(value))
  self.zoneRadius = value
  return self
end

function AirWaveZone:setDrawZone(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setDrawZone(%s)", veaf.lp(self.name), veaf.lp(value))
  self.drawZone = value or false
  return self
end

function AirWaveZone:setDescription(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setDescription(%s)", veaf.lp(self.name), veaf.lp(value))
  self.description = value
  return veafAirWaves.add(self) -- add the zone to the list as soon as a description is available to index it
end

function AirWaveZone:getDescription()
  return self.description or self.name
end

---adds a wave of enemy planes
---parameters are very flexible: they can be:
--- a table containing the following fields:
---     - groups a list of groups or VEAF commands; VEAF commands can be prefixed with [lat, lon], specifying the location of their spawn relative to the center of the zone; default value is set with "setRespawnDefaultOffset"
---     - number how many of these groups will actually be spawned (can be multiple times the same group!); it can be a "randomizable number", e.g., "2-6" for "between 2 and 6"
---     - bias shifts the random generator to the right of the list; it can be a "randomizable number" too
---     - delay the delay between this wave and the next one - if negative, then the next wave is spawned instantaneously (no waiting for this wave to be completed); it can be a "randomizable number" too
--- or a list of strings (the groups or VEAF commands)
--- or almost anything in between; we'll take a string as if it were a table containing one string, anywhere
--- examples:
---   :addWave("group1")
---   :addWave("group1", "group2")
---   :addWave({"group1", "group2"})
---   :addWave({ groups={"group1", "group2"}, number = 2})
---   :addWave({ groups="group1", number = 2})
---returns self
function AirWaveZone:addWave(...)
  local args = { ... }
  local nArgs = select("#", ...)
  veaf.loggers.get(veafAirWaves.Id):debug(string.format("AirWaveZone[%s]:addWave() : %s", veaf.p(self.name), veaf.p(args)))
  if nArgs > 0 then
    local groups = {}
    local number = 1
    local bias = 0
    local delay = nil
    for i = 1, nArgs, 1 do
      local parameter = args[i]
      if type(parameter) == "string" then
        table.insert(groups, parameter)
      elseif type(parameter) == "table" then
        if parameter.groups then
          -- this is a parameters table, let's use it
          if type(parameter.groups) == "string" then
            -- we need a table
            groups = { parameter.groups }
          else
            groups = parameter.groups
          end
          number = parameter.number
          bias = parameter.bias
          delay = parameter.delay
          break
        else
          for j = 1, #parameter, 1 do
            local s = parameter[j]
            if type(s) == "string" then
              table.insert(groups, s)
            end
          end
          break
        end
      end
    end
    if not self.waves then
      self.waves = {}
    end
    table.insert(self.waves, { groups = groups, number = number or 1, bias = bias or 0, delay = delay })
  end
  return self
end

---reset the waves table to zero; useful when deep copying a zone to reset the waves and set something different
---@return table self
function AirWaveZone:resetWaves()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:resetWaves()", veaf.lp(self.name))
  self.waves = {}
  return self
end

function AirWaveZone:setMessageStart(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageStart()", veaf.lp(self.name))
  self.messageStart = value
  return self
end

---Set the onStart callback
---@param value function takes 2 parameters: the zone name (string), the monitored player units (table)
---@return table self
function AirWaveZone:setOnStart(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnStart()", veaf.lp(self.name))
  self.onStart = value
  return self
end

function AirWaveZone:setMessageWaitForHumans(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageWaitForHumans()", veaf.lp(self.name))
  self.messageWaitForHumans = value
  return self
end

---Set the onWaitForHumans callback
---@param value function takes 3 parameters: the zone name (string), the wave index (int), the monitored player units (table)
---@return table self
function AirWaveZone:setOnWaitForHumans(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnWaitForHumans()", veaf.lp(self.name))
  self.onWaitForHumans = value
  return self
end

function AirWaveZone:setMessageWaitToDeploy(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageWaitToDeploy()", veaf.lp(self.name))
  self.messageWaitToDeploy = value
  return self
end

---Set the onWaitToDeploy callback
---@param value function takes 3 parameters: the zone name (string), the wave index (int), the monitored player units (table)
---@return table self
function AirWaveZone:setOnWaitToDeploy(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnWaitToDeploy()", veaf.lp(self.name))
  self.onWaitToDeploy = value
  return self
end

function AirWaveZone:setMessageDeploy(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageDeploy()", veaf.lp(self.name))
  self.messageDeploy = value
  return self
end

function AirWaveZone:setMessageDeployPlayers(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageDeployPlayers()", veaf.lp(self.name))
  self.messageDeployPlayers = value
  return self
end

---Set the onDeploy callback
---@param value function takes 3 parameters: the zone name (string), the wave index (int), the monitored player units (table)
---@return table self
function AirWaveZone:setOnDeploy(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnDeploy()", veaf.lp(self.name))
  self.onDeploy = value
  return self
end

function AirWaveZone:setMessageDestroyed(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageDestroyed()", veaf.lp(self.name))
  self.messageDestroyed = value
  return self
end

---Set the onDestroyed callback
---@param value function takes 3 parameters: the zone name (string), the wave index (int), the monitored player units (table)
---@return table self
function AirWaveZone:setOnDestroyed(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnDestroyed()", veaf.lp(self.name))
  self.onDestroyed = value
  return self
end

function AirWaveZone:setMessageOutsideOfZone(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageOutsideOfZone()", veaf.lp(self.name))
  self.messageOutsideOfZone = value
  return self
end

---Set the onOutsideOfZone callback
---@param value function takes 3 parameters: the zone name (string), the wave index (int), the monitored player units (table)
---@return table self
function AirWaveZone:setOnOutsideOfZone(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnOutsideOfZone()", veaf.lp(self.name))
  self.onOutsideOfZone = value
  return self
end

function AirWaveZone:setMessageWon(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageWon()", veaf.lp(self.name))
  self.messageWon = value
  return self
end

---Set the onWon callback
---@param value function takes 2 parameters: the zone name (string), the monitored player units (table)
---@return table self
function AirWaveZone:setOnWon(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnWon()", veaf.lp(self.name))
  self.onWon = value
  return self
end

function AirWaveZone:setMessageLost(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageLost()", veaf.lp(self.name))
  self.messageLost = value
  return self
end

---Set the onLost callback
---@param value function takes 2 parameters: the zone name (string), the monitored player units (table)
---@return table self
function AirWaveZone:setOnLost(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnLost()", veaf.lp(self.name))
  self.onLost = value
  return self
end

function AirWaveZone:setMessageStop(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageStop()", veaf.lp(self.name))
  self.messageStop = value
  return self
end

---Set the onStop callback
---@param value function takes 2 parameters: the zone name (string), the monitored player units (table)
---@return table self
function AirWaveZone:setOnStop(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnStop()", veaf.lp(self.name))
  self.onStop = value
  return self
end

function AirWaveZone:setSilent(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setSilent(%s)", veaf.lp(self.name), veaf.lp(value))
  self.silent = value or false
  return self
end

function AirWaveZone:setRespawnRadius(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setRespawnRadius(%s)", veaf.lp(self.name), veaf.lp(value))
  self.respawnRadius = value
  if self.respawnRadius < 250 then
    self.respawnRadius = 250
  end
  return self
end

---set the default respawn offset (in meters, relative to the zone center)
---@param defaultOffsetLatitude any in meters
---@param defaultOffsetLongitude any in meters
---@return table self
function AirWaveZone:setRespawnDefaultOffset(defaultOffsetLatitude, defaultOffsetLongitude)
  veaf.loggers.get(veafAirWaves.Id):debug(
    "AirWaveZone[%s]:setRespawnDefaultOffset(%s, %s)",
    veaf.lp(self.name),
    veaf.lp(defaultOffsetLatitude),
    veaf.lp(defaultOffsetLongitude)
  )
  self.respawnDefaultOffset = { latDelta = defaultOffsetLatitude, lonDelta = defaultOffsetLongitude }
  return self
end

function AirWaveZone:addPlayerCoalition(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:addPlayerCoalition(%s)", veaf.lp(self.name), veaf.lp(value))
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

---Sets the default delay in seconds between waves of enemy planes
---@param value number a delay in seconds
---@return table self
function AirWaveZone:setDelayBetweenWaves(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setDelayBetweenWaves(%s)", veaf.lp(self.name), veaf.lp(value))
  self.delayBetweenWaves = value
  return self
end

---Sets the delay in seconds between the first human in zone and the actual activation of the zone
---@param value number a delay in seconds
---@return table self
function AirWaveZone:setDelayBeforeActivation(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setDelayBeforeActivation(%s)", veaf.lp(self.name), veaf.lp(value))
  self.delayBeforeActivation = value
  return self
end

function AirWaveZone:setResetWhenDying(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setResetWhenDying(%s)", veaf.lp(self.name), veaf.lp(value))
  self.resetWhenDying = value
  return self
end

function AirWaveZone:setMinimumAltitudeInFeet(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMinimumAltitudeInFeet(%s)", veaf.lp(self.name), veaf.lp(value))
  self.minimumAltitude = value * 0.3048 -- convert from feet
  return self
end

function AirWaveZone:getMinimumAltitudeInMeters()
  return self.minimumAltitude
end

function AirWaveZone:setMaximumAltitudeInFeet(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMaximumAltitudeInFeet(%s)", veaf.lp(self.name), veaf.lp(value))
  self.maximumAltitude = value * 0.3048 -- convert from feet
  return self
end

function AirWaveZone:getMaximumAltitudeInMeters()
  return self.maximumAltitude
end

---Sets the maximum number of seconds an IA can stay out of its zone before being destroyed
---@param value number a delay in seconds
---@return table self
function AirWaveZone:setMaxSecondsOutsideOfZoneIA(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMaxSecondsOutsideOfZoneIA(%s)", veaf.lp(self.name), veaf.lp(value))
  self.maxSecondsOutsideOfZoneIA = value
  return self
end

---Disables the check for IA out of zone.
---@return table self
function AirWaveZone:disableOutsideOfZoneIA()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:disableOutsideOfZoneIA()", veaf.lp(self.name))
  self.maxSecondsOutsideOfZoneIA = nil
  return self
end

---Sets the maximum number of seconds a player can stay out of its zone before being destroyed; players will be messaged as soon as they exit the zone, and every check
---@param value number a delay in seconds
---@return table self
function AirWaveZone:setMaxSecondsOutsideOfZonePlayers(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMaxSecondsOutsideOfZonePlayers(%s)", veaf.lp(self.name), veaf.lp(value))
  self.maxSecondsOutsideOfZonePlayers = value
  return self
end

---Disables the check for players out of zone.
---@return table self
function AirWaveZone:disableOutsideOfZonePlayers()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:disableOutsideOfZonePlayers()", veaf.lp(self.name))
  self.maxSecondsOutsideOfZonePlayers = nil
  return self
end

function AirWaveZone:_setState(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:_setState(%s)", veaf.lp(self.name), veaf.lp(veafAirWaves.statusToString(value)))
  self.state = value
  return self
end

---the function that decides if a wave is dead or not (as a set of groups and units)
---@param callback function the callback function will be called with 3 parameters: a zone, the wave index number, the spawned groups names list; it must return a boolean
function AirWaveZone:setIsEnemyWaveDeadCallback(callback)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setIsEnemyWaveDeadCallback()", veaf.lp(self.name))
  self.isEnemyWaveDeadCallback = callback
  return self
end

---the function that decides if a group is dead or not (individually)
---@param callback function the callback function will be called with 3 parameters: a zone, the wave index number, a DCS group table; it must return a boolean
function AirWaveZone:setIsEnemyGroupDeadCallback(callback)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setIsEnemyGroupDeadCallback()", veaf.lp(self.name))
  self.isEnemyGroupDeadCallback = callback
  return self
end

---Sets the minimum percentage of life that an AI unit is supposed to have to be considered alive
---@param value number percentage
---@return table
function AirWaveZone:setMinimumLifeForAiInPercent(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMinimumLifeForAiInPercent(%s)", veaf.lp(self.name), veaf.lp(value))
  self.minimumLifeForAiInPercent = value
  return self
end

--- the function that handles crippled enemy units
---@param callback function the callback function will be called with 3 parameters: a zone, the wave index number, a DCS unit table; it must do what it wants with the unit
function AirWaveZone:setHandleCrippledEnemyUnitCallback(callback)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setHandleCrippledEnemyUnitCallback()", veaf.lp(self.name))
  self.handleCrippledEnemyUnitCallback = callback
  return self
end

function AirWaveZone:reset()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:reset()", veaf.lp(self.name))

  -- despawn the ennemies
  self:destroyCurrentWave()

  -- reset all the zone properties

  -- player units (if they die, reset the zone)
  self.playerUnitsNames = {}
  -- groups that have been spawned (the current wave)
  self.spawnedGroupsNames = {}
  -- the delay after this wave, and before the next one (either set in the wave definition, or it's the default delayBetweenWaves)
  self.delayBeforeNextWave = nil
  -- the time when the next wave is supposed to spawn (used to know when to actually spawn when in the STATUS_WAITING_FOR_NEXTWAVE state)
  self.timeOfNextWave = nil
  -- the time when the zones is supposed to be activated (used to know when to actually activate when in the STATUS_WAITING_FOR_MORE_HUMANS state)
  self.timeOfActivation = nil
  -- human units that are being watched
  self.playerHumanUnits = nil
  -- names of the human units that are being watched
  self.playerHumanUnitsNames = nil
  -- IA units that are being watched
  self.unitsInZone = {}
  -- current wave number
  self.currentWaveIndex = 0
  -- the drawing object that has been used to draw the zone
  self.zoneDrawing = nil
  -- the time humans exited the zone
  self.timestampsOutOfZone = {}

  -- deschedule the check() function
  if self.checkFunctionSchedule then
    mist.removeFunction(self.checkFunctionSchedule)
    self.checkFunctionSchedule = nil
  end

  return self
end

-- the function that decides if a wave is dead or not (as a set of groups and units)
function AirWaveZone:isEnemyWaveDead(waveNumber, waveGroupsNames)
  --veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:isEnemyWaveDead(%s)", veaf.p(self.name), veaf.p(waveNumber))
  --veaf.loggers.get(veafAirWaves.Id):trace("waveGroupsNames=%s", veaf.p(waveGroupsNames))

  local currentWaveAlive = false
  for _, groupName in pairs(waveGroupsNames) do
    local group = Group.getByName(groupName)
    if group then
      local groupIsDead = self.isEnemyGroupDeadCallback(self, self.currentWaveIndex, group)
      if not groupIsDead then
        currentWaveAlive = true
      end
    end
  end
  return not currentWaveAlive
end

-- the function that decides if IA ennemy groups are dead (individually)
function AirWaveZone:isEnemyGroupDead(waveNumber, group)
  --veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:isEnemyGroupDead(%s)", veaf.p(self.name), veaf.p(waveNumber))
  if not group then
    return true
  end
  --veaf.loggers.get(veafAirWaves.Id):trace("group:getName()=%s", veaf.p(group:getName()))

  local groupAtLeastOneUnitAlive = false
  local category = group:getCategory()
  local units = group:getUnits()
  if units then
    for _, unit in pairs(units) do
      local unitAlive = false
      local unitLife = unit:getLife()
      local unitLife0 = 0
      if unit.getLife0 then -- statics have no life0
        unitLife0 = unit:getLife0()
      end
      local unitLifePercent = unitLife
      if unitLife0 > 0 then
        unitLifePercent = 100 * unitLife / unitLife0
      end
      if unitLifePercent > self.minimumLifeForAiInPercent then
        if
          category == 0 --[[airplanes]]
          or category == 1 --[[helicopters]]
        then
          if unit:inAir() then
            unitAlive = true
          end
        else
          unitAlive = true
        end
      end
      if not unitAlive then
        self.handleCrippledEnemyUnitCallback(self, self.currentWaveIndex, unit)
      else
        groupAtLeastOneUnitAlive = true
      end
    end
  end
  return not groupAtLeastOneUnitAlive
end

-- the function that handles crippled enemy units
function AirWaveZone:handleCrippledEnemyUnit(waveNumber, unit)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:handleCrippledEnemyUnit(%s)", veaf.lp(self.name), veaf.lp(waveNumber))
  if not unit then
    return
  end
  veaf.loggers.get(veafAirWaves.Id):debug("unit:getName()=%s", veaf.lp(unit:getName()))
  -- simply despawn the unit
  unit:destroy()
end

function AirWaveZone:getPlayerUnitsNames()
  -- Rebuild each time to include dynamic slot players not tracked by mist
  self.playerHumanUnitsNames = {}

  -- Static slot players from mist DB
  local seenUnits = {}
  for _, unit in pairs(veaf.mist.getAllHumanUnitData()) do
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
        if unit.category == "plane" then
          seenUnits[unit.unitName] = true
          table.insert(self.playerHumanUnitsNames, unit.unitName)
        end
      end
    end
  end

  -- Dynamic slot players via DCS coalition API (not tracked by mist)
  for _, checkCoalitionId in pairs({ coalition.side.RED, coalition.side.BLUE }) do
    if self.playerCoalitions[checkCoalitionId] then
      local groups = coalition.getGroups(checkCoalitionId, Group.Category.AIRPLANE)
      if groups then
        for _, grp in pairs(groups) do
          local units = grp:getUnits()
          if units then
            for _, dcsUnit in pairs(units) do
              if dcsUnit:getPlayerName() then
                local dynamicUnitName = dcsUnit:getName()
                -- Only add if not already present from mist DB
                if not seenUnits[dynamicUnitName] then
                  seenUnits[dynamicUnitName] = true
                  table.insert(self.playerHumanUnitsNames, dynamicUnitName)
                end
              end
            end
          end
        end
      end
    end
  end

  return self.playerHumanUnitsNames
end

function AirWaveZone:check()
  veaf.loggers
    .get(veafAirWaves.Id)
    :debug("AirWaveZone[%s]:check() -> self.state=%s", veaf.lp(self.name), veaf.lp(veafAirWaves.statusToString(self.state)))
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:check() -> timer.getTime()=%s", veaf.lp(self.name), veaf.lp(timer.getTime()))

  local function getHumansInZone()
    local resultUnitsByName = {}
    local resultUnitsNames = {}
    local resultUnits = {}
    local unitNames = self:getPlayerUnitsNames()
    local triggerZone = veaf.getTriggerZone(self.triggerZoneName)
    local humanUnits = nil
    if triggerZone then
      -- nil is left as is: the loop below reads `humanUnits or {}`, so an unreadable zone triggers no
      -- wave — the safe conduct, and the same one an empty zone gets. The error is in the log.
      humanUnits = veaf.getUnitsInTriggerZone(self.triggerZoneName, unitNames, veafAirWaves.Id)
    elseif self.zoneCenter then
      humanUnits = veaf.findUnitsInCircle(self.zoneCenter, self.zoneRadius, false, unitNames)
    else
      veaf.loggers.get(veafAirWaves.Id):error("No triggerzone, and no zone center/radius defined!")
    end
    for _, unit in pairs(humanUnits or {}) do
      -- check the unit altitude against the ceiling and floor
      if unit:inAir() then -- never count a landed aircraft
        local alt = unit:getPoint().y
        if alt >= self:getMinimumAltitudeInMeters() and alt <= self:getMaximumAltitudeInMeters() then
          -- add the unit to the player units list, so that we can monitor it
          local unitName = unit:getName()
          table.insert(resultUnitsNames, unitName)
          table.insert(resultUnits, unit)
          resultUnitsByName[unitName] = unit
        end
      end
    end
    return resultUnits, resultUnitsNames, resultUnitsByName
  end

  local humansInZone, humansInZoneNames, humansInZoneByName = getHumansInZone()

  -- whatever the state, monitor the player units if they're defined
  if self.playerUnitsNames and #self.playerUnitsNames > 0 then
    local atLeastOnePlayerAlive = false
    local atLeastOnePlayerAirborne = false
    for _, unitName in pairs(self.playerUnitsNames) do
      local unit = Unit.getByName(unitName)
      if unit then
        -- check alive
        atLeastOnePlayerAlive = true
        if unit:inAir() then
          atLeastOnePlayerAirborne = true
        end
        -- check in zone
        if humansInZoneByName[unitName] then
          self.timestampsOutOfZone[unitName] = nil
        elseif self.maxSecondsOutsideOfZonePlayers then
          local timestampOutOfZone = timer.getTime()
          if self.timestampsOutOfZone[unitName] then
            timestampOutOfZone = self.timestampsOutOfZone[unitName]
          else
            self.timestampsOutOfZone[unitName] = timestampOutOfZone
          end
          local seconds = timer.getTime() - timestampOutOfZone
          self:signalOutsideOfZone(unitName, seconds)
          local secondsOffend = seconds - self.maxSecondsOutsideOfZonePlayers
          if secondsOffend > 0 then
            -- destroy the player
            if secondsOffend > self.maxSecondsOutsideOfZonePlayers then
              veaf.loggers.get(veafAirWaves.Id):debug("destroy out of zone player unitName=%s", veaf.lp(unitName))
              unit:destroy()
            else
              veaf.loggers.get(veafAirWaves.Id):debug("flak out of zone player unitName=%s", veaf.lp(unitName))
              local point = unit:getPoint()
              local positionForFlak1 = mist.vec.add(point, mist.vec.scalarMult(unit:getVelocity(), 1))
              local positionForFlak2 = mist.vec.add(point, mist.vec.scalarMult(unit:getVelocity(), 2))
              local positionForFlak3 = mist.vec.add(point, mist.vec.scalarMult(unit:getVelocity(), 3))
              veafSpawn.spawnBomb(positionForFlak1, 50, 5, 25 + seconds - self.maxSecondsOutsideOfZonePlayers, positionForFlak1.y, 50)
              veafSpawn.spawnBomb(positionForFlak2, 50, 5, 25 + seconds - self.maxSecondsOutsideOfZonePlayers, positionForFlak2.y, 50)
              veafSpawn.spawnBomb(positionForFlak3, 50, 5, 25 + seconds - self.maxSecondsOutsideOfZonePlayers, positionForFlak3.y, 50)
            end
          end
        end
      end
    end
    if not (atLeastOnePlayerAlive and atLeastOnePlayerAirborne) then
      veaf.loggers.get(veafAirWaves.Id):debug("player is dead or despawned in %s", veaf.lp(self:getName()))
      if self.state ~= veafAirWaves.STATUS_OVER then
        -- signal that all players have been destroyed
        self:signalLost()
      end
      if self.resetWhenDying then
        -- reset the zone; start() calls check() which handles rescheduling
        self:stop()
        self:start()
        return
      end
    end
  end

  -- FSM: iterate transitions until the state stabilises in one check() tick
  local transitioned = true
  while transitioned do
    transitioned = false
    local fsmDef = AirWaveZone.FSM[self.state]
    if not fsmDef then
      break
    end
    if fsmDef.tick then
      fsmDef.tick(self)
    end
    for targetState, guardFn in pairs(fsmDef.transitions) do
      if guardFn(self, humansInZone, humansInZoneNames) then
        if fsmDef.exit then
          fsmDef.exit(self, humansInZone, humansInZoneNames)
        end
        self:_setState(targetState)
        local newFsmDef = AirWaveZone.FSM[targetState]
        if newFsmDef and newFsmDef.enter then
          newFsmDef.enter(self, humansInZone, humansInZoneNames)
        end
        transitioned = true
        break
      end
    end
  end

  if self.checkFunctionSchedule then
    -- deschedule if needed
    mist.removeFunction(self.checkFunctionSchedule)
    self.checkFunctionSchedule = nil
  end
  self.checkFunctionSchedule = mist.scheduleFunction(function(zone)
    veaf.safeCall(AirWaveZone.check, zone)
  end, { self }, timer.getTime() + veafAirWaves.WATCHDOG_DELAY + math.random(0, 2)) -- randomize reschedules so not all zones are working at the same time
end

function AirWaveZone:chooseGroupsToDeploy()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:chooseGroupsToDeploy()", veaf.lp(self.name))

  if self.currentWaveIndex <= #self.waves then
    local nextWave = self.waves[self.currentWaveIndex]
    if nextWave then
      -- process a random group definition
      local groupsToChooseFrom = nextWave.groups
      local numberOfGroups = nextWave.number
      local bias = nextWave.bias
      local delay = nextWave.delay
      local result = {}
      if type(numberOfGroups) == "string" then
        -- convert randomizable numeric to number
        numberOfGroups = veaf.getRandomizableNumeric(numberOfGroups)
      end
      if type(bias) == "string" then
        -- convert randomizable numeric to number
        bias = veaf.getRandomizableNumeric(bias)
      end
      if delay ~= nil and type(delay) == "string" then
        -- convert randomizable numeric to number
        delay = veaf.getRandomizableNumeric(delay)
      end
      if
        groupsToChooseFrom
        and type(groupsToChooseFrom) == "table"
        and numberOfGroups
        and type(numberOfGroups) == "number"
        and bias
        and type(bias) == "number"
      then
        for _ = 1, numberOfGroups do
          local group = veaf.randomlyChooseFrom(groupsToChooseFrom, bias)
          table.insert(result, group)
        end
      end
      return result, delay
    end
  end
end

function AirWaveZone:deployWaves()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:deployWaves()", veaf.lp(self.name))
  self.spawnedGroupsNames = {}
  local groupsToDeployForTheseWaves = {}
  local lastDelay
  repeat
    self.currentWaveIndex = self.currentWaveIndex + 1
    local groupsToDeploy, delay = self:chooseGroupsToDeploy()
    veaf.loggers.get(veafAirWaves.Id):debug("groupsToDeploy=%s", veaf.lp(groupsToDeploy))
    veaf.loggers.get(veafAirWaves.Id):debug("delay=%s", veaf.lp(delay))
    lastDelay = delay
    for _, group in pairs(groupsToDeploy) do
      table.insert(groupsToDeployForTheseWaves, group)
    end
  until not lastDelay or lastDelay >= 0 or self.currentWaveIndex >= #self.waves
  if groupsToDeployForTheseWaves then
    local zoneCenter = {}
    -- VMR-085: ask for the trigger zone, then decide — the same shape as AirWaveZone:check().
    -- Testing `self.triggerZoneName` was not enough: setTriggerZone keeps the name even when the
    -- zone does not exist (it warns and keeps the configured center instead), so this indexed nil
    -- and every wave of such a zone raised.
    local triggerZone = self.triggerZoneName and veaf.getTriggerZone(self.triggerZoneName)
    if triggerZone then
      zoneCenter.x = triggerZone.x
      zoneCenter.z = triggerZone.y
      zoneCenter.y = 0
    elseif self.zoneCenter then
      zoneCenter = self.zoneCenter
    else
      veaf.loggers
        .get(veafAirWaves.Id)
        :error("AirWaveZone[%s]:deployWaves(): no trigger zone, and no zone center defined!", veaf.p(self.name))
      return
    end
    for _, groupNameOrCommand in pairs(groupsToDeployForTheseWaves) do
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
          if coords then
            latDelta, lonDelta = coords:match("([%+-%d]+),%s*([%+-%d]+)")
          end
        end
        veaf.loggers.get(veafAirWaves.Id):debug("running command [%s]", veaf.lp(command))
        local position = { x = zoneCenter.x - lonDelta, y = zoneCenter.y, z = zoneCenter.z + latDelta }
        local randomPosition = mist.getRandPointInCircle(position, self.respawnRadius)
        local spawnedGroupsNames = {}
        veafInterpreter.execute(command, randomPosition, self.coalition, nil, spawnedGroupsNames)
        for _, newGroupName in pairs(spawnedGroupsNames) do
          table.insert(self.spawnedGroupsNames, newGroupName)
        end
      else
        -- this is a DCS group
        local groupName = groupNameOrCommand
        veaf.loggers.get(veafAirWaves.Id):debug("spawning group [%s]", veaf.lp(groupName))
        local groupData = mist.getGroupData(groupName)
        veaf.loggers.get(veafAirWaves.Id):trace("groupData=%s", veaf.lp(groupData))
        if not groupData then
          veaf.loggers.get(veafAirWaves.Id):error("group [%s] does not exist in the mission!", veaf.p(groupName))
        else
          local spawnSpot = {
            x = zoneCenter.x - self.respawnDefaultOffset.lonDelta,
            y = zoneCenter.y,
            z = zoneCenter.z + self.respawnDefaultOffset.latDelta,
          }
          -- Try and set the spawn spot at the place the group has been set in the Mission Editor.
          -- Unfortunately this is sometimes not possible because DCS is not returning the group units for some reason.
          -- When this happens we'll default to the default spawn offset (same as spawning with VEAF commands)
          if not groupData.units[1] then
            veaf.loggers.get(veafAirWaves.Id):warn("group [%s] does not have any unit!", veaf.p(groupName))
          else
            spawnSpot = { x = groupData.units[1].x, y = groupData.units[1].alt, z = groupData.units[1].y }
          end
          veaf.loggers.get(veafAirWaves.Id):trace("spawnSpot=%s", veaf.lp(spawnSpot))
          local vars = {}
          vars.point = mist.getRandPointInCircle(spawnSpot, self.respawnRadius)
          vars.point.z = vars.point.y
          vars.point.y = spawnSpot.y
          vars.gpName = groupName
          vars.action = "clone"
          vars.route = mist.getGroupRoute(groupName, "task")
          veaf.loggers.get(veafAirWaves.Id):trace("vars=%s", veaf.lp(vars))
          local newGroup = mist.teleportToPoint(vars) -- respawn with radius
          if newGroup then
            table.insert(self.spawnedGroupsNames, newGroup.name)
          end
        end
      end
    end
    veaf.loggers.get(veafAirWaves.Id):trace("self.spawnedGroupsNames=%s", veaf.lp(self.spawnedGroupsNames))
    self:_setState(veafAirWaves.STATUS_ACTIVE)
  end
  self:signalDeploy()
  return (self.spawnedGroupsNames and #self.spawnedGroupsNames > 0), lastDelay
end

---Sends a message to all players in the zone, but only once per group (because we're actually messaging whole groups, thanks DCS)
---@param msg string the message to be sent
function AirWaveZone:signalToPlayers(msg)
  if self.unitsInZone then
    for _, unitInZone in pairs(self.unitsInZone) do
      local unitName = unitInZone:getName()
      veaf.outTextForUnit(unitName, msg, 15)
    end
  end
end

function AirWaveZone:signalStart()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalStart()", veaf.lp(self.name))
  if not self.silent then
    local msg = veaf.t(self.messageStart, self:getDescription())
    for coalition, _ in pairs(self.playerCoalitions) do
      trigger.action.outTextForCoalition(coalition, msg, 15)
    end
  end
  if self.onStart then
    self.onStart(self.name, self.playerUnitsNames)
  end
end

function AirWaveZone:signalWaitForHumans()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalWaitForHumans()", veaf.lp(self.name))
  if not self.silent then
    self:signalToPlayers(veaf.t(self.messageWaitForHumans, self:getDescription(), self.delayBeforeActivation))
  end
  if self.onWaitForHumans then
    self.onWaitForHumans(self.name, self.playerUnitsNames)
  end
end

function AirWaveZone:signalWaitToDeploy()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalWaitToDeploy()", veaf.lp(self.name))
  if not self.silent then
    self:signalToPlayers(veaf.t(self.messageWaitToDeploy, self:getDescription(), self.delayBeforeNextWave))
  end
  if self.onWaitToDeploy then
    self.onWaitToDeploy(self.name, self.playerUnitsNames)
  end
end

function AirWaveZone:signalDeploy()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalDeploy()", veaf.lp(self.name))
  if not self.silent then
    -- messages to all
    local msg = veaf.t(self.messageDeploy, self:getDescription(), self.currentWaveIndex)
    for coalition, _ in pairs(self.playerCoalitions) do
      trigger.action.outTextForCoalition(coalition, msg, 15)
    end
    -- messages to players with BRAA
    if self.unitsInZone then
      local groupsAlreadyMessaged = {}
      for _, unitInZone in pairs(self.unitsInZone) do
        -- compute BRAA of closest group
        local braa = { bearing = -1, distance = 9999 }
        for _, spawnedGroupName in pairs(self.spawnedGroupsNames) do
          local spawnedGroupPosition = mist.getAvgGroupPos(spawnedGroupName)
          local unitPosition = nil
          if unitInZone and unitInZone:getPosition() then
            unitPosition = unitInZone:getPosition().p
          end
          if spawnedGroupPosition and unitPosition then
            local bearing, _, _, distanceInNm = veaf.getBearingAndRangeFromTo(unitPosition, spawnedGroupPosition)
            if braa.distance > distanceInNm then
              -- this is closer than the group we had before
              braa.distance = math.floor(distanceInNm)
              braa.bearing = math.floor(bearing)
            end
          end
        end
        if braa.bearing > -1 then
          -- found a group
          local braaS = string.format("BRA %03d/%02d", braa.bearing, braa.distance)
          if braa.distance < 5 then
            braaS = "MERGED"
          end
          local group = unitInZone:getGroup()
          local groupId = nil
          if group then
            groupId = group:getID()
          end
          if groupId and not groupsAlreadyMessaged[groupId] then
            groupsAlreadyMessaged[groupId] = true
            trigger.action.outTextForGroup(groupId, veaf.t(self.messageDeployPlayers, self.currentWaveIndex, braaS), 15)
          end
        end
      end
    end
  end
  if self.onDeploy then
    self.onDeploy(self.name, self.currentWaveIndex, self.playerUnitsNames)
  end
end

function AirWaveZone:signalDestroyed()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalDestroyed()", veaf.lp(self.name))
  if not self.silent then
    self:signalToPlayers(veaf.t(self.messageDestroyed, self:getDescription(), self.currentWaveIndex))
  end
  if self.onDestroyed then
    self.onDestroyed(self.name, self.currentWaveIndex, self.playerUnitsNames)
  end
end

function AirWaveZone:signalOutsideOfZone(playerUnitName, seconds)
  veaf.loggers
    .get(veafAirWaves.Id)
    :debug("AirWaveZone[%s]:signalOutsideOfZone(player=%s, seconds=%s)", veaf.lp(self.name), veaf.lp(playerUnitName), veaf.lp(seconds))
  if not self.silent then
    veaf.outTextForUnit(
      playerUnitName,
      veaf.t(self.messageOutsideOfZone, self:getDescription(), seconds, self.maxSecondsOutsideOfZonePlayers),
      15
    )
  end
  if self.onOutsideOfZone then
    self.onOutsideOfZone(self.name, playerUnitName, seconds)
  end
end

function AirWaveZone:signalWon()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalWon()", veaf.lp(self.name))
  if not self.silent then
    self:signalToPlayers(veaf.t(self.messageWon, self:getDescription()))
  end
  if self.onWon then
    self.onWon(self.name, self.playerUnitsNames)
  end
end

function AirWaveZone:signalLost()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalLost()", veaf.lp(self.name))
  if not self.silent then
    local msg = veaf.t(self.messageLost, self:getDescription())
    for coalition, _ in pairs(self.playerCoalitions) do
      trigger.action.outTextForCoalition(coalition, msg, 15)
    end
  end
  if self.onLost then
    self.onLost(self.name, self.playerUnitsNames)
  end
end

function AirWaveZone:signalStop()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalStop()", veaf.lp(self.name))
  if not self.silent then
    local msg = veaf.t(self.messageStop, self:getDescription())
    for coalition, _ in pairs(self.playerCoalitions) do
      trigger.action.outTextForCoalition(coalition, msg, 15)
    end
  end
  if self.onStop then
    self.onStop(self.name, self.playerUnitsNames)
  end
end

function AirWaveZone:start()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:start()", veaf.lp(self.name))
  self:reset()
  self:_setState(veafAirWaves.STATUS_READY)
  self:check()

  -- draw the zone
  if self.drawZone then
    if self.triggerZoneName then
      self.zoneDrawing = mist.marker.drawZone(self.triggerZoneName, { message = self:getDescription(), readOnly = true })
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
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:stop()", veaf.lp(self.name))
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
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:destroyCurrentWave()", veaf.lp(self.name))
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
-- FSM callbacks
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- READY → WAITING_FOR_MORE_HUMANS
function AirWaveZone._canEnterWaitForMoreHumans(self, humansInZone)
  return humansInZone ~= nil and #humansInZone > 0
end

-- enter WAITING_FOR_MORE_HUMANS: record who entered and start activation timer
function AirWaveZone._onEnterWaitForMoreHumans(self, humansInZone, humansInZoneNames)
  self.unitsInZone = humansInZone
  self.playerUnitsNames = humansInZoneNames
  if self.delayBeforeActivation and self.delayBeforeActivation > 0 then
    self:signalWaitForHumans()
  end
  self.timeOfActivation = timer.getTime() + self.delayBeforeActivation
  veaf.loggers.get(veafAirWaves.Id):debug("waiting %s seconds before activation", veaf.lp(self.delayBeforeActivation))
  veaf.loggers.get(veafAirWaves.Id):trace("self.timeOfActivation=%s", veaf.lp(self.timeOfActivation))
end

-- WAITING_FOR_MORE_HUMANS → NEXTWAVE
function AirWaveZone._canEnterNextWave(self, humansInZone)
  return self.timeOfActivation ~= nil and timer.getTime() >= self.timeOfActivation and humansInZone ~= nil and #humansInZone > 0
end

-- exit WAITING_FOR_MORE_HUMANS: refresh tracked humans and reset wave counter
function AirWaveZone._onExitWaitForMoreHumans(self, humansInZone, humansInZoneNames)
  self.unitsInZone = humansInZone
  self.playerUnitsNames = humansInZoneNames
  self.currentWaveIndex = 0
end

-- NEXTWAVE → OVER (no more waves to deploy)
function AirWaveZone._canEnterOver(self)
  return self.currentWaveIndex >= #self.waves
end

-- NEXTWAVE → WAITING_FOR_NEXTWAVE (more waves remain)
function AirWaveZone._canEnterWaitForNextWave(self)
  return self.currentWaveIndex < #self.waves
end

-- enter WAITING_FOR_NEXTWAVE: set inter-wave timer and notify players
function AirWaveZone._onEnterWaitForNextWave(self)
  if not self.delayBeforeNextWave then
    self.delayBeforeNextWave = self.delayBetweenWaves
  end
  self.timeOfNextWave = timer.getTime() + self.delayBeforeNextWave
  if self.delayBeforeNextWave and self.delayBeforeNextWave > 0 then
    self:signalWaitToDeploy()
  end
  veaf.loggers.get(veafAirWaves.Id):debug("waiting %s seconds before spawning next wave(s)", veaf.lp(self.delayBeforeNextWave))
  veaf.loggers.get(veafAirWaves.Id):trace("self.timeOfNextWave=%s", veaf.lp(self.timeOfNextWave))
end

-- WAITING_FOR_NEXTWAVE → ACTIVE
function AirWaveZone._canEnterActive(self)
  return self.timeOfNextWave ~= nil and timer.getTime() >= self.timeOfNextWave
end

-- enter ACTIVE: deploy the next batch of enemy groups
function AirWaveZone._onEnterActive(self)
  local spawnedGroups, delayBeforeNextWave = self:deployWaves()
  if spawnedGroups then
    self.delayBeforeNextWave = delayBeforeNextWave or self.delayBetweenWaves
  else
    -- deploy failed (missing groups, spawn error): spawnedGroupsNames is already empty,
    -- so _canExitActive returns true on the very next check() cycle and the zone moves
    -- on to NEXTWAVE rather than getting stuck here.
    veaf.loggers.get(veafAirWaves.Id):warning(
      "AirWaveZone[%s]: deployWaves() returned no groups — wave %s will be skipped",
      veaf.p(self.name),
      veaf.p(self.currentWaveIndex)
    )
  end
end

-- ACTIVE tick: destroy AI units that have left the zone for too long
function AirWaveZone._tickActive(self)
  if not self.maxSecondsOutsideOfZoneIA then
    return
  end
  local triggerZone = veaf.getTriggerZone(self.triggerZoneName)
  for _, groupName in pairs(self.spawnedGroupsNames) do
    local group = Group.getByName(groupName)
    if group then
      local units = group:getUnits()
      if units then
        for _, unit in pairs(units) do
          local unitName = unit:getName()
          local outOfZone = false
          if triggerZone then
            outOfZone = not (veaf.isUnitInZone(unit, triggerZone))
          else
            local pos = unit:getPosition().p
            if pos then
              local distanceFromCenter = ((pos.x - self.zoneCenter.x) ^ 2 + (pos.z - self.zoneCenter.z) ^ 2) ^ 0.5
              outOfZone = (distanceFromCenter > self.zoneRadius)
            end
          end
          if outOfZone then
            local timestampOutOfZone = timer.getTime()
            if self.timestampsOutOfZone[unitName] then
              timestampOutOfZone = self.timestampsOutOfZone[unitName]
            else
              self.timestampsOutOfZone[unitName] = timestampOutOfZone
            end
            local seconds = timer.getTime() - timestampOutOfZone
            local secondsOffend = seconds - self.maxSecondsOutsideOfZoneIA
            if secondsOffend > 0 then
              veaf.loggers.get(veafAirWaves.Id):debug("destroy out of zone AI unitName=%s", veaf.lp(unitName))
              unit:destroy()
            end
          else
            self.timestampsOutOfZone[unitName] = nil
          end
        end
      end
    end
  end
end

-- ACTIVE → NEXTWAVE
function AirWaveZone._canExitActive(self)
  return self.isEnemyWaveDeadCallback(self, self.currentWaveIndex, self.spawnedGroupsNames)
end

-- exit ACTIVE: clean up surviving enemies and announce wave completion
function AirWaveZone._onExitActive(self)
  self:destroyCurrentWave()
  self:signalDestroyed()
end

-- enter OVER: announce victory
function AirWaveZone._onEnterOver(self)
  self:signalWon()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- FSM definition
-------------------------------------------------------------------------------------------------------------------------------------------------------------

AirWaveZone.FSM = {
  [veafAirWaves.STATUS_READY] = {
    transitions = {
      [veafAirWaves.STATUS_WAITING_FOR_MORE_HUMANS] = AirWaveZone._canEnterWaitForMoreHumans,
    },
  },
  [veafAirWaves.STATUS_WAITING_FOR_MORE_HUMANS] = {
    enter = AirWaveZone._onEnterWaitForMoreHumans,
    exit = AirWaveZone._onExitWaitForMoreHumans,
    transitions = {
      [veafAirWaves.STATUS_NEXTWAVE] = AirWaveZone._canEnterNextWave,
    },
  },
  [veafAirWaves.STATUS_NEXTWAVE] = {
    transitions = {
      [veafAirWaves.STATUS_OVER] = AirWaveZone._canEnterOver,
      [veafAirWaves.STATUS_WAITING_FOR_NEXTWAVE] = AirWaveZone._canEnterWaitForNextWave,
    },
  },
  [veafAirWaves.STATUS_WAITING_FOR_NEXTWAVE] = {
    enter = AirWaveZone._onEnterWaitForNextWave,
    transitions = {
      [veafAirWaves.STATUS_ACTIVE] = AirWaveZone._canEnterActive,
    },
  },
  [veafAirWaves.STATUS_ACTIVE] = {
    enter = AirWaveZone._onEnterActive,
    tick = AirWaveZone._tickActive,
    exit = AirWaveZone._onExitActive,
    transitions = {
      [veafAirWaves.STATUS_NEXTWAVE] = AirWaveZone._canExitActive,
    },
  },
  [veafAirWaves.STATUS_OVER] = {
    enter = AirWaveZone._onEnterOver,
    transitions = {},
  },
}

-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafAirWaves.add(aWaveZone, aName)
  local name = aName or aWaveZone:getName()
  veafAirWaves.zones[name] = aWaveZone
  return aWaveZone
end

function veafAirWaves.get(aNameString)
  return veafAirWaves.zones[aNameString]
end

veaf.loggers.get(veafAirWaves.Id):info(veaf.loggers.get(veafAirWaves.Id):getVersionInfo())
