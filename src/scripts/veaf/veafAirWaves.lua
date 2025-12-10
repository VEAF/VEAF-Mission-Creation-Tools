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
veafAirWaves.Version = "1.7.8"

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

function veafAirWaves.statusToString(status)
  if status == veafAirWaves.STATUS_READY then return "STATUS_READY" end
  if status == veafAirWaves.STATUS_WAITING_FOR_MORE_HUMANS then return "STATUS_WAITING_FOR_MORE_HUMANS" end
  if status == veafAirWaves.STATUS_ACTIVE then return "STATUS_ACTIVE" end
  if status == veafAirWaves.STATUS_WAITING_FOR_NEXTWAVE then return "STATUS_WAITING_FOR_NEXTWAVE" end
  if status == veafAirWaves.STATUS_NEXTWAVE then return "STATUS_NEXTWAVE" end
  if status == veafAirWaves.STATUS_OVER then return "STATUS_OVER" end
  return ""
end
veafAirWaves.STATUS_READY = 1
veafAirWaves.STATUS_WAITING_FOR_MORE_HUMANS = 1.5
veafAirWaves.STATUS_ACTIVE = 2
veafAirWaves.STATUS_WAITING_FOR_NEXTWAVE = 2.5
veafAirWaves.STATUS_NEXTWAVE = 3
veafAirWaves.STATUS_OVER = 4

veafAirWaves.MINIMUM_LIFE_FOR_AI_IN_PERCENT = 0

veafAirWaves.MAX_SECONDS_OUTSIDE_OF_ZONE_PLAYERS = nil -- no outside of zone mechanism by default for players
veafAirWaves.MAX_SECONDS_OUTSIDE_OF_ZONE_IA = 30
veafAirWaves.DEFAULT_MESSAGE_START = "%s - online"
veafAirWaves.DEFAULT_MESSAGE_WAIT_FOR_HUMANS = "%s - waiting %s seconds for more players"
veafAirWaves.DEFAULT_MESSAGE_WAIT_TO_DEPLOY = "%s - waiting %s seconds before next wave"
veafAirWaves.DEFAULT_MESSAGE_DEPLOY = "%s - deploying wave %s"
veafAirWaves.DEFAULT_MESSAGE_DEPLOY_PLAYERS = "Wave %s deploying, %s"
veafAirWaves.DEFAULT_MESSAGE_OUTSIDE_OF_ZONE_PLAYERS = "%s - you've been outside of the zone for %s seconds; go back inside, or you'll be destroyed after %s seconds."
veafAirWaves.DEFAULT_MESSAGE_DESTROYED = "%s - wave %s has been destroyed"
veafAirWaves.DEFAULT_MESSAGE_WON = "%s - won (no more waves)"
veafAirWaves.DEFAULT_MESSAGE_LOST = "%s - lost (no more players)"
veafAirWaves.DEFAULT_MESSAGE_STOP = "%s - offline"

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
  if triggerZone then
    self:setZoneCenter({ x=triggerZone.x, y=triggerZone.y})
    self:setZoneRadius(triggerZone.radius)
  else
    veaf.loggers.get(veafAirWaves.Id):error("AirWaveZone[%s]:setTriggerZone(): trigger zone [%s] does not exist", veaf.p(self.name), veaf.p(value))
  end
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
  local vec3 = coord.LLtoLO(_lat, _lon)
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
  veaf.loggers.get(veafAirWaves.Id):debug(string.format("AirWaveZone[%s]:addWave() : %s", veaf.p(self.name), veaf.p(arg)))
---@diagnostic disable-next-line: undefined-field this is a field defined in the vararg api
  local nArgs = arg.n or 0
  if arg and nArgs > 0 then
    local groups = {}
    local number = 1
    local bias = 0
    local delay = nil
    for i = 1, nArgs, 1 do
      local parameter = arg[i]
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
              table.insert(groups, parameter)
            end
          end
          break
        end
      end
    end
    if not self.waves then
      self.waves = {}
    end
    table.insert(self.waves, {groups=groups, number=number or 1, bias=bias or 0, delay=delay})
  end
  return self
end

