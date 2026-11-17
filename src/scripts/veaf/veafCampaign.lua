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
-- * The persistent mode (FEAT-DYNAMIC-CAMPAIGN): one mission that saves itself, reloads where it stopped,
--   ends in victory or defeat and starts afresh; zones asleep away from the players; a front that moves
--   on its own — counter-attacks, zones reinforced by supply, CTLD 2 troops and crates. Its aircraft,
--   credits, tasks and intelligence are in veafCampaignOps.lua and veafCampaignEconomy.lua.
-- * The V1.5 of the persistent mode: factory zones made of buildings, the price of a unit, territory
--   cells on the F10 map; resources, the supply network, paid spawns, sappers and warehouse stocks are in
--   veafCampaignLogistics.lua.
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

--- The live play's settings when the data table's `dynamic` block does not set them (FEAT-DYNAMIC-CAMPAIGN).
--- The tools check the block and pass it on; this table is the one place its defaults are read from.
veafCampaign.DYNAMIC_DEFAULTS = {
  save_seconds = 60, -- seconds between two saves of a persistent campaign
  wake_radius = 60000, -- metres: an enemy player's aircraft this close wakes a zone's garrison
  ground_wake_radius = 10000, -- metres: an enemy ground group that is no garrison (convoy, troops, spawn) this close too
  reach_wake_margin = 20000, -- metres: an enemy aircraft this far beyond a zone's air defence reach wakes it
  takeoff_threat_range = 40000, -- metres: no take-off (but a SEAD's) this close to an enemy air defence measured
  front_depth = 40000, -- metres: a zone this close to the front line drawn on the map is always awake
  sleep_seconds = 600, -- a zone nobody has come near for this long goes back to sleep
  max_awake_zones = 12, -- zones whose garrison is in the world at once, nearest the players first
  attacks = { "red" }, -- the sides that counter-attack an enemy zone on their own
  attack_seconds = 900, -- seconds between two counter-attacks of a side
  max_convoys = 2, -- assault convoys of a side on the road at once
  supply = { "red" }, -- the sides whose AI helicopters capture and resupply zones
  supply_seconds = 600,
  max_helicopters = 2,
  helicopter_timeout = 1200,
  -- a neutral zone held by landed helicopters only, no ground unit, is taken after this long rather than
  -- `capture_seconds`: on 2026-11-16 red's Mi-8 took both neutral zones in two minutes each, before the blue
  -- convoys sent 25 to 40 minutes earlier arrived
  helicopter_capture_seconds = 600,
  -- an assault convoy not arrived after this long frees its place: on 2026-11-16 two red convoys held both of
  -- `max_convoys` for more than an hour, one 37 km short of its target after 22 minutes on the road
  convoy_timeout = 2700,
  helicopter = { red = "Mi-8MT", blue = "UH-1H" },
  supply_crate = "Zone supplies", -- the CTLD 2 crate description that resupplies a friendly zone
  hunter = { enabled = true, ground_kills = 8, air_kills = 4, chance = 10 },
  economy = {
    start_credits = 500,
    kill_ground = 10,
    kill_air = 30,
    capture = 200,
    delivery = 100,
    prices = {},
    credits_per_point = 6, -- what a resource point costs in credits: the players' spawns pay their units so (ticket 14)
    demolition = 50, -- credits per building the sappers destroy (ticket 15)
    warehouse_delivery = 50, -- credits per weapons cargo unloaded at another airfield (ticket 16)
    -- the share of a pilot's kill held until the pilot lands at a friendly airfield, FARP or carrier, lost on an
    -- ejection, a death or a crash (David, 2026-11-16: "a share at the action, a bonus at landing")
    landing_share = 50,
  },
  tasks = { count = 3, refresh_seconds = 300, air_kills = 2, rewards = {} },
  intel = { hidden = true, seconds = 3600, overflight_altitude = 1500, spy_troops = "Spy", spy_range = 5000 },
  air = { strike_seconds = 900, max_flights = 4, cap_per_players = 3, cap_helicopter_chance = 25 },
  -- the V1.5 (tickets 11 to 18)
  -- start, background and factory output raised on 2026-11-17: on the first server evening red ran dry after
  -- 1 h 20 (no raid, SEAD or CAP), its two garrisons taken by helicopter having cost it 128 points of 225
  resources = { enabled = true, start = 1000, background_per_hour = 60, reserve = 100, prices = {} },
  factory = { buildings = 3, per_hour = 180, types = { "Workshop A", "Tech combine", "Tech hangar A" } },
  network = { hop_seconds = 600, isolated_seconds = 3600, depot_store = 4, max_deliveries = 3 },
  demolition = { troops = "Sappers", range = 5000, fuse = 120 },
  warehouse = { enabled = true, load = 10 },
  bombers = { enabled = true, seconds = 3600, min_distance = 80000, escort = false, package_delay = 30 },
  territory = { enabled = true, margin = 70000, hatch_spacing = 3000, hatch_length = 2500 },
  -- the testing period: every decision of the AI and its reason in dcs.log, a status every
  -- `debug_status_seconds`, the fate of every campaign aircraft (David, 2026-11-16); off once trusted
  debug = true,
  debug_status_seconds = 300,
}

--- What a unit costs in resource points when `resources.prices` does not name its type, by what the DCS
--- unit database says it is (ticket 12). Defaults, to be tuned on a server: one factory pays for about
--- one counter-attack and one CAP flight an hour.
veafCampaign.UNIT_PRICES = {
  infantry = 1,
  unarmed = 2,
  apc = 4,
  tank = 6,
  artillery = 5,
  aaa = 4,
  sam_short = 8,
  sam_long = 15,
  helicopter = 15,
  plane = 30,
  bomber = 100,
  other = 5,
}

--- What a unit type costs in resource points: its `resources.prices` entry, else its kind's price.
--- @param typeName string the DCS type
--- @return number
function veafCampaign.unitPrice(typeName)
  local override = (veafCampaign.setting("resources", "prices") or {})[typeName]
  if override then
    return override
  end
  local prices = veafCampaign.UNIT_PRICES
  local unit = veafUnits and veafUnits.findDcsUnit and typeName and veafUnits.findDcsUnit(typeName)
  if not unit then
    return prices.other
  end
  local a, category = unit.attribute or {}, unit.category
  if a["Bombers"] or a["Strategic bombers"] then
    return prices.bomber
  elseif category == "Plane" then
    return prices.plane
  elseif category == "Helicopter" then
    return prices.helicopter
  elseif a["LR SAM"] or a["MR SAM"] then
    return prices.sam_long
  elseif a["SR SAM"] or a["IR Guided SAM"] then
    return prices.sam_short
  elseif category == "Air Defence" then
    return prices.aaa
  elseif a["Tanks"] then
    return prices.tank
  elseif a["IFV"] or a["APC"] then
    return prices.apc
  elseif a["Artillery"] or a["MLRS"] or category == "Artillery" then
    return prices.artillery
  elseif category == "Infantry" or a["Infantry"] then
    return prices.infantry
  elseif category == "Unarmed" or a["Unarmed vehicles"] then
    return prices.unarmed
  end
  return prices.other
end

--- What a list of units costs: type names, or records with a `type`.
--- @param units table
--- @return number
function veafCampaign.unitsPrice(units)
  local total = 0
  for _, unit in ipairs(units or {}) do
    total = total + veafCampaign.unitPrice(type(unit) == "table" and unit.type or unit)
  end
  return total
end

--- What a garrison's live units cost.
function veafCampaign.garrisonPrice(garrison)
  local units = {}
  for _, group in ipairs(garrison or {}) do
    for _, unit in ipairs(group.units) do
      if unit.alive then
        table.insert(units, unit.type)
      end
    end
  end
  return veafCampaign.unitsPrice(units)
end

--- Whether a side's AI can pay `cost` from its resources (ticket 12). Always true when nothing counts
--- them: an episodic campaign, or `resources.enabled: false`.
--- @param side string "blue" or "red"
--- @param cost number points
--- @param mode string|nil nil for a sortie, which keeps `resources.reserve`; "essential" down to zero
function veafCampaign.canPay(side, cost, mode)
  local logistics = veafCampaignLogistics
  if not (logistics and logistics.active) then
    return true
  end
  return logistics.canPay(side, cost, mode)
end

--- Pay `cost` from a side's resources, when it can (see `canPay`); "partial" pays what is there.
--- @return boolean whether it was paid
function veafCampaign.pay(side, cost, mode, what)
  local logistics = veafCampaignLogistics
  if not (logistics and logistics.active) then
    return true
  end
  return logistics.pay(side, cost, mode, what)
end

--- Tell a side a piece of campaign news, saying who speaks (David, 2026-11-16: "the announcements say nothing of
--- the side"): a side's own command for what its side does or suffers ("Commandement bleu : "), the intelligence
--- for what is learnt of the enemy ("Renseignement : ").
--- @param side string "blue" or "red", the side told
--- @param speaker string "blue", "red" or "intel"
--- @param text string the news, already translated
--- @param seconds number|nil how long it shows (15)
function veafCampaign.announce(side, speaker, text, seconds)
  local coalitionId = veafCampaign.SIDES[side]
  if not coalitionId then
    return
  end
  trigger.action.outTextForCoalition(coalitionId, veaf.t("campaign.speaker." .. speaker) .. text, seconds or 15)
end

--- Tell both sides a piece of news about the front, each from its own command.
--- @param text string the news, already translated
--- @param seconds number|nil
function veafCampaign.announceToBoth(text, seconds)
  for _, side in ipairs({ "blue", "red" }) do
    veafCampaign.announce(side, side, text, seconds)
  end
end

--- The reason last told under each key of `debugOnce`.
veafCampaign.toldOnce = {}

--- Tell a decision once, until its reason changes: a refusal re-examined at every beat wrote the same line every
--- 10 s, 50 times in 9 minutes (2026-11-16, an unpaid CAP). The reason is what the comparison reads, the text may
--- carry figures that move at every beat (a stock).
--- @param key string what the decision is about: "cap red", "takeoff red Senaki"
--- @param reason string what makes it what it is, without the moving figures
function veafCampaign.debugOnce(key, reason, tag, fmt, ...)
  if veafCampaign.toldOnce[key] == reason then
    return
  end
  veafCampaign.toldOnce[key] = reason
  veafCampaign.debug(tag, fmt, ...)
end

--- Forget what was told under a key: the decision went the other way, the next refusal is news again.
function veafCampaign.forgetTold(key)
  veafCampaign.toldOnce[key] = nil
end

--- Whether the campaign tells its every decision in dcs.log: a persistent campaign with `dynamic.debug`.
function veafCampaign.debugging()
  return veafCampaign.isPersistent() and veafCampaign.setting("debug") == true
end

--- Write one line of the testing period's log, when `dynamic.debug` is on: `[CAMPAIGN <TAG>] text`, a tag
--- to search dcs.log by — DECISION, STATUS, FLIGHT, SUPPLY, ZONE.
--- @param tag string
--- @param fmt string a format, as string.format takes it
function veafCampaign.debug(tag, fmt, ...)
  if not veafCampaign.debugging() then
    return
  end
  local ok, text = pcall(string.format, fmt, ...)
  veaf.loggers.get(veafCampaign.Id):info("[CAMPAIGN %s] %s", tag, ok and text or fmt)
end

--- One setting of the live play: the data table's `dynamic.<key>`, or within a block `dynamic.<key>.<sub>`,
--- else its default.
--- @param key string
--- @param sub string|nil
--- @return any
function veafCampaign.setting(key, sub)
  local dynamic = veafCampaign.data and veafCampaign.data.dynamic or {}
  if sub == nil then
    local value = dynamic[key]
    if value == nil then
      return veafCampaign.DYNAMIC_DEFAULTS[key]
    end
    return value
  end
  local block = dynamic[key]
  if type(block) == "table" and block[sub] ~= nil then
    return block[sub]
  end
  local defaults = veafCampaign.DYNAMIC_DEFAULTS[key]
  return defaults and defaults[sub]
end

--- Whether `side` is in a setting that lists sides (`attacks`, `supply`).
function veafCampaign.sideListed(key, side)
  for _, listed in ipairs(veafCampaign.setting(key) or {}) do
    if listed == side then
      return true
    end
  end
  return false
end

--- Whether this mission is a persistent campaign: one mission that saves and reloads itself.
function veafCampaign.isPersistent()
  return veafCampaign.data ~= nil and veafCampaign.data.persistent == true
end

--- The side the players fly for, and the other one.
function veafCampaign.playerSide()
  return veafCampaign.data and veafCampaign.data.player_side or "blue"
end
function veafCampaign.enemyOf(side)
  return side == "blue" and "red" or "blue"
end

--- What other modules want to hear of: `captured` (zone, side), `neutral` (zone, former owner),
--- `delivered` (zone, side, how), `outcome` (outcome). By event name, a list of functions.
veafCampaign.listeners = {}

--- Be told of a campaign event.
function veafCampaign.listen(eventName, callback)
  veafCampaign.listeners[eventName] = veafCampaign.listeners[eventName] or {}
  table.insert(veafCampaign.listeners[eventName], callback)
end

--- Tell the listeners of an event; one that fails is logged and does not stop the others.
function veafCampaign.notify(eventName, ...)
  for _, callback in ipairs(veafCampaign.listeners[eventName] or {}) do
    local ok, problem = pcall(callback, ...)
    if not ok then
      veaf.loggers.get(veafCampaign.Id):error("a listener of [%s] failed: %s", eventName, tostring(problem))
    end
  end
end

--- What other modules keep in the save of a persistent campaign: by name, `{ save = function() -> table,
--- load = function(table) }`.
veafCampaign.saveParts = {}

--- How the campaign ended, once it has: "victory", "defeat" or "reset". Nil while it runs.
veafCampaign.over = nil

--- What other modules do at every beat of the single loop: functions taking the mission time.
veafCampaign.beatHooks = {}

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

--- How many places in the zone a garrison group tries before it keeps the last, whose units on the
--- concrete `drawGarrison` then drops one by one.
veafCampaign.GARRISON_PLACEMENT_TRIES = 10

--- A unit recorded on the concrete is moved to the nearest bare ground, searched in rings this far
--- apart, out to `OFF_CONCRETE_MAX` metres.
veafCampaign.OFF_CONCRETE_STEP = 25
veafCampaign.OFF_CONCRETE_MAX = 1000

--- Whether a point is on an airfield's concrete, where no garrison unit may stand.
---
--- DCS reports runways, taxiways, aprons and stands alike as `RUNWAY`: measured on 2026-10-09 on
--- Batumi and Senaki, all 82 of their stands were on it, and paved cells reached more than 300 m from
--- the runway centreline (FIX-CAMPAIGN-MISSION-1-FINDINGS ticket 03). So the surface alone keeps a
--- garrison off all of it — which `veaf.DRIVABLE_TERRAIN` deliberately does not, for a convoy's dams.
--- @param point table a vec2 or a vec3
--- @return boolean
function veafCampaign.isOnConcrete(point)
  return veaf.isTerrainValid(point, "RUNWAY")
end

--- The nearest point off the concrete, on drivable ground, from `(x, z)`.
--- @return table|nil `{ x, z }`, or nil when there is none within `OFF_CONCRETE_MAX`
function veafCampaign.nearestOffConcrete(x, z)
  for distance = veafCampaign.OFF_CONCRETE_STEP, veafCampaign.OFF_CONCRETE_MAX, veafCampaign.OFF_CONCRETE_STEP do
    for step = 0, 15 do
      local angle = step * math.pi / 8
      local point = { x = x + distance * math.cos(angle), z = z + distance * math.sin(angle) }
      if veaf.isTerrainValid(point, { "LAND", "ROAD" }) then
        return point
      end
    end
  end
  return nil
end

--- Place one garrison group in the zone, off the concrete: a group a unit of which lands on it is
--- placed again elsewhere, up to `GARRISON_PLACEMENT_TRIES` times.
--- @param definition table the group, as `veafCasMission.placeGroup` takes it
--- @param center table the zone's centre, a vec3
--- @param radius number the zone's radius, in metres
--- @param units table the list the placed units are appended to
function veafCampaign.placeGarrisonGroup(definition, center, radius, units)
  if not definition then
    return
  end
  local placed = {}
  for _ = 1, veafCampaign.GARRISON_PLACEMENT_TRIES do
    local position = veaf.findPointInZone(center, radius, false)
    if not position then
      return
    end
    placed = veafCasMission.placeGroup(definition, { x = position.x, y = position.z or position.y }, veafCampaign.GARRISON_SPACING, {})
    local onConcrete = false
    for _, unit in ipairs(placed) do
      if unit.spawnPoint and veafCampaign.isOnConcrete(unit.spawnPoint) then
        onConcrete = true
        break
      end
    end
    if not onConcrete then
      break
    end
  end
  for _, unit in ipairs(placed) do
    table.insert(units, unit)
  end
end

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

--- Which factory building a DCS static name is: `{ zone, index }` (ticket 11).
veafCampaign.structureIndex = {}

--- The buildings of a factory stand this far apart, in a row, in metres.
veafCampaign.STRUCTURE_SPACING = 60

--- What the units still in the world when the server stopped are worth, by side: paid into its resources
--- once they are loaded (ticket 12).
veafCampaign.homecoming = {}

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
    veafCampaign.placeGarrisonGroup(group, center, radius, units)
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
      veafCampaign.placeGarrisonGroup(definition, center, radius, units)
    end
    table.insert(placedGroups, { name = self.name .. " garrison", units = units })
  else
    local size = sizeForDraw(self.entry.size, reserve)
    local units = veafCampaign.composeGarrison(self.name .. " garrison", center, radius, size, side)
    table.insert(placedGroups, { name = self.name .. " garrison", units = units })
    if size.long_range_sam then
      local battery = veafCasMission.generateLongRangeAirDefenseGroup(self.name .. " long-range SAM", side)
      local lrUnits = {}
      veafCampaign.placeGarrisonGroup(battery, center, radius, lrUnits)
      if #lrUnits > 0 then
        table.insert(placedGroups, { name = self.name .. " long-range SAM", units = lrUnits })
      end
    end
  end

  local garrison = {}
  for _, placed in ipairs(placedGroups) do
    local group = { name = placed.name, units = {} }
    for _, unit in ipairs(placed.units) do
      if unit.spawnPoint and veafUnits.checkPositionForUnit(unit.spawnPoint, unit) and not veafCampaign.isOnConcrete(unit.spawnPoint) then
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

--- Spawn one group of the zone's recorded garrison, without the units it has lost. A group of that name
--- already in the world is replaced by it: `coalition.addGroup` with an existing name replaces the group
--- (dcs-runtime-traps), which is what a reinforcement wants.
--- @param groupIndex number the group, in the zone's garrison
--- @return number the number of units submitted to DCS
function VeafCampaignZone:spawnGroup(groupIndex)
  local group = self.entry.garrison and self.entry.garrison[groupIndex]
  local side = veafCampaign.SIDES[self.entry.owner]
  if not group or not side then
    return 0
  end
  local dcsUnits = {}
  for unitIndex, unit in ipairs(group.units) do
    if unit.alive then
      local name = veafCampaign.unitName(group, unitIndex)
      -- drawn before the concrete was kept clear, or by hand: moved, and recorded where it now stands
      if veafCampaign.isOnConcrete({ x = unit.x, z = unit.z }) then
        local clear = veafCampaign.nearestOffConcrete(unit.x, unit.z)
        if clear then
          veaf.loggers.get(veafCampaign.Id):info(
            "unit [%s] moved off the airfield's concrete, %d m",
            name,
            math.floor(math.sqrt((clear.x - unit.x) ^ 2 + (clear.z - unit.z) ^ 2))
          )
          unit.x, unit.z = clear.x, clear.z
        else
          veaf.loggers.get(veafCampaign.Id):warn("unit [%s] stands on the airfield's concrete and no bare ground was found near it", name)
        end
      end
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
  if #dcsUnits == 0 then
    return 0
  end
  veaf.addGroup({
    country = veaf.getCountryForCoalition(side),
    category = "GROUND_UNIT",
    name = group.name,
    hidden = false,
    units = dcsUnits,
  })
  veafCampaign.counters.spawns = veafCampaign.counters.spawns + #dcsUnits
  return #dcsUnits
end

--- Spawn the zone's recorded garrison, without the units it has lost.
--- @return number the number of units submitted to DCS
function VeafCampaignZone:spawnGarrison()
  local submitted = 0
  for groupIndex in ipairs(self.entry.garrison or {}) do
    submitted = submitted + self:spawnGroup(groupIndex)
  end
  self.awake = true
  return submitted
end

--- Remove the zone's garrison from the world, keeping its record: it comes back as it was when a player
--- approaches (ticket 02). Its units are unregistered **before** they are destroyed, so that whatever
--- DCS says of their removal can never read as a loss.
function VeafCampaignZone:sleep(reason)
  veafCampaign.zoneReach(self) -- measured while the units are there, and remembered
  for _, group in ipairs(self.entry.garrison or {}) do
    for unitIndex in ipairs(group.units) do
      veafCampaign.unitIndex[veafCampaign.unitName(group, unitIndex)] = nil
    end
    local dcsGroup = Group.getByName(group.name)
    if dcsGroup then
      pcall(dcsGroup.destroy, dcsGroup)
    end
  end
  self.awake = false
  veafCampaign.counters.sleeps = veafCampaign.counters.sleeps + 1
  veaf.loggers.get(veafCampaign.Id):info("zone [%s] sleeps: %s", self.name, reason or "put to sleep")
end

--- Bring a sleeping zone's garrison back into the world, as its record left it.
function VeafCampaignZone:wake()
  local submitted = self:spawnGarrison()
  veafCampaign.counters.wakes = veafCampaign.counters.wakes + 1
  veaf.loggers.get(veafCampaign.Id):info("zone [%s] wakes: %d unit(s)", self.name, submitted)
end

--- Bring back the dead units of the zone's first damaged group, in their places: what one supply
--- delivery does (ticket 03). A sleeping zone gets them back in its record, an awake one in the world.
--- @return boolean true when a group was reinforced, false when nothing was missing
function VeafCampaignZone:reinforce()
  for groupIndex, group in ipairs(self.entry.garrison or {}) do
    local damaged = false
    for _, unit in ipairs(group.units) do
      if not unit.alive then
        damaged = true
        unit.alive = true
        unit.missiles = nil
      end
    end
    if damaged then
      if self.awake ~= false then
        self:spawnGroup(groupIndex)
      end
      veafCampaign.counters.reinforcements = veafCampaign.counters.reinforcements + 1
      veaf.loggers.get(veafCampaign.Id):info("zone [%s]: group [%s] reinforced", self.name, group.name)
      self:draw()
      return true
    end
  end
  return false
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
  self.entry.reach = nil -- the air defence remembered went with its garrison
  veafCampaign.setAirbaseCoalition(self, coalition.side.NEUTRAL)
  veaf.loggers.get(veafCampaign.Id):info("zone [%s] lost its garrison and is now neutral (was %s)", self.name, former)
  veafCampaign.debug("ZONE", "[%s] neutral, lost by %s", self.name, tostring(former))
  veafCampaign.announceToBoth(veaf.t("campaign.zone_neutral", veafCampaign.zoneTitle(self.name)), 15)
  veafCampaign.planAssaults(self, timer.getTime())
  veafCampaign.buildAssaultMenu()
  veafCampaign.drawTerritory()
  veafCampaign.notify("neutral", self, former)
  veafCampaign.checkOutcome()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Factory buildings (FEAT-DYNAMIC-CAMPAIGN ticket 11)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- How the players read a zone's name: with the number of its waypoint in their flight plan when it has one,
--- "Taftanaz (WP 7)" (David, 2026-11-16: "the waypoint numbers, everywhere, as in Foothold").
--- @param name string the zone's name
--- @return string
function veafCampaign.zoneTitle(name)
  local zone = veafCampaign.zones[name]
  local waypoint = zone and zone.entry.waypoint
  if waypoint then
    return veaf.t("campaign.zone_with_waypoint", name, waypoint)
  end
  return name
end

--- Whether the zone is a factory: a few buildings that make its owner's resources.
function VeafCampaignZone:isFactory()
  return self.entry.kind == "factory"
end

--- Whether the zone is a depot of the supply network.
function VeafCampaignZone:isDepot()
  return self.entry.kind == "depot"
end

--- The name a factory building spawns under: stable from one load to the next, so a loss recorded against
--- it designates the same building.
function veafCampaign.structureName(zone, index)
  return string.format("%s building #%d", zone.name, index)
end

--- Draw the factory's buildings once and record them: `factory.buildings` of `factory.types`, in a row
--- `STRUCTURE_SPACING` apart, on open ground within half the zone's radius.
--- @return table the recorded buildings
function VeafCampaignZone:drawStructures()
  local types = veafCampaign.setting("factory", "types")
  local count = veafCampaign.setting("factory", "buildings")
  local center, radius = self:getCenter(), self.entry.radius or 2000
  local spacing = veafCampaign.STRUCTURE_SPACING
  local anchor = { x = center.x, z = center.z }
  for _ = 1, veafCampaign.GARRISON_PLACEMENT_TRIES do
    local position = veaf.findPointInZone(center, radius / 2, false)
    if position then
      local candidate = { x = position.x, z = position.z or position.y }
      local clear = true
      for index = 1, count do
        local point = { x = candidate.x + (index - 1) * spacing, z = candidate.z }
        if not veaf.isTerrainValid(point, "LAND") or veafCampaign.isOnConcrete(point) then
          clear = false
          break
        end
      end
      anchor = candidate
      if clear then
        break
      end
    end
  end
  local structures = {}
  for index = 1, count do
    table.insert(structures, {
      type = types[(index - 1) % #types + 1],
      x = anchor.x + (index - 1) * spacing,
      z = anchor.z,
      heading = 0,
      alive = true,
    })
  end
  self.entry.structures = structures
  veaf.loggers.get(veafCampaign.Id):info("factory [%s]: %d building(s) drawn", self.name, count)
  return structures
end

--- Where the factory's buildings stand: the middle of their row, or the zone's centre without any.
function VeafCampaignZone:structuresCenter()
  local structures = self.entry.structures or {}
  if #structures == 0 then
    return self:getCenter()
  end
  local x, z = 0, 0
  for _, structure in ipairs(structures) do
    x, z = x + structure.x, z + structure.z
  end
  return { x = x / #structures, y = 0, z = z / #structures }
end

--- Put one building in the world for the side it was last spawned for: standing, or as a wreck. A static of
--- that name already there is taken away first, unregistered so that its removal never reads as a loss.
--- @param index number the building, in the zone's list
--- @return boolean whether it was submitted
function VeafCampaignZone:spawnStructure(index)
  local structure = self.entry.structures and self.entry.structures[index]
  local side = veafCampaign.SIDES[self.entry.structures_side or ""]
  if not (structure and side) then
    return false
  end
  local name = veafCampaign.structureName(self, index)
  veafCampaign.structureIndex[name] = nil
  local existing = StaticObject.getByName(name)
  if existing then
    pcall(existing.destroy, existing)
  end
  veafDcsSpawner.addStatic({
    country = veaf.getCountryForCoalition(side),
    category = "Fortifications",
    type = structure.type,
    name = name,
    x = structure.x,
    y = structure.z,
    heading = structure.heading or 0,
    dead = not structure.alive,
  })
  if structure.alive then
    veafCampaign.structureIndex[name] = { zone = self, index = index }
  end
  return true
end

--- Put the factory's buildings in the world for its owner; a neutral factory keeps the side it had.
--- @return number the buildings submitted
function VeafCampaignZone:spawnStructures()
  if veafCampaign.SIDES[self.entry.owner] then
    self.entry.structures_side = self.entry.owner
  end
  local submitted = 0
  for index in ipairs(self.entry.structures or {}) do
    if self:spawnStructure(index) then
      submitted = submitted + 1
    end
  end
  return submitted
end

--- How many of the factory's buildings stand, and how many it has.
--- @return number standing
--- @return number total
function VeafCampaignZone:structuresStanding()
  local standing, total = 0, 0
  for _, structure in ipairs(self.entry.structures or {}) do
    total = total + 1
    if structure.alive then
      standing = standing + 1
    end
  end
  return standing, total
end

--- Record the loss of one building.
function VeafCampaignZone:onStructureLost(index)
  local structure = self.entry.structures and self.entry.structures[index]
  if not structure or not structure.alive then
    return
  end
  structure.alive = false
  veafCampaign.structureIndex[veafCampaign.structureName(self, index)] = nil
  veafCampaign.counters.structuresLost = veafCampaign.counters.structuresLost + 1
  local standing, total = self:structuresStanding()
  veaf.loggers.get(veafCampaign.Id):info("factory [%s]: a building destroyed, %d of %d standing", self.name, standing, total)
  veafCampaign.notify("structure_lost", self, index)
end

--- Rebuild the factory's first destroyed building: what a supply delivery does once the garrison is whole.
--- @return boolean whether one was rebuilt
function VeafCampaignZone:repairStructure()
  for index, structure in ipairs(self.entry.structures or {}) do
    if not structure.alive then
      structure.alive = true
      self:spawnStructure(index)
      veafCampaign.counters.reinforcements = veafCampaign.counters.reinforcements + 1
      veaf.loggers.get(veafCampaign.Id):info("factory [%s]: building #%d rebuilt", self.name, index)
      self:draw()
      return true
    end
  end
  return false
end

--- What the map adds to a zone's label for its kind: a factory's buildings standing, a depot's name.
function VeafCampaignZone:kindSuffix()
  if self:isFactory() and self.entry.structures then
    return veaf.t("campaign.map_factory", self:structuresStanding())
  elseif self:isDepot() then
    return veaf.t("campaign.map_depot")
  end
  return ""
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
  if not veaf.isCombatant(object) then
    return false -- a CSAR pilot, immortal, would keep a zone contested for ever (2026-11-16, Menagh)
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
        local helicopter = not isStatic and object:getDesc().category == Unit.Category.HELICOPTER
        table.insert(holders, { object = object, side = object:getCoalition(), name = tostring(object:getName()), helicopter = helicopter })
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
--- @return table `{ [coalition.side.BLUE] = true, ... }` for the sides holding it with more than landed helicopters
function VeafCampaignZone:sidesPresent()
  local present, groundForces = {}, {}
  for _, holder in ipairs(self:groundHolders()) do
    present[holder.side] = present[holder.side] or holder.name
    if not holder.helicopter then
      groundForces[holder.side] = true
    end
  end
  return present, groundForces
end

--- How long a side must hold a neutral zone alone to take it: `capture_seconds`, or, in a persistent campaign,
--- `helicopter_capture_seconds` when it holds it with landed helicopters only.
--- @param byHelicopter boolean
--- @return number seconds
function veafCampaign.captureSeconds(byHelicopter)
  if byHelicopter and veafCampaign.isPersistent() then
    return veafCampaign.setting("helicopter_capture_seconds")
  end
  return veafCampaign.data.capture_seconds or veafCampaign.CAPTURE_SECONDS
end

--- Advance the capture of a neutral zone by one beat. One side alone runs the clock; both sides stop
--- it; nobody left cancels it; the clock reaching `capture_seconds` captures the zone.
--- @param elapsed number seconds since the last check
function VeafCampaignZone:checkCapture(elapsed)
  if self.entry.owner ~= "neutral" or veafCampaign.over then
    self.presence = nil
    return
  end
  local present, groundForces = self:sidesPresent()
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
  local byHelicopter = not groundForces[veafCampaign.SIDES[side]]
  if capture.seconds >= veafCampaign.captureSeconds(byHelicopter) then
    -- a token garrison, like the longer delay, belongs to the persistent campaign's helicopter captures
    self:capturedBy(side, byHelicopter and veafCampaign.isPersistent() and "helicopter" or nil)
  end
end

--- The zone is captured: it changes owner, its airbase follows, the new owner's garrison is drawn
--- and spawned, and everybody is told.
--- @param side string
--- @param how string|nil "helicopter" when landed helicopters alone took it: the garrison is a token one, what a
---   helicopter carries (2026-11-16: the two zones red took by helicopter cost it 128 points of its 225)
function VeafCampaignZone:capturedBy(side, how)
  self.entry.owner = side
  self.entry.capture = nil
  self.entry.reach = nil -- the former owner's air defence is not the captor's
  veafCampaign.setAirbaseCoalition(self, veafCampaign.SIDES[side])
  -- an assault convoy that took the zone stays as its garrison: paid once, from the reserve, when it left
  if not veafCampaign.absorbConvoy(self, side) then
    veaf.loggers
      .get(veafCampaign.Id)
      :info("zone [%s]: no assault convoy of %s in it, its garrison is drawn from the reserve", self.name, side)
    self:drawGarrison(how == "helicopter" and {} or veafCampaign.reserveOf(side))
    veafCampaign.payGarrison(self, side)
    self:spawnGarrison()
  end
  if self:isFactory() then
    self:spawnStructures() -- what stands of it now works for its new owner
  end
  veafCampaign.drawTerritory()
  veaf.loggers.get(veafCampaign.Id):info("zone [%s] captured by %s", self.name, side)
  veafCampaign.debug("ZONE", "[%s] captured by %s", self.name, side)
  veafCampaign.announceToBoth(veaf.t("campaign.zone_captured", veafCampaign.zoneTitle(self.name), veaf.t("campaign.side." .. side)), 15)
  for key, pending in pairs(veafCampaign.pendingAssaults) do
    if pending.to == self.name then
      veafCampaign.pendingAssaults[key] = nil -- nothing left to take
    end
  end
  veafCampaign.buildAssaultMenu()
  veafCampaign.notify("captured", self, side)
  veafCampaign.checkOutcome()
end

--- Pay a captured zone's new garrison from its side's resources (ticket 12); a side that cannot gets the
--- token garrison instead and pays what it has left — a zone without a garrison would be held for ever.
--- @param zone table
--- @param side string
function veafCampaign.payGarrison(zone, side)
  if not zone.entry.garrison or veafCampaign.pay(side, veafCampaign.garrisonPrice(zone.entry.garrison), "essential", "garrison") then
    return
  end
  veaf.loggers.get(veafCampaign.Id):info("zone [%s]: %s cannot pay its garrison, a token one is drawn", zone.name, side)
  zone:drawGarrison({})
  veafCampaign.pay(side, veafCampaign.garrisonPrice(zone.entry.garrison), "partial", "garrison")
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

--- Turn DCS's own capture off on every airfield of the map: in a persistent campaign the campaign alone
--- decides who owns one. On 2026-11-16 Minakh's airfield, which no zone stands on, went blue on its own as a
--- blue convoy drove to Menagh 2.3 km away, while the zone, neutral, followed its own rule. The airfields of
--- the zones are set to their owner besides (`setAirbaseCoalition`); FARPs and ships are left alone.
function veafCampaign.freezeAirfields()
  local ok, airbases = pcall(world.getAirbases)
  for _, airbase in ipairs(ok and airbases or {}) do
    local isAirfield = pcall(function()
      assert(airbase:getDesc().category == Airbase.Category.AIRDROME)
    end)
    if isAirfield and airbase.autoCapture then
      pcall(airbase.autoCapture, airbase, false)
    end
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
    return veaf.t(
      "campaign.map_label_capture",
      veafCampaign.zoneTitle(self.name),
      veaf.t("campaign.side." .. capture.side),
      math.floor(capture.seconds or 0)
    )
  end
  if self.entry.owner == "neutral" then
    return veaf.t("campaign.map_label_neutral", veafCampaign.zoneTitle(self.name))
  end
  return veaf.t("campaign.map_label", veafCampaign.zoneTitle(self.name), self:strengthPercent())
end

--- Whether the zone is revealed to the players' side now (FEAT-DYNAMIC-CAMPAIGN ticket 08).
function veafCampaign.isRevealed(zone)
  return (zone.revealedUntil or 0) > timer.getTime()
end

--- Whether a zone's strength is hidden from a side: in a persistent campaign that hides garrisons
--- (`intel.hidden`), an enemy zone the players' side has not revealed.
--- @param zone table
--- @param side string "blue" or "red"
function veafCampaign.hidesFrom(zone, side)
  return veafCampaign.isPersistent()
    and veafCampaign.setting("intel", "hidden") == true
    and side == veafCampaign.playerSide()
    and veafCampaign.SIDES[zone.entry.owner] ~= nil
    and zone.entry.owner ~= side
    and not veafCampaign.isRevealed(zone)
end

--- What a side sees of the zone on the map.
function VeafCampaignZone:labelFor(side)
  if veafCampaign.hidesFrom(self, side) then
    return veaf.t("campaign.map_label_hidden", veafCampaign.zoneTitle(self.name)) .. self:kindSuffix()
  end
  return self:mapLabel() .. self:kindSuffix()
end

--- Draw the zone on the F10 map: a circle coloured by owner, for everybody, and its label — for
--- everybody too, unless garrisons are hidden, in which case each side gets its own. Nothing is redrawn
--- while the owner and the labels stay the same.
--- @return boolean true when the zone was (re)drawn
function VeafCampaignZone:draw()
  local blueLabel, redLabel = self:labelFor("blue"), self:labelFor("red")
  local signature = self.entry.owner .. "|" .. blueLabel .. "|" .. redLabel
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
  self.markIds = { circleId }
  local labels = { { -1, blueLabel } }
  if blueLabel ~= redLabel then
    labels = { { coalition.side.BLUE, blueLabel }, { coalition.side.RED, redLabel } }
  end
  for _, label in ipairs(labels) do
    local labelId = veaf.getUniqueIdentifier()
    trigger.action.textToAll(label[1], labelId, center, { 0, 0, 0, 1 }, { 1, 1, 1, 0.5 }, 12, true, label[2])
    table.insert(self.markIds, labelId)
  end
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
-- Territory cells (FEAT-DYNAMIC-CAMPAIGN ticket 18)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Fill colours of a territory cell, by owner: faint, under the zones' own circles.
veafCampaign.TERRITORY_COLORS = {
  blue = { 0, 0, 1, 0.07 },
  red = { 1, 0, 0, 0.07 },
  neutral = { 0.5, 0.5, 0.5, 0.05 },
}

--- Colour of the front: the edges between two cells of different owners.
veafCampaign.FRONT_COLOR = { 0.1, 0.1, 0.1, 0.8 }

--- Colour of the hatches along the front, on each side's own side of it: strong, where the fill is faint.
veafCampaign.HATCH_COLORS = {
  blue = { 0, 0, 1, 0.9 },
  red = { 1, 0, 0, 0.9 },
}

--- The hatches along one edge of the front, on one side of it: short strokes slanted at 45°, every
--- `territory.hatch_spacing` metres, `territory.hatch_length` long, pointing into the cell of `site`.
--- @param from table one end of the edge, `{ x, z }`
--- @param to table the other end
--- @param site table the site of the cell the hatches go into
--- @return table the strokes, `{ { from = { x, z }, to = { x, z } } }`
function veafCampaign.frontHatches(from, to, site)
  local spacing = veafCampaign.setting("territory", "hatch_spacing")
  local reach = veafCampaign.setting("territory", "hatch_length") / math.sqrt(2)
  local dx, dz = to.x - from.x, to.z - from.z
  local length = math.sqrt(dx * dx + dz * dz)
  if length == 0 then
    return {}
  end
  dx, dz = dx / length, dz / length
  -- the normal to the edge, turned towards the cell's own site
  local nx, nz = -dz, dx
  if (site.x - from.x) * nx + (site.z - from.z) * nz < 0 then
    nx, nz = -nx, -nz
  end
  local strokes = {}
  for t = spacing / 2, length, spacing do
    local base = { x = from.x + dx * t, z = from.z + dz * t }
    table.insert(strokes, { from = base, to = { x = base.x + (nx + dx) * reach, z = base.z + (nz + dz) * reach } })
  end
  return strokes
end

--- Keep the part of a convex polygon nearer `a` than `b`. Each vertex carries `edge`, the label of the edge
--- from it to the next one; the new edge along the bisector gets `label`.
--- @param polygon table `{ { x, z, edge } }`, in order
--- @param a table the site the cell belongs to, `{ x, z }`
--- @param b table the other site
--- @param label any what the new edge is labelled with: the other site's index
--- @return table the clipped polygon
function veafCampaign.clipByBisector(polygon, a, b, label)
  local mx, mz = (a.x + b.x) / 2, (a.z + b.z) / 2
  local dx, dz = b.x - a.x, b.z - a.z
  local function beyond(p)
    return (p.x - mx) * dx + (p.z - mz) * dz
  end
  local result = {}
  for index, p in ipairs(polygon) do
    local q = polygon[index % #polygon + 1]
    local sp, sq = beyond(p), beyond(q)
    local function cut(edge)
      local t = sp / (sp - sq)
      table.insert(result, { x = p.x + t * (q.x - p.x), z = p.z + t * (q.z - p.z), edge = edge })
    end
    if sp <= 0 then
      table.insert(result, { x = p.x, z = p.z, edge = p.edge })
      if sq > 0 then
        cut(label) -- leaving the half-plane: what follows runs along the bisector
      end
    elseif sq <= 0 then
      cut(p.edge) -- entering it again, on the original edge
    end
  end
  return result
end

--- The Voronoi cell of each site, within the sites' bounding box widened by `margin`: the box clipped by the
--- bisector with every other site. An edge labelled with a site's index borders that site's cell; an edge
--- with no label is the box's.
--- @param sites table `{ { x, z } }`
--- @param margin number metres
--- @return table one polygon per site, in the sites' order
function veafCampaign.voronoiCells(sites, margin)
  local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
  for _, site in ipairs(sites) do
    minX, maxX = math.min(minX, site.x), math.max(maxX, site.x)
    minZ, maxZ = math.min(minZ, site.z), math.max(maxZ, site.z)
  end
  local cells = {}
  for index, site in ipairs(sites) do
    local cell = {
      { x = minX - margin, z = minZ - margin },
      { x = maxX + margin, z = minZ - margin },
      { x = maxX + margin, z = maxZ + margin },
      { x = minX - margin, z = maxZ + margin },
    }
    for other, neighbour in ipairs(sites) do
      if other ~= index and #cell > 0 and (neighbour.x ~= site.x or neighbour.z ~= site.z) then
        cell = veafCampaign.clipByBisector(cell, site, neighbour, other)
      end
    end
    cells[index] = cell
  end
  return cells
end

--- Whether the territory is drawn: a persistent campaign with `territory.enabled`.
function veafCampaign.territoryEnabled()
  return veafCampaign.isPersistent() and veafCampaign.setting("territory", "enabled") == true
end

--- Tint the F10 map by owner: each zone's Voronoi cell filled in its owner's colour, as a fan of triangles
--- (a three-point free-form polygon is what fills reliably), and the front drawn between cells of different
--- owners. Redrawn only when an owner changed.
--- @return boolean whether it was (re)drawn
function veafCampaign.drawTerritory()
  if not veafCampaign.territoryEnabled() then
    return false
  end
  local zones, sites, owners = {}, {}, {}
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed then
      table.insert(zones, zone)
      table.insert(sites, { x = zone.entry.x, z = zone.entry.z })
      table.insert(owners, zone.entry.owner)
    end
  end
  local signature = table.concat(owners, "|")
  if signature == veafCampaign.territorySignature or #sites == 0 then
    return false
  end
  for _, id in ipairs(veafCampaign.territoryMarks or {}) do
    trigger.action.removeMark(id)
  end
  veafCampaign.territoryMarks = {}
  local function vec3(p)
    return { x = p.x, y = 0, z = p.z }
  end
  local cells = veafCampaign.voronoiCells(sites, veafCampaign.setting("territory", "margin"))
  for index, cell in ipairs(cells) do
    local fill = veafCampaign.TERRITORY_COLORS[owners[index]] or veafCampaign.TERRITORY_COLORS.neutral
    for k = 2, #cell - 1 do
      local id = veaf.getUniqueIdentifier()
      trigger.action.markupToAll(7, -1, id, vec3(cell[1]), vec3(cell[k]), vec3(cell[k + 1]), { 0, 0, 0, 0 }, fill, 0, true)
      table.insert(veafCampaign.territoryMarks, id)
    end
    for k, vertex in ipairs(cell) do
      local other = vertex.edge
      local nextVertex = cell[k % #cell + 1]
      if other and other > index and owners[other] ~= owners[index] then
        local id = veaf.getUniqueIdentifier()
        trigger.action.lineToAll(-1, id, vec3(vertex), vec3(nextVertex), veafCampaign.FRONT_COLOR, 1, true)
        table.insert(veafCampaign.territoryMarks, id)
      end
      -- hatches on this cell's side of the front, in its owner's colour: the fill alone is too faint to read
      local hatch = veafCampaign.HATCH_COLORS[owners[index]]
      if other and hatch and owners[other] ~= owners[index] then
        for _, stroke in ipairs(veafCampaign.frontHatches(vertex, nextVertex, sites[index])) do
          local id = veaf.getUniqueIdentifier()
          trigger.action.lineToAll(-1, id, vec3(stroke.from), vec3(stroke.to), hatch, 1, true)
          table.insert(veafCampaign.territoryMarks, id)
        end
      end
    end
  end
  veafCampaign.territorySignature = signature
  veafCampaign.counters.territoryDrawings = veafCampaign.counters.territoryDrawings + 1
  return true
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
---
--- In a persistent campaign, only the sides of `dynamic.attacks` send these on their own: on 2026-11-16 blue's AI
--- sent a free convoy to Menagh three minutes after the players had paid 300 credits for the same assault.
--- @param target table the neutral zone
--- @param now number the mission time
function veafCampaign.planAssaults(target, now)
  if veafCampaign.data.assault_convoys == false or target.entry.owner ~= "neutral" or not target.placed then
    return
  end
  for _, neighbour in ipairs(veafCampaign.neighbours(target.name)) do
    local side = neighbour.entry.owner
    local key = target.name .. "|" .. side
    local allowed = not veafCampaign.isPersistent() or veafCampaign.sideListed("attacks", side)
    if allowed and veafCampaign.SIDES[side] and not veafCampaign.pendingAssaults[key] and not convoyUnderway(side, target.name) then
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
    -- checked again when due: a convoy of the side, bought by the players meanwhile, may already drive there
    if
      from
      and to
      and from.entry.owner == pending.side
      and to.entry.owner ~= pending.side
      and not convoyUnderway(pending.side, to.name)
    then
      veafCampaign.sendConvoy(pending.side, from, to)
    end
  end
end

--- The groups of a convoy: its own, and its unarmed vehicles once the convoy watch split them off (`veafGroundAI`,
--- FEAT-CONVOY-UNDER-FIRE), which respawns them under new names.
local function convoyGroupNames(record)
  local names = { record.name }
  local handler = veafGroundAI and veafGroundAI.convoysByGroupName and veafGroundAI.convoysByGroupName[record.name]
  if handler and handler.unarmedGroupName then
    table.insert(names, handler.unarmedGroupName)
  end
  return names
end

--- The live DCS units of a convoy: its group, and its unarmed vehicles once the convoy watch split them
--- off (`veafGroundAI`, FEAT-CONVOY-UNDER-FIRE), which respawns them under new names.
--- @param record table the convoy's record
--- @return table the units
function veafCampaign.convoyUnits(record)
  local names = convoyGroupNames(record)
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
  veafCampaign.announce(
    veafCampaign.enemyOf(record.side),
    "intel",
    veaf.t("campaign.convoy_sent_enemy", veafCampaign.zoneTitle(record.from), veafCampaign.zoneTitle(record.to)),
    20
  )
end

--- Take a convoy off the road: its units leave the world, its place among `max_convoys` is free, and what was paid
--- for its survivors from the side's resources goes back to them.
--- @param record table the convoy's record
--- @param reason string why, for the log
function veafCampaign.retireConvoy(record, reason)
  local survivors = typesOf(veafCampaign.convoyUnits(record))
  record.ended = true
  record.alive = {}
  removeAxis(record)
  for _, name in ipairs(convoyGroupNames(record)) do
    local group = Group.getByName(name)
    if group and group:isExist() then
      group:destroy()
    end
  end
  -- as a restart does (applySave): the survivors go back to the reserve they were taken from, and their price
  -- into the side's resources, bought or not, or each retired convoy empties the counter-attacks' reserve
  local reserve = veafCampaign.reserveOf(record.side)
  if reserve then
    for _, unitType in ipairs(survivors) do
      local category = veafCampaign.reserveCategory(unitType)
      reserve[category] = (reserve[category] or 0) + 1
    end
  end
  local refund = veafCampaign.unitsPrice(survivors)
  if refund > 0 and veafCampaignLogistics and veafCampaignLogistics.active then
    veafCampaignLogistics.credit(record.side, refund)
  end
  veaf.loggers
    .get(veafCampaign.Id)
    :info("assault convoy [%s] to [%s] retired: %s, %d point(s) back", record.name, record.to, reason, refund)
  veafCampaign.debug("DECISION", "%s convoy [%s] to [%s] retired: %s", record.side, record.name, record.to, reason)
end

--- A convoy of a persistent campaign that will not arrive frees its place: its target is its side's already (a
--- helicopter took it first), or it has been on the road `convoy_timeout`. On 2026-11-16 two red convoys held both
--- places of `max_convoys` for more than an hour, and red sent no counter-attack all that time.
--- @param record table the convoy's record
--- @param now number the mission time
function veafCampaign.checkConvoyGoal(record, now)
  if record.ended or not veafCampaign.isPersistent() then
    return
  end
  local target = veafCampaign.zones[record.to]
  if target and target.entry.owner == record.side then
    veafCampaign.retireConvoy(record, "its target is its side's already")
  elseif record.sentAt and now - record.sentAt >= veafCampaign.setting("convoy_timeout") then
    veafCampaign.retireConvoy(record, string.format("not arrived after %d min", math.floor((now - record.sentAt) / 60)))
  end
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
--- In a persistent campaign the AI's convoy is paid from its side's resources (ticket 12): its armour and
--- trucks are priced before it leaves and it stays home when the side cannot pay them; what actually left
--- is paid once it is on the road. A convoy the players bought (`purchased`) was paid in credits.
--- @param side string "blue" or "red"
--- @param from table the zone it leaves from
--- @param to table the zone it goes to
--- @param purchased boolean|nil true for a convoy the players paid for
--- @return table|nil the convoy's record, or nil when none could be sent
function veafCampaign.sendConvoy(side, from, to, purchased)
  local reserve = veafCampaign.reserveOf(side)
  if reserve and reserveTotal(reserve) == 0 then
    veaf.loggers.get(veafCampaign.Id):info("%s has nothing left in reserve for an assault from [%s] to [%s]", side, from.name, to.name)
    return nil
  end
  local size = from.entry.size or { defense = 1, armor = 1 }
  local armor = veafCampaign.composeAssaultArmor(veafCampaign.SIDES[side], size)
  local estimate = veafCampaign.unitsPrice(armor) + veafCampaign.ASSAULT_TRUCKS * veafCampaign.UNIT_PRICES.unarmed
  if not purchased and not veafCampaign.canPay(side, estimate) then
    veaf.loggers.get(veafCampaign.Id):info("%s cannot pay an assault from [%s] to [%s] (%d points)", side, from.name, to.name, estimate)
    return nil
  end
  local destination = "CAMPAIGN " .. to.name
  local target = to:getCenter()
  veafNamedPoints.addPoint(destination, { x = target.x, y = target.y, z = target.z })
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
    armor
  )
  if not groupName then
    veaf.loggers.get(veafCampaign.Id):error("the assault convoy from [%s] to [%s] could not be spawned", from.name, to.name)
    return nil
  end
  -- strong enough to fight, it drives into the zone while engaging, rather than standing off the threat
  -- of the moment for as long as the zone's garrison stays in sight (FIX-CAPTURE-ZONE-MEMBERSHIP)
  if veafGroundAI and veafGroundAI.setConvoyObjective then
    veafGroundAI.setConvoyObjective(groupName, target)
  end
  local record = { name = groupName, side = side, from = from.name, to = to.name, absorbed = {}, purchased = purchased or nil }
  record.sent = typesOf(veafCampaign.convoyUnits(record))
  record.alive = { unpack(record.sent) }
  if not purchased then
    veafCampaign.pay(side, veafCampaign.unitsPrice(record.sent), "partial", "convoy")
  end
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
  veafCampaign.announce(
    side,
    side,
    veaf.t("campaign.convoy_sent_own", veafCampaign.zoneTitle(from.name), veafCampaign.zoneTitle(to.name)),
    20
  )
  local now = timer.getTime()
  record.sentAt = now
  -- a persistent campaign tells the other side at once: told 20 minutes later, the convoy's departure read as the
  -- cause of a capture made by a helicopter in the same second (2026-11-16, Menagh)
  record.intelAt = now + (veafCampaign.isPersistent() and 0 or (veafCampaign.data.intel_seconds or veafCampaign.INTEL_SECONDS))
  veafCampaign.reportConvoy(record, now)
  veaf.loggers
    .get(veafCampaign.Id)
    :info("%s assault convoy [%s] left [%s] for [%s], %d unit(s)", side, groupName, from.name, to.name, #record.sent)
  veafCampaign.logRoadEnd(groupName, to)
  return record
end

--- Say in dcs.log where an assault convoy's road ends, against its target zone: the route drives on the
--- road to the point of it nearest the zone's centre (`END`), then off it to the centre (`T_END`).
---
--- On Kolkhida, 2026-10-08, the blue convoy's nine units halted together 2.04 to 2.08 km from the centre of
--- Poti's 2000 m zone, and nothing in the code stops a convoy there; whether its road ended there was not
--- written anywhere (FIX-CAPTURE-ZONE-MEMBERSHIP ticket 02).
--- @param groupName string the convoy's group
--- @param to table the zone it goes to
function veafCampaign.logRoadEnd(groupName, to)
  local convoy = veafSpawn.spawnedConvoys and veafSpawn.spawnedConvoys[groupName]
  local route = convoy and convoy.route
  local roadEnd, trueEnd = route and route[3], route and route[4]
  if not roadEnd then
    return
  end
  local center = to:getCenter()
  veaf.loggers.get(veafCampaign.Id):info(
    "assault convoy [%s]: its road ends %d m from [%s]'s centre (radius %s), then %s to the centre",
    groupName,
    math.floor(math.sqrt((roadEnd.x - center.x) ^ 2 + (roadEnd.y - center.z) ^ 2)),
    to.name,
    tostring(to.entry.radius or 2000),
    trueEnd and tostring(trueEnd.action) or "nothing"
  )
end

--- A convoy name nobody uses yet, so a second assault on the same axis is a second group.
function veafCampaign.uniqueConvoyName(base)
  -- a convoy that took a zone is its garrison under the convoy's name; asleep, that group is not in the
  -- world, and a new convoy spawned under its name would be replaced by it at the next wake
  local recorded = {}
  for _, zone in ipairs(veafCampaign.zoneList) do
    for _, group in ipairs(zone.entry.garrison or {}) do
      recorded[group.name] = true
    end
  end
  local name, index = base, 1
  while Group.getByName(name) or recorded[name] do
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
  -- in a persistent campaign the order is a purchase, paid in credits (ticket 14); refunded if no convoy leaves
  local economy = veafCampaign.isPersistent() and veafCampaignEconomy and veafCampaignEconomy.charge and veafCampaignEconomy
  local price = economy and veafCampaignEconomy.price("assault") or 0
  if economy and not economy.charge(price, veaf.t("campaign.shop.item.assault")) then
    return
  end
  if not veafCampaign.sendConvoy("blue", from, to, economy and true or nil) then
    if economy then
      economy.credits = economy.credits + price
    end
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
            veaf.t("menu.campaign.assault_entry", veafCampaign.zoneTitle(zone.name), veafCampaign.zoneTitle(neighbour.name)),
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
-- A front that moves on its own (FEAT-DYNAMIC-CAMPAIGN ticket 03)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- When each side counter-attacks next, by side.
veafCampaign.nextAttack = {}

--- How many of a side's assault convoys are on the road.
function veafCampaign.convoysUnderway(side)
  local count = 0
  for _, record in ipairs(veafCampaign.convoys) do
    if record.side == side and not record.ended then
      count = count + 1
    end
  end
  return count
end

--- The enemy zone a side counter-attacks: among the enemy's zones connected to one of the side's, the
--- weakest — the lowest share of its garrison alive —, the first declared on a tie; with the neighbour
--- the convoy leaves from. A zone a convoy of the side is already driving to is left out.
--- @param side string "blue" or "red"
--- @return table|nil the target zone
--- @return table|nil the zone the convoy leaves from
function veafCampaign.attackTarget(side)
  local enemy = veafCampaign.enemyOf(side)
  local best, bestFrom, bestStrength = nil, nil, nil
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == enemy and not convoyUnderway(side, zone.name) then
      for _, neighbour in ipairs(veafCampaign.neighbours(zone.name)) do
        if neighbour.entry.owner == side then
          local strength = zone:strengthPercent()
          if bestStrength == nil or strength < bestStrength then
            best, bestFrom, bestStrength = zone, neighbour, strength
          end
          break
        end
      end
    end
  end
  return best, bestFrom
end

--- Send the counter-attacks that are due: every `attack_seconds` a side listed in `attacks` sends an
--- assault convoy at the weakest enemy zone it borders, `max_convoys` on the road at most.
--- @param now number the mission time
function veafCampaign.launchOffensives(now)
  if veafCampaign.over then
    return
  end
  for _, side in ipairs({ "red", "blue" }) do
    if veafCampaign.sideListed("attacks", side) then
      local due = veafCampaign.nextAttack[side]
      if due == nil then
        veafCampaign.nextAttack[side] = now + veafCampaign.setting("attack_seconds")
      elseif now >= due then
        veafCampaign.nextAttack[side] = now + veafCampaign.setting("attack_seconds")
        if veafCampaign.convoysUnderway(side) >= veafCampaign.setting("max_convoys") then
          veafCampaign.debugOnce(
            "attack " .. side,
            "full",
            "DECISION",
            "%s does not counter-attack: %d convoys already on the road",
            side,
            veafCampaign.convoysUnderway(side)
          )
        else
          local target, from = veafCampaign.attackTarget(side)
          if not target then
            veafCampaign.debugOnce("attack " .. side, "none", "DECISION", "%s does not counter-attack: no enemy zone it borders", side)
          end
          if target then
            veafCampaign.forgetTold("attack " .. side)
            veaf.loggers.get(veafCampaign.Id):info("%s counter-attacks [%s] from [%s]", side, target.name, from.name)
            if veafCampaign.sendConvoy(side, from, target) then
              veafCampaign.keepAwake(target, veafCampaign.setting("helicopter_timeout"))
            end
          end
        end
      end
    end
  end
end

--- A zone that is the target of a sortie stays awake for that long, players near or not (ticket 02).
--- @param zone table
--- @param seconds number
function veafCampaign.keepAwake(zone, seconds)
  zone.keepAwakeUntil = math.max(zone.keepAwakeUntil or 0, timer.getTime() + seconds)
end

--- A supply delivery reached a zone of its side: the zone is reinforced, and everyone who should hear of
--- it does. Nothing happens to a zone with nothing missing.
--- @param zone table
--- @param side string the side that delivered
--- @param how string "crate", "troops" or "helicopter"
--- @return boolean true when the zone was reinforced
function veafCampaign.deliver(zone, side, how)
  -- the garrison first; a factory whose garrison is whole gets a building back (ticket 11)
  if zone.entry.owner ~= side or not (zone:reinforce() or zone:repairStructure()) then
    return false
  end
  veafCampaign.announce(side, side, veaf.t("campaign.zone_reinforced", veafCampaign.zoneTitle(zone.name)), 15)
  veafCampaign.notify("delivered", zone, side, how)
  return true
end

--- Whether a zone has lost any garrison unit.
function VeafCampaignZone:garrisonDamaged()
  local alive, total = self:countUnits()
  return total > 0 and alive < total
end

--- Whether a zone has lost anything a delivery brings back: a garrison unit, or a factory's building.
function VeafCampaignZone:isDamaged()
  local standing, buildings = self:structuresStanding()
  return self:garrisonDamaged() or standing < buildings
end

--- The CTLD 2 crate of that name, as its manager keeps it, or nil.
local function ctldCrate(name)
  if not (CTLDCrateManager and CTLDCrateManager.getInstance) then
    return nil
  end
  local ok, manager = pcall(CTLDCrateManager.getInstance)
  return ok and manager and manager.crates and manager.crates[name] or nil
end

--- The CTLD 2 troop template a deployed group was dropped from, or nil when CTLD did not drop it.
function veafCampaign.ctldTroopTemplate(groupName)
  if not (CTLDTroopManager and CTLDTroopManager.getInstance) then
    return nil
  end
  local ok, manager = pcall(CTLDTroopManager.getInstance)
  local stored = ok and manager and manager._droppedTemplates and manager._droppedTemplates[groupName]
  -- CTLD keeps `{ key, name, weight, total, specificParams }` per dropped group; `name` is the template's
  if type(stored) == "table" then
    return stored.name or stored.key
  end
  return stored or nil
end

--- Whether a CTLD 2 troop template is a supply delivery: any troops but the spy team and the JTAC teams,
--- which players drop in a friendly zone for what they do, not to be consumed.
function veafCampaign.isSupplyTroops(template)
  return template ~= nil
    and template ~= veafCampaign.setting("intel", "spy_troops")
    and not string.find(string.upper(template), "JTAC", 1, true)
end

--- Remove a CTLD 2 troop group: from the world, and from CTLD's list of dropped groups.
local function removeCtldTroops(groupName, side)
  local ok, manager = pcall(CTLDTroopManager.getInstance)
  if ok and manager and manager._removeFromDropped then
    pcall(manager._removeFromDropped, manager, side, groupName)
  end
  local group = Group.getByName(groupName)
  if group then
    pcall(group.destroy, group)
  end
end

--- Look in a damaged friendly zone for what players brought it: a "Zone supplies" crate set down, or CTLD
--- troops deployed. The first found is consumed and reinforces the zone.
--- @param zone table
--- @return boolean true when a delivery was made
function veafCampaign.collectDeliveries(zone)
  local side = zone.entry.owner
  if not veafCampaign.SIDES[side] or not zone:isDamaged() then
    return false
  end
  local wanted = veafCampaign.setting("supply_crate")
  for _, holder in ipairs(zone:groundHolders()) do
    if holder.side == veafCampaign.SIDES[side] then
      local crate = ctldCrate(holder.name)
      if crate and crate.descriptor and crate.descriptor.desc == wanted then
        if veafCampaign.deliver(zone, side, "crate") then
          local ok, manager = pcall(CTLDCrateManager.getInstance)
          if ok and manager and manager.destroyCrate then
            pcall(manager.destroyCrate, manager, holder.name)
          end
          return true
        end
      elseif not crate and holder.object.getGroup then
        local group = holder.object:getGroup()
        local groupName = group and group:getName()
        local template = groupName and veafCampaign.ctldTroopTemplate(groupName)
        if veafCampaign.isSupplyTroops(template) then
          if veafCampaign.deliver(zone, side, "troops") then
            removeCtldTroops(groupName, holder.side)
            return true
          end
        end
      end
    end
  end
  return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The campaign's situation, as the radio menu tells it: zones, objectives, missions flown.
--- @param side string|nil the side reading it; its enemy's hidden garrisons read "unknown"
function veafCampaign.situationText(side)
  local data = veafCampaign.data
  local lines = {
    veaf.t("campaign.situation.header", data.campaign or "", data.mission or 0, data.missions or 0),
  }
  for _, zone in ipairs(veafCampaign.zoneList) do
    local title = veafCampaign.zoneTitle(zone.name)
    local line = veaf.t("campaign.situation.zone", title, veaf.t("campaign.side." .. zone.entry.owner), zone:strengthPercent())
    if side and veafCampaign.hidesFrom(zone, side) then
      line = veaf.t("campaign.situation.zone_hidden", title, veaf.t("campaign.side." .. zone.entry.owner))
    end
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
  if veafCampaign.isPersistent() then
    -- each side reads what it knows: the players' side does not see a garrison it has not revealed
    for side, coalitionId in pairs(veafCampaign.SIDES) do
      trigger.action.outTextForCoalition(coalitionId, veafCampaign.situationText(side), 30)
    end
    return
  end
  trigger.action.outText(veafCampaign.situationText(), 30)
end

--- What other modules add to the self-check: functions returning a list of lines.
veafCampaign.selfChecks = {}

--- One verdict line: OK or KO, then what was measured.
local function verdict(ok, key, ...)
  return veaf.t(ok and "campaign.check.ok" or "campaign.check.ko", veaf.t(key, ...))
end

--- The self-check, as text: one verdict per mechanism, readable in game without the log (ticket 09).
function veafCampaign.selfCheckText()
  local c, lines = veafCampaign.counters, {}
  local placed, unplaced, neutral, capturing, awake = 0, {}, {}, {}, 0
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed then
      placed = placed + 1
    else
      table.insert(unplaced, zone.name)
    end
    if zone.entry.owner == "neutral" then
      table.insert(neutral, zone.name)
    end
    if zone.entry.capture then
      table.insert(capturing, string.format("%s %s %ds", zone.name, zone.entry.capture.side, math.floor(zone.entry.capture.seconds or 0)))
    end
    if zone.awake then
      awake = awake + 1
    end
  end
  -- the mission time and the beats so far: a check made before the first beat (10 s) has nothing to judge
  table.insert(lines, veaf.t("campaign.check.title", math.floor(timer.getTime()), c.beats))
  table.insert(lines, verdict(#unplaced == 0, "campaign.check.zones", placed, #veafCampaign.zoneList, table.concat(unplaced, ", ")))
  if veafCampaign.isPersistent() then
    local load = veafCampaign.loadResult or "-"
    table.insert(lines, verdict(load == "loaded" or load == "fresh", "campaign.check.load", load))
    table.insert(
      lines,
      verdict(veafCampaign.lastWriteOk ~= false, "campaign.check.save", c.stateWrites, tostring(veafCampaign.lastWriteOk))
    )
    table.insert(lines, verdict(true, "campaign.check.outcome", veafCampaign.over or "-"))
  end
  if veafCampaign.dormancyEnabled() then
    table.insert(
      lines,
      verdict(
        awake <= veafCampaign.setting("max_awake_zones"),
        "campaign.check.dormancy",
        awake,
        veafCampaign.setting("max_awake_zones"),
        c.wakes,
        c.sleeps
      )
    )
  end
  table.insert(lines, verdict(true, "campaign.check.capture", table.concat(neutral, ", "), table.concat(capturing, ", ")))
  table.insert(lines, verdict(true, "campaign.check.losses", c.eventsHandled, c.reinforcements))
  local factories, standing, buildings = 0, 0, 0
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone:isFactory() then
      local up, all = zone:structuresStanding()
      factories, standing, buildings = factories + 1, standing + up, buildings + all
    end
  end
  if factories > 0 then
    -- a factory without a building recorded never had any drawn: nothing would ever be produced there
    table.insert(lines, verdict(buildings > 0, "campaign.check.factories", factories, standing, buildings, c.structuresLost))
  end
  if veafCampaign.territoryEnabled() then
    local marks = #(veafCampaign.territoryMarks or {})
    table.insert(lines, verdict(marks > 0, "campaign.check.territory", c.territoryDrawings, marks))
  end
  for _, check in ipairs(veafCampaign.selfChecks) do
    local ok, extra = pcall(check, verdict)
    if ok and type(extra) == "table" then
      for _, line in ipairs(extra) do
        table.insert(lines, line)
      end
    elseif not ok then
      table.insert(lines, verdict(false, "campaign.check.failed", tostring(extra)))
    end
  end
  return table.concat(lines, "\n")
end

--- Radio command, for admins: the self-check.
function veafCampaign.reportSelfCheck()
  trigger.action.outText(veafCampaign.selfCheckText(), 45)
end

--- Radio command, for admins: what the module has done so far.
function veafCampaign.reportCounters()
  local c = veafCampaign.counters
  local text = veaf.t("campaign.counters", c.beats, c.zonesProcessed, c.drawings, c.spawns, c.eventsHandled, c.stateWrites)
  if veafCampaign.dormancyEnabled() then
    local awake = 0
    for _, zone in ipairs(veafCampaign.zoneList) do
      if zone.awake then
        awake = awake + 1
      end
    end
    text = text .. "\n" .. veaf.t("campaign.counters_dormancy", awake, c.wakes, c.sleeps, c.reinforcements)
  end
  trigger.action.outText(text, 20)
end

--- Build the "Campaign" radio menu: the situation for everybody, the counters for admins.
function veafCampaign.buildRadioMenu()
  if not veafRadio then
    return
  end
  veafCampaign.rootPath = veafRadio.addRootMenu("menu.campaign.root")
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.campaign.situation"),
    veafCampaign.rootPath,
    veafCampaign.reportSituation,
    nil,
    veafRadio.USAGE_ForAll
  )
  veafRadio.refreshRadioMenu()
end

--- The "(admin)" commands of the Campaign menu, added once every other entry is: on the first server evening
--- (2026-11-16) they came before the shop and the rest, which fell to the menu's second page.
function veafCampaign.buildAdminMenu()
  if not (veafRadio and veafCampaign.rootPath) then
    return
  end
  -- the "(admin)" commands ask the admin level: a secured command asks a senior pilot by default, and a
  -- senior pilot opened the self-check on the first server evening (2026-11-16)
  local function adminCommand(title, method)
    local command = veafRadio.addSecuredCommandToSubmenu(veaf.t(title), veafCampaign.rootPath, method)
    if command then
      command.securityLevel = veafSecurity and veafSecurity.LEVEL_ADMIN or 90
    end
    return command
  end
  adminCommand("menu.campaign.counters", veafCampaign.reportCounters)
  adminCommand("menu.campaign.self_check", veafCampaign.reportSelfCheck)
  if veafCampaign.isPersistent() then
    adminCommand("menu.campaign.reset", veafCampaign.resetCampaign)
  end
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
      structures = zone.entry.structures,
      structures_side = zone.entry.structures_side,
      reach = zone.entry.reach,
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
  local state = {
    format_version = data.format_version,
    campaign = data.campaign,
    mission = data.mission,
    simulation_time = timer.getTime(),
    zones = zones,
    convoys = convoys,
    sides = data.sides or {},
    scenery_destroyed = veafCampaign.destroyedScenery(),
  }
  if veafCampaign.isPersistent() then
    -- once the campaign is over, every save says so: the next load starts afresh
    state.reset = veafCampaign.over ~= nil or nil
    state.outcome = veafCampaign.over
    state.parts = {}
    for name, part in pairs(veafCampaign.saveParts) do
      local ok, saved = pcall(part.save)
      if ok then
        state.parts[name] = saved
      else
        veaf.loggers.get(veafCampaign.Id):error("the save of [%s] failed: %s", name, tostring(saved))
      end
    end
  end
  return state
end

--- The folder the state files go to, under the DCS write directory, one per campaign.
function veafCampaign.stateFolder(writeDir)
  local name = string.gsub(veafCampaign.data.campaign or "campaign", "[^%w%-_ ]", "_")
  return writeDir .. "Missions\\Saves\\" .. name .. "\\"
end

--- The state file of this mission; a persistent campaign has a single one, which it reloads.
function veafCampaign.stateFileName()
  if veafCampaign.isPersistent() then
    return "persistent.state"
  end
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
  veafCampaign.lastWriteOk = false -- until the write below goes through
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
    -- buffered: a full disk often shows up only at close, so both answers count (issue #1146). Only an error,
    -- or an explicit false, is a failure: inside DCS a write that worked can answer nothing at all (measured
    -- 2026-11-16, every save logged as failed with no error while the file was written whole, so the state
    -- itself was never written and every reload fell back on the temporary)
    local written, writeError = file:write(content)
    local closed, closeError = file:close()
    if written == false or closed == false or writeError ~= nil or closeError ~= nil then
      veaf.loggers.get(veafCampaign.Id):error("cannot write the campaign state to %s: %s", target, tostring(writeError or closeError))
      return false
    end
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
  veafCampaign.lastWriteOk = true
  return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Persistent mode: reload, outcome, reset (FEAT-DYNAMIC-CAMPAIGN ticket 01)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Read one save file: a Lua literal (`return { ... }`), run with no environment at all, so it cannot
--- call anything.
--- @return table|nil the saved state
--- @return string|nil why there is none: "none" or "unreadable"
local function readSaveFile(fsIo, path)
  local file = fsIo.open(path, "r")
  if not file then
    return nil, "none"
  end
  local content = file:read("*a")
  file:close()
  local chunk = content and loadstring(content)
  if not chunk then
    return nil, "unreadable"
  end
  setfenv(chunk, {})
  local ok, state = pcall(chunk)
  if not ok or type(state) ~= "table" or type(state.zones) ~= "table" then
    return nil, "unreadable"
  end
  return state
end

--- Read the save of a persistent campaign, falling back on its temporary when the file itself is cut
--- short or missing: without `os` (the VEAF servers sanitize it) every write is made twice, the complete
--- temporary first, so a server stopped during the second write leaves the temporary whole (#1146).
--- @return table|nil the saved state
--- @return string|nil why there is none: "no-io", "none" or "unreadable"
function veafCampaign.readSave()
  local fsIo, fsLfs = veafCampaign.fileSystem()
  if not (fsIo and fsLfs) then
    return nil, "no-io"
  end
  local path = veafCampaign.stateFolder(fsLfs.writedir()) .. veafCampaign.stateFileName()
  local state, why = readSaveFile(fsIo, path)
  if state then
    return state
  end
  local temporary, temporaryWhy = readSaveFile(fsIo, path .. ".tmp")
  if temporary then
    veaf.loggers.get(veafCampaign.Id):warn("the campaign's save is %s: its temporary is used instead", why)
    return temporary
  end
  if why == "none" and temporaryWhy == "none" then
    return nil, "none"
  end
  return nil, "unreadable"
end

--- Lay a save over the data table: each zone the save knows takes its owner, garrison and capture; a zone
--- the save does not know keeps its declared state; a saved zone the campaign no longer has is dropped.
--- A save of another campaign or format, or marked reset, is not used.
--- @param state table the saved state
--- @return boolean true when it was used
--- @return string|nil why it was not: "reset" or "other"
function veafCampaign.applySave(state)
  local data, logger = veafCampaign.data, veaf.loggers.get(veafCampaign.Id)
  if state.reset then
    return false, "reset"
  end
  if state.campaign ~= data.campaign or state.format_version ~= data.format_version then
    return false, "other"
  end
  local known = {}
  for _, entry in ipairs(data.zones) do
    known[entry.name] = true
    local saved = state.zones[entry.name]
    if type(saved) == "table" and saved.owner then
      entry.owner = saved.owner
      entry.garrison = saved.garrison
      entry.capture = saved.capture
      entry.structures = saved.structures or entry.structures
      entry.structures_side = saved.structures_side or entry.structures_side
      entry.saved_warehouse = saved.warehouse
      entry.reach = saved.reach
    end
  end
  for name in pairs(state.zones) do
    if not known[name] then
      logger:warn("the save holds zone [%s], which the campaign no longer has: dropped", tostring(name))
    end
  end
  if type(state.sides) == "table" then
    data.sides = state.sides
  end
  if type(state.scenery_destroyed) == "table" then
    data.scenery_destroyed = state.scenery_destroyed
  end
  veafCampaign.savedParts = type(state.parts) == "table" and state.parts or {}
  -- a convoy still on the road when the server stopped is not restored: its survivors go back to the
  -- reserve it was paid from, as between two missions, so a restart does not leak units
  for _, record in ipairs(type(state.convoys) == "table" and state.convoys or {}) do
    local reserve = veafCampaign.reserveOf(record.side)
    if reserve and type(record.alive) == "table" then
      for _, unitType in ipairs(record.alive) do
        local category = veafCampaign.reserveCategory(unitType)
        reserve[category] = (reserve[category] or 0) + 1
      end
    end
    -- and their price into the side's resources, bought or not: what survives comes home (ticket 12)
    if veafCampaign.SIDES[record.side] and type(record.alive) == "table" then
      veafCampaign.homecoming[record.side] = (veafCampaign.homecoming[record.side] or 0) + veafCampaign.unitsPrice(record.alive)
    end
  end
  return true
end

--- Reload a persistent campaign's save, if there is one to reload, and say what happened.
--- @return string "loaded", "fresh" (no save, or a reset one), "other", "unreadable" or "no-io"
function veafCampaign.loadSave()
  veafCampaign.savedParts = {}
  local state, why = veafCampaign.readSave()
  local logger = veaf.loggers.get(veafCampaign.Id)
  if not state then
    if why == "none" then
      logger:info("no save of the campaign: it starts from its declared state")
      return "fresh"
    end
    logger:error("the campaign's save could not be read (%s): it starts from its declared state", why)
    return why
  end
  local used, reason = veafCampaign.applySave(state)
  if used then
    logger:info("the campaign resumes from its save (simulation time %s)", tostring(state.simulation_time))
    return "loaded"
  end
  if reason == "reset" then
    logger:info("the campaign's save is marked reset (%s): a fresh campaign starts", tostring(state.outcome))
    return "fresh"
  end
  logger:error("the save is of another campaign or format: it starts from its declared state")
  return reason
end

--- What a module kept in the save, for it to take back once it is initialized.
--- @param name string the part's name in `veafCampaign.saveParts`
--- @return table|nil
function veafCampaign.savedPart(name)
  return veafCampaign.savedParts and veafCampaign.savedParts[name]
end

--- End a persistent campaign when one side holds no zone left: the enemy none is a victory, the players
--- none a defeat. Said to everyone; nothing more is captured nor sent, and every save from now on is
--- marked reset, so the next load of the mission starts a fresh campaign.
--- @return string|nil the outcome, when the campaign ended now
function veafCampaign.checkOutcome()
  if not veafCampaign.isPersistent() or veafCampaign.over then
    return nil
  end
  local held = { blue = 0, red = 0 }
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and held[zone.entry.owner] then
      held[zone.entry.owner] = held[zone.entry.owner] + 1
    end
  end
  local player = veafCampaign.playerSide()
  local outcome = (held[veafCampaign.enemyOf(player)] == 0 and "victory") or (held[player] == 0 and "defeat") or nil
  if outcome then
    veafCampaign.endCampaign(outcome)
  end
  return outcome
end

--- End the campaign: "victory", "defeat", or "reset" by an admin.
function veafCampaign.endCampaign(outcome)
  veafCampaign.over = outcome
  veaf.loggers.get(veafCampaign.Id):info("the campaign ends: %s", outcome)
  trigger.action.outText(veaf.t("campaign.outcome." .. outcome), 60)
  veafCampaign.notify("outcome", outcome)
  veafCampaign.writeState()
end

--- Radio command, for admins: start the campaign afresh at the next load of the mission.
function veafCampaign.resetCampaign()
  if veafCampaign.isPersistent() then
    veafCampaign.endCampaign("reset")
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Dormant zones (FEAT-DYNAMIC-CAMPAIGN ticket 02)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Whether zones sleep away from the players: always in a persistent campaign, in an episodic one only
--- when its data table sets a `wake_radius`.
function veafCampaign.dormancyEnabled()
  local dynamic = veafCampaign.data and veafCampaign.data.dynamic
  return veafCampaign.isPersistent() or (dynamic ~= nil and dynamic.wake_radius ~= nil)
end

--- Where the players' aircraft are: a list of vec3, both sides together, or one side's only.
--- @param side string|nil "red" or "blue"; nil for both
function veafCampaign.playerPoints(side)
  local points = {}
  for _, dcsSide in ipairs({ coalition.side.RED, coalition.side.BLUE }) do
    if not side or veafCampaign.SIDES[side] == dcsSide then
      for _, unit in ipairs(coalition.getPlayers(dcsSide) or {}) do
        if unit and unit.isExist and unit:isExist() then
          table.insert(points, unit:getPoint())
        end
      end
    end
  end
  return points
end

--- The names of the ground groups in the world, both sides: at the first dormancy pass, the ones the mission
--- was built with, which never wake a zone (a vehicle parked by the mission maker would keep its zone awake
--- forever). Not at initialize: the FARPs' vehicles (veafGrass) and the interpreter's groups come 1-2 s later.
--- @return table name → true
function veafCampaign.groundGroupNames()
  local names = {}
  for _, side in ipairs({ coalition.side.RED, coalition.side.BLUE }) do
    for _, group in ipairs(coalition.getGroups(side, Group.Category.GROUND) or {}) do
      if group and group.getName then
        names[group:getName()] = true
      end
    end
  end
  return names
end

--- The first living unit of a group, or nil. A late-activated group answers `isExist()` and `inAir()`
--- true before it is activated: only `isActive()` tells (docs/agents/dcs-runtime-traps.md).
local function firstUnit(group)
  for _, unit in ipairs(group and group.getUnits and group:getUnits() or {}) do
    if unit and unit.isExist and unit:isExist() and unit:isActive() then
      return unit
    end
  end
  return nil
end

--- What wakes an enemy zone besides the players (David, 2026-11-16), one point per group, by side: the
--- aircraft in the air, AI or not, and the ground groups that are neither a zone's garrison nor part of
--- the mission as it was built — convoys, troops dropped, spawns. A garrison waking its neighbour would
--- wake the whole map in a chain.
--- @return table by side ("red", "blue"): `{ air = { vec3 }, ground = { vec3 } }`
function veafCampaign.wakerPoints()
  local points = {}
  local built = veafCampaign.builtGroups or {}
  for side, dcsSide in pairs(veafCampaign.SIDES) do
    local air, ground = {}, {}
    for _, category in ipairs({ Group.Category.AIRPLANE, Group.Category.HELICOPTER }) do
      for _, group in ipairs(coalition.getGroups(dcsSide, category) or {}) do
        local unit = firstUnit(group)
        if unit and unit:inAir() then
          table.insert(air, unit:getPoint())
        end
      end
    end
    for _, group in ipairs(coalition.getGroups(dcsSide, Group.Category.GROUND) or {}) do
      local unit = not built[group:getName()] and firstUnit(group)
      if unit and not veafCampaign.unitIndex[unit:getName()] and veaf.isCombatant(unit) then
        table.insert(ground, unit:getPoint())
      end
    end
    points[side] = { air = air, ground = ground }
  end
  return points
end

--- The distance from a zone's centre to the nearest point of a list, in metres; nil for an empty list.
local function nearestDistance(zone, points)
  local center, best = zone:getCenter(), nil
  for _, point in ipairs(points) do
    local d2 = (point.x - center.x) ^ 2 + (point.z - center.z) ^ 2
    best = math.min(best or d2, d2)
  end
  return best and math.sqrt(best)
end

--- How far a zone's air defence reaches, in metres, for its dormancy: veafCampaignOps measures it, or
--- remembers it from the last time the zone was awake; 0 without that module.
--- @param zone table
--- @return number
function veafCampaign.zoneReach(zone)
  if veafCampaignOps and veafCampaignOps.threatRange then
    return (veafCampaignOps.threatRange(zone))
  end
  return 0
end

--- The front line, as the territory draws it on the F10 map: the edges between the Voronoi cells of zones
--- of different owners. Recomputed only when an owner changed.
--- @return table segments `{ { a = { x, z }, b = { x, z } } }`
function veafCampaign.frontSegments()
  local sites, owners = {}, {}
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed then
      table.insert(sites, { x = zone.entry.x, z = zone.entry.z })
      table.insert(owners, zone.entry.owner)
    end
  end
  local signature = table.concat(owners, "|")
  if veafCampaign.frontCache and veafCampaign.frontCache.signature == signature then
    return veafCampaign.frontCache.segments
  end
  local segments = {}
  for index, cell in ipairs(veafCampaign.voronoiCells(sites, veafCampaign.setting("territory", "margin"))) do
    for k, vertex in ipairs(cell) do
      local other = vertex.edge
      if other and other > index and owners[other] ~= owners[index] then
        table.insert(segments, { a = vertex, b = cell[k % #cell + 1] })
      end
    end
  end
  veafCampaign.frontCache = { signature = signature, segments = segments }
  return segments
end

--- How far a zone's centre is from the front line, in metres; math.huge when there is no front.
--- @param zone table
--- @return number
function veafCampaign.frontDistance(zone)
  local px, pz, best = zone.entry.x, zone.entry.z, math.huge
  for _, segment in ipairs(veafCampaign.frontSegments()) do
    local ax, az, bx, bz = segment.a.x, segment.a.z, segment.b.x, segment.b.z
    local dx, dz = bx - ax, bz - az
    local length2 = dx * dx + dz * dz
    local t = length2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (pz - az) * dz) / length2)) or 0
    local cx, cz = ax + t * dx, az + t * dz
    best = math.min(best, math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2))
  end
  return best
end

--- Whether a zone is on the front: connected to a zone its owner does not hold, or within `front_depth` of the
--- front line drawn on the map (David, 2026-11-16) — a zone just behind the line must not be empty when the
--- enemy goes round. The connection still counts: on a sparse map the line runs farther than `front_depth`
--- from two connected enemies.
--- @param zone table
--- @return boolean
function veafCampaign.isFront(zone)
  if veafCampaign.frontDistance(zone) <= veafCampaign.setting("front_depth") then
    return true
  end
  for _, neighbour in ipairs(veafCampaign.neighbours(zone.name)) do
    if neighbour.entry.owner ~= zone.entry.owner then
      return true
    end
  end
  return false
end

--- Why a zone is wanted awake, most pressing first: "always" (on the front, or the target of a sortie),
--- "player" (an enemy player within `wake_radius`, or within its air defence's reach plus
--- `reach_wake_margin` when that is longer), "ai" (an enemy aircraft in the air within that reach plus
--- the margin, or an enemy ground group within `ground_wake_radius`).
local WAKE_RANK = { always = 1, player = 2, ai = 3 }

--- One pass of the dormancy (David, 2026-11-16). A zone near the front line or targeted by a sortie is always
--- awake, outside `max_awake_zones`; a zone of the rear wakes for its enemies only, and only the rear
--- counts against the cap. One waking per pass, the most pressing first, then the nearest. When the cap
--- is reached, a zone waiting takes the place of an awake zone nobody wants any more, or of one wanted
--- for a lesser reason; between zones wanted by players the nearer takes the farther's place; between
--- zones wanted by AI the first one keeps it — moving aircraft swapped two zones at every pass
--- (measured 2026-11-16). Zones nobody has wanted for `sleep_seconds` go to sleep.
--- @param now number the mission time
function veafCampaign.updateDormancy(now)
  veafCampaign.builtGroups = veafCampaign.builtGroups or veafCampaign.groundGroupNames()
  local wakers = veafCampaign.wakerPoints()
  local radius, delay = veafCampaign.setting("wake_radius"), veafCampaign.setting("sleep_seconds")
  local groundRadius, margin = veafCampaign.setting("ground_wake_radius"), veafCampaign.setting("reach_wake_margin")
  local players = {}
  local awake, waking = {}, {}
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and veafCampaign.SIDES[zone.entry.owner] and zone.entry.garrison then
      local enemy = veafCampaign.enemyOf(zone.entry.owner)
      players[enemy] = players[enemy] or veafCampaign.playerPoints(enemy)
      local reach = veafCampaign.zoneReach(zone) + margin
      zone.playerDistance = nearestDistance(zone, players[enemy]) or math.huge
      local airDistance = nearestDistance(zone, wakers[enemy].air) or math.huge
      local groundDistance = nearestDistance(zone, wakers[enemy].ground) or math.huge
      zone.wakeDistance = math.min(zone.playerDistance, airDistance, groundDistance)
      if (zone.keepAwakeUntil or 0) > now or veafCampaign.isFront(zone) then
        zone.wakeReason = "always"
      elseif zone.playerDistance <= math.max(radius, reach) then
        zone.wakeReason = "player"
      elseif airDistance <= reach or groundDistance <= groundRadius then
        zone.wakeReason = "ai"
      else
        zone.wakeReason = nil
      end
      if zone.wakeReason then
        zone.wantedAt = now
      end
      if zone.awake then
        if now - (zone.wantedAt or -math.huge) >= delay then
          zone:sleep("nobody has come near it")
        elseif zone.wakeReason ~= "always" then
          table.insert(awake, zone)
        end
      elseif zone.wakeReason then
        table.insert(waking, zone)
      end
    end
  end
  local rank = function(zone)
    return WAKE_RANK[zone.wakeReason] or 4
  end
  table.sort(waking, function(a, b)
    if rank(a) ~= rank(b) then
      return rank(a) < rank(b)
    end
    return a.wakeDistance < b.wakeDistance
  end)
  local candidate = waking[1]
  if not candidate then
    return
  end
  if candidate.wakeReason ~= "always" and #awake >= veafCampaign.setting("max_awake_zones") then
    -- full: the one that gives its place is the least wanted, the farthest at the same rank
    table.sort(awake, function(a, b)
      if rank(a) ~= rank(b) then
        return rank(a) > rank(b)
      end
      return a.wakeDistance > b.wakeDistance
    end)
    local victim = awake[1]
    local lesser = rank(victim) > rank(candidate)
    local nearerPlayer = rank(victim) == WAKE_RANK.player
      and candidate.wakeReason == "player"
      and candidate.playerDistance < victim.playerDistance
    if not (lesser or nearerPlayer) then
      return
    end
    victim:sleep(string.format("it gives its place to [%s]", candidate.name))
  end
  candidate:wake()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Loop and events
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- One beat of the module's single loop: every zone is visited once, the state written when due.
function veafCampaign.beat()
  local now = timer.getTime()
  veafCampaign.counters.beats = veafCampaign.counters.beats + 1
  if not veafCampaign.over then
    veafCampaign.launchDueAssaults(now)
  end
  for _, record in ipairs(veafCampaign.convoys) do
    veafCampaign.refreshConvoy(record)
    veafCampaign.checkConvoyGoal(record, now)
    veafCampaign.reportConvoy(record, now)
  end
  if veafCampaign.isPersistent() then
    veafCampaign.launchOffensives(now)
  end
  if veafCampaign.dormancyEnabled() then
    veafCampaign.updateDormancy(now)
  end
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed then
      veafCampaign.counters.zonesProcessed = veafCampaign.counters.zonesProcessed + 1
      zone:checkCapture(veafCampaign.BEAT_SECONDS)
      if veafCampaign.isPersistent() and not veafCampaign.over then
        veafCampaign.collectDeliveries(zone)
      end
      zone:draw()
    end
  end
  for _, hook in ipairs(veafCampaign.beatHooks) do
    local ok, problem = pcall(hook, now)
    if not ok then
      veaf.loggers.get(veafCampaign.Id):error("a beat hook failed: %s", tostring(problem))
    end
  end
  if now >= veafCampaign.nextStateWrite then
    veafCampaign.nextStateWrite = now + veafCampaign.writeInterval()
    veafCampaign.writeState()
  end
end

--- Seconds between two writes of the state: a persistent campaign's `save_seconds`, an episodic one's
--- `state_write_seconds`.
function veafCampaign.writeInterval()
  if veafCampaign.isPersistent() then
    return veafCampaign.setting("save_seconds")
  end
  return veafCampaign.data.state_write_seconds or veafCampaign.STATE_WRITE_SECONDS
end

--- The player's unit an event comes from, or nil. A callback of veafEventHandler receives `initiator` as
--- a data table with no methods (`veafEventHandler.transformEvent`); the DCS object is `dcsInitiator`.
--- Reading the method on the data table fails silently: no error, the handler simply never fires.
--- @param event table the event as veafEventHandler hands it over
--- @return table|nil the DCS unit
--- @return string|nil the player's name
function veafCampaign.playerUnitOf(event)
  local unit = event and (event.dcsInitiator or event.initiator)
  if not (unit and unit.getPlayerName) then
    return nil
  end
  local ok, player = pcall(unit.getPlayerName, unit)
  if not ok or not player then
    return nil
  end
  return unit, player
end

--- What a kill event says, for the campaign: a player of the players' side destroyed an enemy unit.
--- @param event table the S_EVENT_KILL as veafEventHandler hands it over: `dcsInitiator` the killer's
---   DCS unit, `target` a data table (`unitCoalition`, `unitCategory`)
--- @return table|nil `{ unit, player, air }`, nil for any other kill
function veafCampaign.readPlayerKill(event)
  local unit, player = veafCampaign.playerUnitOf(event)
  local target = event and event.target
  if not (unit and target) then
    return nil
  end
  local own = veafCampaign.SIDES[veafCampaign.playerSide()]
  local targetSide = target.unitCoalition
  if targetSide == nil and target.getCoalition then
    targetSide = target:getCoalition()
  end
  if unit:getCoalition() ~= own or targetSide == nil or targetSide == own or targetSide == coalition.side.NEUTRAL then
    return nil
  end
  local category = target.unitCategory
  if category == nil and target.getDesc then
    category = target:getDesc().category
  end
  return { unit = unit, player = player, air = category == Unit.Category.AIRPLANE or category == Unit.Category.HELICOPTER }
end

--- A unit died or was lost: if it is a garrison unit, record it.
function veafCampaign.onUnitDead(event)
  local name = veafEventHandler.unitNameFromEvent(event)
  if not name and event and event.dcsInitiator and event.dcsInitiator.getName then
    name = event.dcsInitiator:getName()
  end
  local where = name and veafCampaign.unitIndex[name]
  if where then
    veafCampaign.counters.eventsHandled = veafCampaign.counters.eventsHandled + 1
    where.zone:onUnitLost(where.group, where.unit)
    where.zone:draw()
  end
  local building = name and veafCampaign.structureIndex[name]
  if building then
    veafCampaign.counters.eventsHandled = veafCampaign.counters.eventsHandled + 1
    building.zone:onStructureLost(building.index)
    building.zone:draw()
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
  veafCampaign.structureIndex, veafCampaign.homecoming, veafCampaign.territoryMarks = {}, {}, {}
  veafCampaign.territorySignature, veafCampaign.frontCache = nil, nil
  veafCampaign.convoys, veafCampaign.pendingAssaults, veafCampaign.assaultPath = {}, {}, nil
  veafCampaign.nextAttack, veafCampaign.over, veafCampaign.savedParts = {}, nil, {}
  veafCampaign.beatHooks, veafCampaign.selfChecks = {}, {}
  veafCampaign.builtGroups = nil -- taken at the first dormancy pass
  veafCampaign.counters = {
    structuresLost = 0,
    territoryDrawings = 0,
    beats = 0,
    zonesProcessed = 0,
    drawings = 0,
    spawns = 0,
    eventsHandled = 0,
    stateWrites = 0,
    wakes = 0,
    sleeps = 0,
    reinforcements = 0,
  }
  local data = veafCampaign.data
  if type(data) ~= "table" or type(data.zones) ~= "table" then
    veaf.loggers.get(veafCampaign.Id):warn("no campaign data in this mission; the campaign module does nothing")
    return false
  end
  if veafCampaign.isPersistent() then
    veafCampaign.loadResult = veafCampaign.loadSave()
  end
  for _, entry in ipairs(data.zones) do
    local zone = VeafCampaignZone:new(entry)
    -- a zone that cannot be placed stays in the state, untouched, and out of everything else
    zone.placed = zone:resolvePosition()
    veafCampaign.zones[zone.name] = zone
    table.insert(veafCampaign.zoneList, zone)
  end
  veafCampaign.toldOnce = {}
  if veafCampaign.isPersistent() then
    veafCampaign.freezeAirfields()
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
      if veafCampaign.dormancyEnabled() then
        zone.awake = false -- asleep until a player comes near (ticket 02)
      else
        zone:spawnGarrison()
      end
    end
    -- a factory's buildings are always in the world: a static costs no AI (ticket 11)
    if zone.placed and zone:isFactory() then
      if not zone.entry.structures then
        zone:drawStructures()
      end
      zone:spawnStructures()
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
  veafCampaign.nextStateWrite = timer.getTime() + veafCampaign.writeInterval()
  -- the persistent campaign's sorties, credits, tasks and intelligence: modules of their own, started here
  -- so that the mission's configuration only ever names CAMPAIGN
  veafCampaign.drawTerritory()
  if veafCampaign.isPersistent() then
    -- logistics first: the others pay their sorties and purchases from what it loaded
    for _, name in ipairs({ "veafCampaignLogistics", "veafCampaignOps", "veafCampaignEconomy" }) do
      local module = _G[name] -- by name: a module left out of the mission is skipped, not the end of the list
      if module and module.initialize then
        local ok, problem = pcall(module.initialize)
        if not ok then
          veaf.loggers.get(veafCampaign.Id):error("a campaign module failed to start: %s", tostring(problem))
        end
      end
    end
  end
  veafCampaign.buildAdminMenu()
  veafCampaign.loopId =
    veafScheduler.scheduleFunction(veafCampaign.beat, nil, timer.getTime() + veafCampaign.BEAT_SECONDS, veafCampaign.BEAT_SECONDS)
  return true
end

veaf.loggers.get(veafCampaign.Id):info(veaf.loggers.get(veafCampaign.Id):getVersionInfo())

veaf.registerModule(veafCampaign.Id, veafCampaign.initialize, { enable = true }, 240)
