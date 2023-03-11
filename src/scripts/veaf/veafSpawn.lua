------------------------------------------------------------------
-- VEAF spawn command and functions for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Listen to marker change events and execute spawn commands, with optional parameters
-- * Possibilities : 
-- *    - spawn a specific ennemy unit or group
-- *    - create a cargo drop to be picked by a helo
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

--- veafSpawn Table.
veafSpawn = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafSpawn.Id = "SPAWN"

--- Version.
veafSpawn.Version = "1.43.0"

-- trace level, specific to this module
--veafSpawn.LogLevel = "trace"

veaf.loggers.new(veafSpawn.Id, veafSpawn.LogLevel)

--- Key phrase to look for in the mark text which triggers the spawn command.
veafSpawn.SpawnKeyphrase = "_spawn"

--- Key phrase to look for in the mark text which triggers the destroy command.
veafSpawn.DestroyKeyphrase = "_destroy"

--- Key phrase to look for in the mark text which triggers the teleport command.
veafSpawn.TeleportKeyphrase = "_teleport"

--- Key phrase to look for in the mark text which triggers the drawing commands.
veafSpawn.DrawingKeyphrase = "_drawing"

--- Key phrase to look for in the mark text which triggers the mission master commands.
veafSpawn.MissionMasterKeyphrase = "_mm"

--- Name of the spawned units group 
veafSpawn.RedSpawnedUnitsGroupName = "VEAF Spawned Units"

--- Illumination flare default initial altitude (in meters AGL)
veafSpawn.IlluminationFlareAglAltitude = 1000

veafSpawn.RadioMenuName = "SPAWN"
veafSpawn.HideRadioMenu = false

--- static object type spawned when using the "logistic" keyword
veafSpawn.LogisticUnitType = "FARP Ammo Dump Coating"
veafSpawn.LogisticUnitCategory = "Fortifications"

veafSpawn.ShellingInterval = 5 -- seconds between shells, randomized by 30%
veafSpawn.FlakingInterval = 2 -- seconds between flak shells, randomized by 30%
veafSpawn.IlluminationShellingInterval = 45 -- seconds between illumination shells, randomized by 30%

veafSpawn.MIN_REPEAT_DELAY = 5

veafSpawn.HoundElintAddDelay = 1 --delay before attempting to add a unit to Hound Elint, required for aircrafts spawned dynamically at least

veafSpawn.AirUnitTemplatesPrefix = "veafSpawn-"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSpawn.rootPath = nil

-- counts the units generated 
veafSpawn.spawnedUnitsCounter = 0

-- store all the convoys spawned
veafSpawn.spawnedConvoys = {}

-- store all the air units templates (groups, actually)
veafSpawn.airUnitTemplates = {}

-- all the named groups that have been spawned
veafSpawn.spawnedNamesIndex = {}

-- time delay between the watchdog checks for each CAP
veafSpawn.CAPwatchdogDelay = 20

-- range scale of cargo weight biases
veafSpawn.cargoWeightBiasRange = 6

--AFAC related base data
veafSpawn.AFAC = {}
-- number of AFAC spawned
veafSpawn.AFAC.numberSpawned = {}
veafSpawn.AFAC.numberSpawned[coalition.side.BLUE] = nil
veafSpawn.AFAC.numberSpawned[coalition.side.RED] = nil
-- maximum number of AFACs allowed for spawning by players
veafSpawn.AFAC.maximumAmount = 8
-- base frequency for the first AFAC spawned
veafSpawn.AFAC.baseAFACfrequency = {}
veafSpawn.AFAC.baseAFACfrequency[coalition.side.BLUE] = 226300000 -- 226.300000 MHz otherwise known as 226300000 Hz
veafSpawn.AFAC.baseAFACfrequency[coalition.side.RED] = 226300000 -- 226.300000 MHz otherwise known as 226300000 Hz
-- callsign list of the AFACs
veafSpawn.AFAC.callsigns = {}
veafSpawn.AFAC.callsigns[coalition.side.BLUE] = {
    [1] = {name = "Enfield 9 1", taken = false},
    [2] = {name = "Springfield 9 1", taken = false},
    [3] = {name = "Uzi 9 1", taken = false},
    [4] = {name = "Colt 9 1", taken = false},
    [5] = {name = "Dodge 9 1", taken = false},
    [6] = {name = "Ford 9 1", taken = false},
    [7] = {name = "Chevy 9 1", taken = false},
    [8] = {name = "Pontiac 9 1", taken = false},
}
veafSpawn.AFAC.callsigns[coalition.side.RED] = {
    [1] = {name = "181", taken = false},
    [2] = {name = "281", taken = false},
    [3] = {name = "381", taken = false},
    [4] = {name = "481", taken = false},
    [5] = {name = "581", taken = false},
    [6] = {name = "681", taken = false},
    [7] = {name = "781", taken = false},
    [8] = {name = "881", taken = false},
}
-- AFAC mission data as MIST isn't able to recover it from dynamically spawned aircrafts
veafSpawn.AFAC.missionData = {}
veafSpawn.AFAC.missionData[coalition.side.BLUE] = {}
veafSpawn.AFAC.missionData[coalition.side.RED] = {}

veafSpawn.traceMarkerId = 3727

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafSpawn.onEventMarkChange(eventPos, event)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("event  = %s", veaf.p(event)))

    -- choose by default the coalition opposing the player who triggered the event
    local invertedCoalition = 1
    if event.coalition == 1 then
        invertedCoalition = 2
    end

    veaf.loggers.get(veafSpawn.Id):trace(string.format("event.idx  = %s", veaf.p(event.idx)))

    if veafSpawn.executeCommand(eventPos, event.text, invertedCoalition, event.idx, nil, nil, nil, nil, nil, true) then
        
        -- Delete old mark.
        veaf.loggers.get(veafSpawn.Id):trace(string.format("Removing mark # %d.", event.idx))
        trigger.action.removeMark(event.idx)

    end
end

function veafSpawn.executeCommand(eventPos, eventText, coalition, markId, bypassSecurity, spawnedGroups, repeatCount, repeatDelay, route, allowStartDelay)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.executeCommand(eventText=[%s])", eventText))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("coalition=%s", veaf.p(coalition)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("markId=%s", veaf.p(markId)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("bypassSecurity=%s", veaf.p(bypassSecurity)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("repeatCount=%s", veaf.p(repeatCount)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("repeatDelay=%s", veaf.p(repeatDelay)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("route=%s", veaf.p(route)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("allowStartDelay=%s", veaf.p(allowStartDelay)))

    -- Check if marker has a text and the veafSpawn.SpawnKeyphrase keyphrase.
    if eventText ~= nil and (eventText:lower():find(veafSpawn.SpawnKeyphrase) or eventText:lower():find(veafSpawn.DestroyKeyphrase) or eventText:lower():find(veafSpawn.TeleportKeyphrase) or eventText:lower():find(veafSpawn.DrawingKeyphrase) or eventText:lower():find(veafSpawn.MissionMasterKeyphrase)) then
        
        -- Analyse the mark point text and extract the keywords.
        local options = veafSpawn.markTextAnalysis(eventText)

        if options then
            local repeatDelay = repeatDelay
            local repeatCount = repeatCount
            local allowStartDelay = allowStartDelay or false
            local startDelay = options.delayedStart

            if allowStartDelay and startDelay and startDelay > 0 then
                veaf.loggers.get(veafSpawn.Id):trace(string.format("scheduling veafSpawn.executeCommand for a delayed start in %s seconds", veaf.p(startDelay)))
                mist.scheduleFunction(veafSpawn.executeCommand, {eventPos, eventText, coalition, markId, bypassSecurity, spawnedGroups, nil, nil, route, false}, timer.getTime() + startDelay)
                return true
            end

            if options.repeatCount and not repeatCount then -- only use the parsed repeat options IF the parameter is not set (not during a repeat loop)
                -- set repeatCount and repeatDelay using the parsed options
                repeatCount = options.repeatCount
                repeatDelay = options.repeatDelay or veafSpawn.MIN_REPEAT_DELAY
                veaf.loggers.get(veafSpawn.Id):trace(string.format("using parsed repeat options to set repeatCount to %s and repeatDelay to %s", veaf.p(repeatCount), veaf.p(repeatDelay)))
            end

            if repeatCount and repeatCount > 0 then
                repeatDelay = repeatDelay
                if repeatDelay < veafSpawn.MIN_REPEAT_DELAY then
                    repeatDelay = veafSpawn.MIN_REPEAT_DELAY
                end
                repeatCount = repeatCount - 1 

                -- schedule the next step of the repeated command
                veaf.loggers.get(veafSpawn.Id):trace(string.format("scheduling veafSpawn.executeCommand for %s repeats in %s seconds", veaf.p(repeatCount), veaf.p(repeatDelay)))
                mist.scheduleFunction(veafSpawn.executeCommand, {eventPos, eventText, coalition, markId, bypassSecurity, spawnedGroups, repeatCount, repeatDelay, route, false}, timer.getTime() + repeatDelay)
            end

            if not(options.radius) then
                if options.farp or options.cargo or options.logistic or options.destroy or options.teleport or options.bomb or options.smoke or options.flare or options.signal then
                    options.radius = 0
                else
                    options.radius = 150
                end
            end

            for i=1,options.multiplier do
                local spawnedGroup = nil

                if not options.side then
                    if options.country then
                        -- deduct the side from the country
                        options.side = veaf.getCoalitionForCountry(options.country, true)
                    else
                        options.side = coalition
                    end
                end

                if not options.country then
                    -- deduct the country from the side
                    options.country = veaf.getCountryForCoalition(options.side)    
                end

                veaf.loggers.get(veafSpawn.Id):trace(string.format("options.side=%s",tostring(options.side)))
                veaf.loggers.get(veafSpawn.Id):trace(string.format("options.country=%s",tostring(options.country)))

                local routeDone = false
                
                --indication is the spawn is meant to be a convoy, to adapt it's spawning pattern
                local hasDest = false
                if (options.destination ~= nil) then 
                    hasDest = true 
                end

                -- Check options commands
                if options.unit then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    local code = options.laserCode
                    local channel = options.freq
                    local band = options.mod
                    if options.role == "tacan" then
---@diagnostic disable-next-line: cast-local-type
                        channel = options.tacanChannel or 99
