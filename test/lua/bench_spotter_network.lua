--- Cost bench for FEAT-SPOTTER-NETWORK.
--
-- Not a test: the runner only collects `test_*.lua`, so this file never runs in CI.
-- It exists so the design document's figures can be reproduced and challenged.
--
--   lua test/lua/bench_spotter_network.lua
--
-- What it measures, for each unit count and each spatial layout:
--   * building the neighbour graph from scratch (the quadratic pass)
--   * the shape of the resulting graph -- edges, connected components, largest one
--   * one multi-source breadth-first sweep (an alert crossing the network)
--   * one movement check over every unit (reading positions, comparing to a reference)
--   * patching the edges of the units that moved
--
-- The graph shape matters more than the timings. A network that costs nothing because
-- it is fragmented into dozens of isolated pockets is not a cheap network, it is an
-- absent one.

-- The default settled on 2026-09-21. It matters for the timings below and not only for the
-- reach: the sweep is O(edges), and widening the range from 10 to 20 km roughly triples them.
local RADIO_RANGE = 20000 -- metres, the radio edge length
local RADIO_RANGE_SQ = RADIO_RANGE * RADIO_RANGE
local RANGE_SWEEP = { 5000, 10000, 20000, 30000, 40000 } -- what the second table varies
local MOVE_THRESHOLD = 2000 -- metres a unit must cover before its edges are recomputed
local MOVE_THRESHOLD_SQ = MOVE_THRESHOLD * MOVE_THRESHOLD

local UNIT_COUNTS = { 200, 500, 1000, 2000 }
local MAP_SIZE = 300000 -- a 300 x 300 km theatre, the order of Caucasus

-- ---------------------------------------------------------------------------
-- Layouts
-- ---------------------------------------------------------------------------

--- Every unit dropped anywhere on the theatre. The worst case for connectivity,
--- and not what a mission looks like, but it brackets the range.
local function layoutUniform(count)
  local units = {}
  for i = 1, count do
    units[i] = { x = math.random() * MAP_SIZE, z = math.random() * MAP_SIZE }
  end
  return units
end

--- Groups of about a dozen units within 1.5 km of each other, the groups themselves
--- scattered over the whole theatre. This is a mission whose contents are spread out.
local function layoutClusters(count)
  local units = {}
  local perCluster = 12
  local clusters = math.ceil(count / perCluster)
  local n = 0
  for _ = 1, clusters do
    local cx, cz = math.random() * MAP_SIZE, math.random() * MAP_SIZE
    for _ = 1, perCluster do
      if n >= count then
        break
      end
      n = n + 1
      units[n] = { x = cx + (math.random() - 0.5) * 3000, z = cz + (math.random() - 0.5) * 3000 }
    end
  end
  return units
end

--- The same groups, but confined to a 200 x 40 km band: a front line, which is where
--- ground units actually sit in a mission built around a contested area.
local function layoutFront(count)
  local units = {}
  local perCluster = 12
  local clusters = math.ceil(count / perCluster)
  local n = 0
  for _ = 1, clusters do
    local cx = math.random() * 200000
    local cz = math.random() * 40000
    for _ = 1, perCluster do
      if n >= count then
        break
      end
      n = n + 1
      units[n] = { x = cx + (math.random() - 0.5) * 3000, z = cz + (math.random() - 0.5) * 3000 }
    end
  end
  return units
end

-- ---------------------------------------------------------------------------
-- Graph
-- ---------------------------------------------------------------------------

