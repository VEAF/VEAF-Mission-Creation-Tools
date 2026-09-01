------------------------------------------------------------------
-- VEAF carrier command and functions for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Radio menus allow starting and ending carrier operations. Carriers go back to their initial point when operations are ended
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafCarrierOperations = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafCarrierOperations.Id = "CARRIER"

-- trace level, specific to this module
--veafCarrierOperations.LogLevel = "trace"

veaf.loggers.new(veafCarrierOperations.Id, veafCarrierOperations.LogLevel)

veafCarrierOperations.RadioMenuName = "menu.carrier.root"
veafCarrierOperations.RadioMenuNameBlue = "menu.carrier.root_blue"
veafCarrierOperations.RadioMenuNameRed = "menu.carrier.root_red"
veafCarrierOperations.DisableSecurity = false

veafCarrierOperations.AllCarriers = {
  ["LHA_Tarawa"] = { runwayAngleWithBRC = -1, desiredWindSpeedOnDeck = 20 },
  ["Stennis"] = { runwayAngleWithBRC = 9.05, desiredWindSpeedOnDeck = 25 },
  ["CVN_71"] = { runwayAngleWithBRC = 9.05, desiredWindSpeedOnDeck = 25 },
  ["CVN_72"] = { runwayAngleWithBRC = 9.05, desiredWindSpeedOnDeck = 25 },
  ["CVN_73"] = { runwayAngleWithBRC = 9.05, desiredWindSpeedOnDeck = 25 },
  ["CVN_75"] = { runwayAngleWithBRC = 9.05, desiredWindSpeedOnDeck = 25 },
  ["Forrestal"] = { runwayAngleWithBRC = 9.05, desiredWindSpeedOnDeck = 25 },
  ["KUZNECOW"] = { runwayAngleWithBRC = 9, desiredWindSpeedOnDeck = 25 },
  ["CV_1143_5"] = { runwayAngleWithBRC = 9, desiredWindSpeedOnDeck = 25 },
}

veafCarrierOperations.ALT_FOR_MEASURING_WIND = 30 -- wind is measured at 30 meters, 10 meters above deck
veafCarrierOperations.ALIGNMENT_MANOEUVER_SPEED = 20 * 0.51445 -- carrier speed when not yet aligned to the wind (in m/s)
veafCarrierOperations.MAX_OPERATIONS_DURATION = 45 -- operations are stopped after (minutes)
veafCarrierOperations.SCHEDULER_INTERVAL = 1 -- scheduler runs every minute
veafCarrierOperations.MIN_WINDSPEED_FOR_CHANGING_HEADING = 4 * 0.51445 -- don't deroute the carrier if the wind speed is lower than this (m/s)
veafCarrierOperations.MIN_CARRIER_SPEED = 4 * 0.51445 -- don't make the carrier steam at less than this speed (m/s)

veafCarrierOperations.RemoteCommandParser = "([[a-zA-Z0-9]+)%s?([^%s]*)%s?(.*)"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Radio menus paths
veafCarrierOperations.rootPath = nil
veafCarrierOperations.rootPathBlue = nil
veafCarrierOperations.rootPathRed = nil

--- Carrier groups data, for Carrier Operations commands
veafCarrierOperations.carriers = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------
veafCarrierOperations.debugMarkersErasedAtEachStep = {}
veafCarrierOperations.traceMarkerId = 2727

function veafCarrierOperations.getDebugMarkersErasedAtEachStep(name)
  if not name then
    return nil
  end
  if not veafCarrierOperations.debugMarkersErasedAtEachStep then
    veafCarrierOperations.debugMarkersErasedAtEachStep = {}
  end
  if not veafCarrierOperations.debugMarkersErasedAtEachStep[name] then
    veafCarrierOperations.debugMarkersErasedAtEachStep[name] = {}
  end
  return veafCarrierOperations.debugMarkersErasedAtEachStep[name]
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Carrier operations commands
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Start carrier operations ; changes the radio menu item to END and make the carrier move
function veafCarrierOperations.startCarrierOperations(parameters)
  veaf.loggers.get(veafCarrierOperations.Id):debug("startCarrierOperations()")
  veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("Parameters for this command are : %s", veaf.p(parameters)))
  local carrierInfo, userUnitName = veaf.safeUnpack(parameters)
  local groupName, duration = veaf.safeUnpack(carrierInfo)
  veaf.loggers.get(veafCarrierOperations.Id):debug(string.format("Carrier groupName : %s", veaf.p(groupName)))
  veaf.loggers.get(veafCarrierOperations.Id):debug(string.format("duration : %s", veaf.p(duration)))
  veaf.loggers.get(veafCarrierOperations.Id):debug(string.format("userUnitName : %s", veaf.p(userUnitName)))

  local carrier = veafCarrierOperations.carriers[groupName]

  if not carrier then
    local text = "Cannot find the carrier group " .. groupName
    veaf.loggers.get(veafCarrierOperations.Id):error(text)
    veaf.outTextForGroup(userUnitName, veaf.t("carrier.not_found", groupName), 5)
    return
  end

  -- find the actual carrier unit
  -- The `if not carrier then` above vouches for VEAF's own record of the carrier, built when the
  -- module initialized; it says nothing about the DCS group still being there when a pilot asks for
  -- air operations, which can be a very long time later. An empty lookup used to take the command
  -- down on `group:getUnits()`.
  local group = Group.getByName(groupName)
  if not group then
    veaf.loggers
      .get(veafCarrierOperations.Id)
      :warn(string.format("startCarrierOperations: DCS no longer knows the carrier group [%s]", veaf.p(groupName)))
    veaf.outTextForGroup(userUnitName, veaf.t("carrier.not_found", groupName), 5)
    return
  end
  for _, unit in pairs(group:getUnits()) do
    local unitType = unit:getDesc()["typeName"]
    for knownCarrierType, data in pairs(veafCarrierOperations.AllCarriers) do
      if unitType == knownCarrierType then
        carrier.carrierUnitName = unit:getName()
        carrier.pedroUnitName = carrier.carrierUnitName .. " Pedro" -- rescue helo unit name
        carrier.tankerUnitName = carrier.carrierUnitName .. " S3B-Tanker" -- emergency tanker unit name
        carrier.tankerRouteSet = 0
        carrier.runwayAngleWithBRC = data.runwayAngleWithBRC
        carrier.desiredWindSpeedOnDeck = data.desiredWindSpeedOnDeck
        carrier.initialPosition = unit:getPosition().p
        veaf.loggers.get(veafCarrierOperations.Id):trace("initialPosition=" .. veaf.vecToString(carrier.initialPosition))
        break
      end
    end
  end

  carrier.conductingAirOperations = true
  carrier.airOperationsStartedAt = timer.getTime()
  carrier.airOperationsEndAt = carrier.airOperationsStartedAt + duration * 60

  veafCarrierOperations.continueCarrierOperations(groupName) -- will update the *carrier* structure

  local text = veafCarrierOperations.getAtcForCarrierOperations(groupName) .. veaf.t("carrier.alignment_delay")

  veaf.loggers.get(veafCarrierOperations.Id):info(text)
  veaf.outTextForGroup(userUnitName, text, 25)

  -- change the menu
  veaf.loggers.get(veafCarrierOperations.Id):trace("change the menu")
  veafCarrierOperations.rebuildRadioMenu()
