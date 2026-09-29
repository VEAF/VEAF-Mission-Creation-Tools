------------------------------------------------------------------
-- VEAF name point command and functions for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Listen to marker change events and name the corresponding point, for future reference
-- * Works with all current and future maps (Caucasus, NTTR, Normandy, PG, ...)
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------
veafNamedPoints = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafNamedPoints.Id = "NAMEDPOINTS"

-- trace level, specific to this module
--veafNamedPoints.LogLevel = "trace"
veaf.loggers.new(veafNamedPoints.Id, veafNamedPoints.LogLevel)

--- Key phrase to look for in the mark text which triggers the command.
veafNamedPoints.Keyphrase = "_name point"
veafNamedPoints.RadioMenuName = "menu.namedpoints.root"
veafNamedPoints.RemoteCommandParser = "([[a-zA-Z0-9]+)%s?([^%s]*)%s?(.*)"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafNamedPoints.namedPoints = {}
veafNamedPoints.rootPath = nil
veafNamedPoints.markid = 1270000 --- Initial Marker id.

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafNamedPoints.executeCommand(eventPos, event, bypassSecurity)
  -- Check if marker has a text and the veafNamedPoints.keyphrase keyphrase.
  if event.text ~= nil and event.text:lower():find(veafNamedPoints.Keyphrase) then
    -- Analyse the mark point text and extract the keywords.
    local options = veafNamedPoints.markTextAnalysis(event.text)

    if options then
      -- Check options commands
      if options.namepoint then
        -- create the mission
        veafNamedPoints.namePoint(eventPos, options.name, event.coalition)
      end
      return true
    else
      -- None of the keywords matched.
      return false
    end
  end
  return false
end
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Extract keywords from mark text.
function veafNamedPoints.markTextAnalysis(text)
  -- Option parameters extracted from the mark text.
  local switch = {}
  switch.namepoint = false

  switch.name = "point"

  -- Check for correct keywords.
  local pos = text:lower():find(veafNamedPoints.Keyphrase)
  if pos then
    switch.namepoint = true
  else
    return nil
  end

  -- the point name should follow a space
  switch.name = text:sub(pos + string.len(veafNamedPoints.Keyphrase) + 1)
  veaf.loggers.get(veafNamedPoints.Id):debug(string.format("Keyword name = %s", switch.name))

  return switch
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Named points management
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Create the point in the named points database
function veafNamedPoints.namePoint(targetSpot, name, coalition, silent)
  veaf.loggers.get(veafNamedPoints.Id):debug(string.format("namePoint(name = %s, coalition=%s)", name, coalition))
  veaf.loggers.get(veafNamedPoints.Id):debug("targetSpot=" .. veaf.vecToString(targetSpot))

  -- find an existing point with the same name
  local existingPoint = veafNamedPoints.getPoint(name)
  veaf.loggers.get(veafNamedPoints.Id):trace(string.format("existingPoint=%s", veaf.p(existingPoint)))
  if existingPoint and existingPoint.markerId then
    -- delete the existing point
    trigger.action.removeMark(existingPoint.markerId)
  end

  local point = { x = targetSpot.x, y = targetSpot.y, z = targetSpot.z }
  point.hidden = false
  veafNamedPoints.addPoint(name, point)

  local message = nil
  if not silent then
    message = veaf.t("namedpoints.added", name)
  end

  veafNamedPoints.markid = veafNamedPoints.markid + 1
  point.markerId = veafNamedPoints.markid
  trigger.action.markToCoalition(veafNamedPoints.markid, veaf.t("namedpoints.label", name), point, coalition, true, message)
  veaf.loggers.get(veafNamedPoints.Id):trace(string.format("created point %s", veaf.p(point)))
end

function veafNamedPoints.addPoint(name, point)
  if not point.y then
    point.y = 0
  end
  veaf.loggers.get(veafNamedPoints.Id):trace(string.format('addPoint: {name="%s",point={x=%d,y=0,z=%d}}', name, point.x, point.z))
  point.name = name:upper()
  veafNamedPoints.namedPoints[name:upper()] = point
  return point
end

function veafNamedPoints.delPoint(name)
  veaf.loggers.get(veafNamedPoints.Id):trace(string.format("delPoint(name = %s)", name))

  veafNamedPoints.namedPoints[name:upper()] = nil
end

function veafNamedPoints.getPoint(name)
  veaf.loggers.get(veafNamedPoints.Id):trace(string.format("getPoint(name = %s)", name or ""))
  if name then
    return veafNamedPoints.namedPoints[name:upper()]
  else
    return nil
  end
