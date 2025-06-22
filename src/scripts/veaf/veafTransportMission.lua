------------------------------------------------------------------
-- VEAF transport mission command and functions for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Listen to marker change events and creates a transport training mission, with optional parameters
-- * Possibilities :
-- *    - create a zone with cargo to pick up, another with friendly troops awaiting their cargo, and optionaly enemy units on the way
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafTransportMission = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafTransportMission.Id = "TRANSPORTMISSION"

--- Version.
veafTransportMission.Version = "1.8.0"

-- trace level, specific to this module
--veafTransportMission.LogLevel = "trace"

veaf.loggers.new(veafTransportMission.Id, veafTransportMission.LogLevel)

--- Key phrase to look for in the mark text which triggers the command.
veafTransportMission.Keyphrase = "_transport"

veafTransportMission.CargoTypes = {"ammo_cargo", "barrels_cargo", "m117_cargo", "oiltank_cargo", "uh1h_cargo" } --, "container_cargo", "fueltank_cargo" }

--- Number of seconds between each check of the friendly group ADF loop function
veafTransportMission.SecondsBetweenAdfLoops = 30

--- Number of seconds between each check of the friendly group watchdog function
veafTransportMission.SecondsBetweenWatchdogChecks = 15

--- Number of seconds between each smoke request on the target
veafTransportMission.SecondsBetweenSmokeRequests = 180

--- Number of seconds between each flare request on the target
veafTransportMission.SecondsBetweenFlareRequests = 120

--- Name of the friendly group that waits for the cargo
veafTransportMission.BlueGroupName = "Transport - Allied Group"

--- Name of the cargo units
veafTransportMission.BlueCargoName = "Cargo - Cargo unit"

--- Name of the enemy group that defends the way to the friendlies
veafTransportMission.RedDefenseGroupName = "Cargo - Enemy Air Defense Group"

--- Name of the enemy group that blocades the friendlies
veafTransportMission.RedBlocadeGroupName = "Cargo - Enemy Blocade Group"

veafTransportMission.RadioMenuName = "TRANSPORT MISSION"

veafTransportMission.AdfRadioSound = "l10n/DEFAULT/beacon.ogg"

veafTransportMission.AdfFrequency = 550000 -- in hz

veafTransportMission.AdfPower = 1000 -- in Watt

veafTransportMission.DoRadioTransmission = false -- set to true when radio transmissions will work

-- minimum authorized route distance ; missions shorter than this will not be authorized
veafTransportMission.MinimumRouteDistance = 15000 -- 15 km

-- size of the safe zone (no enemy group before this distance, in % of the total distance)
veafTransportMission.SafeZoneDistance = 0.6 -- 60%

-- size of the sqfe zone near drop zone (no enemy group after this distance from the drop zone)
veafTransportMission.DropZoneSafeZoneDistance = 5000 -- 5 km

-- an enemy group every xxx meters of the way (randomized)
veafTransportMission.EnemyDefenseDistanceStep = 3000 

-- enemies groups generated along the way are offset to xxx meters max (left or right, randomized)
veafTransportMission.LeftOrRightMaxOffset = 1500

-- enemies groups generated along the way are offset to xxx meters min (left or right, randomized)
veafTransportMission.LeftOrRightMinOffset = 500

-- enemies groups generated far from the way are offset to xxx meters max (left or right, randomized)
veafTransportMission.LeftOrRightMaxFarOffset = 7000

-- enemies groups generated far from the way are offset to xxx meters min (left or right, randomized)
veafTransportMission.LeftOrRightMinFarOffset = 3000

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Friendly group watchdog function id
veafTransportMission.friendlyGroupAliveCheckTaskID = 'none'

-- Friendly group ADF transmission loop function id
veafTransportMission.friendlyGroupAdfLoopTaskID = 'none'