---@diagnostic disable-next-line: cast-local-type
                        code = options.tacanCode or ("T"..tostring(channel))
                        band = options.tacanBand or "X"
                    end
                    spawnedGroup = veafSpawn.spawnUnit(eventPos, options.radius, options.name, options.country, options.altitude, options.heading, options.unitName, options.role, options.forceStatic, code, channel, band, bypassSecurity, not options.showMFD)
                elseif options.farp then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    if not options.type then
                        options.type = "invisible"
                    end
                    spawnedGroup = veafSpawn.spawnFarp(eventPos, options.radius, options.name, options.country, options.type, options.side, options.heading, options.spacing, bypassSecurity, not options.showMFD)
                elseif options.fob then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnFob(eventPos, options.radius, options.name, options.country, options.type, options.side, options.heading, options.spacing, bypassSecurity, not options.showMFD)
                elseif options.cap then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnCombatAirPatrol(eventPos, options.radius, options.name, options.country, options.altitude, options.altdelta, options.heading, options.distance, options.speed, options.capradius, options.skill, bypassSecurity, options.showMFD)
                elseif options.afac then
                    --check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnAFAC(eventPos, options.name, options.country, options.altitude, options.speed, options.heading, options.freq, options.mod, options.laserCode, options.immortal, false, options.showMFD)
                elseif options.group then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnGroup(eventPos, options.radius, options.name, options.country, options.altitude, options.heading, options.spacing, bypassSecurity, hasDest, not options.showMFD)
                elseif options.infantryGroup then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnInfantryGroup(eventPos, options.radius, options.country, options.side, options.heading, options.spacing, options.defense, options.armor, options.size, bypassSecurity, not options.showMFD)
                elseif options.armoredPlatoon then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnArmoredPlatoon(eventPos, options.radius, options.country, options.side, options.heading, options.spacing, options.defense, options.armor, options.size, bypassSecurity, hasDest, not options.showMFD)
                elseif options.airDefenseBattery then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnAirDefenseBattery(eventPos, options.radius, options.country, options.side, options.heading, options.spacing, options.defense, bypassSecurity, hasDest, not options.showMFD)
                elseif options.transportCompany then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnTransportCompany(eventPos, options.radius, options.country, options.side, options.heading, options.spacing, options.defense, options.size, bypassSecurity, hasDest, not options.showMFD)
                elseif options.fullCombatGroup then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnFullCombatGroup(eventPos, options.radius, options.country, options.side, options.heading, options.spacing, options.defense, options.armor, options.size, bypassSecurity, not options.showMFD)
                elseif options.convoy then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnConvoy(eventPos, options.name, options.radius, options.country, options.side, options.heading, options.spacing, options.speed, options.patrol, options.offroad, options.destination, options.defense, options.size, options.armor, bypassSecurity, not options.showMFD)
                    routeDone = true
                elseif options.cargo then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnCargo(eventPos, options.radius, options.cargoType, options.country, options.cargoWeightBias, options.cargoSmoke, options.unitName, bypassSecurity, not options.showMFD)
                elseif options.logistic then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnLogistic(eventPos, options.radius, options.country, bypassSecurity, not options.showMFD)
                elseif options.destroy then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then return end
                    veafSpawn.destroy(eventPos, options.radius, options.unitName)
                elseif options.teleport then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then return end
                    veafSpawn.teleport(eventPos, options.name, bypassSecurity)
                elseif options.bomb then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then return end
                    veafSpawn.spawnBomb(eventPos, options.radius, options.shells, options.power, options.altitude, options.altitudedelta, options.password)
                elseif options.smoke then
                    veafSpawn.spawnSmoke(eventPos, options.smokeColor, options.radius, options.shells)
                elseif options.flare then
                    if not options.altitude or options.altitude == 0 then
                        options.altitude = 1000
                    end
                    if not options.power or options.power == 0 then
                        options.power = 500
                    end
                    options.power = options.power * 1000
                    veafSpawn.spawnIlluminationFlare(eventPos, options.radius, options.shells, options.power, options.altitude, options.heading, options.distance, options.speed)
                elseif options.signal then
                    veafSpawn.spawnSignalFlare(eventPos, options.radius, options.shells, options.smokeColor)
                elseif options.addDrawing then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then return end
                    veafSpawn.addPointToDrawing(eventPos, options.name, options.drawColor, options.drawFillColor, options.type, options.drawArrow)
                elseif options.eraseDrawing then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then return end
                    veafSpawn.eraseDrawing(options.name)
                elseif options.mmFlagOn then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_MM(options.password)) then return end
                    veafSpawn.missionMasterSetFlag(options.name, 1)
                elseif options.mmFlagOff then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_MM(options.password)) then return end
                    veafSpawn.missionMasterSetFlag(options.name, 0)
                elseif options.mmGetFlag then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_MM(options.password)) then return end
                    veafSpawn.missionMasterGetFlag(options.name)
                elseif options.mmRun then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_MM(options.password)) then return end
                    veafSpawn.missionMasterRun(options.name)
                end
                if spawnedGroup then
                    local groupObject = Group.getByName(spawnedGroup)
                    local isStatic = false
                    --group might not have been found because it was a static
                    if not groupObject then
                        isStatic = true
                        groupObject = StaticObject.getByName(spawnedGroup)
                    end
                    veaf.loggers.get(veafSpawn.Id):trace("got groupObject (isStatic=%s) to add group to other platforms : %s", veaf.p(isStatic), veaf.p(groupObject))
                    if groupObject then
                        if not isStatic then
                            --stuff below does not support statics
                            -- make the group combat ready ! well except if the user said otherwise, tweak the AlarmState for some scenarios
                            --veaf.loggers.get(veafSpawn.Id):trace("options.disperse=%s", veaf.p(options.disperse))
                            veaf.readyForCombat(groupObject, options.AlarmState, options.disperse)
                            if not route and not routeDone and options.destination then
                                --  make the group go to destination
                                local actualPosition = groupObject:getUnit(1):getPosition().p
                                local route = veaf.generateVehiclesRoute(actualPosition, options.destination, not options.offroad, options.speed, options.patrol, spawnedGroup)
                                mist.goRoute(groupObject, route)
                            elseif route then
                                mist.goRoute(groupObject, route)
                            end
                            -- add the group to the IADS, if there is one
                            if veafSkynet and options.skynet then -- only add static stuff like sam groups and sam batteries, not mobile groups and convoys
                                veaf.loggers.get(veafSpawn.Id):trace("options.skynet= %s", veaf.p(options.skynet))
                                if type(options.skynet) == "boolean" then --it means options.skynet is true
                                    options.skynet = veafSkynet.defaultIADS[tostring(options.side)]
                                end
                                veaf.loggers.get(veafSpawn.Id):trace("Adding spawned group to skynet, networkName= %s", veaf.p(options.skynet))
                                local networkName = options.skynet
                                if veafSkynet.addGroupToNetwork(networkName, groupObject, options.forceEwr, options.pointDefense, nil, bypassSecurity) then
                                    veaf.loggers.get(veafSpawn.Id):trace("Group Added to IADS network")
                                    if not bypassSecurity then trigger.action.outText(string.format("Group added to the IADS named \"%s\"", options.skynet),15) end
                                else
                                    veaf.loggers.get(veafSpawn.Id):trace("Could not find IADS network or group is not supported by IADS")
                                    if not bypassSecurity then trigger.action.outText(string.format("Could not add group to the IADS named \"%s\", network not found or group not supported", options.skynet),15) end
                                end
                            end
                        end
                        --but houndElint for example does support statics
                        -- reset the Hound Elint system, if the module is active
                        if veafHoundElint then
                            mist.scheduleFunction(veafHoundElint.addPlatformToSystem, {groupObject, nil, false}, timer.getTime()+veafSpawn.HoundElintAddDelay)
                        end
                        --might need to specify the if a group was static in here so that people on the other end know
                        if spawnedGroups then
                            table.insert(spawnedGroups, spawnedGroup)
                        end
                    end
                end
            end
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSpawn.convertLaserToFreq(laser)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("convertLaserToFreq(laser=%s)", tostring(laser)))
    local laser = tonumber(laser)
    if laser and laser >= 1111 and laser <= 1688 then
        local laserB = math.floor((laser - 1000)/100)
        local laserCD = laser - 1000 - laserB*100
        local frequency = tostring(30+laserB+laserCD*0.05)
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
    options.unit = false
    options.forceStatic = false -- if true, will force the spawned unit to be a static
    options.group = false
    options.cap = false
    options.farp = false
    options.fob = false
    options.type = nil
    options.cargo = false
    options.logistic = false
    options.smoke = false
    options.flare = false
    options.signal = false
    options.bomb = false
    options.destroy = false
    options.teleport = false
    options.convoy = false
    options.role = nil
    options.laserCode = 1688
    options.infantryGroup = false
    options.armoredPlatoon = false
    options.airDefenseBattery = false
    options.transportCompany = false
    options.fullCombatGroup = false
    options.speed = nil
    options.capradius = nil
    options.shells = 1
    options.multiplier = 1
    options.skynet = false -- if true, add to skynet
    options.forceEwr = false -- if true, unit will be added as an IADS EWR
    options.pointDefense = false -- if true, unit will be added as point defense to the closest IADS SAM site
    options.AlarmState = 2 -- Alarm state of the convoy to be spawned, 0 is AUTO, 1 is GREEN, 2 is RED. Note: This option is useful for some vehicules which behave badly in Alarm State RED when spawned such as the Scud or Sa-11 (they deploy and can't drive anywhere). Auto is better suited
    options.disperse = 15 --disperse time of groups if under attack, by default is set to 20s
    options.showMFD = false --option to enable groups to be seen on MFDs
    options.addDrawing = false -- draw a polygon on the map
    options.eraseDrawing = false -- erase a polygon from the map
    options.stopDrawing = false -- close a polygon started on the map

    options.drawColor = nil
    options.drawFillColor = nil
    options.drawArrow = nil

    -- spawned group/unit type/alias
    options.name = ""

    -- spawned unit name
    options.unitName = nil

    -- spawned group units spacing
    options.spacing = 5
    
    options.country = nil
    options.side = nil
    options.altitude = 0
    options.altitudedelta = 0
    options.heading = 0
    options.distance = nil
    options.skill = nil

    -- if true, group is part of a road convoy
    options.isConvoy = false

    -- if true, group is patroling between its spawn point and its destination named point
    options.patrol = false

    -- if true, group is set to not follow roads
    options.offroad = false

    -- if set and convoy is true, send the group to the named point
    options.destination = nil

    -- the size of the generated dynamic groups (platoons, convoys, etc.)
    options.size = math.random(7) + 8

    -- defenses force ; ranges from 1 to 5, 5 being the toughest.
    options.defense = math.random(5)

    -- armor force ; ranges from 1 to 5, 5 being the strongest and most modern.
    options.armor = math.random(5)

    -- bomb power
    options.power = 100

    -- smoke color
    options.smokeColor = trigger.smokeColor.Red

    -- optional cargo smoke
    options.cargoSmoke = false

    -- cargo type
    options.cargoType = "container_cargo"
    options.cargoWeightBias = 2 --weight bias of the cargo, if equal to 0, cargo will be very close to minimum weight, if equal to 5, cargo will be close to maximum

    options.alt = nil
    options.altdelta = nil

    options.password = nil

    --AFAC spawn option
    options.afac = false
    options.immortal = false

    -- JTAC radio comms
    options.freq = veafSpawn.convertLaserToFreq(options.laserCode)
    options.mod = "fm"

    -- TACAN name and channel
    options.tacanChannel = 99
    options.tacanBand = "X"

    -- repeat options
    options.repeatCount = nil
    options.repeatDelay = nil

    -- delayed start option
    options.delayedStart = 0

    -- Check for correct keywords.
    if text:lower():find(veafSpawn.SpawnKeyphrase .. " unit") then
        options.unit = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " afac") then
        options.afac = true
        --default country for the AFAC
        options.country = "USA"
        --default AFAC spawned
        options.name = "mq9"
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " cap") then
        options.cap = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " group") then
        options.group = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " farp") then
        options.farp = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " fob") then
        options.fob = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " convoy") then
        options.convoy = true
        options.size = 10 -- default the size parameter to 10
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " infantrygroup") then
        options.infantryGroup = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " armorgroup") then
        options.armoredPlatoon = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " samgroup") then
        options.airDefenseBattery = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " transportgroup") then
        options.transportCompany = true
        options.size = math.random(2, 5)
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " combatgroup") then
        options.fullCombatGroup = true
        options.size = 1 -- default the size parameter to 1
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " smoke") then
        options.smoke = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " flare") then
        options.flare = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " signal") then
        options.signal = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " cargo") then
        options.cargo = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " logistic") then
        options.logistic = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " bomb") then
        options.bomb = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " jtac") then
        options.role = 'jtac'
        options.unit = true
        -- default country for friendly JTAC: USA
        options.country = "USA"
        -- default name for JTAC
        options.name = "LUV HMMWV Jeep"
        -- default JTAC name (will overwrite previous unit with same name)
        options.unitName = "JTAC1"
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " tacan") then
        options.role = 'tacan'
        options.unit = true
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
        options.addDrawing = true
    elseif text:lower():find(veafSpawn.DrawingKeyphrase .. " erase") then
        options.eraseDrawing = true
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

        if (key:lower() == "destination" or key:lower() == "dest") then
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
            if (val == "0" or val == "2" or val =="1") and not options.skynet then
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
            if (val:lower() == "red") then 
                options.smokeColor = trigger.smokeColor.Red
            elseif (val:lower() == "green") then 
                options.smokeColor = trigger.smokeColor.Green
            elseif (val:lower() == "orange") then 
                options.smokeColor = trigger.smokeColor.Orange
            elseif (val:lower() == "blue") then 
                options.smokeColor = trigger.smokeColor.Blue
            elseif (val:lower() == "white") then 
                options.smokeColor = trigger.smokeColor.White
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
    if options.group and not(options.name) then return nil end
    
    -- check mandatory parameter "name" for command "unit"
    if options.unit and not(options.name) then return nil end
    
    -- check mandatory parameter "name" for all mission master commands
    if (options.mmFlagOff or options.mmFlagOn or options.mmRun) and not(options.name) then return nil end

return options
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Manage drawings on the map
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSpawn.drawings = {}
veafSpawn.drawingsMarkers = {}

--- Add a point to a drawing on the map (or start a new drawing)
function veafSpawn.addPointToDrawing(point, name, color, fillColor, lineType, isArrow)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("addPointToDrawing(point=%s, name=%s, color=%s, fillColor=%s, lineType=%s, isArrow=%s)", veaf.p(point), veaf.p(name), veaf.p(color), veaf.p(fillColor), veaf.p(lineType), veaf.p(isArrow)))
    if not name then 
        veaf.loggers.get(veafSpawn.Id):warn("Name is mandatory for drawing commands")
        return
    end
    local drawing = veafSpawn.drawings[name:lower()]
    if not drawing then 
        drawing = VeafDrawingOnMap:new():setName(name)
        veafSpawn.drawings[name:lower()] = drawing
    end
    local drawingMarkerId = veafSpawn.drawingsMarkers[name:lower()]
    if drawingMarkerId then
        trigger.action.removeMark(drawingMarkerId)
    end
    drawingMarkerId = veaf.getUniqueIdentifier()
    trigger.action.markToAll(drawingMarkerId, name, point, true) 
    veafSpawn.drawingsMarkers[name:lower()] = drawingMarkerId
    if color then
        drawing:setColor(color)
    end
    if lineType then
        drawing:setLineType(lineType)
    end
    if isArrow then
        drawing:setArrow()
    end
    if fillColor then
        drawing:setFillColor(fillColor)
    end
    
    drawing:addPoint(point)
    drawing:draw()
end

--- Erase drawing from the map
function veafSpawn.eraseDrawing(name)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("eraseDrawing(name=%s)",veaf.p(name)))
    if not name then 
        veaf.loggers.get(veafSpawn.Id):warn("Name is mandatory for drawing commands")
        return
    end
    local drawing = veafSpawn.drawings[name:lower()]
    if not drawing then 
        local message = string.format("Could not find a drawing named %s", veaf.p(name))
        veaf.loggers.getSpawn(veaf.Id):warn(message)
        trigger.action.outText(message, 5)
        return
    end
    drawing:erase()
    veafSpawn.drawings[name:lower()] = nil
    local drawingMarkerId = veafSpawn.drawingsMarkers[name:lower()]
    if drawingMarkerId then
        trigger.action.removeMark(drawingMarkerId)
    end
    veafSpawn.drawingsMarkers[name:lower()] = nil
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Group spawn command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Spawn a specific group at a specific spot
function veafSpawn.doSpawnGroup(spawnSpot, radius, groupDefinition, country, alt, hdg, spacing, groupName, silent, hasDest, hiddenOnMFD, shuffle)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("doSpawnGroup(country=%s, alt=%s, hdg=%s, spacing=%s, groupName=%s, silent=%s, hasDest=%s, hiddenOnMFD=%s, shuffle=%s)", veaf.p(country), veaf.p(alt), veaf.p(hdg), veaf.p(spacing), veaf.p(groupName), veaf.p(silent), veaf.p(hasDest), veaf.p(hiddenOnMFD), veaf.p(shuffle)))
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

    veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1

    if type(groupDefinition) == "string" then
        local name = groupDefinition
        -- find the desired group in the groups database
        groupDefinition = veafUnits.findGroup(name)
        if not(groupDefinition) then
            veaf.loggers.get(veafSpawn.Id):info("cannot find group "..name)
            if not(silent) then
                trigger.action.outText("cannot find group "..name, 5) 
            end
            return nil    
        end
    end

    veaf.loggers.get(veafSpawn.Id):trace("doSpawnGroup: groupDefinition.description=" .. groupDefinition.description)

    local units = {}

    -- place group units on the map
    local group, cells = veafUnits.placeGroup(groupDefinition, spawnSpot, spacing, hdg, hasDest)
    veafUnits.traceGroup(group, cells)
    
    if not(groupName) then 
        groupName = group.groupName .. " #" .. veafSpawn.spawnedUnitsCounter
    end

    if hasDest then
        mist.scheduleFunction(veafUnits.removePathfindingFixUnit,{groupName}, timer.getTime()+veafUnits.delayBeforePathfindingFix)
    end

    for i=1, #group.units do
        local unit = group.units[i]
        local unitType = unit.typeName
        local unitName = groupName .. " / " .. unit.displayName .. " #" .. i
        
        local spawnPoint = unit.spawnPoint
        if alt > 0 then
            spawnPoint.y = alt
        end
        
        -- check if position is correct for the unit type
        if not veafUnits.checkPositionForUnit(spawnPoint, unit) then
            veaf.loggers.get(veafSpawn.Id):info("cannot find a suitable position for spawning unit ".. unitType)
            if not(silent) then
                trigger.action.outText("cannot find a suitable position for spawning unit "..unitType, 5)
            end
        else 
            local toInsert = {
                    ["x"] = spawnPoint.x,
                    ["y"] = spawnPoint.z,
                    ["alt"] = spawnPoint.y,
                    ["type"] = unitType,
                    ["name"] = unitName,
                    ["speed"] = 0,  -- speed in m/s
                    ["skill"] = "Random",
                    ["heading"] = spawnPoint.hdg
            }
            
            veaf.loggers.get(veafSpawn.Id):trace(string.format("toInsert x=%.1f y=%.1f, alt=%.1f, type=%s, name=%s, speed=%d, heading=%d, skill=%s, country=%s", veaf.p(toInsert.x), veaf.p(toInsert.y), veaf.p(toInsert.alt), veaf.p(toInsert.type), veaf.p(toInsert.name), veaf.p(toInsert.speed), veaf.p(mist.utils.toDegree(toInsert.heading)), veaf.p(toInsert.skill), veaf.p(country)))
            table.insert(units, toInsert)
        end
    end

    -- shuffle the group if needed (useful for randomizing convoys)
    -- counter productive with hasDest which to speed up convoys orders all of the units so that they spawn in order and in a line
    -- the best way to execute this shuffle is to create groups with random cells for each unit, TBD
    if shuffle and not hasDest then
        units = veaf.shuffle(units)
    end

    -- actually spawn the group
    if group.naval then
        mist.dynAdd({country = country, category = "SHIP", name = groupName, hidden = false, units = units, hiddenOnMFD = hiddenOnMFD})
    elseif group.air then
        mist.dynAdd({country = country, category = "AIRPLANE", name = groupName, hidden = false, units = units, hiddenOnMFD = hiddenOnMFD})
    else
        mist.dynAdd({country = country, category = "GROUND_UNIT", name = groupName, hidden = false, units = units, hiddenOnMFD = hiddenOnMFD})
    end

    if not(silent) then
        -- message the group spawning
        trigger.action.outText("A " .. group.description .. "("..country..") has been spawned", 5)
    end

    return groupName
end

--- Spawn a FARP
function veafSpawn.spawnFarp(spawnSpot, radius, name, country, farptype, side, hdg, spacing, silent, hiddenOnMFD)
    veaf.loggers.get(veafSpawn.Id):debug("spawnFarp(name=%s, country=%s, farptype=%s, side=%s, hdg=%s, spacing=%s, silent=%s, hiddenOnMFD=%s)",veaf.p(name), veaf.p(country), veaf.p(farptype), veaf.p(side), veaf.p(hdg), veaf.p(spacing), veaf.p(silent), veaf.p(hiddenOnMFD))
    
    local radius = radius or 0
    local name = name
    local hdg = hdg or 0
    local side = side or 1
    local country = country or "usa"
    local farptype = farptype or ""

    local spawnPosition = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnPosition=%s", veaf.p(spawnPosition))
    if not name or name == "" then 
        local _lat, _lon = coord.LOtoLL(spawnSpot)
        veaf.loggers.get(veafSpawn.Id):trace("_lat=%s", veaf.p(_lat))
        veaf.loggers.get(veafSpawn.Id):trace("_lon=%s", veaf.p(_lon))
        local _mgrs = coord.LLtoMGRS(_lat, _lon)
        veaf.loggers.get(veafSpawn.Id):trace("_mgrs=%s", veaf.p(_mgrs))
        --local _UTM = _mgrs.UTMZone .. _mgrs.MGRSDigraph .. math.floor(_mgrs.Easting / 1000) .. math.floor(_mgrs.Northing / 1000)
        local _UTM = _mgrs.MGRSDigraph .. math.floor(_mgrs.Easting / 1000) .. math.floor(_mgrs.Northing / 1000)
        name = "FARP ".. _UTM:upper()
    end 

    local _type = "Invisible FARP"
    local _shape = "invisiblefarp"
    if farptype:lower() == "quad" then
        _type = "FARP"
        _shape = "FARPs"
    elseif farptype:lower() == "single" then
        _type = "FARP"
        _shape = "FARP"
    end

    -- spawn the FARP
    local _farpStatic = {
        ["category"] = "Heliports",
        ["shape_name"] = _shape,
        ["type"] = _type,
        --["unitId"] = _unitId,
        ["y"] = spawnPosition.z,
        ["x"] = spawnPosition.x,
        ["groupName"] = name,
        ["name"] = name,
        ["canCargo"] = false,
        ["heading"] = mist.utils.toRadian(hdg),
        ["country"] = country,
        ["coalition"] = side,
        --["hiddenOnMFD"] = hiddenOnMFD, --some helicopters won't see the FARPs if this option is true and the FARPs are from the same coalition as the helo, the NS430 will still see them though.
    }
    mist.dynAddStatic(_farpStatic)
    local _spawnedFARP = StaticObject.getByName(name)
    veaf.loggers.get(veafSpawn.Id):trace("_spawnedFARP=%s", veaf.p(_spawnedFARP))

    if _spawnedFARP then
        veaf.loggers.get(veafSpawn.Id):debug("Spawned the FARP static %s", veaf.p(name))

        -- populate the FARP but make the units invisible to MFDs as they are redundant (FARP already shows if wanted)
        veafGrass.buildFarpUnits(_farpStatic, nil, name, hiddenOnMFD)
    end

    return name
