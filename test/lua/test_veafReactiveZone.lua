--- Tests for veafReactiveZone.lua — the base shared by veafQraCore and veafAirWaves
--- (FEAT-AIRWAVES-QRA-MERGE): where a zone is, who is in it, what it spawns, what it depends on.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
dofile(src .. "/veafDcsSpawner.lua")
dofile(src .. "/dcsUnits.lua")
dofile(src .. "/veafI18n.lua")
dofile(src .. "/veafGrass.lua")
dofile(src .. "/veafSpawn.lua")
dofile(src .. "/veafReactiveZone.lua")

--- A bare zone object, carrying the fields the base reads.
local function newZone(fields)
  local zone = {
    name = "Zone",
    respawnDefaultOffset = { latDelta = 0, lonDelta = 0 },
    respawnRadius = 0,
    minimumAltitude = -999999,
    maximumAltitude = 999999,
    links = {},
  }
  for key, value in pairs(fields or {}) do
    zone[key] = value
  end
  zone.getName = function(self)
    return self.name
  end
  return zone
end

--- A unit that is alive (life 10) and stands at the given runtime point.
local function liveUnit(name, point, extra)
  local data = extra or {}
  data.getPoint = function()
    return point
  end
  data.getLife = data.getLife or function()
    return 10
  end
  dcs_mocks.addUnit(name, data)
  return Unit.getByName(name)
end

-- ---------------------------------------------------------------------------
-- Where the zone is
-- ---------------------------------------------------------------------------
TestReactiveZoneCenter = {}

function TestReactiveZoneCenter:setUp()
  dcs_mocks.reset()
  veafMissionDb.unitsById = {}
end

function TestReactiveZoneCenter:tearDown()
  veaf.triggerZones["RZ-Zone"] = nil
  veafMissionDb.unitsById = {}
end

function TestReactiveZoneCenter:test_a_trigger_zone_is_converted_to_a_runtime_vec3()
  -- the mission-table easting is `y`; at runtime it is `z`, and a trigger zone has no altitude
  veaf.triggerZones["RZ-Zone"] = { x = 77, y = 88, radius = 500 }
  local center = veafReactiveZone.getCenter(newZone({ triggerZoneName = "RZ-Zone" }))
  luaunit.assertEquals(center, { x = 77, y = 0, z = 88 })
end

function TestReactiveZoneCenter:test_a_configured_centre_keeps_its_own_altitude()
  local center = veafReactiveZone.getCenter(newZone({ zoneCenter = { x = 1000, y = 1500, z = 2000 } }))
  luaunit.assertEquals(center, { x = 1000, y = 1500, z = 2000 })
end

function TestReactiveZoneCenter:test_no_trigger_zone_and_no_centre_answers_nil()
  luaunit.assertNil(veafReactiveZone.getCenter(newZone({ triggerZoneName = "RZ-Missing" })))
end

function TestReactiveZoneCenter:test_a_zone_follows_the_unit_it_names()
  local point = { x = 100, y = 20, z = 200 }
  liveUnit("CVN-74", point)
  local zone = newZone({ zoneCenter = { x = 0, y = 0, z = 0 }, zoneRadius = 9000, followUnitName = "CVN-74" })
  luaunit.assertEquals(veafReactiveZone.getCenter(zone), { x = 100, y = 0, z = 200 })
  -- the carrier sails on: the zone goes with it
  point.x, point.z = 5100, 3200
  luaunit.assertEquals(veafReactiveZone.getCenter(zone), { x = 5100, y = 0, z = 3200 })
end

function TestReactiveZoneCenter:test_a_trigger_zone_linked_in_the_editor_follows_its_unit()
  liveUnit("Tarawa", { x = 4000, y = 0, z = 6000 })
  veafMissionDb.unitsById[42] = { unitName = "Tarawa", unitId = 42 }
  veaf.triggerZones["RZ-Zone"] = { x = 77, y = 88, radius = 3000, linkUnit = 42 }
  local zone = newZone({ triggerZoneName = "RZ-Zone" })
  luaunit.assertTrue(veafReactiveZone.isMobile(zone))
  luaunit.assertEquals(veafReactiveZone.getCenter(zone), { x = 4000, y = 0, z = 6000 }, "the unit, not where the zone was drawn")
  luaunit.assertEquals(veafReactiveZone.getRadius(zone), 3000, "the radius stays the trigger zone's")
