------------------------------------------------------------------
-- VEAF grass functions for DCS World
-- By mitch (2018)
--
-- Features:
-- ---------
-- * Script to build units on FARPS and grass runways
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafGrass = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafGrass.Id = "GRASS"

--- Version.
veafGrass.Version = "2.8.0"

-- trace level, specific to this module
--veafGrass.LogLevel = "trace"

veaf.loggers.new(veafGrass.Id, veafGrass.LogLevel)

veafGrass.DelayForStartup = 2

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
        if (unit.type == "SINGLE_HELIPAD" or unit.type == "FARP_SINGLE_01" or unit.type == "FARP" or unit.type == "Invisible FARP" or unit.type == "FARP_T") and name:upper():sub(1,5)=="FARP " then
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

---Browse all the FARP-type units and refill their warehouses
function veafGrass.fillAllFarpWarehouses()
	veaf.loggers.get(veafGrass.Id):debug("veafGrass.fillAllFarpWarehouses()")
    local farpBases = {}
    local grassBases = {}
	local bases = world.getAirbases()
    for _, base in pairs(bases) do
		local name = base:getName()
		veaf.loggers.get(veafGrass.Id):trace("fillAllFarpWarehouse: testing %s", veaf.p(name))
		local status, typeName = pcall(base.getTypeName, base) -- test cautiously if the base is a valid airbase, since DCS will either fail the getTypeName call or even crash when the airbase has been "moved" (e.g., by creating a new FARP with the same name)
		if status then
			if name:upper():find('GRASS_RUNWAY') then
				grassBases[name] = base
				veaf.loggers.get(veafGrass.Id):trace("found grassBase [%s]", veaf.p(name))
			end
			--first two types should represent the same object depending on if you're on the MIST side or DCS side, as a safety added both
			if (typeName == "SINGLE_HELIPAD" or typeName == "FARP_SINGLE_01" or typeName == "FARP" or typeName == "Invisible FARP") then
				farpBases[name] = base
				veaf.loggers.get(veafGrass.Id):trace("found farpBase [%s]", veaf.p(name))
			end
		else
			veaf.loggers.get(veafGrass.Id):warn("Airbase is not a valid object - getTypeName crashed - [%s]", veaf.p(name))
		end
    end

    for _, base in pairs(grassBases) do
        veafGrass.fillFarpWarehouse(base)
    end

	for _, base in pairs(farpBases) do
        veafGrass.fillFarpWarehouse(base)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Very long table used to fill FARP warehouses
