------------------------------------------------------------------
-- VEAF CAS (Close Air Support) command and functions for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Listen to marker change events and creates a CAS training mission, with optional parameters
-- * Create a CAS target group, protected by SAM, AAA and manpads, to use for CAS training
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafCasMission = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafCasMission.Id = "CASMISSION"

--- Version.
veafCasMission.Version = "1.14.0"

-- trace level, specific to this module
--veafCasMission.LogLevel = "trace"

veaf.loggers.new(veafCasMission.Id, veafCasMission.LogLevel)

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
veafCasMission.BlueCasGroupName = "Blue CAS Group"
veafCasMission.casGroupName = veafCasMission.RedCasGroupName
veafCasMission.afacName = nil

veafCasMission.RadioMenuName = "CAS MISSION"

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

veafCasMission.SIDE_RED = coalition.side.RED
veafCasMission.SIDE_BLUE = coalition.side.BLUE

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafCasMission.onEventMarkChange(eventPos, event)
    veaf.loggers.get(veafCasMission.Id):trace(string.format("event  = %s", veaf.p(event)))

    -- choose by default the coalition opposing the player who triggered the event
    local invertedCoalition = 1
    if event.coalition == 1 then
        invertedCoalition = 2
    end

    veaf.loggers.get(veafCasMission.Id):trace(string.format("event.idx  = %s", veaf.p(event.idx)))

    if veafCasMission.executeCommand(eventPos, event.text, invertedCoalition, event.idx) then 
        
        -- Delete old mark.
        veaf.loggers.get(veafCasMission.Id):trace(string.format("Removing mark # %d.", event.idx))
        trigger.action.removeMark(event.idx)

    end
end