end

--- Spawn a FARP
function veafSpawn.spawnFob(spawnSpot, radius, name, country, fobtype, side, hdg, spacing, silent, hiddenOnMFD)
    veaf.loggers.get(veafSpawn.Id):debug("spawnFob(name=%s, country=%s, fobtype=%s, side=%s, hdg=%s, spacing=%s, silent=%s, hiddenOnMFD=%s)",veaf.p(name), veaf.p(country), veaf.p(fobtype), veaf.p(side), veaf.p(hdg), veaf.p(spacing), veaf.p(silent), veaf.p(hiddenOnMFD))
    local TOWER_DISTANCE = 20
    local BEACON_DISTANCE = 3

    if not ctld then
        veaf.loggers.get(veafSpawn.Id):error("spawnFob([%s]): cannot spawn FOB without CTLD!)",veaf.p(name))
        return nil
    end

    local _radius = radius or 0
    local _fobName = name
    local _side = side or 1
    local _country = country or "usa"
    local _fobtype = fobtype or "" -- only a single FOB type in CTLD, yet
	local _hdg = hdg or 0

    local _spawnPosition = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, _radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnPosition=%s", veaf.p(_spawnPosition))
    if not _fobName or _fobName == "" then 
        local _lat, _lon = coord.LOtoLL(spawnSpot)
        veaf.loggers.get(veafSpawn.Id):trace("_lat=%s", veaf.p(_lat))
        veaf.loggers.get(veafSpawn.Id):trace("_lon=%s", veaf.p(_lon))
        local _mgrs = coord.LLtoMGRS(_lat, _lon)
        veaf.loggers.get(veafSpawn.Id):trace("_mgrs=%s", veaf.p(_mgrs))
        local _UTM = _mgrs.MGRSDigraph .. math.floor(_mgrs.Easting / 1000) .. math.floor(_mgrs.Northing / 1000)
        _fobName = "FOB ".. _UTM:upper()
    end

    -- make name unique
    _fobName = string.format("%s #%i", _fobName, veaf.getUniqueIdentifier())

    -- spawn the FOB buildings
    local _outpost = {
        category = "Fortifications",
        type = "outpost",
        y = _spawnPosition.z,
        x = _spawnPosition.x,
        name = _fobName,
        canCargo = false,
        heading = mist.utils.toRadian(hdg),
        country = _country
    }
    mist.dynAddStatic(_outpost)
    local _fob = StaticObject.getByName(_outpost["name"])

    local _tower = {
        type = "house2arm",
        rate = 100,
        y = _outpost.y + TOWER_DISTANCE * math.sin(mist.utils.toRadian(_hdg)),
        x = _outpost.x + TOWER_DISTANCE * math.cos(mist.utils.toRadian(_hdg)),
        name = _fobName .. " Watchtower #002",
        category = "Fortifications",
        canCargo = false,
        heading = mist.utils.toRadian(hdg),
        country = _country
    }
    mist.dynAddStatic(_tower)

    --make it able to deploy crates and pickup troops
    table.insert(ctld.logisticUnits, _fobName)
    table.insert(ctld.builtFOBS, _fobName)

    -- add the FOB to the named points
    local _namedPoint = _spawnPosition
    _namedPoint.atc = true
    _namedPoint.runways = {}

    -- spawn a beacon
    local _beaconPoint = {
        z = _tower.y + BEACON_DISTANCE * math.sin(mist.utils.toRadian(_hdg)),
        x = _tower.x + BEACON_DISTANCE * math.cos(mist.utils.toRadian(_hdg)),
        y = _spawnPosition.y,
    }
    ctld.beaconCount = ctld.beaconCount + 1
    local _radioBeaconName = "FOB Beacon #" .. ctld.beaconCount
    local _radioBeaconDetails = ctld.createRadioBeacon(_beaconPoint, _side, _country, _radioBeaconName, nil, true)
    ctld.fobBeacons[_fobName] = { vhf = _radioBeaconDetails.vhf, uhf = _radioBeaconDetails.uhf, fm = _radioBeaconDetails.fm }
    if _radioBeaconDetails ~= nil then
        _namedPoint.tacan = string.format("ADF : %.2f KHz - %.2f MHz - %.2f MHz FM", _radioBeaconDetails.vhf / 1000, _radioBeaconDetails.uhf / 1000000, _radioBeaconDetails.fm / 1000000)
        veaf.loggers.get(veafSpawn.Id):trace("_namedPoint.tacan=%s", veaf.p(_namedPoint.tacan))
    end
    trigger.action.outTextForCoalition(_side, string.format("Finished building FOB %s! Crates and Troops can now be picked up.", _fobName), 10)

	_namedPoint.tower = "No Control"

    veaf.loggers.get(veafSpawn.Id):trace("_namedPoint=%s", veaf.p(_namedPoint))

	veafNamedPoints.addPoint(_fobName, _namedPoint)

    veaf.loggers.get(veafSpawn.Id):info("Spawned FOB %s", veaf.p(_fobName))
    return _fobName
end

--- Spawn a specific group at a specific spot
function veafSpawn.spawnGroup(spawnSpot, radius, name, country, alt, hdg, spacing, silent, hasDest, hiddenOnMFD)

    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnGroup(name=%s, country=%s, alt=%s, hdg=%s, spacing=%s, silent=%s, hiddenOnMFD=%s)", veaf.p(name), veaf.p(country), veaf.p(alt), veaf.p(hdg), veaf.p(spacing), veaf.p(silent), veaf.p(hiddenOnMFD)))
    
    local spawnedGroupName = veafSpawn.doSpawnGroup(spawnSpot, radius, name, country, alt, hdg, spacing, nil, silent, hasDest, hiddenOnMFD)

    return spawnedGroupName
end

function veafSpawn._createDcsUnits(country, units, groupName, hiddenOnMFD, hasDest)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn._createDcsUnits([%s])",country or ""))
    
    if hasDest then
        mist.scheduleFunction(veafUnits.removePathfindingFixUnit,{groupName}, timer.getTime()+veafUnits.delayBeforePathfindingFix)
    end

    local dcsUnits = {}
    for i=1, #units do
        local unit = units[i]
        local unitType = unit.typeName
        local unitName = groupName .. " / " .. unit.displayName .. " #" .. i
        local spawnPosition = unit.spawnPoint
        local hdg = spawnPosition.hdg or math.random(0, 359)
        
        -- check if position is correct for the unit type
        if veafUnits.checkPositionForUnit(spawnPosition, unit) then
            local toInsert = {
                    ["x"] = spawnPosition.x,
                    ["y"] = spawnPosition.z,
                    ["alt"] = spawnPosition.y,
                    ["type"] = unitType,
                    ["name"] = unitName,
                    ["speed"] = 0,
                    ["skill"] = "Excellent",
                    ["heading"] = hdg
            }

            veaf.loggers.get(veafSpawn.Id):trace(string.format("toInsert x=%.1f y=%.1f, alt=%.1f, type=%s, name=%s, speed=%d, heading=%d, skill=%s, country=%s", toInsert.x, toInsert.y, toInsert.alt, toInsert.type, toInsert.name, toInsert.speed, toInsert.heading, toInsert.skill, country ))
            table.insert(dcsUnits, toInsert)
        end
    end

    -- actually spawn groups
    mist.dynAdd({country = country, category = "GROUND_UNIT", name = groupName, hidden = false, units = dcsUnits, hiddenOnMFD = hiddenOnMFD})
end

--- Spawns a dynamic infantry group 
function veafSpawn.spawnInfantryGroup(spawnSpot, radius, country, side, heading, spacing, defense, armor, size, silent, hiddenOnMFD)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnInfantryGroup(country=%s, side=%s, heading=%s, spacing=%s, defense=%s, armor=%s, size=%s, silent=%s, hiddenOnMFD=%s)", veaf.p(country), veaf.p(side), veaf.p(heading), veaf.p(spacing), veaf.p(defense), veaf.p(armor), veaf.p(size), veaf.p(silent), veaf.p(hiddenOnMFD)))
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

    local groupName = "spawn-" .. math.random(99999) .. " - Infantry Section "
    local group = veafCasMission.generateInfantryGroup(groupName, defense, armor, side, size)
    local group = veafUnits.processGroup(group)
    local groupPosition = veaf.placePointOnLand(spawnSpot)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("groupPosition = %s",veaf.vecToString(groupPosition)))
    local group, cells = veafUnits.placeGroup(group, groupPosition, spacing, heading)

    -- shuffle the units in the group
    local units = veaf.shuffle(group.units)

    veafSpawn._createDcsUnits(country, units, groupName, hiddenOnMFD)
 
    if not silent then 
        trigger.action.outText("Spawned dynamic infantry group "..groupName, 5)
    end

    return groupName
end

--- Spawns a dynamic armored platoon
function veafSpawn.spawnArmoredPlatoon(spawnSpot, radius, country, side, heading, spacing, defense, armor, size, silent, hasDest, hiddenOnMFD)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnArmoredPlatoon(country=%s, side=%s, heading=%s, spacing=%s, defense=%s, armor=%s, size=%s, silent=%s, hasDest=%s, hiddenOnMFD=%s)", veaf.p(country), veaf.p(side), veaf.p(heading), veaf.p(spacing), veaf.p(defense), veaf.p(armor), veaf.p(size), veaf.p(silent), veaf.p(hasDest), veaf.p(hiddenOnMFD)))
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

    local groupName = "spawn-" .. math.random(99999) .. " - Armored Platoon "
    local group = veafCasMission.generateArmorPlatoon(groupName, defense, armor, side, size)
    local group = veafUnits.processGroup(group)
    local groupPosition = veaf.placePointOnLand(spawnSpot)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("groupPosition = %s",veaf.vecToString(groupPosition)))
    local group, cells = veafUnits.placeGroup(group, groupPosition, spacing, heading, hasDest)

    -- shuffle the units in the group
    local units = group.units
    if not(hasDest) then
        units = veaf.shuffle(group.units)
    end

    veafSpawn._createDcsUnits(country, units, groupName, hiddenOnMFD, hasDest)
 
    if not silent then 
        trigger.action.outText("Spawned dynamic armored platoon "..groupName, 5)
    end

    return groupName
end

--- Spawns a dynamic air defense battery
function veafSpawn.spawnAirDefenseBattery(spawnSpot, radius, country, side, heading, spacing, defense, silent, hasDest, hiddenOnMFD)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnAirDefenseBattery(country=%s, side=%s, heading=%s, spacing=%s, defense=%s, silent=%s, hasDest=%s, hiddenOnMFD=%s)", veaf.p(country), veaf.p(side), veaf.p(heading), veaf.p(spacing), veaf.p(defense), veaf.p(silent), veaf.p(hasDest), veaf.p(hiddenOnMFD)))

    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

    local groupName = "spawn-" .. math.random(99999) .. " - Air Defense Battery "
    local group = veafCasMission.generateAirDefenseGroup(groupName, defense, side)
    local group = veafUnits.processGroup(group)
    local groupPosition = veaf.placePointOnLand(spawnSpot)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("groupPosition = %s",veaf.vecToString(groupPosition)))
    local group, cells = veafUnits.placeGroup(group, groupPosition, spacing, heading, hasDest)

    -- shuffle the units in the group
    local units = group.units
    if not(hasDest) then
        units = veaf.shuffle(group.units)
    end

    veafSpawn._createDcsUnits(country or veaf.getCountryForCoalition(side), units, groupName, hiddenOnMFD, hasDest)
 
    if not silent then 
        trigger.action.outText("Spawned dynamic air defense battery "..groupName, 5)
    end

    return groupName
end

--- Spawns a dynamic transport company
function veafSpawn.spawnTransportCompany(spawnSpot, radius, country, side, heading, spacing, defense, size, silent, hasDest, hiddenOnMFD)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnTransportCompany(country=%s, side=%s, heading=%s, spacing=%s, defense=%s, size=%s, silent=%s, hasDest=%s, hiddenOnMFD=%s)", veaf.p(country), veaf.p(side), veaf.p(heading), veaf.p(spacing), veaf.p(defense), veaf.p(size), veaf.p(silent), veaf.p(hasDest), veaf.p(hiddenOnMFD)))
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

    local groupName = "spawn-" .. math.random(99999) .. " - Transport Company "
    local group = veafCasMission.generateTransportCompany(groupName, defense, side, size)
    local group = veafUnits.processGroup(group)
    local groupPosition = veaf.placePointOnLand(spawnSpot)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("groupPosition = %s",veaf.vecToString(groupPosition)))
    local group, cells = veafUnits.placeGroup(group, groupPosition, spacing, heading, hasDest)

    -- shuffle the units in the group
    local units = group.units
    if not(hasDest) then
        units = veaf.shuffle(group.units)
    end

    veafSpawn._createDcsUnits(country, units, groupName, hiddenOnMFD, hasDest)
 
    if not silent then 
        trigger.action.outText("Spawned dynamic transport company "..groupName, 5)
    end

    return groupName
end

--- Spawns a dynamic full combat group composed of multiple platoons
function veafSpawn.spawnFullCombatGroup(spawnSpot, radius, country, side, heading, spacing, defense, armor, size, silent, hiddenOnMFD)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnFullCombatGroup(country=%s, side=%s, heading=%s, spacing=%s, defense=%s, armor=%s, size=%s, silent=%s, hiddenOnMFD=%s)", veaf.p(country), veaf.p(side), veaf.p(heading), veaf.p(spacing), veaf.p(defense), veaf.p(armor), veaf.p(size), veaf.p(silent), veaf.p(hiddenOnMFD)))
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

    local groupName = "spawn-" .. math.random(99999) .. " - Full Combat Group "
    local groupPosition = veaf.placePointOnLand(spawnSpot)
    local units = veafCasMission.generateCasGroup(groupName, groupPosition, size, defense, armor, spacing, side)

    veafSpawn._createDcsUnits(country, units, groupName, hiddenOnMFD)
 
    if not silent then 
        trigger.action.outText("Spawned full combat group "..groupName, 5)
    end

    return groupName
end

