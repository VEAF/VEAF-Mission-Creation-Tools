------------------------------------------------------------------
-- VEAF runtime spawner for DCS World
-- By Zip (2026)
--
-- Features:
-- ---------
-- * Create static objects at runtime, without MiST
--
-- This module is the adapter over the DCS calls that put things into the running world --
-- `coalition.addStaticObject` today, `coalition.addGroup` when DROP-MIST ticket 07's second half
-- lands. It is deliberately *not* called veafSpawn-anything: `veafSpawn*` is the family that reads a
-- mission maker's command, while this is what finally asks DCS for an object.
------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafDcsSpawner = {}

--- Identifier. All output in the log will start with this.
veafDcsSpawner.Id = "SPAWNER"

-- trace level, specific to this module (uncomment for debugging)
--veafDcsSpawner.LogLevel = "trace"

veaf.loggers.new(veafDcsSpawner.Id, veafDcsSpawner.LogLevel)

--- The shape a static type is drawn with, when its table does not say.
---
--- DCS needs `shape_name` for a structure, and a mission maker asking for one by type through
--- `-spawn static` never supplies it. Ported verbatim from `mist.DBs.const.shapeNames` (124 entries):
--- **93 of them are types VEAF's own 873-unit catalogue can resolve**, so they are reachable by
--- command — `.Ammunition depot`, `Barracks 2`, `Cafe`, `Boiler-house A` and the like. The other 31
--- only the Mission Editor can place; they are kept anyway rather than filtered, because a filtered
--- copy would silently go stale the day the catalogue grows.
---
--- Objects that carry their own shape never reach this table: the FARP, the windsock and the runway
--- cones all pass `shape_name` explicitly.
veafDcsSpawner.SHAPE_NAMES = {
  ["Landmine"] = "landmine",
  ["FARP CP Blindage"] = "kp_ug",
  ["Subsidiary structure C"] = "saray-c",
  ["Barracks 2"] = "kazarma2",
  ["Small house 2C"] = "dom2c",
  ["Military staff"] = "aviashtab",
  ["Tech hangar A"] = "ceh_ang_a",
  ["Oil derrick"] = "neftevyshka",
  ["Tech combine"] = "kombinat",
  ["Garage B"] = "garage_b",
  ["Airshow_Crowd"] = "Crowd1",
  ["Hangar A"] = "angar_a",
  ["Repair workshop"] = "tech",
  ["Subsidiary structure D"] = "saray-d",
  ["FARP Ammo Dump Coating"] = "SetkaKP",
  ["Small house 1C area"] = "dom2c-all",
  ["Tank 2"] = "airbase_tbilisi_tank_01",
  ["Boiler-house A"] = "kotelnaya_a",
  ["Workshop A"] = "tec_a",
  ["Small werehouse 1"] = "s1",
  ["Garage small B"] = "garagh-small-b",
  ["Small werehouse 4"] = "s4",
  ["Shop"] = "magazin",
  ["Subsidiary structure B"] = "saray-b",
  ["FARP Fuel Depot"] = "GSM Rus",
  ["Coach cargo"] = "wagon-gruz",
  ["Electric power box"] = "tr_budka",
  ["Tank 3"] = "airbase_tbilisi_tank_02",
  ["Red_Flag"] = "H-flag_R",
  ["Container red 3"] = "konteiner_red3",
  ["Garage A"] = "garage_a",
  ["Hangar B"] = "angar_b",
  ["Black_Tyre"] = "H-tyre_B",
  ["Cafe"] = "stolovaya",
  ["Restaurant 1"] = "restoran1",
  ["Subsidiary structure A"] = "saray-a",
  ["Container white"] = "konteiner_white",
  ["Warehouse"] = "sklad",
  ["Tank"] = "bak",
  ["Railway crossing B"] = "pereezd_small",
  ["Subsidiary structure F"] = "saray-f",
  ["Farm A"] = "ferma_a",
  ["Small werehouse 3"] = "s3",
  ["Water tower A"] = "wodokachka_a",
  ["Railway station"] = "r_vok_sd",
  ["Coach a tank blue"] = "wagon-cisterna_blue",
  ["Supermarket A"] = "uniwersam_a",
  ["Coach a platform"] = "wagon-platforma",
  ["Garage small A"] = "garagh-small-a",
  ["TV tower"] = "tele_bash",
  ["Comms tower M"] = "tele_bash_m",
  ["Small house 1A"] = "domik1a",
  ["Farm B"] = "ferma_b",
  ["GeneratorF"] = "GeneratorF",
  ["Cargo1"] = "ab-212_cargo",
  ["Container red 2"] = "konteiner_red2",
  ["Subsidiary structure E"] = "saray-e",
  ["Coach a passenger"] = "wagon-pass",
  ["Black_Tyre_WF"] = "H-tyre_B_WF",
  ["Electric locomotive"] = "elektrowoz",
  ["Shelter"] = "ukrytie",
  ["Coach a tank yellow"] = "wagon-cisterna_yellow",
  ["Railway crossing A"] = "pereezd_big",
  [".Ammunition depot"] = "SkladC",
  ["Small werehouse 2"] = "s2",
  ["Windsock"] = "H-Windsock_RW",
  ["Shelter B"] = "ukrytie_b",
  ["Fuel tank"] = "toplivo-bak",
  ["Locomotive"] = "teplowoz",
  [".Command Center"] = "ComCenter",
  ["Pump station"] = "nasos",
  ["Black_Tyre_RF"] = "H-tyre_B_RF",
  ["Coach cargo open"] = "wagon-gruz-otkr",
  ["Subsidiary structure 3"] = "hozdomik3",
  ["FARP Tent"] = "PalatkaB",
  ["White_Tyre"] = "H-tyre_W",
  ["Subsidiary structure G"] = "saray-g",
  ["Container red 1"] = "konteiner_red1",
  ["Small house 1B area"] = "domik1b-all",
  ["Subsidiary structure 1"] = "hozdomik1",
  ["Container brown"] = "konteiner_brown",
  ["Small house 1B"] = "domik1b",
  ["Subsidiary structure 2"] = "hozdomik2",
  ["Chemical tank A"] = "him_bak_a",
  ["WC"] = "WC",
  ["Small house 1A area"] = "domik1a-all",
  ["White_Flag"] = "H-Flag_W",
  ["Airshow_Cone"] = "Comp_cone",
  ["Bulk Cargo Ship Ivanov"] = "barge-1",
  ["Bulk Cargo Ship Yakushev"] = "barge-2",
  ["Outpost"] = "block",
  ["Road outpost"] = "block-onroad",
  ["Container camo"] = "bw_container_cargo",
  ["Tech Hangar A"] = "ceh_ang_a",
  ["Bunker 1"] = "dot",
  ["Bunker 2"] = "dot2",
  ["Tanker Elnya 160"] = "elnya",
  ["F-shape barrier"] = "f_bar_cargo",
  ["Helipad Single"] = "farp",
  ["FARP_SINGLE_01"] = "farp",
  ["FARP"] = "farps",
  ["Invisible FARP"] = "invisiblefarp",
  ["Fueltank"] = "fueltank_cargo",
  ["Gate"] = "gate",
  ["Armed house"] = "home1_a",
  ["FARP Command Post"] = "kp-ug",
  ["Watch Tower Armed"] = "ohr-vyshka",
  ["Oiltank"] = "oiltank_cargo",
  ["Pipes small"] = "pipes_small_cargo",
  ["Pipes big"] = "pipes_big_cargo",
  ["Oil platform"] = "plavbaza",
  ["Tetrapod"] = "tetrapod_cargo",
  ["Trunks long"] = "trunks_long_cargo",
  ["Trunks small"] = "trunks_small_cargo",
  ["Passenger liner"] = "yastrebow",
  ["Passenger boat"] = "zwezdny",
  ["Oil rig"] = "oil_platform",
  ["Gas platform"] = "gas_platform",
  ["Container 20ft"] = "container_20ft",
  ["Container 40ft"] = "container_40ft",
  ["Downed pilot"] = "cadaver",
  ["Parachute"] = "parash",
  ["Pilot F15 Parachute"] = "pilot_f15_parachute",
  ["Pilot standing"] = "pilot_parashut",
}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Resolve a country given either its name or its id.
---
--- A name is matched case-insensitively with spaces turned into underscores, which is how
--- `country.name` spells them (`"United States of America"` → `USA` is *not* one of these; the entry
--- really is `"USA"`, while `"South Korea"` is `SOUTH_KOREA`). Returns the canonical name, or nil.
---
--- @param wanted string|number a country name or id
--- @return string|nil the name as `country.name` spells it
local function resolveCountry(wanted)
  if wanted == nil then
    return nil
  end
  if type(wanted) == "number" then
    for countryId, countryName in pairs(country.name) do
      if countryId == wanted then
        return countryName
      end
    end
    return nil
  end
  local normalised = string.upper(tostring(wanted):gsub("%s+", "_"))
  for _, countryName in pairs(country.name) do
    if tostring(countryName) == normalised then
      return countryName
    end
  end
  return nil
