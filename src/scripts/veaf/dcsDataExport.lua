-- execute(dofile) this script at the end of
-- of 'DCS World\MissionEditor\modules\me_mission.lua'
-- base.dofile([[D:\dev\_VEAF\VEAF-Mission-Creation-Tools\src\scripts\veaf\dcsDataExport.lua]])

-------------------------------------------------------------------------------
-- settings
-------------------------------------------------------------------------------

--local export_path = [[c:\Users\dpier\Saved Games\DCS.openbeta\Logs\ObjectDB\]]
local export_path = [[.\]]

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Logging
-------------------------------------------------------------------------------------------------------------------------------------------------------------
DcsDataExport = {}
DcsDataExport.loggers = {}
DcsDataExport.loggers.dict = {}

DcsDataExport.Logger =
{
    -- technical name
    name = nil,
    -- logging level
    level = nil,
}
DcsDataExport.Logger.__index = DcsDataExport.Logger

DcsDataExport.Logger.LEVEL = {
    ["error"]=1,
    ["warning"]=2,
    ["info"]=3,
    ["debug"]=4,
    ["trace"]=5,
}

function DcsDataExport.Logger:new(name, level)
    local self = setmetatable({}, DcsDataExport.Logger)
    self:setName(name)
    self:setLevel(level)
    return self
end

function DcsDataExport.Logger:setName(value)
    self.name = value
    return self
end

function DcsDataExport.Logger:getName()
    return self.name
end

function DcsDataExport.Logger:setLevel(value, force)
    if DcsDataExport.ForcedLogLevel then
        value = DcsDataExport.ForcedLogLevel
    end
    local level = value
    if type(level) == "string" then
        level = DcsDataExport.Logger.LEVEL[level:lower()]
    end
    if not level then 
        level = DcsDataExport.Logger.LEVEL["info"]
    end
    if DcsDataExport.BaseLogLevel and DcsDataExport.BaseLogLevel < level and not force then
        level = DcsDataExport.BaseLogLevel
    end
    self.level = level
    return self
end

function DcsDataExport.Logger:getLevel()
    return self.level
end

function DcsDataExport.Logger.splitText(text)
    local tbl = {}
    while text:len() > 4000 do
        local sub = text:sub(1, 4000)
        text = text:sub(4001)
        table.insert(tbl, sub)
    end
    table.insert(tbl, text)
    return tbl
end

function DcsDataExport.Logger.formatText(text, ...)
    if not text then 
        return "" 
    end
    if type(text) ~= 'string' then
        text = DcsDataExport.p(text)
    else
        if arg and #arg > 0 then
            text = text:format(unpack(arg))
        end            
    end
    local fName = nil
    local cLine = nil
    if debug then
        local dInfo = debug.getinfo(3)
        fName = dInfo.name
        cLine = dInfo.currentline
        -- local fsrc = dinfo.short_src
        --local fLine = dInfo.linedefined
    end
    if fName and cLine then
        return fName .. '|' .. cLine .. ': ' .. text
    elseif cLine then
        return cLine .. ': ' .. text
    else
        return ' ' .. text
    end
end

function DcsDataExport.Logger:print(level, text)
    local texts = DcsDataExport.Logger.splitText(text)
    local levelChar = 'E'
    if level == DcsDataExport.Logger.LEVEL["warning"] then
        levelChar = 'W'
    elseif level == DcsDataExport.Logger.LEVEL["info"] then
        levelChar = 'I'
    elseif level == DcsDataExport.Logger.LEVEL["debug"] then
        levelChar = 'D'
    elseif level == DcsDataExport.Logger.LEVEL["trace"] then
        levelChar = 'T'
    end
    for i = 1, #texts do
        if i == 1 then
            print(self.name .. '|' .. levelChar .. '|' .. texts[i])
        else
            print(texts[i])
        end
    end
end

function DcsDataExport.Logger:error(text, ...)
    if self.level >= 1 then
        text = DcsDataExport.Logger.formatText(text, unpack(arg))
        self:print(1, text)
    end
end

function DcsDataExport.Logger:warn(text, ...)
    if self.level >= 2 then
        text = DcsDataExport.Logger.formatText(text, unpack(arg))
        self:print(2, text)
    end
end

