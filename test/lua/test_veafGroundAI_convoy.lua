--- Tests for the convoy watch of veafGroundAI.lua (FEAT-CONVOY-UNDER-FIRE).
---
--- What DCS does was measured in game on 2026-10-08 (the lot's PRD); these tests pin what the handler
--- does with it: when it reacts, how it splits, what it hands the controllers, what it says.
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
dofile(src .. "/veafI18n.lua")
dofile(src .. "/veafGroundAI.lua")

local BLUE, RED = coalition.side.BLUE, coalition.side.RED

local TANK = { ["Tanks"] = true, ["Armed ground units"] = true }
local IFV = { ["IFV"] = true, ["Armed vehicles"] = true, ["Armed ground units"] = true }
local APC = { ["APC"] = true, ["Armed vehicles"] = true, ["Armed ground units"] = true }
local AAA = { ["AAA"] = true }
local INFANTRY = { ["Armed ground units"] = true, ["Infantry"] = true }
local TRUCK = { ["Unarmed vehicles"] = true, ["Trucks"] = true }

--- A ground unit double. `opts.point` is a vec3; everything else has a default.
local function makeUnit(name, opts)
  opts = opts or {}
  dcs_mocks.addUnit(name, {
    _attributes = opts.attributes or TRUCK,
    _categoryEx = opts.categoryEx or Unit.Category.GROUND_UNIT,
    _heading = opts.heading or 0,
    _destroyed = false,
    getPoint = function()
      return opts.point or { x = 0, y = 0, z = 0 }
    end,
    getCoalition = function()
      return opts.side or BLUE
    end,
    getVelocity = function()
      return opts.velocity or { x = 0, y = 0, z = 0 }
    end,
    getLife = function()
      return opts.life or 3
    end,
    getTypeName = function()
      return opts.type or "M 818"
    end,
    getCountry = function()
      return opts.country or 2
    end,
    destroy = function(self)
      self._destroyed = true
    end,
  })
  return Unit.getByName(name)
end

--- A ground group double holding these units.
local function makeGroup(name, units, side)
  dcs_mocks.addGroup(name, {
    getUnits = function()
      return units
    end,
    getCoalition = function()
      return side or BLUE
    end,
  })
  local group = Group.getByName(name)
  for _, unit in ipairs(units) do
    unit.getGroup = function()
      return group
    end
  end
  return group
end

local function countMessages(needle)
  return #dcs_mocks.messagesContaining(needle)
end

local function optionsFor(groupName)
  local found = {}
  for _, option in ipairs(dcs_mocks.optionsSet) do
    if option.group == groupName then
      found[option.id] = option.value
    end
  end
  return found
end

local function tasksPushedTo(groupName, id)
  local count = 0
  for _, pushed in ipairs(dcs_mocks.tasksPushed) do
    if pushed.group == groupName and pushed.task.id == id then
      count = count + 1
    end
  end
  return count
end

local function lastTaskSetOn(groupName)
  local last = nil
  for _, set in ipairs(dcs_mocks.tasksSet) do
    if set.group == groupName then
      last = set.task
    end
  end
  return last
end

--- Shared set-up: a clean mock world, the static `Unit.getPosition` `veaf.getAveragePosition` calls, and
--- the convoy registry emptied.
local function resetWorld()
  dcs_mocks.reset()
  Unit.getPosition = function(unit)
    return unit:getPosition()
  end
  veafGroundAI.handlers = {}
  veafGroundAI.convoysByGroupName = {}
  veafGroundAI.convoyObjectives = {}
  veafGroundAI._townPoints = {}
  veaf.config.language = "en"
end

-- ---------------------------------------------------------------------------
-- The pure helpers
-- ---------------------------------------------------------------------------
TestConvoyHelpers = {}

function TestConvoyHelpers:setUp()
  resetWorld()
end

function TestConvoyHelpers:test_the_watch_radius_grows_with_the_speed()
  luaunit.assertEquals(veafGroundAI.convoyWatchRadius(0), 5000)
  -- 40 km/h is ~11 m/s: a minute of driving more
  luaunit.assertEquals(veafGroundAI.convoyWatchRadius(11), 5660)
end

function TestConvoyHelpers:test_strength_by_attribute()
  luaunit.assertEquals(veafGroundAI.unitStrength(makeUnit("tank", { attributes = TANK })), 4)
  luaunit.assertEquals(veafGroundAI.unitStrength(makeUnit("ifv", { attributes = IFV })), 3)
  luaunit.assertEquals(veafGroundAI.unitStrength(makeUnit("apc", { attributes = APC })), 1)
  luaunit.assertEquals(veafGroundAI.unitStrength(makeUnit("aaa", { attributes = AAA })), 1)
  luaunit.assertEquals(veafGroundAI.unitStrength(makeUnit("inf", { attributes = INFANTRY })), 1)
  luaunit.assertEquals(veafGroundAI.unitStrength(makeUnit("truck", { attributes = TRUCK })), 0)
end

function TestConvoyHelpers:test_fight_or_flee()
  luaunit.assertTrue(veafGroundAI.convoyShouldFight(7, 4), "7 against 4 is at least 1.5 times")
  luaunit.assertFalse(veafGroundAI.convoyShouldFight(5, 4), "5 against 4 is not")
  luaunit.assertTrue(veafGroundAI.convoyShouldFight(3, 0), "armed vehicles facing nothing armed stand")
  luaunit.assertFalse(veafGroundAI.convoyShouldFight(0, 0), "nothing armed never fights")
  luaunit.assertFalse(veafGroundAI.convoyShouldFight(20, math.huge), "an aircraft cannot be fought")
end

function TestConvoyHelpers:test_living_ground_unit_of_a_side()
  luaunit.assertTrue(veafGroundAI.isLivingGroundUnitOf(makeUnit("bmp", { side = RED }), RED))
  luaunit.assertFalse(
    veafGroundAI.isLivingGroundUnitOf(makeUnit("wreck", { side = RED, life = 0 }), RED),
    "a wreck searchObjects still returns"
  )
  luaunit.assertFalse(veafGroundAI.isLivingGroundUnitOf(makeUnit("friend", { side = BLUE }), RED))
  luaunit.assertFalse(veafGroundAI.isLivingGroundUnitOf(makeUnit("jet", { side = RED, categoryEx = Unit.Category.AIRPLANE }), RED))
  local released = makeUnit("released", { side = RED })
  released.isExist = function()
    error("released object")
  end
  luaunit.assertFalse(veafGroundAI.isLivingGroundUnitOf(released, RED), "an object DCS released mid-read is no unit")
end

function TestConvoyHelpers:test_a_town_on_the_line_masks_the_point()
  veafGroundAI._townPoints = { { x = 1000, y = 0, z = 50 } }
  luaunit.assertTrue(veafGroundAI.townBetween({ x = 0, z = 0 }, { x = 2000, z = 0 }))
  veafGroundAI._townPoints = { { x = 1000, y = 0, z = 1000 } }
  luaunit.assertFalse(veafGroundAI.townBetween({ x = 0, z = 0 }, { x = 2000, z = 0 }), "a town off the line")
  veafGroundAI._townPoints = { { x = 100, y = 0, z = 0 } }
  luaunit.assertFalse(veafGroundAI.townBetween({ x = 0, z = 0 }, { x = 2000, z = 0 }), "a town the enemy stands in")
end

function TestConvoyHelpers:test_the_rally_point_goes_behind_the_ridge()
  -- The enemy 2 km north; a ridge hides everything west of z = -500 from it.
  dcs_mocks.visibilityAnswer = function(from, to)
    return to.z > -500
  end
  local rally, masked = veafGroundAI.chooseRallyPoint({ x = 0, y = 0, z = 0 }, { { x = 2000, y = 0, z = 0 } }, nil)
  luaunit.assertTrue(masked)
  luaunit.assertTrue(rally.z <= -500, "the rally point is behind the ridge: z=" .. rally.z)
  luaunit.assertTrue(rally.x <= 0, "and away from the enemy, not toward it: x=" .. rally.x)
end

function TestConvoyHelpers:test_the_rally_point_leans_toward_the_friendly_place()
  -- Everything is hidden: the cheapest drive there plus on to the airbase, south-east, wins.
  dcs_mocks.visibilityAnswer = false
  local rally = veafGroundAI.chooseRallyPoint({ x = 0, y = 0, z = 0 }, { { x = 2000, y = 0, z = 0 } }, { x = -10000, y = 0, z = 10000 })
  luaunit.assertTrue(rally.z > 0 and rally.x < 0, "toward the airbase: x=" .. rally.x .. " z=" .. rally.z)
end

function TestConvoyHelpers:test_no_cover_means_straight_out_of_range()
  dcs_mocks.visibilityAnswer = true
  -- 2 km from the threat: out of its 3 km range plus margin is 1.5 km further, straight away (south).
  local rally, masked = veafGroundAI.chooseRallyPoint({ x = 0, y = 0, z = 0 }, { { x = 2000, y = 0, z = 0 } }, nil)
  luaunit.assertFalse(masked)
  local distanceFromThreat = math.sqrt((rally.x - 2000) ^ 2 + rally.z ^ 2)
  luaunit.assertTrue(distanceFromThreat >= ConvoyUnitHandler.ENGAGEMENT_RANGE + 500 - 1, "out of range: " .. distanceFromThreat)
end

function TestConvoyHelpers:test_the_rally_search_is_bounded()
  dcs_mocks.visibilityAnswer = true
  local threats = {}
  for index = 1, 20 do
    threats[index] = { x = 2000 + index, y = 0, z = 0 }
  end
  veafGroundAI.chooseRallyPoint({ x = 0, y = 0, z = 0 }, threats, nil)
  local candidates = #ConvoyUnitHandler.RALLY_RINGS * (2 * ConvoyUnitHandler.RALLY_SPREAD / ConvoyUnitHandler.RALLY_STEP + 1)
  luaunit.assertTrue(
    #dcs_mocks.visibilityCalls <= candidates * ConvoyUnitHandler.RALLY_MAX_THREATS,
    #dcs_mocks.visibilityCalls .. " lines of sight"
  )
end

function TestConvoyHelpers:test_the_fall_back_route_is_off_road_then_on_road()
  local route = veafGroundAI.fallBackRoute({ x = 0, y = 0, z = 0 }, { x = -1000, y = 0, z = -800 }, { x = -9000, y = 0, z = 4000 }, 11)
  luaunit.assertEquals(#route, 4)
  luaunit.assertEquals(route[2].action, "Off Road")
  luaunit.assertEquals(route[4].action, "On Road")
  -- mission-table form: y is the easting
  luaunit.assertEquals(route[2].y, -800)
  luaunit.assertEquals(route[4].x, -9000)
end

function TestConvoyHelpers:test_the_call_for_help()
  local threats = {
    { name = "r1", point = { x = 1000, y = 0, z = 0 }, typeName = "BMP-2", strength = 3 },
    { name = "r2", point = { x = 1100, y = 0, z = 0 }, typeName = "BMP-2", strength = 3 },
    { name = "r3", point = { x = 1200, y = 0, z = 0 }, typeName = "BTR-80", strength = 1 },
  }
  local text, voice = veafGroundAI.convoyContactCall("Convoy-1", { x = 0, y = 0, z = 0 }, threats)
  luaunit.assertStrContains(text, "Convoy-1")
  luaunit.assertStrContains(text, "TROOPS IN CONTACT")
  luaunit.assertStrContains(text, "2 x BMP-2, 1 x BTR-80")
  -- the nearest enemy, due north, 1 km
  luaunit.assertStrContains(text, "bearing 000, 1000 m")
  luaunit.assertStrContains(voice, "troops in contact, 3 enemies, bearing 000, 1000 meters")
end

-- ---------------------------------------------------------------------------
-- The handler: contact, split, fight or flee
-- ---------------------------------------------------------------------------
TestConvoyContact = {}

--- A blue convoy at the origin: an armed lead of `armed` attributes and two trucks.
function TestConvoyContact:_convoy(armedAttributes)
  local units = {}
  if armedAttributes then
    table.insert(units, makeUnit("c-1", { attributes = armedAttributes, type = "M-2 Bradley", point = { x = 0, y = 0, z = 0 } }))
  end
  table.insert(units, makeUnit("c-2", { attributes = TRUCK, point = { x = -20, y = 0, z = 0 } }))
  table.insert(units, makeUnit("c-3", { attributes = TRUCK, point = { x = -40, y = 0, z = 0 } }))
  makeGroup("Convoy-1", units)
  return veafGroundAI.addConvoy("Convoy-1"), units
end

function TestConvoyContact:setUp()
  resetWorld()
  dcs_mocks.visibilityAnswer = true
end

function TestConvoyContact:test_an_unknown_group_is_not_watched()
  luaunit.assertNil(veafGroundAI.addConvoy("nobody"))
end

function TestConvoyContact:test_a_burst_of_hits_is_one_contact()
  self:_convoy(APC)
  local shooter = makeUnit("r-1", { side = RED, attributes = IFV, type = "BMP-2", point = { x = 1500, y = 0, z = 0 } })
  for _ = 1, 20 do
    veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_HIT, initiator = shooter, target = Unit.getByName("c-2") })
  end
  luaunit.assertEquals(countMessages("TROOPS IN CONTACT"), 1, "one call for twenty hits")
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 1, "one split")
end

