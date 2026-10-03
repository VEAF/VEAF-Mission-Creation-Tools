------------------------------------------------------------------
-- VEAF groups and units database for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Contains all the units aliases and groups definitions used by the other VEAF scripts
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafUnits = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the root VEAF constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafUnits.Id = "UNITS"

-- trace level, specific to this module
--veafUnits.LogLevel = "trace"

veaf.loggers.new(veafUnits.Id, veafUnits.LogLevel)

--- If no unit is spawned in a cell, it will default to this width
veafUnits.DefaultCellWidth = 10

--- If no unit is spawned in a cell, it will default to this height
veafUnits.DefaultCellHeight = 10

--- Group format that will be spawned then destroyed from a convoy to fix the AI's dumb pathfinding as of 17/08/2022
veafUnits.DefaultPathfindingUnitType = "TZ-22_KrAZ"
veafUnits.DefaultPathfindingGroup = {}
veafUnits.DefaultPathfindingGroup = {
  disposition = { h = 1, w = 1 },
  units = {
    { veafUnits.DefaultPathfindingUnitType, random = true },
  },
  groupName = "Pathfinder",
  description = "Plz Fix ED",
}
--- delay before the pathfinding fix unit is destroyed
veafUnits.delayBeforePathfindingFix = 5

--- if true, the groups and units lists will be printed to the logs, so they can be saved to the documentation files
veafUnits.OutputListsForDocumentation = false

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafUnits.traceGroup(group, cells)
  if group and veafUnits.Trace then
    veaf.loggers.get(veafUnits.Id):trace("")
    veaf.loggers.get(veafUnits.Id):trace(" Group : " .. group.description)
    veaf.loggers.get(veafUnits.Id):trace("")
    local nCols = group.disposition.w
    local nRows = group.disposition.h

    local line1 = "|    |"
    local line2 = "|----|"

    for nCol = 1, nCols do
      line1 = line1 .. "                " .. string.format("%02d", nCol) .. "              |"
      line2 = line2 .. "--------------------------------|"
    end
    veaf.loggers.get(veafUnits.Id):trace(line1)
    veaf.loggers.get(veafUnits.Id):trace(line2)

    local unitCounter = 1
    for nRow = 1, nRows do
      local line1 = "|    |"
      local line2 = "| " .. string.format("%02d", nRow) .. " |"
      local line3 = "|    |"
      local line4 = "|----|"
      for nCol = 1, nCols do
        local cellNum = (nRow - 1) * nCols + nCol
        local cell = cells[cellNum]
        local left = "        "
        local top = "        "
        local right = "        "
        local bottom = "        "
        local bottomleft = "                      "
        local center = "                "

        if cell then
          local unit = cell.unit
          if unit then
            local unitName = unit.typeName
            if unitName:len() > 11 then
              unitName = unitName:sub(1, 11)
            end
            unitName = string.format("%02d", unitCounter) .. "-" .. unitName
            local spaces = 14 - unitName:len()
            for i = 1, math.floor(spaces / 2) do
              unitName = " " .. unitName
            end
            for i = 1, math.ceil(spaces / 2) do
              unitName = unitName .. " "
            end
            center = " " .. unitName .. " "

            bottomleft = string.format("               %03d    ", math.deg(unit.spawnPoint.hdg))

            unitCounter = unitCounter + 1
          end

          left = string.format("%08d", math.floor(cell.left))
          top = string.format("%08d", math.floor(cell.top))
          right = string.format("%08d", math.floor(cell.right))
          bottom = string.format("%08d", math.floor(cell.bottom))
        end

        line1 = line1 .. "  " .. top .. "                      " .. "|"
        line2 = line2 .. "" .. left .. center .. right .. "|"
        line3 = line3 .. bottomleft .. bottom .. "  |"
        line4 = line4 .. "--------------------------------|"
      end
      veaf.loggers.get(veafUnits.Id):trace(line1)
      veaf.loggers.get(veafUnits.Id):trace(line2)
      veaf.loggers.get(veafUnits.Id):trace(line3)
      veaf.loggers.get(veafUnits.Id):trace(line4)
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Core methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Browse all the units in a group and counts the infantry and vehicles remaining
function veafUnits.countInfantryAndVehicles(groupname)
  local nbVehicles = 0
  local nbInfantry = 0
  local group = Group.getByName(groupname)
  if group and group:isExist() == true and #group:getUnits() > 0 then
    for _, u in pairs(group:getUnits()) do
      local typeName = u:getTypeName()
      if typeName then
        local unit = veafUnits.findUnit(typeName)
        if unit then
          if unit.vehicle then
            nbVehicles = nbVehicles + 1
          elseif unit.infantry then
            nbInfantry = nbInfantry + 1
          end
        end
      end
    end
  end
  return nbVehicles, nbInfantry
end

--- searches the DCS database for a unit having this type (case insensitive)
function veafUnits.findDcsUnit(unitType)
  veaf.loggers.get(veafUnits.Id):trace("veafUnits.findDcsUnit(unitType=" .. unitType .. ")")

  -- find the desired unit in the DCS units database
  -- fast path: the database is keyed by DCS type id
  local unit = dcsUnits.DcsUnitsDatabase[unitType]
  -- Fallback: case-insensitive match on type or name, **trimmed on both sides**. Two of the 873 units
  -- DCS ships have a trailing space in their display name (`'APC TPz Fuchs '`, `'IFV Warrior '`), which
  -- is invisible to anyone reading it off the mission editor and typing it. Before the trim, asking for
  -- that unit by name resolved to nothing and only said so in the log — FIX-PLATOON-UNITS found six
  -- occurrences of exactly that in the platoon composition tables.
  if not unit then
    local wanted = veaf.trim(unitType):lower()
    for _, u in pairs(dcsUnits.DcsUnitsDatabase) do
      if (u and u.type and wanted == veaf.trim(u.type):lower()) or (u and u.name and wanted == veaf.trim(u.name):lower()) then
        unit = u
        break
      end
    end
  end

  return unit