-------------------------------------------------------------------------------------------------------------------------------------------------------------
veafGrass.WAREHOUSE_ITEMS={[1]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=10},["initialAmount"]=100},[2]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=103},["initialAmount"]=100},[3]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1056},["initialAmount"]=100},[4]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=107},["initialAmount"]=100},[5]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=11},["initialAmount"]=100},[6]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=12},["initialAmount"]=100},[7]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=13},["initialAmount"]=100},[8]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=14},["initialAmount"]=100},[9]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1469},["initialAmount"]=100},[10]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1470},["initialAmount"]=100},[11]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=15},["initialAmount"]=100},[12]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=152},["initialAmount"]=100},[13]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1551},["initialAmount"]=100},[14]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1552},["initialAmount"]=100},[15]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1553},["initialAmount"]=100},[16]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1554},["initialAmount"]=100},[17]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1555},["initialAmount"]=100},[18]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1556},["initialAmount"]=100},[19]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1572},["initialAmount"]=100},[20]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1573},["initialAmount"]=100},[21]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=16},["initialAmount"]=100},[22]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1640},["initialAmount"]=100},[23]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1641},["initialAmount"]=100},[24]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1642},["initialAmount"]=100},[25]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=17},["initialAmount"]=100},[26]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1700},["initialAmount"]=100},[27]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1715},["initialAmount"]=100},[28]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=1716},["initialAmount"]=100},[29]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=2144},["initialAmount"]=100},[30]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=2145},["initialAmount"]=100},[31]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=2146},["initialAmount"]=100},[32]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=2380},["initialAmount"]=100},[33]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=2381},["initialAmount"]=100},[34]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=2382},["initialAmount"]=100},[35]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=2383},["initialAmount"]=100},[36]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=263},["initialAmount"]=100},[37]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=264},["initialAmount"]=100},[38]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=265},["initialAmount"]=100},[39]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=266},["initialAmount"]=100},[40]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=267},["initialAmount"]=100},[41]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=274},["initialAmount"]=100},[42]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=275},["initialAmount"]=100},[43]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=294},["initialAmount"]=100},[44]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=36},["initialAmount"]=100},[45]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=38},["initialAmount"]=100},[46]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=39},["initialAmount"]=100},[47]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=41},["initialAmount"]=100},[48]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=42},["initialAmount"]=100},[49]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=465},["initialAmount"]=100},[50]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=466},["initialAmount"]=100},[51]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=468},["initialAmount"]=100},[52]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=469},["initialAmount"]=100},[53]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=484},["initialAmount"]=100},[54]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=485},["initialAmount"]=100},[55]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=5},["initialAmount"]=100},[56]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=53},["initialAmount"]=100},[57]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=54},["initialAmount"]=100},[58]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=55},["initialAmount"]=100},[59]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=56},["initialAmount"]=100},[60]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=587},["initialAmount"]=100},[61]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=589},["initialAmount"]=100},[62]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=590},["initialAmount"]=100},[63]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=593},["initialAmount"]=100},[64]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=603},["initialAmount"]=100},[65]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=604},["initialAmount"]=100},[66]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=605},["initialAmount"]=100},[67]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=609},["initialAmount"]=100},[68]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=61},["initialAmount"]=100},[69]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=610},["initialAmount"]=100},[70]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=611},["initialAmount"]=100},[71]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=616},["initialAmount"]=100},[72]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=617},["initialAmount"]=100},[73]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=662},["initialAmount"]=100},[74]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=663},["initialAmount"]=100},[75]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=664},["initialAmount"]=100},[76]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=782},["initialAmount"]=100},[77]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=783},["initialAmount"]=100},[78]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=855},["initialAmount"]=100},[79]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=928},["initialAmount"]=100},[80]={["wsType"]={[1]=1,[2]=3,[3]=43,[4]=929},["initialAmount"]=100},[81]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=101},["initialAmount"]=5550},[82]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=1548},["initialAmount"]=5550},[83]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=1717},["initialAmount"]=5550},[84]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=1718},["initialAmount"]=5550},[85]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=1719},["initialAmount"]=5550},[86]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=1720},["initialAmount"]=5550},[87]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=1721},["initialAmount"]=5550},[88]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=19},["initialAmount"]=5550},[89]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=2114},["initialAmount"]=1254},[90]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=2138},["initialAmount"]=5550},[91]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=2139},["initialAmount"]=5550},[92]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=2140},["initialAmount"]=5550},[93]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=2141},["initialAmount"]=5550},[94]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=2142},["initialAmount"]=5550},[95]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=2148},["initialAmount"]=5550},[96]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=2149},["initialAmount"]=5550},[97]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=2286},["initialAmount"]=5550},[98]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=2287},["initialAmount"]=5550},[99]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=2288},["initialAmount"]=5550},[100]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=2475},["initialAmount"]=5550},[101]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=26},["initialAmount"]=5550},[102]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=28},["initialAmount"]=5550},[103]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=424},["initialAmount"]=5550},[104]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=425},["initialAmount"]=5550},[105]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=426},["initialAmount"]=5550},[106]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=461},["initialAmount"]=5550},[107]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=463},["initialAmount"]=5550},[108]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=486},["initialAmount"]=5550},[109]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=59},["initialAmount"]=5550},[110]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=62},["initialAmount"]=5550},[111]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=63},["initialAmount"]=5550},[112]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=64},["initialAmount"]=5550},[113]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=65},["initialAmount"]=5550},[114]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=74},["initialAmount"]=5550},[115]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=78},["initialAmount"]=5550},[116]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=808},["initialAmount"]=5550},[117]={["wsType"]={[1]=4,[2]=15,[3]=44,[4]=95},["initialAmount"]=5550},[118]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=142},["initialAmount"]=5550},[119]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=173},["initialAmount"]=5550},[120]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=1762},["initialAmount"]=5550},[121]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=1763},["initialAmount"]=5550},[122]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=25},["initialAmount"]=5550},[123]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=29},["initialAmount"]=5550},[124]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=295},["initialAmount"]=5550},[125]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=296},["initialAmount"]=5550},[126]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=30},["initialAmount"]=5550},[127]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=301},["initialAmount"]=5550},[128]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=37},["initialAmount"]=5550},[129]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=462},["initialAmount"]=5550},[130]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=464},["initialAmount"]=5550},[131]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=665},["initialAmount"]=5550},[132]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=681},["initialAmount"]=5550},[133]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=94},["initialAmount"]=5550},[134]={["wsType"]={[1]=4,[2]=15,[3]=45,[4]=968},["initialAmount"]=5550},[135]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1057},["initialAmount"]=5550},[136]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1294},["initialAmount"]=5550},[137]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1295},["initialAmount"]=5550},[138]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=145},["initialAmount"]=5550},[139]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1544},["initialAmount"]=5550},[140]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1545},["initialAmount"]=5550},[141]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1546},["initialAmount"]=5550},[142]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1547},["initialAmount"]=5550},[143]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=160},["initialAmount"]=5550},[144]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=161},["initialAmount"]=5550},[145]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=170},["initialAmount"]=5550},[146]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=171},["initialAmount"]=5550},[147]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=174},["initialAmount"]=5550},[148]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=175},["initialAmount"]=5550},[149]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=176},["initialAmount"]=5550},[150]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1764},["initialAmount"]=5550},[151]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1765},["initialAmount"]=5550},[152]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1766},["initialAmount"]=5550},[153]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1767},["initialAmount"]=5550},[154]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1768},["initialAmount"]=5550},[155]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1769},["initialAmount"]=5550},[156]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=177},["initialAmount"]=5550},[157]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1770},["initialAmount"]=5550},[158]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1771},["initialAmount"]=5550},[159]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=18},["initialAmount"]=5550},[160]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1813},["initialAmount"]=5550},[161]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=183},["initialAmount"]=5550},[162]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=184},["initialAmount"]=5550},[163]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=1919},["initialAmount"]=5550},[164]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=20},["initialAmount"]=5550},[165]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=2143},["initialAmount"]=5550},[166]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=2476},["initialAmount"]=5550},[167]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=2477},["initialAmount"]=5550},[168]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=2478},["initialAmount"]=5550},[169]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=2479},["initialAmount"]=5550},[170]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=2480},["initialAmount"]=5550},[171]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=2481},["initialAmount"]=5550},[172]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=2482},["initialAmount"]=5550},[173]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=2483},["initialAmount"]=5550},[174]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=2484},["initialAmount"]=5550},[175]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=2574},["initialAmount"]=5550},[176]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=2575},["initialAmount"]=5550},[177]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=2576},["initialAmount"]=5550},[178]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=2577},["initialAmount"]=5550},[179]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=2578},["initialAmount"]=5550},[180]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=286},["initialAmount"]=5550},[181]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=300},["initialAmount"]=5550},[182]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=428},["initialAmount"]=5550},[183]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=429},["initialAmount"]=5550},[184]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=588},["initialAmount"]=5550},[185]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=596},["initialAmount"]=5550},[186]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=824},["initialAmount"]=5550},[187]={["wsType"]={[1]=4,[2]=15,[3]=46,[4]=825},["initialAmount"]=5550},[188]={["wsType"]={[1]=4,[2]=15,[3]=47,[4]=104},["initialAmount"]=5550},[189]={["wsType"]={[1]=4,[2]=15,[3]=47,[4]=108},["initialAmount"]=5550},[190]={["wsType"]={[1]=4,[2]=15,[3]=47,[4]=1100},["initialAmount"]=5550},[191]={["wsType"]={[1]=4,[2]=15,[3]=47,[4]=1549},["initialAmount"]=5550},[192]={["wsType"]={[1]=4,[2]=15,[3]=47,[4]=4},["initialAmount"]=5550},[193]={["wsType"]={[1]=4,[2]=15,[3]=47,[4]=679},["initialAmount"]=5550},[194]={["wsType"]={[1]=4,[2]=15,[3]=47,[4]=680},["initialAmount"]=5550},[195]={["wsType"]={[1]=4,[2]=15,[3]=48,[4]=1168},["initialAmount"]=5550},[196]={["wsType"]={[1]=4,[2]=15,[3]=48,[4]=1169},["initialAmount"]=5550},[197]={["wsType"]={[1]=4,[2]=15,[3]=48,[4]=1170},["initialAmount"]=5550},[198]={["wsType"]={[1]=4,[2]=15,[3]=48,[4]=1171},["initialAmount"]=5550},[199]={["wsType"]={[1]=4,[2]=15,[3]=48,[4]=1172},["initialAmount"]=5550},[200]={["wsType"]={[1]=4,[2]=15,[3]=48,[4]=1173},["initialAmount"]=5550},[201]={["wsType"]={[1]=4,[2]=15,[3]=48,[4]=1174},["initialAmount"]=5550},[202]={["wsType"]={[1]=4,[2]=15,[3]=48,[4]=297},["initialAmount"]=5550},[203]={["wsType"]={[1]=4,[2]=15,[3]=48,[4]=58},["initialAmount"]=5550},[204]={["wsType"]={[1]=4,[2]=15,[3]=48,[4]=608},["initialAmount"]=5550},[205]={["wsType"]={[1]=4,[2]=15,[3]=48,[4]=666},["initialAmount"]=5550},[206]={["wsType"]={[1]=4,[2]=15,[3]=48,[4]=765},["initialAmount"]=5550},[207]={["wsType"]={[1]=4,[2]=15,[3]=48,[4]=766},["initialAmount"]=5550},[208]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=1550},["initialAmount"]=5550},[209]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=172},["initialAmount"]=5550},[210]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=268},["initialAmount"]=5550},[211]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=269},["initialAmount"]=5550},[212]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=270},["initialAmount"]=5550},[213]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=271},["initialAmount"]=5550},[214]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=272},["initialAmount"]=5550},[215]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=273},["initialAmount"]=5550},[216]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=298},["initialAmount"]=5550},[217]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=427},["initialAmount"]=5550},[218]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=467},["initialAmount"]=5550},[219]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=470},["initialAmount"]=5550},[220]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=66},["initialAmount"]=5550},[221]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=667},["initialAmount"]=5550},[222]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=668},["initialAmount"]=5550},[223]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=67},["initialAmount"]=5550},[224]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=82},["initialAmount"]=5550},[225]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=83},["initialAmount"]=5550},[226]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=84},["initialAmount"]=5550},[227]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=85},["initialAmount"]=5550},[228]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=86},["initialAmount"]=5550},[229]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=87},["initialAmount"]=5550},[230]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=88},["initialAmount"]=5550},[231]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=89},["initialAmount"]=5550},[232]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=90},["initialAmount"]=5550},[233]={["wsType"]={[1]=4,[2]=15,[3]=50,[4]=91},["initialAmount"]=5550},[234]={["wsType"]={[1]=4,[2]=4,[3]=100,[4]=143},["initialAmount"]=100},[235]={["wsType"]={[1]=4,[2]=4,[3]=101,[4]=140},["initialAmount"]=100},[236]={["wsType"]={[1]=4,[2]=4,[3]=101,[4]=141},["initialAmount"]=100},[237]={["wsType"]={[1]=4,[2]=4,[3]=101,[4]=142},["initialAmount"]=100},[238]={["wsType"]={[1]=4,[2]=4,[3]=101,[4]=154},["initialAmount"]=100},[239]={["wsType"]={[1]=4,[2]=4,[3]=32,[4]=719},["initialAmount"]=100},[240]={["wsType"]={[1]=4,[2]=4,[3]=32,[4]=849},["initialAmount"]=100},[241]={["wsType"]={[1]=4,[2]=4,[3]=34,[4]=291},["initialAmount"]=100},[242]={["wsType"]={[1]=4,[2]=4,[3]=34,[4]=91},["initialAmount"]=100},[243]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=1},["initialAmount"]=100},[244]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=10},["initialAmount"]=100},[245]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=106},["initialAmount"]=100},[246]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=11},["initialAmount"]=100},[247]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=11037},["initialAmount"]=100},[248]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=11038},["initialAmount"]=100},[249]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=11039},["initialAmount"]=100},[250]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=13},["initialAmount"]=100},[251]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=135},["initialAmount"]=100},[252]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=136},["initialAmount"]=100},[253]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=14},["initialAmount"]=100},[254]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=15},["initialAmount"]=100},[255]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=16},["initialAmount"]=100},[256]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=18},["initialAmount"]=100},[257]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=19},["initialAmount"]=100},[258]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=2},["initialAmount"]=100},[259]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=21},["initialAmount"]=100},[260]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=22},["initialAmount"]=100},[261]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=23},["initialAmount"]=100},[262]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=24},["initialAmount"]=100},[263]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=26},["initialAmount"]=100},[264]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=265},["initialAmount"]=100},[265]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=266},["initialAmount"]=100},[266]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=267},["initialAmount"]=100},[267]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=268},["initialAmount"]=100},[268]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=269},["initialAmount"]=100},[269]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=27},["initialAmount"]=100},[270]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=270},["initialAmount"]=100},[271]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=3},["initialAmount"]=100},[272]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=306},["initialAmount"]=100},[273]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=307},["initialAmount"]=100},[274]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=308},["initialAmount"]=100},[275]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=309},["initialAmount"]=100},[276]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=310},["initialAmount"]=100},[277]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=320},["initialAmount"]=100},[278]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=321},["initialAmount"]=100},[279]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=322},["initialAmount"]=100},[280]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=327},["initialAmount"]=100},[281]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=333},["initialAmount"]=100},[282]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=334},["initialAmount"]=100},[283]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=335},["initialAmount"]=100},[284]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=336},["initialAmount"]=100},[285]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=337},["initialAmount"]=100},[286]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=338},["initialAmount"]=100},[287]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=339},["initialAmount"]=100},[288]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=368},["initialAmount"]=100},[289]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=371},["initialAmount"]=100},[290]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=372},["initialAmount"]=100},[291]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=395},["initialAmount"]=100},[292]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=396},["initialAmount"]=100},[293]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=397},["initialAmount"]=100},[294]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=4},["initialAmount"]=100},[295]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=403},["initialAmount"]=100},[296]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=405},["initialAmount"]=100},[297]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=409},["initialAmount"]=100},[298]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=410},["initialAmount"]=100},[299]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=412},["initialAmount"]=100},[300]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=425},["initialAmount"]=100},[301]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=426},["initialAmount"]=100},[302]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=429},["initialAmount"]=100},[303]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=446},["initialAmount"]=100},[304]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=7},["initialAmount"]=100},[305]={["wsType"]={[1]=4,[2]=4,[3]=7,[4]=9},["initialAmount"]=100},[306]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=11031},["initialAmount"]=100},[307]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=11035},["initialAmount"]=100},[308]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=11040},["initialAmount"]=100},[309]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=11050},["initialAmount"]=100},[310]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=11051},["initialAmount"]=100},[311]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=11052},["initialAmount"]=100},[312]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=11053},["initialAmount"]=100},[313]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=11054},["initialAmount"]=100},[314]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=11092},["initialAmount"]=100},[315]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=11093},["initialAmount"]=100},[316]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=130},["initialAmount"]=100},[317]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=132},["initialAmount"]=100},[318]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=133},["initialAmount"]=100},[319]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=138},["initialAmount"]=100},[320]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=139},["initialAmount"]=100},[321]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=263},["initialAmount"]=100},[322]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=264},["initialAmount"]=100},[323]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=271},["initialAmount"]=100},[324]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=272},["initialAmount"]=100},[325]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=273},["initialAmount"]=100},[326]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=274},["initialAmount"]=100},[327]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=278},["initialAmount"]=100},[328]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=279},["initialAmount"]=100},[329]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=280},["initialAmount"]=100},[330]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=281},["initialAmount"]=100},[331]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=282},["initialAmount"]=100},[332]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=283},["initialAmount"]=100},[333]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=284},["initialAmount"]=100},[334]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=287},["initialAmount"]=100},[335]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=289},["initialAmount"]=100},[336]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=290},["initialAmount"]=100},[337]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=292},["initialAmount"]=100},[338]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=293},["initialAmount"]=100},[339]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=295},["initialAmount"]=100},[340]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=296},["initialAmount"]=100},[341]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=297},["initialAmount"]=100},[342]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=298},["initialAmount"]=100},[343]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=301},["initialAmount"]=100},[344]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=303},["initialAmount"]=100},[345]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=304},["initialAmount"]=100},[346]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=305},["initialAmount"]=100},[347]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=311},["initialAmount"]=100},[348]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=332},["initialAmount"]=100},[349]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=352},["initialAmount"]=100},[350]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=353},["initialAmount"]=100},[351]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=354},["initialAmount"]=100},[352]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=355},["initialAmount"]=100},[353]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=362},["initialAmount"]=100},[354]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=363},["initialAmount"]=100},[355]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=373},["initialAmount"]=100},[356]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=39},["initialAmount"]=100},[357]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=399},["initialAmount"]=100},[358]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=40},["initialAmount"]=100},[359]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=407},["initialAmount"]=100},[360]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=41},["initialAmount"]=100},[361]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=415},["initialAmount"]=100},[362]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=416},["initialAmount"]=100},[363]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=422},["initialAmount"]=100},[364]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=423},["initialAmount"]=100},[365]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=424},["initialAmount"]=100},[366]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=430},["initialAmount"]=100},[367]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=431},["initialAmount"]=100},[368]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=432},["initialAmount"]=100},[369]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=433},["initialAmount"]=100},[370]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=434},["initialAmount"]=100},[371]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=435},["initialAmount"]=100},[372]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=436},["initialAmount"]=100},[373]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=437},["initialAmount"]=100},[374]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=44},["initialAmount"]=100},[375]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=443},["initialAmount"]=100},[376]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=445},["initialAmount"]=100},[377]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=45},["initialAmount"]=100},[378]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=46},["initialAmount"]=100},[379]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=47},["initialAmount"]=100},[380]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=48},["initialAmount"]=100},[381]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=49},["initialAmount"]=100},[382]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=51},["initialAmount"]=100},[383]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=53},["initialAmount"]=100},[384]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=54},["initialAmount"]=100},[385]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=55},["initialAmount"]=100},[386]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=56},["initialAmount"]=100},[387]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=58},["initialAmount"]=100},[388]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=59},["initialAmount"]=100},[389]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=60},["initialAmount"]=100},[390]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=61},["initialAmount"]=100},[391]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=62},["initialAmount"]=100},[392]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=63},["initialAmount"]=100},[393]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=64},["initialAmount"]=100},[394]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=65},["initialAmount"]=100},[395]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=66},["initialAmount"]=100},[396]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=68},["initialAmount"]=100},[397]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=70},["initialAmount"]=100},[398]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=71},["initialAmount"]=100},[399]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=72},["initialAmount"]=100},[400]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=73},["initialAmount"]=100},[401]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=74},["initialAmount"]=100},[402]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=75},["initialAmount"]=100},[403]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=76},["initialAmount"]=100},[404]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=77},["initialAmount"]=100},[405]={["wsType"]={[1]=4,[2]=4,[3]=8,[4]=78},["initialAmount"]=100},[406]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=1000},["initialAmount"]=100},[407]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=1002},["initialAmount"]=100},[408]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=1003},["initialAmount"]=100},[409]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=1004},["initialAmount"]=100},[410]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=1005},["initialAmount"]=100},[411]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=1006},["initialAmount"]=100},[412]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=1007},["initialAmount"]=100},[413]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=1009},["initialAmount"]=100},[414]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=2558},["initialAmount"]=100},[415]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=2559},["initialAmount"]=100},[416]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=2560},["initialAmount"]=100},[417]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=2561},["initialAmount"]=100},[418]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=2562},["initialAmount"]=100},[419]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=2563},["initialAmount"]=100},[420]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=837},["initialAmount"]=100},[421]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=839},["initialAmount"]=100},[422]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=94},["initialAmount"]=100},[423]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=95},["initialAmount"]=100},[424]={["wsType"]={[1]=4,[2]=5,[3]=32,[4]=999},["initialAmount"]=100},[425]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=11},["initialAmount"]=100},[426]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=12},["initialAmount"]=100},[427]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=14},["initialAmount"]=100},[428]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=287},["initialAmount"]=100},[429]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=288},["initialAmount"]=100},[430]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=289},["initialAmount"]=100},[431]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=290},["initialAmount"]=100},[432]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=291},["initialAmount"]=100},[433]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=292},["initialAmount"]=100},[434]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=293},["initialAmount"]=100},[435]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=351},["initialAmount"]=100},[436]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=36},["initialAmount"]=100},[437]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=38},["initialAmount"]=100},[438]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=39},["initialAmount"]=100},[439]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=41},["initialAmount"]=100},[440]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=42},["initialAmount"]=100},[441]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=43},["initialAmount"]=100},[442]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=448},["initialAmount"]=100},[443]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=459},["initialAmount"]=100},[444]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=469},["initialAmount"]=100},[445]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=47},["initialAmount"]=100},[446]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=476},["initialAmount"]=100},[447]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=48},["initialAmount"]=100},[448]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=72},["initialAmount"]=100},[449]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=85},["initialAmount"]=100},[450]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=86},["initialAmount"]=100},[451]={["wsType"]={[1]=4,[2]=5,[3]=36,[4]=92},["initialAmount"]=100},[452]={["wsType"]={[1]=4,[2]=5,[3]=37,[4]=3},["initialAmount"]=100},[453]={["wsType"]={[1]=4,[2]=5,[3]=37,[4]=330},["initialAmount"]=100},[454]={["wsType"]={[1]=4,[2]=5,[3]=37,[4]=347},["initialAmount"]=100},[455]={["wsType"]={[1]=4,[2]=5,[3]=37,[4]=384},["initialAmount"]=100},[456]={["wsType"]={[1]=4,[2]=5,[3]=37,[4]=4},["initialAmount"]=100},[457]={["wsType"]={[1]=4,[2]=5,[3]=37,[4]=437},["initialAmount"]=100},[458]={["wsType"]={[1]=4,[2]=5,[3]=37,[4]=62},["initialAmount"]=100},[459]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=18},["initialAmount"]=100},[460]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=20},["initialAmount"]=100},[461]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=23},["initialAmount"]=100},[462]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=263},["initialAmount"]=100},[463]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=265},["initialAmount"]=100},[464]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=267},["initialAmount"]=100},[465]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=295},["initialAmount"]=100},[466]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=299},["initialAmount"]=100},[467]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=301},["initialAmount"]=100},[468]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=302},["initialAmount"]=100},[469]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=319},["initialAmount"]=100},[470]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=324},["initialAmount"]=100},[471]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=35},["initialAmount"]=100},[472]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=45},["initialAmount"]=100},[473]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=480},["initialAmount"]=100},[474]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=481},["initialAmount"]=100},[475]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=482},["initialAmount"]=100},[476]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=77},["initialAmount"]=100},[477]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=87},["initialAmount"]=100},[478]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=88},["initialAmount"]=100},[479]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=91},["initialAmount"]=100},[480]={["wsType"]={[1]=4,[2]=5,[3]=38,[4]=93},["initialAmount"]=100},[481]={["wsType"]={[1]=4,[2]=5,[3]=49,[4]=11086},["initialAmount"]=100},[482]={["wsType"]={[1]=4,[2]=5,[3]=49,[4]=11087},["initialAmount"]=100},[483]={["wsType"]={[1]=4,[2]=5,[3]=49,[4]=11088},["initialAmount"]=100},[484]={["wsType"]={[1]=4,[2]=5,[3]=49,[4]=11089},["initialAmount"]=100},[485]={["wsType"]={[1]=4,[2]=5,[3]=49,[4]=427},["initialAmount"]=100},[486]={["wsType"]={[1]=4,[2]=5,[3]=49,[4]=63},["initialAmount"]=100},[487]={["wsType"]={[1]=4,[2]=5,[3]=49,[4]=64},["initialAmount"]=100},[488]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=11033},["initialAmount"]=100},[489]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=11034},["initialAmount"]=100},[490]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=255},["initialAmount"]=100},[491]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=256},["initialAmount"]=100},[492]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=257},["initialAmount"]=100},[493]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=258},["initialAmount"]=100},[494]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=259},["initialAmount"]=100},[495]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=260},["initialAmount"]=100},[496]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=261},["initialAmount"]=100},[497]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=268},["initialAmount"]=100},[498]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=269},["initialAmount"]=100},[499]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=270},["initialAmount"]=100},[500]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=271},["initialAmount"]=100},[501]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=272},["initialAmount"]=100},[502]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=273},["initialAmount"]=100},[503]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=274},["initialAmount"]=100},[504]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=275},["initialAmount"]=100},[505]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=276},["initialAmount"]=100},[506]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=277},["initialAmount"]=100},[507]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=278},["initialAmount"]=100},[508]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=279},["initialAmount"]=100},[509]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=280},["initialAmount"]=100},[510]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=281},["initialAmount"]=100},[511]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=282},["initialAmount"]=100},[512]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=283},["initialAmount"]=100},[513]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=284},["initialAmount"]=100},[514]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=285},["initialAmount"]=100},[515]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=30},["initialAmount"]=100},[516]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=31},["initialAmount"]=100},[517]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=312},["initialAmount"]=100},[518]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=313},["initialAmount"]=100},[519]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=314},["initialAmount"]=100},[520]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=315},["initialAmount"]=100},[521]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=316},["initialAmount"]=100},[522]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=317},["initialAmount"]=100},[523]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=318},["initialAmount"]=100},[524]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=32},["initialAmount"]=100},[525]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=321},["initialAmount"]=100},[526]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=322},["initialAmount"]=100},[527]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=323},["initialAmount"]=100},[528]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=325},["initialAmount"]=100},[529]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=326},["initialAmount"]=100},[530]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=327},["initialAmount"]=100},[531]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=328},["initialAmount"]=100},[532]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=329},["initialAmount"]=100},[533]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=33},["initialAmount"]=100},[534]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=331},["initialAmount"]=100},[535]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=332},["initialAmount"]=100},[536]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=333},["initialAmount"]=100},[537]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=334},["initialAmount"]=100},[538]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=335},["initialAmount"]=100},[539]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=336},["initialAmount"]=100},[540]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=337},["initialAmount"]=100},[541]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=338},["initialAmount"]=100},[542]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=339},["initialAmount"]=100},[543]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=34},["initialAmount"]=100},[544]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=363},["initialAmount"]=100},[545]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=364},["initialAmount"]=100},[546]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=374},["initialAmount"]=100},[547]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=38},["initialAmount"]=100},[548]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=385},["initialAmount"]=100},[549]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=386},["initialAmount"]=100},[550]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=387},["initialAmount"]=100},[551]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=388},["initialAmount"]=100},[552]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=389},["initialAmount"]=100},[553]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=390},["initialAmount"]=100},[554]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=391},["initialAmount"]=100},[555]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=392},["initialAmount"]=100},[556]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=412},["initialAmount"]=100},[557]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=413},["initialAmount"]=100},[558]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=449},["initialAmount"]=100},[559]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=483},["initialAmount"]=100},[560]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=484},["initialAmount"]=100},[561]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=485},["initialAmount"]=100},[562]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=486},["initialAmount"]=100},[563]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=487},["initialAmount"]=100},[564]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=488},["initialAmount"]=100},[565]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=5},["initialAmount"]=100},[566]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=6},["initialAmount"]=100},[567]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=69},["initialAmount"]=100},[568]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=7},["initialAmount"]=100},[569]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=70},["initialAmount"]=100},[570]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=71},["initialAmount"]=100},[571]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=72},["initialAmount"]=100},[572]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=75},["initialAmount"]=100},[573]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=79},["initialAmount"]=100},[574]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=9},["initialAmount"]=100},[575]={["wsType"]={[1]=4,[2]=5,[3]=9,[4]=90},["initialAmount"]=100},[576]={["wsType"]={[1]=4,[2]=7,[3]=32,[4]=11048},["initialAmount"]=100},[577]={["wsType"]={[1]=4,[2]=7,[3]=32,[4]=11056},["initialAmount"]=100},[578]={["wsType"]={[1]=4,[2]=7,[3]=32,[4]=11090},["initialAmount"]=100},[579]={["wsType"]={[1]=4,[2]=7,[3]=32,[4]=619},["initialAmount"]=100},[580]={["wsType"]={[1]=4,[2]=7,[3]=32,[4]=659},["initialAmount"]=100},[581]={["wsType"]={[1]=4,[2]=7,[3]=32,[4]=661},["initialAmount"]=100},[582]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=11044},["initialAmount"]=100},[583]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=11049},["initialAmount"]=100},[584]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=11091},["initialAmount"]=100},[585]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=144},["initialAmount"]=100},[586]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=145},["initialAmount"]=100},[587]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=146},["initialAmount"]=100},[588]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=147},["initialAmount"]=100},[589]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=148},["initialAmount"]=100},[590]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=149},["initialAmount"]=100},[591]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=150},["initialAmount"]=100},[592]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=151},["initialAmount"]=100},[593]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=155},["initialAmount"]=100},[594]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=158},["initialAmount"]=100},[595]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=159},["initialAmount"]=100},[596]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=181},["initialAmount"]=100},[597]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=182},["initialAmount"]=100},[598]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=183},["initialAmount"]=100},[599]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=184},["initialAmount"]=100},[600]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=185},["initialAmount"]=100},[601]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=186},["initialAmount"]=100},[602]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=256},["initialAmount"]=100},[603]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=257},["initialAmount"]=100},[604]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=258},["initialAmount"]=100},[605]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=275},["initialAmount"]=100},[606]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=276},["initialAmount"]=100},[607]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=277},["initialAmount"]=100},[608]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=299},["initialAmount"]=100},[609]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=30},["initialAmount"]=100},[610]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=31},["initialAmount"]=100},[611]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=32},["initialAmount"]=100},[612]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=326},["initialAmount"]=100},[613]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=329},["initialAmount"]=100},[614]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=33},["initialAmount"]=100},[615]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=330},["initialAmount"]=100},[616]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=331},["initialAmount"]=100},[617]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=34},["initialAmount"]=100},[618]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=340},["initialAmount"]=100},[619]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=341},["initialAmount"]=100},[620]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=342},["initialAmount"]=100},[621]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=35},["initialAmount"]=100},[622]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=350},["initialAmount"]=100},[623]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=359},["initialAmount"]=100},[624]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=360},["initialAmount"]=100},[625]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=361},["initialAmount"]=100},[626]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=364},["initialAmount"]=100},[627]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=365},["initialAmount"]=100},[628]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=366},["initialAmount"]=100},[629]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=367},["initialAmount"]=100},[630]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=37},["initialAmount"]=100},[631]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=374},["initialAmount"]=100},[632]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=375},["initialAmount"]=100},[633]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=376},["initialAmount"]=100},[634]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=377},["initialAmount"]=100},[635]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=378},["initialAmount"]=100},[636]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=379},["initialAmount"]=100},[637]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=380},["initialAmount"]=100},[638]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=381},["initialAmount"]=100},[639]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=382},["initialAmount"]=100},[640]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=383},["initialAmount"]=100},[641]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=384},["initialAmount"]=100},[642]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=385},["initialAmount"]=100},[643]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=386},["initialAmount"]=100},[644]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=387},["initialAmount"]=100},[645]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=388},["initialAmount"]=100},[646]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=389},["initialAmount"]=100},[647]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=390},["initialAmount"]=100},[648]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=391},["initialAmount"]=100},[649]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=392},["initialAmount"]=100},[650]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=393},["initialAmount"]=100},[651]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=401},["initialAmount"]=100},[652]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=402},["initialAmount"]=100},[653]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=440},["initialAmount"]=100},[654]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=441},["initialAmount"]=100},[655]={["wsType"]={[1]=4,[2]=7,[3]=33,[4]=442},["initialAmount"]=100},[656]={["wsType"]={[1]=4,[2]=8,[3]=10,[4]=255},["initialAmount"]=100},[657]={["wsType"]={[1]=4,[2]=8,[3]=10,[4]=406},["initialAmount"]=100},[658]={["wsType"]={[1]=4,[2]=8,[3]=11,[4]=319},["initialAmount"]=100},[659]={["wsType"]={[1]=4,[2]=8,[3]=11,[4]=398},["initialAmount"]=100}}