function TestConvoyContact:test_a_same_coalition_hit_is_no_contact()
  -- A truck's explosion hits its neighbours, with the truck as the initiator (measured 2026-10-08).
  self:_convoy(IFV)
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_HIT, initiator = Unit.getByName("c-3"), target = Unit.getByName("c-2") })
  luaunit.assertEquals(countMessages("TROOPS IN CONTACT"), 0)
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

function TestConvoyContact:test_a_shot_at_another_group_is_ignored()
  self:_convoy(IFV)
  local shooter = makeUnit("r-1", { side = RED, attributes = APC, point = { x = 1500, y = 0, z = 0 } })
  local stranger = makeUnit("x-1", { point = { x = 9000, y = 0, z = 0 } })
  makeGroup("Somebody", { stranger })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_SHOOTING_START, initiator = shooter, target = stranger })
  luaunit.assertEquals(countMessages("TROOPS IN CONTACT"), 0)
end

function TestConvoyContact:test_strong_enough_it_splits_and_fights()
  local handler, units = self:_convoy(IFV)
  local shooter = makeUnit("r-1", { side = RED, attributes = APC, type = "BTR-80", point = { x = 1500, y = 0, z = 0 } })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_SHOOTING_START, initiator = shooter, target = units[1] })

  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FIGHTING, "3 against 1")
  -- the trucks left as their own group, where they stood
  luaunit.assertTrue(units[2]._destroyed and units[3]._destroyed)
  luaunit.assertFalse(units[1]._destroyed, "the Bradley stays in the convoy")
  local added = dcs_mocks.groupsAdded[1].group
  luaunit.assertStrContains(added.name, "Convoy-1 unarmed")
  luaunit.assertEquals(#added.units, 2)
  luaunit.assertEquals(added.units[1].type, "M 818")
  luaunit.assertEquals(added.units[2].x, -40)
  luaunit.assertTrue(#added.route.points >= 2, "and they flee at once")
  -- the armed vehicles close in, alarm red, weapons free: to 900 m of the BTR, 1.5 km north
  local options = optionsFor("Convoy-1")
  luaunit.assertEquals(options[AI.Option.Ground.id.ALARM_STATE], AI.Option.Ground.val.ALARM_STATE.RED)
  luaunit.assertEquals(options[AI.Option.Ground.id.ROE], AI.Option.Ground.val.ROE.OPEN_FIRE)
  luaunit.assertEquals(tasksPushedTo("Convoy-1", "Hold"), 0, "not a halt: halted at 1.9 km, nobody fired (2026-10-08)")
  local points = lastTaskSetOn("Convoy-1").params.route.points
  local stop = points[#points]
  luaunit.assertAlmostEquals(math.sqrt((stop.x - 1500) ^ 2 + stop.y ^ 2), ConvoyUnitHandler.ASSAULT_STANDOFF, 1)
  luaunit.assertEquals(stop.action, "Off Road")
  -- the unarmed group is the convoy's too: a hit on it is the same contact
  luaunit.assertEquals(veafGroundAI.convoysByGroupName[added.name], handler)
end

function TestConvoyContact:test_already_close_it_holds_and_fights_where_it_stands()
  local handler, units = self:_convoy(IFV)
  local shooter = makeUnit("r-1", { side = RED, attributes = APC, point = { x = 600, y = 0, z = 0 } })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_HIT, initiator = shooter, target = units[1] })
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FIGHTING)
  luaunit.assertEquals(tasksPushedTo("Convoy-1", "Hold"), 1)
