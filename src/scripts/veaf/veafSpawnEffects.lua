------------------------------------------------------------------
-- VEAF spawn command and functions for DCS World
-- Effects spawn sub-module: cargo, bomb, smoke, flares, destroy, teleport
-- Part of veafSpawn.lua split (LUAR-001)
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

function veafSpawn.spawnCargo(spawnSpot, radius, cargoType, country, weightBias, cargoSmoke, unitName, silent, hiddenOnMFD)
  veaf.loggers.get(veafSpawn.Id):debug("spawnCargo(cargoType = " .. cargoType .. ")")
  return veafSpawn.doSpawnCargo(spawnSpot, radius, cargoType, country, weightBias, unitName, cargoSmoke, silent, hiddenOnMFD)
end

--- Spawn a logistic unit for CTLD at a specific spot
function veafSpawn.spawnLogistic(spawnSpot, radius, country, silent, hiddenOnMFD)
  veaf.loggers.get(veafSpawn.Id):debug("spawnLogistic()")

  local unitName = veafSpawn.doSpawnStatic(
    spawnSpot,
    radius,
    veafSpawn.LogisticUnitCategory,
    veafSpawn.LogisticUnitType,
    country,
    nil,
    false,
    true,
    hiddenOnMFD
  )

  if unitName then
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnLogistic: registering %s as a CTLD logistic zone", unitName))
    if ctld and veaf.isEnabled("ctld") then
      local unit = Unit.getByName(unitName) or StaticObject.getByName(unitName)
      if unit then
        CTLDZoneManager.getInstance():registerFOBAsLogistic(unitName, unit:getPoint(), nil, unit:getCoalition())
      end
    end

    -- message the unit spawning
    if not silent then
      trigger.action.outText(veaf.t("spawn.logistic_spawned", unitName), 15)
    end
    return unitName
  else
    trigger.action.outText(veaf.t("spawn.logistic_failed"), 15)
    return
  end
end