end

function TestReactiveZoneCenter:test_a_dead_followed_unit_leaves_the_zone_where_it_last_was()
  liveUnit("CVN-74", { x = 100, y = 0, z = 200 })
  local zone = newZone({ zoneCenter = { x = 0, y = 0, z = 0 }, zoneRadius = 9000, followUnitName = "CVN-74" })
  veafReactiveZone.getCenter(zone)
  dcs_mocks.removeUnit("CVN-74")
  luaunit.assertEquals(veafReactiveZone.getCenter(zone), { x = 100, y = 0, z = 200 })
end

-- ---------------------------------------------------------------------------
-- Who is in the zone
-- ---------------------------------------------------------------------------
TestReactiveZoneUnits = {}

function TestReactiveZoneUnits:setUp()
  dcs_mocks.reset()
end

function TestReactiveZoneUnits:test_a_mobile_zone_looks_around_its_current_centre()
  liveUnit("CVN-74", { x = 50000, y = 0, z = 50000 })
  local zone = newZone({ zoneCenter = { x = 0, y = 0, z = 0 }, zoneRadius = 9000, followUnitName = "CVN-74" })
  local asked = nil
  local original = veaf.findUnitsInCircle
  veaf.findUnitsInCircle = function(center, radius, _, _)
    asked = { center = center, radius = radius }
    return {}
  end
  veafReactiveZone.findUnitsInZone(zone, { "Pilot" })
  veaf.findUnitsInCircle = original
  luaunit.assertEquals(asked, { center = { x = 50000, y = 0, z = 50000 }, radius = 9000 })
end

function TestReactiveZoneUnits:test_a_zone_with_no_geometry_answers_nil()
  luaunit.assertNil(veafReactiveZone.findUnitsInZone(newZone({}), {}))
end