---reset the waves table to zero; useful when deep copying a zone to reset the waves and set something different
---@return table self
function AirWaveZone:resetWaves()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:resetWaves()", veaf.p(self.name))
  self.waves = {}
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

function AirWaveZone:setMessageWaitForHumans(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageWaitForHumans()", veaf.p(self.name))
  self.messageWaitForHumans = value
  return self
end

---Set the onWaitForHumans callback
---@param value function takes 3 parameters: the zone name (string), the wave index (int), the monitored player units (table)
---@return table self
function AirWaveZone:setOnWaitForHumans(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnWaitForHumans()", veaf.p(self.name))
  self.onWaitForHumans = value
  return self
end

function AirWaveZone:setMessageWaitToDeploy(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageWaitToDeploy()", veaf.p(self.name))
  self.messageWaitToDeploy = value
  return self
end

---Set the onWaitToDeploy callback
---@param value function takes 3 parameters: the zone name (string), the wave index (int), the monitored player units (table)
---@return table self
function AirWaveZone:setOnWaitToDeploy(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnWaitToDeploy()", veaf.p(self.name))
  self.onWaitToDeploy = value
  return self
end

function AirWaveZone:setMessageDeploy(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageDeploy()", veaf.p(self.name))
  self.messageDeploy = value
  return self
end

function AirWaveZone:setMessageDeployPlayers(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageDeployPlayers()", veaf.p(self.name))
  self.messageDeployPlayers = value
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

function AirWaveZone:setMessageOutsideOfZone(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMessageOutsideOfZone()", veaf.p(self.name))
  self.messageOutsideOfZone = value
  return self
end

---Set the onOutsideOfZone callback
---@param value function takes 3 parameters: the zone name (string), the wave index (int), the monitored player units (table)
---@return table self
function AirWaveZone:setOnOutsideOfZone(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setOnOutsideOfZone()", veaf.p(self.name))
  self.onOutsideOfZone = value
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

---Sets the default delay in seconds between waves of enemy planes
---@param value number a delay in seconds
---@return table self
function AirWaveZone:setDelayBetweenWaves(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setDelayBetweenWaves(%s)", veaf.p(self.name), veaf.p(value))
  self.delayBetweenWaves = value
  return self
end

---Sets the delay in seconds between the first human in zone and the actual activation of the zone
---@param value number a delay in seconds
---@return table self
function AirWaveZone:setDelayBeforeActivation(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setDelayBeforeActivation(%s)", veaf.p(self.name), veaf.p(value))
  self.delayBeforeActivation = value
  return self
end

function AirWaveZone:setResetWhenDying(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setResetWhenDying(%s)", veaf.p(self.name), veaf.p(value))
  self.resetWhenDying = value
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

---Sets the maximum number of seconds an IA can stay out of its zone before being destroyed
---@param value number a delay in seconds
---@return table self
function AirWaveZone:setMaxSecondsOutsideOfZoneIA(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMaxSecondsOutsideOfZoneIA(%s)", veaf.p(self.name), veaf.p(value))
  self.maxSecondsOutsideOfZoneIA = value
  return self
end

---Disables the check for IA out of zone.
---@return table self
function AirWaveZone:disableOutsideOfZoneIA()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:disableOutsideOfZoneIA()", veaf.p(self.name))
  self.maxSecondsOutsideOfZoneIA = nil
  return self
end

---Sets the maximum number of seconds a player can stay out of its zone before being destroyed; players will be messaged as soon as they exit the zone, and every check
---@param value number a delay in seconds
---@return table self
function AirWaveZone:setMaxSecondsOutsideOfZonePlayers(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMaxSecondsOutsideOfZonePlayers(%s)", veaf.p(self.name), veaf.p(value))
  self.maxSecondsOutsideOfZonePlayers = value
  return self
end

---Disables the check for players out of zone.
---@return table self
function AirWaveZone:disableOutsideOfZonePlayers()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:disableOutsideOfZonePlayers()", veaf.p(self.name))
  self.maxSecondsOutsideOfZonePlayers = nil
  return self
end

function AirWaveZone:_setState(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:_setState(%s)", veaf.p(self.name), veaf.p(veafAirWaves.statusToString(value)))
  self.state = value
  return self
end

---the function that decides if a wave is dead or not (as a set of groups and units)
---@param callback function the callback function will be called with 3 parameters: a zone, the wave index number, the spawned groups names list; it must return a boolean
function AirWaveZone:setIsEnemyWaveDeadCallback(callback)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setIsEnemyWaveDeadCallback()", veaf.p(self.name))
  self.isEnemyWaveDeadCallback = callback
  return self
end

---the function that decides if a group is dead or not (individually)
---@param callback function the callback function will be called with 3 parameters: a zone, the wave index number, a DCS group table; it must return a boolean
function AirWaveZone:setIsEnemyGroupDeadCallback(callback)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setIsEnemyGroupDeadCallback()", veaf.p(self.name))
  self.isEnemyGroupDeadCallback = callback
  return self
end

---Sets the minimum percentage of life that an AI unit is supposed to have to be considered alive
---@param value number percentage
---@return table
function AirWaveZone:setMinimumLifeForAiInPercent(value)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setMinimumLifeForAiInPercent(%s)", veaf.p(self.name), veaf.p(value))
  self.minimumLifeForAiInPercent = value
  return self
end

--- the function that handles crippled enemy units
---@param callback function the callback function will be called with 3 parameters: a zone, the wave index number, a DCS unit table; it must do what it wants with the unit
function AirWaveZone:setHandleCrippledEnemyUnitCallback(callback)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:setHandleCrippledEnemyUnitCallback()", veaf.p(self.name))
  self.handleCrippledEnemyUnitCallback = callback
  return self
end

function AirWaveZone:reset()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:reset()", veaf.p(self.name))

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
  if not group then return true end
  --veaf.loggers.get(veafAirWaves.Id):trace("group:getName()=%s", veaf.p(group:getName()))

  local groupAtLeastOneUnitAlive = false
  local category = group:getCategory()
  local units = group:getUnits()
  if units then
    for _,unit in pairs(units) do
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
        if category == 0 --[[airplanes]] or category == 1 --[[helicopters]] then
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
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:handleCrippledEnemyUnit(%s)", veaf.p(self.name), veaf.p(waveNumber))
  if not unit then return end
  veaf.loggers.get(veafAirWaves.Id):debug("unit:getName()=%s", veaf.p(unit:getName()))
  -- simply despawn the unit
  unit:destroy()
end

function AirWaveZone:getPlayerUnitsNames()
  if not self.playerHumanUnitsNames then
    self.playerHumanUnitsNames = {}
    for _, unit in pairs(mist.DBs.humansByName) do
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
            table.insert(self.playerHumanUnitsNames, unit.unitName)
          end
        end
      end
    end
  end
  return self.playerHumanUnitsNames
end

function AirWaveZone:check()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:check() -> self.state=%s", veaf.p(self.name), veaf.p(veafAirWaves.statusToString(self.state)))
  veaf.loggers.get(veafAirWaves.Id):trace("AirWaveZone[%s]:check() -> timer.getTime()=%s", veaf.p(self.name), veaf.p(timer.getTime()))

  local function getHumansInZone()
    local resultUnitsByName = {}
    local resultUnitsNames = {}
    local resultUnits = {}
    local unitNames = self:getPlayerUnitsNames()
    local triggerZone = veaf.getTriggerZone(self.triggerZoneName)
    local humanUnits = nil
    if triggerZone then
      if triggerZone.type == 0 then -- circular
        humanUnits = mist.getUnitsInZones(unitNames, {self.triggerZoneName})
      elseif triggerZone.type == 2 then -- quad point
        humanUnits = mist.getUnitsInPolygon(unitNames, triggerZone.verticies)
      end
    elseif self.zoneCenter then
      humanUnits = veaf.findUnitsInCircle(self.zoneCenter, self.zoneRadius, false, unitNames)
    else
      veaf.loggers.get(veafAirWaves.Id):error("No triggerzone, and no zone center/radius defined!")
    end
    for _, unit in pairs(humanUnits) do
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
              veaf.loggers.get(veafAirWaves.Id):debug("destroy out of zone player unitName=%s", veaf.p(unitName))
              unit:destroy()
            else
              veaf.loggers.get(veafAirWaves.Id):debug("flak out of zone player unitName=%s", veaf.p(unitName))
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
      veaf.loggers.get(veafAirWaves.Id):debug("player is dead or despawned in %s", veaf.p(self:getName()))
      if self.state ~= veafAirWaves.STATUS_OVER then
        -- signal that all players have been destroyed
        self:signalLost()
      end
      if self.resetWhenDying then
        -- reset the zone
        self:stop()
        self:start()
      end
    end
  end

  if self.state == veafAirWaves.STATUS_READY then
    if humansInZone and #humansInZone > 0 then
      -- store the human units that we're going to monitor
      self.unitsInZone = humansInZone
      self.playerUnitsNames = humansInZoneNames
      self:_setState(veafAirWaves.STATUS_WAITING_FOR_MORE_HUMANS)
      if self.delayBeforeActivation and self.delayBeforeActivation > 0 then
        self:signalWaitForHumans()
      end
      self.timeOfActivation = timer.getTime() + self.delayBeforeActivation
      veaf.loggers.get(veafAirWaves.Id):debug("waiting %s seconds before activation", veaf.p(self.delayBeforeActivation))
      veaf.loggers.get(veafAirWaves.Id):trace("self.timeOfActivation=%s", veaf.p(self.timeOfActivation))
      veaf.loggers.get(veafAirWaves.Id):debug("restart the check immediately")
      -- restart the check immediately (we don't want to wait for the next state to be processed)
      self:check()
    end
  elseif self.state == veafAirWaves.STATUS_WAITING_FOR_MORE_HUMANS then
    -- wait until the delay has passed
    if self.timeOfActivation and timer.getTime() >= self.timeOfActivation then
      -- zone is ready, check for players entering
      local humansInZone, humanInZoneNames = getHumansInZone()
      if humansInZone and #humansInZone > 0 then
        -- store the human units that we're going to monitor
        self.unitsInZone = humansInZone
        self.playerUnitsNames = humanInZoneNames
        -- reset wave index
        self.currentWaveIndex = 0
        self:_setState(veafAirWaves.STATUS_NEXTWAVE)
        -- restart the check immediately (we don't want to wait for the next state to be processed)
        self:check()
      end
    end
  elseif self.state == veafAirWaves.STATUS_NEXTWAVE then
    -- wave has been destroyed, or it's the first time a wave has to be deployed; check if there is a next one and deploy it
    if self.currentWaveIndex < #self.waves then
      if not self.delayBeforeNextWave then
        self.delayBeforeNextWave = self.delayBetweenWaves
      end
      self:_setState(veafAirWaves.STATUS_WAITING_FOR_NEXTWAVE)
      if self.delayBeforeNextWave and self.delayBeforeNextWave > 0 then
        self:signalWaitToDeploy()
      end
      self.timeOfNextWave = timer.getTime() + self.delayBeforeNextWave
      veaf.loggers.get(veafAirWaves.Id):debug("waiting %s seconds before spawning next wave(s)", veaf.p(self.delayBeforeNextWave))
      veaf.loggers.get(veafAirWaves.Id):trace("self.timeOfNextWave=%s", veaf.p(self.timeOfNextWave))
      -- restart the check immediately (we don't want to wait for the next state to be processed)
      self:check()
    else
      self:signalWon()
      self:_setState(veafAirWaves.STATUS_OVER)
    end
  elseif self.state == veafAirWaves.STATUS_WAITING_FOR_NEXTWAVE then
    -- wait until the delay has passed
    if self.timeOfNextWave and timer.getTime() >= self.timeOfNextWave then
      -- deploy the next wave
      local spawnedGroups, delayBeforeNextWave = self:deployWaves()
      if spawnedGroups then
        self.delayBeforeNextWave = delayBeforeNextWave or self.delayBetweenWaves
        self:_setState(veafAirWaves.STATUS_ACTIVE)
      end
    end
  elseif self.state == veafAirWaves.STATUS_ACTIVE then
    -- zone is active
    
    -- check if the current wave is still alive
    local waveIsDead = self.isEnemyWaveDeadCallback(self, self.currentWaveIndex, self.spawnedGroupsNames)
    if waveIsDead then
      -- clean up any eventual remaining group of the wave
      self:destroyCurrentWave()
      -- signal that wave has been destroyed
      self:signalDestroyed()
      -- prepare next wave
      self:_setState(veafAirWaves.STATUS_NEXTWAVE)
      -- restart the check immediately (we don't want to wait for the next state to be processed)
      self:check()
    else
      -- check if any IA wandered out of the zone for longer than it should have (maxSecondsOutsideOfZoneIA)
      local triggerZone = veaf.getTriggerZone(self.triggerZoneName)
      for _, groupName in pairs(self.spawnedGroupsNames) do
        local group = Group.getByName(groupName)
        if group then
          local units = group:getUnits()
          if units then
            for _, unit in pairs(units) do
              local unitName = unit:getName()
              local outOfZone = false
              if self.maxSecondsOutsideOfZoneIA then -- no need to check if feature is disabled
                if triggerZone then
                  outOfZone = not(veaf.isUnitInZone(unit, triggerZone))
                else
                  local pos = unit:getPosition().p
                  if pos then -- you never know O.o
                      local distanceFromCenter = ((pos.x - self.zoneCenter.x)^2 + (pos.z - self.zoneCenter.z)^2)^0.5
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
                    -- destroy the IA
                    veaf.loggers.get(veafAirWaves.Id):debug("destroy out of zone AI unitName=%s", veaf.p(unitName))
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
    end
  elseif self.state == veafAirWaves.STATUS_OVER then
    -- zone has still to be reset to restart
  end
  if self.checkFunctionSchedule then
    -- deschedule if needed
    mist.removeFunction(self.checkFunctionSchedule)
    self.checkFunctionSchedule = nil
  end
  self.checkFunctionSchedule = mist.scheduleFunction(AirWaveZone.check, {self}, timer.getTime() + veafAirWaves.WATCHDOG_DELAY + math.random(0, 2)) -- randomize reschedules so not all zones are working at the same time
end

function AirWaveZone:chooseGroupsToDeploy()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:chooseGroupsToDeploy()", veaf.p(self.name))

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
      if groupsToChooseFrom and type(groupsToChooseFrom) == "table" and numberOfGroups and type(numberOfGroups) == "number" and bias and type(bias) == "number" then
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
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:deployWaves()", veaf.p(self.name))
  self.spawnedGroupsNames = {}
  local groupsToDeployForTheseWaves = {}
  local lastDelay
  repeat
    self.currentWaveIndex = self.currentWaveIndex + 1
    local groupsToDeploy, delay = self:chooseGroupsToDeploy()
    veaf.loggers.get(veafAirWaves.Id):debug("groupsToDeploy=%s", veaf.p(groupsToDeploy))
    veaf.loggers.get(veafAirWaves.Id):debug("delay=%s", veaf.p(delay))
    lastDelay = delay
    for _, group in pairs(groupsToDeploy) do
      table.insert(groupsToDeployForTheseWaves, group)
    end
  until not lastDelay or lastDelay >= 0 or self.currentWaveIndex >= #self.waves
  if groupsToDeployForTheseWaves then
    local zoneCenter = {}
    if self.triggerZoneName then
      local triggerZone = veaf.getTriggerZone(self.triggerZoneName)
      zoneCenter.x = triggerZone.x
      zoneCenter.z = triggerZone.y
      zoneCenter.y = 0
    elseif self.zoneCenter then
      zoneCenter = self.zoneCenter
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
        veaf.loggers.get(veafAirWaves.Id):debug("running command [%s]", veaf.p(command))
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
        local groupData = mist.getGroupData(groupName)
        veaf.loggers.get(veafAirWaves.Id):trace("groupData=%s", veaf.p(groupData))
        if not groupData then
          veaf.loggers.get(veafAirWaves.Id):error("group [%s] does not exist in the mission!", veaf.p(groupName))
        else
          local spawnSpot = {x = zoneCenter.x - self.respawnDefaultOffset.lonDelta, y = zoneCenter.y, z = zoneCenter.z + self.respawnDefaultOffset.latDelta}
          -- Try and set the spawn spot at the place the group has been set in the Mission Editor.
          -- Unfortunately this is sometimes not possible because DCS is not returning the group units for some reason.
          -- When this happens we'll default to the default spawn offset (same as spawning with VEAF commands)
          if not groupData.units[1] then
            veaf.loggers.get(veafAirWaves.Id):warn("group [%s] does not have any unit!", veaf.p(groupName))
          else
            spawnSpot =  { x = groupData.units[1].x, y = groupData.units[1].alt, z = groupData.units[1].y }
          end
          veaf.loggers.get(veafAirWaves.Id):trace("spawnSpot=%s", veaf.p(spawnSpot))
          local vars = {}
          vars.point = mist.getRandPointInCircle(spawnSpot, self.respawnRadius)
          vars.point.z = vars.point.y
          vars.point.y = spawnSpot.y
          vars.gpName = groupName
          vars.action = 'clone'
          vars.route = mist.getGroupRoute(groupName, 'task')
          veaf.loggers.get(veafAirWaves.Id):trace("vars=%s", veaf.p(vars))
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
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalStart()", veaf.p(self.name))
  if not self.silent then
    local msg = string.format(self.messageStart, self:getDescription())
    for coalition, _ in pairs(self.playerCoalitions) do
      trigger.action.outTextForCoalition(coalition, msg, 15)
    end
  end
  if self.onStart then
    self.onStart(self.name, self.playerUnitsNames)
  end
end

function AirWaveZone:signalWaitForHumans()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalWaitForHumans()", veaf.p(self.name))
  if not self.silent then
    self:signalToPlayers(string.format(self.messageWaitForHumans, self:getDescription(), self.delayBeforeActivation))
  end
  if self.onWaitForHumans then
    self.onWaitForHumans(self.name, self.playerUnitsNames)
  end
end

function AirWaveZone:signalWaitToDeploy()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalWaitToDeploy()", veaf.p(self.name))
  if not self.silent then
    self:signalToPlayers(string.format(self.messageWaitToDeploy, self:getDescription(), self.delayBeforeNextWave))
  end
  if self.onWaitToDeploy then
    self.onWaitToDeploy(self.name, self.playerUnitsNames)
  end
end

function AirWaveZone:signalDeploy()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalDeploy()", veaf.p(self.name))
  if not self.silent then
    -- messages to all
    local msg = string.format(self.messageDeploy, self:getDescription(), self.currentWaveIndex)
    for coalition, _ in pairs(self.playerCoalitions) do
      trigger.action.outTextForCoalition(coalition, msg, 15)
    end
    -- messages to players with BRAA
    if self.unitsInZone then
      local groupsAlreadyMessaged = {}
      for _, unitInZone in pairs(self.unitsInZone) do
        -- compute BRAA of closest group
        local braa = { bearing = -1, distance = 9999}
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
            trigger.action.outTextForGroup(groupId, string.format(self.messageDeployPlayers, self.currentWaveIndex, braaS), 15)
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
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalDestroyed()", veaf.p(self.name))
  if not self.silent then
    self:signalToPlayers(string.format(self.messageDestroyed, self:getDescription(), self.currentWaveIndex))
  end
  if self.onDestroyed then
    self.onDestroyed(self.name, self.currentWaveIndex, self.playerUnitsNames)
  end
end

function AirWaveZone:signalOutsideOfZone(playerUnitName, seconds)
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalOutsideOfZone(player=%s, seconds=%s)", veaf.p(self.name), veaf.p(playerUnitName), veaf.p(seconds))
  if not self.silent then
    veaf.outTextForUnit(playerUnitName, string.format(self.messageOutsideOfZone, self:getDescription(), seconds, self.maxSecondsOutsideOfZonePlayers), 15)
  end
  if self.onOutsideOfZone then
    self.onOutsideOfZone(self.name, playerUnitName, seconds)
  end
end

function AirWaveZone:signalWon()
  veaf.loggers.get(veafAirWaves.Id):debug("AirWaveZone[%s]:signalWon()", veaf.p(self.name))
  if not self.silent then
    self:signalToPlayers(string.format(self.messageWon, self:getDescription()))
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
  self:reset()
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

veaf.loggers.get(veafAirWaves.Id):info(veaf.loggers.get(veafAirWaves.Id):getVersionInfo(veafAirWaves.Version))