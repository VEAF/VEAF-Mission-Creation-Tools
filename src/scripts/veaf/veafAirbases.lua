------------------------------------------------------------------
-- VEAF airbases information
-- By Flogas (2024)
--
-- Features:
-- ---------
-- * Extraction and normalization of airbase an runway data from DCS APIs
------------------------------------------------------------------
veafAirbases = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global module settings
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafAirbases.Id = "AIRBASES"

--- Version.
veafAirbases.Version = "1.0.0"

-- trace level, specific to this module
--veafAirbases.LogLevel = "trace"
veaf.loggers.new(veafAirbases.Id, veafAirbases.LogLevel)

veafAirbases.Airbases = nil

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------
local _manualRunwayNumberCorrections =
{
    -- Syria --
    ["Beirut-Rafic Hariri"] = { [34] = 3, [168] = 16 }, -- Correct RWYs: 17/35, 03/21, 16/34 ; API gives: RWY17 for 178° (ok), RWY35 for 034°, RWY03 for 168°
    ["Khalkhalah"] = { [151] = 15, [76] = 7 }, -- Correct RWYs: 15/33, 07/25 ; API gives: RWY03 for 151°, RWY03 for 076° ; note: runways have no painted numbers, 15/33 in DCS F10 airport window
    ["Minakh"] = { [42] = -1}, -- Correct RWY: 10/28 ; API gives: RWY10 for 101° (ok), RWY28 for 042° ; note: runway oriented to 042° is closed
    ["Ramat David"] = { [110] = 11, [88] = 9 }, -- Correct RWYs: 15/33, 11/29, 09/27 ; API gives: RWY15 for 146° (ok), RWY33 for 110°, RWY11 for 088°
    ["Nicosia"] = { [91] = 9 }, -- Correct RWYs: 14/32, 09/27 ; API gives: RWY32 for 328° (ok), RWY14 for 091°
    ["H3"] = { [64] = 6 }, -- Correct RWYs: 11/29, 06/24 ; API gives: RWY11 for 111° (ok), RWY29 for 064°
    ["Muwaffaq Salti"] = { [312] = 31 }, -- Correct RWYs: 08/26, 13/31 ; API gives: RWY26 for 261° (ok), RWY08 for 312°
    ["Tel Nof"] = { [184] = 18, [332] = 33 }, -- Correct RWYs: 15/33(2), 18/36 ; API gives: RWY33 for 332° (ok), RWY15 for 184°, RWY18 for 332°
    ["Ben Gurion"] = { [210] = 21, [262] = 26 }, -- Correct RWYs: 12/30, 03/21, 08/26 ; API gives: RWY12 for 123° (ok), RWY30 for 210°, RWY21 for 262°
    ["Hatzor"] = { [113] = 11 }, -- Correct RWYs: 05/23, 11/29(2) ; API gives: RWY23 for 236° (ok), RWY05 for 113°, RWY11 for 293° (ok)
    -- Nevada --
    ["Creech"] = { [145] = 13 }, -- Correct RWYs: 08/26, 13/31 ; API gives: RWY08 for 091° (ok), RWY26 for 145°
    ["Boulder City"] = { [278] = 27 }, -- Correct RWYs: 15/33, 09/27 ; API gives: RWY33 for 344° (ok), RWY15 for 278°
    ["North Las Vegas"] = { [313] = 30 }, -- Correct RWYs: 07/25, 12/30(2) ; API gives: RWY25 for 267° (ok), RWY07 for 313°, RWY30 for 133° (ok)
    ["Tonopah"] = { [345] = 33 }, -- Correct RWYs: 11/29, 15/33 ; API gives: RWY29 for 305° (ok), RWY11 for 345°
}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
---  Static methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafAirbases.initialize(bReset)
    bReset = bReset or false
    
    if (bReset) then
        veafAirbases.Airbases = nil
    end

    if (veafAirbases.Airbases) then
        return
    end

    veafAirbases.Airbases = {}

    local dcsAirBases = world.getAirbases()
    for i = 1, #dcsAirBases do
        local dcsAirbase = dcsAirBases[i]
--[[
        local s = string.format("%s  %s  %s  %s",
        veaf.p(dcsAirbase:getCallsign()), veaf.p(dcsAirbase:getUnit()), veaf.p(dcsAirbase:getID()), veaf.p(dcsAirbase:getCategoryEx())
        )
        veaf.loggers.get(veafAirbases.Id):trace(s)
        veaf.loggers.get(veafAirbases.Id):trace(veaf.p(dcsAirbase:getDesc()))
]]
        local veafAirbase = veafAirbase:create(dcsAirbase)
        if (veafAirbase) then
            table.insert(veafAirbases.Airbases, veafAirbase)
        end
    end
end

function veafAirbases.getAirbaseByName(sAirbaseName)
    veafAirbases.initialize()
    
    for _, veafAirbase in pairs(veafAirbases.Airbases) do
        if (veafAirbase.Name == sAirbaseName) then
            return veafAirbase
        end
    end

    return nil
end

