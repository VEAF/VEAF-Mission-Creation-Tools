------------------------------------------------------------------
-- VEAF spawn command and functions for DCS World
-- Effects spawn sub-module: bomb, smoke, signal flare, illumination flare
-- What flashes and fades. Whatever stays in the world once spawned lives in
-- veafSpawnObjects.lua.
-- Part of veafSpawn.lua split (LUAR-001)
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Smoke and Flare commands
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- trigger an explosion at the marker area
function veafSpawn.spawnBomb(spawnSpot, radius, shells, power, altitude, altitudedelta, password)
  veaf.loggers.get(veafSpawn.Id):debug("spawnBomb(power=" .. power .. ")")

  local shellTime = 0
  local shellDelay = 0
  for shell = 1, shells do
    local spawnSpot = veaf.placePointOnLand(veaf.getRandomPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=%s", spawnSpot)
    veaf.loggers.get(veafSpawn.Id):trace("altitude=%s", altitude)
    if altitude and altitude > 0 then
      spawnSpot.y = altitude + altitudedelta * ((math.random(100) - 50) / 100)
      shellDelay = veafSpawn.FlakingInterval
    else
      shellDelay = veafSpawn.ShellingInterval
    end
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=%s", spawnSpot)

    local shellDelay = shellDelay * (math.random(100) + 30) / 100
    local shellPower = power * (math.random(100) + 30) / 100
    -- check security
    if not veafSecurity.checkPassword_L0(password) then
      if shellPower > 1000 then
        shellPower = 1000
      end
    end
    veaf.loggers
      .get(veafSpawn.Id)
      :trace(string.format("shell #%d : shellTime=%d, shellDelay=%d, power=%d", shell, shellTime, shellDelay, shellPower))
    veaf.scheduleFunction(trigger.action.explosion, { spawnSpot, shellPower }, timer.getTime() + shellTime)
    shellTime = shellTime + shellDelay
  end
end

--- add a smoke marker over the marker area
function veafSpawn.spawnSmoke(spawnSpot, color, radius, shells)
  veaf.loggers.get(veafSpawn.Id):debug("spawnSmoke(color=%s", veaf.lp(color))
  local radius = radius or 50
  local shells = shells or 1
  veaf.loggers.get(veafSpawn.Id):trace("radius=%s", veaf.lp(radius))
  veaf.loggers.get(veafSpawn.Id):trace("shells=%s", veaf.lp(shells))

  local shellTime = 0
  for shell = 1, shells do
    local spawnSpot = veaf.placePointOnLand(veaf.getRandomPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnSpot=%s", veaf.vecToString(spawnSpot)))

    local shellDelay = veafSpawn.ShellingInterval * (math.random(100) + 30) / 100
    veaf.loggers.get(veafSpawn.Id):trace(string.format("shell #%d : shellTime=%d, shellDelay=%d", shell, shellTime, shellDelay))
    if shells > 1 then
      -- add a small explosion under the smoke to simulate smoke shells
      veaf.scheduleFunction(trigger.action.explosion, { spawnSpot, 1 }, timer.getTime() + shellTime - 1)
    end
    veaf.scheduleFunction(trigger.action.smoke, { spawnSpot, color }, timer.getTime() + shellTime)
    shellTime = shellTime + shellDelay
  end
end

--- add a signal flare over the marker area
function veafSpawn.spawnSignalFlare(spawnSpot, radius, shells, color)
  veaf.loggers.get(veafSpawn.Id):debug("spawnSignalFlare(color = " .. color .. ")")
  local radius = radius or 50
  local shells = shells or 1

  local shellTime = 0
  for shell = 1, shells do
    local spawnSpot = veaf.placePointOnLand(veaf.getRandomPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnSpot=%s", veaf.vecToString(spawnSpot)))

    local shellDelay = veafSpawn.ShellingInterval * (math.random(100) + 30) / 100
    local azimuth = math.random(359)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("shell #%d : shellTime=%d, shellDelay=%d", shell, shellTime, shellDelay))
    veaf.scheduleFunction(trigger.action.signalFlare, { spawnSpot, color, azimuth }, timer.getTime() + shellTime)
    shellTime = shellTime + shellDelay
  end
end

--- add an illumination flare over the target area
function veafSpawn.spawnIlluminationFlare(spawnSpot, radius, steps, power, height, heading, distance, speed)
  local radius = radius or 50
  local steps = steps or 1
  local power = power or 10
  local height = height or 500

  veaf.loggers.get(veafSpawn.Id):debug("spawnIlluminationFlare()")
  veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=%s", veaf.lp(spawnSpot))
  veaf.loggers.get(veafSpawn.Id):trace("radius=%s", veaf.lp(radius))
  veaf.loggers.get(veafSpawn.Id):trace("steps=%s", veaf.lp(steps))
  veaf.loggers.get(veafSpawn.Id):trace("power=%s", veaf.lp(power))
  veaf.loggers.get(veafSpawn.Id):trace("height=%s", veaf.lp(height))
  veaf.loggers.get(veafSpawn.Id):trace("heading=%s", veaf.lp(heading))
  veaf.loggers.get(veafSpawn.Id):trace("distance=%s", veaf.lp(distance))

  local cosHeading
  local sinHeading
  local stepDistance
  if heading then
    if distance then
      distance = distance * 1852 -- meters
      stepDistance = distance / (steps - 1)
    elseif speed then
      speed = speed / 1.94384 -- m/s
      stepDistance = speed * veafSpawn.IlluminationShellingInterval
    end
    local headingRad = math.rad(heading)
    cosHeading = math.cos(headingRad)
    sinHeading = math.sin(headingRad)
  end

  local stepTime = 0
  for step = 1, steps do
    local stepDelay = veafSpawn.IlluminationShellingInterval * (math.random(100, 130) - 15) / 100
    local newSpawnSpot = veaf.deepCopy(spawnSpot)
    if stepDistance then
      newSpawnSpot.x = spawnSpot.x + stepDistance * (step - 1) * cosHeading
      newSpawnSpot.z = spawnSpot.z + stepDistance * (step - 1) * sinHeading
    end
    local shellsPerStep = math.random(5, 10)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("step #%d : stepTime=%d, shellDelay=%d", step, stepTime, stepDelay))
    for shell = 1, shellsPerStep do
      local shellDelay = shell / 4 + (math.random(100, 150) - 25) / 100
      local shellHeight = height * (math.random(100, 130) - 15) / 100
      local shellPower = power * (math.random(100, 130) - 15) / 100
      local newSpawnSpot = veaf.placePointOnLand(veaf.getRandomPointInCircle(newSpawnSpot, radius))
      newSpawnSpot.y = veaf.getLandHeight(newSpawnSpot) + shellHeight
      veaf.loggers.get(veafSpawn.Id):trace(string.format("shell #%d : shellHeight=%d, shellPower=%d", shell, shellHeight, shellPower))
      local time = timer.getTime() + stepTime + shellDelay
      -- add a small explosion under the flare to simulate flare shells
      veaf.scheduleFunction(trigger.action.explosion, { newSpawnSpot, 0.1 }, time)
      veaf.scheduleFunction(trigger.action.illuminationBomb, { newSpawnSpot, shellPower }, time)
    end
    stepTime = stepTime + stepDelay
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Effects spawn command handlers
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSpawn.registerCommandHandler("bomb", "SENIOR_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.spawnBomb(eventPos, options.radius, options.shells, options.power, options.altitude, options.altitudedelta, options.password)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("smoke", "OPEN", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.spawnSmoke(eventPos, options.smokeColor, options.radius, options.shells)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("flare", "OPEN", function(eventPos, options, coalition, markId, bypassSecurity)
  if not options.altitude or options.altitude == 0 then
    options.altitude = 1000
  end
  if not options.power or options.power == 0 then
    options.power = 500
  end
  options.power = options.power * 1000
  veafSpawn.spawnIlluminationFlare(
    eventPos,
    options.radius,
    options.shells,
    options.power,
    options.altitude,
    options.heading,
    options.distance,
    options.speed
  )
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("signal", "OPEN", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.spawnSignalFlare(eventPos, options.radius, options.shells, options.smokeColor)
  return nil, nil, false
end)
