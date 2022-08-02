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
veafGrass.Id = "GRASS"

--- Version.
veafGrass.Version = "2.3.0"

-- trace level, specific to this module
--veafGrass.LogLevel = "trace"

veaf.loggers.new(veafGrass.Id, veafGrass.LogLevel)

veafGrass.DelayForStartup = 0.5

veafGrass.RadiusAroundFarp = 2000
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- veafGrass.buildGrassRunway
-- Build a grass runway from grassRunwayUnit
-- @param grassRunwayUnit a static unit object (right side)
-- @return a named point if successful
------------------------------------------------------------------------------
function veafGrass.buildGrassRunway(grassRunwayUnit, hiddenOnMFD)
    veaf.loggers.get(veafGrass.Id):debug(string.format("veafGrass.buildGrassRunway()"))
    veaf.loggers.get(veafGrass.Id):trace(string.format("grassRunwayUnit=%s",veaf.p(grassRunwayUnit)))
	veaf.loggers.get(veafGrass.Id):trace(string.format("hiddenOnMFD=%s",veaf.p(hiddenOnMFD)))

    if not grassRunwayUnit then return nil end

    local name = grassRunwayUnit.unitName
    local runwayOrigin = grassRunwayUnit
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
		["hiddenOnMFD"] = hiddenOnMFD,
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
			["hiddenOnMFD"] = hiddenOnMFD,
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
			["hiddenOnMFD"] = hiddenOnMFD,
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
	return point
end

------------------------------------------------------------------------------
-- veafGrass.buildFarpsUnits
-- build FARP units on FARP with group name like "FARP "
------------------------------------------------------------------------------
function veafGrass.buildFarpsUnits(hiddenOnMFD)
    local farpUnits = {}
    local grassRunwayUnits = {}
	for name, unit in pairs(mist.DBs.unitsByName) do
		--veaf.loggers.get(veafGrass.Id):trace("buildFarpsUnits: testing " .. unit.type .. " " .. name)
        if name:upper():find('GRASS_RUNWAY') then 
            grassRunwayUnits[name] = unit
            veaf.loggers.get(veafGrass.Id):trace(string.format("found grassRunwayUnits[%s]= %s", name, veaf.p(unit)))
        end
		--first two types should represent the same object depending on if you're on the MIST side or DCS side, as a safety added both
        if (unit.type == "SINGLE_HELIPAD" or unit.type == "FARP_SINGLE_01" or unit.type == "FARP" or unit.type == "Invisible FARP") and name:upper():find('FARP ') then 
            farpUnits[name] = unit
            veaf.loggers.get(veafGrass.Id):trace(string.format("found farpUnits[%s]= %s", name, veaf.p(unit)))
        end
    end
    veaf.loggers.get(veafGrass.Id):trace(string.format("farpUnits=%s",veaf.p(farpUnits)))
    veaf.loggers.get(veafGrass.Id):trace(string.format("grassRunwayUnits=%s",veaf.p(grassRunwayUnits)))
    for name, unit in pairs(farpUnits) do
        veaf.loggers.get(veafGrass.Id):trace(string.format("calling buildFarpsUnits(%s)",name))
        veafGrass.buildFarpUnits(unit, grassRunwayUnits, nil, hiddenOnMFD)
    end
end