end

function veafNamedPoints.getPointBearing(parameters)
  local name, unitName = veaf.safeUnpack(parameters)
  veaf.loggers.get(veafNamedPoints.Id):trace(string.format("getPointBearing(%s)", name))
  local point = veafNamedPoints.getPoint(name)
  local unit = veafRadio.getHumanUnitOrWingman(unitName)
  if point and unit then
    local angle, distance, distanceInKm, distanceInNm = veaf.getBearingAndRangeFromTo(unit:getPosition().p, point)
    if distanceInNm > 2 then
      return "at " .. angle .. "° for " .. distanceInNm .. " nm"
    end
  end
  return nil
end

function veafNamedPoints.getNearestPoint(unitName)
  veaf.loggers.get(veafNamedPoints.Id):debug("veafNamedPoints.getNearestPoint(unitName = %s)", veaf.lp(unitName))
  local closestPoint = nil
  local minDistance = 99999999
  local unit = veafRadio.getHumanUnitOrWingman(unitName)
  if unit then
    for name, point in pairs(veafNamedPoints.namedPoints) do
      local distanceFromPlayer = ((point.x - unit:getPosition().p.x) ^ 2 + (point.z - unit:getPosition().p.z) ^ 2) ^ 0.5
      veaf.loggers.get(veafNamedPoints.Id):trace(string.format("name=%s, distanceFromPlayer=%d", name, distanceFromPlayer))
      if distanceFromPlayer < minDistance then
        minDistance = distanceFromPlayer
        closestPoint = point
      end
    end
  end
  veaf.loggers.get(veafNamedPoints.Id):trace("closestPoint=%s", veaf.lp(closestPoint))
  return closestPoint
end

function veafNamedPoints.pointFromString(coordinatesString)
  veaf.loggers.get(veafNamedPoints.Id):debug(string.format("pointFromString(coordinatesString = %s)", veaf.p(coordinatesString)))
  local _result = nil
  local _lat, _lon = veaf.computeLLFromString(coordinatesString)
  veaf.loggers.get(veafNamedPoints.Id):trace(string.format("_lat=%s", veaf.p(_lat)))
  veaf.loggers.get(veafNamedPoints.Id):trace(string.format("_lon=%s", veaf.p(_lon)))
  if _lat and _lon then
    _result = veafNamedPoints.pointFromLL(_lat, _lon)
  end
  return _result
end

function veafNamedPoints.pointFromLL(lat, long)
  veaf.loggers.get(veafNamedPoints.Id):debug(string.format("pointFromLL(lat = %s, long = %s)", veaf.p(lat), veaf.p(long)))
  return coord.LLtoLO(lat, long)
end

function veafNamedPoints.addDataToPoint(point, data)
  if point then
    if data then
      for key, value in pairs(data) do
        point[key] = value
      end
    end
    return point
  end
end

