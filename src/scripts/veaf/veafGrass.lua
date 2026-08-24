------------------------------------------------------------------
-- VEAF grass functions for DCS World
-- By mitch (2018)
--
-- Features:
-- ---------
-- * Script to build units on FARPS and grass runways
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafGrass = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafGrass.Id = "GRASS"

-- trace level, specific to this module
--veafGrass.LogLevel = "trace"

veaf.loggers.new(veafGrass.Id, veafGrass.LogLevel)

veafGrass.DelayForStartup = 2

veafGrass.RadiusAroundFarp = 2000

--- DCS types that are a FARP *platform* — something a helicopter lands on — as opposed to the FARP
--- props (`FARP Tent`, `FARP Fuel Depot`, …) that this module places around one.
---
--- This list used to exist **four times** in this file, and it had already diverged: commit a454c577
--- (2025-08-08) added `FARP_T` to the one that recognises FARP units and to none of the three that
--- lay a FARP out. A `FARP_T` was therefore processed as a FARP and then measured as if it were not
--- one — escort at 75 m instead of 150, tent at 100 instead of 200, windsock at 50 m/45° instead of
--- 120 m/0° — which put its escort straight onto the pads. Hence one list, in one place.
---
--- The first two entries are the same object seen from the MIST side and the DCS side; both are kept
--- deliberately.
veafGrass.FARP_PLATFORM_TYPES = {
  ["SINGLE_HELIPAD"] = true,
  ["FARP_SINGLE_01"] = true,
  ["FARP"] = true,
  ["Invisible FARP"] = true,
  ["FARP_T"] = true,
}

--- DCS types whose name mentions FARP but which are **props**, not platforms — the very objects this
--- module places around a FARP. Listed so the warning below stays a signal: without them, every FARP
--- tent in a mission would raise one, and a warning that fires on correct missions gets ignored.
veafGrass.FARP_PROP_TYPES = {
  ["FARP Tent"] = true,
  ["FARP Fuel Depot"] = true,
  ["FARP Ammo Dump Coating"] = true,
  ["FARP CP Blindage"] = true,
}

-- How far apart to try bearings when walking around the circle looking for clear ground, and how much
-- room each object wants. 15° at 150 m is about 39 m of arc, so a full turn tries 24 bearings — cheap,
-- since it only happens when the original spot is actually occupied.
veafGrass.PLACEMENT_BEARING_STEP = 15
veafGrass.PLACEMENT_CLEARANCE = 12

--- How far from a landing platform's centre still counts as "on it".
---
--- **This is an estimate, deliberately stated as one.** DCS exposes no footprint for an airbase:
--- `Airbase` offers `getParking()` and `getRunways()` but no extent, and whether a FARP even reports
--- parking spots is unverified. So the number is reasoned rather than measured — the DCS `FARP` model is
--- roughly 50 m across, and 80 m covers it with margin for the pads at its edge.
---
--- What makes the value safe to get wrong in the generous direction: this module already places the
--- escort at 150 m, the tent at 200 m and the windsock at 50 m from the FARP it is building. So 80 m
--- around a *pre-existing* platform excludes its own surroundings and nothing else, and a mission maker
--- who deliberately drops a FARP 100 m from another one still gets what he asked for.
---
--- Worth measuring properly one day, by reading a real FARP's parking spots in a running mission. Until
--- then, an over-tight value shows up as an escort still landing on a platform, and an over-wide one as
--- an escort nudged onto a further bearing — the second is cheap, which is why the estimate leans wide.
veafGrass.PLATFORM_FOOTPRINT_RADIUS_METRES = 80

