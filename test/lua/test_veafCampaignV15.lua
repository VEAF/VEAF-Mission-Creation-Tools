--- Tests for the V1.5 of the persistent campaign (FEAT-DYNAMIC-CAMPAIGN tickets 11 to 18): factories and
--- depots, resources and production, the supply network, paid spawns, sappers, warehouse stocks, strategic
--- bombers and territory cells.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafI18n.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
dofile(src .. "/veafDcsSpawner.lua")
dofile(src .. "/dcsUnits.lua")
dofile(src .. "/veafUnits.lua")
dofile(src .. "/veafCasMission.lua")
dofile(src .. "/veafEventHandler.lua")
dofile(src .. "/veafRadio.lua")
dofile(src .. "/veafNamedPoints.lua")
veafAircraftSpawn = { roles = {} }
dofile(src .. "/veafCampaign.lua")
dofile(src .. "/veafCampaignOps.lua")
dofile(src .. "/veafCampaignEconomy.lua")
dofile(src .. "/veafCampaignLogistics.lua")

local BLUE, RED = coalition.side.BLUE, coalition.side.RED

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function garrison(name, dead)
  local units = {}
  for index, typeName in ipairs({ "T-72B", "BMP-2", "Ural-375" }) do
    table.insert(units, { type = typeName, x = 10 * index, z = 20, heading = 0, alive = true })
  end
  for _, index in ipairs(dead or {}) do
    units[index].alive = false
  end
  return { { name = name .. " garrison", units = units } }
end

local function zone(name, owner, x, extra)
  local entry = {
    name = name,
    x = x,
    z = 0,
    radius = 2000,
    owner = owner,
    size = { size = 1, defense = 1, armor = 1, long_range_sam = false },
    garrison = owner ~= "neutral" and garrison(name) or nil,
  }
  for key, value in pairs(extra or {}) do
    entry[key] = value
  end
  return entry
end

local AIRCRAFT = { type = "MiG-29A", count = 2, payload = { pylons = {} } }
local BOMBER = { type = "Tu-22M3", count = 1, payload = { pylons = {} } }

--- Kobuleti (blue airfield) — Poti (blue) — Senaki (red airfield) — Zugdidi (red) — Tkvarcheli (red factory),
--- 50 km apart along x; Gali (red depot) between Zugdidi and Tkvarcheli is added by the network tests.
local function data(dynamic)
  dynamic = dynamic or {}
  dynamic.air = dynamic.air
    or {
      red = { cap = AIRCRAFT, cas = AIRCRAFT, sead = AIRCRAFT, bomber = BOMBER },
      blue = { cap = AIRCRAFT, bomber = BOMBER },
    }
  return {
    format_version = 1,
    campaign = "V15",
    mission = 1,
    persistent = true,
    player_side = "blue",
    dynamic = dynamic,
    zones = {
      zone("Kobuleti", "blue", 0, { airbase = "Kobuleti" }),
      zone("Poti", "blue", 50000),
      zone("Senaki", "red", 100000, { airbase = "Senaki-Kolkhi" }),
      zone("Zugdidi", "red", 150000),
      zone("Tkvarcheli", "red", 200000, { kind = "factory" }),
    },
    connections = {
      { "Kobuleti", "Poti" },
      { "Poti", "Senaki" },
      { "Senaki", "Zugdidi" },
      { "Zugdidi", "Tkvarcheli" },
    },
    sides = {},
  }
end

--- A file system in memory, as test_veafCampaignPersistent has it.
local function memoryFileSystem(self)
  self.files = {}
  local files = self.files
  local fsIo = {
    open = function(path, mode)
      if mode == "r" then
        local content = files[path]
        if content == nil then
          return nil
        end
        return {
          read = function()
            return content
          end,
          close = function()
            return true
          end,
        }
      end
      local chunks, file = {}, {}
      file.write = function(_, text)
        table.insert(chunks, text)
        return file
      end
      file.close = function()
        files[path] = table.concat(chunks)
        return true
      end
      return file
    end,
  }
  local fsLfs = {
    writedir = function()
      return "C:\\Saved Games\\DCS\\"
    end,
    mkdir = function()
      return true
    end,
  }
  veafCampaign.fileSystem = function()
    return fsIo, fsLfs, nil
  end
end

local function unitAt(point, options)
  options = options or {}
  return {
    isExist = function()
      return true
    end,
    getLife = function()
      return 1
    end,
    getPoint = function()
      return { x = point.x, y = point.y or 0, z = point.z or 0 }
    end,
    inAir = function()
      return options.inAir == true
    end,
    getTypeName = function()
      return options.type or "T-72B"
    end,
    getDesc = function()
      return { category = options.category or Unit.Category.GROUND_UNIT, attributes = options.attributes or {} }
    end,
    getGroup = function()
      return {
        getID = function()
          return 77
        end,
      }
    end,
  }
end

local function setUpSuite(self)
  dcs_mocks.reset()
  self.saved = {
    fileSystem = veafCampaign.fileSystem,
    getPlayers = coalition.getPlayers,
    callbacks = veafEventHandler.callbacks,
    spawnAirplaneGroup = veafAircraftSpawn.spawnAirplaneGroup,
    spawnHelicopterGroup = veafAircraftSpawn.spawnHelicopterGroup,
    language = veaf.config.language,
    airbase = Airbase.getByName,
    staticByName = StaticObject.getByName,
    troopManager = CTLDTroopManager,
    surface = land.getSurfaceType,
    spawn = veafSpawn,
  }
  veaf.config.language = "en"
  veafEventHandler.callbacks = {}
  land.getSurfaceType = function()
    return land.SurfaceType.LAND
  end
  veafCampaign.fileSystem = function()
    return nil, nil, nil
  end
  coalition.getPlayers = function()
    return {}
  end
  Airbase.getByName = function(name)
    return {
      getID = function()
        return name == "Kobuleti" and 24 or 23
      end,
      getPoint = function()
        return { x = 0, y = 0, z = 0 }
      end,
    }
  end
  self.flights = {}
  local this = self
  veafAircraftSpawn.spawnAirplaneGroup = function(groupData, role, params)
    table.insert(this.flights, { group = groupData, role = role, params = params })
    dcs_mocks.addGroup(groupData.name, {
      getUnits = function()
        return { unitAt({ x = 0 }, { inAir = true }) }
      end,
    })
    return groupData.name
  end
  veafAircraftSpawn.spawnHelicopterGroup = function(groupData)
    return groupData.name
  end
  veafSpawn = {}
  veafCampaign.listeners = {}
  veafCampaign.saveParts = {}
end

local function tearDownSuite(self)
  veafCampaign.fileSystem = self.saved.fileSystem
  coalition.getPlayers = self.saved.getPlayers
  veafEventHandler.callbacks = self.saved.callbacks
  veafAircraftSpawn.spawnAirplaneGroup = self.saved.spawnAirplaneGroup
  veafAircraftSpawn.spawnHelicopterGroup = self.saved.spawnHelicopterGroup
  veaf.config.language = self.saved.language
  Airbase.getByName = self.saved.airbase
  StaticObject.getByName = self.saved.staticByName
  CTLDTroopManager = self.saved.troopManager
  land.getSurfaceType = self.saved.surface
  veafSpawn = self.saved.spawn
  veafCampaign.data = nil
  veafCampaign.listeners = {}
  veafCampaign.saveParts = {}
end

local function start(dynamic, mutate)
  veafCampaign.data = data(dynamic)
  if mutate then
    mutate(veafCampaign.data)
  end
  veafCampaign.initialize()
end

local function staticsNamed(name)
  local found = {}
  for _, call in ipairs(dcs_mocks.staticsAdded) do
    if call.object.name == name then
      table.insert(found, call)
    end
  end
  return found
end

local function messagesContaining(text)
  local found = {}
  for _, message in ipairs(dcs_mocks.messages or {}) do
    for _, value in pairs(message) do
      if type(value) == "string" and string.find(value, text, 1, true) then
        table.insert(found, value)
      end
    end
  end
  return found
end

-- ---------------------------------------------------------------------------
-- Factories (ticket 11)
-- ---------------------------------------------------------------------------
TestCampaignFactory = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignFactory:test_its_buildings_are_drawn_once_recorded_and_spawned_with_their_shape()
  start()
  local factory = veafCampaign.zones["Tkvarcheli"]
  luaunit.assertEquals(#factory.entry.structures, 3)
  local first = staticsNamed("Tkvarcheli building #1")[1]
  luaunit.assertNotNil(first)
  luaunit.assertEquals(first.object.type, "Workshop A")
  luaunit.assertEquals(first.object.shape_name, "tec_a")
  luaunit.assertEquals(first.countryId, country.id.RUSSIA)
  luaunit.assertEquals(factory.entry.structures[2].x - factory.entry.structures[1].x, veafCampaign.STRUCTURE_SPACING)
  luaunit.assertEquals(factory.entry.structures_side, "red")
  -- a zone of another kind has none
  luaunit.assertNil(veafCampaign.zones["Zugdidi"].entry.structures)
end

function TestCampaignFactory:test_a_building_destroyed_is_recorded_and_counted_on_the_map()
  start()
  local factory = veafCampaign.zones["Tkvarcheli"]
  veafCampaign.onUnitDead({ initiator = { unitName = "Tkvarcheli building #2" } })
  luaunit.assertFalse(factory.entry.structures[2].alive)
  luaunit.assertEquals({ factory:structuresStanding() }, { 2, 3 })
  luaunit.assertStrContains(factory:labelFor("red"), "factory 2/3")
  luaunit.assertTrue(factory:isDamaged())
  luaunit.assertFalse(factory:garrisonDamaged())
  -- the second event DCS sends for the same object changes nothing
  veafCampaign.onUnitDead({ initiator = { unitName = "Tkvarcheli building #2" } })
  luaunit.assertEquals(veafCampaign.counters.structuresLost, 1)
end

function TestCampaignFactory:test_a_captured_factory_works_for_its_new_owner()
  start({ resources = { enabled = false } })
  local factory = veafCampaign.zones["Tkvarcheli"]
  factory.entry.structures[3].alive = false
  factory:becomeNeutral()
  dcs_mocks.staticsAdded = {}
  factory:capturedBy("blue")
  luaunit.assertEquals(factory.entry.structures_side, "blue")
  local standing = staticsNamed("Tkvarcheli building #1")[1]
  luaunit.assertEquals(standing.countryId, country.id.USA)
  luaunit.assertFalse(standing.object.dead)
  luaunit.assertTrue(staticsNamed("Tkvarcheli building #3")[1].object.dead) -- the wreck stays a wreck
end

function TestCampaignFactory:test_a_delivery_rebuilds_a_building_once_the_garrison_is_whole()
  start()
  local factory = veafCampaign.zones["Tkvarcheli"]
  factory.entry.structures[1].alive = false
  factory.entry.garrison = garrison("Tkvarcheli", { 1 })
  luaunit.assertTrue(veafCampaign.deliver(factory, "red", "helicopter"))
  luaunit.assertFalse(factory.entry.structures[1].alive) -- the garrison first
  luaunit.assertTrue(veafCampaign.deliver(factory, "red", "helicopter"))
  luaunit.assertTrue(factory.entry.structures[1].alive)
  luaunit.assertFalse(veafCampaign.deliver(factory, "red", "helicopter")) -- nothing left to bring
end

function TestCampaignFactory:test_its_buildings_survive_the_save()
  memoryFileSystem(self)
  start()
  veafCampaign.zones["Tkvarcheli"].entry.structures[2].alive = false
  local x = veafCampaign.zones["Tkvarcheli"].entry.structures[1].x
  luaunit.assertTrue(veafCampaign.writeState())
  start()
  local factory = veafCampaign.zones["Tkvarcheli"]
  luaunit.assertEquals(factory.entry.structures[1].x, x)
  luaunit.assertFalse(factory.entry.structures[2].alive)
end

-- ---------------------------------------------------------------------------
-- Resources and production (ticket 12)
-- ---------------------------------------------------------------------------
TestCampaignResources = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignResources:test_a_unit_is_priced_by_what_it_is()
  start()
  luaunit.assertEquals(veafCampaign.unitPrice("Soldier AK"), 1)
  luaunit.assertEquals(veafCampaign.unitPrice("Ural-375"), 2)
  luaunit.assertEquals(veafCampaign.unitPrice("BMP-2"), 4)
  luaunit.assertEquals(veafCampaign.unitPrice("T-72B"), 6)
  luaunit.assertEquals(veafCampaign.unitPrice("ZSU-23-4 Shilka"), 8)
  luaunit.assertEquals(veafCampaign.unitPrice("Strela-10M3"), 25)
  luaunit.assertEquals(veafCampaign.unitPrice("SA-11 Buk LN 9A310M1"), 40)
  -- FIX-CAMPAIGN-THIRD-SERVER-FLIGHT 10: a lost Tor was worth about a BMP, and one SEAD sortie 25 of them
  luaunit.assertEquals(veafCampaign.unitPrice("Tor 9A331"), 25)
  luaunit.assertEquals(veafCampaign.unitPrice("Mi-8MT"), 15)
  luaunit.assertEquals(veafCampaign.unitPrice("MiG-29A"), 30)
  luaunit.assertEquals(veafCampaign.unitPrice("Tu-22M3"), 100)
  luaunit.assertEquals(veafCampaign.unitPrice("not a unit"), 5)
end

function TestCampaignResources:test_a_price_set_by_type_wins()
  start({ resources = { prices = { ["T-72B"] = 9 } } })
  luaunit.assertEquals(veafCampaign.unitPrice("T-72B"), 9)
  luaunit.assertEquals(veafCampaign.unitsPrice({ "T-72B", { type = "Ural-375" } }), 11)
end

function TestCampaignResources:test_the_production_is_the_background_plus_the_factories_by_their_buildings_standing()
  start()
  luaunit.assertEquals(veafCampaignLogistics.productionPerHour("blue"), 60)
  luaunit.assertEquals(veafCampaignLogistics.productionPerHour("red"), 240)
  veafCampaign.zones["Tkvarcheli"].entry.structures[1].alive = false
  luaunit.assertEquals(veafCampaignLogistics.productionPerHour("red"), 180)
  local before = veafCampaignLogistics.stock("red")
  veafCampaignLogistics.produce(1800)
  luaunit.assertAlmostEquals(veafCampaignLogistics.stock("red") - before, 90, 0.001)
end

function TestCampaignResources:test_a_sortie_keeps_the_reserve_an_essential_spending_goes_to_zero()
  start()
  veafCampaignLogistics.stocks.red = 160
  luaunit.assertTrue(veafCampaignLogistics.canPay("red", 60))
  luaunit.assertFalse(veafCampaignLogistics.canPay("red", 61))
  luaunit.assertTrue(veafCampaignLogistics.canPay("red", 160, "essential"))
  luaunit.assertFalse(veafCampaignLogistics.pay("red", 161, "essential"))
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), 160) -- refused, nothing taken
  luaunit.assertTrue(veafCampaignLogistics.pay("red", 500, "partial"))
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), 0)
end