end

--- process a group definition and return a usable group table
function veafUnits.processGroup(group)
  local result = {}

  -- initialize result table and copy metadata
  result.disposition = {}
  result.disposition.h = group.disposition.h
  result.disposition.w = group.disposition.w
  result.description = group.description
  result.groupName = group.groupName
  result.units = {}
  veaf.loggers.get(veafUnits.Id):trace("group=%s", veaf.lp(group))
  local unitNumber = 1
  -- replace all units with a simplified structure made from the DCS unit metadata structure
  for i = 1, #group.units do
    local unitType
    local cell = nil
    local number = nil
    local size = nil
    local hdg = nil
    local random = false
    local fitToUnit = false
    local u = group.units[i]
    veaf.loggers.get(veafUnits.Id):trace("u=%s", veaf.lp(u))
    if type(u) == "string" then
      -- information was skipped using simplified syntax
      unitType = u
    else
      unitType = u.typeName
      if not unitType then
        unitType = u[1]
      end
      veaf.loggers.get(veafUnits.Id):trace("unitType=%s", veaf.lp(unitType))
      cell = u.cell
      number = u.number
      size = u.size
      hdg = u.hdg
      if type(size) == "number" then
        size = {}
        size.width = u.size
        size.height = u.size
      end
      if u.random then
        random = true
      end
      if u.fitToUnit then
        fitToUnit = true
      end
    end
    if not number then
      number = 1
    end
    if type(number) == "table" then
      -- create a random number of units
      local min = number.min
      local max = number.max
      if not min then
        min = 1
      end
      if not max then
        max = 1
      end
      number = math.random(min, max)
    end
    if not hdg then
      hdg = math.random(0, 359) -- default heading is random
    end
    veaf.loggers.get(veafUnits.Id):trace(string.format("hdg=%d", hdg))
    for numUnit = 1, number do
      veaf.loggers.get(veafUnits.Id):trace("searching for unit [" .. unitType .. "] listed in group [" .. group.groupName .. "]")
      local unit = veafUnits.findUnit(unitType)
      if not unit then
        veaf.loggers.get(veafUnits.Id):info("cannot find unit [" .. unitType .. "] listed in group [" .. group.groupName .. "]")
      else
        unit.cell = cell
        unit.hdg = hdg
        unit.random = random
        unit.fitToUnit = fitToUnit
        unit.size = size
        result.units[unitNumber] = unit
        unitNumber = unitNumber + 1
      end
    end
  end

  -- check group type (WARNING : unit types should not be mixed !)
  for _, unit in pairs(result.units) do
    if unit.naval then
      result.naval = true
      break
    end
    if unit.air then
      result.air = true
      result.helicopter = unit.helicopter
      break
    end
  end

  veaf.loggers.get(veafUnits.Id):trace("result=%s", veaf.lp(result))

  return result
end

--- searches the database for a group having this alias (case insensitive)
function veafUnits.findGroup(groupAlias)
  veaf.loggers.get(veafUnits.Id):debug("veafUnits.findGroup(groupAlias=" .. groupAlias .. ")")

  -- find the desired group in the groups database
  local result = nil

  for _, g in pairs(veafUnits.GroupsDatabase) do
    for _, alias in pairs(g.aliases) do
      if alias:lower() == groupAlias:lower() then
        result = veafUnits.processGroup(g.group)
        break
      end
    end
  end

  return result
end

--- searches the database for a unit having this alias (case insensitive)
function veafUnits.findUnit(unitAlias)
  veaf.loggers.get(veafUnits.Id):trace("veafUnits.findUnit(unitAlias=" .. unitAlias .. ")")

  -- find the desired unit in the units database
  local unit = nil

  for _, u in pairs(veafUnits.UnitsDatabase) do
    for _, alias in pairs(u.aliases) do
      if alias:lower() == unitAlias:lower() then
        unit = u
        break
      end
    end
  end

  -- an armed helicopter alias carries its pylons (FEAT-HELICOPTER-SPAWN); copied, so that a spawn
  -- touching its unit cannot touch the catalogue
  local pylons = unit and unit.pylons and veaf.deepCopy(unit.pylons) or nil
  if unit then
    unit = veafUnits.findDcsUnit(unit.unitType)
  else
    unit = veafUnits.findDcsUnit(unitAlias)
  end
  if not unit then
    veaf.loggers.get(veafUnits.Id):debug("cannot find unit [" .. unitAlias .. "]")
  else
    unit = veafUnits.makeUnitFromDcsStructure(unit, 1)
    unit.pylons = pylons
  end

  return unit
end

