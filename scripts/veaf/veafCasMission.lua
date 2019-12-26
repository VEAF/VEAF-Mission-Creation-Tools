-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF cas command and functions for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Listen to marker change events and creates a CAS training mission, with optional parameters
-- * Possibilities :
-- *    - create a CAS target group, protected by SAM, AAA and manpads, to use for CAS training
-- * Works with all current and future maps (Caucasus, NTTR, Normandy, PG, ...)
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires the base veaf.lua script library (version 1.0 or higher)
-- * It also requires the veafMarkers.lua script library (version 1.0 or higher)
-- * It also requires the veafSpawn.lua script library (version 1.0 or higher)
-- * It also requires the dcsUnits.lua script library (version 1.0 or higher)
-- * It also requires the veafUnits.lua script library (version 1.0 or higher)
--
-- Load the script:
-- ----------------
-- 1.) Download the script and save it anywhere on your hard drive.
-- 2.) Open your mission in the mission editor.
-- 3.) Add a new trigger:
--     * TYPE   "4 MISSION START"
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of MIST and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of veaf.lua and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of veafMarkers.lua and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of veafSpawn.lua and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of this script and click OK.
--     * ACTION "DO SCRIPT"
--     * set the script command to "veafCasMission.initialize()" and click OK.
-- 4.) Save the mission and start it.
-- 5.) Have fun :)
--
-- Basic Usage:
-- ------------
-- 1.) Place a mark on the F10 map.
-- 2.) As text enter "_cas"
-- 3.) Click somewhere else on the map to submit the new text.
-- 4.) The command will be processed. A message will appear to confirm this
-- 5.) The original mark will disappear.
--
-- Options:
-- --------
-- Type "veaf cas mission" to create a default CAS target group
--      add ", defense 0" to completely disable air defenses
--      add ", defense [1-5]" to specify air defense cover (1 = light, 5 = heavy)
--      add ", size [1-5]" to change the group size (1 = small, 5 = huge)
--      add ", armor [1-5]" to specify armor presence (1 = light, 5 = heavy)
--      add ", spacing [1-5]" to change the groups spacing (1 = dense, 3 = default, 5 = sparse)
--
-- *** NOTE ***
-- * All keywords are CaSE inSenSITvE.
-- * Commas are the separators between options ==> They are IMPORTANT!
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafCasMission = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafCasMission.Id = "CAS MISSION - "

--- Version.
veafCasMission.Version = "1.5.0"

-- trace level, specific to this module
veafCasMission.Trace = false

--- Key phrase to look for in the mark text which triggers the command.
veafCasMission.Keyphrase = "_cas"

--- Number of seconds between each check of the CAS group watchdog function
veafCasMission.SecondsBetweenWatchdogChecks = 15

--- Number of seconds between each smoke request on the CAS targets group
veafCasMission.SecondsBetweenSmokeRequests = 180

--- Number of seconds between each flare request on the CAS targets group
veafCasMission.SecondsBetweenFlareRequests = 120

--- Name of the CAS targets vehicles group 
veafCasMission.RedCasGroupName = "Red CAS Group"

veafCasMission.RadioMenuName = "CAS MISSION (" .. veafCasMission.Version .. ")"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Radio menus paths
veafCasMission.targetMarkersPath = nil
veafCasMission.targetInfoPath = nil
veafCasMission.rootPath = nil

-- CAS Group watchdog function id
veafCasMission.groupAliveCheckTaskID = 'none'

-- Smoke reset function id
veafCasMission.smokeResetTaskID = 'none'

-- Flare reset function id
veafCasMission.flareResetTaskID = 'none'

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafCasMission.logInfo(message)
    veaf.logInfo(veafCasMission.Id .. message)
end

function veafCasMission.logDebug(message)
    veaf.logDebug(veafCasMission.Id .. message)
end