function TestCampaignResources:test_the_enemy_cap_is_paid_and_grounded_when_it_cannot_be()
  start()
  veafCampaignLogistics.stocks.red = 159
  veafCampaignOps.maintainCaps("red")
  luaunit.assertEquals(#self.flights, 0)
  luaunit.assertEquals(veafCampaignOps.counters.unpaid, 1)
  veafCampaignLogistics.stocks.red = 200
  veafCampaignOps.maintainCaps("red")
  luaunit.assertEquals(#self.flights, 1)
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), 140) -- two MiG-29 at 30
end

--- Airbases as DCS gives them, with runways of `length` metres and no free stand: a flight starts on the runway.
local function airfieldsWithRunway(length)
  Airbase.getByName = function(name)
    return {
      getID = function()
        return name == "Kobuleti" and 24 or 23
      end,
      getPoint = function()
        return { x = 0, y = 0, z = 0 }
      end,
      getRunways = function()
        return { { length = length } }
      end,
      getParking = function()
        return {}
      end,
    }
  end
end

-- FIX-CAMPAIGN-SECOND-SERVER-FLIGHT 01: no red aeroplane sent from Taftanaz took off all evening
function TestCampaignResources:test_no_aeroplane_leaves_a_field_whose_runway_is_too_short()
  start({ min_runway_length = 1500 })
  local senaki = veafCampaign.zones["Senaki"]
  airfieldsWithRunway(2400)
  local allowed = veafCampaignOps.canTakeOffFrom("red", senaki)
  luaunit.assertTrue(allowed)
  airfieldsWithRunway(1000)
  luaunit.assertFalse(veafCampaignOps.canTakeOffFrom("red", senaki))
end

function TestCampaignResources:test_a_flight_that_never_takes_off_is_taken_away_refunded_and_its_field_grounded()
  start({ takeoff_timeout = 600, grounded_seconds = 3600 })
  airfieldsWithRunway(2400)
  local this = self
  veafAircraftSpawn.spawnAirplaneGroup = function(groupData, role, params)
    table.insert(this.flights, { group = groupData, role = role, params = params })
    dcs_mocks.addGroup(groupData.name, {
      getUnits = function()
        return { unitAt({ x = 0 }, { inAir = false }) }
      end,
    })
    return groupData.name
  end
  veafCampaignLogistics.stocks.red = 200
  veafCampaignOps.maintainCaps("red")
  luaunit.assertEquals(#self.flights, 1)
  local flight = veafCampaignOps.flights[1]
  luaunit.assertTrue(flight.runway)
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), 140)
  -- a second flight from the same field would spawn onto the first, still on the runway
  luaunit.assertNil(
    veafCampaignOps.spawnFlight("red", "cap", veafCampaign.zones[flight.origin], "campaign_cap", { zone = { x = 0, y = 0 } }, 6000)
  )
  veafCampaignOps.followFlights(flight.spawnedAt + 599)
  luaunit.assertNil(flight.done)
  veafCampaignOps.followFlights(flight.spawnedAt + 600)
  luaunit.assertEquals(flight.outcome, "grounded")
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), 200, "its price back")
  luaunit.assertEquals(veafCampaignOps.counters.grounded, 1)
  luaunit.assertFalse(veafCampaignOps.canTakeOffFrom("red", veafCampaign.zones[flight.origin]))
end

-- review of #1310: the flights of one raid leave one field together; a flight the players bought is theirs
function TestCampaignResources:test_a_raid_s_flights_leave_together_and_a_players_flight_is_never_taken_away()
  start({ takeoff_timeout = 600 })
  airfieldsWithRunway(2400)
  local this = self
  veafAircraftSpawn.spawnAirplaneGroup = function(groupData, role, params)
    table.insert(this.flights, { group = groupData, role = role, params = params })
    dcs_mocks.addGroup(groupData.name, {
      getUnits = function()
        return { unitAt({ x = 0 }, { inAir = false }) }
      end,
    })
    return groupData.name
  end
  local senaki = veafCampaign.zones["Senaki"]
  local first = veafCampaignOps.spawnFlight("red", "cap", senaki, "zone_defense", { zone = { x = 0, y = 0 }, package = "raid 1" }, 6000)
  local second = veafCampaignOps.spawnFlight("red", "cap", senaki, "zone_defense", { zone = { x = 0, y = 0 }, package = "raid 1" }, 6000)
  luaunit.assertNotNil(first)
  luaunit.assertNotNil(second, "one package")
  local kobuleti = veafCampaign.zones["Kobuleti"]
  veafCampaignOps.spawnFlight("blue", "cap", kobuleti, "zone_defense", { zone = { x = 0, y = 0 } }, 6000)
  local bought = veafCampaignOps.flights[#veafCampaignOps.flights]
  veafCampaignOps.followFlights(bought.spawnedAt + 5000)
  luaunit.assertNil(bought.outcome)
end

function TestCampaignResources:test_a_flight_in_the_air_is_never_taken_away()
  start({ takeoff_timeout = 600 })
  airfieldsWithRunway(2400)
  veafCampaignLogistics.stocks.red = 200
  veafCampaignOps.maintainCaps("red")
  local flight = veafCampaignOps.flights[1]
  veafCampaignOps.followFlights(flight.spawnedAt + 10)
  luaunit.assertTrue(flight.airborne)
  veafCampaignOps.followFlights(flight.spawnedAt + 5000)
  luaunit.assertNil(flight.outcome)
end

function TestCampaignResources:test_a_bought_cap_costs_credits_not_resources()
  start()
  local before = veafCampaignLogistics.stock("blue")
  luaunit.assertTrue(veafCampaignEconomy.buy({ "cap", "Kobuleti" }))
  luaunit.assertEquals(veafCampaignLogistics.stock("blue"), before)
end

function TestCampaignResources:test_a_captured_zone_the_side_cannot_pay_gets_a_token_garrison()
  start()
  local poti = veafCampaign.zones["Poti"]
  poti:becomeNeutral()
  veafCampaignLogistics.stocks.red = 3
  poti:capturedBy("red")
  luaunit.assertNotNil(poti.entry.garrison)
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), 0)
end

function TestCampaignResources:test_a_zone_taken_by_a_helicopter_gets_a_token_garrison()
  -- 2026-11-16: the garrisons of Menagh and Afrin, taken by helicopter, cost red 128 of its 225 points
  start()
  local poti = veafCampaign.zones["Poti"]
  poti:becomeNeutral()
  local drawnFrom = "not drawn"
  local draw = poti.drawGarrison
  poti.drawGarrison = function(zone, reserve)
    drawnFrom = reserve
    return draw(zone, reserve)
  end
  poti:capturedBy("red", "helicopter")
  poti.drawGarrison = nil
  luaunit.assertEquals(type(drawnFrom), "table")
  for category, count in pairs(drawnFrom) do
    luaunit.assertEquals(count, 0, "an empty reserve draws the token garrison: " .. category)
  end
end

-- FIX-CAMPAIGN-SECOND-SERVER-FLIGHT 08: Menagh (an airfield outpost) got 14 units, Afrin 24, on 2026-11-17
function TestCampaignResources:test_a_helicopter_capture_leaves_a_few_soldiers_whatever_the_size_class()
  start()
  for _, name in ipairs({ "Poti", "Senaki" }) do
    local zone = veafCampaign.zones[name]
    zone.entry.size = { size = 3, defense = 5, armor = 3, long_range_sam = true }
    zone:becomeNeutral()
    zone:capturedBy("red", "helicopter")
    luaunit.assertEquals(#zone.entry.garrison, 1, name)
    local units = zone.entry.garrison[1].units
    luaunit.assertTrue(#units > 0 and #units <= 6, name .. ": " .. #units .. " units")
    for _, unit in ipairs(units) do
      local known = false
      for _, infantry in ipairs(veafCasMission.INFANTRY_TYPES[coalition.side.RED][veaf.config.era]) do
        known = known or unit.type == infantry
      end
      luaunit.assertTrue(known, name .. ": no vehicle, " .. tostring(unit.type))
    end
  end
end

-- review of #1310: a side that could not pay its soldiers fell back on the smallest size class, vehicles included
function TestCampaignResources:test_a_helicopter_capture_the_side_cannot_pay_still_leaves_soldiers_only()
  start()
  veafCampaignLogistics.stocks.red = 0
  local poti = veafCampaign.zones["Poti"]
  poti:becomeNeutral()
  poti:capturedBy("red", "helicopter")
  for _, unit in ipairs(poti.entry.garrison[1].units) do
    local known = false
    for _, infantry in ipairs(veafCasMission.INFANTRY_TYPES[coalition.side.RED][veaf.config.era]) do
      known = known or unit.type == infantry
    end
    luaunit.assertTrue(known, "no vehicle: " .. tostring(unit.type))
  end
end

function TestCampaignResources:test_landed_helicopters_alone_take_a_zone_slower()
  start()
  luaunit.assertEquals(veafCampaign.captureSeconds(true), 600)
  luaunit.assertEquals(veafCampaign.captureSeconds(false), veafCampaign.data.capture_seconds or veafCampaign.CAPTURE_SECONDS)
end

function TestCampaignResources:test_the_ai_starts_with_enough_to_last_an_evening()
  -- 2026-11-16: red ran dry after 1 h 20 with 500 points, 30 an hour and 120 a factory
  luaunit.assertEquals(veafCampaign.DYNAMIC_DEFAULTS.resources.start, 1000)
  luaunit.assertEquals(veafCampaign.DYNAMIC_DEFAULTS.resources.background_per_hour, 60)
  luaunit.assertEquals(veafCampaign.DYNAMIC_DEFAULTS.factory.per_hour, 180)
end

function TestCampaignResources:test_a_captured_zone_s_garrison_is_paid()
  start()
  local poti = veafCampaign.zones["Poti"]
  poti:becomeNeutral()
  veafCampaignLogistics.stocks.red = 1000
  poti:capturedBy("red")
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), 1000 - veafCampaign.garrisonPrice(poti.entry.garrison))
end