--- Creates a simple structure from DCS complex metadata structure
function veafUnits.makeUnitFromDcsStructure(dcsUnit, cell)
  local result = {}
  if not dcsUnit then
    return nil
  end
  --[[
        [9] = 
    {
        ["type"] = "Vulcan",
        ["name"] = "AAA Vulcan M163",
        ["category"] = "Air Defence",
        ["vehicle"] = true,
        ["description"] = "AAA Vulcan M163",
        ["aliases"] = 
        {
            [1] = "M163 Vulcan",
        }, -- end of ["aliases"]
    }, -- end of [9]
]]
  -- dcsUnit.kind is one of "air"/"naval"/"infantry"/"vehicle"/"static" (replaces
  -- the legacy mutually-exclusive booleans). Fortifications keep result.static
  -- unset, matching the previous behaviour.
  result.category = dcsUnit.category
  result.typeName = dcsUnit.type
  result.displayName = dcsUnit.description
  result.naval = dcsUnit.kind == "naval"
  result.air = dcsUnit.kind == "air"
  -- A helicopter goes through the ground spawn (FEAT-HELICOPTER-SPAWN): landed at the marker, then
  -- given its job by a veafAircraftSpawn role. An airplane is still refused there.
  result.helicopter = result.air and dcsUnit.category == "Helicopter"

  if dcsUnit.kind == "static" and (dcsUnit.attribute == nil or dcsUnit.attribute.Fortifications == nil) then
    result.static = true
  end

  result.infantry = dcsUnit.kind == "infantry"
  result.vehicle = dcsUnit.kind == "vehicle"
  --[[
    result.size = { x = veaf.round(dcsUnit.desc.box.max.x - dcsUnit.desc.box.min.x, 1), y = veaf.round(dcsUnit.desc.box.max.y - dcsUnit.desc.box.min.y, 1), z = veaf.round(dcsUnit.desc.box.max.z - dcsUnit.desc.box.min.z, 1)}
    result.width = result.size.z
    result.length= result.size.x
    -- invert if width > height
    if result.width > result.length then
        local width = result.width
        result.width = result.length
        result.length = width
    end
    ]]
  result.cell = cell

  return result
end

--- checks if position is correct for the unit type
function veafUnits.checkPositionForUnit(spawnPosition, unit)
  veaf.loggers.get(veafUnits.Id):trace("checkPositionForUnit()")
  veaf.loggers.get(veafUnits.Id):trace("spawnPosition=%s", spawnPosition)
  local vec2 = { x = spawnPosition.x, y = spawnPosition.z }
  veaf.loggers.get(veafUnits.Id):trace("vec2=%s", vec2)
  veaf.loggers.get(veafUnits.Id):trace("unit=%s", unit)
  -- Open water only, so shallow water counts as ground here exactly as it does for the CSAR survivor
  -- and the ground spawn search (veaf.OPEN_WATER). Note that a naval unit therefore *refuses* shallow
  -- water: the two directions are not each other's mirror image, and CHORE-ONE-TERRAIN-CHECK left that
  -- asymmetry untouched.
  local isOverWater = veaf.isTerrainValid(vec2, veaf.OPEN_WATER)

  local IsNavalStatic = false --offshore static (list in dcsUnits.lua) flag
  if unit.static and veaf.findInTable(dcsUnits.NavalStatics, unit.typeName) then
    veaf.loggers.get(veafUnits.Id):trace("Is Naval Static")
    IsNavalStatic = true
  end

  if isOverWater then
    veaf.loggers.get(veafUnits.Id):trace("landType = WATER")
  else
    veaf.loggers.get(veafUnits.Id):trace("landType = GROUND")
  end
  if spawnPosition then
    if unit.air then -- if the unit is a plane or helicopter
      -- The height is `y`, not `z`. `z` is the easting, which is what the surface query above uses
      -- (docs/agents/dcs-coordinates.md); every caller hands in a `veaf.placePointOnLand` result, and
      -- `veafSpawnAircraft` writes `spawnSpot.y = alt` immediately before calling. This line read `z`
      -- until FIX-AIR-SPAWN-ALTITUDE-GUARD, so it asked whether the point was more than 10 m *east* of
      -- the origin and had therefore never refused anything.
      -- What is refused is a point under the terrain, and only that: an aircraft placed as a static
      -- sits at ground level on purpose — `placePointOnLand` puts it exactly here — so a clearance
      -- margin above the ground would refuse every static aircraft on low-lying or coastal terrain.
      if spawnPosition.y < veaf.getLandHeight(spawnPosition) then
        return false
      end
      -- a helicopter is put down on the ground, where it waits: on open water it would sink
      if unit.helicopter and isOverWater then
        return false
      end
    elseif unit.naval or IsNavalStatic then -- if the unit is a naval unit or an offshore static
      if not isOverWater then -- don't spawn over anything but water
        return false
      end
    else
      if isOverWater then -- don't spawn over water
        return false
      end
    end
  end
  return true
end

--- Distance, in metres, beyond which `settleGroup` leaves a group where it is rather than moving it.
---
--- Since ticket 12 this is also how far the sweep looks: it tries offsets ring by ring, closest
--- first, and stops at this radius.
---
--- 300 m. Measured on GermanyCW-v6: the sweep's own trial run (2026-09-26) solved thirteen groups
--- at 40 to 200 m, the Wittstock S-300 among them at **200 m**; but ticket 10 translated groups by
--- 118 to 278 m (2026-09-26) and ticket 11 moved one by **266 m**, so a bound under 280 m would
--- give up on groups the previous code did move. The sweep's figures were taken with a criterion later found to count
--- vehicles as obstacles (see `isPointClearOfScenery`), so this bound is the first thing to
--- revisit when the sweep is measured in game. It used to be 1000 m, when it bounded a list of
--- candidates the large query returned rather than a search this code pays for probe by probe.
veafUnits.SETTLE_MAX_TRANSLATION = 300

--- Spacing, in metres, between two rings of the sweep and between two offsets along a ring.
---
--- 20 m, the natural spacing of a SAM battery (20 to 27 m, measured 2026-09-25): a finer step
--- mostly re-tests the same ground, and a coarser one can step over a clearing a battery fits in.
veafUnits.SETTLE_SWEEP_STEP = 20

--- How many scenery probes one sweep may spend before it gives up on the group.
---
--- Everything runs in the spawn's own frame — deferring the spawn empties `veafSkynet.declareSpawn`,
--- convoy routing and `veaf.readyForCombat` (FIX-PLACEMENT-IGNORES-SCENERY ticket 11) — so this is
--- the hitch a group with no way out costs on every activation. A probe was measured at **0.38 ms**
--- on 2026-09-26, so 1000 probes is about 0.38 s. With the shipped step and radius a whole sweep
--- takes 761 offsets, and a refused offset usually costs one probe since the outermost units
--- are tried first, so the budget only bites when those bounds are tuned upwards. The Wittstock
--- S-300 sweep measured on 2026-09-26 took 836 probes to reach its 200 m clearing.
veafUnits.SETTLE_SWEEP_PROBE_BUDGET = 1000

