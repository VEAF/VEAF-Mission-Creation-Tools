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
---    `veafSpawnObjects` sets a heading, so defaulting to zero would line every cargo drop up on the
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
--- How many suffixes to try before falling back to an id.
---
--- A ceiling rather than a real limit: reaching it needs 98 live groups derived from one name. It
--- exists so a bug in `isNameTaken` cannot turn this into an endless loop at spawn time.
veafDcsSpawner.MAX_NAME_ATTEMPTS = 100

--- A name close to `taken` that nothing is using yet.
---
--- MiST's answer here was `country .. type .. index`, which told a mission maker nothing about what
--- the group was: a clone of `Arco` came back as `USAKC-1353`. Suffixing keeps the lineage readable
--- in the F10 map and in the logs, which is where these names are actually read.
---
--- @param taken string the name that is already in use
--- @return string a free name
function veafDcsSpawner.freeNameFrom(taken)
  local base = tostring(taken or "group")
  for suffix = 2, veafDcsSpawner.MAX_NAME_ATTEMPTS do
    local candidate = string.format("%s #%d", base, suffix)
    if not veaf.isNameTaken(candidate) then
      return candidate
    end
  end
  -- Unique by construction: the id allocator never hands the same number out twice.
  return string.format("%s #%s", base, veaf.getNextUnitId())
