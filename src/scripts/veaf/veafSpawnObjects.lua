------------------------------------------------------------------
-- VEAF spawn command and functions for DCS World
-- Objects spawn sub-module: cargo, logistic, static, teleport, destroy
-- What creates, moves or removes something that stays in the world.
-- Split out of veafSpawnEffects.lua (CHORE-RENAME-SPAWN-EFFECTS)
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
    if veaf.isCtldReady() then
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

  local spawnSpot = veaf.placePointOnLand(veaf.getRandomPointInCircle(spawnSpot, radius))
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
      -- VMR-100: reorder the bounds locally. `findDcsUnit` hands back the live
      -- dcsUnits.DcsUnitsDatabase entry, so swapping the fields in place edited the shared
      -- units database for the rest of the mission — never can be too careful around DCS,
      -- but the caution belongs in our own locals.
      local lowMass = math.min(unit.desc.minMass, unit.desc.maxMass)
      local massDelta = math.abs(unit.desc.maxMass - unit.desc.minMass)
      local minMass = lowMass + weightBias * massDelta / weightScaleRange
      local maxMass = lowMass + (weightBias + 1) * massDelta / weightScaleRange
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

      veaf.addStatic(cargoTable)

      -- smoke the cargo if needed
      if cargoSmoke then
        local smokePosition = { x = spawnPosition.x + math.random(10, 20), y = 0, z = spawnPosition.y + math.random(10, 20) }
        local height = veaf.getLandHeight(smokePosition)
        smokePosition.y = height
        veaf.loggers
          .get(veafSpawn.Id)
          :trace(string.format("spawnCargo: smokePosition  x=%.1f y=%.1f z=%.1f", smokePosition.x, smokePosition.y, smokePosition.z))
        veafSpawn.spawnSmoke(smokePosition, trigger.smokeColor.GREEN)
        for i = 1, 10 do
          veaf.loggers.get(veafSpawn.Id):trace("Signal flare 1 at " .. timer.getTime() + i * 7)
          veaf.scheduleFunction(veafSpawn.spawnSignalFlare, { smokePosition, nil, nil, trigger.flareColor.RED }, timer.getTime() + i * 3)
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

  local spawnSpot = veaf.placePointOnLand(veaf.getRandomPointInCircle(spawnSpot, radius))
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

    veaf.addStatic(staticTable)

    -- smoke if needed
    if smoke then
      local smokePosition = { x = spawnPosition.x + math.random(10, 20), y = 0, z = spawnPosition.y + math.random(10, 20) }
      local height = veaf.getLandHeight(smokePosition)
      smokePosition.y = height
      veaf.loggers
        .get(veafSpawn.Id)
        :trace(string.format("doSpawnStatic: smokePosition  x=%.1f y=%.1f z=%.1f", smokePosition.x, smokePosition.y, smokePosition.z))
      veafSpawn.spawnSmoke(smokePosition, trigger.smokeColor.GREEN)
      for i = 1, 10 do
        veaf.loggers.get(veafSpawn.Id):trace("Signal flare 1 at " .. timer.getTime() + i * 7)
        veaf.scheduleFunction(veafSpawn.spawnSignalFlare, { smokePosition, nil, nil, trigger.flareColor.RED }, timer.getTime() + i * 3)
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
    local positionForFlak = veaf.vecAdd(point, veaf.vecScalarMult(object:getVelocity(), veafSpawn.DEFAULT_FLAK_FIRE_DELAY))
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
    veaf.scheduleFunction(
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
  local grp = VeafGroupSpawn:new():forGroup(name):at(spawnSpot):teleport()
  if not silent then
    if grp then
      trigger.action.outText(veaf.t("spawn.teleported", name), 5)
    else
      trigger.action.outText(veaf.t("spawn.cannot_teleport", name), 5)
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Objects spawn command handlers
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSpawn.registerCommandHandler("cargo", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
  local g = veafSpawn.spawnCargo(
    eventPos,
    options.radius,
    options.cargoType,
    options.country,
    options.cargoWeightBias,
    options.cargoSmoke,
    options.unitName,
    options.silent,
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("logistic", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
  local g = veafSpawn.spawnLogistic(eventPos, options.radius, options.country, options.silent, not options.showMFD)
  return g, nil, false
end)

veafSpawn.registerCommandHandler("destroy", "SENIOR_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.destroy(eventPos, options.radius, options.unitName)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("teleport", "SENIOR_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
  veafSpawn.teleport(eventPos, options.name, options.silent)
  return nil, nil, false
end)