function TestCampaignResources:test_off_the_ai_is_free()
  start({ resources = { enabled = false } })
  luaunit.assertFalse(veafCampaignLogistics.active)
  luaunit.assertTrue(veafCampaign.canPay("red", 1000000))
  veafCampaignOps.maintainCaps("red")
  luaunit.assertEquals(#self.flights, 1)
end

function TestCampaignResources:test_stocks_and_what_comes_home_survive_a_restart()
  memoryFileSystem(self)
  start()
  veafCampaignLogistics.stocks.red = 321
  table.insert(veafCampaign.convoys, { name = "c", side = "red", from = "Senaki", to = "Poti", sent = {}, absorbed = {} })
  dcs_mocks.addGroup("c", {
    getUnits = function()
      return { unitAt({ x = 70000 }, { type = "T-72B" }), unitAt({ x = 70010 }, { type = "T-72B" }) }
    end,
  })
  table.insert(veafCampaignLogistics.deliveries, { side = "red", zone = "Zugdidi", at = 999, cost = 10 })
  veafCampaign.writeState()
  start()
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), 321 + 12 + 10)
end

-- ---------------------------------------------------------------------------
-- The supply network (ticket 13)
-- ---------------------------------------------------------------------------
TestCampaignNetwork = { setUp = setUpSuite, tearDown = tearDownSuite }

--- The red chain Senaki — Zugdidi — Tkvarcheli (factory), and a depot Gali made of Zugdidi when asked.
local function network(dynamic, depot)
  start(dynamic, function(d)
    if depot then
      d.zones[4].kind = "depot"
    end
  end)
end

function TestCampaignNetwork:test_each_hop_takes_its_time()
  network()
  local delays = veafCampaignLogistics.supplyDelays("red")
  luaunit.assertEquals(delays["Tkvarcheli"].delay, 0)
  luaunit.assertEquals(delays["Zugdidi"].delay, 600)
  luaunit.assertEquals(delays["Senaki"].delay, 1200)
  luaunit.assertEquals(delays["Senaki"].source, "Tkvarcheli")
end

function TestCampaignNetwork:test_a_segment_touching_a_depot_takes_half()
  network(nil, true)
  local delays = veafCampaignLogistics.supplyDelays("red")
  luaunit.assertEquals(delays["Zugdidi"].delay, 0) -- a depot with something in store is a source itself
  luaunit.assertEquals(delays["Senaki"].delay, 300)
  luaunit.assertEquals(
    veafCampaignLogistics.shortestDelays("red", {
      { zone = veafCampaign.zones["Tkvarcheli"], kind = "factory" },
    })["Senaki"].delay,
    600
  ) -- factory > depot > base: T/2 + T/2
end

