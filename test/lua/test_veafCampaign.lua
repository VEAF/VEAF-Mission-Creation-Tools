--- Tests for veafCampaign.lua — a campaign flown mission after mission (FEAT-MULTI-MISSION-CAMPAIGN).
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
dofile(src .. "/veafCampaign.lua")

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- A placed unit as veafCasMission's generators hand it back.
local function placed(typeName, x, z)
  return { typeName = typeName, spawnPoint = { x = x, y = 0, z = z }, hdg = 0.5 }
end

--- A zone entry of the data table, owned by `owner`, with nothing drawn yet.
local function zoneEntry(name, owner, extra)
  local entry = {
    name = name,
    x = 1000,
    z = 2000,
    owner = owner,
    size = { size = 2, defense = 1, armor = 1, long_range_sam = false },
  }
  for key, value in pairs(extra or {}) do
    entry[key] = value
  end
  return entry
end

--- A recorded garrison: one group of three units.
local function recordedGarrison(name)
  return {
    {
      name = name .. " garrison",
      units = {
        { type = "T-72B", x = 10, z = 20, heading = 1, alive = true },
        { type = "BMP-2", x = 11, z = 21, heading = 2, alive = true },
        { type = "Ural-375", x = 12, z = 22, heading = 3, alive = true },
      },
    },
  }
end

--- The units submitted to DCS, by group name.
local function submitted()
  local byGroup = {}
  for _, call in ipairs(dcs_mocks.groupsAdded) do
    byGroup[call.group.name] = call.group.units
  end
  return byGroup
end

local function deadEvent(unitName)
  return { initiator = { unitName = unitName } }
end

--- Common set-up: a clean mock world, and the CAS generators replaced by spies.
local function setUpSuite(self)
  dcs_mocks.reset()
  local this = self
  self.saved = {
    composeGarrison = veafCampaign.composeGarrison,
    generateLongRange = veafCasMission.generateLongRangeAirDefenseGroup,
    placeGroup = veafCasMission.placeGroup,
    findGroup = veafUnits.findGroup,
    callbacks = veafEventHandler.callbacks,
    fileSystem = veafCampaign.fileSystem,
    textToAll = trigger.action.textToAll,
    lineToAll = trigger.action.lineToAll,
    language = veaf.config.language,
  }
  veafEventHandler.callbacks = {}
  self.texts, self.lines = {}, {}
  trigger.action.textToAll = function(side, id, point, color, fill, size, readOnly, text)
    table.insert(this.texts, { id = id, text = text })
  end
  trigger.action.lineToAll = function(side, id, from, to)
    table.insert(this.lines, { id = id, from = from, to = to })
  end
  self.casCalls = {}
  veafCampaign.composeGarrison = function(name, center, radius, size, side)
    table.insert(this.casCalls, { name = name, size = size.size, defense = size.defense, armor = size.armor, side = side })
    return { placed("T-72B", 1, 2), placed("BMP-2", 3, 4) }
  end
  veafCampaign.data = nil
end

local function tearDownSuite(self)
  veafCampaign.composeGarrison = self.saved.composeGarrison
  veafCasMission.generateLongRangeAirDefenseGroup = self.saved.generateLongRange
  veafCasMission.placeGroup = self.saved.placeGroup
  veafUnits.findGroup = self.saved.findGroup
  veafEventHandler.callbacks = self.saved.callbacks
  veafCampaign.fileSystem = self.saved.fileSystem
  trigger.action.textToAll = self.saved.textToAll
  trigger.action.lineToAll = self.saved.lineToAll
  veaf.config.language = self.saved.language
  veafCampaign.data = nil
  veafCampaign.stateUnwritableReported = nil
end

