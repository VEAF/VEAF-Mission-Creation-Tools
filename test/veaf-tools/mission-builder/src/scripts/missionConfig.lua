-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Mission configuration file for the VEAF framework
-- see https://github.com/VEAF/VEAF-Mission-Creation-Tools
-------------------------------------------------------------------------------------------------------------------------------------------------------------
veaf.config.MISSION_NAME = "VEAF-DevTest-Mission"
veaf.config.MISSION_EXPORT_PATH = nil -- use default folder

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialize QRA
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if veafQraManager then
    -- veaf.loggers.get(veaf.Id):info("init - veafQraManager")
    -- veafQraManager.initialize()
end

--if QRA_Minevody then QRA_Minevody:stop() end --use this if you wish to stop the QRA from operating at any point (in a trigger etc.). It can be restarted with : if QRA_Minevody then QRA_Minevody:start() end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialize all the scripts
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if veafRadio then
    -- the RADIO module is mandatory as it is used by many other modules
    veaf.loggers.get(veaf.Id):info("init - veafRadio")
    veafRadio.initialize(true)
end
if veafSpawn then
    -- the SPAWN module is mandatory as it is used by many other modules
    veaf.loggers.get(veaf.Id):info("init - veafSpawn")
    veafSpawn.initialize()
end
if veafGrass then
    -- uncomment (and adapt) the following lines to enable the Grass Runways and FARP decoration
    --[[
    veaf.loggers.get(veaf.Id):info("init - veafGrass")
    veafGrass.initialize()
    ]]
end
if veafCasMission then
    -- uncomment (and adapt) the following lines to enable the CAS mission module, its commands and its radio menu
    --[[
    veaf.loggers.get(veaf.Id):info("init - veafCasMission")
    veafCasMission.initialize()
    ]]
end
if veafTransportMission then
    -- uncomment (and adapt) the following lines to enable the Transport mission module, its commands and its radio menu
    --[[
    veaf.loggers.get(veaf.Id):info("init - veafTransportMission")
    veafTransportMission.initialize()
    ]]
end
if veafWeather then
    -- uncomment (and adapt) the following lines to enable the Weather module, its commands and its radio menu
    --[[
    veaf.loggers.get(veaf.Id):info("init - veafWeather")
    veafWeather.initialize()
    ]]
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- change some default parameters
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- here you can redefine the parameters you want (see in the source files)
--veaf.DEFAULT_GROUND_SPEED_KPH = 25

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialize SHORTCUTS
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if veafShortcuts then
    -- the SHORTCUTS module is mandatory as it is used by many other modules
    veaf.loggers.get(veaf.Id):info("init - veafShortcuts")
    veafShortcuts.initialize()

    -- you can add all the shortcuts you want here. Shortcuts can be any VEAF command, as entered in a map marker.
    -- here are some examples :

    --[[
     veafShortcuts.AddAlias(
         VeafAlias:new()
             :setName("-sa11")
             :setDescription("SA-11 Gadfly (9K37 Buk) battery")
             :setVeafCommand("_spawn group, name sa11")
             :setBypassSecurity(true)
     )
     ]]
end
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- configure ASSETS
-------------------------------------------------------------------------------------------------------------------------------------------------------------

