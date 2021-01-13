-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- DCS World units database
-- By zip (2018)
--
-- Load the script:
-- ----------------
-- 1.) Download the script and save it anywhere on your hard drive.
-- 2.) Open your mission in the mission editor.
-- 3.) Add a new trigger:
--     * TYPE   "4 MISSION START"
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location where you saved the script and click OK.
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

dcsUnits = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the root VEAF constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
dcsUnits.Id = "DCSUNITS - "

--- Version.
dcsUnits.Version = "2021.01.12"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function dcsUnits.logInfo(message)
    if message then
        veaf.logInfo(dcsUnits.Id .. message)
    end
end

function dcsUnits.logDebug(message)
    if message then
        veaf.logDebug(dcsUnits.Id .. message)
    end
end

function dcsUnits.logTrace(message)
    if message then
        veaf.logTrace(dcsUnits.Id .. message)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Raw DCS units database
-------------------------------------------------------------------------------------------------------------------------------------------------------------

dcsUnits.DcsUnitsDatabase =
{
	[1] = 
	{
		["type"] = "flak18",
		["name"] = "AAA 8,8cm Flak 18",
		["category"] = "Air Defence",
		["description"] = "AAA 8,8cm Flak 18",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground vehicles"] = true,
			["Vehicles"] = true,
			[26] = true,
			["NonArmoredUnits"] = true,
			["AA_flak"] = true,
			["All"] = true,
			["AAA"] = true,
			[16] = true,
			[47] = true,
			["Rocket Attack Valid AirDefence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["Air Defence"] = true,
			["Static AAA"] = true,
			["Ground Units"] = true,
			[2] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [1]
	[2] = 
	{
		["type"] = "bofors40",
		["name"] = "AAA Bofors 40 mm",
		["category"] = "Air Defence",
		["description"] = "AAA Bofors 40 mm",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground vehicles"] = true,
			["Vehicles"] = true,
			[26] = true,
			["NonArmoredUnits"] = true,
			["AA_flak"] = true,
			["All"] = true,
			["AAA"] = true,
			[16] = true,
			[47] = true,
			["Rocket Attack Valid AirDefence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["Air Defence"] = true,
			["Static AAA"] = true,
			["Ground Units"] = true,
			[2] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [2]
	[3] = 
	{
		["type"] = "Vulcan",
		["name"] = "AAA Vulcan M163",
		["category"] = "Air Defence",
		["description"] = "AAA Vulcan M163",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["Ground vehicles"] = true,
			[105] = true,
			["Mobile AAA"] = true,
			[46] = true,
			["NonArmoredUnits"] = true,
			["AAA"] = true,
			["Rocket Attack Valid AirDefence"] = true,
			["Air Defence"] = true,
			["Armed Air Defence"] = true,
			["SAM TR"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM related"] = true,
			["AA_flak"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "M163 Vulcan",
		}, -- end of ["aliases"]
	}, -- end of [3]
	[4] = 
	{
		["type"] = "ZSU_57_2",
		["name"] = "AAA ZSU-57-2",
		["category"] = "Air Defence",
		["description"] = "AAA ZSU-57-2",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground vehicles"] = true,
			["Vehicles"] = true,
			[26] = true,
			["Ground Units"] = true,
			["AA_flak"] = true,
			["All"] = true,
			["Rocket Attack Valid AirDefence"] = true,
			[16] = true,
			["AAA"] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Air Defence"] = true,
			[257] = true,
			["Armed Air Defence"] = true,
			["Mobile AAA"] = true,
			[2] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [4]
	[5] = 
	{
		["type"] = "ZU-23 Emplacement Closed",
		["name"] = "AAA ZU-23 Closed",
		["category"] = "Air Defence",
		["description"] = "AAA ZU-23 Closed",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground vehicles"] = true,
			[48] = true,
			[26] = true,
			["Vehicles"] = true,
			["AA_flak"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			[16] = true,
			["AAA"] = true,
			["Rocket Attack Valid AirDefence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["Air Defence"] = true,
			["Static AAA"] = true,
			["Ground Units"] = true,
			[2] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [5]
	[6] = 
	{
		["type"] = "ZU-23 Emplacement",
		["name"] = "AAA ZU-23 Emplacement",
		["category"] = "Air Defence",
		["description"] = "AAA ZU-23 Emplacement",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground vehicles"] = true,
			["Vehicles"] = true,
			[26] = true,
			["NonArmoredUnits"] = true,
			["AA_flak"] = true,
			["All"] = true,
			["AAA"] = true,
			[16] = true,
			[47] = true,
			["Rocket Attack Valid AirDefence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["Air Defence"] = true,
			["Static AAA"] = true,
			["Ground Units"] = true,
			[2] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [6]
	[7] = 
	{
		["type"] = "ZU-23 Insurgent",
		["name"] = "AAA ZU-23 Insurgent",
		["category"] = "Air Defence",
		["description"] = "AAA ZU-23 Insurgent",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground vehicles"] = true,
			["Vehicles"] = true,
			[26] = true,
			[70] = true,
			["AA_flak"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			[16] = true,
			["AAA"] = true,
			["Rocket Attack Valid AirDefence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["Air Defence"] = true,
			["Static AAA"] = true,
			["Ground Units"] = true,
			[2] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [7]
	[8] = 
	{
		["type"] = "ZU-23 Closed Insurgent",
		["name"] = "AAA ZU-23 Insurgent Closed",
		["category"] = "Air Defence",
		["description"] = "AAA ZU-23 Insurgent Closed",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground vehicles"] = true,
			["Vehicles"] = true,
			[26] = true,
			[2] = true,
			["AA_flak"] = true,
			["All"] = true,
			["Rocket Attack Valid AirDefence"] = true,
			[16] = true,
			["AAA"] = true,
			["Armed Air Defence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Air Defence"] = true,
			[71] = true,
			["Static AAA"] = true,
			["Ground Units"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [8]
	[9] = 
	{
		["type"] = "Ural-375 ZU-23 Insurgent",
		["name"] = "AAA ZU-23 Insurgent on Ural-375",
		["category"] = "Air Defence",
		["description"] = "AAA ZU-23 Insurgent on Ural-375",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground vehicles"] = true,
			["Vehicles"] = true,
			[26] = true,
			["Ground Units"] = true,
			["AA_flak"] = true,
			["All"] = true,
			["Rocket Attack Valid AirDefence"] = true,
			[16] = true,
			["AAA"] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			[72] = true,
			["Air Defence"] = true,
			["Armed Air Defence"] = true,
			["Mobile AAA"] = true,
			[2] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [9]
	[10] = 
	{
		["type"] = "Ural-375 ZU-23",
		["name"] = "AAA ZU-23 on Ural-375",
		["category"] = "Air Defence",
		["description"] = "AAA ZU-23 on Ural-375",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground vehicles"] = true,
			["Vehicles"] = true,
			[26] = true,
			["Ground Units"] = true,
			["AA_flak"] = true,
			["All"] = true,
			["Rocket Attack Valid AirDefence"] = true,
			[16] = true,
			["AAA"] = true,
			[49] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["Armed Air Defence"] = true,
			["Mobile AAA"] = true,
			[2] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [10]
	[11] = 
	{
		["type"] = "Dog Ear radar",
		["name"] = "CP 9S80M1 Sborka",
		["category"] = "Air Defence",
		["description"] = "CP 9S80M1 Sborka",
		["vehicle"] = true,
		["attribute"] = 
		{
			["SAM elements"] = true,
			["SAM related"] = true,
			["Vehicles"] = true,
			[27] = true,
			[2] = true,
			["Air Defence"] = true,
			["SAM SR"] = true,
			[101] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [11]
	[12] = 
	{
		["type"] = "1L13 EWR",
		["name"] = "EWR 1L13",
		["category"] = "Air Defence",
		["description"] = "EWR 1L13",
		["vehicle"] = true,
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Vehicles"] = true,
			["NonArmoredUnits"] = true,
			["CustomAimPoint"] = true,
			["Air Defence"] = true,
			["Ground vehicles"] = true,
			["Air Defence vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["EWR"] = true,
			[16] = true,
			["All"] = true,
			["Ground Units"] = true,
			[101] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [12]
	[13] = 
	{
		["type"] = "55G6 EWR",
		["name"] = "EWR 55G6",
		["category"] = "Air Defence",
		["description"] = "EWR 55G6",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Vehicles"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence vehicles"] = true,
			["CustomAimPoint"] = true,
			["Air Defence"] = true,
			["Ground vehicles"] = true,
			[101] = true,
			["NonAndLightArmoredUnits"] = true,
			["EWR"] = true,
			[2] = true,
			["All"] = true,
			["Ground Units"] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [13]
	[14] = 
	{
		["type"] = "HQ-7_LN_SP",
		["name"] = "HQ-7 Self-Propelled LN",
		["category"] = "Air Defence",
		["description"] = "HQ-7 Self-Propelled LN",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			[271] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["AA_missile"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["SAM related"] = true,
			[102] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM TR"] = true,
			["SAM SR"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["SR SAM"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [14]
	[15] = 
	{
		["type"] = "HQ-7_STR_SP",
		["name"] = "HQ-7 Self-Propelled STR",
		["category"] = "Air Defence",
		["description"] = "HQ-7 Self-Propelled STR",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["SAM SR"] = true,
			["Ground vehicles"] = true,
			[101] = true,
			[272] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["SR SAM"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM related"] = true,
			["SAM TR"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [15]
	[16] = 
	{
		["type"] = "rapier_fsa_blindfire_radar",
		["name"] = "Rapier FSA Blindfire Tracker",
		["category"] = "Air Defence",
		["description"] = "Rapier FSA Blindfire Tracker",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			[31] = true,
			[16] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["SAM elements"] = true,
			["SR SAM"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM related"] = true,
			["SAM TR"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[27] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [16]
	[17] = 
	{
		["type"] = "rapier_fsa_launcher",
		["name"] = "Rapier FSA Launcher",
		["category"] = "Air Defence",
		["description"] = "Rapier FSA Launcher",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			[31] = true,
			[16] = true,
			["SAM SR"] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["AA_missile"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			["NonArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["SAM elements"] = true,
			["Air Defence"] = true,
			["SAM related"] = true,
			["SR SAM"] = true,
			["SAM LL"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM TR"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[27] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [17]
	[18] = 
	{
		["type"] = "rapier_fsa_optical_tracker_unit",
		["name"] = "Rapier FSA Optical Tracker",
		["category"] = "Air Defence",
		["description"] = "Rapier FSA Optical Tracker",
		["vehicle"] = true,
		["attribute"] = 
		{
			["SAM elements"] = true,
			["Vehicles"] = true,
			[27] = true,
			[2] = true,
			["SAM related"] = true,
			["SAM SR"] = true,
			[31] = true,
			["Ground vehicles"] = true,
			["SR SAM"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Air Defence"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [18]
	[19] = 
	{
		["type"] = "M1097 Avenger",
		["name"] = "SAM Avenger M1097",
		["category"] = "Air Defence",
		["description"] = "SAM Avenger M1097",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["AA_flak"] = true,
			[33] = true,
			["SAM related"] = true,
			["AA_missile"] = true,
			["IR Guided SAM"] = true,
			["SAM"] = true,
			["NonArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["Air Defence"] = true,
			["Ground Units"] = true,
			["SR SAM"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			[104] = true,
			["Armed Air Defence"] = true,
			["Datalink"] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [19]
	[20] = 
	{
		["type"] = "M48 Chaparral",
		["name"] = "SAM Chaparral M48",
		["category"] = "Air Defence",
		["description"] = "SAM Chaparral M48",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			[16] = true,
			["SAM related"] = true,
			["AA_missile"] = true,
			["IR Guided SAM"] = true,
			["SAM"] = true,
			["NonArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["Air Defence"] = true,
			["Ground Units"] = true,
			["SR SAM"] = true,
			["NonAndLightArmoredUnits"] = true,
			[50] = true,
			[27] = true,
			["Armed Air Defence"] = true,
			["Datalink"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [20]
	[21] = 
	{
		["type"] = "Hawk cwar",
		["name"] = "SAM Hawk CWAR AN/MPQ-55",
		["category"] = "Air Defence",
		["description"] = "SAM Hawk CWAR AN/MPQ-55",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["SAM SR"] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			[42] = true,
			["MR SAM"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM related"] = true,
			["Ground Units"] = true,
			["All"] = true,
			["Datalink"] = true,
			[101] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [21]
	[22] = 
	{
		["type"] = "Hawk ln",
		["name"] = "SAM Hawk LN M192",
		["category"] = "Air Defence",
		["description"] = "SAM Hawk LN M192",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["Ground vehicles"] = true,
			["AA_missile"] = true,
			[41] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["Armed Air Defence"] = true,
			["SAM related"] = true,
			["NonAndLightArmoredUnits"] = true,
			[27] = true,
			["SAM LL"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "Hawk M192 LN",
		}, -- end of ["aliases"]
	}, -- end of [22]
	[23] = 
	{
		["type"] = "Hawk pcp",
		["name"] = "SAM Hawk PCP",
		["category"] = "Air Defence",
		["description"] = "SAM Hawk PCP",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[2] = true,
			["SAM related"] = true,
			[16] = true,
			["Ground vehicles"] = true,
			["Air Defence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			[6] = true,
			["All"] = true,
			["Ground Units"] = true,
			["SAM CC"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [23]
	[24] = 
	{
		["type"] = "Hawk sr",
		["name"] = "SAM Hawk SR AN/MPQ-50",
		["category"] = "Air Defence",
		["description"] = "SAM Hawk SR AN/MPQ-50",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["SAM SR"] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			["MR SAM"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["SAM related"] = true,
			["NonAndLightArmoredUnits"] = true,
			[39] = true,
			["Ground Units"] = true,
			["All"] = true,
			["Datalink"] = true,
			[101] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "Hawk AN/MPQ-50 SR",
		}, -- end of ["aliases"]
	}, -- end of [24]
	[25] = 
	{
		["type"] = "Hawk tr",
		["name"] = "SAM Hawk TR AN/MPQ-46",
		["category"] = "Air Defence",
		["description"] = "SAM Hawk TR AN/MPQ-46",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			[40] = true,
			["MR SAM"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM related"] = true,
			["SAM TR"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[101] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "Hawk AN/MPQ-46 TR",
		}, -- end of ["aliases"]
	}, -- end of [25]
	[26] = 
	{
		["type"] = "M6 Linebacker",
		["name"] = "SAM Linebacker M6",
		["category"] = "Air Defence",
		["description"] = "SAM Linebacker M6",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["AA_flak"] = true,
			["SAM related"] = true,
			["AA_missile"] = true,
			["IR Guided SAM"] = true,
			["SAM"] = true,
			["NonArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["Ground Units"] = true,
			["Air Defence"] = true,
			[51] = true,
			["SR SAM"] = true,
			[104] = true,
			["All"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["Datalink"] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [26]
	[27] = 
	{
		["type"] = "Patriot AMG",
		["name"] = "SAM Patriot AMG AN/MRC-137",
		["category"] = "Air Defence",
		["description"] = "SAM Patriot AMG AN/MRC-137",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[17] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			[36] = true,
			["SAM CC"] = true,
			["Ground Units Non Airdefence"] = true,
			["NonArmoredUnits"] = true,
			[25] = true,
			["Air Defence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM related"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Unarmed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [27]
	[28] = 
	{
		["type"] = "Patriot ECS",
		["name"] = "SAM Patriot ECS AN/MSQ-104",
		["category"] = "Air Defence",
		["description"] = "SAM Patriot ECS AN/MSQ-104",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			[36] = true,
			["SAM CC"] = true,
			["Ground Units Non Airdefence"] = true,
			["NonArmoredUnits"] = true,
			[25] = true,
			["Air Defence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM related"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Unarmed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [28]
	[29] = 
	{
		["type"] = "Patriot EPP",
		["name"] = "SAM Patriot EPP-III",
		["category"] = "Air Defence",
		["description"] = "SAM Patriot EPP-III",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[17] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			[36] = true,
			["SAM CC"] = true,
			["Ground Units Non Airdefence"] = true,
			["NonArmoredUnits"] = true,
			[25] = true,
			["Air Defence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM related"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Unarmed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [29]
	[30] = 
	{
		["type"] = "Patriot cp",
		["name"] = "SAM Patriot ICC",
		["category"] = "Air Defence",
		["description"] = "SAM Patriot ICC",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[17] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			[36] = true,
			["SAM CC"] = true,
			["Ground Units Non Airdefence"] = true,
			["NonArmoredUnits"] = true,
			[25] = true,
			["Air Defence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM related"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Unarmed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [30]
	[31] = 
	{
		["type"] = "Patriot ln",
		["name"] = "SAM Patriot LN M901",
		["category"] = "Air Defence",
		["description"] = "SAM Patriot LN M901",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["Ground vehicles"] = true,
			["AA_missile"] = true,
			["NonArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["Air Defence"] = true,
			["SAM related"] = true,
			[37] = true,
			[27] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM LL"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [31]
	[32] = 
	{
		["type"] = "Patriot str",
		["name"] = "SAM Patriot STR AN/MPQ-53",
		["category"] = "Air Defence",
		["description"] = "SAM Patriot STR AN/MPQ-53",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["SAM SR"] = true,
			[34] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["LR SAM"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["SAM related"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM TR"] = true,
			[101] = true,
			["All"] = true,
			["Datalink"] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [32]
	[33] = 
	{
		["type"] = "Roland ADS",
		["name"] = "SAM Roland ADS",
		["category"] = "Air Defence",
		["description"] = "SAM Roland ADS",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			[31] = true,
			[16] = true,
			["SAM SR"] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["AA_missile"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			["NonArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["SAM elements"] = true,
			["Air Defence"] = true,
			["SAM related"] = true,
			[102] = true,
			["SAM LL"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM TR"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["SR SAM"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [33]
	[34] = 
	{
		["type"] = "Roland Radar",
		["name"] = "SAM Roland EWR",
		["category"] = "Air Defence",
		["description"] = "SAM Roland EWR",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Air Defence"] = true,
			["SAM related"] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[2] = true,
			["NonArmoredUnits"] = true,
			["SAM SR"] = true,
			[101] = true,
			[32] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [34]
	[35] = 
	{
		["type"] = "S-300PS 54K6 cp",
		["name"] = "SAM SA-10 S-300PS CP 54K6",
		["category"] = "Air Defence",
		["description"] = "SAM SA-10 S-300PS CP 54K6",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[2] = true,
			["SAM related"] = true,
			["CustomAimPoint"] = true,
			[16] = true,
			["Ground vehicles"] = true,
			["Air Defence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			[6] = true,
			["All"] = true,
			["Ground Units"] = true,
			["SAM CC"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [35]
	[36] = 
	{
		["type"] = "S-300PS 5P85C ln",
		["name"] = "SAM SA-10 S-300PS LN 5P85C",
		["category"] = "Air Defence",
		["description"] = "SAM SA-10 S-300PS LN 5P85C",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Armed Air Defence"] = true,
			["SAM elements"] = true,
			["Vehicles"] = true,
			[27] = true,
			[2] = true,
			["SAM related"] = true,
			[8] = true,
			[16] = true,
			["Ground vehicles"] = true,
			["Air Defence"] = true,
			["AA_missile"] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["SAM LL"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [36]
	[37] = 
	{
		["type"] = "S-300PS 5P85D ln",
		["name"] = "SAM SA-10 S-300PS LN 5P85D",
		["category"] = "Air Defence",
		["description"] = "SAM SA-10 S-300PS LN 5P85D",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Armed Air Defence"] = true,
			["SAM elements"] = true,
			["Vehicles"] = true,
			[27] = true,
			[2] = true,
			["SAM related"] = true,
			["Air Defence"] = true,
			[16] = true,
			[9] = true,
			["NonArmoredUnits"] = true,
			["SAM LL"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["AA_missile"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [37]
	[38] = 
	{
		["type"] = "S-300PS 40B6MD sr",
		["name"] = "SAM SA-10 S-300PS SR 5N66M",
		["category"] = "Air Defence",
		["description"] = "SAM SA-10 S-300PS SR 5N66M",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["CustomAimPoint"] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			[5] = true,
			["LR SAM"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM related"] = true,
			["SAM SR"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[101] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [38]
	[39] = 
	{
		["type"] = "S-300PS 64H6E sr",
		["name"] = "SAM SA-10 S-300PS SR 64H6E",
		["category"] = "Air Defence",
		["description"] = "SAM SA-10 S-300PS SR 64H6E",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["CustomAimPoint"] = true,
			["Ground vehicles"] = true,
			[101] = true,
			["LR SAM"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["SAM related"] = true,
			["NonAndLightArmoredUnits"] = true,
			[7] = true,
			["SAM SR"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [39]
	[40] = 
	{
		["type"] = "S-300PS 40B6M tr",
		["name"] = "SAM SA-10 S-300PS TR 30N6",
		["category"] = "Air Defence",
		["description"] = "SAM SA-10 S-300PS TR 30N6",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			[4] = true,
			["SAM elements"] = true,
			[16] = true,
			["CustomAimPoint"] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["LR SAM"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["SAM TR"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Vehicles"] = true,
			["SAM related"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[101] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [40]
	[41] = 
	{
		["type"] = "SA-11 Buk CC 9S470M1",
		["name"] = "SAM SA-11 Buk CC 9S470M1",
		["category"] = "Air Defence",
		["description"] = "SAM SA-11 Buk CC 9S470M1",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[2] = true,
			["SAM related"] = true,
			[16] = true,
			[17] = true,
			["Air Defence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["SAM CC"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [41]
	[42] = 
	{
		["type"] = "SA-11 Buk LN 9A310M1",
		["name"] = "SAM SA-11 Buk LN 9A310M1",
		["category"] = "Air Defence",
		["description"] = "SAM SA-11 Buk LN 9A310M1",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["AA_missile"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			["MR SAM"] = true,
			["NonArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["Air Defence"] = true,
			["SAM related"] = true,
			[102] = true,
			["SAM LL"] = true,
			["SAM TR"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[19] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [42]
	[43] = 
	{
		["type"] = "SA-11 Buk SR 9S18M1",
		["name"] = "SAM SA-11 Buk SR 9S18M1",
		["category"] = "Air Defence",
		["description"] = "SAM SA-11 Buk SR 9S18M1",
		["vehicle"] = true,
		["attribute"] = 
		{
			["SAM elements"] = true,
			["SAM related"] = true,
			["Vehicles"] = true,
			["MR SAM"] = true,
			[2] = true,
			["Air Defence"] = true,
			["SAM SR"] = true,
			[101] = true,
			["Ground vehicles"] = true,
			[18] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [43]
	[44] = 
	{
		["type"] = "Strela-10M3",
		["name"] = "SAM SA-13 Strela-10M3 9A35M3",
		["category"] = "Air Defence",
		["description"] = "SAM SA-13 Strela-10M3 9A35M3",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["SAM related"] = true,
			["AA_missile"] = true,
			["IR Guided SAM"] = true,
			["SAM"] = true,
			["NonArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["Air Defence"] = true,
			[26] = true,
			["SR SAM"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM TR"] = true,
			[104] = true,
			["Armed Air Defence"] = true,
			["Ground Units"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "SA-13 Strela-10M3 9A35M3",
		}, -- end of ["aliases"]
	}, -- end of [44]
	[45] = 
	{
		["type"] = "Tor 9A331",
		["name"] = "SAM SA-15 Tor 9A331",
		["category"] = "Air Defence",
		["description"] = "SAM SA-15 Tor 9A331",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["SAM SR"] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["AA_missile"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["SAM related"] = true,
			[102] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM TR"] = true,
			[28] = true,
			["All"] = true,
			["Ground Units"] = true,
			["SR SAM"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [45]
	[46] = 
	{
		["description"] = "SAM SA-18 Igla comm",
		["type"] = "SA-18 Igla comm",
		["name"] = "SAM SA-18 Igla comm",
		["category"] = "Air Defence",
		["infantry"] = true,
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["CustomAimPoint"] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["MANPADS AUX"] = true,
			["Infantry"] = true,
			["NonArmoredUnits"] = true,
			["SAM AUX"] = true,
			["Air Defence"] = true,
			["SAM related"] = true,
			["Ground Units Non Airdefence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Rocket Attack Valid AirDefence"] = true,
			[55] = true,
			["All"] = true,
			["Ground Units"] = true,
			[27] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [46]
	[47] = 
	{
		["infantry"] = true,
		["type"] = "SA-18 Igla manpad",
		["name"] = "SAM SA-18 Igla MANPADS",
		["category"] = "Air Defence",
		["description"] = "SAM SA-18 Igla MANPADS",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			[16] = true,
			["SAM related"] = true,
			["New infantry"] = true,
			["Armed ground units"] = true,
			["MANPADS"] = true,
			["IR Guided SAM"] = true,
			["SAM"] = true,
			["NonArmoredUnits"] = true,
			["Rocket Attack Valid AirDefence"] = true,
			["Infantry"] = true,
			["Air Defence"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			[54] = true,
			[27] = true,
			["Armed Air Defence"] = true,
			["Ground Units"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [47]
	[48] = 
	{
		["infantry"] = true,
		["type"] = "Igla manpad INS",
		["name"] = "SAM SA-18 Igla MANPADS",
		["category"] = "Air Defence",
		["description"] = "SAM SA-18 Igla MANPADS",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			[62] = true,
			["SAM related"] = true,
			["New infantry"] = true,
			["Armed ground units"] = true,
			["MANPADS"] = true,
			["IR Guided SAM"] = true,
			["SAM"] = true,
			["NonArmoredUnits"] = true,
			["Rocket Attack Valid AirDefence"] = true,
			["Infantry"] = true,
			["Air Defence"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			[27] = true,
			["Armed Air Defence"] = true,
			["Ground Units"] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [48]
	[49] = 
	{
		["description"] = "SAM SA-18 Igla-S comm",
		["type"] = "SA-18 Igla-S comm",
		["name"] = "SAM SA-18 Igla-S comm",
		["category"] = "Air Defence",
		["infantry"] = true,
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["CustomAimPoint"] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["MANPADS AUX"] = true,
			["Infantry"] = true,
			["NonArmoredUnits"] = true,
			["SAM AUX"] = true,
			["Air Defence"] = true,
			["SAM related"] = true,
			["Ground Units Non Airdefence"] = true,
			[53] = true,
			["Rocket Attack Valid AirDefence"] = true,
			[27] = true,
			["All"] = true,
			["Ground Units"] = true,
			["NonAndLightArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [49]
	[50] = 
	{
		["infantry"] = true,
		["type"] = "SA-18 Igla-S manpad",
		["name"] = "SAM SA-18 Igla-S MANPADS",
		["category"] = "Air Defence",
		["description"] = "SAM SA-18 Igla-S MANPADS",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			[16] = true,
			["SAM related"] = true,
			["New infantry"] = true,
			["Armed ground units"] = true,
			["MANPADS"] = true,
			["IR Guided SAM"] = true,
			["SAM"] = true,
			["NonArmoredUnits"] = true,
			["Rocket Attack Valid AirDefence"] = true,
			["Infantry"] = true,
			["Air Defence"] = true,
			["Ground Units Non Airdefence"] = true,
			[52] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Armed Air Defence"] = true,
			["Ground Units"] = true,
			[27] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [50]
	[51] = 
	{
		["type"] = "2S6 Tunguska",
		["name"] = "SAM SA-19 Tunguska 2S6",
		["category"] = "Air Defence",
		["description"] = "SAM SA-19 Tunguska 2S6",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Rocket Attack Valid AirDefence"] = true,
			["SAM elements"] = true,
			[16] = true,
			["SAM SR"] = true,
			["AAA"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["AA_missile"] = true,
			["Mobile AAA"] = true,
			["SAM related"] = true,
			["Ground vehicles"] = true,
			["NonArmoredUnits"] = true,
			["Vehicles"] = true,
			["Ground Units"] = true,
			["Air Defence"] = true,
			["All"] = true,
			["SR SAM"] = true,
			["NonAndLightArmoredUnits"] = true,
			[103] = true,
			["SAM TR"] = true,
			["Armed Air Defence"] = true,
			[29] = true,
			["AA_flak"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "SA-19 Tunguska 2S6",
		}, -- end of ["aliases"]
	}, -- end of [51]
	[52] = 
	{
		["type"] = "S_75M_Volhov",
		["name"] = "SAM SA-2 LN SM-90",
		["category"] = "Air Defence",
		["description"] = "SAM SA-2 LN SM-90",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["Ground vehicles"] = true,
			["AA_missile"] = true,
			[74] = true,
			["LR SAM"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["Armed Air Defence"] = true,
			["NonAndLightArmoredUnits"] = true,
			[27] = true,
			["SAM related"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["SAM LL"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [52]
	[53] = 
	{
		["type"] = "SNR_75V",
		["name"] = "SAM SA-2 TR SNR-75 Fan Song",
		["category"] = "Air Defence",
		["description"] = "SAM SA-2 TR SNR-75 Fan Song",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			[256] = true,
			[101] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			["MR SAM"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["SAM related"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM TR"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [53]
	[54] = 
	{
		["type"] = "5p73 s-125 ln",
		["name"] = "SAM SA-3 S-125 LN 5P73",
		["category"] = "Air Defence",
		["description"] = "SAM SA-3 S-125 LN 5P73",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["Ground vehicles"] = true,
			["AA_missile"] = true,
			[74] = true,
			["MR SAM"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["Armed Air Defence"] = true,
			[27] = true,
			["SAM related"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["SAM LL"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [54]
	[55] = 
	{
		["type"] = "snr s-125 tr",
		["name"] = "SAM SA-3 S-125 TR SNR",
		["category"] = "Air Defence",
		["description"] = "SAM SA-3 S-125 TR SNR",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			["MR SAM"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			[73] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM TR"] = true,
			["SAM related"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[101] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [55]
	[56] = 
	{
		["type"] = "Kub 2P25 ln",
		["name"] = "SAM SA-6 Kub LN 2P25",
		["category"] = "Air Defence",
		["description"] = "SAM SA-6 Kub LN 2P25",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Armed Air Defence"] = true,
			["SAM elements"] = true,
			["Vehicles"] = true,
			[27] = true,
			[2] = true,
			["SAM related"] = true,
			["Air Defence"] = true,
			[16] = true,
			["Ground vehicles"] = true,
			["NonArmoredUnits"] = true,
			["SAM LL"] = true,
			["NonAndLightArmoredUnits"] = true,
			["AA_missile"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[22] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "SA-6 Kub LN 2P25",
		}, -- end of ["aliases"]
	}, -- end of [56]
	[57] = 
	{
		["type"] = "Kub 1S91 str",
		["name"] = "SAM SA-6 Kub STR 9S91",
		["category"] = "Air Defence",
		["description"] = "SAM SA-6 Kub STR 9S91",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["SAM SR"] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			[21] = true,
			["MR SAM"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM related"] = true,
			["SAM TR"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[101] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "SA-6 Kub STR 9S91",
		}, -- end of ["aliases"]
	}, -- end of [57]
	[58] = 
	{
		["type"] = "Osa 9A33 ln",
		["name"] = "SAM SA-8 Osa 9A33",
		["category"] = "Air Defence",
		["description"] = "SAM SA-8 Osa 9A33",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["SAM SR"] = true,
			["Ground vehicles"] = true,
			["AA_missile"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			[23] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			[102] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM related"] = true,
			["SAM TR"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["SR SAM"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [58]
	[59] = 
	{
		["type"] = "SA-8 Osa LD 9T217",
		["name"] = "SAM SA-8 Osa LD 9T217",
		["category"] = "Air Defence",
		["description"] = "SAM SA-8 Osa LD 9T217",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[17] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			["SAM AUX"] = true,
			["Ground Units Non Airdefence"] = true,
			["NonArmoredUnits"] = true,
			[25] = true,
			["Air Defence"] = true,
			["NonAndLightArmoredUnits"] = true,
			[24] = true,
			["SAM related"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Unarmed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [59]
	[60] = 
	{
		["type"] = "Strela-1 9P31",
		["name"] = "SAM SA-9 Strela-1 9P31",
		["category"] = "Air Defence",
		["description"] = "SAM SA-9 Strela-1 9P31",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			[16] = true,
			["SAM related"] = true,
			["AA_missile"] = true,
			["IR Guided SAM"] = true,
			["SAM"] = true,
			["NonArmoredUnits"] = true,
			[25] = true,
			["Air Defence"] = true,
			["SR SAM"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			[27] = true,
			["Armed Air Defence"] = true,
			["Ground Units"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "SA-9 Strela-1 9P31",
		}, -- end of ["aliases"]
	}, -- end of [60]
	[61] = 
	{
		["type"] = "p-19 s-125 sr",
		["name"] = "SAM SR P-19",
		["category"] = "Air Defence",
		["description"] = "SAM SR P-19",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["SAM SR"] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			["MR SAM"] = true,
			["NonArmoredUnits"] = true,
			["Air Defence"] = true,
			["NonAndLightArmoredUnits"] = true,
			[75] = true,
			["SAM related"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[101] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [61]
	[62] = 
	{
		["description"] = "SAM Stinger comm",
		["type"] = "Stinger comm",
		["name"] = "SAM Stinger comm",
		["category"] = "Air Defence",
		["infantry"] = true,
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["CustomAimPoint"] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["MANPADS AUX"] = true,
			["Infantry"] = true,
			["NonArmoredUnits"] = true,
			["SAM AUX"] = true,
			["Air Defence"] = true,
			["SAM related"] = true,
			["Ground Units Non Airdefence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Rocket Attack Valid AirDefence"] = true,
			[27] = true,
			["All"] = true,
			[57] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [62]
	[63] = 
	{
		["description"] = "SAM Stinger comm dsr",
		["type"] = "Stinger comm dsr",
		["name"] = "SAM Stinger comm dsr",
		["category"] = "Air Defence",
		["infantry"] = true,
		["vehicle"] = true,
		["attribute"] = 
		{
			[59] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			[16] = true,
			["CustomAimPoint"] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["MANPADS AUX"] = true,
			["Infantry"] = true,
			["NonArmoredUnits"] = true,
			["SAM AUX"] = true,
			["Air Defence"] = true,
			["SAM related"] = true,
			["Ground Units Non Airdefence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Rocket Attack Valid AirDefence"] = true,
			[27] = true,
			["All"] = true,
			["Ground Units"] = true,
			[2] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [63]
	[64] = 
	{
		["type"] = "Gepard",
		["name"] = "SPAAA Gepard",
		["category"] = "Air Defence",
		["description"] = "SPAAA Gepard",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Rocket Attack Valid AirDefence"] = true,
			["SAM elements"] = true,
			[16] = true,
			["SAM SR"] = true,
			["AAA"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			[38] = true,
			["Mobile AAA"] = true,
			["NonArmoredUnits"] = true,
			["SAM related"] = true,
			["Ground vehicles"] = true,
			["Air Defence"] = true,
			["Vehicles"] = true,
			["AA_flak"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["SAM TR"] = true,
			["Armed Air Defence"] = true,
			["Ground Units"] = true,
			[105] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [64]
	[65] = 
	{
		["type"] = "ZSU-23-4 Shilka",
		["name"] = "SPAAA ZSU-23-4 Shilka",
		["category"] = "Air Defence",
		["description"] = "SPAAA ZSU-23-4 Shilka",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Rocket Attack Valid AirDefence"] = true,
			["SAM elements"] = true,
			[16] = true,
			["AAA"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			[105] = true,
			["Mobile AAA"] = true,
			["NonArmoredUnits"] = true,
			["SAM related"] = true,
			["Ground vehicles"] = true,
			["Air Defence"] = true,
			["Vehicles"] = true,
			["AA_flak"] = true,
			["NonAndLightArmoredUnits"] = true,
			["SAM TR"] = true,
			["All"] = true,
			["Armed Air Defence"] = true,
			["Ground Units"] = true,
			[30] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [65]
	[66] = 
	{
		["infantry"] = true,
		["type"] = "Soldier stinger",
		["name"] = "Stinger MANPADS",
		["category"] = "Air Defence",
		["description"] = "Stinger MANPADS",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			[16] = true,
			["SAM related"] = true,
			["New infantry"] = true,
			["Armed ground units"] = true,
			["MANPADS"] = true,
			["IR Guided SAM"] = true,
			["SAM"] = true,
			["NonArmoredUnits"] = true,
			["Rocket Attack Valid AirDefence"] = true,
			["Infantry"] = true,
			["Air Defence"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			[56] = true,
			[27] = true,
			["Armed Air Defence"] = true,
			["Ground Units"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [66]
	[67] = 
	{
		["type"] = "AAV7",
		["name"] = "APC AAV-7",
		["category"] = "Armor",
		["description"] = "APC AAV-7",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			[10] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			[26] = true,
			["NonAndLightArmoredUnits"] = true,
			["LightArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Armed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [67]
	[68] = 
	{
		["type"] = "BTR-80",
		["name"] = "APC BTR-80",
		["category"] = "Armor",
		["description"] = "APC BTR-80",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			[10] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			[26] = true,
			["NonAndLightArmoredUnits"] = true,
			["LightArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Armed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [68]
	[69] = 
	{
		["type"] = "BTR-82A",
		["name"] = "APC BTR-82A",
		["category"] = "Armor",
		["description"] = "APC BTR-82A",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			[258] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			[26] = true,
			["NonAndLightArmoredUnits"] = true,
			["LightArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Armed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [69]
	[70] = 
	{
		["type"] = "Cobra",
		["name"] = "APC Cobra",
		["category"] = "Armor",
		["description"] = "APC Cobra",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			[10] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			[26] = true,
			["NonAndLightArmoredUnits"] = true,
			["LightArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Armed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [70]
	[71] = 
	{
		["type"] = "M1043 HMMWV Armament",
		["name"] = "APC M1043 HMMWV Armament",
		["category"] = "Armor",
		["description"] = "APC M1043 HMMWV Armament",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			[26] = true,
			["LightArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			[14] = true,
			["Armed vehicles"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [71]
	[72] = 
	{
		["type"] = "M1126 Stryker ICV",
		["name"] = "APC M1126 Stryker ICV",
		["category"] = "Armor",
		["description"] = "APC M1126 Stryker ICV",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			[80] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			[26] = true,
			["NonAndLightArmoredUnits"] = true,
			["LightArmoredUnits"] = true,
			["Armed vehicles"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [72]
	[73] = 
	{
		["type"] = "M-113",
		["name"] = "APC M113",
		["category"] = "Armor",
		["description"] = "APC M113",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			[10] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			[26] = true,
			["NonAndLightArmoredUnits"] = true,
			["LightArmoredUnits"] = true,
			["Armed vehicles"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [73]
	[74] = 
	{
		["type"] = "M2A1_halftrack",
		["name"] = "APC M2A1",
		["category"] = "Armor",
		["description"] = "APC M2A1",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			[10] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			[26] = true,
			["NonAndLightArmoredUnits"] = true,
			["LightArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Armed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [74]
	[75] = 
	{
		["type"] = "MTLB",
		["name"] = "APC MTLB",
		["category"] = "Armor",
		["description"] = "APC MTLB",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			[10] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			[26] = true,
			["NonAndLightArmoredUnits"] = true,
			["LightArmoredUnits"] = true,
			["Armed vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["CustomAimPoint"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [75]
	[76] = 
	{
		["type"] = "Sd_Kfz_251",
		["name"] = "APC Sd.Kfz.251",
		["category"] = "Armor",
		["description"] = "APC Sd.Kfz.251",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			[10] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			[26] = true,
			["NonAndLightArmoredUnits"] = true,
			["LightArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Armed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [76]
	[77] = 
	{
		["type"] = "BRDM-2",
		["name"] = "ARV BRDM-2",
		["category"] = "Armor",
		["description"] = "ARV BRDM-2",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			[10] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			[26] = true,
			["NonAndLightArmoredUnits"] = true,
			["LightArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Armed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [77]
	[78] = 
	{
		["type"] = "BTR_D",
		["name"] = "ARV BTR-RD",
		["category"] = "Armor",
		["description"] = "ARV BTR-RD",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			[10] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			["LightArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["ATGM"] = true,
			["Armed vehicles"] = true,
			[104] = true,
			["All"] = true,
			["Ground Units"] = true,
			["CustomAimPoint"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [78]
	[79] = 
	{
		["type"] = "M1045 HMMWV TOW",
		["name"] = "ATGM M1045 HMMWV TOW",
		["category"] = "Armor",
		["description"] = "ATGM M1045 HMMWV TOW",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			["LightArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Armed vehicles"] = true,
			["ATGM"] = true,
			[14] = true,
			[104] = true,
			["All"] = true,
			["Datalink"] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [79]
	[80] = 
	{
		["type"] = "M1134 Stryker ATGM",
		["name"] = "ATGM M1134 Stryker",
		["category"] = "Armor",
		["description"] = "ATGM M1134 Stryker",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			[80] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			["LightArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Armed vehicles"] = true,
			[104] = true,
			["IFV"] = true,
			["Ground Units"] = true,
			["All"] = true,
			["Datalink"] = true,
			["ATGM"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [80]
	[81] = 
	{
		["type"] = "Grad_FDDM",
		["name"] = "FDDM Grad",
		["category"] = "Armor",
		["description"] = "FDDM Grad",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			[10] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			[26] = true,
			["NonAndLightArmoredUnits"] = true,
			["LightArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Armed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "Boman",
		}, -- end of ["aliases"]
	}, -- end of [81]
	[82] = 
	{
		["type"] = "BMD-1",
		["name"] = "IFV BMD-1",
		["category"] = "Armor",
		["description"] = "IFV BMD-1",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			["LightArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			[7] = true,
			[104] = true,
			["Armed vehicles"] = true,
			["IFV"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["ATGM"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [82]
	[83] = 
	{
		["type"] = "BMP-1",
		["name"] = "IFV BMP-1",
		["category"] = "Armor",
		["description"] = "IFV BMP-1",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			["LightArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			[7] = true,
			[104] = true,
			["Armed vehicles"] = true,
			["IFV"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["ATGM"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [83]
	[84] = 
	{
		["type"] = "BMP-2",
		["name"] = "IFV BMP-2",
		["category"] = "Armor",
		["description"] = "IFV BMP-2",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			["LightArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			[7] = true,
			[104] = true,
			["Armed vehicles"] = true,
			["IFV"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["ATGM"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [84]
	[85] = 
	{
		["type"] = "BMP-3",
		["name"] = "IFV BMP-3",
		["category"] = "Armor",
		["description"] = "IFV BMP-3",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			["LightArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			[7] = true,
			[104] = true,
			["Armed vehicles"] = true,
			["IFV"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["ATGM"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [85]
	[86] = 
	{
		["type"] = "LAV-25",
		["name"] = "IFV LAV-25",
		["category"] = "Armor",
		["description"] = "IFV LAV-25",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			[26] = true,
			["NonAndLightArmoredUnits"] = true,
			["LightArmoredUnits"] = true,
			[7] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Armed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [86]
	[87] = 
	{
		["type"] = "M-2 Bradley",
		["name"] = "IFV M2A2 Bradley",
		["category"] = "Armor",
		["description"] = "IFV M2A2 Bradley",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["Ground Units Non Airdefence"] = true,
			["IFV"] = true,
			["LightArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Armed vehicles"] = true,
			[7] = true,
			[104] = true,
			["Infantry carriers"] = true,
			["Ground Units"] = true,
			["All"] = true,
			["Datalink"] = true,
			["ATGM"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "M2A2 Bradley",
		}, -- end of ["aliases"]
	}, -- end of [87]
	[88] = 
	{
		["type"] = "Marder",
		["name"] = "IFV Marder",
		["category"] = "Armor",
		["description"] = "IFV Marder",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			["LightArmoredUnits"] = true,
			[26] = true,
			["NonAndLightArmoredUnits"] = true,
			["ATGM"] = true,
			[7] = true,
			["Armed vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["IFV"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [88]
	[89] = 
	{
		["type"] = "MCV-80",
		["name"] = "IFV MCV-80",
		["category"] = "Armor",
		["description"] = "IFV MCV-80",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			[10] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			[26] = true,
			["NonAndLightArmoredUnits"] = true,
			["LightArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Armed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [89]
	[90] = 
	{
		["type"] = "Challenger2",
		["name"] = "MBT Challenger II",
		["category"] = "Armor",
		["description"] = "MBT Challenger II",
		["vehicle"] = true,
		["attribute"] = 
		{
			["HeavyArmoredUnits"] = true,
			["Tanks"] = true,
			[26] = true,
			["AntiAir Armed Vehicles"] = true,
			[2] = true,
			["Modern Tanks"] = true,
			["Armed vehicles"] = true,
			[16] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Vehicles"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Armored vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [90]
	[91] = 
	{
		["type"] = "Leclerc",
		["name"] = "MBT Leclerc",
		["category"] = "Armor",
		["description"] = "MBT Leclerc",
		["vehicle"] = true,
		["attribute"] = 
		{
			["HeavyArmoredUnits"] = true,
			["Tanks"] = true,
			[26] = true,
			["AntiAir Armed Vehicles"] = true,
			[2] = true,
			["Modern Tanks"] = true,
			["Armed vehicles"] = true,
			[16] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Vehicles"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Armored vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [91]
	[92] = 
	{
		["type"] = "Leopard1A3",
		["name"] = "MBT Leopard 1A3",
		["category"] = "Armor",
		["description"] = "MBT Leopard 1A3",
		["vehicle"] = true,
		["attribute"] = 
		{
			["HeavyArmoredUnits"] = true,
			["Tanks"] = true,
			[26] = true,
			["Armed vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			["Ground vehicles"] = true,
			["Old Tanks"] = true,
			[17] = true,
			["Vehicles"] = true,
			[2] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "LEO1A3",
		}, -- end of ["aliases"]
	}, -- end of [92]
	[93] = 
	{
		["type"] = "Leopard-2",
		["name"] = "MBT Leopard-2",
		["category"] = "Armor",
		["description"] = "MBT Leopard-2",
		["vehicle"] = true,
		["attribute"] = 
		{
			["HeavyArmoredUnits"] = true,
			["Tanks"] = true,
			[26] = true,
			["AntiAir Armed Vehicles"] = true,
			[2] = true,
			["Modern Tanks"] = true,
			["Armed vehicles"] = true,
			[16] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Vehicles"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Armored vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [93]
	[94] = 
	{
		["type"] = "M-1 Abrams",
		["name"] = "MBT M1A2 Abrams",
		["category"] = "Armor",
		["description"] = "MBT M1A2 Abrams",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["Modern Tanks"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["Ground Units Non Airdefence"] = true,
			[16] = true,
			[26] = true,
			["AntiAir Armed Vehicles"] = true,
			["Tanks"] = true,
			["Armed vehicles"] = true,
			["HeavyArmoredUnits"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [94]
	[95] = 
	{
		["type"] = "M-60",
		["name"] = "MBT M60A3 Patton",
		["category"] = "Armor",
		["description"] = "MBT M60A3 Patton",
		["vehicle"] = true,
		["attribute"] = 
		{
			["HeavyArmoredUnits"] = true,
			["Tanks"] = true,
			[26] = true,
			["Armed vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			["Ground vehicles"] = true,
			["Old Tanks"] = true,
			[17] = true,
			["Vehicles"] = true,
			[2] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [95]
	[96] = 
	{
		["type"] = "Merkava_Mk4",
		["name"] = "MBT Merkava Mk. 4",
		["category"] = "Armor",
		["description"] = "MBT Merkava Mk. 4",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["Modern Tanks"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["Ground Units Non Airdefence"] = true,
			[16] = true,
			[26] = true,
			["AntiAir Armed Vehicles"] = true,
			["Tanks"] = true,
			["Armed vehicles"] = true,
			["HeavyArmoredUnits"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [96]
	[97] = 
	{
		["type"] = "T-55",
		["name"] = "MBT T-55",
		["category"] = "Armor",
		["description"] = "MBT T-55",
		["vehicle"] = true,
		["attribute"] = 
		{
			["HeavyArmoredUnits"] = true,
			["Tanks"] = true,
			[26] = true,
			["Armed vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			["Ground vehicles"] = true,
			["Old Tanks"] = true,
			[17] = true,
			["Vehicles"] = true,
			[2] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [97]
	[98] = 
	{
		["type"] = "T-72B",
		["name"] = "MBT T-72B",
		["category"] = "Armor",
		["description"] = "MBT T-72B",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["Modern Tanks"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["Ground Units Non Airdefence"] = true,
			["CustomAimPoint"] = true,
			[26] = true,
			["AntiAir Armed Vehicles"] = true,
			["Tanks"] = true,
			["Armed vehicles"] = true,
			["HeavyArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [98]
	[99] = 
	{
		["type"] = "T-72B3",
		["name"] = "MBT T-72B3",
		["category"] = "Armor",
		["description"] = "MBT T-72B3",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["Modern Tanks"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["Ground Units Non Airdefence"] = true,
			["CustomAimPoint"] = true,
			[26] = true,
			["AntiAir Armed Vehicles"] = true,
			["Tanks"] = true,
			["Armed vehicles"] = true,
			["HeavyArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [99]
	[100] = 
	{
		["type"] = "T-80UD",
		["name"] = "MBT T-80U",
		["category"] = "Armor",
		["description"] = "MBT T-80U",
		["vehicle"] = true,
		["attribute"] = 
		{
			["HeavyArmoredUnits"] = true,
			["Tanks"] = true,
			[26] = true,
			["AntiAir Armed Vehicles"] = true,
			[2] = true,
			["Modern Tanks"] = true,
			["Armed vehicles"] = true,
			[16] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Vehicles"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Armored vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [100]
	[101] = 
	{
		["type"] = "T-90",
		["name"] = "MBT T-90",
		["category"] = "Armor",
		["description"] = "MBT T-90",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["Modern Tanks"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["Ground Units Non Airdefence"] = true,
			["CustomAimPoint"] = true,
			[26] = true,
			["AntiAir Armed Vehicles"] = true,
			["Tanks"] = true,
			["Armed vehicles"] = true,
			["HeavyArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [101]
	[102] = 
	{
		["type"] = "M4_Sherman",
		["name"] = "MT M4 Sherman",
		["category"] = "Armor",
		["description"] = "MT M4 Sherman",
		["vehicle"] = true,
		["attribute"] = 
		{
			["HeavyArmoredUnits"] = true,
			["Tanks"] = true,
			[26] = true,
			["Armed vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			["Ground vehicles"] = true,
			["Old Tanks"] = true,
			[17] = true,
			["Vehicles"] = true,
			[2] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [102]
	[103] = 
	{
		["type"] = "Pz_IV_H",
		["name"] = "MT Pz.Kpfw.IV Ausf.H",
		["category"] = "Armor",
		["description"] = "MT Pz.Kpfw.IV Ausf.H",
		["vehicle"] = true,
		["attribute"] = 
		{
			["HeavyArmoredUnits"] = true,
			["Tanks"] = true,
			[26] = true,
			["Armed vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			["Ground vehicles"] = true,
			["Old Tanks"] = true,
			[17] = true,
			["Vehicles"] = true,
			[2] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [103]
	[104] = 
	{
		["type"] = "M1128 Stryker MGS",
		["name"] = "SPG M1128 Stryker MGS",
		["category"] = "Armor",
		["description"] = "SPG M1128 Stryker MGS",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["Modern Tanks"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			[80] = true,
			["Ground Units Non Airdefence"] = true,
			["IFV"] = true,
			["Infantry carriers"] = true,
			["LightArmoredUnits"] = true,
			["Armed vehicles"] = true,
			[26] = true,
			["AntiAir Armed Vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Tanks"] = true,
			["HeavyArmoredUnits"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [104]
	[105] = 
	{
		["type"] = "TPZ",
		["name"] = "TPz Fuchs",
		["category"] = "Armor",
		["description"] = "TPz Fuchs",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			[10] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			[26] = true,
			["NonAndLightArmoredUnits"] = true,
			["LightArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Armed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [105]
	[106] = 
	{
		["type"] = "ZBD04A",
		["name"] = "ZBD-04A",
		["category"] = "Armor",
		["description"] = "ZBD-04A",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["Ground Units Non Airdefence"] = true,
			["IFV"] = true,
			["LightArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Armed vehicles"] = true,
			[7] = true,
			[104] = true,
			["Infantry carriers"] = true,
			["Ground Units"] = true,
			["All"] = true,
			["Datalink"] = true,
			["ATGM"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [106]
	[107] = 
	{
		["type"] = "ZTZ96B",
		["name"] = "ZTZ-96B",
		["category"] = "Armor",
		["description"] = "ZTZ-96B",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["Modern Tanks"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["Ground Units Non Airdefence"] = true,
			[16] = true,
			[26] = true,
			["AntiAir Armed Vehicles"] = true,
			["Tanks"] = true,
			["Armed vehicles"] = true,
			["HeavyArmoredUnits"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [107]
	[108] = 
	{
		["type"] = "2B11 mortar",
		["name"] = "2B11 mortar",
		["category"] = "Artillery",
		["description"] = "2B11 mortar",
		["vehicle"] = true,
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Artillery"] = true,
			["Ground Units Non Airdefence"] = true,
			[26] = true,
			["Armed vehicles"] = true,
			["LightArmoredUnits"] = true,
			[17] = true,
			["Indirect fire"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [108]
	[109] = 
	{
		["type"] = "Smerch",
		["name"] = "MLRS 9A52 Smerch",
		["category"] = "Artillery",
		["description"] = "MLRS 9A52 Smerch",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Artillery"] = true,
			[63] = true,
			["Vehicles"] = true,
			[27] = true,
			[2] = true,
			["LightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["Indirect fire"] = true,
			[17] = true,
			["Armed vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["MLRS"] = true,
			["Ground Units"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [109]
	[110] = 
	{
		["type"] = "Smerch_HE",
		["name"] = "MLRS 9A52 Smerch HE",
		["category"] = "Artillery",
		["description"] = "MLRS 9A52 Smerch HE",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Artillery"] = true,
			[63] = true,
			["Vehicles"] = true,
			[27] = true,
			[2] = true,
			["LightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["Indirect fire"] = true,
			[17] = true,
			["Armed vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["MLRS"] = true,
			["Ground Units"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [110]
	[111] = 
	{
		["type"] = "Uragan_BM-27",
		["name"] = "MLRS 9K57 Uragan BM-27",
		["category"] = "Artillery",
		["description"] = "MLRS 9K57 Uragan BM-27",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Artillery"] = true,
			[63] = true,
			["Vehicles"] = true,
			[27] = true,
			[2] = true,
			["LightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["Indirect fire"] = true,
			[17] = true,
			["Armed vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["MLRS"] = true,
			["Ground Units"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [111]
	[112] = 
	{
		["type"] = "Grad-URAL",
		["name"] = "MLRS BM-21 Grad",
		["category"] = "Artillery",
		["description"] = "MLRS BM-21 Grad",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Artillery"] = true,
			[63] = true,
			["Vehicles"] = true,
			[27] = true,
			[2] = true,
			["LightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["Indirect fire"] = true,
			[17] = true,
			["Armed vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["MLRS"] = true,
			["Ground Units"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "MLRS BM-21 Grad",
		}, -- end of ["aliases"]
	}, -- end of [112]
	[113] = 
	{
		["type"] = "MLRS FDDM",
		["name"] = "MLRS FDDM",
		["category"] = "Artillery",
		["description"] = "MLRS FDDM",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["Infantry carriers"] = true,
			[26] = true,
			["LightArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			[14] = true,
			["Armed vehicles"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [113]
	[114] = 
	{
		["type"] = "MLRS",
		["name"] = "MLRS M270",
		["category"] = "Artillery",
		["description"] = "MLRS M270",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armed vehicles"] = true,
			["LightArmoredUnits"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["Artillery"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground Units"] = true,
			[63] = true,
			["NonAndLightArmoredUnits"] = true,
			[27] = true,
			["Indirect fire"] = true,
			["All"] = true,
			["Datalink"] = true,
			["MLRS"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "M270 MLRS",
		}, -- end of ["aliases"]
	}, -- end of [114]
	[115] = 
	{
		["type"] = "SpGH_Dana",
		["name"] = "SpGH Dana",
		["category"] = "Artillery",
		["description"] = "SpGH Dana",
		["vehicle"] = true,
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Artillery"] = true,
			["Ground Units Non Airdefence"] = true,
			[26] = true,
			["Armed vehicles"] = true,
			["LightArmoredUnits"] = true,
			[17] = true,
			["Indirect fire"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [115]
	[116] = 
	{
		["type"] = "SAU Gvozdika",
		["name"] = "SPH 2S1 Gvozdika",
		["category"] = "Artillery",
		["description"] = "SPH 2S1 Gvozdika",
		["vehicle"] = true,
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Artillery"] = true,
			["Ground Units Non Airdefence"] = true,
			[26] = true,
			["Armed vehicles"] = true,
			["LightArmoredUnits"] = true,
			[17] = true,
			["Indirect fire"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [116]
	[117] = 
	{
		["type"] = "SAU Msta",
		["name"] = "SPH 2S19 Msta",
		["category"] = "Artillery",
		["description"] = "SPH 2S19 Msta",
		["vehicle"] = true,
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Artillery"] = true,
			["Ground Units Non Airdefence"] = true,
			[26] = true,
			["Armed vehicles"] = true,
			["LightArmoredUnits"] = true,
			[17] = true,
			["Indirect fire"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "2S19 Msta",
		}, -- end of ["aliases"]
	}, -- end of [117]
	[118] = 
	{
		["type"] = "SAU Akatsia",
		["name"] = "SPH 2S3 Akatsia",
		["category"] = "Artillery",
		["description"] = "SPH 2S3 Akatsia",
		["vehicle"] = true,
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Artillery"] = true,
			["Ground Units Non Airdefence"] = true,
			[26] = true,
			["Armed vehicles"] = true,
			["LightArmoredUnits"] = true,
			[17] = true,
			["Indirect fire"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "2S3 Akatsia",
		}, -- end of ["aliases"]
	}, -- end of [118]
	[119] = 
	{
		["type"] = "SAU 2-C9",
		["name"] = "SPH 2S9 Nona",
		["category"] = "Artillery",
		["description"] = "SPH 2S9 Nona",
		["vehicle"] = true,
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Artillery"] = true,
			["Ground Units Non Airdefence"] = true,
			[26] = true,
			["Armed vehicles"] = true,
			["LightArmoredUnits"] = true,
			[17] = true,
			["Indirect fire"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [119]
	[120] = 
	{
		["type"] = "M-109",
		["name"] = "SPH M109 Paladin",
		["category"] = "Artillery",
		["description"] = "SPH M109 Paladin",
		["vehicle"] = true,
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Artillery"] = true,
			["Ground Units Non Airdefence"] = true,
			[26] = true,
			["Armed vehicles"] = true,
			["LightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			[17] = true,
			["Indirect fire"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Vehicles"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "M109",
		}, -- end of ["aliases"]
	}, -- end of [120]
	[121] = 
	{
		["type"] = "ammo_cargo",
		["name"] = "Ammo",
		["category"] = "Cargo",
		["description"] = "Ammo",
		["attribute"] = 
		{
			["Cargos"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [121]
	[122] = 
	{
		["type"] = "barrels_cargo",
		["name"] = "Barrels",
		["category"] = "Cargo",
		["description"] = "Barrels",
		["attribute"] = 
		{
			["Cargos"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [122]
	[123] = 
	{
		["type"] = "container_cargo",
		["name"] = "Container",
		["category"] = "Cargo",
		["description"] = "Container",
		["attribute"] = 
		{
			["Cargos"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [123]
	[124] = 
	{
		["type"] = "f_bar_cargo",
		["name"] = "F-shape barrier",
		["category"] = "Cargo",
		["description"] = "F-shape barrier",
		["attribute"] = 
		{
			["Cargos"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [124]
	[125] = 
	{
		["type"] = "fueltank_cargo",
		["name"] = "Fueltank",
		["category"] = "Cargo",
		["description"] = "Fueltank",
		["attribute"] = 
		{
			["Cargos"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [125]
	[126] = 
	{
		["type"] = "iso_container",
		["name"] = "ISO container",
		["category"] = "Cargo",
		["description"] = "ISO container",
		["attribute"] = 
		{
			["Cargos"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [126]
	[127] = 
	{
		["type"] = "iso_container_small",
		["name"] = "ISO container small",
		["category"] = "Cargo",
		["description"] = "ISO container small",
		["attribute"] = 
		{
			["Cargos"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [127]
	[128] = 
	{
		["type"] = "m117_cargo",
		["name"] = "M117 bombs",
		["category"] = "Cargo",
		["description"] = "M117 bombs",
		["attribute"] = 
		{
			["Cargos"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [128]
	[129] = 
	{
		["type"] = "oiltank_cargo",
		["name"] = "Oiltank",
		["category"] = "Cargo",
		["description"] = "Oiltank",
		["attribute"] = 
		{
			["Cargos"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [129]
	[130] = 
	{
		["type"] = "pipes_big_cargo",
		["name"] = "Pipes big",
		["category"] = "Cargo",
		["description"] = "Pipes big",
		["attribute"] = 
		{
			["Cargos"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [130]
	[131] = 
	{
		["type"] = "pipes_small_cargo",
		["name"] = "Pipes small",
		["category"] = "Cargo",
		["description"] = "Pipes small",
		["attribute"] = 
		{
			["Cargos"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [131]
	[132] = 
	{
		["type"] = "tetrapod_cargo",
		["name"] = "Tetrapod",
		["category"] = "Cargo",
		["description"] = "Tetrapod",
		["attribute"] = 
		{
			["Cargos"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [132]
	[133] = 
	{
		["type"] = "trunks_long_cargo",
		["name"] = "Trunks long",
		["category"] = "Cargo",
		["description"] = "Trunks long",
		["attribute"] = 
		{
			["Cargos"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [133]
	[134] = 
	{
		["type"] = "trunks_small_cargo",
		["name"] = "Trunks short",
		["category"] = "Cargo",
		["description"] = "Trunks short",
		["attribute"] = 
		{
			["Cargos"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [134]
	[135] = 
	{
		["type"] = "uh1h_cargo",
		["name"] = "UH-1H cargo",
		["category"] = "Cargo",
		["description"] = "UH-1H cargo",
		["attribute"] = 
		{
			["Cargos"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [135]
	[136] = 
	{
		["type"] = "Boxcartrinity",
		["name"] = "Boxcartrinity",
		["category"] = "Carriage",
		["description"] = "Boxcartrinity",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			["Vehicles"] = true,
			[100] = true,
			[2] = true,
			[8] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			[51] = true,
			["Unarmed vehicles"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["NonAndLightArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [136]
	[137] = 
	{
		["type"] = "Coach a tank blue",
		["name"] = "Coach a tank blue",
		["category"] = "Carriage",
		["description"] = "Coach a tank blue",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			["Vehicles"] = true,
			[100] = true,
			[2] = true,
			[8] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Unarmed vehicles"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[50] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [137]
	[138] = 
	{
		["type"] = "Coach a tank yellow",
		["name"] = "Coach a tank yellow",
		["category"] = "Carriage",
		["description"] = "Coach a tank yellow",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			["Vehicles"] = true,
			[100] = true,
			[2] = true,
			[8] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			[98] = true,
			["Unarmed vehicles"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["NonAndLightArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [138]
	[139] = 
	{
		["type"] = "Coach a platform",
		["name"] = "Coach flatbed",
		["category"] = "Carriage",
		["description"] = "Coach flatbed",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			["Vehicles"] = true,
			[100] = true,
			[2] = true,
			[8] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			[53] = true,
			["Unarmed vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [139]
	[140] = 
	{
		["type"] = "Coach cargo",
		["name"] = "Coach for cargo",
		["category"] = "Carriage",
		["description"] = "Coach for cargo",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			["Vehicles"] = true,
			[100] = true,
			[2] = true,
			[8] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			[51] = true,
			["Unarmed vehicles"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["NonAndLightArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [140]
	[141] = 
	{
		["type"] = "Coach cargo open",
		["name"] = "Coach for open cargo",
		["category"] = "Carriage",
		["description"] = "Coach for open cargo",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			["Vehicles"] = true,
			[100] = true,
			[2] = true,
			[8] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			[51] = true,
			["Unarmed vehicles"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["NonAndLightArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [141]
	[142] = 
	{
		["type"] = "Coach a passenger",
		["name"] = "Coach for passengers",
		["category"] = "Carriage",
		["description"] = "Coach for passengers",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			["Vehicles"] = true,
			[100] = true,
			[54] = true,
			[8] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Unarmed vehicles"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[2] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [142]
	[143] = 
	{
		["type"] = "Tankcartrinity",
		["name"] = "Tankcartrinity",
		["category"] = "Carriage",
		["description"] = "Tankcartrinity",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			["Vehicles"] = true,
			[100] = true,
			[2] = true,
			[8] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			[51] = true,
			["Unarmed vehicles"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["NonAndLightArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [143]
	[144] = 
	{
		["type"] = "Wellcarnsc",
		["name"] = "Wellcarnsc",
		["category"] = "Carriage",
		["description"] = "Wellcarnsc",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			["Vehicles"] = true,
			[100] = true,
			[2] = true,
			[8] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			[51] = true,
			["Unarmed vehicles"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["NonAndLightArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [144]
	[145] = 
	{
		["type"] = "Airshow_Cone",
		["name"] = "Airshow cone",
		["category"] = "Fortification",
		["description"] = "Airshow cone",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [145]
	[146] = 
	{
		["type"] = "Airshow_Crowd",
		["name"] = "Airshow Crowd",
		["category"] = "Fortification",
		["description"] = "Airshow Crowd",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [146]
	[147] = 
	{
		["type"] = "houseA_arm",
		["name"] = "Armed house",
		["category"] = "Fortification",
		["description"] = "Armed house",
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			[26] = true,
			[2] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["HeavyArmoredUnits"] = true,
			["Fortifications"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[96] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [147]
	[148] = 
	{
		["type"] = "Barracks 2",
		["name"] = "Barracks 2",
		["category"] = "Fortification",
		["description"] = "Barracks 2",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [148]
	[149] = 
	{
		["type"] = "house1arm",
		["name"] = "Barracks armed",
		["category"] = "Fortification",
		["description"] = "Barracks armed",
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			[26] = true,
			[2] = true,
			["AntiAir Armed Vehicles"] = true,
			["CustomAimPoint"] = true,
			[17] = true,
			["HeavyArmoredUnits"] = true,
			["Fortifications"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[96] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [149]
	[150] = 
	{
		["type"] = "Boiler-house A",
		["name"] = "Boiler-house A",
		["category"] = "Fortification",
		["description"] = "Boiler-house A",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [150]
	[151] = 
	{
		["type"] = "Sandbox",
		["name"] = "Bunker 1",
		["category"] = "Fortification",
		["description"] = "Bunker 1",
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			[26] = true,
			[2] = true,
			["AntiAir Armed Vehicles"] = true,
			["CustomAimPoint"] = true,
			[17] = true,
			["HeavyArmoredUnits"] = true,
			["Fortifications"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[96] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [151]
	[152] = 
	{
		["type"] = "Bunker",
		["name"] = "Bunker 2",
		["category"] = "Fortification",
		["description"] = "Bunker 2",
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			[26] = true,
			[2] = true,
			["AntiAir Armed Vehicles"] = true,
			["CustomAimPoint"] = true,
			[17] = true,
			["HeavyArmoredUnits"] = true,
			["Fortifications"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[96] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [152]
	[153] = 
	{
		["type"] = "Cafe",
		["name"] = "Cafe",
		["category"] = "Fortification",
		["description"] = "Cafe",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [153]
	[154] = 
	{
		["type"] = "Chemical tank A",
		["name"] = "Chemical tank A",
		["category"] = "Fortification",
		["description"] = "Chemical tank A",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [154]
	[155] = 
	{
		["type"] = ".Command Center",
		["name"] = "Command Center",
		["category"] = "Fortification",
		["description"] = "Command Center",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [155]
	[156] = 
	{
		["type"] = "Comms tower M",
		["name"] = "Comms tower M",
		["category"] = "Fortification",
		["description"] = "Comms tower M",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [156]
	[157] = 
	{
		["type"] = "Container brown",
		["name"] = "Container brown",
		["category"] = "Fortification",
		["description"] = "Container brown",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [157]
	[158] = 
	{
		["type"] = "Container red 1",
		["name"] = "Container red 1",
		["category"] = "Fortification",
		["description"] = "Container red 1",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [158]
	[159] = 
	{
		["type"] = "Container red 2",
		["name"] = "Container red 2",
		["category"] = "Fortification",
		["description"] = "Container red 2",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [159]
	[160] = 
	{
		["type"] = "Container red 3",
		["name"] = "Container red 3",
		["category"] = "Fortification",
		["description"] = "Container red 3",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [160]
	[161] = 
	{
		["type"] = "Container white",
		["name"] = "Container white",
		["category"] = "Fortification",
		["description"] = "Container white",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [161]
	[162] = 
	{
		["type"] = "Electric power box",
		["name"] = "Electric power box",
		["category"] = "Fortification",
		["description"] = "Electric power box",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [162]
	[163] = 
	{
		["type"] = "Farm A",
		["name"] = "Farm A",
		["category"] = "Fortification",
		["description"] = "Farm A",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [163]
	[164] = 
	{
		["type"] = "Farm B",
		["name"] = "Farm B",
		["category"] = "Fortification",
		["description"] = "Farm B",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [164]
	[165] = 
	{
		["type"] = "FARP Ammo Dump Coating",
		["name"] = "FARP Ammo Storage",
		["category"] = "Fortification",
		["description"] = "FARP Ammo Storage",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [165]
	[166] = 
	{
		["type"] = "FARP CP Blindage",
		["name"] = "FARP Command Post",
		["category"] = "Fortification",
		["description"] = "FARP Command Post",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [166]
	[167] = 
	{
		["type"] = "FARP Fuel Depot",
		["name"] = "FARP Fuel Depot",
		["category"] = "Fortification",
		["description"] = "FARP Fuel Depot",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [167]
	[168] = 
	{
		["type"] = "FARP Tent",
		["name"] = "FARP Tent",
		["category"] = "Fortification",
		["description"] = "FARP Tent",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [168]
	[169] = 
	{
		["type"] = "Fuel tank",
		["name"] = "Fuel tank",
		["category"] = "Fortification",
		["description"] = "Fuel tank",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [169]
	[170] = 
	{
		["type"] = "Garage A",
		["name"] = "Garage A",
		["category"] = "Fortification",
		["description"] = "Garage A",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [170]
	[171] = 
	{
		["type"] = "Garage B",
		["name"] = "Garage B",
		["category"] = "Fortification",
		["description"] = "Garage B",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [171]
	[172] = 
	{
		["type"] = "Garage small A",
		["name"] = "Garage small A",
		["category"] = "Fortification",
		["description"] = "Garage small A",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [172]
	[173] = 
	{
		["type"] = "Garage small B",
		["name"] = "Garage small B",
		["category"] = "Fortification",
		["description"] = "Garage small B",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [173]
	[174] = 
	{
		["type"] = "GeneratorF",
		["name"] = "GeneratorF",
		["category"] = "Fortification",
		["description"] = "GeneratorF",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [174]
	[175] = 
	{
		["type"] = "Hangar A",
		["name"] = "Hangar A",
		["category"] = "Fortification",
		["description"] = "Hangar A",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [175]
	[176] = 
	{
		["type"] = "Hangar B",
		["name"] = "Hangar B",
		["category"] = "Fortification",
		["description"] = "Hangar B",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [176]
	[177] = 
	{
		["type"] = "Hercules_Container_Parachute_Static",
		["name"] = "Hercules container with parachute",
		["category"] = "Fortification",
		["description"] = "Hercules container with parachute",
		["attribute"] = 
		{
			["Fortifications"] = true,
			["Ground Units Non Airdefence"] = true,
			["HeavyArmoredUnits"] = true,
			["AntiAir Armed Vehicles"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			[5] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [177]
	[178] = 
	{
		["type"] = "Landmine",
		["name"] = "Landmine",
		["category"] = "Fortification",
		["description"] = "Landmine",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [178]
	[179] = 
	{
		["type"] = "Red_Flag",
		["name"] = "Mark Flag Red",
		["category"] = "Fortification",
		["description"] = "Mark Flag Red",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [179]
	[180] = 
	{
		["type"] = "White_Flag",
		["name"] = "Mark Flag White",
		["category"] = "Fortification",
		["description"] = "Mark Flag White",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [180]
	[181] = 
	{
		["type"] = "Black_Tyre",
		["name"] = "Mark Tyre Black",
		["category"] = "Fortification",
		["description"] = "Mark Tyre Black",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [181]
	[182] = 
	{
		["type"] = "White_Tyre",
		["name"] = "Mark Tyre White",
		["category"] = "Fortification",
		["description"] = "Mark Tyre White",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [182]
	[183] = 
	{
		["type"] = "Black_Tyre_RF",
		["name"] = "Mark Tyre with Red Flag",
		["category"] = "Fortification",
		["description"] = "Mark Tyre with Red Flag",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [183]
	[184] = 
	{
		["type"] = "Black_Tyre_WF",
		["name"] = "Mark Tyre with White Flag",
		["category"] = "Fortification",
		["description"] = "Mark Tyre with White Flag",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [184]
	[185] = 
	{
		["type"] = "Military staff",
		["name"] = "Military staff",
		["category"] = "Fortification",
		["description"] = "Military staff",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [185]
	[186] = 
	{
		["type"] = "Oil derrick",
		["name"] = "Oil derrick",
		["category"] = "Fortification",
		["description"] = "Oil derrick",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [186]
	[187] = 
	{
		["type"] = "Oil platform",
		["name"] = "Oil platform",
		["category"] = "Fortification",
		["description"] = "Oil platform",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [187]
	[188] = 
	{
		["type"] = "outpost",
		["name"] = "Outpost",
		["category"] = "Fortification",
		["description"] = "Outpost",
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			[26] = true,
			[2] = true,
			["AntiAir Armed Vehicles"] = true,
			["CustomAimPoint"] = true,
			[17] = true,
			["HeavyArmoredUnits"] = true,
			["Fortifications"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[96] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [188]
	[189] = 
	{
		["type"] = "Pump station",
		["name"] = "Pump station",
		["category"] = "Fortification",
		["description"] = "Pump station",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [189]
	[190] = 
	{
		["type"] = "Railway crossing A",
		["name"] = "Railway crossing A",
		["category"] = "Fortification",
		["description"] = "Railway crossing A",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [190]
	[191] = 
	{
		["type"] = "Railway crossing B",
		["name"] = "Railway crossing B",
		["category"] = "Fortification",
		["description"] = "Railway crossing B",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [191]
	[192] = 
	{
		["type"] = "Railway station",
		["name"] = "Railway station",
		["category"] = "Fortification",
		["description"] = "Railway station",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [192]
	[193] = 
	{
		["type"] = "Repair workshop",
		["name"] = "Repair workshop",
		["category"] = "Fortification",
		["description"] = "Repair workshop",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [193]
	[194] = 
	{
		["type"] = "Restaurant 1",
		["name"] = "Restaurant 1",
		["category"] = "Fortification",
		["description"] = "Restaurant 1",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [194]
	[195] = 
	{
		["type"] = "outpost_road",
		["name"] = "Road outpost",
		["category"] = "Fortification",
		["description"] = "Road outpost",
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			[26] = true,
			[2] = true,
			["AntiAir Armed Vehicles"] = true,
			["CustomAimPoint"] = true,
			[17] = true,
			["HeavyArmoredUnits"] = true,
			["Fortifications"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[96] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [195]
	[196] = 
	{
		["type"] = "Shelter",
		["name"] = "Shelter",
		["category"] = "Fortification",
		["description"] = "Shelter",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [196]
	[197] = 
	{
		["type"] = "Shelter B",
		["name"] = "Shelter B",
		["category"] = "Fortification",
		["description"] = "Shelter B",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [197]
	[198] = 
	{
		["type"] = "Shop",
		["name"] = "Shop",
		["category"] = "Fortification",
		["description"] = "Shop",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [198]
	[199] = 
	{
		["type"] = "Small house 1A",
		["name"] = "Small house 1A",
		["category"] = "Fortification",
		["description"] = "Small house 1A",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [199]
	[200] = 
	{
		["type"] = "Small house 1A area",
		["name"] = "Small house 1A area",
		["category"] = "Fortification",
		["description"] = "Small house 1A area",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [200]
	[201] = 
	{
		["type"] = "Small house 1B",
		["name"] = "Small house 1B",
		["category"] = "Fortification",
		["description"] = "Small house 1B",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [201]
	[202] = 
	{
		["type"] = "Small house 1B area",
		["name"] = "Small house 1B area",
		["category"] = "Fortification",
		["description"] = "Small house 1B area",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [202]
	[203] = 
	{
		["type"] = "Small house 1C area",
		["name"] = "Small house 1C area",
		["category"] = "Fortification",
		["description"] = "Small house 1C area",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [203]
	[204] = 
	{
		["type"] = "Small house 2C",
		["name"] = "Small house 2C",
		["category"] = "Fortification",
		["description"] = "Small house 2C",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [204]
	[205] = 
	{
		["type"] = "Small werehouse 1",
		["name"] = "Small warehouse 1",
		["category"] = "Fortification",
		["description"] = "Small warehouse 1",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [205]
	[206] = 
	{
		["type"] = "Small werehouse 2",
		["name"] = "Small warehouse 2",
		["category"] = "Fortification",
		["description"] = "Small warehouse 2",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [206]
	[207] = 
	{
		["type"] = "Small werehouse 3",
		["name"] = "Small warehouse 3",
		["category"] = "Fortification",
		["description"] = "Small warehouse 3",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [207]
	[208] = 
	{
		["type"] = "Small werehouse 4",
		["name"] = "Small warehouse 4",
		["category"] = "Fortification",
		["description"] = "Small warehouse 4",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [208]
	[209] = 
	{
		["type"] = "Subsidiary structure 1",
		["name"] = "Subsidiary structure 1",
		["category"] = "Fortification",
		["description"] = "Subsidiary structure 1",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [209]
	[210] = 
	{
		["type"] = "Subsidiary structure 2",
		["name"] = "Subsidiary structure 2",
		["category"] = "Fortification",
		["description"] = "Subsidiary structure 2",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [210]
	[211] = 
	{
		["type"] = "Subsidiary structure 3",
		["name"] = "Subsidiary structure 3",
		["category"] = "Fortification",
		["description"] = "Subsidiary structure 3",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [211]
	[212] = 
	{
		["type"] = "Subsidiary structure A",
		["name"] = "Subsidiary structure A",
		["category"] = "Fortification",
		["description"] = "Subsidiary structure A",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [212]
	[213] = 
	{
		["type"] = "Subsidiary structure B",
		["name"] = "Subsidiary structure B",
		["category"] = "Fortification",
		["description"] = "Subsidiary structure B",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [213]
	[214] = 
	{
		["type"] = "Subsidiary structure C",
		["name"] = "Subsidiary structure C",
		["category"] = "Fortification",
		["description"] = "Subsidiary structure C",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [214]
	[215] = 
	{
		["type"] = "Subsidiary structure D",
		["name"] = "Subsidiary structure D",
		["category"] = "Fortification",
		["description"] = "Subsidiary structure D",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [215]
	[216] = 
	{
		["type"] = "Subsidiary structure E",
		["name"] = "Subsidiary structure E",
		["category"] = "Fortification",
		["description"] = "Subsidiary structure E",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [216]
	[217] = 
	{
		["type"] = "Subsidiary structure F",
		["name"] = "Subsidiary structure F",
		["category"] = "Fortification",
		["description"] = "Subsidiary structure F",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [217]
	[218] = 
	{
		["type"] = "Subsidiary structure G",
		["name"] = "Subsidiary structure G",
		["category"] = "Fortification",
		["description"] = "Subsidiary structure G",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [218]
	[219] = 
	{
		["type"] = "Supermarket A",
		["name"] = "Supermarket A",
		["category"] = "Fortification",
		["description"] = "Supermarket A",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [219]
	[220] = 
	{
		["type"] = "TACAN_beacon",
		["name"] = "TACAN Beacon (Man Portable) TTS 3030",
		["category"] = "Fortification",
		["description"] = "TACAN Beacon (Man Portable) TTS 3030",
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			[26] = true,
			[2] = true,
			["AntiAir Armed Vehicles"] = true,
			["CustomAimPoint"] = true,
			[17] = true,
			["HeavyArmoredUnits"] = true,
			["Fortifications"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[96] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [220]
	[221] = 
	{
		["type"] = "Tech combine",
		["name"] = "Tech combine",
		["category"] = "Fortification",
		["description"] = "Tech combine",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [221]
	[222] = 
	{
		["type"] = "Tech hangar A",
		["name"] = "Tech hangar A",
		["category"] = "Fortification",
		["description"] = "Tech hangar A",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [222]
	[223] = 
	{
		["type"] = "TV tower",
		["name"] = "TV tower",
		["category"] = "Fortification",
		["description"] = "TV tower",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [223]
	[224] = 
	{
		["type"] = "warning_board_a",
		["name"] = "Warning Board A",
		["category"] = "Fortification",
		["description"] = "Warning Board A",
		["attribute"] = 
		{
			[5] = true,
			[9] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [224]
	[225] = 
	{
		["type"] = "warning_board_b",
		["name"] = "Warning Board B",
		["category"] = "Fortification",
		["description"] = "Warning Board B",
		["attribute"] = 
		{
			[5] = true,
			[9] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [225]
	[226] = 
	{
		["type"] = "house2arm",
		["name"] = "Watch tower armed",
		["category"] = "Fortification",
		["description"] = "Watch tower armed",
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			[26] = true,
			[2] = true,
			["AntiAir Armed Vehicles"] = true,
			["CustomAimPoint"] = true,
			[17] = true,
			["HeavyArmoredUnits"] = true,
			["Fortifications"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[96] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [226]
	[227] = 
	{
		["type"] = "Water tower A",
		["name"] = "Water tower A",
		["category"] = "Fortification",
		["description"] = "Water tower A",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [227]
	[228] = 
	{
		["type"] = "WC",
		["name"] = "WC",
		["category"] = "Fortification",
		["description"] = "WC",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [228]
	[229] = 
	{
		["type"] = "Windsock",
		["name"] = "Windsock",
		["category"] = "Fortification",
		["description"] = "Windsock",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [229]
	[230] = 
	{
		["type"] = "Workshop A",
		["name"] = "Workshop A",
		["category"] = "Fortification",
		["description"] = "Workshop A",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [230]
	[231] = 
	{
		["type"] = "Bridge",
		["name"] = "Bridge",
		["category"] = "GroundObject",
		["description"] = "Bridge",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [231]
	[232] = 
	{
		["type"] = "Building",
		["name"] = "Building",
		["category"] = "GroundObject",
		["description"] = "Building",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [232]
	[233] = 
	{
		["type"] = "Train",
		["name"] = "Train",
		["category"] = "GroundObject",
		["description"] = "Train",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [233]
	[234] = 
	{
		["type"] = "Transport",
		["name"] = "Transport",
		["category"] = "GroundObject",
		["description"] = "Transport",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [234]
	[235] = 
	{
		["air"] = true,
		["type"] = "AH-1W",
		["name"] = "AH-1W",
		["category"] = "Helicopter",
		["description"] = "AH-1W",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			[6] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Air"] = true,
			[163] = true,
			["All"] = true,
			["Helicopters"] = true,
			["Attack helicopters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [235]
	[236] = 
	{
		["air"] = true,
		["type"] = "AH-64A",
		["name"] = "AH-64A",
		["category"] = "Helicopter",
		["description"] = "AH-64A",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			[6] = true,
			["Helicopters"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			[157] = true,
			["Attack helicopters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [236]
	[237] = 
	{
		["air"] = true,
		["type"] = "AH-64D",
		["name"] = "AH-64D",
		["category"] = "Helicopter",
		["description"] = "AH-64D",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			[6] = true,
			[158] = true,
			["NonAndLightArmoredUnits"] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Helicopters"] = true,
			["Attack helicopters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [237]
	[238] = 
	{
		["air"] = true,
		["type"] = "CH-47D",
		["name"] = "CH-47D",
		["category"] = "Helicopter",
		["description"] = "CH-47D",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Air"] = true,
			[159] = true,
			["NonAndLightArmoredUnits"] = true,
			[25] = true,
			["NonArmoredUnits"] = true,
			["Transport helicopters"] = true,
			["Helicopters"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [238]
	[239] = 
	{
		["air"] = true,
		["type"] = "CH-53E",
		["name"] = "CH-53E",
		["category"] = "Helicopter",
		["description"] = "CH-53E",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Air"] = true,
			["All"] = true,
			["NonAndLightArmoredUnits"] = true,
			[25] = true,
			["NonArmoredUnits"] = true,
			["Transport helicopters"] = true,
			["Helicopters"] = true,
			[160] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [239]
	[240] = 
	{
		["air"] = true,
		["type"] = "Ka-27",
		["name"] = "Ka-27",
		["category"] = "Helicopter",
		["description"] = "Ka-27",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			[154] = true,
			["Air"] = true,
			["NonAndLightArmoredUnits"] = true,
			[25] = true,
			["NonArmoredUnits"] = true,
			["Transport helicopters"] = true,
			["Helicopters"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [240]
	[241] = 
	{
		["air"] = true,
		["type"] = "Ka-50",
		["name"] = "Ka-50",
		["category"] = "Helicopter",
		["description"] = "Ka-50",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			[6] = true,
			["NonAndLightArmoredUnits"] = true,
			[155] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Helicopters"] = true,
			["Attack helicopters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [241]
	[242] = 
	{
		["air"] = true,
		["type"] = "Ka-52",
		["name"] = "Ka-52",
		["category"] = "Helicopter",
		["description"] = "Ka-52",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			[6] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Air"] = true,
			[156] = true,
			["All"] = true,
			["Helicopters"] = true,
			["Attack helicopters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [242]
	[243] = 
	{
		["air"] = true,
		["type"] = "Mi-24V",
		["name"] = "Mi-24V",
		["category"] = "Helicopter",
		["description"] = "Mi-24V",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			[6] = true,
			["Air"] = true,
			["NonAndLightArmoredUnits"] = true,
			[152] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Helicopters"] = true,
			["Attack helicopters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [243]
	[244] = 
	{
		["air"] = true,
		["type"] = "Mi-26",
		["name"] = "Mi-26",
		["category"] = "Helicopter",
		["description"] = "Mi-26",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Air"] = true,
			[153] = true,
			["NonAndLightArmoredUnits"] = true,
			[25] = true,
			["NonArmoredUnits"] = true,
			["Transport helicopters"] = true,
			["Helicopters"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [244]
	[245] = 
	{
		["air"] = true,
		["type"] = "Mi-28N",
		["name"] = "Mi-28N",
		["category"] = "Helicopter",
		["description"] = "Mi-28N",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			[6] = true,
			["All"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			[167] = true,
			["Helicopters"] = true,
			["Attack helicopters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [245]
	[246] = 
	{
		["air"] = true,
		["type"] = "Mi-8MT",
		["name"] = "Mi-8MTV2",
		["category"] = "Helicopter",
		["description"] = "Mi-8MTV2",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			[6] = true,
			[151] = true,
			["NonAndLightArmoredUnits"] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Helicopters"] = true,
			["Attack helicopters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [246]
	[247] = 
	{
		["air"] = true,
		["type"] = "OH-58D",
		["name"] = "OH-58D",
		["category"] = "Helicopter",
		["description"] = "OH-58D",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			[6] = true,
			[168] = true,
			["NonAndLightArmoredUnits"] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Helicopters"] = true,
			["Attack helicopters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [247]
	[248] = 
	{
		["air"] = true,
		["type"] = "SA342L",
		["name"] = "SA342L",
		["category"] = "Helicopter",
		["description"] = "SA342L",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			[6] = true,
			[290] = true,
			["NonAndLightArmoredUnits"] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Helicopters"] = true,
			["Attack helicopters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [248]
	[249] = 
	{
		["air"] = true,
		["type"] = "SA342M",
		["name"] = "SA342M",
		["category"] = "Helicopter",
		["description"] = "SA342M",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			[6] = true,
			["Helicopters"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			[289] = true,
			["Attack helicopters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [249]
	[250] = 
	{
		["air"] = true,
		["type"] = "SA342Minigun",
		["name"] = "SA342Minigun",
		["category"] = "Helicopter",
		["description"] = "SA342Minigun",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			[6] = true,
			["NonAndLightArmoredUnits"] = true,
			[292] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Helicopters"] = true,
			["Attack helicopters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [250]
	[251] = 
	{
		["air"] = true,
		["type"] = "SA342Mistral",
		["name"] = "SA342Mistral",
		["category"] = "Helicopter",
		["description"] = "SA342Mistral",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			[6] = true,
			[291] = true,
			["NonAndLightArmoredUnits"] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Helicopters"] = true,
			["Attack helicopters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [251]
	[252] = 
	{
		["air"] = true,
		["type"] = "SH-3W",
		["name"] = "SH-3W",
		["category"] = "Helicopter",
		["description"] = "SH-3W",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Air"] = true,
			["Helicopters"] = true,
			["NonAndLightArmoredUnits"] = true,
			[25] = true,
			["NonArmoredUnits"] = true,
			["Transport helicopters"] = true,
			[164] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [252]
	[253] = 
	{
		["air"] = true,
		["type"] = "SH-60B",
		["name"] = "SH-60B",
		["category"] = "Helicopter",
		["description"] = "SH-60B",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			[6] = true,
			[161] = true,
			["NonAndLightArmoredUnits"] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Helicopters"] = true,
			["Attack helicopters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [253]
	[254] = 
	{
		["air"] = true,
		["type"] = "UH-1H",
		["name"] = "UH-1H",
		["category"] = "Helicopter",
		["description"] = "UH-1H",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			[6] = true,
			["Air"] = true,
			["NonAndLightArmoredUnits"] = true,
			[166] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Helicopters"] = true,
			["Attack helicopters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [254]
	[255] = 
	{
		["air"] = true,
		["type"] = "UH-60A",
		["name"] = "UH-60A",
		["category"] = "Helicopter",
		["description"] = "UH-60A",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Air"] = true,
			["NonAndLightArmoredUnits"] = true,
			[162] = true,
			[25] = true,
			["NonArmoredUnits"] = true,
			["Transport helicopters"] = true,
			["Helicopters"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [255]
	[256] = 
	{
		["type"] = "Soldier M4 GRG",
		["name"] = "Georgian soldier with M4",
		["category"] = "Infantry",
		["infantry"] = true,
		["description"] = "Georgian soldier with M4",
		["attribute"] = 
		{
			["Infantry"] = true,
			[26] = true,
			[2] = true,
			["CustomAimPoint"] = true,
			["NonArmoredUnits"] = true,
			[90] = true,
			["New infantry"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[17] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [256]
	[257] = 
	{
		["type"] = "Soldier M4",
		["name"] = "Infantry M4",
		["category"] = "Infantry",
		["infantry"] = true,
		["description"] = "Infantry M4",
		["attribute"] = 
		{
			["Infantry"] = true,
			[26] = true,
			[2] = true,
			["CustomAimPoint"] = true,
			[90] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[17] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [257]
	[258] = 
	{
		["type"] = "Infantry AK Ins",
		["name"] = "Infantry Soldier Insurgents",
		["category"] = "Infantry",
		["infantry"] = true,
		["description"] = "Infantry Soldier Insurgents",
		["attribute"] = 
		{
			["Infantry"] = true,
			[26] = true,
			[2] = true,
			["NonArmoredUnits"] = true,
			["CustomAimPoint"] = true,
			["Skeleton_type_A"] = true,
			[90] = true,
			["New infantry"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[17] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [258]
	[259] = 
	{
		["type"] = "Infantry AK",
		["name"] = "Infantry Soldier Rus",
		["category"] = "Infantry",
		["infantry"] = true,
		["description"] = "Infantry Soldier Rus",
		["attribute"] = 
		{
			["Infantry"] = true,
			[26] = true,
			[2] = true,
			["NonArmoredUnits"] = true,
			["CustomAimPoint"] = true,
			["Skeleton_type_A"] = true,
			[90] = true,
			["New infantry"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[17] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [259]
	[260] = 
	{
		["type"] = "Paratrooper AKS-74",
		["name"] = "Paratrooper AKS",
		["category"] = "Infantry",
		["infantry"] = true,
		["description"] = "Paratrooper AKS",
		["attribute"] = 
		{
			["Infantry"] = true,
			[26] = true,
			[2] = true,
			["CustomAimPoint"] = true,
			[90] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[17] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [260]
	[261] = 
	{
		["type"] = "Paratrooper RPG-16",
		["name"] = "Paratrooper RPG-16",
		["category"] = "Infantry",
		["infantry"] = true,
		["description"] = "Paratrooper RPG-16",
		["attribute"] = 
		{
			["Infantry"] = true,
			[26] = true,
			[2] = true,
			["CustomAimPoint"] = true,
			[90] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[17] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [261]
	[262] = 
	{
		["type"] = "Soldier AK",
		["name"] = "Soldier AK",
		["category"] = "Infantry",
		["infantry"] = true,
		["description"] = "Soldier AK",
		["attribute"] = 
		{
			["Infantry"] = true,
			[26] = true,
			[2] = true,
			["CustomAimPoint"] = true,
			[90] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[17] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [262]
	[263] = 
	{
		["type"] = "Soldier M249",
		["name"] = "Soldier M249",
		["category"] = "Infantry",
		["infantry"] = true,
		["description"] = "Soldier M249",
		["attribute"] = 
		{
			["Infantry"] = true,
			[26] = true,
			[2] = true,
			["CustomAimPoint"] = true,
			["Prone"] = true,
			[90] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[17] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [263]
	[264] = 
	{
		["type"] = "Soldier RPG",
		["name"] = "Soldier RPG",
		["category"] = "Infantry",
		["infantry"] = true,
		["description"] = "Soldier RPG",
		["attribute"] = 
		{
			["Infantry"] = true,
			[26] = true,
			[2] = true,
			["CustomAimPoint"] = true,
			[90] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[17] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [264]
	[265] = 
	{
		["type"] = "Electric locomotive",
		["name"] = "Electric locomotive VL80",
		["category"] = "Locomotive",
		["description"] = "Electric locomotive VL80",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Ground Units Non Airdefence"] = true,
			["Vehicles"] = true,
			[100] = true,
			[2] = true,
			[8] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Unarmed vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [265]
	[266] = 
	{
		["type"] = "ES44AH",
		["name"] = "ES44AH",
		["category"] = "Locomotive",
		["description"] = "ES44AH",
		["vehicle"] = true,
		["attribute"] = 
		{
			[48] = true,
			["Vehicles"] = true,
			[100] = true,
			[2] = true,
			[8] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Unarmed vehicles"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Ground Units Non Airdefence"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [266]
	[267] = 
	{
		["type"] = "Locomotive",
		["name"] = "Locomotive CHME3T",
		["category"] = "Locomotive",
		["description"] = "Locomotive CHME3T",
		["vehicle"] = true,
		["attribute"] = 
		{
			[48] = true,
			["Vehicles"] = true,
			[100] = true,
			[2] = true,
			[8] = true,
			["Trucks"] = true,
			["Ground vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Unarmed vehicles"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Ground Units Non Airdefence"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [267]
	[268] = 
	{
		["type"] = "Silkworm_SR",
		["name"] = "Silkworm Radar",
		["category"] = "MissilesSS",
		["description"] = "Silkworm Radar",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Artillery"] = true,
			["Ground Units Non Airdefence"] = true,
			["Vehicles"] = true,
			["DetectionByAWACS"] = true,
			[2] = true,
			["LightArmoredUnits"] = true,
			["Indirect fire"] = true,
			[101] = true,
			["Ground vehicles"] = true,
			["Armed vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			[259] = true,
			[16] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [268]
	[269] = 
	{
		["type"] = "Scud_B",
		["name"] = "SRBM SS-1C Scud-B 9K72 LN 9P117M",
		["category"] = "MissilesSS",
		["description"] = "SRBM SS-1C Scud-B 9K72 LN 9P117M",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armed vehicles"] = true,
			[63] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["SS_missile"] = true,
			["Armed ground units"] = true,
			["Artillery"] = true,
			["Ground Units Non Airdefence"] = true,
			["LightArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			[27] = true,
			["Indirect fire"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Datalink"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [269]
	[270] = 
	{
		["type"] = "hy_launcher",
		["name"] = "SS-N-2 Silkworm",
		["category"] = "MissilesSS",
		["description"] = "SS-N-2 Silkworm",
		["vehicle"] = true,
		["attribute"] = 
		{
			["Artillery"] = true,
			["Ground Units Non Airdefence"] = true,
			["Vehicles"] = true,
			[37] = true,
			[2] = true,
			["LightArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			[16] = true,
			["Ground vehicles"] = true,
			["Indirect fire"] = true,
			["SS_missile"] = true,
			["Armed vehicles"] = true,
			["Armed ground units"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[27] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [270]
	[271] = 
	{
		["air"] = true,
		["type"] = "A-10A",
		["name"] = "A-10A",
		["category"] = "Plane",
		["description"] = "A-10A",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			[17] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			["All"] = true,
			[6] = true,
			["Refuelable"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [271]
	[272] = 
	{
		["air"] = true,
		["type"] = "A-10C",
		["name"] = "A-10C",
		["category"] = "Plane",
		["description"] = "A-10C",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battleplanes"] = true,
			["Refuelable"] = true,
			["Link16"] = true,
			["Planes"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			[6] = true,
			["All"] = true,
			["Datalink"] = true,
			[58] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [272]
	[273] = 
	{
		["air"] = true,
		["type"] = "A-10C_2",
		["name"] = "A-10C II",
		["category"] = "Plane",
		["description"] = "A-10C II",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battleplanes"] = true,
			["Refuelable"] = true,
			["Link16"] = true,
			["Planes"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			[6] = true,
			["All"] = true,
			["Datalink"] = true,
			[264] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [273]
	[274] = 
	{
		["air"] = true,
		["type"] = "A-20G",
		["name"] = "A-20G",
		["category"] = "Plane",
		["description"] = "A-20G",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			[263] = true,
			["NonArmoredUnits"] = true,
			[4] = true,
			["Strategic bombers"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["Bombers"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [274]
	[275] = 
	{
		["air"] = true,
		["type"] = "A-50",
		["name"] = "A-50",
		["category"] = "Plane",
		["description"] = "A-50",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			[26] = true,
			["Refuelable"] = true,
			["AWACS"] = true,
			[5] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [275]
	[276] = 
	{
		["air"] = true,
		["type"] = "AJS37",
		["name"] = "AJS37",
		["category"] = "Plane",
		["description"] = "AJS37",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			[265] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [276]
	[277] = 
	{
		["air"] = true,
		["type"] = "An-26B",
		["name"] = "An-26B",
		["category"] = "Plane",
		["description"] = "An-26B",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Planes"] = true,
			["NonAndLightArmoredUnits"] = true,
			[39] = true,
			["Transports"] = true,
			["All"] = true,
			[5] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [277]
	[278] = 
	{
		["air"] = true,
		["type"] = "An-30M",
		["name"] = "An-30M",
		["category"] = "Plane",
		["description"] = "An-30M",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Planes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["Transports"] = true,
			["All"] = true,
			[5] = true,
			[40] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [278]
	[279] = 
	{
		["air"] = true,
		["type"] = "AV8BNA",
		["name"] = "AV-8B N/A",
		["category"] = "Plane",
		["description"] = "AV-8B N/A",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Refuelable"] = true,
			[266] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Bombers"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [279]
	[280] = 
	{
		["air"] = true,
		["type"] = "B-1B",
		["name"] = "B-1B",
		["category"] = "Plane",
		["description"] = "B-1B",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Air"] = true,
			["Refuelable"] = true,
			["Strategic bombers"] = true,
			["Bombers"] = true,
			["Planes"] = true,
			["Battle airplanes"] = true,
			[19] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Link16"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [280]
	[281] = 
	{
		["air"] = true,
		["type"] = "B-52H",
		["name"] = "B-52H",
		["category"] = "Plane",
		["description"] = "B-52H",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Refuelable"] = true,
			[4] = true,
			["Strategic bombers"] = true,
			["Bombers"] = true,
			["Planes"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["Link16"] = true,
			["All"] = true,
			[23] = true,
			["Datalink"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [281]
	[282] = 
	{
		["air"] = true,
		["type"] = "Bf-109K-4",
		["name"] = "Bf 109 K-4",
		["category"] = "Plane",
		["description"] = "Bf 109 K-4",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			[257] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [282]
	[283] = 
	{
		["air"] = true,
		["type"] = "C-101CC",
		["name"] = "C-101CC",
		["category"] = "Plane",
		["description"] = "C-101CC",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			[6] = true,
			["Planes"] = true,
			[270] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [283]
	[284] = 
	{
		["air"] = true,
		["type"] = "C-101EB",
		["name"] = "C-101EB",
		["category"] = "Plane",
		["description"] = "C-101EB",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			[269] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["All"] = true,
			[6] = true,
			["Planes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [284]
	[285] = 
	{
		["air"] = true,
		["type"] = "C-130",
		["name"] = "C-130",
		["category"] = "Plane",
		["description"] = "C-130",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			[31] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			["Transports"] = true,
			["All"] = true,
			[5] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [285]
	[286] = 
	{
		["air"] = true,
		["type"] = "C-17A",
		["name"] = "C-17A",
		["category"] = "Plane",
		["description"] = "C-17A",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Refuelable"] = true,
			[47] = true,
			[5] = true,
			["NonAndLightArmoredUnits"] = true,
			["Transports"] = true,
			["All"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [286]
	[287] = 
	{
		["air"] = true,
		["type"] = "Christen Eagle II",
		["name"] = "Christen Eagle II",
		["category"] = "Plane",
		["description"] = "Christen Eagle II",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			[274] = true,
			["Planes"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [287]
	[288] = 
	{
		["air"] = true,
		["type"] = "E-2C",
		["name"] = "E-2D",
		["category"] = "Plane",
		["description"] = "E-2D",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			[41] = true,
			["Link16"] = true,
			["AWACS"] = true,
			[5] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Planes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [288]
	[289] = 
	{
		["air"] = true,
		["type"] = "E-3A",
		["name"] = "E-3A",
		["category"] = "Plane",
		["description"] = "E-3A",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			[27] = true,
			["Refuelable"] = true,
			["Link16"] = true,
			["AWACS"] = true,
			[5] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			["All"] = true,
			["Datalink"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [289]
	[290] = 
	{
		["air"] = true,
		["type"] = "F-111F",
		["name"] = "F-111F",
		["category"] = "Plane",
		["description"] = "F-111F",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Refuelable"] = true,
			[15] = true,
			["Battle airplanes"] = true,
			["Bombers"] = true,
			["Planes"] = true,
			["All"] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [290]
	[291] = 
	{
		["air"] = true,
		["type"] = "F-117A",
		["name"] = "F-117A",
		["category"] = "Plane",
		["description"] = "F-117A",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			[37] = true,
			["NonArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			[6] = true,
			["All"] = true,
			["Bombers"] = true,
			["Refuelable"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [291]
	[292] = 
	{
		["air"] = true,
		["type"] = "F-14A",
		["name"] = "F-14A",
		["category"] = "Plane",
		["description"] = "F-14A",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Fighters"] = true,
			["NonArmoredUnits"] = true,
			[5] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["All"] = true,
			["Planes"] = true,
			["Refuelable"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [292]
	[293] = 
	{
		["air"] = true,
		["type"] = "F-14A-135-GR",
		["name"] = "F-14A-135-GR",
		["category"] = "Plane",
		["description"] = "F-14A-135-GR",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Fighters"] = true,
			["NonArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			[279] = true,
			["All"] = true,
			["Datalink"] = true,
			["Refuelable"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [293]
	[294] = 
	{
		["air"] = true,
		["type"] = "F-14B",
		["name"] = "F-14B",
		["category"] = "Plane",
		["description"] = "F-14B",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Fighters"] = true,
			[278] = true,
			["Refuelable"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			["All"] = true,
			["Datalink"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [294]
	[295] = 
	{
		["air"] = true,
		["type"] = "F-15C",
		["name"] = "F-15C",
		["category"] = "Plane",
		["description"] = "F-15C",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Fighters"] = true,
			["Refuelable"] = true,
			["Link16"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			[6] = true,
			["All"] = true,
			["Datalink"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [295]
	[296] = 
	{
		["air"] = true,
		["type"] = "F-15E",
		["name"] = "F-15E",
		["category"] = "Plane",
		["description"] = "F-15E",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Fighters"] = true,
			["Refuelable"] = true,
			["Link16"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Datalink"] = true,
			[59] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [296]
	[297] = 
	{
		["air"] = true,
		["type"] = "F-16A",
		["name"] = "F-16A",
		["category"] = "Plane",
		["description"] = "F-16A",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			[52] = true,
			["Refuelable"] = true,
			["Multirole fighters"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [297]
	[298] = 
	{
		["air"] = true,
		["type"] = "F-16A MLU",
		["name"] = "F-16A MLU",
		["category"] = "Plane",
		["description"] = "F-16A MLU",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			[52] = true,
			["Refuelable"] = true,
			["Multirole fighters"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [298]
	[299] = 
	{
		["air"] = true,
		["type"] = "F-16C bl.50",
		["name"] = "F-16C bl.50",
		["category"] = "Plane",
		["description"] = "F-16C bl.50",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			[7] = true,
			["Refuelable"] = true,
			["Link16"] = true,
			["Multirole fighters"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			["All"] = true,
			["Datalink"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [299]
	[300] = 
	{
		["air"] = true,
		["type"] = "F-16C bl.52d",
		["name"] = "F-16C bl.52d",
		["category"] = "Plane",
		["description"] = "F-16C bl.52d",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			[7] = true,
			["Refuelable"] = true,
			["Link16"] = true,
			["Multirole fighters"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			["All"] = true,
			["Datalink"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [300]
	[301] = 
	{
		["air"] = true,
		["type"] = "F-16C_50",
		["name"] = "F-16CM bl.50",
		["category"] = "Plane",
		["description"] = "F-16CM bl.50",
		["attribute"] = 
		{
			[1] = true,
			[275] = true,
			["Refuelable"] = true,
			["Link16"] = true,
			["Multirole fighters"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			["Air"] = true,
			["All"] = true,
			["Datalink"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [301]
	[302] = 
	{
		["air"] = true,
		["type"] = "F-4E",
		["name"] = "F-4E",
		["category"] = "Plane",
		["description"] = "F-4E",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			[45] = true,
			["Multirole fighters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [302]
	[303] = 
	{
		["air"] = true,
		["type"] = "F-5E",
		["name"] = "F-5E",
		["category"] = "Plane",
		["description"] = "F-5E",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Fighters"] = true,
			["NonAndLightArmoredUnits"] = true,
			[46] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Battle airplanes"] = true,
			["Planes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [303]
	[304] = 
	{
		["air"] = true,
		["type"] = "F-5E-3",
		["name"] = "F-5E-3",
		["category"] = "Plane",
		["description"] = "F-5E-3",
		["attribute"] = 
		{
			[1] = true,
			[276] = true,
			["Fighters"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["Air"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [304]
	[305] = 
	{
		["air"] = true,
		["type"] = "F-86F Sabre",
		["name"] = "F-86F",
		["category"] = "Plane",
		["description"] = "F-86F",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			[277] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Battle airplanes"] = true,
			["Planes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [305]
	[306] = 
	{
		["air"] = true,
		["type"] = "F/A-18A",
		["name"] = "F/A-18A",
		["category"] = "Plane",
		["description"] = "F/A-18A",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			[14] = true,
			["Refuelable"] = true,
			["Multirole fighters"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [306]
	[307] = 
	{
		["air"] = true,
		["type"] = "F/A-18C",
		["name"] = "F/A-18C",
		["category"] = "Plane",
		["description"] = "F/A-18C",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Refuelable"] = true,
			["Link16"] = true,
			["Multirole fighters"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			[53] = true,
			["Planes"] = true,
			["All"] = true,
			["Datalink"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [307]
	[308] = 
	{
		["air"] = true,
		["type"] = "FA-18C_hornet",
		["name"] = "F/A-18C Lot 20",
		["category"] = "Plane",
		["description"] = "F/A-18C Lot 20",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Refuelable"] = true,
			[280] = true,
			["Link16"] = true,
			["Multirole fighters"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			["All"] = true,
			["Datalink"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [308]
	[309] = 
	{
		["air"] = true,
		["type"] = "FW-190A8",
		["name"] = "Fw 190 A-8",
		["category"] = "Plane",
		["description"] = "Fw 190 A-8",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			[256] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Battle airplanes"] = true,
			["Planes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [309]
	[310] = 
	{
		["air"] = true,
		["type"] = "FW-190D9",
		["name"] = "Fw 190 D-9",
		["category"] = "Plane",
		["description"] = "Fw 190 D-9",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			[255] = true,
			["Planes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [310]
	[311] = 
	{
		["air"] = true,
		["type"] = "Hawk",
		["name"] = "Hawk",
		["category"] = "Plane",
		["description"] = "Hawk",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			[281] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [311]
	[312] = 
	{
		["air"] = true,
		["type"] = "Hercules",
		["name"] = "Hercules",
		["category"] = "Plane",
		["description"] = "Hercules",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Planes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["Transports"] = true,
			["All"] = true,
			[5] = true,
			[294] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [312]
	[313] = 
	{
		["air"] = true,
		["type"] = "I-16",
		["name"] = "I-16",
		["category"] = "Plane",
		["description"] = "I-16",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			[282] = true,
			["Planes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [313]
	[314] = 
	{
		["air"] = true,
		["type"] = "IL-76MD",
		["name"] = "IL-76MD",
		["category"] = "Plane",
		["description"] = "IL-76MD",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Planes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["Transports"] = true,
			["All"] = true,
			[5] = true,
			[30] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [314]
	[315] = 
	{
		["air"] = true,
		["type"] = "IL-78M",
		["name"] = "IL-78M",
		["category"] = "Plane",
		["description"] = "IL-78M",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Tankers"] = true,
			[28] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			[5] = true,
			["NonAndLightArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [315]
	[316] = 
	{
		["air"] = true,
		["type"] = "J-11A",
		["name"] = "J-11A",
		["category"] = "Plane",
		["description"] = "J-11A",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			[66] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["Fighters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [316]
	[317] = 
	{
		["air"] = true,
		["type"] = "JF-17",
		["name"] = "JF-17",
		["category"] = "Plane",
		["description"] = "JF-17",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Refuelable"] = true,
			["Link16"] = true,
			["Multirole fighters"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			[271] = true,
			["Planes"] = true,
			["All"] = true,
			["Datalink"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [317]
	[318] = 
	{
		["air"] = true,
		["type"] = "KC130",
		["name"] = "KC-130",
		["category"] = "Plane",
		["description"] = "KC-130",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Tankers"] = true,
			["Refuelable"] = true,
			[267] = true,
			[5] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [318]
	[319] = 
	{
		["air"] = true,
		["type"] = "KC-135",
		["name"] = "KC-135",
		["category"] = "Plane",
		["description"] = "KC-135",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Tankers"] = true,
			["NonArmoredUnits"] = true,
			[60] = true,
			[5] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["Refuelable"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [319]
	[320] = 
	{
		["air"] = true,
		["type"] = "KC135MPRS",
		["name"] = "KC-135MPRS",
		["category"] = "Plane",
		["description"] = "KC-135MPRS",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Tankers"] = true,
			["Refuelable"] = true,
			[268] = true,
			[5] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [320]
	[321] = 
	{
		["air"] = true,
		["type"] = "KJ-2000",
		["name"] = "KJ-2000",
		["category"] = "Plane",
		["description"] = "KJ-2000",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			["AWACS"] = true,
			[5] = true,
			["NonAndLightArmoredUnits"] = true,
			[272] = true,
			["All"] = true,
			["Datalink"] = true,
			["Planes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [321]
	[322] = 
	{
		["air"] = true,
		["type"] = "L-39C",
		["name"] = "L-39C",
		["category"] = "Plane",
		["description"] = "L-39C",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			[283] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			[6] = true,
			["Planes"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [322]
	[323] = 
	{
		["air"] = true,
		["type"] = "L-39ZA",
		["name"] = "L-39ZA",
		["category"] = "Plane",
		["description"] = "L-39ZA",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			[6] = true,
			["All"] = true,
			["Planes"] = true,
			[61] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [323]
	[324] = 
	{
		["air"] = true,
		["type"] = "M-2000C",
		["name"] = "M-2000C",
		["category"] = "Plane",
		["description"] = "M-2000C",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			["Multirole fighters"] = true,
			[284] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["All"] = true,
			["Planes"] = true,
			["Refuelable"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [324]
	[325] = 
	{
		["air"] = true,
		["type"] = "MiG-15bis",
		["name"] = "MiG-15bis",
		["category"] = "Plane",
		["description"] = "MiG-15bis",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			[286] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [325]
	[326] = 
	{
		["air"] = true,
		["type"] = "MiG-19P",
		["name"] = "MiG-19P",
		["category"] = "Plane",
		["description"] = "MiG-19P",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Fighters"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battle airplanes"] = true,
			[287] = true,
			["All"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [326]
	[327] = 
	{
		["air"] = true,
		["type"] = "MiG-21Bis",
		["name"] = "MiG-21Bis",
		["category"] = "Plane",
		["description"] = "MiG-21Bis",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Fighters"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["NonArmoredUnits"] = true,
			[288] = true,
			["Planes"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [327]
	[328] = 
	{
		["air"] = true,
		["type"] = "MiG-23MLD",
		["name"] = "MiG-23MLD",
		["category"] = "Plane",
		["description"] = "MiG-23MLD",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Fighters"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Battle airplanes"] = true,
			["Planes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [328]
	[329] = 
	{
		["air"] = true,
		["type"] = "MiG-25PD",
		["name"] = "MiG-25PD",
		["category"] = "Plane",
		["description"] = "MiG-25PD",
		["attribute"] = 
		{
			[1] = true,
			[24] = true,
			["Interceptors"] = true,
			["NonArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			[3] = true,
			["Planes"] = true,
			["Air"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [329]
	[330] = 
	{
		["air"] = true,
		["type"] = "MiG-25RBT",
		["name"] = "MiG-25RBT",
		["category"] = "Plane",
		["description"] = "MiG-25RBT",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Planes"] = true,
			[8] = true,
			[3] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Aux"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [330]
	[331] = 
	{
		["air"] = true,
		["type"] = "MiG-27K",
		["name"] = "MiG-27K",
		["category"] = "Plane",
		["description"] = "MiG-27K",
		["attribute"] = 
		{
			[1] = true,
			[11] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Air"] = true,
			["Bombers"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [331]
	[332] = 
	{
		["air"] = true,
		["type"] = "MiG-29A",
		["name"] = "MiG-29A",
		["category"] = "Plane",
		["description"] = "MiG-29A",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Air"] = true,
			["Fighters"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Battle airplanes"] = true,
			["Planes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [332]
	[333] = 
	{
		["air"] = true,
		["type"] = "MiG-29G",
		["name"] = "MiG-29G",
		["category"] = "Plane",
		["description"] = "MiG-29G",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Fighters"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			[49] = true,
			["Planes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [333]
	[334] = 
	{
		["air"] = true,
		["type"] = "MiG-29K",
		["name"] = "MiG-29K",
		["category"] = "Plane",
		["description"] = "MiG-29K",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			["Multirole fighters"] = true,
			[32] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["Refuelable"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [334]
	[335] = 
	{
		["air"] = true,
		["type"] = "MiG-29S",
		["name"] = "MiG-29S",
		["category"] = "Plane",
		["description"] = "MiG-29S",
		["attribute"] = 
		{
			[1] = true,
			[50] = true,
			["Fighters"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["Air"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [335]
	[336] = 
	{
		["air"] = true,
		["type"] = "MiG-31",
		["name"] = "MiG-31",
		["category"] = "Plane",
		["description"] = "MiG-31",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Interceptors"] = true,
			["Refuelable"] = true,
			[9] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			[3] = true,
			["All"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [336]
	[337] = 
	{
		["air"] = true,
		["type"] = "Mirage 2000-5",
		["name"] = "Mirage 2000-5",
		["category"] = "Plane",
		["description"] = "Mirage 2000-5",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Refuelable"] = true,
			["Link16"] = true,
			["Multirole fighters"] = true,
			[34] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["Planes"] = true,
			["All"] = true,
			["Datalink"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [337]
	[338] = 
	{
		["air"] = true,
		["type"] = "RQ-1A Predator",
		["name"] = "MQ-1A Predator",
		["category"] = "Plane",
		["description"] = "MQ-1A Predator",
		["attribute"] = 
		{
			[1] = true,
			["UAVs"] = true,
			["Planes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			[55] = true,
			[6] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [338]
	[339] = 
	{
		["air"] = true,
		["type"] = "MQ-9 Reaper",
		["name"] = "MQ-9 Reaper",
		["category"] = "Plane",
		["description"] = "MQ-9 Reaper",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["UAVs"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			[285] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [339]
	[340] = 
	{
		["air"] = true,
		["type"] = "P-47D-30",
		["name"] = "P-47D-30",
		["category"] = "Plane",
		["description"] = "P-47D-30",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			[260] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [340]
	[341] = 
	{
		["air"] = true,
		["type"] = "P-47D-30bl1",
		["name"] = "P-47D-30 (Early)",
		["category"] = "Plane",
		["description"] = "P-47D-30 (Early)",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			[261] = true,
			["Planes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [341]
	[342] = 
	{
		["air"] = true,
		["type"] = "P-47D-40",
		["name"] = "P-47D-40",
		["category"] = "Plane",
		["description"] = "P-47D-40",
		["attribute"] = 
		{
			[1] = true,
			[262] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["Air"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [342]
	[343] = 
	{
		["air"] = true,
		["type"] = "P-51D",
		["name"] = "P-51D-25-NA",
		["category"] = "Plane",
		["description"] = "P-51D-25-NA",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			[63] = true,
			["Planes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [343]
	[344] = 
	{
		["air"] = true,
		["type"] = "P-51D-30-NA",
		["name"] = "P-51D-30-NA",
		["category"] = "Plane",
		["description"] = "P-51D-30-NA",
		["attribute"] = 
		{
			[1] = true,
			[64] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["Air"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [344]
	[345] = 
	{
		["air"] = true,
		["type"] = "S-3B",
		["name"] = "S-3B",
		["category"] = "Plane",
		["description"] = "S-3B",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Planes"] = true,
			["NonAndLightArmoredUnits"] = true,
			[5] = true,
			["NonArmoredUnits"] = true,
			["Aux"] = true,
			[42] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [345]
	[346] = 
	{
		["air"] = true,
		["type"] = "S-3B Tanker",
		["name"] = "S-3B Tanker",
		["category"] = "Plane",
		["description"] = "S-3B Tanker",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			[33] = true,
			["Refuelable"] = true,
			["Aux"] = true,
			[5] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			["All"] = true,
			["NonArmoredUnits"] = true,
			["Tankers"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [346]
	[347] = 
	{
		["air"] = true,
		["type"] = "SpitfireLFMkIX",
		["name"] = "Spitfire LF Mk. IX",
		["category"] = "Plane",
		["description"] = "Spitfire LF Mk. IX",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			[258] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [347]
	[348] = 
	{
		["air"] = true,
		["type"] = "SpitfireLFMkIXCW",
		["name"] = "Spitfire LF Mk. IX CW",
		["category"] = "Plane",
		["description"] = "Spitfire LF Mk. IX CW",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			[259] = true,
			["All"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [348]
	[349] = 
	{
		["air"] = true,
		["type"] = "Su-17M4",
		["name"] = "Su-17M4",
		["category"] = "Plane",
		["description"] = "Su-17M4",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battle airplanes"] = true,
			["Bombers"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["NonAndLightArmoredUnits"] = true,
			[48] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [349]
	[350] = 
	{
		["air"] = true,
		["type"] = "Su-24M",
		["name"] = "Su-24M",
		["category"] = "Plane",
		["description"] = "Su-24M",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Refuelable"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			["Bombers"] = true,
			["All"] = true,
			[12] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [350]
	[351] = 
	{
		["air"] = true,
		["type"] = "Su-24MR",
		["name"] = "Su-24MR",
		["category"] = "Plane",
		["description"] = "Su-24MR",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			[51] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			["Refuelable"] = true,
			["All"] = true,
			["NonArmoredUnits"] = true,
			["Aux"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [351]
	[352] = 
	{
		["air"] = true,
		["type"] = "Su-25",
		["name"] = "Su-25",
		["category"] = "Plane",
		["description"] = "Su-25",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			[16] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			[6] = true,
			["Planes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [352]
	[353] = 
	{
		["air"] = true,
		["type"] = "Su-25T",
		["name"] = "Su-25T",
		["category"] = "Plane",
		["description"] = "Su-25T",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			[6] = true,
			["All"] = true,
			["Planes"] = true,
			[54] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [353]
	[354] = 
	{
		["air"] = true,
		["type"] = "Su-25TM",
		["name"] = "Su-25TM",
		["category"] = "Plane",
		["description"] = "Su-25TM",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			[38] = true,
			["All"] = true,
			[6] = true,
			["Planes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [354]
	[355] = 
	{
		["air"] = true,
		["type"] = "Su-27",
		["name"] = "Su-27",
		["category"] = "Plane",
		["description"] = "Su-27",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Fighters"] = true,
			["NonAndLightArmoredUnits"] = true,
			[3] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Battle airplanes"] = true,
			["Planes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [355]
	[356] = 
	{
		["air"] = true,
		["type"] = "Su-30",
		["name"] = "Su-30",
		["category"] = "Plane",
		["description"] = "Su-30",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			[13] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["Multirole fighters"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [356]
	[357] = 
	{
		["air"] = true,
		["type"] = "Su-33",
		["name"] = "Su-33",
		["category"] = "Plane",
		["description"] = "Su-33",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Fighters"] = true,
			["NonArmoredUnits"] = true,
			[4] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["Refuelable"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [357]
	[358] = 
	{
		["air"] = true,
		["type"] = "Su-34",
		["name"] = "Su-34",
		["category"] = "Plane",
		["description"] = "Su-34",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			[20] = true,
			["Planes"] = true,
			["All"] = true,
			["Bombers"] = true,
			["Refuelable"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [358]
	[359] = 
	{
		["air"] = true,
		["type"] = "TF-51D",
		["name"] = "TF-51D",
		["category"] = "Plane",
		["description"] = "TF-51D",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Battleplanes"] = true,
			[65] = true,
			["All"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [359]
	[360] = 
	{
		["air"] = true,
		["type"] = "Tornado GR4",
		["name"] = "Tornado GR4",
		["category"] = "Plane",
		["description"] = "Tornado GR4",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Refuelable"] = true,
			["Link16"] = true,
			["Planes"] = true,
			["Battle airplanes"] = true,
			[10] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Bombers"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "Tornado GR3",
		}, -- end of ["aliases"]
	}, -- end of [360]
	[361] = 
	{
		["air"] = true,
		["type"] = "Tornado IDS",
		["name"] = "Tornado IDS",
		["category"] = "Plane",
		["description"] = "Tornado IDS",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			[56] = true,
			["Link16"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Planes"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Bombers"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [361]
	[362] = 
	{
		["air"] = true,
		["type"] = "Tu-142",
		["name"] = "Tu-142",
		["category"] = "Plane",
		["description"] = "Tu-142",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Refuelable"] = true,
			[4] = true,
			["Strategic bombers"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Bombers"] = true,
			["Planes"] = true,
			[22] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [362]
	[363] = 
	{
		["air"] = true,
		["type"] = "Tu-160",
		["name"] = "Tu-160",
		["category"] = "Plane",
		["description"] = "Tu-160",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Air"] = true,
			["NonArmoredUnits"] = true,
			["Strategic bombers"] = true,
			[18] = true,
			["NonAndLightArmoredUnits"] = true,
			["Bombers"] = true,
			["Battle airplanes"] = true,
			["All"] = true,
			["Planes"] = true,
			["Refuelable"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [363]
	[364] = 
	{
		["air"] = true,
		["type"] = "Tu-22M3",
		["name"] = "Tu-22M3",
		["category"] = "Plane",
		["description"] = "Tu-22M3",
		["attribute"] = 
		{
			[1] = true,
			[2] = true,
			["Air"] = true,
			["Battle airplanes"] = true,
			["Bombers"] = true,
			[25] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			["NonAndLightArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [364]
	[365] = 
	{
		["air"] = true,
		["type"] = "Tu-95MS",
		["name"] = "Tu-95MS",
		["category"] = "Plane",
		["description"] = "Tu-95MS",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Refuelable"] = true,
			[4] = true,
			["Strategic bombers"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Bombers"] = true,
			[21] = true,
			["All"] = true,
			["Planes"] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [365]
	[366] = 
	{
		["air"] = true,
		["type"] = "WingLoong-I",
		["name"] = "WingLoong-I",
		["category"] = "Plane",
		["description"] = "WingLoong-I",
		["attribute"] = 
		{
			[1] = true,
			["Air"] = true,
			["Battleplanes"] = true,
			["NonArmoredUnits"] = true,
			["UAVs"] = true,
			["Battle airplanes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["All"] = true,
			["Planes"] = true,
			[273] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [366]
	[367] = 
	{
		["air"] = true,
		["type"] = "Yak-40",
		["name"] = "Yak-40",
		["category"] = "Plane",
		["description"] = "Yak-40",
		["attribute"] = 
		{
			[1] = true,
			[57] = true,
			["Planes"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Air"] = true,
			["Transports"] = true,
			["All"] = true,
			[5] = true,
			["NonArmoredUnits"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [367]
	[368] = 
	{
		["air"] = true,
		["type"] = "Yak-52",
		["name"] = "Yak-52",
		["category"] = "Plane",
		["description"] = "Yak-52",
		["attribute"] = 
		{
			[1] = true,
			["UAVs"] = true,
			["Planes"] = true,
			["NonAndLightArmoredUnits"] = true,
			[293] = true,
			["NonArmoredUnits"] = true,
			["All"] = true,
			[5] = true,
			["Air"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [368]
	[369] = 
	{
		["type"] = "speedboat",
		["name"] = "Armed speedboat",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "Armed speedboat",
		["attribute"] = 
		{
			["Light armed ships"] = true,
			[14] = true,
			["NonArmoredUnits"] = true,
			["Ships"] = true,
			["Armed Ship"] = true,
			["Armed ships"] = true,
			["All"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NO_SAM"] = true,
			[3] = true,
			[6] = true,
			["low_reflection_vessel"] = true,
			[12] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [369]
	[370] = 
	{
		["type"] = "Dry-cargo ship-1",
		["name"] = "Bulk cargo ship Yakushev",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "Bulk cargo ship Yakushev",
		["attribute"] = 
		{
			["HeavyArmoredUnits"] = true,
			["Ships"] = true,
			[15] = true,
			[3] = true,
			[12] = true,
			["All"] = true,
			[5] = true,
			["Unarmed ships"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [370]
	[371] = 
	{
		["type"] = "MOSCOW",
		["name"] = "CG 1164 Moskva",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "CG 1164 Moskva",
		["attribute"] = 
		{
			[13] = true,
			["Heavy armed ships"] = true,
			["HeavyArmoredUnits"] = true,
			["Ships"] = true,
			["Armed Air Defence"] = true,
			["Armed ships"] = true,
			["Cruisers"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["HelicopterCarrier"] = true,
			["Armed Ship"] = true,
			[3] = true,
			["All"] = true,
			["DetectionByAWACS"] = true,
			[12] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [371]
	[372] = 
	{
		["type"] = "PIOTR",
		["name"] = "CGN 1144.2 Pyotr Velikiy",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "CGN 1144.2 Pyotr Velikiy",
		["attribute"] = 
		{
			["Heavy armed ships"] = true,
			["HeavyArmoredUnits"] = true,
			[14] = true,
			["Armed Air Defence"] = true,
			["Ships"] = true,
			["Armed ships"] = true,
			["HelicopterCarrier"] = true,
			["Cruisers"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			[19] = true,
			["Armed Ship"] = true,
			[3] = true,
			["All"] = true,
			["DetectionByAWACS"] = true,
			[12] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [372]
	[373] = 
	{
		["type"] = "ZWEZDNY",
		["name"] = "Civil boat Zvezdny",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "Civil boat Zvezdny",
		["attribute"] = 
		{
			[15] = true,
			["Unarmed ships"] = true,
			[5] = true,
			["HeavyArmoredUnits"] = true,
			["Ships"] = true,
			[3] = true,
			["All"] = true,
			["low_reflection_vessel"] = true,
			[12] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [373]
	[374] = 
	{
		["type"] = "KUZNECOW",
		["name"] = "CV 1143.5 Admiral Kuznetsov",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "CV 1143.5 Admiral Kuznetsov",
		["attribute"] = 
		{
			[1] = true,
			["Aircraft Carriers"] = true,
			["AircraftCarrier With Tramplin"] = true,
			["AircraftCarrier"] = true,
			["Ships"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["DetectionByAWACS"] = true,
			["ski_jump"] = true,
			[3] = true,
			[12] = true,
			["Heavy armed ships"] = true,
			["Arresting Gear"] = true,
			["Straight_in_approach_type"] = true,
			["Armed Ship"] = true,
			["HeavyArmoredUnits"] = true,
			["All"] = true,
			["Armed Air Defence"] = true,
			["Armed ships"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [374]
	[375] = 
	{
		["type"] = "CV_1143_5",
		["name"] = "CV 1143.5 Admiral Kuznetsov(2017)",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "CV 1143.5 Admiral Kuznetsov(2017)",
		["attribute"] = 
		{
			[255] = true,
			["Aircraft Carriers"] = true,
			["AircraftCarrier With Tramplin"] = true,
			["AircraftCarrier"] = true,
			["Ships"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["DetectionByAWACS"] = true,
			["ski_jump"] = true,
			[3] = true,
			[12] = true,
			["Heavy armed ships"] = true,
			["Straight_in_approach_type"] = true,
			["Armed Air Defence"] = true,
			["Armed Ship"] = true,
			["HeavyArmoredUnits"] = true,
			["All"] = true,
			["Arresting Gear"] = true,
			["Armed ships"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [375]
	[376] = 
	{
		["type"] = "VINSON",
		["name"] = "CVN-70 Carl Vinson",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "CVN-70 Carl Vinson",
		["attribute"] = 
		{
			[2] = true,
			["Aircraft Carriers"] = true,
			["AircraftCarrier"] = true,
			["Ships"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			[3] = true,
			[12] = true,
			["AircraftCarrier With Catapult"] = true,
			["Heavy armed ships"] = true,
			["Armed ships"] = true,
			["Armed Air Defence"] = true,
			["Armed Ship"] = true,
			["HeavyArmoredUnits"] = true,
			["All"] = true,
			["catapult"] = true,
			["Arresting Gear"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [376]
	[377] = 
	{
		["type"] = "CVN_71",
		["name"] = "CVN-71 Theodore Roosevelt",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "CVN-71 Theodore Roosevelt",
		["attribute"] = 
		{
			["Aircraft Carriers"] = true,
			["AircraftCarrier"] = true,
			["Ships"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			[3] = true,
			[12] = true,
			["AircraftCarrier With Catapult"] = true,
			["Heavy armed ships"] = true,
			["HeavyArmoredUnits"] = true,
			["Arresting Gear"] = true,
			["Armed Air Defence"] = true,
			["Armed Ship"] = true,
			[261] = true,
			["All"] = true,
			["catapult"] = true,
			["Armed ships"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [377]
	[378] = 
	{
		["type"] = "CVN_72",
		["name"] = "CVN-72 Abraham Lincoln",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "CVN-72 Abraham Lincoln",
		["attribute"] = 
		{
			[262] = true,
			["Aircraft Carriers"] = true,
			["AircraftCarrier"] = true,
			["Ships"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			[3] = true,
			[12] = true,
			["AircraftCarrier With Catapult"] = true,
			["Heavy armed ships"] = true,
			["Armed ships"] = true,
			["Armed Air Defence"] = true,
			["Armed Ship"] = true,
			["HeavyArmoredUnits"] = true,
			["All"] = true,
			["catapult"] = true,
			["Arresting Gear"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [378]
	[379] = 
	{
		["type"] = "CVN_73",
		["name"] = "CVN-73 George Washington",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "CVN-73 George Washington",
		["attribute"] = 
		{
			["Aircraft Carriers"] = true,
			["AircraftCarrier"] = true,
			["Ships"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			[3] = true,
			[12] = true,
			["AircraftCarrier With Catapult"] = true,
			["Heavy armed ships"] = true,
			["Arresting Gear"] = true,
			["Armed Air Defence"] = true,
			[263] = true,
			["Armed Ship"] = true,
			["HeavyArmoredUnits"] = true,
			["All"] = true,
			["catapult"] = true,
			["Armed ships"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [379]
	[380] = 
	{
		["type"] = "Stennis",
		["name"] = "CVN-74 John C. Stennis",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "CVN-74 John C. Stennis",
		["attribute"] = 
		{
			["Aircraft Carriers"] = true,
			["AircraftCarrier"] = true,
			["Ships"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			[3] = true,
			[12] = true,
			["AircraftCarrier With Catapult"] = true,
			["Heavy armed ships"] = true,
			[260] = true,
			["Arresting Gear"] = true,
			["Armed Air Defence"] = true,
			["Armed Ship"] = true,
			["HeavyArmoredUnits"] = true,
			["All"] = true,
			["catapult"] = true,
			["Armed ships"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [380]
	[381] = 
	{
		["type"] = "CVN_75",
		["name"] = "CVN-75 Harry S. Truman",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "CVN-75 Harry S. Truman",
		["attribute"] = 
		{
			["Aircraft Carriers"] = true,
			["AircraftCarrier"] = true,
			["Ships"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			[3] = true,
			[12] = true,
			["AircraftCarrier With Catapult"] = true,
			["Heavy armed ships"] = true,
			[264] = true,
			["Armed Air Defence"] = true,
			["Armed ships"] = true,
			["Armed Ship"] = true,
			["HeavyArmoredUnits"] = true,
			["All"] = true,
			["catapult"] = true,
			["Arresting Gear"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [381]
	[382] = 
	{
		["type"] = "Dry-cargo ship-2",
		["name"] = "Dry cargo ship Ivanov",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "Dry cargo ship Ivanov",
		["attribute"] = 
		{
			["HeavyArmoredUnits"] = true,
			["Ships"] = true,
			[15] = true,
			[3] = true,
			[12] = true,
			["All"] = true,
			[5] = true,
			["Unarmed ships"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [382]
	[383] = 
	{
		["type"] = "REZKY",
		["name"] = "FF 1135M Rezky",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "FF 1135M Rezky",
		["attribute"] = 
		{
			[14] = true,
			["Ships"] = true,
			["Frigates"] = true,
			["Heavy armed ships"] = true,
			["HeavyArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["Armed ships"] = true,
			["Armed Ship"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			["All"] = true,
			[12] = true,
			[3] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [383]
	[384] = 
	{
		["type"] = "NEUSTRASH",
		["name"] = "FFG 11540 Neustrashimy",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "FFG 11540 Neustrashimy",
		["attribute"] = 
		{
			["Heavy armed ships"] = true,
			[14] = true,
			[28] = true,
			["Ships"] = true,
			["Frigates"] = true,
			["HeavyArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["HelicopterCarrier"] = true,
			["Armed Ship"] = true,
			[3] = true,
			["All"] = true,
			[12] = true,
			["Armed ships"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [384]
	[385] = 
	{
		["type"] = "ALBATROS",
		["name"] = "FFL 1124.4 Grisha",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "FFL 1124.4 Grisha",
		["attribute"] = 
		{
			[14] = true,
			["Heavy armed ships"] = true,
			["Ships"] = true,
			["Frigates"] = true,
			["HeavyArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["Armed ships"] = true,
			[11] = true,
			["Armed Ship"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			["All"] = true,
			[12] = true,
			[3] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [385]
	[386] = 
	{
		["type"] = "MOLNIYA",
		["name"] = "FSG 1241.1MP Molniya",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "FSG 1241.1MP Molniya",
		["attribute"] = 
		{
			["Heavy armed ships"] = true,
			[14] = true,
			["HeavyArmoredUnits"] = true,
			[15] = true,
			["Armed Air Defence"] = true,
			["Armed ships"] = true,
			["Ships"] = true,
			[12] = true,
			["Armed Ship"] = true,
			["NO_SAM"] = true,
			[3] = true,
			["All"] = true,
			["DetectionByAWACS"] = true,
			["Corvettes"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [386]
	[387] = 
	{
		["type"] = "LHA_Tarawa",
		["name"] = "LHA-1 Tarawa",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "LHA-1 Tarawa",
		["attribute"] = 
		{
			["Aircraft Carriers"] = true,
			["AircraftCarrier With Tramplin"] = true,
			["AircraftCarrier"] = true,
			["Ships"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			[265] = true,
			["DetectionByAWACS"] = true,
			["ski_jump"] = true,
			[3] = true,
			[12] = true,
			["Heavy armed ships"] = true,
			["Armed Ship"] = true,
			["HeavyArmoredUnits"] = true,
			["All"] = true,
			["Armed Air Defence"] = true,
			["Armed ships"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [387]
	[388] = 
	{
		["type"] = "PERRY",
		["name"] = "Oliver Hazzard Perry class",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "Oliver Hazzard Perry class",
		["attribute"] = 
		{
			["Heavy armed ships"] = true,
			["HeavyArmoredUnits"] = true,
			[14] = true,
			["Armed Air Defence"] = true,
			["Ships"] = true,
			["Frigates"] = true,
			["Armed ships"] = true,
			[17] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["HelicopterCarrier"] = true,
			["Armed Ship"] = true,
			[3] = true,
			["All"] = true,
			[12] = true,
			["DetectionByAWACS"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [388]
	[389] = 
	{
		["type"] = "SOM",
		["name"] = "SSK 641B",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "SSK 641B",
		["attribute"] = 
		{
			[24] = true,
			["Submarines"] = true,
			["Ships"] = true,
			[16] = true,
			["Heavy armed ships"] = true,
			["HeavyArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["NO_SAM"] = true,
			[3] = true,
			["All"] = true,
			[12] = true,
			["Armed ships"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [389]
	[390] = 
	{
		["type"] = "KILO",
		["name"] = "SSK 877",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "SSK 877",
		["attribute"] = 
		{
			["Submarines"] = true,
			["Ships"] = true,
			["Heavy armed ships"] = true,
			[16] = true,
			["HeavyArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["Armed ships"] = true,
			["NO_SAM"] = true,
			[3] = true,
			["All"] = true,
			[23] = true,
			[12] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [390]
	[391] = 
	{
		["type"] = "ELNYA",
		["name"] = "Tanker Elnya 160",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "Tanker Elnya 160",
		["attribute"] = 
		{
			["HeavyArmoredUnits"] = true,
			["Ships"] = true,
			[15] = true,
			[3] = true,
			[12] = true,
			["All"] = true,
			[5] = true,
			["Unarmed ships"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [391]
	[392] = 
	{
		["type"] = "TICONDEROG",
		["name"] = "Ticonderoga class",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "Ticonderoga class",
		["attribute"] = 
		{
			["Heavy armed ships"] = true,
			["HeavyArmoredUnits"] = true,
			[14] = true,
			["Armed Air Defence"] = true,
			["Ships"] = true,
			["Armed ships"] = true,
			[21] = true,
			["Cruisers"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["HelicopterCarrier"] = true,
			["Armed Ship"] = true,
			[3] = true,
			["All"] = true,
			["DetectionByAWACS"] = true,
			[12] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [392]
	[393] = 
	{
		["type"] = "Type_052B",
		["name"] = "Type 052B Destroyer",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "Type 052B Destroyer",
		["attribute"] = 
		{
			["Heavy armed ships"] = true,
			[13] = true,
			["HeavyArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["Armed ships"] = true,
			["Ships"] = true,
			[266] = true,
			[3] = true,
			["HelicopterCarrier"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["Destroyers"] = true,
			["Armed Ship"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			["All"] = true,
			[12] = true,
			["DetectionByAWACS"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [393]
	[394] = 
	{
		["type"] = "Type_052C",
		["name"] = "Type 052C Destroyer",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "Type 052C Destroyer",
		["attribute"] = 
		{
			["Heavy armed ships"] = true,
			[13] = true,
			["HeavyArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["Armed ships"] = true,
			["Ships"] = true,
			["DetectionByAWACS"] = true,
			["Cruisers"] = true,
			[268] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["HelicopterCarrier"] = true,
			["Armed Ship"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			["All"] = true,
			[12] = true,
			[3] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [394]
	[395] = 
	{
		["type"] = "Type_054A",
		["name"] = "Type 054A Frigate",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "Type 054A Frigate",
		["attribute"] = 
		{
			["Heavy armed ships"] = true,
			[13] = true,
			["HeavyArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["Armed ships"] = true,
			["Ships"] = true,
			["Frigates"] = true,
			[267] = true,
			["DetectionByAWACS"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["HelicopterCarrier"] = true,
			["Armed Ship"] = true,
			[3] = true,
			["All"] = true,
			[12] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [395]
	[396] = 
	{
		["type"] = "Type_071",
		["name"] = "Type 071 Amphibious Transport Dock",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "Type 071 Amphibious Transport Dock",
		["attribute"] = 
		{
			[270] = true,
			["AircraftCarrier With Tramplin"] = true,
			["AircraftCarrier"] = true,
			["Ships"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["NO_SAM"] = true,
			["RADAR_BAND2_FOR_ARM"] = true,
			["DetectionByAWACS"] = true,
			[3] = true,
			[12] = true,
			["Heavy armed ships"] = true,
			["Armed ships"] = true,
			["Armed Air Defence"] = true,
			["Armed Ship"] = true,
			["HeavyArmoredUnits"] = true,
			["All"] = true,
			["Aircraft Carriers"] = true,
			["Straight_in_approach_type"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [396]
	[397] = 
	{
		["type"] = "Type_093",
		["name"] = "Type 093 Attack Submarine",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "Type 093 Attack Submarine",
		["attribute"] = 
		{
			["Heavy armed ships"] = true,
			["Submarines"] = true,
			["HeavyArmoredUnits"] = true,
			["Armed Air Defence"] = true,
			["Ships"] = true,
			["Armed ships"] = true,
			[16] = true,
			[269] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["Armed Ship"] = true,
			["NO_SAM"] = true,
			[3] = true,
			["All"] = true,
			["DetectionByAWACS"] = true,
			[12] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [397]
	[398] = 
	{
		["type"] = "USS_Arleigh_Burke_IIa",
		["name"] = "USS Arleigh Burke IIa",
		["category"] = "Ship",
		["naval"] = true,
		["description"] = "USS Arleigh Burke IIa",
		["attribute"] = 
		{
			["Heavy armed ships"] = true,
			["HeavyArmoredUnits"] = true,
			[14] = true,
			["Armed Air Defence"] = true,
			["Ships"] = true,
			["Armed ships"] = true,
			[21] = true,
			["Cruisers"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
			["HelicopterCarrier"] = true,
			["Armed Ship"] = true,
			[3] = true,
			["All"] = true,
			["DetectionByAWACS"] = true,
			[12] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [398]
	[399] = 
	{
		["type"] = "Hummer",
		["name"] = "APC M1025 HMMWV",
		["category"] = "Unarmed",
		["description"] = "APC M1025 HMMWV",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["human_vehicle"] = true,
			["Infantry carriers"] = true,
			[25] = true,
			["LightArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			[14] = true,
			["Armed vehicles"] = true,
			["All"] = true,
			["Datalink"] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "M1025 HMMWV",
		}, -- end of ["aliases"]
	}, -- end of [399]
	[400] = 
	{
		["type"] = "Tigr_233036",
		["name"] = "APC Tigr 233036",
		["category"] = "Unarmed",
		["description"] = "APC Tigr 233036",
		["vehicle"] = true,
		["attribute"] = 
		{
			[2] = true,
			["Vehicles"] = true,
			["Armored vehicles"] = true,
			["AntiAir Armed Vehicles"] = true,
			[17] = true,
			["Ground vehicles"] = true,
			[10] = true,
			["Armed ground units"] = true,
			["APC"] = true,
			["Ground Units Non Airdefence"] = true,
			["human_vehicle"] = true,
			["Infantry carriers"] = true,
			[25] = true,
			["NonAndLightArmoredUnits"] = true,
			["LightArmoredUnits"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Armed vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [400]
	[401] = 
	{
		["type"] = "Bedford_MWD",
		["name"] = "Bedford MWD",
		["category"] = "Unarmed",
		["description"] = "Bedford MWD",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[6] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [401]
	[402] = 
	{
		["type"] = "Blitz_36-6700A",
		["name"] = "Blitz 3.6-6700A",
		["category"] = "Unarmed",
		["description"] = "Blitz 3.6-6700A",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[6] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [402]
	[403] = 
	{
		["type"] = "Predator GCS",
		["name"] = "CP Predator GCS",
		["category"] = "Unarmed",
		["description"] = "CP Predator GCS",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["CustomAimPoint"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[6] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [403]
	[404] = 
	{
		["type"] = "Predator TrojanSpirit",
		["name"] = "CP Predator TrojanSpirit",
		["category"] = "Unarmed",
		["description"] = "CP Predator TrojanSpirit",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[6] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [404]
	[405] = 
	{
		["type"] = "SKP-11",
		["name"] = "CP SKP-11 ATC Mobile Command Post",
		["category"] = "Unarmed",
		["description"] = "CP SKP-11 ATC Mobile Command Post",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[6] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "SKP-11 Mobile Command Post",
		}, -- end of ["aliases"]
	}, -- end of [405]
	[406] = 
	{
		["type"] = "Ural-375 PBU",
		["name"] = "CP Ural-375 PBU",
		["category"] = "Unarmed",
		["description"] = "CP Ural-375 PBU",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			[41] = true,
			["Trucks"] = true,
			[17] = true,
			["Unarmed vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Ground vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [406]
	[407] = 
	{
		["type"] = "ATMZ-5",
		["name"] = "Fuel Truck ATMZ-5",
		["category"] = "Unarmed",
		["description"] = "Fuel Truck ATMZ-5",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			[4] = true,
			["Trucks"] = true,
			[17] = true,
			["Unarmed vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Ground vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [407]
	[408] = 
	{
		["type"] = "ATZ-10",
		["name"] = "Fuel Truck ATZ-10",
		["category"] = "Unarmed",
		["description"] = "Fuel Truck ATZ-10",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			[5] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Ground vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "ATZ-10 Fuel Truck",
		}, -- end of ["aliases"]
	}, -- end of [408]
	[409] = 
	{
		["type"] = "Ural-4320 APA-5D",
		["name"] = "GPU APA-5D on Ural-4320",
		["category"] = "Unarmed",
		["description"] = "GPU APA-5D on Ural-4320",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[6] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "Ural-4320 APA-5D Ground Power Unit",
		}, -- end of ["aliases"]
	}, -- end of [409]
	[410] = 
	{
		["type"] = "ZiL-131 APA-80",
		["name"] = "GPU APA-80 on ZiL-131",
		["category"] = "Unarmed",
		["description"] = "GPU APA-80 on ZiL-131",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[6] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "ZiL-131 APA-80 Ground Power Unit",
		}, -- end of ["aliases"]
	}, -- end of [410]
	[411] = 
	{
		["type"] = "HEMTT TFFT",
		["name"] = "HEMTT TFFT",
		["category"] = "Unarmed",
		["description"] = "HEMTT TFFT",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[6] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [411]
	[412] = 
	{
		["type"] = "Land_Rover_101_FC",
		["name"] = "Land Rover 101 FC",
		["category"] = "Unarmed",
		["description"] = "Land Rover 101 FC",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[6] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [412]
	[413] = 
	{
		["type"] = "Land_Rover_109_S3",
		["name"] = "Land Rover 109 S3",
		["category"] = "Unarmed",
		["description"] = "Land Rover 109 S3",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[6] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [413]
	[414] = 
	{
		["type"] = "Suidae",
		["name"] = "Suidae",
		["category"] = "Unarmed",
		["description"] = "Suidae",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["NonArmoredUnits"] = true,
			[47] = true,
			["NonAndLightArmoredUnits"] = true,
			["Cars"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[17] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [414]
	[415] = 
	{
		["type"] = "M978 HEMTT Tanker",
		["name"] = "Tanker M978 HEMTT",
		["category"] = "Unarmed",
		["description"] = "Tanker M978 HEMTT",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[6] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [415]
	[416] = 
	{
		["type"] = "Ural ATsP-6",
		["name"] = "Transport fire-engine Ural ATsP-6",
		["category"] = "Unarmed",
		["description"] = "Transport fire-engine Ural ATsP-6",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[6] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [416]
	[417] = 
	{
		["type"] = "GAZ-3307",
		["name"] = "Transport GAZ-3307",
		["category"] = "Unarmed",
		["description"] = "Transport GAZ-3307",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			[68] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Ground vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [417]
	[418] = 
	{
		["type"] = "GAZ-3308",
		["name"] = "Transport GAZ-3308",
		["category"] = "Unarmed",
		["description"] = "Transport GAZ-3308",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			[69] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [418]
	[419] = 
	{
		["type"] = "GAZ-66",
		["name"] = "Transport GAZ-66",
		["category"] = "Unarmed",
		["description"] = "Transport GAZ-66",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			[67] = true,
			["Trucks"] = true,
			[17] = true,
			["Unarmed vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Ground vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [419]
	[420] = 
	{
		["type"] = "IKARUS Bus",
		["name"] = "Transport IKARUS-280",
		["category"] = "Unarmed",
		["description"] = "Transport IKARUS-280",
		["vehicle"] = true,
		["attribute"] = 
		{
			[46] = true,
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Trucks"] = true,
			[17] = true,
			["Unarmed vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Ground vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [420]
	[421] = 
	{
		["type"] = "KAMAZ Truck",
		["name"] = "Transport KAMAZ-43101",
		["category"] = "Unarmed",
		["description"] = "Transport KAMAZ-43101",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[57] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "KAMAZ-43101",
		}, -- end of ["aliases"]
	}, -- end of [421]
	[422] = 
	{
		["type"] = "KrAZ6322",
		["name"] = "Transport KrAZ-6322",
		["category"] = "Unarmed",
		["description"] = "Transport KrAZ-6322",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["human_vehicle"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["NonArmoredUnits"] = true,
			["Trucks"] = true,
			[17] = true,
			["Ground Units Non Airdefence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			["Vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[6] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [422]
	[423] = 
	{
		["type"] = "LAZ Bus",
		["name"] = "Transport LAZ-695",
		["category"] = "Unarmed",
		["description"] = "Transport LAZ-695",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			[58] = true,
			["Trucks"] = true,
			[17] = true,
			["Unarmed vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Ground vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [423]
	[424] = 
	{
		["type"] = "M 818",
		["name"] = "Transport M818",
		["category"] = "Unarmed",
		["description"] = "Transport M818",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["NonArmoredUnits"] = true,
			["Trucks"] = true,
			[17] = true,
			["Ground Units Non Airdefence"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground vehicles"] = true,
			[6] = true,
			["All"] = true,
			["Datalink"] = true,
			["Ground Units"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
			[1] = "M818",
		}, -- end of ["aliases"]
	}, -- end of [424]
	[425] = 
	{
		["type"] = "MAZ-6303",
		["name"] = "Transport MAZ-6303",
		["category"] = "Unarmed",
		["description"] = "Transport MAZ-6303",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[70] = true,
			[2] = true,
			["Trucks"] = true,
			[17] = true,
			["Unarmed vehicles"] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Ground vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [425]
	[426] = 
	{
		["type"] = "UAZ-469",
		["name"] = "Transport UAZ-469",
		["category"] = "Unarmed",
		["description"] = "Transport UAZ-469",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["human_vehicle"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			[17] = true,
			["Ground Units Non Airdefence"] = true,
			["Cars"] = true,
			[38] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [426]
	[427] = 
	{
		["type"] = "Ural-375",
		["name"] = "Transport Ural-375",
		["category"] = "Unarmed",
		["description"] = "Transport Ural-375",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			[40] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Ground vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [427]
	[428] = 
	{
		["type"] = "Ural-4320-31",
		["name"] = "Transport Ural-4320-31 Armored",
		["category"] = "Unarmed",
		["description"] = "Transport Ural-4320-31 Armored",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[6] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [428]
	[429] = 
	{
		["type"] = "Ural-4320T",
		["name"] = "Transport Ural-4320T",
		["category"] = "Unarmed",
		["description"] = "Transport Ural-4320T",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[75] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[17] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [429]
	[430] = 
	{
		["type"] = "VAZ Car",
		["name"] = "Transport VAZ-2109",
		["category"] = "Unarmed",
		["description"] = "Transport VAZ-2109",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["NonArmoredUnits"] = true,
			[47] = true,
			["NonAndLightArmoredUnits"] = true,
			["Cars"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[17] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [430]
	[431] = 
	{
		["type"] = "ZIL-131 KUNG",
		["name"] = "Transport ZIL-131 KUNG",
		["category"] = "Unarmed",
		["description"] = "Transport ZIL-131 KUNG",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			[79] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Ground vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [431]
	[432] = 
	{
		["type"] = "ZIL-4331",
		["name"] = "Transport ZIL-4331",
		["category"] = "Unarmed",
		["description"] = "Transport ZIL-4331",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			["NonArmoredUnits"] = true,
			["NonAndLightArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["Ground vehicles"] = true,
			["All"] = true,
			["Ground Units"] = true,
			[71] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [432]
	[433] = 
	{
		["type"] = "Trolley bus",
		["name"] = "Transport ZIU-9",
		["category"] = "Unarmed",
		["description"] = "Transport ZIU-9",
		["vehicle"] = true,
		["attribute"] = 
		{
			[25] = true,
			["Vehicles"] = true,
			[2] = true,
			["Unarmed vehicles"] = true,
			["Trucks"] = true,
			[17] = true,
			[49] = true,
			["NonAndLightArmoredUnits"] = true,
			["NonArmoredUnits"] = true,
			["Ground Units Non Airdefence"] = true,
			["All"] = true,
			["Ground Units"] = true,
			["Ground vehicles"] = true,
		}, -- end of ["attribute"]
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [433]
	[434] = 
	{
		["type"] = ".Ammunition depot",
		["name"] = "Ammunition depot",
		["category"] = "Warehouse",
		["description"] = "Ammunition depot",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [434]
	[435] = 
	{
		["type"] = "Tank",
		["name"] = "Tank 1",
		["category"] = "Warehouse",
		["description"] = "Tank 1",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [435]
	[436] = 
	{
		["type"] = "Tank 2",
		["name"] = "Tank 2",
		["category"] = "Warehouse",
		["description"] = "Tank 2",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [436]
	[437] = 
	{
		["type"] = "Tank 3",
		["name"] = "Tank 3",
		["category"] = "Warehouse",
		["description"] = "Tank 3",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [437]
	[438] = 
	{
		["type"] = "Warehouse",
		["name"] = "Warehouse",
		["category"] = "Warehouse",
		["description"] = "Warehouse",
		["aliases"] = 
		{
		}, -- end of ["aliases"]
	}, -- end of [438]
}

-- appending custom cargoes
function dcsUnits.addCargoUnit( name, displayName, shape, shapeDstr, life, canExplode, rate, mass, attribute, minMass, maxMass, topdown_view)
    local res = {}
    res.desc = {}
    
    res.desc.typeName = name
    res.desc.displayName = displayName
    res.desc.attributes = {}
    res.desc.attributes.Cargos = true
    res.desc.minMass = minMass
    res.desc.maxMass = maxMass
    res.desc.category = 'Cargo'

    dcsUnits.logDebug("Adding custom cargo "..displayName)
    dcsUnits.DcsUnitsDatabase[name] = res
end

dcsUnits.logInfo(string.format("Loading version %s", dcsUnits.Version))

-- dcsUnits.addCargoUnit( "jeep_cargo", "jeep_cargo", "jeep_cargo", "jeep_cargo",10,false, 100, 1200,  {"Cargos"}, 100, 4000 );
-- dcsUnits.addCargoUnit( "bambi_bucket", "bambi_bucket", "bambi_bucket","bambi_bucket",5,false, 1000, 1500,  {"Cargos"}, 1000, 2000 );
-- dcsUnits.addCargoUnit( "zu23_cargo", "zu23_cargo", "zu23_cargo","zu23_cargo",15,false, 100, 1500,  {"Cargos"}, 1000, 2000 ); --zu23_cargo
-- dcsUnits.addCargoUnit( "blu82_cargo", "blu82_cargo", "blu82_cargo","blu82_cargo",10,true,100, 2400,{"Cargos"},800,5000); --blu82_cargo
-- dcsUnits.addCargoUnit( "generator_cargo", "generator_cargo", "generator_cargo","generator_cargo",10,false, 100, 1500,  {"Cargos"}, 1000, 2000 ); --generator_cargo
-- dcsUnits.addCargoUnit( "Tschechenigel_cargo", "Tschechenigel_cargo", "reiter_cargo","reiter_cargo",20,false, 100, 1000,  {"Cargos"}, 100, 10000 ); --reiter_cargo
-- dcsUnits.addCargoUnit( "sandbag", "sandbag", "sandbag","sandbag", 100, 1000,  {"Cargos"},10,false, 100, 10000 ); --sandbag
-- dcsUnits.addCargoUnit( "booth_container", "booth_container", "booth_container","booth_container",10,false, 100, 3200,  {"Cargos"}, 2200, 10000 );--booth_container
-- dcsUnits.addCargoUnit( "antenne", "antenne", "antenne","antenne",10,false, 100, 3200,  {"Cargos"}, 2200, 10000 );--antenne
-- dcsUnits.addCargoUnit( "mast", "mast", "mast","mast",10,false, 100, 3200,  {"Cargos"}, 2200, 10000 );--mast
-- dcsUnits.addCargoUnit( "uh1_weapons", "uh1_weapons", "uh1_weapons","uh1_weapons",10,false, 100, 1000,  {"Cargos"}, 100, 10000 );--uh1_weapons
-- dcsUnits.addCargoUnit( "panzergranaten", "panzergranaten", "panzergranaten","panzergranaten",10,false, 100, 1500,  {"Cargos"}, 1000, 2000 );--panzergranaten
-- dcsUnits.addCargoUnit( "pz2000_shell", "pz2000_shell", "pz2000_shell","pz2000_shell",10,false, 100, 1500,  {"Cargos"}, 1000, 2000 );--pz2000_shell
-- dcsUnits.addCargoUnit( "sandbag_box", "sandbag_box", "sandbag_box","sandbag_box",10,false, 100, 1500,  {"Cargos"}, 1000, 2000 );--sandbag_box
-- dcsUnits.addCargoUnit( "fir_tree", "fir_tree", "fir_tree","fir_tree",100, 1000,  {"Cargos"},10,false, 100, 10000 );--fir_tree
-- dcsUnits.addCargoUnit( "hmvee_cargo", "hmvee_cargo", "hmvee_cargo","hmvee_cargo",10,false, 100, 3200,  {"Cargos"}, 2200, 10000 );--hmvee_cargo
-- dcsUnits.addCargoUnit( "eurotainer", "eurotainer", "eurotainer","eurotainer",10,false,100, 2400,{"Cargos"},800,5000);--eurotainer
-- dcsUnits.addCargoUnit( "MK6", "MK6", "MK6","MK6",10,true,100, 2400,{"Cargos"},800,5000);--MK6
-- dcsUnits.addCargoUnit( "concrete_pipe_duo", "concrete_pipe_duo", "concrete_pipe_duo","concrete_pipe_duo",10,false,100, 823,  {"Cargos"}, 823, 823 );--concrete_pipe_duo
-- dcsUnits.addCargoUnit( "concrete_pipe", "concrete_pipe", "concrete_pipe","concrete_pipe",10,false,100, 823,  {"Cargos"}, 823, 823 );--concrete_pipe
-- dcsUnits.addCargoUnit( "gaz66_cargo", "gaz66_cargo", "gaz66_cargo","gaz66_cargo",15,false, 100, 3200,  {"Cargos"}, 2200, 10000 );--gaz66_cargo
-- dcsUnits.addCargoUnit( "uaz_cargo", "uaz_cargo", "uaz_cargo","uaz_cargo",15,false, 100, 3200,  {"Cargos"}, 2200, 10000 );--uaz_cargo
-- dcsUnits.addCargoUnit( "stretcher_body", "stretcher_body", "stretcher_body","stretcher_body",5,false,100, 1000,  {"Cargos"}, 100, 10000 );--stretcher_body
-- dcsUnits.addCargoUnit( "stretcher_empty", "stretcher_empty", "stretcher_empty","stretcher_empty",10,false,100, 1000,  {"Cargos"}, 100, 10000 );--stretcher_empty
-- dcsUnits.addCargoUnit( "san_container", "san_container", "san_container","san_container",15,false, 100, 3200,  {"Cargos"}, 2200, 10000 );--san_container
-- dcsUnits.addCargoUnit( "biwak_cargo", "biwak_cargo", "biwak_cargo","biwak_cargo", 15,false,100, 3200,  {"Cargos"}, 2200, 10000 );--biwak_cargo
-- dcsUnits.addCargoUnit( "wolf_cargo", "wolf_cargo", "wolf_cargo","wolf_cargo",15,false, 100, 3200,  {"Cargos"}, 2200, 10000 );--wolf_cargo
-- dcsUnits.addCargoUnit( "biwak_timber", "biwak_timber", "biwak_timber","biwak_timber",15,false, 100, 480,  {"Cargos"}, 100, 480);--biwak_timber
-- dcsUnits.addCargoUnit( "biwak_metal", "biwak_metal", "biwak_metal","biwak_metal",15,false, 100, 480,  {"Cargos"}, 100, 480);--biwak_metal