function DcsDataExport.Logger:info(text, ...)
    if self.level >= 3 then
        text = DcsDataExport.Logger.formatText(text, unpack(arg))
        self:print(3, text)
    end
end

function DcsDataExport.Logger:debug(text, ...)
    if self.level >= 4 then
        text = DcsDataExport.Logger.formatText(text, unpack(arg))
        self:print(4, text)
    end
end

function DcsDataExport.Logger:trace(text, ...)
    if self.level >= 5 then
        text = DcsDataExport.Logger.formatText(text, unpack(arg))
        self:print(5, text)
    end
end

function DcsDataExport.loggers.setBaseLevel(level) 
    DcsDataExport.BaseLogLevel = level
    -- reset all loggers level if lower than the base level
    for name, logger in pairs(DcsDataExport.loggers.dict) do
        logger:setLevel(logger:getLevel())
    end
end

function DcsDataExport.loggers.new(loggerId, level) 
    if not loggerId or #loggerId == 0 then
        return nil
    end
    local result = DcsDataExport.Logger:new(loggerId:upper(), level)
    DcsDataExport.loggers.dict[loggerId:lower()] = result
    return result
end

function DcsDataExport.loggers.get(loggerId) 
    local result = nil
    if loggerId and #loggerId > 0 then
        result = DcsDataExport.loggers.dict[loggerId:lower()]
    end
    if not result then 
        result = DcsDataExport.loggers.get("DcsDataExport")
    end
    return result
end

function DcsDataExport.p(obj, maxLevel, skip, serializeInLua)
    local skip = skip
    if skip and type(skip)=="table" then
        for _, value in ipairs(skip) do
            skip[value]=true
        end
    end
    return DcsDataExport._p(nil, obj, maxLevel, 0, skip, serializeInLua)
end