end

function TestConvoyContact:test_too_weak_it_falls_back_after_the_trucks()
  local handler, units = self:_convoy(APC)
  makeUnit("r-1", { side = RED, attributes = IFV, type = "BMP-2", point = { x = 1500, y = 0, z = 0 } })
  makeUnit("r-2", { side = RED, attributes = IFV, type = "BMP-2", point = { x = 1500, y = 0, z = 60 } })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_HIT, initiator = Unit.getByName("r-1"), target = units[1] })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_HIT, initiator = Unit.getByName("r-2"), target = units[1] })

  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FALLING_BACK, "1 against 3")
  luaunit.assertEquals(tasksPushedTo("Convoy-1", "Hold"), 0)
  local task = lastTaskSetOn("Convoy-1")
  luaunit.assertNotNil(task, "the armed vehicles are given the fall-back route")
  luaunit.assertEquals(task.id, "Mission")
end

function TestConvoyContact:test_an_aircraft_is_not_fought()
  local handler, units = self:_convoy(TANK)
  local jet = makeUnit("su25", { side = RED, categoryEx = Unit.Category.AIRPLANE, type = "Su-25T", point = { x = 1000, y = 500, z = 0 } })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_SHOOTING_START, initiator = jet, target = units[1] })
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FALLING_BACK)
end

function TestConvoyContact:test_a_gun_firing_from_beyond_range_is_not_fought()
  -- a gun the convoy cannot answer: whatever its own strength, it counts for all of it
  local handler, units = self:_convoy(TANK)
  local gun = makeUnit("r-1", { side = RED, attributes = APC, type = "2S1", point = { x = 6000, y = 0, z = 0 } })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_SHOOTING_START, initiator = gun, target = units[1] })
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FALLING_BACK)
end

function TestConvoyContact:test_a_stopped_convoy_reacts_to_nothing()
  local handler, units = self:_convoy(IFV)
  handler:stop()
  local shooter = makeUnit("r-1", { side = RED, attributes = APC, point = { x = 1500, y = 0, z = 0 } })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_HIT, initiator = shooter, target = units[1] })
  luaunit.assertEquals(countMessages("TROOPS IN CONTACT"), 0)
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

function TestConvoyContact:test_no_red_smoke_under_an_aircraft()
  local _, units = self:_convoy(TANK)
  local jet = makeUnit("su25", { side = RED, categoryEx = Unit.Category.AIRPLANE, point = { x = 1000, y = 500, z = 0 } })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_SHOOTING_START, initiator = jet, target = units[1] })
  local red, green = 0, 0
  for _, effect in ipairs(dcs_mocks.effects) do
    if effect.color == trigger.smokeColor.Red then
      red = red + 1
    elseif effect.color == trigger.smokeColor.Green then
      green = green + 1
    end
  end
  luaunit.assertEquals(red, 0)
  luaunit.assertEquals(green, 1, "the convoy is still marked for the pilots")
end

--- A shell as some hit events hand it over for initiator: red, far away, fired by `launcher` (or nobody).
local function shell(launcher)
  return {
    getCategory = function()
      return Object.Category.WEAPON
    end,
    getCoalition = function()
      return RED
    end,
    getName = function()
      return "16777473"
    end,
    getTypeName = function()
      return "weapons.shells.M61_20_HE_gr"
    end,
    getPoint = function()
      return { x = 3697, y = 0, z = 0 }
    end,
    getLauncher = function()
      return launcher
    end,
  }
end

-- FIX-CAPTURE-ZONE-MEMBERSHIP ticket 05: on Kolkhida, 2026-10-08, a convoy's threats held
-- "weapons.shells.M61_20_HE_gr strength=inf at 3697 m": the hit's initiator was the shell, recorded as a threat.
function TestConvoyContact:test_a_shell_is_never_a_threat_its_launcher_is()
  local handler, units = self:_convoy(IFV)
  local shooter = makeUnit("r-1", { side = RED, attributes = APC, type = "BTR-80", point = { x = 1500, y = 0, z = 0 } })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_HIT, initiator = shell(shooter), target = units[1] })
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FIGHTING, "the BTR is fought")
  luaunit.assertNotNil(handler.threats["r-1"])
  luaunit.assertNil(handler.threats["16777473"], "the shell is not a threat")
end

function TestConvoyContact:test_a_shell_whose_launcher_is_unknown_is_no_contact()
  local handler, units = self:_convoy(IFV)
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_HIT, initiator = shell(nil), target = units[1] })
  luaunit.assertNil(next(handler.threats), "nothing recorded")
  luaunit.assertNotEquals(handler.state, ConvoyUnitHandler.STATE_FALLING_BACK, "nobody to fall back from")
  luaunit.assertEquals(countMessages("TROOPS IN CONTACT"), 0)
end

