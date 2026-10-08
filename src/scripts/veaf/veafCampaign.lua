------------------------------------------------------------------
-- VEAF multi-mission campaign
-- By Zip (2026)
--
-- Features:
-- ---------
-- * Runs one mission of a campaign flown mission after mission (FEAT-MULTI-MISSION-CAMPAIGN).
-- * Garrisons: drawn once with veafCasMission's generators, recorded, and spawned at every
--   mission start from the record minus the losses.
-- * The situation on the F10 map (zones by owner, connections) and in a radio menu.
-- * The state file: what the next mission depends on, written during the flight and at its end.
-- * Assault convoys: a side sends one along a connection to a neutral neighbour, by rule, and the
--   players order blue ones from the radio menu; paid from the reserve, their dead are campaign losses.
--
-- The campaign's data table (`veafCampaign.data`) is written by the build from the campaign state,
-- and has the same structure as the state this module writes back: zones by name with their owner,
-- their garrison and its losses. Merging one into the other is a replacement, not a translation.
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------
veafCampaign = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global module settings
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafCampaign.Id = "CAMPAIGN"

-- trace level, specific to this module
--veafCampaign.LogLevel = "trace"
veaf.loggers.new(veafCampaign.Id, veafCampaign.LogLevel)

--- The campaign's data table, written by the build into the mission before this module initializes:
--- `{ campaign, mission, missions, format_version, state_write_seconds, objectives, zones = { { name,
--- x, z, radius, owner, size, kind, garrison_list, garrison, capture } }, connections, sides,
--- scenery_destroyed }`. Nil in a mission that is not part of a campaign, in which case the module
--- does nothing.
veafCampaign.data = nil

--- Seconds between two beats of the module's single loop.
veafCampaign.BEAT_SECONDS = 10

--- Seconds one side has to hold a neutral zone alone to capture it, unless the data table sets
--- `capture_seconds`.
veafCampaign.CAPTURE_SECONDS = 120

--- Seconds between two writes of the state file, unless the data table sets `state_write_seconds`.
veafCampaign.STATE_WRITE_SECONDS = 60

--- What the module has done, readable by admins from the radio menu.
veafCampaign.counters = {}

--- Line and fill colours of a zone on the F10 map, by owner.
veafCampaign.COLORS = {
  blue = { line = { 0, 0, 1, 1 }, fill = { 0, 0, 1, 0.15 } },
  red = { line = { 1, 0, 0, 1 }, fill = { 1, 0, 0, 0.15 } },
  neutral = { line = { 0.42, 0.42, 0.42, 1 }, fill = { 0.42, 0.42, 0.42, 0.15 } },
}

--- The radio menu's root, once built.
veafCampaign.rootPath = nil

--- The spacing `veafCasMission`'s generators place a garrison with; 1 is their default.
veafCampaign.GARRISON_SPACING = 1

--- The coalitions a zone can belong to, as DCS numbers them. A neutral zone has no garrison.
veafCampaign.SIDES = { blue = coalition.side.BLUE, red = coalition.side.RED }

--- Seconds between a zone becoming a target and the assault convoy leaving for it, unless the data
--- table sets `assault_seconds`. Shortened by the opposition level: more players, an earlier attack.
veafCampaign.ASSAULT_SECONDS = 600

--- Seconds between an assault convoy leaving and the other side hearing of it — the message and the
--- line on its map — unless the data table sets `intel_seconds`. Its own side knows at once.
veafCampaign.INTEL_SECONDS = 1200

--- The trucks an assault convoy brings beside its armour: the infantry it lands in the zone.
veafCampaign.ASSAULT_TRUCKS = 2

--- The air defence level an assault convoy brings at most, whatever its source zone's class: 1 is a gun
--- or two (Vulcan, Gepard; ZU-23, ZSU-57, Shilka), never a missile system.
veafCampaign.ASSAULT_DEFENSE = 1

--- What DCS calls the armour an assault is made of: a tank or an infantry fighting vehicle. The scouts
--- and personnel carriers of `veafCasMission.ARMOR_TYPES`' light levels are left out.
veafCampaign.ASSAULT_ARMOR_ATTRIBUTES = { "Tanks", "IFV" }

--- The assault convoys of this mission, in the order they left: what the state file records of them.
veafCampaign.convoys = {}

--- The assaults waiting to leave, by `<target>|<side>`: `{ side, from, to, at }`.
veafCampaign.pendingAssaults = {}

--- The radio submenu blue assaults are ordered from, once built.
veafCampaign.assaultPath = nil

--- Colour of a convoy's axis on the F10 map, by side.
veafCampaign.AXIS_COLORS = {
  blue = { 0, 0, 1, 1 },
  red = { 1, 0, 0, 1 },
}

--- The zones of the campaign, by name: `VeafCampaignZone` objects built from `veafCampaign.data`.
veafCampaign.zones = {}

--- The zones in the order the data table declares them, so that nothing depends on `pairs`.
veafCampaign.zoneList = {}

--- Which garrison unit a DCS unit name is: `{ zone, group index, unit index }`.
veafCampaign.unitIndex = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafCampaignZone
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafCampaignZone = {}
VeafCampaignZone.__index = VeafCampaignZone

--- Build a zone from its entry of the data table. The entry is kept and modified in place: it is the
--- zone's part of the state this module writes back.
--- @param entry table the zone's entry of `veafCampaign.data.zones`
--- @return table the zone
function VeafCampaignZone:new(entry)
  local zone = setmetatable({}, VeafCampaignZone)
  zone.entry = entry
  zone.name = entry.name
  return zone
end

--- Work out where the zone stands, once: the build gives an airbase name or coordinates, never map
--- coordinates, so that the tools need no projection of their own. An airfield zone is centred on
--- its airbase; a point zone is converted with `coord.LLtoLO`.
--- @return boolean true when the zone has a position
function VeafCampaignZone:resolvePosition()
  local entry = self.entry
  if entry.x and entry.z then
    return true
  end
  if entry.airbase then
    local airbase = Airbase.getByName(entry.airbase)
    if airbase then
      local point = airbase:getPoint()
      entry.x, entry.z = point.x, point.z
      return true
    end
    veaf.loggers.get(veafCampaign.Id):error("zone [%s]: no airbase named [%s] on this map", self.name, entry.airbase)
  end
  if entry.lat and entry.lon then
    local point = coord.LLtoLO(entry.lat, entry.lon, 0)
    entry.x, entry.z = point.x, point.z
    return true
  end
  veaf.loggers.get(veafCampaign.Id):error("zone [%s] has no position; it is left out of this mission", self.name)
  return false
end

--- The zone's centre, as a vec3 on the ground.
function VeafCampaignZone:getCenter()
  return { x = self.entry.x, y = 0, z = self.entry.z }
end

--- The zone's owner: "blue", "red" or "neutral".
function VeafCampaignZone:getOwner()
  return self.entry.owner
end

--- Record one placed unit as a garrison unit.
local function recordUnit(unit)
  return {
    type = unit.typeName,
    x = unit.spawnPoint.x,
    z = unit.spawnPoint.z,
    heading = unit.hdg or 0,
    alive = true,
  }
end