--- Spawn a specific cargo at a specific spot
function veafSpawn.doSpawnCargo(spawnSpot, radius, cargoType, country, weightBias, unitName, cargoSmoke, silent, hiddenOnMFD)
  local weightBias = weightBias or 2
  local radius = radius or 0
  veaf.loggers.get(veafSpawn.Id):debug("spawnCargo(cargoType = " .. cargoType .. ")")

  local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
  veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnCargo: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))

  local units = {}

  local spawnPosition = veaf.findPointInZone(spawnSpot)

  -- check spawned position validity
  if spawnPosition == nil then
    veaf.loggers.get(veafSpawn.Id):info("cannot find a suitable position for spawning cargo " .. cargoType)
    trigger.action.outText(veaf.t("spawn.no_position_cargo", cargoType), 5)
    return
  end

  veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnCargo: spawnPosition  x=%.1f y=%.1f", spawnPosition.x, spawnPosition.y))

  -- compute cargo weight
  local cargoWeight = 250
  local unit = veafUnits.findDcsUnit(cargoType)
  if not unit then
    cargoType = cargoType .. "_cargo"
    unit = veafUnits.findDcsUnit(cargoType)
  end
  if unit then
    if unit.type then
      cargoType = unit.type
    else
      veaf.loggers.get(veafSpawn.Id):info("could not find cargo type named " .. veaf.p(cargoType))
      trigger.action.outText(veaf.t("spawn.cargo_type_not_found", veaf.p(cargoType)), 15)
      return
    end

    veaf.loggers.get(veafSpawn.Id):debug(string.format("weightBias=%s", veaf.p(weightBias)))
    if unit.desc and unit.desc.minMass and unit.desc.maxMass then
      local weightScaleRange = veafSpawn.cargoWeightBiasRange + 1
      local massDelta = unit.desc.maxMass - unit.desc.minMass
      if massDelta < 0 then --never can be too careful around DCS
        local temp = unit.desc.maxMass
        unit.desc.maxMass = unit.desc.minMass
        unit.desc.minMass = temp
        massDelta = math.abs(massDelta)
      end
      local minMass = unit.desc.minMass + weightBias * massDelta / weightScaleRange
      local maxMass = unit.desc.minMass + (weightBias + 1) * massDelta / weightScaleRange
      veaf.loggers.get(veafSpawn.Id):debug(string.format("cargo minMass=%s, cargo maxMass=%s", veaf.p(minMass), veaf.p(maxMass)))
      cargoWeight = math.random(minMass, maxMass)
    elseif unit.defaultMass then
      local BiasOffset = -math.floor(veafSpawn.cargoWeightBiasRange / 2)
      local weightBiasCentered = weightBias + BiasOffset
      local cargoWeightBiasScaleMin = BiasOffset
      local cargoWeightBiasScaleMax = veafSpawn.cargoWeightBiasRange + BiasOffset
      local weightBiasMax = weightBiasCentered + 1
      local weightBiasMin = weightBiasCentered

      cargoWeight = unit.defaultMass
      veaf.loggers.get(veafSpawn.Id):debug(string.format("cargo defaultMass=%s", veaf.p(cargoWeight)))
      local minMass = cargoWeight + weightBiasMin * cargoWeight / (2 * cargoWeightBiasScaleMax)
      local maxMass = cargoWeight + weightBiasMax * cargoWeight / (2 * cargoWeightBiasScaleMax)
      veaf.loggers.get(veafSpawn.Id):debug(string.format("cargo minMass=%s, cargo maxMass=%s", veaf.p(minMass), veaf.p(maxMass)))
      cargoWeight = math.random(minMass, maxMass)
    end
    if cargoWeight then
      veaf.loggers.get(veafSpawn.Id):debug(string.format("cargo mass=%s", veaf.p(cargoWeight)))

      if not unitName then
        veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1
        unitName = unit.name .. " #" .. veafSpawn.spawnedUnitsCounter
      end

      -- create the cargo
      local cargoTable = {
        type = cargoType,
        country = country,
        category = "Cargos",
        name = unitName,
        x = spawnPosition.x,
        y = spawnPosition.y,
        canCargo = true,
        mass = cargoWeight,
        hiddenOnMFD = hiddenOnMFD,
      }

      mist.dynAddStatic(cargoTable)

      -- smoke the cargo if needed
      if cargoSmoke then
        local smokePosition = { x = spawnPosition.x + mist.random(10, 20), y = 0, z = spawnPosition.y + mist.random(10, 20) }
        local height = veaf.getLandHeight(smokePosition)
        smokePosition.y = height
        veaf.loggers
          .get(veafSpawn.Id)
          :trace(string.format("spawnCargo: smokePosition  x=%.1f y=%.1f z=%.1f", smokePosition.x, smokePosition.y, smokePosition.z))
        veafSpawn.spawnSmoke(smokePosition, trigger.smokeColor.GREEN)
        for i = 1, 10 do
          veaf.loggers.get(veafSpawn.Id):trace("Signal flare 1 at " .. timer.getTime() + i * 7)
          mist.scheduleFunction(veafSpawn.spawnSignalFlare, { smokePosition, nil, nil, trigger.flareColor.RED }, timer.getTime() + i * 3)
        end
      end

      -- message the unit spawning
      local message = veaf.t("spawn.cargo_spawned", unitName, cargoWeight)
      if cargoSmoke then
        message = message .. veaf.t("spawn.marked_smoke_flares")
      end
      if not silent then
        trigger.action.outText(message, 15)
      end
    end
  else
    veaf.loggers.get(veafSpawn.Id):info("could not find cargo type named " .. veaf.p(cargoType))
    trigger.action.outText(veaf.t("spawn.cargo_type_not_found", veaf.p(cargoType)), 15)
    return
  end
  return unitName
end

