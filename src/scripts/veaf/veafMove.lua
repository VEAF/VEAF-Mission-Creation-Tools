------------------------------------------------------------------
-- VEAF move units for DCS World
-- By mitch (2018)
--
-- Features:
-- ---------
-- * Listen to marker change events and execute move commands, with optional parameters
-- * Possibilities :
-- *    - move a specific group to a marker point, at a specific speed
-- *    - create a new tanker flightplan, moving a specific tanker group
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

--- veafMove Table.
veafMove = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafMove.Id = "MOVE"

-- trace level, specific to this module
--veafMove.LogLevel = "trace"

veaf.loggers.new(veafMove.Id, veafMove.LogLevel)

--- Key phrase to look for in the mark text which triggers the command.
veafMove.Keyphrase = "_move"

--- The escort of a group is the group with this suffix appended to its name.
--- This convention is what lets the framework find an escort in order to repair its Escort task,
--- which DCS invalidates whenever the escorted group is recreated (teleported or respawned).
--- Documented for mission makers on the ASSETS page.
veafMove.EscortGroupNameSuffix = " escort"

veafMove.RadioMenuName = "menu.move.root"

veafMove.tankerMissionParameters = {
  ["A-10C"] = { speed = 250, alt = 12000 },
  ["A-10C_2"] = { speed = 250, alt = 12000 },
  ["AV8BNA"] = { speed = 350, alt = 18000 },
  ["F-14A"] = { speed = 400, alt = 22000 },
  ["F-14A-135-GR"] = { speed = 400, alt = 22000 },
  ["F-14B"] = { speed = 400, alt = 22000 },
  ["F-15C"] = { speed = 400, alt = 22000 },
  ["F-15E"] = { speed = 400, alt = 22000 },
  ["F-16A"] = { speed = 400, alt = 22000 },
  ["F-16A MLU"] = { speed = 400, alt = 22000 },
  ["F-16C bl.50"] = { speed = 400, alt = 22000 },
  ["F-16C bl.52d"] = { speed = 400, alt = 22000 },
  ["F-16C_50"] = { speed = 400, alt = 22000 },
  ["F-4E"] = { speed = 300, alt = 18000 },
  ["F/A-18A"] = { speed = 400, alt = 22000 },
  ["F/A-18C"] = { speed = 400, alt = 22000 },
  ["FA-18C_hornet"] = { speed = 400, alt = 22000 },
  ["JF-17"] = { speed = 400, alt = 22000 },
  ["M-2000C"] = { speed = 400, alt = 22000 },
  ["MiG-29K"] = { speed = 400, alt = 22000 },
  ["MiG-31"] = { speed = 400, alt = 22000 },
  ["Mirage 2000-5"] = { speed = 400, alt = 22000 },
  ["Su-24M"] = { speed = 400, alt = 22000 },
  ["Su-24MR"] = { speed = 400, alt = 22000 },
  ["Su-33"] = { speed = 400, alt = 22000 },
  ["Su-34"] = { speed = 400, alt = 22000 },
  ["Tornado GR4"] = { speed = 400, alt = 22000 },
}
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafMove.rootPath = nil

--- Initial Marker id.
veafMove.markid = 20000

traceMarkerId = 6548
debugMarkers = {}

veafMove.Tankers = {}
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafMove.executeCommand(eventPos, eventText, bypassSecurity)
  -- Check if marker has a text and the veafMove.keyphrase keyphrase.
  if eventText ~= nil and eventText:lower():find(veafMove.Keyphrase) then
    -- Analyse the mark point text and extract the keywords.
    local options = veafMove.markTextAnalysis(eventText)
    local result = false

    if options then
      -- A typo aborts — see veaf.reportUnknownParameters. nil: this handler is not given the requester.
      if veaf.reportUnknownParameters(options, veafMove.Id, nil) then
        return false
      end
      -- Check options commands
      if options.moveGroup then
        result = veafMove.moveGroup(eventPos, options.groupName, options.speed, options.altitude)
      elseif options.moveTanker then
        result = veafMove.moveTanker(
          eventPos,
          options.groupName,
          options.speed,
          options.altitude,
          options.hdg,
          options.distance,
          options.teleport,
          options.silent
        )
      elseif options.changeTanker then
        result = veafMove.changeTanker(eventPos, options.speed, options.altitude)
      elseif options.moveAfac then
        result = veafMove.moveAfac(eventPos, options.groupName, options.speed, options.altitude, options.hdg, options.immortal)
      end
    else
      -- None of the keywords matched.
      return false
    end

    return result
  end