--- Spawn a specific group at a specific spot
function veafSpawn.spawnConvoy(spawnSpot, name, radius, country, side, heading, spacing, speed, patrol, offroad, destination, defense, size, armor, silent, hiddenOnMFD)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnConvoy(spawnSpot=[%s], name=[%s], radius=[%s], country=[%s], side=[%s], speed=[%s], patrol=[%s], offroad=[%s], destination=[%s], defense=[%s], size=[%s], armor=[%s], silent=[%s], hiddenOnMFD=[%s])", veaf.p(spawnSpot), veaf.p(name), veaf.p(radius), veaf.p(country), veaf.p(side), veaf.p(speed), veaf.p(patrol), veaf.p(offroad), veaf.p(destination), veaf.p(defense), veaf.p(size), veaf.p(armor), veaf.p(silent), veaf.p(hiddenOnMFD)))
    
    if not(destination) then
        trigger.action.outText("No destination enterred !", 5)
        return false
    end

    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

    -- check that destination exists
    local point = nil
    if destination then
        point = veafNamedPoints.getPoint(destination)
    end
    if not(point) then
        local _lat, _lon = veaf.computeLLFromString(destination)
        veaf.loggers.get(veafSpawn.Id):trace(string.format("_lat=%s",veaf.p(_lat)))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("_lon=%s",veaf.p(_lon)))
        if _lat and _lon then 
            point = coord.LLtoLO(_lat, _lon)
            veaf.loggers.get(veafSpawn.Id):trace(string.format("point=%s",veaf.p(point)))
        end
    end
    if not(point) then
        trigger.action.outText("A point named "..destination.." cannot be found, and these are not valid coordinates !", 5)
        return false
    end

    local groupUnits = {}
    groupUnits.units = {}
    local groupId = math.random(99999)
    local groupName = name
    if not groupName or groupName == "" then
        groupName = "convoy-" .. groupId
    end

    -- generate the transport vehicles and air defense
    if size and size > 0 then -- this is only for reading clarity sake
        -- generate the group
        local group = veafCasMission.generateTransportCompany(groupId, defense, side, size)

        -- process the group 
        local group = veafUnits.processGroup(group)
        
        -- add the units to the global units list
        for _,u in pairs(group.units) do
            table.insert(groupUnits.units, u)
        end
    end

    -- generate the armored vehicles
    if armor and armor > 0 then
        -- generate the group
        local group = veafCasMission.generateArmorPlatoon(groupId, defense, armor, side, size / 2)
        
        -- process the group 
        local group = veafUnits.processGroup(group)
        
        -- add the units to the global units list
        for _,u in pairs(group.units) do
            table.insert(groupUnits.units, u)
        end
    end

    if groupUnits.units then
        -- place its units
        local groupUnits, cells = veafUnits.placeGroup(groupUnits, veaf.placePointOnLand(spawnSpot), spacing, heading, true)
        veafUnits.traceGroup(groupUnits, cells)
    
        -- shuffle the units in the convoy
        --disabled the shuffle to not have interractions with the line spawn put in place for faster departure times, which shuffles units anyways
        --units = veaf.shuffle(units)

        veafSpawn._createDcsUnits(country, groupUnits.units, groupName, hiddenOnMFD, true)
    
        local route = veaf.generateVehiclesRoute(spawnSpot, destination, not offroad, speed, patrol, groupName)
        veafSpawn.spawnedConvoys[groupName] = {route=route, name=groupName}

        --  make the group go to destination
        veaf.loggers.get(veafSpawn.Id):trace("make the group go to destination : ".. groupName)
        mist.goRoute(groupName, route)

        if not silent then 
            trigger.action.outText("Spawned convoy "..groupName, 5)
        end
    end

    return groupName
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Unit spawn command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Spawn a specific unit at a specific spot
-- @param position spawnPosition
-- @param string name
-- @param string country
-- @param int speed
-- @param int alt
-- @param int speed
-- @param int hdg (0..359)
-- @param string unitName (callsign)
-- @param string role (ex: jtac)
-- @param boolean static (is the unit force to spawn as a static unit)
-- @param integer code (starts at 1111, laser code if jtac)
-- @param string freq (frequency if JTAC in MHz with . separator)
-- @param boolean silent (mutes messages to players except errors)
-- @param boolean hiddenOnMFD
function veafSpawn.spawnUnit(spawnPosition, radius, name, country, alt, hdg, unitName, role, static, code, freq, mod, silent, hiddenOnMFD)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnUnit(name = %s, country=%s, alt=%d, hdg=%d, unitName=%s, role=%s, static=%s, code=%s, freq=%s, mod=%s, silent=%s, hiddenOnMFD=%s)", veaf.p(name), veaf.p(country), veaf.p(alt), veaf.p(hdg), veaf.p(unitName), veaf.p(role), veaf.p(static), veaf.p(code), veaf.p(freq), veaf.p(mod), veaf.p(silent), veaf.p(hiddenOnMFD)))
    
    veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1

    -- find the desired unit in the groups database
    local unit = veafUnits.findUnit(name)
    
    if not(unit) then
        veaf.loggers.get(veafSpawn.Id):info("cannot find unit "..name)
        trigger.action.outText("cannot find unit "..name, 5)
        return    
    end
  
    -- cannot spawn planes or helos yet [TODO], however spawning them as a static is fine
    if unit.air and not static then
        veaf.loggers.get(veafSpawn.Id):info("Air units cannot be spawned at the moment (work in progress)")
        trigger.action.outText("Air units cannot be spawned at the moment (work in progress)", 5)
        return    
    end
    
    local units = {}
    local groupName = nil
    
    veaf.loggers.get(veafSpawn.Id):trace("spawnUnit unit = " .. unit.displayName .. ", dcsUnit = " .. tostring(unit.typeName))
    
    if role == "jtac" then
        local name = "JTAC " .. tostring(code):sub(1,1) .. " " .. tostring(code):sub(2,2) .. " " .. tostring(code):sub(3,3) .. " " .. tostring(code):sub(4,4)
        veaf.loggers.get(veafSpawn.Id):trace(string.format("name=%s", tostring(name)))
        groupName = name
        unitName = name
    elseif role == "tacan" then
        local name = "TACAN " .. tostring(freq)..tostring(mod)
        veaf.loggers.get(veafSpawn.Id):trace(string.format("name=%s", tostring(name)))
        groupName = name
        unitName = name
    else
      groupName = veafSpawn.RedSpawnedUnitsGroupName .. " #" .. veafSpawn.spawnedUnitsCounter
      if not unitName then
        unitName = unit.displayName .. " #" .. veafSpawn.spawnedUnitsCounter
      end
    end
    
    veaf.loggers.get(veafSpawn.Id):trace("groupName="..groupName)
    veaf.loggers.get(veafSpawn.Id):trace("unitName="..unitName)

    local spawnSpot = nil
    local nbTries = 25
    repeat
        spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnPosition, radius))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnUnit: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))   
        if alt > 0 then
            spawnSpot.y = alt
        end
        if not veafUnits.checkPositionForUnit(spawnSpot, unit) then
            veaf.loggers.get(veafSpawn.Id):debug("finding another spawnSpot for unit %s, remaining tries #%s", unit.displayName, nbTries)
            spawnSpot = nil
            nbTries = nbTries - 1
        end
    until spawnSpot or nbTries <= 0

    if not spawnSpot then
        veaf.loggers.get(veafSpawn.Id):info("cannot find a suitable position for spawning unit "..unit.displayName)
        trigger.action.outText("cannot find a suitable position for spawning unit "..unit.displayName, 5)
        return
    else 
        local toInsert = {}
        local effectPreset = nil
        local effectTransparency = nil
        local shapeName = nil

        if unit.static or static then

            if unit.category then
                if unit.category == "Heliport" then
                    unit.category = "Heliports"
                end
                -- if unit.category == "Effect" then
                --     unit.category = "Effects"
                --     effectPreset = 2
                --     effectTransparency = 1
                --     shapeName = "medium smoke and fire"
                -- end
            end

            groupName = unitName --this name here will be used for reference by DCS, since we return groupName for other scripts to do their thing, this must be the unitName

            toInsert = {
                ["x"] = spawnSpot.x,
                ["y"] = spawnSpot.z,
                ["alt"] = spawnSpot.y,
                ["type"] = unit.typeName,
                ["name"] = groupName,
                ["category"] = unit.category,
                ["heading"] = mist.utils.toRadian(hdg),
                -- ["effectTransparency"] = effectTransparency,
                -- ["effectPreset"] = effectPreset,
                -- ["shapeName"] = shapeName,
            }
        else
            toInsert = {
                ["x"] = spawnSpot.x,
                ["y"] = spawnSpot.z,
                ["alt"] = spawnSpot.y,
                ["type"] = unit.typeName,
                ["name"] = unitName,
                ["speed"] = 0,
                ["skill"] = "Random",
                ["heading"] = mist.utils.toRadian(hdg),
            }
        end
            
        table.insert(units, toInsert)       
    end

    veaf.loggers.get(veafSpawn.Id):trace(string.format("unitData = %s", veaf.p(units)))
        
    -- actually spawn the unit
    if unit.static or static then --if the unit was forced to spawn as a static it could still be an air or a naval unit so this check goes first
        veaf.loggers.get(veafSpawn.Id):trace("Spawning STATIC")
        mist.dynAddStatic({country = country, groupName = groupName, units = units, hiddenOnMFD = hiddenOnMFD})
        --groupName = nil --statics do not have a group name, you must set groupName to nil to avoid other scripts interacting
    elseif unit.air then
        veaf.loggers.get(veafSpawn.Id):trace("Spawning AIRPLANE")
        mist.dynAdd({country = country, category = "PLANE", groupName = groupName, units = units, hiddenOnMFD = hiddenOnMFD})
    elseif unit.naval then
        veaf.loggers.get(veafSpawn.Id):trace("Spawning SHIP")
        mist.dynAdd({country = country, category = "SHIP", groupName = groupName, units = units, hiddenOnMFD = hiddenOnMFD})
    else
        veaf.loggers.get(veafSpawn.Id):trace("Spawning GROUND_UNIT")
        mist.dynAdd({country = country, category = "GROUND_UNIT", groupName = groupName, units = units, hiddenOnMFD = hiddenOnMFD})
    end

    if role == "jtac" and not static then
        -- JTAC needs to be invisible and immortal
        local _setImmortal = {
            id = 'SetImmortal',
            params = {
                value = true
            }
        }
        -- invisible to AI, Shagrat
        local _setInvisible = {
            id = 'SetInvisible',
            params = {
                value = true
            }
        }

        local spawnedGroup = Group.getByName(groupName)
        local controller = spawnedGroup:getController()
        Controller.setCommand(controller, _setImmortal)
        Controller.setCommand(controller, _setInvisible)

        -- start lasing 
        if ctld then 
            ctld.cleanupJTAC(groupName)
            local radioData = {freq=freq, mod=mod, name=groupName}
            veafSpawn.JTACAutoLase(groupName, code, radioData)
        end

    elseif role == "tacan" and not static then
        veaf.loggers.get(veafSpawn.Id):trace(string.format("name=%s", tostring(name)))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("freq=%s", tostring(freq)))
        local mod = string.upper(mod) or "X"
        veaf.loggers.get(veafSpawn.Id):trace(string.format("mod=%s", tostring(mod)))
        local txFreq = (1025 + freq - 1) * 1000000
        local rxFreq = (962 + freq - 1) * 1000000
        if (freq < 64 and mod == "Y") or (freq >= 64 and mod == "X") then
            rxFreq = (1088 + freq - 1) * 1000000
        end
        veaf.loggers.get(veafSpawn.Id):trace(string.format("txFreq=%s", tostring(txFreq)))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("rxFreq=%s", tostring(rxFreq)))

        local command = { 
            id = 'ActivateBeacon', 
            params = { 
                type = 4,
                system = 18, 
                callsign = code or "TCN", 
                frequency = rxFreq,
                AA = false,
                channel = freq,
                bearing = true,
                modeChannel = mod,
            }
        }
                
        veaf.loggers.get(veafSpawn.Id):trace(string.format("setting %s", veaf.p(command)))
        local spawnedGroup = Group.getByName(groupName)
        local controller = spawnedGroup:getController()
        controller:setCommand(command)
        veaf.loggers.get(veafSpawn.Id):trace(string.format("done setting command"))
    end

    -- message the unit spawning
    veaf.loggers.get(veafSpawn.Id):trace(string.format("message the unit spawning"))
    if (role == "jtac") or not silent then 
        local message = "A " .. unit.displayName .. " ("..country..") has been spawned"
        if role == "jtac" and not static then
            message = "JTAC spawned, lasing on "..code..", available on "..freq.." "..mod
        end
        veaf.loggers.get(veafSpawn.Id):trace(message)
        trigger.action.outText(message, 15)
    end

    return groupName
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Cargo spawn command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Spawn a specific cargo at a specific spot
function veafSpawn.spawnCargo(spawnSpot, radius, cargoType, country, weightBias, cargoSmoke, unitName, silent, hiddenOnMFD)
    veaf.loggers.get(veafSpawn.Id):debug("spawnCargo(cargoType = " .. cargoType ..")")
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnCargo: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))

    return veafSpawn.doSpawnCargo(spawnSpot, radius, cargoType, country, weightBias, unitName, cargoSmoke, silent, hiddenOnMFD)
end

--- Spawn a logistic unit for CTLD at a specific spot
function veafSpawn.spawnLogistic(spawnSpot, radius, country, silent, hiddenOnMFD)
    veaf.loggers.get(veafSpawn.Id):debug("spawnLogistic()")
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnLogistic: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))

    local unitName = veafSpawn.doSpawnStatic(spawnSpot, radius, veafSpawn.LogisticUnitCategory, veafSpawn.LogisticUnitType, country, nil, false, true, hiddenOnMFD)
    
    if unitName then 
        veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnLogistic: inserting %s into CTLD logistics list", unitName))  
        if ctld then 
            table.insert(ctld.logisticUnits, unitName)
        end

        -- message the unit spawning
        if not silent then 
            local message = "Logistic unit " .. unitName .. " has been spawned and was added to CTLD."
            trigger.action.outText(message, 15)
        end
        return unitName
    else
        local message = "Logistic unit could not be spawned"
        trigger.action.outText(message, 15)
        return
    end
end

