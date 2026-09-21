--- Tests for the spotter network in veafSkynetIadsHelper.lua — detection half.
---
--- Split out of `test_veafSkynetIadsHelper.lua`, which is already 2 500 lines, the way
--- `test_veafMove_escort.lua` and `test_veafMissionDb_scenery.lua` are split from theirs.
---
--- What the design asks these tests to prove, and why each one exists, is in
--- `.backlog/FEAT-SPOTTER-NETWORK/tickets/01-detection-the-unit-table-and-the-latch.md`.
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
dofile(src .. "/veafEventHandler.lua")

-- The helper reads `SkynetIADS.database` at initialisation and `dcsUnits.DcsUnitsDatabase` right
-- after; neither is exercised here, but the module refuses to load without them.
SkynetIADS = { database = {} }
dcsUnits = { DcsUnitsDatabase = {} }

dofile(src .. "/veafSkynetIadsHelper.lua")

-- ---------------------------------------------------------------------------
-- Doubles
-- ---------------------------------------------------------------------------

--- A DCS unit with a position and a set of attributes.
---
--- @param name string
--- @param attributes table|nil attribute set, e.g. `{ ["Tanks"] = true }`
--- @param x number|nil
--- @param y number|nil altitude
--- @param z number|nil
local function _unit(name, attributes, x, y, z)
  local point = { x = x or 0, y = y or 0, z = z or 0 }
  return {
    getName = function()
      return name
    end,
    isExist = function()
      return true
    end,
    inAir = function()
      return true
    end,
    getPoint = function()
      return point
    end,
    hasAttribute = function(_, attribute)
      return (attributes or {})[attribute] == true
    end,
    _point = point,
  }
end

--- A DCS group holding those units.
local function _group(name, units)
  return {
    getName = function()
      return name
    end,
    isExist = function()
      return true
    end,
    getUnits = function()
      return units
    end,
  }
end

--- Make `coalition.getGroups` answer with a fixed, per-coalition, per-category listing.
---
--- `listing[coalitionId]` is an array of groups returned whatever the category; entries under
--- `listing[coalitionId .. ":" .. category]` win for that category, which is how an aircraft is put
--- on one side without it also turning up in the ground sweep.
local function _stubGetGroups(listing)
  coalition.getGroups = function(side, category)
    if category ~= nil then
      return listing[side .. ":" .. category] or {}
    end
    return listing[side] or {}
  end
end

local _realGetGroups = coalition.getGroups

--- Reset everything the spotter code remembers between beats.
local function _resetSpotterState()
  dcs_mocks.reset()
  coalition.getGroups = _realGetGroups
  veafSkynet.spotterProfiles = {}
  veafSkynet.spotterLatches = {}
  veafSkynet.spotterDetectionArmed = false
  veafSkynet.SpotterNetwork = false
  veafSkynet.SpotterRadioRange = 20000
  veafSkynet.SpotterPropagationSpeed = 1000
  veafSkynet.structure = {}
end

-- ---------------------------------------------------------------------------
-- The unit table
-- ---------------------------------------------------------------------------
TestSpotterUnitTable = {}

function TestSpotterUnitTable:setUp()
  _resetSpotterState()
  -- No jitter while the table itself is under test: a ±20 % draw would make every assertion a range.
  veafSkynet.SpotterRangeJitter = 0
end

function TestSpotterUnitTable:tearDown()
  veafSkynet.SpotterRangeJitter = 0.2
end

function TestSpotterUnitTable:test_a_tank_sees_little_and_relays()
  local profile = veafSkynet.getSpotterProfile(_unit("T1", { ["Tanks"] = true, ["Armored vehicles"] = true }))
  luaunit.assertEquals(profile.range, 3000)
  luaunit.assertTrue(profile.relays)
end

function TestSpotterUnitTable:test_a_manpads_team_sees_furthest_on_the_ground()
  local profile = veafSkynet.getSpotterProfile(_unit("M1", { ["MANPADS"] = true, ["Air Defence vehicles"] = true }))
  luaunit.assertEquals(profile.range, 10000)
