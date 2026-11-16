--- Tests for the persistent campaign's live play (FEAT-DYNAMIC-CAMPAIGN tickets 04 to 08): veafCampaignOps
--- (supply helicopters, enemy air, Hunter) and veafCampaignEconomy (credits, shop, tasks, intelligence).
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
-- the aircraft roles the sorties use are veafAircraftSpawn's; the module registers its own into the table
veafAircraftSpawn = { roles = {} }
dofile(src .. "/veafCampaign.lua")
dofile(src .. "/veafCampaignOps.lua")
dofile(src .. "/veafCampaignEconomy.lua")

local BLUE, RED = coalition.side.BLUE, coalition.side.RED

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function garrison(name, dead, types)
  types = types or { "T-72B", "BMP-2", "Ural-375" }
  local units = {}
  for index, typeName in ipairs(types) do
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

local AIRCRAFT = { type = "MiG-29A", count = 2, payload = { fuel = 3376, pylons = { [1] = { CLSID = "x" } } } }

--- Kobuleti (blue airfield) — Poti (neutral) — Senaki (red airfield) — Zugdidi (red).
local function data(dynamic)
  return {
    format_version = 1,
    campaign = "Live",
    mission = 1,
    persistent = true,
    player_side = "blue",
    dynamic = dynamic or {
      air = {
        red = { cap = AIRCRAFT, cas = AIRCRAFT, sead = AIRCRAFT },
        blue = { cap = AIRCRAFT },
      },
    },
    zones = {
      zone("Kobuleti", "blue", 0, { airbase = "Kobuleti" }),
      zone("Poti", "neutral", 50000),
      zone("Senaki", "red", 100000, { airbase = "Senaki-Kolkhi" }),
      zone("Zugdidi", "red", 150000),
    },
    connections = { { "Kobuleti", "Poti" }, { "Poti", "Senaki" }, { "Senaki", "Zugdidi" } },
    sides = {},
  }
end

--- A unit as Group:getUnits and coalition.getPlayers hand it over.
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
    getPlayerName = function()
      return options.player
    end,
    getCoalition = function()
      return options.side or BLUE
    end,
    getDesc = function()
      return { category = options.category or Unit.Category.GROUND_UNIT }
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
    spawnHelicopterGroup = veafAircraftSpawn.spawnHelicopterGroup,
    spawnAirplaneGroup = veafAircraftSpawn.spawnAirplaneGroup,
    language = veaf.config.language,
    airbase = Airbase.getByName,
    opposition = veafOpposition,
    spawn = veafSpawn,
    troopManager = CTLDTroopManager,
    surface = land.getSurfaceType,
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
  veafOpposition = nil
  self.helicopters, self.flights = {}, {}
  local this = self
  veafAircraftSpawn.spawnHelicopterGroup = function(groupData, job)
    table.insert(this.helicopters, { group = groupData, job = job })
    return groupData.name
  end
  veafAircraftSpawn.spawnAirplaneGroup = function(groupData, role, params)
    table.insert(this.flights, { group = groupData, role = role, params = params })
    dcs_mocks.addGroup(groupData.name, {
      getUnits = function()
        return { unitAt({ x = 0 }, { inAir = true }) }
      end,
    })
    return groupData.name
  end
  veafCampaign.listeners = {}
  veafCampaign.saveParts = {}
end

local function tearDownSuite(self)
  for key, value in pairs({
    fileSystem = veafCampaign,
    callbacks = veafEventHandler,
    spawnHelicopterGroup = veafAircraftSpawn,
    spawnAirplaneGroup = veafAircraftSpawn,
  }) do
    value[key] = self.saved[key]
  end
  coalition.getPlayers = self.saved.getPlayers
  veaf.config.language = self.saved.language
  Airbase.getByName = self.saved.airbase
  veafOpposition = self.saved.opposition
  veafSpawn = self.saved.spawn
  CTLDTroopManager = self.saved.troopManager
  land.getSurfaceType = self.saved.surface
  veafCampaign.data = nil
  veafCampaign.listeners = {}
  veafCampaign.saveParts = {}
end

local function start(dynamic)
  veafCampaign.data = data(dynamic)
  veafCampaign.initialize()
end

-- ---------------------------------------------------------------------------
-- Supply helicopters
-- ---------------------------------------------------------------------------
TestCampaignHelicopters = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignHelicopters:test_a_neutral_zone_bordered_comes_first()
  start()
  local target, kind = veafCampaignOps.supplyTarget("red")
  luaunit.assertEquals({ target.name, kind }, { "Poti", "capture" })
end

function TestCampaignHelicopters:test_then_the_most_damaged_zone()
  start()
  veafCampaign.zones["Poti"].entry.owner = "blue"
  veafCampaign.zones["Zugdidi"].entry.garrison = garrison("Zugdidi", { 1, 2 })
  veafCampaign.zones["Senaki"].entry.garrison = garrison("Senaki", { 1 })
  local target, kind = veafCampaignOps.supplyTarget("red")
  luaunit.assertEquals({ target.name, kind }, { "Zugdidi", "resupply" })
end

function TestCampaignHelicopters:test_it_flies_the_transport_job_from_the_nearest_own_zone()
  start()
  local record = veafCampaignOps.sendHelicopter("red", veafCampaign.zones["Poti"], "capture")
  luaunit.assertEquals(record.from, "Senaki")
  local call = self.helicopters[1]
  luaunit.assertEquals(call.job, { task = "transport", destination = "CAMPAIGN SUPPLY Poti" })
  luaunit.assertEquals(call.group.units[1].type, "Mi-8MT")
  luaunit.assertNotNil(veafNamedPoints.getPoint("CAMPAIGN SUPPLY Poti"))
end