--- Spawn a specific cargo at a specific spot
function veafSpawn.doSpawnCargo(spawnSpot, radius, cargoType, country, weightBias, unitName, cargoSmoke, silent, hiddenOnMFD)
    local weightBias = weightBias or 2
    local radius = radius or 0
    veaf.loggers.get(veafSpawn.Id):debug("spawnCargo(cargoType = " .. cargoType ..")")
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnCargo: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))

    local units = {}

    local spawnPosition = veaf.findPointInZone(spawnSpot, 50, false)

    -- check spawned position validity
    if spawnPosition == nil then
        veaf.loggers.get(veafSpawn.Id):info("cannot find a suitable position for spawning cargo "..cargoType)
        trigger.action.outText("cannot find a suitable position for spawning cargo "..cargoType, 5)
        return
    end

    veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnCargo: spawnPosition  x=%.1f y=%.1f", spawnPosition.x, spawnPosition.y))

    -- compute cargo weight
    local cargoWeight = 250
    local unit = veafUnits.findDcsUnit(cargoType)
    if not unit then
        cargoType = cargoType.. "_cargo"
        unit = veafUnits.findDcsUnit(cargoType)
    end
    if unit then
        if unit.type then    
            cargoType = unit.type
        else
            veaf.loggers.get(veafSpawn.Id):info("could not find cargo type named ".. veaf.p(cargoType))
            trigger.action.outText("could not find cargo type named ".. veaf.p(cargoType), 15)
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
            local maxMass =  unit.desc.minMass + (weightBias+1) * massDelta / weightScaleRange 
            veaf.loggers.get(veafSpawn.Id):debug(string.format("cargo minMass=%s, cargo maxMass=%s", veaf.p(minMass), veaf.p(maxMass)))
            cargoWeight = math.random(minMass,maxMass)
        elseif unit.defaultMass then
            local BiasOffset = -math.floor(veafSpawn.cargoWeightBiasRange / 2)
            local weightBiasCentered = weightBias + BiasOffset
            local cargoWeightBiasScaleMin = BiasOffset
            local cargoWeightBiasScaleMax = veafSpawn.cargoWeightBiasRange + BiasOffset
            local weightBiasMax = weightBiasCentered + 1
            local weightBiasMin = weightBiasCentered

            cargoWeight = unit.defaultMass
            veaf.loggers.get(veafSpawn.Id):debug(string.format("cargo defaultMass=%s", veaf.p(cargoWeight)))
            local minMass = cargoWeight + weightBiasMin * cargoWeight / (2*cargoWeightBiasScaleMax)
            local maxMass = cargoWeight + weightBiasMax * cargoWeight / (2*cargoWeightBiasScaleMax)
            veaf.loggers.get(veafSpawn.Id):debug(string.format("cargo minMass=%s, cargo maxMass=%s", veaf.p(minMass), veaf.p(maxMass)))
            cargoWeight = math.random(minMass,maxMass)
        end
        if cargoWeight then
            veaf.loggers.get(veafSpawn.Id):debug(string.format("cargo mass=%s", veaf.p(cargoWeight)))

            if not(unitName) then
                veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1
                unitName = unit.name .. " #" .. veafSpawn.spawnedUnitsCounter
            end

            -- create the cargo
            local cargoTable = {
                type = cargoType,
                country = country,
                category = 'Cargos',
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
                local smokePosition={x=spawnPosition.x + mist.random(10,20), y=0, z=spawnPosition.y + mist.random(10,20)}
                local height = veaf.getLandHeight(smokePosition)
                smokePosition.y = height
                veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnCargo: smokePosition  x=%.1f y=%.1f z=%.1f", smokePosition.x, smokePosition.y, smokePosition.z))
                veafSpawn.spawnSmoke(smokePosition, trigger.smokeColor.Green)
                for i = 1, 10 do
                    veaf.loggers.get(veafSpawn.Id):trace("Signal flare 1 at " .. timer.getTime() + i*7)
                    mist.scheduleFunction(veafSpawn.spawnSignalFlare, {smokePosition, nil, nil, trigger.flareColor.Red}, timer.getTime() + i*3)
                end
            end

            -- message the unit spawning
            local message = "Cargo " .. unitName .. " weighting " .. cargoWeight .. " kg has been spawned"
            if cargoSmoke then 
                message = message .. ". It's marked with green smoke and red flares"
            end
            if not(silent) then trigger.action.outText(message, 15) end
        end
    else
        veaf.loggers.get(veafSpawn.Id):info("could not find cargo type named ".. veaf.p(cargoType))
        trigger.action.outText("could not find cargo type named ".. veaf.p(cargoType), 15)
        return
    end
    return unitName
end


--- Spawn a specific static at a specific spot
function veafSpawn.doSpawnStatic(spawnSpot, radius, staticCategory, staticType, country, unitName, smoke, silent, hiddenOnMFD)
    veaf.loggers.get(veafSpawn.Id):debug("doSpawnStatic(staticCategory = " .. staticCategory ..")")
    veaf.loggers.get(veafSpawn.Id):debug("doSpawnStatic(staticType = " .. staticType ..")")
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("doSpawnStatic: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))

    local units = {}

    local spawnPosition = veaf.findPointInZone(spawnSpot, 50, false)

    -- check spawned position validity
    if spawnPosition == nil then
        veaf.loggers.get(veafSpawn.Id):info("cannot find a suitable position for spawning static "..staticType)
        if not(silent) then trigger.action.outText("cannot find a suitable position for spawning static "..staticType, 5) end
        return
    end

    veaf.loggers.get(veafSpawn.Id):trace(string.format("doSpawnStatic: spawnPosition  x=%.1f y=%.1f", spawnPosition.x, spawnPosition.y))
  
    local unit = veafUnits.findDcsUnit(staticType)
    if unit then
        if not(unitName) then
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
            local smokePosition={x=spawnPosition.x + mist.random(10,20), y=0, z=spawnPosition.y + mist.random(10,20)}
            local height = veaf.getLandHeight(smokePosition)
            smokePosition.y = height
            veaf.loggers.get(veafSpawn.Id):trace(string.format("doSpawnStatic: smokePosition  x=%.1f y=%.1f z=%.1f", smokePosition.x, smokePosition.y, smokePosition.z))
            veafSpawn.spawnSmoke(smokePosition, trigger.smokeColor.Green)
            for i = 1, 10 do
                veaf.loggers.get(veafSpawn.Id):trace("Signal flare 1 at " .. timer.getTime() + i*7)
                mist.scheduleFunction(veafSpawn.spawnSignalFlare, {smokePosition, nil, nil, trigger.flareColor.Red}, timer.getTime() + i*3)
            end
        end

        -- message the unit spawning
        local message = "Static " .. unitName .. " has been spawned"
        if smoke then 
            message = message .. ". It's marked with green smoke and red flares"
        end
        if not(silent) then trigger.action.outText(message, 5) end
    end
    return unitName
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Smoke and Flare commands
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- trigger an explosion at the marker area
function veafSpawn.spawnBomb(spawnSpot, radius, shells, power, altitude, altitudedelta, password)
    veaf.loggers.get(veafSpawn.Id):debug("spawnBomb(power=" .. power ..")")

    local shellTime = 0
    local shellDelay = 0
    for shell=1,shells do
        local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
        veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=%s", spawnSpot)
        veaf.loggers.get(veafSpawn.Id):trace("altitude=%s", altitude)
        if altitude and altitude > 0 then
            spawnSpot.y = altitude + altitudedelta * ((math.random(100)-50)/100)
            shellDelay = veafSpawn.FlakingInterval
        else
            shellDelay = veafSpawn.ShellingInterval
        end
        veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=%s", spawnSpot)
        
        local shellDelay = shellDelay * (math.random(100) + 30)/100
        local shellPower = power * (math.random(100) + 30)/100
        -- check security
        if not veafSecurity.checkPassword_L0(password) then
            if shellPower > 1000 then shellPower = 1000 end
        end
        veaf.loggers.get(veafSpawn.Id):trace(string.format("shell #%d : shellTime=%d, shellDelay=%d, power=%d", shell, shellTime, shellDelay, shellPower))
        mist.scheduleFunction(trigger.action.explosion, {spawnSpot, power}, timer.getTime() + shellTime)
        shellTime = shellTime + shellDelay
    end
end

--- add a smoke marker over the marker area
function veafSpawn.spawnSmoke(spawnSpot, color, radius, shells)
    veaf.loggers.get(veafSpawn.Id):debug("spawnSmoke(color=%s",veaf.p(color))
    local radius = radius or 50
    local shells = shells or 1
    veaf.loggers.get(veafSpawn.Id):trace("radius=%s", veaf.p(radius))
    veaf.loggers.get(veafSpawn.Id):trace("shells=%s", veaf.p(shells))

    local shellTime = 0
    for shell=1,shells do
        local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnSpot=%s", veaf.vecToString(spawnSpot)))
        
        local shellDelay = veafSpawn.ShellingInterval * (math.random(100) + 30)/100
        veaf.loggers.get(veafSpawn.Id):trace(string.format("shell #%d : shellTime=%d, shellDelay=%d", shell, shellTime, shellDelay))
        if shells > 1 then
            -- add a small explosion under the smoke to simulate smoke shells
            mist.scheduleFunction(trigger.action.explosion, {spawnSpot, 1}, timer.getTime() + shellTime-1)
        end
        mist.scheduleFunction(trigger.action.smoke, {spawnSpot, color}, timer.getTime() + shellTime)
        shellTime = shellTime + shellDelay
    end
end

--- add a signal flare over the marker area
function veafSpawn.spawnSignalFlare(spawnSpot, radius, shells, color)
    veaf.loggers.get(veafSpawn.Id):debug("spawnSignalFlare(color = " .. color ..")")
    
    local shellTime = 0
    for shell=1,shells do
        local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnSpot=%s", veaf.vecToString(spawnSpot)))
        
        local shellDelay = veafSpawn.ShellingInterval * (math.random(100) + 30)/100
        local azimuth = math.random(359)
        veaf.loggers.get(veafSpawn.Id):trace(string.format("shell #%d : shellTime=%d, shellDelay=%d", shell, shellTime, shellDelay))
        mist.scheduleFunction(trigger.action.signalFlare, {spawnSpot, color, azimuth}, timer.getTime() + shellTime)
        shellTime = shellTime + shellDelay
    end
end

function veafSpawn.spawnIlluminationFlares(spawnSpot, radius, shells, power, height)
    for shell=1, shells do
        local shellHeight = height * (math.random(100, 130))/100-15
        local shellPower = power * (math.random(100, 130))/100-15
        local newSpawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
        newSpawnSpot.y = veaf.getLandHeight(newSpawnSpot) + shellHeight
        veaf.loggers.get(veafSpawn.Id):trace(string.format("shell #%d : shellHeight=%d, shellPower=%d", shell, shellHeight, shellPower))
        -- add a small explosion under the flare to simulate flare shells
        trigger.action.explosion(spawnSpot, 1)
        trigger.action.illuminationBomb(newSpawnSpot, shellPower)
    end
end

--- add an illumination flare over the target area
function veafSpawn.spawnIlluminationFlare(spawnSpot, radius, steps, power, height, heading, distance, speed)
    veaf.loggers.get(veafSpawn.Id):debug("spawnIlluminationFlare()")
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=%s", veaf.p(spawnSpot))
    veaf.loggers.get(veafSpawn.Id):trace("radius=%s", veaf.p(radius))
    veaf.loggers.get(veafSpawn.Id):trace("steps=%s", veaf.p(steps))
    veaf.loggers.get(veafSpawn.Id):trace("power=%s", veaf.p(power))
    veaf.loggers.get(veafSpawn.Id):trace("height=%s", veaf.p(height))
    veaf.loggers.get(veafSpawn.Id):trace("heading=%s", veaf.p(heading))
    veaf.loggers.get(veafSpawn.Id):trace("distance=%s", veaf.p(distance))

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
    for step=1, steps do
        local stepDelay = veafSpawn.IlluminationShellingInterval * (math.random(100, 130)-15)/100
        local newSpawnSpot = mist.utils.deepCopy(spawnSpot)
        if stepDistance then
            newSpawnSpot.x = spawnSpot.x + stepDistance * (step - 1) * cosHeading
            newSpawnSpot.z = spawnSpot.z + stepDistance * (step - 1) * sinHeading
        end
        local shellsPerStep = math.random(5, 10)
        veaf.loggers.get(veafSpawn.Id):trace(string.format("step #%d : stepTime=%d, shellDelay=%d", step, stepTime, stepDelay))
        for shell=1, shellsPerStep do
            local shellDelay = shell/4 + (math.random(100, 150)-25)/100
            local shellHeight = height * (math.random(100, 130)-15)/100
            local shellPower = power * (math.random(100, 130)-15)/100
            local newSpawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(newSpawnSpot, radius))
            newSpawnSpot.y = veaf.getLandHeight(newSpawnSpot) + shellHeight
            veaf.loggers.get(veafSpawn.Id):trace(string.format("shell #%d : shellHeight=%d, shellPower=%d", shell, shellHeight, shellPower))
            local time = timer.getTime() + stepTime + shellDelay
            -- add a small explosion under the flare to simulate flare shells
            mist.scheduleFunction(trigger.action.explosion, {newSpawnSpot, 0.1}, time)
            mist.scheduleFunction(trigger.action.illuminationBomb, {newSpawnSpot, shellPower}, time)
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
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.destroyObjectWithFlak(%s, %s, %s)", veaf.p(power), veaf.p(power), veaf.p(density)))
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
                x = point.x + (veafSpawn.DEFAULT_FLAK_CLOUD_SIZE * math.random(-100,100) / 100),
                y = point.y + (veafSpawn.DEFAULT_FLAK_CLOUD_SIZE * math.random(-100,100) / 100),
                z = point.z + (veafSpawn.DEFAULT_FLAK_CLOUD_SIZE * math.random(-100,100) / 100)
            }
            --veaf.loggers.get(veafSpawn.Id):trace(string.format("flakPoint=%s", veaf.p(flakPoint)))
            trigger.action.explosion(flakPoint, _power)
        end

        -- reschedule to check if the object is destroyed
        veaf.loggers.get(veafSpawn.Id):trace(string.format("reschedule to check if the object is destroyed"))
        mist.scheduleFunction(veafSpawn.destroyObjectWithFlak, {object, power, power, density}, timer.getTime() + veafSpawn.DEFAULT_FLAK_REPEAT_DELAY)
    end
end

