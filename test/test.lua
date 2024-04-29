function _(value)
  return value
end

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

local type = "I[-]16"
local unitType = "F-16CM_50"
print(string.match(unitType:lower(), type:lower()))