end

function TestSpotterUnitTable:test_a_sam_site_relays_but_never_spots()
  -- Its own detection is the last line of defence's job, with a radius already drawn once. A second
  -- competing radius would mean the larger one always wins and the other setting is dead weight.
  local profile = veafSkynet.getSpotterProfile(_unit("S1", { ["SAM elements"] = true, ["Air Defence vehicles"] = true }))
  luaunit.assertEquals(profile.range, 0)
  luaunit.assertTrue(profile.relays)
end

function TestSpotterUnitTable:test_an_ewr_relays_but_never_spots()
  local profile = veafSkynet.getSpotterProfile(_unit("E1", { ["EWR"] = true }))
  luaunit.assertEquals(profile.range, 0)
  luaunit.assertTrue(profile.relays)
end

function TestSpotterUnitTable:test_an_awacs_relays_but_never_spots()
  local profile = veafSkynet.getSpotterProfile(_unit("A1", { ["AWACS"] = true, ["Air"] = true }))
  luaunit.assertEquals(profile.range, 0)
end

function TestSpotterUnitTable:test_an_aeroplane_sees_thirty_kilometres()
  -- Further than it can talk, deliberately: it has to close on the ground network to pass the word.
  local profile = veafSkynet.getSpotterProfile(_unit("P1", { ["Air"] = true, ["Planes"] = true }))
  luaunit.assertEquals(profile.range, 30000)
end

function TestSpotterUnitTable:test_a_helicopter_is_matched_before_air()
  -- A helicopter carries `Air` too. Order in the table is what makes it a 15 km spotter and not a
  -- 30 km one, so this is the assertion that catches a reordered table.
  local profile = veafSkynet.getSpotterProfile(_unit("H1", { ["Air"] = true, ["Helicopters"] = true }))
  luaunit.assertEquals(profile.range, 15000)
end

function TestSpotterUnitTable:test_an_unknown_type_neither_sees_nor_relays()
  local profile = veafSkynet.getSpotterProfile(_unit("X1", { ["Fortifications"] = true }))
  luaunit.assertEquals(profile.range, 0)
  luaunit.assertFalse(profile.relays)
end

function TestSpotterUnitTable:test_a_unit_without_attributes_neither_sees_nor_relays()
  local profile = veafSkynet.getSpotterProfile(_unit("X2", {}))
  luaunit.assertEquals(profile.range, 0)
  luaunit.assertFalse(profile.relays)
end

-- ---------------------------------------------------------------------------
-- The range is drawn once
-- ---------------------------------------------------------------------------
TestSpotterRangeDraw = {}

function TestSpotterRangeDraw:setUp()
  _resetSpotterState()
end

function TestSpotterRangeDraw:test_the_range_is_drawn_once_per_unit()
  -- Asking again must give the same answer. Drawing per attempt would make the limit wander by four
  -- kilometres between two passes, and the spotter would report the same aircraft over and over.
  local unit = _unit("T1", { ["Tanks"] = true })
  local first = veafSkynet.getSpotterProfile(unit).range
  local second = veafSkynet.getSpotterProfile(unit).range
  local third = veafSkynet.getSpotterProfile(unit).range
  luaunit.assertEquals(second, first)
  luaunit.assertEquals(third, first)
end

function TestSpotterRangeDraw:test_the_draw_stays_within_twenty_percent()
  -- The mocks answer a constant 0 unless a sequence is fed, so the extremes have to be asked for
  -- explicitly: a loop over the default draw would assert the same number fifty times.
  dcs_mocks.setRandomSequence({ 0, 0.5, 1 - 1e-9, 0.25, 0.75 })
  for i = 1, 50 do
    local range = veafSkynet.getSpotterProfile(_unit("T" .. i, { ["Tanks"] = true })).range
    luaunit.assertTrue(range >= 3000 * 0.8)
    luaunit.assertTrue(range <= 3000 * 1.2)
  end
end

