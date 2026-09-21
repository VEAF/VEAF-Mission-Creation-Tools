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
-- Loaded so the radio-menu tests compare against real words. Without the catalogue every key
-- falls back to itself, and a test then cannot tell a menu that reads "Show the spotter view"
-- from one that shows the player `menu.skynet.spotterview.show`.
dofile(src .. "/veafI18n.lua")

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
  veafSkynet.spotterContacts = {}
  veafSkynet.spotterWaves = {}
  veafSkynet.spotterPropagationArmed = false
  veafSkynet.spotterDetectionArmed = false
  veafSkynet.spotterGraphArmed = false
  veafSkynet.spotterGraphs = {}
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

function TestSpotterHopPeriod:test_a_zero_range_does_not_leave_the_network_inert()
  -- Refused in one place, because a zero range refused only in the hop period would still build a
  -- graph with no edges: the feature on, costing its beats, doing nothing, and nothing in the log.
  veafSkynet.SpotterRadioRange = 0
  luaunit.assertEquals(veafSkynet.getSpotterRadioRange(), 20000)
  luaunit.assertEquals(veafSkynet.getSpotterHopPeriod(), 20)
end

function TestSpotterHopPeriod:test_the_graph_uses_the_guarded_range()
  -- The assertion that keeps the guard in *one* place: a nonsensical range must not reach the edges.
  veafSkynet.SpotterRadioRange = -5
  local graph = { adjacency = {}, nodes = {} }
  veafSkynet.reEdgeSpotterNode(graph, "A", 0, 0, veafSkynet.SpotterSpeedClasses.Mobile)
  veafSkynet.reEdgeSpotterNode(graph, "B", 0, 5000, veafSkynet.SpotterSpeedClasses.Mobile)
  luaunit.assertTrue(graph.adjacency["A"]["B"])
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
  veafSkynet.onSpotterAcquired = function(coa, spotterName, contactName)
    table.insert(self.acquired, coa .. ":" .. spotterName .. "->" .. contactName)
  end
  veafSkynet.onSpotterLost = function(coa, spotterName, contactName)
    table.insert(self.lost, coa .. ":" .. spotterName .. "->" .. contactName)
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
  luaunit.assertEquals(self.acquired, { coalition.side.RED .. ":RedTank->BlueJet" })
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
  luaunit.assertEquals(self.lost, { coalition.side.RED .. ":RedTank->BlueJet" })
end

function TestSpotterDetectionBeat:test_an_aircraft_that_leaves_the_sky_re_arms_the_latch()
  -- Found in review, and it was the serious one. The loop can only step the pairs it walks, and it
  -- walks the aircraft currently in the sky; an aircraft shot down simply stops appearing. Left
  -- alone, its latch stayed *triggered* for the rest of the mission, the heartbeat kept speaking for
  -- it, and the contact was refreshed past the forget delay forever.
  self:_layout(2000)
  veafSkynet.spotterDetectionBeat()
  luaunit.assertTrue(veafSkynet.spotterLatches["RedTank"]["BlueJet"].triggered)

  _stubGetGroups({ [coalition.side.RED] = { _group("RedGroup", { self.tank }) } })
  veafSkynet.spotterDetectionBeat()
  luaunit.assertNil((veafSkynet.spotterLatches["RedTank"] or {})["BlueJet"])
end

function TestSpotterDetectionBeat:test_a_landed_aircraft_re_arms_the_latch_too()
  -- Same path, through the `inAir()` filter rather than through destruction.
  self:_layout(2000)
  veafSkynet.spotterDetectionBeat()
  self.bandit.inAir = function()
    return false
  end
  veafSkynet.spotterDetectionBeat()
  luaunit.assertNil((veafSkynet.spotterLatches["RedTank"] or {})["BlueJet"])
end