end

--- Continue carrier operations ; make the carrier move according to the wind. Called by startCarrierOperations and by the scheduler.
function veafCarrierOperations.continueCarrierOperations(groupName, userUnitName)
  veaf.loggers.get(veafCarrierOperations.Id):debug("continueCarrierOperations(" .. groupName .. ")")

  local carrier = veafCarrierOperations.carriers[groupName]

  if not carrier then
    local text = "Cannot find the carrier group " .. groupName
    veaf.loggers.get(veafCarrierOperations.Id):error(text)
    veaf.outTextForGroup(userUnitName, veaf.t("carrier.not_found", groupName), 5)
    return
  end

  -- find the actual carrier unit
  local carrierUnit = Unit.getByName(carrier.carrierUnitName)

  -- take note of the starting position
  local startPosition = veaf.getAvgGroupPos(groupName)
  local currentHeading = 0
  if carrierUnit then
    startPosition = carrierUnit:getPosition().p
    veaf.loggers.get(veafCarrierOperations.Id):trace("startPosition (raw) =" .. veaf.vecToString(startPosition))
    currentHeading = veaf.round(math.deg(veaf.getHeading(carrierUnit, true)), 0)
  end
  veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("currentHeading=%s", veaf.p(currentHeading)))
  startPosition = { x = startPosition.x, z = startPosition.z, y = startPosition.y + veafCarrierOperations.ALT_FOR_MEASURING_WIND } -- on deck, 50 meters above the water
  veaf.loggers.get(veafCarrierOperations.Id):trace("startPosition=" .. veaf.vecToString(startPosition))
  veaf.loggers.get(veafCarrierOperations.Id):cleanupMarkers(veafCarrierOperations.getDebugMarkersErasedAtEachStep(carrier.carrierUnitName))
  --veafCarrierOperations.traceMarkerId = veaf.loggers.get(veafCarrierOperations.Id):marker(veafCarrierOperations.traceMarkerId, "CARRIER", "startPosition", startPosition, veafCarrierOperations.getDebugMarkersErasedAtEachStep(carrier.carrierUnitName))
  local carrierDistanceFromInitialPosition = (
    (startPosition.x - carrier.initialPosition.x) ^ 2 + (startPosition.z - carrier.initialPosition.z) ^ 2
  ) ^ 0.5
  veaf.loggers.get(veafCarrierOperations.Id):trace("carrierDistanceFromInitialPosition=" .. carrierDistanceFromInitialPosition)

  -- compute magnetic deviation at carrier position
  -- the north correction (grid-to-true) is not magnetic deviation, so it is deliberately not used here
  -- TODO find how to actually compute it
  --[[
    local magdev = veaf.round(veaf.getNorthCorrection(startPosition) * 180 / math.pi,1)
    veaf.loggers.get(veafCarrierOperations.Id):trace("magdev = " .. magdev)
    ]]

  -- make the carrier move
  if startPosition ~= nil then
    local dir = currentHeading -- start with current heading

    --get wind info
    local wind = atmosphere.getWind(startPosition)
    veaf.loggers.get(veafCarrierOperations.Id):trace("wind=%s", veaf.lp(wind))
    local windspeed = veaf.vecMag(wind)
    veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("windspeed=%s", veaf.p(windspeed)))

    if windspeed >= veafCarrierOperations.MIN_WINDSPEED_FOR_CHANGING_HEADING then
      --get wind direction sorted
      if wind.x ~= 0 then
        dir = veaf.round(math.atan2(wind.z, wind.x) * 180 / math.pi, 0)
      elseif wind.z < 0 then
        dir = 270
      elseif wind.z > 0 then
        dir = 90
      elseif wind.z == 0 then
        dir = carrier.heading
      end

      if dir < 0 then
        dir = dir + 360 --converts to positive numbers
      end

      if dir <= 180 then
        dir = dir + 180
      else
        dir = dir - 180
      end
      veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("wind direction=%s", veaf.p(dir)))
      dir = veaf.round(dir + carrier.runwayAngleWithBRC) --to account for angle of landing deck and movement of the ship
    end

    if dir > 360 then
      dir = dir - 360
    end

    veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("dir=%s", veaf.p(dir)))

    local speed = 1
    local desiredWindSpeedOnDeck = carrier.desiredWindSpeedOnDeck * 0.51445
    if desiredWindSpeedOnDeck < 1 then
      desiredWindSpeedOnDeck = 1
    end -- minimum 1 m/s
    if windspeed < desiredWindSpeedOnDeck then
      speed = desiredWindSpeedOnDeck - windspeed
    end
    if speed < veafCarrierOperations.MIN_CARRIER_SPEED then
      speed = veafCarrierOperations.MIN_CARRIER_SPEED
    end
    veaf.loggers.get(veafCarrierOperations.Id):trace("BRC speed=" .. speed .. " m/s")

    -- compute a new waypoint
    local headingRad = math.rad(dir)
    local length = 4000
    local newWaypoint = {
      x = startPosition.x + length * math.cos(headingRad),
      z = startPosition.z + length * math.sin(headingRad),
      y = startPosition.y,
    }

    -- check for obstructions
    local carrierGroup = Group.getByName(groupName)
    local unitsToCheck = {}
    if carrierGroup then
      for _, unitToCheck in pairs(carrierGroup:getUnits()) do
        veaf.loggers
          .get(veafCarrierOperations.Id)
          :trace("checking %s %s", veaf.lp(unitToCheck:getTypeName()), veaf.lp(unitToCheck:getName()))
        if not carrierUnit or unitToCheck:getID() ~= carrierUnit:getID() then
          table.insert(unitsToCheck, unitToCheck)
        end
      end
    end
    veaf.loggers.get(veafCarrierOperations.Id):trace("unitsToCheck=%s", veaf.lp(unitsToCheck))
    local pointA = veaf.computeCoordinatesOffsetFromRoute(startPosition, newWaypoint, 500, 500)
    local pointB = veaf.computeCoordinatesOffsetFromRoute(startPosition, newWaypoint, 500, -500)
    local pointC = veaf.computeCoordinatesOffsetFromRoute(startPosition, newWaypoint, 2000, -500)
    local pointD = veaf.computeCoordinatesOffsetFromRoute(startPosition, newWaypoint, 2000, 500)
    local polygon = { pointA, pointB, pointC, pointD }
    veaf.loggers.get(veafCarrierOperations.Id):trace("polygon=%s", veaf.lp(polygon))
    veafCarrierOperations.traceMarkerId = veaf.loggers.get(veafCarrierOperations.Id):markerQuad(
      veafCarrierOperations.traceMarkerId,
      "CARRIER",
      "obstructionsCheck",
      { pointA, pointB, pointC, pointD },
      veafCarrierOperations.getDebugMarkersErasedAtEachStep(carrier.carrierUnitName),
      VeafDrawingOnMap.LINE_TYPE["dashed"],
      { 1, 0, 0, 0.5 }
    )

    local obstructions = {}
    for i = 1, #unitsToCheck do
      local lUnit = unitsToCheck[i]
      veaf.loggers.get(veafCarrierOperations.Id):trace("lUnit:getName()=%s", veaf.lp(lUnit:getName()))
      if veaf.pointInPolygon(lUnit:getPosition().p, polygon) then
        obstructions[#obstructions + 1] = lUnit
      end
    end

    veaf.loggers.get(veafCarrierOperations.Id):trace("obstructions=%s", veaf.lp(obstructions))
    if #obstructions > 0 then
      -- obstructions found, derouting
      local newDir = dir + 90
      if newDir > 360 then
        newDir = newDir - 360
      end

      local msg = string.format(
        "Obstruction found at heading %s, derouting %s to heading %s",
        veaf.p(#obstructions),
        veaf.p(dir),
        veaf.p(groupName),
        veaf.p(newDir)
      )
      veaf.loggers.get(veafCarrierOperations.Id):debug(msg)
      veaf.outTextForGroup(
        userUnitName,
        veaf.t("carrier.obstruction", veaf.p(#obstructions), veaf.p(dir), veaf.p(groupName), veaf.p(newDir)),
        5
      )
      headingRad = math.rad(newDir)
      length = 4000
      newWaypoint = {
        x = startPosition.x + length * math.cos(headingRad),
        z = startPosition.z + length * math.sin(headingRad),
        y = startPosition.y,
      }
    end

    veaf.loggers.get(veafCarrierOperations.Id):trace("headingRad=" .. headingRad)
    veaf.loggers.get(veafCarrierOperations.Id):trace("length=" .. length)
    veaf.loggers.get(veafCarrierOperations.Id):trace("newWaypoint=" .. veaf.vecToString(newWaypoint))
    veafCarrierOperations.traceMarkerId = veaf.loggers.get(veafCarrierOperations.Id):markerArrow(
      veafCarrierOperations.traceMarkerId,
      "CARRIER",
      "route",
      startPosition,
      newWaypoint,
      veafCarrierOperations.getDebugMarkersErasedAtEachStep(carrier.carrierUnitName),
      VeafDrawingOnMap.LINE_TYPE["dashed"],
      { 0, 0, 1, 0.3 }
    )

    local actualSpeed = speed
    if math.abs(dir - currentHeading) > 15 then -- still aligning
      actualSpeed = veafCarrierOperations.ALIGNMENT_MANOEUVER_SPEED
    end
    veaf.moveGroupTo(groupName, newWaypoint, actualSpeed, 0)
    carrier.heading = dir
    veaf.loggers.get(veafCarrierOperations.Id):trace("carrier.heading = " .. carrier.heading .. " (true)")
    --carrier.heading_mag = dir + magdev
    --veaf.loggers.get(veafCarrierOperations.Id):trace("carrier.heading = " .. carrier.heading_mag .. " (mag)")
    carrier.speed = veaf.round(speed * 1.94384, 0)
    veaf.loggers.get(veafCarrierOperations.Id):trace("carrier.speed = " .. carrier.speed .. " kn")

    -- check if a Pedro group exists for this carrier
    if not veaf.mist.getGroupData(carrier.pedroUnitName) then
      veaf.loggers.get(veafCarrierOperations.Id):warn("No Pedro group named " .. carrier.pedroUnitName)
    else
      -- prepare or correct the Pedro route (SH-60B, 250ft high, 1nm to the starboard side of the carrier, riding along at the same speed and heading)
      ---@type Unit|nil
      local pedroUnit = Unit.getByName(carrier.pedroUnitName)
      if pedroUnit then
        veaf.loggers.get(veafCarrierOperations.Id):debug("found Pedro unit")
        -- check if unit is still alive
        if pedroUnit:getLife() < 1 then
          pedroUnit = nil -- respawn when damaged
        end
      end

      -- spawn if needed
      if not (pedroUnit and carrier.pedroIsSpawned) then
        veaf.loggers.get(veafCarrierOperations.Id):debug("respawning Pedro unit")
        VeafGroupSpawn:new()
          :forGroup(carrier.pedroUnitName)
          :at({ x = startPosition.x, y = 100, z = startPosition.z })
          :withRadius(500)
          :respawn()
        carrier.pedroIsSpawned = true
      end

      local pedroGroup = Group.getByName(carrier.pedroUnitName) -- group has the same name as the unit
      if pedroGroup then
        veaf.loggers.get(veafCarrierOperations.Id):debug("found Pedro group")

        pedroUnit = Unit.getByName(carrier.pedroUnitName)
        if not pedroUnit then
          pedroUnit = pedroGroup:getUnit(1)
        end
        veaf.loggers.get(veafCarrierOperations.Id):debug(string.format("pedroUnit=%s", veaf.p(pedroUnit)))

        -- waypoint #1 is 500m to port
        local offsetPointOnLand, offsetPoint = veaf.computeCoordinatesOffsetFromRoute(startPosition, newWaypoint, 0, 500)
        local pedroWaypoint1 = offsetPoint
        local distanceFromWP1 = (
          (pedroUnit:getPosition().p.x - pedroWaypoint1.x) ^ 2 + (pedroUnit:getPosition().p.z - pedroWaypoint1.z) ^ 2
        ) ^ 0.5
        if distanceFromWP1 > 500 then
          veaf.loggers.get(veafCarrierOperations.Id):trace("Pedro WP1 = " .. veaf.vecToString(pedroWaypoint1))
          veafCarrierOperations.traceMarkerId = veaf.loggers.get(veafCarrierOperations.Id):marker(
            veafCarrierOperations.traceMarkerId,
            "CARRIER",
            "pedroWaypoint1",
            pedroWaypoint1,
            veafCarrierOperations.getDebugMarkersErasedAtEachStep(carrier.carrierUnitName)
          )
        else
          pedroWaypoint1 = nil
        end

        -- waypoint #2 is 500m to port, near the end of the carrier route
        local offsetPointOnLand, offsetPoint = veaf.computeCoordinatesOffsetFromRoute(startPosition, newWaypoint, length - 250, 500)
        local pedroWaypoint2 = offsetPoint
        veaf.loggers.get(veafCarrierOperations.Id):trace("Pedro WP2 = " .. veaf.vecToString(pedroWaypoint2))
        veafCarrierOperations.traceMarkerId = veaf.loggers.get(veafCarrierOperations.Id):marker(
          veafCarrierOperations.traceMarkerId,
          "CARRIER",
          "pedroWaypoint2",
          pedroWaypoint2,
          veafCarrierOperations.getDebugMarkersErasedAtEachStep(carrier.carrierUnitName)
        )

        local mission = {
          id = "Mission",
          params = {
            ["communication"] = false,
            ["start_time"] = 0,
            ["task"] = "Transport",
            route = {
              points = {},
            },
          },
        }

        if pedroWaypoint1 then
          mission.params.route.points = {
            [1] = {
              ["alt"] = 35,
              ["action"] = "Turning Point",
              ["alt_type"] = "BARO",
              ["speed"] = 50,
              ["type"] = "Turning Point",
              ["x"] = pedroUnit:getPosition().p.x,
              ["y"] = pedroUnit:getPosition().p.z,
              ["speed_locked"] = true,
            },
            [2] = {
              ["type"] = "Turning Point",
              ["action"] = "Turning Point",
              ["x"] = pedroWaypoint1.x,
              ["y"] = pedroWaypoint1.z,
              ["alt"] = 35, -- in meters
              ["alt_type"] = "BARO",
              ["speed"] = 50,
              ["speed_locked"] = true,
            },
            [3] = {
              ["type"] = "Turning Point",
              ["action"] = "Turning Point",
              ["x"] = pedroWaypoint2.x,
              ["y"] = pedroWaypoint2.z,
              ["alt"] = 35, -- in meters
              ["alt_type"] = "BARO",
              ["speed"] = speed, -- speed in m/s
              ["speed_locked"] = true,
            },
          }
        else
          mission.params.route.points = {
            [1] = {
              ["alt"] = 35,
              ["action"] = "Turning Point",
              ["alt_type"] = "BARO",
              ["speed"] = 50,
              ["type"] = "Turning Point",
              ["x"] = pedroUnit:getPosition().p.x,
              ["y"] = pedroUnit:getPosition().p.z,
              ["speed_locked"] = true,
            },
            [2] = {
              ["type"] = "Turning Point",
              ["action"] = "Turning Point",
              ["x"] = pedroWaypoint2.x,
              ["y"] = pedroWaypoint2.z,
              ["alt"] = 35, -- in meters
              ["alt_type"] = "BARO",
              ["speed"] = speed, -- speed in m/s
              ["speed_locked"] = true,
            },
          }
        end

        -- replace whole mission
        veaf.loggers.get(veafCarrierOperations.Id):debug("Setting Pedro mission")
        local controller = pedroGroup:getController()
        controller:setTask(mission)
      end
    end

    -- check if a S3B-Tanker group exists for this carrier
    if not veaf.mist.getGroupData(carrier.tankerUnitName) then
      veaf.loggers.get(veafCarrierOperations.Id):warn("No Tanker group named " .. carrier.tankerUnitName)
    else
      local routeTanker = (carrierDistanceFromInitialPosition > 18520)
      carrier.tankerRouteSet = carrier.tankerRouteSet + 1
      if carrier.tankerRouteSet <= 2 then
        -- prepare or correct the Tanker route (8000ft high, 10nm aft and 4nm to the starboard side of the carrier, refueling on BRC)
        ---@type Unit|nil
        local tankerUnit = Unit.getByName(carrier.tankerUnitName)
        if tankerUnit then
          veaf.loggers.get(veafCarrierOperations.Id):debug("found Tanker unit")
          -- check if unit is still alive
          if tankerUnit:getLife() < 1 then
            tankerUnit = nil -- respawn when damaged
          end
        end

        -- spawn if needed
        if not (tankerUnit and carrier.tankerIsSpawned) then
          veaf.loggers.get(veafCarrierOperations.Id):debug("respawning Tanker unit")
          VeafGroupSpawn:new()
            :forGroup(carrier.tankerUnitName)
            :at({ x = startPosition.x, y = 2500, z = startPosition.z })
            :withRadius(500)
            :respawn()
          carrier.tankerIsSpawned = true
        end

        tankerUnit = Unit.getByName(carrier.tankerUnitName)
        local tankerGroup = Group.getByName(carrier.tankerUnitName) -- group has the same name as the unit
        -- VMR-018: `carrier.tankerData` is dereferenced twice inside this block — for the TACAN
        -- task and for the radio frequency — and a guard further down (`if carrier.tankerData then`
        -- before the report) proves the code already knows it can be absent. Added to the entry
        -- condition rather than as two inner guards: with no tanker data there is nothing this
        -- block can usefully set up, so skipping it whole is both simpler and the intent.
        if tankerGroup and carrier.tankerData then
          veaf.loggers.get(veafCarrierOperations.Id):debug("found Tanker group")
          veaf.loggers.get(veafCarrierOperations.Id):trace("groupName=" .. tankerGroup:getName())

          -- waypoint #1 is 5nm to port, 5nm to the front
          local offsetPointOnLand, offsetPoint = veaf.computeCoordinatesOffsetFromRoute(startPosition, newWaypoint, 9000, 9000)
          local tankerWaypoint1 = offsetPoint
          veaf.loggers.get(veafCarrierOperations.Id):trace("Tanker WP1 = " .. veaf.vecToString(tankerWaypoint1))
          veafCarrierOperations.traceMarkerId = veaf.loggers.get(veafCarrierOperations.Id):marker(
            veafCarrierOperations.traceMarkerId,
            "CARRIER",
            "tankerWaypoint1",
            tankerWaypoint1,
            veafCarrierOperations.getDebugMarkersErasedAtEachStep(carrier.carrierUnitName)
          )

          -- waypoint #2 is 20nm ahead of waypoint #2, on BRC
          local offsetPointOnLand, offsetPoint = veaf.computeCoordinatesOffsetFromRoute(startPosition, newWaypoint, 37000 + 9000, 9000)
          local tankerWaypoint2 = offsetPoint
          veaf.loggers.get(veafCarrierOperations.Id):trace("Tanker WP2 = " .. veaf.vecToString(tankerWaypoint2))
          veafCarrierOperations.traceMarkerId = veaf.loggers.get(veafCarrierOperations.Id):marker(
            veafCarrierOperations.traceMarkerId,
            "CARRIER",
            "tankerWaypoint2",
            tankerWaypoint2,
            veafCarrierOperations.getDebugMarkersErasedAtEachStep(carrier.carrierUnitName)
          )

          local mission = {
            id = "Mission",
            params = {
              ["communication"] = true,
              ["start_time"] = 0,
              ["task"] = "Refueling",
              ["taskSelected"] = true,
              ["route"] = {
                ["points"] = {
                  [1] = {
                    ["alt"] = 2500,
                    ["action"] = "Turning Point",
                    ["alt_type"] = "BARO",
                    ["speed"] = 165,
                    ["type"] = "Turning Point",
                    ["x"] = startPosition.x,
                    ["y"] = startPosition.z,
                    ["speed_locked"] = true,
                  },
                  [2] = {
                    ["alt"] = 2500,
                    ["action"] = "Turning Point",
                    ["alt_type"] = "BARO",
                    ["speed"] = 165,
                    ["task"] = {
                      ["id"] = "ComboTask",
                      ["params"] = {
                        ["tasks"] = {
                          [1] = {
                            ["enabled"] = true,
                            ["auto"] = true,
                            ["id"] = "Tanker",
                            ["number"] = 1,
                          }, -- end of [1]
                          [2] = carrier.tankerData.tankerTacanTask,
                        }, -- end of ["tasks"]
                      }, -- end of ["params"]
                    }, -- end of ["task"]
                    ["type"] = "Turning Point",
                    ["ETA"] = 0,
                    ["ETA_locked"] = false,
                    ["x"] = startPosition.x,
                    ["y"] = startPosition.z,
                    ["speed_locked"] = true,
                  },
                  [3] = {
                    ["alt"] = 2500,
                    ["action"] = "Turning Point",
                    ["alt_type"] = "BARO",
                    ["speed"] = 165,
                    ["task"] = {
                      ["id"] = "ComboTask",
                      ["params"] = {
                        ["tasks"] = {
                          [1] = {
                            ["enabled"] = true,
                            ["auto"] = false,
                            ["id"] = "Orbit",
                            ["number"] = 1,
                            ["params"] = {
                              ["altitude"] = 2500,
                              ["pattern"] = "Race-Track",
                              ["speed"] = 165,
                            }, -- end of ["params"]
                          }, -- end of [1]
                        }, -- end of ["tasks"]
                      }, -- end of ["params"]
                    }, -- end of ["task"]
                    ["type"] = "Turning Point",
                    ["x"] = tankerWaypoint1.x,
                    ["y"] = tankerWaypoint1.z,
                    ["speed_locked"] = true,
                  },
                  [4] = {
                    ["alt"] = 2500,
                    ["action"] = "Turning Point",
                    ["alt_type"] = "BARO",
                    ["speed"] = 165,
                    ["type"] = "Turning Point",
                    ["x"] = tankerWaypoint2.x,
                    ["y"] = tankerWaypoint2.z,
                    ["speed_locked"] = true,
                  }, -- end of [3]
                }, -- end of ["points"]
              }, -- end of ["route"]
            },
          }

          -- replace whole mission
          veaf.loggers.get(veafCarrierOperations.Id):debug("Setting Tanker mission")
          local controller = tankerGroup:getController()
          controller:setTask(mission)
          carrier.tankerRouteIsSet = true

          local _setFrequency = {
            id = "SetFrequency",
            params = {
              frequency = carrier.tankerData.tankerFrequency * 1000000, --Hz
              modulation = 0, --AM
            },
          }
          Controller.setCommand(controller, _setFrequency)
        end
      end
    end
  end
end

--- Gets informations about current carrier operations
function veafCarrierOperations.getAtcForCarrierOperations(groupName, skipNavigationData)
  veaf.loggers.get(veafCarrierOperations.Id):debug("getAtcForCarrierOperations(" .. groupName .. ")")

  local carrier = veafCarrierOperations.carriers[groupName]
  if not carrier then
    veaf.loggers.get(veafCarrierOperations.Id):error("Cannot find the carrier group " .. tostring(groupName))
    return nil
  end
  local carrierUnit = Unit.getByName(carrier.carrierUnitName)
  local currentHeading = -1
  local currentSpeed = -1
  local startPosition = nil
  if carrierUnit then
    currentHeading = veaf.round(math.deg(veaf.getHeading(carrierUnit, true)), 0)
    currentSpeed = veaf.round(veaf.mpsToKnots(veaf.vecMag(carrierUnit:getVelocity())), 0)
    startPosition =
      { x = carrierUnit:getPosition().p.x, z = carrierUnit:getPosition().p.z, y = veafCarrierOperations.ALT_FOR_MEASURING_WIND } -- on deck, 50 meters above the water
  end

  if not carrier then
    local text = "Cannot find the carrier group " .. groupName
    veaf.loggers.get(veafCarrierOperations.Id):error(text)
    trigger.action.outText(veaf.t("carrier.not_found", groupName), 5)
    return
  end

  local result = ""
  local groupPosition = veaf.getAvgGroupPos(groupName)

  if carrier.conductingAirOperations then
    local remainingTime = veaf.round((carrier.airOperationsEndAt - timer.getTime()) / 60, 1)
    result = veaf.t("carrier.atc_conducting", groupName)
    if carrier.ATC.tower then
      result = result .. "  - ATC : " .. carrier.ATC.tower .. "\n"
    end
    if carrier.ATC.tacan then
      result = result .. "  - TACAN : " .. carrier.ATC.tacan .. "\n"
    end
    if carrier.ATC.icls then
      result = result .. "  - ICLS : " .. carrier.ATC.icls .. "\n"
    end
    if carrier.ATC.link4 then
      result = result .. "  - LINK 4 : " .. carrier.ATC.link4 .. ", "
      if carrier.ATC.acls then
        result = result .. veaf.t("carrier.atc_acls_available")
      end
      result = result .. "\n"
    end
    --"  - BRC : " .. carrier.heading_mag .. " (".. carrier.heading .. " true) at " .. carrier.speed .. " kn\n" ..
    result = result .. veaf.t("carrier.atc_brc", carrier.heading, carrier.speed, remainingTime)
    if carrier.tankerData then
      result = result
        .. veaf.t(
          "carrier.atc_tanker",
          carrier.tankerData.tankerCallsign,
          carrier.tankerData.tankerTacanChannel,
          carrier.tankerData.tankerTacanMode,
          carrier.tankerData.tankerFrequency
        )
    end
  else
    result = veaf.t("carrier.atc_not_conducting", groupName)
  end

  if not skipNavigationData then
    -- add current navigation data

    if currentHeading > -1 and currentSpeed > -1 then
      -- compute magnetic deviation at carrier position
      -- the north correction (grid-to-true) is not magnetic deviation, so it is deliberately not used here
      -- TODO find how to actually compute it
      --[[
            local magdev = veaf.round(veaf.getNorthCorrection(startPosition) * 180 / math.pi,1)
            veaf.loggers.get(veafCarrierOperations.Id):trace("magdev = " .. magdev)
            ]]
      result = result .. veaf.t("carrier.atc_navigation", veaf.round(currentHeading, 0), currentSpeed)
    end
  end

  -- determine the correct unit system based on carrier type
  local weatherUnitSystem = veafWeatherUnitSystem.Systems.FaaNavy -- default for US carriers
  if carrierUnit then
    local carrierType = carrierUnit:getDesc()["typeName"]
    if carrierType == "KUZNECOW" or carrierType == "CV_1143_5" then
      weatherUnitSystem = veafWeatherUnitSystem.Systems.MetricEastern -- for Russian carriers
    end
  end
  result = result .. veaf.t("carrier.atc_weather_header") .. veafWeatherData.getWeatherString(startPosition, nil, weatherUnitSystem, 20) -- typical carrier deck height

  return result
end

--- Gets informations about current carrier operations
function veafCarrierOperations.atcForCarrierOperations(parameters)
  local groupName, unitName = veaf.safeUnpack(parameters)
  veaf.loggers.get(veafCarrierOperations.Id):debug("atcForCarrierOperations(" .. groupName .. ")")
  local text = veafCarrierOperations.getAtcForCarrierOperations(groupName)
  veaf.outTextForGroup(unitName, text, 15)
end

--- Ends carrier operations ; changes the radio menu item to START and send the carrier back to its starting point
function veafCarrierOperations.stopCarrierOperations(parameters)
  local groupName, userUnitName = veaf.safeUnpack(parameters)
  veaf.loggers.get(veafCarrierOperations.Id):debug("stopCarrierOperations(" .. groupName .. ")")

  local carrier = veafCarrierOperations.carriers[groupName]

  if not carrier then
    local text = "Cannot find the carrier group " .. groupName
    veaf.loggers.get(veafCarrierOperations.Id):error(text)
    trigger.action.outText(veaf.t("carrier.not_found", groupName), 5)
    return
  end

  local text = "The carrier group " .. groupName .. " has stopped air operations ; it's moving back to its initial position"
  veaf.loggers.get(veafCarrierOperations.Id):info(text)
  veaf.outTextForGroup(userUnitName, veaf.t("carrier.stopped", groupName), 5)
  carrier.conductingAirOperations = false
  carrier.stoppedAirOperations = true

  -- change the menu
  veaf.loggers.get(veafCarrierOperations.Id):trace("change the menu")
  veafCarrierOperations.rebuildRadioMenu()

  -- make the Pedro land
  if carrier.pedroIsSpawned then
    carrier.pedroIsSpawned = false
    local pedroUnit = Unit.getByName(carrier.pedroUnitName)
    if pedroUnit then
      veaf.loggers.get(veafCarrierOperations.Id):debug("found Pedro unit ; destroying it")
      pedroUnit:destroy()
    end
  end

  -- make the tanker land
  if carrier.tankerIsSpawned then
    carrier.tankerIsSpawned = false
    local tankerUnit = Unit.getByName(carrier.tankerUnitName)
    if tankerUnit then
      veaf.loggers.get(veafCarrierOperations.Id):debug("found tanker unit ; destroying it")
      tankerUnit:destroy()
    end
  end

  veafCarrierOperations.doOperations()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------
--- Rebuild the radio menu
function veafCarrierOperations.rebuildRadioMenu()
  veaf.loggers.get(veafCarrierOperations.Id):debug("veafCarrierOperations.rebuildRadioMenu()")

  -- find the carriers in the veafCarrierOperations.carriers table and prepare their menus
  for name, carrier in pairs(veafCarrierOperations.carriers) do
    veaf.loggers.get(veafCarrierOperations.Id):trace("rebuildRadioMenu processing " .. name)

    local menuRoot = veafCarrierOperations.rootPathRed
    if carrier.side == coalition.side.BLUE then
      menuRoot = veafCarrierOperations.rootPathBlue
    end

    -- remove the submenu if it exists
    if carrier.menuPath then
      veafRadio.delSubmenu(carrier.menuPath, menuRoot)
      veaf.loggers.get(veafCarrierOperations.Id):trace("remove the submenu")
    end

    -- create the submenu
    veaf.loggers.get(veafCarrierOperations.Id):trace("create the submenu")

    carrier.menuPath = veafRadio.addSubMenu(name, menuRoot)

    if carrier.conductingAirOperations then
      -- add the stop menu
      if veafCarrierOperations.DisableSecurity then
        veafRadio.addCommandToSubmenu(
          veaf.t("menu.carrier.end_ops"),
          carrier.menuPath,
          veafCarrierOperations.stopCarrierOperations,
          name,
          veafRadio.USAGE_ForGroup
        )
      else
        veafRadio.addSecuredCommandToSubmenu(
          veaf.t("menu.carrier.end_ops"),
          carrier.menuPath,
          veafCarrierOperations.stopCarrierOperations,
          name,
          veafRadio.USAGE_ForGroup
        )
      end
    else
      -- add the "start for veafCarrierOperations.MAX_OPERATIONS_DURATION" menu
      local startMenuName1 = "Start carrier air operations for " .. veafCarrierOperations.MAX_OPERATIONS_DURATION .. " minutes"
      if veafCarrierOperations.DisableSecurity then
        veafRadio.addCommandToSubmenu(
          startMenuName1,
          carrier.menuPath,
          veafCarrierOperations.startCarrierOperations,
          { name, veafCarrierOperations.MAX_OPERATIONS_DURATION },
          veafRadio.USAGE_ForGroup
        )
      else
        veafRadio.addSecuredCommandToSubmenu(
          startMenuName1,
          carrier.menuPath,
          veafCarrierOperations.startCarrierOperations,
          { name, veafCarrierOperations.MAX_OPERATIONS_DURATION },
          veafRadio.USAGE_ForGroup
        )
      end

      -- add the "start for veafCarrierOperations.MAX_OPERATIONS_DURATION * 2" menu
      local startMenuName2 = "Start carrier air operations for " .. veafCarrierOperations.MAX_OPERATIONS_DURATION * 2 .. " minutes"
      if veafCarrierOperations.DisableSecurity then
        veafRadio.addCommandToSubmenu(
          startMenuName2,
          carrier.menuPath,
          veafCarrierOperations.startCarrierOperations,
          { name, veafCarrierOperations.MAX_OPERATIONS_DURATION * 2 },
          veafRadio.USAGE_ForGroup
        )
      else
        veafRadio.addSecuredCommandToSubmenu(
          startMenuName2,
          carrier.menuPath,
          veafCarrierOperations.startCarrierOperations,
          { name, veafCarrierOperations.MAX_OPERATIONS_DURATION * 2 },
          veafRadio.USAGE_ForGroup
        )
      end
    end

    -- add the ATC menu (by player group)
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.carrier.atc_info"),
      carrier.menuPath,
      veafCarrierOperations.atcForCarrierOperations,
      name,
      veafRadio.USAGE_ForGroup
    )

    veafRadio.refreshRadioMenu()
  end
end

--- Build the initial radio menu
function veafCarrierOperations.buildRadioMenu()
  veaf.loggers.get(veafCarrierOperations.Id):debug("veafCarrierOperations.buildRadioMenu")

  -- don't create an empty menu
  if veaf.length(veafCarrierOperations.carriers) == 0 then
    return
  end

  veafCarrierOperations.rootPath = veafRadio.addSubMenu(veaf.t(veafCarrierOperations.RadioMenuName))
  -- #87: these two were created without their coalition, so the renderer had nothing to filter on and
  -- every player saw both — a red pilot opened "Carrier operations" and drove the blue carrier. The
  -- per-side menus existed already; what was missing was one argument. Each carrier's own submenu
  -- hangs under one of these (see rebuildRadioMenu), and a scoped node scopes everything below it,
  -- so this is the only place the side has to be stated.
  veafCarrierOperations.rootPathBlue =
    veafRadio.addSubMenu(veaf.t(veafCarrierOperations.RadioMenuNameBlue), veafCarrierOperations.rootPath, coalition.side.BLUE)
  veafCarrierOperations.rootPathRed =
    veafRadio.addSubMenu(veaf.t(veafCarrierOperations.RadioMenuNameRed), veafCarrierOperations.rootPath, coalition.side.RED)

  -- build HELP menu for each group
  if not veafRadio.skipHelpMenus then
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.common.help"),
      veafCarrierOperations.rootPath,
      veafCarrierOperations.help,
      nil,
      veafRadio.USAGE_ForGroup
    )
  end

  veafCarrierOperations.rebuildRadioMenu()
end

function veafCarrierOperations.help(unitName)
  veaf.outTextForGroup(unitName, veaf.t("carrier.help"), 30)
end

function veafCarrierOperations.initializeCarrierGroups()
  -- find the carriers and add them to the veafCarrierOperations.carriers table, store its initial location and create the menus
  for name, group in pairs(veaf.mist.getAllGroupData()) do
    veaf.loggers.get(veafCarrierOperations.Id):trace("found group " .. name)
    -- search groups with a carrier unit in the group
    local carrier = nil
    -- find the actual carrier unit
    local group = Group.getByName(name)
    if group then
      for _, unit in pairs(group:getUnits()) do
        local unitType = unit:getDesc()["typeName"]
        for knownCarrierType, data in pairs(veafCarrierOperations.AllCarriers) do
          if unitType == knownCarrierType then
            local coa = group:getCoalition()
            veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("coa=%s", veaf.p(coa)))
            -- found a carrier, initialize the carrier group object if needed
            if not carrier then
              veafCarrierOperations.carriers[name] = {}
              carrier = veafCarrierOperations.carriers[name]
              veaf.loggers.get(veafCarrierOperations.Id):trace("found carrier !")
            else
              veaf.loggers.get(veafCarrierOperations.Id):warn(string.format("more than one carrier in group %s", veaf.p(name)))
            end
            carrier.side = coa
            carrier.carrierUnit = unit
            carrier.carrierUnitName = carrier.carrierUnit:getName()
            carrier.runwayAngleWithBRC = data.runwayAngleWithBRC
            carrier.desiredWindSpeedOnDeck = data.desiredWindSpeedOnDeck
            carrier.heading = veaf.getHeading(unit, true)

            --veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("Carrier Data from MIST : %s",veaf.p(veaf.getGroupData(name))))

            carrier.ATC = {}
            carrier.ATC = veaf.getCarrierATCdata(name, unit:getName())

            carrier.pedroUnitName = carrier.carrierUnitName .. " Pedro" -- rescue helo unit name
            local pedroUnit = Unit.getByName(carrier.pedroUnitName)
            if pedroUnit then
              pedroUnit:destroy()
            end
            carrier.tankerUnitName = carrier.carrierUnitName .. " S3B-Tanker" -- emergency tanker unit name
            carrier.tankerData = veaf.getTankerData(carrier.tankerUnitName)
            local tankerUnit = Unit.getByName(carrier.tankerUnitName)
            if tankerUnit then
              tankerUnit:destroy()
            end
            break
          end
        end
      end

      if carrier then
        -- take note of the carrier route
        carrier.missionRoute = veaf.getGroupRoute(name)
        veaf.loggers.get(veafCarrierOperations.Id):trace("carrier.missionRoute=%s", veaf.lp(carrier.missionRoute))
        if veafCarrierOperations.Trace then
          for num, point in pairs(carrier.missionRoute) do
            veafCarrierOperations.traceMarkerId =
              veaf.loggers
                .get(veafCarrierOperations.Id)
                :marker(veafCarrierOperations.traceMarkerId, "CARRIER", string.format("[%s] point %d", name, tostring(num)), point, nil)
          end
        end
      end
    end
  end
