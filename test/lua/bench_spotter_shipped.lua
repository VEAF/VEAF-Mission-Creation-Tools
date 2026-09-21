--- Cost bench for the **shipped** spotter-network graph code.
--
-- Not a test: the runner only collects `test_*.lua`, so this file never runs in CI.
--
--   lua test/lua/bench_spotter_shipped.lua
--
-- `bench_spotter_network.lua` measures a *model* of the graph, written before the code existed and
-- indexing its nodes by integer. This one calls `veafSkynet.reEdgeSpotterNode` itself, which keys
-- everything by **unit name**, because that is what a DCS mission gives us to work with. String keys
-- are not free and the difference is not in the noise, so the design's figures cannot simply be
-- inherited by the implementation — hence this second bench.
--
-- Measured on Lua 5.1.5 (DAVID-BUREAU, 2026-09-21), densest layout built — 2 000 units on a
-- 200 x 40 km front, ~234 000 edges:
--
--   | operation             | model bench | shipped code |
--   |-----------------------|-------------|--------------|
--   | full build            | 113 ms      | ~205 ms      |
--   | re-edge 100 units     | 13.7 ms     | ~19 ms       |
--
-- Both were judged acceptable and the simpler structure kept. A parallel array of nodes scanned with
-- `ipairs` instead of `pairs` over the hash was measured at 181 ms against 253 ms on the same run —
-- about 28 % — but it needs removal bookkeeping (swap-remove plus an index map), which is exactly
-- the individual-element removal the set representation exists to avoid. Seventy milliseconds once
-- at mission start, on a layout twice the size of any mission we ship, does not buy that back.

local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
dofile(src .. "/veafDcsSpawner.lua")
dofile(src .. "/veafEventHandler.lua")
SkynetIADS = { database = {} }
dcsUnits = { DcsUnitsDatabase = {} }
dofile(src .. "/veafSkynetIadsHelper.lua")

-- The mocks answer a constant 0 for every draw, which would put every unit in the same place and
-- build a complete graph. Ask for the real generator.
dcs_mocks.useRealRandom()
math.randomseed(1)

local UNIT_COUNT = 2000
local RE_EDGED = 100

--- Clusters of a dozen confined to a 200 x 40 km band: a front line, which is where ground units
--- actually sit in a mission built around a contested area, and the densest layout we could build.
local function frontLayout(count)
  local units, n = {}, 0
  while n < count do
    local cx, cz = math.random() * 200000, math.random() * 40000
    for _ = 1, 12 do
      if n >= count then
        break
      end
      n = n + 1
      units[n] = {
        name = "U" .. n,
        x = cx + (math.random() - 0.5) * 3000,
        z = cz + (math.random() - 0.5) * 3000,
      }
    end
  end
  return units
end

local units = frontLayout(UNIT_COUNT)
local graph = { adjacency = {}, nodes = {} }

local started = os.clock()
for _, unit in ipairs(units) do
  veafSkynet.reEdgeSpotterNode(graph, unit.name, unit.x, unit.z, veafSkynet.SpotterSpeedClasses.Mobile)
end
local build = os.clock() - started

local edges = 0
for _, nodeEdges in pairs(graph.adjacency) do
  for _ in pairs(nodeEdges) do
    edges = edges + 1
  end
end
edges = edges / 2

-- A combat zone spawning a hundred units at once: they are re-edged against everything already
-- there, at the next pass of their class's loop. Nothing is triggered by the spawn itself.
started = os.clock()
for i = 1, RE_EDGED do
  local unit = units[i]
  veafSkynet.reEdgeSpotterNode(graph, unit.name, unit.x, unit.z, veafSkynet.SpotterSpeedClasses.Mobile)
end
local patch = os.clock() - started

print(string.format("interpreter        : %s", _VERSION))
print(string.format("units / edges      : %d / %d", UNIT_COUNT, edges))
print(string.format("radio range        : %d m", veafSkynet.SpotterRadioRange))
print(string.format("full build         : %.0f ms  (once per class loop, at mission start)", build * 1000))
print(string.format("re-edge %d units  : %.0f ms  (a combat zone spawning at once)", RE_EDGED, patch * 1000))