-- FIX-CAPTURE-ZONE-MEMBERSHIP ticket 04: on Kolkhida, 2026-10-08, the red assault convoy fought Poti's
-- garrison from 2.8 km for good: in sight all the time, the contact never ended, and the convoy stood 900 m
-- short of the threat of the moment instead of driving into the zone it had been sent to take.
local POTI = { x = 0, y = 0, z = 3000 }

local function lastRoutePoint(groupName)
  local points = lastTaskSetOn(groupName).params.route.points
  return points[#points]
end

function TestConvoyContact:test_an_assault_convoy_strong_enough_drives_into_its_objective()
  local handler, units = self:_convoy(IFV)
  veafGroundAI.setConvoyObjective("Convoy-1", POTI)
  local shooter = makeUnit("r-1", { side = RED, attributes = APC, type = "BTR-80", point = { x = 600, y = 0, z = 1500 } })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_HIT, initiator = shooter, target = units[1] })
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FIGHTING)
  luaunit.assertEquals(tasksPushedTo("Convoy-1", "Hold"), 0, "never a halt short of the objective")
  local stop = lastRoutePoint("Convoy-1")
  luaunit.assertEquals({ stop.x, stop.y, stop.action }, { POTI.x, POTI.z, "Off Road" }, "into the zone, firing as it goes")
  -- still in contact a minute later, the enemy alive out of sight: it presses on to the same place
  dcs_mocks.tasksSet = {}
  handler.enemies = { shooter }
  luaunit.assertTrue(handler:pressOn(timer.getTime()))
  stop = lastRoutePoint("Convoy-1")
  luaunit.assertEquals({ stop.x, stop.y }, { POTI.x, POTI.z })
end

function TestConvoyContact:test_an_assault_convoy_close_to_a_threat_does_not_hold_either()
  local handler, units = self:_convoy(IFV)
  veafGroundAI.setConvoyObjective("Convoy-1", POTI)
  local shooter = makeUnit("r-1", { side = RED, attributes = APC, point = { x = 600, y = 0, z = 0 } })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_HIT, initiator = shooter, target = units[1] })
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FIGHTING)
  luaunit.assertEquals(tasksPushedTo("Convoy-1", "Hold"), 0)
  local stop = lastRoutePoint("Convoy-1")
  luaunit.assertEquals({ stop.x, stop.y }, { POTI.x, POTI.z })
end

function TestConvoyContact:test_an_assault_convoy_far_from_its_objective_fights_like_any_convoy()
  -- 9 km across country bogged a column down at 0.6 m/s (2026-10-08): far off, it closes in on the threat
  local handler, units = self:_convoy(IFV)
  veafGroundAI.setConvoyObjective("Convoy-1", { x = 0, y = 0, z = 9000 })
  local shooter = makeUnit("r-1", { side = RED, attributes = APC, point = { x = 1500, y = 0, z = 0 } })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_HIT, initiator = shooter, target = units[1] })
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FIGHTING)
  local stop = lastRoutePoint("Convoy-1")
  luaunit.assertAlmostEquals(math.sqrt((stop.x - 1500) ^ 2 + stop.y ^ 2), ConvoyUnitHandler.ASSAULT_STANDOFF, 1)
end

function TestConvoyContact:test_an_assault_convoy_too_weak_still_falls_back()
  local handler, units = self:_convoy(APC)
  veafGroundAI.setConvoyObjective("Convoy-1", POTI)
  makeUnit("r-1", { side = RED, attributes = IFV, type = "BMP-2", point = { x = 1500, y = 0, z = 0 } })
  makeUnit("r-2", { side = RED, attributes = IFV, type = "BMP-2", point = { x = 1500, y = 0, z = 60 } })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_HIT, initiator = Unit.getByName("r-1"), target = units[1] })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_HIT, initiator = Unit.getByName("r-2"), target = units[1] })
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FALLING_BACK)
end

function TestConvoyContact:test_a_wholly_unarmed_convoy_flees_as_one()
  local handler = self:_convoy(nil)
  local shooter = makeUnit("r-1", { side = RED, attributes = APC, point = { x = 1500, y = 0, z = 0 } })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_HIT, initiator = shooter, target = Unit.getByName("c-2") })
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0, "nothing to split")
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FALLING_BACK)
  luaunit.assertNotNil(lastTaskSetOn("Convoy-1"))
end

function TestConvoyContact:test_the_smokes_go_with_the_call()
  self:_convoy(APC)
  local shooter = makeUnit("r-1", { side = RED, attributes = IFV, point = { x = 1500, y = 0, z = 300 } })
  veafGroundAI.eventHandler:onEvent({ id = world.event.S_EVENT_HIT, initiator = shooter, target = Unit.getByName("c-1") })
  local red, green = nil, nil
  for _, effect in ipairs(dcs_mocks.effects) do
    if effect.kind == "smoke" and effect.color == trigger.smokeColor.Red then
      red = effect
    elseif effect.kind == "smoke" and effect.color == trigger.smokeColor.Green then
      green = effect
    end
  end
  luaunit.assertNotNil(red)
  luaunit.assertEquals(red.position.x, 1500)
  luaunit.assertEquals(red.position.z, 300)
  luaunit.assertNotNil(green, "green on the convoy")
end

function TestConvoyContact:test_a_radio_that_raises_takes_neither_the_smokes_nor_the_watch_down()
  -- What a half-configured SRS did in game on 2026-10-08: the voice raised two calls down the watch.
  local savedRadio = veafRadio
  veafRadio = {
    transmitMessage = function()
      error("bad argument #2 to 'format' (string expected, got nil)")
    end,
  }
  local units = { makeUnit("v-1", { attributes = APC, point = { x = 0, y = 0, z = 0 } }) }
  makeGroup("Voiced", units)
  dcs_mocks.visibilityAnswer = true
  dcs_mocks.searchObjectsObjects = { makeUnit("seen", { side = RED, attributes = IFV, point = { x = 2000, y = 0, z = 0 } }) }
  local handler = veafGroundAI.addConvoy("Voiced")
  veafRadio = savedRadio
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FALLING_BACK)
  local smokes = 0
  for _, effect in ipairs(dcs_mocks.effects) do
    if effect.kind == "smoke" then
      smokes = smokes + 1
    end
  end
  luaunit.assertEquals(smokes, 2)
  local beats = 0
  for _, task in pairs(dcs_mocks.scheduledTasks) do
    if task.time - dcs_mocks.currentTime == ConvoyUnitHandler.CLOSE_WATCH_PERIOD then
      beats = beats + 1
    end
  end
  luaunit.assertEquals(beats, 1, "the next beat is scheduled")
end

-- ---------------------------------------------------------------------------
-- The watch: wide every 30 s, close every 3 s, quiet after 60 s
-- ---------------------------------------------------------------------------
TestConvoyWatch = {}

function TestConvoyWatch:setUp()
  resetWorld()
  local units = {
    makeUnit("w-1", { attributes = IFV, point = { x = 0, y = 0, z = 0 }, velocity = { x = 11, y = 0, z = 0 } }),
    makeUnit("w-2", { attributes = TRUCK, point = { x = -20, y = 0, z = 0 } }),
  }
  makeGroup("Watched", units)
  self.units = units
end