--- Radio menus paths
veafTransportMission.targetMarkersPath = nil
veafTransportMission.targetInfoPath = nil
veafTransportMission.rootPath = nil

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafTransportMission.onEventMarkChange(eventPos, event)
    -- Check if marker has a text and the veafTransportMission.keyphrase keyphrase.
    if event.text ~= nil and event.text:lower():find(veafTransportMission.Keyphrase) then

        -- Analyse the mark point text and extract the keywords.
        local options = veafTransportMission.markTextAnalysis(event.text)

        if options then
            -- Check options commands
            if options.transportmission then
                -- check security
                if not veafSecurity.checkSecurity_L1(options.password) then return end
                -- create the mission
                veafTransportMission.generateTransportMission(eventPos, options.size, options.defense, options.blocade, options.from)
            end
        else
            -- None of the keywords matched.
            return
        end

        -- Delete old mark.
        veaf.loggers.get(veafTransportMission.Id):trace(string.format("Removing mark # %d.", event.idx))
        trigger.action.removeMark(event.idx)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Extract keywords from mark text.
function veafTransportMission.markTextAnalysis(text)

    -- Option parameters extracted from the mark text.
    local switch = {}
    switch.transportmission = false

    -- size ; number of cargo to be transported
    switch.size = 1

    -- defense [1-5] : air defense cover on the way (1 = light, 5 = heavy)
    switch.defense = 0

    -- blocade [1-5] : enemy blocade around the drop zone (1 = light, 5 = heavy)
    switch.blocade = 0

    -- start position, named point
    switch.from = nil

    -- password
    switch.password = nil

    -- Check for correct keywords.
    if text:lower():find(veafTransportMission.Keyphrase) then
        switch.transportmission = true
    else
        return nil
    end

    -- keywords are split by ","
    local keywords = veaf.split(text, ",")

    for _, keyphrase in pairs(keywords) do
        -- Split keyphrase by space. First one is the key and second, ... the parameter(s) until the next comma.
        local str = veaf.breakString(veaf.trim(keyphrase), " ")
        local key = str[1]
        local val = str[2]

        if key:lower() == "password" then
            -- Unlock the command
            veaf.loggers.get(veafTransportMission.Id):debug(string.format("Keyword password", val))
            switch.password = val
        end

        if switch.transportmission and key:lower() == "size" then
            -- Set size.
            veaf.loggers.get(veafTransportMission.Id):debug(string.format("Keyword size = %d", val))
            local nVal = tonumber(val)
            if nVal <= 5 and nVal >= 1 then
                switch.size = nVal
            end
        end

        if switch.transportmission and key:lower() == "defense" then
            -- Set defense.
            veaf.loggers.get(veafTransportMission.Id):debug(string.format("Keyword defense = %d", val))
            local nVal = tonumber(val)
            if nVal <= 5 and nVal >= 0 then
                switch.defense = nVal
            end
        end

        if switch.transportmission and key:lower() == "blocade" then
            -- Set blocade.
            veaf.loggers.get(veafTransportMission.Id):debug(string.format("Keyword blocade = %d", val))
            local nVal = tonumber(val)
            if nVal <= 5 and nVal >= 0 then
                switch.blocade = nVal
            end
        end

        if switch.transportmission and key:lower() == "from" then
            -- Set armor.
            veaf.loggers.get(veafTransportMission.Id):debug(string.format("Keyword from = %s", val))
            switch.from = val
        end
    end

    return switch
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CAS target group generation and management
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafTransportMission.doRadioTransmission(groupName)
    veaf.loggers.get(veafTransportMission.Id):trace("doRadioTransmission("..groupName..")")
    local group = Group.getByName(groupName)
    if group then
        veaf.loggers.get(veafTransportMission.Id):trace("Group is transmitting")
        local averageGroupPosition = veaf.getAveragePosition(groupName)
        veaf.loggers.get(veafTransportMission.Id):trace("averageGroupPosition=" .. veaf.vecToString(averageGroupPosition))
        trigger.action.radioTransmission(veafTransportMission.AdfRadioSound, averageGroupPosition, 0, false, veafTransportMission.AdfFrequency, veafTransportMission.AdfPower)
    end
    
    veafTransportMission.friendlyGroupAdfLoopTaskID = mist.scheduleFunction(veafTransportMission.doRadioTransmission, { groupName }, timer.getTime() + veafTransportMission.SecondsBetweenAdfLoops)
