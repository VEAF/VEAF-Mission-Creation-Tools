-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF groups and units database for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- Contains all the units aliases and groups definitions used by the other VEAF scripts
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires the veaf.lua base script library (version 1.0 or higher)
-- * It also requires the dcsUnits.lua script library (version 1.0 or higher)
--
-- Load the script:
-- ----------------
-- 1.) Download the script and save it anywhere on your hard drive.
-- 2.) Open your mission in the mission editor.
-- 3.) Add a new trigger:
--     * TYPE   "4 MISSION START"
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of MIST and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of veaf.lua and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of dcsUnits.lua and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location where you saved the script and click OK.
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafUnits = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the root VEAF constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafUnits.Id = "UNITS - "

--- Version.
veafUnits.Version = "1.3.2"

-- trace level, specific to this module
veafUnits.Trace = false

--- If no unit is spawned in a cell, it will default to this width
veafUnits.DefaultCellWidth = 10

--- If no unit is spawned in a cell, it will default to this height
veafUnits.DefaultCellHeight = 10

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafUnits.logInfo(message)
    if message then
        veaf.logInfo(veafUnits.Id .. message)
    end
end

function veafUnits.logDebug(message)
    if message then
        veaf.logDebug(veafUnits.Id .. message)
    end
end

function veafUnits.logTrace(message)
    if message and veafUnits.Trace then
        veaf.logTrace(veafUnits.Id .. message)
    end
end

function veafUnits.traceGroup(group, cells)
    if group and veafUnits.Trace then
        veafUnits.logTrace("")
        veafUnits.logTrace(" Group : " .. group.description)
        veafUnits.logTrace("")
        local nCols = group.disposition.w
        local nRows = group.disposition.h
        
        local line1 = "|    |" 
        local line2 = "|----|" 
        
        for nCol = 1, nCols do
            line1 = line1 .. "                ".. string.format("%02d", nCol) .."              |" 
            line2 = line2 .. "--------------------------------|"
        end
        veafUnits.logTrace(line1)
        veafUnits.logTrace(line2)

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
            veafUnits.logTrace(line1)
            veafUnits.logTrace(line2)
            veafUnits.logTrace(line3)
            veafUnits.logTrace(line4)
        end
    end
end

function veafUnits.debugUnit(unit)
    if unit and veafUnits.Trace then 
        local airnaval = ""
        if unit.naval then
            airnaval = ", naval"
        elseif unit.air then
            airnaval = ", air"
        end
        
        veafUnits.logDebug("unit " .. unit.displayName .. ", dcsType=" .. unit.typeName .. airnaval .. ", size = { width =" .. unit.width .. ", length="..unit.length.."}")
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
                local unit = veafUnits.findUnit(typeName, true)
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
    veafUnits.logTrace("veafUnits.findDcsUnit(unitType=" .. unitType .. ")")

    -- find the desired unit in the DCS units database
    local unit = nil
    for dcsType, u in pairs(dcsUnits.DcsUnitsDatabase) do
        local hasDesc = u.desc
        if      (dcsType and unitType:lower() == dcsType:lower())
            or  (u and u.desc and u.desc.displayName and unitType:lower() == u.desc.displayName:lower())
            or  (u and u.desc and u.desc.typeName and unitType:lower() == u.desc.typeName:lower()) 
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
    local unitNumber = 1
    -- replace all units with a simplified structure made from the DCS unit metadata structure
    for i = 1, #group.units do
        local unitType
        local cell = nil
        local number = nil
        local size = nil
        local hdg = nil
        local random = false
        local u = group.units[i]
        if type(u) == "string" then 
            -- information was skipped using simplified syntax
            unitType = u
        else
            unitType = u[1]
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
            hdg = 0 -- north is the default heading
          end
        for numUnit = 1, number do
            local unit = veafUnits.findUnit(unitType)
            if not(unit) then 
                veafUnits.logInfo("cannot find unit [" .. unitType .. "] listed in group [" .. group.groupName .. "]")
            else 
                unit.cell = cell
                unit.hdg = hdg
                unit.random = random
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
    
    return result
