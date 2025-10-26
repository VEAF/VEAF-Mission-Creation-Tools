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
veafGroundAI.Version = "1.0.0"

-- trace level, specific to this module
--veafGroundAI.LogLevel = "trace"

--- Key phrase to look for in the mark text which triggers the spawn command.
veafGroundAI.MarkerKeyphrase = "_ground"

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

GroundUnitHandler.DEFAULT_MESSAGE_STOP = "Ground unit %s has stopped executing and awaiting orders."
GroundUnitHandler.DEFAULT_MESSAGE_START = "Ground unit %s is executing or awaiting orders."

function GroundUnitHandler.init(object)
  -- technical name (GroundUnitHandler instance name)
  object.name = nil
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
  veaf.loggers.get(veafGroundAI.Id):debug(GroundUnitHandler.CLASS_NAME .. ":new()")
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self

  -- init the new object
  GroundUnitHandler.init(objectToCreate)

  return objectToCreate
end

-- technical name (GroundUnitHandler instance name)
function GroundUnitHandler:setName(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[]:setName(%s)", veaf.p(value))
  self.name = value
  return veafGroundAI.add(self) -- add the handler to the list as soon as a name is available to index it
end

-- technical name (GroundUnitHandler instance name)
function GroundUnitHandler:getName()
  return self.name or self.description
end

-- description for the messages
function GroundUnitHandler:getDescription()
  local result = self:getName()
  if self:getDcsGroup() then
    result = result .. " is handling DCS group " .. self:getDcsGroup():getName() .. ")"
  end
  return result
end

-- draw the position and orders of the unit on screen
function GroundUnitHandler:setDraw(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:setDraw(%s)", veaf.p(self:getName()), veaf.p(value))
  self.draw = value
  return self
end

-- draw the position and orders of the unit on screen
function GroundUnitHandler:getDraw()
  return self.draw
end

-- coalitions of the players (only human units from these coalitions will be monitored)
function GroundUnitHandler:setPlayerCoalitions(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:setPlayerCoalitions(%s)", veaf.p(self:getName()), veaf.p(value))
  self.playerCoalitions = value
  return self
end

-- player units (only they are concerned by the messages)
function GroundUnitHandler:setPlayerUnitsNames(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:setPlayerUnitsNames(%s)", veaf.p(self:getName()), veaf.p(value))
  self.playerUnitsNames = value
  return self
end

-- player units (only they are concerned by the messages)
function GroundUnitHandler:getPlayerUnitsNames()
  return self.playerUnitsNames
end

-- DCS group
function GroundUnitHandler:setDcsGroup(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:setDcsGroup(%s)", veaf.p(self:getName()), veaf.p(value))
  self.dcsGroup = value
  return self
end

-- DCS group
function GroundUnitHandler:getDcsGroup()
  return self.dcsGroup
end

-- current orders for the ground unit
function GroundUnitHandler:setOrders(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:setOrders(%s)", veaf.p(self:getName()), veaf.p(value))
  self.orders = value
  return self
end

-- orders for the ground unit
function GroundUnitHandler:addOrder(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:addOrder(%s)", veaf.p(self:getName()), veaf.p(value))
  if value then
    table.insert(self.orders, value)
  end
  return self
end

-- orders for the ground unit
function GroundUnitHandler:getOrders()
  return self.orders
end

-- orders for the ground unit
function GroundUnitHandler:clearOrders()
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:clearOrders()", veaf.p(self:getName()))
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
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:completeOrder()", veaf.p(self:getName()))
  if self.orders and #self.orders > 0 then
    table.remove(self.orders, 1)
  end
  return self
end

-- silent means no message is emitted
function GroundUnitHandler:setSilent(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:setSilent(%s)", veaf.p(self:getName()), veaf.p(value))
  self.silent = value
  return self
end

-- silent means no message is emitted
function GroundUnitHandler:getSilent()
  return self.silent
end

-- the drawing objects that has been used to draw the situation
function GroundUnitHandler:setZoneDrawings(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:setZoneDrawings(%s)", veaf.p(self:getName()), veaf.p(value))
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
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:handleOrder(%s)", veaf.p(self:getName()),veaf.p(order))
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
  self:setCheckFunctionSchedule(mist.scheduleFunction(GroundUnitHandler.check, { self },
    timer.getTime() + veafGroundAI.WATCHDOG_DELAY))
end

function GroundUnitHandler:start()
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:start()", veaf.p(self:getName()))
  self.status = GroundUnitHandler.STATUS_ACTIVE
  if not self.silent then
    trigger.action.outText(string.format(self.messageStart, self:getName()), 10)
  end
  if self.onStart then
    self.onStart(self)
  end
  self:check()
end

function GroundUnitHandler:stop()
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:stop()", veaf.p(self:getName()))
  self.status = GroundUnitHandler.STATUS_READY
  if not self.silent then
    trigger.action.outText(string.format(self.messageStop, self:getName()), 10)
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

function GroundUnitHandler:orderTextAnalysis(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:orderTextAnalysis(%s)", veaf.p(self:getName()), veaf.p(value))
  -- do nothing clever, all is done in the inheriting classes
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
  veaf.loggers.get(veafGroundAI.Id):debug(ArtilleryUnitHandler.CLASS_NAME .. ":new()")
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

function ArtilleryUnitHandler:orderTextAnalysis(text)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:orderTextAnalysis(%s)", veaf.p(self:getName()), veaf.p(text))

  -- analyze the string for an acceptable order
  ArtilleryUnitHandler.VERB_FIRE_FORAIM = 1
  ArtilleryUnitHandler.VERB_FIRE_FOREFFECT = 2

  -- Option parameters extracted from the mark text.
  local options = {}
  options.verb = ArtilleryUnitHandler.VERB_FIRE_FORAIM -- can be "aim", "fire"
  options.target = nil -- the coordinates of the target
  options.shells = nil -- the number of shells to fire
  options.radius = nil -- the precision of the shelling

  -- Check for correct keywords.
  if text:lower():find("aim") then
    options.verb = ArtilleryUnitHandler.VERB_FIRE_FORAIM
  elseif text:lower():find("fire") then
    options.verb = ArtilleryUnitHandler.VERB_FIRE_FOREFFECT
  else
    return nil
  end

  -- keywords are split by ";"
  local keywords = veaf.split(text, ";")

  for _, keyphrase in pairs(keywords) do
    -- Split keyphrase by space. First one is the key and second, ... the parameter(s) until the next comma.
    local str = veaf.breakString(veaf.trim(keyphrase), " ")
    local key = str[1]
    local val = str[2] or ""

    if key:lower() == "target" then
      -- Set the target
      veaf.loggers.get(veafGroundAI.Id):trace("Keyword target = %s", veaf.p(val))
      if veaf.computeLLFromString(val) then -- check target string validity
        options.target = val
      end
    end

    if key:lower() == "shells" then
      -- Set the number of shells
      veaf.loggers.get(veafGroundAI.Id):trace("Keyword shells = %s", veaf.p(val))
      local nVal = veaf.getRandomizableNumeric(val)
      veaf.loggers.get(veafGroundAI.Id):trace("shells = %s", veaf.p(nVal))
      options.shells = nVal
    end

    if key:lower() == "radius" then
      -- Set the radius of the shelling
      veaf.loggers.get(veafGroundAI.Id):trace("Keyword radius = %s", veaf.p(val))
      local nVal = veaf.getRandomizableNumeric(val)
      veaf.loggers.get(veafGroundAI.Id):trace("radius = %s", veaf.p(nVal))
      options.radius = nVal
    end
  end

  if options.verb == ArtilleryUnitHandler.VERB_FIRE_FORAIM then
    self:fireForAim(options.target, options.shells, options.radius)
  elseif options.verb == ArtilleryUnitHandler.VERB_FIRE_FOREFFECT then
    self:fireForEffect(options.target, options.shells, options.radius)
  end

  return options
end

-- give the artillery unit a fire for effect order
function ArtilleryUnitHandler:fireForAim(coordinates, shells, radius)
  if not shells then
    shells = ArtilleryUnitHandler.FIREFORAIM_SHELLS
  end
  if not radius then
    radius = ArtilleryUnitHandler.FIREFORAIM_RADIUS
  end
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:fireForAim(%s, %s, %s)", veaf.p(self:getName()), veaf.p(coordinates), veaf.p(shells), veaf.p(radius))
  -- check the parameters
  if not coordinates then
    veaf.loggers.get(veafGroundAI.Id):warn(self.CLASS_NAME .. "[%s]:fireForAim() : no target coordinates", veaf.p(self:getName()))
    if not self.silent then
      local message = string.format("%s cannot aim, no target coordinates provided", veaf.p(self:getName()))
      trigger.action.outText(message, 10)
    end
    return
  end
  self:fireAtCoordinates(coordinates, shells, radius)
end

-- give the artillery unit a fire for effect order
function ArtilleryUnitHandler:fireForEffect(coordinates, shells, radius)
  if not shells then
    shells = ArtilleryUnitHandler.FIREFOREFFECT_SHELLS
  end
  if not radius then
    radius = ArtilleryUnitHandler.FIREFOREFFECT_RADIUS
  end
  if not coordinates then
    coordinates = self._lastTarget
  end
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:fireForEffect(%s, %s)", veaf.p(self:getName()), veaf.p(shells), veaf.p(radius))
  if not coordinates then
    veaf.loggers.get(veafGroundAI.Id):warn(self.CLASS_NAME .. "[%s]:fireForEffect() : no previous target - cannot fire for effect", veaf.p(self:getName()))
    if not self.silent then
      local message = string.format("%s cannot fire for effect, no target coordinates provided and no previous target exist", veaf.p(self:getName()))
      trigger.action.outText(message, 10)
    end
    return
  end
  self:fireAtCoordinates(coordinates, shells, radius)
end

-- give the artillery unit a fire order
function ArtilleryUnitHandler:fireAtCoordinates(coordinates, shells, radius)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:fireAtCoordinates(%d, %s, %s)", veaf.p(self:getName()), veaf.p(shells), veaf.p(coordinates), veaf.p(radius))
  -- check the parameters
  if not shells then
    veaf.loggers.get(veafGroundAI.Id):warn(self.CLASS_NAME .. "[%s]:fireAtCoordinates() : shells is nil", veaf.p(self:getName()))
    return
  end
  if not coordinates then
    veaf.loggers.get(veafGroundAI.Id):warn(self.CLASS_NAME .. "[%s]:fireAtCoordinates() : coordinates is nil", veaf.p(self:getName()))
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
    veaf.loggers.get(veafGroundAI.Id):trace(string.format("_lat=%s", veaf.p(_lat)))
    veaf.loggers.get(veafGroundAI.Id):trace(string.format("_lon=%s", veaf.p(_lon)))
    if _lat and _lon then
      target = coord.LLtoLO(_lat, _lon)
    else
      veaf.loggers.get(veafGroundAI.Id):warn(self.CLASS_NAME .. "[%s]:fireAtCoordinates() : coordinates are not valid: %s", veaf.p(self:getName()), veaf.p(coordinates))
    end
  end
  local order = { verb = ArtilleryUnitHandler.ORDER_FIRE, parameters = { shells = shells, target = target, radius = radius } }
  self:addOrder(order)
end

function ArtilleryUnitHandler:handleOrder(order)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:handleOrder(%s)", veaf.p(self:getName()), veaf.p(order))
  if order.verb == ArtilleryUnitHandler.ORDER_FIRE then
    -- fire at the target
    local shells = order.parameters.shells
    local target = order.parameters.target
    local radius = order.parameters.radius
    if not target then
      veaf.loggers.get(veafGroundAI.Id):warn(self.CLASS_NAME .. "[%s]:handleOrder() : no target", veaf.p(self:getName()))
    else
      -- convert the target coordinates to UTM for the message
      local lat, lon, _ = coord.LOtoLL(target)
      local grid = coord.LLtoMGRS(lat, lon)
      local coordinates = grid.UTMZone .. ' ' .. grid.MGRSDigraph .. ' ' .. grid.Easting .. ' ' .. grid.Northing
      local message = string.format("%s is firing %d shells at %s with a %s m dispersion", veaf.p(self:getName()), veaf.p(shells), veaf.p(coordinates), veaf.p(radius))
      trigger.action.outText(message, 10)
      veaf.loggers.get(veafGroundAI.Id):trace("ArtilleryUnitHandler[%s]:handleOrder() : firing %d shells at %s with a %s m dispersion", veaf.p(self:getName()), veaf.p(shells), veaf.p(coordinates), veaf.p(radius))
      -- fire the shells
      local fireParams = {
        x = target.x,
        y = target.z,
        zoneRadius = radius,
        expendQty = shells,
        expendQtyEnabled = true,
        counterbattaryRadius = 500,
      }
      local fire = { id = 'FireAtPoint', params = fireParams }
      self:getDcsGroup():getController():pushTask(fire)
      self._lastTarget = target
    end
  end
  self:completeOrder()
end

function ArtilleryUnitHandler:stop()
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:stop()", veaf.p(self:getName()))
  -- clear the group's orders queue
  self:getDcsGroup():getController():resetTask()
  return GroundUnitHandler.stop(self)
end

function ArtilleryUnitHandler:clearOrders()
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:clearOrders()", veaf.p(self:getName()))
  -- clear the group's orders queue
  self:getDcsGroup():getController():resetTask()
  return GroundUnitHandler.clearOrders(self)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafGroundAI.onEventMarkChange(eventPos, event)
  -- choose by default the coalition of the player who triggered the event
  local coa = coalition.side.BLUE
  if event.coalition == coalition.side.RED then
    coa = coalition.side.RED
  end

  veaf.loggers.get(veafGroundAI.Id):trace(string.format("event.idx  = %s", veaf.p(event.idx)))

  if veafGroundAI.executeCommand(eventPos, event.text, coa, event.idx) then
    -- Delete old mark.
    veaf.loggers.get(veafGroundAI.Id):trace(string.format("Removing mark # %d.", event.idx))
    trigger.action.removeMark(event.idx)
  end
end

function veafGroundAI.executeCommand(eventPos, eventText, eventCoalition, markId, bypassSecurity, spawnedGroups, route)
  veaf.loggers.get(veafGroundAI.Id):debug(string.format("veafGroundAI.executeCommand(eventText=[%s])", eventText))

  -- Check if marker has a text and contains an alias
  if eventText ~= nil then
    -- Analyse the mark point text and extract the keywords.
    local options = veafGroundAI.markTextAnalysis(eventPos, eventCoalition, eventText)
    veaf.loggers.get(veafGroundAI.Id):trace(string.format("options = %s", veaf.p(options)))

    if options then
      -- do the magic
      if options.verb == veafGroundAI.VERB_SET then
        veaf.loggers.get(veafGroundAI.Id):trace("options.verb == veafGroundAI.VERB_SET")
        local handlerName = options.name
        local group = options.group
        if group and handlerName then
          veaf.loggers.get(veafGroundAI.Id):trace("group = %s", veaf.p(group))
          local handler = veafGroundAI.get(handlerName)
          if not handler then
            handler = ArtilleryUnitHandler:new():setName(handlerName)
          end
          if handler then
            handler:setDcsGroup(group)
            handler:start()
            return true
          end
        end
      elseif options.verb == veafGroundAI.VERB_UNSET then
        veaf.loggers.get(veafGroundAI.Id):trace("options.verb == veafGroundAI.VERB_UNSET")
        local handlerName = options.name
        local handler = veafGroundAI.get(handlerName)
        if handler then
          handler:stop()
          veafGroundAI.remove(handler)
          return true
        end
      elseif options.verb == veafGroundAI.VERB_START then
        veaf.loggers.get(veafGroundAI.Id):trace("options.verb == veafGroundAI.VERB_START")
        local handlerName = options.name
        local handler = veafGroundAI.get(handlerName)
        if handler then
          handler:start()
          return true
        end
      elseif options.verb == veafGroundAI.VERB_STOP then
        veaf.loggers.get(veafGroundAI.Id):trace("options.verb == veafGroundAI.VERB_STOP")
        local handlerName = options.name
        local handler = veafGroundAI.get(handlerName)
        if handler then
          handler:stop()
          return true
        end
      elseif options.verb == veafGroundAI.VERB_CLEAR then
        veaf.loggers.get(veafGroundAI.Id):trace("options.verb == veafGroundAI.VERB_CLEAR")
        local handlerName = options.name
        local handler = veafGroundAI.get(handlerName)
        if handler then
          handler:stop()
          handler:clearOrders()
          return true
        end
      elseif options.verb == veafGroundAI.VERB_STATUS then
        veaf.loggers.get(veafGroundAI.Id):trace("options.verb == veafGroundAI.VERB_STATUS")
        local handlerName = options.name
        local handler = veafGroundAI.get(handlerName)
        if handler then
          trigger.action.outText(string.format("AI handler %s: %s", handlerName, handler:getDescription()), 10)
          return true
        end
      elseif options.verb == veafGroundAI.VERB_ORDER then
        veaf.loggers.get(veafGroundAI.Id):trace("options.verb == veafGroundAI.VERB_ORDER")
        local handlerName = options.name
        local handler = veafGroundAI.get(handlerName)
        if handler then
          if handler:orderTextAnalysis(options.order) then
            return true
          end
        end
      end
    end
  end

  -- None of the keywords matched.
  return false
end

--- Extract keywords from mark text.
function veafGroundAI.markTextAnalysis(eventPos, eventCoalition, text)
  veaf.loggers.get(veafGroundAI.Id):trace("veafGroundAI.markTextAnalysis(text=%s)", veaf.p(text))

  veafGroundAI.VERB_SET = 1
  veafGroundAI.VERB_UNSET = 2
  veafGroundAI.VERB_ORDER = 3
  veafGroundAI.VERB_START = 4
  veafGroundAI.VERB_STOP = 5
  veafGroundAI.VERB_CLEAR = 6
  veafGroundAI.VERB_STATUS = 7

  -- Option parameters extracted from the mark text.
  local options = {}
  options.verb = veafGroundAI.VERB_SET -- can be "set", "unset", "order", "start", "stop", "status"
  options.group = nil                  -- the DCS group that is concerned by "set" and "unset" verbs
  options.order = nil                  -- the order that is given by "order" verb
  options.name = nil                   -- the name of the handler that is concerned by all verbs

  -- Check for correct keywords.
  if text:lower():find(veafGroundAI.MarkerKeyphrase .. " set") then
    options.verb = veafGroundAI.VERB_SET
  elseif text:lower():find(veafGroundAI.MarkerKeyphrase .. " unset") then
    options.verb = veafGroundAI.VERB_UNSET
  elseif text:lower():find(veafGroundAI.MarkerKeyphrase .. " order") then
    options.verb = veafGroundAI.VERB_ORDER
  elseif text:lower():find(veafGroundAI.MarkerKeyphrase .. " start") then
    options.verb = veafGroundAI.VERB_START
  elseif text:lower():find(veafGroundAI.MarkerKeyphrase .. " stop") then
    options.verb = veafGroundAI.VERB_STOP
  elseif text:lower():find(veafGroundAI.MarkerKeyphrase .. " clear") then
    options.verb = veafGroundAI.VERB_CLEAR
  elseif text:lower():find(veafGroundAI.MarkerKeyphrase .. " status") then
    options.verb = veafGroundAI.VERB_STATUS
  else
    return nil
  end

  -- keywords are split by ","
  local keywords = veaf.split(text, ",")

  for _, keyphrase in pairs(keywords) do
    -- Split keyphrase by space. First one is the key and second, ... the parameter(s) until the next comma.
    local str = veaf.breakString(veaf.trim(keyphrase), " ")
    local key = str[1]
    local val = str[2] or ""

    if key:lower() == "groupname" then
      -- Set dcs group name.
      veaf.loggers.get(veafGroundAI.Id):trace("Keyword groupname = %s", veaf.p(val))
      -- search for the DCS group
      options.group = Group.getByName(val)
    end

    if key:lower() == "name" then
      -- Set AI handler name.
      veaf.loggers.get(veafGroundAI.Id):trace("Keyword name = %s", veaf.p(val))
      options.name = val
    end

    if key:lower() == "order" then
      -- Set order
      veaf.loggers.get(veafGroundAI.Id):trace("Keyword order = %s", veaf.p(val))
      options.order = val
    end
  end

  -- check mandatory parameter "name" for all commands
  if not (options.name) then return nil end

  -- check mandatory parameter "groupname" for commands "set" and "unset"
  if ((options.verb == veafGroundAI.VERB_SET or options.verb == veafGroundAI.VERB_UNSET) and not (options.group)) then
    -- search for the nearest allied group
    local minDist = 999999
    local closestUnit = nil
    for _, unit in pairs(veaf.getUnitsOfCoalition(false, eventCoalition)) do
      local pos = unit:getPosition().p
      if pos then
        local name = unit:getName()
        local distanceFromCenter = ((pos.x - eventPos.x) ^ 2 + (pos.z - eventPos.z) ^ 2) ^ 0.5
        veaf.loggers.get(veaf.Id):trace("name=%s; distanceFromCenter=%s", veaf.p(name), veaf.p(distanceFromCenter))
        if distanceFromCenter <= 250 then
          if distanceFromCenter < minDist then
            minDist = distanceFromCenter
            closestUnit = unit
          end
        end
      end
    end
    if closestUnit then
      options.group = closestUnit:getGroup()
    else
      return nil
    end
  end

  return options
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
--- Global functions for the module
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafGroundAI.add(handler)
  veaf.loggers.get(veafGroundAI.Id):debug("veafGroundAI.add([%s])", veaf.p(handler:getName()))
  veafGroundAI.handlers[handler:getName():lower()] = handler
  return handler
end

function veafGroundAI.remove(handler)
  veaf.loggers.get(veafGroundAI.Id):debug("veafGroundAI.remove([%s])", veaf.p(handler:getName()))
  veafGroundAI.handlers[handler:getName():lower()] = nil
end

function veafGroundAI.get(handlerName)
  veaf.loggers.get(veafGroundAI.Id):debug("veafGroundAI.get([%s])", veaf.p(handlerName))
  local handler = veafGroundAI.handlers[handlerName:lower()]
  if handler then
    veaf.loggers.get(veafGroundAI.Id):trace("handler found: %s", veaf.p(handler))
  end
  return handler
end

function veafGroundAI.initialize()
  veaf.loggers.get(veafGroundAI.Id):info("Initializing module")
  veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafGroundAI.onEventMarkChange)
end
