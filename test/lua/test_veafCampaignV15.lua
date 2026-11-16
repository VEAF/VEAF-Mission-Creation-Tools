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
  luaunit.assertEquals(veafCampaign.unitPrice("ZSU-23-4 Shilka"), 4)
  luaunit.assertEquals(veafCampaign.unitPrice("Strela-10M3"), 8)
  luaunit.assertEquals(veafCampaign.unitPrice("SA-11 Buk LN 9A310M1"), 15)
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
  luaunit.assertEquals(veafCampaignLogistics.productionPerHour("blue"), 30)
  luaunit.assertEquals(veafCampaignLogistics.productionPerHour("red"), 150)
  veafCampaign.zones["Tkvarcheli"].entry.structures[1].alive = false
  luaunit.assertEquals(veafCampaignLogistics.productionPerHour("red"), 110)
  local before = veafCampaignLogistics.stock("red")
  veafCampaignLogistics.produce(1800)
  luaunit.assertAlmostEquals(veafCampaignLogistics.stock("red") - before, 55, 0.001)
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

function TestCampaignNetwork:test_a_zone_cut_off_waits_the_isolated_delay()
  network()
  for _, structure in ipairs(veafCampaign.zones["Tkvarcheli"].entry.structures) do
    structure.alive = false
  end
  veafCampaign.zones["Senaki"].entry.garrison = garrison("Senaki", { 1 })
  veafCampaignLogistics.dispatchDeliveries(0)
  luaunit.assertEquals(veafCampaignLogistics.deliveries[1].at, 3600)
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
  luaunit.assertStrContains(text, "Resources: 500 points, making 30 an hour")
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

function TestCampaignPaidSpawns:test_a_blue_spawn_is_paid_in_credits()
  start()
  veafCampaignEconomy.credits = 500
  luaunit.assertTrue(veafCampaignLogistics.spawnGate("armoredPlatoon", { side = BLUE }, BLUE))
  veafCampaignLogistics.spawnPaid("armoredPlatoon", { side = BLUE }, "armor 1", BLUE)
  luaunit.assertEquals(veafCampaignEconomy.credits, 350)
  luaunit.assertEquals(veafCampaignLogistics.counters.spawnsCharged, 1)
end