end

function veafCarrierOperations.doOperations()
  veaf.loggers.get(veafCarrierOperations.Id):debug("veafCarrierOperations.doOperations()")

  -- find the carriers in the veafCarrierOperations.carriers table and check if they are operating
  for name, carrier in pairs(veafCarrierOperations.carriers) do
    veaf.loggers.get(veafCarrierOperations.Id):debug("checking " .. name)
    if carrier.conductingAirOperations then
      veaf.loggers.get(veafCarrierOperations.Id):debug(name .. " is conducting operations ; checking course and ops duration")
      if carrier.airOperationsEndAt < timer.getTime() then
        -- time to stop operations
        veaf.loggers.get(veafCarrierOperations.Id):info(name .. " has been conducting operations long enough ; stopping ops")
        veafCarrierOperations.stopCarrierOperations(name)
      else
        local remainingTime = veaf.round((carrier.airOperationsEndAt - timer.getTime()) / 60, 1)
        veaf.loggers
          .get(veafCarrierOperations.Id)
          :debug(name .. " will continue conducting operations for " .. remainingTime .. " more minutes")
        -- check and reset course
        veafCarrierOperations.continueCarrierOperations(name)
      end
    elseif carrier.stoppedAirOperations then
      carrier.conductingAirOperations = false
      veaf.loggers.get(veafCarrierOperations.Id):debug(name .. " stopped conducting operations")
      veaf.loggers
        .get(veafCarrierOperations.Id)
        :cleanupMarkers(veafCarrierOperations.getDebugMarkersErasedAtEachStep(carrier.carrierUnitName))
      carrier.stoppedAirOperations = false
      -- reset the carrier group route to its original route (set in the mission)
      if carrier.missionRoute then
        veaf.loggers.get(veafCarrierOperations.Id):debug(string.format("resetting carrier %s route", name))
        veaf.loggers.get(veafCarrierOperations.Id):trace("carrier.missionRoute=%s", veaf.lp(carrier.missionRoute))
        local result = veaf.goRoute(name, carrier.missionRoute)
      end
    else
      veaf.loggers.get(veafCarrierOperations.Id):debug(name .. " is not conducting operations")
    end
  end