function TestSpotterRangeDraw:test_the_extremes_are_exactly_plus_and_minus_twenty_percent()
  dcs_mocks.setRandomSequence({ 0 })
  luaunit.assertAlmostEquals(veafSkynet.getSpotterProfile(_unit("Low", { ["Tanks"] = true })).range, 2400, 1e-6)
  dcs_mocks.setRandomSequence({ 1 })
  luaunit.assertAlmostEquals(veafSkynet.getSpotterProfile(_unit("High", { ["Tanks"] = true })).range, 3600, 1e-6)
end

function TestSpotterRangeDraw:test_two_units_of_the_same_type_can_differ()
  dcs_mocks.setRandomSequence({ 0, 0.5, 1 - 1e-9 })
  local ranges = {}
  for i = 1, 50 do
    ranges[veafSkynet.getSpotterProfile(_unit("T" .. i, { ["Tanks"] = true })).range] = true
  end
  local distinct = 0
  for _ in pairs(ranges) do
    distinct = distinct + 1
  end
  luaunit.assertEquals(distinct, 3)
end

function TestSpotterRangeDraw:test_a_unit_that_sees_nothing_is_not_jittered()
  -- 0 ± 20 % is still 0, but only if the draw is skipped rather than applied: this pins that a
  -- blind unit cannot acquire eyes through arithmetic.
  luaunit.assertEquals(veafSkynet.getSpotterProfile(_unit("S1", { ["SAM elements"] = true })).range, 0)
end

-- ---------------------------------------------------------------------------
-- The latch
-- ---------------------------------------------------------------------------
TestSpotterLatch = {}

function TestSpotterLatch:setUp()
  _resetSpotterState()
end

--- Run one beat of the latch, with a line of sight that always answers `visible`.
local function _beat(inRange, stillInRange, visible)
  return veafSkynet.stepSpotterLatch("spotter", "bandit", inRange, stillInRange, function()
    return visible
  end)
end

function TestSpotterLatch:test_reports_once_on_acquisition()
  luaunit.assertEquals(_beat(true, true, true), "acquired")
end

function TestSpotterLatch:test_silent_while_it_keeps_seeing_it()
  _beat(true, true, true)
  luaunit.assertNil(_beat(true, true, true))
  luaunit.assertNil(_beat(true, true, true))
  luaunit.assertNil(_beat(true, true, true))
end

function TestSpotterLatch:test_re_arms_after_three_beats_and_not_two()
  _beat(true, true, true)
  luaunit.assertNil(_beat(false, false, false))
  luaunit.assertNil(_beat(false, false, false))
  luaunit.assertEquals(_beat(false, false, false), "lost")
end

function TestSpotterLatch:test_a_single_missed_beat_does_not_lose_the_contact()
  -- Terrain masking: an aircraft dropping behind a ridge for a few seconds is not lost.
  _beat(true, true, true)
  luaunit.assertNil(_beat(false, false, false))
  luaunit.assertNil(_beat(true, true, true))
  -- ...and the counter was reset, so it now takes three fresh misses again.
  luaunit.assertNil(_beat(false, false, false))
  luaunit.assertNil(_beat(false, false, false))
  luaunit.assertEquals(_beat(false, false, false), "lost")
end

function TestSpotterLatch:test_reports_again_after_reacquisition()
  _beat(true, true, true)
  _beat(false, false, false)
  _beat(false, false, false)
  _beat(false, false, false)
  luaunit.assertEquals(_beat(true, true, true), "acquired")
end

function TestSpotterLatch:test_the_margin_holds_an_aircraft_orbiting_on_the_limit()
  -- Between range and range x 1.1: acquired, then held, and one report in total. Without the margin
  -- this flickers, and each flicker is a message crossing the whole network.
  luaunit.assertEquals(_beat(true, true, true), "acquired")
  for _ = 1, 20 do
    luaunit.assertNil(_beat(false, true, true))
  end
end

function TestSpotterLatch:test_the_margin_does_not_let_it_be_acquired_from_outside()
  -- The margin widens *losing*, never *gaining*. An aircraft that never comes inside the range is
  -- never reported.
  for _ = 1, 10 do
    luaunit.assertNil(_beat(false, true, true))
  end
