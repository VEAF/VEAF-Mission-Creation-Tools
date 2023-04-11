function P(o, level, skip)
  if o and type(o) == "table" and (o.x and o.z and o.y and #o == 3) then
      return string.format("{x=%s, z=%s, y=%s}", P(o.x), P(o.z), P(o.y))
  elseif o and type(o) == "table" and (o.x and o.y and #o == 2)  then
      return string.format("{x=%s, y=%s}", P(o.x), P(o.y))
  end
  local skip = skip
  if skip and type(skip)=="table" then
      for _, value in ipairs(skip) do
          skip[value]=true
      end
  end
  return _P(o, level, skip)
end

function _P(o, level, skip)
  local MAX_LEVEL = 20
  if level == nil then level = 0 end
  if level > MAX_LEVEL then
      return ""
  end
  local text = ""
  if o == nil then
      text = "[nil]"
  elseif (type(o) == "table") then
      text = "\n"
      local keys = {}
      local values = {}
      for key, value in pairs(o) do
          local sKey = tostring(key)
          table.insert(keys, sKey)
          values[sKey] = value
      end
      table.sort(keys)
      for _, key in pairs(keys) do
          local value = values[key]
          for i=0, level do
              text = text .. " "
          end
          if not (skip and skip[key]) then
              text = text .. ".".. key.."="..P(value, level+1, skip) .. "\n"
          else
              text = text .. ".".. key.."= [[SKIPPED]]\n"
          end
      end
  elseif (type(o) == "function") then
      text = "[function]"
  elseif (type(o) == "boolean") then
      if o == true then
          text = "[true]"
      else
          text = "[false]"
      end
  else
      text = tostring(o)
  end
  return text
end


---adds a wave of enemy planes
---parameters can be:
--- a table containing the following fields:
---     - groups a list of groups or VEAF commands; VEAF commands can be prefixed with [lat, lon], specifying the location of their spawn relative to the center of the zone; default value is set with "setRespawnDefaultOffset"
---     - number how many of these groups will actually be spawned (can be multiple times the same group!); it can be a "randomizable number", e.g., "2-6" for "between 2 and 6"
---     - bias shifts the random generator to the right of the list; it can be a "randomizable number" too
---     - delay the delay between this wave and the next one - if negative, then the next wave is spawned instantaneously (no waiting for this wave to be completed); it can be a "randomizable number" too
--- or a list of strings (the groups or VEAF commands)
---returns self
function addWave(...)
  local nArgs = arg.n or 0
  if arg and nArgs > 0 then
    local groups = {}
    local number = 1
    local bias = 0
    local delay = nil
    for i = 1, nArgs, 1 do
      local parameter = arg[i]
      if type(parameter) == "string" then
        table.insert(groups, parameter)
      elseif type(parameter) == "table" then
        if parameter.groups then
          -- this is a parameters table, let's use it
          if type(parameter.groups) == "string" then
            -- we need a table
            groups = { parameter.groups }
          else
            groups = parameter.groups
          end
          number = parameter.number
          bias = parameter.bias
          delay = parameter.delay
          break
        else
          for j = 1, #parameter, 1 do
            local s = parameter[j]
            if type(s) == "string" then
              table.insert(groups, parameter)
            end
          end
          break
        end
      end
    end
    return {groups=groups, number=number or 1, bias=bias or 0, delay=delay}
  end
end

function getRandomizableNumeric_random(val)
  local MIN = 0
  local MAX = 99
  local nVal = tonumber(val)
  if nVal == nil then
    local dashPos = string.find(val,"%-")
    if dashPos then 
      local lower = val:sub(1, dashPos-1)
      if lower then 
        lower = tonumber(lower)
      end
      if lower == nil then
        lower = MIN
      end
      local upper = val:sub(dashPos+1)
      if upper then 
        upper = tonumber(upper)
      end
      if upper == nil then
        upper = MAX
      end
      nVal = math.random(lower, upper)
    end
  end
  return nVal
end

function makeVec3(vec, y)
  if not vec.z then
    if vec.alt and not y then
      y = vec.alt
    elseif not y then
      y = 0
    end
    return {x = vec.x, y = y, z = vec.y}
  else
    return {x = vec.x, y = vec.y, z = vec.z}	-- it was already Vec3, actually.
  end
end

function deepCopy(object)
  local lookup_table = {}
  local function _copy(object)
    if type(object) ~= "table" then
      return object
    elseif lookup_table[object] then
      return lookup_table[object]
    end
    local new_table = {}
    lookup_table[object] = new_table
    for index, value in pairs(object) do
      new_table[_copy(index)] = _copy(value)
    end
    return setmetatable(new_table, getmetatable(object))
  end
  return _copy(object)
end

function _PointInPolygon(point, poly, maxalt) --raycasting point in polygon. Code from http://softsurfer.com/Archive/algorithm_0103/algorithm_0103.htm
	--[[local type_tbl = {
		point = {'table'},
		poly = {'table'},
		maxalt = {'number', 'nil'},
		}

	local err, errmsg = typeCheck('mist.pointInPolygon', type_tbl, {point, poly, maxalt})
	assert(err, errmsg)
	]]
	point = makeVec3(point)
	local px = point.x
	local pz = point.z
	local cn = 0
	local newpoly = deepCopy(poly)

	if not maxalt or (point.y <= maxalt) then
		local polysize = #newpoly
		newpoly[#newpoly + 1] = newpoly[1]

		newpoly[1] = makeVec3(newpoly[1])

		for k = 1, polysize do
			newpoly[k+1] = makeVec3(newpoly[k+1])
			if ((newpoly[k].z <= pz) and (newpoly[k+1].z > pz)) or ((newpoly[k].z > pz) and (newpoly[k+1].z <= pz)) then
				local vt = (pz - newpoly[k].z) / (newpoly[k+1].z - newpoly[k].z)
				if (px < newpoly[k].x + vt*(newpoly[k+1].x - newpoly[k].x)) then
					cn = cn + 1
				end
			end
		end

		return cn%2 == 1
	else
		return false
	end
end

local poly = {
  [1] = {
    x = -221054.1448788,
    y = -231563.76460471,
  },
  [2] = {
    x = -219505.858408,
    y = 147766.42074123,
  },
  [3] = {
    x = 267430.23665851,
    y = 137702.55868103,
  },
  [4] = {
    x = 268978.52312931,
    y = -219951.61607371,
  }
}

local point = {
  x = 15103.758720398,
  y = 10662.527549988,
  z = -43786.267360434,
}

print(_PointInPolygon(point, poly))