end

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

  -- Registered here, at the submission boundary, rather than where the name was chosen. Two reasons,
  -- both found in review:
  --
  --  * every path above this line can still refuse the group — a terrain rejection, a unit with no
  --    position. Reserving earlier left a name held forever by a group that was never created, and
  --    the next clone stepped over it.
  --  * a caller may rename the group between building it and submitting it, which is exactly what
  --    `veafCombatMission` does after `buildCloneData()`. Registering the chosen name would have
  --    recorded one name while DCS received another, blocking the first and protecting neither.
  --
  -- So what gets recorded is what DCS was actually given.
  veaf.takeSpawnedName(group.name)

  veaf.loggers.get(veafDcsSpawner.Id):trace("addGroup: created [%s] with %d unit(s)", veaf.p(group.name), #group.units)
  return group
end

--- Terrain a group of this category may be put on, when the caller does not say.
---
--- Ported from `mist.teleportToPoint`, including the reason a runway is valid ground: DCS reports a
--- dam's surface as `RUNWAY`, and a convoy refused a bridge crossing would be a visible regression.
--- A category with no entry here accepts any surface, which is what MiST did.
veafDcsSpawner.TERRAIN_BY_CATEGORY = {
  ship = { "SHALLOW_WATER", "WATER" },
  vehicle = { "LAND", "ROAD", "RUNWAY" },
  ground_unit = { "LAND", "ROAD", "RUNWAY" },
}

--- The editor's word for each `Group.Category`, so a category never travels as a bare number.
veafDcsSpawner.EDITOR_CATEGORY_BY_GROUP_CATEGORY = {
  [Group.Category.AIRPLANE] = "plane",
  [Group.Category.HELICOPTER] = "helicopter",
  [Group.Category.GROUND] = "vehicle",
  [Group.Category.SHIP] = "ship",
}

--- Every surface a spawn accepts when nothing narrows it down.
veafDcsSpawner.ANY_TERRAIN = { "LAND", "ROAD", "SHALLOW_WATER", "WATER", "RUNWAY" }

--- Is this point on one of these surfaces?
---
--- Replaces `mist.isTerrainValid`. Accepts either coordinate shape — a vec3's `z` is the easting that
--- `land.getSurfaceType` wants as `y`, which is the confusion `docs/agents/dcs-coordinates.md` exists
--- for.
---
--- @param point table a vec2 (x, y) or a vec3 (x, y, z)
--- @param surfaces table|string a surface name, or a list of them
--- @return boolean
function veafDcsSpawner.isTerrainValid(point, surfaces)
  if type(point) ~= "table" or type(point.x) ~= "number" then
    return false
  end
  local flat = { x = point.x, y = point.z or point.y }
  if type(flat.y) ~= "number" then
    return false
  end

  local wanted = surfaces
  if type(wanted) == "string" then
    wanted = { wanted }
  end
  if type(wanted) ~= "table" then
    return false
  end

  local actual = land.getSurfaceType(flat)
  for _, name in pairs(wanted) do
    if type(name) == "string" and land.SurfaceType[string.upper(name)] == actual then
      return true
    end
  end
  return false
end

--- The surfaces a group of this category may stand on.
--- @param category string|nil the group's category, in any spelling
--- @return table a list of surface names
function veafDcsSpawner.terrainForCategory(category)
  if type(category) ~= "string" then
    return veafDcsSpawner.ANY_TERRAIN
  end
  return veafDcsSpawner.TERRAIN_BY_CATEGORY[string.lower(category)] or veafDcsSpawner.ANY_TERRAIN
end

--- A group's definition as it stands **right now** — live positions, live ids, live units.
---
--- Replaces `mist.getCurrentGroupData`, the source the `teleport` verb reads (as opposed to `clone` and
--- `respawn`, which read the editor definition). It starts from the editor record so that everything
--- the running world does not expose — skill, payload, callsign — survives, then overwrites what the
--- world knows better: the group id DCS assigned, its current category, and each live unit's position,
--- heading, altitude and speed.
---
--- **Coordinates.** The result is the mission-table shape a spawn expects: `x` northing, `y` easting.
--- The live position is a vec3, so its `z` becomes the record's `y`. Getting this backwards places the
--- group somewhere else entirely, with no error.
---
--- @param groupName string
--- @return table|nil the group data, or nil when neither a group nor a static answers to that name
function veafDcsSpawner.getCurrentGroupData(groupName)
  local record = veafMissionDb.getGroupRecord(groupName)
  local group = Group.getByName(groupName)

  if group and group:isExist() then
    local data = veaf.deepCopy(record or {})
    data.name = groupName
    data.groupName = groupName
    data.groupId = tonumber(group:getID())
    -- `getCategory` answers a **Group.Category**, and a spawn wants the editor's word for it. All four
    -- are converted, not just the two MiST bothered with: `Group.Category` and `Unit.Category` do not
    -- number the same things the same way, so a category left as a number is read against the wrong
    -- table further down and an airplane comes back a helicopter. That is the shape of #299.
    data.category = veafDcsSpawner.EDITOR_CATEGORY_BY_GROUP_CATEGORY[group:getCategory()] or group:getCategory()

    data.units = {}
    local liveUnits = group:getUnits() or {}

    -- The country, from the live unit when the editor knows nothing about this group.
    --
    -- A group spawned during the mission has no editor record, so `record` is nil and everything the
    -- snapshot would have supplied is missing -- the country included, and `addGroup` refuses a group
    -- without one. MiST did not meet this: its database was refreshed every two seconds and held the
    -- dynamic groups too, so `getCurrentGroupData` found their country there.
    --
    -- Found in game (DCS-SESSION-TODO item 23): teleporting a CSAR downed pilot, a group CSAR itself
    -- had just created, failed with "country not found".
    if data.countryId == nil and data.country == nil and liveUnits[1] then
      local ok, countryId = pcall(function()
        return liveUnits[1]:getCountry()
      end)
      if ok and countryId then
        data.countryId = countryId
      end
    end

    if #liveUnits == 0 then
      veaf.loggers.get(veafDcsSpawner.Id):warn("getCurrentGroupData: group [%s] exists but has no units", veaf.p(groupName))
    end
    for index, unit in ipairs(liveUnits) do
      local unitName = unit:getName()
      -- The editor record is reused only when it still describes **this** unit: same type, same id.
      -- MiST checked both, and it matters — a unit dynamically respawned under a name the snapshot
      -- already knows would otherwise inherit the loadout, skill and callsign of whatever used to
      -- carry that name.
      local known = veafMissionDb.getUnitRecord(unitName)
      local liveId = tonumber(unit:getID())
      local liveType = unit:getTypeName()
      local matches = known and known.type == liveType and known.unitId == liveId
      local unitData = matches and veaf.deepCopy(known) or {}
      unitData.unitId = liveId
      unitData.type = liveType
      unitData.unitName = unitName
      unitData.name = unitName

      local position = unit:getPosition()
      if position and position.p then
        unitData.x = position.p.x
        unitData.y = position.p.z
        unitData.alt = position.p.y
        unitData.point = { x = unitData.x, y = unitData.y }
        if position.x then
          unitData.heading = math.atan2(position.x.z, position.x.x)
        end
      end
      local velocity = unit:getVelocity()
      if velocity then
        unitData.speed = veaf.vecMag(velocity)
      end
      data.units[index] = unitData
    end
    return data
  end

  -- A static answers to a name too, and carries a single unit.
  local static = StaticObject.getByName(groupName)
  if static and static:isExist() and record and record.units and record.units[1] then
    local data = veaf.deepCopy(record)
    local position = static:getPosition()
    if position and position.p then
      data.units[1].x = position.p.x
      data.units[1].y = position.p.z
      data.units[1].alt = position.p.y
      if position.x then
        data.units[1].heading = math.atan2(position.x.z, position.x.x)
      end
    end
    return data
  end

  veaf.loggers.get(veafDcsSpawner.Id):debug("getCurrentGroupData: nothing alive named [%s]", veaf.p(groupName))
  return nil
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafGroupSpawn — putting a group somewhere, with the verb in the method name
--
-- This replaces `mist.teleportToPoint`, whose interface was a table called `vars` carrying a string
-- called `action`. That string was not a parameter: it chose between **three different verbs**, and an
-- unnamed second argument chose a fourth. A misspelling silently fell through to "teleport", and a
-- misspelled key did nothing at all.
--
--   VeafGroupSpawn:new():forGroup("Arco"):at(point):withRadius(500):clone()
--
-- The terminal method is the verb, so it cannot be misspelled without failing, and an unfinished chain
-- creates nothing rather than guessing. Chaining rather than an options table because the repository
-- already speaks it — 150 chainable `:setXxx` methods — and because `:withRadus(500)` fails loudly
-- where `{ radus = 500 }` is a silent zero.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafGroupSpawn = {}

--- How many times a valid-terrain draw is attempted before giving up. MiST's number.
VeafGroupSpawn.TERRAIN_ATTEMPTS = 100

--- Altitude bands an aircraft is dropped into when the requested point is too close to the ground,
--- in metres above terrain. MiST's numbers, and the randomness is deliberate: a wave of respawned
--- aircraft all at one altitude looks wrong from the cockpit.
VeafGroupSpawn.ALTITUDE_BANDS = {
  plane = { 300, 9000 },
  helicopter = { 200, 3000 },
}

--- How far above the ground a requested altitude has to be before it is taken at face value.
VeafGroupSpawn.MINIMUM_CLEARANCE_METRES = 10

function VeafGroupSpawn:new()
  local instance = {}
  setmetatable(instance, self)
  self.__index = self
  instance.groupName = nil
  instance.groupData = nil
  instance.point = nil
  instance.radius = 0
  instance.route = nil
  instance.newGroupName = nil
  instance.dispersion = nil
  instance.renameUnits = false
  instance.terrain = nil
  instance.anyTerrain = false
  instance.offsetFirstWaypoint = false
  return instance
end

--- The group to spawn from, by name.
function VeafGroupSpawn:forGroup(groupName)
  self.groupName = groupName
  return self
end

--- A group definition supplied by the caller, instead of one read from the mission.
--- `veafMove` uses this for its AFAC, which it builds rather than looks up.
function VeafGroupSpawn:withGroupData(groupData)
  self.groupData = groupData
  return self
end

--- Where to put it. A vec3 whose `y` is the altitude.
function VeafGroupSpawn:at(point)
  self.point = point
  return self
end

--- Scatter the group's origin anywhere within this radius of the point.
function VeafGroupSpawn:withRadius(radius)
  self.radius = radius or 0
  return self
end

--- The route the spawned group flies or drives. Without one, the group's own is used.
function VeafGroupSpawn:withRoute(route)
  self.route = route
  return self
end

--- Name the new group. Only a clone or a respawn can be renamed.
function VeafGroupSpawn:named(newGroupName)
  self.newGroupName = newGroupName
  return self
end

--- Spread the units of the group over this radius, instead of keeping their formation.
function VeafGroupSpawn:disperseOver(radius)
  self.dispersion = radius
  return self
end

--- Rename each unit after its group and its id, rather than keeping the editor names.
function VeafGroupSpawn:renamingUnitsSequentially(enabled)
  self.renameUnits = enabled ~= false
  return self
end

--- Accept any surface, skipping the terrain check entirely.
function VeafGroupSpawn:onAnyTerrain()
  self.anyTerrain = true
  return self
end

--- Accept only these surfaces, instead of the ones the group's category implies.
function VeafGroupSpawn:onTerrain(surfaces)
  self.terrain = surfaces
  return self
end

--- Move the route's first waypoint by the same offset as the group.
function VeafGroupSpawn:offsettingFirstWaypoint(enabled)
  self.offsetFirstWaypoint = enabled ~= false
  return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- The verbs
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Create a **new** group from an editor group's definition, with new ids and names.
function VeafGroupSpawn:clone()
  return self:_spawn("clone", false)
end

--- Put **the same** group back where the Mission Editor drew it.
function VeafGroupSpawn:respawn()
  return self:_spawn("respawn", false)
end

--- Move the group **as it is right now**, keeping its live state.
function VeafGroupSpawn:teleport()
  return self:_spawn("teleport", false)
end

--- Build what a clone would submit, and create nothing. Replaces MiST's unnamed `prepareOnly` boolean;
--- all three VEAF sites that passed it were cloning.
function VeafGroupSpawn:buildCloneData()
  return self:_spawn("clone", true)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- The engine
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The group definition a verb starts from.
function VeafGroupSpawn:_sourceData(verb)
  if self.groupData then
    return veaf.deepCopy(self.groupData)
  end
  if not self.groupName then
    return nil
  end
  if verb == "teleport" then
    return veaf.getCurrentGroupData(self.groupName)
  end
  -- clone and respawn both read the editor definition; only clone asks for a new identity.
  local record = veafMissionDb.getGroupRecord(self.groupName)
  return record and veaf.deepCopy(record) or nil
end

--- A point in the circle whose terrain suits this group, and the offset to reach it.
function VeafGroupSpawn:_drawOrigin(data)
  local first = data.units[1]
  if not self.point or self.radius < 0 then
    return { x = 0, y = 0 }, nil
  end

  local surfaces = self.terrain or veafDcsSpawner.terrainForCategory(data.category)
  for _ = 1, VeafGroupSpawn.TERRAIN_ATTEMPTS do
    local candidate = veaf.getRandomPointInCircle(self.point, self.radius)
    if self.anyTerrain or veafDcsSpawner.isTerrainValid(candidate, surfaces) then
      return { x = candidate.x - first.x, y = candidate.y - first.y }, candidate
    end
  end

  veaf.loggers
    .get(veafDcsSpawner.Id)
    :error("no point within %sm of the requested spot is valid terrain for [%s]", veaf.p(self.radius), veaf.p(self.groupName))
  return nil, nil
end

--- The altitude an aircraft unit gets at this spot.
function VeafGroupSpawn:_altitudeFor(category, unit)
  local band = VeafGroupSpawn.ALTITUDE_BANDS[category]
  if not band then
    return unit.alt
  end
  local ground = land.getHeight({ x = unit.x, y = unit.y })
  -- A requested altitude is taken at face value only when it clears the terrain; otherwise the
  -- aircraft would be spawned inside a hill.
  if self.point and self.point.z and self.point.y and self.point.y > ground + VeafGroupSpawn.MINIMUM_CLEARANCE_METRES then
    return self.point.y
  end
  return ground + math.random(band[1], band[2])
end

--- Run the verb.
--- @param verb string clone, respawn or teleport
--- @param buildOnly boolean true to return the data without creating anything
--- @return table|false|nil what was created, the data when building only, or false
function VeafGroupSpawn:_spawn(verb, buildOnly)
  local data = self:_sourceData(verb)
  if not data then
    veaf.loggers.get(veafDcsSpawner.Id):info("cannot %s [%s]: no group data", verb, veaf.p(self.groupName))
    return false
  end
  if type(data.units) ~= "table" or not data.units[1] then
    veaf.loggers.get(veafDcsSpawner.Id):warn("cannot %s [%s]: it has no units", verb, veaf.p(self.groupName))
    return false
  end

  -- Every unit needs a position to be moved from. MiST assumed one and raised an arithmetic error on
  -- nil, which in DCS means the whole script stops; saying so and creating nothing is the same outcome
  -- for the group and a far better one for the mission.
  for index, unit in pairs(data.units) do
    if type(unit.x) ~= "number" or type(unit.y) ~= "number" then
      veaf.loggers
        .get(veafDcsSpawner.Id)
        :error("cannot %s [%s]: unit %s has no position", verb, veaf.p(self.groupName), veaf.p(unit.name or index))
      return false
    end
  end

  -- A record from the mission database names its group `groupName`; a spawn wants `name`.
  data.name = self.newGroupName or data.name or data.groupName
  data.groupName = data.name
  local renamed = false
  if verb == "clone" then
    -- New identity: drop the ids so the spawner allocates fresh ones.
    data.groupId = nil
    for _, unit in pairs(data.units) do
      unit.unitId = nil
    end

    -- ...and a new name, when the old one is still in use. `mist.dynAdd` did this and the first
    -- port did not, so every clone of a live group was a homonym of it: `Group.getByName` can only
    -- answer one of them, and both callers here track their groups *by* that name.
    --
    -- A respawn and a teleport reuse an identity rather than creating one, so they keep their name.
    -- That is the same line MiST drew with its `clone` flag.
    if veaf.isNameTaken(data.name) then
      local taken = data.name
      data.name = veafDcsSpawner.freeNameFrom(taken)
      data.groupName = data.name
      renamed = true
      veaf.loggers.get(veafDcsSpawner.Id):debug("clone of [%s] named [%s]", veaf.p(taken), veaf.p(data.name))
    end
  end

  if self.renameUnits then
    for index, unit in pairs(data.units) do
      unit.unitName = string.format("%s #%d", data.name, unit.unitId or index)
      unit.name = unit.unitName
    end
  elseif renamed then
    -- A renamed group renames its units too: DCS is no happier about two `Convoy-1` than about two
    -- `Convoy`. The Mission Editor's own `<group>-<n>` shape is used rather than the `#` form above,
    -- which would read `Arco #2 #1` and tell nobody anything.
    for index, unit in pairs(data.units) do
      unit.unitName = string.format("%s-%d", data.name, index)
      unit.name = unit.unitName
    end
  end

  local offset, origin = self:_drawOrigin(data)
  if not offset then
    return false
  end

  for index, unit in pairs(data.units) do
    if self.dispersion and index > 1 then
      local spread = veaf.getRandomPointInCircle(origin or { x = unit.x, y = 0, z = unit.y }, self.dispersion)
      unit.x, unit.y = spread.x, spread.y
    elseif self.dispersion and origin then
      unit.x, unit.y = origin.x, origin.y
    else
      unit.x, unit.y = unit.x + offset.x, unit.y + offset.y
    end
    if self.point then
      unit.alt = self:_altitudeFor(data.category, unit) or unit.alt
    end
  end

  -- A start time already past means "now"; one still ahead keeps whatever is left of it.
  if data.start_time and data.start_time ~= 0 and verb ~= "teleport" then
    local elapsed = timer.getAbsTime() - timer.getTime0()
    data.start_time = elapsed > data.start_time and 0 or data.start_time - elapsed
  end

  local route = self.route or (self.groupName and veaf.getGroupRoute(self.groupName)) or nil
  if route then
    route = veaf.deepCopy(route)
    if self.offsetFirstWaypoint and route[1] and route[1].x then
      route[1].x, route[1].y = route[1].x + offset.x, route[1].y + offset.y
    end
    data.route = { points = route }
  end

  if buildOnly then
    return data
  end
  if type(data.category) == "string" and string.lower(data.category) == "static" then
    return veaf.addStatic(data)
  end
  return veaf.addGroup(data)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Framework façades. Callers use `veaf.*` and never name the implementation.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.addStatic = veafDcsSpawner.addStatic
veaf.addGroup = veafDcsSpawner.addGroup
veaf.isTerrainValid = veafDcsSpawner.isTerrainValid
veaf.getCurrentGroupData = veafDcsSpawner.getCurrentGroupData
veaf.getGroupRoute = veafDcsSpawner.getGroupRoute
veaf.goRoute = veafDcsSpawner.goRoute

function veafDcsSpawner.initialize()
  veaf.loggers.get(veafDcsSpawner.Id):info("Initializing module")
end

veaf.loggers.get(veafDcsSpawner.Id):info(veaf.loggers.get(veafDcsSpawner.Id):getVersionInfo())