---Add everything to the FARP warehouse; since 2.8.x, the FARPs spawn empty, hence making it impossible to rearm or refuel (even with all the necessary vehicles)
---@param farp any the FARP to be filled
function veafGrass.fillFarpWarehouse(farp)
	veaf.loggers.get(veafGrass.Id):debug("veafGrass.fillFarpWarehouse()")
	veaf.loggers.get(veafGrass.Id):trace("farp=[%s]", veaf.p(farp))
	local farpName = farp.name
	veaf.loggers.get(veafGrass.Id):trace("farpName=[%s]", veaf.p(farpName))
	local result = farpName ~= nil
	if not result then result, farpName = pcall(Unit.getUnitName, farp) end
	veaf.loggers.get(veafGrass.Id):trace("farpName=[%s]", veaf.p(farpName))
	if not result then result, farpName = pcall(Group.getGroupName, farp) end
	veaf.loggers.get(veafGrass.Id):trace("farpName=[%s]", veaf.p(farpName))
	if not result then result, farpName = pcall(Object.getName, farp) end
	veaf.loggers.get(veafGrass.Id):trace("farpName=[%s]", veaf.p(farpName))
	if farpName then
		local farpAirbase = Airbase.getByName(farpName)
		if farpAirbase then
			local farpWarehouse = farpAirbase:getWarehouse()
			if farpWarehouse then
				--veaf.loggers.get(veafGrass.Id):trace("inventory = %s", veaf.p(farpWarehouse:getInventory()))
				for _, datas in ipairs(veafGrass.WAREHOUSE_ITEMS) do
					local rnd = math.random(1, 100)
					farpWarehouse:setItem(datas.wsType, 5000+rnd)
				end
				for i = 0, 3, 1 do
					local rnd = math.random(1, 100)
					farpWarehouse:setLiquidAmount(i,50000+rnd)
				end
				for i = 0, 3 do
					veaf.loggers.get(veafGrass.Id):trace("getLiquidAmount(%s) = %s", i, veaf.p(farpWarehouse:getLiquidAmount(i)))
				end
			else
				veaf.loggers.get(veafGrass.Id):error("Airbase.getByName([%s]):getWarehouse() returned null", veaf.p(farpName))
			end
		else
			veaf.loggers.get(veafGrass.Id):error("Airbase.getByName([%s]) returned null", veaf.p(farpName))
		end
		veaf.loggers.get(veafGrass.Id):debug("FARP [%s] successfully replenished", veaf.p(farpName))
	end