end
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The move module's marker specification, read by `veaf.parseMarkerText`.
---
--- REFACTOR-MARKER-PARSER ticket 03. The per-sub-verb defaults are the quirk that most needed
--- preserving here: a group move starts at 20 knots, a tanker keeps its own speed and altitude
--- via the `-1` sentinel, and an AFAC gets 150 knots at 15000 feet. Order matters —
--- `tankermission` MUST be tested before `tanker`, or it could never match.
veafMove.MarkerSpec = {
  reportUnknownKeys = true,

  defaults = function(options)
    options.moveGroup = false
    options.moveTanker = false
    options.changeTanker = false
    options.moveAfac = false
    options.groupName = "" -- the name of the group to move ; mandatory
    options.speed = -1 -- defaults to original speed
    options.altitude = -1 -- defaults to tanker original altitude
    options.hdg = nil -- defaults to original heading
    options.immortal = false -- option to set AFAC to immortal
    options.distance = nil -- defaults to original distance
    options.teleport = false -- if true, teleport the tanker instead of making it move
    options.silent = false -- if false, Named Points are created when moving the tankers
  end,
  commands = {
    {
      match = veafMove.Keyphrase .. " group",
      init = function(options)
        options.moveGroup = true
        options.speed = 20
      end,
    },
    {
      match = veafMove.Keyphrase .. " tankermission",
      init = function(options)
        options.changeTanker = true
        options.speed = -1
        options.altitude = -1
      end,
    },
    {
      match = veafMove.Keyphrase .. " tanker",
      init = function(options)
        options.moveTanker = true
        options.speed = -1
        options.altitude = -1
      end,
    },
    {
      match = veafMove.Keyphrase .. " afac",
      init = function(options)
        options.moveAfac = true
        options.speed = 150
        options.altitude = 15000
      end,
    },
  },
  parameters = {
    { keys = { "name" }, apply = veaf.markerRules.text("groupName") },
    -- `plainNumber` keeps the field when the value will not convert, which is what protects the
    -- `-1` sentinel meaning "keep the tanker's original speed or altitude". The old code assigned
    -- `tonumber(val)` unconditionally, so `speed banana` sent nil downstream instead.
    -- `plainNumber` and not `number`: this module never accepted the `1-5` random-range syntax.
    { keys = { "speed", "spd" }, apply = veaf.markerRules.plainNumber("speed") },
    { keys = { "heading", "hdg" }, apply = veaf.markerRules.plainNumber("hdg") },
    { keys = { "distance", "dist" }, apply = veaf.markerRules.plainNumber("distance") },
    { keys = { "alt", "altitude" }, apply = veaf.markerRules.plainNumber("altitude") },
    { keys = { "teleport" }, apply = veaf.markerRules.flag("teleport") },
    { keys = { "silent" }, apply = veaf.markerRules.flag("silent") },
    { keys = { "immortal" }, apply = veaf.markerRules.flag("immortal") },
  },
  valueWhenAbsent = nil,
  -- SECREV-010: "" is truthy in Lua, so the empty default has to be rejected explicitly. The check
  -- lives in `veaf.markerRules.requireText` now, since three modules were each writing it out and
  -- the one that wrote it as `if not x` shipped the bug.
  validate = veaf.markerRules.requireText("groupName"),
}

--- Extract keywords from mark text.
function veafMove.markTextAnalysis(text)
  return veaf.parseMarkerText(text, veafMove.MarkerSpec)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Group move command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- veafMove.moveGroup
-- @param point eventPos
-- @param string groupName the group name to move on
-- @param float speed in knots
------------------------------------------------------------------------------
function veafMove.moveGroup(eventPos, groupName, speed, altitude)
  veaf.loggers.get(veafMove.Id):debug("veafMove.moveGroup(groupName = " .. groupName .. ", speed = " .. speed .. ", altitude=" .. altitude)
  veaf.loggers.get(veafMove.Id):debug(string.format("veafMove.moveGroup: eventPos  x=%.1f z=%.1f", eventPos.x, eventPos.z))

  local result = veaf.moveGroupTo(groupName, eventPos, speed, altitude)
  if not result then
    trigger.action.outText(veaf.t("move.group_not_found", groupName), 10)
  end
  return result
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tanker route helpers (shared by changeTanker and moveTanker)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Locate the waypoint carrying the tanker's orbit task.
--- Returns its index and the task, or nil when the route has no orbit at all.
---
--- #248: this used to be "the second-to-last waypoint", which is true of VEAF's own templates — whose
--- route is [approach, orbit, leg end] — and false of a DCS-Liberation tanker, whose longer route ends
--- with a landing point. Both tanker commands then refused with "has no ORBIT task defined".
---
--- **The first orbit wins** when a route carries several. A tanker route has one working orbit; if
--- there are several, the first is the one the tanker reaches first, so it is the one that is active or
--- imminent, which is what a player asking to change tanker parameters means. "The one nearest the
--- requested position" was rejected: appealing for moveTanker, meaningless for changeTanker which moves
--- nothing, and two commands disagreeing about which orbit they mean would be worse.
function veafMove._findOrbitWaypoint(points)
  for index = 1, #points do
    local task = veafMove._findOrbitTaskInPoint(points[index])
    if task then
      return index, task
    end
  end
  return nil, nil
end

--- Extract the tanker's orbit waypoint, its neighbours, and tankerData for a named tanker group.
--- Returns a table {tankerData, points, orbitIndex, orbitTask, point1, point2, point3} or nil + message.
---
--- `point2` is the orbit itself. `point1` (the waypoint before) and `point3` (the waypoint after) are
--- **optional**: an orbit on the first or last waypoint of a route is legal, and refusing such a route
--- would trade one false refusal for another.
---
--- `point3` is the far end of the refuelling leg, which is why callers overwrite it — that is DCS's own
--- semantics for a `Race-Track` orbit: it flies between the waypoint carrying the task and the next
--- one. It therefore holds on a Liberation route just as on a VEAF template. A `Circle` orbit is the
--- exception: it turns around a single point and gives the next waypoint no orbit role, so `point3` is
--- withheld there rather than letting a caller redraw the route. See ticket 01 of FIX-MOVE-ORBIT-SEARCH.
function veafMove._getTankerRouteData(groupName)
  local tankerData = veaf.getGroupData(groupName)
  if not tankerData then
    return nil, "Cannot find group data for tanker " .. groupName
  end
  local route = veaf.findInTable(tankerData, "route")
  local points = veaf.findInTable(route, "points")
  if not points or #points < 1 then
    return nil, "Cannot find a valid route for tanker " .. groupName
  end

  local orbitIndex, orbitTask = veafMove._findOrbitWaypoint(points)
  if not orbitIndex then
    return nil, "Cannot find an ORBIT task in the route of tanker " .. groupName
  end

  local point3 = points[orbitIndex + 1]
  local pattern = orbitTask.params and orbitTask.params.pattern
  if pattern == "Circle" and point3 then
    veaf.loggers.get(veafMove.Id):debug("tanker %s orbits a single point (Circle); leaving the waypoint after it alone", veaf.lp(groupName))
    point3 = nil
  end

  return {
    tankerData = tankerData,
    points = points,
    orbitIndex = orbitIndex,
    orbitTask = orbitTask,
    point1 = points[orbitIndex - 1],
    point2 = points[orbitIndex],
    point3 = point3,
  },
    nil
end