function TestConvoyWatch:_scheduledDelays()
  local delays = {}
  for _, task in pairs(dcs_mocks.scheduledTasks) do
    table.insert(delays, task.time - dcs_mocks.currentTime)
  end
  return delays
end

function TestConvoyWatch:test_the_wide_watch_searches_a_radius_from_the_speed()
  veafGroundAI.addConvoy("Watched")
  local call = dcs_mocks.searchObjectsCalls[1]
  luaunit.assertNotNil(call, "the first beat is a wide watch")
  luaunit.assertEquals(call.category, Object.Category.UNIT)
  luaunit.assertEquals(call.volume.params.radius, 5660)
  luaunit.assertEquals(self:_scheduledDelays(), { 30 }, "nothing near: next look in 30 s")
end

function TestConvoyWatch:test_an_enemy_out_of_sight_tightens_the_watch_without_a_contact()
  dcs_mocks.visibilityAnswer = false
  dcs_mocks.searchObjectsObjects = { makeUnit("hidden", { side = RED, attributes = IFV, point = { x = 2000, y = 0, z = 0 } }) }
  local handler = veafGroundAI.addConvoy("Watched")
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_ALERTED)
  luaunit.assertEquals(countMessages("TROOPS IN CONTACT"), 0)
  luaunit.assertEquals(self:_scheduledDelays(), { 3 }, "an enemy near: next look in 3 s")
end

function TestConvoyWatch:test_an_enemy_in_sight_within_range_is_a_contact_before_any_shot()
  dcs_mocks.visibilityAnswer = true
  dcs_mocks.searchObjectsObjects = { makeUnit("seen", { side = RED, attributes = APC, point = { x = 2500, y = 0, z = 0 } }) }
  local handler = veafGroundAI.addConvoy("Watched")
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FIGHTING, "3 against 1")
  luaunit.assertEquals(countMessages("TROOPS IN CONTACT"), 0, "strong enough: no call for help (David, 2026-10-08)")
  -- radio style, its callsign first and the enemy placed from its heading (north, the enemy north of it)
  luaunit.assertStrContains(
    dcs_mocks.messagesContaining("engaging")[1].text,
    "Mule, contact ahead, 1 enemy at 2510 m bearing 000, engaging."
  )
  luaunit.assertEquals(#dcs_mocks.effects, 0, "and no smoke")
end

function TestConvoyWatch:test_an_outgunned_convoy_calls_for_help()
  dcs_mocks.visibilityAnswer = true
  dcs_mocks.searchObjectsObjects = {
    makeUnit("seen-1", { side = RED, attributes = TANK, point = { x = 2500, y = 0, z = 0 } }),
    makeUnit("seen-2", { side = RED, attributes = TANK, point = { x = 2500, y = 0, z = 60 } }),
  }
  local handler = veafGroundAI.addConvoy("Watched")
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FALLING_BACK, "3 against 8")
  luaunit.assertEquals(countMessages("TROOPS IN CONTACT"), 1)
end

function TestConvoyWatch:test_an_enemy_in_sight_beyond_range_is_no_contact()
  dcs_mocks.visibilityAnswer = true
  dcs_mocks.searchObjectsObjects = { makeUnit("far", { side = RED, attributes = APC, point = { x = 4500, y = 0, z = 0 } }) }
  local handler = veafGroundAI.addConvoy("Watched")
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_ALERTED)
end

function TestConvoyWatch:test_a_rifleman_seen_beyond_engagement_range_counts_for_his_own_strength()
  -- Kolkhida, 2026-10-08: one `Soldier M4 GRG` seen 3164 m from the convoy's centre counted for
  -- `math.huge`, and a group of strength 5 fell back from him. Seen, not fired at by: he counts for 1.
  local units = {
    makeUnit("s-1", { attributes = IFV, point = { x = 0, y = 0, z = 0 } }),
    makeUnit("s-2", { attributes = AAA, point = { x = -250, y = 0, z = 0 } }),
    makeUnit("s-3", { attributes = AAA, point = { x = -500, y = 0, z = 0 } }),
  }
  makeGroup("Bison", units)
  dcs_mocks.visibilityAnswer = true
  local rifleman =
    makeUnit("Poti garrison #8", { side = RED, attributes = INFANTRY, type = "Soldier M4 GRG", point = { x = 2914, y = 0, z = 0 } })
  dcs_mocks.searchObjectsObjects = { rifleman }
  local handler = veafGroundAI.addConvoy("Bison")
  luaunit.assertEquals(handler.threats["Poti garrison #8"].strength, 1)
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FIGHTING, "5 against 1")
end

function TestConvoyWatch:test_quiet_for_a_minute_after_a_fight_it_drives_on_by_itself()
  dcs_mocks.visibilityAnswer = true
  local enemy = makeUnit("seen", { side = RED, attributes = APC, point = { x = 2500, y = 0, z = 0 } })
  dcs_mocks.searchObjectsObjects = { enemy }
  local handler = veafGroundAI.addConvoy("Watched")
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FIGHTING)
  -- the enemy is destroyed: nothing in sight any more
  enemy.getLife = function()
    return 0
  end
  dcs_mocks.runScheduled(ConvoyUnitHandler.QUIET_DELAY + 5)
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_DRIVING, "no `_gc resume` needed after a won fight")
  luaunit.assertEquals(countMessages("back on the road"), 1)
  luaunit.assertEquals(countMessages("holding position"), 0)
end

function TestConvoyWatch:test_out_of_sight_is_not_destroyed_it_closes_in_again()
  -- the demo's run of 2026-10-08: one BMP of three seen, then lost from sight, and the convoy drove on
  local enemy = makeUnit("seen", { side = RED, attributes = APC, point = { x = 2500, y = 0, z = 0 } })
  dcs_mocks.searchObjectsObjects = { enemy }
  dcs_mocks.visibilityAnswer = true
  local handler = veafGroundAI.addConvoy("Watched")
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FIGHTING)
  dcs_mocks.visibilityAnswer = false
  local routesBefore = #dcs_mocks.tasksSet
  dcs_mocks.runScheduled(ConvoyUnitHandler.QUIET_DELAY + 5)
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FIGHTING, "still alive out of sight: the fight goes on")
  luaunit.assertTrue(#dcs_mocks.tasksSet > routesBefore, "it closes in again on the enemy the watch knows of")
  luaunit.assertEquals(countMessages("back on the road"), 0)
  enemy.getLife = function()
    return 0
  end
  dcs_mocks.runScheduled(2 * ConvoyUnitHandler.QUIET_DELAY + 40)
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_DRIVING, "none left alive: it drives on")
  luaunit.assertEquals(countMessages("engaging"), 1, "the contact is reported once, not at each new approach")
end