function veafAirbases.getAirbaseFromDcsAirbase(dcsAirbase)
    if (dcsAirbase == nil) then
        return nil
    end

    return veafAirbases.getAirbaseByName(dcsAirbase:getName())
end

function veafAirbases.getNearestAirbaseList(dcsUnit, iCount)
    veafAirbases.initialize()
    
    iCount = iCount or 1
    local vec3Unit = dcsUnit:getPoint()
    local iMinDistance = nil
    local nearestList = {}

    local function Sort(a, b)
        if (a == nil and b == nil) then
            return false
        elseif (a == nil) then
            return false
        elseif (b == nil) then
            return true
        else
            return a[2] < b[2]
        end
    end

    for _, veafAirbase in pairs(veafAirbases.Airbases) do
        local vec3Airbase = veafAirbase.DcsAirbase:getPoint()
        local iDistance = mist.utils.get2DDist(vec3Unit, vec3Airbase)
        local bAdded = false

        -- first fill all the nil positions
        for i = 1, iCount, 1 do
            if (nearestList[i] == nil) then
                nearestList[i] = { veafAirbase, iDistance }
                bAdded = true
                break
            end
        end

        if (not bAdded) then
            -- then, replace the farthest one if the current one is closer
            for i = iCount, 1, -1 do
                if (iDistance < nearestList[i][2]) then
                    nearestList[i] = { veafAirbase, iDistance}
                    bAdded = true
                    break
                end
            end
        end

        if (bAdded) then
            table.sort(nearestList, Sort)
        end
        
    end

    return nearestList
end