--- The group definitions of an explicit garrison list: each group alias is a group of its own, and the
--- unit aliases and DCS types are gathered into one more.
local function explicitGroupDefinitions(zoneName, list)
  local definitions = {}
  local singles = { disposition = { h = 4, w = 4 }, units = {}, description = zoneName, groupName = zoneName }
  for _, entry in ipairs(list) do
    local group = veafUnits.findGroup(entry)
    if group then
      table.insert(definitions, group)
    else
      table.insert(singles.units, { entry, random = true })
    end
  end
  if #singles.units > 0 then
    local side = math.ceil(math.sqrt(#singles.units)) + 1
    singles.disposition = { h = side, w = side }
    table.insert(definitions, singles)
  end
  return definitions
end

--- How DCS unit categories fall into the reserve's categories (ticket 06); anything else is armour.
--- The same table as `_RESERVE_BY_DCS_CATEGORY` in the tools' `campaign_manager/turn_manager.py`.
veafCampaign.RESERVE_BY_DCS_CATEGORY = { ["Air Defence"] = "air_defense", ["ADEquipment"] = "air_defense", ["Unarmed"] = "transport" }

--- The reserve category a unit type is taken from.
function veafCampaign.reserveCategory(unitType)
  local unit = dcsUnits and dcsUnits.DcsUnitsDatabase and dcsUnits.DcsUnitsDatabase[unitType]
  return unit and veafCampaign.RESERVE_BY_DCS_CATEGORY[unit.category] or "armor"
end

--- A side's ground reserve, by category, or nil when the data table has none.
function veafCampaign.reserveOf(owner)
  local side = veafCampaign.data.sides and veafCampaign.data.sides[owner]
  return side and side.reserve
end

local function reserveTotal(reserve)
  local total = 0
  for _, count in pairs(reserve) do
    total = total + count
  end
  return total
end

--- Compose and place a garrison from `veafCasMission`'s unit generators: infantry sections, armour
--- platoons, air defence groups, in the numbers `generateCasGroup` draws for the same size.
---
--- Not `generateCasGroup` itself, for two reasons measured on 2026-10-06 (40 draws per setting): it
--- always adds a transport company of 10 to 15 lorries, which a garrison has no use for — 15 to 42 of
--- the 28 to 119 units it gives — and it spreads them over `(size + spacing) * 350` m, whatever the
--- zone's radius. Here they stand within the zone.
--- @param name string the group name, used as the prefix of the generated ones
--- @param center table the zone's centre, a vec3
--- @param radius number the zone's radius, in metres
--- @param size table `{ size, defense, armor }`
--- @param side number the DCS coalition
--- @return table the placed units, as `veafCasMission.placeGroup` hands them back
function veafCampaign.composeGarrison(name, center, radius, size, side)
  local units = {}
  local function place(group)
    local position = veaf.findPointInZone(center, radius, false)
    if group and position then
      veafCasMission.placeGroup(group, position, veafCampaign.GARRISON_SPACING, units)
    end
  end
  local sections = math.random(math.max(1, size.size - 2), size.size + 1)
  for index = 1, sections do
    place(veafCasMission.generateInfantryGroup(name .. " - Infantry Section " .. index, size.defense, size.armor, side))
  end
  if size.armor > 0 then
    local platoons = math.random(math.max(1, size.size - 2), size.size + 1)
    for index = 1, platoons do
      place(veafCasMission.generateArmorPlatoon(name .. " - Armor Platoon " .. index, size.defense, size.armor, side))
    end
  end
  if size.defense > 0 then
    local groups = size.defense > 3 and 2 or 1
    for index = 1, groups do
      place(veafCasMission.generateAirDefenseGroup(name .. " - Air Defense Group " .. index, size.defense, side))
    end
  end
  return units
end

--- The size class a draw uses: the zone's own, or the smallest one when the reserve it takes from is
--- empty — a side with nothing left in reserve can only scrape a token garrison together.
local function sizeForDraw(size, reserve)
  if reserve and reserveTotal(reserve) == 0 then
    return { size = 1, defense = math.min(1, size.defense), armor = math.min(1, size.armor), long_range_sam = false }
  end
  return size
end

--- Draw the zone's garrison for its owner, place it, and record it in the zone's entry.
---
--- An explicit `garrison_list` replaces the draw, for the side that declared it (`declared_side`).
--- Otherwise the zone's size class drives
--- `veafCasMission.generateCasGroup`, plus a long-range battery when the class asks for one. Units
--- whose position does not suit them are dropped here, so that what is recorded is what spawns.
--- @param reserve table|nil the reserve the draw takes from, unit by unit; nil for a garrison of the
---   campaign's starting situation, which costs nothing
--- @return table|nil the recorded garrison: a list of `{ name, units = { { type, x, z, heading, alive } } }`,
---   or nil when not a single unit could be placed
function VeafCampaignZone:drawGarrison(reserve)
  local side = veafCampaign.SIDES[self.entry.owner]
  local center = self:getCenter()
  local radius = self.entry.radius or 2000
  local placedGroups = {}

  -- the list is the garrison of the side that declared it: a side taking the zone draws its own
  local declared = self.entry.declared_side
  if self.entry.garrison_list and (declared == nil or declared == self.entry.owner) then
    local units = {}
    for _, definition in ipairs(explicitGroupDefinitions(self.name, self.entry.garrison_list)) do
      local position = veaf.findPointInZone(center, radius, false)
      if position then
        veafCasMission.placeGroup(definition, { x = position.x, y = position.z or position.y }, veafCampaign.GARRISON_SPACING, units)
      end
    end
    table.insert(placedGroups, { name = self.name .. " garrison", units = units })
  else
    local size = sizeForDraw(self.entry.size, reserve)
    local units = veafCampaign.composeGarrison(self.name .. " garrison", center, radius, size, side)
    table.insert(placedGroups, { name = self.name .. " garrison", units = units })
    if size.long_range_sam then
      local battery = veafCasMission.generateLongRangeAirDefenseGroup(self.name .. " long-range SAM", side)
      local position = veaf.findPointInZone(center, radius, false)
      if battery and position then
        local lrUnits = veafCasMission.placeGroup(
          battery,
          { x = position.x, y = position.z or position.y },
          veafCampaign.GARRISON_SPACING,
          {}
        )
        table.insert(placedGroups, { name = self.name .. " long-range SAM", units = lrUnits })
      end
    end
  end

  local garrison = {}
  for _, placed in ipairs(placedGroups) do
    local group = { name = placed.name, units = {} }
    for _, unit in ipairs(placed.units) do
      if unit.spawnPoint and veafUnits.checkPositionForUnit(unit.spawnPoint, unit) then
        table.insert(group.units, recordUnit(unit))
      end
    end
    if #group.units > 0 then
      table.insert(garrison, group)
    end
  end
  if reserve then
    for _, group in ipairs(garrison) do
      for _, unit in ipairs(group.units) do
        local category = veafCampaign.reserveCategory(unit.type)
        reserve[category] = math.max(0, (reserve[category] or 0) - 1)
      end
    end
  end
  if #garrison == 0 then
    -- Recording an empty garrison would hold the zone for ever: never redrawn, and never neutral since
    -- no unit of it can die. Left undrawn, the next mission tries again.
    veaf.loggers.get(veafCampaign.Id):error("zone [%s]: no garrison unit could be placed; the draw is left for the next mission", self.name)
    self.entry.garrison = nil
    return nil
  end
  self.entry.garrison = garrison
  veaf.loggers.get(veafCampaign.Id):info("zone [%s]: garrison drawn, %d unit(s)", self.name, self:countUnits())
  return garrison
end

--- The name a garrison unit spawns under. Stable from one mission to the next, so a loss recorded
--- against it designates the same unit.
function veafCampaign.unitName(group, unitIndex)
  return string.format("%s #%d", group.name, unitIndex)
end

--- Spawn the zone's recorded garrison, without the units it has lost.
--- @return number the number of units submitted to DCS
function VeafCampaignZone:spawnGarrison()
  local garrison = self.entry.garrison
  local side = veafCampaign.SIDES[self.entry.owner]
  if not garrison or not side then
    return 0
  end
  local submitted = 0
  local country = veaf.getCountryForCoalition(side)
  for groupIndex, group in ipairs(garrison) do
    local dcsUnits = {}
    for unitIndex, unit in ipairs(group.units) do
      if unit.alive then
        local name = veafCampaign.unitName(group, unitIndex)
        table.insert(dcsUnits, {
          x = unit.x,
          y = unit.z,
          type = unit.type,
          name = name,
          speed = 0,
          skill = "Random",
          heading = unit.heading,
        })
        veafCampaign.unitIndex[name] = { zone = self, group = groupIndex, unit = unitIndex }
      end
    end
    if #dcsUnits > 0 then
      veaf.addGroup({ country = country, category = "GROUND_UNIT", name = group.name, hidden = false, units = dcsUnits })
      submitted = submitted + #dcsUnits
    end
  end
  veafCampaign.counters.spawns = veafCampaign.counters.spawns + submitted
  return submitted
end

--- How many garrison units the zone has, and how many of them are alive.
--- @return number alive
--- @return number total
function VeafCampaignZone:countUnits()
  local alive, total = 0, 0
  for _, group in ipairs(self.entry.garrison or {}) do
    for _, unit in ipairs(group.units) do
      total = total + 1
      if unit.alive then
        alive = alive + 1
      end
    end
  end
  return alive, total
end

--- Record the loss of one garrison unit; a zone left without any turns neutral.
--- @param groupIndex number the group, in the zone's garrison
--- @param unitIndex number the unit, in its group
function VeafCampaignZone:onUnitLost(groupIndex, unitIndex)
  local group = self.entry.garrison and self.entry.garrison[groupIndex]
  local unit = group and group.units[unitIndex]
  if not unit or not unit.alive then
    return -- already recorded: DCS sends both a dead and a lost event for the same unit
  end
  unit.alive = false
  if self:countUnits() == 0 then
    self:becomeNeutral()
  end
end

--- The zone has lost its whole garrison: it belongs to nobody, and waits to be captured.
function VeafCampaignZone:becomeNeutral()
  local former = self.entry.owner
  self.entry.owner = "neutral"
  self.entry.garrison = nil
  veafCampaign.setAirbaseCoalition(self, coalition.side.NEUTRAL)
  veaf.loggers.get(veafCampaign.Id):info("zone [%s] lost its garrison and is now neutral (was %s)", self.name, former)
  trigger.action.outText(veaf.t("campaign.zone_neutral", self.name), 15)
  veafCampaign.planAssaults(self, timer.getTime())
  veafCampaign.buildAssaultMenu()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Capture (ticket 04)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Whether a CTLD 2 crate of that name exists: crates are static objects that CTLD keeps a registry of.
local function isCtldCrate(name)
  if not (CTLDCrateManager and CTLDCrateManager.getInstance) then
    return false
  end
  local ok, manager = pcall(CTLDCrateManager.getInstance)
  return ok and manager and manager.crates and manager.crates[name] ~= nil or false
end

--- Whether an object found in a zone holds it for its coalition: a ground unit that is active, a
--- helicopter on the ground, or a CTLD crate. Aircraft in flight never do, and neither does a wreck.
function veafCampaign.holdsGround(object, isStatic)
  if object.isExist and not object:isExist() then
    return false
  end
  if object.getLife and object:getLife() < 1 then
    return false -- a destroyed object can still be found, and still answers its coalition (dcs-runtime-traps)
  end
  if isStatic then
    return isCtldCrate(object:getName())
  end
  if object.isActive and not object:isActive() then
    return false -- a late-activated unit is "there" for isExist, not on the ground (dcs-runtime-traps)
  end
  local category = object:getDesc().category
  if category == Unit.Category.GROUND_UNIT then
    return true
  end
  return category == Unit.Category.HELICOPTER and not object:inAir()
end

--- The objects that hold ground in the zone right now: the one definition of "in the zone", for the
--- capture and for the convoy that becomes the garrison alike.
---
--- It is what `world.searchObjects` finds in the zone's sphere, with its slack, and not filtered to the
--- exact radius. That search overshoots: on Kolkhida, 2026-10-08, it found a convoy in a 2000 m zone whose
--- nearest unit stood 2117 m from the centre, and 40 s later returned its nine units at 2036 to 2077 m
--- (dcs-runtime-traps). The capture trusted it and the absorption
--- measured the exact distance, so the convoy took Poti and was not found in it: a garrison was drawn from
--- the reserve under the convoy. Filtering both to the exact radius would agree too, but a convoy halted at
--- the zone's edge — the very case measured — would then never take the zone at all. A few percent beyond
--- the circle drawn on the map is the lesser wrong, as long as both questions get the same answer.
--- @return table the objects, each `{ object = DCS object, side = coalition, name = string }`
function VeafCampaignZone:groundHolders()
  local holders = {}
  local volume = { id = world.VolumeType.SPHERE, params = { point = self:getCenter(), radius = self.entry.radius or 2000 } }
  local function visit(isStatic)
    return function(object)
      if object and veafCampaign.holdsGround(object, isStatic) then
        table.insert(holders, { object = object, side = object:getCoalition(), name = tostring(object:getName()) })
      end
      return true
    end
  end
  world.searchObjects(Object.Category.UNIT, volume, visit(false))
  world.searchObjects(Object.Category.STATIC, volume, visit(true))
  return holders
end

--- Which coalitions hold ground in the zone right now.
--- @return table `{ [coalition.side.BLUE] = "name of the first object found", ... }`
function VeafCampaignZone:sidesPresent()
  local present = {}
  for _, holder in ipairs(self:groundHolders()) do
    present[holder.side] = present[holder.side] or holder.name
  end
  return present
end

--- Advance the capture of a neutral zone by one beat. One side alone runs the clock; both sides stop
--- it; nobody left cancels it; the clock reaching `capture_seconds` captures the zone.
--- @param elapsed number seconds since the last check
function VeafCampaignZone:checkCapture(elapsed)
  if self.entry.owner ~= "neutral" then
    self.presence = nil
    return
  end
  local present = self:sidesPresent()
  local blue, red = present[coalition.side.BLUE], present[coalition.side.RED]
  local presence = (blue and red and string.format("contested: blue (%s), red (%s)", blue, red))
    or (blue and string.format("blue (%s)", blue))
    or (red and string.format("red (%s)", red))
    or "nobody"
  if presence ~= self.presence then
    -- said once per change, so a capture that does not happen can be read in dcs.log
    self.presence = presence
    veaf.loggers.get(veafCampaign.Id):info("neutral zone [%s] held by %s", self.name, presence)
  end
  if blue and red then
    return -- contested: the clock stops where it is
  end
  local side = (blue and "blue") or (red and "red") or nil
  if not side then
    self.entry.capture = nil
    return
  end
  local capture = self.entry.capture
  if not capture or capture.side ~= side then
    capture = { side = side, seconds = 0 }
    self.entry.capture = capture
  end
  capture.seconds = capture.seconds + elapsed
  if capture.seconds >= (veafCampaign.data.capture_seconds or veafCampaign.CAPTURE_SECONDS) then
    self:capturedBy(side)
  end
end

--- The zone is captured: it changes owner, its airbase follows, the new owner's garrison is drawn
--- and spawned, and everybody is told.
function VeafCampaignZone:capturedBy(side)
  self.entry.owner = side
  self.entry.capture = nil
  veafCampaign.setAirbaseCoalition(self, veafCampaign.SIDES[side])
  -- an assault convoy that took the zone stays as its garrison: paid once, from the reserve, when it left
  if not veafCampaign.absorbConvoy(self, side) then
    veaf.loggers
      .get(veafCampaign.Id)
      :info("zone [%s]: no assault convoy of %s in it, its garrison is drawn from the reserve", self.name, side)
    self:drawGarrison(veafCampaign.reserveOf(side))
    self:spawnGarrison()
  end
  veaf.loggers.get(veafCampaign.Id):info("zone [%s] captured by %s", self.name, side)
  trigger.action.outText(veaf.t("campaign.zone_captured", self.name, veaf.t("campaign.side." .. side)), 15)
  for key, pending in pairs(veafCampaign.pendingAssaults) do
    if pending.to == self.name then
      veafCampaign.pendingAssaults[key] = nil -- nothing left to take
    end
  end
  veafCampaign.buildAssaultMenu()
end

--- Make an airfield zone's airbase follow its owner. Both calls exist in the scripting API
--- (`Airbase.setCoalition`, `Airbase.autoCapture`); what they do to dynamic slots and warehouses is
--- still to be measured in game, so each is guarded rather than trusted.
--- @param zone table the zone
--- @param side number the DCS coalition
function veafCampaign.setAirbaseCoalition(zone, side)
  local name = zone.entry.airbase
  if not name then
    return
  end
  local airbase = Airbase.getByName(name)
  if not airbase then
    veaf.loggers.get(veafCampaign.Id):warn("zone [%s]: no airbase named [%s]", zone.name, name)
    return
  end
  if airbase.autoCapture then
    pcall(airbase.autoCapture, airbase, false)
  end
  if airbase.setCoalition then
    pcall(airbase.setCoalition, airbase, side)
  end
end

--- The share of the garrison still alive, in percent; 0 for a zone with none.
function VeafCampaignZone:strengthPercent()
  local alive, total = self:countUnits()
  if total == 0 then
    return 0
  end
  return math.floor(alive * 100 / total + 0.5)
end

--- What the map shows of the zone; a change of it is what makes the zone redrawn.
function VeafCampaignZone:mapLabel()
  local capture = self.entry.capture
  if capture then
    return veaf.t("campaign.map_label_capture", self.name, veaf.t("campaign.side." .. capture.side), math.floor(capture.seconds or 0))
  end
  if self.entry.owner == "neutral" then
    return veaf.t("campaign.map_label_neutral", self.name)
  end
  return veaf.t("campaign.map_label", self.name, self:strengthPercent())
end

--- Draw the zone on the F10 map, for everybody: a circle coloured by owner and its label. Nothing is
--- redrawn while the owner and the label stay the same.
--- @return boolean true when the zone was (re)drawn
function VeafCampaignZone:draw()
  local label = self:mapLabel()
  local signature = self.entry.owner .. "|" .. label
  if signature == self.drawnSignature then
    return false
  end
  for _, id in ipairs(self.markIds or {}) do
    trigger.action.removeMark(id)
  end
  local colors = veafCampaign.COLORS[self.entry.owner] or veafCampaign.COLORS.neutral
  local center = self:getCenter()
  local circleId = veaf.getUniqueIdentifier()
  trigger.action.circleToAll(-1, circleId, center, self.entry.radius or 2000, colors.line, colors.fill, 1, true)
  local labelId = veaf.getUniqueIdentifier()
  trigger.action.textToAll(-1, labelId, center, { 0, 0, 0, 1 }, { 1, 1, 1, 0.5 }, 12, true, label)
  self.markIds = { circleId, labelId }
  self.drawnSignature = signature
  veafCampaign.counters.drawings = veafCampaign.counters.drawings + 1
  return true
end

--- Draw one dashed line per connection between two zones. Connections do not change during a mission.
function veafCampaign.drawConnections()
  for _, connection in ipairs(veafCampaign.data.connections or {}) do
    local a, b = veafCampaign.zones[connection[1]], veafCampaign.zones[connection[2]]
    if a and b and a.placed and b.placed then
      trigger.action.lineToAll(-1, veaf.getUniqueIdentifier(), a:getCenter(), b:getCenter(), { 1, 1, 1, 0.8 }, 2, true)
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Assault convoys (FEAT-OPPOSITION-SCALES-WITH-PLAYERS ticket 04)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The zones connected to this one, in the order the connections are declared.
--- @param zoneName string
--- @return table the neighbouring zones
function veafCampaign.neighbours(zoneName)
  local found = {}
  for _, connection in ipairs(veafCampaign.data.connections or {}) do
    local other = (connection[1] == zoneName and connection[2]) or (connection[2] == zoneName and connection[1]) or nil
    local zone = other and veafCampaign.zones[other]
    if zone and zone.placed then
      table.insert(found, zone)
    end
  end
  return found
end

--- Seconds before an assault leaves: the campaign's delay, shortened when the opposition is sized for
--- more than four players (eight players, half the delay).
function veafCampaign.assaultDelay()
  local delay = veafCampaign.data.assault_seconds or veafCampaign.ASSAULT_SECONDS
  local level = veafOpposition and veafOpposition.getLevel and veafOpposition.getLevel()
  if level and level > 4 then
    delay = delay * 4 / level
  end
  return delay
end

--- Whether a convoy of that side is already on its way to that zone.
local function convoyUnderway(side, target)
  for _, record in ipairs(veafCampaign.convoys) do
    if record.side == side and record.to == target and not record.ended then
      return true
    end
  end
  return false
end

--- The rule: a neutral zone is the target of every side that holds a neighbour of it. The convoy leaves
--- from the first such neighbour, after `assaultDelay()`; one at a time per side and target.
--- @param target table the neutral zone
--- @param now number the mission time
function veafCampaign.planAssaults(target, now)
  if veafCampaign.data.assault_convoys == false or target.entry.owner ~= "neutral" or not target.placed then
    return
  end
  for _, neighbour in ipairs(veafCampaign.neighbours(target.name)) do
    local side = neighbour.entry.owner
    local key = target.name .. "|" .. side
    if veafCampaign.SIDES[side] and not veafCampaign.pendingAssaults[key] and not convoyUnderway(side, target.name) then
      veafCampaign.pendingAssaults[key] = { side = side, from = neighbour.name, to = target.name, at = now + veafCampaign.assaultDelay() }
      veaf.loggers.get(veafCampaign.Id):info("%s will send an assault convoy from [%s] to [%s]", side, neighbour.name, target.name)
    end
  end
end

--- Send the assaults that are due, if they still make sense: the source still held by its side.
--- @param now number the mission time
function veafCampaign.launchDueAssaults(now)
  local due = {}
  for key, pending in pairs(veafCampaign.pendingAssaults) do
    if pending.at <= now then
      table.insert(due, key)
    end
  end
  table.sort(due)
  for _, key in ipairs(due) do
    local pending = veafCampaign.pendingAssaults[key]
    veafCampaign.pendingAssaults[key] = nil
    local from, to = veafCampaign.zones[pending.from], veafCampaign.zones[pending.to]
    if from and to and from.entry.owner == pending.side and to.entry.owner ~= pending.side then
      veafCampaign.sendConvoy(pending.side, from, to)
    end
  end
end

--- The live DCS units of a convoy: its group, and its unarmed vehicles once the convoy watch split them
--- off (`veafGroundAI`, FEAT-CONVOY-UNDER-FIRE), which respawns them under new names.
--- @param record table the convoy's record
--- @return table the units
function veafCampaign.convoyUnits(record)
  local names = { record.name }
  local handler = veafGroundAI and veafGroundAI.convoysByGroupName and veafGroundAI.convoysByGroupName[record.name]
  if handler and handler.unarmedGroupName then
    table.insert(names, handler.unarmedGroupName)
  end
  local units = {}
  for _, name in ipairs(names) do
    local group = Group.getByName(name)
    if group and group:isExist() then
      for _, unit in ipairs(group:getUnits() or {}) do
        -- the pathfinding unit a spawned convoy carries for its first seconds is not the campaign's:
        -- counted, its removal would read as a loss
        local fixer = veafUnits and unit and unit:getTypeName() == veafUnits.DefaultPathfindingUnitType
        if unit and not fixer and unit:isExist() and unit:getLife() >= 1 then
          table.insert(units, unit)
        end
      end
    end
  end
  return units
end

local function typesOf(units)
  local types = {}
  for _, unit in ipairs(units) do
    table.insert(types, unit:getTypeName())
  end
  table.sort(types)
  return types
end

local function removeAxis(record)
  for _, key in ipairs({ "axisId", "intelAxisId" }) do
    if record[key] then
      trigger.action.removeMark(record[key])
      record[key] = nil
    end
  end
end

--- The coalition opposed to a convoy's side.
local function otherCoalition(side)
  return veafCampaign.SIDES[side] == coalition.side.BLUE and coalition.side.RED or coalition.side.BLUE
end

--- Once its intelligence delay has passed, tell the other side of a convoy still on the road: the
--- message and the line on its map, together, once (FEAT-CAMPAIGN-INTEL-DELAY).
--- @param record table the convoy's record
--- @param now number the mission time
function veafCampaign.reportConvoy(record, now)
  if record.reported or record.ended or now < record.intelAt then
    return
  end
  record.reported = true
  local other = otherCoalition(record.side)
  record.intelAxisId = veaf.getUniqueIdentifier()
  trigger.action.lineToAll(other, record.intelAxisId, record.axisFrom, record.axisTo, veafCampaign.AXIS_COLORS[record.side], 1, true)
  trigger.action.outTextForCoalition(other, veaf.t("campaign.convoy_sent_enemy", record.from, record.to), 20)
end

--- Count what is left of a convoy; a convoy with nobody left has ended.
--- @param record table the convoy's record
function veafCampaign.refreshConvoy(record)
  if record.ended then
    return
  end
  record.alive = typesOf(veafCampaign.convoyUnits(record))
  if #record.alive == 0 then
    record.ended = true
    removeAxis(record)
    veaf.loggers.get(veafCampaign.Id):info("assault convoy [%s] to [%s] destroyed", record.name, record.to)
  end
end

--- The tanks and infantry fighting vehicles a side can send in an assault, in the mission's era: every
--- type of `veafCasMission.ARMOR_TYPES` for that side and era that DCS classes as one of
--- `ASSAULT_ARMOR_ATTRIBUTES`, in the order of the table, each once.
--- @param side number the DCS coalition
--- @return table the type names
function veafCampaign.assaultArmorTypes(side)
  local byLevel = veafCasMission.ARMOR_TYPES[side] and veafCasMission.ARMOR_TYPES[side][veaf.config.era] or {}
  local found, seen = {}, {}
  for level = 1, 5 do
    for _, typeName in ipairs(byLevel[level] or {}) do
      if not seen[typeName] then
        seen[typeName] = true
        local unit = veafUnits.findDcsUnit(typeName)
        for _, attribute in ipairs(veafCampaign.ASSAULT_ARMOR_ATTRIBUTES) do
          if unit and unit.attribute and unit.attribute[attribute] then
            table.insert(found, typeName)
            break
          end
        end
      end
    end
  end
  return found
end

--- How many armoured vehicles an assault brings: two per level of its source zone's `armor`, plus two —
--- 4 from an `outpost`, 6 from an `airfield`.
--- @param size table the source zone's size class
--- @return number
function veafCampaign.assaultArmorCount(size)
  return 2 * ((size.armor or 1) + 1)
end

--- The armour of an assault convoy, drawn at random among the side's tanks and IFVs of the era; nil when
--- the era has none, and the convoy then takes the armour platoon `veafSpawn.spawnConvoy` generates.
--- @param side number the DCS coalition
--- @param size table the source zone's size class
--- @return table|nil the type names
function veafCampaign.composeAssaultArmor(side, size)
  local candidates = veafCampaign.assaultArmorTypes(side)
  if #candidates == 0 then
    return nil
  end
  local armor = {}
  for _ = 1, veafCampaign.assaultArmorCount(size) do
    table.insert(armor, candidates[math.random(#candidates)])
  end
  return armor
end

--- Send an assault convoy along a connection: tanks and IFVs after the source zone's size class, a few
--- trucks and a gun or two of air defence, drawn from the side's reserve unit by unit, on the road to the
--- target with the convoy watch.
---
--- Until FIX-ASSAULT-CONVOY-FINDINGS the armour was `veafSpawn.spawnConvoy`'s generated platoon, half the
--- convoy's size give or take 20 %: with two trucks, 0 or 1 vehicle, and the source zone's whole air
--- defence level twice over — on Kolkhida, 2026-10-08, Gepard ×2, Chaparral, Linebacker and two trucks.
--- @param side string "blue" or "red"
--- @param from table the zone it leaves from
--- @param to table the zone it goes to
--- @return table|nil the convoy's record, or nil when none could be sent
function veafCampaign.sendConvoy(side, from, to)
  local reserve = veafCampaign.reserveOf(side)
  if reserve and reserveTotal(reserve) == 0 then
    veaf.loggers.get(veafCampaign.Id):info("%s has nothing left in reserve for an assault from [%s] to [%s]", side, from.name, to.name)
    return nil
  end
  local destination = "CAMPAIGN " .. to.name
  local target = to:getCenter()
  veafNamedPoints.addPoint(destination, { x = target.x, y = target.y, z = target.z })
  local size = from.entry.size or { defense = 1, armor = 1 }
  local name = veafCampaign.uniqueConvoyName(from.name .. " - " .. to.name .. " assault")
  local country = veaf.getCountryForCoalition(veafCampaign.SIDES[side])
  local groupName = veafSpawn.spawnConvoy(
    from:getCenter(),
    name,
    nil,
    math.min(500, from.entry.radius or 2000),
    country,
    veafCampaign.SIDES[side],
    0,
    5,
    nil,
    false,
    false,
    destination,
    math.min(veafCampaign.ASSAULT_DEFENSE, size.defense or 1),
    veafCampaign.ASSAULT_TRUCKS,
    math.max(1, size.armor or 1),
    true,
    false,
    nil,
    veafCampaign.composeAssaultArmor(veafCampaign.SIDES[side], size)
  )
  if not groupName then
    veaf.loggers.get(veafCampaign.Id):error("the assault convoy from [%s] to [%s] could not be spawned", from.name, to.name)
    return nil
  end
  local record = { name = groupName, side = side, from = from.name, to = to.name, absorbed = {} }
  record.sent = typesOf(veafCampaign.convoyUnits(record))
  record.alive = { unpack(record.sent) }
  if reserve then
    for _, unitType in ipairs(record.sent) do
      local category = veafCampaign.reserveCategory(unitType)
      reserve[category] = math.max(0, (reserve[category] or 0) - 1)
    end
  end
  record.axisId = veaf.getUniqueIdentifier()
  record.axisFrom, record.axisTo = from:getCenter(), target
  -- a line in the side's colour over the link, not an arrow: on the F10 map an `arrowToAll` slid away
  -- from its points as the map was panned, whatever their altitude, and it puts its tip on the first
  -- point (FIX-CAMPAIGN-ARROW-ALTITUDE); the links are lines too, and hold still
  local own = veafCampaign.SIDES[side]
  trigger.action.lineToAll(own, record.axisId, record.axisFrom, record.axisTo, veafCampaign.AXIS_COLORS[side], 1, true)
  table.insert(veafCampaign.convoys, record)
  -- the side's own people are told it leaves; the other side hears it as intelligence, later
  trigger.action.outTextForCoalition(own, veaf.t("campaign.convoy_sent_own", from.name, to.name), 20)
  local now = timer.getTime()
  record.intelAt = now + (veafCampaign.data.intel_seconds or veafCampaign.INTEL_SECONDS)
  veafCampaign.reportConvoy(record, now)
  veaf.loggers
    .get(veafCampaign.Id)
    :info("%s assault convoy [%s] left [%s] for [%s], %d unit(s)", side, groupName, from.name, to.name, #record.sent)
  return record
end

--- A convoy name nobody uses yet, so a second assault on the same axis is a second group.
function veafCampaign.uniqueConvoyName(base)
  local name, index = base, 1
  while Group.getByName(name) do
    index = index + 1
    name = string.format("%s %d", base, index)
  end
  return name
end

--- What DCS answers for a convoy's group name, for the log: "missing", "not existing" or "exists".
local function groupState(name)
  local group = Group.getByName(name)
  if not group then
    return "missing"
  end
  local ok, exists = pcall(group.isExist, group)
  return (ok and exists) and "exists" or "not existing"
end

--- A side has just taken a zone: if one of its assault convoys is there, its survivors become the
--- zone's garrison, recorded where they stand, and keep their DCS names for this mission's losses.
---
--- "There" is `VeafCampaignZone:groundHolders`, the search the capture itself ran: the units that took
--- the zone are the ones that become its garrison. Until FIX-CAPTURE-ZONE-MEMBERSHIP this measured the
--- exact distance instead, and a convoy the search had found just beyond the radius took Poti without
--- being found in it. The nearest distance is still logged, to read the search's slack in dcs.log.
---
--- Every convoy record looked at is logged, with why it is or is not absorbed (FIX-ASSAULT-CONVOY-FINDINGS
--- ticket 03).
--- @param zone table the zone captured
--- @param side string the side that took it
--- @return boolean true when a convoy became the garrison
function veafCampaign.absorbConvoy(zone, side)
  local center, radius = zone:getCenter(), zone.entry.radius or 2000
  local logger = veaf.loggers.get(veafCampaign.Id)
  logger:info("zone [%s] taken by %s: %d assault convoy record(s) to look at", zone.name, side, #veafCampaign.convoys)
  local held = {}
  for _, holder in ipairs(zone:groundHolders()) do
    held[holder.name] = true
  end
  for _, record in ipairs(veafCampaign.convoys) do
    local units = veafCampaign.convoyUnits(record)
    local inside, nearest = {}, nil
    for _, unit in ipairs(units) do
      local point = unit:getPoint()
      local distance2 = (point.x - center.x) ^ 2 + (point.z - center.z) ^ 2
      nearest = math.min(nearest or distance2, distance2)
      if held[unit:getName()] then
        table.insert(inside, unit)
      end
    end
    logger:info(
      "zone [%s]: convoy [%s] of %s, ended %s, group %s, %d unit(s) alive, %d inside, nearest %s m from the centre (radius %s)",
      zone.name,
      tostring(record.name),
      tostring(record.side),
      tostring(record.ended),
      groupState(record.name),
      #units,
      #inside,
      nearest and tostring(math.floor(math.sqrt(nearest))) or "-",
      tostring(radius)
    )
    if record.side == side and not record.ended and #inside > 0 then
      local group = { name = record.name, units = {} }
      for index, unit in ipairs(inside) do
        local point = unit:getPoint()
        table.insert(group.units, { type = unit:getTypeName(), x = point.x, z = point.z, heading = 0, alive = true })
        veafCampaign.unitIndex[unit:getName()] = { zone = zone, group = 1, unit = index }
      end
      zone.entry.garrison = { group }
      record.absorbed = typesOf(inside)
      record.ended = true
      record.alive = {}
      removeAxis(record)
      veaf.loggers
        .get(veafCampaign.Id)
        :info("assault convoy [%s] holds [%s]: %d unit(s) become its garrison", record.name, zone.name, #inside)
      return true
    end
  end
  return false
end

--- Radio command: a blue assault from one zone to a neighbour, at once, if it still makes sense.
--- @param parameters table `{ from, to }`
function veafCampaign.orderAssault(parameters)
  local from, to = veafCampaign.zones[parameters[1]], veafCampaign.zones[parameters[2]]
  if not (from and to) or from.entry.owner ~= "blue" or to.entry.owner == "blue" or convoyUnderway("blue", to.name) then
    trigger.action.outTextForCoalition(coalition.side.BLUE, veaf.t("campaign.assault_refused", parameters[1], parameters[2]), 15)
    return
  end
  if not veafCampaign.sendConvoy("blue", from, to) then
    trigger.action.outTextForCoalition(coalition.side.BLUE, veaf.t("campaign.assault_no_reserve"), 15)
  end
end

--- The "Assault" submenu, for blue: one entry per blue zone and neighbour it does not hold. Rebuilt
--- whenever a zone changes hands.
function veafCampaign.buildAssaultMenu()
  if not (veafRadio and veafCampaign.rootPath) then
    return
  end
  if veafCampaign.assaultPath then
    veafRadio.clearSubmenu(veafCampaign.assaultPath)
  else
    veafCampaign.assaultPath = veafRadio.addSubMenu(veaf.t("menu.campaign.assault"), veafCampaign.rootPath, coalition.side.BLUE)
  end
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == "blue" then
      for _, neighbour in ipairs(veafCampaign.neighbours(zone.name)) do
        if neighbour.entry.owner ~= "blue" then
          veafRadio.addSecuredCommandToSubmenu(
            veaf.t("menu.campaign.assault_entry", zone.name, neighbour.name),
            veafCampaign.assaultPath,
            veafCampaign.orderAssault,
            { zone.name, neighbour.name },
            veafRadio.USAGE_ForAll
          )
        end
      end
    end
  end
  veafRadio.refreshRadioMenu()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The campaign's situation, as the radio menu tells it: zones, objectives, missions flown.
function veafCampaign.situationText()
  local data = veafCampaign.data
  local lines = {
    veaf.t("campaign.situation.header", data.campaign or "", data.mission or 0, data.missions or 0),
  }
  for _, zone in ipairs(veafCampaign.zoneList) do
    local line = veaf.t("campaign.situation.zone", zone.name, veaf.t("campaign.side." .. zone.entry.owner), zone:strengthPercent())
    local capture = zone.entry.capture
    if capture then
      line = line .. veaf.t("campaign.situation.capture", veaf.t("campaign.side." .. capture.side), math.floor(capture.seconds or 0))
    end
    table.insert(lines, line)
  end
  if data.objectives and #data.objectives > 0 then
    table.insert(lines, veaf.t("campaign.situation.objectives"))
    for _, objective in ipairs(data.objectives) do
      table.insert(lines, veaf.t("campaign.objective." .. objective.kind, table.concat(objective.zones, ", ")))
    end
  end
  return table.concat(lines, "\n")
end

--- Radio command: the situation, to everybody.
function veafCampaign.reportSituation()
  trigger.action.outText(veafCampaign.situationText(), 30)
end

--- Radio command, for admins: what the module has done so far.
function veafCampaign.reportCounters()
  local c = veafCampaign.counters
  trigger.action.outText(veaf.t("campaign.counters", c.beats, c.zonesProcessed, c.drawings, c.spawns, c.eventsHandled, c.stateWrites), 20)
end

--- Build the "Campaign" radio menu: the situation for everybody, the counters for admins.
function veafCampaign.buildRadioMenu()
  if not veafRadio then
    return
  end
  veafCampaign.rootPath = veafRadio.addSubMenu(veaf.t("menu.campaign.root"))
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.campaign.situation"),
    veafCampaign.rootPath,
    veafCampaign.reportSituation,
    nil,
    veafRadio.USAGE_ForAll
  )
  veafRadio.addSecuredCommandToSubmenu(veaf.t("menu.campaign.counters"), veafCampaign.rootPath, veafCampaign.reportCounters)
  veafRadio.refreshRadioMenu()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- State file
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local function isArray(value)
  local count = 0
  for _ in pairs(value) do
    count = count + 1
  end
  return count == #value
end

--- Serialize a value as a Lua literal, keys sorted, so that the same state always reads the same.
--- What `luadata` reads on the tools' side: numbers, strings, booleans, and tables of those.
--- @param value any
--- @return string
function veafCampaign.serialize(value)
  local kind = type(value)
  if kind == "number" then
    if value == math.floor(value) and math.abs(value) < 1e15 then
      return string.format("%d", value)
    end
    return string.format("%.17g", value)
  elseif kind == "boolean" then
    return tostring(value)
  elseif kind == "string" then
    return string.format("%q", value)
  elseif kind == "table" then
    local parts = {}
    if isArray(value) then
      for _, item in ipairs(value) do
        table.insert(parts, veafCampaign.serialize(item))
      end
    else
      local keys = {}
      for key in pairs(value) do
        table.insert(keys, key)
      end
      table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
      end)
      for _, key in ipairs(keys) do
        local literal = type(key) == "number" and string.format("[%d]", key) or string.format("[%q]", tostring(key))
        table.insert(parts, literal .. "=" .. veafCampaign.serialize(value[key]))
      end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "nil"
end

--- The scenery destroyed so far: what earlier missions recorded, plus what `veafMissionDb` saw die in
--- this one (ticket 07). One entry per object id.
function veafCampaign.destroyedScenery()
  local list, seen = {}, {}
  for _, record in ipairs(veafCampaign.data.scenery_destroyed or {}) do
    seen[record.id] = true
    table.insert(list, record)
  end
  local ids = {}
  for id in pairs(veafMissionDb and veafMissionDb.destroyedScenery or {}) do
    table.insert(ids, id)
  end
  table.sort(ids)
  for _, id in ipairs(ids) do
    if not seen[id] then
      local record = veafMissionDb.destroyedScenery[id]
      table.insert(list, { id = id, x = record.position.x, z = record.position.z, type = record.typeName })
    end
  end
  return list
end

--- How many missiles a unit has left, or nil when it carries none or cannot be asked (ticket 06).
local function missilesLeft(unitName)
  local unit = Unit.getByName(unitName)
  if not unit or not unit.getAmmo then
    return nil
  end
  local ok, ammo = pcall(unit.getAmmo, unit)
  if not ok or type(ammo) ~= "table" then
    return nil
  end
  local missiles, carries = 0, false
  for _, item in ipairs(ammo) do
    if item.desc and item.desc.category == Weapon.Category.MISSILE then
      carries = true
      missiles = missiles + (item.count or 0)
    end
  end
  return carries and missiles or nil
end

--- Record, on every live garrison unit that carries missiles, how many it has left.
function VeafCampaignZone:recordMissiles()
  for _, group in ipairs(self.entry.garrison or {}) do
    for unitIndex, unit in ipairs(group.units) do
      if unit.alive then
        local missiles = missilesLeft(veafCampaign.unitName(group, unitIndex))
        if missiles then
          unit.missiles = missiles
        end
      end
    end
  end
end

--- What the zone's airbase warehouse holds now, or nil (ticket 06). Whether the counts are exact, and
--- cover aircraft as well as weapons, is to be measured in game.
function VeafCampaignZone:readWarehouse()
  local airbase = self.entry.airbase and Airbase.getByName(self.entry.airbase)
  if not (airbase and airbase.getWarehouse) then
    return nil
  end
  local ok, inventory = pcall(function()
    return airbase:getWarehouse():getInventory()
  end)
  if ok and type(inventory) == "table" then
    return inventory
  end
  return nil
end

--- What the next mission depends on, as it stands now: the campaign state's structure, zones by name.
function veafCampaign.stateTable()
  local data = veafCampaign.data
  local zones = {}
  for _, zone in ipairs(veafCampaign.zoneList) do
    zone:recordMissiles()
    zones[zone.name] = {
      owner = zone.entry.owner,
      garrison = zone.entry.garrison,
      capture = zone.entry.capture,
      warehouse = zone:readWarehouse(),
    }
  end
  local convoys = {}
  for _, record in ipairs(veafCampaign.convoys) do
    veafCampaign.refreshConvoy(record)
    table.insert(convoys, {
      name = record.name,
      side = record.side,
      from = record.from,
      to = record.to,
      sent = record.sent,
      alive = record.alive,
      absorbed = record.absorbed,
    })
  end
  return {
    format_version = data.format_version,
    campaign = data.campaign,
    mission = data.mission,
    simulation_time = timer.getTime(),
    zones = zones,
    convoys = convoys,
    sides = data.sides or {},
    scenery_destroyed = veafCampaign.destroyedScenery(),
  }
end

--- The folder the state files go to, under the DCS write directory, one per campaign.
function veafCampaign.stateFolder(writeDir)
  local name = string.gsub(veafCampaign.data.campaign or "campaign", "[^%w%-_ ]", "_")
  return writeDir .. "Missions\\Saves\\" .. name .. "\\"
end

--- The state file of this mission.
function veafCampaign.stateFileName()
  return string.format("mission-%02d.state", veafCampaign.data.mission or 0)
end

--- The libraries the state file is written with. A function so that a test can hand in its own:
--- replacing the globals would also take `io` away from the test runner.
--- @return table|nil io
--- @return table|nil lfs
--- @return table|nil os
function veafCampaign.fileSystem()
  return io, lfs, os
end

--- Write the state file: to a temporary file first, then moved over the previous one, so that a write
--- cut short leaves the previous state whole. Without `io` and `lfs` (a sanitized install) it says so
--- once and does nothing: the mission runs, the campaign just cannot record it.
--- @return boolean true when the file was written
function veafCampaign.writeState()
  local fsIo, fsLfs, fsOs = veafCampaign.fileSystem()
  if not (fsIo and fsLfs) then
    if not veafCampaign.stateUnwritableReported then
      veafCampaign.stateUnwritableReported = true
      veaf.loggers.get(veafCampaign.Id):error("io/lfs are not available (sanitized install): the campaign state cannot be written")
      trigger.action.outText(veaf.t("campaign.state_unwritable"), 30)
    end
    return false
  end
  local writeDir = fsLfs.writedir()
  local folder = veafCampaign.stateFolder(writeDir)
  -- one level at a time: lfs.mkdir creates a single directory, and fails harmlessly on an existing one
  pcall(fsLfs.mkdir, writeDir .. "Missions")
  pcall(fsLfs.mkdir, writeDir .. "Missions\\Saves")
  pcall(fsLfs.mkdir, folder)
  local path = folder .. veafCampaign.stateFileName()
  local temp = path .. ".tmp"
  local content = "return " .. veafCampaign.serialize(veafCampaign.stateTable()) .. "\n"
  local function writeTo(target)
    local file, openError = fsIo.open(target, "w")
    if not file then
      veaf.loggers.get(veafCampaign.Id):error("cannot write the campaign state to %s: %s", target, tostring(openError))
      return false
    end
    file:write(content)
    file:close()
    return true
  end
  if not writeTo(temp) then
    return false
  end
  if fsOs and fsOs.rename then
    -- os.rename does not replace an existing file on Windows: the previous state goes first
    if fsOs.remove then
      fsOs.remove(path)
    end
    local renamed, renameError = fsOs.rename(temp, path)
    if not renamed then
      veaf.loggers.get(veafCampaign.Id):error("cannot move the campaign state to %s: %s", path, tostring(renameError))
      return false
    end
  elseif not writeTo(path) then
    -- No `os` (the VEAF servers sanitize it, measured 2026-10-03): the file is written twice, the
    -- complete temporary first. A write of the real one cut short leaves the temporary whole, and
    -- `campaign apply` falls back on it.
    return false
  end
  veafCampaign.counters.stateWrites = veafCampaign.counters.stateWrites + 1
  return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Loop and events
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- One beat of the module's single loop: every zone is visited once, the state written when due.
function veafCampaign.beat()
  veafCampaign.counters.beats = veafCampaign.counters.beats + 1
  veafCampaign.launchDueAssaults(timer.getTime())
  for _, record in ipairs(veafCampaign.convoys) do
    veafCampaign.refreshConvoy(record)
    veafCampaign.reportConvoy(record, timer.getTime())
  end
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed then
      veafCampaign.counters.zonesProcessed = veafCampaign.counters.zonesProcessed + 1
      zone:checkCapture(veafCampaign.BEAT_SECONDS)
      zone:draw()
    end
  end
  if timer.getTime() >= veafCampaign.nextStateWrite then
    veafCampaign.nextStateWrite = timer.getTime() + (veafCampaign.data.state_write_seconds or veafCampaign.STATE_WRITE_SECONDS)
    veafCampaign.writeState()
  end
end

--- A unit died or was lost: if it is a garrison unit, record it.
function veafCampaign.onUnitDead(event)
  local name = veafEventHandler.unitNameFromEvent(event)
  local where = name and veafCampaign.unitIndex[name]
  if where then
    veafCampaign.counters.eventsHandled = veafCampaign.counters.eventsHandled + 1
    where.zone:onUnitLost(where.group, where.unit)
    where.zone:draw()
  end
end

--- The mission ends: write the state one last time.
function veafCampaign.onMissionEnd()
  veafCampaign.writeState()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the zones from the data table, draw the garrisons that were never drawn, spawn them all.
function veafCampaign.initialize()
  veaf.loggers.get(veafCampaign.Id):info("Initializing module")
  veafCampaign.zones, veafCampaign.zoneList, veafCampaign.unitIndex = {}, {}, {}
  veafCampaign.convoys, veafCampaign.pendingAssaults, veafCampaign.assaultPath = {}, {}, nil
  veafCampaign.counters = { beats = 0, zonesProcessed = 0, drawings = 0, spawns = 0, eventsHandled = 0, stateWrites = 0 }
  local data = veafCampaign.data
  if type(data) ~= "table" or type(data.zones) ~= "table" then
    veaf.loggers.get(veafCampaign.Id):warn("no campaign data in this mission; the campaign module does nothing")
    return false
  end
  for _, entry in ipairs(data.zones) do
    local zone = VeafCampaignZone:new(entry)
    -- a zone that cannot be placed stays in the state, untouched, and out of everything else
    zone.placed = zone:resolvePosition()
    veafCampaign.zones[zone.name] = zone
    table.insert(veafCampaign.zoneList, zone)
  end
  for _, zone in ipairs(veafCampaign.zoneList) do
    -- the campaign decides who owns its airbases, not DCS's own capture
    veafCampaign.setAirbaseCoalition(zone, veafCampaign.SIDES[zone:getOwner()] or coalition.side.NEUTRAL)
    if zone.placed and veafCampaign.SIDES[zone:getOwner()] then
      if not zone.entry.garrison then
        -- the first mission draws the starting situation for free; later, a zone without a garrison
        -- was taken (in flight or between missions) and its garrison comes out of the reserve
        local reserve = (data.mission or 1) > 1 and veafCampaign.reserveOf(zone:getOwner()) or nil
        zone:drawGarrison(reserve)
      end
      zone:spawnGarrison()
    end
  end
  veafEventHandler.addCallback("veafCampaign.onUnitDead", { "S_EVENT_DEAD", "S_EVENT_UNIT_LOST" }, veafCampaign.onUnitDead)
  veafEventHandler.addCallback("veafCampaign.onMissionEnd", { "S_EVENT_MISSION_END" }, veafCampaign.onMissionEnd)
  veafCampaign.drawConnections()
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed then
      zone:draw()
    end
  end
  veafCampaign.buildRadioMenu()
  veafCampaign.buildAssaultMenu()
  -- a neutral zone at the start is a target already: the counter-attack leaves after the delay
  for _, zone in ipairs(veafCampaign.zoneList) do
    veafCampaign.planAssaults(zone, timer.getTime())
  end
  -- the first write is due one interval in: at load time the state is the data table itself
  veafCampaign.nextStateWrite = timer.getTime() + (data.state_write_seconds or veafCampaign.STATE_WRITE_SECONDS)
  veafCampaign.loopId =
    veafScheduler.scheduleFunction(veafCampaign.beat, nil, timer.getTime() + veafCampaign.BEAT_SECONDS, veafCampaign.BEAT_SECONDS)
  return true
end

veaf.loggers.get(veafCampaign.Id):info(veaf.loggers.get(veafCampaign.Id):getVersionInfo())

veaf.registerModule(veafCampaign.Id, veafCampaign.initialize, { enable = true }, 240)