if veafAssets then
    -- uncomment (and adapt) the following lines to enable the ASSETS module, its commands and its radio menu
    --[[
    veaf.loggers.get(veaf.Id):info("Loading configuration")
    veafAssets.Assets = {
		-- list the assets in the mission below
		-- {sort=1, name="CSG-01 Tarawa", description="Tarawa (LHA)", information="Tacan 11X TAA\nU226 (11)"},  
		-- {sort=2, name="CSG-74 Stennis", description="Stennis (CVN)", information="Tacan 10X STS\nICLS 10\nU225 (10)"},  
		-- {sort=2, name="CSG-71 Roosevelt", description="Roosevelt (CVN)", information="Tacan 12X RHR\nICLS 11\nU227 (12)"},  
		-- {sort=3, name="T1-Arco-1", description="Arco-1 (KC-135)", information="Tacan 64Y\nU290.50 (20)\nZone OUEST", linked="T1-Arco-1 escort"}, 
		-- {sort=4, name="T2-Shell-1", description="Shell-1 (KC-135 MPRS)", information="Tacan 62Y\nU290.30 (18)\nZone EST", linked="T2-Shell-1 escort"},  
		-- {sort=5, name="T3-Texaco-1", description="Texaco-1 (KC-135 MPRS)", information="Tacan 60Y\nU290.10 (17)\nZone OUEST", linked="T3-Texaco-1 escort"},  
		-- {sort=6, name="T4-Shell-2", description="Shell-2 (KC-135)", information="Tacan 63Y\nU290.40 (19)\nZone EST", linked="T4-Shell-2 escort"},  
		-- {sort=6, name="T5-Petrolsky", description="900 (IL-78M, RED)", information="U267", linked="T5-Petrolsky escort"},  
		-- {sort=7, name="CVN-74 Stennis S3B-Tanker", description="Texaco-7 (S3-B)", information="Tacan 75X\nU290.90\nZone PA"},  
		-- {sort=7, name="CVN-71 Roosevelt S3B-Tanker", description="Texaco-8 (S3-B)", information="Tacan 76X\nU290.80\nZone PA"},  
		-- {sort=8, name="Bizmuth", description="Colt-1 AFAC Bizmuth (MQ-9)", information="L1688 V118.80 (18)", jtac=1688, freq=118.80, mod="am"},
		-- {sort=9, name="Agate", description="Dodge-1 AFAC Agate (MQ-9)", information="L1687 V118.90 (19)", jtac=1687, freq=118.90, mod="am"},  
		-- {sort=10, name="A1-Magic", description="Magic (E-2D)", information="Datalink 315.3 Mhz\nU282.20 (13)", linked="A1-Magic escort"},  
		-- {sort=11, name="A2-Overlordsky", description="Overlordsky (A-50, RED)", information="V112.12"},  
    }

    veaf.loggers.get(veaf.Id):info("init - veafAssets")
    veafAssets.initialize()
    ]]
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- configure MOVE
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if veafMove then
    veaf.loggers.get(veaf.Id):info("Setting move tanker radio menus")
    -- keeping the veafMove.Tankers table empty will force veafMove.initialize() to browse the units, and find the tankers automatically
    veaf.loggers.get(veaf.Id):info("init - veafMove")
    veafMove.initialize()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- configure COMBAT MISSION
-------------------------------------------------------------------------------------------------------------------------------------------------------------