function veafNamedPoints.listAllPoints(unitName)
  veaf.loggers.get(veafNamedPoints.Id):debug(string.format("listAllPoints(unitName = %s)", tostring(unitName)))
  local message = ""
  local names = {}
  for name, point in pairs(veafNamedPoints.namedPoints) do
    if not point.hidden then
      table.insert(names, name)
    end
  end
  table.sort(names)
  for _, name in pairs(names) do
    local point = veafNamedPoints.namedPoints[name]
    local lat, lon = coord.LOtoLL(point)
    local llString = veaf.toStringLL(lat, lon, 3)
    llString = llString:sub(0, 2) .. "°" .. llString:sub(4)
    local mgrs = coord.LLtoMGRS(lat, lon)
    local mgrsString = veaf.toStringMGRS(mgrs, 5)
    message = message .. name .. " => " .. llString .. " / " .. mgrsString .. "\n"
  end

  -- send message only for the unit
  veaf.outTextForUnit(unitName, message, 30)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafNamedPoints.buildRadioMenu()
  veaf.loggers.get(veafNamedPoints.Id):debug("buildRadioMenu()")
  veafNamedPoints.rootPath = veafRadio.addSubMenu(veaf.t(veafNamedPoints.RadioMenuName))
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.namedpoints.list"),
    veafNamedPoints.rootPath,
    veafNamedPoints.listAllPoints,
    nil,
    veafRadio.USAGE_ForGroup
  )
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- remote interface
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- execute command from the remote interface
function veafNamedPoints.executeCommandFromRemote(parameters)
  veaf.loggers.get(veafNamedPoints.Id):debug(string.format("veafNamedPoints.executeCommandFromRemote()"))
  veaf.loggers.get(veafNamedPoints.Id):trace(string.format("parameters= %s", veaf.p(parameters)))
  local _pilot, _pilotName, _unitName, _command = unpack(parameters)
  veaf.loggers.get(veafNamedPoints.Id):trace(string.format("_pilot= %s", veaf.p(_pilot)))
  veaf.loggers.get(veafNamedPoints.Id):trace(string.format("_pilotName= %s", veaf.p(_pilotName)))
  veaf.loggers.get(veafNamedPoints.Id):trace(string.format("_unitName= %s", veaf.p(_unitName)))
  veaf.loggers.get(veafNamedPoints.Id):trace(string.format("_command= %s", veaf.p(_command)))
  if not _pilot or not _command then
    return false
  end

  veaf.outTextForUnit(_unitName, veaf.t("namedpoints.no_remote"), 30)

  --[[ keep this for later if we need a remote access for the veafNamedPoints script
    if _command then
        -- parse the command
        local _action, _pointName, _parameters = _command:match(veafNamedPoints.RemoteCommandParser)
        veaf.loggers.get(veafNamedPoints.Id):trace(string.format("_action=%s",veaf.p(_action)))
        veaf.loggers.get(veafNamedPoints.Id):trace(string.format("_pointName=%s",veaf.p(_pointName)))
        veaf.loggers.get(veafNamedPoints.Id):trace(string.format("_parameters=%s",veaf.p(_parameters)))
        if _action and _action:lower() == "weather" then
            veaf.loggers.get(veafNamedPoints.Id):info(string.format("[%s] is requesting weather at his position",veaf.p(_pilotName)))
            veafNamedPoints.getWeatherAtClosestPoint(_unitName, true)
            return true
        elseif _action and _action:lower() == "atc" then
            veaf.loggers.get(veafNamedPoints.Id):info(string.format("[%s] is requesting atc at his position",veaf.p(_pilotName)))
            veafNamedPoints.getAtcAndWeatherAtClosestPoint(_unitName, true)
            return true
        end
    end
    return false
    ]]
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafNamedPoints.initialize(customPoints)
  veaf.loggers.get(veafNamedPoints.Id):info("Initialize veafNamedPoints")
  veafNamedPoints.namedPoints = {}

  veafNamedPoints.addCities()
  veafNamedPoints.addAirbases()
  veafNamedPoints.addCustomPoints(customPoints)

  veafNamedPoints.buildRadioMenu()
  -- OPEN: naming a point is informational and has no side effect, so it stays available to
  -- everyone -- but as a written decision rather than an omission. Chosen by David.
  veafCommands.registerCommandHandler(function(pos, event, bypass, fromMarker, groups, route)
    -- From the interpreter (fromMarker=false), preserve legacy coalition=-1 so named
    -- points created via unit names are visible to all coalitions (same as before).
    local effectiveEvent = fromMarker and event or { text = event.text, coalition = -1, idx = nil }
    return veafNamedPoints.executeCommand(pos, effectiveEvent, bypass)
  end, veafCommands.PRIORITY_NAMEDPOINTS, "OPEN", veafNamedPoints.Keyphrase)
  veafRemote.registerRemoteModule("point", veafNamedPoints.executeCommandFromRemote)
end

function veafNamedPoints.addCities()
  local theatre = env.mission.theatre
  veaf.loggers.get(veafNamedPoints.Id):info("Initialize veafNamedPoints cities for theatre %s", theatre)

  -- keyed by env.mission.theatre, generated from each terrain's towns.lua (veafCities.lua)
  local theatreCities = veafCities and veafCities[theatre]
  if not theatreCities then
    veaf.loggers.get(veaf.Id):warn(
      "no cities in veafNamedPoints for theatre %s: a town name will not work as a destination, a shortcut position or a transport start, and the weather at the closest point only knows the airbases",
      veaf.p(theatre)
    )
    theatreCities = {}
  end

  veafNamedPoints.addCitiesFromList(theatreCities)
end

