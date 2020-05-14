-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF grass functions for DCS World
-- By mitch (2018)
--
-- Features:
-- ---------
-- * Script to build units on FARPS and grass runways
-- * Works with all current and future maps (Caucasus, NTTR, Normandy, PG, ...)
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires the base veaf.lua script library (version 1.0 or higher)
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
--     * OPEN --> Browse to the location of this script and click OK.
--     * ACTION "DO SCRIPT"
--     * set the script command to "veafGrass.initialize()" and click OK.
-- 4.) Save the mission and start it.
-- 5.) Have fun :)
--
-- Basic Usage:
-- ------------
-- TODO
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafGrass = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafGrass.Id = "GRASS - "

--- Version.
veafGrass.Version = "1.1.3"

-- trace level, specific to this module
veafGrass.Trace = false

veafGrass.DelayForStartup = 3
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafGrass.logInfo(message)
    veaf.logInfo(veafGrass.Id .. message)
end

function veafGrass.logDebug(message)
    veaf.logDebug(veafGrass.Id .. message)
end

function veafGrass.logTrace(message)
	if message and veafGrass.Trace then
		veaf.logTrace(veafGrass.Id .. message)
	end
end

------------------------------------------------------------------------------
-- veafGrass.buildGrassRunway
-- Build a grass runway from runwayOrigin
-- @param runwayOrigin a static unit object (right side)
-- @return nil
------------------------------------------------------------------------------
function veafGrass.buildGrassRunway(name, runwayOrigin)
	veafGrass.logInfo("Building grass runway for unit " .. runwayOrigin.unitName)
	local tower = true
	local endMarkers = false
	
	-- runway length in meters
	local length = 600;
	-- a plot each XX meters
	local space = 50;
	-- runway width XX meters
	local width = 30;
	
	-- nb plots
	local nbPlots = math.ceil(length / space);

	local angle = math.floor(mist.utils.toDegree(runwayOrigin.heading)+0.5);

	-- create left origin from right origin
	local leftOrigin = {
		["x"] = runwayOrigin.x + width * math.cos(mist.utils.toRadian(angle-90)),
		["y"] = runwayOrigin.y + width * math.sin(mist.utils.toRadian(angle-90)),
	}

    local template = {
	    ["category"] = runwayOrigin.category,
        ["categoryStatic"] = runwayOrigin.categoryStatic,
        ["coalition"] = runwayOrigin.coalition,
        ["country"] = runwayOrigin.country,
        ["countryId"] = runwayOrigin.countryId,
        ["heading"] = runwayOrigin.heading,
        ["shape_name"] =  runwayOrigin.shape_name,
        ["type"] = runwayOrigin.type,
	}
	
	-- leftOrigin plot
	local leftOriginPlot = mist.utils.deepCopy(template)
	leftOriginPlot.x = leftOrigin.x
	leftOriginPlot.y = leftOrigin.y
	mist.dynAddStatic(leftOriginPlot)
	
	-- place plots
	for i = 1, nbPlots do
		-- right plot
		local leftPlot = mist.utils.deepCopy(template)
		leftPlot.x = runwayOrigin.x + i * space * math.cos(mist.utils.toRadian(angle))
		leftPlot.y = runwayOrigin.y + i * space * math.sin(mist.utils.toRadian(angle))
        mist.dynAddStatic(leftPlot)
		
		-- right plot
		local rightPlot = mist.utils.deepCopy(template)
		rightPlot.x = leftOrigin.x + i * space * math.cos(mist.utils.toRadian(angle))
		rightPlot.y = leftOrigin.y + i * space * math.sin(mist.utils.toRadian(angle))
        mist.dynAddStatic(rightPlot)		
	end
	
	if (endMarkers) then
		-- close the runway with optional markers (airshow cones)
		template = {
			["category"] = "Fortifications",
			["categoryStatic"] = runwayOrigin.categoryStatic,
			["coalition"] = runwayOrigin.coalition,
			["country"] = runwayOrigin.country,
			["countryId"] = runwayOrigin.countryId,
			["heading"] = runwayOrigin.heading,
			["shape_name"] =  "Comp_cone",
			["type"] = "Airshow_Cone",
		}
		-- right plot
		local leftPlot = mist.utils.deepCopy(template)
		leftPlot.x = runwayOrigin.x + (nbPlots+1) * space * math.cos(mist.utils.toRadian(angle))
		leftPlot.y = runwayOrigin.y + (nbPlots+1) * space * math.sin(mist.utils.toRadian(angle))
		mist.dynAddStatic(leftPlot)
		
		-- right plot
		local rightPlot = mist.utils.deepCopy(template)
		rightPlot.x = leftOrigin.x + (nbPlots+1) * space * math.cos(mist.utils.toRadian(angle))
		rightPlot.y = leftOrigin.y + (nbPlots+1) * space * math.sin(mist.utils.toRadian(angle))
		mist.dynAddStatic(rightPlot)
	end
	
	if (tower) then
		-- optionally add a tower at the start of the runway
		template = {
			["category"] = "Fortifications",
			["categoryStatic"] = runwayOrigin.categoryStatic,
			["coalition"] = runwayOrigin.coalition,
			["country"] = runwayOrigin.country,
			["countryId"] = runwayOrigin.countryId,
			["heading"] = runwayOrigin.heading,
			["type"] = "house2arm",
		}
		
		-- tower
		local tower = mist.utils.deepCopy(template)
		tower.x = leftOrigin.x-60 + (nbPlots+1.2) * space * math.cos(mist.utils.toRadian(angle))
		tower.y = leftOrigin.y-60 + (nbPlots+1.2) * space * math.sin(mist.utils.toRadian(angle))
		mist.dynAddStatic(tower)
	end

	-- add the runway to the named points
	local point = {
		x = runwayOrigin.x+20 + (nbPlots+1) * space * math.cos(mist.utils.toRadian(angle)) + width/2 * math.cos(mist.utils.toRadian(angle-90)),
		y = math.floor(land.getHeight(leftOrigin) + 1),
		z = runwayOrigin.y+20 + (nbPlots+1) * space * math.sin(mist.utils.toRadian(angle)) + width/2 * math.cos(mist.utils.toRadian(angle-90)),
		atc = true,
		runways = { 
			{ hdg = (angle + 180) % 360, flare = "red"}
		}
	}
	veafNamedPoints.addPoint(name:gsub("GRASS_RUNWAY","Grass strip"), point)
