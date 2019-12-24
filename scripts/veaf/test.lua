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

veafInterpreter = {}
--- Key phrase to look for in the unit name which triggers the interpreter.
veafInterpreter.Starter = "#veafInterpreter%[\""
veafInterpreter.Trailer = "\"%]"

local text = "#veafInterpreter[\"_spawn group, name RU supply convoy with light defense\"]"
local p1, p2 = text:find(veafInterpreter.Starter)
local p_start = 0
local p_end = 0
local command = nil
if p2 then 
  -- starter has been found
  text = text:sub(p2 + 1)
  p1, p2 = text:find(veafInterpreter.Trailer)
  if p1 then
    command = text:sub(1, p1 - 1)
  end
end
print("["..command.."]")

local text = "#command=\"_spawn group, name sa6\" #spawnRadius=250"
local p1, p2, spawnRadius, command 
p1, p2, spawnRadius = text:find("#spawnRadius%s*=%s*(%d+)")
p1, p2, command = text:find("#command%s*=%s*\"(.+)\"")
print(spawnRadius)