function TestConvoyWatch:test_the_contact_report_comes_first_the_tactical_messages_after()
  dcs_mocks.visibilityAnswer = true
  dcs_mocks.searchObjectsObjects = {
    makeUnit("seen-1", { side = RED, attributes = TANK, point = { x = 2500, y = 0, z = 0 } }),
    makeUnit("seen-2", { side = RED, attributes = TANK, point = { x = 2500, y = 0, z = 60 } }),
  }
  veafGroundAI.addConvoy("Watched")
  luaunit.assertEquals(countMessages("TROOPS IN CONTACT"), 1, "the call at once")
  luaunit.assertEquals(countMessages("breaking contact"), 0, "not yet")
  luaunit.assertEquals(countMessages("unarmed vehicles"), 0, "not yet")
  dcs_mocks.runScheduled(ConvoyUnitHandler.TACTICAL_MESSAGE_DELAY + 5)
  local order = {}
  for index, message in ipairs(dcs_mocks.messages) do
    for _, needle in ipairs({ "TROOPS IN CONTACT", "breaking contact", "unarmed vehicles" }) do
      if message.text:find(needle, 1, true) and not order[needle] then
        order[needle] = index
      end
    end
  end
  luaunit.assertNotNil(order["breaking contact"])
  luaunit.assertNotNil(order["unarmed vehicles"])
  luaunit.assertTrue(order["TROOPS IN CONTACT"] < order["breaking contact"])
  luaunit.assertTrue(order["breaking contact"] < order["unarmed vehicles"])
end

function TestConvoyWatch:test_quiet_for_a_minute_after_a_fall_back_it_holds_and_says_so()
  dcs_mocks.visibilityAnswer = true
  local enemies = {
    makeUnit("seen-1", { side = RED, attributes = TANK, point = { x = 2500, y = 0, z = 0 } }),
    makeUnit("seen-2", { side = RED, attributes = TANK, point = { x = 2500, y = 0, z = 60 } }),
  }
  dcs_mocks.searchObjectsObjects = enemies
  local handler = veafGroundAI.addConvoy("Watched")
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FALLING_BACK)
  -- out of their sight now
  dcs_mocks.visibilityAnswer = false
  dcs_mocks.runScheduled(ConvoyUnitHandler.QUIET_DELAY + 5)
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_HOLDING, "the enemy it fled is still there")
  luaunit.assertEquals(countMessages("holding position"), 1)
  luaunit.assertStrContains(dcs_mocks.messagesContaining("holding position")[1].text, "_gc Mule, resume")
end

--- Fall back from two tanks, then lose sight of them: the convoy holds at QUIET_DELAY.
function TestConvoyWatch:_fallBackAndHold()
  dcs_mocks.visibilityAnswer = true
  dcs_mocks.searchObjectsObjects = {
    makeUnit("seen-1", { side = RED, attributes = TANK, point = { x = 2500, y = 0, z = 0 } }),
    makeUnit("seen-2", { side = RED, attributes = TANK, point = { x = 2500, y = 0, z = 60 } }),
  }
  local handler = veafGroundAI.addConvoy("Watched")
  dcs_mocks.visibilityAnswer = false
  dcs_mocks.runScheduled(ConvoyUnitHandler.QUIET_DELAY + 5)
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_HOLDING)
  return handler
end

function TestConvoyWatch:_withPlayers(side, count)
  coalition.getPlayers = function(asked)
    local players = {}
    if asked == side then
      for index = 1, count do
        players[index] = {
          getPlayerName = function()
            return "player " .. index
          end,
        }
      end
    end
    return players
  end
end

function TestConvoyWatch:tearDown()
  coalition.getPlayers = function()
    return {}
  end
end

function TestConvoyWatch:test_holding_with_nobody_of_its_side_it_drives_on_after_the_delay()
  -- Kolkhida, 2026-10-08: the red convoy held for ever, waiting for a `_gc resume` nobody on red can give
  self:_withPlayers(RED, 2)
  local handler = self:_fallBackAndHold()
  dcs_mocks.runScheduled(ConvoyUnitHandler.QUIET_DELAY + ConvoyUnitHandler.HOLD_ALONE_DELAY - 5)
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_HOLDING, "not before the delay")
  dcs_mocks.runScheduled(ConvoyUnitHandler.QUIET_DELAY + ConvoyUnitHandler.HOLD_ALONE_DELAY + 10)
  luaunit.assertNotEquals(handler.state, ConvoyUnitHandler.STATE_HOLDING)
  luaunit.assertEquals(countMessages("back on the road"), 1)
end

function TestConvoyWatch:test_holding_with_a_player_of_its_side_it_keeps_the_choice()
  self:_withPlayers(BLUE, 1)
  local handler = self:_fallBackAndHold()
  dcs_mocks.runScheduled(ConvoyUnitHandler.QUIET_DELAY + 3 * ConvoyUnitHandler.HOLD_ALONE_DELAY)
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_HOLDING, "a player of its side gives the order")
  luaunit.assertEquals(countMessages("back on the road"), 0)
  -- he leaves: at the next check, nobody is left to give it
  self:_withPlayers(BLUE, 0)
  dcs_mocks.runScheduled(ConvoyUnitHandler.QUIET_DELAY + 4 * ConvoyUnitHandler.HOLD_ALONE_DELAY + 10)
  luaunit.assertEquals(countMessages("back on the road"), 1)
end

function TestConvoyWatch:test_a_new_contact_while_holding_cancels_the_drive_on()
  local handler = self:_fallBackAndHold()
  -- the enemy shows up again before the delay ends
  dcs_mocks.visibilityAnswer = true
  dcs_mocks.runScheduled(ConvoyUnitHandler.QUIET_DELAY + 100)
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_FALLING_BACK)
  dcs_mocks.runScheduled(ConvoyUnitHandler.QUIET_DELAY + ConvoyUnitHandler.HOLD_ALONE_DELAY + 10)
  luaunit.assertEquals(countMessages("back on the road"), 0, "the first hold's delay no longer counts")
end

function TestConvoyWatch:test_an_order_to_hold_is_never_overridden()
  local handler = self:_fallBackAndHold()
  luaunit.assertTrue(handler:hold())
  dcs_mocks.runScheduled(ConvoyUnitHandler.QUIET_DELAY + 2 * ConvoyUnitHandler.HOLD_ALONE_DELAY)
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_HOLDING)
  luaunit.assertEquals(countMessages("back on the road"), 0)
end

function TestConvoyWatch:test_the_watch_ends_when_the_convoy_is_gone()
  local handler = veafGroundAI.addConvoy("Watched")
  dcs_mocks.removeGroup("Watched")
  dcs_mocks.runScheduled(40)
  luaunit.assertNil(veafGroundAI.convoysByGroupName["Watched"])
  luaunit.assertEquals(handler.status, GroundUnitHandler.STATUS_OVER)
  luaunit.assertEquals(self:_scheduledDelays(), {})
end

-- ---------------------------------------------------------------------------
-- The orders, and the merge
-- ---------------------------------------------------------------------------
TestConvoyOrders = {}

function TestConvoyOrders:setUp()
  resetWorld()
end

function TestConvoyOrders:test_the_verbs_are_read()
  local options = veafGroundAI.markTextAnalysis({ x = 0, y = 0, z = 0 }, BLUE, "_gc convoy-1, retreat")
  luaunit.assertEquals(options.verb, veafGroundAI.VERB_RETREAT)
  luaunit.assertNil(options.destination)
  options = veafGroundAI.markTextAnalysis({ x = 0, y = 0, z = 0 }, BLUE, "_gc convoy-1, retreat KOBULETI")
  luaunit.assertEquals(options.destination, "KOBULETI")
  luaunit.assertEquals(veafGroundAI.markTextAnalysis({ x = 0, y = 0, z = 0 }, BLUE, "_gc convoy-1, hold").verb, veafGroundAI.VERB_HOLD)
  luaunit.assertEquals(veafGroundAI.markTextAnalysis({ x = 0, y = 0, z = 0 }, BLUE, "_gc convoy-1, resume").verb, veafGroundAI.VERB_RESUME)