function veafAirbases.getNearestAirbase(dcsUnit)
    local nearestList = veafAirbases.getNearestAirbaseList(dcsUnit, 1)
    if (nearestList and #nearestList >= 1) then
        local veafAirbase = nearestList[1][1]
        veaf.loggers.get(veafAirbases.Id):trace(string.format("Nearest airbase for [ %s ]: [ %s ] at %dm", dcsUnit:getName(), veafAirbase:toString(), nearestList[1][2]))
        return nearestList[1][1]
    else
        veaf.loggers.get(veafAirbases.Id):trace(string.format("No near airbase for [ %s ]", dcsUnit:getName()))
        return nil
    end
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  Airbase descriptor class
---  Holds normalized information describing a DCS airbase
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
veafAirbase = {}
veafAirbase.__index = veafAirbase

---------------------------------------------------------------------------------------------------
---  CTOR
function veafAirbase:create(dcsAirbase)
    if (dcsAirbase == nil) then
        return nil
    end
    
    local _, iCategory = dcsAirbase:getCategory()

    local veafRunways = {}
    if (iCategory ==Airbase.Category.AIRDROME) then
        local dcsRunways = dcsAirbase:getRunways()
        for iRunwayReportOrder, dcsRunway in pairs(dcsRunways) do
            local veafRunway = veafAirbaseRunway:create(dcsAirbase, dcsRunway, iRunwayReportOrder)
            if (veafRunway) then
                table.insert(veafRunways, veafRunway)
            end
        end
    end

    local this =
    {
        Name = dcsAirbase:getName(),
        Category = iCategory,
        DcsAirbase = dcsAirbase,
        Runways = veafRunways
    }

    setmetatable(this, veafAirbase)

    return this
end

---------------------------------------------------------------------------------------------------
---  Methods
function veafAirbase:getRunwayInService(iWindDirectionTrue)
    local function _getHeadwind(iWindDirection, nRunwayHeading)
        local nAngle = math.abs(iWindDirection - nRunwayHeading)
    
        if (nAngle > 180) then
            nAngle = 360 - nAngle
        end
    
        return math.cos(math.rad(nAngle))
    end

    local bestRunwayEnd = nil
    local nBestHeadwind = -math.huge -- Start with lowest possible value
    
    for i, veafRunway in ipairs(self.Runways) do
        for _, veafRunwayEnd in ipairs(veafRunway) do
            local nHeadwind = _getHeadwind(iWindDirectionTrue, veafRunwayEnd.Heading)
            
            if nHeadwind > nBestHeadwind then
                nBestHeadwind = nHeadwind
                bestRunwayEnd = veafRunwayEnd
            end
        end
    end

    local sLog = string.format("Runway in service for [ %s ] with wind from [ %03dT ] -->", self:toString(), iWindDirectionTrue)
    if (bestRunwayEnd) then
        sLog = sLog .. string.format(" [ %02d ]", bestRunwayEnd.Number)
    else
        sLog = sLog .. " none identified"
    end

    veaf.loggers.get(veafAirbases.Id):trace(sLog)
    return bestRunwayEnd
end

function veafAirbase:getRunwayInServiceString(iWindDirectionTrue)
    local veafRunwayEnd = self:getRunwayInService(iWindDirectionTrue)
    if (veafRunwayEnd) then
        return string.format("%02d", veafRunwayEnd.Number)
    else
        return nil
    end
end


function veafAirbase:toString()
    local s = self.Name
    
    for _, veafRunway in pairs(self.Runways) do
        s = s .. string.format(" | %s", veafRunway:toString())
    end

    return s
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  Runway descriptor class
---  Holds normalized information describing a DCS airbase runway
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
veafAirbaseRunway = {}
veafAirbaseRunway.__index = veafAirbaseRunway

---------------------------------------------------------------------------------------------------
---  CTOR
function veafAirbaseRunway:create(dcsAirbase, dcsRunway, iReportOrder)
    if (dcsAirbase == nil or dcsRunway == nil) then
        return nil
    end

    local function _normalizeHeading(nHeading)
        nHeading = nHeading % 360
        if (nHeading == 0) then nHeading = 360 end
        return nHeading
    end

    local function _normalizeNumber(iNumber)
        iNumber = iNumber % 36
        if (iNumber == 0) then iNumber = 36 end
        return iNumber
    end

    local function _numberFromHeading(nHeading)
        return mist.utils.round(nHeading / 10)
    end

    local function _numbersOffest(iOffset1, iOffest2)
        -- Calculate the absolute difference between angles
        local iOffset = math.abs(iOffset1 - iOffest2)
        local iOffsetOpposite = math.abs(36 - iOffset)
        return math.min(iOffset, iOffsetOpposite)
    end

    local sAirbaseName = dcsAirbase:getName()
    local iDcsNumber = tonumber(dcsRunway.Name)
    local nDcsHeading = _normalizeHeading(math.deg(-dcsRunway.course))

    -- correction for special misreported runways
    -- first reported runway is assumed always ok
    -- and we need to assume that since sometimes it has the same reported heading as another incorrect one (Tel Nof in Syria for ex)
    if (iReportOrder and iReportOrder > 1) then
        local manualAirbaseCorrections = _manualRunwayNumberCorrections[sAirbaseName]
        if (manualAirbaseCorrections) then
            local iCorrectedNumber = manualAirbaseCorrections[math.floor(nDcsHeading)]
            if (iCorrectedNumber and iCorrectedNumber > 0) then
                iDcsNumber = iCorrectedNumber
            elseif (iCorrectedNumber and iCorrectedNumber <= 0) then
                return nil -- for closed runways
            end
        end
    end

    --[[
    if (sAirbaseName == "Pahute Mesa") then
        veaf.loggers.get(veafAirbases.Id):trace("=======")
        veaf.loggers.get(veafAirbases.Id):trace(string.format("%d, %.2f", iDcsNumber, nDcsHeading))
        veaf.loggers.get(veafAirbases.Id):trace(veaf.p(dcsRunway))
    end
    ]]

    if (iDcsNumber == nil) then
        iDcsNumber = _numberFromHeading(nDcsHeading - veaf.getMagneticDeclination())
    end

    -- Calculate standard runway number (first two digits of heading)
    local iNumberFromHeading = _numberFromHeading(nDcsHeading)

    -- Calculate the opposite heading
    local nOppositeHeading = _normalizeHeading(nDcsHeading + 180)
    local iOppositeNumberFromHeading =  _numberFromHeading(nOppositeHeading)
    
    local iPrimaryNumber = iDcsNumber
    local iSecondaryNumber = _normalizeNumber(iDcsNumber + 18)
    local nPrimaryHeading, nSecondaryHeading

    local iFlipThreshold = 4
    if (_numbersOffest(iDcsNumber, iOppositeNumberFromHeading) <= iFlipThreshold or _numbersOffest(iDcsNumber, iNumberFromHeading) > iFlipThreshold) then
        -- If DCS number if close to computed opposite heading, or far from the DCS heading, flip the heading
        nPrimaryHeading = nOppositeHeading
        nSecondaryHeading = nDcsHeading
    else
        nPrimaryHeading = nDcsHeading
        nSecondaryHeading = nOppositeHeading
    end

    -- order the runway in ascending numbers
    local iNumber1 = iPrimaryNumber
    local nHeading1 = nPrimaryHeading
    local iNumber2 = iSecondaryNumber
    local nHeading2 = nSecondaryHeading

    if (iPrimaryNumber > iSecondaryNumber) then
        iNumber1 = iSecondaryNumber
        nHeading1 = nSecondaryHeading
        iNumber2 = iPrimaryNumber
        nHeading2 = nPrimaryHeading        
    end

    local this =
    {
        [1] = { Number = iNumber1, Heading = nHeading1 },
        [2] = { Number = iNumber2, Heading = nHeading2 },
    }

    setmetatable(this, veafAirbaseRunway)

    return this
end

---------------------------------------------------------------------------------------------------
---  Methods
function veafAirbaseRunway:toString()
    return string.format("RWY %02d(%.2fT) / %02d(%.2fT)", self[1].Number, self[1].Heading, self[2].Number, self[2].Heading)
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  MODULE TESTS
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--[[
veafAirbases.initialize()
veaf.loggers.get(veafAirbases.Id):trace("Airbases and runways initialized for theater " .. env.mission.theatre)
for _, veafAirbase in pairs(veafAirbases.Airbases) do
    veaf.loggers.get(veafAirbases.Id):trace(veafAirbase:toString())
end
]]