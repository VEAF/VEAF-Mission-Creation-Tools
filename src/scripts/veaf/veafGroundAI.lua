------------------------------------------------------------------
-- VEAF Ground AI (a.k.a. Slightly Less Dumb Ground AI) for DCS World
-- By Zip (2024-25)
--
-- Features:
-- ---------
-- * DCS groups can be managed by the mission maker (API calls, radio menus) and by the pilots (radio menus, markers, remote commands)
--
-- See the documentation : https://veaf.github.io/documentation/mission-maker/groundAI.html
------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafGroundAI = {}

--- Identifier. All output in the log will start with this.
veafGroundAI.Id = "GROUNDAI - "

--- Version.
veafGroundAI.Version = "0.0.1"

-- trace level, specific to this module
veafGroundAI.LogLevel = "trace"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.loggers.new(veafGroundAI.Id, veafGroundAI.LogLevel)

veafGroundAI.handlers = {}

veafGroundAI.WATCHDOG_DELAY = 1

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- GroundUnitHandler class
-------------------------------------------------------------------------------------------------------------------------------------------------------------

GroundUnitHandler = {}
GroundUnitHandler.CLASS_NAME = "GroundUnitHandler"

GroundUnitHandler.DEFAULT_MESSAGE_STOP = "Ground unit has stopped executing orders."
GroundUnitHandler.DEFAULT_MESSAGE_START = "Ground unit is executing orders."

function GroundUnitHandler.init(object)
  -- technical name (GroundUnitHandler instance name)
  object.name = nil
  -- description for the messages
  object.description = nil
  -- draw the position and orders of the unit on screen
  object.draw = false
  -- player units (only they are concerned by the messages)
  object.playerUnitsNames = {}
  -- DCS group
  object.dcsGroup = nil
  -- orders for the ground unit
  object.orders = {}
  -- index of the currently executed order
  object.currentOrderIndex = 1
  -- silent means no message is emitted
  object.silent = false
  -- the drawing objects that has been used to draw the situation
  object.zoneDrawings = {}
  -- the scheduled state of the :check() function
  object.checkFunctionSchedule = nil
  -- status, from one of the GroundUnitHandler.STATUS_xxx constants
  object.status = GroundUnitHandler.STATUS_READY
  -- message when the ground unit starts executing orders
  object.messageStart = GroundUnitHandler.DEFAULT_MESSAGE_START
  -- event when the ground unit starts executing orders
  object.onStart = nil
  -- message when the ground unit stops executing orders
  object.messageStop = GroundUnitHandler.DEFAULT_MESSAGE_STOP
  -- event when the ground unit stops executing orders
  object.onStop = nil
end

function GroundUnitHandler.statusToString(status)
  if status == GroundUnitHandler.STATUS_READY then return "STATUS_READY" end
  if status == GroundUnitHandler.STATUS_ACTIVE then return "STATUS_ACTIVE" end
  if status == GroundUnitHandler.STATUS_OVER then return "STATUS_OVER" end
  return ""
end
GroundUnitHandler.STATUS_READY = 1
GroundUnitHandler.STATUS_ACTIVE = 2
GroundUnitHandler.STATUS_OVER = 4

function GroundUnitHandler:new(objectToCopy)
  veaf.loggers.get(veafGroundAI.Id):debug(GroundUnitHandler.CLASS_NAME..":new()")
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self

  -- init the new object
  GroundUnitHandler.init(objectToCreate)

  return objectToCreate
end

