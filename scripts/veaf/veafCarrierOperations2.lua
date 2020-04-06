-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF carrier command and functions for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- New version using Moose.AIRBOSS
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires Moose
-- * It also requires the base veaf.lua script library (version 1.0 or higher)
-- * It also requires the base veafRadio.lua script library (version 1.0 or higher)
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
--     * OPEN --> Browse to the location of MOOSE and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of veaf.lua and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of veafRadio.lua and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of this script and click OK.
--     * ACTION "DO SCRIPT"
--     * set the script command to "veafRadio.initialize();veafCarrierOperations.initialize()" and click OK.
-- 4.) Save the mission and start it.
-- 5.) Have fun :)
--
-- Basic Usage:
-- ------------
-- Use the F10 radio menu to start and end carrier operations for every detected carrier group (having a group name like "CSG-*")
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafCarrierOperations = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafCarrierOperations.Id = "CARRIER - "

--- Version.
veafCarrierOperations.Version = "2.0.1"

-- trace level, specific to this module
veafCarrierOperations.Trace = false

veafCarrierOperations.RadioMenuName = "CARRIER OPS"

---------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Radio menus paths
veafCarrierOperations.rootPath = nil

--- Carrier info to store the status
veafCarrierOperations.carrier = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafCarrierOperations.logError(message)
    veaf.logError(veafCarrierOperations.Id .. message)
end

function veafCarrierOperations.logInfo(message)
    veaf.logInfo(veafCarrierOperations.Id .. message)
end

function veafCarrierOperations.logDebug(message)
    veaf.logDebug(veafCarrierOperations.Id .. message)
end

function veafCarrierOperations.logTrace(message)
    if message and veafCarrierOperations.Trace then 
        veaf.logTrace(veafCarrierOperations.Id .. message)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu 
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Start recovery function.
function veafCarrierOperations.startRecovery(parameters)
    local case, unitName = unpack(parameters)
    veafCarrierOperations.logDebug(string.format("veafCarrierOperations.startRecovery(%s, %d)", unitName, case))
    veafCarrierOperations.AirbossStennis:_SkipperStartRecovery(unitName, case)
end

-- Stop recovery function.
function veafCarrierOperations.stopRecovery(unitName)
    veafCarrierOperations.logDebug(string.format("veafCarrierOperations.stopRecovery(%s)", unitName))
    veafCarrierOperations.AirbossStennis:_SkipperStopRecovery(unitName)
end

--- Rebuild the radio menu
function veafCarrierOperations.rebuildRadioMenu()
    veafCarrierOperations.logDebug("veafCarrierOperations.rebuildRadioMenu()")

    -- add specific protected recovery radio commands
    local case1Path = veafRadio.addSubMenu("Start CASE I", veafCarrierOperations.rootPath)
    veafRadio.addSecuredCommandToSubmenu( "Start CASE I",   case1Path, veafCarrierOperations.startRecovery, 1, veafRadio.USAGE_ForUnit)

    local case2Path = veafRadio.addSubMenu("Start CASE II", veafCarrierOperations.rootPath)
    veafRadio.addSecuredCommandToSubmenu( "Start CASE II",   case2Path, veafCarrierOperations.startRecovery, 2, veafRadio.USAGE_ForUnit)

    local case3Path = veafRadio.addSubMenu("Start CASE III", veafCarrierOperations.rootPath)
    veafRadio.addSecuredCommandToSubmenu( "Start CASE III",   case3Path, veafCarrierOperations.startRecovery, 3, veafRadio.USAGE_ForUnit)

    local stopPath = veafRadio.addSubMenu("Stop Recovery", veafCarrierOperations.rootPath)
    veafRadio.addSecuredCommandToSubmenu( "Stop Recovery",   stopPath, veafCarrierOperations.stopRecovery, nil, veafRadio.USAGE_ForUnit)

    veafRadio.refreshRadioMenu()
end

--- Build the initial radio menu
function veafCarrierOperations.buildRadioMenu()
    veafCarrierOperations.logDebug("veafCarrierOperations.buildRadioMenu")

    veafCarrierOperations.rootPath = veafRadio.addSubMenu(veafCarrierOperations.RadioMenuName)

    veafCarrierOperations.rebuildRadioMenu()
end