--- Every landing platform in the mission, as `{ x = northing, z = easting }` runtime points.
---
--- `veafGrass.isSpotOccupied` used to probe `world.searchObjects` over units and statics only, and the
--- comment above it reasoned about the wrong distinction: for a FARP the choice is not
--- static-versus-scenery but static-versus-**airbase**. A FARP placed in the editor is an *airbase* —
--- `Airbase.Category.HELIPAD`, reached through `world.getAirbases()`, exactly as `veafAirbases.lua:191`
--- has always treated it, and as the DCS log says (`NO ATC COMM HELIPAD + StaticFarpAlpha-1`). So the
--- probe could never see the one object #232 is about, and the fix shipped in 6.15.11 changed nothing.
--- Measured in game 2026-08-22: everything still came up on the static FARP.
---
--- Read once per bearing search rather than per candidate position: a full turn tries 24 bearings and
--- each tests every position the group would occupy, so calling `world.getAirbases()` inside the probe
--- would mean hundreds of calls per FARP.
function veafGrass.getLandingPlatforms()
  local platforms = {}
  local ok, airbases = pcall(world.getAirbases)
  if not ok or type(airbases) ~= "table" then
    veaf.loggers.get(veafGrass.Id):debug("getLandingPlatforms: world.getAirbases unusable")
    return platforms
  end
  for _, airbase in pairs(airbases) do
    pcall(function()
      local category = airbase:getDesc() and airbase:getDesc().category
      local typeName = airbase.getTypeName and airbase:getTypeName() or ""
      -- The SHIP branch is not defensive padding: DCS miscategorises some FARPs
      -- ("FARP_SINGLE_01", "VAP FARP") as ships, which `veafAirbases` already remediates the same way.
      -- Leaving it out would let exactly those types keep the defect.
      local isPlatform = category == Airbase.Category.HELIPAD
        or (category == Airbase.Category.SHIP and string.find(tostring(typeName), "FARP"))
      if isPlatform then
        local point = airbase:getPoint()
        if point then
          table.insert(platforms, { x = point.x, z = point.z, name = airbase:getName() })
        end
      end
    end)
  end
  -- At info, and deliberately: when an escort still lands on a platform, "0 platforms" and "3 platforms"
  -- are completely different bugs and from outside they look the same. Not knowing which cost a
  -- round-trip on 2026-08-24.
  veaf.loggers.get(veafGrass.Id):info("getLandingPlatforms: %s landing platform(s) to avoid", veaf.p(#platforms))
  return platforms
end

--- Is `position` inside the footprint of one of `platforms`?
--- Takes a **mission-table position** (`{x, y}` where y is the easting); `platforms` carry runtime
--- points (`z` is the easting). Mixing the two raises nothing and reads a distance from the wrong axis,
--- so the conversion is done here, once — see docs/agents/dcs-coordinates.md.
function veafGrass.isOnLandingPlatform(position, platforms)
  if not position or not platforms then
    return false
  end
  local radius = veafGrass.PLATFORM_FOOTPRINT_RADIUS_METRES
  for _, platform in ipairs(platforms) do
    local dx, dz = position.x - platform.x, position.y - platform.z
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance <= radius then
      veaf.loggers.get(veafGrass.Id):info(
        "isOnLandingPlatform: refusing a spot %sm from [%s] (footprint %sm)",
        veaf.p(math.floor(distance)),
        veaf.p(platform.name),
        veaf.p(radius)
      )
      return true
    end
  end
  return false
end

--- Is anything already standing within `clearance` metres of this spot, or is it on a landing platform?
--- Takes a **mission-table position** (`{x, y}` where y is the easting), which is what the FARP layout
--- code works in, and converts it for the runtime API — see docs/agents/dcs-coordinates.md, since the
--- two shapes both look like plausible coordinates and swapping them raises no error.
---
--- Two different questions, and the second is why 6.15.11 did not work:
---
--- * **units and statics**, within `clearance` — another group already parked here. `world.searchObjects`
---   is right for that, and scenery is deliberately left to `veaf.findSpawnPoint`'s Disposition tier.
--- * **landing platforms**, within their footprint — passed in by the caller. A sphere probe cannot
---   answer this even for a static, because `searchObjects` matches an object's *position*: with a 12 m
---   clearance and a platform tens of metres across, an escort on its **edge** — the actual complaint in
---   #232 — leaves the platform's centre well outside the sphere.
---
--- `platforms` is optional so every existing caller keeps working; pass `veafGrass.getLandingPlatforms()`
--- to get the platform half.
function veafGrass.isSpotOccupied(position, clearance, platforms)
  clearance = clearance or veafGrass.PLACEMENT_CLEARANCE
  if not position then
    return false
  end
  if veafGrass.isOnLandingPlatform(position, platforms) then
    return true
  end
  local occupied = false
  local volume = {
    id = world.VolumeType.SPHERE,
    params = { point = veaf.placePointOnLand(position), radius = clearance },
  }
  local function found(object)
    -- An object can cease to exist between DCS handing it over and us asking about it, and a raise
    -- here would abort building the FARP. A failed probe reads as "clear", which is the behaviour
    -- this module had before it probed at all.
    pcall(function()
      if object and object:isExist() then
        occupied = true
      end
    end)
  end
  for _, category in ipairs({ Object.Category.UNIT, Object.Category.STATIC }) do
    local ok = pcall(world.searchObjects, category, volume, found)
    if not ok then
      veaf.loggers.get(veafGrass.Id):debug("isSpotOccupied: world.searchObjects unusable, treating the spot as clear")
      return false
    end
    if occupied then
      return true
    end
  end
  return false
end

--- Find a bearing at `distance` from `center` where every position a group would occupy is clear.
--- Keeps the radius and moves the bearing, per David's arbitration on #232: growing the radius would
--- push the escort away from the FARP it serves, and in a campaign the crew wants it close.
--- `positionsFor(angle)` returns the list of mission-table positions the objects would take at that
--- bearing — the whole list, because a five-vehicle group at 6 m spacing needs a clear *arc*, and
--- testing its origin alone would move it so its tail still overlapped.
--- Returns the original angle when nothing is clear: a FARP that refuses to exist because it is
--- crowded would be worse than one whose escort is tight.
function veafGrass.findClearBearing(baseAngle, positionsFor)
  -- Read once, here: a full turn tries 24 bearings and each tests every position the group would
  -- occupy, so asking DCS for its airbase list inside the probe would mean hundreds of calls per FARP.
  local platforms = veafGrass.getLandingPlatforms()

  local function allClear(angle)
    for _, position in ipairs(positionsFor(angle) or {}) do
      if veafGrass.isSpotOccupied(position, nil, platforms) then
        return false
      end
    end
    return true
  end

  -- The original bearing first, so a FARP with nothing in its way does not move at all.
  if allClear(baseAngle) then
    return baseAngle
  end

  local steps = math.floor(360 / veafGrass.PLACEMENT_BEARING_STEP)
  for i = 1, steps do
    -- Alternate sides, so the escort ends up as close as possible to where the mission maker aimed it.
    local offset = math.ceil(i / 2) * veafGrass.PLACEMENT_BEARING_STEP
    if i % 2 == 0 then
      offset = -offset
    end
    local candidate = baseAngle + offset
    if allClear(candidate) then
      veaf.loggers
        .get(veafGrass.Id)
        :debug("findClearBearing: moved from %s to %s to find clear ground", veaf.p(baseAngle), veaf.p(candidate))
      return candidate
    end
  end

  veaf.loggers.get(veafGrass.Id):info(string.format("findClearBearing: no clear bearing at this distance, keeping %s", tostring(baseAngle)))
  return baseAngle
end

--- Is this DCS type a FARP platform?
--- A type that is not one but *looks* like one — its name mentions FARP or HELIPAD, and it is not a
--- known prop — is reported rather than silently taking the non-FARP distances, which is what hid the
--- FARP_T divergence for a year. Same shape as FIX-COMBATZONE-ZONE-TYPE-SILENT: guessing is
--- acceptable, guessing in silence is not.
function veafGrass.isFarpPlatformType(typeName)
  if type(typeName) ~= "string" then
    return false
  end
  if veafGrass.FARP_PLATFORM_TYPES[typeName] then
    return true
  end
  if not veafGrass.FARP_PROP_TYPES[typeName] then
    local upper = typeName:upper()
    if upper:find("FARP", 1, true) or upper:find("HELIPAD", 1, true) then
      veaf.loggers.get(veafGrass.Id):warn(
        "unknown FARP-like type [%s]: using the default distances, not the FARP ones. Add it to veafGrass.FARP_PLATFORM_TYPES if it is a platform.",
        veaf.p(typeName)
      )
    end
  end
  return false
end

-- these units will be placed in spawned FARPs warehouses and available for the dynamic slot mechanism
veafGrass.helicoptersOnFARPs = {
  "SA342Mistral",
  "SA342Minigun",
  "SA342L",
  "SA342M",
  "UH-1H",
  "Mi-8MTV2",
  "Mi-8MT",
  "Mi-24P",
  "Mi-24V",
  "Bell-47",
  "UH-60L",
  "UH-60L_DAP",
  "AH-64D_BLK_II",
  "Bronco-OV-10A",
  "MH-60R",
  "OH-6A",
  "OH58D",
  "CH-47Fbl1",
}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- veafGrass.buildGrassRunway
-- Build a grass runway from grassRunwayUnit
-- @param grassRunwayUnit a static unit object (right side)
-- @return a named point if successful
------------------------------------------------------------------------------
function veafGrass.buildGrassRunway(grassRunwayUnit, hiddenOnMFD)
  veaf.loggers.get(veafGrass.Id):debug(string.format("veafGrass.buildGrassRunway()"))
  veaf.loggers.get(veafGrass.Id):trace(string.format("grassRunwayUnit=%s", veaf.p(grassRunwayUnit)))
  veaf.loggers.get(veafGrass.Id):trace(string.format("hiddenOnMFD=%s", veaf.p(hiddenOnMFD)))

  if not grassRunwayUnit then
    return nil
  end

  local name = grassRunwayUnit.unitName
  local runwayOrigin = grassRunwayUnit
  local tower = true
  local endMarkers = false

  -- runway length in meters
  local length = 600
  -- a plot each XX meters
  local space = 50
  -- runway width XX meters
  local width = 30

  -- nb plots
  local nbPlots = math.ceil(length / space)

  local angle = math.floor(mist.utils.toDegree(runwayOrigin.heading) + 0.5)

  -- create left origin from right origin
  local leftOrigin = {
    ["x"] = runwayOrigin.x + width * math.cos(mist.utils.toRadian(angle - 90)),
    ["y"] = runwayOrigin.y + width * math.sin(mist.utils.toRadian(angle - 90)),
  }

  local template = {
    ["category"] = runwayOrigin.category,
    ["categoryStatic"] = runwayOrigin.categoryStatic,
    ["coalition"] = runwayOrigin.coalition,
    ["country"] = runwayOrigin.country,
    ["countryId"] = runwayOrigin.countryId,
    ["heading"] = runwayOrigin.heading,
    ["shape_name"] = runwayOrigin.shape_name,
    ["type"] = runwayOrigin.type,
    ["hiddenOnMFD"] = hiddenOnMFD,
  }

  -- leftOrigin plot
  local leftOriginPlot = mist.utils.deepCopy(template)
  leftOriginPlot.x = leftOrigin.x
  leftOriginPlot.y = leftOrigin.y
  mist.dynAddStatic(leftOriginPlot)

  -- place plots
  for i = 1, nbPlots do
    -- right plot
    local leftPlot = mist.utils.deepCopy(template)
    leftPlot.x = runwayOrigin.x + i * space * math.cos(mist.utils.toRadian(angle))
    leftPlot.y = runwayOrigin.y + i * space * math.sin(mist.utils.toRadian(angle))
    mist.dynAddStatic(leftPlot)

    -- right plot
    local rightPlot = mist.utils.deepCopy(template)
    rightPlot.x = leftOrigin.x + i * space * math.cos(mist.utils.toRadian(angle))
    rightPlot.y = leftOrigin.y + i * space * math.sin(mist.utils.toRadian(angle))
    mist.dynAddStatic(rightPlot)
  end

  if endMarkers then
    -- close the runway with optional markers (airshow cones)
    template = {
      ["category"] = "Fortifications",
      ["categoryStatic"] = runwayOrigin.categoryStatic,
      ["coalition"] = runwayOrigin.coalition,
      ["country"] = runwayOrigin.country,
      ["countryId"] = runwayOrigin.countryId,
      ["heading"] = runwayOrigin.heading,
      ["shape_name"] = "Comp_cone",
      ["type"] = "Airshow_Cone",
      ["hiddenOnMFD"] = hiddenOnMFD,
    }
    -- right plot
    local leftPlot = mist.utils.deepCopy(template)
    leftPlot.x = runwayOrigin.x + (nbPlots + 1) * space * math.cos(mist.utils.toRadian(angle))
    leftPlot.y = runwayOrigin.y + (nbPlots + 1) * space * math.sin(mist.utils.toRadian(angle))
    mist.dynAddStatic(leftPlot)

    -- right plot
    local rightPlot = mist.utils.deepCopy(template)
    rightPlot.x = leftOrigin.x + (nbPlots + 1) * space * math.cos(mist.utils.toRadian(angle))
    rightPlot.y = leftOrigin.y + (nbPlots + 1) * space * math.sin(mist.utils.toRadian(angle))
    mist.dynAddStatic(rightPlot)
  end

  if tower then
    -- optionally add a tower at the start of the runway
    template = {
      ["category"] = "Fortifications",
      ["categoryStatic"] = runwayOrigin.categoryStatic,
      ["coalition"] = runwayOrigin.coalition,
      ["country"] = runwayOrigin.country,
      ["countryId"] = runwayOrigin.countryId,
      ["heading"] = runwayOrigin.heading,
      ["type"] = "house2arm",
      ["hiddenOnMFD"] = hiddenOnMFD,
    }

    -- tower
    local tower = mist.utils.deepCopy(template)
    tower.x = leftOrigin.x - 60 + (nbPlots + 1.2) * space * math.cos(mist.utils.toRadian(angle))
    tower.y = leftOrigin.y - 60 + (nbPlots + 1.2) * space * math.sin(mist.utils.toRadian(angle))
    mist.dynAddStatic(tower)
  end

  -- add the runway to the named points
  local point = {
    x = runwayOrigin.x + 20 + (nbPlots + 1) * space * math.cos(mist.utils.toRadian(angle)) + width / 2 * math.cos(
      mist.utils.toRadian(angle - 90)
    ),
    y = math.floor(land.getHeight(leftOrigin) + 1),
    z = runwayOrigin.y + 20 + (nbPlots + 1) * space * math.sin(mist.utils.toRadian(angle)) + width / 2 * math.cos(
      mist.utils.toRadian(angle - 90)
    ),
    atc = true,
    runways = {
      { hdg = (angle + 180) % 360, flare = "red" },
    },
  }
  return point
end

------------------------------------------------------------------------------
-- veafGrass.buildFarpsUnits
-- build FARP units on FARP with group name like "FARP "
------------------------------------------------------------------------------
function veafGrass.buildFarpsUnits(hiddenOnMFD)
  local farpUnits = {}
  local grassRunwayUnits = {}
  for name, unit in pairs(veaf.mist.getAllUnitData()) do
    --veaf.loggers.get(veafGrass.Id):trace("buildFarpsUnits: testing " .. unit.type .. " " .. name)
    if name:upper():find("GRASS_RUNWAY") then
      grassRunwayUnits[name] = unit
      veaf.loggers.get(veafGrass.Id):trace(string.format("found grassRunwayUnits[%s]= %s", name, veaf.p(unit)))
    end
    --first two types should represent the same object depending on if you're on the MIST side or DCS side, as a safety added both
    if veafGrass.isFarpPlatformType(unit.type) and name:upper():sub(1, 5) == "FARP " then
      farpUnits[name] = unit
      veaf.loggers.get(veafGrass.Id):trace(string.format("found farpUnits[%s]= %s", name, veaf.p(unit)))
    end
  end
  veaf.loggers.get(veafGrass.Id):trace(string.format("farpUnits=%s", veaf.p(farpUnits)))
  veaf.loggers.get(veafGrass.Id):trace(string.format("grassRunwayUnits=%s", veaf.p(grassRunwayUnits)))
  for name, unit in pairs(farpUnits) do
    veaf.loggers.get(veafGrass.Id):trace(string.format("calling buildFarpsUnits(%s)", name))
    veafGrass.buildFarpUnits(unit, grassRunwayUnits, nil, hiddenOnMFD)
  end
end

---Browse all the FARP-type units and refill their warehouses
function veafGrass.fillAllFarpWarehouses()
  veaf.loggers.get(veafGrass.Id):debug("veafGrass.fillAllFarpWarehouses()")
  local farpBases = {}
  local grassBases = {}
  local bases = world.getAirbases()
  for _, base in pairs(bases) do
    local name = base:getName()
    veaf.loggers.get(veafGrass.Id):trace("fillAllFarpWarehouse: testing %s", veaf.lp(name))
    local status, typeName = pcall(base.getTypeName, base) -- test cautiously if the base is a valid airbase, since DCS will either fail the getTypeName call or even crash when the airbase has been "moved" (e.g., by creating a new FARP with the same name)
    if status then
      if name:upper():find("GRASS_RUNWAY") then
        grassBases[name] = base
        veaf.loggers.get(veafGrass.Id):trace("found grassBase [%s]", veaf.lp(name))
      end
      --first two types should represent the same object depending on if you're on the MIST side or DCS side, as a safety added both
      if veafGrass.isFarpPlatformType(typeName) then
        farpBases[name] = base
        veaf.loggers.get(veafGrass.Id):trace("found farpBase [%s]", veaf.lp(name))
      end
    else
      veaf.loggers.get(veafGrass.Id):warn("Airbase is not a valid object - getTypeName crashed - [%s]", veaf.p(name))
    end
  end

  for _, base in pairs(grassBases) do
    veafGrass.fillFarpWarehouse(base)
  end

  for _, base in pairs(farpBases) do
    veafGrass.fillFarpWarehouse(base)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Very long table used to fill FARP warehouses
-------------------------------------------------------------------------------------------------------------------------------------------------------------
veafGrass.WAREHOUSE_ITEMS = {
  [1] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 10 }, ["initialAmount"] = 100 },
  [2] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 103 }, ["initialAmount"] = 100 },
  [3] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1056 }, ["initialAmount"] = 100 },
  [4] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 107 }, ["initialAmount"] = 100 },
  [5] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 11 }, ["initialAmount"] = 100 },
  [6] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 12 }, ["initialAmount"] = 100 },
  [7] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 13 }, ["initialAmount"] = 100 },
  [8] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 14 }, ["initialAmount"] = 100 },
  [9] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1469 }, ["initialAmount"] = 100 },
  [10] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1470 }, ["initialAmount"] = 100 },
  [11] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 15 }, ["initialAmount"] = 100 },
  [12] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 152 }, ["initialAmount"] = 100 },
  [13] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1551 }, ["initialAmount"] = 100 },
  [14] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1552 }, ["initialAmount"] = 100 },
  [15] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1553 }, ["initialAmount"] = 100 },
  [16] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1554 }, ["initialAmount"] = 100 },
  [17] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1555 }, ["initialAmount"] = 100 },
  [18] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1556 }, ["initialAmount"] = 100 },
  [19] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1572 }, ["initialAmount"] = 100 },
  [20] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1573 }, ["initialAmount"] = 100 },
  [21] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 16 }, ["initialAmount"] = 100 },
  [22] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1640 }, ["initialAmount"] = 100 },
  [23] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1641 }, ["initialAmount"] = 100 },
  [24] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1642 }, ["initialAmount"] = 100 },
  [25] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 17 }, ["initialAmount"] = 100 },
  [26] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1700 }, ["initialAmount"] = 100 },
  [27] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1715 }, ["initialAmount"] = 100 },
  [28] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 1716 }, ["initialAmount"] = 100 },
  [29] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 2144 }, ["initialAmount"] = 100 },
  [30] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 2145 }, ["initialAmount"] = 100 },
  [31] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 2146 }, ["initialAmount"] = 100 },
  [32] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 2380 }, ["initialAmount"] = 100 },
  [33] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 2381 }, ["initialAmount"] = 100 },
  [34] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 2382 }, ["initialAmount"] = 100 },
  [35] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 2383 }, ["initialAmount"] = 100 },
  [36] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 263 }, ["initialAmount"] = 100 },
  [37] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 264 }, ["initialAmount"] = 100 },
  [38] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 265 }, ["initialAmount"] = 100 },
  [39] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 266 }, ["initialAmount"] = 100 },
  [40] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 267 }, ["initialAmount"] = 100 },
  [41] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 274 }, ["initialAmount"] = 100 },
  [42] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 275 }, ["initialAmount"] = 100 },
  [43] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 294 }, ["initialAmount"] = 100 },
  [44] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 36 }, ["initialAmount"] = 100 },
  [45] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 38 }, ["initialAmount"] = 100 },
  [46] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 39 }, ["initialAmount"] = 100 },
  [47] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 41 }, ["initialAmount"] = 100 },
  [48] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 42 }, ["initialAmount"] = 100 },
  [49] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 465 }, ["initialAmount"] = 100 },
  [50] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 466 }, ["initialAmount"] = 100 },
  [51] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 468 }, ["initialAmount"] = 100 },
  [52] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 469 }, ["initialAmount"] = 100 },
  [53] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 484 }, ["initialAmount"] = 100 },
  [54] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 485 }, ["initialAmount"] = 100 },
  [55] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 5 }, ["initialAmount"] = 100 },
  [56] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 53 }, ["initialAmount"] = 100 },
  [57] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 54 }, ["initialAmount"] = 100 },
  [58] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 55 }, ["initialAmount"] = 100 },
  [59] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 56 }, ["initialAmount"] = 100 },
  [60] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 587 }, ["initialAmount"] = 100 },
  [61] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 589 }, ["initialAmount"] = 100 },
  [62] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 590 }, ["initialAmount"] = 100 },
  [63] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 593 }, ["initialAmount"] = 100 },
  [64] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 603 }, ["initialAmount"] = 100 },
  [65] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 604 }, ["initialAmount"] = 100 },
  [66] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 605 }, ["initialAmount"] = 100 },
  [67] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 609 }, ["initialAmount"] = 100 },
  [68] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 61 }, ["initialAmount"] = 100 },
  [69] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 610 }, ["initialAmount"] = 100 },
  [70] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 611 }, ["initialAmount"] = 100 },
  [71] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 616 }, ["initialAmount"] = 100 },
  [72] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 617 }, ["initialAmount"] = 100 },
  [73] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 662 }, ["initialAmount"] = 100 },
  [74] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 663 }, ["initialAmount"] = 100 },
  [75] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 664 }, ["initialAmount"] = 100 },
  [76] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 782 }, ["initialAmount"] = 100 },
  [77] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 783 }, ["initialAmount"] = 100 },
  [78] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 855 }, ["initialAmount"] = 100 },
  [79] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 928 }, ["initialAmount"] = 100 },
  [80] = { ["wsType"] = { [1] = 1, [2] = 3, [3] = 43, [4] = 929 }, ["initialAmount"] = 100 },
  [81] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 101 }, ["initialAmount"] = 5550 },
  [82] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 1548 }, ["initialAmount"] = 5550 },
  [83] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 1717 }, ["initialAmount"] = 5550 },
  [84] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 1718 }, ["initialAmount"] = 5550 },
  [85] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 1719 }, ["initialAmount"] = 5550 },
  [86] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 1720 }, ["initialAmount"] = 5550 },
  [87] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 1721 }, ["initialAmount"] = 5550 },
  [88] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 19 }, ["initialAmount"] = 5550 },
  [89] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 2114 }, ["initialAmount"] = 1254 },
  [90] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 2138 }, ["initialAmount"] = 5550 },
  [91] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 2139 }, ["initialAmount"] = 5550 },
  [92] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 2140 }, ["initialAmount"] = 5550 },
  [93] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 2141 }, ["initialAmount"] = 5550 },
  [94] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 2142 }, ["initialAmount"] = 5550 },
  [95] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 2148 }, ["initialAmount"] = 5550 },
  [96] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 2149 }, ["initialAmount"] = 5550 },
  [97] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 2286 }, ["initialAmount"] = 5550 },
  [98] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 2287 }, ["initialAmount"] = 5550 },
  [99] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 2288 }, ["initialAmount"] = 5550 },
  [100] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 2475 }, ["initialAmount"] = 5550 },
  [101] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 26 }, ["initialAmount"] = 5550 },
  [102] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 28 }, ["initialAmount"] = 5550 },
  [103] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 424 }, ["initialAmount"] = 5550 },
  [104] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 425 }, ["initialAmount"] = 5550 },
  [105] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 426 }, ["initialAmount"] = 5550 },
  [106] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 461 }, ["initialAmount"] = 5550 },
  [107] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 463 }, ["initialAmount"] = 5550 },
  [108] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 486 }, ["initialAmount"] = 5550 },
  [109] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 59 }, ["initialAmount"] = 5550 },
  [110] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 62 }, ["initialAmount"] = 5550 },
  [111] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 63 }, ["initialAmount"] = 5550 },
  [112] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 64 }, ["initialAmount"] = 5550 },
  [113] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 65 }, ["initialAmount"] = 5550 },
  [114] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 74 }, ["initialAmount"] = 5550 },
  [115] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 78 }, ["initialAmount"] = 5550 },
  [116] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 808 }, ["initialAmount"] = 5550 },
  [117] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 44, [4] = 95 }, ["initialAmount"] = 5550 },
  [118] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 142 }, ["initialAmount"] = 5550 },
  [119] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 173 }, ["initialAmount"] = 5550 },
  [120] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 1762 }, ["initialAmount"] = 5550 },
  [121] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 1763 }, ["initialAmount"] = 5550 },
  [122] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 25 }, ["initialAmount"] = 5550 },
  [123] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 29 }, ["initialAmount"] = 5550 },
  [124] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 295 }, ["initialAmount"] = 5550 },
  [125] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 296 }, ["initialAmount"] = 5550 },
  [126] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 30 }, ["initialAmount"] = 5550 },
  [127] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 301 }, ["initialAmount"] = 5550 },
  [128] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 37 }, ["initialAmount"] = 5550 },
  [129] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 462 }, ["initialAmount"] = 5550 },
  [130] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 464 }, ["initialAmount"] = 5550 },
  [131] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 665 }, ["initialAmount"] = 5550 },
  [132] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 681 }, ["initialAmount"] = 5550 },
  [133] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 94 }, ["initialAmount"] = 5550 },
  [134] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 45, [4] = 968 }, ["initialAmount"] = 5550 },
  [135] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1057 }, ["initialAmount"] = 5550 },
  [136] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1294 }, ["initialAmount"] = 5550 },
  [137] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1295 }, ["initialAmount"] = 5550 },
  [138] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 145 }, ["initialAmount"] = 5550 },
  [139] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1544 }, ["initialAmount"] = 5550 },
  [140] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1545 }, ["initialAmount"] = 5550 },
  [141] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1546 }, ["initialAmount"] = 5550 },
  [142] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1547 }, ["initialAmount"] = 5550 },
  [143] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 160 }, ["initialAmount"] = 5550 },
  [144] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 161 }, ["initialAmount"] = 5550 },
  [145] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 170 }, ["initialAmount"] = 5550 },
  [146] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 171 }, ["initialAmount"] = 5550 },
  [147] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 174 }, ["initialAmount"] = 5550 },
  [148] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 175 }, ["initialAmount"] = 5550 },
  [149] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 176 }, ["initialAmount"] = 5550 },
  [150] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1764 }, ["initialAmount"] = 5550 },
  [151] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1765 }, ["initialAmount"] = 5550 },
  [152] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1766 }, ["initialAmount"] = 5550 },
  [153] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1767 }, ["initialAmount"] = 5550 },
  [154] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1768 }, ["initialAmount"] = 5550 },
  [155] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1769 }, ["initialAmount"] = 5550 },
  [156] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 177 }, ["initialAmount"] = 5550 },
  [157] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1770 }, ["initialAmount"] = 5550 },
  [158] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1771 }, ["initialAmount"] = 5550 },
  [159] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 18 }, ["initialAmount"] = 5550 },
  [160] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1813 }, ["initialAmount"] = 5550 },
  [161] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 183 }, ["initialAmount"] = 5550 },
  [162] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 184 }, ["initialAmount"] = 5550 },
  [163] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 1919 }, ["initialAmount"] = 5550 },
  [164] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 20 }, ["initialAmount"] = 5550 },
  [165] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 2143 }, ["initialAmount"] = 5550 },
  [166] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 2476 }, ["initialAmount"] = 5550 },
  [167] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 2477 }, ["initialAmount"] = 5550 },
  [168] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 2478 }, ["initialAmount"] = 5550 },
  [169] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 2479 }, ["initialAmount"] = 5550 },
  [170] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 2480 }, ["initialAmount"] = 5550 },
  [171] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 2481 }, ["initialAmount"] = 5550 },
  [172] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 2482 }, ["initialAmount"] = 5550 },
  [173] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 2483 }, ["initialAmount"] = 5550 },
  [174] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 2484 }, ["initialAmount"] = 5550 },
  [175] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 2574 }, ["initialAmount"] = 5550 },
  [176] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 2575 }, ["initialAmount"] = 5550 },
  [177] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 2576 }, ["initialAmount"] = 5550 },
  [178] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 2577 }, ["initialAmount"] = 5550 },
  [179] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 2578 }, ["initialAmount"] = 5550 },
  [180] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 286 }, ["initialAmount"] = 5550 },
  [181] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 300 }, ["initialAmount"] = 5550 },
  [182] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 428 }, ["initialAmount"] = 5550 },
  [183] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 429 }, ["initialAmount"] = 5550 },
  [184] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 588 }, ["initialAmount"] = 5550 },
  [185] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 596 }, ["initialAmount"] = 5550 },
  [186] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 824 }, ["initialAmount"] = 5550 },
  [187] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 46, [4] = 825 }, ["initialAmount"] = 5550 },
  [188] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 47, [4] = 104 }, ["initialAmount"] = 5550 },
  [189] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 47, [4] = 108 }, ["initialAmount"] = 5550 },
  [190] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 47, [4] = 1100 }, ["initialAmount"] = 5550 },
  [191] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 47, [4] = 1549 }, ["initialAmount"] = 5550 },
  [192] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 47, [4] = 4 }, ["initialAmount"] = 5550 },
  [193] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 47, [4] = 679 }, ["initialAmount"] = 5550 },
  [194] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 47, [4] = 680 }, ["initialAmount"] = 5550 },
  [195] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 48, [4] = 1168 }, ["initialAmount"] = 5550 },
  [196] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 48, [4] = 1169 }, ["initialAmount"] = 5550 },
  [197] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 48, [4] = 1170 }, ["initialAmount"] = 5550 },
  [198] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 48, [4] = 1171 }, ["initialAmount"] = 5550 },
  [199] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 48, [4] = 1172 }, ["initialAmount"] = 5550 },
  [200] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 48, [4] = 1173 }, ["initialAmount"] = 5550 },
  [201] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 48, [4] = 1174 }, ["initialAmount"] = 5550 },
  [202] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 48, [4] = 297 }, ["initialAmount"] = 5550 },
  [203] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 48, [4] = 58 }, ["initialAmount"] = 5550 },
  [204] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 48, [4] = 608 }, ["initialAmount"] = 5550 },
  [205] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 48, [4] = 666 }, ["initialAmount"] = 5550 },
  [206] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 48, [4] = 765 }, ["initialAmount"] = 5550 },
  [207] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 48, [4] = 766 }, ["initialAmount"] = 5550 },
  [208] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 1550 }, ["initialAmount"] = 5550 },
  [209] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 172 }, ["initialAmount"] = 5550 },
  [210] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 268 }, ["initialAmount"] = 5550 },
  [211] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 269 }, ["initialAmount"] = 5550 },
  [212] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 270 }, ["initialAmount"] = 5550 },
  [213] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 271 }, ["initialAmount"] = 5550 },
  [214] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 272 }, ["initialAmount"] = 5550 },
  [215] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 273 }, ["initialAmount"] = 5550 },
  [216] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 298 }, ["initialAmount"] = 5550 },
  [217] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 427 }, ["initialAmount"] = 5550 },
  [218] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 467 }, ["initialAmount"] = 5550 },
  [219] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 470 }, ["initialAmount"] = 5550 },
  [220] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 66 }, ["initialAmount"] = 5550 },
  [221] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 667 }, ["initialAmount"] = 5550 },
  [222] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 668 }, ["initialAmount"] = 5550 },
  [223] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 67 }, ["initialAmount"] = 5550 },
  [224] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 82 }, ["initialAmount"] = 5550 },
  [225] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 83 }, ["initialAmount"] = 5550 },
  [226] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 84 }, ["initialAmount"] = 5550 },
  [227] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 85 }, ["initialAmount"] = 5550 },
  [228] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 86 }, ["initialAmount"] = 5550 },
  [229] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 87 }, ["initialAmount"] = 5550 },
  [230] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 88 }, ["initialAmount"] = 5550 },
  [231] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 89 }, ["initialAmount"] = 5550 },
  [232] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 90 }, ["initialAmount"] = 5550 },
  [233] = { ["wsType"] = { [1] = 4, [2] = 15, [3] = 50, [4] = 91 }, ["initialAmount"] = 5550 },
  [234] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 100, [4] = 143 }, ["initialAmount"] = 100 },
  [235] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 101, [4] = 140 }, ["initialAmount"] = 100 },
  [236] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 101, [4] = 141 }, ["initialAmount"] = 100 },
  [237] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 101, [4] = 142 }, ["initialAmount"] = 100 },
  [238] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 101, [4] = 154 }, ["initialAmount"] = 100 },
  [239] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 32, [4] = 719 }, ["initialAmount"] = 100 },
  [240] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 32, [4] = 849 }, ["initialAmount"] = 100 },
  [241] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 34, [4] = 291 }, ["initialAmount"] = 100 },
  [242] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 34, [4] = 91 }, ["initialAmount"] = 100 },
  [243] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 1 }, ["initialAmount"] = 100 },
  [244] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 10 }, ["initialAmount"] = 100 },
  [245] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 106 }, ["initialAmount"] = 100 },
  [246] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 11 }, ["initialAmount"] = 100 },
  [247] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 11037 }, ["initialAmount"] = 100 },
  [248] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 11038 }, ["initialAmount"] = 100 },
  [249] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 11039 }, ["initialAmount"] = 100 },
  [250] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 13 }, ["initialAmount"] = 100 },
  [251] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 135 }, ["initialAmount"] = 100 },
  [252] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 136 }, ["initialAmount"] = 100 },
  [253] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 14 }, ["initialAmount"] = 100 },
  [254] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 15 }, ["initialAmount"] = 100 },
  [255] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 16 }, ["initialAmount"] = 100 },
  [256] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 18 }, ["initialAmount"] = 100 },
  [257] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 19 }, ["initialAmount"] = 100 },
  [258] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 2 }, ["initialAmount"] = 100 },
  [259] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 21 }, ["initialAmount"] = 100 },
  [260] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 22 }, ["initialAmount"] = 100 },
  [261] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 23 }, ["initialAmount"] = 100 },
  [262] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 24 }, ["initialAmount"] = 100 },
  [263] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 26 }, ["initialAmount"] = 100 },
  [264] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 265 }, ["initialAmount"] = 100 },
  [265] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 266 }, ["initialAmount"] = 100 },
  [266] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 267 }, ["initialAmount"] = 100 },
  [267] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 268 }, ["initialAmount"] = 100 },
  [268] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 269 }, ["initialAmount"] = 100 },
  [269] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 27 }, ["initialAmount"] = 100 },
  [270] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 270 }, ["initialAmount"] = 100 },
  [271] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 3 }, ["initialAmount"] = 100 },
  [272] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 306 }, ["initialAmount"] = 100 },
  [273] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 307 }, ["initialAmount"] = 100 },
  [274] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 308 }, ["initialAmount"] = 100 },
  [275] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 309 }, ["initialAmount"] = 100 },
  [276] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 310 }, ["initialAmount"] = 100 },
  [277] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 320 }, ["initialAmount"] = 100 },
  [278] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 321 }, ["initialAmount"] = 100 },
  [279] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 322 }, ["initialAmount"] = 100 },
  [280] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 327 }, ["initialAmount"] = 100 },
  [281] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 333 }, ["initialAmount"] = 100 },
  [282] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 334 }, ["initialAmount"] = 100 },
  [283] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 335 }, ["initialAmount"] = 100 },
  [284] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 336 }, ["initialAmount"] = 100 },
  [285] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 337 }, ["initialAmount"] = 100 },
  [286] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 338 }, ["initialAmount"] = 100 },
  [287] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 339 }, ["initialAmount"] = 100 },
  [288] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 368 }, ["initialAmount"] = 100 },
  [289] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 371 }, ["initialAmount"] = 100 },
  [290] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 372 }, ["initialAmount"] = 100 },
  [291] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 395 }, ["initialAmount"] = 100 },
  [292] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 396 }, ["initialAmount"] = 100 },
  [293] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 397 }, ["initialAmount"] = 100 },
  [294] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 4 }, ["initialAmount"] = 100 },
  [295] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 403 }, ["initialAmount"] = 100 },
  [296] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 405 }, ["initialAmount"] = 100 },
  [297] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 409 }, ["initialAmount"] = 100 },
  [298] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 410 }, ["initialAmount"] = 100 },
  [299] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 412 }, ["initialAmount"] = 100 },
  [300] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 425 }, ["initialAmount"] = 100 },
  [301] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 426 }, ["initialAmount"] = 100 },
  [302] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 429 }, ["initialAmount"] = 100 },
  [303] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 446 }, ["initialAmount"] = 100 },
  [304] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 7 }, ["initialAmount"] = 100 },
  [305] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 7, [4] = 9 }, ["initialAmount"] = 100 },
  [306] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 11031 }, ["initialAmount"] = 100 },
  [307] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 11035 }, ["initialAmount"] = 100 },
  [308] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 11040 }, ["initialAmount"] = 100 },
  [309] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 11050 }, ["initialAmount"] = 100 },
  [310] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 11051 }, ["initialAmount"] = 100 },
  [311] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 11052 }, ["initialAmount"] = 100 },
  [312] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 11053 }, ["initialAmount"] = 100 },
  [313] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 11054 }, ["initialAmount"] = 100 },
  [314] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 11092 }, ["initialAmount"] = 100 },
  [315] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 11093 }, ["initialAmount"] = 100 },
  [316] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 130 }, ["initialAmount"] = 100 },
  [317] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 132 }, ["initialAmount"] = 100 },
  [318] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 133 }, ["initialAmount"] = 100 },
  [319] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 138 }, ["initialAmount"] = 100 },
  [320] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 139 }, ["initialAmount"] = 100 },
  [321] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 263 }, ["initialAmount"] = 100 },
  [322] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 264 }, ["initialAmount"] = 100 },
  [323] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 271 }, ["initialAmount"] = 100 },
  [324] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 272 }, ["initialAmount"] = 100 },
  [325] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 273 }, ["initialAmount"] = 100 },
  [326] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 274 }, ["initialAmount"] = 100 },
  [327] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 278 }, ["initialAmount"] = 100 },
  [328] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 279 }, ["initialAmount"] = 100 },
  [329] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 280 }, ["initialAmount"] = 100 },
  [330] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 281 }, ["initialAmount"] = 100 },
  [331] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 282 }, ["initialAmount"] = 100 },
  [332] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 283 }, ["initialAmount"] = 100 },
  [333] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 284 }, ["initialAmount"] = 100 },
  [334] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 287 }, ["initialAmount"] = 100 },
  [335] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 289 }, ["initialAmount"] = 100 },
  [336] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 290 }, ["initialAmount"] = 100 },
  [337] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 292 }, ["initialAmount"] = 100 },
  [338] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 293 }, ["initialAmount"] = 100 },
  [339] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 295 }, ["initialAmount"] = 100 },
  [340] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 296 }, ["initialAmount"] = 100 },
  [341] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 297 }, ["initialAmount"] = 100 },
  [342] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 298 }, ["initialAmount"] = 100 },
  [343] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 301 }, ["initialAmount"] = 100 },
  [344] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 303 }, ["initialAmount"] = 100 },
  [345] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 304 }, ["initialAmount"] = 100 },
  [346] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 305 }, ["initialAmount"] = 100 },
  [347] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 311 }, ["initialAmount"] = 100 },
  [348] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 332 }, ["initialAmount"] = 100 },
  [349] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 352 }, ["initialAmount"] = 100 },
  [350] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 353 }, ["initialAmount"] = 100 },
  [351] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 354 }, ["initialAmount"] = 100 },
  [352] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 355 }, ["initialAmount"] = 100 },
  [353] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 362 }, ["initialAmount"] = 100 },
  [354] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 363 }, ["initialAmount"] = 100 },
  [355] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 373 }, ["initialAmount"] = 100 },
  [356] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 39 }, ["initialAmount"] = 100 },
  [357] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 399 }, ["initialAmount"] = 100 },
  [358] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 40 }, ["initialAmount"] = 100 },
  [359] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 407 }, ["initialAmount"] = 100 },
  [360] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 41 }, ["initialAmount"] = 100 },
  [361] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 415 }, ["initialAmount"] = 100 },
  [362] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 416 }, ["initialAmount"] = 100 },
  [363] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 422 }, ["initialAmount"] = 100 },
  [364] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 423 }, ["initialAmount"] = 100 },
  [365] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 424 }, ["initialAmount"] = 100 },
  [366] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 430 }, ["initialAmount"] = 100 },
  [367] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 431 }, ["initialAmount"] = 100 },
  [368] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 432 }, ["initialAmount"] = 100 },
  [369] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 433 }, ["initialAmount"] = 100 },
  [370] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 434 }, ["initialAmount"] = 100 },
  [371] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 435 }, ["initialAmount"] = 100 },
  [372] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 436 }, ["initialAmount"] = 100 },
  [373] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 437 }, ["initialAmount"] = 100 },
  [374] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 44 }, ["initialAmount"] = 100 },
  [375] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 443 }, ["initialAmount"] = 100 },
  [376] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 445 }, ["initialAmount"] = 100 },
  [377] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 45 }, ["initialAmount"] = 100 },
  [378] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 46 }, ["initialAmount"] = 100 },
  [379] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 47 }, ["initialAmount"] = 100 },
  [380] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 48 }, ["initialAmount"] = 100 },
  [381] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 49 }, ["initialAmount"] = 100 },
  [382] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 51 }, ["initialAmount"] = 100 },
  [383] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 53 }, ["initialAmount"] = 100 },
  [384] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 54 }, ["initialAmount"] = 100 },
  [385] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 55 }, ["initialAmount"] = 100 },
  [386] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 56 }, ["initialAmount"] = 100 },
  [387] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 58 }, ["initialAmount"] = 100 },
  [388] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 59 }, ["initialAmount"] = 100 },
  [389] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 60 }, ["initialAmount"] = 100 },
  [390] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 61 }, ["initialAmount"] = 100 },
  [391] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 62 }, ["initialAmount"] = 100 },
  [392] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 63 }, ["initialAmount"] = 100 },
  [393] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 64 }, ["initialAmount"] = 100 },
  [394] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 65 }, ["initialAmount"] = 100 },
  [395] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 66 }, ["initialAmount"] = 100 },
  [396] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 68 }, ["initialAmount"] = 100 },
  [397] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 70 }, ["initialAmount"] = 100 },
  [398] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 71 }, ["initialAmount"] = 100 },
  [399] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 72 }, ["initialAmount"] = 100 },
  [400] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 73 }, ["initialAmount"] = 100 },
  [401] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 74 }, ["initialAmount"] = 100 },
  [402] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 75 }, ["initialAmount"] = 100 },
  [403] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 76 }, ["initialAmount"] = 100 },
  [404] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 77 }, ["initialAmount"] = 100 },
  [405] = { ["wsType"] = { [1] = 4, [2] = 4, [3] = 8, [4] = 78 }, ["initialAmount"] = 100 },
  [406] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 1000 }, ["initialAmount"] = 100 },
  [407] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 1002 }, ["initialAmount"] = 100 },
  [408] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 1003 }, ["initialAmount"] = 100 },
  [409] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 1004 }, ["initialAmount"] = 100 },
  [410] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 1005 }, ["initialAmount"] = 100 },
  [411] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 1006 }, ["initialAmount"] = 100 },
  [412] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 1007 }, ["initialAmount"] = 100 },
  [413] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 1009 }, ["initialAmount"] = 100 },
  [414] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 2558 }, ["initialAmount"] = 100 },
  [415] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 2559 }, ["initialAmount"] = 100 },
  [416] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 2560 }, ["initialAmount"] = 100 },
  [417] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 2561 }, ["initialAmount"] = 100 },
  [418] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 2562 }, ["initialAmount"] = 100 },
  [419] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 2563 }, ["initialAmount"] = 100 },
  [420] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 837 }, ["initialAmount"] = 100 },
  [421] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 839 }, ["initialAmount"] = 100 },
  [422] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 94 }, ["initialAmount"] = 100 },
  [423] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 95 }, ["initialAmount"] = 100 },
  [424] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 32, [4] = 999 }, ["initialAmount"] = 100 },
  [425] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 11 }, ["initialAmount"] = 100 },
  [426] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 12 }, ["initialAmount"] = 100 },
  [427] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 14 }, ["initialAmount"] = 100 },
  [428] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 287 }, ["initialAmount"] = 100 },
  [429] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 288 }, ["initialAmount"] = 100 },
  [430] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 289 }, ["initialAmount"] = 100 },
  [431] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 290 }, ["initialAmount"] = 100 },
  [432] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 291 }, ["initialAmount"] = 100 },
  [433] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 292 }, ["initialAmount"] = 100 },
  [434] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 293 }, ["initialAmount"] = 100 },
  [435] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 351 }, ["initialAmount"] = 100 },
  [436] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 36 }, ["initialAmount"] = 100 },
  [437] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 38 }, ["initialAmount"] = 100 },
  [438] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 39 }, ["initialAmount"] = 100 },
  [439] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 41 }, ["initialAmount"] = 100 },
  [440] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 42 }, ["initialAmount"] = 100 },
  [441] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 43 }, ["initialAmount"] = 100 },
  [442] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 448 }, ["initialAmount"] = 100 },
  [443] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 459 }, ["initialAmount"] = 100 },
  [444] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 469 }, ["initialAmount"] = 100 },
  [445] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 47 }, ["initialAmount"] = 100 },
  [446] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 476 }, ["initialAmount"] = 100 },
  [447] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 48 }, ["initialAmount"] = 100 },
  [448] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 72 }, ["initialAmount"] = 100 },
  [449] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 85 }, ["initialAmount"] = 100 },
  [450] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 86 }, ["initialAmount"] = 100 },
  [451] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 36, [4] = 92 }, ["initialAmount"] = 100 },
  [452] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 37, [4] = 3 }, ["initialAmount"] = 100 },
  [453] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 37, [4] = 330 }, ["initialAmount"] = 100 },
  [454] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 37, [4] = 347 }, ["initialAmount"] = 100 },
  [455] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 37, [4] = 384 }, ["initialAmount"] = 100 },
  [456] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 37, [4] = 4 }, ["initialAmount"] = 100 },
  [457] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 37, [4] = 437 }, ["initialAmount"] = 100 },
  [458] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 37, [4] = 62 }, ["initialAmount"] = 100 },
  [459] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 18 }, ["initialAmount"] = 100 },
  [460] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 20 }, ["initialAmount"] = 100 },
  [461] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 23 }, ["initialAmount"] = 100 },
  [462] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 263 }, ["initialAmount"] = 100 },
  [463] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 265 }, ["initialAmount"] = 100 },
  [464] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 267 }, ["initialAmount"] = 100 },
  [465] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 295 }, ["initialAmount"] = 100 },
  [466] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 299 }, ["initialAmount"] = 100 },
  [467] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 301 }, ["initialAmount"] = 100 },
  [468] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 302 }, ["initialAmount"] = 100 },
  [469] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 319 }, ["initialAmount"] = 100 },
  [470] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 324 }, ["initialAmount"] = 100 },
  [471] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 35 }, ["initialAmount"] = 100 },
  [472] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 45 }, ["initialAmount"] = 100 },
  [473] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 480 }, ["initialAmount"] = 100 },
  [474] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 481 }, ["initialAmount"] = 100 },
  [475] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 482 }, ["initialAmount"] = 100 },
  [476] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 77 }, ["initialAmount"] = 100 },
  [477] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 87 }, ["initialAmount"] = 100 },
  [478] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 88 }, ["initialAmount"] = 100 },
  [479] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 91 }, ["initialAmount"] = 100 },
  [480] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 38, [4] = 93 }, ["initialAmount"] = 100 },
  [481] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 49, [4] = 11086 }, ["initialAmount"] = 100 },
  [482] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 49, [4] = 11087 }, ["initialAmount"] = 100 },
  [483] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 49, [4] = 11088 }, ["initialAmount"] = 100 },
  [484] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 49, [4] = 11089 }, ["initialAmount"] = 100 },
  [485] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 49, [4] = 427 }, ["initialAmount"] = 100 },
  [486] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 49, [4] = 63 }, ["initialAmount"] = 100 },
  [487] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 49, [4] = 64 }, ["initialAmount"] = 100 },
  [488] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 11033 }, ["initialAmount"] = 100 },
  [489] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 11034 }, ["initialAmount"] = 100 },
  [490] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 255 }, ["initialAmount"] = 100 },
  [491] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 256 }, ["initialAmount"] = 100 },
  [492] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 257 }, ["initialAmount"] = 100 },
  [493] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 258 }, ["initialAmount"] = 100 },
  [494] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 259 }, ["initialAmount"] = 100 },
  [495] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 260 }, ["initialAmount"] = 100 },
  [496] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 261 }, ["initialAmount"] = 100 },
  [497] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 268 }, ["initialAmount"] = 100 },
  [498] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 269 }, ["initialAmount"] = 100 },
  [499] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 270 }, ["initialAmount"] = 100 },
  [500] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 271 }, ["initialAmount"] = 100 },
  [501] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 272 }, ["initialAmount"] = 100 },
  [502] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 273 }, ["initialAmount"] = 100 },
  [503] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 274 }, ["initialAmount"] = 100 },
  [504] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 275 }, ["initialAmount"] = 100 },
  [505] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 276 }, ["initialAmount"] = 100 },
  [506] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 277 }, ["initialAmount"] = 100 },
  [507] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 278 }, ["initialAmount"] = 100 },
  [508] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 279 }, ["initialAmount"] = 100 },
  [509] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 280 }, ["initialAmount"] = 100 },
  [510] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 281 }, ["initialAmount"] = 100 },
  [511] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 282 }, ["initialAmount"] = 100 },
  [512] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 283 }, ["initialAmount"] = 100 },
  [513] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 284 }, ["initialAmount"] = 100 },
  [514] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 285 }, ["initialAmount"] = 100 },
  [515] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 30 }, ["initialAmount"] = 100 },
  [516] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 31 }, ["initialAmount"] = 100 },
  [517] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 312 }, ["initialAmount"] = 100 },
  [518] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 313 }, ["initialAmount"] = 100 },
  [519] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 314 }, ["initialAmount"] = 100 },
  [520] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 315 }, ["initialAmount"] = 100 },
  [521] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 316 }, ["initialAmount"] = 100 },
  [522] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 317 }, ["initialAmount"] = 100 },
  [523] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 318 }, ["initialAmount"] = 100 },
  [524] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 32 }, ["initialAmount"] = 100 },
  [525] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 321 }, ["initialAmount"] = 100 },
  [526] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 322 }, ["initialAmount"] = 100 },
  [527] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 323 }, ["initialAmount"] = 100 },
  [528] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 325 }, ["initialAmount"] = 100 },
  [529] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 326 }, ["initialAmount"] = 100 },
  [530] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 327 }, ["initialAmount"] = 100 },
  [531] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 328 }, ["initialAmount"] = 100 },
  [532] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 329 }, ["initialAmount"] = 100 },
  [533] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 33 }, ["initialAmount"] = 100 },
  [534] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 331 }, ["initialAmount"] = 100 },
  [535] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 332 }, ["initialAmount"] = 100 },
  [536] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 333 }, ["initialAmount"] = 100 },
  [537] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 334 }, ["initialAmount"] = 100 },
  [538] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 335 }, ["initialAmount"] = 100 },
  [539] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 336 }, ["initialAmount"] = 100 },
  [540] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 337 }, ["initialAmount"] = 100 },
  [541] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 338 }, ["initialAmount"] = 100 },
  [542] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 339 }, ["initialAmount"] = 100 },
  [543] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 34 }, ["initialAmount"] = 100 },
  [544] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 363 }, ["initialAmount"] = 100 },
  [545] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 364 }, ["initialAmount"] = 100 },
  [546] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 374 }, ["initialAmount"] = 100 },
  [547] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 38 }, ["initialAmount"] = 100 },
  [548] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 385 }, ["initialAmount"] = 100 },
  [549] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 386 }, ["initialAmount"] = 100 },
  [550] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 387 }, ["initialAmount"] = 100 },
  [551] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 388 }, ["initialAmount"] = 100 },
  [552] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 389 }, ["initialAmount"] = 100 },
  [553] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 390 }, ["initialAmount"] = 100 },
  [554] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 391 }, ["initialAmount"] = 100 },
  [555] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 392 }, ["initialAmount"] = 100 },
  [556] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 412 }, ["initialAmount"] = 100 },
  [557] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 413 }, ["initialAmount"] = 100 },
  [558] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 449 }, ["initialAmount"] = 100 },
  [559] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 483 }, ["initialAmount"] = 100 },
  [560] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 484 }, ["initialAmount"] = 100 },
  [561] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 485 }, ["initialAmount"] = 100 },
  [562] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 486 }, ["initialAmount"] = 100 },
  [563] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 487 }, ["initialAmount"] = 100 },
  [564] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 488 }, ["initialAmount"] = 100 },
  [565] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 5 }, ["initialAmount"] = 100 },
  [566] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 6 }, ["initialAmount"] = 100 },
  [567] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 69 }, ["initialAmount"] = 100 },
  [568] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 7 }, ["initialAmount"] = 100 },
  [569] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 70 }, ["initialAmount"] = 100 },
  [570] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 71 }, ["initialAmount"] = 100 },
  [571] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 72 }, ["initialAmount"] = 100 },
  [572] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 75 }, ["initialAmount"] = 100 },
  [573] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 79 }, ["initialAmount"] = 100 },
  [574] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 9 }, ["initialAmount"] = 100 },
  [575] = { ["wsType"] = { [1] = 4, [2] = 5, [3] = 9, [4] = 90 }, ["initialAmount"] = 100 },
  [576] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 32, [4] = 11048 }, ["initialAmount"] = 100 },
  [577] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 32, [4] = 11056 }, ["initialAmount"] = 100 },
  [578] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 32, [4] = 11090 }, ["initialAmount"] = 100 },
  [579] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 32, [4] = 619 }, ["initialAmount"] = 100 },
  [580] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 32, [4] = 659 }, ["initialAmount"] = 100 },
  [581] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 32, [4] = 661 }, ["initialAmount"] = 100 },
  [582] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 11044 }, ["initialAmount"] = 100 },
  [583] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 11049 }, ["initialAmount"] = 100 },
  [584] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 11091 }, ["initialAmount"] = 100 },
  [585] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 144 }, ["initialAmount"] = 100 },
  [586] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 145 }, ["initialAmount"] = 100 },
  [587] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 146 }, ["initialAmount"] = 100 },
  [588] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 147 }, ["initialAmount"] = 100 },
  [589] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 148 }, ["initialAmount"] = 100 },
  [590] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 149 }, ["initialAmount"] = 100 },
  [591] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 150 }, ["initialAmount"] = 100 },
  [592] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 151 }, ["initialAmount"] = 100 },
  [593] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 155 }, ["initialAmount"] = 100 },
  [594] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 158 }, ["initialAmount"] = 100 },
  [595] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 159 }, ["initialAmount"] = 100 },
  [596] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 181 }, ["initialAmount"] = 100 },
  [597] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 182 }, ["initialAmount"] = 100 },
  [598] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 183 }, ["initialAmount"] = 100 },
  [599] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 184 }, ["initialAmount"] = 100 },
  [600] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 185 }, ["initialAmount"] = 100 },
  [601] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 186 }, ["initialAmount"] = 100 },
  [602] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 256 }, ["initialAmount"] = 100 },
  [603] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 257 }, ["initialAmount"] = 100 },
  [604] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 258 }, ["initialAmount"] = 100 },
  [605] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 275 }, ["initialAmount"] = 100 },
  [606] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 276 }, ["initialAmount"] = 100 },
  [607] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 277 }, ["initialAmount"] = 100 },
  [608] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 299 }, ["initialAmount"] = 100 },
  [609] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 30 }, ["initialAmount"] = 100 },
  [610] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 31 }, ["initialAmount"] = 100 },
  [611] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 32 }, ["initialAmount"] = 100 },
  [612] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 326 }, ["initialAmount"] = 100 },
  [613] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 329 }, ["initialAmount"] = 100 },
  [614] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 33 }, ["initialAmount"] = 100 },
  [615] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 330 }, ["initialAmount"] = 100 },
  [616] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 331 }, ["initialAmount"] = 100 },
  [617] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 34 }, ["initialAmount"] = 100 },
  [618] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 340 }, ["initialAmount"] = 100 },
  [619] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 341 }, ["initialAmount"] = 100 },
  [620] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 342 }, ["initialAmount"] = 100 },
  [621] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 35 }, ["initialAmount"] = 100 },
  [622] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 350 }, ["initialAmount"] = 100 },
  [623] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 359 }, ["initialAmount"] = 100 },
  [624] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 360 }, ["initialAmount"] = 100 },
  [625] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 361 }, ["initialAmount"] = 100 },
  [626] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 364 }, ["initialAmount"] = 100 },
  [627] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 365 }, ["initialAmount"] = 100 },
  [628] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 366 }, ["initialAmount"] = 100 },
  [629] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 367 }, ["initialAmount"] = 100 },
  [630] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 37 }, ["initialAmount"] = 100 },
  [631] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 374 }, ["initialAmount"] = 100 },
  [632] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 375 }, ["initialAmount"] = 100 },
  [633] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 376 }, ["initialAmount"] = 100 },
  [634] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 377 }, ["initialAmount"] = 100 },
  [635] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 378 }, ["initialAmount"] = 100 },
  [636] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 379 }, ["initialAmount"] = 100 },
  [637] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 380 }, ["initialAmount"] = 100 },
  [638] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 381 }, ["initialAmount"] = 100 },
  [639] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 382 }, ["initialAmount"] = 100 },
  [640] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 383 }, ["initialAmount"] = 100 },
  [641] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 384 }, ["initialAmount"] = 100 },
  [642] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 385 }, ["initialAmount"] = 100 },
  [643] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 386 }, ["initialAmount"] = 100 },
  [644] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 387 }, ["initialAmount"] = 100 },
  [645] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 388 }, ["initialAmount"] = 100 },
  [646] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 389 }, ["initialAmount"] = 100 },
  [647] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 390 }, ["initialAmount"] = 100 },
  [648] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 391 }, ["initialAmount"] = 100 },
  [649] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 392 }, ["initialAmount"] = 100 },
  [650] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 393 }, ["initialAmount"] = 100 },
  [651] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 401 }, ["initialAmount"] = 100 },
  [652] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 402 }, ["initialAmount"] = 100 },
  [653] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 440 }, ["initialAmount"] = 100 },
  [654] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 441 }, ["initialAmount"] = 100 },
  [655] = { ["wsType"] = { [1] = 4, [2] = 7, [3] = 33, [4] = 442 }, ["initialAmount"] = 100 },
  [656] = { ["wsType"] = { [1] = 4, [2] = 8, [3] = 10, [4] = 255 }, ["initialAmount"] = 100 },
  [657] = { ["wsType"] = { [1] = 4, [2] = 8, [3] = 10, [4] = 406 }, ["initialAmount"] = 100 },
  [658] = { ["wsType"] = { [1] = 4, [2] = 8, [3] = 11, [4] = 319 }, ["initialAmount"] = 100 },
  [659] = { ["wsType"] = { [1] = 4, [2] = 8, [3] = 11, [4] = 398 }, ["initialAmount"] = 100 },
}