function TestCampaignPaidSpawns:test_short_of_credits_it_is_refused_with_the_price_and_the_balance()
  start()
  veafCampaignEconomy.credits = 100
  luaunit.assertFalse(veafCampaignLogistics.spawnGate("cap", { side = BLUE }, BLUE))
  luaunit.assertEquals(veafCampaignEconomy.credits, 100)
  luaunit.assertEquals(#messagesContaining("cap refused: it costs 400 credits and the coalition has 100"), 1)
end

function TestCampaignPaidSpawns:test_a_red_spawn_is_paid_from_red_resources()
  start()
  veafCampaignLogistics.stocks.red = 200
  luaunit.assertTrue(veafCampaignLogistics.spawnGate("armoredPlatoon", { side = RED }, BLUE))
  veafCampaignLogistics.spawnPaid("armoredPlatoon", { side = RED }, "armor 2", BLUE)
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), 50)
  luaunit.assertFalse(veafCampaignLogistics.spawnGate("armoredPlatoon", { side = RED }, BLUE))
  luaunit.assertEquals(#messagesContaining("armoredPlatoon refused: red pays it 150 resource points and has 50"), 1)
end

function TestCampaignPaidSpawns:test_a_command_with_no_price_is_free()
  start({ economy = { spawn_prices = { cargo = 0 } } })
  veafCampaignEconomy.credits = 0
  luaunit.assertTrue(veafCampaignLogistics.spawnGate("smoke", { side = BLUE }, BLUE))
  luaunit.assertTrue(veafCampaignLogistics.spawnGate("cargo", { side = BLUE }, BLUE))
end

function TestCampaignPaidSpawns:test_what_a_paid_spawn_left_standing_comes_home_at_the_next_load()
  memoryFileSystem(self)
  start()
  veafCampaignEconomy.credits = 1000
  veafCampaignLogistics.spawnPaid("armoredPlatoon", { side = BLUE }, "armor 3", BLUE)
  dcs_mocks.addGroup("armor 3", {
    getUnits = function()
      return { unitAt({ x = 0 }, { type = "T-72B" }), unitAt({ x = 10 }, { type = "BMP-2" }) }
    end,
  })
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
  luaunit.assertEquals(veafCampaignEconomy.credits, credits + 50)
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
  veafCampaignLogistics.loadWeapons({ nil, "Huey" })
  luaunit.assertEquals(self.stocks["Kobuleti"]["weapons.missiles.AIM_9"], 20)
  luaunit.assertEquals(self.stocks["Kobuleti"]["weapons.bombs.Mk_82"], 0)
  luaunit.assertEquals(veafCampaignLogistics.cargo["Huey"].total, 14)
  -- not at the airfield it loaded at
  veafCampaignLogistics.unloadWeapons({ nil, "Huey" })
  luaunit.assertNotNil(veafCampaignLogistics.cargo["Huey"])
  pilot("Huey", { x = 50000 }, { category = Unit.Category.HELICOPTER })
  local credits = veafCampaignEconomy.credits
  veafCampaignLogistics.unloadWeapons({ nil, "Huey" })
  luaunit.assertEquals(self.stocks["Poti"]["weapons.missiles.AIM_9"], 10)
  luaunit.assertEquals(self.stocks["Poti"]["weapons.bombs.Mk_82"], 4)
  luaunit.assertNil(veafCampaignLogistics.cargo["Huey"])
  luaunit.assertEquals(veafCampaignEconomy.credits, credits + 50)
end

function TestCampaignWarehouse:test_a_fighter_or_an_aircraft_in_flight_carries_nothing()
  start()
  warehouses(self)
  pilot("Viper", { x = 100 }, { category = Unit.Category.AIRPLANE })
  veafCampaignLogistics.loadWeapons({ nil, "Viper" })
  luaunit.assertNil(veafCampaignLogistics.cargo["Viper"])
  pilot("Huey", { x = 100 }, { category = Unit.Category.HELICOPTER, inAir = true })
  veafCampaignLogistics.loadWeapons({ nil, "Huey" })
  luaunit.assertNil(veafCampaignLogistics.cargo["Huey"])
  pilot("Herc", { x = 100 }, { category = Unit.Category.AIRPLANE, attributes = { Transports = true } })
  veafCampaignLogistics.loadWeapons({ nil, "Herc" })
  luaunit.assertNotNil(veafCampaignLogistics.cargo["Herc"])
end

function TestCampaignWarehouse:test_the_cargo_is_lost_with_the_aircraft()
  start()
  warehouses(self)
  pilot("Huey", { x = 100 }, { category = Unit.Category.HELICOPTER })
  veafCampaignLogistics.loadWeapons({ nil, "Huey" })
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
  start({}, function(d)
    d.zones[2].kind = "factory"
  end)
  luaunit.assertEquals(veafCampaignOps.raidTarget("red").name, "Poti")
  luaunit.assertEquals(veafCampaignOps.raidTarget("blue").name, "Tkvarcheli")
end

function TestCampaignBombers:test_it_leaves_from_the_nearest_airfield_far_enough()
  start()
  luaunit.assertEquals(veafCampaignOps.raidOrigin("red", veafCampaign.zones["Poti"]), nil) -- Senaki is 50 km away
  luaunit.assertEquals(veafCampaignOps.raidOrigin("red", veafCampaign.zones["Kobuleti"]).name, "Senaki")
end

function TestCampaignBombers:test_the_red_raid_is_escorted_paid_announced_and_posted_on_the_board()
  start({ bombers = { seconds = 60, min_distance = 50000 } })
  veafCampaignLogistics.stocks.red = 1000
  veafCampaignOps.launchRaids("red", 0)
  veafCampaignOps.launchRaids("red", 60)
  luaunit.assertEquals(#self.flights, 2)
  luaunit.assertEquals(self.flights[1].role, "campaign_bomber")
  luaunit.assertEquals(self.flights[1].group.units[1].type, "Tu-22M3")
  luaunit.assertEquals(self.flights[2].role, "campaign_escort")
  luaunit.assertEquals(veafCampaignLogistics.stock("red"), 1000 - 100 - 60)
  -- Kobuleti and Poti hold as many units; Kobuleti, declared first, is the target, Senaki 100 km off the origin
  luaunit.assertEquals(#messagesContaining("escorted enemy bombers are heading for Kobuleti, from Senaki"), 1)
  veafCampaignEconomy.refreshTasks()
  luaunit.assertEquals(veafCampaignEconomy.tasks[1].kind, "intercept")
  -- one out at a time
  veafCampaignOps.launchRaids("red", 120)
  luaunit.assertEquals(#self.flights, 2)
end

function TestCampaignBombers:test_shot_down_the_intercept_task_pays()
  start({ bombers = { min_distance = 50000 } })
  local raid = veafCampaignOps.sendRaid("red", veafCampaign.zones["Poti"])
  veafCampaignEconomy.refreshTasks()
  local credits = veafCampaignEconomy.credits
  dcs_mocks.clearUnitsAndGroups() -- the bomber is gone
  veafCampaignOps.followRaid(raid, 100)
  luaunit.assertEquals(raid.outcome, "destroyed")
  veafCampaignEconomy.checkTasks()
  luaunit.assertEquals(veafCampaignEconomy.credits, credits + 400)
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
  luaunit.assertEquals(veafCampaignEconomy.credits, 800)
  luaunit.assertEquals(veafCampaignLogistics.stock("blue"), stock)
  luaunit.assertEquals(self.flights[1].params.target.x, 150000)
end

function TestCampaignBombers:test_the_bomber_route_bombs_then_lands_at_home()
  start()
  local route = veafAircraftSpawn.roles.campaign_bomber.buildRoute({
    spot = { x = 1, y = 7000, z = 2 },
    params = { target = { x = 100, z = 200 }, airdromeId = 5, home = { x = 1, z = 2 } },
  })
  luaunit.assertEquals(route[1].task.params.tasks[2].id, "Bombing")
  luaunit.assertEquals(route[1].task.params.tasks[2].params.point, { x = 100, y = 200 })
  luaunit.assertEquals(route[3].type, "Land")
  luaunit.assertEquals(route[3].airdromeId, 5)
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

function TestCampaignTerritory:test_off_nothing_is_drawn()
  start({ territory = { enabled = false } })
  luaunit.assertEquals(#dcs_mocks.markups, 0)
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
  luaunit.assertStrContains(text, "OK  resources: blue 500 (+30/h), red 500 (+150/h)")
  luaunit.assertStrContains(text, "OK  network: 0 delivery(ies) on the way")
  luaunit.assertStrContains(text, "OK  paid spawns: 0 charged, 0 refused")
  luaunit.assertStrContains(text, "OK  sappers: 0 team(s)")
  luaunit.assertStrContains(text, "OK  warehouses: 0 restored")
  luaunit.assertStrContains(text, "OK  bombers: 0 raid(s)")
end

os.exit(luaunit.LuaUnit.run())