end

------------------------------------------------------------------------------
-- build nice FARP units arround the FARP
-- @param unit farp : the FARP unit
------------------------------------------------------------------------------
function veafGrass.buildFarpUnits(farp, grassRunwayUnits, groupName, hiddenOnMFD, noFarpMarkers, code, freq, mod)
	veaf.loggers.get(veafGrass.Id):debug(string.format("buildFarpUnits()"))
	veaf.loggers.get(veafGrass.Id):trace(string.format("farp=%s",veaf.p(farp)))
	veaf.loggers.get(veafGrass.Id):trace(string.format("grassRunwayUnits=%s",veaf.p(grassRunwayUnits)))
	veaf.loggers.get(veafGrass.Id):trace(string.format("hiddenOnMFD=%s",veaf.p(hiddenOnMFD)))
	veaf.loggers.get(veafGrass.Id):trace(string.format("noFarpMarkers=%s",veaf.p(noFarpMarkers)))
	veaf.loggers.get(veafGrass.Id):trace(string.format("code=%s",veaf.p(code)))
	veaf.loggers.get(veafGrass.Id):trace(string.format("freq=%s",veaf.p(freq)))
	veaf.loggers.get(veafGrass.Id):trace(string.format("mod=%s",veaf.p(mod)))

	local freq = freq or math.random(90)+100
	local mod = mod or "X"
	local code = code or "FRP"

	-- add FARP to CTLD FOBs and logistic units
	local name = farp.name
	if not name then name = farp.unitName end
	if not name then name = farp.groupName end
	if ctld then
		table.insert(ctld.builtFOBS, name)
		table.insert(ctld.logisticUnits, name)
	end

	local farpUnitNameCounter=1
	local farpCoalition = farp.coalition
	local farpCoalitionNumber = farp.coalition
	if type(farpCoalition == "number") then
		if farpCoalition == 1 then
			farpCoalition = "red"
		else
			farpCoalition = "blue"
		end
	end
	if type(farpCoalition == 'string') then
		if farpCoalition == "red" then
			farpCoalitionNumber = 1
		else
			farpCoalitionNumber = 2
		end
	end

	local farpHeading = farp.heading or 0
	local angle = mist.utils.toDegree(farpHeading)
	local tentDistance = 100
	local tentSpacing = 30
	local otherDistance = 85
	local otherSpacing = 15
	local unitsDistance = 75

	-- fix distances on FARPs
	if farp.type == "SINGLE_HELIPAD" or farp.type == "FARP_SINGLE_01" or farp.type == "FARP" or farp.type == "Invisible FARP" then
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
				["unitName"] = string.format("FARP %s unit #%d", farp.groupName, farpUnitNameCounter),
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
			farpUnitNameCounter = farpUnitNameCounter + 1
		end
	end

	-- add visible markers to the invisible farps
	if farp.type == "Invisible FARP" and not noFarpMarkers then
		local markerDistance = 25
		local markerAngle = -45
		local markerUnit1 = {
			["unitName"] = string.format("FARP %s unit #%d", farp.groupName, farpUnitNameCounter),
			["category"] = "Unarmed",
			["type"] = "M978 HEMTT Tanker",
			["coalition"] = farpCoalition,
			["country"] = farp.country,
			["countryId"] = farp.countryId,
			["heading"] = mist.utils.toRadian(angle-90),
			["x"] = farp.x - markerDistance * math.cos(mist.utils.toRadian(angle + markerAngle)),
			["y"] = farp.y - markerDistance * math.sin(mist.utils.toRadian(angle + markerAngle)),
			["hiddenOnMFD"] = hiddenOnMFD,
		}
		if groupName then
			markerUnit1["groupName"] = groupName
		end
		mist.dynAddStatic(markerUnit1)
		farpUnitNameCounter = farpUnitNameCounter + 1
		local markerUnit2 = {
			["unitName"] = string.format("FARP %s unit #%d", farp.groupName, farpUnitNameCounter),
			["category"] = "Fortifications",
			["shape_name"] = "H-Windsock_RW",
			["type"] = "Windsock",
			["coalition"] = farpCoalition,
			["country"] = farp.country,
			["countryId"] = farp.countryId,
			["heading"] = mist.utils.toRadian(angle-90),
			["x"] = farp.x - markerDistance * math.cos(mist.utils.toRadian(angle - markerAngle)),
			["y"] = farp.y - markerDistance * math.sin(mist.utils.toRadian(angle - markerAngle)),
			["hiddenOnMFD"] = hiddenOnMFD,
		}
		if groupName then
			markerUnit2["groupName"] = groupName
		end
		mist.dynAddStatic(markerUnit2)
		farpUnitNameCounter = farpUnitNameCounter + 1
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
			["unitName"] = string.format("FARP %s unit #%d", farp.groupName, farpUnitNameCounter),
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
		farpUnitNameCounter = farpUnitNameCounter + 1
	end

	-- create Windsock
	local windsockDistance = 50
	local windsockAngle = 45

	-- fix Windsock position on FARPs
  if farp.type == "SINGLE_HELIPAD" or farp.type == "FARP_SINGLE_01" or farp.type == "FARP" or farp.type == "Invisible FARP" then
    windsockDistance = 120
		windsockAngle = 0
	end

	local windsockUnit = {
		["unitName"] = string.format("FARP %s unit #%d", farp.groupName, farpUnitNameCounter),
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
	farpUnitNameCounter = farpUnitNameCounter + 1

	-- on FARP unit, place a second windsock, at 90°
	if farp.type == 'FARP' then
		local windsockUnit = {
			["unitName"] = string.format("FARP %s unit #%d", farp.groupName, farpUnitNameCounter),
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
		farpUnitNameCounter = farpUnitNameCounter + 1
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
			["unitName"] = string.format("FARP %s unit #%d", farp.groupName, farpUnitNameCounter),
			["heading"] = mist.utils.toRadian(angle-135), -- parked \\\\\
			["type"] = typeName,
			["x"] = unitsOrigin.x - (j-1) * unitsSpacing * math.sin(mist.utils.toRadian(angle)),
			["y"] = unitsOrigin.y + (j-1) * unitsSpacing * math.cos(mist.utils.toRadian(angle)),
			["skill"] = "Random",
		}
		table.insert(farpEscortGroup.units, escortUnit)
		farpUnitNameCounter = farpUnitNameCounter + 1

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
        x = farp.x + 250,
        y = math.floor(land.getHeight(farp) + 1),
        z = farp.y
    }

	farpNamedPoint.tower = "No Control"

	if ctld then
		-- spawn tacan
		mod = string.upper(mod)
		local tacanGroupName = string.format("TACAN %s - %s%s", tostring(code), tostring(freq), tostring(mod))
		veaf.loggers.get(veafGrass.Id):trace(string.format("tacanGroupName=%s", tostring(tacanGroupName)))
		veaf.loggers.get(veafGrass.Id):trace(string.format("freq=%s", tostring(freq)))
		veaf.loggers.get(veafGrass.Id):trace(string.format("mod=%s", tostring(mod)))
		local txFreq = (1025 + freq - 1) * 1000000
		local rxFreq = (962 + freq - 1) * 1000000
		if (freq < 64 and mod == "Y") or (freq >= 64 and mod == "X") then
				rxFreq = (1088 + freq - 1) * 1000000
		end
		veaf.loggers.get(veafGrass.Id):trace(string.format("txFreq=%s", tostring(txFreq)))
		veaf.loggers.get(veafGrass.Id):trace(string.format("rxFreq=%s", tostring(rxFreq)))

		local command = {
				id = 'ActivateBeacon',
				params = {
						type = 4,
						system = 18,
						callsign = code,
						frequency = rxFreq,
						AA = false,
						channel = freq,
						bearing = true,
						modeChannel = mod,
				}
		}
		veaf.loggers.get(veafGrass.Id):trace(string.format("setting %s", veaf.p(command)))
    local spawnedGroup = ctld.spawnRadioBeaconUnit(beaconPoint, farp.country, tacanGroupName, tacanGroupName)
		local controller = spawnedGroup:getController()
		controller:setCommand(command)
		veaf.loggers.get(veafGrass.Id):trace(string.format("done setting TACAN command"))
		-- spawn CTLD beacon
		local _beaconInfo = ctld.createRadioBeacon(beaconPoint, farpCoalitionNumber, farp.country, farp.unitName or farp.name, -1, true)
		if _beaconInfo ~= nil then
			farpNamedPoint.tacan = string.format("ADF : %.2f KHz - %.2f MHz - %.2f MHz FM - %s", _beaconInfo.vhf / 1000, _beaconInfo.uhf / 1000000, _beaconInfo.fm / 1000000, tacanGroupName)
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
			if grassNamedPoint then
				farpNamedPoint.x = grassNamedPoint.x
				farpNamedPoint.y = grassNamedPoint.y
				farpNamedPoint.z = grassNamedPoint.z
				farpNamedPoint.atc = grassNamedPoint.atc
				farpNamedPoint.runways = grassNamedPoint.runways
			end
        end
    end
    veaf.loggers.get(veafGrass.Id):trace(string.format("farpNamedPoint=%s", veaf.p(farpNamedPoint)))

	veafNamedPoints.addPoint(farp.unitName or farp.name, farpNamedPoint)

	veaf.loggers.get(veafGrass.Id):trace(string.format("calling fillFarpWarehouse(%s)",name))
	veafGrass.fillFarpWarehouse(farp)