--- The probe `settleGroup` uses to ask whether one unit's spot is clear of scenery: is there a patch
--- of `SETTLE_UNIT_CLEARANCE` metres free within `SETTLE_UNIT_PROBE` metres of it?
---
--- Deliberately the same question the mission's acceptance probe asks, because the two criteria
--- disagreeing is precisely how ticket 10 came out green in CI and inert in game: it accepted a
--- candidate on a terrain test that says nothing about vegetation, while the metric it was written
--- to move was measuring the scenery.
---
--- These values suit **vehicles**. They are not meaningful for a large static, whose own footprint
--- can exceed the probe radius and so blocks its own test — a 47×52 m building always fails it.
--- `settleGroup` only ever moves settleable ground units, so the caveat does not bite here.
veafUnits.SETTLE_UNIT_PROBE = 20
veafUnits.SETTLE_UNIT_CLEARANCE = 5

--- Does a unit standing here have a patch of open ground around it?
--
-- **This is the test ticket 10 did not do.** Its code asserted that "a candidate is scenery-free by
-- construction", so nothing had to look at a forest. Measured in DCS on 2026-09-26 (GermanyCW-v6):
-- the Wittstock S-300 was translated 217 m onto a candidate asked for 183 m of clearance, and that
-- arrival point is blocked in **12 directions out of 12 at 10 m** — it only opens up at 183 m. The
-- group had been moved into the middle of a wood that has a clearing well outside it. Six of its
-- fourteen vehicles ended up under trees, and the whole lot measured inert.
--
-- It is the one question `settleGroup` asks the singleton since ticket 12: this small query is
-- deterministic, where the large one that proposes clearings is a lottery.
--
-- **It answers "is there room here", and a vehicle occupies room.** Measured on 2026-09-26: the
-- same points, probed with a group standing on them and again once it was destroyed, went from
-- 12 blocked out of 14 to 0 out of 14. That is harmless *here* — this runs before the group's
-- units exist, so it sees vegetation and nothing else — and it is ruinous anywhere a spawned
-- mission is measured, where a tight SAM battery fails the test wherever you put it. Three
-- published counts of "units in scenery" were mostly groups blocking themselves
-- (`known-limitations.yaml`, `disposition-getsimplezones-is-a-lottery`).
--
-- ADR 0018 — when the singleton is missing or raises, this answers **true** and lets the caller
-- proceed. An undocumented dependency may improve quality; it must never be what refuses a spawn.
-- @param point table vec3 where the unit would stand
-- @return boolean true when the spot is clear, or when the scenery criterion cannot be evaluated
local function isPointClearOfScenery(point)
  if veaf.doNotAvoidScenery or not Disposition or not Disposition.getSimpleZones then
    return true
  end
  local ok, candidates =
    pcall(Disposition.getSimpleZones, point, veafUnits.SETTLE_UNIT_PROBE, veafUnits.SETTLE_UNIT_CLEARANCE, veaf.SPAWN_SEARCH_ATTEMPTS)
  if not ok or type(candidates) ~= "table" then
    return true
  end
  return #candidates > 0
end

--- May this unit be moved to get clear of the scenery?
-- Air units live in the air, and naval units (naval statics included, identified exactly as in
-- `checkPositionForUnit`) are placed on water — moving them toward drivable terrain would make
-- `checkPositionForUnit` refuse them downstream.
local function isSettleableUnit(unit)
  if type(unit) ~= "table" or unit.air or unit.naval then
    return false
  end
  if unit.static and veaf.findInTable(dcsUnits.NavalStatics, unit.typeName) then
    return false
  end
  return true
end