function veafCasMission.logTrace(message)
    if message and veafCasMission.Trace then
        veaf.logTrace(veafCasMission.Id .. message)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafCasMission.onEventMarkChange(eventPos, event)
    -- Check if marker has a text and the veafCasMission.keyphrase keyphrase.
    if event.text ~= nil and event.text:lower():find(veafCasMission.Keyphrase) then

        -- Analyse the mark point text and extract the keywords.
        local options = veafCasMission.markTextAnalysis(event.text)

        if options then
            -- Check options commands
            if options.casmission then
                -- check security
                if not veafSecurity.checkSecurity_L1(options.password) then return end
                -- create the group
                veafCasMission.generateCasMission(eventPos, options.size, options.defense, options.armor, options.spacing, options.disperseOnAttack)
            end
        else
            -- None of the keywords matched.
            return
        end

        -- Delete old mark.
        veafCasMission.logTrace(string.format("Removing mark # %d.", event.idx))
        trigger.action.removeMark(event.idx)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Extract keywords from mark text.
function veafCasMission.markTextAnalysis(text)

    -- Option parameters extracted from the mark text.
    local switch = {}
    switch.casmission = false

    -- size ; ranges from 1 to 5, 5 being the biggest.
    switch.size = 1

    -- defenses force ; ranges from 1 to 5, 5 being the toughest.
    switch.defense = 1

    -- armor force ; ranges from 1 to 5, 5 being the strongest and most modern.
    switch.armor = 1

    -- spacing ; ranges from 1 to 5, 1 being the default and 5 being the widest spacing.
    switch.spacing = 1

    -- disperse on attack ; self explanatory, if keyword is present the option will be set to true
    switch.disperseOnAttack = false

    -- password
    switch.password = nil

    -- Check for correct keywords.
    if text:lower():find(veafCasMission.Keyphrase) then
        switch.casmission = true
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
            veafSpawn.logDebug(string.format("Keyword password", val))
            switch.password = val
        end

        if switch.casmission and key:lower() == "size" then
            -- Set size.
            veafCasMission.logDebug(string.format("Keyword size = %d", val))
            local nVal = tonumber(val)
            if nVal <= 5 and nVal >= 1 then
                switch.size = nVal
            end
        end

        if switch.casmission and key:lower() == "defense" then
            -- Set defense.
            veafCasMission.logDebug(string.format("Keyword defense = %d", val))
            local nVal = tonumber(val)
            if nVal <= 5 and nVal >= 0 then
                switch.defense = nVal
            end
        end

        if switch.casmission and key:lower() == "armor" then
            -- Set armor.
            veafCasMission.logDebug(string.format("Keyword armor = %d", val))
            local nVal = tonumber(val)
            if nVal <= 5 and nVal >= 0 then
                switch.armor = nVal
            end
        end

        if switch.casmission and key:lower() == "spacing" then
            -- Set spacing.
            veafCasMission.logDebug(string.format("Keyword spacing = %d", val))
            local nVal = tonumber(val)
            if nVal <= 5 and nVal >= 1 then
                switch.spacing = nVal
            end
        end

        if switch.casmission and key:lower() == "disperse" then
            -- Set disperse on attack.
            veafCasMission.logDebug("Keyword disperse is set")
            switch.disperseOnAttack = true
        end

    end

    return switch
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CAS target group generation and management
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Generates an air defense group
function veafCasMission.generateAirDefenseGroup(groupName, defense)
    local group = {
            disposition = { h = 3, w = 3},
            units = {},
            description = groupName,
            groupName = groupName,
        }

    -- generate a primary air defense platoon
    local groupCount = math.random(2, 4)
    local samType
    local samTypeRand 
    samTypeRand = math.random(100)
            
    if samTypeRand > (90-(3*(defense-1))) then
        samType = 'Tor 9A331'
    elseif samTypeRand > (75-(4*(defense-1))) then
        samType = 'Osa 9A33 ln'
    elseif samTypeRand > (60-(4*(defense-1))) then
        samType = '2S6 Tunguska'
    elseif samTypeRand > (40-(5*(defense-1))) then
        samType = 'Strela-10M3'
    else
        samType = 'Strela-1 9P31'
    end
    veafCasMission.logDebug("samType = " .. samType)
    table.insert(group.units, { samType, ["cell"] = 5, random })

    -- generate a secondary air defense platoon
    for _ = 2, groupCount do
        samTypeRand = math.random(100)
				
        if samTypeRand > (75-(4*(defense-1))) then
            samType = '2S6 Tunguska'
        elseif samTypeRand > (65-(5*(defense-1))) then
            samType = 'Strela-10M3'
        elseif samTypeRand > (50-(5*(defense-1))) then
            samType = 'Strela-1 9P31'
        elseif samTypeRand > (30-(5*(defense-1))) then
            samType = 'ZSU-23-4 Shilka'
        else
            samType = 'Ural-375 ZU-23'
        end
        veafCasMission.logDebug("secondary samType = " .. samType)
        table.insert(group.units, { samType, random })
    end

    return group