function DcsDataExport._p(objKey, objValue, maxLevel, level, skip, serializeInLua)
    local function getSerializationForSingle(value)
        if value == nil then
            if serializeInLua then
                return "nil"
            else
                return getSerializationForSingle("[nil]")
            end
        elseif serializeInLua and type(value)=="string" then
            return "\"" .. string.gsub(value, [["]], [[\"]]) .. "\""
        else
            return tostring(value)
        end
    end

    local function alphanumsort(o)
        local function conv(s)
           local res, dot = "", ""
           for n, m, c in tostring(s):gmatch"(0*(%d*))(.?)" do
              if n == "" then
                 dot, c = "", dot..c
              else
                 res = res..(dot == "" and ("%03d%s"):format(#m, m)
                                       or "."..n)
                 dot, c = c:match"(%.?)(.*)"
              end
              res = res..c:gsub(".", "\0%0")
           end
           return res
        end
        table.sort(o,
           function (a, b)
              local ca, cb = conv(a), conv(b)
              return ca < cb or ca == cb and a < b
           end)
        return o
     end
     
    local MAX_LEVEL = 20
    if level == nil then level = 0 end
    if level > MAX_LEVEL then 
        logError("max depth reached in p : "..tostring(MAX_LEVEL))
        return ""
    end

    local text = ""
    if (type(objValue) == "table") then
        if 
        (maxLevel and level >= maxLevel) 
        or
        (skip and skip[objKey])
        then
            text = getSerializationForSingle("[table]")
        else
            if level > 0 then
                text = text .. "\n"
            end
            local keys = {}
            local realKeys = {}
            for realKey, _ in pairs(objValue) do
                local key = tostring(realKey)
                realKeys[key] = realKey
                table.insert(keys, key)
            end
            keys = alphanumsort(keys)
        
            local firstElement = true
            for _, key in pairs(keys) do
                local padding = ""
                for i=0, level do
                    if serializeInLua then
                        padding = padding .. "    "
                    else
                        padding = padding .. "---|"
                    end
                end
                local value = objValue[realKeys[key]]
                local carriageReturn = "\n"
                local result, wasTable = DcsDataExport._p(key, value, maxLevel, level+1, skip, serializeInLua)
                if wasTable then
                    carriageReturn = ""
                end
                if serializeInLua then
                    text = text .. padding
                    if not firstElement then
                        text = text .. ","
                    end
                    local realKey = realKeys[key]
                    if type(realKey) == "number" then
                        text = text .. "[" .. key .."] = "
                    else
                        text = text .. "[\"" .. key .."\"] = "
                    end
                    if wasTable then
                        text = text .. "{" .. result .. carriageReturn
                        text = text .. padding .. "}\n"
                    else
                        text = text .. result .. carriageReturn
                    end
                else
                    text = text .. padding .. ".".. key.."=".. result .. carriageReturn
                end
                firstElement = false
            end
            return text, true
        end
    elseif (type(objValue) == "function") then
        text = getSerializationForSingle("[function]")
    elseif (type(objValue) == "boolean") then
        if objValue == true then 
            text = getSerializationForSingle("[true]")
        else
            text = getSerializationForSingle("[false]")
        end
    else
        text = getSerializationForSingle(objValue)
    end
    return text, false
end


--DcsDataExport.loggers.setBaseLevel(DcsDataExport.Logger.LEVEL["trace"])
DcsDataExport.Id = "DCSEXPORT"
DcsDataExport.loggers.new(DcsDataExport.Id, "trace")

-------------------------------------------------------------------------------
-- helper functions
-------------------------------------------------------------------------------

local function writeln(file, text)
    file:write(text.."\r\n")
end

local function safe_name(name)
    local safeName = name
    safeName = string.gsub(safeName, "[-()/., *'+`#%[%]]", "_")
    safeName = string.gsub(safeName, "_*$", "")  -- strip __ from end
    safeName = string.gsub(safeName, "^([0-9])", "_%1")
    if safeName == 'None' then
        safeName = 'None_'
    end
    return safeName
end

local function has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

--- Serializes the give variable to a string. Stolen from MisT
-- borrowed from slmod
-- @param var variable to serialize
-- @treturn string variable serialized to string
function DcsDataExport.basicSerialize(var)
    if var == nil then
        return "\"\""
    else
        if ((type(var) == 'number') or
                (type(var) == 'boolean') or
                (type(var) == 'function') or
                (type(var) == 'table') or
                (type(var) == 'userdata') ) then
            return tostring(var)
        elseif type(var) == 'string' then
            var = string.format('%q', var)
            return var
        end
    end
end

--- Serialize value
-- borrowed from slmod (serialize_slmod)
-- @param name
-- @param value value to serialize
-- @param level
function DcsDataExport.serialize(name, value, level)
	--Based on ED's serialize_simple2
	local function basicSerialize(o)
		if type(o) == "number" then
			return tostring(o)
		elseif type(o) == "boolean" then
			return tostring(o)
		else -- assume it is a string
			return DcsDataExport.basicSerialize(o)
		end
	end

	local function serializeToTbl(name, value, level)
		local var_str_tbl = {}
		if level == nil then
			level = ""
		end
		if level ~= "" then 
			level = level.."" 
		end
		table.insert(var_str_tbl, level .. name .. " = ")

		if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
			table.insert(var_str_tbl, basicSerialize(value) ..	",\n")
		elseif type(value) == "table" then
			table.insert(var_str_tbl, "\n"..level.."{\n")

			for k,v in pairs(value) do -- serialize its fields
				local key
				if type(k) == "number" then
					key = string.format("[%s]", k)
				else
					key = string.format("[%q]", k)
				end
				table.insert(var_str_tbl, DcsDataExport.serialize(key, v, level.."	"))

			end
			if level == "" then
				table.insert(var_str_tbl, level.."} -- end of "..name.."\n")

			else
				table.insert(var_str_tbl, level.."}, -- end of "..name.."\n")

			end
		else
			log:error('Cannot serialize a $1', type(value))
		end
		return var_str_tbl
	end

	local t_str = serializeToTbl(name, value, level)

	return table.concat(t_str)
end

local function _sortUnits(u1,u2)
    if u1 and u1.category and u2 and u2.category then
        if string.lower(u1.category) == string.lower(u2.category) then 
            if u1 and u1.type and u2 and u2.type then
                return string.lower(u1.type) < string.lower(u2.type)
            elseif u1 and u1.name and u2 and u2.name then
                return string.lower(u1.name) < string.lower(u2.name)
            else
                return string.lower(u1) < string.lower(u2)
            end
        else
            return string.lower(u1.category) < string.lower(u2.category)
        end
    else
        return string.lower(u1) < string.lower(u2)
    end
end

local function browseUnits(out, database, defaultCategory, fullDcsUnit, exportAllAttributes)
    for _, unit in pairs(database) do
        if fullDcsUnit then
            out[unit["type"]] = unit
        else
            out[unit["type"]] = {}
            local u = out[unit["type"]]
            u.category = unit["category"]
            if not u.category then 
                u.category = defaultCategory
            end
            u.type = unit["type"]
            u.name = unit["Name"]
            u.description = unit["DisplayName"]
            u.aliases = {}
            if unit["Aliases"] then 
                for _, alias in pairs(unit["Aliases"]) do
                    table.insert(u.aliases, alias)
                end
            end
            if unit["attribute"] then
                if exportAllAttributes then
                    u.attribute = {}
                    for _, attribute in pairs(unit["attribute"]) do
                        u.attribute[attribute] = true
                    end
                end
                for _, attr in pairs(unit["attribute"]) do
                    if type(attr) == "string" then
                        if attr:lower() == "ships" then u.naval = true end
                        if attr:lower() == "air" then u.air = true end
                        if attr:lower() == "infantry" then u.infantry = true end
                        if attr:lower() == "vehicles" then u.vehicle = true end
                    end
                end
            end
            if unit["isPutToWater"] and type(unit["isPutToWater"]) == 'boolean' then
                u.isPutToWater = unit["isPutToWater"]
            end
            if u.category == "Cargo" then
                u.defaultMass = 0
                if u.category == "Cargo" and unit["mass"] and type(unit["mass"]) == 'number' then
                    u.defaultMass = unit["mass"]
                end
                u.desc = {}
                if u.category == "Cargo" and unit["maxMass"] and unit["minMass"] and type(unit["maxMass"]) == 'number' and type(unit["minMass"]) == 'number' then
                    u.desc.minMass = unit["minMass"]
                    u.desc.maxMass = unit["maxMass"]
                end
            end

        end
    end
end

-- export all units as a lua file
local file = io.open(export_path.."db.Units.lua", "w")
writeln(file, "db={\n    [\"Units\"] = {" .. DcsDataExport.p(db.Units, nil, nil, true).."}\n}")
if file then file:close() end

local units = {}
local fullDcsUnit = false
local exportAllAttributes = true
browseUnits(units, db.Units.Animals.Animal, "Animal", fullDcsUnit, exportAllAttributes)
browseUnits(units, db.Units.Cargos.Cargo, "Cargo", fullDcsUnit, exportAllAttributes)
browseUnits(units, db.Units.Cars.Car, "Vehicle", fullDcsUnit, exportAllAttributes)
browseUnits(units, db.Units.Effects.Effect, "Effect", fullDcsUnit, exportAllAttributes)
browseUnits(units, db.Units.Fortifications.Fortification, "Fortification", fullDcsUnit, exportAllAttributes)
browseUnits(units, db.Units.GrassAirfields.GrassAirfield, "GrassAirfield", fullDcsUnit, exportAllAttributes)
browseUnits(units, db.Units.GroundObjects.GroundObject, "GroundObject", fullDcsUnit, exportAllAttributes)
browseUnits(units, db.Units.Helicopters.Helicopter, "Helicopter", fullDcsUnit, exportAllAttributes)
browseUnits(units, db.Units.Heliports.Heliport, "Heliport", fullDcsUnit, exportAllAttributes)
browseUnits(units, db.Units.Personnel.Personnel, "Personnel", fullDcsUnit, exportAllAttributes)
browseUnits(units, db.Units.Planes.Plane, "Plane", fullDcsUnit, exportAllAttributes)
browseUnits(units, db.Units.Ships.Ship, "Ship", fullDcsUnit, exportAllAttributes)
browseUnits(units, db.Units.Warehouses.Warehouse, "Warehouse", fullDcsUnit, exportAllAttributes)
local values = {}
if fullDcsUnit then
    values = units    
else
    for _,v in pairs(units) do
        table.insert(values,v)
    end
    table.sort(values, _sortUnits)
end
file = io.open(export_path.."dcsUnits.lua", "w")
writeln(file, DcsDataExport.serialize("units", values))
if file then file:close() end