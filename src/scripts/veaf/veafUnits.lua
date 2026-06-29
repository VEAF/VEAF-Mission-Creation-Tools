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

            bottomleft = string.format("               %03d    ", mist.utils.toDegree(unit.spawnPoint.hdg))

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
  -- fallback: case-insensitive match on type or name
  if not unit then
    for _, u in pairs(dcsUnits.DcsUnitsDatabase) do
      if (u and u.type and unitType:lower() == u.type:lower()) or (u and u.name and unitType:lower() == u.name:lower()) then
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

  if unit then
    unit = veafUnits.findDcsUnit(unit.unitType)
  else
    unit = veafUnits.findDcsUnit(unitAlias)
  end
  if not unit then
    veaf.loggers.get(veafUnits.Id):info("cannot find unit [" .. unitAlias .. "]")
  else
    unit = veafUnits.makeUnitFromDcsStructure(unit, 1)
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
  local landType = land.getSurfaceType(vec2)

  local IsNavalStatic = false --offshore static (list in dcsUnits.lua) flag
  if unit.static and veaf.findInTable(dcsUnits.NavalStatics, unit.typeName) then
    veaf.loggers.get(veafUnits.Id):trace("Is Naval Static")
    IsNavalStatic = true
  end

  if landType == land.SurfaceType.WATER then
    veaf.loggers.get(veafUnits.Id):trace("landType = WATER")
  else
    veaf.loggers.get(veafUnits.Id):trace("landType = GROUND")
  end
  if spawnPosition then
    if unit.air then -- if the unit is a plane or helicopter
      if spawnPosition.z <= 10 then -- if lower than 10m don't spawn unit
        return false
      end
    elseif unit.naval or IsNavalStatic then -- if the unit is a naval unit or an offshore static
      if landType ~= land.SurfaceType.WATER then -- don't spawn over anything but water
        return false
      end
    else
      if landType == land.SurfaceType.WATER then -- don't spawn over water
        return false
      end
    end
  end
  return true
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
        local angle = mist.utils.toRadian(hdg)
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
        unit.spawnPoint.hdg = mist.utils.toRadian(unitHeading)
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

veaf.loggers.get(veafUnits.Id):info(veaf.loggers.get(veafUnits.Id):getVersionInfo())

if veafUnits.OutputListsForDocumentation then
  veafUnits.logGroupsListInMarkdown()
  veafUnits.logUnitsListInMarkdown()
end