---Add everything to the FARP warehouse; since 2.8.x, the FARPs spawn empty, hence making it impossible to rearm or refuel (even with all the necessary vehicles)
---@param farp any the FARP to be filled
function veafGrass.fillFarpWarehouse(farp)
  veaf.loggers.get(veafGrass.Id):debug("veafGrass.fillFarpWarehouse()")
  veaf.loggers.get(veafGrass.Id):trace("farp=[%s]", veaf.lp(farp))
  local farpName = farp.name
  veaf.loggers.get(veafGrass.Id):trace("farpName=[%s]", veaf.lp(farpName))
  local result = farpName ~= nil
  if not result then
    result, farpName = pcall(Unit.getUnitName, farp)
  end
  veaf.loggers.get(veafGrass.Id):trace("farpName=[%s]", veaf.lp(farpName))
  if not result then
    result, farpName = pcall(Group.getGroupName, farp)
  end
  veaf.loggers.get(veafGrass.Id):trace("farpName=[%s]", veaf.lp(farpName))
  if not result then
    result, farpName = pcall(Object.getName, farp)
  end
  veaf.loggers.get(veafGrass.Id):trace("farpName=[%s]", veaf.lp(farpName))
  if farpName then
    local farpAirbase = Airbase.getByName(farpName)
    if farpAirbase then
      local farpWarehouse = farpAirbase:getWarehouse()
      if farpWarehouse then
        --veaf.loggers.get(veafGrass.Id):trace("inventory = %s", veaf.p(farpWarehouse:getInventory()))
        for _, datas in ipairs(veafGrass.WAREHOUSE_ITEMS) do
          local rnd = math.random(1, 100)
          farpWarehouse:setItem(datas.wsType, 5000 + rnd)
        end
        for i = 0, 3, 1 do
          local rnd = math.random(1, 100)
          farpWarehouse:setLiquidAmount(i, 50000 + rnd)
        end
        for i = 0, 3 do
          veaf.loggers.get(veafGrass.Id):trace("getLiquidAmount(%s) = %s", i, veaf.lp(farpWarehouse:getLiquidAmount(i)))
        end
        for _, aircraft_type in pairs(veafGrass.helicoptersOnFARPs) do
          farpWarehouse:addItem(aircraft_type, 999)
        end
      else
        veaf.loggers.get(veafGrass.Id):error("Airbase.getByName([%s]):getWarehouse() returned null", veaf.p(farpName))
      end
    else
      veaf.loggers.get(veafGrass.Id):error("Airbase.getByName([%s]) returned null", veaf.p(farpName))
    end
    veaf.loggers.get(veafGrass.Id):debug("FARP [%s] successfully replenished", veaf.lp(farpName))
  end