end

---
--- called from veafEventHandler when a unit is created
function veafGrass.onBirth(event)
	--veaf.loggers.get(veafGrass.Id):trace(string.format("onBirth(%s)",veaf.p(event)))

	-- find the originator unit
    local unitName = nil
    if event.initiator ~= nil then
        unitName = event.initiator.unitName
    end
    if not unitName then 
        veaf.loggers.get(veafGrass.Id):warn("no unitname found in event %s", veaf.p(event))
        return
    end

    if mist.DBs.humansByName[unitName] then -- it's a human unit
        veaf.loggers.get(veafGrass.Id):debug("caught event BIRTH for human unit [%s]", veaf.p(unitName))
        local _unit = event.initiator
        if _unit ~= nil then
			-- refill all farp warehouses, to work around a DCS bug where the warehouses are spawned empty and their content is not synced over the network
			veafGrass.fillAllFarpWarehouses()
        end
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafGrass.initialize()
	-- delay all these functions 30 seconds (to ensure that the other modules are loaded)

	-- auto generate FARP units (hide these units on MFDs as they create clutter for nothing since the FARP already shows or not depending on what the Mission maker wanted, regardless, don't show them)
    mist.scheduleFunction(veafGrass.buildFarpsUnits,{true},timer.getTime()+veafGrass.DelayForStartup)

	veafEventHandler.addCallback("veafGrass.OnBirth", {"S_EVENT_BIRTH", "S_EVENT_PLAYER_ENTER_UNIT"}, veafGrass.onBirth)
end

veaf.loggers.get(veafGrass.Id):info(string.format("Loading version %s", veafGrass.Version))