end

function veafTransportMission.generateFriendlyGroup(groupPosition)
    veafSpawn.doSpawnGroup(groupPosition, 0, "US infgroup", nil, "USA", 0, 0, 0, veafTransportMission.BlueGroupName, true, false, true, true)

    if veafTransportMission.DoRadioTransmission then
        veafTransportMission.doRadioTransmission(veafTransportMission.BlueGroupName)
    end
end

--- Generates an enemy defense group on the way to the drop zone
--- defenseLevel = 1 : 3-7 soldiers, GAZ-3308 transport
--- defenseLevel = 2 : 3-7 soldiers, BTR-80 APC
--- defenseLevel = 3 : 3-7 soldiers, chance of BMP-1 IFV, chance of Igla manpad
--- defenseLevel = 4 : 3-7 soldiers, big chance of BMP-1 IFV, big chance of Igla-S manpad, chance of ZU-23 on a truck
--- defenseLevel = 5 : 3-7 soldiers, BMP-1 IFV, big chance of Igla-S manpad, chance of ZSU-23-4 Shilka
function veafTransportMission.generateEnemyDefenseGroup(groupPosition, groupName, defenseLevel)
    local groupDefinition = {
            disposition = { h = 6, w = 6},
            units = {},
            description = groupName,
            groupName = groupName,
        }

    -- generate an infantry group
    local groupCount = math.random(3, 7)
    for _ = 1, groupCount do
        local rand = math.random(3)
        local unitType = nil
        if rand == 1 then
            unitType = 'Soldier RPG'
        elseif rand == 2 then
            unitType = 'Soldier AK'
        else
            unitType = 'Infantry AK'
        end
        table.insert(groupDefinition.units, { unitType })
    end

    -- add a transport vehicle or an APC/IFV
    if defenseLevel > 4 or (defenseLevel > 3 and math.random(100) > 33) or (defenseLevel > 2 and math.random(100) > 66) then
        table.insert(groupDefinition.units, { "BMP-1", cell=11, random = true })
    elseif defenseLevel > 1 then
        table.insert(groupDefinition.units, { "BTR-80", cell=11, random = true })
    else
        table.insert(groupDefinition.units, { "GAZ-3308", cell=11, random = true })
    end

    -- add manpads if needed
    if defenseLevel > 3 and math.random(100) > 33 then
        -- for defenseLevel = 4-5, spawn a modern Igla-S team
        table.insert(groupDefinition.units, { "SA-18 Igla-S comm", random = true })
        table.insert(groupDefinition.units, { "SA-18 Igla-S manpad", random = true })
    elseif defenseLevel > 2 and math.random(100) > 66 then
        -- for defenseLevel = 3, spawn an older Igla team
        table.insert(groupDefinition.units, { "SA-18 Igla comm", random = true })
        table.insert(groupDefinition.units, { "SA-18 Igla manpad", random = true })
    else
        -- for defenseLevel = 0, don't spawn any manpad
    end

    -- add an air defenseLevel vehicle
    if defenseLevel > 4 and math.random(100) > 66 then
        -- defenseLevel = 3-5 : add a Shilka
        table.insert(groupDefinition.units, { "ZSU-23-4 Shilka", cell = 3, random = true })
    elseif defenseLevel > 3 and math.random(100) > 66 then
        -- defenseLevel = 1 : add a ZU23 on a truck
        table.insert(groupDefinition.units, { "Ural-375 ZU-23", cell = 3, random = true })
    end

    groupDefinition = veafUnits.processGroup(groupDefinition)
    veafSpawn.doSpawnGroup(groupPosition, 0, groupDefinition, nil, "RUSSIA", 0, math.random(359), math.random(3,6), groupName, true, false, true, true)
end