--- Spawn a specific static at a specific spot
function veafSpawn.doSpawnStatic(spawnSpot, radius, staticCategory, staticType, country, unitName, smoke, silent, hiddenOnMFD)
  veaf.loggers.get(veafSpawn.Id):debug("doSpawnStatic(staticCategory = " .. staticCategory .. ")")
  veaf.loggers.get(veafSpawn.Id):debug("doSpawnStatic(staticType = " .. staticType .. ")")

  local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
  veaf.loggers
    .get(veafSpawn.Id)
    :trace(string.format("doSpawnStatic: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))

  local units = {}

  local spawnPosition = veaf.findPointInZone(spawnSpot, 50, false)

  -- check spawned position validity
  if spawnPosition == nil then
    veaf.loggers.get(veafSpawn.Id):info("cannot find a suitable position for spawning static " .. staticType)
    if not silent then
      trigger.action.outText(veaf.t("spawn.no_position_static", staticType), 5)
    end
    return
  end

  veaf.loggers.get(veafSpawn.Id):trace(string.format("doSpawnStatic: spawnPosition  x=%.1f y=%.1f", spawnPosition.x, spawnPosition.y))

  local unit = veafUnits.findDcsUnit(staticType)
  if unit then
    if not unitName then
      veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1
      unitName = unit.name .. " #" .. veafSpawn.spawnedUnitsCounter
    end

    -- create the static
    local staticTable = {
      category = staticCategory,
      type = staticType,
      country = country,
      name = unitName,
      x = spawnPosition.x,
      y = spawnPosition.y,
      hiddenOnMFD = hiddenOnMFD,
    }

    mist.dynAddStatic(staticTable)

    -- smoke if needed
    if smoke then
      local smokePosition = { x = spawnPosition.x + mist.random(10, 20), y = 0, z = spawnPosition.y + mist.random(10, 20) }
      local height = veaf.getLandHeight(smokePosition)
      smokePosition.y = height
      veaf.loggers
        .get(veafSpawn.Id)
        :trace(string.format("doSpawnStatic: smokePosition  x=%.1f y=%.1f z=%.1f", smokePosition.x, smokePosition.y, smokePosition.z))
      veafSpawn.spawnSmoke(smokePosition, trigger.smokeColor.GREEN)
      for i = 1, 10 do
        veaf.loggers.get(veafSpawn.Id):trace("Signal flare 1 at " .. timer.getTime() + i * 7)
        mist.scheduleFunction(veafSpawn.spawnSignalFlare, { smokePosition, nil, nil, trigger.flareColor.RED }, timer.getTime() + i * 3)
      end
    end

    -- message the unit spawning
    local message = veaf.t("spawn.static_spawned", unitName)
    if smoke then
      message = message .. veaf.t("spawn.marked_smoke_flares")
    end
    if not silent then
      trigger.action.outText(message, 5)
    end
  end
  return unitName
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Smoke and Flare commands
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- trigger an explosion at the marker area
function veafSpawn.spawnBomb(spawnSpot, radius, shells, power, altitude, altitudedelta, password)
  veaf.loggers.get(veafSpawn.Id):debug("spawnBomb(power=" .. power .. ")")

  local shellTime = 0
  local shellDelay = 0
  for shell = 1, shells do
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
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
    mist.scheduleFunction(trigger.action.explosion, { spawnSpot, shellPower }, timer.getTime() + shellTime)
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
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnSpot=%s", veaf.vecToString(spawnSpot)))

    local shellDelay = veafSpawn.ShellingInterval * (math.random(100) + 30) / 100
    veaf.loggers.get(veafSpawn.Id):trace(string.format("shell #%d : shellTime=%d, shellDelay=%d", shell, shellTime, shellDelay))
    if shells > 1 then
      -- add a small explosion under the smoke to simulate smoke shells
      mist.scheduleFunction(trigger.action.explosion, { spawnSpot, 1 }, timer.getTime() + shellTime - 1)
    end
    mist.scheduleFunction(trigger.action.smoke, { spawnSpot, color }, timer.getTime() + shellTime)
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
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnSpot=%s", veaf.vecToString(spawnSpot)))

    local shellDelay = veafSpawn.ShellingInterval * (math.random(100) + 30) / 100
    local azimuth = math.random(359)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("shell #%d : shellTime=%d, shellDelay=%d", shell, shellTime, shellDelay))
    mist.scheduleFunction(trigger.action.signalFlare, { spawnSpot, color, azimuth }, timer.getTime() + shellTime)
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
    local headingRad = mist.utils.toRadian(heading)
    cosHeading = math.cos(headingRad)
    sinHeading = math.sin(headingRad)
  end

  local stepTime = 0
  for step = 1, steps do
    local stepDelay = veafSpawn.IlluminationShellingInterval * (math.random(100, 130) - 15) / 100
    local newSpawnSpot = mist.utils.deepCopy(spawnSpot)
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
      local newSpawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(newSpawnSpot, radius))
      newSpawnSpot.y = veaf.getLandHeight(newSpawnSpot) + shellHeight
      veaf.loggers.get(veafSpawn.Id):trace(string.format("shell #%d : shellHeight=%d, shellPower=%d", shell, shellHeight, shellPower))
      local time = timer.getTime() + stepTime + shellDelay
      -- add a small explosion under the flare to simulate flare shells
      mist.scheduleFunction(trigger.action.explosion, { newSpawnSpot, 0.1 }, time)
      mist.scheduleFunction(trigger.action.illuminationBomb, { newSpawnSpot, shellPower }, time)
    end
    stepTime = stepTime + stepDelay
  end
end

--- FLAK-related constants
veafSpawn.NB_OF_FLAKS_AT_DENSITY_1 = 30
veafSpawn.DEFAULT_FLAK_CLOUD_SIZE = 30
veafSpawn.DEFAULT_FLAK_POWER = 1
veafSpawn.DEFAULT_FLAK_REPEAT_DELAY = 0.2
veafSpawn.DEFAULT_FLAK_FIRE_DELAY = 0.1