end

--- Create a static object in the running mission.
---
--- Replaces `mist.dynAddStatic`, and reproduces what its 18 VEAF call sites depend on. Four of those
--- behaviours are load-bearing and easy to lose in a port, so they are named here:
---
---  * **The MiST wrapper form.** `veafSpawnAircraft` passes `{ country, groupName, units = { … } }`
---    rather than a flat object. The first unit is flattened into the object, as MiST did.
---  * **The random heading.** An object with no heading gets one at random. Nothing in
---    `veafSpawnEffects` sets a heading, so defaulting to zero would line every cargo drop up on the
---    same axis — visible in game, invisible to a test.
---  * **`mass` forces the Cargos category**, whatever the caller said.
---  * **`categoryStatic` is an alias for `category`**, which is the spelling `veafGrass` uses
---    throughout for its FARP furniture.
---
--- **Coordinates.** A static's table is the mission-table shape: `x` is the northing and **`y` is the
--- easting** — `veafSpawnGround.lua` writes `["y"] = spawnPosition.z`. See
--- `docs/agents/dcs-coordinates.md`. Getting this wrong raises no error, it only misplaces the object.
---
--- @param objectData table the static's definition
--- @return table|false the object as it was submitted, or false when it could not be created
function veafDcsSpawner.addStatic(objectData)
  if type(objectData) ~= "table" then
    veaf.loggers.get(veafDcsSpawner.Id):error("addStatic: no object data")
    return false
  end
  local object = veaf.deepCopy(objectData)

  -- The MiST wrapper form: hoist the single unit's fields onto the object itself.
  if object.units and object.units[1] then
    for key, value in pairs(object.units[1]) do
      object[key] = value
    end
  end

  local countryName = resolveCountry(object.countryId or object.country)
  if not countryName then
    veaf.loggers.get(veafDcsSpawner.Id):error("addStatic: country not found: %s", veaf.p(object.countryId or object.country))
    return false
  end

  if object.clone or not object.groupId then
    object.groupId = veaf.getNextUnitId()
  end
  if object.clone or not object.unitId then
    object.unitId = veaf.getNextUnitId()
  end

  object.name = object.name or object.unitName
  if object.clone or not object.name then
    object.name = string.format("%s static %s", countryName, veaf.getNextUnitId())
  end

  if object.dead == nil then
    object.dead = false
  end

  if not object.heading then
    object.heading = math.rad(math.random(360))
  end

  if object.categoryStatic then
    object.category = object.categoryStatic
  end
  if object.mass then
    object.category = "Cargos"
  end

  if object.shapeName then
    object.shape_name = object.shapeName
  end
  if not object.shape_name and object.type then
    object.shape_name = veafDcsSpawner.SHAPE_NAMES[object.type]
  end

  if type(object.x) ~= "number" or type(object.y) ~= "number" or type(object.type) ~= "string" then
    veaf.loggers
      .get(veafDcsSpawner.Id)
      :error("addStatic: refusing an object with x=%s y=%s type=%s", veaf.p(object.x), veaf.p(object.y), veaf.p(object.type))
    return false
  end

  coalition.addStaticObject(country.id[countryName], object)
  veaf.loggers.get(veafDcsSpawner.Id):trace("addStatic: created [%s] of type [%s]", veaf.p(object.name), veaf.p(object.type))
  return object