--- Find the Orbit task in a waypoint's task list.
--- Returns the task table or nil if not found.
function veafMove._findOrbitTaskInPoint(point)
  local task1 = veaf.findInTable(point, "task")
  if not task1 then
    return nil
  end
  local tasks = task1.params and task1.params.tasks
  if not tasks then
    return nil
  end
  for _, task in pairs(tasks) do
    if task.id and task.id == "Orbit" and task.params then
      return task
    end
  end
  return nil
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Change tanker mission parameters
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafMove.changeTanker(eventPos, speed, alt)
  veaf.loggers.get(veafMove.Id):debug(string.format("veafMove.changeTanker(speed=%s, alt=%s)", tostring(speed), tostring(alt)))
  veaf.loggers.get(veafMove.Id):trace(string.format("eventPos=%s", veaf.p(eventPos)))
  veaf.loggers.get(veafMove.Id):cleanupMarkers(debugMarkers)

  local tankerUnit = nil
  local units = veaf.findUnitsInCircle(eventPos, 2000, false)
  veaf.loggers.get(veafMove.Id):trace(string.format("units=%s", veaf.p(units)))
  if units then
    for name, _ in pairs(units) do
      -- try and find a tanker unit
      local unit = Unit.getByName(name)
      if unit and unit:getDesc()["attributes"]["Tankers"] then
        tankerUnit = unit
        break
      end
    end
  end

  if not tankerUnit then
    veaf.loggers.get(veafMove.Id):warn("Cannot find tanker unit around marker")
    trigger.action.outText(veaf.t("move.no_tanker"), 10)
    return false
  end

  local tankerGroup = tankerUnit:getGroup()
  local tankerGroupName = tankerGroup:getName()

  local routeData, errMsg = veafMove._getTankerRouteData(tankerGroupName)
  if not routeData then
    veaf.loggers.get(veafMove.Id):info(errMsg)
    trigger.action.outText(errMsg or "", 10)
    return false
  end
  local tankerData, points = routeData.tankerData, routeData.points
  local point1, point2, point3 = routeData.point1, routeData.point2, routeData.point3

  veaf.loggers.get(veafMove.Id):trace("found a " .. #points .. "-points route for tanker " .. tankerGroupName)

  -- point1 is the point where the tanker mission starts ; we'll change the speed and altitude.
  -- Optional since #248: the orbit is now found wherever it is in the route, and it may be the very
  -- first waypoint, in which case there is no waypoint before it. A caller passing -1 asks to *read*
  -- the current speed or altitude, so that read falls back to the orbit waypoint, which always exists.
  local referencePoint = point1 or point2
  if point1 then
    if speed > -1 then
      point1.speed = speed / 1.94384 -- in m/s
    end
    if alt > -1 then
      point1.alt = alt * 0.3048 -- in meters
    end
    veaf.loggers.get(veafMove.Id):trace(string.format("newPoint1=%s", veaf.p(point1)))
  else
    veaf.loggers.get(veafMove.Id):debug("tanker %s orbits on its first waypoint; no approach point to adjust", veaf.lp(tankerGroupName))
  end
  if speed <= -1 then
    speed = referencePoint.speed * 1.94384 -- in knots
  end
  if alt <= -1 then
    alt = referencePoint.alt / 0.3048 -- in feet
  end

  -- point 2 is the start of the tanking Orbit ; we'll change the speed and altitude
  local orbitTask = routeData.orbitTask
  veaf.loggers.get(veafMove.Id):debug("Found a ORBIT task for tanker " .. tankerGroupName)
  if speed > -1 then
    orbitTask.params.speed = speed / 1.94384 -- in m/s
    point2.speed = speed / 1.94384 -- in m/s
  end
  if alt > -1 then
    orbitTask.params.altitude = alt * 0.3048 -- in meters
    point2.alt = alt * 0.3048 -- in meters
  end

  -- point 3 is the end of the tanking Orbit ; we'll change the speed and altitude.
  -- Optional since #248: absent when the orbit is the last waypoint of the route, and withheld for a
  -- Circle orbit, which turns around one point and gives the next waypoint no orbit role.
  if point3 then
    if speed > -1 then
      point3.speed = speed / 1.94384 -- in m/s
    end
    if alt > -1 then
      point3.alt = alt * 0.3048 -- in meters
    end
    veaf.loggers.get(veafMove.Id):trace("newpoint3=%s", veaf.lp(point3))
  else
    veaf.loggers.get(veafMove.Id):debug("tanker %s has no leg-end waypoint to adjust", veaf.lp(tankerGroupName))
  end

  -- replace whole mission
  veaf.loggers.get(veafMove.Id):debug("Resetting changed tanker mission")
  local mission = {
    id = "Mission",
    params = tankerData,
  }
  local controller = tankerGroup:getController()
  controller:setTask(mission)

  local msg = string.format("Set tanker %s to %d kn (ground) at %d ft", tankerGroupName, speed, alt)
  veaf.loggers.get(veafMove.Id):info(msg)
  trigger.action.outText(veaf.t("move.tanker_set_params", tankerGroupName, speed, alt), 10)
  return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tanker move command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafMove.moveTanker(eventPos, groupName, speed, alt, hdg, distance, teleport, silent)
  veaf.loggers.get(veafMove.Id):debug(
    string.format(
      "veafMove.moveTanker(groupName=%s, speed=%s, alt=%s, hdg=%s, distance=%s)",
      tostring(groupName),
      tostring(speed),
      tostring(alt),
      tostring(hdg),
      tostring(distance)
    )
  )
  veaf.loggers.get(veafMove.Id):cleanupMarkers(debugMarkers)

  veaf.loggers.get(veafMove.Id):trace(string.format("eventPos=%s", veaf.p(eventPos)))

  local FIRSTPOINT_DISTANCE_SECONDS = 60 -- seconds to fly to WP1

  local unitGroup = Group.getByName(groupName)
  if unitGroup == nil then
    veaf.loggers.get(veafMove.Id):info(groupName .. " not found for move tanker command")
    trigger.action.outText(veaf.t("move.tanker_not_found", groupName), 10)
    return false
  end

  local routeData, errMsg = veafMove._getTankerRouteData(groupName)
  if not routeData then
    veaf.loggers.get(veafMove.Id):info(errMsg)
    trigger.action.outText(errMsg or "", 10)
    return false
  end
  local tankerData, points = routeData.tankerData, routeData.points
  local point1, point2, point3 = routeData.point1, routeData.point2, routeData.point3
  veaf.loggers.get(veafMove.Id):trace("tankerData : %s", veaf.lp(tankerData))
  veaf.loggers.get(veafMove.Id):trace("found a " .. #points .. "-points route for tanker " .. groupName)
  veaf.loggers.get(veafMove.Id):trace(string.format("point1=%s", veaf.p(point1)))
  veaf.loggers.get(veafMove.Id):trace(string.format("point2=%s", veaf.p(point2)))
  veaf.loggers.get(veafMove.Id):trace(string.format("point3=%s", veaf.p(point3)))

  -- Moving a tanker is a geometric operation on its refuelling leg, whose far end is point3. Since
  -- #248 that waypoint may be absent — the orbit is the route's last point, or it is a Circle orbit,
  -- which turns around a single point and has no leg. Refusing beats inventing a leg the mission maker
  -- never drew: "moving a tanker to the wrong place is worse than telling the player it cannot be
  -- done". A player who wants it moved anyway says where, with `distance` and `hdg`.
  if not point3 and (distance == nil or hdg == nil) then
    veaf.loggers
      .get(veafMove.Id)
      :info("Cannot work out the refuelling leg of tanker " .. groupName .. " without a waypoint after its orbit")
    trigger.action.outText(veaf.t("move.tanker_move_no_leg", groupName), 10)
    return false
  end

  -- if distance is not set, compute distance between point2 and point3
  local distance = distance
  if distance == nil then
    distance = math.sqrt((point3.x - point2.x) ^ 2 + (point3.y - point2.y) ^ 2)
  else
    -- convert distance to meters
    distance = distance * 1852 -- meters
  end

  -- if hdg is not set, compute heading between point2 and point3
  local hdg = hdg
  if hdg == nil then
    hdg = veaf.headingBetweenPoints(point2, point3)
  else
    hdg = hdg * math.pi / 180
  end

  -- if speed is not set, use point2 speed
  local speed = speed
  if speed == nil or speed < 0 then
    speed = point2.speed
  else
    -- convert speed to m/s
    speed = speed / 1.94384
  end

  -- if alt is not set, use point2 altitude
  local alt = alt
  if alt == nil or alt < 0 then
    alt = point2.alt
  else
    -- convert altitude to meters
    alt = alt * 0.3048 -- meters
  end

  veaf.loggers.get(veafMove.Id):trace(string.format("distance=%s", veaf.p(distance)))
  veaf.loggers.get(veafMove.Id):trace(string.format("hdg=%s", veaf.p(hdg)))
  veaf.loggers.get(veafMove.Id):trace(string.format("speed=%s", veaf.p(speed)))
  veaf.loggers.get(veafMove.Id):trace(string.format("alt=%s", veaf.p(alt)))

  -- the first point in the refuel leg is based on the marker position
  local startLegPoint = { x = eventPos.x, y = eventPos.z, alt = alt, speed = speed }
  veaf.loggers.get(veafMove.Id):trace(string.format("startLegPoint=%s", veaf.p(startLegPoint)))
  if veafNamedPoints and not silent then
    veafNamedPoints.namePoint(
      { x = startLegPoint.x, y = startLegPoint.alt, z = startLegPoint.y },
      groupName .. " refuel start",
      unitGroup:getCoalition(),
      true
    )
  end

  -- compute the second point in the refuel leg based on desired heading and distance
  local endLegPoint = { x = startLegPoint.x, y = startLegPoint.y, alt = alt, speed = speed }
  veaf.loggers.get(veafMove.Id):trace(string.format("distance=%s", veaf.p(distance)))
  veaf.loggers.get(veafMove.Id):trace(string.format("hdg=%s", veaf.p(hdg)))
  endLegPoint.x = startLegPoint.x + distance * math.cos(hdg)
  endLegPoint.y = startLegPoint.y + distance * math.sin(hdg)
  veaf.loggers.get(veafMove.Id):trace(string.format("endLegPoint=%s", veaf.p(endLegPoint)))
  if veafNamedPoints and not silent then
    veafNamedPoints.namePoint(
      { x = endLegPoint.x, y = endLegPoint.alt, z = endLegPoint.y },
      groupName .. " refuel end",
      unitGroup:getCoalition(),
      true
    )
  end

  -- compute the point where the tanker should move in the opposite direction from the desired heading, at a standard distance
  local movePoint = { x = startLegPoint.x, y = startLegPoint.y, alt = alt, speed = speed }
  local teleportPoint = { x = startLegPoint.x, y = startLegPoint.y, alt = alt, speed = speed }
  local reverseHdg = hdg - math.pi
  if reverseHdg < 0 then
    reverseHdg = reverseHdg + math.pi * 2
  end
  veaf.loggers.get(veafMove.Id):trace(string.format("reverseHdg=%s", veaf.p(reverseHdg)))
  movePoint.x = startLegPoint.x + 1.5 * speed * FIRSTPOINT_DISTANCE_SECONDS * math.cos(reverseHdg)
  movePoint.y = startLegPoint.y + 1.5 * speed * FIRSTPOINT_DISTANCE_SECONDS * math.sin(reverseHdg)
  teleportPoint.x = startLegPoint.x + 3 * speed * FIRSTPOINT_DISTANCE_SECONDS * math.cos(reverseHdg)
  teleportPoint.y = startLegPoint.y + 3 * speed * FIRSTPOINT_DISTANCE_SECONDS * math.sin(reverseHdg)
  veaf.loggers.get(veafMove.Id):trace(string.format("movePoint=%s", veaf.p(movePoint)))

  -- set point1 to the computed movePoint
  -- Optional since #248: absent when the orbit is the route's first waypoint, in which case there is
  -- no approach point to bring in front of the leg.
  if point1 then
    point1.x = movePoint.x
    point1.y = movePoint.y
    point1.alt = movePoint.alt
    point1.speed = movePoint.speed
    veaf.loggers.get(veafMove.Id):trace(string.format("newPoint1=%s", veaf.p(point1)))
  else
    veaf.loggers.get(veafMove.Id):debug("tanker %s orbits on its first waypoint; no approach point to move", veaf.lp(groupName))
  end

  -- set point2 to the start of the tanking Orbit (startLegPoint)
  local orbitTask = routeData.orbitTask
  veaf.loggers.get(veafMove.Id):debug("Found a ORBIT task for tanker " .. groupName)
  orbitTask.params.speed = speed
  orbitTask.params.altitude = alt
  point2.x = startLegPoint.x
  point2.y = startLegPoint.y
  point2.alt = startLegPoint.alt
  point2.speed = startLegPoint.speed
  veaf.loggers.get(veafMove.Id):trace(string.format("newPoint2=%s", veaf.p(point2)))

  -- set point3 to the end of the tanking Orbit (endLegPoint). This is the far end of a Race-Track
  -- orbit by DCS's own semantics — it flies between the task's waypoint and the next one — which is
  -- why overwriting it is right, on a long route as much as on a VEAF template. Guaranteed present
  -- here: the leg check above refused earlier if it was missing and the player gave no distance/hdg.
  if point3 then
    point3.x = endLegPoint.x
    point3.y = endLegPoint.y
    point3.alt = endLegPoint.alt
    point3.speed = endLegPoint.speed
    veaf.loggers.get(veafMove.Id):trace("newpoint3=%s", veaf.lp(point3))
  end

  --actually move the group
  local delay = 0

  -- teleport if the option is set
  if teleport then
    veaf.loggers.get(veafMove.Id):debug("Teleport the tanker")
    local vars = { groupName = groupName, point = teleportPoint, action = "teleport" }
    local grp = mist.teleportToPoint(vars)
    unitGroup = Group.getByName(groupName)

    veafMove.teleportEscort(groupName, movePoint, teleportPoint)

    delay = 1
  end

  veaf.loggers.get(veafMove.Id):debug(string.format("Resetting moved tanker mission in %d seconds", delay))
  veafMove.replaceMission(unitGroup, tankerData, delay)

  return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Finds the Escort task of an escort group, in the group data DCS keeps for it.
--
-- The task lives on the **last** waypoint of the escort's route, which is where a mission maker sets
-- it up in the editor. Returns nil as soon as any link of that chain is missing -- no group data, no
-- route, no task table, no enabled Escort task -- because that is the ordinary case for a group that
-- simply has no escort, not an error to report.
--
-- @param groupName_escort, string, the name of the escort group itself (see EscortGroupNameSuffix)
-- @return escortData, table, the escort's group data (nil when there is no Escort task to be found)
-- @return task_escort, table, the Escort task inside it, ready to have its groupId reassigned
-- @return points_escort, table, the route points already walked to find it -- returned rather than
--         left to the caller to recompute, because two traversals of this structure would be two
--         things to keep in step, which is the whole reason this lookup was extracted
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafMove.findEscortTask(groupName_escort)
  local escortData = veaf.getGroupData(groupName_escort)
  if not escortData then
    veaf.loggers.get(veafMove.Id):debug("findEscortTask: no group data for %s", groupName_escort)
    return nil
  end

  local points_escort = veaf.findInTable(veaf.findInTable(escortData, "route"), "points")
  if not points_escort or #points_escort == 0 then
    veaf.loggers.get(veafMove.Id):debug("findEscortTask: %s has no route points", groupName_escort)
    return nil
  end

  -- Last waypoint: where the escort task has to be set up in the editor.
  local task2_escort = veaf.findInTable(points_escort[#points_escort], "task")
  if not (task2_escort and task2_escort.params and task2_escort.params.tasks) then
    veaf.loggers.get(veafMove.Id):debug("findEscortTask: last WP of %s carries no tasks", groupName_escort)
    return nil
  end

  for _, task in pairs(task2_escort.params.tasks) do
    -- The groupId stored in the mission has nothing to do with the id DCS needs at runtime, so it is
    -- not checked here -- only that this is an enabled Escort task. Group.getID() supplies the real
    -- one, and that is exactly what reestablishEscortTask writes back into it.
    if task.enabled and task.id and task.id == "Escort" and task.params then
      veaf.loggers
        .get(veafMove.Id)
        :trace("findEscortTask: found an Escort task on %s, stored groupId=%s", groupName_escort, task.params.groupId)
      return escortData, task, points_escort
    end
  end

  -- No log here: every caller reports this at info, where the context ("we were trying to repair
  -- this escort") makes it actionable for a mission maker. Two lines at two levels for one condition
  -- is noise in dcs.log.
  return nil
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Repairs the Escort task of a group's escort after the escorted group has been recreated.
--
-- DCS destroys the link the moment the escorted group is recreated -- respawned or teleported -- and
-- it does so silently: the escort keeps flying, runs out of route and goes home, which reads as an
-- escort that quit after ten minutes rather than as a broken task (#107, measured in game
-- 2026-08-18). The repair is to write the escorted group's **current** id into the task and push the
-- mission back to the controller.
--
-- Unlike teleportEscort, nothing is moved here: the escort is where it was, only the id it points at
-- has changed. That is why the respawn path needs this and nothing more.
--
-- The id is read inside the scheduled call rather than before it, because a respawn that has not
-- landed yet would still hand back the id that just died.
--
-- @param escorted_groupName, string, the group that was just recreated
-- @optional param delay, integer, seconds to wait for the respawn to land (default 1, as replaceMission)
-- @return boolean, true when a repair was scheduled; false when this group has no escort to repair
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafMove.reestablishEscortTask(escorted_groupName, delay)
  local groupName_escort = escorted_groupName .. veafMove.EscortGroupNameSuffix

  if not Group.getByName(groupName_escort) then
    veaf.loggers.get(veafMove.Id):trace("reestablishEscortTask: %s has no escort", escorted_groupName)
    return false
  end

  local escortData, task_escort = veafMove.findEscortTask(groupName_escort)
  if not task_escort then
    veaf.loggers.get(veafMove.Id):info(groupName_escort .. " exists but carries no Escort task ; nothing to repair")
    return false
  end

  veaf.scheduleFunction(
    veafMove.actualReestablishEscortTask,
    { escorted_groupName, groupName_escort, escortData, task_escort },
    timer.getTime() + (delay or 1)
  )
  return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- The scheduled half of reestablishEscortTask -- separate so the id is read after the respawn.
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafMove.actualReestablishEscortTask(escorted_groupName, groupName_escort, escortData, task_escort)
  local unitGroup = Group.getByName(escorted_groupName)
  if not unitGroup then
    veaf.loggers.get(veafMove.Id):info("Cannot repair the escort of " .. escorted_groupName .. " ; that group does not exist (any more)")
    return false
  end

  local unitGroup_escort = Group.getByName(groupName_escort)
  if not unitGroup_escort then
    veaf.loggers.get(veafMove.Id):info("Cannot repair " .. groupName_escort .. " ; that group does not exist (any more)")
    return false
  end

  -- This and only this is the id DCS wants; what the mission file stores does not correspond.
  task_escort.params.groupId = Group.getID(unitGroup)
  veaf.loggers
    .get(veafMove.Id)
    :debug("Re-establishing the escort task of %s onto group id %s", groupName_escort, task_escort.params.groupId)

  -- No further delay: the respawn has landed by the time this runs.
  veafMove.replaceMission(unitGroup_escort, escortData, 0)
  return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Escort move method, only called internally
-- @param escorted_groupName, string, corresponds to the groupname of the aicraft being escorted
-- @param movePoint, vec3 + speed, corresponds to the first waypoint that the escorted aircraft will take after it was moved
-- @param teleportPoint, vec3 + speed, corresponds to the waypoint on which the escorted aircraft is teleported to, this is required
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafMove.teleportEscort(escorted_groupName, movePoint, teleportPoint)
  --verify existence of the escorted aircraft
  local unitGroup = Group.getByName(escorted_groupName)

  if not unitGroup then
    veaf.loggers
      .get(veafMove.Id)
      :info("Cannot move the escort of " .. escorted_groupName .. " ; this groupName does not correspond to any aircraft")
    return false
  end

  --verify the existence of the escort and proper configuration
  local escortedId = Group.getID(unitGroup) --this and only this serves as a groupID, what is given in EscortData does not correspond on the DCS side
  local groupName_escort = escorted_groupName .. veafMove.EscortGroupNameSuffix --standardized escort groupName

  if not Group.getByName(groupName_escort) then
    veaf.loggers.get(veafMove.Id):info(groupName_escort .. " not found for move tanker escort command")
    return false
  end

  -- Same lookup the respawn path uses (reestablishEscortTask): one implementation of where an Escort
  -- task lives and what a valid one looks like.
  local EscortData, task_escort, points_escort = veafMove.findEscortTask(groupName_escort)
  if not task_escort then
    veaf.loggers.get(veafMove.Id):info(groupName_escort .. " carries no Escort task ; cannot move its escort")
    return false
  end

  if #points_escort < 2 then
    -- The teleport rewrites the last two waypoints; with a single one there is nothing to rewrite.
    -- findEscortTask accepts a one-point route on purpose: repairing the task needs no waypoints.
    veaf.loggers.get(veafMove.Id):info(groupName_escort .. " has fewer than two waypoints ; cannot move its escort")
    return false
  end
  local point1_escort = points_escort[#points_escort - 1] --second to last waypoint
  local point2_escort = points_escort[#points_escort] --last waypoint where the escort has to be set up in the editor
  veaf.loggers.get(veafMove.Id):trace("Required escort ID : %s", escortedId)

  --distances by which the escort is offseted from the escorted group in the map's referential, task_escort provides relative spacing
  local escort_offset = {}
  local hdg = veaf.headingBetweenPoints(teleportPoint, movePoint)
  escort_offset.x = (task_escort.params.pos.x * math.cos(hdg) - task_escort.params.pos.z * math.sin(hdg))
  escort_offset.z = (task_escort.params.pos.x * math.sin(hdg) + task_escort.params.pos.z * math.cos(hdg))

  local teleportPoint_escort = {}
  teleportPoint_escort.x = teleportPoint.x + escort_offset.x
  teleportPoint_escort.y = teleportPoint.y + escort_offset.z
  teleportPoint_escort.alt = teleportPoint.alt + task_escort.params.pos.y
  teleportPoint_escort.speed = teleportPoint.speed

  --Effectively waypoint 0, the AI will have to fly over it and in the editor it never poses a problem but in scripting the AI will do orbits to try and reach it
  --so it has to be offseted
  point1_escort.x = (teleportPoint.x + movePoint.x) / 2 + escort_offset.x
  point1_escort.y = (teleportPoint.y + movePoint.y) / 2 + escort_offset.z
  point1_escort.alt = movePoint.alt + task_escort.params.pos.y
  point1_escort.speed = movePoint.speed

  --Waypoint 1 where the escort tasking will come into play
  point2_escort.x = 2 * point1_escort.x - teleportPoint.x - escort_offset.x
  point2_escort.y = 2 * point1_escort.y - teleportPoint.y - escort_offset.z
  point2_escort.alt = movePoint.alt + task_escort.params.pos.y
  point2_escort.speed = movePoint.speed

  task_escort.params.groupId = escortedId --assign the new groupID within the old escort mission, only necessary after teleporting as the tanker's ID will have changed

  veaf.loggers.get(veafMove.Id):debug("Teleport the escort")
  local vars_escort = { groupName = groupName_escort, point = teleportPoint_escort, action = "teleport" }
  mist.teleportToPoint(vars_escort)
  local unitGroup_escort = Group.getByName(groupName_escort)

  veafMove.replaceMission(unitGroup_escort, EscortData)
  --this method appears to not work very well, the escort just doesn't defend the group

  --mist.goRoute(groupName_escort, route_escort)
  --works even worse, sends them to X=0, Z=0

  return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- support method to replace the mission of moved aircraft (default delay of 1s for teleported aircraft)
-- @param unitGroup, data returned by the Group.getByName(groupName) command
-- @param missionData, data returned by the veaf.getGroupData(groupName) command
-- @optional param delay, integer, delay to apply before replacing the mission, useful when teleporting, recommended 1s for such a scenario (which is the default value)
-- @optional param immortal, boolean, sets the group which is seeing it's mission replaced to immortal and invisible
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafMove.replaceMission(unitGroup, missionData, delay, immortal)
  local delay = delay or 1

  local actualReplaceMission = function(unitGroup, missionData, immortal)
    local freq = missionData.frequency or 243 --set frequency or guard channel
    local mod = missionData.modulation or 0 --set modulation or AM (=0)

    veaf.loggers.get(veafMove.Id):debug(string.format("Resetting %s mission", unitGroup:getName()))
    veaf.loggers.get(veafMove.Id):debug(string.format("replaceMissionData=%s", veaf.p(missionData)))
    --... for the escort, necessary to re assign the mission wether the tanker was teleported (== changed ID) or not because DCS

    local mission = {
      id = "Mission",
      params = missionData,
    }
    local controller = unitGroup:getController()
    controller:setTask(mission)

    if immortal then
      -- JTAC needs to be invisible and immortal
      veaf.loggers.get(veafMove.Id):trace("Group immortalized")
      local _setImmortal = {
        id = "SetImmortal",
        params = {
          value = true,
        },
      }
      -- invisible to AI, Shagrat
      local _setInvisible = {
        id = "SetInvisible",
        params = {
          value = true,
        },
      }

      Controller.setCommand(controller, _setImmortal)
      Controller.setCommand(controller, _setInvisible)
    end

    --have to set the frequency again as setTask seems to ignore missionData.frequency and switch the unit to 124AM
    local _setFrequency = {
      id = "SetFrequency",
      params = {
        frequency = freq * 1000000,
        modulation = mod,
      },
    }

    Controller.setCommand(controller, _setFrequency)
  end

  veaf.scheduleFunction(actualReplaceMission, { unitGroup, missionData, immortal }, timer.getTime() + delay)
end

------------------------------------------------------------------------------
-- veafMove.moveAfac
-- @param point eventPos
-- @param string groupName
-- @param float speed in knots
-- @param float alt in feet
-- @param float hdg in degrees
-- @param boolean immortal
------------------------------------------------------------------------------
function veafMove.moveAfac(eventPos, groupName, speed, alt, heading, immortal)
  if not speed then
    speed = 150
  end
  if not alt then
    alt = 20000
  end
  veaf.loggers.get(veafMove.Id):debug("veafMove.moveAfac(groupName = " .. groupName .. ", speed = " .. speed .. ", alt = " .. alt)
  veaf.loggers.get(veafMove.Id):debug(string.format("veafMove.moveAfac: eventPos  x=%.1f z=%.1f", eventPos.x, eventPos.z))

  local distanceFromTeleport = 3000 --distance between the orbit point and the teleport point in meters

  local unitGroup = Group.getByName(groupName)
  if unitGroup == nil then
    veaf.loggers.get(veafMove.Id):info(groupName .. " not found for move afac command")
    trigger.action.outText(veaf.t("move.afac_not_found", groupName), 10)
    return false
  end

  local coalition = unitGroup:getCoalition()

  local afacData = veaf.getGroupData(groupName)
  local isDynamicallySpawned = false
  if not afacData then
    for number, dynAFACcallsign in pairs(veafSpawn.AFAC.callsigns[coalition]) do
      if groupName:find(dynAFACcallsign.name) then
        veaf.loggers.get(veafMove.Id):trace("AFAC is dynamically spawned")
        afacData = veafSpawn.AFAC.missionData[coalition][number]
        isDynamicallySpawned = true
      end
    end
  end
  veaf.loggers.get(veafMove.Id):trace("Found AFAC named " .. groupName .. " for move command")
  veaf.loggers.get(veafMove.Id):debug(string.format("AFAC mission data is : %s", veaf.p(afacData)))

  local route_afac = veaf.findInTable(afacData, "route")
  local points_afac = veaf.findInTable(route_afac, "points")
  if points_afac then
    veaf.loggers.get(veafMove.Id):trace("Found AFAC waypoints")
    local idxPoint1_afac = #points_afac - 1 --second to last waypoint
    local idxPoint2_afac = #points_afac --last waypoint
    local point1_afac = points_afac[idxPoint1_afac]
    local point2_afac = points_afac[idxPoint2_afac]
    local FACflag = false
    local OrbitFlag = false

    -- if hdg is not set, compute heading between point1 and point2
    local hdg = heading
    if hdg == nil then
      hdg = veaf.headingBetweenPoints(point1_afac, point2_afac)
    else
      hdg = heading * math.pi / 180
    end

    -- teleport position
    local teleportPosition = {
      ["x"] = eventPos.x - distanceFromTeleport * math.cos(hdg), --teleport 3km south of orbit point
      ["y"] = eventPos.z - distanceFromTeleport * math.sin(hdg),
      ["alt"] = alt * 0.3048, -- in meters
    }

    -- orbit position
    local fromPosition = {
      ["x"] = eventPos.x,
      ["y"] = eventPos.z,
    }

    --check valid configuration of the AFAC
    if point1_afac and point2_afac then
      veaf.loggers.get(veafMove.Id):debug("AFAC has at least the two waypoints required")
      local tasks1_afac = point1_afac.task.params.tasks
      local tasks2_afac = point2_afac.task.params.tasks
      if tasks1_afac and tasks2_afac then
        for _, task in pairs(tasks1_afac) do
          if task.id == "FAC" then
            veaf.loggers.get(veafMove.Id):trace("FAC configuration valid on second to last WP")
            FACflag = true
          end
        end

        for _, task in pairs(tasks2_afac) do
          if task.id == "Orbit" then
            veaf.loggers.get(veafMove.Id):trace("AFAC Orbit configuration valid on last WP")
            OrbitFlag = true
          end
        end
      end
    end

    if FACflag == false or OrbitFlag == false then
      veaf.loggers.get(veafMove.Id):info(groupName .. " has an invalid FAC/Orbit configuration")
      trigger.action.outText(veaf.t("move.invalid_fac", groupName), 10)
      return false
    end

    --edit the last two waypoints of the AFAC's flight plan with the new requested position,speed and alt info
    point1_afac.speed = speed
    point1_afac.alt = teleportPosition.alt
    point1_afac.x = teleportPosition.x + distanceFromTeleport * math.cos(hdg) / 2
    point1_afac.y = teleportPosition.y + distanceFromTeleport * math.sin(hdg) / 2

    point2_afac.speed = speed
    point2_afac.alt = teleportPosition.alt
    point2_afac.x = eventPos.x
    point2_afac.y = eventPos.z

    --teleport the group south of the requested location
    veaf.loggers.get(veafMove.Id):trace("AFAC " .. groupName .. " teleported")
    local vars = { groupName = groupName, point = teleportPosition, action = "teleport" }
    if isDynamicallySpawned then
      vars = { groupName = groupName, groupData = afacData, anyTerrain = true, point = teleportPosition, action = "teleport" }
    end
    local grp = mist.teleportToPoint(vars)
    unitGroup = Group.getByName(groupName) --refresh group class after respawn, not necessary but safer considering at least the groupId changes

    --necessary delay for the following code to not be ignored
    local delay = 1

    -- replace whole mission
    veafMove.replaceMission(unitGroup, afacData, delay, immortal)

    return true
  else
    return false
  end
end

-- prepare tanker units
function veafMove.findAllTankers()
  local TankerTypeNames = { "KC130", "KC-135", "KC135MPRS", "KJ-2000", "IL-78M" }
  veaf.loggers.get(veafMove.Id):trace(string.format("findAllTankers()"))
  local result = {}
  local units = veaf.mist.getAllUnitData() -- local copy for faster execution
  for name, unit in pairs(units) do
    veaf.loggers.get(veafMove.Id):trace(string.format("name=%s, unit.type=%s", veaf.p(name), veaf.p(unit.type)))
    --veaf.loggers.get(veafMove.Id):trace(string.format("unit=%s", veaf.p(unit)))
    --local unit = Unit.getByName(name)
    if unit then
      for _, tankerTypeName in pairs(TankerTypeNames) do
        if tankerTypeName:lower() == unit.type:lower() then
          table.insert(result, unit.groupName)
        end
      end
    end
  end
  return result
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build a radio menu to move or teleport a tanker
function veafMove.moveTankerToMe(parameters)
  local subParameters, unitName = veaf.safeUnpack(parameters)
  local tankerName, direction = veaf.safeUnpack(subParameters)
  veaf.loggers
    .get(veafMove.Id)
    :debug(string.format("veafMove.moveTankerToMe(tankerName=%s, unitName=%s, direction=%d)", tankerName, unitName, direction))
  ---@diagnostic disable-next-line: param-type-mismatch
  local unit = Unit.getByName(unitName)
  if unit then
    local unitType = unit:getDesc()["typeName"]
    veaf.loggers.get(veafMove.Id):trace(string.format("checking unit %s of type %s", tostring(unitName), tostring(unitType)))
    local tankerMissionParameters = veafMove.tankerMissionParameters[unitType]
    if not tankerMissionParameters then
      tankerMissionParameters = { speed = -1, alt = -1 } -- -1 means to use the currently defined speed and altitude
    end
    veafMove.moveTanker(
      unit:getPosition().p,
      tankerName,
      tankerMissionParameters.speed,
      tankerMissionParameters.alt,
      direction,
      nil,
      true,
      false
    )
    veaf.outTextForUnit(unitName, veaf.t("move.tanker_moving", tankerName), 15)
  end
end

--- Build the initial radio menu
function veafMove.buildRadioMenu()
  veaf.loggers.get(veafMove.Id):debug(string.format("veafMove.buildRadioMenu()"))
  veafMove.rootPath = veafRadio.addSubMenu(veaf.t(veafMove.RadioMenuName))
  if not veafRadio.skipHelpMenus then
    veafRadio.addCommandToSubmenu(veaf.t("menu.common.help"), veafMove.rootPath, veafMove.help, nil, veafRadio.USAGE_ForGroup)
  end
  for _, tankerUnitName in pairs(veafMove.Tankers) do
    local tankerName = tankerUnitName
    if veafAssets then
      veaf.loggers.get(veafMove.Id):trace(string.format("searching for asset name %s", tankerUnitName))
      local asset = veafAssets.get(tankerUnitName)
      if asset then
        tankerName = asset.description
        veaf.loggers.get(veafMove.Id):trace(string.format("found asset name : %s", tankerName))
      end
    end
    -- Move tanker to me
    local menuName = string.format("%s - WEST", tankerName)
    local moveTankerPath = veafRadio.addSubMenu(menuName, veafMove.rootPath)
    veafRadio.addCommandToSubmenu(menuName, moveTankerPath, veafMove.moveTankerToMe, { tankerUnitName, 270 }, veafRadio.USAGE_ForGroup)

    menuName = string.format("%s - EAST", tankerName)
    moveTankerPath = veafRadio.addSubMenu(menuName, veafMove.rootPath)
    veafRadio.addCommandToSubmenu(menuName, moveTankerPath, veafMove.moveTankerToMe, { tankerUnitName, 90 }, veafRadio.USAGE_ForGroup)
  end
end

function veafMove.help(unitName)
  local text = veaf.t("move.help")
  veaf.outTextForGroup(unitName, text, 30)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafMove.initialize()
  if #veafMove.Tankers == 0 then
    -- find all existing Tankers
    veafMove.Tankers = veafMove.findAllTankers()
  end
  veafMove.buildRadioMenu()
  -- L1: moving a tanker or AFAC affects everyone flying, so it is a pilot action rather than
  -- an open one. Had no check at all before SECREV-2. Level chosen by David.
  veafCommands.registerCommandHandler(function(pos, event, bypass, fromMarker, groups, route)
    return veafMove.executeCommand(pos, event.text, bypass)
  end, veafCommands.PRIORITY_MOVE, "SENIOR_PILOT", veafMove.Keyphrase)
end

veaf.loggers.get(veafMove.Id):info(veaf.loggers.get(veafMove.Id):getVersionInfo())

veaf.registerModule(veafMove.Id, veafMove.initialize, { enable = true }, 60)