end

function TestConvoyOrders:test_convoy_hands_a_named_group_to_the_watch()
  makeGroup("Supply", { makeUnit("s-1", { point = { x = 0, y = 0, z = 0 } }) })
  luaunit.assertTrue(veafGroundAI.executeCommand({ x = 0, y = 0, z = 0 }, "_gc supply-1, convoy, groupname Supply", BLUE))
  luaunit.assertNotNil(veafGroundAI.convoysByGroupName["Supply"])
  luaunit.assertEquals(veafGroundAI.get("supply-1"), veafGroundAI.convoysByGroupName["Supply"])
end

function TestConvoyOrders:test_an_artillery_battery_is_told_it_is_no_convoy()
  ArtilleryUnitHandler:new():setName("arty-1")
  luaunit.assertFalse(veafGroundAI.executeCommand({ x = 0, y = 0, z = 0 }, "_gc arty-1, retreat", BLUE))
  luaunit.assertEquals(countMessages("is not a convoy"), 1)
end

function TestConvoyOrders:test_hold_halts_both_groups()
  makeGroup("Column", { makeUnit("k-1", { attributes = IFV }) })
  local handler = veafGroundAI.addConvoy("Column", "Column")
  makeGroup("Column unarmed", { makeUnit("k-2", { point = { x = -2000, y = 0, z = 0 } }) })
  handler.unarmedGroupName = "Column unarmed"
  luaunit.assertTrue(veafGroundAI.executeCommand({ x = 0, y = 0, z = 0 }, "_gc column, hold", BLUE))
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_HOLDING)
  luaunit.assertEquals(tasksPushedTo("Column", "Hold"), 1)
  luaunit.assertEquals(tasksPushedTo("Column unarmed", "Hold"), 1)
end

function TestConvoyOrders:test_retreat_without_a_friendly_place_says_where_to_give_one()
  makeGroup("Lost", { makeUnit("l-1", { attributes = IFV }) })
  veafGroundAI.addConvoy("Lost", "Lost")
  luaunit.assertFalse(veafGroundAI.executeCommand({ x = 0, y = 0, z = 0 }, "_gc lost, retreat", BLUE))
  luaunit.assertStrContains(dcs_mocks.messagesContaining("no friendly place")[1].text, "_gc Lost, retreat <point>")
end

