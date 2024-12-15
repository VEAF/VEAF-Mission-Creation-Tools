------------------------------------------------------------------
-- VEAF Ground Battle (a.k.a. Slightly Less Dumb Ground IA) for DCS World
-- By Zip (2024-25)
--
-- Features:
-- ---------
-- * Combat groups can be managed by the mission maker (API calls, radio menus) and by the pilots (radio menus, markers, remote commands)
--
-- See the documentation : https://veaf.github.io/documentation/mission-maker/groundBattle.html
------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafGroundBattle = {}

--- Identifier. All output in the log will start with this.
veafGroundBattle.Id = "GROUNDBATTLE - "

--- Version.
veafGroundBattle.Version = "0.0.1"

-- trace level, specific to this module
veafGroundBattle.LogLevel = "trace"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.loggers.new(veafGroundBattle.Id, veafGroundBattle.LogLevel)

veafGroundBattle.battles = {}

veafGroundBattle.WATCHDOG_DELAY = 1

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- GroundBattle class
-------------------------------------------------------------------------------------------------------------------------------------------------------------

GroundBattle = {}
function GroundBattle.init(object)
  -- technical name (GroundBattle instance name)
  object.name = nil
  -- description for the messages
  object.description = nil
  -- draw the battle points/lines/zones on screen
  object.draw = false
  -- coalitions of the players (only human units from these coalitions will be monitored)
  object.playerCoalitions = {}
  -- player units (only they are concerned by the messages)
  object.playerUnitsNames = {}
  -- allied battle groups
  object.alliedGroups = {}
  -- silent means no message is emitted
  object.silent = false
  -- message when the battle starts
  object.messageStart = veafGroundBattle.DEFAULT_MESSAGE_START
  -- event when the battle starts
  object.onStart = nil
  -- message when the battle is won
  object.messageWon = veafGroundBattle.DEFAULT_MESSAGE_WON
  -- event when the battle is won
  object.onWon = nil
  -- message when the battle is lost
  object.messageLost = veafGroundBattle.DEFAULT_MESSAGE_LOST
  -- event when the battle is lost
  object.onLost = nil
  -- message when the battle is ended (deactivated)
  object.messageStop = veafGroundBattle.DEFAULT_MESSAGE_STOP
  -- event when the battle is ended (deactivated)
  object.onStop = nil
  -- IA units that are being watched
  object.unitsInZone = {}
  -- the drawing objects that has been used to draw the battle
  object.zoneDrawings = {}
  -- the scheduled state of the :check() function
  object.checkFunctionSchedule = nil
  -- enemy that has been spotted
  object.enemyData = {}
end

function GroundBattle.statusToString(status)
  if status == GroundBattle.STATUS_READY then return "STATUS_READY" end
  if status == GroundBattle.STATUS_ACTIVE then return "STATUS_ACTIVE" end
  if status == GroundBattle.STATUS_OVER then return "STATUS_OVER" end
  return ""
end
GroundBattle.STATUS_READY = 1
GroundBattle.STATUS_ACTIVE = 2
GroundBattle.STATUS_OVER = 4

function GroundBattle:new(objectToCopy)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle:new()")
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self

  -- init the new object
  GroundBattle.init(objectToCreate)

  return objectToCreate
end