--- Generates a transport mission
function veafTransportMission.generateTransportMission(targetSpot, size, defense, blocade, from)
    veaf.loggers.get(veafTransportMission.Id):debug("generateTransportMission(size = %s, defense=%s, blocade=%d, from=%s)", veaf.p(size), veaf.p(defense), veaf.p(blocade), veaf.p(from))
    veaf.loggers.get(veafTransportMission.Id):debug("generateTransportMission: targetSpot ", veaf.p(targetSpot))

    if veafTransportMission.friendlyGroupAliveCheckTaskID ~= 'none' then
        trigger.action.outText("A transport mission already exists !", 5)
        return
    end

    if not from then
        trigger.action.outText("The \"from\" keyword is mandatory !", 5)
        return
    end

    local startPoint = veafNamedPoints.getPoint(from)
    if not(startPoint) then
        trigger.action.outText("A point named "..from.." cannot be found !", 5)
        return
    end
    
    local friendlyUnits = {}
    local routeDistance = 0

    -- generate a friendly group around the target target spot
    local groupPosition = veaf.findPointInZone(targetSpot, 100, false)
    if groupPosition ~= nil then
        veaf.loggers.get(veafTransportMission.Id):trace("groupPosition=" .. veaf.vecToString(groupPosition))
        groupPosition = { x = groupPosition.x, z = groupPosition.y, y = 0 }
        groupPosition = veaf.placePointOnLand(groupPosition)
        veaf.loggers.get(veafTransportMission.Id):trace("groupPosition on land=" .. veaf.vecToString(groupPosition))

        -- compute player route to friendly group
        local vecAB = {x = groupPosition.x +- startPoint.x, y = 0, z = groupPosition.z - startPoint.z}
        routeDistance = mist.vec.mag(vecAB)
        veaf.loggers.get(veafTransportMission.Id):trace("routeDistance="..routeDistance)
        if routeDistance < veafTransportMission.MinimumRouteDistance then
            trigger.action.outText("This drop zone is too close ; you have to place it at least " .. veafTransportMission.MinimumRouteDistance / 1000 .. " km away from point "..from.." !", 5)
            return
        end

        veafTransportMission.generateFriendlyGroup(groupPosition)
    else
        veaf.loggers.get(veafTransportMission.Id):info("cannot find a suitable position for friendly group")
        return
    end

    -- generate cargo to be picked up near the player helo
    veaf.loggers.get(veafTransportMission.Id):debug("Generating cargo")
    local startPosition = veaf.placePointOnLand(startPoint)
    veaf.loggers.get(veafTransportMission.Id):trace("startPosition=" .. veaf.vecToString(startPosition))
    for i = 1, size do
        local spawnSpot = { x = startPosition.x + 50, z = startPosition.z + i * 10, y = startPosition.y }
        veaf.loggers.get(veafTransportMission.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))
        local cargoType = veafTransportMission.CargoTypes[math.random(#veafTransportMission.CargoTypes)]
        local cargoName = veafTransportMission.BlueCargoName .. " #" .. i
        veafSpawn.doSpawnCargo(spawnSpot, 0, cargoType, "USA")
    end
    veaf.loggers.get(veafTransportMission.Id):debug("Done generating cargo")

    -- generate enemy air defense on the way
    if defense > 0 then
        veaf.loggers.get(veafTransportMission.Id):debug("Generating air defense")

         -- place groups on the way
         local startingDistance = routeDistance * veafTransportMission.SafeZoneDistance -- enemy presence start after the safe zone
         local defendedDistance = routeDistance - veafTransportMission.DropZoneSafeZoneDistance - startingDistance
         local distanceStep = veafTransportMission.EnemyDefenseDistanceStep
         local nbSteps = math.floor(defendedDistance / distanceStep) 
         local groupNum = 1
         for stepNum = 1, nbSteps do
            local distanceFromStartingPoint = startingDistance + stepNum * distanceStep + math.random(distanceStep/5, 4*distanceStep/5)
            veaf.loggers.get(veafTransportMission.Id):trace("distanceFromStartingPoint="..distanceFromStartingPoint)

            -- place an enemy defense group along the way
            local offset = math.random(veafTransportMission.LeftOrRightMinOffset, veafTransportMission.LeftOrRightMaxOffset)
            if math.random(100) < 51 then 
               offset = -offset 
            end
            veaf.loggers.get(veafTransportMission.Id):trace("offset="..offset)
            local spawnPoint = veaf.computeCoordinatesOffsetFromRoute(startPoint, groupPosition, distanceFromStartingPoint, offset)
            local groupName = veafTransportMission.RedDefenseGroupName .. " #"  .. groupNum
            veafTransportMission.generateEnemyDefenseGroup(spawnPoint, groupName, defense)
            groupNum = groupNum + 1

            -- place a random number of defense groups further away
            local nbFarGroups = math.random(0,1)
            if defense > 4 then 
                nbFarGroups = math.random(1,3)
            end
            for _ = 1, nbFarGroups do
                local offset = math.random(veafTransportMission.LeftOrRightMinFarOffset, veafTransportMission.LeftOrRightMaxFarOffset)
                if math.random(100) < 51 then 
                   offset = -offset 
                end
                veaf.loggers.get(veafTransportMission.Id):trace("offset="..offset)
                local spawnPoint = veaf.computeCoordinatesOffsetFromRoute(startPoint, groupPosition, distanceFromStartingPoint, offset)
                local groupName = veafTransportMission.RedDefenseGroupName .. " #"  .. groupNum
                veafTransportMission.generateEnemyDefenseGroup(spawnPoint, groupName, defense)
                groupNum = groupNum + 1
            end

         end

        veaf.loggers.get(veafTransportMission.Id):debug("Done generating air defense")
    end

    -- generate enemy blocade forces
    if blocade > 0 then
        veaf.loggers.get(veafTransportMission.Id):debug("Generating blocade")
        -- TODO
        veaf.loggers.get(veafTransportMission.Id):debug("Done generating blocade")
    end

    -- add radio menu for drop zone information (by player group)
    veafRadio.addCommandToSubmenu('Drop zone information', veafTransportMission.rootPath, veafTransportMission.reportTargetInformation, nil, veafRadio.USAGE_ForGroup)

    -- add radio menus for commands
    veafRadio.addSecuredCommandToSubmenu('Skip current objective', veafTransportMission.rootPath, veafTransportMission.skip)
    veafTransportMission.targetMarkersPath = veafRadio.addSubMenu("Drop zone markers", veafTransportMission.rootPath)
    veafRadio.addCommandToSubmenu('Request smoke on drop zone', veafTransportMission.targetMarkersPath, veafTransportMission.smokeTarget)
    veafRadio.addCommandToSubmenu('Request illumination flare over drop zone', veafTransportMission.targetMarkersPath, veafTransportMission.flareTarget)

    local message = "See F10 radio menu for details\n" -- TODO
    trigger.action.outText(message,5)
    
    veafRadio.refreshRadioMenu()
    
    -- start checking for targets destruction
    veafTransportMission.friendlyGroupWatchdog()
end

--- Checks if the friendly group is still alive, and if not announces the failure of the transport mission
function veafTransportMission.friendlyGroupWatchdog() 
    local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(veafTransportMission.BlueGroupName)
    if nbVehicles + nbInfantry > 0 then
        ----veaf.loggers.get(veafTransportMission.Id):trace("Group is still alive with "..nbVehicles.." vehicles and "..nbInfantry.." soldiers")
        veafTransportMission.friendlyGroupAliveCheckTaskID = mist.scheduleFunction(veafTransportMission.friendlyGroupWatchdog,{},timer.getTime()+veafTransportMission.SecondsBetweenWatchdogChecks)
    else
        trigger.action.outText("Friendly group has been destroyed! The mission is a failure!", 5)
        veafTransportMission.cleanupAfterMission()
    end
end

function veafTransportMission.reportTargetInformation(unitName)
    -- generate information dispatch
    local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(veafTransportMission.BlueGroupName)

    local message =      "DROP ZONE : ressuply a group of " .. nbVehicles .. " vehicles and " .. nbInfantry .. " soldiers.\n"
    message = message .. "\n"
    if veafTransportMission.DoRadioTransmission then 
        message = message .. "NAVIGATION: They will transmit on 550 kHz every " .. veafTransportMission.SecondsBetweenAdfLoops .. " seconds.\n"
    end

    -- add coordinates and position from bullseye
    local averageGroupPosition = veaf.getAveragePosition(veafTransportMission.BlueGroupName)
    local lat, lon = coord.LOtoLL(averageGroupPosition)
    local mgrsString = mist.tostringMGRS(coord.LLtoMGRS(lat, lon), 3)
    local bullseye = mist.utils.makeVec3(mist.DBs.missionData.bullseye.blue, 0)
    local vec = {x = averageGroupPosition.x - bullseye.x, y = averageGroupPosition.y - bullseye.y, z = averageGroupPosition.z - bullseye.z}
    local dir = mist.utils.round(mist.utils.toDegree(mist.utils.getDir(vec, bullseye)), 0)
    local dist = mist.utils.get2DDist(averageGroupPosition, bullseye)
    local distMetric = mist.utils.round(dist/1000, 0)
    local distImperial = mist.utils.round(mist.utils.metersToNM(dist), 0)
    local fromBullseye = string.format('%03d', dir) .. ' for ' .. distMetric .. 'km /' .. distImperial .. 'nm'

    message = message .. "LAT LON (decimal): " .. mist.tostringLL(lat, lon, 2) .. ".\n"
    message = message .. "LAT LON (DMS)    : " .. mist.tostringLL(lat, lon, 0, true) .. ".\n"
    message = message .. "MGRS/UTM         : " .. mgrsString .. ".\n"
    message = message .. "FROM BULLSEYE    : " .. fromBullseye .. ".\n"
    message = message .. "\n"

    -- get altitude, qfe and wind information
    local altitude = veaf.getLandHeight(averageGroupPosition)
    --local qfeHp = mist.utils.getQFE(averageGroupPosition, false)
    --local qfeinHg = mist.utils.getQFE(averageGroupPosition, true)
    local windDirection, windStrength = veaf.getWind(veaf.placePointOnLand(averageGroupPosition))

    message = message .. 'DROP ZONE ALT       : ' .. altitude .. " meters.\n"
    --message = message .. 'TARGET QFW       : ' .. qfeHp .. " hPa / " .. qfeinHg .. " inHg.\n"
    local windText =     'no wind.\n'
    if windStrength > 0 then
        windText = string.format(
                         'from %s at %s m/s.\n', windDirection, windStrength)
    end
    message = message .. 'WIND OVER DROP ZONE : ' .. windText

    -- send message only for the unit
    veaf.outTextForUnit(unitName, message, 30)
end

--- add a smoke marker over the drop zone
function veafTransportMission.smokeTarget()
    veaf.loggers.get(veafTransportMission.Id):debug("smokeTarget()")
    veafSpawn.spawnSmoke(veaf.getAveragePosition(veafTransportMission.BlueGroupName), trigger.smokeColor.Green)
	trigger.action.outText('Copy smoke requested, GREEN smoke marks the drop zone!',5)
    veafRadio.delCommand(veafTransportMission.targetMarkersPath, 'Request smoke on drop zone')
    veafRadio.addCommandToSubmenu('Drop zone is marked with GREEN smoke', veafTransportMission.targetMarkersPath, veaf.emptyFunction)
    veafTransportMission.smokeResetTaskID = mist.scheduleFunction(veafTransportMission.smokeReset,{},timer.getTime()+veafTransportMission.SecondsBetweenSmokeRequests)
    veafRadio.refreshRadioMenu()
end

--- Reset the smoke request radio menu
function veafTransportMission.smokeReset()
    veaf.loggers.get(veafTransportMission.Id):debug("smokeReset()")
    veafRadio.delCommand(veafTransportMission.targetMarkersPath, 'Drop zone is marked with GREEN smoke')
    veafRadio.addCommandToSubmenu('Request smoke on drop zone', veafTransportMission.targetMarkersPath, veafTransportMission.smokeTarget)
    trigger.action.outText('Smoke marker over drop zone available',5)
    veafRadio.refreshRadioMenu()
end

--- add an illumination flare over the target area
function veafTransportMission.flareTarget()
    veaf.loggers.get(veafTransportMission.Id):debug("flareTarget()")
    veafSpawn.spawnIlluminationFlare(veaf.getAveragePosition(veafTransportMission.BlueGroupName))
	trigger.action.outText('Copy illumination flare requested, illumination flare over target area!',5)
    veafRadio.delCommand(veafTransportMission.targetMarkersPath, 'Request illumination flare over drop zone')
    veafRadio.addCommandToSubmenu('Drop zone is lit with illumination flare', veafTransportMission.targetMarkersPath, veaf.emptyFunction)
    veafTransportMission.flareResetTaskID = mist.scheduleFunction(veafTransportMission.flareReset,{},timer.getTime()+veafTransportMission.SecondsBetweenFlareRequests)
    veafRadio.refreshRadioMenu()
end

--- Reset the flare request radio menu
function veafTransportMission.flareReset()
    veaf.loggers.get(veafTransportMission.Id):debug("flareReset()")
    veafRadio.delCommand(veafTransportMission.targetMarkersPath, 'Drop zone is lit with illumination flare')
    veafRadio.addCommandToSubmenu('Request illumination flare over drop zone', veafTransportMission.targetMarkersPath, veafTransportMission.flareTarget)
    trigger.action.outText('Illumination flare over drop zone available',5)
    veafRadio.refreshRadioMenu()
end


--- Called from the "Skip delivery" radio menu : remove the current transport mission
function veafTransportMission.skip()
    veafTransportMission.cleanupAfterMission()
    trigger.action.outText("Transport mission cleaned up.", 5)
end

--- Cleanup after either mission is ended or aborted
function veafTransportMission.cleanupAfterMission()
    veaf.loggers.get(veafTransportMission.Id):trace("cleanupAfterMission()")

    -- destroy groups
    veaf.loggers.get(veafTransportMission.Id):trace("destroy friendly group")
    local group = Group.getByName(veafTransportMission.BlueGroupName)
    if group and group:isExist() == true then
        group:destroy()
    end

    veaf.loggers.get(veafTransportMission.Id):trace("destroy cargos")
    local unitNum = 1
    local doIt = true
    while doIt do
        local cargo = StaticObject.getByName(veafTransportMission.BlueCargoName.." #"..unitNum)
        if cargo and cargo:isExist() == true then
            cargo:destroy()
            unitNum = unitNum + 1
        else
            doIt = false
        end
    end

    veaf.loggers.get(veafTransportMission.Id):trace("destroy enemy defense group")
    local groupNum = 1
    local doIt = true
    while doIt do
        group = Group.getByName(veafTransportMission.RedDefenseGroupName.." #"..groupNum)
        if group and group:isExist() == true then
            group:destroy()
            groupNum = groupNum + 1
        else
            doIt = false
        end
    end

    veaf.loggers.get(veafTransportMission.Id):trace("destroy enemy blocade group")
    group = Group.getByName(veafTransportMission.RedBlocadeGroupName)
    if group and group:isExist() == true then
        group:destroy()
    end

    -- remove the watchdog function
    veaf.loggers.get(veafTransportMission.Id):trace("remove the watchdog function")
    if veafTransportMission.friendlyGroupAliveCheckTaskID ~= 'none' then
        mist.removeFunction(veafTransportMission.friendlyGroupAliveCheckTaskID)
    end
    veafTransportMission.friendlyGroupAliveCheckTaskID = 'none'

    -- remove the watchdog function
    veaf.loggers.get(veafTransportMission.Id):trace("remove the adf loop function")
    if veafTransportMission.friendlyGroupAdfLoopTaskID ~= 'none' then
        mist.removeFunction(veafTransportMission.friendlyGroupAdfLoopTaskID)
    end
    veafTransportMission.friendlyGroupAdfLoopTaskID = 'none'

    veafRadio.delCommand(veafTransportMission.rootPath, 'Skip current objective')
    veafRadio.delCommand(veafTransportMission.rootPath, 'Get current objective situation')
    veafRadio.delCommand(veafTransportMission.rootPath, 'Drop zone markers')
    veafRadio.delSubmenu(veafTransportMission.targetMarkersPath, veafTransportMission.rootPath)

    veafRadio.refreshRadioMenu()
    veaf.loggers.get(veafTransportMission.Id):trace("cleanupAfterMission DONE")

end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafTransportMission.buildRadioMenu()
    veafTransportMission.rootPath = veafRadio.addSubMenu(veafTransportMission.RadioMenuName)
    veafRadio.addCommandToSubmenu("HELP", veafTransportMission.rootPath, veafTransportMission.help, nil, veafRadio.USAGE_ForGroup)
    -- TODO add this command when the respawn will work (see veafTransportMission.resetAllCargoes)
    -- missionCommands.addCommand('Respawn all cargoes', veafTransportMission.rootPath, veafTransportMission.resetAllCargoes)
end

function veafTransportMission.help(unitName)
    local text =
        'Create a marker and type "_transport" in the text\n' ..
        'This will create a default friendly group awaiting cargo that you need to transport\n' ..
        'You can add options (comma separated) :\n' ..
        '   "defense [0-5]" to specify air defense cover on the way (1 = light, 5 = heavy)\n' ..
        '        defense = 1 : 3-7 soldiers, GAZ-3308 transport\n' ..
        '        defense = 2 : 3-7 soldiers, BTR-80 APC\n' ..
        '        defense = 3 : 3-7 soldiers, chance of BMP-1 IFV, chance of Igla manpad\n' ..
        '        defense = 4 : 3-7 soldiers, big chance of BMP-1 IFV, big chance of Igla-S manpad, chance of ZU-23 on a truck\n' ..
        '        defense = 5 : 3-7 soldiers, BMP-1 IFV, big chance of Igla-S manpad, chance of ZSU-23-4 Shilka\n' ..
        '   "size [1-5]" to change the number of cargo items to be transported (1 per participating helo, usually)\n' ..
        '   "blocade [0-5]" to specify enemy blocade around the drop zone (1 = light, 5 = heavy)'

    veaf.outTextForUnit(unitName, text, 30)
end


function veafTransportMission.endTransportOfCargo(cargoName)
    local text = 
    'Congratulations on a job well done ! Cargo ' .. cargoName .. ' has been delivered safely'
    trigger.action.outText(text, 15)
    -- TODO reset cargo position
    -- mist.respawnGroup(cargoName, 15) 
    -- does not work yet because 1. the unit name is changed by mist and 2. the trigger zone condition does not work with the new unit (maybe bc of 1. ?)
end

function veafTransportMission.resetAllCargoes()
    -- does not work yet (see veafTransportMission.endTransportOfCargo)
    local lunits = mist.DBs.unitsByNum
    if lunits then
        for i = 1, #lunits do
            if lunits[i] and lunits[i].unitName and lunits[i].unitName:lower():find('cargo - ') then 
                local name = lunits[i].unitName
                -- destroy cargo static unit
                local c = StaticObject.getByName(name)
                if c then
                    StaticObject.destroy(c)
                end
                mist.respawnGroup(name, true)
            end
        end
    end
    trigger.action.outText("All cargoes have been respawned", 15)
end

function veafTransportMission.initializeAllHelosInCTLD()
    veaf.loggers.get(veafTransportMission.Id):warn("Please use ctld.autoInitializeAllHumanTransports - it's automatically run by the veaf.lua script")
end

function veafTransportMission.initializeAllLogisticInCTLD()
    veaf.loggers.get(veafTransportMission.Id):warn("Please use ctld.autoInitializeAllLogistic - it's automatically run by the veaf.lua script")
end
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafTransportMission.initialize()
    veafTransportMission.buildRadioMenu()
    veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafTransportMission.onEventMarkChange)
end

veaf.loggers.get(veafTransportMission.Id):info(string.format("Loading version %s", veafTransportMission.Version))

--- Enable/Disable error boxes displayed on screen.
env.setErrorMessageBoxEnabled(false)