if veafCombatMission then 
    -- uncomment (and adapt) the following lines to enable the COMBAT MISSION module (air to air fights), its commands and its radio menu
    --[[
    veaf.loggers.get(veaf.Id):info("Loading configuration")

    veaf.loggers.get(veaf.Id):info("init - veafCombatMission")
    veafCombatMission.initialize()
    ]]
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- configure COMBAT ZONE
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if veafCombatZone then 
    -- veaf.loggers.get(veaf.Id):info("Loading configuration")
    -- veaf.loggers.get(veaf.Id):info("init - veafCombatZone")
    -- veafCombatZone.initialize()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- configure NAMEDPOINTS
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if veafNamedPoints then
    -- the NAMED POINTS module is mandatory as it is used by many other modules

    veaf.loggers.get(veaf.Id):info("Loading configuration")

    
    -- here you can add points of interest, that will be added to the default points
    local customPoints = {
    --     {name="RANGE KhalKhalah",point=coord.LLtoLO("33.036180", "37.196608")},
    }
    veaf.loggers.get(veaf.Id):info("init - veafNamedPoints")
    veafNamedPoints.initialize(customPoints)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- configure SECURITY
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if veafSecurity then
    -- the SECURITY module is mandatory as it is used by many other modules

    --let's not set a password
    veaf.SecurityDisabled = true
    --veafSecurity.password_L9["SHA1 hash of the password"] = true -- set the L9 password (the lowest possible security)
    veaf.loggers.get(veaf.Id):info("Loading configuration")
    veaf.loggers.get(veaf.Id):info("init - veafSecurity")
    veafSecurity.initialize()

    -- force security in order to test it when dynamic loading is in place (change to TRUE)
    if (false) then
        veaf.SecurityDisabled = false
        veafSecurity.authenticated = false
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- configure CARRIER OPERATIONS
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if veafCarrierOperations then
    -- uncomment (and adapt) the following lines to enable the CARRIER OPERATIONS module, its commands and its radio menu
    --[[
    veaf.loggers.get(veaf.Id):info("init - veafCarrierOperations")
    veafCarrierOperations.initialize(true)
    ]]
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- configure CTLD
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if ctld then
    local initializeCTLD = true
    if initializeCTLD then -- we want to use CTLD
        veaf.loggers.get(veaf.Id):info("initialize CTLD")
        local function configurationCallback()
            veaf.loggers.get(veaf.Id):info("configuring CTLD for %s", veaf.config.MISSION_NAME)
            -- do what you have to do in CTLD before it is initialized
            -- ctld.hoverPickup = false
            -- ctld.slingLoad = true
        end
        -- call the VEAF function that replaced ctld.initialize
        ctld.initialize(configurationCallback)
    else
        -- make the already scheduled ctld.initialize function think it's already initialized
        ctld.alreadyInitialized = true
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- configure CSAR
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if csar then
    local initializeCSAR = true
    if initializeCSAR then -- we want to use CSAR
        veaf.loggers.get(veaf.Id):info("initialize CSAR")
        local function configurationCallback()
            veaf.loggers.get(veaf.Id):info("configuring CSAR for %s", veaf.config.MISSION_NAME)
            --[[
            -- do what you have to do in csar before it is initialized
            csar.enableAllslots = true  -- Doesn't require to set the Unit name check Aircraft Type and Limit below
            -- All slot / Limit settings
            csar.aircraftType = {} -- Type and limit
            csar.aircraftType["SA342Mistral"] = 2
            csar.aircraftType["SA342Minigun"] = 2
            csar.aircraftType["SA342L"] = 2
            csar.aircraftType["SA342M"] = 2
            csar.aircraftType["UH-1H"] = 8
            csar.aircraftType["Mi-8MT"] = 16
            
            -- Prefix Settings - Only For helicopters
            csar.useprefix    = true  -- Use the Prefixed defined below, Requires Unit have the Prefix defined below 
            csar.csarPrefix = { "helicargo", "MEDEVAC"}
            ]]
            csar.enableAllslots = true
            csar.aircraftType["SA342Mistral"] = 2
            csar.aircraftType["SA342Minigun"] = 2
            csar.aircraftType["SA342L"] = 2
            csar.aircraftType["SA342M"] = 2
            csar.aircraftType["UH-1H"] = 8
            csar.aircraftType["Mi-8MT"] = 16
            csar.useprefix  = false
            csar.radioSound = "csar-beacon.ogg"
        end
        -- call the VEAF function that replaced csar.initialize
        csar.initialize(configurationCallback)
    else
        -- make the already scheduled csar.initialize function think it's already initialized
        csar.alreadyInitialized = true
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- configure AIEN
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if AIEN then
    local initializeAIEN = true
    if initializeAIEN then -- we want to use AIEN
        veaf.loggers.get(veaf.Id):info("initialize AIEN")

        -- these are the default configuration values, edit them to make them match your mission
        
        -- coalition affected by the script
        AIEN.config.blueAI                        = true        -- true/false. If true, the AI enhancement will be applied to the blue coalition ground groups, else, no script effect will take place
        AIEN.config.redAI                         = true        -- true/false. If true, the AI enhancement will be applied to the red  coalition ground groups, else, no script effect will take place

        -- Action sets allowed.
        AIEN.config.suppression                   = true        -- true/false. If true, once a group take fire from arty or air and it's not armoured, it will be suppressed for 15-45 seconds and won't return fire. Require reactions to be set as 'true'
        AIEN.config.firemissions                  = true        -- true/false. If true, each artillery in the coalition will fire automatically at available targets provided by other ground units and drones
        AIEN.config.reactions                     = true        -- true/false. If true, when a mover group gets an hit, it will react accordingly to its skills and to its situational awareness, not staying there taking hits without doing nothing
        AIEN.config.dismount                      = true        -- true/false. //BEWARE: CAN AFFECT PERFORMANCES ON LOW END SYSTEMS // Thanks to MBot's original script, if true AI ground units with infantry transport capabilities (mainly APC/IFV/Trucks) will dismount soldiers with rifle, rpg and sometimes mandpads when appropriate

        -- User advanced customization
        AIEN.config.AIEN_xcl_tag                  = "XCL"       -- string, global, case sensitive. Can be dynamically changed by other script or triggers, since it's a global variable. used as a text format without spaces or special characters. only letters and numbers allowed. Any ground group with this 'tag' in its group name won't get AI enhancement behaviour, regardless of its coalition
        AIEN.config.AIEN_zoneFilter               = ""          -- string, global, case sensitive. Can be dynamically changed by other script or triggers, since it's a global variable. used as a text format without spaces or special characters. only letters and numbers allowed, i.e. "AIEN" will fit. If left nil, or void string like "", won't be used. Only groups inside the named trigger zone will be affected by AIEN script behaviors of reaction, dismount and suppression, and vice versa. If no trigger zone with the specific name is in the mission, then all the groups will use AIEN features.
        AIEN.config.message_feed                  = true        -- true/false. If true, each relevant AI action starting will also create a trigger message feedback for its coalition
        AIEN.config.mark_on_f10_map               = true        -- true/false. If true, when an artillery fire mission is ongoing, a markpoint will appear on the map of the allied coalition to show the expected impact point
        AIEN.config.skill_action_const            = false       -- true/false. If true, AI available reactions types will be limited by the group average skill. If not, almost 2/3 of all available actions will be always be available regardless of the group skills

        -- User bug report: prior to report a bug, please try reproducing it with this variable set to "true"
        AIEN.config.AIEN_debugProcessDetail       = true

        -- movement variables
        AIEN.config.outRoadSpeed                  = 8           -- do *3.6 for km/h, cause DCS thinks in m/s
        AIEN.config.inRoadSpeed                   = 15          -- do *3.6 for km/h, cause DCS thinks in m/s
        AIEN.config.infantrySpeed                 = 2           -- do *3.6 for km/h, cause DCS thinks in m/s
        AIEN.config.repositionDistance            = 500         -- meters, radius to a specific destination point that will be randomized between 90% and 110% of this value. Used when a group is moved upon another group position: the other group position will be the destination.
        AIEN.config.rndFleeDistance               = 2000        -- meters, reposition distance given to a group when a destination is not defined. The direction also will be totally random. Used, i.e., for "panic" reaction

        -- dismounted troops variables
        AIEN.config.droppedReposition             = 80          -- if no enemy is identified, this is the distance where dismount group will reposition themselves
        AIEN.config.remountTime                   = 600         -- time after which dismounted troops will try to go back to their original vehicle for remount, if commanded
        AIEN.config.infantryExtractDist           = 200         -- max distance from vehicle to troops to allow a group extraction
        AIEN.config.infantrySearchDist            = 2000        -- max distance from vehicle to troops to allow a dismount group to run toward the enemies

        -- informative calls variables
        AIEN.config.outAmmoLowLevel               = 0.5         -- factor on total amount

        -- reactions and tasking variables
        AIEN.config.intelDbTimeout                = 1200        -- seconds. Used to cancel intelDb entries for units (not static!), when the time of the contact gathering is more than this value
        AIEN.config.artyFireLastContactThereshold = 300         -- seconds, max amount of time since last contact to consider an arty target ok
        AIEN.config.taskTimeout                   = 480         -- seconds after which a tasked group is removed from the database
        AIEN.config.targetedTimeout               = 240         -- seconds after which a targeted variable in inteldb is removed from database
        AIEN.config.disperseActionTime            = 120         -- seconds
        AIEN.config.counterBatteryRadarRange      = 50000       -- m, capable distance for a radar to perform counter battery calculations
        AIEN.config.counterBatteryPlanDelay       = 240         -- s, will be also randomized on +-35%. Used to define the delay of the planned counter battery fire if available
        AIEN.config.smoke_source_num              = 5           -- number, between 4 and 9. Generated smokes for each unit when smoke reaction is called in. Any number below 4 or above 9 will be converted in the nearest threshold

        -- SA evaluation variables
        AIEN.config.proxyBuildingDistance         = 4000        -- m, if buildings are within this distance value, they are considered "close"
        AIEN.config.proxyUnitsDistance            = 5000        -- m, if units are within this distance value, they are considered "close"
        AIEN.config.supportDistance               = 8000        -- m, maximum distance for evaluating support or cover movements when under attack
        AIEN.config.withrawDist                   = 15000       -- m, maximum distance for withdraw manoeuvre nearby a friendly support unit

        -- initialize AIEN
        AIEN.performPhaseCycle()
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialize the remote interface
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if veafRemote then
    -- uncomment (and adapt) the following lines to enable the REMOTE module (call functions from a remote interface, such as the server), its commands and its radio menu
    --[[
    veaf.loggers.get(veaf.Id):info("init - veafRemote")
    veafRemote.initialize()
    ]]
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialize Skynet-IADS
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if veafSkynet then
    -- uncomment (and adapt) the following lines to enable Skynet-IADS
    --[[
    veaf.loggers.get(veaf.Id):info("init - veafSkynet")
    veafSkynet.initialize(
        false, --includeRedInRadio=true
        false, --debugRed
        false, --includeBlueInRadio
        false --debugBlue
    )
    ]]
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialize the interpreter
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if veafInterpreter then
    -- the INTERPRETER module is mandatory as it is used by many other modules
    veaf.loggers.get(veaf.Id):info("init - veafInterpreter")
    veafInterpreter.initialize()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialize veafSanctuary
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if veafSanctuary then
    -- uncomment (and adapt) the following lines to enable the SANCTUARY module, its commands and its radio menu
    --[[
    veaf.loggers.get(veaf.Id):info("init - veafSanctuary")
    veafSanctuary.initialize()
    ]]
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialize Hound Elint
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if veafHoundElint then
    -- uncomment (and adapt) the following lines to enable Hound Elint
    --[[
    veaf.loggers.get(veaf.Id):info("init - veafHoundElint")
    veafHoundElint.initialize(
        "ELINT", -- prefix
        { -- red
            --global parameters
            sectors = {},
            markers = true,
            disableBDA = false, --disables notifications that a radar has dropped off scope
            platformPositionErrors = true,
            NATOmessages = false, --provides positions relative to the bullseye
            NATO_SectorCallsigns = false, --uses a different pool for sector callsigns
            ATISinterval = 180,
            preBriefedContacts = {
                --"Stuff",
                --"Thing",
            }, --contains the name of units placed in the ME which will be designated as pre-briefed (exact location) and who's position will be indicated exactly by Hound until the unit moved 100m away
            debug = false, --set this to true to make sure your configuration is correct and working as intended
        },
        { -- blue
            sectors = {
                --Global sector, mandatory inclusion if you want a global ATIS/controller etc., encompasses the whole map so it'll be very crowded in terms of comms
                [veafHoundElint.globalSectorName] = {
                    callsign = "Global Sector", --defines a specific callsign for the sector which will be used by the ATIS etc., if absent or nil Hound will assign it a callsign automatically, NATO format of regular Hound format. If true, callsign will be equal to the sector name
                    atis = {
                        freq = 282.175,
                        speed = 1,
                        --additional params
                        reportEWR = false
                    },
                    controller = {
                        freq = 282.225,
                        --additional params
                        voiceEnabled = true
                    },
                    notifier = {
                        freq = 282.2,
                        --additional params
                    },
                    disableAlerts = false, --disables alerts on the ATIS/Controller when a new radar is detected or destroyed
                    transmitterUnit = nil, --use the Unit/Pilot name to set who the transmitter is for the ATIS etc. This can be a static, and aircraft or a vehicule/ship
                    disableTTS = false,
                },
                --sector named "Maykop", will be geofenced to the mission editor polygon drawing (free or rectangle) called "Maykop" (case sensitive)
                ["Maykop"] = {
                    callsign = true, --defines a specific callsign for the sector which will be used by the ATIS etc., if absent or nil Hound will assign it a callsign automatically, NATO format of regular Hound format. If true, callsign will be equal to the sector name
                    atis = {
                        freq = 281.075,
                        speed = 1,
                        --additional params
                        reportEWR = false
                    },
                    controller = {
                        freq = 281.125,
                        --additional params
                        voiceEnabled = true
                    },
                    notifier = {
                        freq = 281.1,
                        --additional params
                    },
                    disableAlerts = false, --disables alerts on the ATIS/Controller when a new radar is detected or destroyed
                    transmitterUnit = nil, --use the Unit/Pilot name to set who the transmitter is for the ATIS etc. This can be a static, and aircraft or a vehicule/ship
                    disableTTS = false,
                },
            },
            --global parameters
            markers = true,
            disableBDA = false, --disables notifications that a radar has dropped off scope
            platformPositionErrors = true,
            NATOmessages= true, --provides positions relative to the bullseye
            NATO_SectorCallsigns = true, --uses a different pool for sector callsigns
            ATISinterval = 180,
            preBriefedContacts = {
                --"Stuff",
                --"Thing",
            }, --contains the name of units or groups placed in the ME which will be designated as pre-briefed (exact location) and who's position will be indicated exactly by Hound until the unit moved 100m away. If multiple radars are within a specified group, they'll all be added as pre-briefed targets
            debug = false, --set this to true to make sure your configuration is correct and working as intended
        }
        -- args = {
        --     freq = 250.000,
        --     modulation = "AM",
        --     volume = "1.0",
        --     speed = <speed> -- number default is 0/1 for controller/atis. range is -10 to +10 on windows TTS. for google it's 0.25 to 4.0
        --     gender = "male"|"female",
        --     culture = "en-US"|"en-UK" -- (any installed on your system)
        --     isGoogle = true/false -- use google TTS (requires additional STTS config)
        --     voiceEnabled = true/false (for the controller only) -- to set if the controllers uses text or TTS
        --     reportEWR = true/false (for ATIS only) -- set to tell the ATIS to report EWRs as threats
        -- }
    )
    ]]
end

-- uncomment the following lines to silence the default ATC on all the airdromes
veaf.silenceAtcOnAllAirbases()

-- veafShortcuts.ExecuteBatchAliasesList({
--     "-point#U37TGG3632145648 npKobuletiRw07",
--     "-farp#npKobuletiRw07, side blue, radius 1, hdg 070",
--     "-farp#tzKobuletiRw25, side blue, radius 1, hdg 250",
--     "-farp#U37TGG3745845864, side blue, radius 1, hdg 0",
-- }, 0, coalition.side.BLUE, false)

--veafCombatZone.HideZoneNameFromGroupNames = false
--veafCombatZone.GetZone("combatZone_Batumi"):activate()