function TestCampaignHelicopters:test_no_more_helicopters_than_the_cap()
  start({ supply_seconds = 10, max_helicopters = 1, air = {} })
  veafCampaignOps.dispatchHelicopters(0)
  veafCampaignOps.dispatchHelicopters(10)
  veafCampaign.zones["Zugdidi"].entry.garrison = garrison("Zugdidi", { 1 })
  veafCampaignOps.dispatchHelicopters(20)
  luaunit.assertEquals(#self.helicopters, 1)
end

--- A helicopter group whose single unit stands at `point`.
local function flying(name, point, inAir)
  dcs_mocks.addGroup(name, {
    getUnits = function()
      return { unitAt(point, { inAir = inAir }) }
    end,
  })
end

function TestCampaignHelicopters:test_landed_in_a_neutral_zone_it_waits_for_the_capture_and_is_consumed()
  start()
  local record = veafCampaignOps.sendHelicopter("red", veafCampaign.zones["Poti"], "capture")
  flying(record.name, { x = 50030 }, false)
  veafCampaignOps.followHelicopter(record, 100)
  luaunit.assertNil(record.done)
  luaunit.assertEquals(record.landedAt, 100)
  veafCampaign.zones["Poti"].entry.owner = "red" -- the capture rule took it
  veafCampaignOps.followHelicopter(record, 200)
  luaunit.assertEquals(record.outcome, "captured")
end

function TestCampaignHelicopters:test_landed_in_a_damaged_friendly_zone_it_reinforces_it_then_leaves()
  start()
  veafCampaign.zones["Zugdidi"].entry.garrison = garrison("Zugdidi", { 1 })
  local record = veafCampaignOps.sendHelicopter("red", veafCampaign.zones["Zugdidi"], "resupply")
  flying(record.name, { x = 150010 }, false)
  veafCampaignOps.followHelicopter(record, 100)
  luaunit.assertEquals(veafCampaign.zones["Zugdidi"]:strengthPercent(), 100)
  veafCampaignOps.followHelicopter(record, 129)
  luaunit.assertNil(record.done)
  veafCampaignOps.followHelicopter(record, 130)
  luaunit.assertEquals(record.outcome, "delivered")
end

function TestCampaignHelicopters:test_still_flying_after_the_timeout_it_has_failed()
  start({ helicopter_timeout = 600, air = {} })
  local record = veafCampaignOps.sendHelicopter("red", veafCampaign.zones["Poti"], "capture")
  flying(record.name, { x = 70000 }, true)
  record.startedAt = 0
  veafCampaignOps.followHelicopter(record, 599)
  luaunit.assertNil(record.done)
  veafCampaignOps.followHelicopter(record, 600)
  luaunit.assertEquals(record.outcome, "failed")
end

function TestCampaignHelicopters:test_shot_down_it_is_counted_as_failed()
  start()
  local record = veafCampaignOps.sendHelicopter("red", veafCampaign.zones["Poti"], "capture")
  veafCampaignOps.followHelicopter(record, 100)
  luaunit.assertEquals(record.outcome, "destroyed")
  luaunit.assertEquals(veafCampaignOps.counters.helicoptersFailed, 1)
end

-- ---------------------------------------------------------------------------
-- Enemy air
-- ---------------------------------------------------------------------------
TestCampaignAir = { setUp = setUpSuite, tearDown = tearDownSuite }

local function opposition(level, noAircraft)
  veafOpposition = {
    getLevel = function()
      return level
    end,
    isNoAircraft = function()
      return noAircraft == true
    end,
  }
end

function TestCampaignAir:test_the_cap_count_follows_the_opposition_level()
  start()
  luaunit.assertEquals(veafCampaignOps.wantedCaps(), 1)
  opposition(2)
  luaunit.assertEquals(veafCampaignOps.wantedCaps(), 1)
  opposition(8)
  luaunit.assertEquals(veafCampaignOps.wantedCaps(), 3)
  opposition(20)
  luaunit.assertEquals(veafCampaignOps.wantedCaps(), 4)
  opposition(4, true)
  luaunit.assertEquals(veafCampaignOps.wantedCaps(), 0)
end

-- 2026-11-16, after Foothold: the CAP follows the players' fighters, spares helicopters and attack airplanes,
-- and does not stay grounded because its nearest zone is under the enemy's SAMs.
local function spared(attributes, id)
  return {
    hasAttribute = function(_, name)
      return attributes[name] == true
    end,
    getID = function()
      return id or 1
    end,
  }
end

function TestCampaignAir:test_no_cap_when_following_and_no_fighter_is_up()
  start()
  opposition(0)
  veafOpposition.follow, veafOpposition.FOLLOW_OFF = "air_to_air", "off"
  luaunit.assertEquals(veafCampaignOps.wantedCaps(), 0)
  opposition(4)
  veafOpposition.follow, veafOpposition.FOLLOW_OFF = "air_to_air", "off"
  luaunit.assertEquals(veafCampaignOps.wantedCaps(), 2)
end

function TestCampaignAir:test_a_persistent_campaign_follows_the_fighters_unless_the_mission_follows_already()
  start()
  local followed
  opposition(0)
  veafOpposition.follow, veafOpposition.FOLLOW_OFF, veafOpposition.FOLLOW_AIR_TO_AIR = "off", "off", "air_to_air"
  veafOpposition.setFollow = function(mode)
    followed = mode
  end
  veafCampaignOps.followFighters()
  luaunit.assertEquals(followed, "air_to_air")
  followed = nil
  veafOpposition.follow = "players"
  veafCampaignOps.followFighters()
  luaunit.assertNil(followed)
end

function TestCampaignAir:test_the_cap_spares_helicopters_and_attack_airplanes_but_on_a_draw()
  start({ air = { cap_helicopter_chance = 0 } })
  luaunit.assertTrue(veafCampaignOps.capEngages("cap", spared({ Fighters = true }, 1)))
  luaunit.assertFalse(veafCampaignOps.capEngages("cap", spared({ Helicopters = true }, 2)))
  luaunit.assertFalse(veafCampaignOps.capEngages("cap", spared({ Battleplanes = true }, 3)))
  veafCampaign.data.dynamic.air.cap_helicopter_chance = 100
  luaunit.assertFalse(veafCampaignOps.capEngages("cap", spared({ Helicopters = true }, 2))) -- drawn once
  luaunit.assertTrue(veafCampaignOps.capEngages("cap", spared({ Helicopters = true }, 4)))
end

function TestCampaignAir:test_the_cap_takes_the_next_front_zone_when_the_nearest_is_under_the_sams()
  start()
  local first, second = veafCampaign.zones["Senaki"], veafCampaign.zones["Zugdidi"]
  second.entry.airbase = nil
  local capZones, capRadius = veafCampaignOps.capZones, veafCampaignOps.capRadius
  veafCampaignOps.capZones = function()
    return { first, second }
  end
  veafCampaignOps.capRadius = function(_, zone)
    if zone == first then
      return veafCampaignOps.CAP_MIN_RADIUS, "Kobuleti", true
    end
    return 30000, nil, false
  end
  veafCampaignOps.maintainCaps("red")
  veafCampaignOps.capZones, veafCampaignOps.capRadius = capZones, capRadius
  luaunit.assertEquals(#self.flights, 1)
  luaunit.assertEquals(self.flights[1].params.zone.x, second:getCenter().x)
end

function TestCampaignAir:test_a_cap_refused_everywhere_is_logged_once()
  start()
  local lines = 0
  local debug = veafCampaign.debug
  veafCampaign.debug = function()
    lines = lines + 1
  end
  local capRadius = veafCampaignOps.capRadius
  veafCampaignOps.capRadius = function()
    return veafCampaignOps.CAP_MIN_RADIUS, "Kobuleti", true
  end
  veafCampaignOps.maintainCaps("red")
  veafCampaignOps.maintainCaps("red")
  veafCampaignOps.capRadius, veafCampaign.debug = capRadius, debug
  luaunit.assertEquals(#self.flights, 0)
  luaunit.assertEquals(lines, 1)
end

function TestCampaignAir:test_a_cap_covers_the_front_with_the_zone_defense_role()
  start()
  veafCampaignOps.maintainCaps("red")
  luaunit.assertEquals(#self.flights, 1)
  local flight = self.flights[1]
  luaunit.assertEquals(flight.role, "zone_defense")
  luaunit.assertEquals(flight.params.zone.x, 100000) -- Senaki, red's only front zone
  luaunit.assertEquals(#flight.group.units, 2)
  veafCampaignOps.maintainCaps("red")
  luaunit.assertEquals(#self.flights, 1) -- one wanted, one up
end

function TestCampaignAir:test_cas_strikes_the_enemy_zone_with_most_units_sead_the_most_air_defence()
  start()
  veafCampaign.zones["Poti"].entry.owner = "blue"
  veafCampaign.zones["Poti"].entry.garrison = garrison("Poti", nil, { "T-72B", "T-72B", "T-72B", "T-72B" })
  veafCampaign.zones["Kobuleti"].entry.garrison = garrison("Kobuleti", nil, { "T-72B", "Avenger" })
  local savedCategory = veafCampaign.reserveCategory
  veafCampaign.reserveCategory = function(typeName)
    return typeName == "Avenger" and "air_defense" or "armor"
  end
  -- Kobuleti does not border red; Poti does
  luaunit.assertEquals(veafCampaignOps.strikeTarget("red", "cas").name, "Poti")
  luaunit.assertNil(veafCampaignOps.strikeTarget("red", "sead"))
  veafCampaign.connections = nil
  veafCampaign.data.connections = { { "Kobuleti", "Senaki" }, { "Poti", "Senaki" } }
  luaunit.assertEquals(veafCampaignOps.strikeTarget("red", "sead").name, "Kobuleti")
  veafCampaign.reserveCategory = savedCategory
end

function TestCampaignAir:test_a_strike_engages_orbits_and_lands_home()
  local route, state = veafAircraftSpawn.roles.campaign_strike.buildRoute({
    spot = { x = 0, y = 2500, z = 0 },
    params = {
      target = { x = 5000, y = 0, z = 6000 },
      radius = 2000,
      targetTypes = { "Air Defence" },
      airdromeId = 23,
      home = { x = 10, y = 0, z = 20 },
      task = "SEAD",
    },
  })
  luaunit.assertEquals(#route, 3)
  local engage = route[1].task.params.tasks[2]
  luaunit.assertEquals(engage.id, "EngageTargetsInZone")
  luaunit.assertEquals(engage.params.point, { x = 5000, y = 6000 })
  luaunit.assertEquals(engage.params.targetTypes, { "Air Defence" })
  luaunit.assertEquals(route[2].task.params.tasks[1].params.stopCondition.duration, 600)
  luaunit.assertEquals({ route[3].action, route[3].airdromeId }, { "Landing", 23 })
  luaunit.assertEquals(state.task, "SEAD")
end

function TestCampaignAir:test_strikes_come_on_their_cadence()
  start({ air = { strike_seconds = 900, red = { cas = AIRCRAFT, sead = AIRCRAFT, cap = AIRCRAFT } } })
  veafCampaign.zones["Poti"].entry.owner = "blue"
  veafCampaign.zones["Poti"].entry.garrison = garrison("Poti")
  veafCampaignOps.launchStrike("red", 0)
  veafCampaignOps.launchStrike("red", 899)
  luaunit.assertEquals(#self.flights, 0)
  veafCampaignOps.launchStrike("red", 900)
  luaunit.assertEquals(self.flights[1].role, "campaign_strike")
  luaunit.assertEquals(self.flights[1].params.airdromeId, 23)
end

function TestCampaignAir:test_no_airfield_no_sortie()
  local campaignData = data()
  campaignData.zones[3].airbase = nil
  veafCampaign.data = campaignData
  veafCampaign.initialize()
  veafCampaignOps.maintainCaps("red")
  luaunit.assertEquals(#self.flights, 0)
end

-- ---------------------------------------------------------------------------
-- Hunter
-- ---------------------------------------------------------------------------
TestCampaignHunter = { setUp = setUpSuite, tearDown = tearDownSuite }

--- A kill, in the shape veafEventHandler hands it over: `initiator` and `target` are data tables with no
--- methods, the killer's DCS object is `dcsInitiator`.
local function kill(player, category)
  return {
    initiator = { unitName = "Zip's Hog", unitCoalition = BLUE },
    dcsInitiator = unitAt({ x = 90000 }, { player = player, side = BLUE }),
    target = { unitName = "T-72", unitCoalition = RED, unitCategory = category or Unit.Category.GROUND_UNIT },
  }
end

function TestCampaignHunter:test_two_fighters_after_the_threshold_once_per_life()
  start()
  -- the mocks draw the lowest value: 8 ground kills needed, and the 10 % chance comes up
  for _ = 1, 7 do
    veafCampaignOps.onKill(kill("Zip"))
  end
  luaunit.assertEquals(#self.flights, 0)
  veafCampaignOps.onKill(kill("Zip"))
  luaunit.assertEquals(#self.flights, 1)
  luaunit.assertEquals(self.flights[1].role, "campaign_intercept")
  luaunit.assertEquals(self.flights[1].params.groupId, 77)
  luaunit.assertEquals(#dcs_mocks.messagesContaining("Zip"), 1)
  veafCampaignOps.onKill(kill("Zip"))
  luaunit.assertEquals(#self.flights, 1)
  veafCampaignOps.onBirth({ initiator = { unitName = "Zip's Hog" }, dcsInitiator = unitAt({ x = 0 }, { player = "Zip" }) })
  luaunit.assertNil(veafCampaignOps.hunted["Zip"])
end

function TestCampaignHunter:test_air_kills_count_on_their_own_threshold()
  start()
  for _ = 1, 4 do
    veafCampaignOps.onKill(kill("Zip", Unit.Category.AIRPLANE))
  end
  luaunit.assertEquals(#self.flights, 1)
end

function TestCampaignHunter:test_a_kill_read_from_the_data_table_alone_does_not_fail()
  start()
  -- the data table has no methods: reading getPlayerName on it would have failed silently in game
  veafCampaignOps.onKill({ initiator = { unitName = "x" }, target = { unitCoalition = RED } })
  luaunit.assertNil(next(veafCampaignOps.hunted))
end

function TestCampaignHunter:test_a_friendly_kill_does_not_count()
  start()
  local event = kill("Zip")
  event.target.unitCoalition = BLUE
  veafCampaignOps.onKill(event)
  luaunit.assertNil(next(veafCampaignOps.hunted))
end

function TestCampaignHunter:test_an_ai_kill_does_not_count()
  start()
  for _ = 1, 10 do
    veafCampaignOps.onKill(kill(nil))
  end
  luaunit.assertNil(next(veafCampaignOps.hunted))
end

-- ---------------------------------------------------------------------------
-- Credits and shop
-- ---------------------------------------------------------------------------
TestCampaignShop = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignShop:setUp()
  setUpSuite(self)
  self.effects = {}
  local this = self
  veafSpawn = {
    spawnIlluminationFlare = function(spot)
      table.insert(this.effects, { "illumination", spot.x })
    end,
    spawnSmoke = function(spot)
      table.insert(this.effects, { "smoke", spot.x })
    end,
  }
  start({ economy = { start_credits = 100 }, air = {} })
end

function TestCampaignShop:test_kills_captures_and_deliveries_earn_credits()
  veafCampaignEconomy.onKill(kill("Zip"))
  luaunit.assertEquals(veafCampaignEconomy.credits, 110)
  veafCampaignEconomy.onKill(kill("Zip", Unit.Category.AIRPLANE))
  luaunit.assertEquals(veafCampaignEconomy.credits, 140)
  veafCampaign.notify("captured", veafCampaign.zones["Poti"], "blue")
  luaunit.assertEquals(veafCampaignEconomy.credits, 340)
  veafCampaign.notify("delivered", veafCampaign.zones["Kobuleti"], "blue", "crate")
  luaunit.assertEquals(veafCampaignEconomy.credits, 440)
  -- the enemy's captures and an AI's kills earn nothing
  veafCampaign.notify("captured", veafCampaign.zones["Poti"], "red")
  veafCampaignEconomy.onKill(kill(nil))
  luaunit.assertEquals(veafCampaignEconomy.credits, 440)
end

function TestCampaignShop:test_credits_never_go_below_zero()
  veafCampaignEconomy.earn(-1000)
  luaunit.assertEquals(veafCampaignEconomy.credits, 0)
end

function TestCampaignShop:test_a_purchase_is_paid_and_takes_effect()
  luaunit.assertTrue(veafCampaignEconomy.buy({ "illumination", "Senaki" }))
  luaunit.assertEquals(self.effects, { { "illumination", 100000 } })
  luaunit.assertEquals(veafCampaignEconomy.credits, 50)
end

function TestCampaignShop:test_too_expensive_is_refused_and_free()
  luaunit.assertFalse(veafCampaignEconomy.buy({ "jtac", "Senaki" }))
  luaunit.assertEquals(veafCampaignEconomy.credits, 100)
  luaunit.assertEquals(#dcs_mocks.messagesContaining("costs 300"), 1)
end

function TestCampaignShop:test_a_zone_that_no_longer_suits_is_refused()
  luaunit.assertFalse(veafCampaignEconomy.buy({ "smoke", "Kobuleti" })) -- ours, smoke is for the enemy
  luaunit.assertEquals(veafCampaignEconomy.credits, 100)
end

function TestCampaignShop:test_an_effect_that_cannot_be_had_costs_nothing()
  veafCampaign.zones["Senaki"].entry.garrison = garrison("Senaki", { 1, 2, 3 })
  luaunit.assertFalse(veafCampaignEconomy.buy({ "smoke", "Senaki" }))
  luaunit.assertEquals(veafCampaignEconomy.credits, 100)
end

function TestCampaignShop:test_intel_reveals_the_zone()
  veafCampaignEconomy.earn(100) -- intel costs 150
  luaunit.assertTrue(veafCampaignEconomy.buy({ "intel", "Senaki" }))
  luaunit.assertTrue(veafCampaign.isRevealed(veafCampaign.zones["Senaki"]))
end

function TestCampaignShop:test_credits_survive_a_restart()
  veafCampaignEconomy.earn(250)
  local saved = veafCampaignEconomy.save()
  veafCampaignEconomy.credits = 0
  veafCampaignEconomy.load(saved)
  luaunit.assertEquals(veafCampaignEconomy.credits, 350)
end

-- ---------------------------------------------------------------------------
-- Task board
-- ---------------------------------------------------------------------------
TestCampaignTasks = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignTasks:test_the_board_is_drawn_from_the_situation()
  start({ air = {} })
  veafCampaign.zones["Kobuleti"].entry.garrison = garrison("Kobuleti", { 1 })
  veafCampaignEconomy.refreshTasks()
  local kinds = {}
  for _, task in ipairs(veafCampaignEconomy.tasks) do
    table.insert(kinds, task.kind .. ":" .. tostring(task.zone))
  end
  -- blue borders no enemy zone yet: capture Poti, resupply Kobuleti, air superiority
  luaunit.assertEquals(kinds, { "capture:Poti", "resupply:Kobuleti", "air:nil" })
end

function TestCampaignTasks:test_a_task_done_pays_and_frees_its_place()
  start({ air = {}, economy = { start_credits = 0 } })
  veafCampaignEconomy.refreshTasks()
  veafCampaign.zones["Poti"].entry.owner = "blue"
  veafCampaignEconomy.checkTasks()
  luaunit.assertEquals(veafCampaignEconomy.credits, 300)
  luaunit.assertEquals(#veafCampaignEconomy.tasks, 1) -- air superiority stays
  veafCampaignEconomy.refreshTasks()
  -- Poti is ours now: blue borders Senaki, and the attack comes up
  luaunit.assertEquals(veafCampaignEconomy.tasks[2].kind, "attack")
  luaunit.assertEquals(veafCampaignEconomy.tasks[2].zone, "Senaki")
end

function TestCampaignTasks:test_a_capture_lost_to_the_enemy_is_withdrawn_without_reward()
  start({ air = {}, economy = { start_credits = 0 } })
  veafCampaignEconomy.refreshTasks()
  veafCampaign.zones["Poti"].entry.owner = "red"
  veafCampaignEconomy.checkTasks()
  luaunit.assertEquals(veafCampaignEconomy.credits, 0)
  luaunit.assertEquals(#dcs_mocks.messagesContaining("Task withdrawn"), 1)
end

function TestCampaignTasks:test_air_superiority_counts_aircraft_shot_down()
  start({ air = {}, economy = { start_credits = 0 }, tasks = { air_kills = 2 } })
  veafCampaignEconomy.refreshTasks()
  veafCampaignEconomy.onKill(kill("Zip", Unit.Category.AIRPLANE))
  veafCampaignEconomy.checkTasks()
  luaunit.assertEquals(#veafCampaignEconomy.tasks, 2)
  veafCampaignEconomy.onKill(kill("Zip", Unit.Category.AIRPLANE))
  veafCampaignEconomy.checkTasks()
  luaunit.assertEquals(#veafCampaignEconomy.tasks, 1)
  luaunit.assertEquals(veafCampaignEconomy.credits, 60 + 200)
end

-- ---------------------------------------------------------------------------
-- Intelligence
-- ---------------------------------------------------------------------------
TestCampaignIntel = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignIntel:test_an_enemy_zone_is_hidden_from_the_players_only()
  start({ air = {} })
  local senaki = veafCampaign.zones["Senaki"]
  luaunit.assertEquals(senaki:labelFor("blue"), "Senaki — strength unknown")
  luaunit.assertEquals(senaki:labelFor("red"), "Senaki — 100%")
  luaunit.assertEquals(veafCampaign.zones["Kobuleti"]:labelFor("blue"), "Kobuleti — 100%")
end

function TestCampaignIntel:test_hiding_can_be_turned_off()
  start({ air = {}, intel = { hidden = false } })
  luaunit.assertEquals(veafCampaign.zones["Senaki"]:labelFor("blue"), "Senaki — 100%")
end

function TestCampaignIntel:test_a_reveal_lasts_its_time()
  start({ air = {} })
  local senaki = veafCampaign.zones["Senaki"]
  dcs_mocks.currentTime = 100
  veafCampaignEconomy.reveal(senaki, 600, "purchase")
  luaunit.assertEquals(senaki:labelFor("blue"), "Senaki — 100%")
  dcs_mocks.currentTime = 701
  luaunit.assertEquals(senaki:labelFor("blue"), "Senaki — strength unknown")
end

function TestCampaignIntel:test_a_low_overflight_of_an_awake_zone_reveals_it()
  start({ air = {} })
  local senaki = veafCampaign.zones["Senaki"]
  senaki.awake = true
  coalition.getPlayers = function(side)
    return side == BLUE and { unitAt({ x = 100500, y = 2000 }) } or {}
  end
  veafCampaignEconomy.checkOverflights()
  luaunit.assertFalse(veafCampaign.isRevealed(senaki)) -- too high
  coalition.getPlayers = function(side)
    return side == BLUE and { unitAt({ x = 100500, y = 300 }) } or {}
  end
  veafCampaignEconomy.checkOverflights()
  luaunit.assertTrue(veafCampaign.isRevealed(senaki))
end

function TestCampaignIntel:test_the_composition_lists_air_defence_first()
  start({ air = {} })
  local senaki = veafCampaign.zones["Senaki"]
  senaki.entry.garrison = garrison("Senaki", { 3 }, { "T-72B", "Avenger", "T-72B" })
  local savedCategory = veafCampaign.reserveCategory
  veafCampaign.reserveCategory = function(typeName)
    return typeName == "Avenger" and "air_defense" or "armor"
  end
  luaunit.assertEquals(veafCampaignEconomy.compositionText(senaki), "Senaki — garrison at 67%:\n- Avenger x1\n- T-72B x1")
  veafCampaign.reserveCategory = savedCategory
end

function TestCampaignIntel:test_a_spy_team_walks_to_the_nearest_enemy_zone_and_reveals_it()
  start({ air = {}, intel = { spy_range = 5000 } })
  local position = { x = 96000 }
  local tasks = {}
  dcs_mocks.addGroup("Spy-3", {
    getUnits = function()
      return { unitAt(position) }
    end,
    getController = function()
      return {
        setTask = function(_, task)
          table.insert(tasks, task)
        end,
      }
    end,
  })
  CTLDTroopManager = {
    getInstance = function()
      return { _droppedGroups = { [BLUE] = { "Spy-3" } }, _droppedTemplates = { ["Spy-3"] = { key = "spy", name = "Spy" } } }
    end,
  }
  veafCampaignEconomy.followSpies()
  luaunit.assertEquals(#tasks, 1)
  luaunit.assertEquals(tasks[1].params.route.points[2].x, 100000)
  luaunit.assertFalse(veafCampaign.isRevealed(veafCampaign.zones["Senaki"]))
  position.x = 99500
  veafCampaignEconomy.followSpies()
  luaunit.assertTrue(veafCampaign.isRevealed(veafCampaign.zones["Senaki"]))
end

function TestCampaignIntel:test_a_spy_team_with_no_enemy_zone_in_range_stays()
  start({ air = {}, intel = { spy_range = 5000 } })
  dcs_mocks.addGroup("Spy-4", {
    getUnits = function()
      return { unitAt({ x = 20000 }) }
    end,
  })
  CTLDTroopManager = {
    getInstance = function()
      return { _droppedGroups = { [BLUE] = { "Spy-4" } }, _droppedTemplates = { ["Spy-4"] = { key = "spy", name = "Spy" } } }
    end,
  }
  veafCampaignEconomy.followSpies()
  luaunit.assertEquals(#dcs_mocks.messagesContaining("no enemy zone within 5 km"), 1)
end

function TestCampaignIntel:test_a_reveal_survives_a_restart_with_the_time_it_had_left()
  start({ air = {} })
  dcs_mocks.currentTime = 100
  veafCampaignEconomy.reveal(veafCampaign.zones["Senaki"], 600, "purchase")
  dcs_mocks.currentTime = 400
  local saved = veafCampaignEconomy.save()
  luaunit.assertEquals(saved.revealed, { Senaki = 300 })
  dcs_mocks.currentTime = 0
  veafCampaign.zones["Senaki"].revealedUntil = nil
  veafCampaignEconomy.load(saved)
  luaunit.assertEquals(veafCampaign.zones["Senaki"].revealedUntil, 300)
end

-- ---------------------------------------------------------------------------
-- Self-check
-- ---------------------------------------------------------------------------
TestCampaignLiveSelfCheck = { setUp = setUpSuite, tearDown = tearDownSuite }

local function verdict(ok, key)
  return (ok and "OK " or "KO ") .. key
end

function TestCampaignLiveSelfCheck:test_an_empty_board_is_not_a_fault_before_the_first_beat()
  start({ air = {} })
  luaunit.assertEquals(veafCampaignEconomy.selfCheck(verdict)[2], "OK campaign.check.tasks")
  veafCampaignEconomy.nextTasks = 300 -- drawn once, and nothing on it
  veafCampaignEconomy.tasks = {}
  luaunit.assertEquals(veafCampaignEconomy.selfCheck(verdict)[2], "KO campaign.check.tasks")
end

-- ---------------------------------------------------------------------------
-- Take-off and BARCAP
-- ---------------------------------------------------------------------------
TestCampaignTakeoff = { setUp = setUpSuite, tearDown = tearDownSuite }

--- An airbase whose stands are those given: `{ index, type, taken }`.
local function airbaseWithStands(stands)
  local parking = {}
  for _, stand in ipairs(stands) do
    table.insert(parking, {
      Term_Index = stand[1],
      Term_Type = stand[2],
      TO_AC = stand[3] or nil,
      vTerminalPos = { x = 1000 + stand[1], y = 0, z = 2000 },
    })
  end
  return {
    getPoint = function()
      return { x = 1000, y = 0, z = 2000 }
    end,
    getID = function()
      return 23
    end,
    getParking = function()
      return parking
    end,
  }
end

function TestCampaignTakeoff:test_a_flight_starts_hot_on_free_aircraft_stands()
  -- a runway (16), a helicopter pad (40), a taken stand, then two free ones
  local airbase = airbaseWithStands({ { 1, 16 }, { 2, 40 }, { 3, 72, true }, { 5, 72 }, { 4, 104 } })
  local point, positions = veafCampaignOps.takeoffFrom(airbase, 2)
  luaunit.assertEquals({ point.type, point.action, point.airdromeId }, { "TakeOffParkingHot", "From Parking Area Hot", 23 })
  luaunit.assertEquals({ positions[1].parking, positions[2].parking }, { 4, 5 })
  luaunit.assertEquals({ positions[1].x, positions[1].z }, { 1004, 2000 })
end

function TestCampaignTakeoff:test_a_fighter_takes_the_shelters_before_the_open_stands()
  -- Senaki, measured 2026-11-16: open stands 2-6 (104) line the strip to the runway, and groups
  -- sharing them deadlock; the shelters (68) come first
  local airbase = airbaseWithStands({ { 2, 104 }, { 3, 104 }, { 14, 68 }, { 15, 68 } })
  local _, positions = veafCampaignOps.takeoffFrom(airbase, 2, "MiG-29A")
  luaunit.assertEquals({ positions[1].parking, positions[2].parking }, { 14, 15 })
end

function TestCampaignTakeoff:test_a_fighter_falls_back_on_open_stands_when_the_shelters_are_full()
  local airbase = airbaseWithStands({ { 2, 104 }, { 14, 68 } })
  local _, positions = veafCampaignOps.takeoffFrom(airbase, 2, "MiG-29A")
  luaunit.assertEquals({ positions[1].parking, positions[2].parking }, { 14, 2 })
end

function TestCampaignTakeoff:test_a_large_aircraft_never_takes_a_shelter()
  local airbase = airbaseWithStands({ { 6, 104 }, { 14, 68 } })
  local _, positions = veafCampaignOps.takeoffFrom(airbase, 1, "Tu-22M3")
  luaunit.assertEquals(positions[1].parking, 6)
  local point = veafCampaignOps.takeoffFrom(airbaseWithStands({ { 14, 68 }, { 15, 68 } }), 1, "Tu-22M3")
  luaunit.assertEquals(point.type, "TakeOff")
end

function TestCampaignTakeoff:test_too_few_free_stands_start_on_the_runway()
  local airbase = airbaseWithStands({ { 5, 72 } })
  local point, positions = veafCampaignOps.takeoffFrom(airbase, 2)
  luaunit.assertEquals({ point.type, point.action }, { "TakeOff", "From Runway" })
  luaunit.assertEquals(#positions, 2)
  luaunit.assertNil(positions[1].parking)
end

function TestCampaignTakeoff:test_a_sortie_takes_off_from_its_airfield()
  start()
  local airbase = airbaseWithStands({ { 4, 72 }, { 5, 72 } })
  Airbase.getByName = function()
    return airbase
  end
  veafCampaignOps.maintainCaps("red")
  local flight = self.flights[1]
  luaunit.assertEquals(flight.params.takeoffPoint.type, "TakeOffParkingHot")
  luaunit.assertEquals({ flight.group.units[1].parking, flight.group.units[2].parking }, { 4, 5 })
  -- seated on the ground, not in the air
  luaunit.assertEquals(flight.group.units[1].alt, land.getHeight({ x = 1004, y = 2000 }))
end

function TestCampaignTakeoff:test_nothing_takes_off_from_a_field_under_an_enemy_defence_measured()
  -- 2026-11-16: the whole raid package of Senaki, under Kobuleti's Patriot, lost within 70 s of the take-off.
  -- Senaki is 100 km from Kobuleti here: a take-off threat range of 150 km puts it under.
  start({ takeoff_threat_range = 150000 })
  local senaki, kobuleti = veafCampaign.zones["Senaki"], veafCampaign.zones["Kobuleti"]
  kobuleti.entry.reach = 120000 -- measured while Kobuleti was awake
  luaunit.assertEquals(veafCampaignOps.coveringEnemy("red", senaki), "Kobuleti")
  luaunit.assertFalse(veafCampaignOps.canTakeOffFrom("red", senaki))
  luaunit.assertNil(veafCampaignOps.nearestOwnZone("red", kobuleti, true))
  luaunit.assertNil(veafCampaignOps.raidOrigin("red", kobuleti))
  veafCampaignOps.maintainCaps("red")
  luaunit.assertEquals(#self.flights, 0)
  -- out of its reach, it does
  kobuleti.entry.reach = 80000
  luaunit.assertTrue(veafCampaignOps.canTakeOffFrom("red", senaki))
end

function TestCampaignTakeoff:test_a_long_reach_grounds_only_within_the_takeoff_threat_range()
  -- 2026-11-16: the Patriot's reach as DCS gives it grounded every red field, Sukhumi 120 km away included
  start()
  local senaki, kobuleti = veafCampaign.zones["Senaki"], veafCampaign.zones["Kobuleti"]
  kobuleti.entry.reach = 160000
  luaunit.assertTrue(veafCampaignOps.canTakeOffFrom("red", senaki)) -- 100 km, beyond the default 40 km
end

function TestCampaignTakeoff:test_a_sead_takes_off_under_the_defence_it_is_there_to_put_out()
  -- David, 2026-11-16: what it destroys frees the field for the strikes
  start({ takeoff_threat_range = 150000 })
  local senaki, kobuleti = veafCampaign.zones["Senaki"], veafCampaign.zones["Kobuleti"]
  kobuleti.entry.reach = 120000
  luaunit.assertFalse(veafCampaignOps.canTakeOffFrom("red", senaki, "cas"))
  luaunit.assertTrue(veafCampaignOps.canTakeOffFrom("red", senaki, "sead"))
  luaunit.assertEquals(veafCampaignOps.nearestOwnZone("red", kobuleti, true, "sead").name, "Senaki")
  luaunit.assertNil(veafCampaignOps.nearestOwnZone("red", kobuleti, true, "cas"))
end

function TestCampaignTakeoff:test_an_assumed_reach_grounds_nobody()
  -- a sleeping zone never measured: its reach is a guess, which must not ground a side
  start()
  veafCampaign.zones["Kobuleti"].entry.size.long_range_sam = true -- 75 km assumed; Poti is 50 km away
  luaunit.assertEquals({ veafCampaignOps.threatRange(veafCampaign.zones["Kobuleti"]) }, { 75000, false })
  luaunit.assertNil(veafCampaignOps.coveringEnemy("red", veafCampaign.zones["Poti"]))
end

function TestCampaignTakeoff:test_a_strike_takes_off_then_flies_at_its_altitude()
  local takeoff = { type = "TakeOffParkingHot", action = "From Parking Area Hot", airdromeId = 23 }
  local route = veafAircraftSpawn.roles.campaign_strike.buildRoute({
    spot = { x = 0, y = 10, z = 0 },
    takeoffPoint = takeoff,
    params = {
      target = { x = 5000, y = 0, z = 6000 },
      radius = 2000,
      targetTypes = { "Ground Units" },
      airdromeId = 23,
      home = { x = 0, y = 0, z = 0 },
      altitude = 2600,
    },
  })
  luaunit.assertEquals(route[1].type, "TakeOffParkingHot")
  luaunit.assertEquals(route[1].task.params.tasks[2].id, "EngageTargetsInZone")
  luaunit.assertEquals(route[2].alt, 2600)
end

function TestCampaignTakeoff:test_a_barcap_holds_beyond_the_measured_air_defence()
  start()
  local senaki = veafCampaign.zones["Senaki"]
  -- a live SA-11 launcher of Senaki's garrison, its missile reaching 35 km
  dcs_mocks.addUnit("Senaki garrison #1", {
    getAmmo = function()
      return { { count = 4, desc = { category = Weapon.Category.MISSILE, rangeMaxAltMax = 35000 } } }
    end,
  })
  local station, origin, distance, reach, measured = veafCampaignOps.barcapStation("blue", senaki)
  luaunit.assertEquals(origin.name, "Kobuleti")
  luaunit.assertEquals({ reach, measured }, { 35000, true })
  luaunit.assertEquals(distance, 35000 + 15000 + 15000)
  -- on the line from Senaki (x = 100000) back to Kobuleti (x = 0)
  luaunit.assertEquals({ station.x, station.y, station.radius }, { 100000 - 65000, 0, 15000 })
  dcs_mocks.removeUnit("Senaki garrison #1")
end

function TestCampaignTakeoff:test_a_reach_measured_is_remembered_once_the_zone_sleeps()
  start()
  local senaki = veafCampaign.zones["Senaki"]
  dcs_mocks.addUnit("Senaki garrison #1", {
    getAmmo = function()
      return { { count = 4, desc = { category = Weapon.Category.MISSILE, rangeMaxAltMax = 35000 } } }
    end,
  })
  veafCampaignOps.threatRange(senaki)
  dcs_mocks.removeUnit("Senaki garrison #1")
  -- asleep: no live unit, the reach measured is still known, and saved with the zone
  luaunit.assertEquals({ veafCampaignOps.threatRange(senaki) }, { 35000, true })
  luaunit.assertEquals(veafCampaign.stateTable().zones.Senaki.reach, 35000)
end

function TestCampaignTakeoff:test_a_reach_remembered_is_forgotten_once_the_launchers_are_gone()
  -- a SEAD destroyed the launchers, the radars stand: the zone no longer grounds the fields around it
  start()
  local senaki = veafCampaign.zones["Senaki"]
  senaki.entry.reach = 35000
  dcs_mocks.addUnit("Senaki garrison #2", {
    getAmmo = function()
      return nil
    end,
  })
  luaunit.assertEquals({ veafCampaignOps.threatRange(senaki) }, { 20000, false })
  luaunit.assertNil(senaki.entry.reach)
  dcs_mocks.removeUnit("Senaki garrison #2")
end

function TestCampaignTakeoff:test_a_zone_that_changes_hands_forgets_the_reach_remembered()
  start()
  local senaki = veafCampaign.zones["Senaki"]
  senaki.entry.reach = 35000
  senaki:becomeNeutral()
  luaunit.assertNil(senaki.entry.reach)
  senaki.entry.reach = 35000
  senaki:capturedBy("blue")
  luaunit.assertNil(senaki.entry.reach)
end

function TestCampaignTakeoff:test_a_sleeping_zone_s_reach_is_assumed()
  start()
  local senaki = veafCampaign.zones["Senaki"]
  local _, _, _, reach, measured = veafCampaignOps.barcapStation("blue", senaki)
  luaunit.assertEquals({ reach, measured }, { 20000, false })
  senaki.entry.size.long_range_sam = true
  _, _, _, reach = veafCampaignOps.barcapStation("blue", senaki)
  luaunit.assertEquals(reach, 75000)
end

function TestCampaignTakeoff:test_a_barcap_is_bought_against_an_enemy_zone()
  start({ air = { blue = { cap = AIRCRAFT } }, economy = { start_credits = 1000 } })
  luaunit.assertTrue(veafCampaignEconomy.buy({ "barcap", "Senaki" }))
  luaunit.assertEquals(self.flights[1].role, "zone_defense")
  luaunit.assertEquals(self.flights[1].params.zone.x, 100000 - 50000)
  luaunit.assertEquals(veafCampaignEconomy.credits, 600)
  luaunit.assertFalse(veafCampaignEconomy.buy({ "barcap", "Kobuleti" })) -- ours: a BARCAP is on an enemy zone
end

os.exit(luaunit.LuaUnit.run())
