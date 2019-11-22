mist = {}
mist.utils = {}

--- Converts angle in degrees to radians.
-- @param angle angle in degrees
-- @return angle in degrees
function mist.utils.toRadian(angle)
    return angle*math.pi/180
end

	function mist.utils.toDegree(angle)
		return angle*180/math.pi
	end

veaf = {}
math.randomseed(os.time())
--- Identifier. All output in DCS.log will start with this.
veaf.Id = "VEAF - "

--- Version.
veaf.Version = "1.1.1"

--- Development version ?
veaf.Development = true

--- Enable logDebug ==> give more output to DCS log file.
veaf.Debug = veaf.Development
--- Enable logTrace ==> give even more output to DCS log file.
veaf.Trace = veaf.Development

veaf.RadioMenuName = "VEAF"

function veaf.logError(text)
  print("ERROR VEAF - " .. text)
end

function veaf.logInfo(text)
  print("INFO VEAF - " .. text)
end

function veaf.logDebug(text)
  print("DEBUG VEAF - " .. text)
end

function veaf.logTrace(text)
  print("TRACE VEAF - " .. text)
end

function veaf.dummyFunction()
  veaf.logDebug("dummyFunction()")
end

function veaf.round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

function veaf.vecToString(vec)
    local result = ""
    if vec.x then
        result = result .. string.format(" x=%.1f", vec.x)
    end
    if vec.y then
        result = result .. string.format(" y=%.1f", vec.y)
    end
    if vec.z then
        result = result .. string.format(" z=%.1f", vec.z)
    end
    return result
end

function veaf.discoverTable(o)
    local text = ""
    for key,value in pairs(o) do
        if value then
            text = text .. " - ".. key.."="..value.."\n";
        else
            text = text .. " - ".. key.."\n";
        end
    end
	return text
end

veafMarkers = {}
function veafMarkers.registerEventHandler(a, b)
end

dofile("veafRadio.lua")

function veafRadio.buildHumanGroups()
  veafRadio.logInfo("buildHumanGroups()")
end

missionCommands = {}
function missionCommands.addSubMenu(title, path)
  veafRadio.logInfo("addSubMenu() " .. title)
end

function missionCommands.addCommand(title, dcsRadioMenu, method)
  veafRadio.logInfo("addCommand() " .. title)
end

function missionCommands.removeItem(item)
  veafRadio.logInfo("removeItem()")
end

function veafRadio.initialize()
    -- Build the initial radio menu
    veafRadio.buildHumanGroups()
    veafRadio.refreshRadioMenu()
    --veafRadio.radioRefreshWatchdog()
  end
  
veafRadio.initialize()

dofile("veafSecurity.lua")

veafSecurity.initialize()

function test1()
  veaf.logInfo(test1)
end

function test2()
  veaf.logInfo(test2)
end

local casRadioMenu = veafRadio.addSubMenu("VEAF CAS MISSION")
veafRadio.addCommandToSubmenu("HELP",casRadioMenu, veaf.dummyFunction)
local cas_Markers_RadioMenu = veafRadio.addSubMenu("Markers",casRadioMenu)
veafRadio.addCommandToSubmenu('Request smoke on target area', cas_Markers_RadioMenu, veaf.dummyFunction)
veafRadio.refreshRadioMenu()

if veafSecurity.checkPassword_L1("testpassword") then
  veaf.logError("password matches")
else
  veaf.logError("password do not match")
end

dofile("veafGrass.lua")
dofile("veafNamedPoints.lua")
function veafNamedPoints.getAtcAtPoint(parameters)
    local name, unitName = unpack(parameters)
    veafNamedPoints.logTrace(string.format("getAtcAtPoint(name = %s)",name))
    local point = veafNamedPoints.getPoint(name)
    if point then
        -- exanple : point={x=-315414,y=480,z=897262, atc=true, tower="138.00", runways={{name="12R", hdg=121, ils="110.30"},{name="30L", hdg=301, ils="108.90"}}}
        local atcReport = "ATC            : " .. name .. "\n"
        
        -- altitude and QFE
        local altitude = 0
        local qfeHp = "2992"
        local qfeinHg = "16.62"
        atcReport = atcReport .. "ALTITUDE       : " .. altitude .. " meters.\n"
        atcReport = atcReport .. "QFE            : " .. qfeHp .. " hPa / " .. qfeinHg .. " inHg.\n"

        -- wind
        local windDirection = 291
        local windStrength = 10
        local windText =     'no wind.\n'
        if windStrength > 0 then
            windText = string.format(
                'from %s at %s m/s.\n', windDirection, windStrength)
            end
        atcReport = atcReport .. "WIND           : " .. windText
        
        -- runway and other information
        if point.tower then
            atcReport = atcReport .. "TOWER          : " .. point.tower .. "\n"
        end
        if point.runways then
            for _, runway in pairs(point.runways) do
                if not runway.name then
                    runway.name = math.floor((runway.hdg/10)+0.5)
                end
                -- ils when available
                local ils = ""
                if runway.ils then
                    ils = " ILS " .. runway.ils
                end
                -- pop flare if needed
                local flare = ""
                if runway.flare then
                    -- TODO
                    flare = " marked with ".. runway.flare .. " flare"
                    --veafSpawn.spawnSignalFlare(point, runway.flare, runway.hdg)
                end
                atcReport = atcReport .. "RUNWAY         : " .. runway.name .. " heading " .. runway.hdg .. ils .. flare .. "\n"
            end
        end

        -- weather
        --atcReport = atcReport .. "\n\n"
        --local weatherReport = weathermark._WeatherReport(point, altitude, "imperial")
        --atcReport = atcReport ..weatherReport
        print(atcReport)
    end
end

dofile("mission-specific\\caucasus\\veafNamedPointsConfig.lua")
veafNamedPoints.initialize()

--veafNamedPoints.getAtcAtPoint({"AIRBASE Tbilisi", 0})
veafNamedPoints.getAtcAtPoint({"AIRBASE Sukhumi", 0})

function veaf.discover(o)
    return veaf._discover(o, 0)
end

function veaf._discover(o, level)
    local text = ""
    if (type(o) == "table") then
        text = "\n"
        for key,value in pairs(o) do
            for i=0, level do
                text = text .. " "
            end
            text = text .. ".".. key.."="..veaf._discover(value, level+1);
        end
    else
        text = text .. o .."\n";
    end
    return text
end

local callsign={}
callsign["1"]=7
callsign["2"]={}
callsign["2"]["toto"]="toto"
callsign["2"]["titi"]="toto"
callsign["name"]="Chevy41"

print(veaf.discover(callsign))