end

------------------------------------------------------------------------------
-- Spawn the ground unit that carries a FARP's TACAN.
--
-- A TACAN needs a group to receive the ActivateBeacon command; the unit type
-- (`TACAN_beacon`) is the same one CTLD uses for its own beacons. CTLD v1 exposed
-- ctld.spawnRadioBeaconUnit and VEAF borrowed it, but this is plain DCS spawning with
-- nothing CTLD about it — and CTLD 2 keeps its equivalent private, rightly so.
--
-- @param point vec3 : where to put it
-- @param country : the FARP's country (name or id, as mist.dynAdd accepts)
-- @param displayName string : shown in the unit name, so a pilot reading the F10 map
--                             sees the channel
-- @return Group or nil
------------------------------------------------------------------------------
function veafGrass.spawnTacanCarrierUnit(point, country, displayName)
  local groupName = string.format("VEAF TACAN carrier - %s", displayName)
  local spawned = mist.dynAdd({
    country = country,
    category = "GROUND_UNIT",
    groupName = groupName,
    hidden = true,
    units = {
      {
        type = "TACAN_beacon",
        name = groupName,
        x = point.x,
        y = point.z, -- DCS ground unit: mission y is world z
        heading = 0,
        skill = "Excellent",
      },
    },
  })
  if not spawned then
    return nil
  end
  return Group.getByName(spawned.name)