end

function TestSpotterLatch:test_two_spotters_latch_independently()
  veafSkynet.stepSpotterLatch("alpha", "bandit", true, true, function()
    return true
  end)
  local event = veafSkynet.stepSpotterLatch("bravo", "bandit", true, true, function()
    return true
  end)
  luaunit.assertEquals(event, "acquired")
end

function TestSpotterLatch:test_a_forgotten_spotter_keeps_nothing()
  _beat(true, true, true)
  veafSkynet.forgetSpotter("spotter")
  luaunit.assertEquals(_beat(true, true, true), "acquired")
end

-- ---------------------------------------------------------------------------
-- Line of sight
-- ---------------------------------------------------------------------------
TestSpotterLineOfSight = {}

function TestSpotterLineOfSight:setUp()
  _resetSpotterState()
end

function TestSpotterLineOfSight:test_masked_at_acquisition_produces_no_report()
  luaunit.assertNil(_beat(true, true, false))
end

function TestSpotterLineOfSight:test_masked_at_loss_loses_the_contact()
  -- In range the whole time, but the ridge is in the way: the contact is given up all the same,
  -- which is the half a distance-only implementation gets wrong.
  _beat(true, true, true)
  _beat(true, true, false)
  _beat(true, true, false)
  luaunit.assertEquals(_beat(true, true, false), "lost")
end