function veafNamedPoints.addCitiesFromList(cities)
  for name, data in pairs(cities) do
    veaf.loggers.get(veafNamedPoints.Id):trace(string.format("processing city name=[%s]", name or ""))
    local point = coord.LLtoLO(data.latitude, data.longitude)
    --veaf.loggers.get(veafNamedPoints.Id):trace(string.format("point=[%s]",veaf.p(point)))
    ---@diagnostic disable-next-line: inject-field
    point.hidden = true
    local name = data.display_name
    --veaf.loggers.get(veafNamedPoints.Id):trace(string.format("name=[%s]",name or ""))

    veafNamedPoints.addPoint(name, point)

    -- add a clean version of the city name
    local cleanedUpCityName = name:gsub("[^a-zA-Z]", "")
    if not veafNamedPoints.namedPoints[cleanedUpCityName:upper()] then
      veafNamedPoints.addPoint(cleanedUpCityName, point)
    end

    --veafNamedPoints.markid = veafNamedPoints.markid + 1
    --trigger.action.markToAll(veafNamedPoints.markid, "VEAF - Point named "..name, point, true)
  end
end

function veafNamedPoints.addAirbases()
  veafAirbases.initialize()

  for _, veafAirbase in pairs(veafAirbases.Airbases) do
    if veafAirbase.Category == Airbase.Category.AIRDROME then
      if not veafAirbase.DcsAirbase or not veafAirbase.DcsAirbase:isExist() then
        -- skip stale/destroyed airbase references (e.g. sunk carriers)
      else
        veaf.loggers.get(veafNamedPoints.Id):trace("processing airbase name=[%s]", veafAirbase.DisplayName)
        local vec3 = veafAirbase.DcsAirbase:getPoint()
        local runways = {}
        for i, veafRunway in ipairs(veafAirbase.Runways) do
          for __, veafRunwayEnd in ipairs(veafRunway) do
            --veaf.loggers.get(veafNamedPoints.Id):trace(veaf.p(veafRunwayEnd))
            table.insert(runways, { name = string.format("%02d", veafRunwayEnd.Number), hdg = veafRunwayEnd.Heading })
          end
        end

        local namedPoint = { x = vec3.x, y = 0, z = vec3.z, runways = runways } --{name="AIRBASE Batumi",  point={x=-356437,y=0,z=618211, atc=true, tower="V131, U260", tacan="16X BTM", runways={{name="13", hdg=125, ils="110.30"}, {name="31", hdg=305}}}},
        namedPoint.hidden = true
        veafNamedPoints.addPoint(string.format("AIRBASE %s", veafAirbase.DisplayName), namedPoint)
      end -- end of isExist() guard
    end
  end

  return nil
end

function veafNamedPoints.addCustomPoints(customPoints)
  veaf.loggers.get(veafNamedPoints.Id):debug("addCustomPoints()")

  if customPoints then
    for _, defaultPoint in pairs(customPoints) do
      veafNamedPoints.addPoint(defaultPoint.name, defaultPoint.point)
    end
  end
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  Cities tables
--- the tables themselves are generated into veafCities.lua (veaf-build update-dcs-data --cities)
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- backward compatibility for old mission created with pre-2023 VMC
function veafNamedPoints.addAllSyriaCities() end
function veafNamedPoints.addAllCaucasusCities() end
function veafNamedPoints.addAllTheChannelCities() end
function veafNamedPoints.addAllMarianasIslandsCities() end
function veafNamedPoints.addAllPersianGulfCities() end
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  Module loading log
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
veaf.loggers.get(veafNamedPoints.Id):info(veaf.loggers.get(veafNamedPoints.Id):getVersionInfo())

veaf.registerModule(veafNamedPoints.Id, function()
  local cfg = veaf.getConfig(veafNamedPoints.Id)
  veafNamedPoints.initialize(cfg.customPoints)
end, { enable = true }, 50)

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  MODULE TESTS
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--[[
veaf.loggers.get(veafNamedPoints.Id):trace("MODULE TESTS: " .. veafNamedPoints.Id)
veafNamedPoints.addCities()
veafNamedPoints.addAirbases()
veaf.loggers.get(veafNamedPoints.Id):trace(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
for _, veafNamedPoint in pairs(veafNamedPoints.namedPoints) do
    if (veaf.startsWith(_, "AIRBASE", false)) then
        veaf.loggers.get(veafNamedPoints.Id):trace(">>> %s", veaf.lp(veafNamedPoint))    
    end
    --veaf.loggers.get(veafNamedPoints.Id):trace(">>> %s", veaf.p(veafNamedPoint))
    veafNamedPoints.markid = veafNamedPoints.markid + 1
    trigger.action.markToAll(veafNamedPoints.markid, "VEAF - Point named ".. _, veafNamedPoint, true) 

end
veaf.loggers.get(veafNamedPoints.Id):trace(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
]]
