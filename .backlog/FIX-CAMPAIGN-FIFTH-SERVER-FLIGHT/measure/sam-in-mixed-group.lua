-- FIX-CAMPAIGN-FIFTH-SERVER-FLIGHT 02 — does a SAM made of separate radars and launchers fire from inside a large
-- mixed group? Run in the mission environment of any Syria mission (fiddle hook, port 12080, env=default), unpaused.
--
-- Spawns, 60 km apart over open ground south of Hatay:
--   A  a blue Hawk site alone in its group (sr, tr, pcp, 3 ln)
--   B  the same Hawk site inside one group of ~30 units, as `generateAirDefenseGroup-BLUE-5` plus armour and trucks
-- and, for each, a red An-26B flown straight over the site at 4,000 m from 40 km out.
-- Then read `measure-result.lua` (below) every minute: the missiles left on each site's launchers and the shots seen.
-- Not run yet: DCS was not running on 2026-11-22 when the lot was implemented.

MEASURE = { shots = {}, started = timer.getTime() }

local function unitsAt(cx, cz, list)
  local units = {}
  for index, entry in ipairs(list) do
    table.insert(units, {
      name = string.format("%s-%d", entry.prefix, index),
      type = entry.type,
      x = cx + entry.dx,
      y = cz + entry.dz,
      heading = entry.hdg or 0,
      skill = "Excellent",
    })
  end
  return units
end

local function hawkSite(prefix)
  return {
    { prefix = prefix, type = "Hawk sr", dx = 0, dz = 0 },
    { prefix = prefix, type = "Hawk tr", dx = 60, dz = 40 },
    { prefix = prefix, type = "Hawk pcp", dx = -50, dz = 30 },
    { prefix = prefix, type = "Hawk ln", dx = 200, dz = -150, hdg = 0 },
    { prefix = prefix, type = "Hawk ln", dx = -200, dz = -150, hdg = 0 },
    { prefix = prefix, type = "Hawk ln", dx = 0, dz = 250, hdg = 0 },
  }
end

local function addGround(name, units)
  coalition.addGroup(country.id.CJTF_BLUE, Group.Category.GROUND, {
    name = name,
    task = "Ground Nothing",
    units = units,
  })
end

local function addTarget(name, cx, cz)
  local start = { x = cx - 40000, z = cz }
  coalition.addGroup(country.id.CJTF_RED, Group.Category.AIRPLANE, {
    name = name,
    task = "Transport",
    units = {
      { name = name .. "-1", type = "An-26B", x = start.x, y = start.z, alt = 4000, alt_type = "BARO", speed = 120, heading = math.pi / 2, skill = "Average", payload = { pylons = {}, fuel = 5500, flare = 0, chaff = 0, gun = 0 } },
    },
    route = {
      points = {
        { x = start.x, y = start.z, alt = 4000, alt_type = "BARO", type = "Turning Point", action = "Turning Point", speed = 120, task = { id = "ComboTask", params = { tasks = {} } } },
        { x = cx + 40000, y = cz, alt = 4000, alt_type = "BARO", type = "Turning Point", action = "Turning Point", speed = 120, task = { id = "ComboTask", params = { tasks = {} } } },
      },
    },
  })
end

-- open ground east of the Orontes, south of Hatay (Syria map, mission coordinates); move them if a site lands in a town
local A = { x = 30000, z = 10000 }
local B = { x = 30000, z = 70000 }

addGround("MEASURE A hawk alone", unitsAt(A.x, A.z, hawkSite("MEASURE A")))

local mixed = hawkSite("MEASURE B")
local extras = {
  { "M48 Chaparral", 3 }, { "Gepard", 3 }, { "M 818", 3 }, { "M-1 Abrams", 6 }, { "M-2 Bradley", 6 }, { "Soldier M4", 6 },
}
local ring = 0
for _, extra in ipairs(extras) do
  for _ = 1, extra[2] do
    ring = ring + 1
    local angle = ring * 0.4
    table.insert(mixed, { prefix = "MEASURE B", type = extra[1], dx = math.cos(angle) * (400 + ring * 20), dz = math.sin(angle) * (400 + ring * 20) })
  end
end
addGround("MEASURE B hawk in mixed group", unitsAt(B.x, B.z, mixed))

addTarget("MEASURE target A", A.x, A.z)
addTarget("MEASURE target B", B.x, B.z)

world.addEventHandler({
  onEvent = function(_, event)
    if event.id == world.event.S_EVENT_SHOT and event.initiator then
      local ok, name = pcall(event.initiator.getName, event.initiator)
      if ok and name and name:find("^MEASURE") then
        table.insert(MEASURE.shots, string.format("%.0f s %s", timer.getTime() - MEASURE.started, name))
      end
    end
  end,
})

return string.format("spawned, %d units in the mixed group", #mixed)

--[[ measure-result.lua — send this one every minute:
local lines = { string.format("t+%.0f s", timer.getTime() - MEASURE.started) }
for _, groupName in ipairs({ "MEASURE A hawk alone", "MEASURE B hawk in mixed group" }) do
  local group, missiles = Group.getByName(groupName), 0
  for _, unit in ipairs(group and group:getUnits() or {}) do
    if unit:getTypeName() == "Hawk ln" then
      for _, ammo in ipairs(unit:getAmmo() or {}) do
        missiles = missiles + ammo.count
      end
    end
  end
  table.insert(lines, string.format("%s: %d missile(s) on the launchers", groupName, missiles))
end
for _, target in ipairs({ "MEASURE target A", "MEASURE target B" }) do
  local group = Group.getByName(target)
  table.insert(lines, string.format("%s: %s", target, group and group:getSize() > 0 and "alive" or "down"))
end
table.insert(lines, "shots: " .. table.concat(MEASURE.shots, ", "))
return table.concat(lines, "\n")
]]