function TestConvoyOrders:test_retreat_to_the_nearest_friendly_airbase()
  makeGroup("Column", { makeUnit("k-1", { attributes = IFV }) })
  local handler = veafGroundAI.addConvoy("Column", "Column")
  local saved = coalition.getAirbases
  coalition.getAirbases = function(side)
    local function airbase(name, x, z, category)
      return {
        getName = function()
          return name
        end,
        getPoint = function()
          return { x = x, y = 0, z = z }
        end,
        getDesc = function()
          return { category = category }
        end,
      }
    end
    return {
      airbase("Far", 50000, 0, Airbase.Category.AIRDROME),
      airbase("Carrier", 1000, 0, Airbase.Category.SHIP),
      airbase("Near", 9000, 0, Airbase.Category.AIRDROME),
    }
  end
  local ok = veafGroundAI.executeCommand({ x = 0, y = 0, z = 0 }, "_gc column, retreat", BLUE)
  coalition.getAirbases = saved
  luaunit.assertTrue(ok)
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_RETREATING)
  local points = lastTaskSetOn("Column").params.route.points
  luaunit.assertEquals(points[#points].x, 9000, "the nearest airbase, not the carrier")
end

function TestConvoyOrders:test_resume_brings_the_unarmed_group_back_and_merges_it_when_close()
  local lead = makeUnit("m-1", { attributes = IFV, type = "M-2 Bradley", point = { x = 0, y = 0, z = 0 } })
  makeGroup("Column", { lead })
  local handler = veafGroundAI.addConvoy("Column")
  local truckPoint = { x = -2000, y = 0, z = 0 }
  makeGroup("Column unarmed", { makeUnit("m-2", { point = truckPoint }) })
  handler.unarmedGroupName = "Column unarmed"
  veafGroundAI.convoysByGroupName["Column unarmed"] = handler

  luaunit.assertTrue(handler:resume())
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_RESUMING)
  -- the trucks wait where they fell back, and the armed vehicles go and fetch them, by road
  luaunit.assertEquals(tasksPushedTo("Column unarmed", "Hold"), 1)
  luaunit.assertNil(lastTaskSetOn("Column unarmed"), "no route for the trucks before the merge")
  local points = lastTaskSetOn("Column").params.route.points
  luaunit.assertEquals({ points[#points].x, points[#points].y, points[#points].action }, { -2000, 0, "On Road" })
  handler:mergeIfClose()
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0, "2 km apart: not yet")

  truckPoint.x = -200
  handler:mergeIfClose()
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 1)
  local merged = dcs_mocks.groupsAdded[1].group
  luaunit.assertEquals(merged.name, "Column", "rebuilt under the convoy's own name, which replaces it")
  luaunit.assertEquals(#merged.units, 2)
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_DRIVING)
  luaunit.assertNil(handler.unarmedGroupName)
  luaunit.assertNil(veafGroundAI.convoysByGroupName["Column unarmed"])
end

function TestConvoyOrders:test_the_onward_route_of_a_spawned_convoy_goes_back_to_the_road()
  -- the convoy stands 350 m off the road after its fight; the road is at x = 0
  makeGroup("[b]-Convoy-9", { makeUnit("o-1", { attributes = IFV, point = { x = 350, y = 0, z = 1000 } }) })
  local savedSpawn, savedRoads = veafSpawn, land.getClosestPointOnRoads
  veafSpawn = {
    spawnedConvoys = {
      ["[b]-Convoy-9"] = {
        stopped = true,
        route = {
          { name = "T_STA", x = 300, y = 0, action = "Off Road" },
          { name = "STA", x = 0, y = 0, action = "On Road" },
          { name = "END", x = 0, y = 9000, action = "On Road" },
          { name = "T_END", x = 200, y = 9100, action = "Diamond" },
        },
      },
    },
  }
  land.getClosestPointOnRoads = function(_, x, z)
    return 0, z
  end
  local handler = veafGroundAI.addConvoy("[b]-Convoy-9")
  local points = handler:onwardRoute(Group.getByName("[b]-Convoy-9"))
  local record = veafSpawn.spawnedConvoys["[b]-Convoy-9"]
  veafSpawn, land.getClosestPointOnRoads = savedSpawn, savedRoads
  luaunit.assertEquals(#points, 4)
  luaunit.assertEquals({ points[2].x, points[2].y, points[2].action }, { 0, 1000, "On Road" }, "back to the road first")
  luaunit.assertEquals({ points[3].x, points[3].y, points[3].action }, { 0, 9000, "On Road" }, "then the leg's road end")
  luaunit.assertEquals(points[4].action, "Diamond", "and its true end last, as the spawn made it")
  luaunit.assertFalse(record.stopped, "the itinerary watch may advance it again")
end

function TestConvoyOrders:test_trucks_that_never_rejoin_do_not_hold_the_column_forever()
  makeGroup("Column", { makeUnit("t-1", { attributes = IFV, point = { x = 0, y = 0, z = 0 } }) })
  local handler = veafGroundAI.addConvoy("Column", "Column")
  makeGroup("Column unarmed", { makeUnit("t-2", { point = { x = -2000, y = 0, z = 0 } }) })
  handler.unarmedGroupName = "Column unarmed"
  handler:resume()
  dcs_mocks.advanceTime(ConvoyUnitHandler.REJOIN_TIMEOUT + 1)
  handler:mergeIfClose()
  luaunit.assertEquals(handler.state, ConvoyUnitHandler.STATE_DRIVING)
  luaunit.assertNotNil(lastTaskSetOn("Column"), "the armed vehicles drive on")
  luaunit.assertNotNil(lastTaskSetOn("Column unarmed"), "and so do the trucks, on their own")
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0, "never merged")
end

function TestConvoyOrders:test_a_marker_shows_the_convoy_in_contact_and_goes_with_it()
  local marks, removed = {}, {}
  local savedMark, savedRemove = trigger.action.markToCoalition, trigger.action.removeMark
  trigger.action.markToCoalition = function(id, text, point, side, readOnly)
    marks[#marks + 1] = { id = id, text = text, point = point, side = side, readOnly = readOnly }
  end
  trigger.action.removeMark = function(id)
    removed[#removed + 1] = id
  end
  dcs_mocks.visibilityAnswer = true
  local enemy = makeUnit("seen", { side = RED, attributes = APC, point = { x = 2500, y = 0, z = 0 } })
  dcs_mocks.searchObjectsObjects = { enemy }
  makeGroup("Marked", { makeUnit("mk-1", { attributes = IFV, point = { x = 0, y = 0, z = 0 } }) })
  local handler = veafGroundAI.addConvoy("Marked")
  local first = marks[1]
  dcs_mocks.runScheduled(ConvoyUnitHandler.DANGER_MARK_PERIOD + 4)
  local movedOnce = #marks
  enemy.getLife = function()
    return 0
  end
  dcs_mocks.runScheduled(ConvoyUnitHandler.QUIET_DELAY + 30)
  trigger.action.markToCoalition, trigger.action.removeMark = savedMark, savedRemove
  luaunit.assertNotNil(first, "a marker at the contact")
  luaunit.assertStrContains(first.text, "Mule")
  luaunit.assertEquals(first.side, BLUE)
  luaunit.assertTrue(first.readOnly)
  luaunit.assertTrue(movedOnce >= 2, "moved with the convoy: " .. movedOnce)
  luaunit.assertNil(handler.dangerMarkId, "gone once the contact is over")
  luaunit.assertEquals(removed[#removed], marks[#marks].id, "the last one put is the last one removed")
end

function TestConvoyOrders:test_a_part_of_the_name_gives_an_order_to_one_handler()
  makeGroup("Supply North", { makeUnit("p-1") })
  makeGroup("Supply South", { makeUnit("p-2") })
  veafGroundAI.addConvoy("Supply North", "Supply North")
  veafGroundAI.addConvoy("Supply South", "Supply South")
  luaunit.assertEquals(veafGroundAI.getOrComplain("north"):getName(), "Supply North")
  luaunit.assertNil(veafGroundAI.getByPart("supply"), "two matches are no match")
end

function TestConvoyOrders:test_a_convoy_nobody_named_takes_the_next_free_callsign()
  -- `_gc mule, resume` rather than `_gc [b]-Convoy#10473, resume`
  makeGroup("[b]-Convoy#1", { makeUnit("n-1") })
  makeGroup("[b]-Convoy#2", { makeUnit("n-2") })
  luaunit.assertEquals(veafGroundAI.addConvoy("[b]-Convoy#1"):getName(), "Mule")
  luaunit.assertEquals(veafGroundAI.addConvoy("[b]-Convoy#2"):getName(), "Bison")
  luaunit.assertEquals(veafGroundAI.getOrComplain("mule"):getGroupName(), "[b]-Convoy#1")
  -- once every callsign is held, the list starts again with a number
  for index = 3, #ConvoyUnitHandler.CALLSIGNS do
    makeGroup("[b]-Convoy#" .. index, { makeUnit("n-" .. index) })
    veafGroundAI.addConvoy("[b]-Convoy#" .. index)
  end
  makeGroup("[b]-Convoy#99", { makeUnit("n-99") })
  luaunit.assertEquals(veafGroundAI.addConvoy("[b]-Convoy#99"):getName(), "Mule 2")
end

function TestConvoyOrders:test_the_relative_direction_of_a_threat()
  luaunit.assertEquals(veafGroundAI.relativeDirectionKey(10), "groundai.direction_ahead")
  luaunit.assertEquals(veafGroundAI.relativeDirectionKey(-30), "groundai.direction_ahead")
  luaunit.assertEquals(veafGroundAI.relativeDirectionKey(90), "groundai.direction_right")
  luaunit.assertEquals(veafGroundAI.relativeDirectionKey(180), "groundai.direction_behind")
  luaunit.assertEquals(veafGroundAI.relativeDirectionKey(-90), "groundai.direction_left")
  luaunit.assertEquals(veafGroundAI.relativeDirectionKey(270), "groundai.direction_left")
end

function TestConvoyOrders:test_set_does_not_take_over_an_autopilot_by_a_part_of_its_name()
  -- `_gc arty, set` while `arty-1` exists creates `arty`; it must not re-target `arty-1`.
  ArtilleryUnitHandler:new():setName("arty-1")
  luaunit.assertNil(veafGroundAI.get("arty"), "get is exact: set relies on it to create what it does not find")
end

-- ---------------------------------------------------------------------------
-- The wiring
-- ---------------------------------------------------------------------------
TestConvoyWiring = {}

function TestConvoyWiring:setUp()
  resetWorld()
  veafCommands = veafCommands or { PRIORITY_GROUNDAI = 0 }
  self._savedRegister = veafCommands.registerCommandHandler
  veafCommands.registerCommandHandler = function() end
  veafGroundAI.initialized = nil
end

function TestConvoyWiring:tearDown()
  veafCommands.registerCommandHandler = self._savedRegister
end

function TestConvoyWiring:test_the_event_handler_is_registered_once()
  veafGroundAI.initialize()
  veafGroundAI.initialize()
  local count = 0
  for _, handler in ipairs(dcs_mocks.eventHandlers) do
    if handler == veafGroundAI.eventHandler then
      count = count + 1
    end
  end
  luaunit.assertEquals(count, 1)
end

function TestConvoyWiring:test_the_mission_yaml_convoys_are_watched()
  makeGroup("Supply", { makeUnit("s-1") })
  veaf.setConfig(veafGroundAI.Id, "convoys", { "Supply" })
  veafGroundAI.initialize()
  veaf.setConfig(veafGroundAI.Id, "convoys", nil)
  luaunit.assertNotNil(veafGroundAI.convoysByGroupName["Supply"])
end

os.exit(luaunit.LuaUnit.run())
