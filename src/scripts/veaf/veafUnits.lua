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

--- Version.
veafUnits.Version = "1.13.2"

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
veafUnits.DefaultPathfindingGroup =
{
    disposition = {h=1, w=1},
    units = {
        {veafUnits.DefaultPathfindingUnitType, random = true}
    },
    groupName = "Pathfinder",
    description = "Plz Fix ED"
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
            line1 = line1 .. "                ".. string.format("%02d", nCol) .."              |"
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
                            unitName = unitName:sub(1,11)
                        end
                        unitName = string.format("%02d", unitCounter) .. "-" .. unitName
                        local spaces = 14 - unitName:len()
                        for i=1, math.floor(spaces/2) do
                            unitName = " " .. unitName
                        end
                        for i=1, math.ceil(spaces/2) do
                            unitName = unitName .. " "
                        end
                        center = " " .. unitName .. " "

                        bottomleft = string.format("               %03d    ", mist.utils.toDegree(unit.spawnPoint.hdg))

                        unitCounter = unitCounter + 1
                    end

                    left = string.format("%08d",math.floor(cell.left))
                    top = string.format("%08d",math.floor(cell.top))
                    right = string.format("%08d",math.floor(cell.right))
                    bottom = string.format("%08d",math.floor(cell.bottom))
                end

                line1 = line1 .. "  " .. top .. "                      " .. "|"
                line2 = line2 .. "" .. left .. center .. right.. "|"
                line3 = line3 .. bottomleft  .. bottom.. "  |"
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
    local unit = nil
    for _, u in pairs(dcsUnits.DcsUnitsDatabase) do
        if      (u and u.type and unitType:lower() == u.type:lower())
            or  (u and u.name and unitType:lower() == u.name:lower())
        then
            unit = u
            break
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
    veaf.loggers.get(veafUnits.Id):trace("group="..veaf.p(group))
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
        veaf.loggers.get(veafUnits.Id):trace("u="..veaf.p(u))
        if type(u) == "string" then
            -- information was skipped using simplified syntax
            unitType = u
        else
            unitType = u.typeName
            if not unitType then
                unitType = u[1]
            end
            veaf.loggers.get(veafUnits.Id):trace("unitType="..veaf.p(unitType))
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
        if not(number) then
          number = 1
        end
        if type(number) == "table" then
            -- create a random number of units
            local min = number.min
            local max = number.max
            if not(min) then min = 1 end
            if not(max) then max = 1 end
            number = math.random(min, max)
        end
        if not(hdg) then
            hdg = math.random(0, 359) -- default heading is random
        end
        veaf.loggers.get(veafUnits.Id):trace(string.format("hdg=%d",hdg))
        for numUnit = 1, number do
            veaf.loggers.get(veafUnits.Id):trace("searching for unit [" .. unitType .. "] listed in group [" .. group.groupName .. "]")
            local unit = veafUnits.findUnit(unitType)
            if not(unit) then
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

    veaf.loggers.get(veafUnits.Id):trace("result="..veaf.p(result))

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
    if not(unit) then
        veaf.loggers.get(veafUnits.Id):info("cannot find unit [" .. unitAlias .. "]")
    else
        unit = veafUnits.makeUnitFromDcsStructure(unit, 1)
    end

    return unit
end

--- Creates a simple structure from DCS complex metadata structure
function veafUnits.makeUnitFromDcsStructure(dcsUnit, cell)
    local result = {}
    if not(dcsUnit) then
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
    result.category = dcsUnit.category
    result.typeName = dcsUnit.type
    result.displayName = dcsUnit.description
    result.naval = (dcsUnit.naval)
    result.air = (dcsUnit.air)

    if (not(dcsUnit.naval) and not(dcsUnit.air) and not(dcsUnit.infantry) and not(dcsUnit.vehicle) and (dcsUnit.attribute==nil or dcsUnit.attribute.Fortifications==nil)) then
        result.static = true
    end

    result.infantry = (dcsUnit.infantry)
    result.vehicle = (dcsUnit.vehicle)
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
    veaf.loggers.get(veafUnits.Id):trace(string.format("group = %s",veaf.p(group)))
    if not(hdg) then
        hdg = 0 -- default north
    end

    local hasDest = false or hasDest
    veaf.loggers.get(veafUnits.Id):trace(string.format("hasDest = %s", veaf.p(hasDest)))

    if not(group.disposition) then
        -- default disposition is a square
        local l = math.ceil(math.sqrt(#group.units))
        group.disposition = { h = l, w = l}
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
    for cellNum = 1, nRows*nCols do
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
        totalHeight = totalHeight + rows[#rows-nRow+1].height
    end
    veaf.loggers.get(veafUnits.Id):trace(string.format("totalWidth = %d",totalWidth))
    veaf.loggers.get(veafUnits.Id):trace(string.format("totalHeight = %d",totalHeight))
    -- place the grid
    local currentColLeft = spawnPoint.z - totalWidth/2
    local currentColTop = spawnPoint.x - totalHeight/2
    for nCol = 1, #cols do
        veaf.loggers.get(veafUnits.Id):trace(string.format("currentColLeft = %d",currentColLeft))
        cols[nCol].left = currentColLeft
        cols[nCol].right= currentColLeft + cols[nCol].width
        currentColLeft = cols[nCol].right
    end
    for nRow = 1, #rows do -- bottom -> up
        veaf.loggers.get(veafUnits.Id):trace(string.format("currentColTop = %d",currentColTop))
        rows[#rows-nRow+1].bottom = currentColTop
        rows[#rows-nRow+1].top = currentColTop + rows[#rows-nRow+1].height
        currentColTop = rows[#rows-nRow+1].top
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
        veaf.loggers.get(veafUnits.Id):trace(string.format("cell = %s",veaf.p(cell)))
        local unit = cell.unit
        if unit then
            unit.spawnPoint = {}
            if not cell.center then
                veaf.loggers.get(veafUnits.Id):error(string.format("Cannot find cell.center !"))
                veaf.loggers.get(veafUnits.Id):error(string.format("cell = %s",veaf.p(cell)))
                veaf.loggers.get(veafUnits.Id):error(string.format("group = %s",veaf.p(group)))
            end
            unit.spawnPoint.z = cell.center.x
            if unit.random and spacing > 0 then
                unit.spawnPoint.z = unit.spawnPoint.z + math.random(-((spacing-1) * (unit.width or veafUnits.DefaultCellWidth))/2, ((spacing-1) * (unit.width or veafUnits.DefaultCellWidth))/2)
            end
            unit.spawnPoint.x = cell.center.y
            if unit.random and spacing > 0 then
                unit.spawnPoint.x = unit.spawnPoint.x + math.random(-((spacing-1) * (unit.length or veafUnits.DefaultCellHeight))/2, ((spacing-1) * (unit.length or veafUnits.DefaultCellHeight))/2)
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
            for _,unit in pairs(units) do
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
    local function _sortGroupNameCaseInsensitive(g1,g2)
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
    local function _sortUnitNameCaseInsensitive(u1,u2)
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
    for _, u in pairs(units) do  -- serialize its fields
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

veafUnits.UnitsDatabase = {
    {
        aliases = {"hq7"},
        unitType = "HQ-7_LN_SP",
    },
    {
        aliases = {"hq7eo"},
        unitType = "HQ-7_LN_EO",
    },
    {
        aliases = {"sa8", "sa-8"},
        unitType = "Osa 9A33 ln",
    },
    {
        aliases = {"sa9", "sa-9"},
        unitType = "Strela-1 9P31"
    },
    {
        aliases = {"sa13", "sa-13"},
        unitType = "Strela-10M3",
    },
    {
        aliases = {"sa15", "sa-15"},
        unitType = "Tor 9A331",
    },
    {
        aliases = {"sa18", "sa-18", "manpad"},
        unitType = "SA-18 Igla-S manpad",
    },
    {
        aliases = {"dogear"},
        unitType = "Dog Ear radar",
    },
    {
        aliases = {"shilka"},
        unitType = "ZSU-23-4 Shilka",
    },
    {
        aliases = {"tarawa"},
        unitType = "LHA_Tarawa",
    },
    {
        aliases = {"blue-ewr"},
        unitType = "FPS-117",
    },
    {
        aliases = {"red-ewr"},
        unitType = "1L13 EWR",
    },
    {
        aliases = {"avenger"},
        unitType = "M1097 Avenger",
    },
}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Groups databases
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Syntax :
------------
-- 
-- aliases : list of aliases which can be used to designate this group, case insensitive
-- disposition : height and width (in cells) of the group layout template (see explanation of group layouts below)
-- units : list of all the units composing the group. Each unit in the list is composed of :
--      alias : alias of the unit in the VEAF units database, or actual DCS type name in the DCS units database
--      cell : preferred layout cell ; the unit will be spawned in this cell, in the layout defined in the *layout* field. (see explanation of group layouts below) ; when nothing else is  specified, a number after the unit alias is considered to be the *cell* parameter
--      size : fixes the cell size (in meters), instead of relying on the contained unit size (modified with the *spacing* parameter) ; can be either a table with width and height, or a number for square cells
--      number : either a number, which will be the quantity of this unit type spawned ; or a table, with *min* and *max* values that will be used to spawn a random quantity of this unit typ
--      hdg : the unit heading will mean that, if the group is spawned facing north, this unit will be facing this heading (in degrees). If not set, units will face the group heading
--      random : if set, the unit will be placed randomly in the cell, leaving a one unit size margin around.
--      fitToUnit : if set, the cell around the unit will not be a square but a rectangle of the unit's exact size (plus the spacing, if set)
-- description = human-friendly name for the group
-- groupName   = name used when spawning this group (will be flavored with a numerical suffix)
--
-- empty cells measure 10m x 10m

veafUnits.GroupsDatabase = {
    --China
    {
        aliases = {"hq7"},
        group = {
            disposition = { h= 5, w= 5},
            units = {
                --STR
                {"HQ-7_STR_SP", cell = 8},
                --LN
                {"HQ-7_LN_SP", cell = 1, hdg = 300}, {"HQ-7_LN_SP", cell = 5, hdg = 60}, {"HQ-7_LN_SP", cell = 23, hdg = 180},
                --supply truck
                {"Ural-375", random=true},
            },
            description = "HQ-7 SAM site",
            groupName = "HQ-7"
        },
    },
    {
        aliases = {"hq7_single"},
        group = {
            disposition = { h= 3, w= 3},
            units = {
                --LN
                {"HQ-7_LN_SP", cell = 1},
                --supply truck
                {"Ural-375", random=true},
            },
            description = "HQ-7 SAM site",
            groupName = "HQ-7"
        },
    },
    {
        aliases = {"hq7-noew"},
        group = {
            disposition = { h= 5, w= 5},
            units = {{"HQ-7_LN_SP", cell = 1, hdg = 300}, {"HQ-7_LN_SP", cell = 5, hdg = 60}, {"HQ-7_LN_SP", cell = 23, hdg = 180}, {"Ural-375", random=true},},
            description = "HQ-7 SAM site without STR",
            groupName = "HQ-7"
        },
    },
    {
        aliases = {"hq7eo"},
        group = {
            disposition = { h= 5, w= 5},
            units = {
                --STR
                {"HQ-7_STR_SP", cell = 8},
                --LN
                {"HQ-7_LN_EO", cell = 1, hdg = 300}, {"HQ-7_LN_EO", cell = 5, hdg = 60}, {"HQ-7_LN_EO", cell = 23, hdg = 180},
                --supply truck
                {"Ural-375", random=true},
            },
            description = "HQ-7EO SAM site",
            groupName = "HQ-7"
        },
    },
    {
        aliases = {"hq7eo_single"},
        group = {
            disposition = { h= 3, w= 3},
            units = {
                --LN
                {"HQ-7_LN_EO", cell = 1},
                --supply truck
                {"Ural-375", random=true},
            },
            description = "HQ-7EO SAM site",
            groupName = "HQ-7"
        },
    },
    {
        aliases = {"hq7eo-noew"},
        group = {
            disposition = { h= 5, w= 5},
            units = {{"HQ-7_LN_EO", cell = 1, hdg = 300}, {"HQ-7_LN_EO", cell = 5, hdg = 60}, {"HQ-7_LN_EO", cell = 23, hdg = 180}, {"Ural-375", random=true},},
            description = "HQ-7EO SAM site without STR",
            groupName = "HQ-7"
        },
    },
    --Warsaw Pact
    {
        aliases = {"sa2", "sa-2", "fs"},
        group = {
            disposition = { h= 6, w= 8},
            units = {
                {"SNR_75V", cell = 20}, {"p-19 s-125 sr", cell = 48}, {"S_75M_Volhov", cell = 2, hdg = 315}, {"S_75M_Volhov", cell = 6, hdg = 45}, {"S_75M_Volhov", cell = 17, hdg = 270}, {"S_75M_Volhov", cell = 24, hdg = 90}, {"S_75M_Volhov", cell = 34, hdg = 225}, {"S_75M_Volhov", cell = 38, hdg = 135},
                {"ZSU_57_2", number = {min=1, max=2}, random=true},
                {"S-60_Type59_Artillery", number = {min=1, max=2}, random=true},
                {"ZIL-135", number = {min = 1, max = 2}, random=true},
            },
            description = "SA-2 SAM site",
            groupName = "SA2"
        },
    },
    {
        aliases = {"sa3", "sa-3", "lb"},
        group = {
            disposition = { h= 7, w= 9},
            units = {
                {"p-19 s-125 sr", cell = 1}, {"snr s-125 tr", cell = 33}, {"5p73 s-125 ln", cell = 18, hdg = 30}, {"5p73 s-125 ln", cell = 30, hdg = 270}, {"5p73 s-125 ln", cell = 61, hdg = 150},
                {"ZSU_57_2", number = {min=1, max=2}, random=true},
                {"S-60_Type59_Artillery", number = {min=1, max=2}, random=true},
                {"ZIL-135", number = {min = 1, max = 2}, random=true},
            },
            description = "SA-3 SAM site",
            groupName = "SA3"
        },
    },
    {
        -- Sa-5 SAM site (2 launcher battery configuration, IRL 5 maximum could be seen deployed on one site). Note: doesn't come out exactly as planned when spawned, but close enough
        aliases = {"sa5", "sa-5", "S-200", "S200", "s200", "s-200"},
        group = {
            disposition = {h= 155, w= 120},
            units = {
                -- Search radar unit
                {"RLS_19J6", cell = 17614, size = 10},
                -- Track radar unit
                {"RPC_5N62V", cell = 15118, size = 10},
                --generator units
                {"generator_5i57", hdg = 80, cell = 15358, size = 10}, {"generator_5i57", hdg = 75, cell = 17854, size = 10}, --Track Radar, Search Radar generator

                -- launchers
                --battery 1
                {"S-200_Launcher", hdg = 2, cell = 676, size = 10}, {"S-200_Launcher", hdg = 4, cell = 702, size = 10}, {"S-200_Launcher", hdg = 358, cell = 2749, size = 10}, {"S-200_Launcher", hdg = 358, cell = 3069, size = 10}, {"S-200_Launcher", hdg = 358, cell = 4786, size = 10}, {"S-200_Launcher", hdg = 355, cell = 5115, size = 10},
                --battery 2
                {"S-200_Launcher", hdg = 347, cell = 7231, size = 10}, {"S-200_Launcher", hdg = 343, cell = 8045, size = 10}, {"S-200_Launcher", hdg = 341, cell = 8935, size = 10}, {"S-200_Launcher", hdg = 355, cell = 9962, size = 10}, {"S-200_Launcher", hdg = 350, cell = 10734, size = 10}, {"S-200_Launcher", hdg = 340, cell = 11781, size = 10},

                -- missile loading trucks (emulated, 1 per launcher for simplicity, 2 IRL)
                --battery 1
                {"ZIL-135", hdg = 174, cell = 76, size = 10}, {"ZIL-135", hdg = 181, cell = 102, size = 10}, {"ZIL-135", hdg = 194, cell = 2149, size = 10}, {"ZIL-135", hdg = 179, cell = 2469, size = 10}, {"ZIL-135", hdg = 165, cell = 4186, size = 10}, {"ZIL-135", hdg = 183, cell = 4515, size = 10},
                --battery 2
                {"ZIL-135", hdg = 157, cell = 6631, size = 10}, {"ZIL-135", hdg = 175, cell = 7445, size = 10}, {"ZIL-135", hdg = 165, cell = 8335, size = 10}, {"ZIL-135", hdg = 175, cell = 9362, size = 10}, {"ZIL-135", hdg = 172, cell = 10134, size = 10}, {"ZIL-135", hdg = 179, cell = 11181, size = 10},

                -- C2 units
                --battery 1
                {"ZIL-131 KUNG", hdg = 192, cell = 2730, size = 10},
                --battery 2
                {"ZIL-131 KUNG", hdg = 170, cell = 9262, size = 10},
                --site wide
                {"ZIL-131 KUNG", cell = 14616, size = 10}
            },
            description = "S200 SAM site",
            groupName = "S200"
        },
    },
    {
        aliases = {"sa6", "sa-6", "06"},
        group = {
            disposition = { h= 7, w= 7},
            units = {
                {"Kub 1S91 str", cell = 25}, {"Kub 2P25 ln", cell = 4, hdg = 180}, {"Kub 2P25 ln", cell = 22, hdg = 90}, {"Kub 2P25 ln", cell = 28, hdg = 270}, {"Kub 2P25 ln", cell = 46, hdg = 0},
                {"ZSU-23-4 Shilka", number = {min=1, max=2}, random=true},
                {"ATZ-5", random=true},
                {"ZIL-135", number = {min = 1, max = 2}, random=true},
                {"Ural-375 PBU", random=true}
            },
            description = "SA-6 SAM site",
            groupName = "SA6"
        },
    },
    {
        aliases = {"sa8_squad"},
        group = {
            disposition = { h= 4, w= 4},
            units = {{"Osa 9A33 ln", random = true}, {"GAZ-66", random=true}},
            description = "Sa-8 SAM site",
            groupName = "SA8"
        },
    },
    {
        aliases = {"sa9_squad"},
        group = {
            disposition = { h= 4, w= 4},
            units = {{"Strela-1 9P31", random = true}, {"GAZ-66", random=true}},
            description = "Sa-9 SAM site",
            groupName = "SA9"
        },
    },
    {
        aliases = {"sa10", "s300", "bb"},
        group = {
            disposition = { h= 10, w= 13},
            units = {
                {"S-300PS 40B6MD sr", cell = 130},
                {"S-300PS 40B6M tr", cell = 7},
                {"S-300PS 5P85C ln", cell = 29},
                {"S-300PS 5P85D ln", cell = 37},
                {"S-300PS 5P85D ln", cell = 43},
                {"S-300PS 5P85C ln", cell = 49},
                {"S-300PS 5P85C ln", cell = 57},
                {"S-300PS 5P85D ln", cell = 61},
                {"S-300PS 5P85D ln", cell = 71},
                {"S-300PS 5P85C ln", cell = 73},
                {"S-300PS 64H6E sr", cell = 98},
                {"S-300PS 54K6 cp", cell = 118},
                {"ZSU-23-4 Shilka", number = {min=1, max=2}, random=true},
                {"2S6 Tunguska", random=true},
            },
            description = "S300 SAM site",
            groupName = "S300"
        },
    },
    {
        aliases = {"sa11", "sa-11", "sd"},
        group = {
            disposition = { h= 9, w= 9},
            units = {
                {"SA-11 Buk SR 9S18M1", cell = 42}, {"SA-11 Buk CC 9S470M1", cell = 39}, {"SA-11 Buk LN 9A310M1", cell = 1}, {"SA-11 Buk LN 9A310M1", cell = 5}, {"SA-11 Buk LN 9A310M1", cell = 9}, {"SA-11 Buk LN 9A310M1", cell = 72}, {"SA-11 Buk LN 9A310M1", cell = 76}, {"SA-11 Buk LN 9A310M1", cell = 81},
                {"ZSU-23-4 Shilka", number = {min=1, max=2}, random=true},
                {"ATZ-5", random=true},
                {"Ural-375", number = {min = 1, max = 2}, random=true},
            },
            description = "SA-11 SAM site",
            groupName = "SA11"
        },
    },
    {
        aliases = {"sa13_squad"},
        group = {
            disposition = { h= 4, w= 4},
            units = {{"Strela-10M3", random = true}, {"GAZ-66", random=true}},
            description = "Sa-13 SAM site",
            groupName = "SA13"
        },
    },
    {
        aliases = {"sa15_squad"},
        group = {
            disposition = { h= 4, w= 4},
            units = {{"Tor 9A331", random = true}, {"GAZ-66", random=true}},
            description = "Sa-15 SAM site",
            groupName = "SA15"
        },
    },
    {
        -- insurgent sa18 squad
        aliases = {"insurgent_manpad_squad", "ins_manpad"},
        group = {
            disposition = {h= 3, w= 3},
            units = {
                -- IglaS Command Unit
                {"MANPADS SA-18 Igla \"Grouse\" C2", random=true},
                -- IglaS
                {"Igla manpad INS", random=true},
                -- Troops
                {"Infantry AK Ins", number = {min=2, max=3}, random=true},
                -- Transport
                {"HL_DSHK", random=true}
            },
            description = "Insurgent Sa-18 Manpad Squad",
            groupName = "Insurgent Manpad Squad"
        },
    },
    {
        -- sa18 squad
        aliases = {"sa18_squad"},
        group = {
            disposition = {h= 3, w= 3},
            units = {
                -- IglaS Command Unit
                {"MANPADS SA-18 Igla \"Grouse\" C2", random=true},
                -- IglaS
                {"SA-18 Igla manpad", number = {min=1, max=2}, random=true},
                -- Troops
                {"Infantry AK", number = {min=2, max=4}, random=true},
                --Transport
                {"UAZ-469", random=true}
            },
            description = "Sa-18 Manpad Squad",
            groupName = "Red Manpad Squad"
        },
    },
    {
        -- sa18s squad
        aliases = {"sa18s_squad"},
        group = {
            disposition = {h= 4, w= 4},
            units = {
                -- IglaS Command Unit
                {"MANPADS SA-18 Igla-S \"Grouse\" C2", random=true},
                -- IglaS
                {"SA-18 Igla-S manpad", number = {min=1, max=2}, random=true},
                -- Troops
                {"Infantry AK ver2", number = {min=2, max=6}, random=true},
                --Transport
                {"Tigr_233036", random=true}
            },
            description = "Sa-18S Manpad Squad",
            groupName = "Red Modern Manpad Squad"
        },
    },
    {
        aliases = {"sa19_squad"},
        group = {
            disposition = { h= 4, w= 4},
            units = {{"2S6 Tunguska", random = true}, {"Ural-375", random=true}},
            description = "Sa-19 SAM site",
            groupName = "SA19"
        },
    },
    {
        -- red ewr position
        aliases = {"red_ewr", "ewr"},
        group = {
            disposition = {h= 7, w= 7},
            units = {
                -- Radar unit
                {"55G6 EWR", cell = 25},
                -- IglaS Command Unit
                {"MANPADS SA-18 Igla \"Grouse\" C2", random=true},
                -- IglaS
                {"SA-18 Igla manpad", random=true},
                -- C2
                {"Ural-375 PBU", random=true}
            },
            description = "Red EWR",
            groupName = "Red EWR"
        },
    },
    --NATO 
    {
        aliases = {"rapier_optical", "rpo"},
        group = {
            disposition = { h= 5, w= 5},
            units = {
                {"rapier_fsa_optical_tracker_unit", cell = 9},
                {"rapier_fsa_optical_tracker_unit", cell = 17},
                {"rapier_fsa_launcher", cell = 1, hdg = 315},
                {"rapier_fsa_launcher", cell = 5, hdg = 45},
                {"rapier_fsa_launcher", cell = 21, hdg = 225},
                {"rapier_fsa_launcher", cell = 25, hdg = 135},

                --supply/crew truck
                {"Land_Rover_101_FC", number = {min=1, max = 2}, random = true},
            },
            description = "Rapier SAM site",
            groupName = "Rapier"
        },
    },
    {
        aliases = {"rapier_radar", "rpr"},
        group = {
            disposition = { h= 5, w= 5},
            units = {
                {"rapier_fsa_blindfire_radar", cell = 13},
                {"rapier_fsa_optical_tracker_unit", cell = 9},
                {"rapier_fsa_optical_tracker_unit", cell = 17},
                {"rapier_fsa_launcher", cell = 1, hdg = 315},
                {"rapier_fsa_launcher", cell = 5, hdg = 45},
                {"rapier_fsa_launcher", cell = 21, hdg = 225},
                {"rapier_fsa_launcher", cell = 25, hdg = 135},

                --supply/crew truck
                {"Land_Rover_101_FC", number = {min=1, max = 2}, random = true},
            },
            description = "Rapier SAM site with radar",
            groupName = "Rapier-radar"
        },
    },
    {
        -- Stinger Squad
        aliases = {"stinger_squad"},
        group = {
            disposition = {h= 4, w= 4},
            units = {
                -- Stinger Command Unit
                {"MANPADS Stinger C2", random=true}, {"MANPADS Stinger C2", random=true},
                -- Stinger
                {"Soldier stinger", random=true}, {"Soldier stinger", random=true},
                -- Troops
                {"Soldier M4 GRG", number = {min=3, max=4}, random=true},
                --Transport
                {"Hummer", random=true}, {"Hummer", random=true}
            },
            description = "Stinger Manpad Squad",
            groupName = "Blue Manpad Squad"
        },
    },
    {
        aliases = {"avenger_squad"},
        group = {
            disposition = { h= 4, w= 4},
            units = {{"M1097 Avenger", random = true}, {"M 818", random=true}},
            description = "Avenger SAM site",
            groupName = "Avenger"
        },
    },
    {
        aliases = {"roland"},
        group = {
            disposition = { h= 5, w= 5},
            units = {{"Roland Radar", cell = 8}, {"Roland ADS", cell = 1 , hdg = 300}, {"Roland ADS", cell = 5, hdg = 60}, {"Roland ADS", cell = 23, hdg = 180}, {"M 818", random=true}},
            description = "Roland SAM site",
            groupName = "Roland"
        },
    },
    {
        aliases = {"roland-noew"},
        group = {
            disposition = { h= 5, w= 5},
            units = {{"Roland ADS", cell = 1 , hdg = 300}, {"Roland ADS", cell = 5, hdg = 60}, {"Roland ADS", cell = 23, hdg = 180}, {"M 818", random=true}},
            description = "Roland SAM site",
            groupName = "Roland"
        },
    },
    {
        -- NASAMS SHORAD system with 120C
        aliases = {"nasams_c", "nasams", "NASAMS", "NASAMS_C"},
        group = {
            disposition = { h= 7, w= 11},
            units = {
                -- Search radar unit
                {"NASAMS_Radar_MPQ64F1", cell = 41},
                -- launchers
                {"NASAMS_LN_C", hdg = 315, cell = 4}, {"NASAMS_LN_C", hdg = 45, cell = 11}, {"NASAMS_LN_C", hdg = 225, cell = 70}, {"NASAMS_LN_C", hdg = 135, cell = 77},
                -- C2
                {"NASAMS_Command_Post", cell = 34},
                -- a supply truck or three
                {"M 818", number = {min=1, max=3}, random=true},
                --IR defense
                {"M1097 Avenger", number = {min=1, max=2}, random=true}
            },
            description = "NASAMS C battery",
            groupName = "NASAMS C battery"
        },
    },
    {
        -- NASAMS SHORAD system with 120B
        aliases = {"nasams_b", "NASAMS_B"},
        group = {
            disposition = { h= 7, w= 11},
            units = {
                -- Search radar unit
                {"NASAMS_Radar_MPQ64F1", cell = 41},
                -- launchers
                {"NASAMS_LN_B", hdg = 315, cell = 4}, {"NASAMS_LN_B", hdg = 45, cell = 11}, {"NASAMS_LN_B", hdg = 225, cell = 70}, {"NASAMS_LN_B", hdg = 135, cell = 77},
                -- C2
                {"NASAMS_Command_Post", cell = 34},
                -- a supply truck or three
                {"M 818", number = {min=1, max=3}, random=true},
                --IR defense
                {"M1097 Avenger", number = {min=1, max=2}, random=true}
            },
            description = "NASAMS B battery",
            groupName = "NASAMS B battery"
        },
    },
    {
        aliases = {"hawk", "ha", "mim-23"},
        group = {
            disposition = { h= 40, w= 40},
            units = {
                {"Hawk sr", cell = 816},
                {"Hawk cwar", cell = 826},
                {"Hawk cwar", cell = 1100},

                {"Hawk tr", cell = 381, hdg = 0},
                {"Hawk tr", cell = 1208, hdg = 240},
                {"Hawk tr", cell = 1231, hdg = 120},

                {"Hawk pcp", cell = 941},

                {"Hawk ln", cell = 22, hdg = 0}, {"Hawk ln", cell = 297, hdg = 300 }, {"Hawk ln", cell = 306, hdg = 60},
                {"Hawk ln", cell = 1042, hdg = 300}, {"Hawk ln", cell = 1401, hdg = 240 }, {"Hawk ln", cell = 1568, hdg = 180},
                {"Hawk ln", cell = 1080, hdg = 60}, {"Hawk ln", cell = 1440, hdg = 120 }, {"Hawk ln", cell = 1588, hdg = 180},

                -- a supply truck or three
                {"M 818", number = {min=4, max=6}, random=true},
                --AAA defense
                {"Vulcan", number = {min=2, max=3}, random=true},
                --IR defense
                {"M1097 Avenger", random=true},
            },
            description = "Hawk SAM site",
            groupName = "Hawk"
        },
    },
    {
        aliases = {"patriot", "pa", "mim-104"},
        group = {
            disposition = { h= 7, w= 12},
            units = {
                {"Patriot str", cell = 66, hdg = 0},
                {"Patriot cp" , cell = 78},
                {"Patriot AMG", cell = 79},
                {"Patriot ECS", cell = 67},
                {"Patriot EPP", cell = 68},

                {"Patriot ln", cell = 1, hdg = 280},
                {"Patriot ln", cell = 2, hdg = 300},

                {"Patriot ln", cell = 28, hdg = 20},
                {"Patriot ln", cell = 29, hdg = 40},
                {"Patriot ln", cell = 32, hdg = 330},
                {"Patriot ln", cell = 33, hdg = 310},

                {"Patriot ln", cell = 11, hdg = 60},
                {"Patriot ln", cell = 12, hdg = 80},

                --supply trucks
                {"M 818", number = {min=2, max=5}, random=true},

                --AAA defense
                {"Vulcan", number = {min=0, max=1}, cell = 60},
                {"Vulcan", number = {min=0, max=1}, cell = 48},
                {"Vulcan", cell = 54},
            },
            description = "Patriot SAM site",
            groupName = "Patriot"
        },
    },
    {
        -- blue ewr position
        aliases = {"blue_ewr"},
        group = {
            disposition = {h= 7, w= 7},
            units = {
                -- Radar unit
                {"FPS-117 Dome", cell = 25},
                -- IR Defense
                {"M1097 Avenger", random=true}
            },
            description = "Blue EWR",
            groupName = "Blue EWR"
        },
    },
    --infantry
    {
        aliases = {"infantry section", "infsec"},
        group = {
            disposition = { h= 10, w= 4},
            units = {{"IFV BTR-80", cell=38, random=true},{"IFV BTR-80", cell=39, random=true},{"INF Soldier AK", number = {min=12, max=30}, random=true}, {"SA-18 Igla manpad", number = {min=0, max=2}, random=true}},
            description = "Mechanized infantry section with APCs",
            groupName = "Mechanized infantry section"
        },
    },
    {
        aliases = {"US infgroup"},
        group = {
            disposition = { h = 5, w = 5},
            units = {{"Hummer", number = {min=1, max=2}, random=true},{"Soldier M249", number = {min=1, max=2}, random=true},{"Soldier M4", number = {min=2, max=4}, random=true},{"Soldier M4 GRG", number = {min=6, max=15}, random=true}},
            description = "US infantry group",
            groupName = "US infantry group",
        },
    },
    --artillery
    {
        aliases = {"insurgent_arty"},
        group = {
            disposition = { h = 2, w = 4},
            units = { {"tt_B8M1", number = {min=1, max=2}}, {"HL_B8M1", number = {min=1, max=2}} },
            description = "Insurgent artillery battery",
            groupName = "Insurgent artillery battery",
        },
    },
    {
        aliases = {"mortar"},
        group = {
            disposition = { h = 2, w = 4},
            units = { {"2B11 mortar", number = 4} },
            description = "2B11 Mortar team",
            groupName = "2B11 Mortar team",
        },
    },
    {
        aliases = {"M-109"},
        group = {
            disposition = { h = 2, w = 3},
            units = { {"M-109", number = 3}, {"MLRS FDDM", number = 1}, {"M 818", number = 1} },
            description = "M-109 artillery battery",
            groupName = "M-109 artillery battery",
        },
    },
    {
        aliases = {"PLZ05"},
        group = {
            disposition = { h = 2, w = 3},
            units = { {"PLZ05", number = 3}, {"Grad_FDDM", number = 1}, {"Ural-375", number = 1} },
            description = "PLZ05 artillery battery",
            groupName = "PLZ05 artillery battery",
        },
    },
    {
        aliases = {"Msta"},
        group = {
            disposition = { h = 2, w = 3},
            units = { {"SAU Msta", number = 3}, {"Grad_FDDM", number = 1}, {"Ural-375", number = 1} },
            description = "Msta artillery battery",
            groupName = "Msta artillery battery",
        },
    },
    {
        aliases = {"MLRS"},
        group = {
            disposition = { h = 2, w = 4},
            units = { {"MLRS", number = 4}, {"MLRS FDDM", number = 1}, {"M 818", number = 1} },
            description = "M270 MLRS artillery battery",
            groupName = "M270 MLRS artillery battery",
        },
    },
    {
        aliases = {"SmerchCM"},
        group = {
            disposition = { h = 2, w = 4},
            units = { {"Smerch", number = 4}, {"Grad_FDDM", number = 1}, {"ZIL-135", number = 2} },
            description = "Smerch (CM) MLRS artillery battery",
            groupName = "Smerch (CM) MLRS artillery battery",
        },
    },
    {
        aliases = {"SmerchHE"},
        group = {
            disposition = { h = 2, w = 4},
            units = { {"Smerch_HE", number = 4}, {"Grad_FDDM", number = 1}, {"ZIL-135", number = 2} },
            description = "Smerch (HE) MLRS artillery battery",
            groupName = "Smerch (HE) MLRS artillery battery",
        },
    },
    {
        aliases = {"Uragan"},
        group = {
            disposition = { h = 2, w = 4},
            units = { {"Uragan_BM-27", number = 4}, {"Grad_FDDM", number = 1}, {"ZIL-135", number = 2} },
            description = "Uragan MLRS artillery battery",
            groupName = "Uragan MLRS artillery battery",
        },
    },
    {
        aliases = {"Grad"},
        group = {
            disposition = { h = 2, w = 4},
            units = { {"Grad-URAL", number = 4}, {"Grad_FDDM", number = 1}, {"Ural-375", number = 2} },
            description = "Grad MLRS artillery battery",
            groupName = "Grad MLRS artillery battery",
        },
    },
    --convoys
    {
        aliases = {"US supply convoy","blueconvoy"},
        group = {
            disposition = { h = 20, w = 20},
            units = {
                {"Hummer", number = {min=2, max=4}, random=true},
                {"Truck M 818", number = {min=3, max=6}, random=true},
                {"Truck M978 HEMTT Tanker", number = {min=0, max=3}, random=true},
                {"Truck Predator GCS", number = {min=0, max=2}, random=true},
                {"Truck Predator TrojanSpirit", number = {min=0, max=2}, random=true}
            },
            description = "US supply convoy",
            groupName = "US supply convoy",
        },
    },
    {
        aliases = {"RU supply convoy with defense","redconvoy-def"},
        group = {
            disposition = { h = 20, w = 20},
            units = {
                {"2S6 Tunguska", number = {min=0, max=1}, random=true},
                {"Strela-10M3", number = {min=0, max=1}, random=true},
                {"Strela-1 9P31", number = {min=0, max=1}, random=true},
                {"ZSU-23-4 Shilka", number = {min=0, max=2}, random=true},
                {"ZSU_57_2", number = {min=0, max=1}, random=true},
                {"S-60_Type59_Artillery", number = {min=0, max=1}, random=true},
                {"Ural-375 ZU-23", number = {min=0, max=2}, random=true},
                {"UAZ-469", number = {min=2, max=4}, random=true},
                {"Truck SKP-11", number = {min=1, max=3}, random=true},
                {"Ural-375 PBU", number = {min=1, max=3}, random=true},
                {"Truck Ural-375", number = {min=1, max=3}, random=true},
                {"Truck Ural-4320 APA-5D", number = {min=1, max=3}, random=true},
                {"Truck Ural-4320-31", number = {min=1, max=3}, random=true},
                {"Truck Ural-4320T", number = {min=1, max=3}, random=true},
                {"Truck ZiL-131 APA-80", number = {min=1, max=3}, random=true},
                {"Truck ZIL-131 KUNG", number = {min=1, max=3}, random=true}
            },
            description = "RU supply convoy with defense",
            groupName = "RU supply convoy with defense",
        },
    },
    {
        aliases = {"RU supply convoy with light defense","redconvoy-lightdef"},
        group = {
            disposition = { h = 20, w = 20},
            units = {
                {"ZSU-23-4 Shilka", number = {min=0, max=2}, random=true},
                {"ZSU_57_2", number = {min=0, max=1}, random=true},
                {"S-60_Type59_Artillery", number = {min=0, max=1}, random=true},
                {"Ural-375 ZU-23", number = {min=0, max=2}, random=true},
                {"UAZ-469", number = {min=2, max=4}, random=true},
                {"Truck SKP-11", number = {min=1, max=3}, random=true},
                {"Ural-375 PBU", number = {min=1, max=3}, random=true},
                {"Truck Ural-375", number = {min=1, max=3}, random=true},
                {"Truck Ural-4320 APA-5D", number = {min=1, max=3}, random=true},
                {"Truck Ural-4320-31", number = {min=1, max=3}, random=true},
                {"Truck Ural-4320T", number = {min=1, max=3}, random=true},
                {"Truck ZiL-131 APA-80", number = {min=1, max=3}, random=true},
                {"Truck ZIL-131 KUNG", number = {min=1, max=3}, random=true}
            },
            description = "RU supply convoy with light defense",
            groupName = "RU supply convoy with light defense",
        },
    },
    {
        aliases = {"RU supply convoy with no defense","redconvoy-nodef"},
        group = {
            disposition = { h = 20, w = 20},
            units = {
                {"UAZ-469", number = {min=2, max=4}, random=true},
                {"Truck SKP-11", number = {min=1, max=3}, random=true},
                {"Ural-375 PBU", number = {min=1, max=3}, random=true},
                {"Truck Ural-375", number = {min=1, max=3}, random=true},
                {"Truck Ural-4320 APA-5D", number = {min=1, max=3}, random=true},
                {"Truck Ural-4320-31", number = {min=1, max=3}, random=true},
                {"Truck Ural-4320T", number = {min=1, max=3}, random=true},
                {"Truck ZiL-131 APA-80", number = {min=1, max=3}, random=true},
                {"Truck ZIL-131 KUNG", number = {min=1, max=3}, random=true}
            },
            description = "RU supply convoy with no defense",
            groupName = "RU supply convoy with no defense",
        },
    },
    {
        aliases = {"RU small supply convoy with defense","redsmallconvoy-def"},
        group = {
            disposition = { h = 20, w = 20},
            units = {
                {"2S6 Tunguska", number = {min=0, max=1}, random=true},
                {"Strela-10M3", number = {min=0, max=1}, random=true},
                {"Strela-1 9P31", number = {min=0, max=1}, random=true},
                {"ZSU-23-4 Shilka", number = {min=0, max=2}, random=true},
                {"ZSU_57_2", number = {min=0, max=1}, random=true},
                {"S-60_Type59_Artillery", number = {min=0, max=1}, random=true},
                {"Ural-375 ZU-23", number = {min=0, max=2}, random=true},
                {"UAZ-469", number = {min=1, max=2}, random=true},
                {"Truck SKP-11", number = {min=1, max=2}, random=true},
                {"Ural-375 PBU", number = {min=0, max=2}, random=true},
                {"Truck Ural-375", number = {min=0, max=2}, random=true},
                {"Truck Ural-4320 APA-5D", number = {min=0, max=2}, random=true},
                {"Truck Ural-4320-31", number = {min=0, max=2}, random=true},
                {"Truck Ural-4320T", number = {min=0, max=2}, random=true},
                {"Truck ZiL-131 APA-80", number = {min=0, max=2}, random=true},
                {"Truck ZIL-131 KUNG", number = {min=0, max=2}, random=true}
            },
            description = "RU small supply convoy with defense",
            groupName = "RU small supply convoy with defense",
        },
    },
    {
        aliases = {"RU small supply convoy with light defense","redsmallconvoy-lightdef"},
        group = {
            disposition = { h = 20, w = 20},
            units = {
                {"ZSU-23-4 Shilka", number = {min=0, max=2}, random=true},
                {"ZSU_57_2", number = {min=0, max=1}, random=true},
                {"S-60_Type59_Artillery", number = {min=0, max=1}, random=true},
                {"Ural-375 ZU-23", number = {min=0, max=2}, random=true},
                {"UAZ-469", number = {min=1, max=2}, random=true},
                {"Truck SKP-11", number = {min=1, max=2}, random=true},
                {"Ural-375 PBU", number = {min=0, max=2}, random=true},
                {"Truck Ural-375", number = {min=0, max=2}, random=true},
                {"Truck Ural-4320 APA-5D", number = {min=0, max=2}, random=true},
                {"Truck Ural-4320-31", number = {min=0, max=2}, random=true},
                {"Truck Ural-4320T", number = {min=0, max=2}, random=true},
                {"Truck ZiL-131 APA-80", number = {min=0, max=2}, random=true},
                {"Truck ZIL-131 KUNG", number = {min=0, max=2}, random=true}
            },
            description = "RU small supply convoy with light defense",
            groupName = "RU small supply convoy with light defense",
        },
    },
    {
        aliases = {"RU small supply convoy with no defense","redsmallconvoy-nodef","redconvoy","convoy"},
        group = {
            disposition = { h = 20, w = 20},
            units = {
                {"UAZ-469", number = {min=1, max=2}, random=true},
                {"Truck SKP-11", number = {min=1, max=2}, random=true},
                {"Ural-375 PBU", number = {min=0, max=2}, random=true},
                {"Truck Ural-375", number = {min=0, max=2}, random=true},
                {"Truck Ural-4320 APA-5D", number = {min=0, max=2}, random=true},
                {"Truck Ural-4320-31", number = {min=0, max=2}, random=true},
                {"Truck Ural-4320T", number = {min=0, max=2}, random=true},
                {"Truck ZiL-131 APA-80", number = {min=0, max=2}, random=true},
                {"Truck ZIL-131 KUNG", number = {min=0, max=2}, random=true}
            },
            description = "RU small supply convoy with no defense",
            groupName = "RU small supply convoy with no defense",
        },
    },
    {
        -- High value offensive convoy potentially defended by Sa-15, Sa-19, Sa-13 and armor
        aliases = {"hv_convoy_red"},
        group = {
            disposition = { h= 4, w= 4},
            units = {
                --Radar defense
                {"Tor 9A331", number = {min=0, max=1}, random=true, hdg=0},
                {"2S6 Tunguska", number = {min=0, max=1}, random=true, hdg=0},

                -- scud units
                {"Scud_B", number = {min=0, max=2}, random=true, hdg=0},

                -- armor
                {"T-72B3", random=true, hdg=0},
                {"BTR-82A", random=true, hdg=0},

                --supply truck and C2
                {"ZIL-135", random=true, hdg=0},
                {"Tigr_233036", random=true, hdg=0},

                --IR defense
                {"Strela-10M3", number = {min=0, max=1}, random=true, hdg=0}
            },
            description = "High Value Attack convoy red",
            groupName =  "High Value Attack convoy red"
       },
    },
    {
        -- Offensive convoy potentially defended by Sa-15, Shilka, Sa-13 and armor
        aliases = {"attack_convoy_red"},
        group = {
            disposition = { h= 4, w= 4},
            units = {
                --Radar defense
                {"Tor 9A331", number = {min=0, max=1}, random=true},
                {"ZSU-23-4 Shilka", random=true},

                -- armor
                {"T-72B3", random=true},
                {"BTR-82A", random=true},

                --supply truck
                {"ZIL-135", random=true},

                --IR defense
                {"Strela-10M3", random=true}
            },
            description = "Attack convoy red",
            groupName =  "Attack convoy red"
       },
    },
    {
        -- Quick reaction convoy potentially defended by Roland and armor
        aliases = {"QRC_red"},
        group = {
            disposition = { h= 4, w= 4},
            units = {
                --Radar defense
                {"Roland ADS", number = {min=0, max=1}, random=true},

                -- armor
                {"BTR-82A", number = {min=0, max=1}, random=true},
                {"BTR-82A", random=true},

                --ATGM
                {"VAB_Mephisto", random=true},
                {"VAB_Mephisto", random=true},
            },
            description = "Quick reaction convoy red",
            groupName =  "Quick reaction convoy red"
       },
    },
    {
        -- Offensive convoy potentially defended by Sa-15, Sa-19, Sa-13 and armor
        aliases = {"civilian_convoy_red"},
        group = {
            disposition = {h= 3, w= 3},
            units = {
                -- buses
                {"LAZ Bus", number = {min=1,max=3}, random=true},
                {"LiAZ Bus", number = {min=1,max=3}, random=true},
            },
            description = "Civilian convoy red",
            groupName =  "Civilian convoy red"
       },
    },
    {
        -- Quick reaction convoy potentially defended by Roland and armor
        aliases = {"QRC_blue"},
        group = {
            disposition = { h= 4, w= 4},
            units = {
                --Radar defense
                {"Roland ADS", number = {min=0, max=1}, random=true},

                -- armor
                {"M1128 Stryker MGS", number = {min=0, max=1}, random=true},
                {"M1128 Stryker MGS", random=true},

                --ATGM
                {"M1134 Stryker ATGM", random=true},
                {"M1134 Stryker ATGM", random=true},
            },
            description = "Quick reaction convoy blue",
            groupName =  "Quick reaction convoy blue"
       },
    },
    --ships
    {
        aliases = {"cargoships-nodef", "cargoships"},
        group = {
            disposition = { h = 20, w = 20},
            units = {
                {"Dry-cargo ship-1", number = {min=1, max=3}, random=true, size=150},
                {"Dry-cargo ship-2", number = {min=1, max=3}, random=true, size=150},
                {"ELNYA", number = {min=1, max=3}, random=true, size=150}
            },
            description = "Cargo ships with no defense",
            groupName = "Cargo ships with no defense",
        },
    },
    {
        aliases = {"cargoships-escorted"},
        group = {
            disposition = { h = 20, w = 20},
            units = {
                {"Dry-cargo ship-1", number = {min=1, max=3}, random=true, size=150},
                {"Dry-cargo ship-2", number = {min=1, max=3}, random=true, size=150},
                {"ELNYA", number = {min=1, max=3}, random=true, size=150},
                {"MOLNIYA", number = {min=1, max=2}, random=true, size=150},
                {"ALBATROS", number = {min=1, max=2}, random=true, size=150},
                {"NEUSTRASH", number = {min=0, max=1}, random=true, size=150}
            },
            description = "Cargo ships with escort",
            groupName = "Cargo ships with escort",
        },
    },
    {
        aliases = {"combatships"},
        group = {
            disposition = { h = 20, w = 20},
            units = {
                {"MOLNIYA", number = {min=2, max=3}, random=true, size=150},
                {"ALBATROS", number = {min=2, max=3}, random=true, size=150},
                {"NEUSTRASH", number = {min=1, max=2}, random=true, size=150}
            },
            description = "Combat ships with possible FFG defense",
            groupName = "Combat ships",
        },
    },
    ---
    --- groups made for dynamic group spawning (veafCasMission.generateAirDefenseGroup)
    ---
    {
        aliases = {"generateAirDefenseGroup-BLUE-5"},
        hidden = true,
        group = {
            disposition = { h= 7, w= 7},
            units = {
                -- hawk battery
                {"Hawk sr", cell = 8}, {"Hawk pcp", cell = 13}, {"Hawk tr", cell = 15}, {"Hawk ln", cell = 1, hdg = 225}, {"Hawk ln", cell = 3, hdg = 0 }, {"Hawk ln", cell = 21, hdg = 135},
                -- Some M48 Chaparral
                {"M48 Chaparral", number = {min=2, max=4}, random=true},
                -- Some Gepards
                {"Gepard", number = {min=2, max=4}, random=true},
                -- a supply truck or three
                {"M 818", number = {min=1, max=3}, random=true}
            },
            description = "generateAirDefenseGroup-BLUE-5",
            groupName = "generateAirDefenseGroup-BLUE-5",
        },
    },
    {
        aliases = {"generateAirDefenseGroup-BLUE-4"},
        hidden = true,
        group = {
            disposition = { h= 7, w= 7},
            units = {
                -- Roland battery
                {"Roland Radar", random=true}, {"Roland ADS", random=true, hdg = 0}, {"Roland ADS", random=true, hdg = 225}, {"Roland ADS", random=true, hdg = 135},
                -- Some M48 Chaparral
                {"M48 Chaparral", number = {min=2, max=4}, random=true},
                -- Some Gepards
                {"Gepard", number = {min=2, max=4}, random=true},
                -- a supply truck or three
                {"M 818", number = {min=1, max=3}, random=true}
            },
            description = "generateAirDefenseGroup-BLUE-4",
            groupName = "generateAirDefenseGroup-BLUE-4",
        },
    },
    {
        aliases = {"generateAirDefenseGroup-BLUE-3"},
        hidden = true,
        group = {
            disposition = { h= 7, w= 7},
            units = {
                -- Some Gepards
                {"Gepard", number = {min=2, max=4}, random=true},
                -- M6 Linebacker battery
                {"M6 Linebacker", hdg = 0, random=true}, {"M6 Linebacker", hdg = 90, random=true}, {"M6 Linebacker", hdg = 180, random=true}, {"M6 Linebacker", hdg = 270, random=true},
                -- Some M1097 Avenger
                {"M1097 Avenger", number = {min=2, max=4}, random=true},
                -- a supply truck or three
                {"M 818", number = {min=1, max=3}, random=true}
            },
            description = "generateAirDefenseGroup-BLUE-3",
            groupName = "generateAirDefenseGroup-BLUE-3",
        },
    },
    {
        aliases = {"generateAirDefenseGroup-BLUE-2"},
        hidden = true,
        group = {
            disposition = { h= 7, w= 7},
            units = {
                -- Some Vulcans
                {"Vulcan", number = {min=2, max=4}, random=true},
                -- Some M1097 Avenger
                {"M1097 Avenger", number = {min=2, max=4}, random=true},
                -- a supply truck or three
                {"M 818", number = {min=1, max=3}, random=true}
            },
            description = "generateAirDefenseGroup-BLUE-2",
            groupName = "generateAirDefenseGroup-BLUE-2",
        },
    },
    {
        aliases = {"generateAirDefenseGroup-BLUE-1"},
        hidden = true,
        group = {
            disposition = { h= 7, w= 7},
            units = {
                -- Some Vulcans
                {"Vulcan", number = {min=1, max=3}, random=true},
                -- Some M1097 Avenger
                {"M1097 Avenger", number = {min=0, max=1}, random=true},
                -- a supply truck or three
                {"M 818", number = {min=1, max=3}, random=true}
            },
            description = "generateAirDefenseGroup-BLUE-1",
            groupName = "generateAirDefenseGroup-BLUE-1",
        },
    },
    {
        aliases = {"generateAirDefenseGroup-BLUE-0"},
        hidden = true,
        group = {
            disposition = { h= 7, w= 7},
            units = {
                -- Some AAV7
                {"AAV7", number = {min=1, max=3}, random=true},
                -- a supply truck or three
                {"M 818", number = {min=1, max=3}, random=true}
            },
            description = "generateAirDefenseGroup-BLUE-0",
            groupName = "generateAirDefenseGroup-BLUE-0",
        },
    },
    {
        aliases = {"generateAirDefenseGroup-RED-5"},
        hidden = true,
        group = {
            disposition = { h= 7, w= 7},
            units = {
                -- the search radar
                {"Dog Ear radar", random=true},
                -- Tor battery
                {"Tor 9A331", hdg = 180, number = 1, random=true},
                -- SA-8 battery                
                {"Osa 9A33 ln", number = {min=1, max=2}, random=true},
                -- Some SA13
                {"Strela-10M3", number = {min=1, max=2}, random=true},
                -- Some Tunguskas
                {"2S6 Tunguska", number = {min=1, max=2}, random=true},
                -- Some ZU-57-2
                {"ZSU_57_2", number = 1, random=true},
                -- Some S-60
                {"S-60_Type59_Artillery", number = 1, random=true},
                -- a supply truck or three
                {"Ural-4320-31", number = {min=1, max=3}, random=true}
            },
            description = "generateAirDefenseGroup-RED-5",
            groupName = "generateAirDefenseGroup-RED-5",
        },
    },
    {
        aliases = {"generateAirDefenseGroup-RED-4"},
        hidden = true,
        group = {
            disposition = { h= 7, w= 7},
            units = {
                -- the search radar
                {"Dog Ear radar", random=true},
                -- SA-8 battery                
                {"Osa 9A33 ln", number = {min=1, max=2}, random=true},
                -- Some SA13
                {"Strela-10M3", number = {min=1, max=2}, random=true},
                -- Some Shilkas
                {"ZSU-23-4 Shilka", number = {min=1, max=2}, random=true},
                -- Some ZU-57-2
                {"ZSU_57_2", number = {min=1, max=1}, random=true},
                -- Some S-60
                {"S-60_Type59_Artillery", number = {min=0, max=1}, random=true},
                -- a supply truck or three
                {"Ural-4320-31", number = {min=1, max=3}, random=true}
            },
            description = "generateAirDefenseGroup-RED-4",
            groupName = "generateAirDefenseGroup-RED-4",
        },
    },
    {
        aliases = {"generateAirDefenseGroup-RED-3"},
        hidden = true,
        group = {
            disposition = { h= 7, w= 7},
            units = {
                -- the search radar
                {"Dog Ear radar", random=true},
                -- SA13 battery
                {"Strela-10M3", number = {min=1, max=2}, random=true},
                -- Some SA9
                {"Strela-1 9P31", number = {min=1, max=2}, random=true},
                -- Some Shilkas
                {"ZSU-23-4 Shilka", number = {min=1, max=2}, random=true},
                -- Some ZU-57-2
                {"ZSU_57_2", number = {min=0, max=1}, random=true},
                -- Some S-60
                {"S-60_Type59_Artillery", number = {min=0, max=1}, random=true},
                -- a supply truck or three
                {"Ural-4320-31", number = {min=1, max=3}, random=true}
            },
            description = "generateAirDefenseGroup-RED-3",
            groupName = "generateAirDefenseGroup-RED-3",
        },
    },
    {
        aliases = {"generateAirDefenseGroup-RED-2"},
        hidden = true,
        group = {
            disposition = { h= 7, w= 7},
            units = {
                -- the search radar
                {"Dog Ear radar", random=true},
                -- SA9 battery
                {"Strela-1 9P31", number = {min=1, max=2}, random=true},
                -- Some Shilkas
                {"ZSU-23-4 Shilka", number = {min=1, max=2}, random=true},
                -- Some ZU-57-2
                {"ZSU_57_2", number = {min=0, max=1}, random=true},
                -- Some S-60
                {"S-60_Type59_Artillery", number = {min=0, max=1}, random=true},
                -- a supply truck or three
                {"Ural-4320-31", number = {min=1, max=3}, random=true}
            },
            description = "generateAirDefenseGroup-RED-2",
            groupName = "generateAirDefenseGroup-RED-2",
        },
    },
    {
        aliases = {"generateAirDefenseGroup-RED-1"},
        hidden = true,
        group = {
            disposition = { h= 7, w= 7},
            units = {
                -- the search radar
                {"Dog Ear radar", random=true},
                -- Some Shilkas
                {"ZSU-23-4 Shilka", number = {min=1, max=2}, random=true},
                -- Some ZU-57-2
                {"ZSU_57_2", number = {min=0, max=1}, random=true},
                -- a supply truck or three
                {"Ural-4320-31", number = {min=1, max=3}, random=true}
            },
            description = "generateAirDefenseGroup-RED-1",
            groupName = "generateAirDefenseGroup-RED-1",
        },
    },
    {
        aliases = {"generateAirDefenseGroup-RED-0"},
        hidden = true,
        group = {
            disposition = { h= 7, w= 7},
            units = {
                -- Some Ural-375 ZU-23
                {"Ural-375 ZU-23", number = {min=0, max=1}, random=true},
                -- Some S-60
                {"S-60_Type59_Artillery", number = {min=0, max=1}, random=true},
                -- a supply truck or three
                {"Ural-4320-31", number = {min=1, max=3}, random=true}
            },
            description = "generateAirDefenseGroup-RED-0",
            groupName = "generateAirDefenseGroup-RED-0",
        },
    },
    ---
    --- Seemingly realistic russian air defense batteries
    ---
    {
        aliases = {"RU-SAM-Shilka-Battery", "shilka-battery"},
        group = {
            disposition = { h= 5, w= 5},
            units = {
                -- the search radar
                {"Dog Ear radar", cell = 13},
                -- the actual air defense units
                {"ZSU-23-4 Shilka", hdg = 0, random=true}, {"ZSU-23-4 Shilka", hdg = 90, random=true}, {"ZSU-23-4 Shilka", hdg = 180, random=true}, {"ZSU-23-4 Shilka", hdg = 270, random=true},
                -- a supply truck or three
                {"Ural-4320-31", number = {min=1, max=3}, random=true},
            },
            description = "ZSU-23-4 battery",
            groupName = "ZSU-23-4 battery"
        },
    },
    {
        aliases = {"RU-SAM-S60-Battery", "s60-battery"},
        group = {
            disposition = { h= 5, w= 5},
            units = {
                -- the search radar
                {"Dog Ear radar", cell = 13},
                -- the actual air defense units
                {"S-60_Type59_Artillery", hdg = 0, random=true}, {"S-60_Type59_Artillery", hdg = 90, random=true}, {"S-60_Type59_Artillery", hdg = 180, random=true}, {"S-60_Type59_Artillery", hdg = 270, random=true},
                -- a supply truck or three
                {"Ural-4320-31", number = {min=1, max=3}, random=true}
            },
            description = "S-60 battery",
            groupName = "S-60 battery"
        },
    },
    {
        aliases = {"RU-SAM-SA9-Battery", "sa9-battery"},
        group = {
            disposition = { h= 5, w= 5},
            units = {
                -- the search radar
                {"Dog Ear radar", cell = 13},
                -- the actual air defense units
                {"Strela-1 9P31", hdg = 0, random=true}, {"Strela-1 9P31", hdg = 90, random=true}, {"Strela-1 9P31", hdg = 180, random=true}, {"Strela-1 9P31", hdg = 270, random=true},
                -- a supply truck or three
                {"Ural-4320-31", number = {min=1, max=3}, random=true}
            },
            description = "SA-9 battery",
            groupName = "SA-9 battery"
        },
    },
    {
        aliases = {"RU-SAM-SA13-Battery", "sa13-battery"},
        group = {
            disposition = { h= 5, w= 5},
            units = {
                -- the search radar
                {"Dog Ear radar", cell = 13},
                -- the actual air defense units
                {"Strela-10M3", hdg = 0, random=true}, {"Strela-10M3", hdg = 90, random=true}, {"Strela-10M3", hdg = 180, random=true}, {"Strela-10M3", hdg = 270, random=true},
                -- a supply truck or three
                {"Ural-4320-31", number = {min=1, max=3}, random=true},
            },
            description = "SA-13 battery",
            groupName = "SA-13 battery"
        },
    },
}

veaf.loggers.get(veafUnits.Id):info(string.format("Loading version %s", veafUnits.Version))

if veafUnits.OutputListsForDocumentation then
    veafUnits.logGroupsListInMarkdown()
    veafUnits.logUnitsListInMarkdown()
end