--- destroy unit(s)
function veafSpawn.destroy(spawnSpot, radius, unitName)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("destroy(radius=%s, unitName=%s)", tostring(radius), tostring(unitName)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnSpot=%s", veaf.p(spawnSpot)))
    if unitName then
        -- destroy a specific unit
        local c = Unit.getByName(unitName)
        if c then
            veaf.loggers.get(veafSpawn.Id):trace("destroy a specific unit")
            Unit.destroy(c)
        end

        -- or a specific static
        c = StaticObject.getByName(unitName)
        if c then
            veaf.loggers.get(veafSpawn.Id):trace("destroy a specific static")
            StaticObject.destroy(c)
        end

        -- or a specific group
        c = Group.getByName(unitName)
        if c then
            veaf.loggers.get(veafSpawn.Id):trace("destroy a specific group")
            Group.destroy(c)
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
                    unit = StaticObject.getByName(name)
                    if unit then 
                        StaticObject.destroy(unit)
                    end
                end
            end
        end
    end
end

--- teleport group
function veafSpawn.teleport(spawnSpot, name, silent)
    veaf.loggers.get(veafSpawn.Id):debug("teleport(name = " .. name ..")")
    local vars = { groupName = name, point = spawnSpot, action = "teleport" }
    local grp = mist.teleportToPoint(vars)
    if not silent then 
        if grp then
            trigger.action.outText("Teleported group "..name, 5) 
        else
            trigger.action.outText("Cannot teleport group : "..name, 5) 
        end
    end
end

function veafSpawn._findClosestConvoy(unitName)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn._findClosestConvoy(%s)",unitName))
    local closestConvoyName = nil
    local minDistance = 99999999
    local unit = veafRadio.getHumanUnitOrWingman(unitName)
    if unit then
        for name, _ in pairs(veafSpawn.spawnedConvoys) do
            local averageGroupPosition = veaf.getAveragePosition(name)
            if not averageGroupPosition then
                veaf.loggers.get(veafSpawn.Id):error("cannot get average position of %s",veaf.p(unitName))
                return nil
            end
            local distanceFromPlayer = ((averageGroupPosition.x - unit:getPosition().p.x)^2 + (averageGroupPosition.z - unit:getPosition().p.z)^2)^0.5
            veaf.loggers.get(veafSpawn.Id):trace(string.format("distanceFromPlayer = %d",distanceFromPlayer))
            if distanceFromPlayer < minDistance then
                minDistance = distanceFromPlayer
                closestConvoyName = name
                veaf.loggers.get(veafSpawn.Id):trace(string.format("convoy %s is closest",closestConvoyName))
            end
        end
    end
    return closestConvoyName
end

function veafSpawn._commandConvoy(convoyName, stop)
    local group = Group.getByName(convoyName)
    if group then
        if stop then
            local stopped = veafSpawn.spawnedConvoys[convoyName].stopped
            if stopped then 
                -- already stopped !
                return false
            else
                local task ={ 
                    id = 'Hold', 
                    params = { } 
                    }
                    group:getController():pushTask(task)
                veafSpawn.spawnedConvoys[convoyName].stopped = true
            end
        else
            local stopped = veafSpawn.spawnedConvoys[convoyName].stopped
            if stopped then 
                mist.goRoute(convoyName, veafSpawn.spawnedConvoys[convoyName].route)
                veafSpawn.spawnedConvoys[convoyName].stopped = false
            else
                -- not stopped !
                return false
            end
        end
    end
end

function veafSpawn.stopClosestConvoy(unitName)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.stopClosestConvoy(unitName=%s)",unitName))
    local convoyName = veafSpawn._findClosestConvoy(unitName)
    if convoyName then
        return veafSpawn._commandConvoy(convoyName, true)
    end
end

function veafSpawn.moveClosestConvoy(unitName)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.moveClosestConvoy(unitName=%s)",unitName))
    local convoyName = veafSpawn._findClosestConvoy(unitName)
    if convoyName then
        return veafSpawn._commandConvoy(convoyName, false)
    end
end

function veafSpawn._markClosestConvoyWithSmoke(unitName, markRoute)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.markClosestConvoyWithSmoke(unitName=%s)",unitName))
    local closestConvoyName = veafSpawn._findClosestConvoy(unitName)
    if closestConvoyName then
        if markRoute then
            local route = veafSpawn.spawnedConvoys[closestConvoyName].route
            local startPoint = veaf.placePointOnLand({x = route[1].x, y = 0, z = route[1].y})
            local endPoint = veaf.placePointOnLand({x = route[2].x, y = 0, z = route[2].y})
            trigger.action.smoke(startPoint, trigger.smokeColor.Green)
            trigger.action.smoke(endPoint, trigger.smokeColor.Red)
            veaf.outTextForUnit(unitName, closestConvoyName .. " is going from green to red smoke", 10)
        else
            local averageGroupPosition = veaf.getAveragePosition(closestConvoyName)
            trigger.action.smoke(averageGroupPosition, trigger.smokeColor.White)
            veaf.outTextForUnit(unitName, closestConvoyName .. " marked with white smoke", 10)
        end
    else
        veaf.outTextForUnit(unitName, "No convoy found", 10)
    end
end

function veafSpawn.markClosestConvoyWithSmoke(unitName)
    return veafSpawn._markClosestConvoyWithSmoke(unitName, false)
end

function veafSpawn.markClosestConvoyRouteWithSmoke(unitName)
    return veafSpawn._markClosestConvoyWithSmoke(unitName, true)
end

function veafSpawn.infoOnAllConvoys(unitName)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.infoOnAllConvoys(unitName=%s)",unitName))
    local text = ""
    for name, _ in pairs(veafSpawn.spawnedConvoys) do
        local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(name)
        if nbVehicles > 0 then
            local averageGroupPosition = veaf.getAveragePosition(name)
            local lat, lon = coord.LOtoLL(averageGroupPosition)
            local llString = mist.tostringLL(lat, lon, 0, true)
            text = text .. " - " .. name .. ", " .. nbVehicles .. " vehicles : " .. llString
            if veafSpawn.spawnedConvoys[name].stopped then
                text = text .. ", stopped"
            end
        else
            text = text .. " - " .. name .. "has been destroyed"
            -- convoy has been dispatched, remove it from the convoys list
            veafSpawn.spawnedConvoys[name] = nil
        end
    end
    if text == "" then
        veaf.outTextForUnit(unitName, "No convoy found", 10)
    else
        veaf.outTextForUnit(unitName, text, 30)
    end
end

function veafSpawn.cleanupAllConvoys()
    veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.cleanupAllConvoys()")
    local foundOne = false
    for name, _ in pairs(veafSpawn.spawnedConvoys) do
        foundOne = true
        local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(name)
        if nbVehicles > 0 then
            local group = Group.getByName(name)
            if group then
                Group.destroy(group)
            end
        end
        -- convoy has been dispatched, remove it from the convoys list
        veafSpawn.spawnedConvoys[name] = nil
    end
    if foundOne then
        trigger.action.outText("All convoys cleaned up", 10)
    else
        trigger.action.outText("No convoy found", 10)
    end
end    

function veafSpawn.JTACAutoLase(groupName, laserCode, radioData)
    veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.JTACAutoLase()")
    veaf.loggers.get(veafSpawn.Id):trace(string.format("groupName=%s",tostring(groupName)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("laserCode=%s",tostring(laserCode)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("radioData=%s\n",veaf.p(radioData)))
    local _radio = radioData or {}
    veaf.loggers.get(veafSpawn.Id):trace(string.format("_radio=%s\n",veaf.p(_radio)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("calling CTLD"))
    ctld.JTACAutoLase(groupName, laserCode, false, "all", nil, _radio)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("CTLD called"))
end
    
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- air units templates
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafAirUnitTemplate object
-------------------------------------------------------------------------------------------------------------------------------------------------------------
VeafAirUnitTemplate = {}

function VeafAirUnitTemplate:new(objectToCopy)
    local objectToCreate = objectToCopy or {} -- create object if user does not provide one
    setmetatable(objectToCreate, self)
    self.__index = self

    -- init the new object

    -- name
    objectToCreate.name = nil
    --  coalition (0 = neutral, 1 = red, 2 = blue)
    objectToCreate.coalition = nil
    -- route, only for veaf commands (groups already have theirs)
    objectToCreate.route = nil
    objectToCreate.humanName = nil
    objectToCreate.groupData = nil

    return objectToCreate
end

---
--- setters and getters
---

function VeafAirUnitTemplate:setName(value)
    self.name = value
    return self
end

function VeafAirUnitTemplate:getName()
    return self.name
end

function VeafAirUnitTemplate:setCoalition(value)
    self.coalition = value
    return self
end

function VeafAirUnitTemplate:getCoalition()
    return self.coalition
end

function VeafAirUnitTemplate:setGroupData(value)
    self.groupData = value
    return self
end

function VeafAirUnitTemplate:getGroupData()
    return self.groupData
end

function veafSpawn.initializeAirUnitTemplates()
    
    veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.initializeAirUnitTemplates()")

    -- find groups with the air units template prefix
    veaf.loggers.get(veafSpawn.Id):debug("find groups with the air units template prefix")
    local _prefix = veafSpawn.AirUnitTemplatesPrefix:upper()
    veaf.loggers.get(veafSpawn.Id):trace("_prefix=%s",_prefix)
    local _templateGroups = {}
    local _groups = veaf.getGroupsOfCoalition()
    for _, group in pairs(_groups) do
        local _name = group:getName():upper()
        --veaf.loggers.get(veafSpawn.Id):trace("_name=%s",_name)
        if string.sub(_name,1,string.len(_prefix)) == _prefix then
            table.insert(_templateGroups, group)
        end
    end

    veaf.loggers.get(veafSpawn.Id):trace("_templateGroups=%s", _templateGroups)
    for _, group in pairs(_templateGroups) do
        local _groupName = group:getName()
        veaf.loggers.get(veafSpawn.Id):trace("_groupName=%s", _groupName)
        local _template = VeafAirUnitTemplate:new():setName(_groupName)
        veafSpawn.airUnitTemplates[_groupName:upper()] = _template
    end

    -- find groups within the veafSpawn.SpawnablePlanes table
    -- DOES NOT WORK YET
    if veafSpawn.SpawnablePlanes then 
        veaf.loggers.get(veafSpawn.Id):debug("find groups within the veafSpawn.SpawnablePlanes table")
        for _, groupData in pairs(veafSpawn.SpawnablePlanes) do
            local _groupName = groupData.name
            veaf.loggers.get(veafSpawn.Id):trace("_groupName=%s", _groupName)
            groupData.country="russia"
            groupData.countryId=0
            groupData.category="plane"
            groupData.coalition="red"
            groupData.uncontrolled=false
            groupData.hidden=false
            local _template = VeafAirUnitTemplate:new():setName(_groupName):setGroupData(groupData)
            veafSpawn.airUnitTemplates[_groupName:upper()] = _template
        end
    end

end

function veafSpawn.listAllCAP(unitName)
    veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.listAllCAP(unitName=%s)",unitName)
    local sorted = {}
    for name, template in pairs(veafSpawn.airUnitTemplates) do
        local _name = template:getName():sub(veafSpawn.AirUnitTemplatesPrefix:len()+1)
        table.insert(sorted, _name)
    end
    table.sort(sorted)
    local text = ""
    for _, name in pairs(sorted) do
        text = text .. name .. "\n"
    end
    if text == "" then
        veaf.outTextForUnit(unitName, "No CAP available for spawn", 10)
    else
        veaf.outTextForUnit(unitName, text, 30)
    end
end

function veafSpawn.spawnAFAC(spawnSpot, name, country, altitude, speed, hdg, frequency, mod, code, immortal, silent, hiddenOnMFD)
    
    local coalition = veaf.getCoalitionForCountry(country, true)
    if not coalition then
        veaf.loggers.get(veafSpawn.Id):error("No country/coalition for AFAC !")
        return nil
    end

    -- find template
    local _name = veafSpawn.AirUnitTemplatesPrefix .. name 
    local _template = veafSpawn.airUnitTemplates[_name:upper()]
    if not _template then
        local message = string.format("The AFAC aircraft template could not be found for \"%s\"", veaf.p(name))
        veaf.loggers.get(veafSpawn.Id):info(message)
        trigger.action.outTextForCoalition(coalition, message, 15)
        return nil
    end
    veaf.loggers.get(veafSpawn.Id):trace("found template=%s",_template)
    local groupName = _template:getName()

    if not veafSpawn.AFAC.numberSpawned[coalition] then
        veafSpawn.AFAC.numberSpawned[coalition] = 1
    elseif veafSpawn.AFAC.numberSpawned[coalition] > veafSpawn.AFAC.maximumAmount then
        veaf.loggers.get(veafSpawn.Id):info("The limit for AFACs was reached, one needs to be destroyed")
        if not silent then trigger.action.outTextForCoalition(coalition, "The limit for AFACs was reached, one needs to be destroyed", 15) end
        return false
    end

    veaf.loggers.get(veafSpawn.Id):info(string.format("number of AFAC spawned : %s", veaf.p(veafSpawn.AFAC.numberSpawned[coalition])))

    local AFAC_num = veafSpawn.AFAC.numberSpawned[coalition]
    local newGroupName = veafSpawn.AFAC.callsigns[coalition][AFAC_num].name
    for i = 1, veafSpawn.AFAC.maximumAmount do
        if veafSpawn.AFAC.callsigns[coalition][i].taken == false then
            newGroupName = veafSpawn.AFAC.callsigns[coalition][i].name
            AFAC_num = i
            break
        end
    end
    veaf.loggers.get(veafSpawn.Id):trace("newGroupName=%s",newGroupName)
    veaf.loggers.get(veafSpawn.Id):trace("AFAC_num=%s",AFAC_num)
    veaf.loggers.get(veafSpawn.Id):trace("AFAC coalition=%s",coalition)
    
    --essentially the same counter but for the template group itself, not for all AFACs
    if not veafSpawn.spawnedNamesIndex[groupName] then
        veafSpawn.spawnedNamesIndex[groupName] = 1
    end

    local codeDigit = {}
    codeDigit = veaf.laserCodeToDigit(code)

    local altitude = altitude or 15000
    if altitude <= 8000 then
        altitude = 15000 -- ft
    end

    local speed = speed or 150 -- kn
    -- convert speed to m/s
    speed = speed/1.94384

    -- convert altitude to meters
    altitude = altitude * 0.3048 -- meters

    --convert heading to radians
    if hdg then
        hdg = hdg * math.pi / 180
    else
        hdg = 0
    end

    local distanceFromTeleport = 3000 --distance between the orbit point and the teleport point in meters

    --calculate DCS radio frequency based on which AFAC out of 8 this is
    local dcsFrequency = veafSpawn.AFAC.baseAFACfrequency[coalition]+(AFAC_num-1)*50000 -- .05 MHz increments

    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=%s", veaf.p(spawnSpot))
    veaf.loggers.get(veafSpawn.Id):trace("name=%s", veaf.p(name))
    veaf.loggers.get(veafSpawn.Id):trace("country=%s", veaf.p(country))
    veaf.loggers.get(veafSpawn.Id):trace("altitude (m)=%s", veaf.p(altitude))
    veaf.loggers.get(veafSpawn.Id):trace("speed (m/s)=%s", veaf.p(speed))
    veaf.loggers.get(veafSpawn.Id):trace("frequency=%s", veaf.p(frequency))
    veaf.loggers.get(veafSpawn.Id):trace("dcsFrequency=%s", veaf.p(dcsFrequency))
    veaf.loggers.get(veafSpawn.Id):trace("code=%s", veaf.p(code))
    veaf.loggers.get(veafSpawn.Id):trace("mod=%s", veaf.p(mod))
    veaf.loggers.get(veafSpawn.Id):trace("silent=%s", veaf.p(silent))
    veaf.loggers.get(veafSpawn.Id):trace("hiddenOnMFD=%s", veaf.p(hiddenOnMFD))

    local teleportSpot = {}
    teleportSpot.x = spawnSpot.x - distanceFromTeleport*math.cos(hdg) --teleport spot is 3km south of the orbit point
    teleportSpot.y = spawnSpot.z - distanceFromTeleport*math.sin(hdg)
    teleportSpot.alt = altitude
    teleportSpot.speed = speed

    --define 2 point route + teleport Waypoint
    local WP = {}
    WP.one = {}
    WP.two = {}
    WP.three = {}
    WP.one.x = teleportSpot.x
    WP.one.y = teleportSpot.y
    WP.two.x = spawnSpot.x - distanceFromTeleport*math.cos(hdg)/2
    WP.two.y = spawnSpot.z - distanceFromTeleport*math.sin(hdg)/2
    WP.three.x = spawnSpot.x
    WP.three.y = spawnSpot.z

    veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "AFAC", "teleportPoint", WP.one)
    veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "AFAC", "setupPoint", WP.two)
    veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "AFAC", "orbitPoint", WP.three)

	local newRoute = { 
        ["points"] = { 
            -- first point
            [1] = { 
                ["type"] = "Turning Point",
                ["action"] = "Turning Point",
                ["x"] = WP.two.x, --1500m south of the orbit point
                ["y"] = WP.two.y,
                ["alt"] = altitude, -- in meters
                ["alt_type"] = "BARO", 
                ["speed"] = speed,  -- speed in m/s
                ["speed_locked"] = true, 
                ["task"] = {
                    ["id"] = "ComboTask",
                    ["params"] = {
                        ["tasks"] = {
                            [1] = {
                                ["id"]="FAC",
                                ["params"] = {
                                    ["frequency"]=dcsFrequency,
                                    ["modulation"]=0, --0 is AM, 1 is FM
                                    ["callname"]=AFAC_num,
                                    ["number"]=7+coalition, --number x as in it's callsign Springfield x-1 for example
                                    ["priority"]=0,
                                }
                            } -- end of [1]
                        } -- end of tasks
                    } -- end of params
                } -- end of task
            }, -- end of waypoint 1
            [2] = {
                ["type"] = "Turning Point",
                ["action"] = "Turning Point",
                ["x"] = WP.three.x,
                ["y"] = WP.three.y,
                ["alt"] = altitude, -- in meters
                ["alt_type"] = "BARO", 
                ["speed"] = speed,  -- speed in m/s
                ["speed_locked"] = true, 
                ["task"] = {
                    ["id"] = "ComboTask",
                    ["params"] = {
                        ["tasks"] = {
                            [1] = {
                                ["id"] = "Orbit",
                                ["params"] = 
                                {
                                    ["altitude"] = altitude, -- in meters,
                                    ["pattern"] = "Circle",
                                    ["speed"] = speed,  -- speed in m/s
                                }, -- end of ["params"]
                            } -- end of [1]
                        } -- end of ["tasks"]
                    } -- end of ["params"]
                } -- end of ["task"]
            } -- end of waypoint 2
        }
    }

    -- (re)spawn group
    local vars = {}
    vars.gpName = _template:getName()
    vars.name = _template:getName()
    --vars.groupData = _template:getGroupData()
    --replace the callsign to prevent interractions
    vars.route = newRoute
    vars.action = 'clone'
    vars.point = teleportSpot
    vars.newGroupName = newGroupName

    local newGroup = mist.teleportToPoint(vars, true)
    if not newGroup then
        veaf.loggers.get(veafSpawn.Id):error("cannot respawn group %s",veaf.p(vars.name))
        return nil
    end
    if country and #country > 0 then
        newGroup.coalition = coalition
        newGroup.countryId = veaf.getCountryId(country)
    end
    --newGroup.task = "AFAC"
    veaf.loggers.get(veafSpawn.Id):trace("newGroup=%s", veaf.p(newGroup, nil, {"route", "payload"}))

    --setup of the new group
    local unit = newGroup.units[1]
    if not unit then
        veaf.loggers.get(veafSpawn.Id):error("cannot get first unit of group %s",veaf.p(newGroup:getName()))
        return nil
    end

    unit.skill = "Excellent"
    newGroup.hidden=false
    newGroup.name = newGroupName
    newGroup.hiddenOnMFD = hiddenOnMFD

    local unitName = newGroupName
    veaf.loggers.get(veafSpawn.Id):trace("unitName=%s",unitName)
    unit.unitName = unitName
    unit.name = unitName
    newGroup.sameName = true

    unit.alt = teleportSpot.alt

    veaf.loggers.get(veafSpawn.Id):trace("newGroup=%s", veaf.p(newGroup, nil, {"route", "payload"}))
    local _spawnedGroup = mist.dynAdd(newGroup)

    if _spawnedGroup then
        veaf.loggers.get(veafSpawn.Id):trace("_spawnedGroup=%s", veaf.p(_spawnedGroup, nil, {"route", "payload"}))
        veaf.loggers.get(veafSpawn.Id):trace("_spawnedGroup.name=%s",_spawnedGroup.name)
        --mist.goRoute(_spawnedGroup.name, newRoute)

        _spawnedGroup.category = "AIRPLANE"
        _spawnedGroup.country = country
        veaf.loggers.get(veafSpawn.Id):trace("_spawnedGroup=%s", veaf.p(_spawnedGroup))
        veafSpawn.AFAC.missionData[coalition][AFAC_num] = _spawnedGroup --since MIST does not store cloned group data, this is a bit of trickery to allow teleporting AFACs

        -- start lasing 
        if ctld then 
            ctld.cleanupJTAC(_spawnedGroup.name)
            local radioData = {freq=frequency, mod=mod, name=_spawnedGroup.name}
            veafSpawn.JTACAutoLase(_spawnedGroup.name, code, radioData)
        end

        local humanFrequency = dcsFrequency/1000000
        local text = "AFAC " .. string.format(veafSpawn.AFAC.numberSpawned[coalition]) .. "/" .. string.format(veafSpawn.AFAC.maximumAmount) .. " - " .. string.format(_spawnedGroup.name) .. " (" .. string.format(country) .. ") - on " .. string.format(humanFrequency) .. "AM (DCS AFAC) or " .. string.format(frequency) .. string.upper(mod) .. " (SRS)"
        veaf.loggers.get(veafSpawn.Id):info(text)
        if not silent then trigger.action.outTextForCoalition(coalition, text, 15) end
 
        local _dcsSpawnedGroup = Group.getByName(_spawnedGroup.name)
        local controller = _dcsSpawnedGroup:getController()

        if immortal then
            veaf.loggers.get(veafSpawn.Id):trace("AFAC immortalized")
            -- JTAC needs to be invisible and immortal
            local _setImmortal = {
                id = 'SetImmortal',
                params = {
                    value = true
                }
            }
            -- invisible to AI, Shagrat
            local _setInvisible = {
                id = 'SetInvisible',
                params = {
                    value = true
                }
            }

            Controller.setCommand(controller, _setImmortal)
            Controller.setCommand(controller, _setInvisible)
        end

        --set the callsign to avoid desyncs in the DCS JTAC menu
        local _setCallsign = { 
            id = 'SetCallsign', 
            params = { 
              callname = AFAC_num, 
              number = 9, 
            } 
        }

        Controller.setCommand(controller, _setCallsign)

        if veafNamedPoints and not silent then
            text = "AFAC" .. " - " .. string.format(_spawnedGroup.name) .. " - " .. string.format(humanFrequency) .. "AM (DCS) or " .. string.format(frequency) .. string.upper(mod) .. " (SRS)"
            veafNamedPoints.namePoint({x=spawnSpot.x, y=altitude, z=spawnSpot.z}, text, veaf.getCoalitionForCountry(country, true), true)
        end

        veafSpawn.afacWatchdog(newGroupName, AFAC_num, coalition, text)
        veafSpawn.AFAC.callsigns[coalition][AFAC_num].taken = true
        veafSpawn.spawnedNamesIndex[groupName] = veafSpawn.spawnedNamesIndex[groupName] + 1
        veafSpawn.AFAC.numberSpawned[coalition] = veafSpawn.AFAC.numberSpawned[coalition] + 1
        
        return _spawnedGroup.name
    else
        veaf.loggers.get(veafSpawn.Id):error("MIST could not add AFAC")
        return nil
    end
end

