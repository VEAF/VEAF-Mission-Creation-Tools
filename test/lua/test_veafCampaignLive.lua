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
  -- the other side hears of it at once, to intercept it (2026-11-16)
  local told = dcs_mocks.messagesContaining(veaf.t("campaign.speaker.intel"))
  luaunit.assertEquals(#told, 1)
  luaunit.assertEquals(told[1].target, coalition.side.BLUE)
end

-- FIX-CAMPAIGN-SECOND-SERVER-FLIGHT 04: four Mi-8 sent to Afrin's centre, a town, turned back at once
function TestCampaignHelicopters:test_a_town_zone_is_landed_in_on_a_clear_spot_an_airfield_on_its_field()
  start()
  local asked = {}
  local findSpawnPoint = veaf.findSpawnPoint
  veaf.findSpawnPoint = function(point, radius, clearance)
    table.insert(asked, { radius = radius, clearance = clearance })
    return { x = point.x + 300, y = 0, z = point.z }
  end
  local poti = veafCampaign.zones["Poti"]
  local spot = veafCampaignOps.landingSpot(poti)
  local senaki = veafCampaignOps.landingSpot(veafCampaign.zones["Senaki"])
  veaf.findSpawnPoint = findSpawnPoint
  luaunit.assertEquals(spot.x, poti:getCenter().x + 300)
  luaunit.assertEquals(asked[1].radius, (poti.entry.radius or 2000) * veafCampaignOps.LANDING_SEARCH_SHARE)
  luaunit.assertEquals(#asked, 1, "an airfield is landed on its field, as Menagh was")
  luaunit.assertEquals(senaki.x, veafCampaign.zones["Senaki"]:getCenter().x)
end

-- FIX-CAMPAIGN-SECOND-SERVER-FLIGHT 04: red sent one every 10 minutes regardless, 60 points for nothing
function TestCampaignHelicopters:test_after_two_failures_to_a_zone_red_sends_none_there_for_an_hour()
  start({ route_failures = 2, route_failure_seconds = 3600 })
  local first = veafCampaignOps.sendHelicopter("red", veafCampaign.zones["Poti"], "capture")
  veafCampaignOps.followHelicopter(first, 100) -- gone, no death seen
  luaunit.assertEquals(veafCampaignOps.supplyTarget("red").name, "Poti", "one failure is not enough")
  local second = veafCampaignOps.sendHelicopter("red", veafCampaign.zones["Poti"], "capture")
  veafCampaignOps.followHelicopter(second, 200)
  luaunit.assertNil(veafCampaignOps.supplyTarget("red"), "Poti given up, nothing else to do")
  luaunit.assertTrue(veafCampaign.givenUp("helicopter", "red", "Poti"))
  luaunit.assertFalse(veafCampaign.givenUp("helicopter", "blue", "Poti"), "the other side's memory is its own")
  dcs_mocks.currentTime = timer.getTime() + 3600
  luaunit.assertEquals(veafCampaignOps.supplyTarget("red").name, "Poti")
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

function TestCampaignHelicopters:test_landed_back_away_from_its_zone_it_has_failed_at_once()
  -- 2026-11-16: two Mi-8 for Afrin landed back at Aleppo 3 minutes after leaving, and kept their place 20 minutes
  start()
  local record = veafCampaignOps.sendHelicopter("red", veafCampaign.zones["Poti"], "capture")
  flying(record.name, { x = 90000, z = 0 }, true)
  veafCampaignOps.followHelicopter(record, 60)
  luaunit.assertNil(record.done)
  flying(record.name, { x = 99000, z = 0 }, false) -- down at Senaki, where it left
  veafCampaignOps.followHelicopter(record, 180)
  luaunit.assertTrue(record.done)
  luaunit.assertEquals(record.outcome, "failed")
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
  veafCampaignOps.onFlightEvent({ id = world.event.S_EVENT_CRASH, initiator = { unitName = record.name .. " #1" } })
  veafCampaignOps.followHelicopter(record, 100)
  luaunit.assertEquals(record.outcome, "destroyed")
  luaunit.assertEquals(veafCampaignOps.counters.helicoptersFailed, 1)
end

-- FIX-CAMPAIGN-SECOND-SERVER-FLIGHT 09: a group that vanished with no death seen is "gone", not "destroyed"
function TestCampaignHelicopters:test_vanished_with_no_death_seen_it_is_gone()
  start()
  local record = veafCampaignOps.sendHelicopter("red", veafCampaign.zones["Poti"], "capture")
  veafCampaignOps.followHelicopter(record, 100)
  luaunit.assertEquals(record.outcome, "gone")
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

function TestCampaignAir:test_cas_keeps_out_of_a_measured_medium_range_air_defence()
  -- 2026-11-16: a red CAS sent at Hatay, under a Hawk of 40 km, dropped its bombs 20 km short and was shot down
  start()
  veafCampaign.zones["Poti"].entry.owner = "blue"
  veafCampaign.zones["Poti"].entry.garrison = garrison("Poti", nil, { "T-72B", "T-72B", "T-72B" })
  veafCampaign.zones["Kobuleti"].entry.reach = 60000 -- Kobuleti's Hawk, measured, reaches Poti 50 km away
  local target, avoided = veafCampaignOps.strikeTarget("red", "cas")
  luaunit.assertNil(target)
  luaunit.assertEquals(avoided, "[Poti] under the air defence of [Kobuleti]")
  -- guns and short-range missiles do not keep it off
  veafCampaign.zones["Kobuleti"].entry.reach = 8000
  veafCampaign.zones["Poti"].entry.reach = 8000
  luaunit.assertEquals(veafCampaignOps.strikeTarget("red", "cas").name, "Poti")
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
  -- a kill earns half at once, the other half when the pilot lands at a friendly base (economy.landing_share)
  veafCampaignEconomy.onKill(kill("Zip"))
  luaunit.assertEquals(veafCampaignEconomy.credits, 105)
  veafCampaignEconomy.onKill(kill("Zip", Unit.Category.AIRPLANE))
  luaunit.assertEquals(veafCampaignEconomy.credits, 130)
  veafCampaign.notify("captured", veafCampaign.zones["Poti"], "blue")
  luaunit.assertEquals(veafCampaignEconomy.credits, 330)
  veafCampaign.notify("delivered", veafCampaign.zones["Kobuleti"], "blue", "crate")
  luaunit.assertEquals(veafCampaignEconomy.credits, 430)
  -- the enemy's captures and an AI's kills earn nothing
  veafCampaign.notify("captured", veafCampaign.zones["Poti"], "red")
  veafCampaignEconomy.onKill(kill(nil))
  luaunit.assertEquals(veafCampaignEconomy.credits, 430)
end

--- An airbase of a side, as `Airbase.getByName` hands it.
local function airbaseOf(side)
  return {
    getCoalition = function()
      return side
    end,
  }
end

function TestCampaignShop:test_the_held_credits_are_earned_at_a_friendly_landing()
  -- David, 2026-11-16: "a share at the action, a bonus at landing"
  veafCampaignEconomy.onKill(kill("Zip", Unit.Category.AIRPLANE))
  luaunit.assertEquals(veafCampaignEconomy.credits, 125)
  local saved = Airbase.getByName
  Airbase.getByName = function(name)
    return airbaseOf(name == "Kobuleti" and BLUE or RED)
  end
  local function land(place)
    veafCampaignEconomy.onPilotEvent({
      type = { id = world.event.S_EVENT_LAND },
      initiator = { unitName = "Zip's Hog" },
      place = place and { unitName = place } or nil,
    })
  end
  land(nil) -- in the open
  land("Senaki-Kolkhi") -- an enemy field
  luaunit.assertEquals(veafCampaignEconomy.credits, 125)
  land("Kobuleti")
  Airbase.getByName = saved
  luaunit.assertEquals(veafCampaignEconomy.credits, 150)
  luaunit.assertNil(veafCampaignEconomy.held["Zip's Hog"])
end

function TestCampaignShop:test_the_held_credits_are_lost_with_the_pilot()
  veafCampaignEconomy.onKill(kill("Zip", Unit.Category.AIRPLANE))
  veafCampaignEconomy.onPilotEvent({ type = { id = world.event.S_EVENT_EJECTION }, initiator = { unitName = "Zip's Hog" } })
  luaunit.assertNil(veafCampaignEconomy.held["Zip's Hog"])
  luaunit.assertEquals(veafCampaignEconomy.credits, 125)
  luaunit.assertEquals(#dcs_mocks.messagesContaining("25"), 2) -- the kill, then the loss
end

--- The dcs.log lines holding `text`.
local function loggedLines(text)
  local found = {}
  for _, entry in ipairs(dcs_mocks.logs) do
    if string.find(entry.text, text, 1, true) then
      table.insert(found, entry.text)
    end
  end
  return found
end

-- FIX-CAMPAIGN-SECOND-SERVER-FLIGHT 10: 400 credits earned around 21:35 on 2026-11-17 could not be told to anyone
function TestCampaignShop:test_each_gain_is_logged_with_its_pilot_and_its_reason()
  veafCampaignEconomy.onKill(kill("Zip"))
  veafCampaign.notify("captured", veafCampaign.zones["Poti"], "blue")
  luaunit.assertEquals(#loggedLines("CREDITS Zip +5 (kill_held)"), 1)
  luaunit.assertEquals(#loggedLines("CREDITS team +200 (capture)"), 1)
  luaunit.assertEquals(veafCampaignEconomy.pilots["Zip"].total, 5)
  luaunit.assertEquals(veafCampaignEconomy.pilots["team"].reasons.capture, 200)
  -- kept in the save, for the debrief
  local saved = veafCampaignEconomy.save()
  luaunit.assertEquals(saved.pilots["Zip"].total, 5)
end

function TestCampaignShop:test_the_session_summary_says_who_earned_what_once_nobody_is_left()
  veafCampaignEconomy.onKill(kill("Zip", Unit.Category.AIRPLANE))
  veafCampaignEconomy.onKill(kill("Paluche"))
  local getPlayers = coalition.getPlayers
  coalition.getPlayers = function()
    return { "someone" }
  end
  veafCampaignEconomy.beat(100)
  luaunit.assertEquals(#loggedLines("CREDITS SUMMARY"), 0, "players still in a slot")
  coalition.getPlayers = function()
    return {}
  end
  veafCampaignEconomy.beat(200)
  coalition.getPlayers = getPlayers
  luaunit.assertEquals(#loggedLines("CREDITS SUMMARY (nobody left in a slot): 30 earned by the side"), 1)
  luaunit.assertEquals(#loggedLines("CREDITS SUMMARY Zip: 25 this session"), 1)
  luaunit.assertEquals(#loggedLines("CREDITS SUMMARY Paluche: 5 this session"), 1)
  luaunit.assertFalse(veafCampaignEconomy.summarizeSession("again"), "said once")
end

-- FIX-CAMPAIGN-ECONOMY-BALANCE 01: the rewards of Foothold (SAM 30, aircraft 50, building 100, rescue 200)
function TestCampaignShop:test_a_sam_pays_more_than_a_ground_unit()
  local getByName = Unit.getByName
  Unit.getByName = function(name)
    if name == "SA-11" then
      return {
        hasAttribute = function(_, attribute)
          return attribute == "SAM related"
        end,
      }
    end
    return getByName(name)
  end
  local event = kill("Zip")
  event.target.unitName = "SA-11"
  veafCampaignEconomy.onKill(event)
  Unit.getByName = getByName
  -- half at once, half at landing
  luaunit.assertEquals(veafCampaignEconomy.credits, 115)
  luaunit.assertEquals(veafCampaignEconomy.held["Zip's Hog"].amount, 15)
end

function TestCampaignShop:test_a_helicopter_pays_as_an_aeroplane()
  veafCampaignEconomy.onKill(kill("Zip", Unit.Category.HELICOPTER))
  luaunit.assertEquals(veafCampaignEconomy.credits, 125)
  luaunit.assertEquals(veafCampaignEconomy.held["Zip's Hog"].amount, 25)
end

--- A kill of a building of a zone, as veafEventHandler hands it: a static has no side it can read.
local function buildingKill(player, zoneName)
  veafCampaign.structureIndex["building of " .. zoneName] = { zone = veafCampaign.zones[zoneName], index = 1 }
  return {
    initiator = { unitName = "Zip's Hog", unitCoalition = BLUE },
    dcsInitiator = unitAt({ x = 90000 }, { player = player, side = BLUE }),
    target = { unitName = "building of " .. zoneName },
  }
end

function TestCampaignShop:test_a_building_of_an_enemy_zone_destroyed_by_a_player_pays()
  veafCampaignEconomy.onKill(buildingKill("Zip", "Senaki"))
  luaunit.assertEquals(veafCampaignEconomy.credits, 150)
  luaunit.assertEquals(veafCampaignEconomy.held["Zip's Hog"].amount, 50)
  luaunit.assertEquals(veafCampaignEconomy.pilots["Zip"].stats.Structure, 1)
  -- one of the players' own buildings, or one destroyed by the AI, pays nothing
  veafCampaignEconomy.onKill(buildingKill("Zip", "Kobuleti"))
  veafCampaignEconomy.onKill(buildingKill(nil, "Senaki"))
  luaunit.assertEquals(veafCampaignEconomy.credits, 150)
end

function TestCampaignShop:test_each_reward_is_a_setting()
  veafCampaign.data.dynamic.economy = { kill_air = 7, kill_sam = 8, kill_building = 9, landing_share = 0 }
  veafCampaignEconomy.onKill(kill("Zip", Unit.Category.AIRPLANE))
  veafCampaignEconomy.onKill(buildingKill("Zip", "Senaki"))
  luaunit.assertEquals(veafCampaignEconomy.credits, 116)
end

--- The CSAR module's registry and its delivery to the MASH, as CSAR.lua has them.
local function csarWithPilots(heliName, count)
  local rescued = {}
  local groups = {}
  for index = 1, count do
    groups["Downed " .. index] = { originalUnit = "x" .. index }
  end
  return {
    inTransitGroups = { [heliName] = groups },
    rescuePilots = function(heli)
      table.insert(rescued, heli)
      csar.inTransitGroups[heli:getName()] = nil
    end,
  },
    rescued
end

--- A helicopter as `csar.rescuePilots` is handed it.
local function heli(name, player, side)
  local unit = unitAt({ x = 0 }, { player = player, side = side or BLUE, category = Unit.Category.HELICOPTER })
  unit.getName = function()
    return name
  end
  return unit
end

function TestCampaignShop:test_a_rescue_pays_the_rescuing_pilot_per_pilot_delivered()
  local saved = csar
  local rescued
  csar, rescued = csarWithPilots("Zip's Huey", 2)
  veafCampaignEconomy.watchRescues()
  csar.rescuePilots(heli("Zip's Huey", "Zip"))
  -- the pilots are delivered as before, and the rescuer is paid in full: he is on the ground at the MASH
  luaunit.assertEquals(#rescued, 1)
  luaunit.assertEquals(veafCampaignEconomy.credits, 500)
  luaunit.assertEquals(veafCampaignEconomy.pilots["Zip"].reasons.rescue, 400)
  luaunit.assertEquals(#loggedLines("CREDITS Zip +400 (rescue)"), 1)
  -- a second call, nothing in transit any more, pays nothing; watching twice does not pay twice
  veafCampaignEconomy.watchRescues()
  csar.inTransitGroups["Zip's Huey"] = { ["Downed 3"] = {} }
  csar.rescuePilots(heli("Zip's Huey", "Zip"))
  luaunit.assertEquals(veafCampaignEconomy.credits, 700)
  csar.rescuePilots(heli("Zip's Huey", "Zip"))
  luaunit.assertEquals(veafCampaignEconomy.credits, 700)
  csar = saved
end

function TestCampaignShop:test_a_rescue_by_the_ai_or_the_enemy_pays_nothing()
  local saved = csar
  csar = csarWithPilots("AI Huey", 1)
  csar.inTransitGroups["Ivan's Mi-8"] = { ["Downed red"] = {} }
  veafCampaignEconomy.watchRescues()
  csar.rescuePilots(heli("AI Huey", nil))
  csar.rescuePilots(heli("Ivan's Mi-8", "Ivan", RED))
  luaunit.assertEquals(veafCampaignEconomy.credits, 100)
  csar = saved
end

function TestCampaignShop:test_no_csar_module_no_rescue_reward()
  local saved = csar
  csar = nil
  luaunit.assertFalse(veafCampaignEconomy.watchRescues())
  csar = saved
end

-- FIX-CAMPAIGN-ECONOMY-BALANCE 03: what the players earn and spend in an evening, by kind, to tune the prices
function TestCampaignShop:test_the_economy_summary_gives_what_was_earned_and_spent_by_kind()
  local getPlayers, getAirbase = coalition.getPlayers, Airbase.getByName
  coalition.getPlayers = function()
    return { "someone" }
  end
  dcs_mocks.currentTime = 1000
  veafCampaignEconomy.beat(1000) -- a player in a slot: the session's books open, at 100 credits
  luaunit.assertNotNil(veafCampaignEconomy.ledger)
  veafCampaignEconomy.onKill(kill("Zip", Unit.Category.AIRPLANE))
  Airbase.getByName = function()
    return airbaseOf(BLUE)
  end
  veafCampaignEconomy.onPilotEvent({
    type = { id = world.event.S_EVENT_LAND },
    initiator = { unitName = "Zip's Hog" },
    place = { unitName = "Kobuleti" },
  })
  Airbase.getByName = getAirbase
  veafCampaignEconomy.buy({ "illumination", "Senaki" })
  veafCampaignEconomy.buy({ "illumination", "Senaki" })
  coalition.getPlayers = function()
    return {}
  end
  dcs_mocks.currentTime = 1000 + 3 * 3600
  veafCampaignEconomy.beat(dcs_mocks.currentTime)
  coalition.getPlayers = getPlayers
  luaunit.assertEquals(#loggedLines("ECONOMY SUMMARY (nobody left in a slot): 180 min"), 1)
  luaunit.assertEquals(#loggedLines("ECONOMY SUMMARY blue credits: 100 at the start, 50 at the end"), 1)
  -- the kill counts once, both its parts under its own kind
  luaunit.assertEquals(#loggedLines("ECONOMY SUMMARY blue credits earned 50: kill_air 50 (x1)"), 1)
  luaunit.assertEquals(#loggedLines("ECONOMY SUMMARY blue credits spent 100: shop illumination 100 (x2)"), 1)
  -- closed until a player sits in a slot again
  luaunit.assertNil(veafCampaignEconomy.ledger)
  luaunit.assertFalse(veafCampaignEconomy.summarizeSession("again"))
end

function TestCampaignShop:test_no_economy_summary_when_nobody_played()
  veafCampaignEconomy.earn(200, "campaign.credits.capture", "Poti")
  veafCampaignEconomy.summarizeSession("the mission ends")
  luaunit.assertEquals(#loggedLines("ECONOMY SUMMARY"), 0)
  luaunit.assertEquals(#loggedLines("CREDITS SUMMARY (the mission ends): 200 earned"), 1)
end

function TestCampaignShop:test_the_mission_end_closes_the_books()
  veafCampaignEconomy.openLedger()
  luaunit.assertTrue(veafCampaignEconomy.charge(30, "Assault", "shop assault"))
  luaunit.assertTrue(veafCampaignEconomy.summarizeSession("the mission ends"))
  luaunit.assertEquals(#loggedLines("ECONOMY SUMMARY blue credits earned 0: nothing"), 1)
  luaunit.assertEquals(#loggedLines("ECONOMY SUMMARY blue credits spent 30: shop assault 30 (x1)"), 1)
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
-- Zone upgrades (FEAT-CAMPAIGN-SHOP-UPGRADES 01)
-- ---------------------------------------------------------------------------
TestCampaignUpgrades = {}

--- The groups of veaf-units.yaml the upgrades are taken from, as `veafUnits.findGroup` hands them back.
local UPGRADE_GROUPS = {
  hawk = { "Hawk ln", "Hawk ln", "Hawk sr", "Hawk tr", "M 818" },
  nasams = { "NASAMS_LN_C", "NASAMS_Radar_MPQ64F1" },
  patriot = { "Patriot ln", "Patriot str" },
  avenger_squad = { "M1097 Avenger", "M 818" },
}

local function processed(types, name)
  local group = { units = {}, groupName = name }
  for _, typeName in ipairs(types) do
    table.insert(group.units, { typeName = typeName })
  end
  return group
end

function TestCampaignUpgrades:setUp()
  setUpSuite(self)
  self.savedUpgrades = {
    findGroup = veafUnits.findGroup,
    processGroup = veafUnits.processGroup,
    infantry = veafCasMission.generateInfantryGroup,
    armor = veafCasMission.generateArmorPlatoon,
    placeGarrisonGroup = veafCampaign.placeGarrisonGroup,
    era = veaf.config.era,
  }
  local this = self
  self.found = {}
  veafUnits.findGroup = function(alias)
    table.insert(this.found, alias)
    return UPGRADE_GROUPS[alias] and processed(UPGRADE_GROUPS[alias], alias)
  end
  veafUnits.processGroup = function(definition)
    local types = {}
    for _, unit in ipairs(definition.units) do
      table.insert(types, unit.typeName or unit[1])
    end
    return processed(types, definition.groupName)
  end
  veafCasMission.generateInfantryGroup = function(name)
    return { units = { { "Soldier M4" }, { "Soldier M4" }, { "M 818" } }, groupName = name }
  end
  veafCasMission.generateArmorPlatoon = function(name)
    return { units = { { "M-1 Abrams" }, { "M-2 Bradley" } }, groupName = name }
  end
  veafCampaign.placeGarrisonGroup = function(definition, center, _, units)
    for index, unit in ipairs(definition.units) do
      table.insert(units, { typeName = unit.typeName, spawnPoint = { x = center.x + 30 * index, y = 0, z = center.z + 40 }, hdg = 0 })
    end
  end
  start({ economy = { start_credits = 100000 }, air = {} })
end

function TestCampaignUpgrades:tearDown()
  local s = self.savedUpgrades
  veafUnits.findGroup, veafUnits.processGroup = s.findGroup, s.processGroup
  veafCasMission.generateInfantryGroup, veafCasMission.generateArmorPlatoon = s.infantry, s.armor
  veafCampaign.placeGarrisonGroup, veaf.config.era = s.placeGarrisonGroup, s.era
  tearDownSuite(self)
end

local function upgradeGroupNamed(zone, name)
  for _, group in ipairs(zone.entry.garrison) do
    if group.name == name then
      return group
    end
  end
  return nil
end

function TestCampaignUpgrades:test_a_bought_battery_joins_the_zone_s_garrison_at_its_spawn_price()
  local kobuleti = veafCampaign.zones["Kobuleti"]
  local price = veafCampaign.unitsPrice(UPGRADE_GROUPS.hawk) * 6 -- economy.credits_per_point
  luaunit.assertEquals(veafCampaignEconomy.upgradePrice("hawk"), price)
  luaunit.assertTrue(veafCampaignEconomy.buyUpgrade({ "hawk", "Kobuleti" }))
  luaunit.assertEquals(veafCampaignEconomy.credits, 100000 - price)
  local group = upgradeGroupNamed(kobuleti, "Kobuleti upgrade 1 hawk")
  luaunit.assertNotNil(group)
  luaunit.assertEquals(group.upgrade, "hawk")
  luaunit.assertEquals(#group.units, 5)
  luaunit.assertEquals(group.units[1].type, "Hawk ln")
  luaunit.assertEquals(#dcs_mocks.messagesContaining("Hawk battery"), 1)
end

function TestCampaignUpgrades:test_the_battery_is_in_the_world_at_once_when_its_zone_is_awake_in_its_record_when_asleep()
  local kobuleti = veafCampaign.zones["Kobuleti"]
  kobuleti:sleep("test")
  dcs_mocks.groupsAdded = {}
  veafCampaignEconomy.buyUpgrade({ "hawk", "Kobuleti" })
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0, "asleep: recorded only")
  kobuleti:wake()
  while kobuleti.wakeQueue do
    kobuleti:continueSpawning()
  end
  local names = {}
  for _, call in ipairs(dcs_mocks.groupsAdded) do
    table.insert(names, call.group.name)
  end
  luaunit.assertEquals(names, { "Kobuleti garrison", "Kobuleti upgrade 1 hawk" }, "it wakes with the zone")
  dcs_mocks.groupsAdded = {}
  veafCampaignEconomy.buyUpgrade({ "gepard", "Kobuleti" })
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 1, "awake: in the world at once")
  luaunit.assertEquals(dcs_mocks.groupsAdded[1].group.name, "Kobuleti upgrade 2 gepard")
  luaunit.assertEquals(#dcs_mocks.groupsAdded[1].group.units, 4)
end

function TestCampaignUpgrades:test_the_battery_is_saved_reinforced_and_lost_with_the_zone()
  local kobuleti = veafCampaign.zones["Kobuleti"]
  veafCampaignEconomy.buyUpgrade({ "nasams", "Kobuleti" })
  local saved = veafCampaign.stateTable().zones["Kobuleti"].garrison
  luaunit.assertEquals(saved[#saved].name, "Kobuleti upgrade 1 nasams")
  -- reinforced at its spawn price, as the rest of the garrison
  kobuleti.entry.garrison[1].units[1].alive = true
  local group = upgradeGroupNamed(kobuleti, "Kobuleti upgrade 1 nasams")
  group.units[1].alive = false
  luaunit.assertTrue(kobuleti:reinforce())
  luaunit.assertTrue(group.units[1].alive)
  -- lost with the zone
  kobuleti:becomeNeutral()
  luaunit.assertEquals(#kobuleti:upgrades(), 0)
end

function TestCampaignUpgrades:test_a_third_upgrade_on_a_zone_is_refused_and_free()
  luaunit.assertTrue(veafCampaignEconomy.buyUpgrade({ "infantry", "Kobuleti" }))
  luaunit.assertTrue(veafCampaignEconomy.buyUpgrade({ "armor", "Kobuleti" }))
  local credits = veafCampaignEconomy.credits
  luaunit.assertFalse(veafCampaignEconomy.buyUpgrade({ "avenger", "Kobuleti" }))
  luaunit.assertEquals(veafCampaignEconomy.credits, credits)
  luaunit.assertEquals(#veafCampaign.zones["Kobuleti"]:upgrades(), 2)
  luaunit.assertEquals(#dcs_mocks.messagesContaining("already holds its 2 bought upgrades"), 1)
end

function TestCampaignUpgrades:test_the_limit_per_zone_is_a_setting()
  veafCampaign.data.dynamic.economy.upgrades_per_zone = 1
  luaunit.assertTrue(veafCampaignEconomy.buyUpgrade({ "infantry", "Kobuleti" }))
  luaunit.assertFalse(veafCampaignEconomy.buyUpgrade({ "armor", "Kobuleti" }))
end

function TestCampaignUpgrades:test_a_second_patriot_on_a_zone_is_refused()
  veafCampaign.data.dynamic.economy.upgrades_per_zone = 3
  luaunit.assertTrue(veafCampaignEconomy.buyUpgrade({ "patriot", "Kobuleti" }))
  local credits = veafCampaignEconomy.credits
  luaunit.assertFalse(veafCampaignEconomy.buyUpgrade({ "patriot", "Kobuleti" }))
  luaunit.assertEquals(veafCampaignEconomy.credits, credits)
  luaunit.assertEquals(#dcs_mocks.messagesContaining("one per zone"), 1)
  luaunit.assertTrue(veafCampaignEconomy.buyUpgrade({ "hawk", "Kobuleti" }), "another upgrade still fits")
end

function TestCampaignUpgrades:test_an_upgrade_is_for_the_players_zones_only()
  luaunit.assertFalse(veafCampaignEconomy.buyUpgrade({ "hawk", "Senaki" }))
  luaunit.assertFalse(veafCampaignEconomy.buyUpgrade({ "hawk", "Poti" }))
  luaunit.assertEquals(veafCampaignEconomy.credits, 100000)
end

function TestCampaignUpgrades:test_too_expensive_is_refused_and_free()
  veafCampaignEconomy.credits = 10
  luaunit.assertFalse(veafCampaignEconomy.buyUpgrade({ "hawk", "Kobuleti" }))
  luaunit.assertEquals(veafCampaignEconomy.credits, 10)
  luaunit.assertEquals(#veafCampaign.zones["Kobuleti"]:upgrades(), 0)
end

function TestCampaignUpgrades:test_a_group_that_cannot_be_placed_costs_nothing()
  veafCampaign.placeGarrisonGroup = function() end
  luaunit.assertFalse(veafCampaignEconomy.buyUpgrade({ "hawk", "Kobuleti" }))
  luaunit.assertEquals(veafCampaignEconomy.credits, 100000)
  luaunit.assertEquals(#dcs_mocks.messagesContaining("no room for it"), 1)
end

function TestCampaignUpgrades:test_the_price_shown_is_the_group_placed_and_economy_prices_wins()
  -- drawn once: the menu's price and the purchase place the same units
  veafCampaignEconomy.upgradePrice("hawk")
  veafCampaignEconomy.buyUpgrade({ "hawk", "Kobuleti" })
  local hawks = 0
  for _, alias in ipairs(self.found) do
    hawks = hawks + (alias == "hawk" and 1 or 0)
  end
  luaunit.assertEquals(hawks, 1)
  veafCampaign.data.dynamic.economy.prices = { hawk = 2000 }
  luaunit.assertEquals(veafCampaignEconomy.upgradePrice("hawk"), 2000)
end

-- FIX-CAMPAIGN-ECONOMY-BALANCE 05: one rule, the spawn price; ticket 02's hand prices are gone
function TestCampaignUpgrades:test_the_nasams_and_the_patriot_cost_their_units_spawn_price()
  local nasams = veafCampaign.unitsPrice(UPGRADE_GROUPS.nasams) * 6 -- economy.credits_per_point
  local patriot = veafCampaign.unitsPrice(UPGRADE_GROUPS.patriot) * 6
  luaunit.assertEquals(veafCampaignEconomy.upgradePrice("nasams"), nasams)
  luaunit.assertEquals(veafCampaignEconomy.upgradePrice("patriot"), patriot)
  luaunit.assertTrue(veafCampaignEconomy.buyUpgrade({ "patriot", "Kobuleti" }))
  luaunit.assertEquals(veafCampaignEconomy.credits, 100000 - patriot)
  for _, upgrade in ipairs(veafCampaignEconomy.UPGRADES) do
    luaunit.assertNil(upgrade.price, upgrade.id)
  end
  -- a campaign's economy.prices still wins
  veafCampaign.data.dynamic.economy.prices = { nasams = 1500 }
  luaunit.assertEquals(veafCampaignEconomy.upgradePrice("nasams"), 1500)
end

function TestCampaignUpgrades:test_the_upgrades_offered_follow_the_era()
  local function ids()
    local list = {}
    for _, upgrade in ipairs(veafCampaignEconomy.availableUpgrades()) do
      table.insert(list, upgrade.id)
    end
    return list
  end
  veaf.config.era = veaf.ERA.MODERN
  luaunit.assertEquals(ids(), { "hawk", "nasams", "patriot", "avenger", "gepard", "infantry", "armor" })
  veaf.config.era = veaf.ERA.COLD_WAR
  luaunit.assertEquals(ids(), { "hawk", "gepard", "infantry", "armor" })
  veaf.config.era = veaf.ERA.WW2
  luaunit.assertEquals(ids(), { "infantry", "armor" })
end

-- ---------------------------------------------------------------------------
-- CAS and SEAD flights (FEAT-CAMPAIGN-SHOP-UPGRADES 02)
-- ---------------------------------------------------------------------------
TestCampaignShopFlights = { setUp = setUpSuite, tearDown = tearDownSuite }

local function startWithFlights()
  start({
    economy = { start_credits = 2000 },
    air = { red = { cap = AIRCRAFT }, blue = { cap = AIRCRAFT, cas = AIRCRAFT, sead = AIRCRAFT } },
  })
end

function TestCampaignShopFlights:test_a_cas_bought_takes_off_from_our_airfield_and_strikes_the_zone()
  startWithFlights()
  luaunit.assertTrue(veafCampaignEconomy.buy({ "cas", "Senaki" }))
  luaunit.assertEquals(veafCampaignEconomy.credits, 1500)
  local flight = self.flights[1]
  luaunit.assertEquals(flight.role, "campaign_strike")
  luaunit.assertEquals(flight.params.task, "CAS")
  luaunit.assertEquals(flight.params.target.x, 100000)
  luaunit.assertEquals(flight.params.targetTypes, { "Ground Units" })
  luaunit.assertEquals(flight.params.airdromeId, 24) -- Kobuleti
  luaunit.assertStrContains(flight.group.name, "blue cas Kobuleti")
  luaunit.assertEquals(#dcs_mocks.messagesContaining("CAS flight: leaving Kobuleti for Senaki"), 1)
end

function TestCampaignShopFlights:test_a_sead_bought_engages_the_zone_s_air_defence()
  startWithFlights()
  luaunit.assertTrue(veafCampaignEconomy.buy({ "sead", "Senaki" }))
  luaunit.assertEquals(veafCampaignEconomy.credits, 1400)
  luaunit.assertEquals(self.flights[1].params.task, "SEAD")
  luaunit.assertEquals(self.flights[1].params.targetTypes, { "Air Defence" })
end

function TestCampaignShopFlights:test_one_flight_of_each_kind_in_the_air_at_a_time()
  startWithFlights()
  luaunit.assertTrue(veafCampaignEconomy.buy({ "sead", "Senaki" }))
  luaunit.assertFalse(veafCampaignEconomy.buy({ "sead", "Zugdidi" }))
  luaunit.assertEquals(veafCampaignEconomy.credits, 1400, "refused, nothing charged")
  luaunit.assertEquals(#dcs_mocks.messagesContaining("already in the air"), 1)
  luaunit.assertTrue(veafCampaignEconomy.buy({ "cas", "Zugdidi" }), "the other kind is free")
  -- the SEAD down, another one may go (once past the grace a flight just spawned is given to appear)
  dcs_mocks.removeGroup(self.flights[1].group.name)
  dcs_mocks.advanceTime(veafCampaignOps.FLIGHT_GRACE)
  luaunit.assertTrue(veafCampaignEconomy.buy({ "sead", "Zugdidi" }))
end

function TestCampaignShopFlights:test_no_airfield_to_leave_from_is_refused_and_free()
  local campaignData = data({ economy = { start_credits = 2000 }, air = { blue = { cas = AIRCRAFT } } })
  campaignData.zones[1].airbase = nil
  veafCampaign.data = campaignData
  veafCampaign.initialize()
  luaunit.assertFalse(veafCampaignEconomy.buy({ "cas", "Senaki" }))
  luaunit.assertEquals(veafCampaignEconomy.credits, 2000)
  luaunit.assertEquals(#self.flights, 0)
end

function TestCampaignShopFlights:test_a_flight_is_for_an_enemy_zone_only()
  startWithFlights()
  luaunit.assertFalse(veafCampaignEconomy.buy({ "cas", "Kobuleti" }))
  luaunit.assertFalse(veafCampaignEconomy.buy({ "sead", "Poti" }))
  luaunit.assertEquals(#self.flights, 0)
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
  luaunit.assertEquals(veafCampaignEconomy.credits, 50 + 200) -- half of each kill, the rest held until landing
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

TestCampaignTankers = { setUp = setUpSuite, tearDown = tearDownSuite }

-- David, 2026-11-17: a boom and a basket, each its own shop item
function TestCampaignTankers:test_each_tanker_is_bought_apart()
  start({ economy = { start_credits = 1000, tanker = { "Tanker Texaco", "Tanker Arco" } } })
  local respawned = {}
  local savedAssets = veafAssets
  veafAssets = {
    respawn = function(name)
      table.insert(respawned, name)
    end,
  }
  luaunit.assertTrue(veafCampaignEconomy.buy({ "tanker", "Tanker Arco" }))
  luaunit.assertFalse(veafCampaignEconomy.buy({ "tanker", "Tanker Shell" }), "a tanker the campaign does not name")
  veafAssets = savedAssets
  luaunit.assertEquals(respawned, { "Tanker Arco" })
  luaunit.assertEquals(veafCampaignEconomy.tankers(), { "Tanker Texaco", "Tanker Arco" })
end

-- David, 2026-11-17: the shop says whether each tanker is a boom or a basket
function TestCampaignTankers:test_each_tanker_says_how_it_refuels()
  local function tanker(name, typeName)
    dcs_mocks.addGroup(name, {
      getUnit = function()
        return {
          getTypeName = function()
            return typeName
          end,
        }
      end,
    })
  end
  tanker("Tanker Texaco", "KC-135")
  tanker("Tanker Arco", "KC135MPRS")
  luaunit.assertEquals(veafCampaignEconomy.tankerTitle("Tanker Texaco"), "Tanker Texaco (" .. veaf.t("tanker.kind.boom") .. ")")
  luaunit.assertEquals(veafCampaignEconomy.tankerTitle("Tanker Arco"), "Tanker Arco (" .. veaf.t("tanker.kind.basket") .. ")")
  luaunit.assertEquals(veafCampaignEconomy.tankerTitle("Tanker Shell"), "Tanker Shell", "a group not in the mission")
  dcs_mocks.removeGroup("Tanker Texaco")
  dcs_mocks.removeGroup("Tanker Arco")
end

function TestCampaignTankers:test_one_name_still_works()
  start({ economy = { tanker = "Tanker Texaco" } })
  luaunit.assertEquals(veafCampaignEconomy.tankers(), { "Tanker Texaco" })
end

TestCampaignAdminMenus = { setUp = setUpSuite, tearDown = tearDownSuite }

-- 2026-11-16, first server evening: a senior pilot opened the self-check marked "(admin)"
function TestCampaignAdminMenus:test_the_admin_commands_ask_the_admin_level()
  start()
  local added = {}
  local add = veafRadio.addSecuredCommandToSubmenu
  veafRadio.addSecuredCommandToSubmenu = function(title, ...)
    local command = { title = title }
    added[title] = command
    return command
  end
  veafCampaign.buildAdminMenu()
  veafRadio.addSecuredCommandToSubmenu = add
  for _, key in ipairs({ "menu.campaign.counters", "menu.campaign.self_check", "menu.campaign.reset" }) do
    local command = added[veaf.t(key)]
    luaunit.assertNotNil(command, key)
    luaunit.assertEquals(command.securityLevel, 90, key)
    luaunit.assertTrue(command.sortLast, key .. ": veafRadio sorts by label, the order of insertion is not enough")
  end
  luaunit.assertTrue(added[veaf.t("menu.campaign.counters")].sortKey < added[veaf.t("menu.campaign.reset")].sortKey)
end

-- 2026-11-16: the admin commands came before the shop and the rest, which fell to the menu's second page
function TestCampaignAdminMenus:test_the_admin_commands_come_last()
  local titles = {}
  local saved = {}
  for _, name in ipairs({ "addCommandToSubmenu", "addSecuredCommandToSubmenu", "addSubMenu" }) do
    saved[name] = veafRadio[name]
    veafRadio[name] = function(title, menu, ...)
      if menu ~= nil and menu == veafCampaign.rootPath then
        table.insert(titles, title)
      end
      return saved[name](title, menu, ...)
    end
  end
  start()
  for name, original in pairs(saved) do
    veafRadio[name] = original
  end
  local admin =
    { [veaf.t("menu.campaign.counters")] = true, [veaf.t("menu.campaign.self_check")] = true, [veaf.t("menu.campaign.reset")] = true }
  local seenAdmin = false
  for _, title in ipairs(titles) do
    if admin[title] then
      seenAdmin = true
    else
      luaunit.assertFalse(seenAdmin, "a command after the admin ones: " .. tostring(title))
    end
  end
  luaunit.assertTrue(seenAdmin)
  luaunit.assertEquals(titles[#titles], veaf.t("menu.campaign.reset"))
end

-- ---------------------------------------------------------------------------
-- The sitac's ranking, ejected pilots and task board (FIX-CAMPAIGN-THIRD-SERVER-FLIGHT 03 to 05)
-- ---------------------------------------------------------------------------
TestCampaignRanking = { setUp = setUpSuite, tearDown = tearDownSuite }

--- A kill of the unit `name` by Zip, the unit registered with its DCS attributes.
local function killOf(name, attributes, category)
  dcs_mocks.addUnit(name, { _attributes = attributes or {} })
  local event = kill("Zip", category)
  event.target.unitName = name
  return event
end

function TestCampaignRanking:test_each_kill_counts_under_its_foothold_category()
  start({ economy = { start_credits = 0 }, air = {} })
  veafCampaignEconomy.onKill(killOf("T-72"))
  veafCampaignEconomy.onKill(killOf("Soldier", { Infantry = true }))
  veafCampaignEconomy.onKill(killOf("SA-11 launcher", { ["SAM related"] = true }))
  veafCampaignEconomy.onKill(killOf("ZU-23", { ["Air Defence"] = true }))
  veafCampaignEconomy.onKill(killOf("MiG-29", {}, Unit.Category.AIRPLANE))
  veafCampaignEconomy.onKill(killOf("Mi-24", {}, Unit.Category.HELICOPTER))
  local zip = veafCampaignEconomy.sitacStats()["Zip"]
  luaunit.assertEquals(zip["Ground Units"], 1)
  luaunit.assertEquals(zip.Infantry, 1)
  luaunit.assertEquals(zip.SAM, 2)
  luaunit.assertEquals(zip.Air, 1)
  luaunit.assertEquals(zip.Helo, 1)
  luaunit.assertEquals(zip.Points, veafCampaignEconomy.pilots["Zip"].total)
end

function TestCampaignRanking:test_a_building_of_the_enemy_counts_as_a_structure()
  start({ economy = { start_credits = 0 }, air = {} })
  veafCampaign.structureIndex["Workshop 1"] = { zone = veafCampaign.zones["Senaki"], index = 1 }
  -- a static object: veafEventHandler cannot read its side, and calls it neutral
  local event = kill("Zip")
  event.target = { unitName = "Workshop 1", unitCoalition = coalition.side.NEUTRAL }
  veafCampaignEconomy.onKill(event)
  luaunit.assertEquals(veafCampaignEconomy.sitacStats()["Zip"].Structure, 1)
  -- one of ours, shot by mistake, is no score
  veafCampaign.structureIndex["Workshop 2"] = { zone = veafCampaign.zones["Kobuleti"], index = 1 }
  event.target = { unitName = "Workshop 2", unitCoalition = coalition.side.NEUTRAL }
  veafCampaignEconomy.onKill(event)
  luaunit.assertEquals(veafCampaignEconomy.sitacStats()["Zip"].Structure, 1)
end

function TestCampaignRanking:test_a_death_and_a_delivery_are_counted()
  start({ economy = { start_credits = 0 }, air = {} })
  veafCampaignEconomy.onPilotEvent({
    type = { id = world.event.S_EVENT_PILOT_DEAD },
    initiator = { unitName = "Zip's Hog" },
    dcsInitiator = unitAt({ x = 0 }, { player = "Zip" }),
  })
  veafCampaignEconomy.earnBy("Zip", 10, "campaign.credits.warehouse", "Kobuleti")
  local zip = veafCampaignEconomy.sitacStats()["Zip"]
  luaunit.assertEquals(zip.Deaths, 1)
  luaunit.assertEquals(zip["Warehouse delivery"], 1)
  luaunit.assertEquals(zip.Points, 10)
end

function TestCampaignRanking:test_the_team_is_no_pilot_and_the_figures_survive_a_restart()
  start({ economy = { start_credits = 0 }, air = {} })
  veafCampaignEconomy.onKill(killOf("T-72"))
  veafCampaign.notify("captured", veafCampaign.zones["Poti"], "blue")
  local before = veafCampaignEconomy.sitacStats()
  luaunit.assertNil(before[veafCampaignEconomy.TEAM])
  local saved = veafCampaign.serialize(veafCampaignEconomy.save())
  veafCampaignEconomy.pilots = {}
  veafCampaignEconomy.load(assert(loadstring("return " .. saved))())
  luaunit.assertEquals(veafCampaignEconomy.sitacStats(), before)
end

function TestCampaignRanking:test_the_credits_lost_at_an_ejection_are_remembered()
  start({ economy = { start_credits = 100 }, air = {} })
  veafCampaignEconomy.onKill(kill("Zip", Unit.Category.AIRPLANE))
  veafCampaignEconomy.onPilotEvent({ type = { id = world.event.S_EVENT_EJECTION }, initiator = { unitName = "Zip's Hog" } })
  luaunit.assertEquals(veafCampaignEconomy.lostAtEjection["Zip's Hog"], 25)
end

function TestCampaignRanking:test_the_board_is_listed_as_the_f10_menu_gives_it()
  start({ air = {}, tasks = { air_kills = 3 } })
  veafCampaignEconomy.refreshTasks()
  veafCampaignEconomy.onKill(kill("Zip", Unit.Category.AIRPLANE))
  local missions = veafCampaignEconomy.sitacTasks()
  luaunit.assertEquals(#missions, 2)
  luaunit.assertEquals(missions[1].title, veaf.t("campaign.task.capture", "Poti", 300))
  luaunit.assertTrue(missions[1].isRunning)
  luaunit.assertFalse(missions[1].isEscortMission)
  luaunit.assertEquals({ missions[1].kind, missions[1].zone, missions[1].reward }, { "capture", "Poti", 300 })
  luaunit.assertEquals(missions[2].kind, "air")
  luaunit.assertNil(missions[2].zone)
  luaunit.assertEquals(missions[2].description, "1/3")
end

-- ---------------------------------------------------------------------------
-- The assault order, a purchase open to every player (FIX-CAMPAIGN-ASSAULT-ORDER-OPEN)
-- ---------------------------------------------------------------------------
TestCampaignAssaultOrder = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignAssaultOrder:setUp()
  setUpSuite(self)
  self.savedSendConvoy = veafCampaign.sendConvoy
  self.sent = {}
  local this = self
  veafCampaign.sendConvoy = function(side, from, to, purchased)
    table.insert(this.sent, { side = side, from = from.name, to = to.name, purchased = purchased })
    return { side = side }
  end
end

function TestCampaignAssaultOrder:tearDown()
  veafCampaign.sendConvoy = self.savedSendConvoy
  tearDownSuite(self)
end

-- 2026-11-21: the entries were secured, a player without the VEAF password could not run them on the Campagne server
function TestCampaignAssaultOrder:test_the_entries_are_open_to_every_player()
  start({ economy = { start_credits = 500 } })
  local commands = veafCampaign.assaultPath.commands
  luaunit.assertTrue(#commands > 0)
  for _, command in ipairs(commands) do
    luaunit.assertFalse(command.isSecured, command.title)
    luaunit.assertEquals(command.usage, veafRadio.USAGE_ForAll, command.title)
  end
end

function TestCampaignAssaultOrder:test_the_menu_gives_the_price()
  start({ economy = { start_credits = 500, prices = { assault = 250 } } })
  luaunit.assertEquals(veafCampaign.assaultPath.title, veaf.t("menu.campaign.shop_item", veaf.t("menu.campaign.assault"), 250))
end

function TestCampaignAssaultOrder:test_an_order_is_paid_and_a_convoy_leaves()
  start({ economy = { start_credits = 500 } })
  local command = veafCampaign.assaultPath.commands[1]
  command.method(command.parameters)
  luaunit.assertEquals(self.sent, { { side = "blue", from = "Kobuleti", to = "Poti", purchased = true } })
  luaunit.assertEquals(veafCampaignEconomy.credits, 200)
end

function TestCampaignAssaultOrder:test_too_few_credits_send_nothing()
  start({ economy = { start_credits = 299 } })
  veafCampaign.orderAssault({ "Kobuleti", "Poti" })
  luaunit.assertEquals(self.sent, {})
  luaunit.assertEquals(veafCampaignEconomy.credits, 299)
end

-- ---------------------------------------------------------------------------
-- A ground kill whose target is already gone (FIX-CAMPAIGN-GROUND-KILLS-UNPAID 01)
-- ---------------------------------------------------------------------------
TestCampaignGroundKill = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignGroundKill:setUp()
  setUpSuite(self)
  self.descByName = Unit.getDescByName
  start({ economy = { start_credits = 0, landing_share = 0 }, air = {} })
end

function TestCampaignGroundKill:tearDown()
  Unit.getDescByName = self.descByName
  tearDownSuite(self)
end

--- A kill as the evening of 2026-11-21 handed it over: the target was no longer found by `Unit.getByName`, so its
--- data table says neutral with no category; `dcsTarget` is the raw DCS object, `raw` how it answers (nil: gone).
local function goneKill(name, raw)
  local event = kill("Zip")
  event.target = { unitName = name, unitCoalition = coalition.side.NEUTRAL }
  if raw then
    event.dcsTarget = {
      getName = function()
        return name
      end,
      getCoalition = function()
        return raw.side
      end,
      getDesc = function()
        return { category = raw.category or Unit.Category.GROUND_UNIT }
      end,
      getTypeName = function()
        return raw.type or "T-72B"
      end,
      hasAttribute = function(_, attribute)
        return (raw.attributes or {})[attribute] == true
      end,
    }
  else
    -- the object no longer answers anything
    event.dcsTarget = setmetatable({}, {
      __index = function()
        return function()
          error("the object is gone")
        end
      end,
    })
  end
  return event
end

function TestCampaignGroundKill:test_a_red_vehicle_gone_by_name_is_counted_and_paid()
  veafCampaignEconomy.onKill(goneKill("Red armor #1", { side = RED }))
  luaunit.assertEquals(veafCampaignEconomy.sitacStats()["Zip"]["Ground Units"], 1)
  luaunit.assertEquals(#loggedLines("CREDITS Zip +10 (kill)"), 1)
end

function TestCampaignGroundKill:test_the_held_share_is_held_as_for_any_kill()
  veafCampaign.data.dynamic.economy.landing_share = 50
  veafCampaignEconomy.onKill(goneKill("Red armor #1", { side = RED }))
  luaunit.assertEquals(#loggedLines("CREDITS Zip +5 (kill_held)"), 1)
end

function TestCampaignGroundKill:test_a_sam_gone_by_name_is_still_a_sam()
  veafCampaignEconomy.onKill(goneKill("Red SAM #1", { side = RED, attributes = { ["SAM related"] = true } }))
  luaunit.assertEquals(veafCampaignEconomy.sitacStats()["Zip"].SAM, 1)
  luaunit.assertEquals(#loggedLines("CREDITS Zip +30 (kill)"), 1)
end

function TestCampaignGroundKill:test_a_garrison_unit_found_by_the_campaign_alone_is_counted()
  -- nothing answers any more: the campaign's index says the unit stood in Senaki, which red holds
  Unit.getDescByName = function(typeName)
    return { attributes = typeName == "T-72B" and { ["Ground Units"] = true } or {} }
  end
  veafCampaign.unitIndex["Senaki garrison #1"] = { zone = veafCampaign.zones["Senaki"], group = 1, unit = 1 }
  veafCampaignEconomy.onKill(goneKill("Senaki garrison #1"))
  luaunit.assertEquals(veafCampaignEconomy.sitacStats()["Zip"]["Ground Units"], 1)
  luaunit.assertEquals(#loggedLines("CREDITS Zip +10 (kill)"), 1)
end

function TestCampaignGroundKill:test_the_last_unit_of_a_zone_is_paid_when_its_death_came_first()
  -- Zugdidi's garrison spawned; its units die one after the other, each death read before its kill: the last one
  -- turns the zone neutral and drops its garrison before its kill is read
  local zugdidi = veafCampaign.zones["Zugdidi"]
  zugdidi:spawnGroup(1)
  local names = {}
  for index in ipairs(zugdidi.entry.garrison[1].units) do
    table.insert(names, veafCampaign.unitName(zugdidi.entry.garrison[1], index))
  end
  for index, name in ipairs(names) do
    zugdidi:onUnitLost(1, index)
    veafCampaignEconomy.onKill(goneKill(name))
  end
  luaunit.assertEquals(zugdidi:getOwner(), "neutral")
  luaunit.assertEquals(veafCampaignEconomy.sitacStats()["Zip"]["Ground Units"], #names)
end

function TestCampaignGroundKill:test_a_garrison_sam_found_by_the_campaign_alone_is_a_sam()
  Unit.getDescByName = function(typeName)
    return { attributes = typeName == "SA-11 Buk LN 9A310M1" and { ["SAM related"] = true } or {} }
  end
  veafCampaign.zones["Senaki"].entry.garrison = garrison("Senaki", nil, { "SA-11 Buk LN 9A310M1" })
  veafCampaign.unitIndex["Senaki garrison #1"] = { zone = veafCampaign.zones["Senaki"], group = 1, unit = 1 }
  veafCampaignEconomy.onKill(goneKill("Senaki garrison #1"))
  luaunit.assertEquals(veafCampaignEconomy.sitacStats()["Zip"].SAM, 1)
end

function TestCampaignGroundKill:test_an_assault_convoy_found_by_the_campaign_alone_is_counted()
  table.insert(veafCampaign.convoys, { name = "Senaki - Poti assault", side = "red" })
  veafCampaignEconomy.onKill(goneKill("Senaki - Poti assault #3"))
  luaunit.assertEquals(veafCampaignEconomy.sitacStats()["Zip"]["Ground Units"], 1)
end

function TestCampaignGroundKill:test_the_hunter_counts_it_too()
  veafCampaign.data.dynamic.hunter = { enabled = true }
  veafCampaignOps.onKill(goneKill("Red armor #1", { side = RED }))
  luaunit.assertEquals(veafCampaignOps.hunted["Zip"].ground, 1)
end

function TestCampaignGroundKill:test_an_air_kill_is_still_paid()
  veafCampaignEconomy.onKill(kill("Zip", Unit.Category.AIRPLANE))
  luaunit.assertEquals(veafCampaignEconomy.sitacStats()["Zip"].Air, 1)
end

function TestCampaignGroundKill:test_a_truly_neutral_target_is_ignored()
  veafCampaignEconomy.onKill(goneKill("Civilian car #1", { side = coalition.side.NEUTRAL }))
  veafCampaignEconomy.onKill(goneKill("Unknown wreck #1"))
  luaunit.assertNil(veafCampaignEconomy.sitacStats()["Zip"])
end

function TestCampaignGroundKill:test_friendly_fire_is_ignored()
  veafCampaignEconomy.onKill(goneKill("Blue armor #1", { side = BLUE }))
  veafCampaign.unitIndex["Kobuleti garrison #1"] = { zone = veafCampaign.zones["Kobuleti"], group = 1, unit = 1 }
  veafCampaignEconomy.onKill(goneKill("Kobuleti garrison #1"))
  luaunit.assertNil(veafCampaignEconomy.sitacStats()["Zip"])
end

-- ---------------------------------------------------------------------------
-- Every pilot on the ranking, and the evening's summary (FIX-CAMPAIGN-GROUND-KILLS-UNPAID 02 and 03)
-- ---------------------------------------------------------------------------
TestCampaignEvening = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignEvening:setUp()
  setUpSuite(self)
  start({ economy = { start_credits = 0, landing_share = 0 }, air = {} })
end

--- A player's aircraft, named `name`, as coalition.getPlayers and an event's `dcsInitiator` hand it over.
local function playerAircraft(name, player, side)
  local unit = unitAt({ x = 0 }, { player = player, side = side or BLUE })
  unit.getName = function()
    return name
  end
  return unit
end

--- An event of a player's aircraft, in the shape veafEventHandler hands it over.
local function pilotEvent(id, unit)
  return { type = { id = id }, initiator = { unitName = unit:getName() }, dcsInitiator = unit }
end

function TestCampaignEvening:test_a_pilot_who_took_a_slot_is_on_the_ranking_with_zero()
  veafCampaignEconomy.onPlayerEnter(pilotEvent(world.event.S_EVENT_BIRTH, playerAircraft("Hog 1", "griffin")))
  luaunit.assertEquals(veafCampaignEconomy.sitacStats()["griffin"], { Points = 0 })
end

function TestCampaignEvening:test_a_gain_afterwards_adds_to_the_same_books()
  veafCampaignEconomy.onPlayerEnter(pilotEvent(world.event.S_EVENT_PLAYER_ENTER_UNIT, playerAircraft("Hog 1", "Zip")))
  veafCampaignEconomy.onKill(kill("Zip"))
  luaunit.assertEquals(veafCampaignEconomy.sitacStats()["Zip"].Points, 10)
  luaunit.assertEquals(veafCampaignEconomy.sitacStats()["Zip"]["Ground Units"], 1)
end

function TestCampaignEvening:test_an_enemy_pilot_and_an_ai_get_no_books()
  veafCampaignEconomy.onPlayerEnter(pilotEvent(world.event.S_EVENT_BIRTH, playerAircraft("Fulcrum 1", "Ivan", RED)))
  veafCampaignEconomy.onPlayerEnter(pilotEvent(world.event.S_EVENT_BIRTH, playerAircraft("Hog 2", nil)))
  luaunit.assertNil(next(veafCampaignEconomy.sitacStats()))
end

function TestCampaignEvening:test_the_last_player_leaving_writes_the_summary_at_once()
  local hog = playerAircraft("Hog 1", "Zip")
  coalition.getPlayers = function(side)
    return side == BLUE and { hog } or {}
  end
  veafCampaignEconomy.beat(100) -- a player in a slot: the session's books open
  veafCampaignEconomy.onKill(kill("Zip"))
  -- he quits the server from his cockpit; DCS pauses the mission at once, so no beat follows
  veafCampaignEconomy.onPlayerLeave(pilotEvent(world.event.S_EVENT_PLAYER_LEAVE_UNIT, hog))
  luaunit.assertEquals(#loggedLines("CREDITS SUMMARY (the last player left his slot): 10 earned by the side"), 1)
  luaunit.assertEquals(#loggedLines("ECONOMY SUMMARY (the last player left his slot)"), 1)
  -- said once: the beat that may come has nothing left to say
  coalition.getPlayers = function()
    return {}
  end
  veafCampaignEconomy.beat(200)
  luaunit.assertEquals(#loggedLines("SUMMARY (nobody left in a slot)"), 0)
end

function TestCampaignEvening:test_a_player_still_in_a_slot_keeps_the_session_open()
  local hog, viper = playerAircraft("Hog 1", "Zip"), playerAircraft("Viper 1", "Paluche")
  coalition.getPlayers = function(side)
    return side == BLUE and { hog, viper } or {}
  end
  veafCampaignEconomy.beat(100)
  veafCampaignEconomy.onKill(kill("Zip"))
  veafCampaignEconomy.onPlayerLeave(pilotEvent(world.event.S_EVENT_PLAYER_LEAVE_UNIT, hog))
  veafCampaignEconomy.onPlayerLeave(pilotEvent(world.event.S_EVENT_PILOT_DEAD, hog))
  luaunit.assertEquals(#loggedLines("SUMMARY"), 0)
  luaunit.assertNotNil(veafCampaignEconomy.ledger)
end

function TestCampaignEvening:test_the_last_pilot_dead_writes_the_summary_too()
  local hog = playerAircraft("Hog 1", "Zip")
  coalition.getPlayers = function(side)
    return side == BLUE and { hog } or {}
  end
  veafCampaignEconomy.beat(100)
  veafCampaignEconomy.onKill(kill("Zip"))
  veafCampaignEconomy.onPlayerLeave(pilotEvent(world.event.S_EVENT_PILOT_DEAD, hog))
  luaunit.assertEquals(#loggedLines("CREDITS SUMMARY (the last player left his slot)"), 1)
end

os.exit(luaunit.LuaUnit.run())