function veafCasMission.executeCommand(eventPos, eventText, coalition, markId, bypassSecurity)
    veaf.loggers.get(veafCasMission.Id):debug(string.format("veafCasMission.executeCommand(eventText=[%s])", eventText))
    veaf.loggers.get(veafCasMission.Id):trace(string.format("coalition=%s", veaf.p(coalition)))
    veaf.loggers.get(veafCasMission.Id):trace(string.format("markId=%s", veaf.p(markId)))
    veaf.loggers.get(veafCasMission.Id):trace(string.format("bypassSecurity=%s", veaf.p(bypassSecurity)))


    -- Check if marker has a text and the veafCasMission.keyphrase keyphrase.
    if eventText ~= nil and eventText:lower():find(veafCasMission.Keyphrase) then

        -- Analyse the mark point text and extract the keywords.
        local options = veafCasMission.markTextAnalysis(eventText)

        if options then
            -- Check options commands
            if options.casmission then

                if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                
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

                -- create the group
                veafCasMission.generateCasMission(eventPos, options.size, options.defense, options.armor, options.spacing, options.disperseOnAttack, options.side)
                return true
            end
        end
    end
    return false
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

    -- coalition
    switch.side = nil

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
            veaf.loggers.get(veafCasMission.Id):debug(string.format("Keyword password", val))
            switch.password = val
        end

        if switch.casmission and key:lower() == "size" then
            -- Set size.
            veaf.loggers.get(veafCasMission.Id):debug(string.format("Keyword size = %d", val))
            local nVal = tonumber(val)
            if nVal <= 5 and nVal >= 1 then
                switch.size = nVal
            end
        end

        if switch.casmission and key:lower() == "defense" then
            -- Set defense.
            veaf.loggers.get(veafCasMission.Id):debug(string.format("Keyword defense = %d", val))
            local nVal = tonumber(val)
            if nVal <= 5 and nVal >= 0 then
                switch.defense = nVal
            end
        end

        if switch.casmission and key:lower() == "armor" then
            -- Set armor.
            veaf.loggers.get(veafCasMission.Id):debug(string.format("Keyword armor = %d", val))
            local nVal = tonumber(val)
            if nVal <= 5 and nVal >= 0 then
                switch.armor = nVal
            end
        end

        if switch.casmission and key:lower() == "spacing" then
            -- Set spacing.
            veaf.loggers.get(veafCasMission.Id):debug(string.format("Keyword spacing = %d", val))
            local nVal = tonumber(val)
            if nVal <= 5 and nVal >= 1 then
                switch.spacing = nVal
            end
        end

        if key:lower() == "side" then
            -- Set side
            veaf.loggers.get(veafCasMission.Id):trace(string.format("Keyword side = %s", val))
            if val:upper() == "BLUE" then
                switch.side = veafCasMission.SIDE_BLUE
            else
                switch.side = veafCasMission.SIDE_RED
            end
        end

        if switch.casmission and key:lower() == "disperse" then
            -- Set disperse on attack.
            veaf.loggers.get(veafCasMission.Id):debug("Keyword disperse = %s", val)
            
            if val ~= "" then
                local nVal = tonumber(val)
                if nVal then
                    switch.disperseOnAttack = nVal
                end
            else
                switch.disperseOnAttack = 15
            end
        end

    end

    return switch
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CAS target group generation and management
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local function _addDefenseForGroups(group, side, defense, multiple, forInfantry)
    veaf.loggers.get(veafCasMission.Id):trace(string.format("_addDefenseForGroups(defense=[%s], side=[%s], multiple=[%s], forInfantry=[%s])", veaf.p(defense), veaf.p(side), veaf.p(multiple), veaf.p(forInfantry)))
    local _actualDefense = defense
    if defense > 0 then
        -- roll a dice : 20% chance to get a -1 (lower) difficulty, 30% chance to get a +1 (higher) difficulty, and 50% to get what was asked for
        local _dice = math.random(100)
        veaf.loggers.get(veafCasMission.Id):trace("_dice = " .. _dice)
        if _dice <= 20 then
            _actualDefense = defense - 1
        elseif _dice > 80 then
            _actualDefense = defense + 1
        end
    end
    if _actualDefense > 5 then _actualDefense = 6 end
    if _actualDefense < 0 then _actualDefense = 0 end
    veaf.loggers.get(veafCasMission.Id):trace("_actualDefense = " .. _actualDefense)
    for _ = 1, multiple do
        if _actualDefense > 5 then
            if side == veafCasMission.SIDE_BLUE then
                if forInfantry then
                    -- only spawn manpads
                    for _ = 1, math.random(1,_actualDefense-2) do
                        table.insert(group.units, { "Stinger comm", random=true })
                        table.insert(group.units, { "Soldier stinger", random=true })
                    end
                else
                    table.insert(group.units, { "M1097 Avenger", random=true })
                    table.insert(group.units, { "Roland ADS", random=true })
                    table.insert(group.units, { "Gepard", random=true })
                end
            else
                if forInfantry then
                    -- only spawn manpads
                    for _ = 1, math.random(1,_actualDefense-2) do
                        -- for _actualDefense = 4-5, spawn a modern Igla-S team
                        table.insert(group.units, { "SA-18 Igla-S comm", random=true })
                        table.insert(group.units, { "SA-18 Igla-S manpad", random=true })
                    end
                else
                    table.insert(group.units, { veaf.randomlyChooseFrom({"2S6 Tunguska", "Tor 9A331", "Tor 9A331"}), random=true })
                    table.insert(group.units, { "Strela-10M3", random=true })
                    table.insert(group.units, { "ZSU-23-4 Shilka", random=true })
                end
            end
        elseif _actualDefense == 5 then
            if side == veafCasMission.SIDE_BLUE then
                if forInfantry then
                    -- only spawn manpads
                    for _ = 1, math.random(1,_actualDefense-2) do
                        table.insert(group.units, { "Stinger comm", random=true })
                        table.insert(group.units, { "Soldier stinger", random=true })
                    end
                else
                    table.insert(group.units, { veaf.randomlyChooseFrom({"Gepard", "M1097 Avenger", "M1097 Avenger"}), random=true })
                    table.insert(group.units, { "Roland ADS", random=true })
                end
            else
                if forInfantry then
                    -- only spawn manpads
                    for _ = 1, math.random(1,_actualDefense-2) do
                        -- for _actualDefense = 4-5, spawn a modern Igla-S team
                        table.insert(group.units, { "SA-18 Igla-S comm", random=true })
                        table.insert(group.units, { "SA-18 Igla-S manpad", random=true })
                    end
                else
                    table.insert(group.units, { veaf.randomlyChooseFrom({"Osa 9A33 ln", "2S6 Tunguska"}), random=true })
                    table.insert(group.units, { veaf.randomlyChooseFrom({"ZSU-23-4 Shilka", "Strela-10M3"}), random=true })
                end
            end
        elseif _actualDefense == 4 then
            if side == veafCasMission.SIDE_BLUE then
                if forInfantry then
                    -- only spawn manpads
                    for _ = 1, math.random(1,_actualDefense-2) do
                        table.insert(group.units, { "Stinger comm", random=true })
                        table.insert(group.units, { "Soldier stinger", random=true })
                    end
                else
                    table.insert(group.units, { "Gepard", random=true })
                    table.insert(group.units, { "Roland ADS", random=true })
                end
            else
                if forInfantry then
                    -- only spawn manpads
                    for _ = 1, math.random(1,_actualDefense-2) do
                        -- for _actualDefense = 4-5, spawn a modern Igla-S team
                        table.insert(group.units, { "SA-18 Igla-S comm", random=true })
                        table.insert(group.units, { "SA-18 Igla-S manpad", random=true })
                    end
                else
                    table.insert(group.units, { veaf.randomlyChooseFrom({"ZSU-23-4 Shilka", "ZSU-23-4 Shilka", "ZSU_57_2"}), random=true })
                    table.insert(group.units, { veaf.randomlyChooseFrom({"HQ-7_LN_EO", "HQ-7_LN_SP"}), random=true })
                end
            end
        elseif _actualDefense == 3 then
            if side == veafCasMission.SIDE_BLUE then
                if forInfantry then
                    -- only spawn manpads
                    for _ = 1, math.random(1,_actualDefense-2) do
                        table.insert(group.units, { "Stinger comm", random=true })
                        table.insert(group.units, { "Soldier stinger", random=true })
                    end
                else
                    table.insert(group.units, { veaf.randomlyChooseFrom({"M48 Chaparral", "M6 Linebacker"}), random=true })
                    table.insert(group.units, { "Gepard", random=true })
                end
            else
                if forInfantry then
                    -- only spawn manpads
                    for _ = 1, math.random(1,_actualDefense-2) do
                        -- for _actualDefense = 3, spawn an older Igla team
                        table.insert(group.units, { "SA-18 Igla comm", random=true })
                        table.insert(group.units, { "SA-18 Igla manpad", random=true })
                    end
                else
                    table.insert(group.units, { veaf.randomlyChooseFrom({"Strela-1 9P31", "Strela-10M3"}), random=true })
                    table.insert(group.units, { veaf.randomlyChooseFrom({"ZSU-23-4 Shilka", "ZSU-23-4 Shilka", "ZSU_57_2"}), random=true })
                end
            end
        elseif _actualDefense == 2 then
            if side == veafCasMission.SIDE_BLUE then
                table.insert(group.units, { "Gepard", random=true })
                table.insert(group.units, { "Vulcan", random=true })
            else
                table.insert(group.units, { veaf.randomlyChooseFrom({"ZSU-23-4 Shilka", "ZSU_57_2"}), random=true })
                table.insert(group.units, { veaf.randomlyChooseFrom({"ZSU-23-4 Shilka", "ZSU_57_2"}), random=true })
            end
        elseif _actualDefense == 1 then
            if side == veafCasMission.SIDE_BLUE then
                table.insert(group.units, { "Vulcan", random=true })
            else
                table.insert(group.units, { veaf.randomlyChooseFrom({"Ural-375 ZU-23", "ZSU_57_2"}), random=true })
            end
        end
    end
    --veaf.loggers.get(veafCasMission.Id):trace(string.format("group.units=%s", veaf.p(group.units)))
