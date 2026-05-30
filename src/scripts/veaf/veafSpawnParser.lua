------------------------------------------------------------------
-- VEAF spawn text parser for DCS World
-- Extracted from veafSpawnCore.lua — parse spawn command text into options tables.
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSpawn.convertLaserToFreq(laser)
  veaf.loggers.get(veafSpawn.Id):trace(string.format("convertLaserToFreq(laser=%s)", tostring(laser)))
  local laser = tonumber(laser)
  if laser and laser >= 1111 and laser <= 1688 then
    local laserB = math.floor((laser - 1000) / 100)
    local laserCD = laser - 1000 - laserB * 100
    local frequency = tostring(30 + laserB + laserCD * 0.05)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("laserB=%s", tostring(laserB)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("laserCD=%s", tostring(laserCD)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("frequency=%s", tostring(frequency)))
    return frequency
  else
    return nil
  end
end

--- Extract keywords from mark text.
function veafSpawn.markTextAnalysis(text)
  veaf.loggers.get(veafSpawn.Id):trace(string.format("veafSpawn.markTextAnalysis(text=%s)", text))

  -- Option parameters extracted from the mark text.
  local options = {}

  -- common fields
  options.czName = nil
  options.name = ""
  options.unitName = nil
  options.country = nil
  options.side = nil
  options.altitude = 0
  options.altitudedelta = 0
  options.heading = 0
  options.multiplier = 1
  options.password = nil
  options.repeatCount = nil
  options.repeatDelay = nil
  options.delayedStart = 0
  options.showMFD = false
  options.AlarmState = 2
  options.disperse = 15

  -- Check for correct keywords.
  if text:lower():find(veafSpawn.SpawnKeyphrase .. " unit") then
    -- ground
    options.unit = true
    options.forceStatic = false
    options.immortal = false
    options.spacing = 5
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " afac") then
    -- air
    options.afac = true
    options.laserCode = 1688
    options.freq = veafSpawn.convertLaserToFreq(1688)
    options.mod = "fm"
    options.immortal = false
    --default country for the AFAC
    options.country = "USA"
    --default AFAC spawned
    options.name = "mq-9"
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " cap") then
    -- air
    options.cap = true
    options.speed = nil
    options.capradius = nil
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " group") then
    -- ground
    options.group = true
    options.forceStatic = false
    options.immortal = false
    options.spacing = 5
    options.size = math.random(7) + 8
    options.defense = math.random(5)
    options.armor = math.random(5)
    options.skynet = false
    options.forceEwr = false
    options.pointDefense = false
    options.isConvoy = false
    options.patrol = false
    options.offroad = false
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " farp") then
    -- ground
    options.farp = true
    options.noFarpMarkers = false
    options.type = nil
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " fob") then
    options.fob = true
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " convoy") then
    -- ground
    options.convoy = true
    options.size = 10
    options.defense = math.random(5)
    options.armor = math.random(5)
    options.spacing = 5
    options.isConvoy = false
    options.patrol = false
    options.offroad = false
    options.skynet = false
    options.forceEwr = false
    options.pointDefense = false
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " infantrygroup") then
    -- ground
    options.infantryGroup = true
    options.size = math.random(7) + 8
    options.defense = math.random(5)
    options.armor = math.random(5)
    options.spacing = 5
    options.skynet = false
    options.forceEwr = false
    options.pointDefense = false
    options.immortal = false
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " armorgroup") then
    -- ground
    options.armoredPlatoon = true
    options.size = math.random(7) + 8
    options.defense = math.random(5)
    options.armor = math.random(5)
    options.spacing = 5
    options.skynet = false
    options.forceEwr = false
    options.pointDefense = false
    options.immortal = false
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " samgroup") then
    -- ground
    options.airDefenseBattery = true
    options.size = math.random(7) + 8
    options.defense = math.random(5)
    options.armor = math.random(5)
    options.spacing = 5
    options.skynet = false
    options.forceEwr = false
    options.pointDefense = false
    options.immortal = false
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " transportgroup") then
    -- ground
    options.transportCompany = true
    options.size = math.random(2, 5)
    options.defense = math.random(5)
    options.armor = math.random(5)
    options.spacing = 5
    options.skynet = false
    options.forceEwr = false
    options.pointDefense = false
    options.immortal = false
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " combatgroup") then
    -- ground
    options.fullCombatGroup = true
    options.size = 1
    options.defense = math.random(5)
    options.armor = math.random(5)
    options.spacing = 5
    options.skynet = false
    options.forceEwr = false
    options.pointDefense = false
    options.immortal = false
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " smoke") then
    -- effects
    options.smoke = true
    options.smokeColor = trigger.smokeColor.RED
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " flare") then
    -- effects
    options.flare = true
    options.smokeColor = trigger.smokeColor.RED
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " signal") then
    -- effects
    options.signal = true
    options.smokeColor = trigger.smokeColor.RED
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " cargo") then
    -- cargo
    options.cargo = true
    options.cargoType = "container_cargo"
    options.cargoWeightBias = 2
    options.cargoSmoke = false
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " logistic") then
    -- cargo
    options.logistic = true
    options.cargoType = "container_cargo"
    options.cargoWeightBias = 2
    options.cargoSmoke = false
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " bomb") then
    -- effects
    options.bomb = true
    options.power = 100
    options.shells = 1
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " jtac") then
    options.role = "jtac"
    options.unit = true
    options.laserCode = 1688
    options.freq = veafSpawn.convertLaserToFreq(1688)
    options.mod = "fm"
    options.immortal = false
    options.spacing = 5
    -- default country for friendly JTAC: USA
    options.country = "USA"
    -- default name for JTAC
    options.name = "LUV HMMWV Jeep"
    -- default JTAC name (will overwrite previous unit with same name)
    options.unitName = "JTAC1"
  elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " tacan") then
    -- air
    options.role = "tacan"
    options.unit = true
    options.tacanChannel = nil
    options.tacanBand = nil
    options.immortal = false
    options.spacing = 5
    -- default country for friendly tacan: USA
    options.country = "USA"
    -- default name for tacan
    options.name = "TACAN_beacon"
    -- default name (will overwrite previous unit with same name)
    options.unitName = "TACAN TCN"
  elseif text:lower():find(veafSpawn.DestroyKeyphrase) then
    options.destroy = true
  elseif text:lower():find(veafSpawn.TeleportKeyphrase) then
    options.teleport = true
  elseif text:lower():find(veafSpawn.DrawingKeyphrase .. " add") then
    -- drawing
    options.addDrawing = true
    options.drawColor = nil
    options.drawFillColor = nil
    options.drawArrow = nil
  elseif text:lower():find(veafSpawn.DrawingKeyphrase .. " erase") then
    -- drawing
    options.eraseDrawing = true
  elseif text:lower():find(veafSpawn.DrawingKeyphrase .. " square") then
    -- drawing
    options.drawSquare = true
    options.drawColor = nil
    options.drawFillColor = nil
    options.drawArrow = nil
  elseif text:lower():find(veafSpawn.DrawingKeyphrase .. " circle") then
    -- drawing
    options.drawCircle = true
    options.drawColor = nil
    options.drawFillColor = nil
    options.drawArrow = nil
  elseif text:lower():find(veafSpawn.MissionMasterKeyphrase .. " flagon") then
    options.mmFlagOn = true
  elseif text:lower():find(veafSpawn.MissionMasterKeyphrase .. " flagoff") then
    options.mmFlagOff = true
  elseif text:lower():find(veafSpawn.MissionMasterKeyphrase .. " getflag") then
    options.mmGetFlag = true
  elseif text:lower():find(veafSpawn.MissionMasterKeyphrase .. " run") then
    options.mmRun = true
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

    if key:lower() == "unitname" then
      -- Set name.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword unitname = %s", tostring(val)))
      options.unitName = val
    end

    if key:lower() == "name" then
      -- Set name.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword name = %s", tostring(val)))
      options.name = val
    end

    if key:lower() == "czname" then
      -- Set name.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword czname = %s", tostring(val)))
      options.czName = val
    end

    if key:lower() == "destination" or key:lower() == "dest" then
      -- Set destination.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword destination = %s", tostring(val)))
      options.destination = val
      options.AlarmState = 0 --since some units will not move when they are told to have an alarm state red, it's best to by default leave it on auto. AI is pretty all knowing anyways, it knows when it should go to red state
      options.spacing = 1 --compress the convoy to not make it extremely long at departure
      options.radius = 1 --convoy spawns on the marker exactly to not have them spawn in trees etc.
    end

    if key:lower() == "isconvoy" then
      veaf.loggers.get(veafSpawn.Id):trace("Keyword isconvoy found")
      options.convoy = true
    end

    if key:lower() == "patrol" then
      veaf.loggers.get(veafSpawn.Id):trace("Keyword patrol found")
      options.patrol = true
    end

    if key:lower() == "offroad" then
      veaf.loggers.get(veafSpawn.Id):trace("Keyword offroad found")
      options.offroad = true
    end

    if key:lower() == "skynet" then
      -- Retreive the name of the IADS you wish to add the spawned group to
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword skynet = %s", tostring(val)))
      options.skynet = val:lower()
      if options.skynet == "" or options.skynet == "true" then
        options.skynet = true
      elseif options.skynet == "false" then
        options.skynet = false
      end
    end

    if key:lower() == "ewr" then
      -- Set force IADS EWR toggle for unit spawn
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword ewr found"))
      options.forceEwr = true
    end

    if key:lower() == "pointdefense" then
      -- Tells IADS to add the spawned SAM to the point defenses of the specified site or to the nearest site
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword pointdefense found"))
      options.pointDefense = true
      if val ~= "" then
        veaf.loggers.get(veafSpawn.Id):trace(string.format("groupName specified : %s", tostring(val)))
        options.pointDefense = tostring(val)
      end
    end

    --to be placed after the skynet input, SAMs in the skynet network work better if set to AlarmState RED, so AlarmState is equal to 2 if skynet is enabled
    if key:lower() == "alarm" then
      -- Set Alarm State of the unit to be spawned
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword alarm = %s", tostring(val)))
      if (val == "0" or val == "2" or val == "1") and not options.skynet then
        options.AlarmState = tonumber(val)
      end
    end

    if key:lower() == "radius" then
      -- Set name.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword radius = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.radius = nVal
    end

    if key:lower() == "spacing" then
      -- Set spacing.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword spacing = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.spacing = nVal
    end

    if key:lower() == "multiplier" then
      -- Set multiplier.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword multiplier = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.multiplier = nVal
    end

    if key:lower() == "alt" then
      -- Set altitude.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword alt = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.altitude = nVal
    end

    if key:lower() == "altdelta" then
      -- Set altitude delta.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword altdelta = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.altitudedelta = nVal
    end

    if key:lower() == "speed" then
      -- Set speed.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword speed = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.speed = nVal
    end

    if key:lower() == "capradius" then
      -- Set capradius.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword capradius = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.capradius = nVal
    end

    if key:lower() == "shells" then
      -- Set altitude.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword shells = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.shells = nVal
    end

    if key:lower() == "hdg" then
      -- Set heading.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword hdg = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.heading = nVal
    end

    if key:lower() == "heading" then
      -- Set heading.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword heading = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.heading = nVal
    end

    if key:lower() == "country" then
      -- Set country
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword country = %s", tostring(val)))
      options.country = val:upper()
    end

    if key:lower() == "side" then
      -- Set side
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword side = %s", tostring(val)))
      if val:upper() == "BLUE" then
        options.side = veafCasMission.SIDE_BLUE
      else
        options.side = veafCasMission.SIDE_RED
      end
    end

    if key:lower() == "password" then
      -- Unlock the command
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword password", tostring(val)))
      options.password = val
    end

    if key:lower() == "power" then
      -- Set bomb power.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword power = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.power = nVal
    end

    if key:lower() == "laser" then
      -- Set laser code.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("laser code = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.freq = veafSpawn.convertLaserToFreq(nVal)
      options.laserCode = nVal
    end

    if key:lower() == "freq" then
      -- Set JTAC/AFAC frequency.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("freq = %s", tostring(val)))
      options.freq = val
    end

    if key:lower() == "mod" then
      -- Set JTAC/AFAC modulation.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("mod = %s", tostring(val)))
      options.mod = val
    end

    if key:lower() == "band" then
      -- Set TACAN band
      veaf.loggers.get(veafSpawn.Id):trace(string.format("band = %s", tostring(val)))
      options.tacanBand = val
    end

    if key:lower() == "code" then
      -- Set TACAN code
      veaf.loggers.get(veafSpawn.Id):trace(string.format("code = %s", tostring(val)))
      options.tacanCode = val
    end

    if key:lower() == "channel" then
      -- Set TACAN channel.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("channel = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.tacanChannel = nVal
    end

    if key:lower() == "arrow" then
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword arrow = %s", tostring(val)))
      options.drawArrow = true
    end
    if key:lower() == "fill" then
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword fill = %s", tostring(val)))
      options.drawFillColor = val
    end

    if key:lower() == "color" then
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword color = %s", tostring(val)))
      options.drawColor = val
      -- Set smoke color.
      if val:lower() == "red" then
        options.smokeColor = trigger.smokeColor.RED
      elseif val:lower() == "green" then
        options.smokeColor = trigger.smokeColor.GREEN
      elseif val:lower() == "orange" then
        options.smokeColor = trigger.smokeColor.ORANGE
      elseif val:lower() == "blue" then
        options.smokeColor = trigger.smokeColor.BLUE
      elseif val:lower() == "white" then
        options.smokeColor = trigger.smokeColor.WHITE
      end
    end

    if key:lower() == "skill" then
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword skill = %s", tostring(val)))
      options.skill = val
    end

    if key:lower() == "dist" or key:lower() == "distance" then
      -- Set distance.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword distance = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.distance = nVal
    end

    if options.cargo and key:lower() == "name" then
      -- Set cargo type.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword name = %s", tostring(val)))
      options.cargoType = val
    end

    if options.cargo and key:lower() == "weight" then
      -- Set cargo type.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword weight = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      if nVal >= 0 and nVal <= veafSpawn.cargoWeightBiasRange then
        options.cargoWeightBias = nVal
      elseif nVal > veafSpawn.cargoWeightBiasRange then
        options.cargoWeightBias = veafSpawn.cargoWeightBiasRange
      elseif nVal < 0 then
        options.cargoWeightBias = 0
      end
    end

    if key:lower() == "type" then
      -- Set farp type.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword type = %s", tostring(val)))
      options.type = val
    end

    if options.farp and key:lower() == "nofarpmarkers" then
      -- Skip the invisible FARP special vehicles that mark the position of the FARP
      veaf.loggers.get(veafSpawn.Id):trace("Keyword noFarpMarkers is set")
      options.noFarpMarkers = true
    end

    if options.cargo and key:lower() == "smoke" then
      -- Mark with green smoke.
      veaf.loggers.get(veafSpawn.Id):trace("Keyword smoke is set")
      options.cargoSmoke = true
    end

    if key:lower() == "size" then
      -- Set size.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword size = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.size = nVal
    end

    if key:lower() == "defense" then
      -- Set defense.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword defense = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      if nVal >= 0 then
        options.defense = nVal
      end
    end

    if key:lower() == "armor" then
      -- Set armor.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword armor = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      if nVal >= 0 then
        options.armor = nVal
      end
    end

    if key:lower() == "repeat" then
      -- Set repeat count.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword repeat = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.repeatCount = nVal
    end

    if key:lower() == "delay" then
      -- Set delay.
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword delay = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      options.repeatDelay = nVal
    end

    if key:lower() == "static" then
      -- Set static unit spawn toggle
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword static found"))
      options.forceStatic = true
    end

    if key:lower() == "immortal" then
      -- Set spawned unit to invisible and immortal
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword immortal found"))
      options.immortal = true
    end

    if key:lower() == "delayed" then
      -- Set delayed start on first spawn occurence
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword delayed = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      if nVal >= 0 then
        options.delayedStart = nVal
      else
        options.delayedStart = veafSpawn.MIN_REPEAT_DELAY
      end
    end

    if key:lower() == "showmfd" then
      -- Set hiddenOnMFD option or not
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword showmfd found"))
      options.showMFD = true
    end

    if key:lower() == "disperse" then
      -- Set hiddenOnMFD option or not
      veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword disperse = %s", tostring(val)))
      local nVal = veaf.getRandomizableNumeric(val)
      if nVal >= 0 then
        options.disperse = nVal
      end
    end
  end

  -- check mandatory parameter "name" for command "group"
  if options.group and (not options.name or options.name == "") then
    return nil
  end

  -- check mandatory parameter "name" for command "unit"
  if options.unit and (not options.name or options.name == "") then
    return nil
  end

  -- check mandatory parameter "name" for all mission master commands
  if (options.mmFlagOff or options.mmFlagOn or options.mmRun) and (not options.name or options.name == "") then
    return nil
  end

  return options
end