--- Every pair compared once, squared distances only -- no square root anywhere.
local function buildGraph(units, range)
  local count = #units
  local rangeSq = (range or RADIO_RANGE) ^ 2
  local adjacency = {}
  for i = 1, count do
    adjacency[i] = {}
  end
  for i = 1, count - 1 do
    local ui = units[i]
    local uix, uiz = ui.x, ui.z
    for j = i + 1, count do
      local uj = units[j]
      local dx = uix - uj.x
      local dz = uiz - uj.z
      if dx * dx + dz * dz <= rangeSq then
        local ai = adjacency[i]
        ai[#ai + 1] = j
        local aj = adjacency[j]
        aj[#aj + 1] = i
      end
    end
  end
  return adjacency
end

local function countEdges(adjacency)
  local degrees = 0
  for i = 1, #adjacency do
    degrees = degrees + #adjacency[i]
  end
  return degrees / 2
end

--- Connected components, so we can say whether an alert has anywhere to go.
local function components(adjacency)
  local count = #adjacency
  local seen = {}
  local total, largest, largestSeed = 0, 0, 1
  for start = 1, count do
    if not seen[start] then
      total = total + 1
      local size = 0
      local queue, head = { start }, 1
      seen[start] = true
      while head <= #queue do
        local node = queue[head]
        head = head + 1
        size = size + 1
        local neighbours = adjacency[node]
        for k = 1, #neighbours do
          local neighbour = neighbours[k]
          if not seen[neighbour] then
            seen[neighbour] = true
            queue[#queue + 1] = neighbour
          end
        end
      end
      if size > largest then
        largest = size
        largestSeed = start
      end
    end
  end
  return total, largest, largestSeed
end

--- How many hops it takes to cross a component, from one of its members. Not the exact
--- diameter -- a single sweep underestimates it -- but it is the figure that matters:
--- hops times the propagation period is how long an alert takes to get across.
local function depthFrom(adjacency, start)
  local seen = { [start] = true }
  local queue, depths, head = { start }, { [start] = 0 }, 1
  local deepest = 0
  while head <= #queue do
    local node = queue[head]
    head = head + 1
    local neighbours = adjacency[node]
    for k = 1, #neighbours do
      local neighbour = neighbours[k]
      if not seen[neighbour] then
        seen[neighbour] = true
        depths[neighbour] = depths[node] + 1
        if depths[neighbour] > deepest then
          deepest = depths[neighbour]
        end
        queue[#queue + 1] = neighbour
      end
    end
  end
  return deepest
end

--- One alert crossing the network: breadth-first from every spotter holding a contact.
local function sweep(adjacency, sources)
  local seen = {}
  local queue, head = {}, 1
  for i = 1, #sources do
    local s = sources[i]
    if not seen[s] then
      seen[s] = true
      queue[#queue + 1] = s
    end
  end
  local reached = 0
  while head <= #queue do
    local node = queue[head]
    head = head + 1
    reached = reached + 1
    local neighbours = adjacency[node]
    for k = 1, #neighbours do
      local neighbour = neighbours[k]
      if not seen[neighbour] then
        seen[neighbour] = true
        queue[#queue + 1] = neighbour
      end
    end
  end
  return reached
end

--- One pass of a movement-check loop: read each position, compare to the reference.
local function movementCheck(units, references)
  local moved = {}
  for i = 1, #units do
    local u = units[i]
    local r = references[i]
    local dx = u.x - r.x
    local dz = u.z - r.z
    if dx * dx + dz * dz > MOVE_THRESHOLD_SQ then
      moved[#moved + 1] = i
    end
  end
  return moved
end

--- Recomputing the edges of the units that moved: each against everybody.
--
-- Both sides are maintained. Rewriting only adjacency[i] would be cheaper and would still
-- measure the quadratic scan, but it leaves the graph asymmetric: a unit that moves out of
-- range keeps a stale back-edge from its former neighbour, and an alert goes on relaying
-- through a link that no longer exists until the next full rebuild. The implementation will
-- copy this function, so it had better be right rather than merely fast.
local function patchNodes(units, adjacency, moved)
  local count = #units
  for m = 1, #moved do
    local i = moved[m]

    local previous = adjacency[i]
    for k = 1, #previous do
      local other = adjacency[previous[k]]
      for idx = #other, 1, -1 do
        if other[idx] == i then
          table.remove(other, idx)
        end
      end
    end

    local ui = units[i]
    local uix, uiz = ui.x, ui.z
    local fresh = {}
    for j = 1, count do
      if j ~= i then
        local uj = units[j]
        local dx = uix - uj.x
        local dz = uiz - uj.z
        if dx * dx + dz * dz <= RADIO_RANGE_SQ then
          fresh[#fresh + 1] = j
        end
      end
    end
    adjacency[i] = fresh

    for k = 1, #fresh do
      local other = adjacency[fresh[k]]
      other[#other + 1] = i
    end
  end
end

-- ---------------------------------------------------------------------------
-- The same graph held as sets rather than lists
--
-- Removing a back-edge from a list means scanning it, so patching costs O(degree^2) per
-- node and that is what dominates at a 20 km range. Held as a set, `adjacency[i][j] = true`,
-- the removal is a single assignment. The sweep pays a little more for `pairs` instead of
-- `ipairs`; this measures whether the trade is worth making.
-- ---------------------------------------------------------------------------

local function buildGraphSets(units, range)
  local count = #units
  local rangeSq = (range or RADIO_RANGE) ^ 2
  local adjacency = {}
  for i = 1, count do
    adjacency[i] = {}
  end
  for i = 1, count - 1 do
    local ui = units[i]
    local uix, uiz = ui.x, ui.z
    for j = i + 1, count do
      local uj = units[j]
      local dx = uix - uj.x
      local dz = uiz - uj.z
      if dx * dx + dz * dz <= rangeSq then
        adjacency[i][j] = true
        adjacency[j][i] = true
      end
    end
  end
  return adjacency
end

local function patchNodesSets(units, adjacency, moved)
  local count = #units
  for m = 1, #moved do
    local i = moved[m]

    for previous in pairs(adjacency[i]) do
      adjacency[previous][i] = nil
    end

    local ui = units[i]
    local uix, uiz = ui.x, ui.z
    local fresh = {}
    for j = 1, count do
      if j ~= i then
        local uj = units[j]
        local dx = uix - uj.x
        local dz = uiz - uj.z
        if dx * dx + dz * dz <= RADIO_RANGE_SQ then
          fresh[j] = true
          adjacency[j][i] = true
        end
      end
    end
    adjacency[i] = fresh
  end
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------

--- os.clock has a coarse resolution, so short operations are repeated and averaged.
local function timeIt(repeats, fn)
  local started = os.clock()
  for _ = 1, repeats do
    fn()
  end
  return (os.clock() - started) / repeats * 1000 -- milliseconds per run
end

local LAYOUTS = {
  { name = "uniform", build = layoutUniform },
  { name = "clusters", build = layoutClusters },
  { name = "front", build = layoutFront },
}

print("FEAT-SPOTTER-NETWORK cost bench")
print(string.format("Lua %s | radio range %d m | move threshold %d m", _VERSION, RADIO_RANGE, MOVE_THRESHOLD))
print("")
print("layout     units   edges  comps  largest   build_ms  sweep_ms  check_ms  patch_list  patch_sets")
print(string.rep("-", 104))

for _, layout in ipairs(LAYOUTS) do
  for _, count in ipairs(UNIT_COUNTS) do
    math.randomseed(42)
    local units = layout.build(count)

    local adjacency
    local buildMs = timeIt(3, function()
      adjacency = buildGraph(units)
    end)

    local edges = countEdges(adjacency)
    local comps, largest = components(adjacency)

    -- ten spotters holding a contact, the order of a raid crossing a defended area
    local sources = {}
    for i = 1, 10 do
      sources[i] = math.random(1, count)
    end
    local sweepMs = timeIt(20, function()
      sweep(adjacency, sources)
    end)

    -- every unit sits on its reference except 5%, which have crossed the threshold
    local references = {}
    for i = 1, count do
      references[i] = { x = units[i].x, z = units[i].z }
    end
    local moverCount = math.max(1, math.floor(count * 0.05))
    for i = 1, moverCount do
      references[i] = { x = units[i].x - 5000, z = units[i].z }
    end

    local moved
    local checkMs = timeIt(20, function()
      moved = movementCheck(units, references)
    end)
    local patchMs = timeIt(3, function()
      patchNodes(units, adjacency, moved)
    end)

    local setAdjacency = buildGraphSets(units)
    local patchSetMs = timeIt(3, function()
      patchNodesSets(units, setAdjacency, moved)
    end)

    print(
      string.format(
        "%-9s %6d %7d %6d %8d %10.2f %9.3f %9.3f %10.2f %10.2f",
        layout.name,
        count,
        edges,
        comps,
        largest,
        buildMs,
        sweepMs,
        checkMs,
        patchMs,
        patchSetMs
      )
    )
  end
end

print("")
print("comps    = connected components; an alert never leaves the one it starts in")
print("largest  = units in the biggest component, i.e. the real reach of the network")
print("patch_list = re-edging the 5% that moved, adjacency held as lists")
print("patch_sets = the same, adjacency held as sets -- back-edge removal is O(1)")

-- ---------------------------------------------------------------------------
-- How the radio range changes the network that exists at all
-- ---------------------------------------------------------------------------

print("")
print("Sensitivity to the radio range -- 1000 units, averaged over 8 draws")
print("")
print("layout     range_km   edges  comps  largest  reach_%   hops  crossing_s")
print(string.rep("-", 78))

-- The hop period is derived, not set: a hop covers the radio range, so holding the alert's
-- speed constant means a wider range takes proportionally longer per hop. 3600 km/h is the
-- decision of 2026-09-21 -- four times a penetrating fighter.
local PROPAGATION_SPEED = 1000 -- metres per second, i.e. 3600 km/h

-- Averaged over several layouts: a single draw moves the reach by fifteen points, which
-- is enough to argue about a default radio range on noise.
local DRAWS = 8

for _, layout in ipairs(LAYOUTS) do
  for _, range in ipairs(RANGE_SWEEP) do
    local edgeSum, compSum, largestSum, hopSum = 0, 0, 0, 0
    for draw = 1, DRAWS do
      math.randomseed(draw)
      local units = layout.build(1000)
      local adjacency = buildGraph(units, range)
      local comps, largest, seed = components(adjacency)
      edgeSum = edgeSum + countEdges(adjacency)
      compSum = compSum + comps
      largestSum = largestSum + largest
      hopSum = hopSum + depthFrom(adjacency, seed)
    end
    local largest = largestSum / DRAWS
    local hops = hopSum / DRAWS
    -- %.0f, not %d: these are averages, and string.format("%d", 413.4) truncates on 5.1 but
    -- raises "number has no integer representation" from 5.2 on. The bench exists to be
    -- re-run by someone else, quite possibly on a newer interpreter.
    print(
      string.format(
        "%-9s %9d %7.0f %6.0f %8.0f %8.1f %6.1f %11.0f",
        layout.name,
        range / 1000,
        edgeSum / DRAWS,
        compSum / DRAWS,
        largest,
        largest / 1000 * 100,
        hops,
        hops * (range / PROPAGATION_SPEED)
      )
    )
  end
end

print("")
print("reach_%     = share of the mission's units the biggest component covers")
print("hops        = breadth of that component in hops, from one of its members")
print("crossing_s  = hops x (range / 1000 m/s), how long an alert takes to cross it end to end")
