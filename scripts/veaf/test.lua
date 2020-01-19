require 'lfs'
require 'os'
require 'veafMissionEditor'

local DIR = "a:\\tmp\\Mission Stats"
local result = {}
for filePath in lfs.dir(DIR) do
  if lfs.attributes(filePath,"mode") ~= "directory" then 
    local file = assert(loadfile(DIR.."\\"..filePath))
    if not file then
        return
    end
    
    file()
    for id, stats in pairs(misStats) do
      for _, callsign in pairs(stats.names) do
        if callsign and string.len(callsign) > 0 then 
          if not result[callsign] then 
            result[callsign] = { lastJoin = 0, aircrafts={}, total = 0}
          end
          local _result = result[callsign]
          if stats.lastJoin and stats.lastJoin > _result.lastJoin then
            _result.lastJoin = stats.lastJoin
          end
          for aircraft, data in pairs(stats.times) do
            if not _result.aircrafts[aircraft] then 
              _result.aircrafts[aircraft] = { inAir = 0, total = 0}
            end
            local _acData = _result.aircrafts[aircraft]
            if data.inAir then 
              _acData.inAir = _acData.inAir + data.inAir
            end
            if data.total then
              _acData.total = _acData.total + data.total
              _result.total = _result.total + data.total
            end
          end
        end
      end
    end
  end
end

local tableAsLua = veafMissionEditor.serialize("stats", result)
veafMissionEditor.writeMissionFile("a:\\tmp\\Mission_Stats_summary.lua", tableAsLua)

local function _sortVEAFOrCaseInsensitive(a,b)
  if type(a) == "string" or type(b) == "string" then
    local sA = string.lower(a)
    local sB = string.lower(b)
    if string.sub(sA, 1,4) == "veaf" and string.sub(sB, 1,4) == "veaf" then 
        return sA < sB
    elseif string.sub(sA, 1,4) == "veaf" then
      return true
    elseif string.sub(sB, 1,4) == "veaf" then
      return false
    else
      return sA < sB
    end   
  else
    return a < b
  end
end

local xmlText = '<xml>\n  <pilots>\n'
local bbText = ''
local tkeys = {}
-- populate the table that holds the keys
for k in pairs(result) do table.insert(tkeys, k) end
-- sort the keys
table.sort(tkeys, _sortVEAFOrCaseInsensitive)
-- use the keys to retrieve the values in the sorted order
for _, k in ipairs(tkeys) do  -- serialize its fields
  local data = result[k]
  local callsign = k
  xmlText = xmlText .. string.format('    <pilot name="%s">\n',callsign)
  bbText = bbText .. string.format('**%s**\n',callsign)
  if data.lastJoin then
    local _temp = os.date("*t", data.lastJoin)
    local _lastJoin = string.format("%02d/%02d/%04d %02d:%02d",_temp.day, _temp.month, _temp.year, _temp.hour, _temp.min)
    xmlText = xmlText .. string.format('      <lastJoin>%s</lastJoin>\n',_lastJoin)
    bbText = bbText .. string.format('- Dernière connexion : %s\n',_lastJoin)
  end
  if data.total then
    xmlText = xmlText .. string.format('      <total>%.2f</total>\n',data.total / 3600)
    bbText = bbText .. string.format('- Temps de vol total : %.2fh\n',data.total / 3600)
  end
  xmlText = xmlText .. '      <aircrafts>\n'
  bbText = bbText .. '- Appareils :\n'
  for aircraft, acData in pairs(data.aircrafts) do
    xmlText = xmlText .. string.format('        <aircraft type="%s">\n',aircraft)
    bbText = bbText .. string.format('  * %s: ',aircraft)
    if acData.inAir then 
      xmlText = xmlText .. string.format('          <inAir>%.2f</inAir>\n', acData.inAir / 3600)
      bbText = bbText .. string.format("%.2fh en l'air",acData.inAir / 3600)
    end
    if acData.total then
      xmlText = xmlText .. string.format('          <total>%.2f</total>\n',acData.total / 3600)
      bbText = bbText .. string.format(', %.2fh au total',acData.total / 3600)
    end
    bbText = bbText .. '\n'
    xmlText = xmlText .. '        </aircraft>\n'
  end  
  xmlText = xmlText .. string.format('      </aircrafts>\n')
  xmlText = xmlText .. '    </pilot>\n'
  bbText = bbText .. '\n'
end
xmlText = xmlText .. '  </pilots>\n</xml>'

local tableAsLua = veafMissionEditor.serialize("stats", result)
veafMissionEditor.writeMissionFile("a:\\tmp\\Mission_Stats_summary.xml", xmlText)
veafMissionEditor.writeMissionFile("a:\\tmp\\Mission_Stats_summary.bb", bbText)