end

--- Generates a transport company and its air defenses
function veafCasMission.generateTransportCompany(groupName, defense, groupSize)
    if not groupSize then
        groupSize = 6
    end
    local group = {
            disposition = { h = math.ceil(math.sqrt(groupSize*3)), w = math.ceil(math.sqrt(groupSize*3))},
            units = {},
            description = groupName,
            groupName = groupName,
        }

    -- generate a transport company
    local transportType
    local transportRand
  
    for _ = 1, groupSize do
        transportRand = math.random(8)
        if transportRand == 1 then
            transportType = 'ATMZ-5'
        elseif transportRand == 2 then
            transportType = 'Ural-4320 APA-5D'
        elseif transportRand == 3 then
            transportType = 'SKP-11'
        elseif transportRand == 4 then
            transportType = 'GAZ-66'
        elseif transportRand == 5 then
            transportType = 'KAMAZ Truck'
        elseif transportRand == 6 then
            transportType = 'Ural-375'
        elseif transportRand == 7 then
            transportType = 'Ural-4320T'
        elseif transportRand == 8 then
            transportType = 'ZIL-131 KUNG'
        end
        table.insert(group.units, { transportType, random})
    end

    -- add an air defense vehicle every 10 vehicles
    local nbDefense = groupSize / 10 + 1
    if nbDefense == 0 then
        nbDefense = 1
    end
    veafCasMission.logDebug("nbDefense = " .. nbDefense)
    for _ = 1, nbDefense do
        if defense > 3 then
            -- defense = 4-5 : add a Tunguska and a Shilka
            table.insert(group.units, { "ZSU-23-4 Shilka", random })
            table.insert(group.units, { "2S6 Tunguska", random })
        elseif defense > 2 then
            -- defense = 3 : add a Tunguska
            table.insert(group.units, { "2S6 Tunguska", random })
        elseif defense > 1 then
            -- defense = 2 : add a Shilka
            table.insert(group.units, { "ZSU-23-4 Shilka", random })
        elseif defense > 0 then
            -- defense = 1 : add a ZU23 on a truck
            table.insert(group.units, { "Ural-375 ZU-23", random })
        end
    end

    return group
end

--- Generates an armor platoon and its air defenses
function veafCasMission.generateArmorPlatoon(groupName, defense, armor)
    local group = {
            disposition = { h = 3, w = 3},
            units = {},
            description = groupName,
            groupName = groupName,
        }

    -- generate an armor platoon
    local groupCount = math.random(3, 6)
    local armorType
    local armorRand
    for _ = 1, groupCount do
        if armor <= 2 then
            armorRand = math.random(3)
            if armorRand == 1 then
                armorType = 'BRDM-2'
            elseif armorRand == 2 then
                armorType = 'BMD-1'
            elseif armorRand == 3 then
                armorType = 'BMP-1'
            end
        elseif armor == 3 then
            armorRand = math.random(3)
            if armorRand == 1 then
                armorType = 'BMP-1'
            elseif armorRand == 2 then
                armorType = 'BMP-2'
            elseif armorRand == 3 then
                armorType = 'T-55'
            end
        elseif armor == 4 then
            armorRand = math.random(4)
            if armorRand == 1 then
                armorType = 'BMP-1'
            elseif armorRand == 2 then
                armorType = 'BMP-2'
            elseif armorRand == 3 then
                armorType = 'T-55'
            elseif armorRand == 4 then
                armorType = 'T-72B'
            end
        elseif armor >= 5 then
            armorRand = math.random(4)
            if armorRand == 1 then
                armorType = 'BMP-2'
            elseif armorRand == 2 then
                armorType = 'BMP-3'
            elseif armorRand == 3 then
                armorType = 'T-80UD'
            elseif armorRand == 4 then
                armorType = 'T-90'
            end
        end
        table.insert(group.units, { armorType, random })
    end

   -- add an air defense vehicle
    if defense > 3 then 
        -- defense = 4-5 : add a Tunguska
        table.insert(group.units, { "2S6 Tunguska", cell = 5, random })
    elseif defense > 0 then
        -- defense = 1-3 : add a Shilka
        table.insert(group.units, { "ZSU-23-4 Shilka", cell = 5, random })
    end

    return group