end

--- Generates an air defense group
function veafCasMission.generateAirDefenseGroup(groupName, defense, side)
    side = side or veafCasMission.SIDE_RED
    
    -- generate a primary air defense platoon
    local _actualDefense = defense
    if defense > 0 then
        -- roll a dice : 20% chance to get a -1 (lower) difficulty, 30% chance to get a +1 (higher) difficulty, and 50% to get what was asked for
        local _dice = math.random(100)
        veaf.loggers.get(veafCasMission.Id):trace("_dice = " .. _dice)
        if _dice <= 20 then
            _actualDefense = defense - 1
        elseif _dice > 80 then
            _actualDefense = defense + 1
        end
    end
    if _actualDefense > 5 then _actualDefense = 5 end
    if _actualDefense < 0 then _actualDefense = 0 end
    veaf.loggers.get(veafCasMission.Id):trace("_actualDefense = " .. _actualDefense)
    local _groupDefinition = "generateAirDefenseGroup-BLUE-"
    if side == veafCasMission.SIDE_RED then
        _groupDefinition = "generateAirDefenseGroup-RED-"
    end
    _groupDefinition = _groupDefinition .. tostring(_actualDefense)
    veaf.loggers.get(veafCasMission.Id):trace("_groupDefinition = " .. _groupDefinition)

    local group = veafUnits.findGroup(_groupDefinition)
    if not group then
        veaf.loggers.get(veafCasMission.Id):error(string.format("veafCasMission.generateAirDefenseGroup cannot find group [%s]", _groupDefinition or ""))
    end
    group.description = groupName
    group.groupName = groupName
    
    veaf.loggers.get(veafCasMission.Id):trace("#group.units = " .. #group.units)
    return group
end

--- Generates a transport company and its air defenses
function veafCasMission.generateTransportCompany(groupName, defense, side, size)
    veaf.loggers.get(veafCasMission.Id):trace(string.format("veafCasMission.generateTransportCompany(groupName=[%s], defense=[%s], side=[%s], size=[%s])", groupName or "", defense  or "", side or "", size or ""))
    side = side or veafCasMission.SIDE_RED
    local groupCount = math.floor((size or math.random(10, 15)))
    veaf.loggers.get(veafCasMission.Id):trace(string.format("groupCount=%s", tostring(groupCount)))
    local group = {
            disposition = { h = groupCount, w = groupCount},
            units = {},
            description = groupName,
            groupName = groupName,
        }
    -- generate a transport company
    local transportType
  
    for _ = 1, groupCount do
        if veaf.config.ww2 then
            if side == veafCasMission.SIDE_BLUE then
                transportType = veaf.randomlyChooseFrom({"Bedford_MWD", "CCKW_353", "Willys_MB"})
            else
                transportType = veaf.randomlyChooseFrom({"Blitz_36-6700A", "Horch_901_typ_40_kfz_21", "Kubelwagen_82", "Sd_Kfz_7", "Sd_Kfz_2" })
            end
        else
            if side == veafCasMission.SIDE_BLUE then
                transportType = veaf.randomlyChooseFrom({"LUV HMMWV Jeep", "M 818", "M978 HEMTT Tanker", "Land_Rover_101_FC", "Land_Rover_109_S3"})
            else
                transportType = veaf.randomlyChooseFrom({"ATZ-60_Maz", "ZIL-135", "ATZ-5", 'Ural-4320 APA-5D', 'SKP-11', 'GAZ-66', 'KAMAZ Truck', 'Ural-375', "KrAZ6322", 'ZIL-131 KUNG', "Tigr_233036", "UAZ-469"})
            end
        end
        table.insert(group.units, { transportType, random=true})
    end

    -- add an air defense vehicle every 10 vehicles
    local nbDefense = groupCount / 10 + 1
    if nbDefense == 0 then
        nbDefense = 1
    end
    veaf.loggers.get(veafCasMission.Id):debug("nbDefense = " .. nbDefense)
    if not veaf.config.ww2 then
        _addDefenseForGroups(group, side, defense, nbDefense)
    else
        -- nothing, there are no mobile defense units in WW2
    end

    return group
end

--- Generates an armor platoon and its air defenses
function veafCasMission.generateArmorPlatoon(groupName, defense, armor, side, size)
    veaf.loggers.get(veafCasMission.Id):trace(string.format("veafCasMission.generateArmorPlatoon(groupName=[%s], defense=[%s], armor=[%s], side=[%s], size=[%s])", groupName or "", defense  or "", armor or "", side or "", size or ""))
    side = side or veafCasMission.SIDE_RED
    
    -- generate an armor platoon
    local groupCount = math.floor((size or math.random(3, 6)) * (math.random(8, 12)/10))
    veaf.loggers.get(veafCasMission.Id):trace(string.format("groupCount=%s", tostring(groupCount)))
    local group = {
            disposition = { h = groupCount, w = groupCount},
            units = {},
            description = groupName,
            groupName = groupName,
        }
    if group.disposition.h < 4 then 
        group.disposition.h = 4
        group.disposition.w = 4
    end
    local armorType
    local armorRand
    for _ = 1, groupCount do
        if armor <= 2 then
            if veaf.config.ww2 then
                if side == veafCasMission.SIDE_BLUE then
                    armorType = veaf.randomlyChooseFrom({"M30_CC", "M10_GMC"})
                else
                    armorType = veaf.randomlyChooseFrom({"Sd_Kfz_251", "Sd_Kfz_234_2_Puma"})
                end
            else
                if side == veafCasMission.SIDE_BLUE then
                    armorType = veaf.randomlyChooseFrom({'IFV Marder', 'MCV-80', 'IFV LAV-25', "M1134 Stryker ATGM", 'M-2 Bradley'})
                else
                    armorType = veaf.randomlyChooseFrom({"BTR-82A", 'BMP-1', 'BMP-1', "VAB_Mephisto", 'BMP-2'})
                end
            end
        elseif armor == 3 then
            if veaf.config.ww2 then
                if side == veafCasMission.SIDE_BLUE then
                    armorType = veaf.randomlyChooseFrom({"M30_CC", "M10_GMC", "Centaur_IV",})
                else
                    armorType = veaf.randomlyChooseFrom({"Sd_Kfz_251", "Sd_Kfz_234_2_Puma", "Elefant_SdKfz_184"})
                end
            else
                if side == veafCasMission.SIDE_BLUE then
                    armorType = veaf.randomlyChooseFrom({'IFV Marder', "VAB_Mephisto", "M-2 Bradley", 'MBT Leopard 1A3', "Chieftain_mk3"})
                else
                    armorType = veaf.randomlyChooseFrom({"BTR-82A", "VAB_Mephisto", 'BMP-2', 'T-55', "Chieftain_mk3"})
                end
            end
        elseif armor == 4 then
            if veaf.config.ww2 then
                if side == veafCasMission.SIDE_BLUE then
                    armorType = veaf.randomlyChooseFrom({"Centaur_IV", "Churchill_VII", "Cromwell_IV"})
                else
                    armorType = veaf.randomlyChooseFrom({"Pz_IV_H", "Tiger_I", "Tiger_II_H","Stug_III","Stug_IV"})
                end
            else
                if side == veafCasMission.SIDE_BLUE then
                    armorType = veaf.randomlyChooseFrom({'M-2 Bradley', 'MBT Leopard 1A3', "Merkava_Mk4", "M1128 Stryker MGS"})
                else
                    armorType = veaf.randomlyChooseFrom({"BTR-82A", "BMP-3", "Chieftain_mk3", 'T-72B'})
                end
            end
        elseif armor >= 5 then
            if veaf.config.ww2 then
                if side == veafCasMission.SIDE_BLUE then
                    armorType = veaf.randomlyChooseFrom({"Centaur_IV", "Churchill_VII", "Cromwell_IV", "M4_Sherman", "M4A4_Sherman_FF"}, armor-5)
                else
                    armorType = veaf.randomlyChooseFrom({"Pz_IV_H", "Tiger_I", "Tiger_II_H","Stug_III","Stug_IV", "JagdPz_IV", "Jagdpanther_G1", "Pz_V_Panther_G"}, armor-5)
                end
            else
                if side == veafCasMission.SIDE_BLUE then
                    armorType = veaf.randomlyChooseFrom({"Merkava_Mk4", "Challenger2", "Leclerc", "Leopard-2", 'M-1 Abrams'}, armor-5)
                else
                    armorType = veaf.randomlyChooseFrom({"BMP-3", "ZTZ96B", 'T-72B3', 'T-80UD', 'T-90'}, armor-5)
                end
            end
        end
        table.insert(group.units, { armorType, random=true })
    end

    -- add air defense vehicles
    if not veaf.config.ww2 then
        _addDefenseForGroups(group, side, defense, 1)
    else
        -- nothing, there are no mobile defense units in WW2
    end

    return group
end

--- Generates an infantry group along with its manpad units and tranport vehicles
function veafCasMission.generateInfantryGroup(groupName, defense, armor, side, size)
    side = side or veafCasMission.SIDE_RED
    veaf.loggers.get(veafCasMission.Id):trace(string.format("veafCasMission.generateInfantryGroup(groupName=%s, defense=%d, armor=%d)",groupName, defense, armor))
    -- generate an infantry group
    local groupCount = math.floor((size or math.random(3, 6)) * (math.random(8, 12)/10))
    veaf.loggers.get(veafCasMission.Id):trace(string.format("groupCount=%s", tostring(groupCount)))
    local group = {
            disposition = { h = groupCount, w = groupCount},
            units = {},
            description = groupName,
            groupName = groupName,
        }
    if group.disposition.h < 4 then 
        group.disposition.h = 4
        group.disposition.w = 4
    end
    for _ = 1, groupCount do
        local rand = math.random(3)
        local unitType = nil
        if rand == 1 then
            if side == veafCasMission.SIDE_BLUE then
                unitType = 'Soldier RPG'
            else
                unitType = "Paratrooper RPG-16"
            end
        elseif rand == 2 then
            if side == veafCasMission.SIDE_BLUE then
                unitType = "Soldier M249"
            else
                unitType = "Infantry AK ver3"
            end
        else
            if side == veafCasMission.SIDE_BLUE then
                unitType = "Soldier M4 GRG"
            else
                unitType = "Infantry AK ver2"
            end
        end
        table.insert(group.units, { unitType })
    end

    -- add a transport vehicle or an APC/IFV
    if armor > 3 then
        if side == veafCasMission.SIDE_BLUE then
            table.insert(group.units, { "M-2 Bradley", cell=11, random=true })
        else
            table.insert(group.units, { "BMP-2", cell=11, random=true })
        end
    elseif armor > 0 then
        if side == veafCasMission.SIDE_BLUE then
            table.insert(group.units, { "IFV Marder", cell=11, random=true })
        else
            table.insert(group.units, { "BTR-82A", cell=11, random=true })
        end
    else
        if side == veafCasMission.SIDE_BLUE then
            table.insert(group.units, { "M 818", cell=11, random=true })
        else
            table.insert(group.units, { "KAMAZ Truck", cell=11, random=true })
        end
    end

    -- add air defense
    if not veaf.config.ww2 then
        _addDefenseForGroups(group, side, defense, 1, true)
    else
        -- nothing, there are no mobile defense units in WW2
    end

    return group
end

function veafCasMission.placeGroup(groupDefinition, spawnPosition, spacing, resultTable, hasDest)
    if spawnPosition ~= nil and groupDefinition ~= nil then
        veaf.loggers.get(veafCasMission.Id):trace(string.format("veafCasMission.placeGroup(#groupDefinition.units=%d)",#groupDefinition.units))

        -- process the group 
        veaf.loggers.get(veafCasMission.Id):trace("process the group")
        local group = veafUnits.processGroup(groupDefinition)
        
        -- place its units
        local groupPosition = { x = spawnPosition.x, z = spawnPosition.y }
        local hdg = math.random(359)
        local group, cells = veafUnits.placeGroup(group, veaf.placePointOnLand(groupPosition), spacing+3, hdg, hasDest)
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
    veaf.loggers.get(veafCasMission.Id):trace(string.format("#resultTable=%d",#resultTable))
    return resultTable
end

--- Generates a complete CAS target group
function veafCasMission.generateCasGroup(casGroupName, spawnSpot, size, defense, armor, spacing, side)
    veaf.loggers.get(veafCasMission.Id):trace("side = " .. tostring(side))
    side = side or veafCasMission.SIDE_RED
    local units = {}
    local zoneRadius = (size+spacing)*350
    veaf.loggers.get(veafCasMission.Id):trace("zoneRadius = " .. zoneRadius)
    
    -- generate between size-2 and size+1 infantry groups
    local infantryGroupsCount = math.random(math.max(1, size-2), size + 1)
    veaf.loggers.get(veafCasMission.Id):trace("infantryGroupsCount = " .. infantryGroupsCount)
    for infantryGroupNumber = 1, infantryGroupsCount do
        local groupName = casGroupName .. " - Infantry Section " .. infantryGroupNumber
        local groupPosition = veaf.findPointInZone(spawnSpot, zoneRadius, false)
        veaf.loggers.get(veafCasMission.Id):trace(string.format("infantry group #%s position : %s", veaf.p(infantryGroupNumber), veaf.p(groupPosition)))
        local group = veafCasMission.generateInfantryGroup(groupName, defense, armor, side)
        veafCasMission.placeGroup(group, groupPosition, spacing, units)
    end

    if armor > 0 then
        -- generate between size-2 and size+1 armor platoons
        local armorPlatoonsCount = math.random(math.max(1, size-2), size + 1)
        veaf.loggers.get(veafCasMission.Id):trace("armorPlatoonsCount = " .. armorPlatoonsCount)
        for armorGroupNumber = 1, armorPlatoonsCount do
            local groupName = casGroupName .. " - Armor Platoon " .. armorGroupNumber
            local groupPosition = veaf.findPointInZone(spawnSpot, zoneRadius, false)
            veaf.loggers.get(veafCasMission.Id):trace(string.format("armor group #%s position : %s", veaf.p(armorGroupNumber), veaf.p(groupPosition)))
            local group = veafCasMission.generateArmorPlatoon(groupName, defense, armor, side)
            veafCasMission.placeGroup(group, groupPosition, spacing, units)
        end
    end

    if defense > 0 then
        -- generate between 1 and 2 air defense groups
        local airDefenseGroupsCount = 1
        if defense > 3 then
            airDefenseGroupsCount = 2
        end
        veaf.loggers.get(veafCasMission.Id):trace("airDefenseGroupsCount = " .. airDefenseGroupsCount)
        for airDefenseGroupNumber = 1, airDefenseGroupsCount do
            local groupName = casGroupName .. " - Air Defense Group ".. airDefenseGroupNumber
            local groupPosition = veaf.findPointInZone(spawnSpot, zoneRadius, false)
            veaf.loggers.get(veafCasMission.Id):trace(string.format("air defense group #%s position : %s", veaf.p(airDefenseGroupNumber), veaf.p(groupPosition)))
            local group = veafCasMission.generateAirDefenseGroup(groupName, defense, side)
            veafCasMission.placeGroup(group, groupPosition, spacing, units)
        end
    end

    -- generate between 1 and size transport companies
    local transportCompaniesCount = math.random(1, size)
    veaf.loggers.get(veafCasMission.Id):trace("transportCompaniesCount = " .. transportCompaniesCount)
    for transportCompanyGroupNumber = 1, transportCompaniesCount do
        local groupName = casGroupName .. " - Transport Company " .. transportCompanyGroupNumber
        local groupPosition = veaf.findPointInZone(spawnSpot, zoneRadius, false)
        veaf.loggers.get(veafCasMission.Id):trace(string.format("transport group #%s position : %s", veaf.p(transportCompanyGroupNumber), veaf.p(groupPosition)))
        local group = veafCasMission.generateTransportCompany(groupName, defense, side)
        veafCasMission.placeGroup(group, groupPosition, spacing, units)
    end

    return units
end

--- Generates a CAS mission
function veafCasMission.generateCasMission(spawnSpot, size, defense, armor, spacing, disperseOnAttack, side)
    if veafCasMission.groupAliveCheckTaskID ~= 'none' then
        trigger.action.outText("A CAS target group already exists !", 15)
        return
    end
    if side == veafCasMission.SIDE_BLUE then
        veafCasMission.casGroupName = veafCasMission.BlueCasGroupName
    end
    local country = veaf.getCountryForCoalition(side)
    local units = veafCasMission.generateCasGroup(veafCasMission.casGroupName, spawnSpot, size, defense, armor, spacing, side)

    -- prepare the actual DCS units
    local dcsUnits = {}
    for i=1, #units do
        local unit = units[i]
        local unitType = unit.typeName
        local unitName = veafCasMission.casGroupName .. " / " .. unit.displayName .. " #" .. i
        local unitHdg = unit.hdg
        
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
                    ["heading"] = unitHdg,
            }
            table.insert(dcsUnits, toInsert)
        end
    end

    -- actually spawn groups
    mist.dynAdd({country = country, category = "GROUND_UNIT", name = veafCasMission.casGroupName, hidden = false, units = dcsUnits})

    -- set AI options
    local controller = Group.getByName(veafCasMission.casGroupName):getController()
    controller:setOption(9, 2) -- set alarm state to red
    controller:setOption(AI.Option.Ground.id.DISPERSE_ON_ATTACK, disperseOnAttack) -- set disperse on attack according to the option

    -- Spawn Reaper
    local opposing_side = coalition.side.BLUE
    if coalition.side.RED ~= side then
        opposing_side = coalition.side.RED
    end

    local avgPos = veaf.getAveragePosition(veafCasMission.casGroupName)
    veafCasMission.afacName = veafSpawn.spawnAFAC(avgPos, "mq9", veaf.getCountryForCoalition(opposing_side), nil, nil, nil, veafSpawn.convertLaserToFreq(1688), "FM", 1688, true, false, false)

    -- build menu for each player
    veafRadio.addCommandToSubmenu('Target information', veafCasMission.rootPath, veafCasMission.reportTargetInformation, nil, veafRadio.USAGE_ForGroup)

    -- add radio menus for commands
    veafRadio.addSecuredCommandToSubmenu('Skip current objective', veafCasMission.rootPath, veafCasMission.skipCasTarget)
    veafCasMission.targetMarkersPath = veafRadio.addSubMenu("Target markers", veafCasMission.rootPath)
    veafRadio.addCommandToSubmenu('Request smoke on target area', veafCasMission.targetMarkersPath, veafCasMission.smokeCasTargetGroup)
    veafRadio.addCommandToSubmenu('Request illumination flare over target area', veafCasMission.targetMarkersPath, veafCasMission.flareCasTargetGroup)

    local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(veafCasMission.casGroupName)
    local message = "TARGET: Group of " .. nbVehicles .. " vehicles and " .. nbInfantry .. " soldiers. See F10 radio menu for details\n"
    trigger.action.outText(message,5)

    veafRadio.refreshRadioMenu()

    -- start checking for targets destruction
    veafCasMission.casGroupWatchdog()
end

-- Ask a report
-- @param int groupId
function veafCasMission.reportTargetInformation(unitName)
    -- generate information dispatch
    local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(veafCasMission.casGroupName)

    local message = "TARGET: Group of " .. nbVehicles .. " vehicles and " .. nbInfantry .. " soldiers.\n"

    if veafCasMission.afacName then
        message = message .. "AFAC on station: " .. veafCasMission.afacName .. "\n"
    end

    message = message .. "\n"

    -- add coordinates and position from bullseye
    local averageGroupPosition = veaf.getAveragePosition(veafCasMission.casGroupName)
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

    message = message .. veaf.weatherReport(averageGroupPosition, nil, true)

    -- send message only for the unit
    veaf.outTextForUnit(unitName, message, 30)
end

--- add a smoke marker over the target area
function veafCasMission.smokeCasTargetGroup()
    veaf.loggers.get(veafCasMission.Id):trace("veafCasMission.smokeCasTargetGroup START")
    veafSpawn.spawnSmoke(veaf.getAveragePosition(veafCasMission.casGroupName), trigger.smokeColor.Red)
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
    veafSpawn.spawnIlluminationFlare(veaf.getAveragePosition(veafCasMission.casGroupName))
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
    local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(veafCasMission.casGroupName)
    if nbVehicles > 0 then
        veaf.loggers.get(veafCasMission.Id):trace("Group is still alive with "..nbVehicles.." vehicles and "..nbInfantry.." soldiers")
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
    veaf.loggers.get(veafCasMission.Id):trace("skipCasTarget START")

    -- destroy vehicles and infantry groups
    veaf.loggers.get(veafCasMission.Id):trace("destroy CAS group")
    local group = Group.getByName(veafCasMission.casGroupName)
    if group and group:isExist() == true then
        group:destroy()
    end
    veaf.loggers.get(veafCasMission.Id):trace("destroy AFAC group")
    group = Group.getByName(veafCasMission.afacName)
    if group and group:isExist() == true then
        group:destroy()
    end
    veafCasMission.afacName = nil

    -- remove the watchdog function
    veaf.loggers.get(veafCasMission.Id):trace("remove the watchdog function")
    if veafCasMission.groupAliveCheckTaskID ~= 'none' then
        mist.removeFunction(veafCasMission.groupAliveCheckTaskID)
    end
    veafCasMission.groupAliveCheckTaskID = 'none'

    
    veaf.loggers.get(veafCasMission.Id):trace("update the radio menu 1")
    veafRadio.delCommand(veafCasMission.rootPath, 'Target information')

    veaf.loggers.get(veafCasMission.Id):trace("update the radio menu 2")
    veafRadio.delCommand(veafCasMission.rootPath, 'Skip current objective')
    veaf.loggers.get(veafCasMission.Id):trace("update the radio menu 3")
    veafRadio.delCommand(veafCasMission.rootPath, 'Get current objective situation')
    veaf.loggers.get(veafCasMission.Id):trace("update the radio menu 4")
    veafRadio.delSubmenu(veafCasMission.targetMarkersPath, veafCasMission.rootPath)

    veafRadio.refreshRadioMenu()
    veaf.loggers.get(veafCasMission.Id):trace("skipCasTarget DONE")

end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafCasMission.buildRadioMenu()
    veafCasMission.rootPath = veafRadio.addSubMenu(veafCasMission.RadioMenuName)
    if not(veafRadio.skipHelpMenus) then
        veafRadio.addCommandToSubmenu("HELP", veafCasMission.rootPath, veafCasMission.help, nil, veafRadio.USAGE_ForGroup)
    end
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

veaf.loggers.get(veafCasMission.Id):info(string.format("Loading version %s", veafCasMission.Version))

--- Enable/Disable error boxes displayed on screen.
env.setErrorMessageBoxEnabled(false)



