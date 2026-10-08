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
veafGroundAI.Id = "GROUNDAI"

-- trace level, specific to this module
--veafGroundAI.LogLevel = "trace"

--- Key phrase to look for in the mark text which triggers the spawn command.
veafGroundAI.MarkerKeyphrase = "_ground"

--- Le mot-cle courant : `_gc`, pour *ground commander*.
---
--- Plus court a taper sous le feu, et il ouvre la forme positionnelle
--- `_gc <nom>, <verbe> <valeur>, <parametres>` — le destinataire d'abord, comme a la radio.
--- `_ground` et sa forme imbriquee restent acceptes, sans etre documentes : on ne sait pas ce que les
--- missions au monde ont ecrit. FEAT-GC-MARKER-SYNTAX.
veafGroundAI.ShortKeyphrase = "_gc"

--- Une regle de parametre qui pose simplement un verbe : `_gc arty-1, stop`.
---
--- Locale au module plutot qu'ajoutee a `veaf.markerRules` : six verbes d'un seul module ne justifient
--- pas d'elargir l'interface partagee, et les regles communes existantes rangent toutes une *valeur*
--- alors que celle-ci n'en lit aucune.
---
--- @param word string le mot que le pilote ecrit
--- @param verb number la constante VERB_* correspondante
--- @return table la regle, prete a entrer dans `parameters`
function veafGroundAI.verbRule(word, verb)
  return {
    keys = { word },
    apply = function(options)
      options.verb = verb
    end,
  }
end

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

-- Default messages are i18n catalog keys (see veafI18n.lua), resolved through
-- veaf.t() at send time so they localize to the mission language; a mission
-- overriding them with its own literal keeps it verbatim.
GroundUnitHandler.DEFAULT_MESSAGE_STOP = "groundai.msg_stop"
GroundUnitHandler.DEFAULT_MESSAGE_START = "groundai.msg_start"

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
  return veaf.enumToString(status, {
    [GroundUnitHandler.STATUS_READY] = "STATUS_READY",
    [GroundUnitHandler.STATUS_ACTIVE] = "STATUS_ACTIVE",
    [GroundUnitHandler.STATUS_OVER] = "STATUS_OVER",
  })
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
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[]:setName(%s)", veaf.lp(value))
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
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:setDraw(%s)", veaf.lp(self:getName()), veaf.lp(value))
  self.draw = value
  return self
end

-- draw the position and orders of the unit on screen
function GroundUnitHandler:getDraw()
  return self.draw
end