function TestReactiveZoneUnits:test_only_airborne_units_between_floor_and_ceiling_count()
  local zone = newZone({ minimumAltitude = 100, maximumAltitude = 5000 })
  local inAir = function()
    return true
  end
  local units = {
    liveUnit("low", { x = 0, y = 50, z = 0 }, { inAir = inAir }),
    liveUnit("good", { x = 0, y = 2000, z = 0 }, { inAir = inAir }),
    liveUnit("high", { x = 0, y = 9000, z = 0 }, { inAir = inAir }),
    liveUnit("parked", { x = 0, y = 2000, z = 0 }),
  }
  local result = veafReactiveZone.filterAirborne(zone, units)
  luaunit.assertEquals(#result, 1)
  luaunit.assertEquals(result[1]:getName(), "good")
end

-- ---------------------------------------------------------------------------
-- What the zone spawns
-- ---------------------------------------------------------------------------
TestReactiveZoneDeploy = {}

function TestReactiveZoneDeploy:setUp()
  dcs_mocks.reset()
  self._savedInterpreter = veafInterpreter
  self.executed = {}
  local executed = self.executed
  veafInterpreter = veafInterpreter or {}
  veafInterpreter.execute = function(command, position, side, _, _)
    table.insert(executed, { command = command, position = position, side = side })
  end
end

function TestReactiveZoneDeploy:tearDown()
  veafInterpreter = self._savedInterpreter
  veaf.triggerZones["RZ-Gone"] = nil
end

function TestReactiveZoneDeploy:test_a_command_is_handed_the_side_it_was_given()
  local zone = newZone({ zoneCenter = { x = 0, y = 0, z = 0 } })
  veafReactiveZone.deployGroups(zone, { "-sa2" }, coalition.side.BLUE)
  luaunit.assertEquals(#self.executed, 1)
  luaunit.assertEquals(self.executed[1].side, coalition.side.BLUE)
end

function TestReactiveZoneDeploy:test_a_missing_zone_and_no_centre_spawns_nothing_and_does_not_raise()
  -- VMR-085's twin: the QRA read `triggerZone.x` on a zone that does not exist
  local zone = newZone({ triggerZoneName = "RZ-Gone" })
  local spawned = veafReactiveZone.deployGroups(zone, { "-sa2", "Editor group" }, coalition.side.RED)
  luaunit.assertEquals(spawned, {})
  luaunit.assertEquals(#self.executed, 0)
end

function TestReactiveZoneDeploy:test_a_mobile_zone_spawns_around_the_unit()
  liveUnit("CVN-74", { x = 40000, y = 0, z = 30000 })
  local zone = newZone({ zoneCenter = { x = 0, y = 0, z = 0 }, zoneRadius = 9000, followUnitName = "CVN-74" })
  veafReactiveZone.deployGroups(zone, { "[1000,0]-cap" }, coalition.side.RED)
  luaunit.assertEquals(self.executed[1].position.x, 41000)
  luaunit.assertEquals(self.executed[1].position.z, 30000)
end

function TestReactiveZoneDeploy:test_an_unknown_editor_group_spawns_nothing()
  local zone = newZone({ zoneCenter = { x = 0, y = 0, z = 0 } })
  luaunit.assertEquals(veafReactiveZone.deployGroups(zone, { "Nobody" }, coalition.side.RED), {})
end

TestReactiveZonePick = {}

function TestReactiveZonePick:test_draws_the_number_asked()
  luaunit.assertEquals(#veafReactiveZone.pickGroups({ "a", "b" }, 3, 0), 3)
end

function TestReactiveZonePick:test_a_plain_list_comes_back_unchanged()
  luaunit.assertEquals(veafReactiveZone.pickGroups({ "a", "b" }, nil, nil), { "a", "b" })
end

function TestReactiveZonePick:test_a_distinct_draw_never_repeats_a_group()
  -- the mocks' draw answers 0 every time
  local picked = veafReactiveZone.pickDistinctGroups({ "a", "b", "c" }, 3, 0)
  table.sort(picked)
  luaunit.assertEquals(picked, { "a", "b", "c" })
end

function TestReactiveZonePick:test_a_distinct_draw_stops_at_the_size_of_the_list()
  luaunit.assertEquals(#veafReactiveZone.pickDistinctGroups({ "a", "b" }, 5, 0), 2)
end

function TestReactiveZonePick:test_a_distinct_draw_leaves_the_list_untouched()
  local groups = { "a", "b" }
  veafReactiveZone.pickDistinctGroups(groups, 2, 0)
  luaunit.assertEquals(groups, { "a", "b" })
end

function TestReactiveZonePick:test_a_distinct_draw_of_a_plain_list_comes_back_unchanged()
  luaunit.assertEquals(veafReactiveZone.pickDistinctGroups({ "a", "b" }, nil, nil), { "a", "b" })
end

-- ---------------------------------------------------------------------------
-- Groups alive or dead
-- ---------------------------------------------------------------------------
TestReactiveZoneGroupsDead = {}

function TestReactiveZoneGroupsDead:setUp()
  dcs_mocks.reset()
end

local function groupOf(name, lives)
  dcs_mocks.addGroup(name, {
    getUnits = function()
      local units = {}
      for i, life in ipairs(lives) do
        table.insert(units, {
          isExist = function()
            return true
          end,
          getLife = function()
            return life
          end,
          getName = function()
            return name .. "-" .. i
          end,
        })
      end
      return units
    end,
  })
end

function TestReactiveZoneGroupsDead:test_one_unit_alive_keeps_the_list_alive()
  groupOf("A", { 0 })
  groupOf("B", { 0, 5 })
  luaunit.assertFalse(veafReactiveZone.areGroupsDead({ "A", "B" }))
end

function TestReactiveZoneGroupsDead:test_wrecks_and_vanished_groups_are_dead()
  groupOf("A", { 0 })
  luaunit.assertTrue(veafReactiveZone.areGroupsDead({ "A", "Vanished" }))
end

-- ---------------------------------------------------------------------------
-- What the zone depends on (#183)
-- ---------------------------------------------------------------------------
TestReactiveZoneLinks = {}

function TestReactiveZoneLinks:setUp()
  dcs_mocks.reset()
  self._savedAirbaseGetByName = Airbase.getByName
  self._savedLife = veaf.getAirbaseLife
  self._savedStaticGetByName = StaticObject.getByName
  self.airbases = {}
  local airbases = self.airbases
  Airbase.getByName = function(name)
    return airbases[name]
  end
  self.life = 1
  veaf.getAirbaseLife = function(_, _)
    return self.life
  end
end

function TestReactiveZoneLinks:tearDown()
  Airbase.getByName = self._savedAirbaseGetByName
  veaf.getAirbaseLife = self._savedLife
  StaticObject.getByName = self._savedStaticGetByName
end

function TestReactiveZoneLinks:_airbase(name, side, category)
  local exists = true
  self.airbases[name] = {
    getCoalition = function()
      return side
    end,
    getDesc = function()
      return { category = category or Airbase.Category.AIRDROME }
    end,
    isExist = function()
      return exists
    end,
  }
end

function TestReactiveZoneLinks:test_no_links_is_ok()
  luaunit.assertEquals(veafReactiveZone.checkLinks(newZone({}), coalition.side.RED, 0.9), veafReactiveZone.LINKS_OK)
end

function TestReactiveZoneLinks:test_an_airbase_held_and_intact_is_ok()
  self:_airbase("Maykop", coalition.side.RED)
  local zone = newZone({ links = { "Maykop" } })
  luaunit.assertEquals(veafReactiveZone.checkLinks(zone, coalition.side.RED, 0.9), veafReactiveZone.LINKS_OK)
end

function TestReactiveZoneLinks:test_a_captured_airbase_pauses_and_a_retaken_one_resumes()
  self:_airbase("Maykop", coalition.side.BLUE)
  local zone = newZone({ links = { "Maykop" } })
  local state, culprit = veafReactiveZone.checkLinks(zone, coalition.side.RED, 0.9)
  luaunit.assertEquals(state, veafReactiveZone.LINKS_PAUSED)
  luaunit.assertEquals(culprit, "Maykop")
  self:_airbase("Maykop", coalition.side.RED)
  luaunit.assertEquals(veafReactiveZone.checkLinks(zone, coalition.side.RED, 0.9), veafReactiveZone.LINKS_OK)
end

function TestReactiveZoneLinks:test_a_damaged_airbase_pauses()
  self:_airbase("Maykop", coalition.side.RED)
  self.life = 0.5
  local zone = newZone({ links = { "Maykop" } })
  luaunit.assertEquals(veafReactiveZone.checkLinks(zone, coalition.side.RED, 0.9), veafReactiveZone.LINKS_PAUSED)
end

function TestReactiveZoneLinks:test_a_sunk_ship_is_lost_for_good()
  self:_airbase("Kuznetsov", coalition.side.RED, Airbase.Category.SHIP)
  local zone = newZone({ links = { "Kuznetsov" } })
  luaunit.assertEquals(veafReactiveZone.checkLinks(zone, coalition.side.RED, 0.9), veafReactiveZone.LINKS_OK)
  -- sunk: nothing answers to its name any more, and it must still be known as a ship
  self.airbases["Kuznetsov"] = nil
  luaunit.assertEquals(veafReactiveZone.checkLinks(zone, coalition.side.RED, 0.9), veafReactiveZone.LINKS_LOST)
end

function TestReactiveZoneLinks:test_a_destroyed_group_is_lost_for_good()
  groupOf("SA-10 site", { 10 })
  local zone = newZone({ links = { "SA-10 site" } })
  luaunit.assertEquals(veafReactiveZone.checkLinks(zone, coalition.side.RED, 0.9), veafReactiveZone.LINKS_OK)
  dcs_mocks.removeGroup("SA-10 site")
  luaunit.assertEquals(veafReactiveZone.checkLinks(zone, coalition.side.RED, 0.9), veafReactiveZone.LINKS_LOST)
end

function TestReactiveZoneLinks:test_a_destroyed_static_is_lost_for_good()
  local life = 100
  local static = {
    isExist = function()
      return true
    end,
    getLife = function()
      return life
    end,
  }
  StaticObject.getByName = function(name)
    return name == "Command post" and static or nil
  end
  local zone = newZone({ links = { "Command post" } })
  luaunit.assertEquals(veafReactiveZone.checkLinks(zone, coalition.side.RED, 0.9), veafReactiveZone.LINKS_OK)
  life = 0
  luaunit.assertEquals(veafReactiveZone.checkLinks(zone, coalition.side.RED, 0.9), veafReactiveZone.LINKS_LOST)
end

function TestReactiveZoneLinks:test_one_lost_link_wins_over_a_paused_one()
  self:_airbase("Maykop", coalition.side.BLUE)
  groupOf("SA-10 site", { 10 })
  local zone = newZone({ links = { "Maykop", "SA-10 site" } })
  veafReactiveZone.checkLinks(zone, coalition.side.RED, 0.9)
  dcs_mocks.removeGroup("SA-10 site")
  local state, culprit = veafReactiveZone.checkLinks(zone, coalition.side.RED, 0.9)
  luaunit.assertEquals(state, veafReactiveZone.LINKS_LOST)
  luaunit.assertEquals(culprit, "SA-10 site")
end

function TestReactiveZoneLinks:test_a_name_nothing_answers_to_is_ignored_not_fatal()
  local zone = newZone({ links = { "Typo" } })
  luaunit.assertEquals(veafReactiveZone.checkLinks(zone, coalition.side.RED, 0.9), veafReactiveZone.LINKS_OK)
end

-- ---------------------------------------------------------------------------
-- #1078: a command that spawns later (`delayed`, `repeat`) is still heard
-- ---------------------------------------------------------------------------
TestReactiveZoneDeferredSpawn = {}

function TestReactiveZoneDeferredSpawn:setUp()
  dcs_mocks.reset()
  self._savedInterpreter = veafInterpreter
  self.later = {}
  local later = self.later
  veafInterpreter = veafInterpreter or {}
  -- what `veafSpawn.executeCommand` does with a start delay: accept the command, spawn nothing yet
  veafInterpreter.execute = function(_, _, _, _, spawnedGroups)
    table.insert(later, function(name)
      veaf.collectSpawnedGroup(spawnedGroups, name)
    end)
    return true
  end
  self._savedDefend = veafAircraftSpawn.defendZoneWithCaps
  self.defended = {}
  veafAircraftSpawn.defendZoneWithCaps = function(names, _)
    for _, name in pairs(names) do
      table.insert(self.defended, name)
    end
  end
end

function TestReactiveZoneDeferredSpawn:tearDown()
  veafInterpreter = self._savedInterpreter
  veafAircraftSpawn.defendZoneWithCaps = self._savedDefend
end

function TestReactiveZoneDeferredSpawn:test_a_group_spawned_later_lands_in_the_list_and_defends_the_zone()
  local zone = newZone({ zoneCenter = { x = 0, y = 0, z = 0 }, zoneRadius = 9000 })
  local spawned = veafReactiveZone.deployGroups(zone, { "-cap mig29, delayed 30" }, coalition.side.RED)
  luaunit.assertEquals(spawned, {}, "nothing yet")
  luaunit.assertTrue(veafReactiveZone.hasPendingSpawns(spawned), "but something is expected")
  self.later[1]("CAP #0001")
  luaunit.assertEquals(spawned, { "CAP #0001" })
  luaunit.assertEquals(self.defended, { "CAP #0001" })
  luaunit.assertFalse(veafReactiveZone.hasPendingSpawns(spawned))
end

function TestReactiveZoneDeferredSpawn:test_every_repeat_is_heard()
  local zone = newZone({ zoneCenter = { x = 0, y = 0, z = 0 } })
  local spawned = veafReactiveZone.deployGroups(zone, { "-cap mig29, repeat 2" }, coalition.side.RED)
  self.later[1]("CAP #0001")
  self.later[1]("CAP #0002")
  luaunit.assertEquals(spawned, { "CAP #0001", "CAP #0002" })
end

function TestReactiveZoneDeferredSpawn:test_a_group_arriving_after_its_wave_ended_is_destroyed()
  local destroyed = false
  dcs_mocks.addGroup("CAP #0001", {
    destroy = function()
      destroyed = true
    end,
  })
  local zone = newZone({ zoneCenter = { x = 0, y = 0, z = 0 } })
  local spawned = veafReactiveZone.deployGroups(zone, { "-cap mig29, delayed 30" }, coalition.side.RED)
  veafReactiveZone.destroyGroups(spawned) -- the wave ended, the QRA re-armed
  luaunit.assertFalse(veafReactiveZone.hasPendingSpawns(spawned))
  self.later[1]("CAP #0001")
  luaunit.assertTrue(destroyed, "nothing would ever destroy it otherwise")
  luaunit.assertEquals(spawned, {})
end

function TestReactiveZoneDeferredSpawn:test_a_deferred_spawn_that_never_comes_is_not_waited_for_ever()
  local zone = newZone({ zoneCenter = { x = 0, y = 0, z = 0 } })
  local spawned = veafReactiveZone.deployGroups(zone, { "-cap mig29, delayed 30" }, coalition.side.RED)
  dcs_mocks.currentTime = dcs_mocks.currentTime + veafReactiveZone.PENDING_SPAWN_TIMEOUT + 1
  luaunit.assertFalse(veafReactiveZone.hasPendingSpawns(spawned))
end

function TestReactiveZoneDeferredSpawn:test_a_refused_command_is_not_waited_for()
  veafInterpreter.execute = function()
    return false
  end
  local zone = newZone({ zoneCenter = { x = 0, y = 0, z = 0 } })
  luaunit.assertFalse(veafReactiveZone.hasPendingSpawns(veafReactiveZone.deployGroups(zone, { "-typo" }, coalition.side.RED)))
end

-- ---------------------------------------------------------------------------
-- Review of the lot: what is waited for, what is reported, where a linked zone sits
-- ---------------------------------------------------------------------------
TestReactiveZoneReview = {}

function TestReactiveZoneReview:setUp()
  dcs_mocks.reset()
  self._savedInterpreter = veafInterpreter
  veafMissionDb.unitsById = {}
end

function TestReactiveZoneReview:tearDown()
  veafInterpreter = self._savedInterpreter
  veaf.triggerZones["RZ-Linked"] = nil
  veafMissionDb.unitsById = {}
end

function TestReactiveZoneReview:test_only_the_delayed_keyword_defers_a_command()
  luaunit.assertTrue(veafReactiveZone.isDeferredCommand("-sa6, delayed 30"))
  luaunit.assertTrue(veafReactiveZone.isDeferredCommand("[0,0]-spawn su-27, DELAYED"))
  luaunit.assertFalse(veafReactiveZone.isDeferredCommand("-cap f15, repeat 2"), "repeat spawns its first group at once")
  luaunit.assertFalse(veafReactiveZone.isDeferredCommand("-cap delayedfighter"), "a word that merely contains it")
end

function TestReactiveZoneReview:test_an_accepted_command_that_spawned_nothing_is_not_waited_for()
  -- a spawn that failed inside a handler still returning true: waiting would hold the zone 10 min
  veafInterpreter = veafInterpreter or {}
  veafInterpreter.execute = function()
    return true
  end
  local zone = newZone({ zoneCenter = { x = 0, y = 0, z = 0 } })
  luaunit.assertFalse(veafReactiveZone.hasPendingSpawns(veafReactiveZone.deployGroups(zone, { "-cap f15" }, coalition.side.RED)))
end

function TestReactiveZoneReview:test_a_linked_trigger_zone_keeps_its_offset_from_the_unit()
  -- drawn 20 km north of the carrier in the editor, it stays 20 km north of it at sea
  veafMissionDb.unitsById[7] = { unitName = "CVN-74", unitId = 7, x = 1000, y = 2000 }
  veaf.triggerZones["RZ-Linked"] = { x = 21000, y = 2000, radius = 9000, linkUnit = 7 }
  liveUnit("CVN-74", { x = 50000, y = 0, z = 60000 })
  local center = veafReactiveZone.getCenter(newZone({ triggerZoneName = "RZ-Linked" }))
  luaunit.assertEquals(center, { x = 70000, y = 0, z = 60000 })
end

function TestReactiveZoneReview:test_a_zone_with_no_geometry_says_so_once()
  local zone = newZone({})
  local errors = 0
  local logger = veaf.loggers.get(veafReactiveZone.Id)
  local original = logger.error
  logger.error = function()
    errors = errors + 1
  end
  for _ = 1, 3 do
    veafReactiveZone.findUnitsInZone(zone, {})
  end
  logger.error = original
  luaunit.assertEquals(errors, 1)
end

function TestReactiveZoneReview:test_a_link_spawned_after_the_start_is_found_later()
  local zone = newZone({ links = { "FOB-1" } })
  luaunit.assertEquals(veafReactiveZone.checkLinks(zone, coalition.side.RED, 0.9), veafReactiveZone.LINKS_OK)
  -- the FOB appears, then is destroyed
  groupOf("FOB-1", { 10 })
  veafReactiveZone.checkLinks(zone, coalition.side.RED, 0.9)
  dcs_mocks.removeGroup("FOB-1")
  luaunit.assertEquals(veafReactiveZone.checkLinks(zone, coalition.side.RED, 0.9), veafReactiveZone.LINKS_LOST)
end

os.exit(luaunit.LuaUnit.run())