-- technical name (GroundBattle instance name)
function GroundBattle:setName(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[]:setName(%s)", veaf.p(value))
  self.name = value
  return veafGroundBattle.add(self) -- add the battle to the list as soon as a name is available to index it
end

-- technical name (GroundBattle instance name)
function GroundBattle:getName()
  return self.name or self.description
end

-- description for the messages
function GroundBattle:setDescription(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setDescription(%s)", veaf.p(self:getName()), veaf.p(value))
  self.description = value
  return self
end

-- description for the messages
function GroundBattle:getDescription()
  return self.description
end

-- draw the battle points/lines/zones on screen
function GroundBattle:setDraw(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setDraw(%s)", veaf.p(self:getName()), veaf.p(value))
  self.draw = value
  return self
end

-- draw the battle points/lines/zones on screen
function GroundBattle:getDraw()
  return self.draw
end

-- coalitions of the players (only human units from these coalitions will be monitored)
function GroundBattle:setPlayerCoalitions(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setPlayerCoalitions(%s)", veaf.p(self:getName()), veaf.p(value))
  self.playerCoalitions = value
  return self
end

-- coalitions of the players (only human units from these coalitions will be monitored)
function GroundBattle:getPlayerCoalitions()
  return self.playerCoalitions
end

-- player units (only they are concerned by the messages)
function GroundBattle:setPlayerUnitsNames(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setPlayerUnitsNames(%s)", veaf.p(self:getName()), veaf.p(value))
  self.playerUnitsNames = value
  return self
end

-- player units (only they are concerned by the messages)
function GroundBattle:getPlayerUnitsNames()
  return self.playerUnitsNames
end

-- allied battle groups
function GroundBattle:setAlliedGroups(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setAlliedGroups(%s)", veaf.p(self:getName()), veaf.p(value))
  self.alliedGroups = value
  return self
end

-- allied battle groups
function GroundBattle:getAlliedGroups()
  return self.alliedGroups
end

-- silent means no message is emitted
function GroundBattle:setSilent(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setSilent(%s)", veaf.p(self:getName()), veaf.p(value))
  self.silent = value
  return self
end

-- silent means no message is emitted
function GroundBattle:getSilent()
  return self.silent
end

-- message when the battle starts
function GroundBattle:setMessageStart(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setMessageStart(%s)", veaf.p(self:getName()), veaf.p(value))
  self.messageStart = value
  return self
end

-- message when the battle starts
function GroundBattle:getMessageStart()
  return self.messageStart
end

-- event when the battle starts
function GroundBattle:setOnStart(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setOnStart(%s)", veaf.p(self:getName()), veaf.p(value))
  self.onStart = value
  return self
end

-- event when the battle starts
function GroundBattle:getOnStart()
  return self.onStart
end

-- message when the battle is won
function GroundBattle:setMessageWon(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setMessageWon(%s)", veaf.p(self:getName()), veaf.p(value))
  self.messageWon = value
  return self
end

-- message when the battle is won
function GroundBattle:getMessageWon()
  return self.messageWon
end

-- event when the battle is won
function GroundBattle:setOnWon(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setOnWon(%s)", veaf.p(self:getName()), veaf.p(value))
  self.onWon = value
  return self
end

-- event when the battle is won
function GroundBattle:getOnWon()
  return self.onWon
end

-- message when the battle is lost
function GroundBattle:setMessageLost(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setMessageLost(%s)", veaf.p(self:getName()), veaf.p(value))
  self.messageLost = value
  return self
end

-- message when the battle is lost
function GroundBattle:getMessageLost()
  return self.messageLost
end

-- event when the battle is lost
function GroundBattle:setOnLost(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setOnLost(%s)", veaf.p(self:getName()), veaf.p(value))
  self.onLost = value
  return self
end

-- event when the battle is lost
function GroundBattle:getOnLost()
  return self.onLost
end

-- message when the battle is ended (deactivated)
function GroundBattle:setMessageStop(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setMessageStop(%s)", veaf.p(self:getName()), veaf.p(value))
  self.messageStop = value
  return self
end

-- message when the battle is ended (deactivated)
function GroundBattle:getMessageStop()
  return self.messageStop
end

-- event when the battle is ended (deactivated)
function GroundBattle:setOnStop(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setOnStop(%s)", veaf.p(self:getName()), veaf.p(value))
  self.onStop = value
  return self
end

-- event when the battle is ended (deactivated)
function GroundBattle:getOnStop()
  return self.onStop
end

-- IA units that are being watched
function GroundBattle:setUnitsInZone(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setUnitsInZone(%s)", veaf.p(self:getName()), veaf.p(value))
  self.unitsInZone = value
  return self
end

-- IA units that are being watched
function GroundBattle:getUnitsInZone()
  return self.unitsInZone
end

-- the drawing objects that has been used to draw the battle
function GroundBattle:setZoneDrawings(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setZoneDrawings(%s)", veaf.p(self:getName()), veaf.p(value))
  self.zoneDrawings = value
  return self
end

-- the drawing objects that has been used to draw the battle
function GroundBattle:getZoneDrawings()
  return self.zoneDrawings
end

-- the scheduled state of the :check() function
function GroundBattle:setCheckFunctionSchedule(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("GroundBattle[%s]:setCheckFunctionSchedule(%s)", veaf.p(self:getName()), veaf.p(value))
  self.checkFunctionSchedule = value
  return self
end

-- the scheduled state of the :check() function
function GroundBattle:getCheckFunctionSchedule()
  return self.checkFunctionSchedule
end



-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- BattleGroup class
-------------------------------------------------------------------------------------------------------------------------------------------------------------

BattleGroup = {}

BattleGroup.STATUS_READY = 1
BattleGroup.STATUS_ACTIVE = 2
BattleGroup.STATUS_ADVANCING = 3
BattleGroup.STATUS_RETREATING = 4
BattleGroup.STATUS_TAKING_FIRE = 5
BattleGroup.STATUS_SUPPRESSED = 6

function BattleGroup.statusToString(status)
  if status == BattleGroup.STATUS_READY then return "STATUS_READY" end
  if status == BattleGroup.STATUS_ACTIVE then return "STATUS_ACTIVE" end
  if status == BattleGroup.STATUS_ADVANCING then return "STATUS_ADVANCING" end
  if status == BattleGroup.STATUS_RETREATING then return "STATUS_RETREATING" end
  if status == BattleGroup.STATUS_TAKING_FIRE then return "STATUS_TAKING_FIRE" end
  if status == BattleGroup.STATUS_SUPPRESSED then return "STATUS_SUPPRESSED" end
  return ""
end

BattleGroup.RADIO_RETREATING = 1
BattleGroup.RADIO_MESSAGES = {
  [BattleGroup.RADIO_RETREATING] = "Retreating",
}

BattleGroup.CACHE_CENTER = { name="center", ttl=10 }
BattleGroup.CACHE_ENEMY_COALITION = {name = "enemyCoalition", ttl = VeafCache.LIVE_FOREVER }
BattleGroup.CACHE_ENEMIES = { name = "enemies", ttl = 15 }
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CTOR

function BattleGroup.init(object)
  -- technical name (BattleGroup instance name)
  object.name = nil
  -- description for the messages
  object.description = nil
  -- coalition this group belongs to
  object.coalition = coalition.side.BLUE
  -- DCS objects
  object.dcsObjects = {}
  -- silent means no message is emitted
  object.silent = false
  -- status, from one of the BattleGroup.STATUS_xxx constants
  object.status = BattleGroup.STATUS_READY
  -- cache for resource-intensive calculations
  object.cache = VeafCache:new()
end

function BattleGroup:new(objectToCopy)
  veaf.loggers.get(veafGroundBattle.Id):debug("BattleGroup:new()")
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self

  -- init the new object
  BattleGroup.init(objectToCreate)

  return objectToCreate
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTIES

-- technical name (BattleGroup instance name)
function BattleGroup:setName(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("BattleGroup[]:setName(%s)", veaf.p(value))
  self.name = value
  self.cache:setName("BattleGroup:"..veaf.p(value))
  return veafGroundBattle.add(self) -- add the battle to the list as soon as a name is available to index it
end

-- technical name (BattleGroup instance name)
function BattleGroup:getName()
  return self.name or self.description
end

-- description for the messages
function BattleGroup:setDescription(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("BattleGroup[%s]:setDescription(%s)", veaf.p(self:getName()), veaf.p(value))
  self.description = value
  return self
end

-- description for the messages
function BattleGroup:getDescription()
  return self.description
end

-- coalition this group belongs to
function BattleGroup:setCoalition(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("BattleGroup[%s]:setCoalition(%s)", veaf.p(self:getName()), veaf.p(value))
  self.coalition = value
  -- reset cache
  self:_getCache():delCachedData(BattleGroup.CACHE_ENEMY_COALITION)
  return self
end

-- coalition this group belongs to
function BattleGroup:getCoalition()
  return self.coalition
end

-- silent means no message is emitted
function BattleGroup:setSilent(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("BattleGroup[%s]:setSilent(%s)", veaf.p(self:getName()), veaf.p(value))
  self.silent = value
  return self
end

-- silent means no message is emitted
function BattleGroup:getSilent()
  return self.silent
end

-- add DCS object
function BattleGroup:addDcsObject(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("BattleGroup[%s]:addDcsObject(%s)", veaf.p(self:getName()), veaf.p(value))
  if value then 
    if not self.dcsObjects then
      self.dcsObjects = {}
    end
    self.dcsObjects[value:getID()] = value
  end
  return self
end

-- remove DCS object
function BattleGroup:delDcsObject(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("BattleGroup[%s]:delDcsObject(%s)", veaf.p(self:getName()), veaf.p(value))
  if value and self.dcsObjects then
    self.dcsObjects[value:getID()] = nil
  end
  return self
end

-- add DCS objects
function BattleGroup:getDcsObjects()
  return self.dcsObjects
end

-- enemy that has been spotted
function BattleGroup:getEnemyData()
  return self.enemyData
end

-- status, from one of the BattleGroup.STATUS_xxx constants
function BattleGroup:setStatus(value)
  veaf.loggers.get(veafGroundBattle.Id):debug("BattleGroup[%s]:setStatus(%s)", veaf.p(self:getName()), veaf.p(value))
  self.status = value
  return self
end

-- status, from one of the BattleGroup.STATUS_xxx constants
function BattleGroup:getStatus()
  return self.status
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- COMPUTED PROPERTIES

-- browse all the units in the battle group, and determines the barycenter of their positions and the radius that encloses them all.
function BattleGroup:getAlliedBattlegroupPosition()
  local result = self:_getCache():getCachedData(BattleGroup.CACHE_BATTLEGROUP_POSITION.name)
  if result then
    return result
  else
    -- compute the barycenter of all allied units
    result = veaf.calculateBarycenterAndRadius(self:getDcsObjects())
    self:_getCache():setCachedData(BattleGroup.CACHE_BATTLEGROUP_POSITION.name, result, BattleGroup.CACHE_BATTLEGROUP_POSITION.ttl)
  end
end

-- coalition this group belongs to
function BattleGroup:getEnemyCoalition()
  local result = self:_getCache():getCachedData(BattleGroup.CACHE_ENEMY_COALITION.name)
  if result then
    return result
  else
    result = veaf.getEnemyCoalition(self:getCoalition())
    self:_getCache():setCachedData(BattleGroup.CACHE_ENEMY_COALITION.name, result, BattleGroup.CACHE_ENEMY_COALITION.ttl)
  end
end

-- browse all the units in the enemy coalition and determines if they're close enough to the battle to be considered in the algorithm; will run with a high latency to save cycles
function BattleGroup:getEnemiesInvolvedInBattle()
  local result = self:_getCache():getCachedData(BattleGroup.CACHE_ENEMIES.name)
  if result then
    return result
  else
    -- compute the enemies list and check their distance to the battle
    local bgPosition = self:getAlliedBattlegroupPosition()
    local enemyUnits = veaf.findUnitsInCircle(bgPosition.center, bgPosition.radius + BattleGroup.CHECK_ENEMY_RADIUS, true, nil, veaf.getEnemyCoalition(self:getCoalition()))
    if enemyUnits and #enemyUnits > 0 then
      veaf.loggers.get(veafGroundBattle.Id):trace("enemyUnits=[%s]", veaf.p(enemyUnits))
    else
      veaf.loggers.get(veafGroundBattle.Id):trace("No enemy found")
    end
    self:_getCache():setCachedData(BattleGroup.CACHE_ENEMIES.name, result, BattleGroup.CACHE_ENEMIES.ttl)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- METHODS

-- this function manages the groups behavior
BattleGroup.CHECK_ENEMY_RADIUS = 10000 -- in meters, the radius in which to search for the nearest enemies
BattleGroup.DANGERCLOSE_ENEMY_RADIUS = 2000 -- in meters, the radius in which to search for the nearest enemies
function BattleGroup:check()
  veaf.loggers.get(veafGroundBattle.Id):debug("BattleGroup[%s]:check()", veaf.p(self:getName()))

  -- find the nearest enemies (in a certain radius) and check existing enemies in the enemyData table
  local dangerCloseEnemies = self:_manageEnemies()

  -- if enemy is danger close, retreat
  if dangerCloseEnemies and #dangerCloseEnemies > 0 then
    self:retreat()
  end

  -- if retreating and enemy is not nearby, stop and assess

  -- default to advancing to the BP/BL
end

-- send a message on the group frequency
function BattleGroup:_radioMessage(messageId, message)
  local _message = message
  if messageId then
    _message = BattleGroup.RADIO_MESSAGES[messageId]
  end
  -- TODO send message
end

function BattleGroup:_manageEnemies()
  veaf.loggers.get(veafGroundBattle.Id):debug("BattleGroup[%s]:_manageEnemies()", veaf.p(self:getName()))

  local dangerCloseEnemies = {}

  local center = self:getAlliedBattlegroupPosition()
  local enemyUnits = veaf.findUnitsInCircle(center, BattleGroup.CHECK_ENEMY_RADIUS, true, self:_getEnemies(), veaf.getEnemyCoalition(self:getCoalition()))
  if enemyUnits and #enemyUnits > 0 then
    veaf.loggers.get(veafGroundBattle.Id):trace("enemyUnits=[%s]", veaf.p(enemyUnits))
  else
    veaf.loggers.get(veafGroundBattle.Id):trace("No enemy found")
  end
  for _, unit in pairs(enemyUnits) do
    -- check the unit distance to the lead allied unit
  end


  return dangerCloseEnemies
end

function BattleGroup:retreat()
  veaf.loggers.get(veafGroundBattle.Id):debug("BattleGroup[%s]:retreat()", veaf.p(self:getName()))
  -- message on the group frequency (only if the retreat is beginning)
  if not self:getStatus() == BattleGroup.STATUS_RETREATING then
    -- radio
    self:_radioMessage(BattleGroup.RADIO_RETREATING)
  end

  -- choose the best path: if enemy is danger close, use a direct offroad path; if not, use the roads
  -- TODO

  -- set the new status
  self:setStatus(BattleGroup.STATUS_RETREATING)

  return self
end

function BattleGroup:stop()
  veaf.loggers.get(veafGroundBattle.Id):debug("BattleGroup[%s]:stop()", veaf.p(self:getName()))

  return self
end

function BattleGroup:advance()
  veaf.loggers.get(veafGroundBattle.Id):debug("BattleGroup[%s]:advance()", veaf.p(self:getName()))
  -- choose the best path: if close to enemy or BP/BL, use a direct offroad path; if not, use the roads
  -- TODO

  return self
end