function veafCarrierOperations.initializeCarrierGroup()

    -- Create AIRBOSS object.
    veafCarrierOperations.AirbossStennis=AIRBOSS:New(veafCarrierOperations.carrier.carrierName)
    veafCarrierOperations.AirbossStennis:SetLSORadio(veafCarrierOperations.carrier.lsoFreq)
    veafCarrierOperations.AirbossStennis:SetPatrolAdInfinitum()

    local shift=1 -- Current shift.
    local function ChangeShift(airboss)
        local airboss=airboss --Ops.Airboss#AIRBOSS
        
        -- Next shift.
        shift=shift+1
        
        -- One cycle done. Next will be first shift.
        if shift==5 then
            shift=1
        end
        
        -- Set sound folder and voice over timings. 
        if shift==1 then
            env.info("Starting LSO/Marshal Shift 1: LSO Raynor, Marshal Raynor")
            airboss:SetVoiceOversLSOByRaynor()
            airboss:SetVoiceOversMarshalByRaynor()
        elseif shift==2 then
            env.info("Starting LSO/Marshal Shift 2: LSO FF, Marshal Raynor")
            airboss:SetVoiceOversLSOByFF("Airboss Soundpack LSO FF/")
            airboss:SetVoiceOversMarshalByRaynor()  
        elseif shift==3 then
            env.info("Starting LSO/Marshal Shift 3: LSO Raynor, Marshal FF")
            airboss:SetVoiceOversLSOByRaynor()
            airboss:SetVoiceOversMarshalByFF("Airboss Soundpack Marshal FF/")
        elseif shift==4 then
            env.info("Starting LSO/Marshal Shift 4: LSO FF, Marshal FF")
            airboss:SetVoiceOversLSOByFF("Airboss Soundpack LSO FF/")
            airboss:SetVoiceOversMarshalByFF("Airboss Soundpack Marshal FF/")
        end  
    end

    -- Length of shift in minutes.
    local L=30

    -- Start shift scheduler to change shift every L minutes.
    SCHEDULER:New(nil, ChangeShift, {veafCarrierOperations.AirbossStennis}, L*60, L*60)

    -- Add recovery windows 
    local duration = 30 * 60 -- every 30 minutes
    for seconds = env.mission.start_time+300 --[[5 minutes after mission start]],env.mission.start_time + 86400,3600 do 
        local startClock = UTILS.SecondsToClock(seconds)
        local endClock = UTILS.SecondsToClock(seconds+duration)
        local secondsToday = math.fmod(seconds,86400)  -- time mod a full day
        if secondsToday  < 5 * 3600 and secondsToday > 22 * 3600 then            
            -- night = CASE 3
            veafCarrierOperations.AirbossStennis:AddRecoveryWindow( startClock, endClock, 3, 30, true, 21)
        elseif secondsToday < 8 * 3600 and secondsToday > 5 * 3600 then 
            -- dawn = CASE 2
            veafCarrierOperations.AirbossStennis:AddRecoveryWindow( startClock, endClock, 2, 15, true, 23)
        elseif secondsToday < 20 * 3600 and secondsToday > 8 * 3600 then 
            -- day
            veafCarrierOperations.AirbossStennis:AddRecoveryWindow( startClock, endClock, 1, nil, true, 25)
        elseif secondsToday < 22 * 3600 and secondsToday > 20 * 3600 then 
            -- sunset = CASE 2
            veafCarrierOperations.AirbossStennis:AddRecoveryWindow( startClock, endClock, 2, 15, true, 23)
        end
    end

    -- Set folder of airboss sound files within miz file.
    veafCarrierOperations.AirbossStennis:SetSoundfilesFolder("Airboss Soundfiles/")

    -- Single carrier menu optimization.
    veafCarrierOperations.AirbossStennis:SetMenuSingleCarrier()

    -- Remove landed AI planes from flight deck.
    veafCarrierOperations.AirbossStennis:SetDespawnOnEngineShutdown()

    -- Load all saved player grades from your "Saved Games\DCS" folder (if lfs was desanitized).
    veafCarrierOperations.AirbossStennis:Load()

    -- Automatically save player results to your "Saved Games\DCS" folder each time a player get a final grade from the LSO.
    veafCarrierOperations.AirbossStennis:SetAutoSave()

    -- Enable trap sheet.
    veafCarrierOperations.AirbossStennis:SetTrapSheet()

    -- Repeater for radio transmissions
    veafCarrierOperations.AirbossStennis:SetRadioRelayLSO(veafCarrierOperations.carrier.repeaterLso)
    veafCarrierOperations.AirbossStennis:SetRadioRelayMarshal(veafCarrierOperations.carrier.repeaterMarshal)

    -- S-3B Recovery Tanker spawning in air.
    local tanker=RECOVERYTANKER:New(veafCarrierOperations.carrier.carrierName, veafCarrierOperations.carrier.tankerName)
    tanker:SetTakeoffAir()
    tanker:SetRadio(veafCarrierOperations.carrier.tankerFreq)
    tanker:SetModex(veafCarrierOperations.carrier.tankerModex)
    tanker:SetTACAN(veafCarrierOperations.carrier.tankerTacanChannel, veafCarrierOperations.carrier.tankerTacanMorse)
    tanker:__Start(1)

    --- Function called when recovery tanker is started.
    function tanker:OnAfterStart(From,Event,To)
        
        -- Set recovery tanker.
        veafCarrierOperations.AirbossStennis:SetRecoveryTanker(tanker)  
    end

    -- Rescue Helo with home base Lake Erie. Has to be a global object!
    rescuehelo=RESCUEHELO:New(veafCarrierOperations.carrier.carrierName, veafCarrierOperations.carrier.pedroName)
    rescuehelo:SetHomeBase(AIRBASE:FindByName(veafCarrierOperations.carrier.pedroBase))
    rescuehelo:SetModex(veafCarrierOperations.carrier.pedroModex)
    rescuehelo:__Start(1)

    --- Function called when a player gets graded by the LSO.
    function veafCarrierOperations.AirbossStennis:OnAfterLSOGrade(From, Event, To, playerData, grade)
        local PlayerData=playerData --Ops.Airboss#AIRBOSS.PlayerData
        local Grade=grade --Ops.Airboss#AIRBOSS.LSOgrade
        
        
        local score=tonumber(Grade.points)
        local name=tostring(PlayerData.name)
        
        -- Report LSO grade to dcs.log file.
        env.info(string.format("Player %s scored %.1f", name, score))
    end

    -- No Skipper menu.
    --veafCarrierOperations.AirbossStennis:SetMenuRecovery()
    veafCarrierOperations.AirbossStennis.skipperTime=30
    veafCarrierOperations.AirbossStennis.skipperSpeed=25
    veafCarrierOperations.AirbossStennis.skipperOffset=30
    veafCarrierOperations.AirbossStennis.skipperUturn=true
  
    -- Start airboss class.
    veafCarrierOperations.AirbossStennis:Start()