function veafSpawn.destroyObjectWithFlak(object, power, density)
  veaf.loggers
    .get(veafSpawn.Id)
    :debug(string.format("veafSpawn.destroyObjectWithFlak(%s, %s, %s)", veaf.p(object), veaf.p(power), veaf.p(density)))
  veaf.loggers.get(veafSpawn.Id):trace(string.format("object=%s", veaf.p(object)))
  local _power = power or veafSpawn.DEFAULT_FLAK_POWER
  local _density = density or 1

  if object and object:isExist() then
    local point = object:getPoint()
    local positionForFlak = mist.vec.add(point, mist.vec.scalarMult(object:getVelocity(), veafSpawn.DEFAULT_FLAK_FIRE_DELAY))
    local nbFlaks = veafSpawn.NB_OF_FLAKS_AT_DENSITY_1 * _density
    veaf.loggers.get(veafSpawn.Id):trace(string.format("firing %d flak shells", nbFlaks))
    for i = 1, nbFlaks do
      local flakPoint = {
        x = point.x + (veafSpawn.DEFAULT_FLAK_CLOUD_SIZE * math.random(-100, 100) / 100),
        y = point.y + (veafSpawn.DEFAULT_FLAK_CLOUD_SIZE * math.random(-100, 100) / 100),
        z = point.z + (veafSpawn.DEFAULT_FLAK_CLOUD_SIZE * math.random(-100, 100) / 100),
      }
      --veaf.loggers.get(veafSpawn.Id):trace(string.format("flakPoint=%s", veaf.p(flakPoint)))
      trigger.action.explosion(flakPoint, _power)
    end

    -- reschedule to check if the object is destroyed
    veaf.loggers.get(veafSpawn.Id):trace(string.format("reschedule to check if the object is destroyed"))
    mist.scheduleFunction(
      veafSpawn.destroyObjectWithFlak,
      { object, power, density },
      timer.getTime() + veafSpawn.DEFAULT_FLAK_REPEAT_DELAY
    )
  end
end

--- destroy unit(s)
function veafSpawn.destroy(spawnSpot, radius, unitName)
  veaf.loggers.get(veafSpawn.Id):debug(string.format("destroy(radius=%s, unitName=%s)", tostring(radius), tostring(unitName)))
  veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnSpot=%s", veaf.p(spawnSpot)))
  if unitName then
    -- destroy a specific unit
    local cu = Unit.getByName(unitName)
    if cu then
      veaf.loggers.get(veafSpawn.Id):trace("destroy a specific unit")
      Unit.destroy(cu)
    end

    -- or a specific static
    local cs = StaticObject.getByName(unitName)
    if cs then
      veaf.loggers.get(veafSpawn.Id):trace("destroy a specific static")
      StaticObject.destroy(cs)
    end

    -- or a specific group
    local cg = Group.getByName(unitName)
    if cg then
      veaf.loggers.get(veafSpawn.Id):trace("destroy a specific group")
      Group.destroy(cg)
    end
  else
    -- radius based destruction
    veaf.loggers.get(veafSpawn.Id):trace("radius based destruction")
    local units = veaf.findUnitsInCircle(spawnSpot, radius or 150, true)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("units=%s", veaf.p(units)))
    if units then
      for name, _ in pairs(units) do
        -- try and find a  unit
        local unit = Unit.getByName(name)
        if unit then
          Unit.destroy(unit)
        else
          local staticUnit = StaticObject.getByName(name)
          if staticUnit then
            StaticObject.destroy(staticUnit)
          end
        end
      end
    end
  end
end

--- teleport group
function veafSpawn.teleport(spawnSpot, name, silent)
  veaf.loggers.get(veafSpawn.Id):debug("teleport(name = " .. name .. ")")
  local vars = { groupName = name, point = spawnSpot, action = "teleport" }
  local grp = mist.teleportToPoint(vars)
  if not silent then
    if grp then
      trigger.action.outText(veaf.t("spawn.teleported", name), 5)
    else
      trigger.action.outText(veaf.t("spawn.cannot_teleport", name), 5)
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Effects spawn command handlers
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSpawn.registerCommandHandler("cargo", "L9", function(eventPos, options, coalition, markId, bypassSecurity)
  local g = veafSpawn.spawnCargo(
    eventPos,
    options.radius,
    options.cargoType,
    options.country,
    options.cargoWeightBias,
    options.cargoSmoke,
    options.unitName,
    bypassSecurity,
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("logistic", "L9", function(eventPos, options, coalition, markId, bypassSecurity)
  local g = veafSpawn.spawnLogistic(eventPos, options.radius, options.country, bypassSecurity, not options.showMFD)
  return g, nil, false
end)

veafSpawn.registerCommandHandler("destroy", "L1", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.destroy(eventPos, options.radius, options.unitName)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("teleport", "L1", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.teleport(eventPos, options.name, bypassSecurity)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("bomb", "L1", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.spawnBomb(eventPos, options.radius, options.shells, options.power, options.altitude, options.altitudedelta, options.password)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("smoke", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.spawnSmoke(eventPos, options.smokeColor, options.radius, options.shells)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("flare", function(eventPos, options, coalition, markId, bypassSecurity)
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

veafSpawn.registerCommandHandler("signal", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.spawnSignalFlare(eventPos, options.radius, options.shells, options.smokeColor)
  return nil, nil, false
end)
