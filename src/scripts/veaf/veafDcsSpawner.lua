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

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Framework façades. Callers use `veaf.*` and never name the implementation.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.addStatic = veafDcsSpawner.addStatic

function veafDcsSpawner.initialize()
  veaf.loggers.get(veafDcsSpawner.Id):info("Initializing module")
end

veaf.loggers.get(veafDcsSpawner.Id):info(veaf.loggers.get(veafDcsSpawner.Id):getVersionInfo())