end


--- searches the database for a group having this alias (case insensitive)
function veafUnits.findGroup(groupAlias)
    veafUnits.logTrace("veafUnits.findGroup(groupAlias=" .. groupAlias .. ")")

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
function veafUnits.findUnit(unitAlias, nolog)
    if not(nolog) then veafUnits.logTrace("veafUnits.findUnit(unitAlias=" .. unitAlias .. ")") end
    
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
        veafUnits.logInfo("cannot find unit [" .. unitAlias .. "]")
    else
        unit = veafUnits.makeUnitFromDcsStructure(unit, cell)
    end
    
    return unit
end

--- Creates a simple structure from DCS complex metadata structure
function veafUnits.makeUnitFromDcsStructure(dcsUnit, cell)
    local result = {}
    if not(dcsUnit) then 
        return nil 
    end

    result.typeName = dcsUnit.desc.typeName
    result.displayName = dcsUnit.desc.displayName
    result.naval = (dcsUnit.desc.attributes.Ships == true)
    result.air = (dcsUnit.desc.attributes.Air == true)
    result.infantry = (dcsUnit.desc.attributes.Infantry == true)
    result.vehicle = (dcsUnit.desc.attributes.Vehicles == true)
    result.size = { x = veaf.round(dcsUnit.desc.box.max.x - dcsUnit.desc.box.min.x, 1), y = veaf.round(dcsUnit.desc.box.max.y - dcsUnit.desc.box.min.y, 1), z = veaf.round(dcsUnit.desc.box.max.z - dcsUnit.desc.box.min.z, 1)}
    result.width = result.size.z
    result.length= result.size.x
    -- invert if width > height
    if result.width > result.length then
        local width = result.width
        result.width = result.length
        result.length = width
    end
    result.cell = cell

    return result
end