------------------------------------------------------------------------------
-- build nice FARP units arround the FARP
-- @param unit farp : the FARP unit
------------------------------------------------------------------------------
function veafGrass.buildFarpUnits(farp, grassRunwayUnits, groupName, hiddenOnMFD)
    veaf.loggers.get(veafGrass.Id):debug(string.format("buildFarpUnits()"))
    veaf.loggers.get(veafGrass.Id):trace(string.format("farp=%s",veaf.p(farp)))
    veaf.loggers.get(veafGrass.Id):trace(string.format("grassRunwayUnits=%s",veaf.p(grassRunwayUnits)))
	veaf.loggers.get(veafGrass.Id):trace(string.format("hiddenOnMFD=%s",veaf.p(hiddenOnMFD)))

	local farpCoalition = farp.coalition
	if type(farpCoalition == "number") then
		if farpCoalition == 1 then
			farpCoalition = "red"
		else
			farpCoalition = "blue"
		end
	end

	local farpHeading = farp.heading or 0
	local angle = mist.utils.toDegree(farpHeading)
	local tentDistance = 100
	local tentSpacing = 30
	local otherDistance = 85
	local otherSpacing = 15
	local unitsDistance = 75

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
				["coalition"] = farpCoalition,
				["country"] = farp.country,
				["countryId"] = farp.countryId,
				["heading"] = mist.utils.toRadian(angle-90),
				["type"] = 'FARP Tent',
				["x"] = tentOrigin.x + (i-1) * tentSpacing * math.cos(mist.utils.toRadian(angle)) - (j-1) * tentSpacing * math.sin(mist.utils.toRadian(angle)),
				["y"] = tentOrigin.y + (i-1) * tentSpacing * math.sin(mist.utils.toRadian(angle)) + (j-1) * tentSpacing *  math.cos(mist.utils.toRadian(angle)),
						["hiddenOnMFD"] = hiddenOnMFD,
			}
			if groupName then
				tent["groupName"] = groupName
			end			

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
			["coalition"] = farpCoalition,
			["country"] = farp.country,
			["countryId"] = farp.countryId,
			["heading"] = mist.utils.toRadian(angle-90),
			["type"] = typeName,
			["x"] = otherOrigin.x - (j-1) * otherSpacing * math.sin(mist.utils.toRadian(angle)),
			["y"] = otherOrigin.y + (j-1) * otherSpacing * math.cos(mist.utils.toRadian(angle)),
			["hiddenOnMFD"] = hiddenOnMFD,
		}		
		if groupName then
			otherUnit["groupName"] = groupName
		end			
		mist.dynAddStatic(otherUnit)
	end

	-- create Windsock
	local windsockDistance = 50
	local windsockAngle = 45

	-- fix Windsock position on FARP
	if farp.type == "FARP" then
		windsockDistance = 120
		windsockAngle = 0
	end

	local windsockUnit = {
		["category"] = 'static',
		["categoryStatic"] = 'Fortifications',
		["shape_name"] = "H-Windsock_RW",
		["type"] = "Windsock",	
		["coalition"] = farpCoalition,
		["country"] = farp.country,
		["countryId"] = farp.countryId,
		["heading"] = mist.utils.toRadian(angle-90),
		["x"] = farp.x + windsockDistance * math.cos(mist.utils.toRadian(angle + windsockAngle)),
		["y"] = farp.y + windsockDistance * math.sin(mist.utils.toRadian(angle + windsockAngle)),
		["hiddenOnMFD"] = hiddenOnMFD,
	}
	if groupName then
		windsockUnit["groupName"] = groupName
	end			
	mist.dynAddStatic(windsockUnit)

	-- on FARP unit, place a second windsock, at 90°
	if farp.type == 'FARP' then
		local windsockUnit = {
			["category"] = 'static',
			["categoryStatic"] = 'Fortifications',
			["shape_name"] = "H-Windsock_RW",
			["type"] = "Windsock",	
			["coalition"] = farpCoalition,
			["country"] = farp.country,
			["countryId"] = farp.countryId,
			["heading"] = mist.utils.toRadian(angle-90),
			["x"] = farp.x + windsockDistance * math.cos(mist.utils.toRadian(angle + windsockAngle - 90)),
			["y"] = farp.y + windsockDistance * math.sin(mist.utils.toRadian(angle + windsockAngle - 90)),
			["hiddenOnMFD"] = hiddenOnMFD,
		}
		if groupName then
			windsockUnit["groupName"] = groupName
		end			
		mist.dynAddStatic(windsockUnit)
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
		["coalition"] = farpCoalition,
		["country"] = farp.country,
		["countryId"] = farp.countryId,
		["groupName"] = farp.groupName,
		["units"] = {},
		["hiddenOnMFD"] = hiddenOnMFD,
	}
	if groupName then
		farpEscortGroup["groupName"] = groupName
	end			

	for j,typeName in ipairs(farpEscortUnitsNames[farpCoalition]) do
		local escortUnit = {
			["heading"] = mist.utils.toRadian(angle-135), -- parked \\\\\
			["type"] = typeName,
			["x"] = unitsOrigin.x - (j-1) * unitsSpacing * math.sin(mist.utils.toRadian(angle)),
			["y"] = unitsOrigin.y + (j-1) * unitsSpacing * math.cos(mist.utils.toRadian(angle)),
			["skill"] = "Random",
		}		
		table.insert(farpEscortGroup.units, escortUnit)

	end

	mist.dynAdd(farpEscortGroup)
	
    -- add the FARP to the named points
    local farpNamedPoint = {
        x = farp.x,
        y = math.floor(land.getHeight(farp) + 1),
        z = farp.y,
        atc = true,
        runways = {}
    }

    -- add the FARP to the named points
    local beaconPoint = {
        x = farp.x - 250,
        y = math.floor(land.getHeight(farp) + 1),
        z = farp.y - 250
    }

	if ctld then
		local _beaconInfo = ctld.createRadioBeacon(beaconPoint, farpCoalition, farp.country, farp.unitName or farp.name, -1, true)
		if _beaconInfo ~= nil then
			farpNamedPoint.tacan = string.format("ADF : %.2f KHz - %.2f MHz - %.2f MHz", _beaconInfo.vhf / 1000, _beaconInfo.uhf / 1000000, _beaconInfo.fm / 1000000)
			veaf.loggers.get(veafGrass.Id):trace(string.format("farpNamedPoint.tacan=%s", veaf.p(farpNamedPoint.tacan)))
		end
	end

    -- search for an associated grass runway
    if (grassRunwayUnits) then
        local grassRunwayUnit = nil
        for name, unitDef in pairs(grassRunwayUnits) do
            local unit = Unit.getByName(name)
            if not unit then 
                unit = StaticObject.getByName(name)
            end
            if unit then 
                local pos = unit:getPosition().p
                if pos then -- you never know O.o
                    local distanceFromCenter = ((pos.x - farp.x)^2 + (pos.z - farp.y)^2)^0.5
                    veaf.loggers.get(veafGrass.Id):trace(string.format("name=%s; distanceFromCenter=%s", tostring(name), veaf.p(distanceFromCenter)))
                    if distanceFromCenter <= veafGrass.RadiusAroundFarp then
                        grassRunwayUnit = unitDef
                        break
                    end
                end
            end
        end
        if grassRunwayUnit then
            veaf.loggers.get(veafGrass.Id):trace(string.format("found grassRunwayUnit %s", veaf.p(grassRunwayUnit)))
			local grassNamedPoint = veafGrass.buildGrassRunway(grassRunwayUnit, hiddenOnMFD)
			farpNamedPoint.x = grassNamedPoint.x
			farpNamedPoint.y = grassNamedPoint.y
			farpNamedPoint.z = grassNamedPoint.z
			farpNamedPoint.atc = grassNamedPoint.atc
			farpNamedPoint.runways = grassNamedPoint.runways
        end
    end
    veaf.loggers.get(veafGrass.Id):trace(string.format("farpNamedPoint=%s", veaf.p(farpNamedPoint)))

	veafNamedPoints.addPoint(farp.unitName or farp.name, farpNamedPoint)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafGrass.initialize()
	-- delay all these functions 30 seconds (to ensure that the other modules are loaded)
	
	-- auto generate FARP units (hide these units on MFDs as they create clutter for nothing since the FARP already shows or not depending on what the Mission maker wanted, regardless, don't show them)
    mist.scheduleFunction(veafGrass.buildFarpsUnits,{true},timer.getTime()+veafGrass.DelayForStartup)
end

veaf.loggers.get(veafGrass.Id):info(string.format("Loading version %s", veafGrass.Version))