function veafSpawn.afacWatchdog(afacGroupName, AFAC_num, coalition, markName)
    if afacGroupName and not Group.getByName(afacGroupName) then
        veaf.loggers.get(veafSpawn.Id):info(string.format("AFAC named=%s is KIA, removing mark (if it exists) and allowing it to be spawned again", veaf.p(afacGroupName)))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("markName=%s", veaf.p(markName)))

        if veafNamedPoints and markName then
            local existingPoint = veafNamedPoints.getPoint(markName)
            veaf.loggers.get(veafSpawn.Id):trace(string.format("existingPoint=%s", veaf.p(existingPoint)))
            if existingPoint and existingPoint.markerId then
                -- delete the existing point
                trigger.action.removeMark(existingPoint.markerId)
            end
        end

        --Make the callsign index available again for spawn
        veaf.loggers.get(veafSpawn.Id):trace(string.format("AFAC_num=%s", veaf.p(AFAC_num)))
        veafSpawn.AFAC.callsigns[coalition][AFAC_num].taken = false
        veafSpawn.AFAC.numberSpawned[coalition] = veafSpawn.AFAC.numberSpawned[coalition] - 1
        mist.DBs.unitsByName[afacGroupName] = nil --MIST does not do it on it's own, I highly recommend looking for an alternative, this is to spawn the AFAC once again with the unit name equal to the group name
        mist.DBs.groupsByName[afacGroupName] = nil
        veafSpawn.AFAC.missionData[coalition][AFAC_num] = nil
    else
        veaf.loggers.get(veafSpawn.Id):trace(string.format("AFAC named=%s is alive", veaf.p(afacGroupName)))

        --update the mark if the AFAC moves
        if veafNamedPoints and markName then
            local existingPoint = veafNamedPoints.getPoint(markName)
            veaf.loggers.get(veafSpawn.Id):trace(string.format("existingAFACmarker=%s", veaf.p(existingPoint)))
            if existingPoint and existingPoint.markerId then
                local AFAC_points = veafSpawn.AFAC.missionData[coalition][AFAC_num].route.points
                local orbitPoint = AFAC_points[#AFAC_points]
                if existingPoint.x ~= orbitPoint.x and existingPoint.z ~= orbitPoint.y then
                    -- delete the existing point
                    veaf.loggers.get(veafSpawn.Id):trace(string.format("Marker needs updating, AFAC moved, newAFACmarker=%s", veaf.p(orbitPoint)))
                    trigger.action.removeMark(existingPoint.markerId)
                    veafNamedPoints.namePoint({x=orbitPoint.x, y=orbitPoint.alt, z=orbitPoint.y}, markName, coalition, true)
                end
            end
        end

        mist.scheduleFunction(veafSpawn.afacWatchdog, {afacGroupName, AFAC_num, coalition, markName}, timer.getTime()+120)
    end
end

function veafSpawn.spawnCombatAirPatrol(spawnSpot, radius, name, country, altitude, altdelta, hdg, distance, speed, capRadius, skill, silent, hiddenOnMFD)
    
    local coalition = veaf.getCoalitionForCountry(country, true)
    if not coalition then
        veaf.loggers.get(veafSpawn.Id):error("No country/coalition for CAP !")
        return nil
    end

    -- find template
    local _name = veafSpawn.AirUnitTemplatesPrefix .. name 
    local _template = veafSpawn.airUnitTemplates[_name:upper()]
    if not _template then
        local message = string.format("The CAP aircraft template could not be found for \"%s\"", veaf.p(name))
        veaf.loggers.get(veafSpawn.Id):info(message)
        trigger.action.outText(message, 15)
        return nil
    end
    veaf.loggers.get(veafSpawn.Id):trace("found template=%s",_template)
    local groupName = _template:getName()
    
    local radius = radius or 5000 -- m
    local altitude = altitude 
    if altitude == 0 then
        altitude = 20000 -- ft
    end
    local altdelta = altdelta or 0
    local hdg = hdg or 0
    local distance = distance or 60 -- nm
    local speed = speed or 370 -- knots
    local capRadius = capRadius or distance / 2
    local skill = skill or "random"

    -- convert distance to meters
    distance = distance * 1852 -- meters

    -- convert capRadius to meters
    capRadius = capRadius * 1852 -- meters

    -- convert speed to m/s
    speed = speed/1.94384

    -- convert altitude to meters
    altitude = altitude * 0.3048 -- meters
    altdelta = altdelta * 0.3048 -- meters

    veaf.loggers.get(veafSpawn.Id):debug("spawnSpot=%s", veaf.p(spawnSpot))
    veaf.loggers.get(veafSpawn.Id):debug("radius=%s", veaf.p(radius))
    veaf.loggers.get(veafSpawn.Id):debug("name=%s", veaf.p(name))
    veaf.loggers.get(veafSpawn.Id):debug("country=%s", veaf.p(country))
    veaf.loggers.get(veafSpawn.Id):debug("altitude=%s", veaf.p(altitude))
    veaf.loggers.get(veafSpawn.Id):debug("altdelta=%s", veaf.p(altdelta))
    veaf.loggers.get(veafSpawn.Id):debug("hdg=%s", veaf.p(hdg))
    veaf.loggers.get(veafSpawn.Id):debug("distance=%s", veaf.p(distance))
    veaf.loggers.get(veafSpawn.Id):debug("speed=%s", veaf.p(speed))
    veaf.loggers.get(veafSpawn.Id):debug("capRadius=%s", veaf.p(capRadius))
    veaf.loggers.get(veafSpawn.Id):debug("skill=%s", veaf.p(skill))
    veaf.loggers.get(veafSpawn.Id):debug("silent=%s", veaf.p(silent))
    veaf.loggers.get(veafSpawn.Id):debug("hiddenOnMFD=%s", veaf.p(hiddenOnMFD))
   
    local getRoute = function(parameters)
        local newRoute = {
            ["points"] = {
                [1] = 
                {
                    ["alt"] = parameters.altitude,
                    ["action"] = "Turning Point",
                    ["alt_type"] = "BARO",
                    ["speed"] = parameters.speed,
                    ["properties"] = 
                    {
                        ["addopt"] = 
                        {
                        }, -- end of ["addopt"]
                    }, -- end of ["properties"]
                    ["task"] = 
                    {
                        ["id"] = "ComboTask",
                        ["params"] = 
                        {
                            ["tasks"] = 
                            {
                                [1] = 
                                {
                                    ["number"] = 1,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = 
                                    {
                                        ["action"] = 
                                        {
                                            ["id"] = "Option",
                                            ["params"] = 
                                            {
                                                ["value"] = true,
                                                ["name"] = 17,
                                            }, -- end of ["params"]
                                        }, -- end of ["action"]
                                    }, -- end of ["params"]
                                }, -- end of [1]
                                [2] = 
                                {
                                    ["number"] = 2,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = 
                                    {
                                        ["action"] = 
                                        {
                                            ["id"] = "Option",
                                            ["params"] = 
                                            {
                                                ["value"] = 4,
                                                ["name"] = 18,
                                            }, -- end of ["params"]
                                        }, -- end of ["action"]
                                    }, -- end of ["params"]
                                }, -- end of [2]
                                [3] = 
                                {
                                    ["number"] = 3,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["enabled"] = true,
                                    ["params"] = 
                                    {
                                        ["action"] = 
                                        {
                                            ["id"] = "Option",
                                            ["params"] = 
                                            {
                                                ["value"] = true,
                                                ["name"] = 19,
                                            }, -- end of ["params"]
                                        }, -- end of ["action"]
                                    }, -- end of ["params"]
                                }, -- end of [3]
                                [4] = 
                                {
                                    ["enabled"] = true,
                                    ["auto"] = true,
                                    ["id"] = "WrappedAction",
                                    ["number"] = 5,
                                    ["params"] = 
                                    {
                                        ["action"] = 
                                        {
                                            ["id"] = "EPLRS",
                                            ["params"] = 
                                            {
                                                ["value"] = true,
                                                ["groupId"] = 1,
                                            }, -- end of ["params"]
                                        }, -- end of ["action"]
                                    }, -- end of ["params"]
                                }, -- end of [4]                       
                            }, -- end of ["tasks"]
                        }, -- end of ["params"]
                    }, -- end of ["task"]
                    ["type"] = "Turning Point",
                    ["ETA"] = 10000,
                    ["ETA_locked"] = false,
                    ["y"] = parameters.wp1.y,
                    ["x"] = parameters.wp1.x,
                    ["formation_template"] = "",
                    ["speed_locked"] = true,
                }, -- end of [1]
                [2] = 
                {
                    ["alt"] = parameters.altitude,
                    ["action"] = "Turning Point",
                    ["alt_type"] = "BARO",
                    ["speed"] = parameters.speed,
                    ["properties"] = 
                    {
                        ["addopt"] = 
                        {
                        }, -- end of ["addopt"]
                    }, -- end of ["properties"]
                    ["task"] = 
                    {
                        ["id"] = "ComboTask",
                        ["params"] = 
                        {
                            ["tasks"] = 
                            { 
                                -- [1] = 
                                -- {
                                --     ["number"] = 1,
                                --     ["auto"] = false,
                                --     ["enabled"] = true,
                                --     ["id"] = "EngageTargetsInZone",
                                --     ["params"] = {
                                --         ["noTargetTypes"] = {
                                --             [1] = "Cruise missiles",
                                --             [2] = "Antiship Missiles",
                                --             [3] = "AA Missiles",
                                --             [4] = "AG Missiles",
                                --             [5] = "SA Missiles",
                                --         }, -- end of ["noTargetTypes"]
                                --         ["priority"] = 0,
                                --         ["targetTypes"] = {
                                --             [1] = "Air",
                                --         }, -- end of ["targetTypes"]
                                --         ["value"] = "Air;",
                                --         ["x"] = parameters.targetZone.x,
                                --         ["y"] = parameters.targetZone.y,
                                --         ["zoneRadius"] = parameters.targetZone.radius,
                                --     }, -- end of ["params"]
                                -- }, -- end of [1]                       
                            }, -- end of ["tasks"]
                        }, -- end of ["params"]
                    }, -- end of ["task"]
                    ["type"] = "Turning Point",
                    ["ETA"] = 20000,
                    ["ETA_locked"] = false,
                    ["y"] = parameters.wp2.y,
                    ["x"] = parameters.wp2.x,
                    ["formation_template"] = "",
                    ["speed_locked"] = true,
                }, -- end of [2]
                [3] = 
                {
                    ["alt"] = parameters.altitude,
                    ["action"] = "Turning Point",
                    ["alt_type"] = "BARO",
                    ["speed"] = parameters.speed,
                    ["properties"] = 
                    {
                        ["addopt"] = 
                        {
                        }, -- end of ["addopt"]
                    }, -- end of ["properties"]
                    ["task"] = 
                    {
                        ["id"] = "ComboTask",
                        ["params"] = 
                        {
                            ["tasks"] = 
                            {
                                [1] = 
                                {
                                    ["enabled"] = true,
                                    ["auto"] = false,
                                    ["id"] = "WrappedAction",
                                    ["number"] = 1,
                                    ["params"] = 
                                    {
                                        ["action"] = 
                                        {
                                            ["id"] = "SwitchWaypoint",
                                            ["params"] = 
                                            {
                                                ["goToWaypointIndex"] = 2,
                                                ["fromWaypointIndex"] = 3,
                                            }, -- end of ["params"]
                                        }, -- end of ["action"]
                                    }, -- end of ["params"]
                                }, -- end of [1]
                            }, -- end of ["tasks"]
                        }, -- end of ["params"]
                    }, -- end of ["task"]
                    ["type"] = "Turning Point",
                    ["ETA"] = 30000,
                    ["ETA_locked"] = false,
                    ["y"] = parameters.wp3.y,
                    ["x"] = parameters.wp3.x,
                    ["formation_template"] = "",
                    ["speed_locked"] = true,
                }, -- end of [3]
            }
        }

        return newRoute
    end
    
    -- find spawn spot
    if altdelta then 
        altitude = altitude + math.random(0, altdelta*2) - altdelta
    end
    local position = mist.getRandPointInCircle(spawnSpot, radius)
    position.z = position.y 
    position.y = altitude
    veaf.loggers.get(veafSpawn.Id):debug("final spawn, position=%s",position)

    -- compute route
    local headingRad = mist.utils.toRadian(hdg)
    local parameters = {
        altitude = altitude,
        speed = speed + (speed * 0.02 * altitude / 304.8), -- convert IAS speed to TAS
        wp1 = { x = position.x, y = position.z }
    }
    parameters.wp2 = { x = parameters.wp1.x + 2500 * math.cos(headingRad), y = parameters.wp1.y + 2500 * math.sin(headingRad) } -- second wp at 2500m in the right direction
    parameters.wp3 = { x = parameters.wp2.x + distance * math.cos(headingRad), y = parameters.wp2.y + distance * math.sin(headingRad) } -- last wp at the right distance in the right direction
    parameters.targetZone = { x = parameters.wp3.x - capRadius * math.cos(headingRad), y = parameters.wp3.y - capRadius * math.sin(headingRad), radius = capRadius } -- target zone at the middle point between wp2 and wp3

    veaf.loggers.get(veafSpawn.Id):trace("to create route, parameters=%s",parameters)
    local newRoute = getRoute(parameters)
    
    veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "CAP", "wp1", parameters.wp1)
    veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "CAP", "wp2", parameters.wp2)
    veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "CAP", "wp3", parameters.wp3)
    veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "CAP", "targetZone", parameters.targetZone, nil, capRadius, {1,0,0,0.15})

    if not veafSpawn.spawnedNamesIndex[groupName] then
        veafSpawn.spawnedNamesIndex[groupName] = 1
    else
        veafSpawn.spawnedNamesIndex[groupName] = veafSpawn.spawnedNamesIndex[groupName] + 1
    end
    local newGroupName = string.format("%s #%04d", groupName, veafSpawn.spawnedNamesIndex[groupName])
    veaf.loggers.get(veafSpawn.Id):debug("indexed newGroupName=%s",newGroupName)

    -- (re)spawn group
    local vars = {}
    vars.gpName = _template:getName()
    vars.name = _template:getName()
    --vars.groupData = _template:getGroupData()
    vars.route = newRoute
    vars.action = 'clone'
    vars.point = position
    vars.newGroupName = newGroupName

    local newGroup = mist.teleportToPoint(vars, true)
    if not newGroup then
        veaf.loggers.get(veafSpawn.Id):error("cannot respawn group %s",veaf.p(vars.name))
        return nil
    end
    if country and #country > 0 then
        newGroup.countryId = veaf.getCountryId(country)
    end
    --newGroup.task = "CAP" --needs to be set in the editor
    veaf.loggers.get(veafSpawn.Id):trace("after preparation by MIST, newGroup=%s", veaf.p(newGroup, nil, {"route", "payload"}))

    newGroup.hidden = false
    newGroup.name = newGroupName
    newGroup.hiddenOnMFD = hiddenOnMFD

    for _, unit in pairs(newGroup.units) do
        unit.skill = skill
        local unitName = unit.unitName or unit.name
        veaf.loggers.get(veafSpawn.Id):trace("original unitName=%s",unitName)
        if not veafSpawn.spawnedNamesIndex[unitName] then
            veafSpawn.spawnedNamesIndex[unitName] = 1
        else
            veafSpawn.spawnedNamesIndex[unitName] = veafSpawn.spawnedNamesIndex[unitName] + 1
        end
        local spawnedUnitName = string.format("%s #%04d", unitName, veafSpawn.spawnedNamesIndex[unitName])
        unit.name = spawnedUnitName
        unit.alt = position.y
        veaf.loggers.get(veafSpawn.Id):debug("indexed spawnedUnitName=%s",spawnedUnitName)
    end

    veaf.loggers.get(veafSpawn.Id):trace("before mist.dynAdd, newGroup=%s", veaf.p(newGroup, nil, {"route", "payload"}))
    local _spawnedGroup = mist.dynAdd(newGroup)
    if not _spawnedGroup then
        veaf.loggers.get(veafSpawn.Id):error("cannot spawn group %s",veaf.p(newGroup.name))
        return nil
    end
    veaf.loggers.get(veafSpawn.Id):debug("after mist.dynAdd, _spawnedGroup.name=%s",_spawnedGroup.name)
    veaf.loggers.get(veafSpawn.Id):trace("after mist.dynAdd, _spawnedGroup=%s", veaf.p(_spawnedGroup, nil, {"route", "payload"}))

    local _dcsSpawnedGroup = Group.getByName(_spawnedGroup.name)
    veaf.loggers.get(veafSpawn.Id):trace("result of dcs side getByName, _dcsSpawnedGroup=%s", veaf.p(_dcsSpawnedGroup, nil, {"route", "payload"}))
    veaf.loggers.get(veafSpawn.Id):debug("result of dcs side getByName, _dcsSpawnedGroup.name=%s", _dcsSpawnedGroup:getName())
    for index, unit in pairs(_dcsSpawnedGroup:getUnits()) do
        veaf.loggers.get(veafSpawn.Id):debug("result of dcs side getByName, _dcsSpawnedGroup.unit[%s].name=%s", index, unit:getName())
    end

    local controller = _dcsSpawnedGroup:getController()
    controller:setOption(AI.Option.Air.id.PROHIBIT_AA, true)
    veaf.loggers.get(veafSpawn.Id):debug("restricting AA engagements for the AI to no go dumb, starting target watchdog...")
    mist.scheduleFunction(veafSpawn.CAPTargetWatchdog, {_spawnedGroup.name, controller, coalition, {x = parameters.targetZone.x, z = parameters.targetZone.y}, parameters.targetZone.radius}, timer.getTime()+veafSpawn.CAPwatchdogDelay)

    local message = string.format("A CAP of %s (%s) has been spawned", name, country)
    veaf.loggers.get(veafSpawn.Id):info(message)
    if not silent then trigger.action.outText(message, 15) end

    return _spawnedGroup.name