-- FIX-CAMPAIGN-SECOND-SERVER-FLIGHT 02: Saraqib supplied itself "in 0 s" while a factory reached it, invulnerable
function TestCampaignNetwork:test_a_depot_has_buildings_to_destroy()
  network(nil, true)
  local zugdidi = veafCampaign.zones["Zugdidi"]
  luaunit.assertEquals(#zugdidi.entry.structures, veafCampaign.setting("network", "depot_buildings"))
  luaunit.assertEquals(zugdidi.entry.structures[1].type, "Warehouse")
  luaunit.assertEquals(veafCampaign.staticCategory("Warehouse"), "Warehouses")
  luaunit.assertEquals(veafCampaign.staticCategory("Workshop A"), "Fortifications")
  luaunit.assertTrue(zugdidi:isWorkingDepot())
end

function TestCampaignNetwork:test_a_depot_with_its_buildings_down_is_an_ordinary_node()
  network(nil, true)
  local zugdidi = veafCampaign.zones["Zugdidi"]
  veafCampaignLogistics.supplyDelays("red") -- reached by the factory: its store full
  for index in ipairs(zugdidi.entry.structures) do
    zugdidi:onStructureLost(index)
  end
  luaunit.assertFalse(zugdidi:isWorkingDepot())
  luaunit.assertEquals(veafCampaignLogistics.depotStores["Zugdidi"], 0, "its store burnt with it")
  local delays = veafCampaignLogistics.supplyDelays("red")
  luaunit.assertEquals(delays["Zugdidi"].delay, 600, "no longer a source of its own")
  luaunit.assertEquals(delays["Senaki"].delay, 1200, "no shorter hop")
  luaunit.assertEquals(veafCampaignLogistics.depotStores["Zugdidi"], 0, "a factory reaching it does not refill it")
  luaunit.assertFalse(zugdidi:repairStructure(), "a delivery rebuilds no depot building")
end

-- review of #1310: a depot at 2/3 read as damaged for ever, and the shop sold a resupply nothing could do
function TestCampaignNetwork:test_a_depot_s_lost_building_is_no_damage_a_delivery_repairs()
  network(nil, true)
  local zugdidi = veafCampaign.zones["Zugdidi"]
  zugdidi:onStructureLost(1)
  luaunit.assertFalse(zugdidi:isDamaged())
end

function TestCampaignNetwork:test_a_depot_is_rebuilt_only_after_its_long_delay()
  network({ network = { depot_rebuild_seconds = 2700 } }, true)
  local zugdidi = veafCampaign.zones["Zugdidi"]
  for index in ipairs(zugdidi.entry.structures) do
    zugdidi:onStructureLost(index)
  end
  luaunit.assertFalse(zugdidi:followDepot(2690))
  luaunit.assertFalse(zugdidi:isWorkingDepot())
  -- the delay is saved: a restart does not rebuild it, nor start the count again
  luaunit.assertEquals(veafCampaign.stateTable().zones["Zugdidi"].depot_down_seconds, 2690)
  luaunit.assertTrue(zugdidi:followDepot(10))
  luaunit.assertTrue(zugdidi:isWorkingDepot())
  luaunit.assertEquals(zugdidi:structuresStanding(), veafCampaign.setting("network", "depot_buildings"))
  luaunit.assertNil(zugdidi.entry.depot_down_seconds)
end

function TestCampaignNetwork:test_an_enemy_zone_cuts_the_path()
  network()
  veafCampaign.zones["Zugdidi"].entry.owner = "blue"
  local delays = veafCampaignLogistics.supplyDelays("red")
  luaunit.assertNil(delays["Senaki"])
  luaunit.assertNil(delays["Zugdidi"])
end

function TestCampaignNetwork:test_the_detour_is_taken()
  start(nil, function(d)
    table.insert(d.zones, zone("Mestia", "red", 175000, { z = 40000 }))
    table.insert(d.connections, { "Senaki", "Mestia" })
    table.insert(d.connections, { "Mestia", "Tkvarcheli" })
  end)
  veafCampaign.zones["Zugdidi"].entry.owner = "blue"
  luaunit.assertEquals(veafCampaignLogistics.supplyDelays("red")["Senaki"].delay, 1200)
end

function TestCampaignNetwork:test_a_destroyed_factory_feeds_nothing()
  network()
  for _, structure in ipairs(veafCampaign.zones["Tkvarcheli"].entry.structures) do
    structure.alive = false
  end
  luaunit.assertNil(veafCampaignLogistics.supplyDelays("red")["Senaki"])
end

function TestCampaignNetwork:test_a_depot_cut_from_its_factories_feeds_from_its_store_then_runs_dry()
  network({ network = { depot_store = 1 } }, true)
  veafCampaignLogistics.supplyDelays("red") -- reached by the factory: full
  for _, structure in ipairs(veafCampaign.zones["Tkvarcheli"].entry.structures) do
    structure.alive = false
  end
  veafCampaign.zones["Senaki"].entry.garrison = garrison("Senaki", { 1 })
  veafCampaignLogistics.dispatchDeliveries(0)
  luaunit.assertEquals(veafCampaignLogistics.deliveries[1].source, "Zugdidi")
  luaunit.assertEquals(veafCampaignLogistics.deliveries[1].at, 300)
  luaunit.assertEquals(veafCampaignLogistics.depotStores["Zugdidi"], 0)
  luaunit.assertNil(veafCampaignLogistics.supplyDelays("red")["Senaki"])
end

function TestCampaignNetwork:test_a_delivery_is_paid_at_the_order_and_reinforces_after_its_delay()
  network()
  local senaki = veafCampaign.zones["Senaki"]
  senaki.entry.garrison = garrison("Senaki", { 1 })
  local before = veafCampaignLogistics.stock("red")
  veafCampaignLogistics.dispatchDeliveries(0)
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), before - 6) -- the T-72B
  veafCampaignLogistics.dispatchDeliveries(10) -- one on its way per zone
  luaunit.assertEquals(#veafCampaignLogistics.deliveries, 1)
  veafCampaignLogistics.arriveDeliveries(1199)
  luaunit.assertTrue(senaki:garrisonDamaged())
  veafCampaignLogistics.arriveDeliveries(1200)
  luaunit.assertFalse(senaki:garrisonDamaged())
  luaunit.assertEquals(veafCampaignLogistics.counters.arrived, 1)
end

function TestCampaignNetwork:test_a_zone_lost_meanwhile_receives_nothing()
  network()
  local senaki = veafCampaign.zones["Senaki"]
  senaki.entry.garrison = garrison("Senaki", { 1 })
  veafCampaignLogistics.dispatchDeliveries(0)
  senaki.entry.owner = "blue"
  veafCampaignLogistics.arriveDeliveries(1200)
  luaunit.assertTrue(senaki:garrisonDamaged())
  luaunit.assertEquals(veafCampaignLogistics.counters.lost, 1)
end

-- FIX-CAMPAIGN-SECOND-SERVER-FLIGHT 03: Aleppo, under a player's fire, was reinforced every 5 minutes
function TestCampaignNetwork:test_a_delivery_waits_while_the_zone_is_under_fire()
  network()
  local senaki = veafCampaign.zones["Senaki"]
  senaki.entry.garrison = garrison("Senaki", { 1 })
  veafCampaignLogistics.dispatchDeliveries(0)
  senaki.lastLossAt = 1000
  veafCampaignLogistics.arriveDeliveries(1200)
  luaunit.assertTrue(senaki:garrisonDamaged())
  luaunit.assertEquals(#veafCampaignLogistics.deliveries, 1, "kept, not lost")
  veafCampaignLogistics.arriveDeliveries(1600)
  luaunit.assertFalse(senaki:garrisonDamaged())
  luaunit.assertEquals(#veafCampaignLogistics.deliveries, 0)
end

-- FIX-CAMPAIGN-SECOND-SERVER-FLIGHT 09: "lost: the zone is no longer theirs" said of Aleppo, still red, whole again
function TestCampaignNetwork:test_a_delivery_with_nothing_to_repair_goes_back_to_the_stock()
  network()
  local senaki = veafCampaign.zones["Senaki"]
  senaki.entry.garrison = garrison("Senaki", { 1 })
  veafCampaignLogistics.dispatchDeliveries(0)
  local paid = veafCampaignLogistics.stock("red")
  senaki:reinforce() -- a supply helicopter made it whole meanwhile
  veafCampaignLogistics.arriveDeliveries(1200)
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), paid + 6)
  luaunit.assertEquals(veafCampaignLogistics.counters.lost, 0)
  luaunit.assertEquals(veafCampaignLogistics.counters.unneeded, 1)
end

function TestCampaignNetwork:test_a_zone_cut_off_waits_the_isolated_delay()
  network()
  for _, structure in ipairs(veafCampaign.zones["Tkvarcheli"].entry.structures) do
    structure.alive = false
  end
  veafCampaign.zones["Senaki"].entry.garrison = garrison("Senaki", { 1 })
  veafCampaignLogistics.dispatchDeliveries(0)
  luaunit.assertEquals(veafCampaignLogistics.deliveries[1].at, 3600)
end

function TestCampaignNetwork:test_the_players_zones_are_reinforced_too()
  network()
  veafCampaign.zones["Poti"].entry.garrison = garrison("Poti", { 1 })
  veafCampaignLogistics.dispatchDeliveries(0)
  luaunit.assertEquals(veafCampaignLogistics.deliveries[1].zone, "Poti")
  luaunit.assertEquals(veafCampaignLogistics.deliveries[1].at, 3600) -- blue has no factory: cut off
end

function TestCampaignNetwork:test_no_more_deliveries_than_the_cap()
  network({ network = { max_deliveries = 1 } })
  veafCampaign.zones["Senaki"].entry.garrison = garrison("Senaki", { 1 })
  veafCampaign.zones["Zugdidi"].entry.garrison = garrison("Zugdidi", { 1 })
  veafCampaignLogistics.dispatchDeliveries(0)
  luaunit.assertEquals(#veafCampaignLogistics.deliveries, 1)
end

function TestCampaignNetwork:test_the_players_read_their_network()
  network()
  local text = veafCampaignLogistics.networkText("blue")
  luaunit.assertStrContains(text, "Resources: 1000 points, making 60 an hour")
  luaunit.assertStrContains(text, "- Kobuleti: cut off")
end

-- ---------------------------------------------------------------------------
-- Paid spawns (ticket 14)
-- ---------------------------------------------------------------------------
TestCampaignPaidSpawns = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignPaidSpawns:test_the_campaign_sets_the_gate()
  start()
  luaunit.assertEquals(veafSpawn.spawnGate, veafCampaignLogistics.spawnGate)
  luaunit.assertEquals(veafSpawn.spawnPaid, veafCampaignLogistics.spawnPaid)
end

--- A group spawned, with units of those types; `self.destroyed` lists what is taken away.
local function spawned(self, name, types)
  self.destroyed = self.destroyed or {}
  local this = self
  dcs_mocks.addGroup(name, {
    getUnits = function()
      local units = {}
      for index, typeName in ipairs(types) do
        table.insert(units, unitAt({ x = 10 * index }, { type = typeName }))
      end
      return units
    end,
    destroy = function()
      table.insert(this.destroyed, name)
    end,
  })
end

function TestCampaignPaidSpawns:test_a_blue_spawn_pays_its_units_in_credits()
  start()
  veafCampaignEconomy.credits = 500
  luaunit.assertTrue(veafCampaignLogistics.spawnGate("armoredPlatoon", { side = BLUE }, BLUE))
  -- a random platoon: what it drew is what it costs, 6 + 6 + 4 points, 6 credits a point
  spawned(self, "armor 1", { "T-72B", "T-72B", "BMP-2" })
  veafCampaignLogistics.spawnPaid("armoredPlatoon", { side = BLUE }, "armor 1", BLUE)
  luaunit.assertEquals(veafCampaignEconomy.credits, 500 - 16 * 6)
  luaunit.assertEquals(veafCampaignLogistics.counters.spawnsCharged, 1)
  luaunit.assertEquals(#messagesContaining("armoredPlatoon: 3 unit(s), 96 credits charged, balance 404"), 1)
end

function TestCampaignPaidSpawns:test_short_of_credits_the_spawn_stands_whole_and_the_side_goes_into_debt()
  start()
  veafCampaignEconomy.credits = 100
  self.destroyed = {} -- luaunit keeps the suite's table from one test to the next
  spawned(self, "armor 2", { "T-72B", "T-72B", "T-72B" })
  veafCampaignLogistics.spawnPaid("armoredPlatoon", { side = BLUE }, "armor 2", BLUE)
  luaunit.assertEquals(self.destroyed, {}) -- never cut in part
  luaunit.assertEquals(veafCampaignEconomy.credits, -8)
  luaunit.assertEquals(#messagesContaining("is in debt: -8 credits"), 1)
  -- in debt, nothing more
  luaunit.assertFalse(veafCampaignLogistics.spawnGate("armoredPlatoon", { side = BLUE }, BLUE))
  luaunit.assertEquals(#messagesContaining("armoredPlatoon refused: the coalition (blue) has -8 credits"), 1)
  -- a gain pays the debt off first
  veafCampaignEconomy.earn(10)
  luaunit.assertEquals(veafCampaignEconomy.credits, 2)
  luaunit.assertTrue(veafCampaignLogistics.spawnGate("armoredPlatoon", { side = BLUE }, BLUE))
end

function TestCampaignPaidSpawns:test_with_nothing_at_all_it_is_refused_before_anything_spawns()
  start()
  veafCampaignEconomy.credits = 0
  luaunit.assertFalse(veafCampaignLogistics.spawnGate("cap", { side = BLUE }, BLUE))
  luaunit.assertEquals(#messagesContaining("cap refused: the coalition (blue) has 0 credits"), 1)
end

function TestCampaignPaidSpawns:test_a_red_spawn_pays_its_units_from_red_resources_into_debt_if_need_be()
  start()
  veafCampaignLogistics.stocks.red = 20
  spawned(self, "armor 3", { "T-72B", "BMP-2" })
  veafCampaignLogistics.spawnPaid("armoredPlatoon", { side = RED }, "armor 3", BLUE)
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), 10)
  spawned(self, "armor 4", { "T-72B", "T-72B" })
  veafCampaignLogistics.spawnPaid("armoredPlatoon", { side = RED }, "armor 4", BLUE)
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), -2)
  luaunit.assertFalse(veafCampaignLogistics.spawnGate("armoredPlatoon", { side = RED }, BLUE))
  luaunit.assertEquals(#messagesContaining("armoredPlatoon refused: red has -2 resource points"), 1)
end

function TestCampaignPaidSpawns:test_a_side_in_debt_pays_nothing_else()
  start()
  veafCampaignLogistics.stocks.red = -2
  luaunit.assertFalse(veafCampaignLogistics.canPay("red", 1))
  luaunit.assertFalse(veafCampaignLogistics.canPay("red", 1, "essential"))
  -- what "partial" pays when there is nothing is nothing: a debt never grows by it, nor shrinks
  luaunit.assertTrue(veafCampaignLogistics.pay("red", 30, "partial"))
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), -2)
  veafCampaignOps.maintainCaps("red")
  luaunit.assertEquals(#self.flights, 0)
end

function TestCampaignPaidSpawns:test_a_command_that_puts_no_unit_into_play_is_free()
  start()
  veafCampaignEconomy.credits = 0
  luaunit.assertTrue(veafCampaignLogistics.spawnGate("smoke", { side = BLUE }, BLUE))
  luaunit.assertTrue(veafCampaignLogistics.spawnGate("teleport", { side = BLUE }, BLUE))
  veafCampaignLogistics.spawnPaid("teleport", { side = BLUE }, "anything", BLUE)
  luaunit.assertEquals(veafCampaignEconomy.credits, 0)
end

function TestCampaignPaidSpawns:test_what_a_paid_spawn_left_standing_comes_home_at_the_next_load()
  memoryFileSystem(self)
  start()
  veafCampaignEconomy.credits = 1000
  spawned(self, "armor 5", { "T-72B", "BMP-2" })
  veafCampaignLogistics.spawnPaid("armoredPlatoon", { side = BLUE }, "armor 5", BLUE)
  veafCampaignLogistics.stocks.blue = 100
  veafCampaign.writeState()
  start()
  luaunit.assertEquals(veafCampaignLogistics.stock("blue"), 110)
end

-- ---------------------------------------------------------------------------
-- Demolition team (ticket 15)
-- ---------------------------------------------------------------------------
TestCampaignSappers = { setUp = setUpSuite, tearDown = tearDownSuite }

--- A CTLD 2 troop manager with one blue group dropped, of that template, its unit where `self.position` says.
local function dropTroops(self, groupName, template)
  self.position = { x = 0, z = 0 }
  self.routes = {}
  local this = self
  CTLDTroopManager = {
    getInstance = function()
      return {
        _droppedGroups = { [BLUE] = { groupName } },
        _droppedTemplates = { [groupName] = { key = template, name = template, weight = 200, total = 2 } },
      }
    end,
  }
  dcs_mocks.addGroup(groupName, {
    getUnits = function()
      return { unitAt(this.position) }
    end,
    getController = function()
      return {
        setTask = function(_, task)
          table.insert(this.routes, task)
        end,
      }
    end,
  })
end

function TestCampaignSappers:test_they_blow_up_the_factory_in_range()
  start()
  local factory = veafCampaign.zones["Tkvarcheli"]
  local row = factory:structuresCenter()
  dropTroops(self, "Sappers #1", "Sappers")
  self.position = { x = row.x - 3000, z = row.z }
  veafCampaignLogistics.followSappers(0)
  luaunit.assertEquals(veafCampaignLogistics.sappers["Sappers #1"].zone, "Tkvarcheli")
  luaunit.assertEquals(#self.routes, 1)
  self.position = { x = row.x - 100, z = row.z }
  veafCampaignLogistics.followSappers(600)
  luaunit.assertEquals(veafCampaignLogistics.sappers["Sappers #1"].plantedAt, 600)
  luaunit.assertEquals(#self.routes, 2) -- walking back to where they were dropped
  veafCampaignLogistics.followSappers(719)
  luaunit.assertEquals(#dcs_mocks.effects, 0)
  dcs_mocks.currentTime = 720
  veafCampaignLogistics.followSappers(720)
  luaunit.assertEquals(#dcs_mocks.effects, 3)
  luaunit.assertEquals(dcs_mocks.effects[1].kind, "explosion")
  local credits = veafCampaignEconomy.credits
  veafCampaign.onUnitDead({ initiator = { unitName = "Tkvarcheli building #1" } })
  luaunit.assertEquals(veafCampaignEconomy.credits, credits + 100)
  luaunit.assertEquals(veafCampaignLogistics.counters.demolished, 1)
end

function TestCampaignSappers:test_no_factory_in_range_they_stay()
  start({ demolition = { range = 1000 } })
  dropTroops(self, "Sappers #2", "Sappers")
  veafCampaignLogistics.followSappers(0)
  luaunit.assertNil(veafCampaignLogistics.sappers["Sappers #2"].zone)
  luaunit.assertEquals(#self.routes, 0)
  luaunit.assertEquals(#messagesContaining("no enemy factory within 1 km"), 1)
end

function TestCampaignSappers:test_other_troops_are_left_alone()
  start()
  dropTroops(self, "Squad #3", "Standard Group")
  veafCampaignLogistics.followSappers(0)
  luaunit.assertNil(veafCampaignLogistics.sappers["Squad #3"])
end

-- ---------------------------------------------------------------------------
-- Warehouse stocks (ticket 16)
-- ---------------------------------------------------------------------------
TestCampaignWarehouse = { setUp = setUpSuite, tearDown = tearDownSuite }

--- Airfields whose warehouses hold what `self.stocks[airbase]` says, and record what they are told.
local function warehouses(self)
  self.stocks = { ["Kobuleti"] = { ["weapons.missiles.AIM_9"] = 30, ["weapons.bombs.Mk_82"] = 4 }, ["Senaki-Kolkhi"] = {} }
  self.set = {}
  local this = self
  Airbase.getByName = function(name)
    return {
      getID = function()
        return 1
      end,
      getPoint = function()
        return { x = 0, y = 0, z = 0 }
      end,
      getWarehouse = function()
        local stock = this.stocks[name] or {}
        this.stocks[name] = stock
        return {
          getInventory = function()
            return { weapon = stock, aircraft = {}, liquids = {} }
          end,
          removeItem = function(_, item, count)
            stock[item] = stock[item] - count
          end,
          addItem = function(_, item, count)
            stock[item] = (stock[item] or 0) + count
          end,
          setItem = function(_, item, count)
            table.insert(this.set, { name, item, count })
            stock[item] = count
          end,
        }
      end,
    }
  end
end

local function pilot(name, point, options)
  dcs_mocks.addUnit(name, unitAt(point, options))
end

function TestCampaignWarehouse:test_a_helicopter_carries_weapons_from_one_airfield_to_another()
  start()
  warehouses(self)
  self.stocks["Poti"] = nil
  veafCampaign.zones["Poti"].entry.airbase = "Poti"
  pilot("Huey", { x = 100 }, { category = Unit.Category.HELICOPTER })
  veafCampaignLogistics.loadWeapons("Huey")
  luaunit.assertEquals(self.stocks["Kobuleti"]["weapons.missiles.AIM_9"], 20)
  luaunit.assertEquals(self.stocks["Kobuleti"]["weapons.bombs.Mk_82"], 0)
  luaunit.assertEquals(veafCampaignLogistics.cargo["Huey"].total, 14)
  -- not at the airfield it loaded at
  veafCampaignLogistics.unloadWeapons("Huey")
  luaunit.assertNotNil(veafCampaignLogistics.cargo["Huey"])
  pilot("Huey", { x = 50000 }, { category = Unit.Category.HELICOPTER })
  local credits = veafCampaignEconomy.credits
  veafCampaignLogistics.unloadWeapons("Huey")
  luaunit.assertEquals(self.stocks["Poti"]["weapons.missiles.AIM_9"], 10)
  luaunit.assertEquals(self.stocks["Poti"]["weapons.bombs.Mk_82"], 4)
  luaunit.assertNil(veafCampaignLogistics.cargo["Huey"])
  luaunit.assertEquals(veafCampaignEconomy.credits, credits + 50)
end

function TestCampaignWarehouse:test_weapons_carried_back_and_forth_pay_once_per_new_airfield()
  start()
  warehouses(self)
  self.stocks["Poti"] = { ["weapons.missiles.AIM_9"] = 30 }
  veafCampaign.zones["Poti"].entry.airbase = "Poti"
  local credits = veafCampaignEconomy.credits
  local function trip(fromX, toX)
    pilot("Huey", { x = fromX }, { category = Unit.Category.HELICOPTER })
    veafCampaignLogistics.loadWeapons("Huey")
    pilot("Huey", { x = toX }, { category = Unit.Category.HELICOPTER })
    veafCampaignLogistics.unloadWeapons("Huey")
  end
  trip(100, 50000)
  trip(50000, 100)
  trip(100, 50000)
  -- Poti, Kobuleti, then Poti again: the last one is a delivery already paid
  luaunit.assertEquals(veafCampaignEconomy.credits, credits + 100)
  -- a new life starts afresh
  veafCampaignLogistics.onAircraftGone({ initiator = { unitName = "Huey" } })
  trip(100, 50000)
  luaunit.assertEquals(veafCampaignEconomy.credits, credits + 150)
end

function TestCampaignWarehouse:test_a_fighter_or_an_aircraft_in_flight_carries_nothing()
  start()
  warehouses(self)
  pilot("Viper", { x = 100 }, { category = Unit.Category.AIRPLANE })
  veafCampaignLogistics.loadWeapons("Viper")
  luaunit.assertNil(veafCampaignLogistics.cargo["Viper"])
  pilot("Huey", { x = 100 }, { category = Unit.Category.HELICOPTER, inAir = true })
  veafCampaignLogistics.loadWeapons("Huey")
  luaunit.assertNil(veafCampaignLogistics.cargo["Huey"])
  pilot("Herc", { x = 100 }, { category = Unit.Category.AIRPLANE, attributes = { Transports = true } })
  veafCampaignLogistics.loadWeapons("Herc")
  luaunit.assertNotNil(veafCampaignLogistics.cargo["Herc"])
end

function TestCampaignWarehouse:test_the_cargo_is_lost_with_the_aircraft()
  start()
  warehouses(self)
  pilot("Huey", { x = 100 }, { category = Unit.Category.HELICOPTER })
  veafCampaignLogistics.loadWeapons("Huey")
  veafCampaignLogistics.onAircraftGone({ initiator = { unitName = "Huey" } })
  luaunit.assertNil(veafCampaignLogistics.cargo["Huey"])
end

function TestCampaignWarehouse:test_the_counts_are_restored_at_the_load_an_unlimited_one_left()
  warehouses(self)
  veafCampaign.data = data()
  veafCampaign.data.zones[1].saved_warehouse = { weapon = { ["weapons.missiles.AIM_9"] = 12, ["weapons.bombs.Mk_82"] = 1073741823 } }
  veafCampaign.initialize()
  luaunit.assertEquals(self.set, { { "Kobuleti", "weapons.missiles.AIM_9", 12 } })
  luaunit.assertEquals(veafCampaignLogistics.counters.warehousesRestored, 1)
end

-- ---------------------------------------------------------------------------
-- Strategic bombers (ticket 17)
-- ---------------------------------------------------------------------------
TestCampaignBombers = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignBombers:test_a_raid_aims_at_a_factory_first()
  start({ bombers = { min_distance = 40000 } }, function(d)
    d.zones[2].kind = "factory"
  end)
  luaunit.assertEquals(veafCampaignOps.raidTarget("red").name, "Poti")
  luaunit.assertEquals(veafCampaignOps.raidTarget("blue").name, "Tkvarcheli")
end

function TestCampaignBombers:test_a_target_no_airfield_can_reach_is_passed_over()
  start({ bombers = { min_distance = 90000 } }, function(d)
    d.zones[2].kind = "factory" -- Poti, 50 km from Senaki, red's only airfield: too near; Kobuleti, 100 km, is not
  end)
  luaunit.assertEquals(veafCampaignOps.raidTarget("red").name, "Kobuleti")
  start({ bombers = { min_distance = 500000 } })
  luaunit.assertNil(veafCampaignOps.raidTarget("red"))
end

function TestCampaignBombers:test_it_leaves_from_the_nearest_airfield_far_enough()
  start()
  luaunit.assertEquals(veafCampaignOps.raidOrigin("red", veafCampaign.zones["Poti"]), nil) -- Senaki is 50 km away
  luaunit.assertEquals(veafCampaignOps.raidOrigin("red", veafCampaign.zones["Kobuleti"]).name, "Senaki")
end

local function rolesFlown(self)
  local roles = {}
  for _, flight in ipairs(self.flights) do
    table.insert(roles, flight.role)
  end
  return roles
end

function TestCampaignBombers:test_the_red_raid_is_a_paid_package_announced_and_posted_on_the_board()
  start({ bombers = { seconds = 60, min_distance = 50000 } })
  veafCampaignLogistics.stocks.red = 1000
  veafCampaignOps.launchRaids("red", 0)
  veafCampaignOps.launchRaids("red", 60)
  -- nothing covers Kobuleti: no SEAD, the bomber leaves with its BARCAP; no escort by default
  luaunit.assertEquals(rolesFlown(self), { "zone_defense", "campaign_bomber" })
  luaunit.assertEquals(self.flights[2].group.units[1].type, "Tu-22M3")
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), 1000 - 100 - 60)
  -- Kobuleti and Poti hold as many units; Kobuleti, declared first, is the target, Senaki 100 km off the origin
  luaunit.assertEquals(#messagesContaining("Intelligence: enemy bombers are heading for Kobuleti, from Senaki"), 1)
  veafCampaignEconomy.refreshTasks()
  luaunit.assertEquals(veafCampaignEconomy.tasks[1].kind, "intercept")
  -- one out at a time
  veafCampaignOps.launchRaids("red", 120)
  luaunit.assertEquals(#self.flights, 2)
end

--- Put a raid's flight at a point, in the air or not.
local function flightAt(name, point, inAir)
  dcs_mocks.addGroup(name, {
    getUnits = function()
      return { unitAt(point, { inAir = inAir }) }
    end,
    getID = function()
      return 77
    end,
  })
end

function TestCampaignBombers:test_the_whole_package_takes_off_from_the_ground()
  start({ bombers = { min_distance = 50000, escort = true } }, function(d)
    d.zones[1].garrison[1].units[1].type = "SA-11 Buk LN 9A310M1"
  end)
  veafCampaignLogistics.stocks.red = 1000
  local airStarts = {}
  local spawnFlight = veafCampaignOps.spawnFlight
  veafCampaignOps.spawnFlight = function(side, aircraftRole, origin, roleName, params, altitude, airStart)
    table.insert(airStarts, airStart == true)
    return spawnFlight(side, aircraftRole, origin, roleName, params, altitude, airStart)
  end
  veafCampaignOps.sendRaid("red", veafCampaign.zones["Kobuleti"])
  veafCampaignOps.spawnFlight = spawnFlight
  -- BARCAP, SEAD, bomber and escort: none of them starts in the air (David, 2026-11-16)
  luaunit.assertEquals(airStarts, { false, false, false, false })
end

function TestCampaignBombers:test_a_raid_keeps_the_sead_zone_awake_as_well_as_its_target()
  -- measured 2026-11-16: Kobuleti, the SEAD's zone, slept while the raid on Ozurgeti flew at it
  start({ bombers = { min_distance = 50000 } })
  veafCampaignLogistics.stocks.red = 1000
  local covering, keepAwake = veafCampaignOps.coveringAirDefence, veafCampaign.keepAwake
  veafCampaignOps.coveringAirDefence = function()
    return veafCampaign.zones["Poti"]
  end
  local kept = {}
  veafCampaign.keepAwake = function(zone, seconds)
    kept[zone.name] = seconds
  end
  local raid = veafCampaignOps.sendRaid("red", veafCampaign.zones["Kobuleti"])
  veafCampaignOps.coveringAirDefence, veafCampaign.keepAwake = covering, keepAwake
  luaunit.assertEquals(raid.seadOn, "Poti")
  luaunit.assertEquals(kept, { Kobuleti = veafCampaignOps.RAID_TIMEOUT, Poti = veafCampaignOps.RAID_TIMEOUT })
end

function TestCampaignBombers:test_the_sead_and_the_bomber_hold_together_then_push_the_bomber_behind()
  start({ bombers = { min_distance = 50000 } }, function(d)
    d.zones[1].garrison[1].units[1].type = "SA-11 Buk LN 9A310M1"
  end)
  veafCampaignLogistics.stocks.red = 1000
  local flags = {}
  local setUserFlag = trigger.action.setUserFlag
  trigger.action.setUserFlag = function(flag, value)
    flags[flag] = value
  end
  dcs_mocks.currentTime = 1000
  local raid = veafCampaignOps.sendRaid("red", veafCampaign.zones["Kobuleti"])
  -- all of it at once, and paid at once
  luaunit.assertEquals(rolesFlown(self), { "zone_defense", "campaign_strike", "campaign_bomber" })
  luaunit.assertEquals(self.flights[2].params.task, "SEAD")
  luaunit.assertEquals(raid.seadOn, "Kobuleti")
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), 1000 - 100 - 60 - 60)
  -- both hold at the same point on the axis, out of Kobuleti's and Poti's reach (20 km assumed, 15 km margin)
  local seadHold, bomberHold = self.flights[2].params.hold, self.flights[3].params.hold
  luaunit.assertEquals({ seadHold.x, seadHold.z }, { 85000, 0 })
  luaunit.assertEquals({ bomberHold.x, bomberHold.z }, { 85000, 0 })
  luaunit.assertNotEquals(seadHold.flag, bomberHold.flag)
  -- in a package, the bomber flies at the SEAD's speed: it does not catch it up
  luaunit.assertEquals(self.flights[3].params.speed, veafCampaignOps.STRIKE_SPEED)
  -- the bomber is on the ground, the SEAD on its way: nobody pushes
  flightAt(raid.name, { x = 100000 }, false)
  flightAt(raid.sead, { x = 110000, y = 2500 }, true)
  veafCampaignOps.followRaid(raid, 1100)
  luaunit.assertEquals(flags, {})
  luaunit.assertNil(raid.outcome)
  -- the bomber over the hold but still climbing: not holding yet (2026-11-16: both pushed straight after take-off)
  flightAt(raid.name, { x = 86000, y = 3000 }, true)
  flightAt(raid.sead, { x = 84000, y = 2500 }, true)
  veafCampaignOps.followRaid(raid, 1150)
  luaunit.assertEquals(flags, {})
  -- the bomber holds, the SEAD not yet: still nobody, and the log says where each stands
  -- (2026-11-16: circling at 200 m/s, a flight stays some 7 km from the point; it held 10 min unseen at 5 km)
  flightAt(raid.name, { x = 93000, y = 7000 }, true)
  flightAt(raid.sead, { x = 110000, y = 2500 }, true)
  veafCampaignOps.followRaid(raid, 1200)
  luaunit.assertEquals(flags, {})
  local waiting = "waits at its hold: bomber 8 km away at 7000 m (holds), SEAD 25 km away at 2500 m"
  local seen = false
  for _, entry in ipairs(dcs_mocks.logs) do
    seen = seen or string.find(entry.text, waiting, 1, true) ~= nil
  end
  luaunit.assertTrue(seen, waiting)
  -- both hold, each on its circle 7-8 km from the point: the SEAD pushes, the bomber `package_delay` after it
  flightAt(raid.sead, { x = 78000, y = 2500 }, true)
  veafCampaignOps.followRaid(raid, 1300)
  luaunit.assertEquals(flags, { [seadHold.flag] = 1 })
  veafCampaignOps.followRaid(raid, 1329)
  luaunit.assertNil(flags[bomberHold.flag])
  veafCampaignOps.followRaid(raid, 1330)
  luaunit.assertEquals(flags[bomberHold.flag], 1)
  trigger.action.setUserFlag = setUserFlag
end

function TestCampaignBombers:test_with_its_sead_shot_down_the_bomber_pushes_alone()
  start({ bombers = { min_distance = 50000 } }, function(d)
    d.zones[1].garrison[1].units[1].type = "SA-11 Buk LN 9A310M1"
  end)
  veafCampaignLogistics.stocks.red = 1000
  local flags = {}
  local setUserFlag = trigger.action.setUserFlag
  trigger.action.setUserFlag = function(flag, value)
    flags[flag] = value
  end
  local raid = veafCampaignOps.sendRaid("red", veafCampaign.zones["Kobuleti"])
  flightAt(raid.name, { x = 85000, y = 7000 }, true)
  dcs_mocks.addGroup(raid.sead, {
    getUnits = function()
      return {}
    end,
  })
  veafCampaignOps.followRaid(raid, 100)
  luaunit.assertEquals(flags[self.flights[3].params.hold.flag], 1)
  trigger.action.setUserFlag = setUserFlag
end

function TestCampaignBombers:test_a_raid_on_the_ground_is_not_over_until_it_has_flown()
  start({ bombers = { min_distance = 50000 } })
  local raid = veafCampaignOps.sendRaid("red", veafCampaign.zones["Kobuleti"])
  flightAt(raid.name, { x = 100000 }, false)
  veafCampaignOps.followRaid(raid, 1000)
  luaunit.assertNil(raid.outcome)
  flightAt(raid.name, { x = 50000 }, true)
  veafCampaignOps.followRaid(raid, 1100)
  flightAt(raid.name, { x = 100000 }, false)
  veafCampaignOps.followRaid(raid, 3000)
  luaunit.assertEquals(raid.outcome, "home")
end

function TestCampaignBombers:test_the_barcap_holds_out_of_every_enemy_air_defence()
  start(nil, function(d)
    d.zones[3].x = 200000 -- Senaki
  end)
  -- Kobuleti's own reach would put it at 50 km, over Poti; Poti's puts it 50 km beyond
  local station, origin = veafCampaignOps.barcapStation("red", veafCampaign.zones["Kobuleti"])
  luaunit.assertEquals(origin.name, "Senaki")
  luaunit.assertEquals({ station.x, station.y }, { 100000, 0 })
  -- no point of the axis is out of reach — a long-range battery at Poti covers Senaki: it holds over its own field
  start(nil, function(d)
    d.zones[2].size.long_range_sam = true
  end)
  station = veafCampaignOps.barcapStation("red", veafCampaign.zones["Kobuleti"])
  luaunit.assertEquals({ station.x, station.y }, { 100000, 0 })
end

function TestCampaignBombers:test_the_escort_flies_only_when_asked_and_starts_beside_its_bomber()
  start({ bombers = { min_distance = 50000, escort = true } })
  veafCampaignLogistics.stocks.red = 1000
  veafCampaignOps.sendRaid("red", veafCampaign.zones["Poti"])
  luaunit.assertEquals(rolesFlown(self), { "zone_defense", "campaign_bomber", "campaign_escort" })
  local bomber, escort = self.flights[2].group.units[1], self.flights[3].group.units[1]
  luaunit.assertNotEquals({ bomber.x, bomber.y }, { escort.x, escort.y })
  luaunit.assertEquals(escort.alt - bomber.alt, veafCampaignOps.ESCORT_START_OFFSET.alt)
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), 1000 - 100 - 60 - 60)
end

function TestCampaignBombers:test_the_intercept_task_is_posted_at_once_even_on_a_full_board()
  start({ bombers = { min_distance = 50000 }, tasks = { count = 1 } })
  veafCampaignEconomy.refreshTasks()
  luaunit.assertEquals(#veafCampaignEconomy.tasks, 1)
  veafCampaignOps.sendRaid("red", veafCampaign.zones["Poti"])
  luaunit.assertEquals(#veafCampaignEconomy.tasks, 2)
  luaunit.assertEquals(veafCampaignEconomy.tasks[2].kind, "intercept")
end

function TestCampaignBombers:test_shot_down_the_intercept_task_pays()
  start({ bombers = { min_distance = 50000 } })
  local raid = veafCampaignOps.sendRaid("red", veafCampaign.zones["Poti"])
  veafCampaignEconomy.refreshTasks()
  local credits = veafCampaignEconomy.credits
  dcs_mocks.clearUnitsAndGroups() -- the bomber is gone
  veafCampaignOps.onFlightEvent({ id = world.event.S_EVENT_KILL, target = { unitName = raid.name .. " #1" } })
  veafCampaignOps.followRaid(raid, 100)
  luaunit.assertEquals(raid.outcome, "destroyed")
  veafCampaignEconomy.checkTasks()
  luaunit.assertEquals(veafCampaignEconomy.credits, credits + 400)
end

-- FIX-CAMPAIGN-SECOND-SERVER-FLIGHT 09: the Tu-22M3 of 2026-11-17 aborted on the ground and vanished, no death seen
function TestCampaignBombers:test_a_bomber_gone_without_a_death_is_not_a_raid_shot_down()
  start({ bombers = { min_distance = 50000 } })
  local raid = veafCampaignOps.sendRaid("red", veafCampaign.zones["Poti"])
  veafCampaignEconomy.refreshTasks()
  local credits = veafCampaignEconomy.credits
  dcs_mocks.clearUnitsAndGroups()
  veafCampaignOps.followRaid(raid, 100)
  luaunit.assertEquals(raid.outcome, "gone")
  luaunit.assertEquals(veafCampaignOps.counters.raidsDestroyed, 0)
  veafCampaignEconomy.checkTasks()
  luaunit.assertEquals(veafCampaignEconomy.credits, credits, "nobody shot it down")
end

function TestCampaignBombers:test_the_escort_keeps_fighting_when_its_bomber_falls_and_goes_with_it_home()
  start({ bombers = { min_distance = 50000 } })
  local destroyed = {}
  local function flight(name, alive)
    dcs_mocks.addGroup(name, {
      getUnits = function()
        return alive and { unitAt({ x = 0 }, { inAir = true }) } or {}
      end,
      destroy = function()
        table.insert(destroyed, name)
      end,
    })
  end
  local shot = { name = "bomber A", escort = "escort A", side = "red", target = "Poti", startedAt = 0 }
  flight("bomber A", false)
  flight("escort A", true)
  veafCampaignOps.onFlightEvent({ id = world.event.S_EVENT_DEAD, initiator = { unitName = "bomber A #1" } })
  veafCampaignOps.followRaid(shot, 100)
  luaunit.assertEquals(shot.outcome, "destroyed")
  luaunit.assertEquals(destroyed, {})
  local back = { name = "bomber B", escort = "escort B", side = "red", target = "Poti", startedAt = 0 }
  flight("bomber B", true)
  flight("escort B", true)
  veafCampaignOps.followRaid(back, veafCampaignOps.RAID_TIMEOUT + 1)
  luaunit.assertEquals(back.outcome, "home")
  luaunit.assertEquals(destroyed, { "bomber B", "escort B" })
end

function TestCampaignBombers:test_no_raid_when_red_cannot_pay()
  start({ bombers = { min_distance = 50000 } })
  veafCampaignLogistics.stocks.red = 150
  luaunit.assertNil(veafCampaignOps.sendRaid("red", veafCampaign.zones["Poti"]))
  luaunit.assertEquals(#self.flights, 0)
end

function TestCampaignBombers:test_the_players_buy_a_raid()
  start({ bombers = { min_distance = 50000 } })
  veafCampaignEconomy.credits = 2000
  local stock = veafCampaignLogistics.stock("blue")
  luaunit.assertTrue(veafCampaignEconomy.buy({ "bomber", "Zugdidi" }))
  luaunit.assertEquals(veafCampaignEconomy.credits, 700)
  luaunit.assertEquals(veafCampaignLogistics.stock("blue"), stock)
  -- the same package as the enemy's: a BARCAP, then the bomber on the target
  luaunit.assertEquals(rolesFlown(self), { "zone_defense", "campaign_bomber" })
  luaunit.assertEquals(self.flights[2].params.target.x, 150000)
end

function TestCampaignBombers:test_the_bomber_route_bombs_then_lands_at_home()
  start()
  local route = veafAircraftSpawn.roles.campaign_bomber.buildRoute({
    spot = { x = 1, y = 7000, z = 2 },
    params = { target = { x = 100, z = 200 }, airdromeId = 5, home = { x = 1, z = 2 } },
  })
  local tasks = route[1].task.params.tasks
  -- weapons free, no reaction to a threat, no jettison, then the bombing
  luaunit.assertEquals(tasks[2].params.action.params, { name = 1, value = 0 })
  luaunit.assertEquals(tasks[3].params.action.params, { name = 15, value = true })
  -- a carpet: the `Bombing` task let a Tu-22M3 drop its 33 bombs one or two a pass (2026-11-16)
  luaunit.assertEquals(tasks[4].id, "CarpetBombing")
  luaunit.assertEquals({ tasks[4].params.x, tasks[4].params.y }, { 100, 200 })
  luaunit.assertEquals(tasks[4].params.expend, "All")
  luaunit.assertEquals(tasks[4].params.carpetLength, veafCampaignOps.CARPET_LENGTH)
  -- over the target, then back the way it came before it turns home (David, 2026-11-16: it went on over
  -- Kobuleti and was shot down)
  luaunit.assertEquals({ route[2].x, route[2].y }, { 100, 200 })
  local back = math.min(veafCampaignOps.EGRESS_DISTANCE, math.sqrt(99 ^ 2 + 198 ^ 2))
  luaunit.assertAlmostEquals(math.sqrt((route[3].x - 100) ^ 2 + (route[3].y - 200) ^ 2), back, 0.01)
  luaunit.assertTrue(route[3].x < 100 and route[3].y < 200, "toward where it came from")
  luaunit.assertEquals(route[4].type, "Land")
  luaunit.assertEquals(route[4].airdromeId, 5)
end

function TestCampaignBombers:test_the_bomber_takes_off_holds_then_bombs_from_its_push_point()
  start()
  local takeoffPoint = { x = 0, y = 0, alt = 0, type = "TakeOffParkingHot", action = "From Parking Area Hot", airdromeId = 5 }
  local route = veafAircraftSpawn.roles.campaign_bomber.buildRoute({
    spot = { x = 0, y = 7000, z = 0 },
    takeoffPoint = takeoffPoint,
    params = {
      target = { x = -40000, z = 0 },
      airdromeId = 5,
      home = { x = 0, z = 0 },
      hold = { x = -10000, z = 0, flag = "raid 1 bomber" },
    },
  })
  luaunit.assertEquals(route[1].type, "TakeOffParkingHot")
  -- no reaction to a threat and no jettison from the take-off on (2026-11-16: fired at before its push point,
  -- a Tu-22M3 jettisoned its 33 bombs 50 km short of the target)
  local options = {}
  for _, task in ipairs(route[1].task.params.tasks) do
    local action = task.params and task.params.action
    if action and action.id == "Option" then
      options[action.params.name] = action.params.value
    end
  end
  luaunit.assertEquals(options, { [1] = 0, [15] = true })
  -- it orbits at the hold until its flag is raised
  local hold = route[2].task.params.tasks[1]
  luaunit.assertEquals({ route[2].x, route[2].y }, { -10000, 0 })
  luaunit.assertEquals(hold.id, "ControlledTask")
  luaunit.assertEquals(hold.params.stopCondition.userFlag, "raid 1 bomber")
  -- then bombs, from its push point on the axis
  local tasks = route[3].task.params.tasks
  luaunit.assertEquals({ route[3].x, route[3].y }, { -12000, 0 })
  luaunit.assertEquals(tasks[4].id, "CarpetBombing")
  -- over the target, then back along the axis it came in on, which its SEAD cleared, before it turns home
  luaunit.assertEquals({ route[4].x, route[4].y }, { -40000, 0 })
  luaunit.assertEquals({ route[5].x, route[5].y }, { -40000 + veafCampaignOps.EGRESS_DISTANCE, 0 })
  luaunit.assertEquals(route[#route].type, "Land")
end

function TestCampaignBombers:test_the_sead_holds_then_engages_from_its_push_point()
  start()
  local route = veafAircraftSpawn.roles.campaign_strike.buildRoute({
    spot = { x = 0, y = 2500, z = 0 },
    params = {
      target = { x = -40000, z = 0 },
      radius = 2000,
      targetTypes = { "Air Defence" },
      airdromeId = 5,
      home = { x = 0, z = 0 },
      hold = { x = -10000, z = 0, flag = "raid 1 sead" },
    },
  })
  -- its targets given from the start, weapons held (2026-11-16: given only at the push point, the SEAD flew over
  -- Kobuleti without a shot; sent straight, with its targets from the start, it had fired)
  local first = route[1].task.params.tasks
  luaunit.assertEquals(first[1].params.action.params, { name = 0, value = 4 })
  luaunit.assertEquals(first[2].id, "EngageTargetsInZone")
  -- it orbits at the hold until its flag is raised, then is weapons free from its push point
  luaunit.assertEquals(route[2].task.params.tasks[1].params.stopCondition.userFlag, "raid 1 sead")
  luaunit.assertEquals(route[3].task.params.tasks[1].params.action.params, { name = 0, value = 0 })
  luaunit.assertEquals(#route[3].task.params.tasks, 1)
  luaunit.assertEquals({ route[4].x, route[4].y }, { -40000, 0 })
end

-- ---------------------------------------------------------------------------
-- Territory cells (ticket 18)
-- ---------------------------------------------------------------------------
TestCampaignTerritory = { setUp = setUpSuite, tearDown = tearDownSuite }

local function area(polygon)
  local sum = 0
  for index, p in ipairs(polygon) do
    local q = polygon[index % #polygon + 1]
    sum = sum + p.x * q.z - q.x * p.z
  end
  return math.abs(sum) / 2
end

local function contains(polygon, point)
  -- convex, either orientation: the point is on the same side of every edge
  local sign = nil
  for index, p in ipairs(polygon) do
    local q = polygon[index % #polygon + 1]
    local cross = (q.x - p.x) * (point.z - p.z) - (q.z - p.z) * (point.x - p.x)
    if cross ~= 0 then
      local s = cross > 0
      if sign == nil then
        sign = s
      elseif sign ~= s then
        return false
      end
    end
  end
  return true
end

function TestCampaignTerritory:test_two_sites_split_the_box_in_half()
  local cells = veafCampaign.voronoiCells({ { x = 0, z = 0 }, { x = 100, z = 0 } }, 50)
  luaunit.assertAlmostEquals(area(cells[1]), 100 * 100, 0.001)
  luaunit.assertAlmostEquals(area(cells[2]), 100 * 100, 0.001)
end

function TestCampaignTerritory:test_the_cells_cover_the_box_and_each_holds_its_site()
  local sites = { { x = 0, z = 0 }, { x = 100, z = 30 }, { x = 40, z = 120 }, { x = 160, z = 160 } }
  local cells = veafCampaign.voronoiCells(sites, 50)
  local total = 0
  for index, cell in ipairs(cells) do
    total = total + area(cell)
    luaunit.assertTrue(contains(cell, sites[index]), "site " .. index)
  end
  luaunit.assertAlmostEquals(total, 260 * 260, 0.001)
end

function TestCampaignTerritory:test_an_edge_knows_the_cell_on_its_other_side()
  local cells = veafCampaign.voronoiCells({ { x = 0, z = 0 }, { x = 100, z = 0 } }, 50)
  local labels = {}
  for _, vertex in ipairs(cells[1]) do
    if vertex.edge then
      table.insert(labels, vertex.edge)
    end
  end
  luaunit.assertEquals(labels, { 2 })
end

function TestCampaignTerritory:test_the_map_is_tinted_and_the_front_drawn_once_per_change()
  start()
  local markups = #dcs_mocks.markups
  luaunit.assertTrue(markups >= 5) -- a triangle at least per cell
  luaunit.assertEquals(dcs_mocks.markups[1].shape, 7)
  luaunit.assertFalse(veafCampaign.drawTerritory()) -- nothing changed
  luaunit.assertEquals(#dcs_mocks.markups, markups)
  veafCampaign.zones["Senaki"]:becomeNeutral()
  luaunit.assertTrue(#dcs_mocks.markups > markups)
  luaunit.assertTrue(#dcs_mocks.marksRemoved >= markups) -- the former tint taken away
end

function TestCampaignTerritory:test_the_hatches_run_along_the_front_into_their_own_cell()
  start()
  -- a front 10 km long along z, between a site west of it and one east of it
  local from, to = { x = 0, z = 0 }, { x = 0, z = 10000 }
  local west = veafCampaign.frontHatches(from, to, { x = -5000, z = 5000 })
  luaunit.assertEquals(#west, 3) -- every 3000 m from 1500 m on
  for _, stroke in ipairs(west) do
    luaunit.assertEquals(stroke.from.x, 0) -- on the front
    luaunit.assertTrue(stroke.to.x < 0) -- into the western cell
    -- slanted at 45 degrees, hatch_length long
    luaunit.assertAlmostEquals(math.abs(stroke.to.x - stroke.from.x), math.abs(stroke.to.z - stroke.from.z), 0.001)
    luaunit.assertAlmostEquals(math.sqrt((stroke.to.x - stroke.from.x) ^ 2 + (stroke.to.z - stroke.from.z) ^ 2), 2500, 0.001)
  end
  luaunit.assertTrue(veafCampaign.frontHatches(from, to, { x = 5000, z = 5000 })[1].to.x > 0)
end

function TestCampaignTerritory:test_the_hatches_are_drawn_with_the_tint()
  start({ territory = { hatch_spacing = 1000 } })
  local fine = #veafCampaign.territoryMarks
  start({ territory = { hatch_spacing = 100000 } })
  luaunit.assertTrue(fine > #veafCampaign.territoryMarks + 20)
end

function TestCampaignTerritory:test_off_nothing_is_drawn()
  start({ territory = { enabled = false } })
  luaunit.assertEquals(#dcs_mocks.markups, 0)
end

-- ---------------------------------------------------------------------------
-- The players' markers in a persistent campaign (David, 2026-11-16)
-- ---------------------------------------------------------------------------
TestCampaignMarkerPolicy = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignMarkerPolicy:test_cheats_are_for_admins_cas_is_off_the_rest_untouched()
  local expected = {
    ["-shell"] = "ADMIN",
    ["-cesar, radius 50"] = "ADMIN",
    ["-flak"] = "ADMIN",
    ["-destroy"] = "ADMIN",
    ["-tanker"] = "ADMIN",
    ["-tankerhere Texaco"] = "ADMIN",
    ["-zonestart, name x"] = "ADMIN",
    ["-airstop"] = "ADMIN",
    ["-send hello"] = "ADMIN",
    ["-light"] = "ADMIN",
    ["_spawn bomb, power 500"] = "ADMIN",
    ["_SPAWN FLARE"] = "ADMIN",
    ["_destroy, radius 100"] = "ADMIN",
    ["_teleport, name x"] = "ADMIN",
    ["_move tanker, teleport, name x"] = "ADMIN",
    ["_radio transmit, message x"] = "ADMIN",
    ["-cas"] = "disabled",
    ["-cas!30"] = "disabled",
    ["_cas, disperse"] = "disabled",
    -- a command is found anywhere in the text, as its module finds it (review of #1282)
    ["_x _spawn bomb"] = "ADMIN",
    ["radius 50, _spawn bomb"] = "ADMIN",
    ["_x _destroy"] = "ADMIN",
    ["_x _move tanker, teleport"] = "ADMIN",
    ["_x _cas"] = "disabled",
  }
  for text, policy in pairs(expected) do
    luaunit.assertEquals(veafCampaignLogistics.markerPolicy(text), policy, text)
  end
  for _, text in ipairs({
    "-smoke",
    "-signal",
    "-tankerlow",
    "-tankerhigh",
    "-armor, side blue",
    "_spawn group, name x",
    "_move tanker, alt 6000",
    "RDV ici",
    "-point here",
  }) do
    luaunit.assertNil(veafCampaignLogistics.markerPolicy(text), text)
  end
end

function TestCampaignMarkerPolicy:test_the_campaign_sets_it()
  veafCommands = { SECURITY_CHECKS = {} }
  start()
  luaunit.assertEquals(veafCommands.markerPolicy, veafCampaignLogistics.markerPolicy)
  veafCommands = nil
end

-- ---------------------------------------------------------------------------
-- The testing period's log (dynamic.debug, David 2026-11-16)
-- ---------------------------------------------------------------------------
TestCampaignDebugLog = { setUp = setUpSuite, tearDown = tearDownSuite }

local function logged(text)
  local found = {}
  for _, entry in ipairs(dcs_mocks.logs) do
    if string.find(entry.text, text, 1, true) then
      table.insert(found, entry.text)
    end
  end
  return found
end

function TestCampaignDebugLog:test_on_by_default_a_decision_and_its_reason_are_told()
  start()
  veafCampaignLogistics.stocks.red = 10
  veafCampaignOps.maintainCaps("red")
  luaunit.assertEquals(#logged("[CAMPAIGN DECISION] red does not send a CAP: costs 60, stock 10"), 1)
end

function TestCampaignDebugLog:test_an_unpaid_sortie_is_told_once_until_it_is_paid()
  -- 2026-11-16: the unpaid CAP, three lines every 10 s, 50 times in 9 minutes
  start()
  veafCampaignLogistics.stocks.red = 10
  for _ = 1, 5 do
    veafCampaignOps.maintainCaps("red")
    veafCampaignLogistics.stocks.red = veafCampaignLogistics.stocks.red + 1
  end
  luaunit.assertEquals(#logged("red does not send a CAP"), 1)
  luaunit.assertEquals(#logged("red cannot pay a CAP"), 1)
  luaunit.assertEquals(#logged("red CAP over"), 1)
  veafCampaignLogistics.stocks.red = 1000
  veafCampaignOps.maintainCaps("red")
  luaunit.assertEquals(#logged("red sends a CAP"), 1)
end

function TestCampaignDebugLog:test_a_wreck_crushing_the_scenery_is_no_kill()
  start({ bombers = { min_distance = 50000 } })
  local raid = veafCampaignOps.sendRaid("red", veafCampaign.zones["Poti"])
  veafCampaignOps.onFlightEvent({
    type = { id = world.event.S_EVENT_KILL },
    initiator = { unitName = raid.name .. " #1" },
    target = { unitName = "509796368" },
  })
  luaunit.assertEquals(#logged("kills 509796368"), 0)
end

function TestCampaignDebugLog:test_a_lost_aircraft_and_a_landing_in_the_open_say_no_nil()
  -- 2026-11-16: "red cas Aleppo #1 (nil) is lost", "lands at nil"
  start({ bombers = { min_distance = 50000 } })
  local raid = veafCampaignOps.sendRaid("red", veafCampaign.zones["Poti"])
  veafCampaignOps.onFlightEvent({ type = { id = world.event.S_EVENT_CRASH }, initiator = { unitName = raid.name .. " #1" } })
  luaunit.assertEquals(#logged(raid.name .. " #1 (Tu-22M3) is lost"), 1)
  veafCampaignOps.onFlightEvent({
    type = { id = world.event.S_EVENT_LAND },
    initiator = { unitName = raid.name .. " #1" },
    dcsInitiator = unitAt({ x = 51000, z = 0 }, { type = "Tu-22M3" }),
  })
  luaunit.assertEquals(#logged("(nil)"), 0)
  luaunit.assertEquals(#logged("lands at nil"), 0)
  luaunit.assertEquals(#logged("lands in the open, 1 km from [Poti]"), 1)
end

function TestCampaignDebugLog:test_off_nothing_is_told()
  start({ debug = false })
  veafCampaignLogistics.stocks.red = 10
  veafCampaignOps.maintainCaps("red")
  luaunit.assertEquals(#logged("[CAMPAIGN"), 0)
end

function TestCampaignDebugLog:test_a_status_every_period()
  start({ debug_status_seconds = 300 })
  veafCampaignLogistics.beat(10)
  veafCampaignLogistics.beat(20)
  veafCampaignLogistics.beat(310)
  local status = logged("[CAMPAIGN STATUS]")
  luaunit.assertEquals(#status, 2)
  luaunit.assertStrContains(status[1], "red: 3 zones, stock 1000 (+240/h)")
  luaunit.assertStrContains(status[1], "players' credits 500")
end

function TestCampaignDebugLog:test_a_campaign_aircraft_releasing_a_weapon_is_told_with_its_distance_to_its_aim()
  start({ bombers = { min_distance = 50000 } })
  local raid = veafCampaignOps.sendRaid("red", veafCampaign.zones["Poti"])
  local shooter = unitAt({ x = 52000, z = 0 }, { type = "Tu-22M3" })
  veafCampaignOps.onFlightEvent({
    type = { id = world.event.S_EVENT_SHOT },
    initiator = { unitName = raid.name .. " #1", unitType = "Tu-22M3" },
    dcsInitiator = shooter,
    weaponName = "FAB-250",
  })
  luaunit.assertEquals(#logged("releases FAB-250, 2000 m from its aim"), 1)
end

function TestCampaignDebugLog:test_a_campaign_aircraft_shot_down_is_told_with_its_killer()
  start({ bombers = { min_distance = 50000 } })
  local raid = veafCampaignOps.sendRaid("red", veafCampaign.zones["Poti"])
  veafCampaignOps.onFlightEvent({
    type = { id = world.event.S_EVENT_KILL },
    initiator = { unitName = "Viper #1", unitType = "F-16C_50" },
    target = { unitName = raid.name .. " #1", unitType = "Tu-22M3" },
  })
  luaunit.assertEquals(#logged("Viper #1 (F-16C_50) kills " .. raid.name .. " #1 (Tu-22M3)"), 1)
end

-- ---------------------------------------------------------------------------
-- The enemy's CAP stays out of the players' air defence (David, 2026-11-16)
-- ---------------------------------------------------------------------------
TestCampaignCapReach = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignCapReach:test_the_cap_stops_short_of_the_enemy_air_defence()
  start()
  -- Senaki is 50 km from Poti, whose garrison is assumed to reach 20 km: 50 - 20 - 15 = 15 km
  local radius, limit = veafCampaignOps.capRadius("red", veafCampaign.zones["Senaki"])
  luaunit.assertEquals({ radius, limit }, { 15000, "Poti" })
end

function TestCampaignCapReach:test_never_below_its_floor()
  start(nil, function(d)
    d.zones[2].x = 90000 -- Poti 10 km from Senaki
  end)
  luaunit.assertEquals(veafCampaignOps.capRadius("red", veafCampaign.zones["Senaki"]), veafCampaignOps.CAP_MIN_RADIUS)
end

function TestCampaignCapReach:test_far_from_any_defence_it_keeps_its_full_reach()
  start(nil, function(d)
    d.zones[1].owner, d.zones[1].garrison = "neutral", nil
    d.zones[2].owner, d.zones[2].garrison = "neutral", nil
  end)
  luaunit.assertEquals(veafCampaignOps.capRadius("red", veafCampaign.zones["Senaki"]), veafCampaignOps.CAP_RADIUS)
end

-- ---------------------------------------------------------------------------
-- AWACS and tankers: the campaign feeds the SUPPORT module (ticket 20, point 14)
-- ---------------------------------------------------------------------------
TestCampaignSupport = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignSupport:test_the_threats_are_the_enemy_zones_at_their_reach_asleep_or_awake()
  start()
  veafCampaign.zones["Senaki"].entry.reach = 120000
  local threats = {}
  for _, threat in ipairs(veafCampaignOps.supportThreats(coalition.side.BLUE)) do
    threats[threat.name] = threat.reach
  end
  luaunit.assertEquals(threats["Senaki"], 120000)
  luaunit.assertNil(threats["Poti"], "a zone of ours is no threat")
end

function TestCampaignSupport:test_the_front_is_our_zone_nearest_the_threat()
  start()
  -- Poti (ours) stands 50 km from Senaki
  luaunit.assertEquals(veafCampaignOps.supportFront(coalition.side.BLUE, nil, { center = { x = 100000, z = 0 } }), 50000)
end

function TestCampaignSupport:test_the_campaign_hands_its_hooks_to_the_module()
  veafSupport = {}
  start()
  luaunit.assertEquals(veafSupport.threatSource, veafCampaignOps.supportThreats)
  luaunit.assertEquals(veafSupport.frontLimit, veafCampaignOps.supportFront)
  veafSupport.tell(coalition.side.BLUE, "Magic moves")
  luaunit.assertEquals(#messagesContaining(veaf.t("campaign.speaker.blue") .. "Magic moves"), 1)
  veafSupport = nil
end

-- ---------------------------------------------------------------------------
-- Self-check
-- ---------------------------------------------------------------------------
TestCampaignV15SelfCheck = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignV15SelfCheck:test_every_mechanism_has_its_line()
  start()
  local text = veafCampaign.selfCheckText()
  luaunit.assertStrContains(text, "OK  factories: 1, buildings standing 3 of 3, 0 destroyed")
  luaunit.assertStrContains(text, "OK  territory: drawn 1 time(s)")
  luaunit.assertStrContains(text, "OK  resources: blue 1000 (+60/h), red 1000 (+240/h)")
  luaunit.assertStrContains(text, "OK  network: 0 delivery(ies) on the way")
  luaunit.assertStrContains(text, "OK  paid spawns: 0 charged, 0 refused")
  luaunit.assertStrContains(text, "OK  sappers: 0 team(s)")
  luaunit.assertStrContains(text, "OK  warehouses: 0 restored")
  luaunit.assertStrContains(text, "OK  bombers: 0 raid(s)")
end

-- ---------------------------------------------------------------------------
-- What the second raid in game showed (David, 2026-11-16)
-- ---------------------------------------------------------------------------
TestCampaignSecondRaid = {
  setUp = function(self)
    setUpSuite(self)
    self.unitByName = Unit.getByName
  end,
  tearDown = function(self)
    Unit.getByName = self.unitByName
    tearDownSuite(self)
  end,
}

--- A garrison unit of a zone, alive in DCS, carrying `missiles`.
local function airDefenceUnit(missiles)
  return {
    hasAttribute = function(_, attribute)
      return attribute == "Air Defence"
    end,
    getAmmo = function()
      return missiles > 0 and { { count = missiles, desc = { category = Weapon.Category.MISSILE } } } or nil
    end,
  }
end

function TestCampaignSecondRaid:test_the_missiles_left_in_each_zone_s_air_defence_are_logged()
  start()
  Unit.getByName = function(name)
    if name == "Kobuleti garrison #1" then
      return airDefenceUnit(3)
    elseif name == "Kobuleti garrison #2" then
      return airDefenceUnit(0)
    end
    return nil
  end
  veafCampaignOps.reportAirDefences()
  -- an empty launcher still counts: that is the point
  luaunit.assertEquals(#logged("[CAMPAIGN AIRDEF] [Kobuleti] blue: 3 missiles left on 2 air defence units (T-72B 3, BMP-2 0)"), 1)
  luaunit.assertEquals(#logged("[Poti]"), 0)
end

function TestCampaignSecondRaid:test_a_release_tells_what_the_aircraft_has_left()
  start()
  veafCampaignOps.flights = { { name = "red bomber Senaki", side = "red", role = "bomber", aim = { x = 0, z = 0 } } }
  veafCampaignOps.onFlightEvent({
    type = { id = world.event.S_EVENT_SHOT },
    initiator = { unitName = "red bomber Senaki #1", unitType = "Tu-22M3" },
    weaponName = "FAB_250",
    dcsInitiator = {
      getPoint = function()
        return { x = 7000, y = 7000, z = 0 }
      end,
      getAmmo = function()
        return { { count = 31, desc = { category = Weapon.Category.BOMB } } }
      end,
    },
  })
  -- the count also keeps DCS from folding two identical lines into one
  -- and where it fires from (2026-11-16: 33 releases logged 50 km from the aim where David saw them on the target)
  luaunit.assertEquals(#logged("releases FAB_250, 7000 m from its aim, near [Kobuleti] 7 km, 31 left"), 1)
end

function TestCampaignSecondRaid:test_a_flight_just_spawned_is_not_lost_while_dcs_has_not_registered_it()
  start()
  dcs_mocks.currentTime = 1000
  table.insert(veafCampaignOps.flights, { name = "red cap Senaki", side = "red", role = "cap", spawnedAt = 1000 })
  dcs_mocks.currentTime = 1030
  luaunit.assertEquals(veafCampaignOps.flightsUp("red", "cap"), 1)
  dcs_mocks.currentTime = 1000 + veafCampaignOps.FLIGHT_GRACE + 1
  luaunit.assertEquals(veafCampaignOps.flightsUp("red", "cap"), 0)
end

function TestCampaignSecondRaid:test_a_flight_never_takes_the_name_of_one_dcs_has_not_registered_yet()
  start()
  veafAircraftSpawn.spawnAirplaneGroup = function(groupData)
    table.insert(self.flights, { group = groupData })
    return groupData.name -- DCS does not answer it by name yet
  end
  local first =
    veafCampaignOps.spawnFlight("red", "cap", veafCampaign.zones["Senaki"], "zone_defense", { zone = { x = 0, y = 0, radius = 1 } }, 6000)
  local second =
    veafCampaignOps.spawnFlight("red", "cap", veafCampaign.zones["Senaki"], "zone_defense", { zone = { x = 0, y = 0, radius = 1 } }, 6000)
  luaunit.assertNotEquals(first, second)
end

function TestCampaignSecondRaid:test_no_cap_where_even_its_smallest_circle_is_under_the_enemy_sams()
  start(nil, function(d)
    d.zones[2].x = 90000 -- Poti 10 km from Senaki
  end)
  veafCampaignLogistics.stocks.red = 1000
  veafCampaignOps.maintainCaps("red")
  luaunit.assertEquals(#self.flights, 0)
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), 1000)
  luaunit.assertEquals(
    #logged(
      "red sends no CAP: even 5 km over every front zone is under the enemy's air defence, or has no airfield (first: [Senaki], under [Poti])"
    ),
    1
  )
end

os.exit(luaunit.LuaUnit.run())
