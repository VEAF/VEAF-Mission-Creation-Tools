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
  self:setCheckFunctionSchedule(mist.scheduleFunction(function(handler)
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
    mist.removeFunction(self.checkFunctionSchedule)
    self.checkFunctionSchedule = nil
  end
  if self:getCheckFunctionSchedule() then
    mist.removeFunction(self:getCheckFunctionSchedule())
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
  local handler = veafGroundAI.get(handlerName)
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
  local needsGroup = options.verb == veafGroundAI.VERB_SET or options.verb == veafGroundAI.VERB_UNSET

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
end

veaf.registerModule(veafGroundAI.Id, veafGroundAI.initialize, { enable = true }, 190)