end

function veafSpawn.CAPTargetWatchdog(CAPname, CAPcontroller, CAPcoalition, zone_position, zoneRadius, TargetList, numberOfTasks)
    
    local CAPdead = false
    local CAPgroup = Group.getByName(CAPname)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("Watchdog for CAP %s...", veaf.p(CAPname)))

    if CAPname and not CAPgroup then
        CAPdead = true
        veaf.loggers.get(veafSpawn.Id):debug("watchdog found that Jester's dead ! (CAP is dead), stopping watchdog")
    else
        local CAPlanded = true

        for _,unit in pairs(CAPgroup:getUnits()) do
            if unit and unit:inAir() then
                CAPlanded = false
                veaf.loggers.get(veafSpawn.Id):trace("watchdog found that CAP is still in the air...")
                break
            end
        end
    
        if CAPlanded then
            CAPgroup:destroy()
            veaf.loggers.get(veafSpawn.Id):debug("Destroying landed CAP, stopping watchdog")
        else
            local CAPposition = veaf.getAveragePosition(CAPgroup)
            local CAPoutOfArea = {}
            local CAPsize = CAPgroup:getSize()
            for i=1, CAPsize do
                CAPoutOfArea[i] = true
            end
            veaf.loggers.get(veafSpawn.Id):trace(string.format("CAP is composed of %s alive/active units", veaf.p(CAPsize)))

            veaf.loggers.get(veafSpawn.Id):trace("Looking in CAP zone for targets...")
            local time = timer.getTime()
            local TargetList = TargetList or {}
            local numberOfTasks = numberOfTasks or 0

            local targetVolume = {
                id = world.VolumeType.SPHERE,
                params = {
                    point = zone_position,
                    radius = zoneRadius,
                },
            }

            local allowAA = function(foundUnit)
                local TargetId = foundUnit:getID()
                local group = foundUnit:getGroup()
                local unitIndex = nil --foundUnit:getNumber() returns the Number of the unit as per the mission editor, which won't change when an element dies unlike for every other method related to units
                for index,unit in pairs(group:getUnits()) do
                    if unit:getID() == TargetId then
                        unitIndex=index
                    end
                end
                local name = group:getName()
                veaf.loggers.get(veafSpawn.Id):trace(string.format("Checking group named %s, unitIndex=%s...", veaf.p(name), veaf.p(unitIndex)))

                if CAPname ~= name then
                    local isAirborn = foundUnit:isActive() and foundUnit:inAir()
                    local foundCoalition = foundUnit:getCoalition()
                    local foundCategory = group:getCategory()

                    veaf.loggers.get(veafSpawn.Id):trace(string.format("Found unit in CAP zone ! unit.category=%s (%s for airplanes, %s for helos), unitCoalition=%s (CAP coalition is %s), isAirborn=%s", veaf.p(foundCategory), Group.Category.AIRPLANE, Group.Category.HELICOPTER, veaf.p(foundCoalition), CAPcoalition, veaf.p(isAirborn)))

                    if isAirborn and foundCategory and foundCoalition and foundCoalition ~= CAPcoalition and (foundCategory == Group.Category.AIRPLANE or foundCategory == Group.Category.HELICOPTER) then
                        local foundDesc = foundUnit:getDesc()
                        local foundAttributes = foundDesc.attributes
                        local foundType = foundUnit:getTypeName()
                        local foundPosition = foundUnit:getPosition().p
                        local distance = mist.utils.get2DDist(foundPosition, CAPposition)
                        veaf.loggers.get(veafSpawn.Id):trace(string.format("unitID %s is a %s at position %s. This is %s meters away from the average CAP position", veaf.p(TargetId), veaf.p(foundType), veaf.p(foundPosition), veaf.p(distance)))

                        local priority = nil
                        local isNew = true
                        if TargetList then
                            for _,oldTarget in pairs(TargetList) do
                                if oldTarget.TargetId == TargetId then
                                    veaf.loggers.get(veafSpawn.Id):trace("Target has already been seen...")
                                    isNew = false
                                end                                    
                            end
                        end

                        if foundAttributes["Fighters"] or foundAttributes["Multirole fighters"] then
                            veaf.loggers.get(veafSpawn.Id):trace("Target is a Fighter")
                            priority = math.floor(distance/2)
                        elseif foundAttributes["Strategic bombers"] then
                            veaf.loggers.get(veafSpawn.Id):trace("Target is a strategic bomber")
                            priority = math.floor(distance/1.5) + 10000
                        elseif foundAttributes["Bombers"] then
                            veaf.loggers.get(veafSpawn.Id):trace("Target is a bomber")
                            priority = math.floor(distance/1) + 15000
                        elseif foundAttributes["UAVs"] and foundType ~= "Yak-52" then --wtf ED, Yak-52 UAV master race
                            veaf.loggers.get(veafSpawn.Id):trace("Target is a UAV (except the Yak-52, that shit is not a UAV ED)")
                            priority = math.floor(distance/0.5) + 15000
                        elseif foundAttributes["AWACS"] then
                            veaf.loggers.get(veafSpawn.Id):trace("Target is an AWACS")
                            priority = math.floor(distance/0.5) + 15000
                        elseif foundAttributes["Transports"] then
                            veaf.loggers.get(veafSpawn.Id):trace("Target is a Transport")
                            priority = math.floor(distance/0.5) + 15000
                        elseif foundAttributes["Battle airplanes"] or foundAttributes["Battleplanes"] then
                            veaf.loggers.get(veafSpawn.Id):trace("Target is a generic Battleplane")
                            priority = math.floor(distance/0.25) + 15000
                        elseif foundAttributes["Helicopters"] or foundAttributes["Attack helicopters"] or foundAttributes["Transport helicopters"] then
                            veaf.loggers.get(veafSpawn.Id):trace("Target is a Helicopter")
                            priority = math.floor(distance/0.1) + 20000
                        else
                            veaf.loggers.get(veafSpawn.Id):trace("Target has unknown attributes, calculating generic priority")
                            priority = math.floor(distance/0.25) + 15000
                        end
                        -- https://www.geogebra.org/calculator if you want to visualize, type in functions y=x/factor + offset and set points on each curve. y is the priority, x the distance
                    
                        veaf.loggers.get(veafSpawn.Id):trace(string.format("Calculated priority : %s", veaf.p(priority)))

                        if isNew then
                            table.insert(TargetList, {isNew = true, seenAt = time, priority = priority, TargetId = TargetId, unit = foundUnit})
                        else
                            for _,oldTarget in pairs(TargetList) do
                                if oldTarget.TargetId == TargetId then
                                    veaf.loggers.get(veafSpawn.Id):trace("Refreshing unit that had already been seen in the TargetList")

                                    oldTarget.seenAt = time
                                    oldTarget.priority = priority
                                end
                            end
                        end
                    end
                else
                    veaf.loggers.get(veafSpawn.Id):trace("Unit is part of the CAP and is in Area")

                    CAPoutOfArea[unitIndex] = false
                end
            end

            world.searchObjects(Object.Category.UNIT, targetVolume, allowAA)

            local isCAPoutOfArea = false
            for i=1, CAPsize do
                if CAPoutOfArea[i] then
                    isCAPoutOfArea = true
                    break
                end
            end

            if isCAPoutOfArea then
                veaf.loggers.get(veafSpawn.Id):debug("CAP is outside of it's area ! Discarding targets...")
            else
                veaf.loggers.get(veafSpawn.Id):debug("CAP was found in it's area...")
            end

            if #TargetList > 0 and not isCAPoutOfArea then
                veaf.loggers.get(veafSpawn.Id):debug("Watchdog has targets ! Allowing AA for CAP")
                CAPcontroller:setOption(AI.Option.Air.id.PROHIBIT_AA, false)
                CAPcontroller:setOption(0,0) --weapons free

                --sort the list in reverse priority order so that the last task to be pushed in spot #1 is the one with the lowest priority, couldn't quite figure out which way works best, since this one makes the least sense it seems appropriate for DCS
                table.sort(TargetList, function(a,b) return a.priority < b.priority end)
                veaf.loggers.get(veafSpawn.Id):trace(string.format("Targets List : %s", veaf.p(TargetList)))
                for index,target in pairs(TargetList) do
                    veaf.loggers.get(veafSpawn.Id):trace(string.format("Checking target %s for pushTask to CAP...", index))

                    --system to perhaps not add the unit until it is detected ?
                    -- local isDetected = false
                    -- for CAPindex,unit in pairs(CAPgroup:getUnits()) do
                    --     if unit:getController():isTargetDetected(target.unit).detected then
                    --         veaf.loggers.get(veafSpawn.Id):trace(string.format("Target is detected by CAP unit %s", CAPindex))
                    --         isDetected = true
                    --     end
                    -- end

                    --what would be ideal would be to not add, simply update, tasks that have already been added but since the priority is updated continually the tasks need to be updated and regardless it seems that what matters is which task is assigned first and not priority so they need to be discarded all together anyways
                    if not Unit.isExist(target.unit) or not target.unit:inAir() or time > target.seenAt + veafSpawn.CAPwatchdogDelay*2 then
                        veaf.loggers.get(veafSpawn.Id):trace("Target is outdated, landed or doesn't exist, removing it from the list")
                        table.remove(TargetList, index)
                    else
                        local engageUnit = {
                            id = 'EngageUnit',
                            params = {
                                unitId = target.TargetId,
                                weaponType = "ALL",
                                priority = target.priority,
                            }
                        }

                        CAPcontroller:pushTask(engageUnit)

                        numberOfTasks = numberOfTasks + 1 
                    end
                end
            else
                while numberOfTasks ~= 0 do --using CAPcontroller:hasTask() seems to always return true
                    veaf.loggers.get(veafSpawn.Id):debug("resetting task #%s", veaf.p(numberOfTasks))
                    CAPcontroller:resetTask() --:popTask() crashes the game
                    numberOfTasks = numberOfTasks - 1
                end

                veaf.loggers.get(veafSpawn.Id):debug("Watchdog found no targets, prohibiting AA for CAP")
                CAPcontroller:setOption(AI.Option.Air.id.PROHIBIT_AA, true)
                CAPcontroller:setOption(0,3) --return fire
            end

            veaf.loggers.get(veafSpawn.Id):debug(string.format("Rescheduling watchdog in %s seconds", veafSpawn.CAPwatchdogDelay))
            veaf.loggers.get(veafSpawn.Id):debug("===============================================================================")
            mist.scheduleFunction(veafSpawn.CAPTargetWatchdog, {CAPname, CAPcontroller, CAPcoalition, zone_position, zoneRadius, TargetList, numberOfTasks}, timer.getTime()+veafSpawn.CAPwatchdogDelay)
        end
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Mission master features
-------------------------------------------------------------------------------------------------------------------------------------------------------------
veafSpawn.missionMasterRunnables = {}
veafSpawn.missionMasterRunnables.__silent = true

function veafSpawn.missionMasterSetMessagingMode(silent, toGroupId)
    veafSpawn.missionMasterRunnables.__silent = silent
    veafSpawn.missionMasterRunnables.__toGroupId = toGroupId
end

function veafSpawn.missionMasterOutText(message)
    -- don't send the message if __silent is true
    if not(veafSpawn.missionMasterRunnables.__silent) then 
        if (veafSpawn.missionMasterRunnables.__toGroupId) then
            -- send to a group
            trigger.action.outTextForGroup(veafSpawn.missionMasterRunnables.__toGroupId, message, 5) 
        else
            -- send to all
            trigger.action.outText(message, 5) 
        end
    end
end

function veafSpawn.missionMasterAddRunnable(name, code, parameters)
    veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.missionMasterAddRunnable(name=%s)",name)
    veafSpawn.missionMasterRunnables[veaf.ifnn(name, "upper")] = { code, parameters }
end

function veafSpawn.missionMasterRun(name)
    veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.missionMasterRun(name=%s)",name)
    if not name or #name == 0 then
        local message = "Mission Master, `run` requires the name of the code to be run"
        veaf.loggers.get(veafSpawn.Id):warn(message)    
        veafSpawn.missionMasterOutText(message)
        return 
    end

    local code, parameters = veaf.safeUnpack(veafSpawn.missionMasterRunnables[veaf.ifnn(name, "upper")])
    if code then
        local sta, res = pcall(code, parameters)
        if sta then 
            local message = string.format("Mission Master, the runnable [%s] was successfully run and returned : %s", name, veaf.p(res))
            veaf.loggers.get(veafSpawn.Id):warn(message)    
            veafSpawn.missionMasterOutText(message)
        else
            local message = string.format("Mission Master, the runnable [%s] returned an error : %s", name, veaf.p(res))
            veaf.loggers.get(veafSpawn.Id):warn(message)
            veafSpawn.missionMasterOutText(message)
        end
    else
        local message = string.format("Mission Master, the runnable [%s] does not exist", name)
        veaf.loggers.get(veafSpawn.Id):warn(message)
        veafSpawn.missionMasterOutText(message)
    end
end

function veafSpawn.missionMasterSetFlag(name, value)
    veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.missionMasterSetFlag(name=%s, value=%s)", name, value)
    if not name or #name == 0 then
        local message = "Mission Master, `setFlag` requires the name or number of the flag"
        veaf.loggers.get(veafSpawn.Id):warn(message)
        veafSpawn.missionMasterOutText(message)
        return 
    end
    trigger.action.setUserFlag(name , value)
end

function veafSpawn.missionMasterGetFlag(name)
    veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.missionMasterGetFlag(name=%s)", name)
    if not name or #name == 0 then
        local message = "Mission Master, `getFlag` requires the name or number of the flag"
        veaf.loggers.get(veafSpawn.Id):warn(message)
        veafSpawn.missionMasterOutText(message)
        return 
    end
    local value = trigger.misc.getUserFlag(name)
    local message = string.format("Mission Master, flag [%s] has value [%s]", name, veaf.p(value))
    veaf.loggers.get(veafSpawn.Id):info(message)
    veafSpawn.missionMasterOutText(message)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafSpawn.buildRadioMenu()
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.buildRadioMenu() hideMenu%s", veaf.p(veafSpawn.HideRadioMenu)))
    if not veafSpawn.HideRadioMenu then
        veafSpawn.rootPath = veafRadio.addSubMenu(veafSpawn.RadioMenuName)
        veafRadio.addCommandToSubmenu("Available Aircraft spawns", veafSpawn.rootPath, veafSpawn.listAllCAP, nil, veafRadio.USAGE_ForAll)
        veafRadio.addCommandToSubmenu("Info on all convoys", veafSpawn.rootPath, veafSpawn.infoOnAllConvoys, nil, veafRadio.USAGE_ForGroup)
        local menuPath = veafRadio.addSubMenu("Mark closest convoy route", veafSpawn.rootPath)
        veafRadio.addCommandToSubmenu("Mark closest convoy route" , menuPath, veafSpawn.markClosestConvoyRouteWithSmoke, nil, veafRadio.USAGE_ForGroup)    
        local menuPath = veafRadio.addSubMenu("Mark closest convoy", veafSpawn.rootPath)
        veafRadio.addCommandToSubmenu("Mark closest convoy" , menuPath, veafSpawn.markClosestConvoyWithSmoke, nil, veafRadio.USAGE_ForGroup)    
        local menuPath = veafRadio.addSubMenu("Stop closest convoy", veafSpawn.rootPath)
        veafRadio.addCommandToSubmenu("Stop closest convoy" , menuPath, veafSpawn.stopClosestConvoy, nil, veafRadio.USAGE_ForGroup)    
        local menuPath = veafRadio.addSubMenu("Makes closest convoy move", veafSpawn.rootPath)
        veafRadio.addCommandToSubmenu("Make closest convoy move" , menuPath, veafSpawn.moveClosestConvoy, nil, veafRadio.USAGE_ForGroup)    
        veafRadio.addSecuredCommandToSubmenu('Cleanup all convoys', veafSpawn.rootPath, veafSpawn.cleanupAllConvoys)
        veafRadio.refreshRadioMenu()
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSpawn.initialize()
    veafSpawn.buildRadioMenu()
    veafSpawn.initializeAirUnitTemplates()
    veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafSpawn.onEventMarkChange)
end

veaf.loggers.get(veafSpawn.Id):info(string.format("Loading version %s", veafSpawn.Version))