end

--- This function is called at regular interval (see veafCarrierOperations.SCHEDULER_INTERVAL) and manages the carrier operations schedules
--- It will make any carrier group that has started carrier operations maintain a correct course for recovery, even if wind changes.
--- Also, it will stop carrier operations after a set time (see veafCarrierOperations.MAX_OPERATIONS_DURATION).
function veafCarrierOperations.operationsScheduler()
  veaf.loggers.get(veafCarrierOperations.Id):debug("veafCarrierOperations.operationsScheduler()")

  veafCarrierOperations.doOperations()

  veaf.loggers
    .get(veafCarrierOperations.Id)
    :debug("veafCarrierOperations.operationsScheduler() - rescheduling in " .. veafCarrierOperations.SCHEDULER_INTERVAL * 60 .. " s")
  veaf.scheduleFunction(veafCarrierOperations.operationsScheduler, {}, timer.getTime() + veafCarrierOperations.SCHEDULER_INTERVAL * 60)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- remote interface
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafCarrierOperations.listAvailableCarriers(forGroup)
  local _message = veaf.t("carrier.available_list")
  for name, carrier in pairs(veafCarrierOperations.carriers) do
    _message = _message .. " - " .. name .. "\n"
  end
  if forGroup then
    trigger.action.outTextForGroup(forGroup, _message, 15)
  else
    trigger.action.outText(_message, 15)
  end