end

------------------------------------------------------------------------------
-- veafGrass.buildGrassRunways
-- Build all grass runway from static object like 'GRASS_RUNWAY'
-- @return nil
------------------------------------------------------------------------------
function veafGrass.buildGrassRunways()

	for name, unit in pairs(mist.DBs.unitsByName) do
		if string.find(name, 'GRASS_RUNWAY') then		
            veafGrass.buildGrassRunway(name, unit)
        end
	end
end

------------------------------------------------------------------------------
-- veafGrass.buildFarpsUnits
-- build FARP units on FARP with group name like "FARP "
------------------------------------------------------------------------------
function veafGrass.buildFarpsUnits()

	for name, unit in pairs(mist.DBs.unitsByName) do
		veafGrass.logTrace("buildFarpsUnits: testing " .. unit.type .. " " .. name)

		if (unit.type == "SINGLE_HELIPAD" or unit.type == "FARP") and string.find(name:upper(), 'FARP ') then
			veafGrass.buildFarpUnits(unit)
		end
	end
	
end

------------------------------------------------------------------------------
-- build nice FARP units arround the FARP
-- @param unit farp : the FARP unit
------------------------------------------------------------------------------
function veafGrass.buildFarpUnits(farp)
	veafGrass.logInfo("Building FARP for unit " .. farp.unitName)

	local angle = mist.utils.toDegree(farp.heading);
	local tentDistance = 100
	local tentSpacing = 30
	local otherDistance = 85
	local otherSpacing = 15
	local unitsDistance = 80

	-- fix distances on FARP
	if farp.type == "FARP" then
		tentDistance = 200
	    unitsDistance = 150
	    otherDistance = 130
	end

	local tentOrigin = {
		["x"] = farp.x + tentDistance * math.cos(mist.utils.toRadian(angle)),
		["y"] = farp.y + tentDistance * math.sin(mist.utils.toRadian(angle)),
	}

	-- create tents
	for j = 1,2 do
		for i = 1,3 do
			local tent = {
				["category"] = 'static',
				["categoryStatic"] = 'Fortifications',
				["coalition"] = farp.coalition,
				["country"] = farp.country,
				["countryId"] = farp.countryId,
				["heading"] = mist.utils.toRadian(angle-90),
				["type"] = 'FARP Tent',
				["x"] = tentOrigin.x + (i-1) * tentSpacing * math.cos(mist.utils.toRadian(angle)) - (j-1) * tentSpacing * math.sin(mist.utils.toRadian(angle)),
				["y"] = tentOrigin.y + (i-1) * tentSpacing * math.sin(mist.utils.toRadian(angle)) + (j-1) * tentSpacing *  math.cos(mist.utils.toRadian(angle)),
			}
			
			mist.dynAddStatic(tent)
			
		end	
	end
	
	-- spawn other static units
	local otherUnits={
		'FARP Fuel Depot',
		'FARP Ammo Dump Coating',
		'GeneratorF',
	}
	local otherOrigin = {
		["x"] = farp.x + otherDistance * math.cos(mist.utils.toRadian(angle)),
		["y"] = farp.y + otherDistance * math.sin(mist.utils.toRadian(angle)),
	}
	
	for j,typeName in ipairs(otherUnits) do
		local otherUnit = {
			["category"] = 'static',
			["categoryStatic"] = 'Fortifications',
			["coalition"] = farp.coalition,
			["country"] = farp.country,
			["countryId"] = farp.countryId,
			["heading"] = mist.utils.toRadian(angle-90),
			["type"] = typeName,
			["x"] = otherOrigin.x - (j-1) * otherSpacing * math.sin(mist.utils.toRadian(angle)),
			["y"] = otherOrigin.y + (j-1) * otherSpacing * math.cos(mist.utils.toRadian(angle)),
		}		
		mist.dynAddStatic(otherUnit)
	end

	-- create Windsock
	local windstockDistance = 50
	local windstockAngle = 45

	-- fix Windsock position on FARP
	if farp.type == "FARP" then
		windstockDistance = 120
		windstockAngle = 0
	end

	local windstockUnit = {
		["category"] = 'static',
		["categoryStatic"] = 'Fortifications',
		["shape_name"] = "H-Windsock_RW",
		["type"] = "Windsock",	
		["coalition"] = farp.coalition,
		["country"] = farp.country,
		["countryId"] = farp.countryId,
		["heading"] = mist.utils.toRadian(angle-90),
		["x"] = farp.x + windstockDistance * math.cos(mist.utils.toRadian(angle + windstockAngle)),
		["y"] = farp.y + windstockDistance * math.sin(mist.utils.toRadian(angle + windstockAngle)),
	}
	mist.dynAddStatic(windstockUnit)

	-- on FARP unit, place a second windsock, at 90°
	if farp.type == 'FARP' then
		local windstockUnit = {
			["category"] = 'static',
			["categoryStatic"] = 'Fortifications',
			["shape_name"] = "H-Windsock_RW",
			["type"] = "Windsock",	
			["coalition"] = farp.coalition,
			["country"] = farp.country,
			["countryId"] = farp.countryId,
			["heading"] = mist.utils.toRadian(angle-90),
			["x"] = farp.x + windstockDistance * math.cos(mist.utils.toRadian(angle + windstockAngle - 90)),
			["y"] = farp.y + windstockDistance * math.sin(mist.utils.toRadian(angle + windstockAngle - 90)),
		}
		mist.dynAddStatic(windstockUnit)
	end

	-- spawn a FARP escort group
	local farpEscortUnitsNames={
		blue = {
			"Hummer",
			"M978 HEMTT Tanker",
			"M 818",
			"M 818",
			"Hummer",
		},		
		red = {
			"ATZ-10",
			"ATZ-10",
			"Ural-4320 APA-5D",
			"Ural-375",
			"Ural-375",
			"Ural-375 PBU",
		}
	}

	local unitsSpacing=6
	local unitsOrigin = {
		x = farp.x + unitsDistance * math.cos(mist.utils.toRadian(angle)),
		y = farp.y + unitsDistance * math.sin(mist.utils.toRadian(angle)),
	}
	
	local farpEscortGroup = {
		["category"] = 'vehicle',
		["coalition"] = farp.coalition,
		["country"] = farp.country,
		["countryId"] = farp.countryId,
		["groupName"] = farp.groupName .. ' escort',
		["units"] = {},
	}		
	for j,typeName in ipairs(farpEscortUnitsNames[farp.coalition]) do
		local escrotUnit = {
			["heading"] = mist.utils.toRadian(angle-135), -- parked \\\\\
			["type"] = typeName,
			["x"] = unitsOrigin.x - (j-1) * unitsSpacing * math.sin(mist.utils.toRadian(angle)),
			["y"] = unitsOrigin.y + (j-1) * unitsSpacing * math.cos(mist.utils.toRadian(angle)),
			["skill"] = "Random",
		}		
		table.insert(farpEscortGroup.units, escrotUnit)

	end

	mist.dynAdd(farpEscortGroup)
	
	-- add the FARP to the named points
	local point = {
		x = farp.x,
		y = math.floor(land.getHeight(farp) + 1),
		z = farp.y,
		atc = true,
		runways = {}
	}
	veafNamedPoints.addPoint(farp.unitName, point)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafGrass.initialize()
	-- delay all these functions 30 seconds (to ensure that the other modules are loaded)
	
	-- auto generate FARP units
	mist.scheduleFunction(veafGrass.buildFarpsUnits,{},timer.getTime()+veafGrass.DelayForStartup)
	
	-- auto generate GRASS RUNWAY
	mist.scheduleFunction(veafGrass.buildGrassRunways,{},timer.getTime()+veafGrass.DelayForStartup)

end

veafGrass.logInfo(string.format("Loading version %s", veafGrass.Version))