end

--- Generates an infantry group along with its manpad units and tranport vehicles
function veafCasMission.generateInfantryGroup(groupName, defense, armor)
    veafCasMission.logTrace(string.format("veafCasMission.generateInfantryGroup(groupName=%s, defense=%d, armor=%d)",groupName, defense, armor))
    local group = {
            disposition = { h = 4, w = 3},
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
        table.insert(group.units, { unitType })
    end

    -- add a transport vehicle or an APC/IFV
    if armor > 3 then
        table.insert(group.units, { "BMP-1", cell=11, random })
    elseif armor > 0 then
        table.insert(group.units, { "BTR-80", cell=11, random })
    else
        table.insert(group.units, { "GAZ-3308", cell=11, random })
    end

    -- add manpads if needed
    if defense > 3 then
        for _ = 1, math.random(1,defense-2) do
            -- for defense = 4-5, spawn a modern Igla-S team
            table.insert(group.units, { "SA-18 Igla-S comm", random })
            table.insert(group.units, { "SA-18 Igla-S manpad", random })
        end
    elseif defense > 0 then
        for _ = 1, math.random(1,defense) do
            -- for defense = 1-3, spawn an older Igla team
            table.insert(group.units, { "SA-18 Igla comm", random })
            table.insert(group.units, { "SA-18 Igla manpad", random })
        end
    else
        -- for defense = 0, don't spawn any manpad
    end

    return group
end

function veafCasMission.placeGroup(groupDefinition, spawnPosition, spacing, resultTable)
    veafCasMission.logTrace(string.format("veafCasMission.placeGroup(#groupDefinition=%d)",#groupDefinition))
    if spawnPosition ~= nil and groupDefinition ~= nil then
        -- process the group 
        veafCasMission.logTrace("process the group")
        local group = veafUnits.processGroup(groupDefinition)
        
        -- place its units
        groupPosition = { x = spawnPosition.x, z = spawnPosition.y }
        local hdg = math.random(359)
        local group, cells = veafUnits.placeGroup(group, veaf.placePointOnLand(groupPosition), spacing+3, hdg)
        if veaf.Trace then 
            veafUnits.traceGroup(group, cells)
        end
        
        -- add the units to the result units list
        if not resultTable then 
            resultTable = {}
        end
        for _,u in pairs(group.units) do
            table.insert(resultTable, u)
        end
    end
    veafCasMission.logTrace(string.format("#resultTable=%d",#resultTable))
    return resultTable
end

--- Generates a complete CAS target group
function veafCasMission.generateCasGroup(country, casGroupName, spawnSpot, size, defense, armor, spacing, disperseOnAttack)
    local units = {}
    local groupId = 1234 + math.random(1000)
    local zoneRadius = (size+spacing)*350
    veafCasMission.logDebug("zoneRadius = " .. zoneRadius)
    
    -- generate between size-2 and size+1 infantry groups
    local infantryGroupsCount = math.random(math.max(1, size-2), size + 1)
    veafCasMission.logDebug("infantryGroupsCount = " .. infantryGroupsCount)
    for infantryGroupNumber = 1, infantryGroupsCount do
        local groupName = casGroupName .. " - Infantry Section " .. infantryGroupNumber
        local group = veafCasMission.generateInfantryGroup(groupName, defense, armor)
        local groupPosition = veaf.findPointInZone(spawnSpot, zoneRadius, false)
        veafCasMission.placeGroup(group, groupPosition, spacing, units)
    end

    if armor > 0 then
        -- generate between size-2 and size+1 armor platoons
        local armorPlatoonsCount = math.random(math.max(1, size-2), size + 1)
        veafCasMission.logDebug("armorPlatoonsCount = " .. armorPlatoonsCount)
        for armorGroupNumber = 1, armorPlatoonsCount do
            local groupName = casGroupName .. " - Armor Platoon " .. armorGroupNumber
            local groupPosition = veaf.findPointInZone(spawnSpot, zoneRadius, false)
            local group = veafCasMission.generateArmorPlatoon(groupName, defense, armor)
            veafCasMission.placeGroup(group, groupPosition, spacing, units)
        end
    end

    if defense > 0 then
        -- generate between 1 and 2 air defense groups
        local airDefenseGroupsCount = 1
        if defense > 3 then
            airDefenseGroupsCount = 2
        end
        veafCasMission.logDebug("airDefenseGroupsCount = " .. airDefenseGroupsCount)
        for airDefenseGroupNumber = 1, airDefenseGroupsCount do
            local groupName = casGroupName .. " - Air Defense Group ".. airDefenseGroupNumber
            local groupPosition = veaf.findPointInZone(spawnSpot, zoneRadius, false)
            local group = veafCasMission.generateAirDefenseGroup(groupName, defense)
            veafCasMission.placeGroup(group, groupPosition, spacing, units)
        end
    end

    -- generate between 1 and size transport companies
    local transportCompaniesCount = math.random(1, size)
    veafCasMission.logDebug("transportCompaniesCount = " .. transportCompaniesCount)
    for transportCompanyGroupNumber = 1, transportCompaniesCount do
        local groupName = casGroupName .. " - Transport Company " .. transportCompanyGroupNumber
        local groupPosition = veaf.findPointInZone(spawnSpot, zoneRadius, false)
        local groupCount = math.random(2, 5)
        local group = veafCasMission.generateTransportCompany(groupName, defense, groupCount)
        veafCasMission.placeGroup(group, groupPosition, spacing, units)
    end

    return units
end

--- Generates a CAS mission
function veafCasMission.generateCasMission(spawnSpot, size, defense, armor, spacing, disperseOnAttack)
    if veafCasMission.groupAliveCheckTaskID ~= 'none' then
        trigger.action.outText("A CAS target group already exists !", 5)
        return
    end
        
    local country = "RUSSIA"
    local units = veafCasMission.generateCasGroup(country, veafCasMission.RedCasGroupName, spawnSpot, size, defense, armor, spacing, disperseOnAttack)

    -- prepare the actual DCS units
    local dcsUnits = {}
    for i=1, #units do
        local unit = units[i]
        local unitType = unit.typeName
        local unitName = veafCasMission.RedCasGroupName .. " / " .. unit.displayName .. " #" .. i
        
        local spawnPosition = unit.spawnPoint
        
        -- check if position is correct for the unit type
        if veafUnits.checkPositionForUnit(spawnPosition, unit) then
            local toInsert = {
                    ["x"] = spawnPosition.x,
                    ["y"] = spawnPosition.z,
                    ["alt"] = spawnPosition.y,
                    ["type"] = unitType,
                    ["name"] = unitName,
                    ["speed"] = 0,
                    ["skill"] = "Random",
                    ["heading"] = 0
            }
            table.insert(dcsUnits, toInsert)
        end
    end

    -- actually spawn groups
    mist.dynAdd({country = country, category = "GROUND_UNIT", name = veafCasMission.RedCasGroupName, hidden = false, units = dcsUnits})

    -- set AI options
    local controller = Group.getByName(veafCasMission.RedCasGroupName):getController()
    controller:setOption(9, 2) -- set alarm state to red
    controller:setOption(AI.Option.Ground.id.DISPERSE_ON_ATTACK, disperseOnAttack) -- set disperse on attack according to the option

    -- Move reaper
    -- TODO

    -- build menu for each player
    veafRadio.addCommandToSubmenu('Target information', veafCasMission.rootPath, veafCasMission.reportTargetInformation, nil, veafRadio.USAGE_ForGroup)

    -- add radio menus for commands
    veafRadio.addSecuredCommandToSubmenu('Skip current objective', veafCasMission.rootPath, veafCasMission.skipCasTarget)
    veafCasMission.targetMarkersPath = veafRadio.addSubMenu("Target markers", veafCasMission.rootPath)
    veafRadio.addCommandToSubmenu('Request smoke on target area', veafCasMission.targetMarkersPath, veafCasMission.smokeCasTargetGroup)
    veafRadio.addCommandToSubmenu('Request illumination flare over target area', veafCasMission.targetMarkersPath, veafCasMission.flareCasTargetGroup)

    local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(veafCasMission.RedCasGroupName)
    local message =      "TARGET: Group of " .. nbVehicles .. " vehicles and " .. nbInfantry .. " soldiers. See F10 radio menu for details\n"
    trigger.action.outText(message,5)

    veafRadio.refreshRadioMenu()

    -- start checking for targets destruction
    veafCasMission.casGroupWatchdog()
end

-- Ask a report
-- @param int groupId
function veafCasMission.reportTargetInformation(unitName)
    -- generate information dispatch
    local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(veafCasMission.RedCasGroupName)

    local message =      "TARGET: Group of " .. nbVehicles .. " vehicles and " .. nbInfantry .. " soldiers.\n"
    message = message .. "\n"

    -- add coordinates and position from bullseye
    local averageGroupPosition = veaf.getAveragePosition(veafCasMission.RedCasGroupName)
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

    message = message .. 'TARGET ALT       : ' .. altitude .. " meters.\n"
    --message = message .. 'TARGET QFW       : ' .. qfeHp .. " hPa / " .. qfeinHg .. " inHg.\n"
    local windText =     'no wind.\n'
    if windStrength > 0 then
        windText = string.format(
                         'from %s at %s m/s.\n', windDirection, windStrength)
    end
    message = message .. 'WIND OVER TARGET : ' .. windText

    -- send message only for the unit
    veaf.outTextForUnit(unitName, message, 30)
end

--- add a smoke marker over the target area
function veafCasMission.smokeCasTargetGroup()
    veafCasMission.logTrace("veafCasMission.smokeCasTargetGroup START")
    veafSpawn.spawnSmoke(veaf.getAveragePosition(veafCasMission.RedCasGroupName), trigger.smokeColor.Red)
    trigger.action.outText('Copy smoke requested, RED smoke on the deck!',5)
    veafRadio.delCommand(veafCasMission.targetMarkersPath, 'Request smoke on target area')
    veafRadio.addCommandToSubmenu('Target is marked with red smoke', veafCasMission.targetMarkersPath, veaf.emptyFunction)
    veafCasMission.smokeResetTaskID = mist.scheduleFunction(veafCasMission.smokeReset,{},timer.getTime()+veafCasMission.SecondsBetweenSmokeRequests)
    veafRadio.refreshRadioMenu()
end

--- Reset the smoke request radio menu
function veafCasMission.smokeReset()
    veafRadio.delCommand(veafCasMission.targetMarkersPath, 'Target is marked with red smoke')
    veafRadio.addCommandToSubmenu('Request smoke on target area', veafCasMission.targetMarkersPath, veafCasMission.smokeCasTargetGroup)
    trigger.action.outText('Smoke marker available',5)
    veafRadio.refreshRadioMenu()
end

--- add an illumination flare over the target area
function veafCasMission.flareCasTargetGroup()
    veafSpawn.spawnIlluminationFlare(veaf.getAveragePosition(veafCasMission.RedCasGroupName))
	trigger.action.outText('Copy illumination flare requested, illumination flare over target area!',5)
    veafRadio.delCommand(veafCasMission.targetMarkersPath, 'Request illumination flare over target area')
    veafRadio.addCommandToSubmenu('Target area is marked with illumination flare', veafCasMission.targetMarkersPath, veaf.emptyFunction)
    veafCasMission.flareResetTaskID = mist.scheduleFunction(veafCasMission.flareReset,{},timer.getTime()+veafCasMission.SecondsBetweenFlareRequests)
    veafRadio.refreshRadioMenu()
end

--- Reset the flare request radio menu
function veafCasMission.flareReset()
    veafRadio.delCommand(veafCasMission.targetMarkersPath, 'Target area is marked with illumination flare')
    veafRadio.addCommandToSubmenu('Request illumination flare over target area', veafCasMission.targetMarkersPath, veafCasMission.flareCasTargetGroup)
    trigger.action.outText('Target illumination available',5)
    veafRadio.refreshRadioMenu()
end

--- Checks if the vehicles group is still alive, and if not announces the end of the CAS mission
function veafCasMission.casGroupWatchdog() 
    local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(veafCasMission.RedCasGroupName)
    if nbVehicles > 0 then
        veafCasMission.logTrace("Group is still alive with "..nbVehicles.." vehicles and "..nbInfantry.." soldiers")
        veafCasMission.groupAliveCheckTaskID = mist.scheduleFunction(veafCasMission.casGroupWatchdog,{},timer.getTime()+veafCasMission.SecondsBetweenWatchdogChecks)
    else
        trigger.action.outText("CAS objective group destroyed!", 5)
        veafCasMission.cleanupAfterMission()
    end
end

--- Called from the "Skip target" radio menu : remove the current CAS target group
function veafCasMission.skipCasTarget()
    veafCasMission.cleanupAfterMission()
    trigger.action.outText("CAS objective group cleaned up.", 5)
end

--- Cleanup after either mission is ended or aborted
function veafCasMission.cleanupAfterMission()
    veafCasMission.logTrace("skipCasTarget START")

    -- destroy vehicles and infantry groups
    veafCasMission.logTrace("destroy vehicles group")
    local group = Group.getByName(veafCasMission.RedCasGroupName)
    if group and group:isExist() == true then
        group:destroy()
    end
    veafCasMission.logTrace("destroy infantry group")
    group = Group.getByName(veafCasMission.RedCasGroupName)
    if group and group:isExist() == true then
        group:destroy()
    end

    -- remove the watchdog function
    veafCasMission.logTrace("remove the watchdog function")
    if veafCasMission.groupAliveCheckTaskID ~= 'none' then
        mist.removeFunction(veafCasMission.groupAliveCheckTaskID)
    end
    veafCasMission.groupAliveCheckTaskID = 'none'

    
    veafCasMission.logTrace("update the radio menu 1")
    veafRadio.delCommand(veafCasMission.rootPath, 'Target information')

    veafCasMission.logTrace("update the radio menu 2")
    veafRadio.delCommand(veafCasMission.rootPath, 'Skip current objective')
    veafCasMission.logTrace("update the radio menu 3")
    veafRadio.delCommand(veafCasMission.rootPath, 'Get current objective situation')
    veafCasMission.logTrace("update the radio menu 4")
    veafRadio.delSubmenu(veafCasMission.targetMarkersPath, veafCasMission.rootPath)

    veafRadio.refreshRadioMenu()
    veafCasMission.logTrace("skipCasTarget DONE")

end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafCasMission.buildRadioMenu()
    veafCasMission.rootPath = veafRadio.addSubMenu(veafCasMission.RadioMenuName)
    veafRadio.addCommandToSubmenu("HELP", veafCasMission.rootPath, veafCasMission.help, nil, veafRadio.USAGE_ForGroup)
end

function veafCasMission.help(unitName)
    local text =
        'Create a marker and type "_cas" in the text\n' ..
        'This will create a default CAS target group\n' ..
        'You can add options (comma separated) :\n' ..
        '   "defense 0" completely disables air defenses\n' ..
        '   "defense [1-5]" specifies air defense cover (1 = light, 5 = heavy)\n' ..
        '   "size [1-5]" changes the group size (1 = small, 5 = huge)\n' ..
        '   "armor [1-5]" specifies armor presence (1 = light, 5 = heavy)\n' ..
        '   "spacing [1-5]" changes the groups spacing (1 = dense, 3 = default, 5 = sparse)'

    veaf.outTextForUnit(unitName, text, 30)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafCasMission.initialize()
    veafCasMission.buildRadioMenu()
    veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafCasMission.onEventMarkChange)
end

veafCasMission.logInfo(string.format("Loading version %s", veafCasMission.Version))

--- Enable/Disable error boxes displayed on screen.
env.setErrorMessageBoxEnabled(false)