end

------------------------------------------------------------------------------
-- Normalize a FARP coalition, given either as a number or as a name.
--
-- VMR-022: this lived inline as two guards written `if type(x == "number") then`. The closing
-- parenthesis is misplaced, so each evaluated `type(boolean)` — always the string "boolean",
-- always truthy — and **both blocks always ran**.
--
-- That was not merely dead code. With both executing in order, a coalition arriving as the
-- string "red" failed the `== 1` test in the first block, fell into its `else`, and came out
-- **blue**: the FARP was built for the wrong side. Extracted here so the behaviour is testable
-- rather than buried in a 200-line builder.
--
-- @param coalition number (1 = red) or string ("red"/"blue")
-- @return string the coalition name, string the coalition number
------------------------------------------------------------------------------
function veafGrass._normalizeFarpCoalition(coalition)
  -- Anything that is not red is blue, for the name as well as the number. The two must agree:
  -- returning an unrecognised name alongside the blue number would hand the builder a coalition
  -- string DCS does not know, which is a worse failure than the one being fixed. "Not red means
  -- blue" is also what the old code did, albeit by accident.
  local isRed = (coalition == 1) or (coalition == "red")
  return isRed and "red" or "blue", isRed and 1 or 2
end

------------------------------------------------------------------------------
-- build nice FARP units arround the FARP
-- @param unit farp : the FARP unit
------------------------------------------------------------------------------
function veafGrass.buildFarpUnits(farp, grassRunwayUnits, groupName, hiddenOnMFD, noFarpMarkers, code, freq, mod)
  veaf.loggers.get(veafGrass.Id):debug("buildFarpUnits()")
  veaf.loggers.get(veafGrass.Id):trace("farp=%s", farp)
  veaf.loggers.get(veafGrass.Id):trace("grassRunwayUnits=%s", grassRunwayUnits)
  veaf.loggers.get(veafGrass.Id):trace("hiddenOnMFD=%s", hiddenOnMFD)
  veaf.loggers.get(veafGrass.Id):trace("noFarpMarkers=%s", noFarpMarkers)
  veaf.loggers.get(veafGrass.Id):trace("code=%s", code)
  veaf.loggers.get(veafGrass.Id):trace("freq=%s", freq)
  veaf.loggers.get(veafGrass.Id):trace("mod=%s", mod)

  local freq = freq or math.random(90) + 100
  local mod = mod or "X"
  local code = code or "FRP"

  -- add FARP to CTLD FOBs and logistic units
  local name = farp.name
  if not name then
    name = farp.unitName
  end
  if not name then
    name = farp.groupName
  end
  if veaf.isCtldReady() then
    -- CTLD 2 owns its FOB list (CTLDFOBManager), so only the logistic zone is ours to
    -- declare. It is anchored to the FARP's position rather than to a unit: the FARP is a
    -- set of statics, not a single object to follow.
    local farpPoint = { x = farp.x, y = math.floor(land.getHeight(farp) + 1), z = farp.y }
    CTLDZoneManager.getInstance():registerFOBAsLogistic(name, farpPoint, nil, farp.coalition)
  end

  local farpUnitNameCounter = 1
  local farpCoalition, farpCoalitionNumber = veafGrass._normalizeFarpCoalition(farp.coalition)

  local farpHeading = farp.heading or 0
  local angle = mist.utils.toDegree(farpHeading)
  local tentDistance = 100
  local tentSpacing = 30
  local otherDistance = 85
  local otherSpacing = 15
  local unitsDistance = 75

  -- fix distances on FARPs
  if veafGrass.isFarpPlatformType(farp.type) then
    tentDistance = 200
    unitsDistance = 150
    otherDistance = 130
  end

  -- Same treatment as the escort below (#232): the tents are laid out by the identical fixed-distance
  -- formula, so they can land on an obstacle just as the escort did. The original bearing is tried
  -- first, so a FARP with clear ground around it is laid out exactly where it always was.
  local function tentPositionsAt(bearing)
    local origin = {
      x = farp.x + tentDistance * math.cos(mist.utils.toRadian(bearing)),
      y = farp.y + tentDistance * math.sin(mist.utils.toRadian(bearing)),
    }
    local positions = {}
    for j = 1, 2 do
      for i = 1, 3 do
        table.insert(positions, {
          x = origin.x + (i - 1) * tentSpacing * math.cos(mist.utils.toRadian(bearing)) - (j - 1) * tentSpacing * math.sin(
            mist.utils.toRadian(bearing)
          ),
          y = origin.y + (i - 1) * tentSpacing * math.sin(mist.utils.toRadian(bearing)) + (j - 1) * tentSpacing * math.cos(
            mist.utils.toRadian(bearing)
          ),
        })
      end
    end
    return positions
  end

  local tentAngle = veafGrass.findClearBearing(angle, tentPositionsAt)
  local tentPositions = tentPositionsAt(tentAngle)

  -- create tents
  for index = 1, #tentPositions do
    local tent = {
      ["unitName"] = string.format("FARP %s unit #%d", farp.groupName, farpUnitNameCounter),
      ["category"] = "static",
      ["categoryStatic"] = "Fortifications",
      ["coalition"] = farpCoalition,
      ["country"] = farp.country,
      ["countryId"] = farp.countryId,
      ["heading"] = mist.utils.toRadian(tentAngle - 90),
      ["type"] = "FARP Tent",
      ["x"] = tentPositions[index].x,
      ["y"] = tentPositions[index].y,
      ["hiddenOnMFD"] = hiddenOnMFD,
    }
    if groupName then
      tent["groupName"] = groupName
    end

    mist.dynAddStatic(tent)
    farpUnitNameCounter = farpUnitNameCounter + 1
  end

  -- add visible markers to the invisible farps
  if farp.type == "Invisible FARP" and not noFarpMarkers then
    local markerDistance = 25
    local markerAngle = -45
    local markerUnit1 = {
      ["unitName"] = string.format("FARP %s unit #%d", farp.groupName, farpUnitNameCounter),
      ["category"] = "Unarmed",
      ["type"] = "M978 HEMTT Tanker",
      ["coalition"] = farpCoalition,
      ["country"] = farp.country,
      ["countryId"] = farp.countryId,
      ["heading"] = mist.utils.toRadian(angle - 90),
      ["x"] = farp.x - markerDistance * math.cos(mist.utils.toRadian(angle + markerAngle)),
      ["y"] = farp.y - markerDistance * math.sin(mist.utils.toRadian(angle + markerAngle)),
      ["hiddenOnMFD"] = hiddenOnMFD,
    }
    if groupName then
      markerUnit1["groupName"] = groupName
    end
    mist.dynAddStatic(markerUnit1)
    farpUnitNameCounter = farpUnitNameCounter + 1
    local markerUnit2 = {
      ["unitName"] = string.format("FARP %s unit #%d", farp.groupName, farpUnitNameCounter),
      ["category"] = "Fortifications",
      ["shape_name"] = "H-Windsock_RW",
      ["type"] = "Windsock",
      ["coalition"] = farpCoalition,
      ["country"] = farp.country,
      ["countryId"] = farp.countryId,
      ["heading"] = mist.utils.toRadian(angle - 90),
      ["x"] = farp.x - markerDistance * math.cos(mist.utils.toRadian(angle - markerAngle)),
      ["y"] = farp.y - markerDistance * math.sin(mist.utils.toRadian(angle - markerAngle)),
      ["hiddenOnMFD"] = hiddenOnMFD,
    }
    if groupName then
      markerUnit2["groupName"] = groupName
    end
    mist.dynAddStatic(markerUnit2)
    farpUnitNameCounter = farpUnitNameCounter + 1
  end

  -- spawn other static units
  local otherUnits = {
    "FARP Fuel Depot",
    "FARP Ammo Dump Coating",
    "GeneratorF",
  }
  -- Same fixed-distance formula as the tents and the escort, so same treatment (#232).
  local function otherPositionsAt(bearing)
    local origin = {
      x = farp.x + otherDistance * math.cos(mist.utils.toRadian(bearing)),
      y = farp.y + otherDistance * math.sin(mist.utils.toRadian(bearing)),
    }
    local positions = {}
    for j = 1, #otherUnits do
      table.insert(positions, {
        x = origin.x - (j - 1) * otherSpacing * math.sin(mist.utils.toRadian(bearing)),
        y = origin.y + (j - 1) * otherSpacing * math.cos(mist.utils.toRadian(bearing)),
      })
    end
    return positions
  end

  local otherAngle = veafGrass.findClearBearing(angle, otherPositionsAt)
  local otherPositions = otherPositionsAt(otherAngle)

  for j, typeName in ipairs(otherUnits) do
    local otherUnit = {
      ["unitName"] = string.format("FARP %s unit #%d", farp.groupName, farpUnitNameCounter),
      ["category"] = "static",
      ["categoryStatic"] = "Fortifications",
      ["coalition"] = farpCoalition,
      ["country"] = farp.country,
      ["countryId"] = farp.countryId,
      ["heading"] = mist.utils.toRadian(otherAngle - 90),
      ["type"] = typeName,
      ["x"] = otherPositions[j].x,
      ["y"] = otherPositions[j].y,
      ["hiddenOnMFD"] = hiddenOnMFD,
    }
    if groupName then
      otherUnit["groupName"] = groupName
    end
    mist.dynAddStatic(otherUnit)
    farpUnitNameCounter = farpUnitNameCounter + 1
  end

  -- create Windsock
  local windsockDistance = 50
  local windsockAngle = 45

  -- fix Windsock position on FARPs
  if veafGrass.isFarpPlatformType(farp.type) then
    windsockDistance = 120
    windsockAngle = 0
  end

  local windsockUnit = {
    ["unitName"] = string.format("FARP %s unit #%d", farp.groupName, farpUnitNameCounter),
    ["category"] = "static",
    ["categoryStatic"] = "Fortifications",
    ["shape_name"] = "H-Windsock_RW",
    ["type"] = "Windsock",
    ["coalition"] = farpCoalition,
    ["country"] = farp.country,
    ["countryId"] = farp.countryId,
    ["heading"] = mist.utils.toRadian(angle - 90),
    ["x"] = farp.x + windsockDistance * math.cos(mist.utils.toRadian(angle + windsockAngle)),
    ["y"] = farp.y + windsockDistance * math.sin(mist.utils.toRadian(angle + windsockAngle)),
    ["hiddenOnMFD"] = hiddenOnMFD,
  }
  if groupName then
    windsockUnit["groupName"] = groupName
  end
  mist.dynAddStatic(windsockUnit)
  farpUnitNameCounter = farpUnitNameCounter + 1

  -- on FARP unit, place a second windsock, at 90°
  if farp.type == "FARP" then
    local windsockUnit = {
      ["unitName"] = string.format("FARP %s unit #%d", farp.groupName, farpUnitNameCounter),
      ["category"] = "static",
      ["categoryStatic"] = "Fortifications",
      ["shape_name"] = "H-Windsock_RW",
      ["type"] = "Windsock",
      ["coalition"] = farpCoalition,
      ["country"] = farp.country,
      ["countryId"] = farp.countryId,
      ["heading"] = mist.utils.toRadian(angle - 90),
      ["x"] = farp.x + windsockDistance * math.cos(mist.utils.toRadian(angle + windsockAngle - 90)),
      ["y"] = farp.y + windsockDistance * math.sin(mist.utils.toRadian(angle + windsockAngle - 90)),
      ["hiddenOnMFD"] = hiddenOnMFD,
    }
    if groupName then
      windsockUnit["groupName"] = groupName
    end
    mist.dynAddStatic(windsockUnit)
    farpUnitNameCounter = farpUnitNameCounter + 1
  end

  -- spawn a FARP escort group
  local farpEscortUnitsNames = {
    blue = {
      "Hummer",
      "M978 HEMTT Tanker",
      "M 818",
      "M 818",
      "Hummer",
    },
    red = {
      "ATZ-10",
      "ATZ-10",
      "Ural-4320 APA-5D",
      "Ural-375",
      "Ural-375",
      "Ural-375 PBU",
    },
  }

  local unitsSpacing = 6

  -- #232: the escort's position used to be this formula and nothing else — a fixed distance on a fixed
  -- bearing, with no test of whether that spot was free. Beside a static FARP, which is the *nominal*
  -- use (the static FARP is what unlocks spawning on it once the zone is captured), the trucks came
  -- down on its pads. Keeping the radius and walking the bearing instead, per David's arbitration:
  -- growing the radius would push the escort away from the FARP it serves.
  -- The whole group is tested, not its origin: these vehicles sit on a ~30 m line perpendicular to the
  -- bearing, so a clear origin with an overlapping tail would still block a helipad.
  local escortUnitTypes = farpEscortUnitsNames[farpCoalition]
  local function escortPositionsAt(bearing)
    local origin = {
      x = farp.x + unitsDistance * math.cos(mist.utils.toRadian(bearing)),
      y = farp.y + unitsDistance * math.sin(mist.utils.toRadian(bearing)),
    }
    local positions = {}
    for j = 1, #escortUnitTypes do
      table.insert(positions, {
        x = origin.x - (j - 1) * unitsSpacing * math.sin(mist.utils.toRadian(bearing)),
        y = origin.y + (j - 1) * unitsSpacing * math.cos(mist.utils.toRadian(bearing)),
      })
    end
    return positions
  end

  local escortAngle = veafGrass.findClearBearing(angle, escortPositionsAt)
  local escortPositions = escortPositionsAt(escortAngle)
  -- Says whether the bearing search actually did anything. A FARP dropped *on* an existing platform is a
  -- different problem from an escort placed on one: this fix moves the **bearing**, never the distance, so
  -- if the new FARP sits 50 m from a static one, every bearing at 150 m is ~150 m away from it, none is
  -- refused, and nothing moves — correctly, by this fix's own rule. Logging both angles is what tells the
  -- two apart from outside.
  veaf.loggers
    .get(veafGrass.Id)
    :info("FARP escort: bearing %s requested, %s used", veaf.p(math.floor(angle)), veaf.p(math.floor(escortAngle)))

  local farpEscortGroup = {
    ["category"] = "vehicle",
    ["coalition"] = farpCoalition,
    ["country"] = farp.country,
    ["countryId"] = farp.countryId,
    ["groupName"] = farp.groupName,
    ["units"] = {},
    ["hiddenOnMFD"] = hiddenOnMFD,
  }
  if groupName then
    farpEscortGroup["groupName"] = groupName
  end

  for j, typeName in ipairs(escortUnitTypes) do
    local escortUnit = {
      ["unitName"] = string.format("FARP %s unit #%d", farp.groupName, farpUnitNameCounter),
      ["heading"] = mist.utils.toRadian(escortAngle - 135), -- parked \\\\\
      ["type"] = typeName,
      ["x"] = escortPositions[j].x,
      ["y"] = escortPositions[j].y,
      ["skill"] = "Random",
    }
    table.insert(farpEscortGroup.units, escortUnit)
    farpUnitNameCounter = farpUnitNameCounter + 1
  end

  mist.dynAdd(farpEscortGroup)

  -- add the FARP to the named points
  local farpNamedPoint = {
    x = farp.x,
    y = math.floor(land.getHeight(farp) + 1),
    z = farp.y,
    atc = true,
    runways = {},
  }

  -- add the FARP to the named points
  local beaconPoint = {
    x = farp.x + 250,
    y = math.floor(land.getHeight(farp) + 1),
    z = farp.y,
  }

  farpNamedPoint.tower = "No Control"

  if veaf.isCtldReady() then
    -- spawn tacan
    mod = string.upper(mod)
    local tacanGroupName = string.format("TACAN %s - %s%s", tostring(code), tostring(freq), tostring(mod))
    veaf.loggers.get(veafGrass.Id):trace(string.format("tacanGroupName=%s", tostring(tacanGroupName)))
    veaf.loggers.get(veafGrass.Id):trace(string.format("freq=%s", tostring(freq)))
    veaf.loggers.get(veafGrass.Id):trace(string.format("mod=%s", tostring(mod)))
    local txFreq = (1025 + freq - 1) * 1000000
    local rxFreq = (962 + freq - 1) * 1000000
    if (freq < 64 and mod == "Y") or (freq >= 64 and mod == "X") then
      rxFreq = (1088 + freq - 1) * 1000000
    end
    veaf.loggers.get(veafGrass.Id):trace(string.format("txFreq=%s", tostring(txFreq)))
    veaf.loggers.get(veafGrass.Id):trace(string.format("rxFreq=%s", tostring(rxFreq)))

    local command = {
      id = "ActivateBeacon",
      params = {
        type = 4,
        system = 18,
        callsign = code,
        frequency = rxFreq,
        AA = false,
        channel = freq,
        bearing = true,
        modeChannel = mod,
      },
    }
    veaf.loggers.get(veafGrass.Id):trace(string.format("setting %s", veaf.p(command)))
    -- The carrier unit for the TACAN is a plain DCS group, not a CTLD concept: v1's
    -- ctld.spawnRadioBeaconUnit was borrowed for convenience and has no public equivalent
    -- in CTLD 2. Spawning it here removes the dependency on a CTLD internal.
    local spawnedGroup = veafGrass.spawnTacanCarrierUnit(beaconPoint, farp.country, tacanGroupName)
    if spawnedGroup then
      local controller = spawnedGroup:getController()
      controller:setCommand(command)
      veaf.loggers.get(veafGrass.Id):trace(string.format("done setting TACAN command"))
    else
      veaf.loggers.get(veafGrass.Id):error("could not spawn the TACAN carrier unit for %s", veaf.p(tacanGroupName))
    end
    -- spawn CTLD beacon
    local _beacon = CTLDBeaconManager.getInstance():createAtPoint(beaconPoint, farpCoalitionNumber, farp.country, {
      name = farp.unitName or farp.name,
      isFOB = true, -- never expires, as the v1 call did with batteryLife = -1
    })
    if _beacon ~= nil then
      farpNamedPoint.tacan = string.format(
        "ADF : %.2f KHz - %.2f MHz - %.2f MHz FM - %s",
        _beacon.vhf / 1000,
        _beacon.uhf / 1000000,
        _beacon.fm / 1000000,
        tacanGroupName
      )
      veaf.loggers.get(veafGrass.Id):trace(string.format("farpNamedPoint.tacan=%s", veaf.p(farpNamedPoint.tacan)))
    end
  end

  -- search for an associated grass runway
  if grassRunwayUnits then
    local grassRunwayUnit = nil
    for name, unitDef in pairs(grassRunwayUnits) do
      ---@type Unit|StaticObject|nil
      local unit = Unit.getByName(name)
      if not unit then
        unit = StaticObject.getByName(name)
      end
      if unit then
        local pos = unit:getPosition().p
        if pos then -- you never know O.o
          local distanceFromCenter = ((pos.x - farp.x) ^ 2 + (pos.z - farp.y) ^ 2) ^ 0.5
          veaf.loggers.get(veafGrass.Id):trace(string.format("name=%s; distanceFromCenter=%s", tostring(name), veaf.p(distanceFromCenter)))
          if distanceFromCenter <= veafGrass.RadiusAroundFarp then
            grassRunwayUnit = unitDef
            break
          end
        end
      end
    end
    if grassRunwayUnit then
      veaf.loggers.get(veafGrass.Id):trace(string.format("found grassRunwayUnit %s", veaf.p(grassRunwayUnit)))
      local grassNamedPoint = veafGrass.buildGrassRunway(grassRunwayUnit, hiddenOnMFD)
      if grassNamedPoint then
        farpNamedPoint.x = grassNamedPoint.x
        farpNamedPoint.y = grassNamedPoint.y
        farpNamedPoint.z = grassNamedPoint.z
        farpNamedPoint.atc = grassNamedPoint.atc
        farpNamedPoint.runways = grassNamedPoint.runways
      end
    end
  end
  veaf.loggers.get(veafGrass.Id):trace(string.format("farpNamedPoint=%s", veaf.p(farpNamedPoint)))

  veafNamedPoints.addPoint(farp.unitName or farp.name, farpNamedPoint)

  veaf.loggers.get(veafGrass.Id):trace(string.format("calling fillFarpWarehouse(%s)", name))
  veafGrass.fillFarpWarehouse(farp)
end

---
--- called from veafEventHandler when a unit is created
function veafGrass.onBirth(event)
  --veaf.loggers.get(veafGrass.Id):trace(string.format("onBirth(%s)",veaf.p(event)))

  -- find the originator unit
  local unitName = nil
  if event.initiator ~= nil then
    unitName = event.initiator.unitName
    if not unitName and event.initiator.getName then
      -- dynamic slot units are DCS objects without mist table properties
      unitName = event.initiator:getName()
    end
  end
  if not unitName then
    veaf.loggers.get(veafGrass.Id):warn("no unitname found in event %s", veaf.p(event))
    return
  end

  local isHumanUnit = veaf.mist.isHumanUnit(unitName) or (event.type and event.type.id == world.event.S_EVENT_PLAYER_ENTER_UNIT)
  if isHumanUnit then -- it's a human unit
    veaf.loggers.get(veafGrass.Id):debug("caught event BIRTH for human unit [%s]", veaf.lp(unitName))
    local _unit = event.initiator
    if _unit ~= nil then
      -- refill all farp warehouses, to work around a DCS bug where the warehouses are spawned empty and their content is not synced over the network
      veafGrass.fillAllFarpWarehouses()
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafGrass.initialize()
  -- delay all these functions 30 seconds (to ensure that the other modules are loaded)

  -- auto generate FARP units (hide these units on MFDs as they create clutter for nothing since the FARP already shows or not depending on what the Mission maker wanted, regardless, don't show them)
  mist.scheduleFunction(veafGrass.buildFarpsUnits, { true }, timer.getTime() + veafGrass.DelayForStartup)

  veafEventHandler.addCallback("veafGrass.OnBirth", { "S_EVENT_BIRTH", "S_EVENT_PLAYER_ENTER_UNIT" }, veafGrass.onBirth)
end

veaf.loggers.get(veafGrass.Id):info(veaf.loggers.get(veafGrass.Id):getVersionInfo())

veaf.registerModule(veafGrass.Id, veafGrass.initialize, { enable = true }, 150)