-- technical name (GroundUnitHandler instance name)
function GroundUnitHandler:setName(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[]:setName(%s)", veaf.p(value))
  self.name = value
  return veafGroundAI.add(self) -- add the handler to the list as soon as a name is available to index it
end

-- technical name (GroundUnitHandler instance name)
function GroundUnitHandler:getName()
  return self.name or self.description
end

-- description for the messages
function GroundUnitHandler:setDescription(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:setDescription(%s)", veaf.p(self:getName()), veaf.p(value))
  self.description = value
  return self
end

-- description for the messages
function GroundUnitHandler:getDescription()
  return self.description
end

-- draw the position and orders of the unit on screen
function GroundUnitHandler:setDraw(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:setDraw(%s)", veaf.p(self:getName()), veaf.p(value))
  self.draw = value
  return self
end

-- draw the position and orders of the unit on screen
function GroundUnitHandler:getDraw()
  return self.draw
end

-- coalitions of the players (only human units from these coalitions will be monitored)
function GroundUnitHandler:setPlayerCoalitions(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:setPlayerCoalitions(%s)", veaf.p(self:getName()), veaf.p(value))
  self.playerCoalitions = value
  return self
end

-- player units (only they are concerned by the messages)
function GroundUnitHandler:setPlayerUnitsNames(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:setPlayerUnitsNames(%s)", veaf.p(self:getName()), veaf.p(value))
  self.playerUnitsNames = value
  return self
end

-- player units (only they are concerned by the messages)
function GroundUnitHandler:getPlayerUnitsNames()
  return self.playerUnitsNames
end

-- DCS group
function GroundUnitHandler:setDcsGroup(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:setDcsGroup(%s)", veaf.p(self:getName()), veaf.p(value))
  self.dcsGroup = value
  return self
end

-- DCS group
function GroundUnitHandler:getDcsGroup()
  return self.dcsGroup
end

-- current orders for the ground unit
function GroundUnitHandler:setOrders(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:setOrders(%s)", veaf.p(self:getName()), veaf.p(value))
  self.orders = value
  return self
end

-- orders for the ground unit
function GroundUnitHandler:addOrder(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:addOrder(%s)", veaf.p(self:getName()), veaf.p(value))
  table.insert(self.orders, value)
  return self
end

-- orders for the ground unit
function GroundUnitHandler:getOrders()
  return self.orders
end

-- orders for the ground unit
function GroundUnitHandler:clearOrders()
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:clearOrders()", veaf.p(self:getName()))
  self.orders = {}
  return self
end

-- get the current order
function GroundUnitHandler:getCurrentOrder()
  if self.orders then
    return self.orders[1]
  else
    return nil
  end
end

-- complete an order (pop it from the start of the list)
function GroundUnitHandler:completeOrder()
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:completeOrder()", veaf.p(self:getName()))
  if self.orders and #self.orders > 0 then
    table.remove(self.orders, 1)
  end
  return self
end

-- silent means no message is emitted
function GroundUnitHandler:setSilent(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:setSilent(%s)", veaf.p(self:getName()), veaf.p(value))
  self.silent = value
  return self
end

-- silent means no message is emitted
function GroundUnitHandler:getSilent()
  return self.silent
end

-- the drawing objects that has been used to draw the situation
function GroundUnitHandler:setZoneDrawings(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:setZoneDrawings(%s)", veaf.p(self:getName()), veaf.p(value))
  self.zoneDrawings = value
  return self
end

-- the drawing objects that has been used to draw the situation
function GroundUnitHandler:getZoneDrawings()
  return self.zoneDrawings
end

-- the scheduled state of the :check() function
function GroundUnitHandler:setCheckFunctionSchedule(value)
  --veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:setCheckFunctionSchedule(%s)", veaf.p(self:getName()), veaf.p(value))
  self.checkFunctionSchedule = value
  return self
end

-- the scheduled state of the :check() function
function GroundUnitHandler:getCheckFunctionSchedule()
  return self.checkFunctionSchedule
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- METHODS

function GroundUnitHandler:handleOrder(order)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:handleOrder(%s)", veaf.p(self:getName()), veaf.p(order))
  -- do nothing clever, all is done in the inheriting classes
  self:completeOrder()
end

function GroundUnitHandler:check()
  --veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:check()", veaf.p(self:getName()))

  -- consider the orders in the orders list
  local currentOrder = self:getCurrentOrder()
  if currentOrder then
    -- do something with the order
    self:handleOrder(currentOrder)
  end

  -- reschedule the check function
  self:setCheckFunctionSchedule(mist.scheduleFunction(GroundUnitHandler.check, {self}, timer.getTime() + veafGroundAI.WATCHDOG_DELAY))
end

function GroundUnitHandler:start()
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:start()", veaf.p(self:getName()))
  self.status = GroundUnitHandler.STATUS_ACTIVE
  if not self.silent then
    trigger.action.outText(self.messageStart, 10)
  end
  if self.onStart then
    self.onStart(self)
  end
  self:check()
end

function GroundUnitHandler:stop()
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:stop()", veaf.p(self:getName()))
  self.status = GroundUnitHandler.STATUS_READY
  if not self.silent then
    trigger.action.outText(self.messageStop, 10)
  end
  if self.onStop then
    self.onStop(self)
  end
  if self.checkFunctionSchedule then
    mist.removeFunction(self.checkFunctionSchedule)
    self.checkFunctionSchedule = nil
  end
  if self:getCheckFunctionSchedule() then
    mist.removeFunction(self:getCheckFunctionSchedule())
    self:setCheckFunctionSchedule(nil)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ArtilleryUnitHandler class
-------------------------------------------------------------------------------------------------------------------------------------------------------------

ArtilleryUnitHandler = GroundUnitHandler:new()
ArtilleryUnitHandler.CLASS_NAME = "ArtilleryUnitHandler"

-- fire for aim constants
ArtilleryUnitHandler.FIREFORAIM_SHELLS = 2
ArtilleryUnitHandler.FIREFORAIM_RADIUS = 10

-- fire for effect constants
ArtilleryUnitHandler.FIREFOREFFECT_SHELLS = 40
ArtilleryUnitHandler.FIREFOREFFECT_RADIUS = 100

ArtilleryUnitHandler.ORDER_STOP = 0
ArtilleryUnitHandler.ORDER_FIRE = 1
ArtilleryUnitHandler.ORDER_ADVANCE = 2

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CTOR

function ArtilleryUnitHandler.init(object)
  -- status, from one of the ArtilleryUnitHandler.STATUS_xxx constants
  object.status = ArtilleryUnitHandler.STATUS_READY
end

function ArtilleryUnitHandler:new(objectToCopy)
  veaf.loggers.get(veafGroundAI.Id):debug(ArtilleryUnitHandler.CLASS_NAME..":new()")
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self

  -- init the new object
  ArtilleryUnitHandler.init(objectToCreate)

  return objectToCreate
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTIES

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- COMPUTED PROPERTIES

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- METHODS

-- give the artillery unit a fire for effect order
function ArtilleryUnitHandler:fireForAim(coordinates)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:fireForAim(%s)", veaf.p(self:getName()), veaf.p(coordinates))
  -- check the parameters
  if not coordinates then
    veaf.loggers.get(veafGroundAI.Id):warn(self.CLASS_NAME.."[%s]:fireForAim() : coordinates is nil", veaf.p(self:getName()))
    return
  end
  self:fireAtCoordinates(ArtilleryUnitHandler.FIREFORAIM_SHELLS, coordinates, ArtilleryUnitHandler.FIREFORAIM_RADIUS)
end


-- give the artillery unit a fire for effect order
function ArtilleryUnitHandler:fireForEffect()
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:fireForEffect()", veaf.p(self:getName()))
  if not self._lastTarget then
    veaf.loggers.get(veafGroundAI.Id):warn(self.CLASS_NAME.."[%s]:fireForEffect() : no previous target - cannot fire for effect", veaf.p(self:getName()))
    return
  end
  if self._lastTarget then
    self:fireAtCoordinates(ArtilleryUnitHandler.FIREFOREFFECT_SHELLS, self._lastTarget, ArtilleryUnitHandler.FIREFOREFFECT_RADIUS)
  else
    veaf.loggers.get(veafGroundAI.Id):warn(self.CLASS_NAME.."[%s]:fireForEffect() : no previous target - cannot fire for effect", veaf.p(self:getName()))
  end
end

-- give the artillery unit a fire order
function ArtilleryUnitHandler:fireAtCoordinates(nbShells, coordinates, radius)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:fireAtCoordinates(%d, %s, %s)", veaf.p(self:getName()), veaf.p(nbShells), veaf.p(coordinates), veaf.p(radius))
  -- check the parameters
  if not nbShells then
    veaf.loggers.get(veafGroundAI.Id):warn(self.CLASS_NAME.."[%s]:fireAtCoordinates() : nbShells is nil", veaf.p(self:getName()))
    return
  end
  if not coordinates then
    veaf.loggers.get(veafGroundAI.Id):warn(self.CLASS_NAME.."[%s]:fireAtCoordinates() : coordinates is nil", veaf.p(self:getName()))
    return
  end
  if not radius then
    radius = ArtilleryUnitHandler.DEFAULT_FIRE_RADIUS
  end
  -- check if these are coordinates
  local target = nil
  if type(coordinates) == "table" then
    target = coordinates
  elseif type(coordinates) == "string" then
    local _lat, _lon = veaf.computeLLFromString(coordinates)
    veaf.loggers.get(veafGroundAI.Id):trace(string.format("_lat=%s",veaf.p(_lat)))
    veaf.loggers.get(veafGroundAI.Id):trace(string.format("_lon=%s",veaf.p(_lon)))
    if _lat and _lon then
        target = coord.LLtoLO(_lat, _lon)
    else
        veaf.loggers.get(veafGroundAI.Id):warn(self.CLASS_NAME.."[%s]:fireAtCoordinates() : coordinates are not valid: %s", veaf.p(self:getName()), veaf.p(coordinates))
    end
  end
  local order = {verb=ArtilleryUnitHandler.ORDER_FIRE, parameters={nbShells=nbShells, target=target, radius=radius}}
  self:addOrder(order)
end

function ArtilleryUnitHandler:handleOrder(order)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME.."[%s]:handleOrder(%s)", veaf.p(self:getName()), veaf.p(order))
  if order.verb == ArtilleryUnitHandler.ORDER_FIRE then
    -- fire at the target
    local nbShells = order.parameters.nbShells
    local target = order.parameters.target
    local radius = order.parameters.radius
    -- convert the target coordinates to UTM for the message
    local lat, lon, _ = coord.LOtoLL(target)
    local grid = coord.LLtoMGRS(lat, lon)
    local coordinates = grid.UTMZone .. ' ' .. grid.MGRSDigraph .. ' ' .. grid.Easting .. ' ' .. grid.Northing
    veaf.loggers.get(veafGroundAI.Id):trace("ArtilleryUnitHandler[%s]:handleOrder() : firing %d shells at %s with a %s m dispersion", veaf.p(self:getName()), veaf.p(nbShells), veaf.p(coordinates), veaf.p(radius))
    -- fire the shells
    local fireParams = {
      x = target.x,
      y = target.z,
      zoneRadius = radius,
      expendQty = nbShells,
      expendQtyEnabled = true,
      counterbattaryRadius = 500,
    }
    local fire = {id = 'FireAtPoint', params = fireParams}
    self:getDcsGroup():getController():pushTask(fire)
    self._lastTarget = target
  end
  GroundUnitHandler.handleOrder(self, order)
end
-------------------------------------------------------------------------------------------------------------------------------------------------------------
--- Global functions for the module
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafGroundAI.add(handler)
  veaf.loggers.get(veafGroundAI.Id):debug("veafGroundAI.add([%s])", veaf.p(handler:getName()))
  veafGroundAI.handlers[handler:getName()] = handler
  return handler
end

function veafGroundAI.get(handlerName)
  veaf.loggers.get(veafGroundAI.Id):debug("veafGroundAI.get([%s])", veaf.p(handlerName))
  local handler = veafGroundAI.handlers[handlerName]
  if handler then
    veaf.loggers.get(veafGroundAI.Id):trace("handler found: %s", veaf.p(handler))
  end
  return handler
end

function veafGroundAI.initialize()
  veaf.loggers.get(veafGroundAI.Id):info("Initializing module")
end