-- ---------------------------------------------------------------------------
-- TestVeafCampaignWithoutData
-- ---------------------------------------------------------------------------
TestVeafCampaignWithoutData = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestVeafCampaignWithoutData:test_a_mission_without_campaign_data_does_nothing()
  luaunit.assertFalse(veafCampaign.initialize())
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
  luaunit.assertEquals(#veafEventHandler.callbacks, 0)
end

-- ---------------------------------------------------------------------------
-- TestVeafCampaignDraw
-- ---------------------------------------------------------------------------
TestVeafCampaignDraw = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestVeafCampaignDraw:test_a_zone_with_no_recorded_garrison_draws_one_from_its_size_class()
  veafCampaign.data = { zones = { zoneEntry("Senaki", "red") } }
  veafCampaign.initialize()
  luaunit.assertEquals(#self.casCalls, 1)
  local call = self.casCalls[1]
  luaunit.assertEquals({ call.size, call.defense, call.armor, call.side }, { 2, 1, 1, coalition.side.RED })
end

function TestVeafCampaignDraw:test_the_drawn_garrison_is_recorded_in_the_data_table()
  veafCampaign.data = { zones = { zoneEntry("Senaki", "red") } }
  veafCampaign.initialize()
  local garrison = veafCampaign.data.zones[1].garrison
  luaunit.assertEquals(#garrison, 1)
  luaunit.assertEquals(garrison[1].name, "Senaki garrison")
  luaunit.assertEquals(garrison[1].units[1], { type = "T-72B", x = 1, z = 2, heading = 0.5, alive = true })
  luaunit.assertEquals(garrison[1].units[2].type, "BMP-2")
end

function TestVeafCampaignDraw:test_a_draw_that_places_nothing_is_left_for_the_next_mission()
  veafCampaign.composeGarrison = function()
    return {}
  end
  veafCampaign.data = { zones = { zoneEntry("Senaki", "red") } }
  veafCampaign.initialize()
  -- an empty record would hold the zone for ever: never redrawn, never neutral
  luaunit.assertNil(veafCampaign.data.zones[1].garrison)
  luaunit.assertEquals(veafCampaign.data.zones[1].owner, "red")
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

function TestVeafCampaignDraw:test_a_zone_with_a_recorded_garrison_does_not_draw_again()
  veafCampaign.data = { zones = { zoneEntry("Senaki", "red", { garrison = recordedGarrison("Senaki") }) } }
  veafCampaign.initialize()
  luaunit.assertEquals(#self.casCalls, 0)
end

function TestVeafCampaignDraw:test_a_zone_is_placed_on_its_airbase_or_at_its_coordinates()
  local savedAirbase, savedLLtoLO = Airbase.getByName, coord.LLtoLO
  Airbase.getByName = function(name)
    if name == "Senaki-Kolkhi" then
      return {
        getPoint = function()
          return { x = 100, y = 7, z = 200 }
        end,
      }
    end
    return nil
  end
  coord.LLtoLO = function(lat, lon)
    return { x = lat * 1000, y = 0, z = lon * 1000 }
  end
  local senaki = { name = "Senaki", airbase = "Senaki-Kolkhi", owner = "neutral" }
  local depot = { name = "Depot", lat = 43, lon = 40, owner = "neutral" }
  local lost = { name = "Lost", airbase = "Atlantis", owner = "red", size = { size = 1, defense = 0, armor = 0 } }
  veafCampaign.data = { zones = { senaki, depot, lost } }
  veafCampaign.initialize()
  Airbase.getByName, coord.LLtoLO = savedAirbase, savedLLtoLO
  luaunit.assertEquals({ senaki.x, senaki.z }, { 100, 200 })
  luaunit.assertEquals({ depot.x, depot.z }, { 43000, 40000 })
  -- a zone that cannot be placed is neither drawn nor garrisoned, and keeps its record in the state
  luaunit.assertFalse(veafCampaign.zones["Lost"].placed)
  luaunit.assertEquals(#self.casCalls, 0)
  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 2)
  luaunit.assertEquals(veafCampaign.stateTable().zones.Lost.owner, "red")
  veafCampaign.beat()
end

function TestVeafCampaignDraw:test_the_starting_garrisons_of_mission_one_cost_nothing()
  local reserve = { armor = 5, air_defense = 0, transport = 0 }
  veafCampaign.data = { mission = 1, sides = { red = { reserve = reserve } }, zones = { zoneEntry("Senaki", "red") } }
  veafCampaign.initialize()
  luaunit.assertEquals(reserve.armor, 5)
end

function TestVeafCampaignDraw:test_a_zone_taken_between_missions_draws_from_the_reserve_at_the_next_start()
  local reserve = { armor = 5, air_defense = 0, transport = 0 }
  veafCampaign.data = { mission = 3, sides = { red = { reserve = reserve } }, zones = { zoneEntry("Senaki", "red") } }
  veafCampaign.initialize()
  luaunit.assertEquals(reserve.armor, 3)
end

function TestVeafCampaignDraw:test_a_unit_type_falls_in_one_reserve_category()
  luaunit.assertEquals(veafCampaign.reserveCategory("T-72B"), "armor")
  luaunit.assertEquals(veafCampaign.reserveCategory("Osa 9A33 ln"), "air_defense")
  luaunit.assertEquals(veafCampaign.reserveCategory("Ural-375"), "transport")
  luaunit.assertEquals(veafCampaign.reserveCategory("Some mod"), "armor")
end

function TestVeafCampaignDraw:test_the_owner_side_is_used_for_a_blue_zone()
  veafCampaign.data = { zones = { zoneEntry("Kobuleti", "blue") } }
  veafCampaign.initialize()
  luaunit.assertEquals(self.casCalls[1].side, coalition.side.BLUE)
end

function TestVeafCampaignDraw:test_a_neutral_zone_draws_nothing_and_spawns_nothing()
  veafCampaign.data = { zones = { zoneEntry("Poti", "neutral") } }
  veafCampaign.initialize()
  luaunit.assertEquals(#self.casCalls, 0)
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

function TestVeafCampaignDraw:test_a_size_class_with_a_long_range_sam_adds_a_battery_of_its_own()
  veafCasMission.generateLongRangeAirDefenseGroup = function(name, side)
    return { units = { { "S-300PS 40B6M tr" } }, groupName = name }
  end
  veafCasMission.placeGroup = function(definition, position, spacing, result)
    table.insert(result, placed("S-300PS 40B6M tr", 5, 6))
    return result
  end
  local entry = zoneEntry("Senaki", "red")
  entry.size.long_range_sam = true
  veafCampaign.data = { zones = { entry } }
  veafCampaign.initialize()
  local garrison = veafCampaign.data.zones[1].garrison
  luaunit.assertEquals(#garrison, 2)
  luaunit.assertEquals(garrison[2].name, "Senaki long-range SAM")
  luaunit.assertEquals(garrison[2].units[1].type, "S-300PS 40B6M tr")
end

function TestVeafCampaignDraw:test_an_explicit_garrison_list_replaces_the_draw()
  local definitions = {}
  veafUnits.findGroup = function(name)
    if name == "hq7" then
      return { units = { { "HQ-7_LN_SP" } }, groupName = "hq7" }
    end
    return nil
  end
  veafCasMission.placeGroup = function(definition, position, spacing, result)
    table.insert(definitions, definition)
    for _, unit in ipairs(definition.units) do
      table.insert(result, placed(unit[1], 7, 8))
    end
    return result
  end
  veafCampaign.data = { zones = { zoneEntry("Gudauta depot", "red", { garrison_list = { "hq7", "sa8", "T-72B" } }) } }
  veafCampaign.initialize()
  luaunit.assertEquals(#self.casCalls, 0)
  -- the group alias is a group of its own, the unit alias and the DCS type are gathered in another
  luaunit.assertEquals(#definitions, 2)
  local types = {}
  for _, unit in ipairs(veafCampaign.data.zones[1].garrison[1].units) do
    table.insert(types, unit.type)
  end
  luaunit.assertEquals(types, { "HQ-7_LN_SP", "sa8", "T-72B" })
end

-- ---------------------------------------------------------------------------
-- TestVeafCampaignCompose — the garrison is not a CAS target group
-- ---------------------------------------------------------------------------
TestVeafCampaignCompose = {}

function TestVeafCampaignCompose:setUp()
  self.saved = {
    random = math.random,
    findPointInZone = veaf.findPointInZone,
    placeGroup = veafCasMission.placeGroup,
    infantry = veafCasMission.generateInfantryGroup,
    armor = veafCasMission.generateArmorPlatoon,
    airDefense = veafCasMission.generateAirDefenseGroup,
    transport = veafCasMission.generateTransportCompany,
  }
  local this = self
  self.made, self.radii = {}, {}
  math.random = function(low, high)
    return high or low -- the largest draw
  end
  veaf.findPointInZone = function(center, radius)
    table.insert(this.radii, radius)
    return { x = center.x, y = center.z }
  end
  veafCasMission.placeGroup = function(group, position, spacing, result)
    table.insert(result, placed(group.kind, position.x, position.y))
    return result
  end
  local function maker(kind)
    return function()
      table.insert(this.made, kind)
      return { kind = kind, units = {} }
    end
  end
  veafCasMission.generateInfantryGroup = maker("infantry")
  veafCasMission.generateArmorPlatoon = maker("armor")
  veafCasMission.generateAirDefenseGroup = maker("air defense")
  veafCasMission.generateTransportCompany = maker("transport")
end

function TestVeafCampaignCompose:tearDown()
  local s = self.saved
  math.random, veaf.findPointInZone, veafCasMission.placeGroup = s.random, s.findPointInZone, s.placeGroup
  veafCasMission.generateInfantryGroup, veafCasMission.generateArmorPlatoon = s.infantry, s.armor
  veafCasMission.generateAirDefenseGroup, veafCasMission.generateTransportCompany = s.airDefense, s.transport
end

local function count(list, kind)
  local n = 0
  for _, item in ipairs(list) do
    if item == kind then
      n = n + 1
    end
  end
  return n
end

function TestVeafCampaignCompose:test_the_same_groups_as_a_cas_target_but_no_transport_company()
  veafCampaign.composeGarrison("Z", { x = 1, y = 0, z = 2 }, 1500, { size = 2, defense = 4, armor = 1 }, coalition.side.RED)
  -- the largest draw of a size 2: size + 1 sections and platoons; defense above 3: two air defence groups
  luaunit.assertEquals(count(self.made, "infantry"), 3)
  luaunit.assertEquals(count(self.made, "armor"), 3)
  luaunit.assertEquals(count(self.made, "air defense"), 2)
  luaunit.assertEquals(count(self.made, "transport"), 0)
end

function TestVeafCampaignCompose:test_no_armour_and_no_defence_mean_infantry_alone()
  veafCampaign.composeGarrison("Z", { x = 1, y = 0, z = 2 }, 1500, { size = 1, defense = 0, armor = 0 }, coalition.side.RED)
  luaunit.assertEquals(self.made, { "infantry", "infantry" })
end

function TestVeafCampaignCompose:test_every_group_stands_within_the_zone_radius()
  local units = veafCampaign.composeGarrison("Z", { x = 1, y = 0, z = 2 }, 1500, { size = 1, defense = 1, armor = 1 }, coalition.side.RED)
  luaunit.assertEquals(#units, #self.made)
  for _, radius in ipairs(self.radii) do
    luaunit.assertEquals(radius, 1500)
  end
end

-- ---------------------------------------------------------------------------
-- TestVeafCampaignSpawn
-- ---------------------------------------------------------------------------
TestVeafCampaignSpawn = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestVeafCampaignSpawn:test_a_recorded_garrison_spawns_identically()
  veafCampaign.data = { zones = { zoneEntry("Senaki", "red", { garrison = recordedGarrison("Senaki") }) } }
  veafCampaign.initialize()
  local units = submitted()["Senaki garrison"]
  luaunit.assertEquals(#units, 3)
  luaunit.assertEquals({ units[1].type, units[1].x, units[1].y, units[1].heading }, { "T-72B", 10, 20, 1 })
  luaunit.assertEquals(units[3].name, "Senaki garrison #3")
end

function TestVeafCampaignSpawn:test_lost_units_are_not_spawned_and_the_others_keep_their_names()
  local garrison = recordedGarrison("Senaki")
  garrison[1].units[2].alive = false
  veafCampaign.data = { zones = { zoneEntry("Senaki", "red", { garrison = garrison }) } }
  veafCampaign.initialize()
  local units = submitted()["Senaki garrison"]
  luaunit.assertEquals(#units, 2)
  luaunit.assertEquals({ units[1].name, units[2].name }, { "Senaki garrison #1", "Senaki garrison #3" })
end

function TestVeafCampaignSpawn:test_a_group_whose_units_are_all_lost_is_not_submitted()
  local garrison = recordedGarrison("Senaki")
  table.insert(
    garrison,
    { name = "Senaki long-range SAM", units = { { type = "S-300PS 40B6M tr", x = 0, z = 0, heading = 0, alive = false } } }
  )
  veafCampaign.data = { zones = { zoneEntry("Senaki", "red", { garrison = garrison }) } }
  veafCampaign.initialize()
  luaunit.assertNil(submitted()["Senaki long-range SAM"])
  luaunit.assertNotNil(submitted()["Senaki garrison"])
end

-- ---------------------------------------------------------------------------
-- TestVeafCampaignLosses
-- ---------------------------------------------------------------------------
TestVeafCampaignLosses = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestVeafCampaignLosses:setUp()
  setUpSuite(self)
  veafCampaign.data = { zones = { zoneEntry("Senaki", "red", { garrison = recordedGarrison("Senaki") }) } }
  veafCampaign.initialize()
end

--- The callback registered for a function, or nil.
local function callbackFor(fn)
  for _, callback in ipairs(veafEventHandler.callbacks) do
    if callback.call == fn then
      return callback
    end
  end
  return nil
end

function TestVeafCampaignLosses:test_the_module_listens_to_dead_and_lost_events()
  luaunit.assertEquals(callbackFor(veafCampaign.onUnitDead).events, { "S_EVENT_DEAD", "S_EVENT_UNIT_LOST" })
end

function TestVeafCampaignLosses:test_a_dead_garrison_unit_is_recorded_as_lost()
  veafCampaign.onUnitDead(deadEvent("Senaki garrison #2"))
  local units = veafCampaign.data.zones[1].garrison[1].units
  luaunit.assertEquals({ units[1].alive, units[2].alive, units[3].alive }, { true, false, true })
  luaunit.assertEquals({ veafCampaign.zones["Senaki"]:countUnits() }, { 2, 3 })
end

function TestVeafCampaignLosses:test_a_unit_that_is_not_the_campaigns_is_ignored()
  veafCampaign.onUnitDead(deadEvent("Some player"))
  veafCampaign.onUnitDead({})
  luaunit.assertEquals({ veafCampaign.zones["Senaki"]:countUnits() }, { 3, 3 })
end

function TestVeafCampaignLosses:test_a_zone_that_loses_its_whole_garrison_turns_neutral_and_says_so()
  for index = 1, 3 do
    veafCampaign.onUnitDead(deadEvent("Senaki garrison #" .. index))
    -- DCS sends a lost event after the dead one: counted once
    veafCampaign.onUnitDead(deadEvent("Senaki garrison #" .. index))
  end
  local entry = veafCampaign.data.zones[1]
  luaunit.assertEquals(entry.owner, "neutral")
  luaunit.assertNil(entry.garrison)
  luaunit.assertEquals(#dcs_mocks.messages, 1)
  luaunit.assertStrContains(dcs_mocks.messages[1].text, "Senaki")
end

function TestVeafCampaignLosses:test_a_zone_that_keeps_one_unit_stays_with_its_owner()
  veafCampaign.onUnitDead(deadEvent("Senaki garrison #1"))
  veafCampaign.onUnitDead(deadEvent("Senaki garrison #2"))
  luaunit.assertEquals(veafCampaign.data.zones[1].owner, "red")
end

-- ---------------------------------------------------------------------------
-- TestVeafCampaignMap (ticket 03)
-- ---------------------------------------------------------------------------
TestVeafCampaignMap = { tearDown = tearDownSuite }

function TestVeafCampaignMap:setUp()
  setUpSuite(self)
  veaf.config.language = "en"
  local poti = zoneEntry("Poti", "neutral")
  poti.x, poti.z = 5000, 6000
  veafCampaign.data = {
    zones = {
      zoneEntry("Senaki", "red", { garrison = recordedGarrison("Senaki"), radius = 3000 }),
      zoneEntry("Kobuleti", "blue", { garrison = recordedGarrison("Kobuleti") }),
      poti,
    },
    connections = { { "Senaki", "Kobuleti" }, { "Senaki", "Poti" } },
  }
  veafCampaign.initialize()
end

function TestVeafCampaignMap:test_every_zone_is_drawn_once_with_its_owner_colour()
  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 3)
  local senaki = dcs_mocks.circlesDrawn[1]
  luaunit.assertEquals(senaki.coalition, -1)
  luaunit.assertEquals(senaki.radius, 3000)
  luaunit.assertEquals(senaki.color, veafCampaign.COLORS.red.line)
  luaunit.assertEquals(senaki.fillColor, veafCampaign.COLORS.red.fill)
  luaunit.assertEquals(dcs_mocks.circlesDrawn[2].color, veafCampaign.COLORS.blue.line)
  luaunit.assertEquals(dcs_mocks.circlesDrawn[3].color, veafCampaign.COLORS.neutral.line)
end

function TestVeafCampaignMap:test_each_zone_is_labelled_with_its_name_and_state()
  luaunit.assertEquals(self.texts[1].text, "Senaki — 100%")
  luaunit.assertEquals(self.texts[3].text, "Poti — neutral")
end

function TestVeafCampaignMap:test_one_line_per_connection()
  luaunit.assertEquals(#self.lines, 2)
  luaunit.assertEquals(self.lines[2].to, { x = 5000, y = 0, z = 6000 })
end

function TestVeafCampaignMap:test_nothing_is_redrawn_without_a_change()
  local drawn = #self.texts
  veafCampaign.beat()
  veafCampaign.beat()
  luaunit.assertEquals(#self.texts, drawn)
  luaunit.assertEquals(#dcs_mocks.marksRemoved, 0)
end

function TestVeafCampaignMap:test_a_loss_redraws_the_zone_and_only_that_one()
  local drawn = #self.texts
  veafCampaign.onUnitDead(deadEvent("Senaki garrison #1"))
  luaunit.assertEquals(#self.texts, drawn + 1)
  luaunit.assertEquals(self.texts[#self.texts].text, "Senaki — 67%")
  -- the former circle and label are gone, the new ones are the only Senaki drawing left
  luaunit.assertEquals(#dcs_mocks.marksRemoved, 2)
  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 3)
end

function TestVeafCampaignMap:test_a_zone_turned_neutral_is_redrawn_grey()
  for index = 1, 3 do
    veafCampaign.onUnitDead(deadEvent("Senaki garrison #" .. index))
  end
  local last = dcs_mocks.circlesDrawn[#dcs_mocks.circlesDrawn]
  luaunit.assertEquals(last.color, veafCampaign.COLORS.neutral.line)
  luaunit.assertEquals(self.texts[#self.texts].text, "Senaki — neutral")
end

function TestVeafCampaignMap:test_a_capture_in_progress_shows_on_the_label()
  veafCampaign.zones["Poti"].entry.capture = { side = "blue", seconds = 40 }
  veafCampaign.zones["Poti"]:draw()
  luaunit.assertEquals(self.texts[#self.texts].text, "Poti — blue capture in progress (40 s)")
end

function TestVeafCampaignMap:test_the_module_runs_one_loop_for_all_its_zones()
  local loops = 0
  for _, task in pairs(dcs_mocks.scheduledTasks) do
    if not task.done then
      loops = loops + 1
    end
  end
  luaunit.assertEquals(loops, 1)
  veafCampaign.beat()
  luaunit.assertEquals(veafCampaign.counters.beats, 1)
  luaunit.assertEquals(veafCampaign.counters.zonesProcessed, 3)
end

-- ---------------------------------------------------------------------------
-- TestVeafCampaignMenu (ticket 03)
-- ---------------------------------------------------------------------------
TestVeafCampaignMenu = { tearDown = tearDownSuite }

function TestVeafCampaignMenu:setUp()
  setUpSuite(self)
  local garrison = recordedGarrison("Senaki")
  garrison[1].units[1].alive = false
  veafCampaign.data = {
    campaign = "Caucasus Front",
    mission = 2,
    missions = 10,
    objectives = { { kind = "capture", zones = { "Senaki", "Kutaisi" } }, { kind = "destroy", zones = { "Gudauta depot" } } },
    zones = {
      zoneEntry("Senaki", "red", { garrison = garrison, capture = { side = "blue", seconds = 30 } }),
      zoneEntry("Kobuleti", "blue", { garrison = recordedGarrison("Kobuleti") }),
    },
  }
  veafCampaign.initialize()
end

function TestVeafCampaignMenu:test_the_situation_in_english()
  veaf.config.language = "en"
  luaunit.assertEquals(
    veafCampaign.situationText(),
    table.concat({
      "Campaign Caucasus Front — mission 2 of 10",
      "- Senaki: red, garrison 67%, blue capture in progress (30 s)",
      "- Kobuleti: blue, garrison 100%",
      "Objectives:",
      "- capture Senaki, Kutaisi",
      "- destroy Gudauta depot",
    }, "\n")
  )
end

function TestVeafCampaignMenu:test_the_situation_in_french()
  veaf.config.language = "fr"
  local text = veafCampaign.situationText()
  luaunit.assertStrContains(text, "Campagne Caucasus Front — mission 2 sur 10")
  luaunit.assertStrContains(text, "- Senaki : rouge, garnison 67 %, capture bleu en cours (30 s)")
  luaunit.assertStrContains(text, "- prendre Senaki, Kutaisi")
end

function TestVeafCampaignMenu:test_the_situation_goes_to_everybody()
  veafCampaign.reportSituation()
  luaunit.assertEquals(dcs_mocks.messages[#dcs_mocks.messages].fn, "outText")
end

function TestVeafCampaignMenu:test_the_menu_is_built()
  luaunit.assertNotNil(veafCampaign.rootPath)
end

function TestVeafCampaignMenu:test_the_counters_are_reported_in_both_languages()
  veaf.config.language = "en"
  veafCampaign.beat()
  veafCampaign.reportCounters()
  luaunit.assertStrContains(dcs_mocks.messages[#dcs_mocks.messages].text, "Campaign: 1 beats, 2 zones visited")
  veaf.config.language = "fr"
  veafCampaign.reportCounters()
  luaunit.assertStrContains(dcs_mocks.messages[#dcs_mocks.messages].text, "Campagne : 1 battements, 2 zones visitées")
end

-- ---------------------------------------------------------------------------
-- TestVeafCampaignStateFile (ticket 05)
-- ---------------------------------------------------------------------------
TestVeafCampaignStateFile = { tearDown = tearDownSuite }

--- A file system in memory: what was created, written, renamed and removed.
local function fakeFileSystem(self, options)
  options = options or {}
  self.files, self.mkdirs, self.renames, self.removed = {}, {}, {}, {}
  local this = self
  local fakeIo = {
    open = function(path, mode)
      if options.openFails then
        return nil, "Permission denied"
      end
      local chunks = {}
      return {
        write = function(_, text)
          table.insert(chunks, text)
        end,
        close = function()
          this.files[path] = table.concat(chunks)
        end,
      }
    end,
  }
  local fakeLfs = {
    writedir = function()
      return "C:\\Saved Games\\DCS\\"
    end,
    mkdir = function(path)
      table.insert(this.mkdirs, path)
      return true
    end,
  }
  local fakeOs = {
    rename = function(from, to)
      table.insert(this.renames, { from, to })
      this.files[to], this.files[from] = this.files[from], nil
      return true
    end,
    remove = function(path)
      table.insert(this.removed, path)
      this.files[path] = nil
      return true
    end,
  }
  veafCampaign.fileSystem = function()
    if options.sanitized then
      return nil, nil, nil
    end
    if options.withoutOs then
      return fakeIo, fakeLfs, nil
    end
    return fakeIo, fakeLfs, fakeOs
  end
end

local FOLDER = "C:\\Saved Games\\DCS\\Missions\\Saves\\Caucasus Front\\"
local PATH = FOLDER .. "mission-02.state"

function TestVeafCampaignStateFile:setUp()
  setUpSuite(self)
  local garrison = recordedGarrison("Senaki")
  garrison[1].units[2].alive = false
  veafCampaign.data = {
    format_version = 1,
    campaign = "Caucasus Front",
    mission = 2,
    state_write_seconds = 60,
    zones = {
      zoneEntry("Senaki", "red", { garrison = garrison }),
      zoneEntry("Poti", "neutral", { capture = { side = "blue", seconds = 20 } }),
    },
    sides = { red = { reserve = { armor = 4 } }, blue = { reserve = {} } },
    scenery_destroyed = { { id = 1234, x = 1.5, z = -2.5 } },
  }
  dcs_mocks.currentTime = 100
  veafCampaign.initialize()
end

function TestVeafCampaignStateFile:test_the_state_holds_everything_the_next_mission_depends_on()
  dcs_mocks.currentTime = 130
  local state = veafCampaign.stateTable()
  luaunit.assertEquals(state.format_version, 1)
  luaunit.assertEquals(state.campaign, "Caucasus Front")
  luaunit.assertEquals(state.mission, 2)
  luaunit.assertEquals(state.simulation_time, 130)
  luaunit.assertEquals(state.zones.Senaki.owner, "red")
  luaunit.assertFalse(state.zones.Senaki.garrison[1].units[2].alive)
  luaunit.assertEquals(state.zones.Poti, { owner = "neutral", capture = { side = "blue", seconds = 20 } })
  luaunit.assertEquals(state.sides.red.reserve.armor, 4)
  luaunit.assertEquals(state.scenery_destroyed[1].id, 1234)
end

function TestVeafCampaignStateFile:test_a_serialized_state_reads_back_identical()
  local state = veafCampaign.stateTable()
  local text = veafCampaign.serialize(state)
  local read = assert(loadstring("return " .. text))()
  luaunit.assertEquals(read, state)
  -- the same state always serializes the same way
  luaunit.assertEquals(veafCampaign.serialize(read), text)
end

function TestVeafCampaignStateFile:test_numbers_keep_their_precision()
  local value = { 1234.5678901234, -0.1, 3, 1e20 }
  luaunit.assertEquals(assert(loadstring("return " .. veafCampaign.serialize(value)))(), value)
end

function TestVeafCampaignStateFile:test_the_file_is_written_to_a_temporary_then_moved_over_the_previous_one()
  fakeFileSystem(self)
  luaunit.assertTrue(veafCampaign.writeState())
  luaunit.assertEquals(self.mkdirs, {
    "C:\\Saved Games\\DCS\\Missions",
    "C:\\Saved Games\\DCS\\Missions\\Saves",
    FOLDER,
  })
  luaunit.assertEquals(self.removed, { PATH })
  luaunit.assertEquals(self.renames, { { PATH .. ".tmp", PATH } })
  luaunit.assertNil(self.files[PATH .. ".tmp"])
  local content = self.files[PATH]
  luaunit.assertEquals(content:sub(1, 7), "return ")
  luaunit.assertEquals(assert(loadstring(content))().zones.Senaki.owner, "red")
end

function TestVeafCampaignStateFile:test_without_os_the_complete_temporary_is_written_before_the_file_itself()
  -- the VEAF servers sanitize `os` and keep `io` and `lfs` (measured 2026-10-03)
  fakeFileSystem(self, { withoutOs = true })
  luaunit.assertTrue(veafCampaign.writeState())
  luaunit.assertEquals(self.renames, {})
  luaunit.assertNotNil(self.files[PATH .. ".tmp"])
  luaunit.assertEquals(self.files[PATH], self.files[PATH .. ".tmp"])
end

function TestVeafCampaignStateFile:test_a_file_that_cannot_be_opened_keeps_the_previous_one()
  fakeFileSystem(self, { openFails = true })
  luaunit.assertFalse(veafCampaign.writeState())
  luaunit.assertEquals(self.removed, {})
  luaunit.assertEquals(self.renames, {})
end

function TestVeafCampaignStateFile:test_a_sanitized_install_is_reported_once_and_never_crashes()
  fakeFileSystem(self, { sanitized = true })
  luaunit.assertFalse(veafCampaign.writeState())
  luaunit.assertFalse(veafCampaign.writeState())
  luaunit.assertEquals(#dcs_mocks.messages, 1)
end

function TestVeafCampaignStateFile:test_the_state_is_written_every_interval_during_the_flight()
  fakeFileSystem(self)
  dcs_mocks.currentTime = 150
  veafCampaign.beat()
  luaunit.assertEquals(#self.renames, 0)
  dcs_mocks.currentTime = 160
  veafCampaign.beat()
  luaunit.assertEquals(#self.renames, 1)
  dcs_mocks.currentTime = 200
  veafCampaign.beat()
  luaunit.assertEquals(#self.renames, 1)
  dcs_mocks.currentTime = 220
  veafCampaign.beat()
  luaunit.assertEquals(#self.renames, 2)
  luaunit.assertEquals(veafCampaign.counters.stateWrites, 2)
end

function TestVeafCampaignStateFile:test_the_state_is_written_at_mission_end()
  fakeFileSystem(self)
  luaunit.assertEquals(callbackFor(veafCampaign.onMissionEnd).events, { "S_EVENT_MISSION_END" })
  veafCampaign.onMissionEnd()
  luaunit.assertNotNil(self.files[PATH])
end

function TestVeafCampaignStateFile:test_scenery_destroyed_in_this_mission_is_added_to_the_earlier_record()
  local saved = veafMissionDb.destroyedScenery
  veafMissionDb.destroyedScenery = {
    [1234] = { id = 1234, position = { x = 1.5, y = 0, z = -2.5 } }, -- already recorded by an earlier mission
    [77] = { id = 77, position = { x = 10, y = 3, z = 20 }, typeName = "BRIDGE" },
  }
  local scenery = veafCampaign.stateTable().scenery_destroyed
  veafMissionDb.destroyedScenery = saved
  luaunit.assertEquals(scenery, { { id = 1234, x = 1.5, z = -2.5 }, { id = 77, x = 10, z = 20, type = "BRIDGE" } })
end

function TestVeafCampaignStateFile:test_the_missiles_a_garrison_unit_has_left_are_recorded()
  local saved = Unit.getByName
  Unit.getByName = function(name)
    if name ~= "Senaki garrison #1" then
      return nil
    end
    return {
      getAmmo = function()
        return {
          { count = 3, desc = { category = Weapon.Category.MISSILE } },
          { count = 200, desc = { category = Weapon.Category.SHELL } },
        }
      end,
    }
  end
  local units = veafCampaign.stateTable().zones.Senaki.garrison[1].units
  Unit.getByName = saved
  luaunit.assertEquals(units[1].missiles, 3)
  luaunit.assertNil(units[3].missiles)
end

function TestVeafCampaignStateFile:test_the_airbase_warehouse_is_recorded()
  local saved = Airbase.getByName
  local inventory = { aircraft = { ["F-16C_50"] = 4 }, weapon = { ["AIM-120C"] = 20 }, liquids = { 1000 } }
  Airbase.getByName = function(name)
    return {
      getWarehouse = function()
        return {
          getInventory = function()
            return inventory
          end,
        }
      end,
    }
  end
  veafCampaign.zones["Senaki"].entry.airbase = "Senaki-Kolkhi"
  local zones = veafCampaign.stateTable().zones
  Airbase.getByName = saved
  luaunit.assertEquals(zones.Senaki.warehouse, inventory)
  luaunit.assertNil(zones.Poti.warehouse)
end

function TestVeafCampaignStateFile:test_a_campaign_name_cannot_escape_its_folder()
  veafCampaign.data.campaign = "..\\..\\Windows"
  luaunit.assertEquals(veafCampaign.stateFolder("W\\"), "W\\Missions\\Saves\\______Windows\\")
end

-- ---------------------------------------------------------------------------
-- TestVeafCampaignCapture (ticket 04)
-- ---------------------------------------------------------------------------
TestVeafCampaignCapture = {}

--- An object as world.searchObjects hands it over.
local function object(side, category, options)
  options = options or {}
  return {
    getDesc = function()
      return { category = category }
    end,
    getCoalition = function()
      return side
    end,
    isActive = function()
      return not options.inactive
    end,
    inAir = function()
      return options.inAir or false
    end,
    getName = function()
      return options.name or "some object"
    end,
    isExist = function()
      return not options.gone
    end,
    getLife = function()
      return options.life or 10
    end,
  }
end

local function groundUnit(side, options)
  return object(side, Unit.Category.GROUND_UNIT, options)
end

local BLUE, RED = coalition.side.BLUE, coalition.side.RED

function TestVeafCampaignCapture:setUp()
  setUpSuite(self)
  self.savedAirbase, self.savedCrates = Airbase.getByName, CTLDCrateManager
  self.airbaseCalls = {}
  local this = self
  Airbase.getByName = function(name)
    return {
      autoCapture = function(_, enabled)
        table.insert(this.airbaseCalls, { "autoCapture", name, enabled })
      end,
      setCoalition = function(_, side)
        table.insert(this.airbaseCalls, { "setCoalition", name, side })
      end,
    }
  end
  veafCampaign.data = {
    capture_seconds = 60,
    zones = {
      zoneEntry("Poti", "neutral", { airbase = "Poti" }),
      zoneEntry("Senaki", "red", { garrison = recordedGarrison("Senaki"), airbase = "Senaki-Kolkhi" }),
    },
  }
  veafCampaign.initialize()
  self.poti = veafCampaign.zones["Poti"]
end

function TestVeafCampaignCapture:tearDown()
  Airbase.getByName, CTLDCrateManager = self.savedAirbase, self.savedCrates
  dcs_mocks.searchObjectsObjects = {}
  tearDownSuite(self)
end

local function beats(count)
  for _ = 1, count do
    veafCampaign.beat()
  end
end

function TestVeafCampaignCapture:test_one_side_alone_runs_the_clock()
  dcs_mocks.searchObjectsObjects = { groundUnit(BLUE) }
  beats(3)
  luaunit.assertEquals(self.poti.entry.capture, { side = "blue", seconds = 30 })
  luaunit.assertEquals(self.poti.entry.owner, "neutral")
end

function TestVeafCampaignCapture:test_the_clock_reaching_capture_seconds_captures_the_zone()
  dcs_mocks.searchObjectsObjects = { groundUnit(BLUE) }
  beats(6)
  local entry = self.poti.entry
  luaunit.assertEquals(entry.owner, "blue")
  luaunit.assertNil(entry.capture)
  -- the new owner's garrison is drawn and spawned at once
  luaunit.assertEquals(self.casCalls[1].side, BLUE)
  luaunit.assertNotNil(entry.garrison)
  luaunit.assertNotNil(submitted()["Poti garrison"])
  luaunit.assertEquals(#dcs_mocks.messagesContaining("Poti"), 1)
end

function TestVeafCampaignCapture:test_only_a_neutral_zone_can_be_captured()
  dcs_mocks.searchObjectsObjects = { groundUnit(BLUE) }
  beats(10)
  luaunit.assertEquals(veafCampaign.zones["Senaki"].entry.owner, "red")
  luaunit.assertNil(veafCampaign.zones["Senaki"].entry.capture)
end

function TestVeafCampaignCapture:test_both_sides_present_stop_the_clock()
  dcs_mocks.searchObjectsObjects = { groundUnit(BLUE) }
  beats(3)
  dcs_mocks.searchObjectsObjects = { groundUnit(BLUE), groundUnit(RED) }
  beats(10)
  luaunit.assertEquals(self.poti.entry.capture, { side = "blue", seconds = 30 })
  luaunit.assertEquals(self.poti.entry.owner, "neutral")
end

function TestVeafCampaignCapture:test_everyone_gone_cancels_the_capture()
  dcs_mocks.searchObjectsObjects = { groundUnit(BLUE) }
  beats(3)
  dcs_mocks.searchObjectsObjects = {}
  beats(1)
  luaunit.assertNil(self.poti.entry.capture)
end

function TestVeafCampaignCapture:test_the_other_side_alone_starts_its_own_clock()
  dcs_mocks.searchObjectsObjects = { groundUnit(BLUE) }
  beats(3)
  dcs_mocks.searchObjectsObjects = { groundUnit(RED) }
  beats(1)
  luaunit.assertEquals(self.poti.entry.capture, { side = "red", seconds = 10 })
end

function TestVeafCampaignCapture:test_aircraft_in_flight_never_hold_ground()
  dcs_mocks.searchObjectsObjects = {
    object(BLUE, Unit.Category.AIRPLANE),
    object(BLUE, Unit.Category.HELICOPTER, { inAir = true }),
  }
  beats(10)
  luaunit.assertNil(self.poti.entry.capture)
  luaunit.assertEquals(self.poti.entry.owner, "neutral")
end

function TestVeafCampaignCapture:test_a_landed_helicopter_holds_ground()
  dcs_mocks.searchObjectsObjects = { object(BLUE, Unit.Category.HELICOPTER, { inAir = false }) }
  beats(1)
  luaunit.assertEquals(self.poti.entry.capture.side, "blue")
end

function TestVeafCampaignCapture:test_a_late_activated_unit_does_not_hold_ground()
  dcs_mocks.searchObjectsObjects = { groundUnit(BLUE, { inactive = true }) }
  beats(1)
  luaunit.assertNil(self.poti.entry.capture)
end

function TestVeafCampaignCapture:test_the_wreck_of_a_dead_unit_does_not_contest_the_zone()
  -- a garrison destroyed, its wrecks still around: they must not stop the capture
  dcs_mocks.searchObjectsObjects = {
    groundUnit(BLUE),
    groundUnit(RED, { life = 0 }),
    groundUnit(RED, { gone = true }),
  }
  beats(1)
  luaunit.assertEquals(self.poti.entry.capture, { side = "blue", seconds = 10 })
end

function TestVeafCampaignCapture:test_who_holds_a_neutral_zone_is_said_when_it_changes()
  dcs_mocks.searchObjectsObjects = { groundUnit(BLUE, { name = "Abrams 1" }) }
  beats(1)
  luaunit.assertEquals(self.poti.presence, "blue (Abrams 1)")
  dcs_mocks.searchObjectsObjects = { groundUnit(BLUE, { name = "Abrams 1" }), groundUnit(RED, { name = "BMP 7" }) }
  beats(1)
  luaunit.assertEquals(self.poti.presence, "contested: blue (Abrams 1), red (BMP 7)")
  dcs_mocks.searchObjectsObjects = {}
  beats(1)
  luaunit.assertEquals(self.poti.presence, "nobody")
end

function TestVeafCampaignCapture:test_a_ctld_crate_holds_ground_and_another_static_does_not()
  CTLDCrateManager = {
    getInstance = function()
      return { crates = { ["CTLD crate 7"] = {} } }
    end,
  }
  dcs_mocks.searchObjectsObjects = { object(RED, -1, { name = "a fuel tank" }) }
  beats(1)
  luaunit.assertNil(self.poti.entry.capture)
  dcs_mocks.searchObjectsObjects = { object(RED, -1, { name = "CTLD crate 7" }) }
  beats(1)
  luaunit.assertEquals(self.poti.entry.capture.side, "red")
end

function TestVeafCampaignCapture:test_both_units_and_statics_are_searched_over_the_zone()
  beats(1)
  local poti = dcs_mocks.searchObjectsCalls[1]
  luaunit.assertEquals(poti.category, Object.Category.UNIT)
  luaunit.assertEquals(poti.volume.params.point, { x = 1000, y = 0, z = 2000 })
  luaunit.assertEquals(dcs_mocks.searchObjectsCalls[2].category, Object.Category.STATIC)
end

function TestVeafCampaignCapture:test_the_capturing_side_draws_its_own_garrison_not_the_declared_list()
  local poti = self.poti.entry
  poti.garrison_list, poti.declared_side = { "sa8", "shilka" }, "red"
  dcs_mocks.searchObjectsObjects = { groundUnit(BLUE) }
  beats(6)
  luaunit.assertEquals(poti.owner, "blue")
  luaunit.assertEquals(#self.casCalls, 1)
  luaunit.assertEquals(self.casCalls[1].side, BLUE)
end

function TestVeafCampaignCapture:test_a_garrison_drawn_after_a_capture_is_paid_from_the_reserve()
  veafCampaign.data.sides = { blue = { reserve = { armor = 5, air_defense = 0, transport = 1 } } }
  dcs_mocks.searchObjectsObjects = { groundUnit(BLUE) }
  beats(6)
  -- the spy draws a T-72B and a BMP-2, both armour
  luaunit.assertEquals(veafCampaign.data.sides.blue.reserve, { armor = 3, air_defense = 0, transport = 1 })
  luaunit.assertEquals(self.casCalls[1].size, 2)
end

function TestVeafCampaignCapture:test_an_empty_reserve_gives_the_smallest_draw()
  veafCampaign.data.sides = { blue = { reserve = { armor = 0, air_defense = 0, transport = 0 } } }
  veafCampaign.zones["Poti"].entry.size = { size = 4, defense = 3, armor = 2, long_range_sam = true }
  dcs_mocks.searchObjectsObjects = { groundUnit(BLUE) }
  beats(6)
  local call = self.casCalls[1]
  luaunit.assertEquals({ call.size, call.defense, call.armor }, { 1, 1, 1 })
  luaunit.assertEquals(#veafCampaign.zones["Poti"].entry.garrison, 1) -- no long-range battery
  luaunit.assertEquals(veafCampaign.data.sides.blue.reserve.armor, 0)
end

function TestVeafCampaignCapture:test_the_campaign_owns_its_airbases_from_the_start()
  luaunit.assertEquals(self.airbaseCalls, {
    { "autoCapture", "Poti", false },
    { "setCoalition", "Poti", coalition.side.NEUTRAL },
    { "autoCapture", "Senaki-Kolkhi", false },
    { "setCoalition", "Senaki-Kolkhi", RED },
  })
end

function TestVeafCampaignCapture:test_a_captured_airbase_follows_its_zone()
  dcs_mocks.searchObjectsObjects = { groundUnit(BLUE) }
  beats(6)
  luaunit.assertEquals(self.airbaseCalls[#self.airbaseCalls], { "setCoalition", "Poti", BLUE })
end

function TestVeafCampaignCapture:test_an_airbase_whose_zone_turns_neutral_turns_neutral()
  for index = 1, 3 do
    veafCampaign.onUnitDead(deadEvent("Senaki garrison #" .. index))
  end
  luaunit.assertEquals(self.airbaseCalls[#self.airbaseCalls], { "setCoalition", "Senaki-Kolkhi", coalition.side.NEUTRAL })
end

-- ---------------------------------------------------------------------------
-- TestVeafCampaignAssault — FEAT-OPPOSITION-SCALES-WITH-PLAYERS ticket 04: assault convoys in flight
-- ---------------------------------------------------------------------------
TestVeafCampaignAssault = {}

--- A convoy unit as Group:getUnits() hands it over, at a position that can be moved.
local function convoyUnit(name, typeName, x, z)
  local unit = { _name = name, _type = typeName, _alive = true, _x = x, _z = z }
  function unit:getName()
    return self._name
  end
  function unit:getTypeName()
    return self._type
  end
  function unit:isExist()
    return self._alive
  end
  function unit:getLife()
    return self._alive and 10 or 0
  end
  function unit:getPoint()
    return { x = self._x, y = 0, z = self._z }
  end
  return unit
end

function TestVeafCampaignAssault:setUp()
  setUpSuite(self)
  local this = self
  self.savedSpawn, self.savedNamedPoints, self.savedOpposition = veafSpawn, veafNamedPoints, veafOpposition
  self.savedUnits = veafUnits.DefaultPathfindingUnitType
  veafUnits.DefaultPathfindingUnitType = "Fixer"
  self.spawns, self.points, self.units = {}, {}, {}
  veafNamedPoints = {
    addPoint = function(name, point)
      this.points[name] = point
    end,
  }
  veafSpawn = {
    spawnConvoy = function(
      spot,
      name,
      _,
      radius,
      country,
      side,
      heading,
      spacing,
      speed,
      patrol,
      offroad,
      destination,
      defense,
      size,
      armor
    )
      table.insert(
        this.spawns,
        { spot = spot, name = name, side = side, destination = destination, defense = defense, size = size, armor = armor }
      )
      local units = {
        convoyUnit(name .. " #1", "T-72B", spot.x, spot.z),
        convoyUnit(name .. " #2", "BMP-2", spot.x, spot.z),
        convoyUnit(name .. " #3", "Ural-375", spot.x, spot.z),
        convoyUnit(name .. " #4", "Fixer", spot.x, spot.z),
      }
      this.units[name] = units
      dcs_mocks.addGroup(name, {
        getUnits = function()
          return units
        end,
      })
      return name
    end,
  }
  veafOpposition = nil
  timer.setTime(0)
  veafCampaign.data = {
    capture_seconds = 60,
    assault_seconds = 600,
    zones = {
      zoneEntry("Kutaisi", "blue", { x = 0, z = 0, garrison = recordedGarrison("Kutaisi") }),
      zoneEntry("Poti", "neutral", { x = 10000, z = 0 }),
      zoneEntry("Senaki", "red", { x = 20000, z = 0, garrison = recordedGarrison("Senaki") }),
    },
    connections = { { "Kutaisi", "Poti" }, { "Poti", "Senaki" } },
    sides = {
      blue = { reserve = { armor = 6, air_defense = 2, transport = 3 } },
      red = { reserve = { armor = 6, air_defense = 2, transport = 3 } },
    },
  }
end

function TestVeafCampaignAssault:tearDown()
  veafSpawn, veafNamedPoints, veafOpposition = self.savedSpawn, self.savedNamedPoints, self.savedOpposition
  veafUnits.DefaultPathfindingUnitType = self.savedUnits
  dcs_mocks.searchObjectsObjects = {}
  tearDownSuite(self)
end

function TestVeafCampaignAssault:test_a_neutral_zone_at_the_start_is_the_target_of_both_neighbours()
  veafCampaign.initialize()
  local red, blue = veafCampaign.pendingAssaults["Poti|red"], veafCampaign.pendingAssaults["Poti|blue"]
  luaunit.assertEquals({ red.from, red.at }, { "Senaki", 600 })
  luaunit.assertEquals({ blue.from, blue.at }, { "Kutaisi", 600 })
end

function TestVeafCampaignAssault:test_nothing_leaves_before_the_delay()
  veafCampaign.initialize()
  timer.setTime(599)
  veafCampaign.beat()
  luaunit.assertEquals(#self.spawns, 0)
end

function TestVeafCampaignAssault:test_the_convoy_leaves_on_the_road_to_its_target_paid_from_the_reserve()
  veafCampaign.initialize()
  veafCampaign.pendingAssaults["Poti|blue"] = nil
  timer.setTime(600)
  veafCampaign.beat()
  luaunit.assertEquals(#self.spawns, 1)
  local spawn = self.spawns[1]
  luaunit.assertEquals({ spawn.side, spawn.destination, spawn.spot.x }, { coalition.side.RED, "CAMPAIGN Poti", 20000 })
  luaunit.assertEquals(self.points["CAMPAIGN Poti"].x, 10000)
  local record = veafCampaign.convoys[1]
  luaunit.assertEquals({ record.side, record.from, record.to }, { "red", "Senaki", "Poti" })
  -- the pathfinding unit a spawned convoy carries is not counted, nor paid for
  luaunit.assertEquals(record.sent, { "BMP-2", "T-72B", "Ural-375" })
  luaunit.assertEquals(veafCampaign.data.sides.red.reserve, { armor = 4, air_defense = 2, transport = 2 })
  luaunit.assertEquals(#dcs_mocks.messagesContaining("Senaki"), 2, "its side told, the other one warned")
end

-- FIX-CAMPAIGN-ARROW-ALTITUDE: the axis was drawn at y = 0, and on the F10 map it slid away from the
-- ground as the map was panned (right only fully zoomed in) — both its ends sit on the terrain now.
function TestVeafCampaignAssault:test_the_axis_arrow_lies_on_the_ground_from_source_to_target()
  local savedArrow, savedHeight = trigger.action.arrowToAll, land.getHeight
  local arrows = {}
  trigger.action.arrowToAll = function(_, _, startPoint, endPoint)
    table.insert(arrows, { startPoint = startPoint, endPoint = endPoint })
  end
  land.getHeight = function(vec2)
    return 30 + vec2.x / 1000
  end
  veafCampaign.initialize()
  veafCampaign.pendingAssaults["Poti|blue"] = nil
  timer.setTime(600)
  veafCampaign.beat()
  trigger.action.arrowToAll, land.getHeight = savedArrow, savedHeight
  luaunit.assertEquals(#arrows, 1)
  luaunit.assertEquals(arrows[1].startPoint, { x = 20000, y = 50, z = 0 })
  luaunit.assertEquals(arrows[1].endPoint, { x = 10000, y = 40, z = 0 })
end

function TestVeafCampaignAssault:test_a_bigger_opposition_attacks_earlier()
  veafOpposition = {
    getLevel = function()
      return 8
    end,
  }
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.pendingAssaults["Poti|red"].at, 300)
end

function TestVeafCampaignAssault:test_the_campaign_can_turn_the_rule_off()
  veafCampaign.data.assault_convoys = false
  veafCampaign.initialize()
  luaunit.assertNil(next(veafCampaign.pendingAssaults))
end

function TestVeafCampaignAssault:test_a_zone_that_falls_neutral_is_counter_attacked()
  veafCampaign.data.zones[2].owner = "red"
  veafCampaign.data.zones[2].garrison = recordedGarrison("Poti")
  veafCampaign.initialize()
  luaunit.assertNil(next(veafCampaign.pendingAssaults))
  timer.setTime(100)
  for index = 1, 3 do
    veafCampaign.onUnitDead(deadEvent("Kutaisi garrison #" .. index))
  end
  luaunit.assertEquals(veafCampaign.zones["Kutaisi"].entry.owner, "neutral")
  local pending = veafCampaign.pendingAssaults["Kutaisi|red"]
  luaunit.assertEquals({ pending.from, pending.at }, { "Poti", 700 })
end

function TestVeafCampaignAssault:test_one_convoy_at_a_time_per_side_and_target()
  veafCampaign.initialize()
  timer.setTime(600)
  veafCampaign.beat()
  veafCampaign.planAssaults(veafCampaign.zones["Poti"], 700)
  luaunit.assertNil(veafCampaign.pendingAssaults["Poti|red"], "a red convoy is already on its way")
end

function TestVeafCampaignAssault:test_an_empty_reserve_sends_nothing()
  veafCampaign.data.sides.red.reserve = { armor = 0, air_defense = 0, transport = 0 }
  veafCampaign.initialize()
  timer.setTime(600)
  veafCampaign.beat()
  for _, spawn in ipairs(self.spawns) do
    luaunit.assertNotEquals(spawn.side, coalition.side.RED)
  end
end

function TestVeafCampaignAssault:test_the_dead_of_a_convoy_are_in_the_state()
  veafCampaign.initialize()
  veafCampaign.pendingAssaults["Poti|blue"] = nil
  timer.setTime(600)
  veafCampaign.beat()
  local name = veafCampaign.convoys[1].name
  self.units[name][1]._alive = false
  local state = veafCampaign.stateTable()
  luaunit.assertEquals(state.convoys[1].sent, { "BMP-2", "T-72B", "Ural-375" })
  luaunit.assertEquals(state.convoys[1].alive, { "BMP-2", "Ural-375" })
  self.units[name][2]._alive, self.units[name][3]._alive = false, false
  veafCampaign.beat()
  luaunit.assertTrue(veafCampaign.convoys[1].ended)
  luaunit.assertEquals(veafCampaign.convoys[1].alive, {})
end

function TestVeafCampaignAssault:test_a_convoy_that_takes_the_zone_becomes_its_garrison()
  veafCampaign.initialize()
  veafCampaign.pendingAssaults["Poti|blue"] = nil
  timer.setTime(600)
  veafCampaign.beat()
  local record = veafCampaign.convoys[1]
  for _, unit in ipairs(self.units[record.name]) do
    unit._x = 10050 -- arrived in Poti
  end
  self.units[record.name][3]._alive = false
  self.casCalls = {}
  veafCampaign.zones["Poti"]:capturedBy("red")
  local garrison = veafCampaign.zones["Poti"].entry.garrison
  luaunit.assertEquals(#self.casCalls, 0, "no second draw: the convoy was paid for when it left")
  luaunit.assertEquals(#garrison[1].units, 2)
  luaunit.assertEquals(record.absorbed, { "BMP-2", "T-72B" })
  luaunit.assertTrue(record.ended)
  -- its units keep their names, and their loss is the zone's
  veafCampaign.onUnitDead(deadEvent(record.name .. " #1"))
  luaunit.assertEquals(veafCampaign.zones["Poti"]:countUnits(), 1)
end

function TestVeafCampaignAssault:test_without_a_convoy_there_the_capture_draws_a_garrison()
  veafCampaign.initialize()
  veafCampaign.zones["Poti"]:capturedBy("blue")
  luaunit.assertEquals(#self.casCalls, 1)
end

function TestVeafCampaignAssault:test_blue_orders_an_assault_from_the_menu()
  veafCampaign.initialize()
  veafCampaign.orderAssault({ "Kutaisi", "Poti" })
  luaunit.assertEquals(#self.spawns, 1)
  luaunit.assertEquals(self.spawns[1].side, coalition.side.BLUE)
  veafCampaign.orderAssault({ "Kutaisi", "Poti" })
  luaunit.assertEquals(#self.spawns, 1, "one convoy at a time to the same target")
end

function TestVeafCampaignAssault:test_blue_cannot_order_from_a_zone_it_does_not_hold()
  veafCampaign.initialize()
  veafCampaign.orderAssault({ "Senaki", "Poti" })
  luaunit.assertEquals(#self.spawns, 0)
end

function TestVeafCampaignAssault:test_an_assault_whose_start_zone_was_lost_does_not_leave()
  veafCampaign.initialize()
  veafCampaign.zones["Senaki"].entry.owner = "blue"
  timer.setTime(600)
  veafCampaign.launchDueAssaults(600)
  for _, spawn in ipairs(self.spawns) do
    luaunit.assertNotEquals(spawn.side, coalition.side.RED)
  end
end

function TestVeafCampaignAssault:test_the_blue_menu_lists_each_blue_zone_towards_each_neighbour_it_does_not_hold()
  veaf.config.language = "en"
  veafCampaign.initialize()
  local titles = {}
  for _, command in ipairs(veafCampaign.assaultPath.commands or {}) do
    table.insert(titles, command.title)
  end
  luaunit.assertEquals(titles, { "Kutaisi to Poti" })
  luaunit.assertEquals(veafCampaign.assaultPath.commands[1].isSecured, true)
end

os.exit(luaunit.LuaUnit.run())