function TestSpotterLineOfSight:test_the_ray_starts_above_the_spotter()
  -- Two metres up, so a spotter looks from its eyes rather than from the mud.
  veafSkynet.spotterHasLineOfSight({ x = 100, y = 50, z = 200 }, { x = 0, y = 3000, z = 0 })
  luaunit.assertEquals(#dcs_mocks.visibilityCalls, 1)
  luaunit.assertEquals(dcs_mocks.visibilityCalls[1].from.y, 52)
  luaunit.assertEquals(dcs_mocks.visibilityCalls[1].from.x, 100)
  luaunit.assertEquals(dcs_mocks.visibilityCalls[1].to.y, 3000)
end

function TestSpotterLineOfSight:test_a_blocked_ray_is_not_seen()
  dcs_mocks.visibilityAnswer = false
  luaunit.assertFalse(veafSkynet.spotterHasLineOfSight({ x = 0, y = 0, z = 0 }, { x = 0, y = 1000, z = 0 }))
end

-- ---------------------------------------------------------------------------
-- The derived hop period
-- ---------------------------------------------------------------------------
TestSpotterHopPeriod = {}

function TestSpotterHopPeriod:setUp()
  _resetSpotterState()
end

function TestSpotterHopPeriod:test_twenty_seconds_at_the_defaults()
  luaunit.assertEquals(veafSkynet.getSpotterHopPeriod(), 20)
end

function TestSpotterHopPeriod:test_widening_the_range_slows_the_hop_and_leaves_the_speed_alone()
  -- The whole reason a speed is exposed rather than a period: doubling the range must not double how
  -- fast an alert crosses the map. This is the trap the design exists to close, so it is asserted
  -- rather than commented.
  veafSkynet.SpotterRadioRange = 40000
  luaunit.assertEquals(veafSkynet.getSpotterHopPeriod(), 40)
  luaunit.assertEquals(veafSkynet.SpotterRadioRange / veafSkynet.getSpotterHopPeriod(), 1000)
end

function TestSpotterHopPeriod:test_a_zero_speed_does_not_stop_the_network()
  veafSkynet.SpotterPropagationSpeed = 0
  luaunit.assertEquals(veafSkynet.getSpotterHopPeriod(), 20)
end

-- ---------------------------------------------------------------------------
-- The beat, end to end
-- ---------------------------------------------------------------------------
TestSpotterDetectionBeat = {}

function TestSpotterDetectionBeat:setUp()
  _resetSpotterState()
  veafSkynet.SpotterNetwork = true
  veafSkynet.SpotterRangeJitter = 0
  veafSkynet.structure = {
    ["red iads"] = { coalitionID = coalition.side.RED },
  }
  self.acquired = {}
  self.lost = {}
  self._realAcquired = veafSkynet.onSpotterAcquired
  self._realLost = veafSkynet.onSpotterLost
  veafSkynet.onSpotterAcquired = function(spotterName, contactName)
    table.insert(self.acquired, spotterName .. "->" .. contactName)
  end
  veafSkynet.onSpotterLost = function(spotterName, contactName)
    table.insert(self.lost, spotterName .. "->" .. contactName)
  end
end

function TestSpotterDetectionBeat:tearDown()
  veafSkynet.onSpotterAcquired = self._realAcquired
  veafSkynet.onSpotterLost = self._realLost
  veafSkynet.SpotterRangeJitter = 0.2
  coalition.getGroups = _realGetGroups
end

--- One RED tank at the origin, one BLUE aeroplane `distance` metres east of it at 1 000 m.
function TestSpotterDetectionBeat:_layout(distance)
  self.tank = _unit("RedTank", { ["Tanks"] = true }, 0, 0, 0)
  self.bandit = _unit("BlueJet", { ["Air"] = true }, 0, 1000, distance)
  _stubGetGroups({
    [coalition.side.RED] = { _group("RedGroup", { self.tank }) },
    [coalition.side.BLUE .. ":" .. Group.Category.AIRPLANE] = { _group("BlueGroup", { self.bandit }) },
  })
end

function TestSpotterDetectionBeat:test_a_tank_reports_an_aircraft_within_range()
  self:_layout(2000)
  veafSkynet.spotterDetectionBeat()
  luaunit.assertEquals(self.acquired, { "RedTank->BlueJet" })
end

function TestSpotterDetectionBeat:test_it_reports_once_and_then_stays_quiet()
  self:_layout(2000)
  veafSkynet.spotterDetectionBeat()
  veafSkynet.spotterDetectionBeat()
  veafSkynet.spotterDetectionBeat()
  luaunit.assertEquals(#self.acquired, 1)
end

function TestSpotterDetectionBeat:test_an_aircraft_beyond_range_is_not_reported()
  -- 3 000 m of range against a contact 4 000 m away on the ground and 1 000 m up.
  self:_layout(4000)
  veafSkynet.spotterDetectionBeat()
  luaunit.assertEquals(#self.acquired, 0)
end

function TestSpotterDetectionBeat:test_altitude_counts_towards_the_distance()
  -- Directly overhead at 4 000 m: out of a 3 000 m range, which a ground-range implementation would
  -- have reported as sitting on top of the spotter.
  self.tank = _unit("RedTank", { ["Tanks"] = true }, 0, 0, 0)
  self.bandit = _unit("BlueJet", { ["Air"] = true }, 0, 4000, 0)
  _stubGetGroups({
    [coalition.side.RED] = { _group("RedGroup", { self.tank }) },
    [coalition.side.BLUE .. ":" .. Group.Category.AIRPLANE] = { _group("BlueGroup", { self.bandit }) },
  })
  veafSkynet.spotterDetectionBeat()
  luaunit.assertEquals(#self.acquired, 0)
end

function TestSpotterDetectionBeat:test_a_pair_the_distance_settles_costs_no_ray()
  -- This is the affordability property, and it is about **pairs**, not beats: the overwhelming
  -- majority of spotter/aircraft pairs on a mission are tens of kilometres apart, and none of them
  -- may cost a terrain query. Ten beats with the aircraft far out of range, and no ray at all.
  --
  -- The design says the ray is traced "only on transitions". That is not implementable alongside
  -- its own requirement that masking lose a held contact — see
  -- `test_a_held_contact_costs_exactly_one_ray_per_beat` below.
  self:_layout(40000)
  for _ = 1, 10 do
    veafSkynet.spotterDetectionBeat()
  end
  luaunit.assertEquals(#dcs_mocks.visibilityCalls, 0)
end

function TestSpotterDetectionBeat:test_a_held_contact_costs_exactly_one_ray_per_beat()
  -- One, and not two: the latch asks its closure twice on a transition, and the ray behind it is
  -- memoised for the pair within the beat. A regression here doubles the terrain queries of the
  -- whole mission without changing a single observable behaviour.
  self:_layout(2000)
  veafSkynet.spotterDetectionBeat()
  local afterAcquisition = #dcs_mocks.visibilityCalls
  luaunit.assertEquals(afterAcquisition, 1)
  for _ = 1, 10 do
    veafSkynet.spotterDetectionBeat()
  end
  luaunit.assertEquals(#dcs_mocks.visibilityCalls, afterAcquisition + 10)
end

function TestSpotterDetectionBeat:test_nothing_happens_when_the_feature_is_off()
  self:_layout(2000)
  veafSkynet.SpotterNetwork = false
  veafSkynet.spotterDetectionBeat()
  luaunit.assertEquals(#self.acquired, 0)
end

function TestSpotterDetectionBeat:test_nothing_happens_without_a_skynet_network()
  -- The feature lives inside the helper and does nothing when Skynet is off: the no-Skynet
  -- alarm-state fallback was dropped on 2026-09-20.
  self:_layout(2000)
  veafSkynet.structure = {}
  veafSkynet.spotterDetectionBeat()
  luaunit.assertEquals(#self.acquired, 0)
end

function TestSpotterDetectionBeat:test_a_deactivated_network_does_not_spot()
  self:_layout(2000)
  veafSkynet.structure = { ["red iads"] = { coalitionID = coalition.side.RED, deactivated = true } }
  veafSkynet.spotterDetectionBeat()
  luaunit.assertEquals(#self.acquired, 0)
end

function TestSpotterDetectionBeat:test_a_grounded_aircraft_is_not_a_contact()
  self:_layout(2000)
  self.bandit.inAir = function()
    return false
  end
  veafSkynet.spotterDetectionBeat()
  luaunit.assertEquals(#self.acquired, 0)
end

function TestSpotterDetectionBeat:test_a_sam_site_in_range_reports_nothing()
  local sam = _unit("RedSam", { ["SAM elements"] = true }, 0, 0, 0)
  local bandit = _unit("BlueJet", { ["Air"] = true }, 0, 1000, 2000)
  _stubGetGroups({
    [coalition.side.RED] = { _group("RedGroup", { sam }) },
    [coalition.side.BLUE .. ":" .. Group.Category.AIRPLANE] = { _group("BlueGroup", { bandit }) },
  })
  veafSkynet.spotterDetectionBeat()
  luaunit.assertEquals(#self.acquired, 0)
end

function TestSpotterDetectionBeat:test_a_friendly_aircraft_is_not_a_contact()
  local tank = _unit("RedTank", { ["Tanks"] = true }, 0, 0, 0)
  local friend = _unit("RedJet", { ["Air"] = true }, 0, 1000, 2000)
  _stubGetGroups({
    [coalition.side.RED] = { _group("RedGroup", { tank }) },
    [coalition.side.RED .. ":" .. Group.Category.AIRPLANE] = { _group("RedAir", { friend }) },
  })
  veafSkynet.spotterDetectionBeat()
  luaunit.assertEquals(#self.acquired, 0)
end

function TestSpotterDetectionBeat:test_the_beat_reports_a_loss_after_the_tolerance()
  self:_layout(2000)
  veafSkynet.spotterDetectionBeat()
  -- The aircraft flies off; the point table the double hands out is the one it holds, so moving it
  -- moves the aircraft.
  self.bandit._point.z = 50000
  veafSkynet.spotterDetectionBeat()
  veafSkynet.spotterDetectionBeat()
  luaunit.assertEquals(#self.lost, 0)
  veafSkynet.spotterDetectionBeat()
  luaunit.assertEquals(self.lost, { "RedTank->BlueJet" })
end

function TestSpotterDetectionBeat:test_a_dead_group_does_not_take_the_beat_down()
  self:_layout(2000)
  local corpse = _group("DeadGroup", {})
  corpse.isExist = function()
    return false
  end
  corpse.getUnits = function()
    error("group does not exist")
  end
  _stubGetGroups({
    [coalition.side.RED] = { corpse, _group("RedGroup", { self.tank }) },
    [coalition.side.BLUE .. ":" .. Group.Category.AIRPLANE] = { _group("BlueGroup", { self.bandit }) },
  })
  veafSkynet.spotterDetectionBeat()
  luaunit.assertEquals(self.acquired, { "RedTank->BlueJet" })
end

function TestSpotterDetectionBeat:test_the_beat_re_arms_itself()
  -- It returns its own period, which is how DCS keeps a repeating schedule alive.
  self:_layout(2000)
  luaunit.assertEquals(veafSkynet.spotterDetectionBeat(), veafSkynet.SpotterDetectionPeriod)
end

-- ---------------------------------------------------------------------------
-- Wiring — the loop is actually scheduled
--
-- The defect class that shipped green in August: tests that called the handler and never what
-- branches it.
-- ---------------------------------------------------------------------------
TestSpotterWiring = {}

function TestSpotterWiring:setUp()
  _resetSpotterState()
  -- Capture what the module asks the scheduler for, the way the vanished-sites sweep is asserted in
  -- `test_veafSkynetIadsHelper.lua`: `veaf.scheduleFunction` wraps the real function in a task of
  -- its own before it reaches `timer.scheduleFunction`, so the mock's task list never names it.
  self.scheduled = {}
  self.previousSchedule = veaf.scheduleFunction
  veaf.scheduleFunction = function(fn, vars, t, rep)
    table.insert(self.scheduled, { fn = fn, time = t, rep = rep })
    return #self.scheduled
  end
end

function TestSpotterWiring:tearDown()
  veaf.scheduleFunction = self.previousSchedule
  veafSkynet.SpotterNetwork = false
  veafSkynet.spotterDetectionArmed = false
end

--- What was scheduled for the detection beat.
function TestSpotterWiring:_beats()
  local found = {}
  for _, task in ipairs(self.scheduled) do
    if task.fn == veafSkynet.spotterDetectionBeat then
      table.insert(found, task)
    end
  end
  return found
end

function TestSpotterWiring:test_the_detection_beat_is_scheduled_when_the_feature_is_on()
  veafSkynet.SpotterNetwork = true
  veafSkynet._armSpotterDetection()
  luaunit.assertEquals(#self:_beats(), 1)
end

function TestSpotterWiring:test_nothing_is_scheduled_when_the_feature_is_off()
  veafSkynet.SpotterNetwork = false
  veafSkynet._armSpotterDetection()
  luaunit.assertEquals(#self:_beats(), 0)
end

function TestSpotterWiring:test_arming_twice_does_not_stack_a_second_beat()
  -- Reinitialising the IADS must not make every sighting be reported twice — the shape of #824.
  veafSkynet.SpotterNetwork = true
  veafSkynet._armSpotterDetection()
  veafSkynet._armSpotterDetection()
  veafSkynet._armSpotterDetection()
  luaunit.assertEquals(#self:_beats(), 1)
end

function TestSpotterWiring:test_it_is_armed_at_the_detection_period_and_repeats()
  veafSkynet.SpotterNetwork = true
  veafSkynet._armSpotterDetection()
  local beat = self:_beats()[1]
  luaunit.assertEquals(beat.time, timer.getTime() + veafSkynet.SpotterDetectionPeriod)
  luaunit.assertEquals(beat.rep, veafSkynet.SpotterDetectionPeriod)
end

function TestSpotterWiring:test_a_lost_unit_forgets_what_it_was_watching()
  veafSkynet.spotterLatches["RedTank"] = { ["BlueJet"] = { triggered = true, missedBeats = 0 } }
  veafSkynet.onUnitLost({ initiator = {
    getName = function()
      return "RedTank"
    end,
  } })
  luaunit.assertNil(veafSkynet.spotterLatches["RedTank"])
end

os.exit(luaunit.LuaUnit.run())