end

--- A group's route as the Mission Editor drew it, projected into the fields a caller reads.
---
--- Replaces `veaf.getGroupRoute(name)`. Every one of the eight VEAF call sites passed `"task"`,
--- so the task-less form is not ported: a route without its tasks has no caller here.
---
--- This is a **projection, not the raw route**: MiST built a new point table with ten named fields and
--- callers depend on that shape — `veafMove` reads `.speed` and `.alt`, `veafCombatZone` stores the
--- result and hands it back to a spawn. Returning `env.mission`'s own points instead would hand callers
--- a table they could mutate, and MiST never did.
---
--- @param groupName string the name of a group placed in the Mission Editor
--- @return table|nil the route points, or nil when the group is unknown or has no route
function veafDcsSpawner.getGroupRoute(groupName)
  local group = veafMissionDb.getGroupRecord(groupName)
  if not group then
    veaf.loggers.get(veafDcsSpawner.Id):debug("getGroupRoute: no group named [%s] in the mission", veaf.p(groupName))
    return nil
  end
  if not (group.route and group.route.points and #group.route.points > 0) then
    veaf.loggers.get(veafDcsSpawner.Id):debug("getGroupRoute: group [%s] has no route", veaf.p(groupName))
    return nil
  end

  local points = {}
  for index, point in pairs(group.route.points) do
    local projected = {
      name = point.name,
      form = point.action,
      speed = point.speed,
      alt = point.alt,
      alt_type = point.alt_type,
      airdromeId = point.airdromeId,
      helipadId = point.helipadId,
      type = point.type,
      action = point.action,
      task = point.task,
    }
    -- The Mission Editor writes either loose x/y or a `point` vec2; both shapes exist in the wild.
    if point.point then
      projected.point = point.point
    else
      projected.x = point.x
      projected.y = point.y
    end
    points[index] = projected
  end
  return points
end

--- Send a group along a route, now.
---
--- Replaces `mist.goRoute`. Accepts either a group object or a group name, because both forms are in
--- use — `veaf.lua` and `veafSpawnCore` pass the object, the other seven sites pass the name.
---
--- @param groupOrName table|string a DCS group, or the name of one
--- @param route table the route points
--- @return boolean true when the task was set
function veafDcsSpawner.goRoute(groupOrName, route)
  local group = groupOrName
  if type(groupOrName) == "string" then
    group = Group.getByName(groupOrName)
  end
  if not (group and group.getController) then
    veaf.loggers.get(veafDcsSpawner.Id):debug("goRoute: no such group [%s]", veaf.p(groupOrName))
    return false
  end
  local controller = group:getController()
  if not controller then
    return false
  end
  controller:setTask({
    id = "Mission",
    params = { route = { points = veaf.deepCopy(route) } },
  })
  return true
end

--- Category names DCS accepts for a group, and the spellings VEAF actually passes.
---
--- MiST tolerated four aliases and our call sites use two of them: `veafSpawnAircraft` passes `"PLANE"`
--- where `veafSpawnCore` passes `"AIRPLANE"`, for the same thing. A port accepting only the canonical
--- spelling would break the first one **silently**, because an unresolved category leaves the group
--- type nil and the group is submitted anyway.
veafDcsSpawner.GROUP_CATEGORIES = {
  GROUND_UNIT = "GROUND_UNIT",
  VEHICLE = "GROUND_UNIT",
  GROUND = "GROUND_UNIT",
  AIRPLANE = "AIRPLANE",
  PLANE = "AIRPLANE",
  HELICOPTER = "HELICOPTER",
  SHIP = "SHIP",
  BUILDING = "BUILDING",
}

--- Default cruise settings per aircraft category, applied to a unit that carries none.
--- MiST's numbers, kept as they are: a spawned aircraft that suddenly cruises at a different speed or
--- altitude is a behaviour change a mission maker would notice before any test would.
veafDcsSpawner.AIRCRAFT_DEFAULTS = {
  AIRPLANE = { speed = 150, alt = 2000 },
  HELICOPTER = { speed = 60, alt = 500 },
}

--- Resolve a group category name or id to the spelling DCS wants.
--- @param wanted string|number
--- @return string|nil
local function resolveCategory(wanted)
  if type(wanted) == "number" then
    for name, id in pairs(Unit.Category) do
      if id == wanted then
        return veafDcsSpawner.GROUP_CATEGORIES[name]
      end
    end
    return nil
  end
  if type(wanted) ~= "string" then
    return nil
  end
  return veafDcsSpawner.GROUP_CATEGORIES[string.upper(wanted)]
end

--- Create a group in the running mission.
---
--- Replaces `mist.dynAdd`. What it fills in for a caller who left it out is behaviour, not tidying, so
--- each default is reproduced deliberately:
---
---  * a **group id** and a **unit id** per unit, from VEAF's own allocator;
---  * a **group name**, and a unit name per unit built from it (`"<group> unit<N>"`);
---  * `skill` = `"Random"`;
---  * for aircraft only: `alt_type` = `RADIO`, and the cruise speed and altitude above — plus the
---    **payload read from the mission**, which is why the snapshot carries it: `veafSpawnCore` builds
---    `AIRPLANE` groups with no payload field at all;
---  * for ground units: `playerCanDrive` = true;
---  * an empty route for an aircraft that has none, or DCS sends it straight home.
---
--- **Coordinates.** A unit's table is the mission-table shape: `x` northing, `y` easting. See
--- `docs/agents/dcs-coordinates.md`.
---
--- @param groupData table the group definition
--- @return table|false the group as submitted, or false when it could not be created
function veafDcsSpawner.addGroup(groupData)
  if type(groupData) ~= "table" then
    veaf.loggers.get(veafDcsSpawner.Id):error("addGroup: no group data")
    return false
  end
  local group = veaf.deepCopy(groupData)

  local countryName = resolveCountry(group.countryId or group.country)
  if not countryName then
    veaf.loggers.get(veafDcsSpawner.Id):error("addGroup: country not found: %s", veaf.p(group.countryId or group.country))
    return false
  end

  local category = resolveCategory(group.category)
  if not category then
    -- Loud, where MiST was silent: it left the type nil and submitted the group anyway, so a misspelled
    -- category produced a group DCS could not classify and nobody was told.
    veaf.loggers.get(veafDcsSpawner.Id):error("addGroup: unknown category: %s", veaf.p(group.category))
    return false
  end

  if type(group.units) ~= "table" or not group.units[1] then
    veaf.loggers.get(veafDcsSpawner.Id):error("addGroup: a group needs at least one unit")
    return false
  end

  group.groupId = group.groupId or veaf.getNextUnitId()
  group.name = group.groupName or group.name
  if not group.name then
    group.name = string.format("%s %s %s", countryName, string.lower(category), group.groupId)
  end

  if group.hidden == nil then
    group.hidden = false
  end
  if group.visible == nil then
    group.visible = false
  end
  if type(group.start_time) ~= "number" then
    group.start_time = group.startTime and veaf.round(group.startTime, 0) or 0
  end

  for index, unit in ipairs(group.units) do
    unit.unitId = unit.unitId or veaf.getNextUnitId()
    unit.name = unit.unitName or unit.name or string.format("%s unit%d", group.name, index)
    unit.skill = unit.skill or "Random"

    if category == "AIRPLANE" or category == "HELICOPTER" then
      local defaults = veafDcsSpawner.AIRCRAFT_DEFAULTS[category]
      if unit.alt_type ~= "BARO" then
        unit.alt_type = "RADIO"
      end
      unit.speed = unit.speed or defaults.speed
      if not unit.alt then
        unit.alt = defaults.alt
        unit.alt_type = "RADIO"
        unit.speed = defaults.speed
      end
      if not unit.payload then
        -- The loadout of the editor unit this one is modelled on. Held by reference in the snapshot,
        -- exactly as MiST's getPayload returned it.
        local record = veafMissionDb.getUnitRecord(unit.unitName or unit.name)
        unit.payload = record and record.payload or nil
      end
    elseif category == "GROUND_UNIT" then
      if unit.playerCanDrive == nil then
        unit.playerCanDrive = true
      end
    end
  end

  -- A route given as a bare list of points is wrapped; an aircraft with no route at all gets an empty
  -- one, without which DCS sends it home the moment it spawns.
  if group.route and not group.route.points and group.route[1] then
    group.route = { points = group.route }
  elseif not group.route and (category == "AIRPLANE" or category == "HELICOPTER") then
    group.route = { points = { {} } }
  end

  -- Tasks that name the group or its first unit have to point at the ids just allocated.
  if group.route and group.route.points then
    for _, point in pairs(group.route.points) do
      local tasks = point.task and point.task.params and point.task.params.tasks
      for _, task in pairs(tasks or {}) do
        local action = task.params and task.params.action
        if action and action.id == "EPLRS" then
          action.params.groupId = group.groupId
        elseif action and (action.id == "ActivateBeacon" or action.id == "ActivateICLS") then
          action.params.unitId = group.units[1].unitId
        end
      end
    end
  end

  -- DCS reads the country and category from the call, not from the table, and chokes on VEAF's own
  -- bookkeeping fields.
  group.groupName, group.category, group.country, group.countryId, group.startTime = nil, nil, nil, nil, nil
  group.tasks = {}
  for _, unit in ipairs(group.units) do
    unit.unitName = nil
  end

  coalition.addGroup(country.id[countryName], Unit.Category[category], group)
  veaf.loggers.get(veafDcsSpawner.Id):trace("addGroup: created [%s] with %d unit(s)", veaf.p(group.name), #group.units)
  return group
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Framework façades. Callers use `veaf.*` and never name the implementation.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.addStatic = veafDcsSpawner.addStatic
veaf.addGroup = veafDcsSpawner.addGroup
veaf.getGroupRoute = veafDcsSpawner.getGroupRoute
veaf.goRoute = veafDcsSpawner.goRoute

function veafDcsSpawner.initialize()
  veaf.loggers.get(veafDcsSpawner.Id):info("Initializing module")
end

veaf.loggers.get(veafDcsSpawner.Id):info(veaf.loggers.get(veafDcsSpawner.Id):getVersionInfo())