end

-- execute command from the remote interface
function veafCarrierOperations.executeCommandFromRemote(parameters)
  veaf.loggers.get(veafCarrierOperations.Id):debug(string.format("veafCarrierOperations.executeCommandFromRemote()"))
  veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("parameters= %s", veaf.p(parameters)))
  local _pilot, _pilotName, _unitName, _command = unpack(parameters)
  veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("_pilot= %s", veaf.p(_pilot)))
  veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("_pilotName= %s", veaf.p(_pilotName)))
  veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("_unitName= %s", veaf.p(_unitName)))
  veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("_command= %s", veaf.p(_command)))
  if not _pilot or not _command then
    return false
  end

  local function findCarrier(carrierName)
    local _result = nil
    local _name = carrierName:lower()
    for name, carrier in pairs(veafCarrierOperations.carriers) do
      if name:lower():find(_name) then
        _result = name
      end
    end
    return _result
  end

  if _command then
    -- parse the command
    local _action, _carrierName, _parameters = _command:match(veafCarrierOperations.RemoteCommandParser)
    veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("_action=%s", veaf.p(_action)))
    veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("_carrierName=%s", veaf.p(_carrierName)))
    veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("_parameters=%s", veaf.p(_parameters)))
    local _groupId = nil
    if _unitName then
      local _unit = Unit.getByName(_unitName)
      if _unit then
        _groupId = _unit:getGroup():getID()
      end
    end
    veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("_groupId=%s", veaf.p(_groupId)))
    if _action and _action:lower() == "list" then
      veaf.loggers.get(veafCarrierOperations.Id):info(string.format("[%s] is listing carriers)", veaf.p(_pilot.name)))
      veafCarrierOperations.listAvailableCarriers(_groupId)
      return true
    elseif _action and _action:lower() == "start" and _carrierName then
      ---@type number
      -- VMR-086: `_parameters` comes from a string match, so it is never a number and the
      -- duration the caller asked for was dropped on the floor. The dead branch also read a
      -- global `parameters` instead of `_parameters`, which is why nothing ever noticed.
      local _duration = tonumber(_parameters) or 45
      local _carrier = findCarrier(_carrierName)
      veaf.loggers.get(veafCarrierOperations.Id):trace(string.format("_duration=%s", veaf.p(_duration)))
      veaf.loggers.get(veafCarrierOperations.Id):info(
        string.format("[%s] is starting operations on carrier [%s] for %s)", veaf.p(_pilot.name), veaf.p(_carrier), veaf.p(_parameters))
      )
      veafCarrierOperations.startCarrierOperations({ _carrier, _duration })
      return true
    elseif _action and _action:lower() == "stop" then
      local _carrier = findCarrier(_carrierName)
      veaf.loggers
        .get(veafCarrierOperations.Id)
        :info(string.format("[%s] is stopping operations on carrier [%s])", veaf.p(_pilot.name), veaf.p(_carrier)))
      veafCarrierOperations.stopCarrierOperations(_carrier)
      return true
    elseif _action and _action:lower() == "atc" then
      local _carrier = findCarrier(_carrierName)
      veaf.loggers
        .get(veafCarrierOperations.Id)
        :info(string.format("[%s] is requesting atc on carrier [%s])", veaf.p(_pilot.name), veaf.p(_carrier)))
      local text = veafCarrierOperations.getAtcForCarrierOperations(_carrier)
      if _groupId then
        trigger.action.outTextForGroup(_groupId, text or "", 15)
      else
        trigger.action.outText(text or "", 15)
      end
      return true
    end
  end
  return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Carrier ATC
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafCarrierOperations.initialize()
  veafCarrierOperations.initializeCarrierGroups()
  veafCarrierOperations.buildRadioMenu()
  veafCarrierOperations.operationsScheduler()
  veafRemote.registerRemoteModule("carrier", veafCarrierOperations.executeCommandFromRemote)
end

veaf.loggers.get(veafCarrierOperations.Id):info(veaf.loggers.get(veafCarrierOperations.Id):getVersionInfo())

--- Enable/Disable error boxes displayed on screen.
env.setErrorMessageBoxEnabled(false)

veaf.registerModule(veafCarrierOperations.Id, veafCarrierOperations.initialize, { enable = true }, 80)