end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafCarrierOperations.setCarrierInfo(name, lsoFreq, marshallFreq)
    veafCarrierOperations.carrier.carrierName = name
    veafCarrierOperations.carrier.lsoFreq = lsoFreq
    veafCarrierOperations.carrier.marshallFreq = marshallFreq
end

function veafCarrierOperations.setTankerInfo(name, freq, tacanChannel, tacanMorse, modex)
    veafCarrierOperations.carrier.tankerName = name
    veafCarrierOperations.carrier.tankerFreq = freq
    veafCarrierOperations.carrier.tankerTacanChannel = tacanChannel
    veafCarrierOperations.carrier.tankerTacanMorse = tacanMorse
    veafCarrierOperations.carrier.tankerModex = modex
end

function veafCarrierOperations.setPedroInfo(name, base, modex)
    veafCarrierOperations.carrier.pedroName = name
    veafCarrierOperations.carrier.pedroBase = base
    veafCarrierOperations.carrier.pedroModex = modex
end

function veafCarrierOperations.setRepeaterInfo(lso, marshal)
    veafCarrierOperations.carrier.repeaterLso = lso
    veafCarrierOperations.carrier.repeaterMarshal = marshal
end
   
function veafCarrierOperations.initialize()
    veafCarrierOperations.initializeCarrierGroup()
    veafCarrierOperations.buildRadioMenu()
end

veafCarrierOperations.logInfo(string.format("Loading version %s", veafCarrierOperations.Version))

--- Enable/Disable error boxes displayed on screen.
env.setErrorMessageBoxEnabled(false)