--- checks if position is correct for the unit type
function veafUnits.checkPositionForUnit(spawnPosition, unit)
    veafUnits.logTrace("checkPositionForUnit()")
    veafUnits.logTrace(string.format("checkPositionForUnit: spawnPosition=", veaf.vecToString(spawnPosition)))
    local vec2 = { x = spawnPosition.x, y = spawnPosition.z }
    veafUnits.logTrace(string.format("checkPositionForUnit: vec2=", veaf.vecToString(vec2)))
    local landType = land.getSurfaceType(vec2)
    if landType == land.SurfaceType.WATER then
        veafUnits.logTrace("landType = WATER")
    else
        veafUnits.logTrace("landType = GROUND")
    end
    veafUnits.debugUnit(unit)
    if spawnPosition then
        if unit.air then -- if the unit is a plane or helicopter
            if spawnPosition.z <= 10 then -- if lower than 10m don't spawn unit
                return false
            end
        elseif unit.naval then -- if the unit is a naval unit
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
function veafUnits.placeGroup(group, spawnPoint, spacing, hdg)
    if not(hdg) then
        hdg = 0 -- default north
    end

    if not(group.disposition) then 
        -- default disposition is a square
        local l = math.ceil(math.sqrt(#group.units))
        group.disposition = { h = l, w = l}
    end 

    local nRows = group.disposition.h
    local nCols = group.disposition.w

    -- sort the units by occupied cell
    local fixedUnits = {}
    local freeUnits = {}
    for _, unit in pairs(group.units) do
        if unit.cell then
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
                end
                if unit.size then
                    cell.width = unit.size.width + (spacing * unit.size.width)
                    cell.height = unit.size.height + (spacing * unit.size.height)
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
    veafUnits.logTrace(string.format("totalWidth = %d",totalWidth))
    veafUnits.logTrace(string.format("totalHeight = %d",totalHeight))
    -- place the grid
    local currentColLeft = spawnPoint.z - totalWidth/2
    local currentColTop = spawnPoint.x - totalHeight/2
    for nCol = 1, #cols do
        veafUnits.logTrace(string.format("currentColLeft = %d",currentColLeft))
        cols[nCol].left = currentColLeft
        cols[nCol].right= currentColLeft + cols[nCol].width
        currentColLeft = cols[nCol].right
    end
    for nRow = 1, #rows do -- bottom -> up
        veafUnits.logTrace(string.format("currentColTop = %d",currentColTop))
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
                cell.center.x = cell.left + (cell.right - cell.left) / 2
                cell.center.y = cell.top + (cell.bottom - cell.top) / 2
            end            
        end
    end
    
    -- randomly place the units
    for _, cell in pairs(cells) do
        local unit = cell.unit
        if unit then
            unit.spawnPoint = {}
            unit.spawnPoint.z = cell.center.x
            if unit.random and spacing > 0 then
                unit.spawnPoint.z = unit.spawnPoint.z + math.random(-((spacing-1) * unit.width)/2, ((spacing-1) * unit.width)/2)
            end
            unit.spawnPoint.x = cell.center.y
            if unit.random and spacing > 0 then
                unit.spawnPoint.x = unit.spawnPoint.x + math.random(-((spacing-1) * unit.length)/2, ((spacing-1) * unit.length)/2)
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

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Units databases
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafUnits.UnitsDatabase = {
    {
        aliases = {"sa9", "sa-9"},
        unitType = "Strela-1 9P31"
    },
    {
        aliases = {"sa13", "sa-13"},
        unitType = "Strela-10M3",
    },
    {
        aliases = {"sa6", "sa-6"},
        unitType = "Kub 2P25 ln",
    },
    {
        aliases = {"sa8", "sa-8"},
        unitType = "Osa 9A33 ln",
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
        aliases = {"shilka"},
        unitType = "ZSU-23-4 Shilka",
    },
    {
        aliases = {"tarawa"},
        unitType = "LHA_Tarawa",
    }
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
-- description = human-friendly name for the group
-- groupName   = name used when spawning this group (will be flavored with a numerical suffix)
--
-- empty cells measure 10m x 10m

veafUnits.GroupsDatabase = {
        {
        aliases = {"sa2", "sa-2", "fs"},
        group = {
            disposition = { h= 6, w= 8},
            units = {{"SNR_75V", cell = 20}, {"p-19 s-125 sr", cell = 48}, {"S_75M_Volhov", cell = 2, hdg = 315}, {"S_75M_Volhov", cell = 6, hdg = 45}, {"S_75M_Volhov", cell = 17, hdg = 270}, {"S_75M_Volhov", cell = 24, hdg = 90}, {"S_75M_Volhov", cell = 34, hdg = 225}, {"S_75M_Volhov", cell = 38, hdg = 135}},
            description = "SA-2 SAM site",
            groupName = "SA2"
        },
    },
    {
        aliases = {"rapier_optical", "rpo"},
        group = {
            disposition = { h= 3, w= 5},
            units = {{"rapier_fsa_optical_tracker_unit", cell = 13}, {"rapier_fsa_launcher", cell = 1}, {"rapier_fsa_launcher", cell = 5}},
            description = "Rapier SAM site",
            groupName = "Rapier"
        },
    }, 
    {
        aliases = {"rapier_radar", "rpr"},
        group = {
            disposition = { h= 5, w= 5},
            units = {{"rapier_fsa_optical_tracker_unit", cell = 13}, {"rapier_fsa_launcher", cell = 1}, {"rapier_fsa_launcher", cell = 5}, {"rapier_fsa_blindfire_radar", cell = 23}},
            description = "Rapier SAM site with radar",
            groupName = "Rapier-radar"
        },
    }, 
    {
        aliases = {"sa3", "sa-3", "lb"},
        group = {
            disposition = { h= 7, w= 9},
            units = {{"p-19 s-125 sr", cell = 1}, {"snr s-125 tr", cell = 33}, {"5p73 s-125 ln", cell = 18}, {"5p73 s-125 ln", cell = 30}, {"5p73 s-125 ln", cell = 61}},
            description = "SA-3 SAM site",
            groupName = "SA3"
        },
    },
    {
        aliases = {"sa6", "sa-6", "06"},
        group = {
            disposition = { h= 7, w= 7},
            units = {{"Kub 1S91 str", cell = 25}, {"Kub 2P25 ln", cell = 4, hdg = 180}, {"Kub 2P25 ln", cell = 22, hdg = 90}, {"Kub 2P25 ln", cell = 28, hdg = 270}, {"Kub 2P25 ln", cell = 46, hdg = 0},
            {"Fuel Truck ATZ-10", number = 2, random},
            {"GPU APA-80 on ZiL-131", number = 1, random},
            {"Transport Ural-4320-31 Armored", number = 2, random},
            {"CP Ural-375 PBU", number = 1, random},
            },
            description = "SA-6 SAM site",
            groupName = "SA6"
        },
    },
    {
        aliases = {"sa11", "sa-11", "sd"},
        group = {
            disposition = { h= 9, w= 9},
            units = {{"SA-11 Buk SR 9S18M1", cell = 42}, {"SA-11 Buk CC 9S470M1", cell = 39}, {"SA-11 Buk LN 9A310M1", cell = 1}, {"SA-11 Buk LN 9A310M1", cell = 5}, {"SA-11 Buk LN 9A310M1", cell = 9}, {"SA-11 Buk LN 9A310M1", cell = 72}, {"SA-11 Buk LN 9A310M1", cell = 76}, {"SA-11 Buk LN 9A310M1", cell = 81}},
            description = "SA-11 SAM site",
            groupName = "SA11"
        },
    },
    {
        aliases = {"sa10", "s300", "bb"},
        group = {
            disposition = { h= 10, w= 13},
            units = {{"S-300PS 40B6M tr", cell = 7}, {"S-300PS 5P85C ln", cell = 29}, {"S-300PS 5P85D ln", cell = 37}, {"S-300PS 5P85D ln", cell = 43}, {"S-300PS 5P85C ln", cell = 49}, {"S-300PS 5P85C ln", cell = 57}, {"S-300PS 5P85D ln", cell = 61}, {"S-300PS 5P85D ln", cell = 71}, {"S-300PS 5P85C ln", cell = 73}, {"S-300PS 64H6E sr", cell = 98}, {"S-300PS 54K6 cp", cell = 118}, {"S-300PS 40B6MD sr", cell = 130}},
            description = "S300 SAM site",
            groupName = "S300"
        },
    },   
    {
        aliases = {"infantry section", "infsec"},
        group = {
            disposition = { h= 10, w= 4},
            units = {{"IFV BTR-80", cell=38, random},{"IFV BTR-80", cell=39, random},{"INF Soldier AK", number = {min=12, max=30}, random}, {"SA-18 Igla manpad", number = {min=0, max=2}, random}},
            description = "Mechanized infantry section with APCs",
            groupName = "Mechanized infantry section"
        },
    },
    {
        aliases = {"roland", "rd", "mim-115"},
        group = {
            disposition = { h= 3, w= 3},
            units = {{"Roland Radar", cell = 8}, {"Roland ADS", cell = 1}, {"Roland ADS", cell = 3}},
            description = "Roland SAM site",
            groupName = "Roland"
        },
    },
    {
        aliases = {"hawk", "ha", "mim-23"},
        group = {
            disposition = { h= 7, w= 3},
            units = {{"Hawk pcp", cell = 8}, {"Hawk sr", cell = 13}, {"Hawk tr", cell = 15}, {"Hawk ln", cell = 1}, {"Hawk ln", cell = 3}, {"Hawk ln", cell = 21}},
            description = "Hawk SAM site",
            groupName = "Hawk"
        },
    },
    {
        aliases = {"patriot", "pa", "mim-104"},
        group = {
            disposition = { h= 7, w= 4},
            units = {{"Patriot ln", cell = 1}, {"Patriot cp", cell = 8}, {"Patriot str", cell = 10}, {"Patriot AMG", cell = 19}, {"Patriot ECS", cell = 25}, {"Patriot EPP", cell = 28}},
            description = "Patriot SAM site",
            groupName = "Patriot"
        },
    },
    {
        aliases = {"Tarawa"},
        group = {
            disposition = { h = 3, w = 3},
            units = {{"Tarawa", cell=2}, {"Perry", cell=4}, {"Perry", cell=6}, {"TICONDEROG", cell=8}},
            description = "Tarawa battle group",
            groupName = "Tarawa",
        },
    },  
    {
        aliases = {"Test"},
        group = {
            disposition = { h = 3, w = 3},
            units = {{"S_75M_Volhov", cell=2, size={height=15, width=15}, hdg=0},{"S_75M_Volhov", cell=4, size=15, hdg=270},{"S_75M_Volhov", cell=6, size=15, hdg=90},{"S_75M_Volhov", cell=8, size=15, hdg=180}},
            description = "Test group",
            groupName = "Test",
        },
    },
    {
        aliases = {"US infgroup"},
        group = {
            disposition = { h = 5, w = 5},
            units = {{"IFV Hummer", number = {min=1, max=2}, random},{"INF Soldier M249", number = {min=1, max=2}, random},{"INF Soldier M4 GRG", number = {min=2, max=4}, random},{"INF Soldier M4", number = {min=6, max=15}, random}},
            description = "US infantry group",
            groupName = "US infantry group",
        },
    },
    {
        aliases = {"US supply convoy","blueconvoy"},
        group = {
            disposition = { h = 20, w = 20},
            units = {
                {"IFV Hummer", number = {min=2, max=4}, random},
                {"Truck M 818", number = {min=3, max=6}, random},
                {"Truck M978 HEMTT Tanker", number = {min=0, max=3}, random},
                {"Truck Predator GCS", number = {min=0, max=2}, random},
                {"Truck Predator TrojanSpirit", number = {min=0, max=2}, random},
            },
            description = "US infantry group",
            groupName = "US infantry group",
        },
    },
    {
        aliases = {"RU supply convoy with defense","redconvoy-def"},
        group = {
            disposition = { h = 20, w = 20},
            units = {
                {"2S6 Tunguska", number = {min=0, max=1}, random},
                {"Strela-10M3", number = {min=0, max=1}, random},
                {"Strela-1 9P31", number = {min=0, max=1}, random},
                {"ZSU-23-4 Shilka", number = {min=0, max=2}, random},
                {"Ural-375 ZU-23", number = {min=0, max=2}, random},
                {"UAZ-469", number = {min=2, max=4}, random},
                {"Truck SKP-11", number = {min=1, max=3}, random},
                {"Truck Ural-375 PBU", number = {min=1, max=3}, random},
                {"Truck Ural-375", number = {min=1, max=3}, random},
                {"Truck Ural-4320 APA-5D", number = {min=1, max=3}, random},
                {"Truck Ural-4320-31", number = {min=1, max=3}, random},
                {"Truck Ural-4320T", number = {min=1, max=3}, random},
                {"Truck ZiL-131 APA-80", number = {min=1, max=3}, random},
                {"Truck ZIL-131 KUNG", number = {min=1, max=3}, random},
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
                {"ZSU-23-4 Shilka", number = {min=0, max=2}, random},
                {"Ural-375 ZU-23", number = {min=0, max=2}, random},
                {"UAZ-469", number = {min=2, max=4}, random},
                {"Truck SKP-11", number = {min=1, max=3}, random},
                {"Truck Ural-375 PBU", number = {min=1, max=3}, random},
                {"Truck Ural-375", number = {min=1, max=3}, random},
                {"Truck Ural-4320 APA-5D", number = {min=1, max=3}, random},
                {"Truck Ural-4320-31", number = {min=1, max=3}, random},
                {"Truck Ural-4320T", number = {min=1, max=3}, random},
                {"Truck ZiL-131 APA-80", number = {min=1, max=3}, random},
                {"Truck ZIL-131 KUNG", number = {min=1, max=3}, random},
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
                {"UAZ-469", number = {min=2, max=4}, random},
                {"Truck SKP-11", number = {min=1, max=3}, random},
                {"Truck Ural-375 PBU", number = {min=1, max=3}, random},
                {"Truck Ural-375", number = {min=1, max=3}, random},
                {"Truck Ural-4320 APA-5D", number = {min=1, max=3}, random},
                {"Truck Ural-4320-31", number = {min=1, max=3}, random},
                {"Truck Ural-4320T", number = {min=1, max=3}, random},
                {"Truck ZiL-131 APA-80", number = {min=1, max=3}, random},
                {"Truck ZIL-131 KUNG", number = {min=1, max=3}, random},
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
                {"2S6 Tunguska", number = {min=0, max=1}, random},
                {"Strela-10M3", number = {min=0, max=1}, random},
                {"Strela-1 9P31", number = {min=0, max=1}, random},
                {"ZSU-23-4 Shilka", number = {min=0, max=2}, random},
                {"Ural-375 ZU-23", number = {min=0, max=2}, random},
                {"UAZ-469", number = {min=1, max=2}, random},
                {"Truck SKP-11", number = {min=1, max=2}, random},
                {"Truck Ural-375 PBU", number = {min=0, max=2}, random},
                {"Truck Ural-375", number = {min=0, max=2}, random},
                {"Truck Ural-4320 APA-5D", number = {min=0, max=2}, random},
                {"Truck Ural-4320-31", number = {min=0, max=2}, random},
                {"Truck Ural-4320T", number = {min=0, max=2}, random},
                {"Truck ZiL-131 APA-80", number = {min=0, max=2}, random},
                {"Truck ZIL-131 KUNG", number = {min=0, max=2}, random},
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
                {"ZSU-23-4 Shilka", number = {min=0, max=2}, random},
                {"Ural-375 ZU-23", number = {min=0, max=2}, random},
                {"UAZ-469", number = {min=1, max=2}, random},
                {"Truck SKP-11", number = {min=1, max=2}, random},
                {"Truck Ural-375 PBU", number = {min=0, max=2}, random},
                {"Truck Ural-375", number = {min=0, max=2}, random},
                {"Truck Ural-4320 APA-5D", number = {min=0, max=2}, random},
                {"Truck Ural-4320-31", number = {min=0, max=2}, random},
                {"Truck Ural-4320T", number = {min=0, max=2}, random},
                {"Truck ZiL-131 APA-80", number = {min=0, max=2}, random},
                {"Truck ZIL-131 KUNG", number = {min=0, max=2}, random},
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
                {"UAZ-469", number = {min=1, max=2}, random},
                {"Truck SKP-11", number = {min=1, max=2}, random},
                {"Truck Ural-375 PBU", number = {min=0, max=2}, random},
                {"Truck Ural-375", number = {min=0, max=2}, random},
                {"Truck Ural-4320 APA-5D", number = {min=0, max=2}, random},
                {"Truck Ural-4320-31", number = {min=0, max=2}, random},
                {"Truck Ural-4320T", number = {min=0, max=2}, random},
                {"Truck ZiL-131 APA-80", number = {min=0, max=2}, random},
                {"Truck ZIL-131 KUNG", number = {min=0, max=2}, random},
            },
            description = "RU small supply convoy with no defense",
            groupName = "RU small supply convoy with no defense",
        },
    },
}

veafUnits.logInfo(string.format("Loading version %s", veafUnits.Version))