-- coalitions of the players (only human units from these coalitions will be monitored)
function GroundUnitHandler:setPlayerCoalitions(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:setPlayerCoalitions(%s)", veaf.lp(self:getName()), veaf.lp(value))
  self.playerCoalitions = value
  return self
end

-- player units (only they are concerned by the messages)
function GroundUnitHandler:setPlayerUnitsNames(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:setPlayerUnitsNames(%s)", veaf.lp(self:getName()), veaf.lp(value))
  self.playerUnitsNames = value
  return self
end

-- player units (only they are concerned by the messages)
function GroundUnitHandler:getPlayerUnitsNames()
  return self.playerUnitsNames
end

-- DCS group
function GroundUnitHandler:setDcsGroup(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:setDcsGroup(%s)", veaf.lp(self:getName()), veaf.lp(value))
  self.dcsGroup = value
  return self
end

-- DCS group
function GroundUnitHandler:getDcsGroup()
  return self.dcsGroup
end

-- current orders for the ground unit
function GroundUnitHandler:setOrders(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:setOrders(%s)", veaf.lp(self:getName()), veaf.lp(value))
  self.orders = value
  return self
end

-- orders for the ground unit
function GroundUnitHandler:addOrder(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:addOrder(%s)", veaf.lp(self:getName()), veaf.lp(value))
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
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:clearOrders()", veaf.lp(self:getName()))
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
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:completeOrder()", veaf.lp(self:getName()))
  if self.orders and #self.orders > 0 then
    table.remove(self.orders, 1)
  end
  return self
end

-- silent means no message is emitted
function GroundUnitHandler:setSilent(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:setSilent(%s)", veaf.lp(self:getName()), veaf.lp(value))
  self.silent = value
  return self
end

-- silent means no message is emitted
function GroundUnitHandler:getSilent()
  return self.silent
end

-- the drawing objects that has been used to draw the situation
function GroundUnitHandler:setZoneDrawings(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:setZoneDrawings(%s)", veaf.lp(self:getName()), veaf.lp(value))
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
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:handleOrder(%s)", veaf.lp(self:getName()), veaf.lp(order))
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
  self:setCheckFunctionSchedule(veaf.scheduleFunction(function(handler)
    veaf.safeCall(GroundUnitHandler.check, handler)
  end, { self }, timer.getTime() + veafGroundAI.WATCHDOG_DELAY))
end

function GroundUnitHandler:start()
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:start()", veaf.lp(self:getName()))
  self.status = GroundUnitHandler.STATUS_ACTIVE
  if not self.silent then
    trigger.action.outText(veaf.t(self.messageStart, self:getName()), 10)
  end
  if self.onStart then
    self.onStart(self)
  end
  self:check()
end

function GroundUnitHandler:stop()
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:stop()", veaf.lp(self:getName()))
  self.status = GroundUnitHandler.STATUS_READY
  if not self.silent then
    trigger.action.outText(veaf.t(self.messageStop, self:getName()), 10)
  end
  if self.onStop then
    self.onStop(self)
  end
  if self.checkFunctionSchedule then
    veaf.removeFunction(self.checkFunctionSchedule)
    self.checkFunctionSchedule = nil
  end
  if self:getCheckFunctionSchedule() then
    veaf.removeFunction(self:getCheckFunctionSchedule())
    self:setCheckFunctionSchedule(nil)
  end
end

function GroundUnitHandler:orderTextAnalysis(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:orderTextAnalysis(%s)", veaf.lp(self:getName()), veaf.lp(value))
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

--- Rayon de dispersion apres une mission de tir, en metres.
---
--- Zero : la batterie reste en place. DCS ferait rouler le groupe dans ce rayon apres CHAQUE tache de tir,
--- ce qui empeche l'ordre suivant d'aboutir — un canon qui roule ne tire pas. Voir le commentaire dans
--- `handleOrder`. Une mission qui voudrait la dispersion realiste devrait la demander explicitement.
ArtilleryUnitHandler.COUNTERBATTERY_SCATTER = 0

ArtilleryUnitHandler.VERB_FIRE_FORAIM = 1
ArtilleryUnitHandler.VERB_FIRE_FOREFFECT = 2
--- Shift the last aim point by a bearing and a distance, then fire again — FEAT-ARTILLERY-CONTROL.
ArtilleryUnitHandler.VERB_CORRECT = 3

--- The artillery order specification, read by `veaf.parseMarkerText`.
---
--- REFACTOR-MARKER-PARSER ticket 03, group B. This is the only parser in the codebase that splits
--- on `";"` rather than `","`, which is why the shared parser takes the separator as a parameter.
---
--- Two other things are specific to it. The verbs are matched anywhere in the text and the chain's
--- order decides, so `fire aim` is an *aim*. And `target` is the only parameter rule in the
--- codebase that **validates its own input**, dropping a coordinate string `computeLLFromString`
--- cannot read instead of storing it.
ArtilleryUnitHandler.OrderSpec = {
  reportUnknownKeys = true,

  defaults = function(options)
    options.verb = ArtilleryUnitHandler.VERB_FIRE_FORAIM
    options.target = nil -- the coordinates of the target
    options.shells = nil -- the number of shells to fire
    options.radius = nil -- the precision of the shelling
    options.correction = nil -- { bearing, distance } once parsed, see parseCorrection
  end,
  commands = {
    {
      match = "aim",
      init = function(options)
        options.verb = ArtilleryUnitHandler.VERB_FIRE_FORAIM
      end,
    },
    {
      match = "fire",
      init = function(options)
        options.verb = ArtilleryUnitHandler.VERB_FIRE_FOREFFECT
      end,
    },
    -- Declared AFTER the two above and matched anywhere in the text, with the chain's order deciding
    -- (see this spec's own note). "correct" shares no substring with "aim" or "fire", so the position
    -- is not load-bearing — but a test pins it, because the next verb added might.
    {
      match = "correct",
      init = function(options)
        options.verb = ArtilleryUnitHandler.VERB_CORRECT
      end,
    },
  },
  parameters = {
    {
      keys = { "target" },
      apply = function(options, value)
        if veaf.computeLLFromString(value) then -- check target string validity
          options.target = value
        end
      end,
    },
    -- These assign whatever the conversion returns, nil included, which is the existing
    -- behaviour: an unreadable `shells` clears it, and fireForAim then applies its own default.
    {
      keys = { "shells" },
      apply = function(options, value)
        options.shells = veaf.getRandomizableNumeric(value)
      end,
    },
    {
      keys = { "radius" },
      apply = function(options, value)
        options.radius = veaf.getRandomizableNumeric(value)
      end,
    },
    -- The correction, as the artillery convention writes it: three digits of true bearing followed by
    -- the distance in metres. `09050` is fifty metres east. Validated here rather than in the handler,
    -- like `target` above — the only other rule in this codebase that checks its own input — because a
    -- correction the parser cannot read must not reach a gun as a nil.
    {
      keys = { "correction" },
      apply = function(options, value)
        options.correction = ArtilleryUnitHandler.parseCorrection(value)
      end,
    },
  },
  separator = ";",
  valueWhenAbsent = "",
}

function ArtilleryUnitHandler:orderTextAnalysis(text)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:orderTextAnalysis(%s)", veaf.lp(self:getName()), veaf.lp(text))

  local options = veaf.parseMarkerText(text, ArtilleryUnitHandler.OrderSpec)
  if not options then
    -- Announced, not dropped. A typo inside a readable order is already reported by
    -- `veaf.reportUnknownParameters` below; this is for text nothing could be made of, which used to
    -- vanish without a word. FIX-GROUNDAI-SILENT-REFUSALS.
    if not self.silent then
      trigger.action.outText(veaf.t("groundai.unreadable_order", self:getName(), tostring(text)), 10)
    end
    return nil
  end
  -- A typo aborts — see veaf.reportUnknownParameters. An artillery order arrives through the radio menu
  -- or as the value of a `_ground` marker, and neither path carries the requester's side.
  if veaf.reportUnknownParameters(options, veafGroundAI.Id, nil) then
    return nil
  end

  -- La valeur de retour reste les options analysees : c'est le contrat de cette fonction, et ses tests de
  -- caracterisation lisent ce qu'elle a compris du texte.
  self:executeOrder(options.verb, options.target, options.correction, options.shells, options.radius)
  return options
end

--- Executer un ordre deja decrit : un verbe et ses valeurs.
---
--- Extrait de `orderTextAnalysis` pour que les deux syntaxes partagent ce code. L'ancienne forme
--- (`order aim; target X`) doit d'abord recouper une chaine pour arriver ici ; la forme `_gc`
--- (`_gc arty-1, aim X`) arrive avec tout a plat et appelle directement. Deux copies de ce routage
--- divergeraient, et le symptome serait un ordre qui marche dans une syntaxe et pas dans l'autre.
---
--- @param verb number une constante VERB_* de ArtilleryUnitHandler
--- @param target string|nil les coordonnees, deja validees par le lecteur
--- @param correction table|nil { bearing, distance }, deja validee
--- @param shells number|nil
--- @param radius number|nil
--- @return boolean true si le verbe a ete reconnu
function ArtilleryUnitHandler:executeOrder(verb, target, correction, shells, radius)
  if verb == ArtilleryUnitHandler.VERB_CORRECT then
    self:correct(correction, shells, radius)
  elseif verb == ArtilleryUnitHandler.VERB_FIRE_FORAIM then
    self:fireForAim(target, shells, radius)
  elseif verb == ArtilleryUnitHandler.VERB_FIRE_FOREFFECT then
    self:fireForEffect(target, shells, radius)
  else
    return false
  end
  return true
end

-- give the artillery unit a fire for effect order
function ArtilleryUnitHandler:fireForAim(coordinates, shells, radius)
  if not shells then
    shells = ArtilleryUnitHandler.FIREFORAIM_SHELLS
  end
  if not radius then
    radius = ArtilleryUnitHandler.FIREFORAIM_RADIUS
  end
  veaf.loggers
    .get(veafGroundAI.Id)
    :debug(
      self.CLASS_NAME .. "[%s]:fireForAim(%s, %s, %s)",
      veaf.lp(self:getName()),
      veaf.lp(coordinates),
      veaf.lp(shells),
      veaf.lp(radius)
    )
  -- check the parameters
  if not coordinates then
    veaf.loggers.get(veafGroundAI.Id):warn(self.CLASS_NAME .. "[%s]:fireForAim() : no target coordinates", veaf.p(self:getName()))
    if not self.silent then
      local message = veaf.t("groundai.cannot_aim", veaf.p(self:getName()))
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
    -- The battery's remembered aim point, which is also what a correction corrects. There used to be a
    -- second field here (`_lastTarget`, set in `handleOrder` once the shells actually went out); the
    -- correction loop needed the same notion and two competing definitions of "the last target" in one
    -- class is a divergence waiting to happen. Unified on the queue-time point, because that is what
    -- makes chained corrections compound: two corrections of 50 m east land 100 m east even when the
    -- first order has not been executed yet. FEAT-ARTILLERY-CONTROL.
    coordinates = self.lastAimPoint
  end
  veaf.loggers
    .get(veafGroundAI.Id)
    :debug(self.CLASS_NAME .. "[%s]:fireForEffect(%s, %s)", veaf.lp(self:getName()), veaf.lp(shells), veaf.lp(radius))
  if not coordinates then
    veaf.loggers
      .get(veafGroundAI.Id)
      :warn(self.CLASS_NAME .. "[%s]:fireForEffect() : no previous target - cannot fire for effect", veaf.p(self:getName()))
    if not self.silent then
      local message = veaf.t("groundai.cannot_fire_effect", veaf.p(self:getName()))
      trigger.action.outText(message, 10)
    end
    return
  end
  self:fireAtCoordinates(coordinates, shells, radius)
end

-- give the artillery unit a fire order
--- Read a correction of the form `<bbb><ddd>`: three digits of true bearing, then metres.
---
--- `09050` is fifty metres east, which is the form #198 writes. Three digits for the bearing is not a
--- style choice: a bearing is always spoken and written as three digits, so `090` and `90` would
--- otherwise be the same string with different meanings once the distance is appended.
---
--- Rejects rather than guesses. A correction is a number a gun acts on, and the failure mode of a
--- lenient parser here is a shell in the wrong village.
---
--- @param value string the correction as typed
--- @return table|nil `{ bearing = degrees, distance = metres }`, or nil when it cannot be read
function ArtilleryUnitHandler.parseCorrection(value)
  if type(value) ~= "string" then
    return nil
  end
  local sDigits = value:match("^%s*(%d+)%s*$")
  -- At least four digits: three of bearing and one of distance. Fewer cannot be told apart from a
  -- bearing with no distance, and a correction of zero metres is not a correction.
  if not sDigits or #sDigits < 4 then
    return nil
  end
  local iBearing = tonumber(sDigits:sub(1, 3))
  local iDistance = tonumber(sDigits:sub(4))
  if not iBearing or not iDistance then
    return nil
  end
  -- 360 is refused rather than folded to 0: a player who wrote it meant something, and silently
  -- accepting it would hide the same typo the next time it is 361.
  if iBearing > 359 or iDistance <= 0 then
    return nil
  end
  return { bearing = iBearing, distance = iDistance }
end

--- Shift a point by a bearing and a distance.
---
--- **The convention matters more than the trigonometry.** A runtime vec3 is
--- `{ x = northing, y = altitude, z = easting }` — see `docs/agents/dcs-coordinates.md`, which exists
--- because getting this wrong raises no error and only produces a wrong position. So the northing takes
--- the cosine and the easting the sine, and a bearing of 090 moves the point east.
---
--- @param vec3Point table the point to shift
--- @param iBearing number true bearing in degrees
--- @param iDistance number metres
--- @return table a new point; the original is not modified
function ArtilleryUnitHandler.shiftPoint(vec3Point, iBearing, iDistance)
  local nRadians = math.rad(iBearing)
  return {
    x = vec3Point.x + iDistance * math.cos(nRadians),
    y = vec3Point.y,
    z = vec3Point.z + iDistance * math.sin(nRadians),
  }
end

--- Correct the last aim point and fire again.
---
--- The correction applies to **this battery's** last aim point, which is what makes the loop work
--- without a second name for the player to remember: an order already names its battery
--- (`_ground order, name Sierra23, order "correct 09050"`), and a battery holds one current aim point.
---
--- @param correction table|nil the result of `parseCorrection`
--- @param shells number|nil
--- @param radius number|nil
function ArtilleryUnitHandler:correct(correction, shells, radius)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:correct(%s)", veaf.lp(self:getName()), veaf.p(correction))

  if not correction then
    -- Told to the player, not only logged: he typed a correction and is waiting for shells.
    if not self.silent then
      trigger.action.outText(veaf.t("groundai.correction_unreadable", self:getName()), 10)
    end
    return
  end

  if not self.lastAimPoint then
    -- Nothing to correct from. Firing at the offset alone would put shells wherever the battery
    -- happens to stand, which is worse than refusing.
    if not self.silent then
      trigger.action.outText(veaf.t("groundai.correction_no_mission", self:getName()), 10)
    end
    return
  end

  local vec3New = ArtilleryUnitHandler.shiftPoint(self.lastAimPoint, correction.bearing, correction.distance)
  if not self.silent then
    trigger.action.outText(veaf.t("groundai.correction_applied", self:getName(), correction.bearing, correction.distance), 10)
  end
  -- Delegated to `fireForAim` rather than straight to `fireAtCoordinates`, so a correction gets the
  -- ranging defaults (2 rounds, 10 m) when the order gave no `shells` or `radius`. Calling
  -- `fireAtCoordinates` directly passed the nils through and queued an order with no round count — the
  -- two verbs above both apply their defaults first, and this one has to as well. A correction *is* a
  -- ranging shot: you fire a couple, look again, correct again.
  self:fireForAim(vec3New, shells, radius)
end

function ArtilleryUnitHandler:fireAtCoordinates(coordinates, shells, radius)
  veaf.loggers.get(veafGroundAI.Id):debug(
    self.CLASS_NAME .. "[%s]:fireAtCoordinates(%d, %s, %s)",
    veaf.lp(self:getName()),
    veaf.lp(shells),
    veaf.lp(coordinates),
    veaf.lp(radius)
  )
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
      veaf.loggers
        .get(veafGroundAI.Id)
        :warn(self.CLASS_NAME .. "[%s]:fireAtCoordinates() : coordinates are not valid: %s", veaf.p(self:getName()), veaf.p(coordinates))
    end
  end
  -- Remembered here, at the one place where a target has been resolved to a point, whichever form it
  -- arrived in — a string of coordinates or a vec3 from a previous correction. Storing it at the callers
  -- instead would mean remembering to do it in each, and a correction chain is only as good as the
  -- weakest link that forgot. FEAT-ARTILLERY-CONTROL.
  if target then
    self.lastAimPoint = { x = target.x, y = target.y, z = target.z }
  end

  local order = { verb = ArtilleryUnitHandler.ORDER_FIRE, parameters = { shells = shells, target = target, radius = radius } }
  self:addOrder(order)
end

function ArtilleryUnitHandler:handleOrder(order)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:handleOrder(%s)", veaf.lp(self:getName()), veaf.lp(order))
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
      local coordinates = grid.UTMZone .. " " .. grid.MGRSDigraph .. " " .. grid.Easting .. " " .. grid.Northing
      local message = veaf.t("groundai.firing", veaf.p(self:getName()), veaf.p(shells), veaf.p(coordinates), veaf.p(radius))
      trigger.action.outText(message, 10)
      veaf.loggers.get(veafGroundAI.Id):trace(
        "ArtilleryUnitHandler[%s]:handleOrder() : firing %d shells at %s with a %s m dispersion",
        veaf.lp(self:getName()),
        veaf.lp(shells),
        veaf.lp(coordinates),
        veaf.lp(radius)
      )
      -- fire the shells
      -- `y` prend le `z` du vec3 : la tache attend un vec2 de carte, ou le second axe est l'EST. Melanger
      -- les deux conventions ne leve aucune erreur et met les obus ailleurs — docs/agents/dcs-coordinates.md.
      local fireParams = {
        x = target.x,
        y = target.z,
        zoneRadius = radius,
        expendQty = shells,
        expendQtyEnabled = true,
        -- ZERO, et c'etait 500 en dur. Le schema de l'API DCS decrit ce champ comme « le rayon en metres,
        -- depuis le chef de groupe, dans lequel le groupe se deplacera dans des directions aleatoires
        -- APRES avoir termine la tache » : de l'evitement de contre-batterie.
        --
        -- Ce qui detruit une boucle de reglage. Signale en jeu le 2026-08-25 : le tir d'essai part, les
        -- canons se dispersent, l'ordre d'efficacite arrive sur un groupe qui roule — et une piece
        -- d'artillerie ne tire pas en roulant. « les canons se sont deplaces et ne tirent pas ».
        --
        -- La correction, elle, restait juste : elle porte sur la CIBLE, pas sur la position des canons.
        -- C'est bien le tir qui etait empeche, pas le calcul.
        counterbattaryRadius = ArtilleryUnitHandler.COUNTERBATTERY_SCATTER,
      }
      local fire = { id = "FireAtPoint", params = fireParams }
      self:getDcsGroup():getController():pushTask(fire)
    end
  end
  self:completeOrder()
end

function ArtilleryUnitHandler:stop()
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:stop()", veaf.lp(self:getName()))
  -- clear the group's orders queue
  self:getDcsGroup():getController():resetTask()
  return GroundUnitHandler.stop(self)
end

function ArtilleryUnitHandler:clearOrders()
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:clearOrders()", veaf.lp(self:getName()))
  -- clear the group's orders queue
  self:getDcsGroup():getController():resetTask()
  return GroundUnitHandler.clearOrders(self)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ConvoyUnitHandler class
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- A convoy that looks ahead, splits when it sees the enemy, calls for help and falls back.
---
--- What DCS does with a convoy on its own was measured on 2026-10-08 (FEAT-CONVOY-UNDER-FIRE, the PRD's
--- table): it drives on at full speed through an ambush without firing a round, its
--- `getDetectedTargets` can stay empty for 45 s under fire, and when it is given a new route only its
--- lead obeys while the rest of the column stalls where it stands. So this handler does not wait for
--- DCS to notice anything:
---
--- * a **wide watch** every 30 s lists the living enemy ground units within reach;
--- * while there are some, a **close watch** every 3 s traces lines of sight to them;
--- * an enemy in sight within range, or a shot or a hit received, is a **contact**: the unarmed vehicles
---   are respawned as their own group and flee at once, the armed ones fight or fall back after them,
---   and the convoy calls for help.
---
--- The two watches are David's design (2026-10-08). A line of sight costs ~14 µs (measured), so the close
--- watch is not the expensive part; the wide watch is kept slow because it asks the engine to walk every
--- object in a sphere.
ConvoyUnitHandler = GroundUnitHandler:new()
ConvoyUnitHandler.CLASS_NAME = "ConvoyUnitHandler"

--- Seconds between two wide watches.
ConvoyUnitHandler.WIDE_WATCH_PERIOD = 30
--- Seconds between two close watches, while an enemy is within the watch radius.
ConvoyUnitHandler.CLOSE_WATCH_PERIOD = 3
--- The wide watch's radius at a standstill, in metres; it grows with the speed.
ConvoyUnitHandler.WATCH_BASE_RADIUS = 5000
--- Seconds of driving added to the watch radius, so the next wide watch does not come too late.
ConvoyUnitHandler.WATCH_LOOKAHEAD_SECONDS = 60
--- An enemy in sight closer than this is a contact, in metres. The ambush of 2026-10-08 opened fire at
--- ~1.3 km; a BMP's Konkurs reaches 4 km, its guns much less.
ConvoyUnitHandler.ENGAGEMENT_RANGE = 3000
--- Height of a vehicle's eyes above the ground, for the lines of sight.
ConvoyUnitHandler.EYE_HEIGHT = 2.5
--- The armed vehicles fight when their strength is at least this many times the enemy's in sight.
ConvoyUnitHandler.FIGHT_RATIO = 1.5
--- Seconds with nothing in sight and no shot received before the convoy stands down and holds.
ConvoyUnitHandler.QUIET_DELAY = 60
--- The unarmed group is merged back into the convoy once this close to it, in metres.
ConvoyUnitHandler.MERGE_DISTANCE = 300
--- How close the armed vehicles go to the nearest threat to fight it, in metres, and how fast. On
--- 2026-10-08 Bradleys driving in opened fire at ~1.3 km; halted at 1.9 km they never did.
ConvoyUnitHandler.ASSAULT_STANDOFF = 900
ConvoyUnitHandler.ASSAULT_SPEED = 8
--- Seconds between two smoke marks while the contact lasts.
ConvoyUnitHandler.SMOKE_RENEW_PERIOD = 300
--- The fall-back search: rings around the convoy, in metres, and the spread of bearings away from the
--- enemy, in degrees either side of straight away.
ConvoyUnitHandler.RALLY_RINGS = { 1000, 1500, 2000, 2500, 3000 }
ConvoyUnitHandler.RALLY_SPREAD = 90
ConvoyUnitHandler.RALLY_STEP = 15
--- At most this many threats are tested for each candidate rally point (the nearest ones).
ConvoyUnitHandler.RALLY_MAX_THREATS = 5
--- A rally point this close to a road is moved onto it: off road, the second run's column bogged down.
ConvoyUnitHandler.ROAD_SNAP_DISTANCE = 300
--- A town masks a rally point when its centre lies this close to the line from the enemy to it.
ConvoyUnitHandler.TOWN_COVER_RADIUS = 400
--- The name the unarmed vehicles' group takes, after the convoy's.
ConvoyUnitHandler.UNARMED_SUFFIX = "unarmed"
--- What the call for help is sent on, in voice, when the mission can speak: the two guard frequencies.
ConvoyUnitHandler.GUARD_FREQUENCIES = "243,121.5"
ConvoyUnitHandler.GUARD_MODULATIONS = "AM,AM"

--- The callsigns a convoy is given when nobody named it, in this order; once all are taken, the list
--- starts again with a number (`Mule 2`). Beasts of burden, for columns that carry loads; without
--- accents, because the callsign is also the name `_gc` addresses the convoy by and is typed in a marker.
ConvoyUnitHandler.CALLSIGNS = {
  "Mule",
  "Bison",
  "Yak",
  "Lama",
  "Zebu",
  "Buffle",
  "Chameau",
  "Mammouth",
  "Taureau",
  "Elan",
  "Renne",
  "Okapi",
  "Bourricot",
  "Percheron",
  "Dromadaire",
  "Boeuf",
}

--- Seconds the armed vehicles wait for their unarmed ones to rejoin before both drive on separately.
ConvoyUnitHandler.REJOIN_TIMEOUT = 600

--- Seconds between the contact report and the tactical messages that follow it.
ConvoyUnitHandler.TACTICAL_MESSAGE_DELAY = 15

--- Seconds between two moves of the F10 marker that shows a convoy in contact.
ConvoyUnitHandler.DANGER_MARK_PERIOD = 15

--- The strength a vehicle brings to a fight, by DCS attribute, first match wins.
---
--- Read from DCS on 2026-10-08: a `Hummer` is an `APC` and `Armed vehicles` like the armed HMMWV; a
--- `ZSU-23-4 Shilka` is `AAA` but not `Armed ground units`, which is why `AAA` has its own line; a truck
--- is `Unarmed vehicles` and matches none of them.
ConvoyUnitHandler.STRENGTH_BY_ATTRIBUTE = {
  { attribute = "Tanks", strength = 4 },
  { attribute = "IFV", strength = 3 },
  { attribute = "APC", strength = 1 },
  { attribute = "AAA", strength = 1 },
  { attribute = "Armed ground units", strength = 1 },
}

ConvoyUnitHandler.STATE_DRIVING = 1
ConvoyUnitHandler.STATE_ALERTED = 2
ConvoyUnitHandler.STATE_FIGHTING = 3
ConvoyUnitHandler.STATE_FALLING_BACK = 4
ConvoyUnitHandler.STATE_HOLDING = 5
ConvoyUnitHandler.STATE_RETREATING = 6
ConvoyUnitHandler.STATE_RESUMING = 7

function ConvoyUnitHandler.stateToString(state)
  return veaf.enumToString(state, {
    [ConvoyUnitHandler.STATE_DRIVING] = "driving",
    [ConvoyUnitHandler.STATE_ALERTED] = "alerted",
    [ConvoyUnitHandler.STATE_FIGHTING] = "fighting",
    [ConvoyUnitHandler.STATE_FALLING_BACK] = "falling back",
    [ConvoyUnitHandler.STATE_HOLDING] = "holding",
    [ConvoyUnitHandler.STATE_RETREATING] = "retreating",
    [ConvoyUnitHandler.STATE_RESUMING] = "resuming",
  })
end

function ConvoyUnitHandler.init(object)
  -- the DCS group's name: the group object itself is replaced when the convoy is merged back
  object.groupName = nil
  -- the group of the unarmed vehicles, once the convoy has split
  object.unarmedGroupName = nil
  object.side = nil
  object.enemySide = nil
  object.state = ConvoyUnitHandler.STATE_DRIVING
  -- the enemy units the last wide watch found, as DCS objects
  object.enemies = {}
  -- one record per enemy unit that was seen or fired: { name, point, typeName, strength, lastSeen }
  object.threats = {}
  object.lastContact = nil
  object.nextWideWatch = 0
  object.nextSmoke = 0
  -- the route a Mission Editor group was given, kept to drive on after a contact
  object.originalRoute = nil
end

function ConvoyUnitHandler:new(objectToCopy)
  veaf.loggers.get(veafGroundAI.Id):debug(ConvoyUnitHandler.CLASS_NAME .. ":new()")
  local objectToCreate = objectToCopy or {}
  setmetatable(objectToCreate, self)
  self.__index = self
  GroundUnitHandler.init(objectToCreate)
  ConvoyUnitHandler.init(objectToCreate)
  return objectToCreate
end

--- The convoy's DCS group, by name, and the coalitions that follow from it.
--- @param value string
function ConvoyUnitHandler:setGroupName(value)
  veaf.loggers.get(veafGroundAI.Id):debug(self.CLASS_NAME .. "[%s]:setGroupName(%s)", veaf.lp(self:getName()), veaf.lp(value))
  self.groupName = value
  local group = Group.getByName(value)
  if group then
    self.dcsGroup = group
    self.side = group:getCoalition()
    self.enemySide = veafGroundAI.enemySideOf(self.side)
  end
  return self
end

function ConvoyUnitHandler:getGroupName()
  return self.groupName
end

--- The convoy's group, or nil once it no longer exists.
function ConvoyUnitHandler:getGroup()
  return veafGroundAI.livingGroup(self.groupName)
end

--- The unarmed vehicles' group, or nil when the convoy has not split or they are gone.
function ConvoyUnitHandler:getUnarmedGroup()
  return veafGroundAI.livingGroup(self.unarmedGroupName)
end

function ConvoyUnitHandler:stop()
  self:clearDanger()
  return GroundUnitHandler.stop(self)
end

function ConvoyUnitHandler:getDescription()
  return string.format(
    "%s is a convoy (%s), DCS group %s",
    self:getName(),
    ConvoyUnitHandler.stateToString(self.state),
    tostring(self.groupName)
  )
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- convoy helpers, kept free of any handler so that they can be tested on their own

--- The coalition a convoy of this side fights. Neutral fights nobody.
--- @param side number a coalition.side
--- @return number|nil
function veafGroundAI.enemySideOf(side)
  if side == coalition.side.RED then
    return coalition.side.BLUE
  elseif side == coalition.side.BLUE then
    return coalition.side.RED
  end
  return nil
end

--- A group that exists and still has units, or nil.
--- @param groupName string|nil
--- @return table|nil
function veafGroundAI.livingGroup(groupName)
  if not groupName then
    return nil
  end
  local group = Group.getByName(groupName)
  if not group then
    return nil
  end
  local ok, alive = pcall(function()
    return group:isExist() and #group:getUnits() > 0
  end)
  if ok and alive then
    return group
  end
  return nil
end

--- How far the wide watch looks, in metres, for a convoy driving at this speed.
--- @param speed number metres per second
--- @return number
function veafGroundAI.convoyWatchRadius(speed)
  return ConvoyUnitHandler.WATCH_BASE_RADIUS + ConvoyUnitHandler.WATCH_LOOKAHEAD_SECONDS * (speed or 0)
end

--- The strength a unit brings to a fight; 0 for a truck.
--- @param unit table a DCS unit
--- @return number
function veafGroundAI.unitStrength(unit)
  for _, entry in ipairs(ConvoyUnitHandler.STRENGTH_BY_ATTRIBUTE) do
    if unit:hasAttribute(entry.attribute) then
      return entry.strength
    end
  end
  return 0
end

--- Do the armed vehicles stand and fight, rather than fall back?
--- @param ownStrength number
--- @param enemyStrength number `math.huge` for an enemy they cannot answer (an aircraft, a gun out of range)
--- @return boolean
function veafGroundAI.convoyShouldFight(ownStrength, enemyStrength)
  return ownStrength > 0 and ownStrength >= ConvoyUnitHandler.FIGHT_RATIO * enemyStrength
end

--- Is this object a living ground unit of that coalition?
---
--- `world.searchObjects` keeps returning destroyed ground units with their coalition (known limitation
--- `destroyed-units-are-still-found-by-searchobjects`), so `isExist()` and `getLife() >= 1` are both
--- tested. Guarded: an object handed by DCS may be released while it is read.
--- @param object table a DCS object
--- @param side number a coalition.side
--- @return boolean
function veafGroundAI.isLivingGroundUnitOf(object, side)
  if not object or not side then
    return false
  end
  local ok, result = pcall(function()
    return object:isExist()
      and object:getCoalition() == side
      and object:getCategoryEx() == Unit.Category.GROUND_UNIT
      and object:getLife() >= 1
      and (not object.isActive or object:isActive())
  end)
  return ok and result == true
end

--- The living enemy ground units within a sphere.
--- @param center table a vec3
--- @param radius number metres
--- @param enemySide number a coalition.side
--- @return table the DCS units
function veafGroundAI.findEnemyGroundUnits(center, radius, enemySide)
  local found = {}
  local volume = { id = world.VolumeType.SPHERE, params = { point = center, radius = radius } }
  world.searchObjects(Object.Category.UNIT, volume, function(object)
    if veafGroundAI.isLivingGroundUnitOf(object, enemySide) then
      table.insert(found, object)
    end
    return true
  end)
  return found
end

local function dist2D(a, b)
  local dx, dz = a.x - b.x, a.z - b.z
  return math.sqrt(dx * dx + dz * dz)
end

--- A point raised to a vehicle's eyes, on the ground under it.
local function atEyeHeight(point)
  return { x = point.x, y = land.getHeight({ x = point.x, y = point.z }) + ConvoyUnitHandler.EYE_HEIGHT, z = point.z }
end

--- A point on the ground, as `trigger.action.smoke` wants it.
local function onGround(point)
  return { x = point.x, y = land.getHeight({ x = point.x, y = point.z }), z = point.z }
end

--- Does any of these units see the enemy, within range?
--- @param units table DCS units
--- @param enemyPoint table a vec3
--- @return boolean
function veafGroundAI.anyUnitSees(units, enemyPoint)
  local enemyEyes = atEyeHeight(enemyPoint)
  for _, unit in ipairs(units) do
    local point = unit:getPoint()
    if dist2D(point, enemyPoint) <= ConvoyUnitHandler.ENGAGEMENT_RANGE and land.isVisible(atEyeHeight(point), enemyEyes) then
      return true
    end
  end
  return false
end

--- The towns of the theatre, as map points, converted once.
veafGroundAI._townPoints = nil

function veafGroundAI.townPoints()
  if veafGroundAI._townPoints then
    return veafGroundAI._townPoints
  end
  local points = {}
  local theatre = env and env.mission and env.mission.theatre
  local towns = veafCities and theatre and veafCities[theatre]
  for _, town in pairs(towns or {}) do
    local point = coord.LLtoLO(town.latitude, town.longitude, 0)
    table.insert(points, { x = point.x, y = 0, z = point.z })
  end
  veafGroundAI._townPoints = points
  return points
end

--- Does a town stand between the enemy and the point, close enough to the line to mask it?
--- @param from table the enemy's vec3
--- @param to table the point's vec3
--- @return boolean
function veafGroundAI.townBetween(from, to)
  local dx, dz = to.x - from.x, to.z - from.z
  local length2 = dx * dx + dz * dz
  if length2 == 0 then
    return false
  end
  local cover = ConvoyUnitHandler.TOWN_COVER_RADIUS
  for _, town in ipairs(veafGroundAI.townPoints()) do
    local t = ((town.x - from.x) * dx + (town.z - from.z) * dz) / length2
    -- strictly between the two, and not on top of either: a town the enemy stands in masks nothing
    if t > 0 and t < 1 and dist2D(town, from) > cover and dist2D(town, to) > cover then
      local closest = { x = from.x + t * dx, z = from.z + t * dz }
      if dist2D(town, closest) <= cover then
        return true
      end
    end
  end
  return false
end

--- Is the point hidden from every one of these threats, by terrain or a town?
--- @param point table a vec3
--- @param threatPoints table vec3s
--- @return boolean
function veafGroundAI.isMaskedFrom(point, threatPoints)
  local eyes = atEyeHeight(point)
  for _, threatPoint in ipairs(threatPoints) do
    if land.isVisible(atEyeHeight(threatPoint), eyes) and not veafGroundAI.townBetween(threatPoint, point) then
      return false
    end
  end
  return true
end

--- The nearest friendly place: a campaign zone the side owns, or one of its airbases (not a ship).
--- @param side number a coalition.side
--- @param from table a vec3
--- @return table|nil { name, point }
function veafGroundAI.nearestFriendlyPlace(side, from)
  local best, bestDistance = nil, math.huge
  local function consider(name, point)
    local distance = dist2D(point, from)
    if distance < bestDistance then
      best, bestDistance = { name = name, point = { x = point.x, y = 0, z = point.z } }, distance
    end
  end
  local owner = (side == coalition.side.BLUE and "blue") or (side == coalition.side.RED and "red") or nil
  if owner and veafCampaign and veafCampaign.zoneList then
    for _, zone in ipairs(veafCampaign.zoneList) do
      if zone:getOwner() == owner and zone.entry.x and zone.entry.z then
        consider(zone.name, zone:getCenter())
      end
    end
  end
  for _, airbase in ipairs(coalition.getAirbases(side) or {}) do
    local desc = airbase:getDesc()
    if not (desc and desc.category == Airbase.Category.SHIP) then
      consider(airbase:getName(), airbase:getPoint())
    end
  end
  return best
end

--- The point a convoy falls back to: out of the enemy's sight, preferably toward a friendly place.
---
--- Candidates are sampled on rings around the convoy, across the half-plane away from the enemy, and
--- moved onto a road when one is near. A candidate the threats cannot see (terrain or a town in the
--- way) wins over one they can; among the hidden ones the cheapest is the shortest drive there plus the
--- drive on to the friendly place. When none is hidden, the cheapest one out of the enemy's range wins;
--- when there is none of those either, straight away from the nearest threat, out of its range.
---
--- Bounded work: `#RALLY_RINGS * (2 * RALLY_SPREAD / RALLY_STEP + 1)` candidates, each tested against
--- at most `RALLY_MAX_THREATS` threats — 325 lines of sight at most, ~5 ms by the 2026-10-08 measure.
---
--- @param from table the convoy's vec3
--- @param threatPoints table the threats' vec3s, nearest first
--- @param destination table|nil the friendly place's vec3
--- @return table the rally point, a vec3
--- @return boolean whether it is hidden from the threats
function veafGroundAI.chooseRallyPoint(from, threatPoints, destination)
  local threats = {}
  for index = 1, math.min(#threatPoints, ConvoyUnitHandler.RALLY_MAX_THREATS) do
    threats[index] = threatPoints[index]
  end
  local nearest = threats[1]
  local away = math.atan2(from.z - nearest.z, from.x - nearest.x)
  local outOfRange = ConvoyUnitHandler.ENGAGEMENT_RANGE + 500

  local bestHidden, bestHiddenCost = nil, math.huge
  local bestFar, bestFarCost = nil, math.huge
  for _, ring in ipairs(ConvoyUnitHandler.RALLY_RINGS) do
    for offset = -ConvoyUnitHandler.RALLY_SPREAD, ConvoyUnitHandler.RALLY_SPREAD, ConvoyUnitHandler.RALLY_STEP do
      local bearing = away + math.rad(offset)
      local candidate = { x = from.x + ring * math.cos(bearing), y = 0, z = from.z + ring * math.sin(bearing) }
      local roadX, roadZ = land.getClosestPointOnRoads("roads", candidate.x, candidate.z)
      if roadX and roadZ and dist2D({ x = roadX, z = roadZ }, candidate) <= ConvoyUnitHandler.ROAD_SNAP_DISTANCE then
        candidate = { x = roadX, y = 0, z = roadZ }
      end
      local cost = dist2D(from, candidate) + (destination and dist2D(candidate, destination) or 0)
      if veafGroundAI.isMaskedFrom(candidate, threats) then
        if cost < bestHiddenCost then
          bestHidden, bestHiddenCost = candidate, cost
        end
      else
        local closest = math.huge
        for _, threat in ipairs(threats) do
          closest = math.min(closest, dist2D(threat, candidate))
        end
        if closest >= outOfRange and cost < bestFarCost then
          bestFar, bestFarCost = candidate, cost
        end
      end
    end
  end
  if bestHidden then
    return bestHidden, true
  end
  if bestFar then
    return bestFar, false
  end
  local alreadyAway = dist2D(from, nearest)
  local run = math.max(outOfRange - alreadyAway, ConvoyUnitHandler.RALLY_RINGS[1])
  return { x = from.x + run * math.cos(away), y = 0, z = from.z + run * math.sin(away) }, false
end

--- A route point in mission-table form, where `y` is the easting (docs/agents/dcs-coordinates.md).
local function routePoint(point, action, speed)
  return {
    x = point.x,
    y = point.z,
    type = "Turning Point",
    action = action,
    speed = speed,
    speed_locked = true,
    ETA = 0,
    ETA_locked = false,
  }
end

--- The route a convoy falls back on: off road to the rally point, then on road to the friendly place.
---
--- Off road only for the first leg, which is short; the second run of 2026-10-08 bogged down at 0.6 m/s
--- on a 9 km straight line across country.
--- @param from table the convoy's vec3
--- @param rally table the rally point's vec3
--- @param destination table|nil the friendly place's vec3
--- @param speed number metres per second
--- @return table route points
function veafGroundAI.fallBackRoute(from, rally, destination, speed)
  local points = { routePoint(from, "Off Road", speed), routePoint(rally, "Off Road", speed) }
  if destination then
    table.insert(points, routePoint(rally, "On Road", speed))
    table.insert(points, routePoint(destination, "On Road", speed))
  end
  return points
end

--- "enemy" or "enemies", in the mission's language, for this count.
--- @param count number
--- @return string
function veafGroundAI.enemyWord(count)
  return veaf.t(count == 1 and "groundai.enemy_one" or "groundai.enemy_many")
end

--- The call for help, in the shape of a troops-in-contact call.
---
--- JP 3-09.3, *Close Air Support* (25 November 2014): "troops in contact" is friendly forces receiving
--- effective fire, an advisory call that highlights the urgency of the ground situation (p. III-36); an
--- immediate request names the unit called and the caller, priority #1 emergency, then "target is /
--- number of" (Appendix A, Section I). The rest is what a pilot needs to find both sides: where the
--- convoy is, where the enemy is from it, and the smokes.
--- @param callsign string
--- @param convoyPoint table a vec3
--- @param threats table the threat records, nearest first
--- @return string the text
--- @return string the shorter text for the voice
function veafGroundAI.convoyContactCall(callsign, convoyPoint, threats)
  local nearest = threats[1]
  local bearing, distance = veaf.getBearingAndRangeFromTo(convoyPoint, nearest.point)
  local lat, lon = coord.LOtoLL(convoyPoint)
  local position = veafGeo.toStringLL(lat, lon, 3) .. " / " .. veafGeo.toStringMGRS(coord.LLtoMGRS(lat, lon), 4)
  local counts, order = {}, {}
  for _, threat in ipairs(threats) do
    if not counts[threat.typeName] then
      counts[threat.typeName] = 0
      table.insert(order, threat.typeName)
    end
    counts[threat.typeName] = counts[threat.typeName] + 1
  end
  local described = {}
  for _, typeName in ipairs(order) do
    table.insert(described, string.format("%d x %s", counts[typeName], typeName))
  end
  local text = veaf.t("groundai.convoy_tic", callsign, position, #threats, table.concat(described, ", "), bearing, veaf.round(distance, -1))
  local voice =
    veaf.t("groundai.convoy_tic_voice", callsign, #threats, veafGroundAI.enemyWord(#threats), bearing, veaf.round(distance / 100, 0) * 100)
  return text, voice
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- the watch

function ConvoyUnitHandler:start()
  self.nextWideWatch = 0
  return GroundUnitHandler.start(self)
end

--- One beat of the watch, then the next one scheduled: every 30 s while nothing is near, every 3 s
--- otherwise. The beat ends for good once the convoy and its unarmed group are both gone.
function ConvoyUnitHandler:check()
  local now = timer.getTime()
  local group = self:getGroup()
  if not group and not self:getUnarmedGroup() then
    veaf.loggers.get(veafGroundAI.Id):info("convoy %s is gone, its watch ends", veaf.p(self:getName()))
    veafGroundAI.forgetConvoy(self)
    return
  end
  -- Guarded, so that a beat that raises still schedules the next one: the first in-game run lost its
  -- watch to an error two calls down (2026-10-08).
  if group then
    veaf.safeCall(self.watch, self, now, group)
  end
  if self.state == ConvoyUnitHandler.STATE_RESUMING then
    veaf.safeCall(self.mergeIfClose, self)
  end

  local delay = ConvoyUnitHandler.CLOSE_WATCH_PERIOD
  if self.state == ConvoyUnitHandler.STATE_DRIVING then
    delay = ConvoyUnitHandler.WIDE_WATCH_PERIOD
  end
  self:setCheckFunctionSchedule(veaf.scheduleFunction(function(handler)
    veaf.safeCall(handler.check, handler)
  end, { self }, now + delay))
end

--- Is the convoy in contact, rather than looking for one?
function ConvoyUnitHandler:isInContact()
  return self.state == ConvoyUnitHandler.STATE_FIGHTING or self.state == ConvoyUnitHandler.STATE_FALLING_BACK
end

--- The wide watch when it is due, the close watch while an enemy is near, and what follows from them.
--- @param now number
--- @param group table the convoy's DCS group
function ConvoyUnitHandler:watch(now, group)
  local units = group:getUnits()
  if now >= self.nextWideWatch then
    self.nextWideWatch = now + ConvoyUnitHandler.WIDE_WATCH_PERIOD
    local velocity = units[1]:getVelocity()
    local speed = math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z)
    local center = veaf.getAveragePosition(group)
    self.enemies = veafGroundAI.findEnemyGroundUnits(center, veafGroundAI.convoyWatchRadius(speed), self.enemySide)
    if self.state == ConvoyUnitHandler.STATE_DRIVING and #self.enemies > 0 then
      veaf.loggers.get(veafGroundAI.Id):debug("convoy %s: %d enemies within reach, close watch on", veaf.p(self:getName()), #self.enemies)
      self.state = ConvoyUnitHandler.STATE_ALERTED
    elseif self.state == ConvoyUnitHandler.STATE_ALERTED and #self.enemies == 0 then
      self.state = ConvoyUnitHandler.STATE_DRIVING
    end
  end

  local seen = {}
  for _, enemy in ipairs(self.enemies) do
    if veafGroundAI.isLivingGroundUnitOf(enemy, self.enemySide) and veafGroundAI.anyUnitSees(units, enemy:getPoint()) then
      table.insert(seen, enemy)
    end
  end
  for _, enemy in ipairs(seen) do
    self:recordThreat(enemy, now)
  end
  if #seen > 0 and not self:isInContact() then
    self:engage(now)
  end

  if self:isInContact() then
    if now >= (self.nextDangerMark or 0) then
      self:markDanger(now)
    end
    if now - self.lastContact >= ConvoyUnitHandler.QUIET_DELAY then
      if not self:pressOn(now) then
        self:standDown()
      end
    elseif self.calledForHelp and now >= self.nextSmoke then
      self:markWithSmoke(now)
    end
  end
end

--- Remember an enemy unit that was seen or that fired. One record per unit, however many bullets.
--- @param unit table a DCS unit
--- @param now number
function ConvoyUnitHandler:recordThreat(unit, now)
  local ok, name, point, typeName = pcall(function()
    return unit:getName(), unit:getPoint(), unit:getTypeName()
  end)
  if not ok then
    return
  end
  local strength = math.huge
  local group = self:getGroup()
  local isGround = veafGroundAI.isLivingGroundUnitOf(unit, self.enemySide)
  -- an aircraft, or a gun firing from beyond the range the convoy can answer at: nothing to fight
  if isGround and group and dist2D(point, veaf.getAveragePosition(group)) <= ConvoyUnitHandler.ENGAGEMENT_RANGE then
    strength = veafGroundAI.unitStrength(unit)
  end
  self.threats[name] = { name = name, point = point, typeName = typeName, strength = strength, lastSeen = now, ground = isGround }
  self.lastContact = now
end

--- A shot fired at the convoy or a hit taken, from the event handler.
---
--- A same-coalition initiator is ignored: a truck's explosion raises `S_EVENT_HIT` on its neighbours with
--- the truck as the initiator (measured 2026-10-08), and it is not an enemy. An event with no initiator
--- is ignored too: some shell hits carry none, and the shooter's own `S_EVENT_SHOOTING_START` names it.
--- @param initiator table|nil the DCS unit that fired
function ConvoyUnitHandler:reportFire(initiator)
  -- `_gc <convoy>, stop` or `unset` leaves the convoy in the event registry; stopped, it reacts to nothing
  if not initiator or self.status ~= GroundUnitHandler.STATUS_ACTIVE then
    return
  end
  local ok, side = pcall(function()
    return initiator:getCoalition()
  end)
  if not ok or side ~= self.enemySide then
    return
  end
  local now = timer.getTime()
  self:recordThreat(initiator, now)
  if not self:isInContact() then
    self:engage(now)
  end
end

--- The threats seen lately, nearest first.
--- @return table threat records
function ConvoyUnitHandler:recentThreats()
  local now = timer.getTime()
  local group = self:getGroup() or self:getUnarmedGroup()
  local center = group and veaf.getAveragePosition(group)
  local recent = {}
  for _, threat in pairs(self.threats) do
    if now - threat.lastSeen <= ConvoyUnitHandler.QUIET_DELAY then
      table.insert(recent, threat)
    end
  end
  if center then
    table.sort(recent, function(a, b)
      return dist2D(a.point, center) < dist2D(b.point, center)
    end)
  end
  return recent
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- the reaction

--- The contact: split, fight or fall back, call for help.
--- @param now number
function ConvoyUnitHandler:engage(now)
  local group = self:getGroup()
  local threats = self:recentThreats()
  if not group or #threats == 0 then
    return
  end
  veaf.loggers.get(veafGroundAI.Id):info("convoy %s: contact with %d enemies", veaf.p(self:getName()), #threats)
  self.lastContact = now
  self:suspendItinerary()

  local armed, unarmed, ownStrength = {}, {}, 0
  for _, unit in ipairs(group:getUnits()) do
    local strength = veafGroundAI.unitStrength(unit)
    if strength > 0 then
      table.insert(armed, unit)
      ownStrength = ownStrength + strength
    else
      table.insert(unarmed, unit)
    end
  end
  local enemyStrength = 0
  for _, threat in ipairs(threats) do
    enemyStrength = enemyStrength + threat.strength
  end

  local rally, destination = self:fallBackPoints(group, threats)
  if #armed == 0 then
    self:fallBack(self.groupName, rally, destination)
    self.state = ConvoyUnitHandler.STATE_FALLING_BACK
  else
    if #unarmed > 0 then
      self:detachUnarmed(unarmed, rally, destination)
    elseif self:getUnarmedGroup() then
      self:fallBack(self.unarmedGroupName, rally, destination)
    end
    if veafGroundAI.convoyShouldFight(ownStrength, enemyStrength) then
      self:fight(threats)
      self.state = ConvoyUnitHandler.STATE_FIGHTING
    else
      self:fallBack(self.groupName, rally, destination)
      self.state = ConvoyUnitHandler.STATE_FALLING_BACK
    end
  end
  -- Only a convoy falling back needs the air: one strong enough to fight says what it meets and deals
  -- with it, without smoke nor a call (David, after the demo's run of 2026-10-08).
  if self.state == ConvoyUnitHandler.STATE_FALLING_BACK then
    self:callForHelp(now)
  end
  self:markDanger(now)
end

--- Where the convoy falls back to, from where it stands now.
--- @return table the rally point
--- @return table|nil the friendly place's point
function ConvoyUnitHandler:fallBackPoints(group, threats)
  local from = veaf.getAveragePosition(group)
  local threatPoints = {}
  for _, threat in ipairs(threats) do
    table.insert(threatPoints, threat.point)
  end
  local place = veafGroundAI.nearestFriendlyPlace(self.side, from)
  local destination = place and place.point
  local rally = veafGroundAI.chooseRallyPoint(from, threatPoints, destination)
  return rally, destination
end

--- A `_spawn convoy` keeps walking its itinerary through `veafSpawn.convoyArrivalWatchdog`, which would
--- send it back on its way at the next arrival check; its `stopped` flag is what that watch respects.
function ConvoyUnitHandler:suspendItinerary()
  local record = veafSpawn and veafSpawn.spawnedConvoys and veafSpawn.spawnedConvoys[self.groupName]
  if record then
    record.stopped = true
  end
end

--- Respawn the unarmed vehicles as their own group, where they stand, and send it away at once.
---
--- A DCS ground group moves as one — the second run of 2026-10-08 turned its lead and left the rest of
--- the column standing — so a split is the only way for some vehicles to stay while others leave. DCS
--- cannot set a respawned unit's damage: a damaged truck comes back whole (decided 2026-10-08; the watch
--- makes the split come before the first hit in most cases).
--- @param units table the unarmed DCS units
--- @param rally table the rally point
--- @param destination table|nil the friendly place
function ConvoyUnitHandler:detachUnarmed(units, rally, destination)
  local definitions = {}
  local countryId = units[1]:getCountry()
  local center = { x = 0, y = 0, z = 0 }
  for _, unit in ipairs(units) do
    table.insert(definitions, veafGroundAI.unitDefinition(unit))
    local point = unit:getPoint()
    center.x, center.z = center.x + point.x / #units, center.z + point.z / #units
  end
  local name = self.unarmedGroupName or veafDcsSpawner.freeNameFrom(self.groupName .. " " .. ConvoyUnitHandler.UNARMED_SUFFIX)
  for _, unit in ipairs(units) do
    unit:destroy()
  end
  veafDcsSpawner.addGroup({
    countryId = countryId,
    category = "vehicle",
    name = name,
    units = definitions,
    route = { points = veafGroundAI.fallBackRoute(center, rally, destination, veafGroundAI.FALL_BACK_SPEED) },
  })
  self.unarmedGroupName = name
  veafGroundAI.convoysByGroupName[name] = self
  self:sayLater(ConvoyUnitHandler.TACTICAL_MESSAGE_DELAY + 3, "groundai.convoy_unarmed_falling_back")
end

--- Speed of a falling-back group, in metres per second (about 40 km/h).
veafGroundAI.FALL_BACK_SPEED = 11

--- What `addGroup` needs to rebuild this unit where it stands. The name is left to the spawner: the unit
--- being replaced may still hold its own for a frame.
--- @param unit table a DCS unit
--- @return table the unit definition
function veafGroundAI.unitDefinition(unit)
  local position = unit:getPosition()
  return {
    type = unit:getTypeName(),
    x = position.p.x,
    y = position.p.z,
    heading = math.atan2(position.x.z, position.x.x),
    skill = "Average",
  }
end

--- Go and fight: alarm red, weapons free, and close in to `ASSAULT_STANDOFF` of the nearest threat.
---
--- Not a halt where the contact was made. On 2026-10-08 two Bradleys halted 1.9 km from a BMP and a BTR
--- the watch could see: in two minutes not a round was fired by either side, their unit-level
--- `getDetectedTargets` stayed empty, and neither `Controller.knowTarget` nor a `FireAtPoint` task made
--- them fire. Sent forward instead, they opened fire at ~1.3 km and destroyed both in 16 s.
--- @param threats table the threats' records, nearest first
--- @param quietly boolean|nil true when closing in again: the contact was already reported
function ConvoyUnitHandler:fight(threats, quietly)
  local threat = threats[1]
  local group = self:getGroup()
  local controller = group:getController()
  controller:setOption(AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.RED)
  controller:setOption(AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.OPEN_FIRE)
  local from = veaf.getAveragePosition(group)
  local distance = dist2D(from, threat.point)
  if distance <= ConvoyUnitHandler.ASSAULT_STANDOFF then
    controller:pushTask({ id = "Hold", params = {} })
  else
    local share = (distance - ConvoyUnitHandler.ASSAULT_STANDOFF) / distance
    local stop = { x = from.x + (threat.point.x - from.x) * share, y = 0, z = from.z + (threat.point.z - from.z) * share }
    veaf.goRoute(self.groupName, {
      routePoint(from, "Off Road", ConvoyUnitHandler.ASSAULT_SPEED),
      routePoint(stop, "Off Road", ConvoyUnitHandler.ASSAULT_SPEED),
    })
  end
  if not quietly then
    local bearing, range = veaf.getBearingAndRangeFromTo(from, threat.point)
    self:say(
      "groundai.convoy_fighting",
      self:relativeDirection(threat.point),
      #threats,
      veafGroundAI.enemyWord(#threats),
      veaf.round(range, -1),
      bearing
    )
  end
end

--- Send a group away on the fall-back route, returning fire as it goes.
--- @param groupName string
--- @param rally table
--- @param destination table|nil
function ConvoyUnitHandler:fallBack(groupName, rally, destination)
  local group = veafGroundAI.livingGroup(groupName)
  if not group then
    return
  end
  local controller = group:getController()
  controller:setOption(AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.RED)
  controller:setOption(AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.OPEN_FIRE)
  veaf.goRoute(groupName, veafGroundAI.fallBackRoute(veaf.getAveragePosition(group), rally, destination, veafGroundAI.FALL_BACK_SPEED))
  if groupName == self.groupName then
    local threats = self:recentThreats()
    self:sayLater(
      ConvoyUnitHandler.TACTICAL_MESSAGE_DELAY,
      "groundai.convoy_falling_back",
      threats[1] and self:relativeDirection(threats[1].point) or ""
    )
  end
end

--- A message to the convoy's coalition, opened by its callsign — the handler's name.
function ConvoyUnitHandler:say(key, ...)
  trigger.action.outTextForCoalition(self.side, veaf.t(key, self:getName(), ...), 15)
end

--- A message said a little later: the tactical ones come after the contact report, the way a crew
--- reports first and acts on the net afterwards (David, 2026-10-08: "d'abord le message de contact, puis
--- on attend quelques secondes, puis les messages tactiques"). The actions themselves are not delayed.
--- @param delay number seconds
function ConvoyUnitHandler:sayLater(delay, key, ...)
  local args = { ... }
  veaf.scheduleFunction(function()
    self:say(key, unpack(args))
  end, nil, timer.getTime() + delay)
end

--- Where a point is from the convoy, as a crew says it: ahead, right, behind or left of its lead's heading.
--- @param point table a vec3
--- @return string the word, in the mission's language
function ConvoyUnitHandler:relativeDirection(point)
  local group = self:getGroup() or self:getUnarmedGroup()
  local lead = group and group:getUnits()[1]
  if not lead then
    return ""
  end
  local position = lead:getPosition()
  local heading = math.deg(math.atan2(position.x.z, position.x.x))
  local bearing = math.deg(math.atan2(point.z - position.p.z, point.x - position.p.x))
  return veaf.t(veafGroundAI.relativeDirectionKey(bearing - heading))
end

--- The i18n key of a relative bearing: within 45 degrees of the heading is ahead, and so on round.
--- @param relative number degrees, any range
--- @return string
function veafGroundAI.relativeDirectionKey(relative)
  local angle = relative % 360
  if angle < 45 or angle >= 315 then
    return "groundai.direction_ahead"
  elseif angle < 135 then
    return "groundai.direction_right"
  elseif angle < 225 then
    return "groundai.direction_behind"
  end
  return "groundai.direction_left"
end

--- Put, or move, the F10 marker that shows the convoy in contact to its coalition (David, 2026-10-08:
--- "pendant la résolution du combat, il faut mettre un marqueur sur la carte pour identifier le convoi en
--- danger, et le retirer quand c'est plus nécessaire"). A DCS mark cannot move: it is replaced.
--- @param now number
function ConvoyUnitHandler:markDanger(now)
  self:clearDanger()
  local group = self:getGroup() or self:getUnarmedGroup()
  if not group then
    return
  end
  self.dangerMarkId = veaf.getUniqueIdentifier()
  trigger.action.markToCoalition(
    self.dangerMarkId,
    veaf.t("groundai.convoy_danger_mark", self:getName()),
    veaf.getAveragePosition(group),
    self.side,
    true
  )
  self.nextDangerMark = now + ConvoyUnitHandler.DANGER_MARK_PERIOD
end

--- Remove the convoy's contact marker, if there is one.
function ConvoyUnitHandler:clearDanger()
  if self.dangerMarkId then
    trigger.action.removeMark(self.dangerMarkId)
    self.dangerMarkId = nil
  end
end

--- Call for help: the text to the coalition, the voice on guard when the mission can speak, the smokes.
---
--- The voice goes through `veafRadio.transmitMessage`, which does nothing when the mission has no SRS
--- configured (`STTS`) or no `os` — the case on dcs.veaf.org, decided 2026-10-08 — and the text goes out
--- regardless.
--- @param now number
function ConvoyUnitHandler:callForHelp(now)
  local group = self:getGroup() or self:getUnarmedGroup()
  local threats = self:recentThreats()
  if not group or #threats == 0 then
    return
  end
  local center = veaf.getAveragePosition(group)
  local text, voice = veafGroundAI.convoyContactCall(self:getName(), center, threats)
  trigger.action.outTextForCoalition(self.side, text, 30)
  self.calledForHelp = true
  self:markWithSmoke(now)
  -- Last, and guarded: a radio that raises must not take the smokes or the watch down with it, which is
  -- what a half-configured SRS did on 2026-10-08.
  if veafRadio and veafRadio.transmitMessage then
    veaf.safeCall(
      veafRadio.transmitMessage,
      voice,
      ConvoyUnitHandler.GUARD_FREQUENCIES,
      ConvoyUnitHandler.GUARD_MODULATIONS,
      self:getName(),
      self.side,
      center,
      true
    )
  end
end

--- Red smoke on the nearest enemy, green on the convoy: only with a call for help (David, 2026-10-08),
--- and for the pilots' eyes only — smoke does not blind DCS's AI (measured 2026-10-08).
--- @param now number
function ConvoyUnitHandler:markWithSmoke(now)
  local group = self:getGroup() or self:getUnarmedGroup()
  local threats = self:recentThreats()
  if not group or #threats == 0 then
    return
  end
  -- on the nearest enemy on the ground: under an aircraft, a red smoke would mark nothing
  for _, threat in ipairs(threats) do
    if threat.ground then
      trigger.action.smoke(onGround(threat.point), trigger.smokeColor.Red)
      break
    end
  end
  trigger.action.smoke(onGround(veaf.getAveragePosition(group)), trigger.smokeColor.Green)
  self.nextSmoke = now + ConvoyUnitHandler.SMOKE_RENEW_PERIOD
end

--- After a quiet minute in a fight: is an enemy still alive within the watch, even out of sight?
---
--- Out of sight is not destroyed. In the demo's run of 2026-10-08 the convoy saw one BMP of three, lost
--- sight of it, and drove on after a quiet minute — back toward an ambush still whole. So a fighting
--- convoy closes in again on the nearest living enemy the wide watch knows of, and only stands down when
--- none is left. A convoy falling back does not press on: it stands down and holds (Q4).
--- @param now number
--- @return boolean true when it closes in again rather than standing down
function ConvoyUnitHandler:pressOn(now)
  if self.state ~= ConvoyUnitHandler.STATE_FIGHTING then
    return false
  end
  local alive = {}
  for _, enemy in ipairs(self.enemies) do
    if veafGroundAI.isLivingGroundUnitOf(enemy, self.enemySide) then
      self:recordThreat(enemy, now)
      table.insert(alive, enemy)
    end
  end
  if #alive == 0 then
    return false
  end
  veaf.loggers.get(veafGroundAI.Id):info("convoy %s: %d enemies still alive out of sight, closing in again", veaf.p(self:getName()), #alive)
  self:fight(self:recentThreats(), true)
  self.lastContact = now
  return true
end

--- Nothing in sight and no shot for a while.
---
--- After a fight, the convoy drives on by itself and its unarmed vehicles join it (David, 2026-10-08:
--- "il faut faire `_gc resume` après l'engagement ? ça devrait [être automatique]"). After a fall back it
--- reports and holds, waiting for an order (Q4): the enemy it fled is still there, and driving on would
--- take it back into the same ambush.
function ConvoyUnitHandler:standDown()
  self:clearDanger()
  if self.state == ConvoyUnitHandler.STATE_FIGHTING then
    veaf.loggers
      .get(veafGroundAI.Id)
      :info("convoy %s: no contact for %d s after a fight, driving on", veaf.p(self:getName()), ConvoyUnitHandler.QUIET_DELAY)
    self:resume()
    return
  end
  veaf.loggers.get(veafGroundAI.Id):info("convoy %s: no contact for %d s, holding", veaf.p(self:getName()), ConvoyUnitHandler.QUIET_DELAY)
  local group = self:getGroup()
  if group then
    group:getController():pushTask({ id = "Hold", params = {} })
  end
  self.state = ConvoyUnitHandler.STATE_HOLDING
  self:say("groundai.convoy_holding", self:getName())
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- the orders: `_gc <convoy>, retreat|hold|resume`

--- Fall back now, to a named point or coordinates when one is given, otherwise to the nearest friendly
--- place. Not under fire, so on the road all the way, and no stand-down timer.
--- @param destinationText string|nil a named point or coordinates
--- @return boolean true when an order was given
function ConvoyUnitHandler:retreat(destinationText)
  local group = self:getGroup()
  if not group then
    return false
  end
  local from = veaf.getAveragePosition(group)
  local destination
  if destinationText and destinationText ~= "" then
    destination = veafNamedPoints and veafNamedPoints.getPoint(destinationText)
    if not destination then
      local lat, lon = veaf.computeLLFromString(destinationText)
      if lat and lon then
        destination = coord.LLtoLO(lat, lon)
      end
    end
    if not destination then
      trigger.action.outText(veaf.t("spawn.point_not_found", destinationText), 10)
      return false
    end
  else
    local place = veafGroundAI.nearestFriendlyPlace(self.side, from)
    if not place then
      self:say("groundai.convoy_nowhere_to_go", self:getName())
      return false
    end
    destination = place.point
  end
  self:suspendItinerary()
  self:clearDanger()
  local speed = veafGroundAI.FALL_BACK_SPEED
  local route = { routePoint(from, "On Road", speed), routePoint(destination, "On Road", speed) }
  veaf.goRoute(self.groupName, route)
  if self:getUnarmedGroup() then
    veaf.goRoute(
      self.unarmedGroupName,
      { routePoint(veaf.getAveragePosition(self:getUnarmedGroup()), "On Road", speed), routePoint(destination, "On Road", speed) }
    )
  end
  self.state = ConvoyUnitHandler.STATE_RETREATING
  self:say("groundai.convoy_retreating")
  return true
end

--- Halt where it stands, both groups.
--- @return boolean
function ConvoyUnitHandler:hold()
  local group = self:getGroup()
  if not group then
    return false
  end
  self:suspendItinerary()
  self:clearDanger()
  group:getController():pushTask({ id = "Hold", params = {} })
  local unarmed = self:getUnarmedGroup()
  if unarmed then
    unarmed:getController():pushTask({ id = "Hold", params = {} })
  end
  self.state = ConvoyUnitHandler.STATE_HOLDING
  self:say("groundai.convoy_holding", self:getName())
  return true
end

--- Drive on: the convoy back on its way, the unarmed group joining it to be merged back.
--- @return boolean
function ConvoyUnitHandler:resume()
  local group = self:getGroup()
  if not group then
    return false
  end
  local controller = group:getController()
  controller:setOption(AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.AUTO)
  self.threats = {}
  self.enemies = {}
  self.nextWideWatch = 0
  self.calledForHelp = false
  self:clearDanger()
  local unarmed = self:getUnarmedGroup()
  if unarmed then
    -- The armed vehicles wait where they are, and the convoy drives on once merged. Driving on at once
    -- left the trucks, sent to where the armed vehicles had been, parked on the ambush site while the
    -- column went on without them (the demo's run, 2026-10-08).
    controller:pushTask({ id = "Hold", params = {} })
    -- Straight across, not by road: sent "On Road" on 2026-10-08, the trucks drove away to reach the road
    -- network first, 2.8 km then 3.2 km from where they were going.
    veaf.goRoute(self.unarmedGroupName, {
      routePoint(veaf.getAveragePosition(unarmed), "Off Road", veafGroundAI.FALL_BACK_SPEED),
      routePoint(veaf.getAveragePosition(group), "Off Road", veafGroundAI.FALL_BACK_SPEED),
    })
    self.rejoinDeadline = timer.getTime() + ConvoyUnitHandler.REJOIN_TIMEOUT
    self.state = ConvoyUnitHandler.STATE_RESUMING
  else
    veaf.goRoute(self.groupName, self:onwardRoute(group))
    self.state = ConvoyUnitHandler.STATE_DRIVING
  end
  self:say("groundai.convoy_resuming")
  return true
end

--- The route on from where the convoy stands: back to the nearest road, then its itinerary's current
--- leg for a `_spawn convoy`, the rest of its Mission Editor route otherwise (from the waypoint nearest
--- to it).
---
--- Back to the road first, the way `veaf.generateVehiclesRoute` starts a convoy (`T_STA` off road, `STA`
--- on it). On 2026-10-08 the route went straight to the leg's last point — `T_END`, the true end, whose
--- action is `Diamond` — and the convoy drove on across country, 330 to 376 m from the road at 3 to 4 m/s.
--- @param group table the convoy's DCS group
--- @return table route points
function ConvoyUnitHandler:onwardRoute(group)
  local from = veaf.getAveragePosition(group)
  local speed = veafGroundAI.FALL_BACK_SPEED
  local roadX, roadZ = land.getClosestPointOnRoads("roads", from.x, from.z)
  local points = { routePoint(from, "Off Road", speed) }
  if roadX and roadZ then
    table.insert(points, routePoint({ x = roadX, z = roadZ }, "On Road", speed))
  end
  local record = veafSpawn and veafSpawn.spawnedConvoys and veafSpawn.spawnedConvoys[self.groupName]
  if record and record.route then
    record.stopped = false
    -- the leg's road end (`END`) and its true end (`T_END`), as the spawn made them; never the start
    for index = 3, #record.route do
      local point = record.route[index]
      table.insert(points, routePoint({ x = point.x, z = point.y }, point.action or "On Road", point.speed or speed))
    end
    return points
  end
  local original = self.originalRoute or {}
  local nearest, nearestDistance = nil, math.huge
  for index, point in ipairs(original) do
    local distance = dist2D({ x = point.x, z = point.y }, from)
    if distance < nearestDistance then
      nearest, nearestDistance = index, distance
    end
  end
  for index = (nearest or #original) + 1, #original do
    local point = original[index]
    table.insert(
      points,
      routePoint({ x = point.x, z = point.y }, point.form or point.action or "On Road", point.speed or veafGroundAI.FALL_BACK_SPEED)
    )
  end
  return points
end

--- Once the unarmed group has caught up, rebuild the convoy as one group, under its own name.
---
--- `coalition.addGroup` with the name of a group that exists replaces it — same id, the old vehicles
--- gone, one group of that name (measured 2026-10-08). Like the split, it cannot carry damage over.
function ConvoyUnitHandler:mergeIfClose()
  local group, unarmed = self:getGroup(), self:getUnarmedGroup()
  if not (group and unarmed) then
    -- nobody left to wait for: whoever is left drives on
    local left = group or unarmed
    if left then
      veaf.goRoute(left:getName(), self:onwardRoute(left))
    end
    self.state = ConvoyUnitHandler.STATE_DRIVING
    return
  end
  if dist2D(veaf.getAveragePosition(group), veaf.getAveragePosition(unarmed)) > ConvoyUnitHandler.MERGE_DISTANCE then
    if timer.getTime() >= (self.rejoinDeadline or math.huge) then
      -- a truck stuck short of the column: both drive on, each on its own
      veaf.loggers.get(veafGroundAI.Id):warn("convoy %s: the unarmed vehicles did not rejoin, driving on apart", veaf.p(self:getName()))
      veaf.goRoute(self.groupName, self:onwardRoute(group))
      veaf.goRoute(self.unarmedGroupName, self:onwardRoute(unarmed))
      self.state = ConvoyUnitHandler.STATE_DRIVING
    end
    return
  end
  local definitions = {}
  local units = group:getUnits()
  for _, unit in ipairs(units) do
    table.insert(definitions, veafGroundAI.unitDefinition(unit))
  end
  for _, unit in ipairs(unarmed:getUnits()) do
    table.insert(definitions, veafGroundAI.unitDefinition(unit))
  end
  local route = self:onwardRoute(group)
  local countryId = units[1]:getCountry()
  veafGroundAI.convoysByGroupName[self.unarmedGroupName] = nil
  unarmed:destroy()
  self.unarmedGroupName = nil
  veafDcsSpawner.addGroup({
    countryId = countryId,
    category = "vehicle",
    name = self.groupName,
    units = definitions,
    route = { points = route },
  })
  self.state = ConvoyUnitHandler.STATE_DRIVING
  veaf.loggers.get(veafGroundAI.Id):info("convoy %s merged back", veaf.p(self:getName()))
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- the convoys' registry and their events

--- The convoy handler of each DCS group name — the convoy and, once split, its unarmed group.
veafGroundAI.convoysByGroupName = {}

--- Hand a group to the convoy watch. Called for every `_spawn convoy`, for the groups `mission.yaml`
--- lists under `GROUNDAI.convoys`, and by `_gc <name>, convoy`.
---
--- The handler's name is the convoy's **callsign**: what it opens its messages with, and what `_gc`
--- addresses it by — `_gc eglantine, resume`. A name the player chose is kept as the callsign; a convoy
--- nobody named takes the next free one of `ConvoyUnitHandler.CALLSIGNS`.
--- @param groupName string the DCS group's name
--- @param handlerName string|nil the callsign; the next free one of the list by default
--- @return table|nil the handler, or nil when there is no such group
function veafGroundAI.addConvoy(groupName, handlerName)
  veaf.loggers.get(veafGroundAI.Id):debug("veafGroundAI.addConvoy(%s)", veaf.p(groupName))
  if veafGroundAI.convoysByGroupName[groupName] then
    return veafGroundAI.convoysByGroupName[groupName]
  end
  if not veafGroundAI.livingGroup(groupName) then
    veaf.loggers.get(veafGroundAI.Id):warn("no group named %s to watch as a convoy", veaf.p(groupName))
    return nil
  end
  local handler = ConvoyUnitHandler:new()
  handler:setSilent(true)
  handler:setName(handlerName or veafGroundAI.nextConvoyCallsign())
  handler:setGroupName(groupName)
  if not (veafSpawn and veafSpawn.spawnedConvoys and veafSpawn.spawnedConvoys[groupName]) then
    handler.originalRoute = veafDcsSpawner.getGroupRoute(groupName)
  end
  veafGroundAI.convoysByGroupName[groupName] = handler
  handler:start()
  return handler
end

--- Drop a convoy whose groups are all gone.
function veafGroundAI.forgetConvoy(handler)
  for name, registered in pairs(veafGroundAI.convoysByGroupName) do
    if registered == handler then
      veafGroundAI.convoysByGroupName[name] = nil
    end
  end
  handler:clearDanger()
  handler.status = GroundUnitHandler.STATUS_OVER
  veafGroundAI.remove(handler)
end

--- The next callsign nobody holds: the first free one of the list, then the list again with a number.
--- @return string
function veafGroundAI.nextConvoyCallsign()
  local round = 1
  while true do
    for _, flower in ipairs(ConvoyUnitHandler.CALLSIGNS) do
      local callsign = round == 1 and flower or string.format("%s %d", flower, round)
      if not veafGroundAI.handlers[callsign:lower()] then
        return callsign
      end
    end
    round = round + 1
  end
end

--- The DCS events a convoy reacts to: a shot starting at one of its units, a hit on one.
veafGroundAI.eventHandler = {}

function veafGroundAI.eventHandler:onEvent(event)
  if not event or (event.id ~= world.event.S_EVENT_SHOOTING_START and event.id ~= world.event.S_EVENT_HIT) then
    return
  end
  local target = event.target
  if not (target and target.getGroup) then
    return
  end
  local ok, groupName = pcall(function()
    return target:getGroup():getName()
  end)
  local handler = ok and veafGroundAI.convoysByGroupName[groupName]
  if handler then
    veaf.safeCall(handler.reportFire, handler, event.initiator)
  end
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

--- The one autopilot whose name contains this text, or nil when none or several do.
---
--- A `_spawn convoy` is named by the spawner (`[b]-Convoy-3` and the like), so a part of the name that
--- designates one autopilot is enough to give it an order, the way `groupname` already works.
--- Deliberately not part of `get`: `set` creates the autopilot it does not find by its exact name, and a
--- partial match there would hand `arty-1`'s autopilot to the group a new `arty` was meant for.
--- @param text string
--- @return table|nil
function veafGroundAI.getByPart(text)
  local wanted = text:lower()
  local found = nil
  for name, candidate in pairs(veafGroundAI.handlers) do
    if name:find(wanted, 1, true) then
      if found then
        return nil
      end
      found = candidate
    end
  end
  return found
end

--- Find a named autopilot, and tell the player when there is none.
---
--- Six `_ground` verbs used to do `if handler then … end` with no `else`, so a command addressed to a name
--- nobody had registered did nothing and said nothing — its only trace a `trace` line, invisible at the
--- default log level. Reported in game as "ça ne fait rien (et rien dans le log)" after a mission reload
--- had discarded the autopilot created before it.
---
--- `_ground set` deliberately does NOT use this: it creates the handler when it is missing, which is the
--- whole point of that verb.
---
--- @param handlerName string the name the player used
--- @return table|nil the handler, or nil after having said so
function veafGroundAI.getOrComplain(handlerName)
  local handler = veafGroundAI.get(handlerName) or veafGroundAI.getByPart(handlerName)
  if not handler then
    veaf.loggers.get(veafGroundAI.Id):warn("no autopilot named %s", veaf.p(handlerName))
    trigger.action.outText(veaf.t("groundai.no_such_handler", tostring(handlerName), tostring(handlerName)), 10)
  end
  return handler
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
          veaf.loggers.get(veafGroundAI.Id):trace("group = %s", veaf.lp(group))
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
        local handler = veafGroundAI.getOrComplain(handlerName)
        if handler then
          handler:stop()
          veafGroundAI.remove(handler)
          return true
        end
      elseif options.verb == veafGroundAI.VERB_START then
        veaf.loggers.get(veafGroundAI.Id):trace("options.verb == veafGroundAI.VERB_START")
        local handlerName = options.name
        local handler = veafGroundAI.getOrComplain(handlerName)
        if handler then
          handler:start()
          return true
        end
      elseif options.verb == veafGroundAI.VERB_STOP then
        veaf.loggers.get(veafGroundAI.Id):trace("options.verb == veafGroundAI.VERB_STOP")
        local handlerName = options.name
        local handler = veafGroundAI.getOrComplain(handlerName)
        if handler then
          handler:stop()
          return true
        end
      elseif options.verb == veafGroundAI.VERB_CLEAR then
        veaf.loggers.get(veafGroundAI.Id):trace("options.verb == veafGroundAI.VERB_CLEAR")
        local handlerName = options.name
        local handler = veafGroundAI.getOrComplain(handlerName)
        if handler then
          handler:stop()
          handler:clearOrders()
          return true
        end
      elseif options.verb == veafGroundAI.VERB_STATUS then
        veaf.loggers.get(veafGroundAI.Id):trace("options.verb == veafGroundAI.VERB_STATUS")
        local handlerName = options.name
        local handler = veafGroundAI.getOrComplain(handlerName)
        if handler then
          trigger.action.outText(veaf.t("groundai.handler_info", handlerName, handler:getDescription()), 10)
          return true
        end
      elseif options.verb == veafGroundAI.VERB_CONVOY then
        local handler = options.group and veafGroundAI.addConvoy(options.group:getName(), options.name)
        if handler then
          trigger.action.outText(veaf.t("groundai.convoy_watched", handler:getName()), 10)
          return true
        end
      elseif
        options.verb == veafGroundAI.VERB_RETREAT
        or options.verb == veafGroundAI.VERB_HOLD
        or options.verb == veafGroundAI.VERB_RESUME
      then
        local handler = veafGroundAI.getOrComplain(options.name)
        if handler then
          if not handler.retreat then
            -- an artillery battery has no such order: said, rather than silently ignored
            trigger.action.outText(veaf.t("groundai.not_a_convoy", handler:getName(), handler:getName()), 10)
          elseif options.verb == veafGroundAI.VERB_RETREAT then
            return handler:retreat(options.destination)
          elseif options.verb == veafGroundAI.VERB_HOLD then
            return handler:hold()
          else
            return handler:resume()
          end
        end
      elseif options.verb == veafGroundAI.VERB_ORDER then
        veaf.loggers.get(veafGroundAI.Id):trace("options.verb == veafGroundAI.VERB_ORDER")
        local handlerName = options.name
        local handler = veafGroundAI.getOrComplain(handlerName)
        if handler then
          if options.orderVerb then
            -- Forme `_gc` : l'ordre est deja a plat, rien a recouper.
            if handler:executeOrder(options.orderVerb, options.target, options.correction, options.shells, options.radius) then
              return true
            end
          elseif handler:orderTextAnalysis(options.order) then
            -- Ancienne forme : `order aim; target X`, a recouper sur les points-virgules.
            return true
          end
        end
      end
    end
  end

  -- None of the keywords matched.
  return false
end

veafGroundAI.VERB_SET = 1
veafGroundAI.VERB_UNSET = 2
veafGroundAI.VERB_ORDER = 3
veafGroundAI.VERB_START = 4
veafGroundAI.VERB_STOP = 5
veafGroundAI.VERB_CLEAR = 6
veafGroundAI.VERB_STATUS = 7
-- FEAT-CONVOY-UNDER-FIRE: hand a group to the convoy watch, and steer a convoy.
veafGroundAI.VERB_CONVOY = 8
veafGroundAI.VERB_RETREAT = 9
veafGroundAI.VERB_HOLD = 10
veafGroundAI.VERB_RESUME = 11

--- The ground-AI module's marker specification, read by `veaf.parseMarkerText`.
---
--- REFACTOR-MARKER-PARSER ticket 03. `valueWhenAbsent = ""` is load-bearing and reproduced as-is:
--- it is also why a valueless `name` is accepted as an empty string, since the mandatory check
--- below is `not options.name` and `""` is truthy in Lua. That is a recorded defect and it gets
--- its own named commit rather than being repaired inside this move.
---
--- What deliberately stays OUT of the specification is the nearest-allied-group search: it needs
--- the marker's position and coalition and it reads the game world, which a text parser has no
--- business doing. The shared parser handles the text; `markTextAnalysis` handles the world.
veafGroundAI.MarkerSpec = {
  reportUnknownKeys = true,

  defaults = function(options)
    options.verb = veafGroundAI.VERB_SET
    options.group = nil -- the DCS group concerned by "set" and "unset"
    options.order = nil -- the order given by "order" (ancienne forme imbriquee)
    options.name = nil -- the handler name, concerned by every verb
    -- Forme `_gc` : l'ordre est decrit a plat, ici, au lieu d'etre une chaine a recouper.
    options.orderVerb = nil -- aim / fire / correct
    options.target = nil -- les coordonnees, validees a la lecture
    options.correction = nil -- { bearing, distance }, validee a la lecture
    options.shells = nil
    options.radius = nil
    options.destination = nil -- `retreat <point>`, the convoy's
  end,
  commands = {
    {
      match = veafGroundAI.MarkerKeyphrase .. " set",
      init = function(options)
        options.verb = veafGroundAI.VERB_SET
      end,
    },
    {
      match = veafGroundAI.MarkerKeyphrase .. " unset",
      init = function(options)
        options.verb = veafGroundAI.VERB_UNSET
      end,
    },
    {
      match = veafGroundAI.MarkerKeyphrase .. " order",
      init = function(options)
        options.verb = veafGroundAI.VERB_ORDER
      end,
    },
    {
      match = veafGroundAI.MarkerKeyphrase .. " start",
      init = function(options)
        options.verb = veafGroundAI.VERB_START
      end,
    },
    {
      match = veafGroundAI.MarkerKeyphrase .. " stop",
      init = function(options)
        options.verb = veafGroundAI.VERB_STOP
      end,
    },
    {
      match = veafGroundAI.MarkerKeyphrase .. " clear",
      init = function(options)
        options.verb = veafGroundAI.VERB_CLEAR
      end,
    },
    {
      match = veafGroundAI.MarkerKeyphrase .. " status",
      init = function(options)
        options.verb = veafGroundAI.VERB_STATUS
      end,
    },
    -- Declaree en DERNIER, et ce n'est pas cosmetique : les commandes sont cherchees comme un morceau
    -- de texte n'importe ou, premiere trouvee gagne. Un groupe nomme `x_gcy` dans un ancien
    -- `_ground stop, name x_gcy` contient `_gc` ; laisser cette entree devant detournerait la commande.
    {
      match = veafGroundAI.ShortKeyphrase,
      init = function(options)
        -- `_gc arty-1` seul vaut `set`, comme le defaut du spec. Le verbe est ensuite pose par la regle
        -- du mot correspondant, s'il y en a un.
        options.verb = veafGroundAI.VERB_SET
      end,
    },
  },
  parameters = {
    {
      -- A valueless `groupname` arrives as "" and used to be handed to `Group.getByName("")`.
      -- Skipped now: an empty name cannot identify a group, and leaving `options.group` nil is
      -- what lets the nearest-allied-group search below do its job.
      --
      -- Une recherche exacte, elle, ne trouvait jamais un groupe apparu par une commande VEAF : `-arty,
      -- unitname arty-1` cree un groupe que DCS appelle `[b]-arty-1#7`, donc `groupname arty-1` tombait
      -- systematiquement dans la recherche de proximite. Le nom retenu suffit maintenant.
      keys = { "groupname" },
      apply = function(options, value)
        if value ~= nil and value ~= "" then
          -- Le nom demande est conserve : c'est lui qu'on redit au pilote si la recherche echoue, et
          -- c'est aussi ce qui distingue "aucun nom donne" de "un nom donne qui ne designe rien".
          options.groupName = value
          options.group, options.groupCandidates = veaf.findGroupByPartialName(value)
        end
      end,
    },
    { keys = { "name" }, apply = veaf.markerRules.text("name") },
    { keys = { "order" }, apply = veaf.markerRules.text("order") },

    -- ── la forme `_gc` ────────────────────────────────────────────────────────
    -- Le mot-cle lui-meme porte le nom : `_gc arty-1` se lit "cle `_gc`, valeur `arty-1`". C'est ce qui
    -- supprime le mot `name` sans toucher au moteur du parseur.
    { keys = { veafGroundAI.ShortKeyphrase }, apply = veaf.markerRules.text("name") },

    -- Les sept verbes du marqueur, en mots simples. Ecrire `_gc arty-1, stop` plutot que
    -- `_ground stop, name arty-1`.
    veafGroundAI.verbRule("set", veafGroundAI.VERB_SET),
    veafGroundAI.verbRule("unset", veafGroundAI.VERB_UNSET),
    veafGroundAI.verbRule("start", veafGroundAI.VERB_START),
    veafGroundAI.verbRule("stop", veafGroundAI.VERB_STOP),
    veafGroundAI.verbRule("clear", veafGroundAI.VERB_CLEAR),
    veafGroundAI.verbRule("status", veafGroundAI.VERB_STATUS),

    -- The convoy's verbs (FEAT-CONVOY-UNDER-FIRE). `retreat` carries, inline and optional, the named point
    -- or the coordinates to fall back to; without a value, the nearest friendly place.
    veafGroundAI.verbRule("convoy", veafGroundAI.VERB_CONVOY),
    veafGroundAI.verbRule("hold", veafGroundAI.VERB_HOLD),
    veafGroundAI.verbRule("resume", veafGroundAI.VERB_RESUME),
    {
      keys = { "retreat" },
      apply = function(options, value)
        options.verb = veafGroundAI.VERB_RETREAT
        if value and value ~= "" then
          options.destination = value
        end
      end,
    },

    -- Les verbes d'ordre portent leur valeur EN LIGNE, et c'est tout l'objet du lot : la grille se
    -- recopie telle que DCS l'affiche, espaces compris, sans mot `target` ni point-virgule.
    --
    -- Chacun pose deux choses : le verbe du marqueur (`order`, pour que le repartiteur route vers
    -- l'artillerie) et le verbe de l'ordre lui-meme.
    {
      keys = { "aim" },
      apply = function(options, value)
        options.verb = veafGroundAI.VERB_ORDER
        options.orderVerb = ArtilleryUnitHandler.VERB_FIRE_FORAIM
        -- Validee a la lecture, comme `target` : une chaine que le lecteur de coordonnees ne sait pas
        -- lire ne doit jamais atteindre un canon. Une valeur absente reste absente.
        if value and value ~= "" and veaf.computeLLFromString(value) then
          options.target = value
        end
      end,
    },
    {
      keys = { "fire" },
      apply = function(options, value)
        options.verb = veafGroundAI.VERB_ORDER
        options.orderVerb = ArtilleryUnitHandler.VERB_FIRE_FOREFFECT
        -- `fire` sans cible retire au dernier point vise : l'absence de valeur est un cas normal ici,
        -- pas une erreur.
        if value and value ~= "" and veaf.computeLLFromString(value) then
          options.target = value
        end
      end,
    },
    {
      -- Deux orthographes plutot qu'une a retenir sous le feu.
      keys = { "correct", "correction" },
      apply = function(options, value)
        options.verb = veafGroundAI.VERB_ORDER
        options.orderVerb = ArtilleryUnitHandler.VERB_CORRECT
        options.correction = ArtilleryUnitHandler.parseCorrection(value)
      end,
    },

    -- Remontes au niveau du marqueur : c'est ce qui rend le point-virgule inutile.
    {
      keys = { "target" },
      apply = function(options, value)
        if value and value ~= "" and veaf.computeLLFromString(value) then
          options.target = value
        end
      end,
    },
    {
      keys = { "shells" },
      apply = function(options, value)
        options.shells = veaf.getRandomizableNumeric(value)
      end,
    },
    {
      keys = { "radius" },
      apply = function(options, value)
        options.radius = veaf.getRandomizableNumeric(value)
      end,
    },
  },
  valueWhenAbsent = "",
  -- `name` is mandatory for every verb, and the empty string has to be rejected explicitly: values
  -- arrive as "" rather than nil in this module, and `""` is truthy in Lua, so the old
  -- `if not options.name` guard let `_ground status, name` through with a nameless handler. Same
  -- bug shape SECREV-010 fixed in veafMove; `requireText` is now the one place it is spelled out.
  validate = veaf.markerRules.requireText("name"),
}

--- Extract keywords from mark text.
function veafGroundAI.markTextAnalysis(eventPos, eventCoalition, text)
  veaf.loggers.get(veafGroundAI.Id):trace("veafGroundAI.markTextAnalysis(text=%s)", veaf.lp(text))

  local options = veaf.parseMarkerText(text, veafGroundAI.MarkerSpec)
  if not options then
    return nil
  end

  -- Seuls `set` et `unset` designent un groupe ; les autres verbes s'adressent a un pilote automatique
  -- deja pose et ignorent `groupname`, y compris ecrit de travers. Les deux blocs ci-dessous partagent
  -- donc cette condition.
  local needsGroup = options.verb == veafGroundAI.VERB_SET
    or options.verb == veafGroundAI.VERB_UNSET
    or options.verb == veafGroundAI.VERB_CONVOY

  -- Un nom donne qui ne designe pas UN groupe arrete la commande, au lieu de retomber sur la recherche
  -- de proximite : le pilote a nomme le groupe qu'il voulait, et lui poser le pilote automatique sur le
  -- groupe le plus proche du marqueur serait piloter une unite que personne n'a designee.
  if needsGroup and options.groupName and not options.group then
    if options.groupCandidates then
      local candidates = table.concat(options.groupCandidates, ", ")
      veaf.loggers.get(veafGroundAI.Id):warn("ambiguous group name [%s]: %s", veaf.lp(options.groupName), veaf.lp(candidates))
      trigger.action.outText(veaf.t("groundai.ambiguous_group_name", options.groupName, candidates), 15)
    else
      veaf.loggers.get(veafGroundAI.Id):warn("no group matches [%s]", veaf.lp(options.groupName))
      trigger.action.outText(veaf.t("groundai.no_such_group", options.groupName), 10)
    end
    return nil
  end

  -- check mandatory parameter "groupname" for commands "set" and "unset"
  if needsGroup and not options.group then
    -- search for the nearest allied group
    local minDist = 999999
    local closestUnit = nil
    for _, unit in pairs(veaf.getUnitsOfCoalition(false, eventCoalition)) do
      local pos = unit:getPosition().p
      if pos then
        local name = unit:getName()
        local distanceFromCenter = ((pos.x - eventPos.x) ^ 2 + (pos.z - eventPos.z) ^ 2) ^ 0.5
        veaf.loggers.get(veaf.Id):trace("name=%s; distanceFromCenter=%s", veaf.lp(name), veaf.lp(distanceFromCenter))
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
      -- Said out loud rather than aborted in silence: a marker dropped a hundred metres too far from the
      -- battery produced nothing at all, and nothing distinguished that from a broken module.
      -- FIX-GROUNDAI-SILENT-REFUSALS.
      veaf.loggers.get(veafGroundAI.Id):warn("no allied group within 250m of the marker")
      trigger.action.outText(veaf.t("groundai.no_group_nearby"), 10)
      return nil
    end
  end

  return options
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
--- Global functions for the module
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafGroundAI.add(handler)
  veaf.loggers.get(veafGroundAI.Id):debug("veafGroundAI.add([%s])", veaf.lp(handler:getName()))
  veafGroundAI.handlers[handler:getName():lower()] = handler
  return handler
end

function veafGroundAI.remove(handler)
  veaf.loggers.get(veafGroundAI.Id):debug("veafGroundAI.remove([%s])", veaf.lp(handler:getName()))
  veafGroundAI.handlers[handler:getName():lower()] = nil
end

function veafGroundAI.get(handlerName)
  veaf.loggers.get(veafGroundAI.Id):debug("veafGroundAI.get([%s])", veaf.lp(handlerName))
  local handler = veafGroundAI.handlers[handlerName:lower()]
  if handler then
    veaf.loggers.get(veafGroundAI.Id):trace("handler found: %s", veaf.lp(handler))
  end
  return handler
end

function veafGroundAI.initialize()
  veaf.loggers.get(veafGroundAI.Id):info(veaf.loggers.get(veafGroundAI.Id):getVersionInfo())
  veaf.loggers.get(veafGroundAI.Id):info("Initializing module")
  -- L9: any pilot the server hook lists in veaf-pilots.txt (level >= 1). Spawning and
  -- commanding ground AI is the same power veafSpawn already gates, and this path had no
  -- check at all (SECREV-2, VMR-003). David: restrict to VEAF pilots authenticated by the hook.
  -- Deux enregistrements, un par mot-clé, et c'est la seule façon d'être appelé pour les deux.
  --
  -- Le dernier argument est un FILTRE : le répartiteur n'appelle ce gestionnaire que pour les textes qui
  -- contiennent ce mot. Il n'accepte qu'une chaîne, pas une liste — donc `_gc` n'atteignait tout
  -- simplement pas le module, et le marqueur restait sur la carte sans un mot. Trouvé en jeu le
  -- 2026-08-25, alors que 163 tests passaient : ils appelaient `executeCommand` directement, jamais le
  -- répartiteur. C'est le câblage qui manquait, pas le gestionnaire.
  local function handleMarker(pos, event, bypass, fromMarker)
    if not fromMarker then
      return false
    end
    return veafGroundAI.onEventMarkChange(pos, event)
  end
  veafCommands.registerCommandHandler(handleMarker, veafCommands.PRIORITY_GROUNDAI, "KNOWN_PILOT", veafGroundAI.MarkerKeyphrase)
  veafCommands.registerCommandHandler(handleMarker, veafCommands.PRIORITY_GROUNDAI, "KNOWN_PILOT", veafGroundAI.ShortKeyphrase)

  -- FEAT-CONVOY-UNDER-FIRE: the convoys' own event handler, registered once — DCS delivers an event to a
  -- handler as many times as it was added (#824). It reads the raw `target` and `initiator`, which
  -- `veafEventHandler` hands its callbacks as data tables with no methods.
  if not veafGroundAI.initialized then
    world.addEventHandler(veafGroundAI.eventHandler)
  end
  veafGroundAI.initialized = true
  for _, groupName in ipairs(veaf.getConfig(veafGroundAI.Id).convoys or {}) do
    veafGroundAI.addConvoy(groupName)
  end
  -- the convoys spawned before this module started up, by a mission script or a combat zone
  for groupName in pairs(veafSpawn and veafSpawn.spawnedConvoys or {}) do
    veafGroundAI.addConvoy(groupName)
  end
end

veaf.registerModule(veafGroundAI.Id, veafGroundAI.initialize, { enable = true }, 190)