function TestSpotterDetectionBeat:test_giving_up_a_vanished_contact_cancels_it_on_the_network()
  -- The sites holding it are elsewhere on the map and have no other way of being told.
  self:_layout(2000)
  veafSkynet.spotterDetectionBeat()
  veafSkynet.spotterWaves = {}
  _stubGetGroups({ [coalition.side.RED] = { _group("RedGroup", { self.tank }) } })
  timer.setTime(timer.getTime() + 1)
  veafSkynet.spotterDetectionBeat()
  local waves = veafSkynet.spotterWaves[coalition.side.RED] or {}
  luaunit.assertEquals(#waves, 1)
  luaunit.assertEquals(waves[1].kind, "cancel")
  luaunit.assertEquals(waves[1].aircraft, "BlueJet")
end

function TestSpotterDetectionBeat:test_the_heartbeat_stops_speaking_for_a_vanished_contact()
  -- The reading that showed the defect: before the fix, a jet shot down two hours ago still produced
  -- a wave crossing the whole network every two minutes.
  self:_layout(2000)
  veafSkynet.spotterDetectionBeat()
  _stubGetGroups({ [coalition.side.RED] = { _group("RedGroup", { self.tank }) } })
  veafSkynet.spotterDetectionBeat()

  local graph = veafSkynet.getSpotterGraph(coalition.side.RED)
  graph.nodes["RedTank"] = { x = 0, z = 0, class = veafSkynet.SpotterSpeedClasses.Mobile }
  graph.adjacency["RedTank"] = {}
  veafSkynet.spotterWaves = {}
  veafSkynet.spotterHeartbeat()
  luaunit.assertEquals(#(veafSkynet.spotterWaves[coalition.side.RED] or {}), 0)
end

function TestSpotterDetectionBeat:test_a_contact_still_in_the_sky_keeps_its_latch()
  -- The other half: giving up on absence must not give up on anything present, or a held contact
  -- would be re-reported every single beat.
  self:_layout(2000)
  veafSkynet.spotterDetectionBeat()
  for _ = 1, 10 do
    veafSkynet.spotterDetectionBeat()
  end
  luaunit.assertTrue(veafSkynet.spotterLatches["RedTank"]["BlueJet"].triggered)
  luaunit.assertEquals(#self.acquired, 1)
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
  luaunit.assertEquals(self.acquired, { coalition.side.RED .. ":RedTank->BlueJet" })
end

function TestSpotterDetectionBeat:test_the_beat_returns_nothing()
  -- `veafScheduler` re-arms a repeating task from its own `rep` and ignores what the task returned.
  -- A period handed back here would read as if it drove the schedule while driving nothing, and a
  -- test asserting it would look like proof of re-arming and be proof of nothing. What actually
  -- keeps the beat alive is asserted in TestSpotterWiring.
  self:_layout(2000)
  luaunit.assertNil(veafSkynet.spotterDetectionBeat())
end

-- ---------------------------------------------------------------------------
-- The radio graph
-- ---------------------------------------------------------------------------
TestSpotterGraph = {}

function TestSpotterGraph:setUp()
  _resetSpotterState()
  veafSkynet.SpotterNetwork = true
  veafSkynet.spotterGraphs = {}
  veafSkynet.spotterGraphArmed = false
  veafSkynet.structure = { ["red iads"] = { coalitionID = coalition.side.RED } }
end

function TestSpotterGraph:tearDown()
  veafSkynet.spotterGraphs = {}
  coalition.getGroups = _realGetGroups
end

--- Put these RED relays on the map. `units` is an array of `{ name, x, z, attributes }`.
function TestSpotterGraph:_relays(units)
  local built = {}
  self.units = {}
  for _, spec in ipairs(units) do
    local unit = _unit(spec.name, spec.attributes or { ["Tanks"] = true }, spec.x, 0, spec.z)
    self.units[spec.name] = unit
    table.insert(built, unit)
  end
  _stubGetGroups({ [coalition.side.RED] = { _group("RedGroup", built) } })
  return built
end

function TestSpotterGraph:_graph()
  return veafSkynet.getSpotterGraph(coalition.side.RED)
end

function TestSpotterGraph:test_two_units_within_the_radio_range_are_linked()
  self:_relays({ { name = "A", x = 0, z = 0 }, { name = "B", x = 0, z = 5000 } })
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  luaunit.assertTrue(self:_graph().adjacency["A"]["B"])
  luaunit.assertTrue(self:_graph().adjacency["B"]["A"])
end

function TestSpotterGraph:test_two_units_beyond_the_radio_range_are_not_linked()
  self:_relays({ { name = "A", x = 0, z = 0 }, { name = "B", x = 0, z = 25000 } })
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  luaunit.assertNil(self:_graph().adjacency["A"]["B"])
  luaunit.assertNil(self:_graph().adjacency["B"]["A"])
end

function TestSpotterGraph:test_the_adjacency_is_a_set_and_not_a_list()
  -- Measured, not taste: removing a back-edge from a list means scanning it, and re-edging a hundred
  -- units costs 86 ms with lists against 13.7 ms with sets on the densest layout built. A test that
  -- only checked reachability would pass on the slow representation too.
  self:_relays({ { name = "A", x = 0, z = 0 }, { name = "B", x = 0, z = 5000 } })
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  local edges = self:_graph().adjacency["A"]
  luaunit.assertEquals(edges["B"], true)
  luaunit.assertEquals(#edges, 0) -- no array part at all
end

function TestSpotterGraph:test_a_unit_that_appears_joins_at_the_next_pass()
  self:_relays({ { name = "A", x = 0, z = 0 } })
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  luaunit.assertNil(self:_graph().nodes["B"])
  self:_relays({ { name = "A", x = 0, z = 0 }, { name = "B", x = 0, z = 5000 } })
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  luaunit.assertNotNil(self:_graph().nodes["B"])
  luaunit.assertTrue(self:_graph().adjacency["A"]["B"])
end

function TestSpotterGraph:test_a_unit_that_dies_leaves_at_the_next_pass()
  self:_relays({ { name = "A", x = 0, z = 0 }, { name = "B", x = 0, z = 5000 } })
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  self:_relays({ { name = "A", x = 0, z = 0 } })
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  luaunit.assertNil(self:_graph().nodes["B"])
  -- And its back-edge went with it, which is the half a naive removal leaves behind.
  luaunit.assertNil(self:_graph().adjacency["A"]["B"])
end

function TestSpotterGraph:test_a_pass_only_touches_its_own_class()
  self:_relays({
    { name = "Tank", x = 0, z = 0, attributes = { ["Tanks"] = true } },
    { name = "Grunt", x = 0, z = 5000, attributes = { ["Infantry"] = true } },
  })
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  luaunit.assertNotNil(self:_graph().nodes["Tank"])
  luaunit.assertNil(self:_graph().nodes["Grunt"])
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Slow)
  luaunit.assertNotNil(self:_graph().nodes["Grunt"])
  luaunit.assertTrue(self:_graph().adjacency["Tank"]["Grunt"])
end

function TestSpotterGraph:test_a_vanished_unit_of_another_class_is_left_alone()
  -- The mobile pass must not evict the infantry it cannot see: only nodes of its own class count as
  -- gone when they are missing from its listing.
  self:_relays({
    { name = "Tank", x = 0, z = 0, attributes = { ["Tanks"] = true } },
    { name = "Grunt", x = 0, z = 5000, attributes = { ["Infantry"] = true } },
  })
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Slow)
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  luaunit.assertNotNil(self:_graph().nodes["Grunt"])
end

function TestSpotterGraph:test_a_unit_that_moved_less_than_the_threshold_is_not_re_edged()
  self:_relays({ { name = "A", x = 0, z = 0 }, { name = "B", x = 0, z = 5000 } })
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  local before = self:_graph().nodes["A"]
  self.units["A"]._point.x = 1500 -- under the 2 km threshold
  self:_relays({ { name = "A", x = 1500, z = 0 }, { name = "B", x = 0, z = 5000 } })
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  -- The stored position is still the one the edges were measured from, which is the whole point of
  -- the threshold: it is a *reference*, not a last-known position.
  luaunit.assertEquals(self:_graph().nodes["A"].x, before.x)
end

function TestSpotterGraph:test_a_unit_that_moved_past_the_threshold_is_re_edged()
  self:_relays({ { name = "A", x = 0, z = 0 }, { name = "B", x = 0, z = 5000 } })
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  luaunit.assertTrue(self:_graph().adjacency["A"]["B"])
  self:_relays({ { name = "A", x = 100000, z = 0 }, { name = "B", x = 0, z = 5000 } })
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  luaunit.assertEquals(self:_graph().nodes["A"].x, 100000)
  luaunit.assertNil(self:_graph().adjacency["A"]["B"])
  luaunit.assertNil(self:_graph().adjacency["B"]["A"])
end

function TestSpotterGraph:test_a_unit_that_cannot_relay_is_not_in_the_graph()
  self:_relays({
    { name = "Tank", x = 0, z = 0, attributes = { ["Tanks"] = true } },
    { name = "Shed", x = 0, z = 1000, attributes = { ["Fortifications"] = true } },
  })
  for _, class in pairs(veafSkynet.SpotterSpeedClasses) do
    veafSkynet.spotterGraphPass(class)
  end
  luaunit.assertNil(self:_graph().nodes["Shed"])
end

function TestSpotterGraph:test_a_sam_site_is_in_the_graph_although_it_never_spots()
  -- What produces the domino: a battery that is warned lights up *and* passes the word, so a line of
  -- batteries wakes in the direction of the penetration.
  self:_relays({
    { name = "Sam", x = 0, z = 0, attributes = { ["SAM elements"] = true } },
    { name = "Tank", x = 0, z = 5000, attributes = { ["Tanks"] = true } },
  })
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  luaunit.assertTrue(self:_graph().adjacency["Sam"]["Tank"])
end

function TestSpotterGraph:test_the_graph_stays_symmetric_after_a_move()
  self:_relays({
    { name = "A", x = 0, z = 0 },
    { name = "B", x = 0, z = 5000 },
    { name = "C", x = 0, z = 10000 },
  })
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  self:_relays({
    { name = "A", x = 0, z = 0 },
    { name = "B", x = 0, z = 40000 },
    { name = "C", x = 0, z = 10000 },
  })
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  local adjacency = self:_graph().adjacency
  for from, edges in pairs(adjacency) do
    for to, _ in pairs(edges) do
      luaunit.assertTrue(adjacency[to][from], from .. " reaches " .. to .. " but not the other way")
    end
  end
end

function TestSpotterGraph:test_nothing_is_built_when_the_feature_is_off()
  self:_relays({ { name = "A", x = 0, z = 0 } })
  veafSkynet.SpotterNetwork = false
  veafSkynet.spotterGraphPass(veafSkynet.SpotterSpeedClasses.Mobile)
  luaunit.assertNil(self:_graph().nodes["A"])
end

function TestSpotterGraph:test_each_class_has_a_period_of_its_own()
  -- What the periods *are*; that they reach the scheduler is asserted in TestSpotterWiring.
  luaunit.assertEquals(veafSkynet.SpotterGraphPeriods[veafSkynet.SpotterSpeedClasses.Fast], 10)
  luaunit.assertEquals(veafSkynet.SpotterGraphPeriods[veafSkynet.SpotterSpeedClasses.Mobile], 20)
  luaunit.assertEquals(veafSkynet.SpotterGraphPeriods[veafSkynet.SpotterSpeedClasses.Slow], 30)
end

-- ---------------------------------------------------------------------------
-- Propagation: alert, cancellation, heartbeat
-- ---------------------------------------------------------------------------
TestSpotterPropagation = {}

local RED = coalition.side.RED

function TestSpotterPropagation:setUp()
  _resetSpotterState()
  veafSkynet.SpotterNetwork = true
  veafSkynet.structure = { ["red iads"] = { coalitionID = RED } }
end

function TestSpotterPropagation:tearDown()
  coalition.getGroups = _realGetGroups
end

--- Build a graph by hand: `chain("A", "B", "C")` links A-B and B-C and nothing else.
---
--- Hand-built rather than grown through `spotterGraphPass`, so a propagation test fails for a
--- propagation reason and never for a graph one.
local function _chain(...)
  local names = { ... }
  local graph = veafSkynet.getSpotterGraph(RED)
  for _, name in ipairs(names) do
    graph.adjacency[name] = graph.adjacency[name] or {}
    graph.nodes[name] = { x = 0, z = 0, class = veafSkynet.SpotterSpeedClasses.Mobile }
  end
  for i = 1, #names - 1 do
    graph.adjacency[names[i]][names[i + 1]] = true
    graph.adjacency[names[i + 1]][names[i]] = true
  end
  return graph
end

local function _holds(unitName, aircraft)
  local contact = veafSkynet.getSpotterContacts(RED, unitName)[aircraft]
  return contact ~= nil and not contact.cancelled
end

function TestSpotterPropagation:test_the_spotter_holds_the_contact_immediately()
  _chain("A", "B", "C")
  veafSkynet.emitSpotterMessage(RED, "alert", "A", "Bandit")
  luaunit.assertTrue(_holds("A", "Bandit"))
end

function TestSpotterPropagation:test_it_reaches_k_hops_away_after_k_periods()
  _chain("A", "B", "C", "D")
  veafSkynet.emitSpotterMessage(RED, "alert", "A", "Bandit")
  luaunit.assertFalse(_holds("B", "Bandit"))

  veafSkynet.spotterPropagationTick()
  luaunit.assertTrue(_holds("B", "Bandit"))
  -- ...and no sooner. The "no sooner" half is what catches an accidental flood.
  luaunit.assertFalse(_holds("C", "Bandit"))

  veafSkynet.spotterPropagationTick()
  luaunit.assertTrue(_holds("C", "Bandit"))
  luaunit.assertFalse(_holds("D", "Bandit"))

  veafSkynet.spotterPropagationTick()
  luaunit.assertTrue(_holds("D", "Bandit"))
end

function TestSpotterPropagation:test_a_wave_terminates()
  -- Each unit relays a given message at most once, because the message carries a fixed stamp. A
  -- cycle in the graph must not make it circulate forever.
  local graph = _chain("A", "B", "C")
  graph.adjacency["C"]["A"] = true
  graph.adjacency["A"]["C"] = true
  veafSkynet.emitSpotterMessage(RED, "alert", "A", "Bandit")
  for _ = 1, 20 do
    veafSkynet.spotterPropagationTick()
  end
  luaunit.assertEquals(#(veafSkynet.spotterWaves[RED] or {}), 0)
end

function TestSpotterPropagation:test_an_alert_does_not_leave_its_pocket()
  -- Two islands, no edge between them. An alert never leaves the pocket it starts in, which is the
  -- whole reason the radio range decides whether this feature does anything at all.
  _chain("A", "B")
  _chain("Y", "Z")
  veafSkynet.emitSpotterMessage(RED, "alert", "A", "Bandit")
  for _ = 1, 10 do
    veafSkynet.spotterPropagationTick()
  end
  luaunit.assertTrue(_holds("B", "Bandit"))
  luaunit.assertFalse(_holds("Y", "Bandit"))
  luaunit.assertFalse(_holds("Z", "Bandit"))
end

function TestSpotterPropagation:test_two_spotters_in_one_pocket_merge()
  -- Both ends of a five-unit chain see the same aircraft. The middle is served by whichever wave
  -- reached it first — the nearest witness — and the other is not relayed past it.
  _chain("A", "B", "C", "D", "E")
  veafSkynet.emitSpotterMessage(RED, "alert", "A", "Bandit")
  veafSkynet.emitSpotterMessage(RED, "alert", "E", "Bandit")
  for _ = 1, 10 do
    veafSkynet.spotterPropagationTick()
  end
  for _, name in ipairs({ "A", "B", "C", "D", "E" }) do
    luaunit.assertTrue(_holds(name, "Bandit"), name .. " should hold the contact")
  end
  luaunit.assertEquals(#(veafSkynet.spotterWaves[RED] or {}), 0)
end

function TestSpotterPropagation:test_two_spotters_in_separate_pockets_stay_independent()
  _chain("A", "B")
  _chain("Y", "Z")
  veafSkynet.emitSpotterMessage(RED, "alert", "A", "Bandit")
  veafSkynet.emitSpotterMessage(RED, "alert", "Y", "Bandit")
  for _ = 1, 10 do
    veafSkynet.spotterPropagationTick()
  end
  -- Each front served its own pocket, and neither marked the other's units on the way.
  luaunit.assertEquals(veafSkynet.getSpotterContacts(RED, "B")["Bandit"].origin, "A")
  luaunit.assertEquals(veafSkynet.getSpotterContacts(RED, "Z")["Bandit"].origin, "Y")
end

function TestSpotterPropagation:test_a_cancellation_extinguishes_along_the_path()
  _chain("A", "B", "C")
  veafSkynet.emitSpotterMessage(RED, "alert", "A", "Bandit")
  veafSkynet.spotterPropagationTick()
  veafSkynet.spotterPropagationTick()
  luaunit.assertTrue(_holds("C", "Bandit"))

  timer.setTime(timer.getTime() + 1)
  veafSkynet.emitSpotterMessage(RED, "cancel", "A", "Bandit")
  veafSkynet.spotterPropagationTick()
  veafSkynet.spotterPropagationTick()
  luaunit.assertFalse(_holds("A", "Bandit"))
  luaunit.assertFalse(_holds("B", "Bandit"))
  luaunit.assertFalse(_holds("C", "Bandit"))
end

function TestSpotterPropagation:test_a_cancellation_arriving_before_its_alert_is_not_undone()
  -- The ordering rule. The graph is reconfigured between the two, so a cancellation can overtake the
  -- alert it belongs to; without the rule the site would hold that contact forever.
  _chain("A", "B")
  local alert = { kind = "alert", aircraft = "Bandit", origin = "A", stamp = 100, frontier = {} }
  local cancel = { kind = "cancel", aircraft = "Bandit", origin = "A", stamp = 200, frontier = {} }
  luaunit.assertTrue(veafSkynet.deliverSpotterMessage(RED, "B", cancel))
  luaunit.assertFalse(veafSkynet.deliverSpotterMessage(RED, "B", alert))
  luaunit.assertFalse(_holds("B", "Bandit"))
end

function TestSpotterPropagation:test_a_stale_message_is_refused()
  local older = { kind = "alert", aircraft = "Bandit", origin = "A", stamp = 100, frontier = {} }
  local newer = { kind = "alert", aircraft = "Bandit", origin = "A", stamp = 200, frontier = {} }
  luaunit.assertTrue(veafSkynet.deliverSpotterMessage(RED, "B", newer))
  luaunit.assertFalse(veafSkynet.deliverSpotterMessage(RED, "B", older))
  luaunit.assertEquals(veafSkynet.getSpotterContacts(RED, "B")["Bandit"].stamp, 200)
end

function TestSpotterPropagation:test_an_older_wave_dies_where_a_fresher_one_has_been()
  -- What refusing a stale message buys, put the only way it can actually happen: two spotters at the
  -- ends of a chain, the second seeing the aircraft a little later. Where the two fronts meet, the
  -- older one has nothing left to tell anyone and stops; the fresher one carries on.
  _chain("A", "B", "C")
  timer.setTime(0)
  veafSkynet.emitSpotterMessage(RED, "alert", "A", "Bandit")
  timer.setTime(50)
  veafSkynet.emitSpotterMessage(RED, "alert", "C", "Bandit")
  luaunit.assertEquals(#veafSkynet.spotterWaves[RED], 2)

  veafSkynet.spotterPropagationTick()
  veafSkynet.spotterPropagationTick()
  luaunit.assertEquals(#veafSkynet.spotterWaves[RED], 1)
  -- A is now served by the nearer-in-time witness, which is the merge the relaying rule produces.
  luaunit.assertEquals(veafSkynet.getSpotterContacts(RED, "A")["Bandit"].origin, "C")
end

function TestSpotterPropagation:test_a_contact_nobody_refreshes_is_forgotten()
  _chain("A", "B")
  veafSkynet.emitSpotterMessage(RED, "alert", "A", "Bandit")
  veafSkynet.spotterPropagationTick()
  luaunit.assertTrue(_holds("B", "Bandit"))
  timer.setTime(timer.getTime() + veafSkynet.SpotterForgetDelay - 1)
  veafSkynet.spotterPropagationTick()
  luaunit.assertTrue(_holds("B", "Bandit"))
  timer.setTime(timer.getTime() + 2)
  veafSkynet.spotterPropagationTick()
  luaunit.assertFalse(_holds("B", "Bandit"))
end

function TestSpotterPropagation:test_a_lost_cancellation_is_caught_by_the_heartbeat_net()
  -- The relay that would have carried the cancellation is gone, so the cancellation never arrives.
  -- Nothing refreshes the far unit either, and it forgets on its own. That is the net under every
  -- failure the design does not try to tell apart.
  _chain("A", "B", "C")
  veafSkynet.emitSpotterMessage(RED, "alert", "A", "Bandit")
  veafSkynet.spotterPropagationTick()
  veafSkynet.spotterPropagationTick()
  luaunit.assertTrue(_holds("C", "Bandit"))

  veafSkynet.removeSpotterNode(veafSkynet.getSpotterGraph(RED), "B")
  timer.setTime(timer.getTime() + 1)
  veafSkynet.emitSpotterMessage(RED, "cancel", "A", "Bandit")
  veafSkynet.spotterPropagationTick()
  veafSkynet.spotterPropagationTick()
  luaunit.assertTrue(_holds("C", "Bandit")) -- the cancellation could not reach it

  timer.setTime(timer.getTime() + veafSkynet.SpotterForgetDelay + 1)
  veafSkynet.spotterPropagationTick()
  luaunit.assertFalse(_holds("C", "Bandit"))
end

function TestSpotterPropagation:test_the_heartbeat_keeps_a_held_contact_alive()
  _chain("A", "B")
  veafSkynet.spotterLatches["A"] = { ["Bandit"] = { triggered = true, missedBeats = 0 } }
  veafSkynet.emitSpotterMessage(RED, "alert", "A", "Bandit")
  veafSkynet.spotterPropagationTick()

  -- Just short of the forget delay, the spotter says it again.
  timer.setTime(timer.getTime() + veafSkynet.SpotterForgetDelay - 10)
  veafSkynet.spotterHeartbeat()
  veafSkynet.spotterPropagationTick()
  timer.setTime(timer.getTime() + 20)
  veafSkynet.spotterPropagationTick()
  luaunit.assertTrue(_holds("B", "Bandit"))
end

function TestSpotterPropagation:test_the_heartbeat_says_nothing_for_a_contact_no_longer_held()
  _chain("A", "B")
  veafSkynet.spotterLatches["A"] = { ["Bandit"] = { triggered = false, missedBeats = 2 } }
  veafSkynet.spotterHeartbeat()
  luaunit.assertEquals(#(veafSkynet.spotterWaves[RED] or {}), 0)
end

function TestSpotterPropagation:test_the_heartbeat_says_nothing_for_a_spotter_off_the_graph()
  _chain("A", "B")
  veafSkynet.spotterLatches["Ghost"] = { ["Bandit"] = { triggered = true, missedBeats = 0 } }
  veafSkynet.spotterHeartbeat()
  luaunit.assertEquals(#(veafSkynet.spotterWaves[RED] or {}), 0)
end

function TestSpotterPropagation:test_nothing_propagates_when_the_feature_is_off()
  _chain("A", "B")
  veafSkynet.emitSpotterMessage(RED, "alert", "A", "Bandit")
  veafSkynet.SpotterNetwork = false
  veafSkynet.spotterPropagationTick()
  luaunit.assertFalse(_holds("B", "Bandit"))
end

-- ---------------------------------------------------------------------------
-- Handing over to Skynet
-- ---------------------------------------------------------------------------
TestSpotterHandover = {}

function TestSpotterHandover:setUp()
  _resetSpotterState()
  veafSkynet.SpotterNetwork = true
  veafSkynet.spotterHandoverArmed = false
  veafSkynet.spotterHandoverDoorWarned = false

  self.reported = {}
  self.rangeAsked = {}
  self.inEnvelope = true

  self.bandit = _unit("Bandit", { ["Air"] = true }, 0, 5000, 0)
  self.previousGetByName = Unit.getByName
  Unit.getByName = function(name)
    if name == "Bandit" then
      return self.bandit
    end
    return nil
  end

  -- A SAM site: a Skynet element wrapping a DCS group of two launchers.
  local siteUnits = { _unit("Sam1", { ["SAM elements"] = true }), _unit("Sam2", { ["SAM elements"] = true }) }
  local siteGroup = _group("SamSite", siteUnits)
  setmetatable(siteGroup, Group)
  self.samSite = {
    dcsName = "SamSite",
    dcsRepresentation = siteGroup,
    isTargetInRange = function(_, target)
      table.insert(self.rangeAsked, veafSkynet.safeDcsName(target))
      return self.inEnvelope
    end,
  }

  self.iads = {
    getSAMSites = function()
      return { self.samSite }
    end,
    reportContact = function(_, dcsUnit, samSite)
      table.insert(self.reported, veafSkynet.safeDcsName(dcsUnit) .. "@" .. samSite.dcsName)
    end,
  }
  veafSkynet.structure = {
    ["red iads"] = { coalitionID = coalition.side.RED, iads = self.iads },
  }
end

function TestSpotterHandover:tearDown()
  Unit.getByName = self.previousGetByName
  veafSkynet.spotterHandoverArmed = false
end

--- Put the aircraft in the hands of one of the site's units.
function TestSpotterHandover:_siteHolds()
  veafSkynet.deliverSpotterMessage(
    coalition.side.RED,
    "Sam1",
    { kind = "alert", aircraft = "Bandit", origin = "Scout", stamp = timer.getTime() }
  )
end

function TestSpotterHandover:test_a_site_holding_nothing_is_never_asked_for_its_envelope()
  -- `isTargetInRange` is annotated as expensive in Skynet's own source. A site with no alert must
  -- not reach it at all.
  veafSkynet.spotterHandoverPass()
  luaunit.assertEquals(#self.rangeAsked, 0)
  luaunit.assertEquals(#self.reported, 0)
end

function TestSpotterHandover:test_nothing_is_reported_while_the_aircraft_is_outside_the_envelope()
  self:_siteHolds()
  self.inEnvelope = false
  veafSkynet.spotterHandoverPass()
  luaunit.assertEquals(self.rangeAsked, { "Bandit" })
  luaunit.assertEquals(#self.reported, 0)
end

function TestSpotterHandover:test_exactly_one_report_when_it_enters_the_envelope()
  self:_siteHolds()
  veafSkynet.spotterHandoverPass()
  luaunit.assertEquals(self.reported, { "Bandit@SamSite" })
end

function TestSpotterHandover:test_an_aircraft_two_of_the_sites_units_hold_is_reported_once()
  self:_siteHolds()
  veafSkynet.deliverSpotterMessage(
    coalition.side.RED,
    "Sam2",
    { kind = "alert", aircraft = "Bandit", origin = "Scout", stamp = timer.getTime() }
  )
  veafSkynet.spotterHandoverPass()
  luaunit.assertEquals(#self.reported, 1)
end

function TestSpotterHandover:test_a_cancelled_contact_is_not_handed_over()
  self:_siteHolds()
  veafSkynet.deliverSpotterMessage(
    coalition.side.RED,
    "Sam1",
    { kind = "cancel", aircraft = "Bandit", origin = "Scout", stamp = timer.getTime() + 1 }
  )
  veafSkynet.spotterHandoverPass()
  luaunit.assertEquals(#self.reported, 0)
end

function TestSpotterHandover:test_an_aircraft_that_left_the_mission_is_not_handed_over()
  self:_siteHolds()
  Unit.getByName = function()
    return nil
  end
  veafSkynet.spotterHandoverPass()
  luaunit.assertEquals(#self.reported, 0)
end

function TestSpotterHandover:test_a_deactivated_network_hands_nothing_over()
  self:_siteHolds()
  veafSkynet.structure["red iads"].deactivated = true
  veafSkynet.spotterHandoverPass()
  luaunit.assertEquals(#self.reported, 0)
end

function TestSpotterHandover:test_nothing_is_handed_over_when_the_feature_is_off()
  self:_siteHolds()
  veafSkynet.SpotterNetwork = false
  veafSkynet.spotterHandoverPass()
  luaunit.assertEquals(#self.reported, 0)
end

function TestSpotterHandover:test_skynet_own_guards_are_not_second_guessed()
  -- Skynet refusing the contact -- out of ammunition, under HARM silence, no power -- is Skynet's
  -- business. We report and let it decide; we do not re-implement any of it, and a refusal must not
  -- make us stop reporting either.
  self.iads.reportContact = function()
    error("skynet says no")
  end
  self:_siteHolds()
  veafSkynet.spotterHandoverPass()
  veafSkynet.spotterHandoverPass()
  luaunit.assertEquals(#self.rangeAsked, 2)
end

function TestSpotterHandover:test_a_skynet_without_the_door_warns_once_and_not_every_beat()
  -- The vendored artifact predates `reportContact`. Switching the feature on against it must say so
  -- plainly, and say it once: every five seconds for four hours is a log nobody reads.
  self.iads.reportContact = nil
  self:_siteHolds()
  local before = #dcs_mocks.logs
  for _ = 1, 5 do
    veafSkynet.spotterHandoverPass()
  end
  local warnings = 0
  for i = before + 1, #dcs_mocks.logs do
    if tostring(dcs_mocks.logs[i].text):find("reportContact") then
      warnings = warnings + 1
    end
  end
  luaunit.assertEquals(warnings, 1)
end

-- ---------------------------------------------------------------------------
-- The status page
-- ---------------------------------------------------------------------------
TestSpotterStatusPage = {}

function TestSpotterStatusPage:setUp()
  _resetSpotterState()
  veafSkynet.SpotterNetwork = true
  veafSkynet.spotterStatusArmed = false
  veafSkynet.spotterStatusAcquisitions = {}
  veafSkynet.spotterStatusWakeUps = {}
  veafSkynet.structure = { ["red iads"] = { coalitionID = RED, debugFlag = true } }
end

function TestSpotterStatusPage:tearDown()
  veafSkynet.spotterStatusArmed = false
end

--- Everything the page wrote, as one string.
local function _pageText()
  local parts = {}
  for _, entry in ipairs(dcs_mocks.logs) do
    table.insert(parts, tostring(entry.text))
  end
  return table.concat(parts, "\n")
end

function TestSpotterStatusPage:test_nothing_is_written_without_the_debug_flag()
  -- A page that prints regardless is a log flood in every mission that never asked for it.
  veafSkynet.structure["red iads"].debugFlag = false
  dcs_mocks.logs = {}
  veafSkynet.spotterStatusPage()
  luaunit.assertNotStrContains(_pageText(), "spotter network")
end

function TestSpotterStatusPage:test_nothing_is_written_when_the_feature_is_off()
  veafSkynet.SpotterNetwork = false
  dcs_mocks.logs = {}
  veafSkynet.spotterStatusPage()
  luaunit.assertNotStrContains(_pageText(), "spotter network")
end

function TestSpotterStatusPage:test_it_names_the_aircraft_the_spotter_and_the_site()
  -- Asserted against what a human reads, not against an internal table: that is the whole point of
  -- this ticket, since three different mechanisms can now wake a site.
  veafSkynet.deliverSpotterMessage(RED, "SamLauncher", { kind = "alert", aircraft = "Bandit", origin = "Scout", stamp = 1 })
  veafSkynet.recordSpotterAcquisition(RED, "Scout -> Bandit")
  veafSkynet.recordSpotterWakeUp(RED, "SamSite <- Bandit")
  dcs_mocks.logs = {}
  veafSkynet.spotterStatusPage()
  local text = _pageText()
  -- The header too, so the "nothing is written" tests above cannot pass vacuously on a page that
  -- never prints at all.
  luaunit.assertStrContains(text, "spotter network [red iads]")
  luaunit.assertStrContains(text, "Scout -> Bandit")
  luaunit.assertStrContains(text, "SamSite <- Bandit")
  luaunit.assertStrContains(text, "SamLauncher")
end

function TestSpotterStatusPage:test_an_alerts_age_grows_so_a_stale_contact_looks_stale()
  timer.setTime(100)
  veafSkynet.deliverSpotterMessage(RED, "SamLauncher", { kind = "alert", aircraft = "Bandit", origin = "Scout", stamp = 1 })
  timer.setTime(142)
  dcs_mocks.logs = {}
  veafSkynet.spotterStatusPage()
  luaunit.assertStrContains(_pageText(), "42 s old")
end

function TestSpotterStatusPage:test_a_cancelled_contact_is_not_listed_as_an_alert()
  veafSkynet.deliverSpotterMessage(RED, "SamLauncher", { kind = "alert", aircraft = "Bandit", origin = "Scout", stamp = 1 })
  veafSkynet.deliverSpotterMessage(RED, "SamLauncher", { kind = "cancel", aircraft = "Bandit", origin = "Scout", stamp = 2 })
  dcs_mocks.logs = {}
  veafSkynet.spotterStatusPage()
  luaunit.assertStrContains(_pageText(), "alert: none")
end

function TestSpotterStatusPage:test_what_happened_is_reported_once_and_not_forever()
  veafSkynet.recordSpotterAcquisition(RED, "Scout -> Bandit")
  dcs_mocks.logs = {}
  veafSkynet.spotterStatusPage()
  luaunit.assertStrContains(_pageText(), "Scout -> Bandit")
  dcs_mocks.logs = {}
  veafSkynet.spotterStatusPage()
  luaunit.assertNotStrContains(_pageText(), "Scout -> Bandit")
end

function TestSpotterStatusPage:test_one_network_does_not_report_the_others_sightings()
  -- Found in review. The two buckets used to be flat lists printed under every debug network's
  -- header, so a mission running both sides in debug read red's sightings as blue's. A page that can
  -- misattribute a wake-up is worse than no page, since the whole reason for it is that a site can
  -- now light up for three different reasons.
  veafSkynet.structure["blue iads"] = { coalitionID = coalition.side.BLUE, debugFlag = true }
  veafSkynet.recordSpotterAcquisition(RED, "RedTank -> BlueJet")
  veafSkynet.recordSpotterWakeUp(RED, "RedSam <- BlueJet")
  dcs_mocks.logs = {}
  veafSkynet.spotterStatusPage()

  local underBlue, seenBlueHeader = 0, false
  for _, entry in ipairs(dcs_mocks.logs) do
    local text = tostring(entry.text)
    if text:find("blue iads", 1, true) then
      seenBlueHeader = true
    elseif text:find("red iads", 1, true) then
      seenBlueHeader = false
    elseif seenBlueHeader and (text:find("RedTank", 1, true) or text:find("RedSam", 1, true)) then
      underBlue = underBlue + 1
    end
  end
  luaunit.assertEquals(underBlue, 0)
  -- ...and red still gets its own lines, so this cannot pass by printing nothing at all.
  luaunit.assertStrContains(_pageText(), "RedTank -> BlueJet")
end

function TestSpotterStatusPage:test_a_site_woken_over_and_over_is_reported_once()
  -- Found in review. The hand-over reports the same contact on every 5 s pass while the aircraft
  -- stays inside the envelope -- which is right, Skynet ages contacts out -- so a list would print the
  -- same line twelve times per page and bury the graph and alert lines it exists to show.
  for _ = 1, 12 do
    veafSkynet.recordSpotterWakeUp(RED, "SamSite <- Bandit")
  end
  dcs_mocks.logs = {}
  veafSkynet.spotterStatusPage()
  local occurrences = 0
  for _, entry in ipairs(dcs_mocks.logs) do
    if tostring(entry.text):find("SamSite <- Bandit", 1, true) then
      occurrences = occurrences + 1
    end
  end
  luaunit.assertEquals(occurrences, 1)
end

function TestSpotterStatusPage:test_the_graph_line_counts_pockets()
  -- The figure that answers "why did my alert not travel". Two islands of two.
  local graph = veafSkynet.getSpotterGraph(RED)
  for _, pair in ipairs({ { "A", "B" }, { "Y", "Z" } }) do
    for _, name in ipairs(pair) do
      graph.nodes[name] = { x = 0, z = 0, class = veafSkynet.SpotterSpeedClasses.Mobile }
      graph.adjacency[name] = graph.adjacency[name] or {}
    end
    graph.adjacency[pair[1]][pair[2]] = true
    graph.adjacency[pair[2]][pair[1]] = true
  end
  dcs_mocks.logs = {}
  veafSkynet.spotterStatusPage()
  luaunit.assertStrContains(_pageText(), "4 units, 2 links, 2 pockets, largest 2")
end

function TestSpotterStatusPage:test_an_empty_graph_is_described_without_falling_over()
  dcs_mocks.logs = {}
  veafSkynet.spotterStatusPage()
  luaunit.assertStrContains(_pageText(), "0 units, 0 links, 0 pockets, largest 0")
end

-- ---------------------------------------------------------------------------
-- The map view
-- ---------------------------------------------------------------------------
TestSpotterMapView = {}

function TestSpotterMapView:setUp()
  _resetSpotterState()
  veafSkynet.SpotterNetwork = true
  veafSkynet.spotterViewCoalitions = {}
  veafSkynet.spotterViewMarkers = {}
  veafSkynet.spotterRedrawScheduled = nil
  veafSkynet.structure = { ["red iads"] = { coalitionID = RED } }

  self.scheduled = {}
  self.previousSchedule = veaf.scheduleFunction
  veaf.scheduleFunction = function(fn, vars, t, rep)
    table.insert(self.scheduled, { fn = fn, vars = vars, time = t, rep = rep })
    return #self.scheduled
  end

  self.marked = {}
  self.removed = {}
  self.previousMark = trigger.action.markToCoalition
  self.previousCircle = trigger.action.circleToAll
  self.previousRemove = trigger.action.removeMark
  trigger.action.markToCoalition = function(id, text, _, coa)
    table.insert(self.marked, { id = id, text = text, coalition = coa })
  end
  trigger.action.circleToAll = function(_, id)
    table.insert(self.marked, { id = id, circle = true })
  end
  trigger.action.removeMark = function(id)
    table.insert(self.removed, id)
  end

  self.spotter = _unit("Scout", { ["Tanks"] = true }, 1000, 0, 2000)
  self.previousGetByName = Unit.getByName
  Unit.getByName = function(name)
    if name == "Scout" then
      return self.spotter
    end
    return nil
  end
end

function TestSpotterMapView:tearDown()
  veaf.scheduleFunction = self.previousSchedule
  trigger.action.markToCoalition = self.previousMark
  trigger.action.circleToAll = self.previousCircle
  trigger.action.removeMark = self.previousRemove
  Unit.getByName = self.previousGetByName
  veafSkynet.spotterViewCoalitions = {}
  veafSkynet.spotterRedrawScheduled = nil
end

function TestSpotterMapView:_scoutSees()
  veafSkynet.getSpotterProfile(self.spotter, "Scout")
  veafSkynet.deliverSpotterMessage(RED, "Scout", { kind = "alert", aircraft = "Bandit", origin = "Scout", stamp = 1 })
end

function TestSpotterMapView:_redrawRequests()
  local count = 0
  for _, task in ipairs(self.scheduled) do
    if task.fn == veafSkynet._redrawSpotterView then
      count = count + 1
    end
  end
  return count
end

function TestSpotterMapView:test_a_hundred_requests_in_a_row_schedule_one_redraw()
  for _ = 1, 100 do
    veafSkynet.requestSpotterViewRedraw()
  end
  luaunit.assertEquals(self:_redrawRequests(), 1)
end

function TestSpotterMapView:test_the_flag_is_cleared_so_a_later_request_still_works()
  -- The assertion that catches `veafRadio._refreshRadioMenu`'s shape, which clears its flag inside a
  -- conditional. A test counting only the first burst passes on the broken version.
  veafSkynet.requestSpotterViewRedraw()
  veafSkynet._redrawSpotterView()
  veafSkynet.requestSpotterViewRedraw()
  luaunit.assertEquals(self:_redrawRequests(), 2)
end

function TestSpotterMapView:test_the_flag_is_cleared_even_when_there_is_nothing_to_draw()
  -- No coalition switched on: the redraw returns having done nothing, and must still re-arm. A
  -- coalescing guard that never re-arms is worse than none, because the first redraw looks like proof
  -- that it works.
  veafSkynet.spotterViewCoalitions = {}
  veafSkynet.requestSpotterViewRedraw()
  veafSkynet._redrawSpotterView()
  luaunit.assertNil(veafSkynet.spotterRedrawScheduled)
  veafSkynet.requestSpotterViewRedraw()
  luaunit.assertEquals(self:_redrawRequests(), 2)
end

function TestSpotterMapView:test_the_flag_is_cleared_even_when_the_feature_is_off()
  veafSkynet.showSpotterView(RED, true)
  veafSkynet.SpotterNetwork = false
  veafSkynet._redrawSpotterView()
  luaunit.assertNil(veafSkynet.spotterRedrawScheduled)
end

function TestSpotterMapView:test_nothing_is_drawn_until_the_view_is_switched_on()
  self:_scoutSees()
  veafSkynet._redrawSpotterView()
  luaunit.assertEquals(#self.marked, 0)
end

function TestSpotterMapView:test_it_marks_the_spotter_that_raised_the_alert()
  self:_scoutSees()
  veafSkynet.showSpotterView(RED, true)
  veafSkynet._redrawSpotterView()
  luaunit.assertTrue(#self.marked >= 1)
  luaunit.assertStrContains(self.marked[1].text, "Scout sees Bandit")
  luaunit.assertEquals(self.marked[1].coalition, RED)
end

function TestSpotterMapView:test_it_marks_only_where_the_alert_was_raised()
  -- Every unit of the pocket holds the contact; a marker on each is a wall of markers all saying the
  -- same thing.
  self:_scoutSees()
  veafSkynet.deliverSpotterMessage(RED, "Relay", { kind = "alert", aircraft = "Bandit", origin = "Scout", stamp = 1 })
  veafSkynet.showSpotterView(RED, true)
  veafSkynet._redrawSpotterView()
  local markers = 0
  for _, entry in ipairs(self.marked) do
    if entry.text then
      markers = markers + 1
    end
  end
  luaunit.assertEquals(markers, 1)
end

function TestSpotterMapView:test_a_cancelled_contact_is_not_drawn()
  self:_scoutSees()
  veafSkynet.deliverSpotterMessage(RED, "Scout", { kind = "cancel", aircraft = "Bandit", origin = "Scout", stamp = 2 })
  veafSkynet.showSpotterView(RED, true)
  veafSkynet._redrawSpotterView()
  luaunit.assertEquals(#self.marked, 0)
end

function TestSpotterMapView:test_drawing_twice_replaces_rather_than_stacks()
  self:_scoutSees()
  veafSkynet.showSpotterView(RED, true)
  veafSkynet._redrawSpotterView()
  local first = #self.marked
  veafSkynet._redrawSpotterView()
  luaunit.assertEquals(#self.marked, first * 2) -- drawn again...
  luaunit.assertEquals(#self.removed, first) -- ...and the first set was taken off the map
end

function TestSpotterMapView:test_switching_the_view_off_removes_what_it_drew()
  self:_scoutSees()
  veafSkynet.showSpotterView(RED, true)
  veafSkynet._redrawSpotterView()
  local drawn = #self.marked
  veafSkynet.showSpotterView(RED, false)
  luaunit.assertEquals(#self.removed, drawn)
  luaunit.assertNil(veafSkynet.spotterViewMarkers[RED])
end

function TestSpotterMapView:test_an_acquisition_asks_for_a_redraw()
  -- Wiring: the view is useless if nothing ever asks it to refresh.
  veafSkynet.onSpotterAcquired(RED, "Scout", "Bandit", self.spotter)
  luaunit.assertEquals(self:_redrawRequests(), 1)
end

function TestSpotterMapView:test_a_loss_asks_for_a_redraw()
  veafSkynet.onSpotterLost(RED, "Scout", "Bandit")
  luaunit.assertEquals(self:_redrawRequests(), 1)
end

-- ---------------------------------------------------------------------------
-- How the map view is offered: off, on, or a radio switch
-- ---------------------------------------------------------------------------
TestSpotterViewModes = {}

function TestSpotterViewModes:setUp()
  _resetSpotterState()
  veafSkynet.SpotterNetwork = true
  veafSkynet.spotterViewCoalitions = {}
  veafSkynet.spotterViewMarkers = {}
  veafSkynet.spotterViewRootPaths = {}
  veafSkynet.spotterViewArmed = false
  veafSkynet.SpotterView = veafSkynet.SpotterViewModes.Off
  veafSkynet.structure = { ["red iads"] = { coalitionID = RED } }

  -- A radio module that records what it is asked to build, rather than one that answers nothing: a
  -- menu asserted against a silent stub is a menu nobody has checked exists.
  self.menus = {}
  self.commands = {}
  self.refreshes = 0
  self.previousRadio = veafRadio
  veafRadio = {
    addSubMenu = function(title, parent, coalitionSide)
      local menu = { title = title, parent = parent, coalition = coalitionSide, commands = {} }
      table.insert(self.menus, menu)
      return menu
    end,
    addCommandToSubmenu = function(title, menu, method, parameters, usage)
      local command = { title = title, menu = menu, method = method, parameters = parameters, usage = usage }
      table.insert(self.commands, command)
      table.insert(menu.commands, command)
      return command
    end,
    clearSubmenu = function(menu)
      menu.commands = {}
    end,
    refreshRadioMenu = function()
      self.refreshes = self.refreshes + 1
    end,
  }
end

function TestSpotterViewModes:tearDown()
  veafRadio = self.previousRadio
  veafSkynet.SpotterView = veafSkynet.SpotterViewModes.Off
  veafSkynet.spotterViewArmed = false
  veafSkynet.spotterViewRootPaths = {}
  veafSkynet.spotterViewCoalitions = {}
end

function TestSpotterViewModes:test_off_draws_nothing_and_offers_nothing()
  veafSkynet.SpotterView = veafSkynet.SpotterViewModes.Off
  veafSkynet._armSpotterView()
  luaunit.assertNil(veafSkynet.spotterViewCoalitions[RED])
  luaunit.assertEquals(#self.commands, 0)
end

function TestSpotterViewModes:test_on_switches_the_view_on_from_the_start()
  veafSkynet.SpotterView = veafSkynet.SpotterViewModes.On
  veafSkynet._armSpotterView()
  luaunit.assertTrue(veafSkynet.spotterViewCoalitions[RED])
  luaunit.assertEquals(#self.commands, 0) -- no menu: it is simply on
end

function TestSpotterViewModes:test_radio_offers_the_switch_and_leaves_the_view_off()
  -- The point of a toggle, and the cautious reading: the view shows a whole coalition where its
  -- spotters are looking, so it starts off and somebody asks for it.
  veafSkynet.SpotterView = veafSkynet.SpotterViewModes.Radio
  veafSkynet._armSpotterView()
  luaunit.assertNil(veafSkynet.spotterViewCoalitions[RED])
  luaunit.assertEquals(#self.commands, 1)
  luaunit.assertEquals(self.commands[1].title, veaf.t("menu.skynet.spotterview.show"))
  -- ...and that is a sentence, not the key itself: a catalogue entry missing in either language puts
  -- `menu.skynet.spotterview.show` in front of the player.
  luaunit.assertNotEquals(self.commands[1].title, "menu.skynet.spotterview.show")
  luaunit.assertNotEquals(self.menus[1].title, "menu.skynet.root")
end

function TestSpotterViewModes:test_the_menu_is_scoped_to_its_own_coalition()
  -- The other side has its own network and no business seeing a switch for this one.
  veafSkynet.SpotterView = veafSkynet.SpotterViewModes.Radio
  veafSkynet._armSpotterView()
  luaunit.assertEquals(#self.menus, 1)
  luaunit.assertEquals(self.menus[1].coalition, RED)
end

function TestSpotterViewModes:test_the_command_reaches_a_game_master()
  -- A game master has no group, so a USAGE_ForGroup command never reaches one (#128) -- and a game
  -- master is exactly who this menu is for. Leaving the usage unset means USAGE_ForAll.
  veafSkynet.SpotterView = veafSkynet.SpotterViewModes.Radio
  veafSkynet._armSpotterView()
  luaunit.assertNil(self.commands[1].usage)
end

function TestSpotterViewModes:test_the_switch_flips_the_view_and_the_label()
  veafSkynet.SpotterView = veafSkynet.SpotterViewModes.Radio
  veafSkynet._armSpotterView()
  local toggle = self.commands[1]
  toggle.method(toggle.parameters)
  luaunit.assertTrue(veafSkynet.spotterViewCoalitions[RED])
  luaunit.assertEquals(self.commands[#self.commands].title, veaf.t("menu.skynet.spotterview.hide"))

  local hide = self.commands[#self.commands]
  hide.method(hide.parameters)
  luaunit.assertNil(veafSkynet.spotterViewCoalitions[RED])
  luaunit.assertEquals(self.commands[#self.commands].title, veaf.t("menu.skynet.spotterview.show"))
end

function TestSpotterViewModes:test_the_switch_carries_its_own_coalition()
  veafSkynet.SpotterView = veafSkynet.SpotterViewModes.Radio
  veafSkynet.structure["blue iads"] = { coalitionID = coalition.side.BLUE }
  veafSkynet._armSpotterView()
  local byCoalition = {}
  for _, command in ipairs(self.commands) do
    byCoalition[command.parameters] = true
  end
  luaunit.assertTrue(byCoalition[RED])
  luaunit.assertTrue(byCoalition[coalition.side.BLUE])
end

function TestSpotterViewModes:test_the_menu_is_replaced_rather_than_stacked()
  -- A DCS radio command's title is fixed once created, so the entry has to be rebuilt to read
  -- "Hide". Rebuilding must not leave the old one beside it.
  veafSkynet.SpotterView = veafSkynet.SpotterViewModes.Radio
  veafSkynet._armSpotterView()
  local menu = self.menus[1]
  local toggle = self.commands[1]
  toggle.method(toggle.parameters)
  luaunit.assertEquals(#menu.commands, 1)
  luaunit.assertEquals(#self.menus, 1) -- and no second submenu was created either
end

function TestSpotterViewModes:test_arming_twice_does_not_stack_a_second_menu()
  veafSkynet.SpotterView = veafSkynet.SpotterViewModes.Radio
  veafSkynet._armSpotterView()
  veafSkynet._armSpotterView()
  luaunit.assertEquals(#self.menus, 1)
end

function TestSpotterViewModes:test_nothing_is_offered_when_the_network_is_off()
  veafSkynet.SpotterView = veafSkynet.SpotterViewModes.Radio
  veafSkynet.SpotterNetwork = false
  veafSkynet._armSpotterView()
  luaunit.assertEquals(#self.commands, 0)
end

function TestSpotterViewModes:test_a_missing_radio_module_does_not_take_the_start_up_down()
  -- The helper loads without veafRadio today, and switching a map view on must not be the thing that
  -- changes that.
  veafRadio = nil
  veafSkynet.SpotterView = veafSkynet.SpotterViewModes.Radio
  local ok = pcall(veafSkynet._armSpotterView)
  luaunit.assertTrue(ok)
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
    table.insert(self.scheduled, { fn = fn, vars = vars, time = t, rep = rep })
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

function TestSpotterWiring:test_the_three_graph_passes_are_scheduled()
  veafSkynet.SpotterNetwork = true
  veafSkynet._armSpotterGraph()
  local periods = {}
  for _, task in ipairs(self.scheduled) do
    if task.fn == veafSkynet.spotterGraphPass then
      periods[task.rep] = true
    end
  end
  luaunit.assertTrue(periods[10])
  luaunit.assertTrue(periods[20])
  luaunit.assertTrue(periods[30])
end

function TestSpotterWiring:test_the_graph_passes_are_not_scheduled_when_the_feature_is_off()
  veafSkynet.SpotterNetwork = false
  veafSkynet._armSpotterGraph()
  for _, task in ipairs(self.scheduled) do
    luaunit.assertNotEquals(task.fn, veafSkynet.spotterGraphPass)
  end
end

function TestSpotterWiring:test_arming_the_graph_twice_does_not_stack_a_second_set()
  veafSkynet.SpotterNetwork = true
  veafSkynet._armSpotterGraph()
  veafSkynet._armSpotterGraph()
  local count = 0
  for _, task in ipairs(self.scheduled) do
    if task.fn == veafSkynet.spotterGraphPass then
      count = count + 1
    end
  end
  luaunit.assertEquals(count, 3)
end

function TestSpotterWiring:test_each_graph_pass_carries_its_own_class()
  veafSkynet.SpotterNetwork = true
  veafSkynet._armSpotterGraph()
  -- The class is the pass's only argument, and a pass armed without one would silently fall back on
  -- the slow period and re-edge nothing of the other two classes.
  local classes = {}
  for _, task in ipairs(self.scheduled) do
    if task.fn == veafSkynet.spotterGraphPass then
      classes[task.vars and task.vars[1]] = true
    end
  end
  luaunit.assertTrue(classes[veafSkynet.SpotterSpeedClasses.Fast])
  luaunit.assertTrue(classes[veafSkynet.SpotterSpeedClasses.Mobile])
  luaunit.assertTrue(classes[veafSkynet.SpotterSpeedClasses.Slow])
end

function TestSpotterWiring:test_propagation_and_the_heartbeat_are_scheduled()
  veafSkynet.SpotterNetwork = true
  veafSkynet._armSpotterPropagation()
  local byFunction = {}
  for _, task in ipairs(self.scheduled) do
    byFunction[task.fn] = task
  end
  luaunit.assertNotNil(byFunction[veafSkynet.spotterPropagationTick])
  luaunit.assertNotNil(byFunction[veafSkynet.spotterHeartbeat])
  luaunit.assertEquals(byFunction[veafSkynet.spotterHeartbeat].rep, veafSkynet.SpotterHeartbeatPeriod)
end

function TestSpotterWiring:test_propagation_is_armed_at_the_derived_hop_period()
  -- Not at a stored period: the whole reason a speed is exposed rather than a period is that
  -- widening the range must slow the hops instead of doubling how fast an alert crosses the map.
  veafSkynet.SpotterNetwork = true
  veafSkynet.SpotterRadioRange = 40000
  veafSkynet._armSpotterPropagation()
  for _, task in ipairs(self.scheduled) do
    if task.fn == veafSkynet.spotterPropagationTick then
      luaunit.assertEquals(task.rep, 40)
      return
    end
  end
  luaunit.fail("propagation was never scheduled")
end

function TestSpotterWiring:test_propagation_is_not_scheduled_when_the_feature_is_off()
  veafSkynet.SpotterNetwork = false
  veafSkynet._armSpotterPropagation()
  for _, task in ipairs(self.scheduled) do
    luaunit.assertNotEquals(task.fn, veafSkynet.spotterPropagationTick)
  end
end

function TestSpotterWiring:test_arming_propagation_twice_does_not_stack_a_second_set()
  veafSkynet.SpotterNetwork = true
  veafSkynet._armSpotterPropagation()
  veafSkynet._armSpotterPropagation()
  local count = 0
  for _, task in ipairs(self.scheduled) do
    if task.fn == veafSkynet.spotterPropagationTick then
      count = count + 1
    end
  end
  luaunit.assertEquals(count, 1)
end

function TestSpotterWiring:test_the_handover_pass_is_scheduled()
  veafSkynet.SpotterNetwork = true
  veafSkynet.spotterHandoverArmed = false
  veafSkynet._armSpotterHandover()
  local count = 0
  for _, task in ipairs(self.scheduled) do
    if task.fn == veafSkynet.spotterHandoverPass then
      count = count + 1
      luaunit.assertEquals(task.rep, veafSkynet.SpotterDetectionPeriod)
    end
  end
  luaunit.assertEquals(count, 1)
  veafSkynet.spotterHandoverArmed = false
end

function TestSpotterWiring:test_the_handover_pass_is_not_scheduled_when_the_feature_is_off()
  veafSkynet.SpotterNetwork = false
  veafSkynet.spotterHandoverArmed = false
  veafSkynet._armSpotterHandover()
  for _, task in ipairs(self.scheduled) do
    luaunit.assertNotEquals(task.fn, veafSkynet.spotterHandoverPass)
  end
end

function TestSpotterWiring:test_the_status_page_is_scheduled()
  veafSkynet.SpotterNetwork = true
  veafSkynet.spotterStatusArmed = false
  veafSkynet._armSpotterStatus()
  local count = 0
  for _, task in ipairs(self.scheduled) do
    if task.fn == veafSkynet.spotterStatusPage then
      count = count + 1
      luaunit.assertEquals(task.rep, veafSkynet.SpotterStatusPeriod)
    end
  end
  luaunit.assertEquals(count, 1)
  veafSkynet.spotterStatusArmed = false
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