--- Moves a whole ground group, as one rigid body, onto ground where every unit stands clear.
--
-- `veaf.findSpawnPoint` places the **group centre** clear of scenery; `placeGroup` then spreads the
-- units around that centre without consulting the scenery, so a battery whose centre stands in the
-- open can still have half its vehicles inside a treeline. This function runs after `placeGroup`,
-- which is the only moment the real disposition is known: `veafUnits` draws it at random on every
-- spawn, so no amount of editing the positions declared in a mission can pre-empt it — and since
-- it runs on the disposition actually drawn, what it validates is exactly what spawns.
--
-- **Rigidly, and that is the whole point.** Measured on GermanyCW-v6 (2026-09-25): a group's natural
-- spacing is 20 to 27 m for a SAM battery, while the closest point DCS can propose is 52 m, so any
-- per-unit displacement breaks the formation by a factor of 2 to 5 — there is no threshold that is
-- both effective and safe. One offset is applied to every unit, so no inter-unit distance changes.
--
-- **It sweeps with the probe; it never asks `Disposition` for a clearing.** Rings of growing
-- radius around the group, `SETTLE_SWEEP_STEP` apart, closest first; each offset is kept only when
-- every translated unit stands on drivable terrain and passes `isPointClearOfScenery`. Ticket 11
-- asked the singleton's large query to *propose* clearings and verified each one, and measured on
-- 2026-09-26 that query is a lottery — 12 ms a call, not deterministic, and **zero candidates at
-- every clearance, down to 5 m**, for the places a group most needs moving out of. The small probe
-- is 0.38 ms and gives the same answer every time. So the singleton is only ever asked about one
-- point at a time, the one way it is dependable (`known-limitations.yaml`,
-- `disposition-getsimplezones-is-a-lottery`).
--
-- The outermost units are probed first: they carry the footprint, so they are the ones a bad
-- offset puts in the trees, and a refused offset then costs one probe rather than one per unit.
--
-- No-op, and the group is left strictly untouched, when: `Disposition` is unavailable or raises
-- (ADR 0018 — this undocumented singleton may improve quality, never decide correctness), any unit
-- of the group is exempt (a rigid translation is a property of the whole group; moving half of it
-- would break the very invariant this exists to protect), every unit already stands clear, no
-- offset within `SETTLE_MAX_TRANSLATION` clears every unit, or the sweep has spent
-- `SETTLE_SWEEP_PROBE_BUDGET` probes.
--
-- Editor content is **not** concerned: zone elements are respawned through `VeafGroupSpawn`, whose
-- `honouringDeclaredPosition` keeps the position the mission maker drew (ruling 3 of David's
-- arbitration, 2026-08-27). This path is the dynamic spawners only.
--
-- **The exemption is the explicit flag, never a zero radius.** `VeafGroupSpawn:honouringDeclaredPosition()`
-- (#1004) made exactly that distinction and it holds here for the same reason: zero is the *default*
-- radius, not a statement. Measured in DCS on GermanyCW-v6, 2026-09-25: of the 118 spawn commands of
-- one launch, **100 pass `radius 0`** — `sa10`, `sa11`, `sa15_squad`, `ewr`, `patriot`, `msta` and the
-- rest, that is to say every single group this lot exists for. Keying the exemption on the radius
-- would leave the S-300 of `combatZone_Wittstock`, 13 of its 14 units under trees, exactly where it
-- is, and make this lot the no-op it was written to replace. Only a caller that *owns* the placement
-- decision, and says so, is obeyed.
--
-- @param units table list of unit definitions, each carrying the `spawnPoint` vec3 `placeGroup` set
-- @param honourDeclaredPosition boolean|nil when true, the caller has already settled where these
--        units go — editor content, or a caller that settled its groups one by one — and nothing moves
-- @return number the distance the group was translated by, 0 when it was left alone
function veafUnits.settleGroup(units, honourDeclaredPosition)
  if type(units) ~= "table" or #units == 0 then
    return 0
  end
  if honourDeclaredPosition then
    veaf.loggers.get(veafUnits.Id):trace("settleGroup: the caller owns this placement, the group stays exactly where it is")
    return 0
  end
  for _, unit in ipairs(units) do
    if not isSettleableUnit(unit) or type(unit.spawnPoint) ~= "table" or type(unit.spawnPoint.x) ~= "number" then
      veaf.loggers.get(veafUnits.Id):trace("settleGroup: the group holds an exempt or unplaced unit, leaving it alone")
      return 0
    end
  end
  -- Same opt-out as `veaf.findSpawnPoint` tier 1 and `veafGrass.findClearBearing`: a mission that
  -- has turned the scenery criterion off gets nothing moved on its behalf here either.
  if veaf.doNotAvoidScenery or not Disposition or not Disposition.getSimpleZones then
    return 0
  end

  -- The group already stands in the open: measured unit by unit. This is the common case, and it
  -- costs one probe per unit.
  local alreadyClear = true
  for _, unit in ipairs(units) do
    if not isPointClearOfScenery(unit.spawnPoint) then
      alreadyClear = false
      break
    end
  end
  if alreadyClear then
    veaf.loggers.get(veafUnits.Id):trace("settleGroup: every unit already stands clear, keeping the group")
    return 0
  end

  -- Outermost first, measured from the barycentre; ties keep the list order so a sweep is
  -- reproducible.
  local centreX, centreZ = 0, 0
  for _, unit in ipairs(units) do
    centreX = centreX + unit.spawnPoint.x
    centreZ = centreZ + (unit.spawnPoint.z or 0)
  end
  centreX, centreZ = centreX / #units, centreZ / #units
  local order = {}
  for i, unit in ipairs(units) do
    local dx, dz = unit.spawnPoint.x - centreX, (unit.spawnPoint.z or 0) - centreZ
    order[i] = { index = i, reach = dx * dx + dz * dz }
  end
  table.sort(order, function(a, b)
    if a.reach ~= b.reach then
      return a.reach > b.reach
    end
    return a.index < b.index
  end)

  local step, probes = veafUnits.SETTLE_SWEEP_STEP, 0
  -- A mission can tune the step; zero or less would make the loop below run forever in the spawn's
  -- frame, so it reads as "do not sweep".
  if type(step) ~= "number" or step <= 0 then
    veaf.loggers.get(veafUnits.Id):debug("settleGroup: SETTLE_SWEEP_STEP is %s, not sweeping", tostring(step))
    return 0
  end
  for radius = step, veafUnits.SETTLE_MAX_TRANSLATION, step do
    local offsets = math.ceil(2 * math.pi * radius / step)
    for k = 0, offsets - 1 do
      local angle = 2 * math.pi * k / offsets
      local offsetX, offsetZ = radius * math.cos(angle), radius * math.sin(angle)
      local placed, everyUnitClear = {}, true
      for _, entry in ipairs(order) do
        local unit = units[entry.index]
        local point = veaf.placePointOnLand({ x = unit.spawnPoint.x + offsetX, y = 0, z = (unit.spawnPoint.z or 0) + offsetZ })
        if not veaf.isTerrainValid(point, veaf.DRIVABLE_TERRAIN) then
          everyUnitClear = false
          break
        end
        -- Say which of the two it was. "We stopped looking" and "there is nothing to find" call
        -- for different answers when this shows up in a log.
        if probes >= veafUnits.SETTLE_SWEEP_PROBE_BUDGET then
          veaf.loggers.get(veafUnits.Id):debug(
            "settleGroup: probe budget of %d spent before %dm, keeping the group where it is",
            veafUnits.SETTLE_SWEEP_PROBE_BUDGET,
            radius
          )
          return 0
        end
        probes = probes + 1
        if not isPointClearOfScenery(point) then
          everyUnitClear = false
          break
        end
        placed[entry.index] = point
      end
      if everyUnitClear then
        for i, unit in ipairs(units) do
          -- Copy the original to keep every caller-set field (hdg, cell, …); only the coordinates
          -- move, and `y` is the ground height where the unit now stands.
          local settled = veaf.deepCopy(unit.spawnPoint)
          settled.x, settled.y, settled.z = placed[i].x, placed[i].y, placed[i].z
          unit.spawnPoint = settled
        end
        veaf.loggers.get(veafUnits.Id):debug("settleGroup: translated the group by %.0fm onto clear ground, %d probes", radius, probes)
        return radius
      end
    end
  end

  veaf.loggers.get(veafUnits.Id):debug(
    "settleGroup: no offset within %dm clears every unit (%d probes), keeping the group where it is",
    veafUnits.SETTLE_MAX_TRANSLATION,
    probes
  )
  return 0
end

--- Adds a placement point to every unit of the group, centering the whole group around the spawnPoint, and adding an optional spacing
function veafUnits.placeGroup(group, spawnPoint, spacing, hdg, hasDest)
  veaf.loggers.get(veafUnits.Id):trace("group = %s", group)
  veaf.loggers.get(veafUnits.Id):trace("spawnPoint = %s", spawnPoint)
  veaf.loggers.get(veafUnits.Id):trace("spacing = %s", spacing)
  veaf.loggers.get(veafUnits.Id):trace("hdg = %s", hdg)
  veaf.loggers.get(veafUnits.Id):trace("hasDest = %s", hasDest)

  if not hdg then
    hdg = 0 -- default north
  end

  local hasDest = false or hasDest
  veaf.loggers.get(veafUnits.Id):trace(string.format("hasDest = %s", veaf.p(hasDest)))

  if not group.disposition then
    -- default disposition is a square
    local l = math.ceil(math.sqrt(#group.units))
    group.disposition = { h = l, w = l }
  end

  local nRows = nil
  local nCols = nil

  if hasDest then
    local pathfindingFixer = veafUnits.processGroup(veafUnits.DefaultPathfindingGroup) --insert a unit (structured into a group) that will be destroyed just after the convoy is spawned, this is to fix the AI weird pathfinding
    table.insert(group.units, pathfindingFixer.units[1]) --insert the unit that has all of the necessary info into the group that's being placed
    nRows = #group.units
    nCols = 1
  else
    nRows = group.disposition.h
    nCols = group.disposition.w
  end

  -- sort the units by occupied cell
  local fixedUnits = {}
  local freeUnits = {}
  for _, unit in pairs(group.units) do
    if unit.cell and not hasDest then --if the group has a destination, programmer defined patterns do not apply anymore as the convoy is spawned in a line
      table.insert(fixedUnits, unit)
    else
      table.insert(freeUnits, unit)
    end
  end

  local cells = {}
  local allCells = {}
  for cellNum = 1, nRows * nCols do
    allCells[cellNum] = cellNum
  end

  -- place fixed units in their designated cells
  for i = 1, #fixedUnits do
    local unit = fixedUnits[i]
    cells[unit.cell] = {}
    cells[unit.cell].unit = unit

    -- remove this cell from the list of available cells
    for cellNum = 1, #allCells do
      if allCells[cellNum] == unit.cell then
        table.remove(allCells, cellNum)
        break
      end
    end
  end

  -- randomly place non-fixed units in the remaining cells
  for i = 1, #freeUnits do
    local randomCellNum = allCells[math.random(1, #allCells)]
    local unit = freeUnits[i]
    unit.cell = randomCellNum
    cells[unit.cell] = {}
    cells[randomCellNum].unit = unit

    -- remove this cell from the list of available cells
    for cellNum = 1, #allCells do
      if allCells[cellNum] == unit.cell then
        table.remove(allCells, cellNum)
        break
      end
    end
  end

  if hasDest then
    local cellGreater = function(unit1, unit2)
      if unit1 and unit2 and unit1.cell < unit2.cell then
        return true
      else
        return false
      end
    end

    table.sort(group.units, cellGreater)
  end

  -- compute the size of the cells, rows and columns
  local cols = {}
  local rows = {}
  for nRow = 1, nRows do
    for nCol = 1, nCols do
      local cellNum = (nRow - 1) * nCols + nCol
      local cell = cells[cellNum]
      local colWidth = 0
      local rowHeight = 0
      if cols[nCol] then
        colWidth = cols[nCol].width
      end
      if rows[nRow] then
        rowHeight = rows[nRow].height
      end
      if cell then
        cell.width = veafUnits.DefaultCellWidth + (spacing * veafUnits.DefaultCellWidth)
        cell.height = veafUnits.DefaultCellHeight + (spacing * veafUnits.DefaultCellHeight)
        local unit = cell.unit
        if unit then
          unit.cell = cellNum
          if unit.width and unit.width > 0 then
            cell.width = unit.width + (spacing * unit.width)
          end
          if unit.length and unit.length > 0 then
            cell.height = unit.length + (spacing * unit.length)
          end
          if unit.size then
            cell.width = unit.size.width + (spacing * unit.size.width)
            cell.height = unit.size.height + (spacing * unit.size.height)
          end
        end
        if not unit.fitToUnit then
          -- make the cell square
          if cell.width > cell.height then
            cell.height = cell.width
          elseif cell.width < cell.height then
            cell.width = cell.height
          end
        end
        if cell.width > colWidth then
          colWidth = cell.width
        end
        if cell.height > rowHeight then
          rowHeight = cell.height
        end
      end
      cols[nCol] = {}
      cols[nCol].width = colWidth
      rows[nRow] = {}
      rows[nRow].height = rowHeight
    end
  end

  -- compute the size of the grid
  local totalWidth = 0
  local totalHeight = 0
  for nCol = 1, #cols do
    totalWidth = totalWidth + cols[nCol].width
  end
  for nRow = 1, #rows do -- bottom -> up
    totalHeight = totalHeight + rows[#rows - nRow + 1].height
  end
  veaf.loggers.get(veafUnits.Id):trace(string.format("totalWidth = %d", totalWidth))
  veaf.loggers.get(veafUnits.Id):trace(string.format("totalHeight = %d", totalHeight))
  -- place the grid
  local currentColLeft = spawnPoint.z - totalWidth / 2
  local currentColTop = spawnPoint.x - totalHeight / 2
  for nCol = 1, #cols do
    veaf.loggers.get(veafUnits.Id):trace(string.format("currentColLeft = %d", currentColLeft))
    cols[nCol].left = currentColLeft
    cols[nCol].right = currentColLeft + cols[nCol].width
    currentColLeft = cols[nCol].right
  end
  for nRow = 1, #rows do -- bottom -> up
    veaf.loggers.get(veafUnits.Id):trace(string.format("currentColTop = %d", currentColTop))
    rows[#rows - nRow + 1].bottom = currentColTop
    rows[#rows - nRow + 1].top = currentColTop + rows[#rows - nRow + 1].height
    currentColTop = rows[#rows - nRow + 1].top
  end

  -- compute the centers and extents of the cells
  for nRow = 1, nRows do
    for nCol = 1, nCols do
      local cellNum = (nRow - 1) * nCols + nCol
      local cell = cells[cellNum]
      if cell then
        cell.top = rows[nRow].top
        cell.bottom = rows[nRow].bottom
        cell.left = cols[nCol].left
        cell.right = cols[nCol].right
        cell.center = {}
        cell.center.x = cell.left + math.random((cell.right - cell.left) / 10, (cell.right - cell.left) - ((cell.right - cell.left) / 10))
        cell.center.y = cell.top + math.random((cell.bottom - cell.top) / 10, (cell.bottom - cell.top) - ((cell.bottom - cell.top) / 10))
      end
    end
  end

  --find the heading offset relative to the group's heading to spawn the units perpendicular to the road
  -- local convoyHDGoffset = 90
  -- if hasDest then
  --     local road_x, road_z = land.getClosestPointOnRoads('roads',spawnPoint.x, spawnPoint.z)
  --     local roadPoint = veaf.placePointOnLand({x = road_x, y = 0, z = road_z})
  --     local nearestRoadHDG = mist.utils.getHeadingPoints(spawnPoint, roadPoint,false) * 180 / math.pi
  --     veaf.loggers.get(veafUnits.Id):trace(string.format("HDG to nearest road : %s", veaf.p(nearestRoadHDG)))
  --     veaf.loggers.get(veafUnits.Id):trace(string.format("Group HDG : %s", veaf.p(hdg)))
  --     if nearestRoadHDG then
  --         nearestRoadHDG = nearestRoadHDG - hdg
  --         if nearestRoadHDG < 0 then
  --             nearestRoadHDG = nearestRoadHDG + 360
  --         end

  --         if nearestRoadHDG >= 180 then
  --             convoyHDGoffset = 270
  --         end
  --     end
  -- end

  -- randomly place the units
  for _, cell in pairs(cells) do
    veaf.loggers.get(veafUnits.Id):trace(string.format("cell = %s", veaf.p(cell)))
    local unit = cell.unit
    if unit then
      unit.spawnPoint = {}
      if not cell.center then
        veaf.loggers.get(veafUnits.Id):error(string.format("Cannot find cell.center !"))
        veaf.loggers.get(veafUnits.Id):error(string.format("cell = %s", veaf.p(cell)))
        veaf.loggers.get(veafUnits.Id):error(string.format("group = %s", veaf.p(group)))
      end
      unit.spawnPoint.z = cell.center.x
      if unit.random and spacing > 0 then
        unit.spawnPoint.z = unit.spawnPoint.z
          + math.random(
            -((spacing - 1) * (unit.width or veafUnits.DefaultCellWidth)) / 2,
            ((spacing - 1) * (unit.width or veafUnits.DefaultCellWidth)) / 2
          )
      end
      unit.spawnPoint.x = cell.center.y
      if unit.random and spacing > 0 then
        unit.spawnPoint.x = unit.spawnPoint.x
          + math.random(
            -((spacing - 1) * (unit.length or veafUnits.DefaultCellHeight)) / 2,
            ((spacing - 1) * (unit.length or veafUnits.DefaultCellHeight)) / 2
          )
      end
      unit.spawnPoint.y = spawnPoint.y

      -- take into account group rotation, if needed
      if hdg > 0 then
        local angle = math.rad(hdg)
        local x = unit.spawnPoint.z - spawnPoint.z
        local y = unit.spawnPoint.x - spawnPoint.x
        local x_rotated = x * math.cos(angle) + y * math.sin(angle)
        local y_rotated = -x * math.sin(angle) + y * math.cos(angle)
        unit.spawnPoint.z = x_rotated + spawnPoint.z
        unit.spawnPoint.x = y_rotated + spawnPoint.x
      end

      -- unit heading
      if hasDest then --apply the offset when the group has a destination, 0 will make them spawn in line, 90 or 270 perpendicular to the group's hdg (the road if the group's hdg was set properly) etc.
        unit.hdg = 0 --convoyHDGoffset
      end

      if unit.hdg then
        local unitHeading = unit.hdg + hdg -- don't forget to add group heading
        if unitHeading > 360 then
          unitHeading = unitHeading - 360
        end
        unit.spawnPoint.hdg = math.rad(unitHeading)
      else
        unit.spawnPoint.hdg = 0 -- due north
      end
    end
  end

  return group, cells
end

function veafUnits.removePathfindingFixUnit(groupName)
  local group = Group.getByName(groupName)

  if group then
    local units = group:getUnits()
    if units then
      for _, unit in pairs(units) do
        if unit then
          local unitType = unit:getTypeName()
          if unitType and unitType == veafUnits.DefaultPathfindingUnitType then
            unit:destroy()
            break
          end
        end
      end
    end
  end
end

function veafUnits.logGroupsListInMarkdown()
  local function _sortGroupNameCaseInsensitive(g1, g2)
    if g1 and g1.group and g1.group.groupName and g2 and g2.group and g2.group.groupName then
      return string.lower(g1.group.groupName) < string.lower(g2.group.groupName)
    else
      return string.lower(g1) < string.lower(g2)
    end
  end

  local text = [[
This goes in [documentation\content\Mission maker\references\group-list.md]:

|Name|Description|Aliases|
|--|--|--|
]]
  veaf.loggers.get(veafUnits.Id):info(text)

  -- make a copy of the table
  local groupsCopy = {}
  for _, g in pairs(veafUnits.GroupsDatabase) do
    if not g.hidden then
      table.insert(groupsCopy, g)
    end
  end
  -- sort the copy
  table.sort(groupsCopy, _sortGroupNameCaseInsensitive)
  -- use the keys to retrieve the values in the sorted order
  for _, g in pairs(groupsCopy) do
    text = "|" .. g.group.groupName .. "|" .. g.group.description .. "|" .. table.concat(g.aliases, ", ") .. "|\n"
    veaf.loggers.get(veafUnits.Id):info(text)
  end
end

function veafUnits.logUnitsListInMarkdown()
  local function _sortUnitNameCaseInsensitive(u1, u2)
    if u1 and u1.name and u2 and u2.name then
      return string.lower(u1.name) < string.lower(u2.name)
    else
      return string.lower(u1) < string.lower(u2)
    end
  end

  local text = [[
This goes in [documentation\content\Mission maker\references\units-list.md]:

|Name|Description|Aliases|
|--|--|--|
]]
  veaf.loggers.get(veafUnits.Id):info(text)
  -- make a copy of the table
  local units = {}
  for k, data in pairs(dcsUnits.DcsUnitsDatabase) do
    local u = { name = k }
    for _, aliasData in pairs(veafUnits.UnitsDatabase) do
      if aliasData and aliasData.unitType and string.lower(aliasData.unitType) == string.lower(k) then
        u.aliases = aliasData.aliases
      end
    end
    if data then
      u.description = data.description
      u.typeName = data.type
    end
    table.insert(units, u)
  end
  -- sort the copy
  table.sort(units, _sortUnitNameCaseInsensitive)
  -- use the keys to retrieve the values in the sorted order
  for _, u in pairs(units) do -- serialize its fields
    text = "|" .. u.name .. "|"
    if u.description then
      text = text .. u.description
    end
    text = text .. "|"
    if u.aliases then
      text = text .. table.concat(u.aliases, ", ")
    end
    text = text .. "|"
    veaf.loggers.get(veafUnits.Id):info(text)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Units databases
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Populated at mission build by the injected spawn-data module (rendered from
-- veaf-units.yaml). Defaults to empty so the framework loads standalone. See ADR 0005.
veafUnits.UnitsDatabase = {}

--- Fuel, chaff and flare a helicopter of each type carries, by DCS type: `{ fuel, chaff, flare }`.
---
--- Rendered by the spawn-data module from `dcsUnits.yaml` (FEAT-HELICOPTER-SPAWN), because nothing at
--- runtime knows a type's fuel capacity, and an aircraft created with no fuel falls out of the sky.
--- Defaults to empty so the framework loads standalone.
veafUnits.AircraftPayloads = {}

--- The payload a spawned helicopter carries: its type's fuel and countermeasures, and the pylons its
--- catalogue alias names — none for an unarmed one.
--- @param unit table a unit from `veafUnits.findUnit`
--- @return table the `payload` table of a mission unit
function veafUnits.aircraftPayload(unit)
  local base = veafUnits.AircraftPayloads[unit.typeName] or {}
  return {
    fuel = base.fuel,
    chaff = base.chaff or 0,
    flare = base.flare or 0,
    gun = 100,
    pylons = unit.pylons or {}, -- findUnit already copied them out of the catalogue
  }
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Groups databases
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- The group schema (aliases, disposition, units[cell/number/hdg/size/random/fitToUnit],
-- description, groupName, hidden) is documented in veaf-units.yaml.
-- Populated at mission build by the injected spawn-data module (rendered from
-- veaf-units.yaml). Defaults to empty so the framework loads standalone. See ADR 0005.
veafUnits.GroupsDatabase = {}

function veafUnits.initialize()
  veaf.loggers.get(veafUnits.Id):info("Initializing module")
end

-- Registered although `initialize()` does nothing but log: the generated `veaf-config.lua` already
-- calls it on every mission, and a registry that omits it describes a framework that does not exist.
-- The order is the infrastructure tier — this module's tables are filled at load, so no initialisation
-- order can be wrong for it. See docs/agents/module-initialisation.md.
veaf.registerModule(veafUnits.Id, veafUnits.initialize, { enable = true }, 1)

veaf.loggers.get(veafUnits.Id):info(veaf.loggers.get(veafUnits.Id):getVersionInfo())

if veafUnits.OutputListsForDocumentation then
  veafUnits.logGroupsListInMarkdown()
  veafUnits.logUnitsListInMarkdown()
end
