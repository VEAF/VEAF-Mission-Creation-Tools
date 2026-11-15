--- Tests for veafCampaign.lua's persistent mode (FEAT-DYNAMIC-CAMPAIGN tickets 01 to 03): the save reloaded,
--- victory, defeat and reset, dormant zones, reinforcement, counter-attacks and deliveries.
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

local BLUE, RED = coalition.side.BLUE, coalition.side.RED

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- A recorded garrison of one group of three units, named after the zone.
local function garrison(name, deadUnits)
  local units = {
    { type = "T-72B", x = 10, z = 20, heading = 1, alive = true },
    { type = "BMP-2", x = 11, z = 21, heading = 2, alive = true },
    { type = "Ural-375", x = 12, z = 22, heading = 3, alive = true },
  }
  for _, index in ipairs(deadUnits or {}) do
    units[index].alive = false
  end
  return { { name = name .. " garrison", units = units } }
end

--- A zone entry with a recorded garrison, at `x` along the map's x axis.
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

--- A persistent campaign of four zones in a row, 50 km apart: Kobuleti (blue) — Senaki (red) — Poti
--- (red) — Zugdidi (red).
local function persistentData(dynamic)
  return {
    format_version = 1,
    campaign = "Caucasus Front",
    mission = 1,
    persistent = true,
    player_side = "blue",
    dynamic = dynamic or {},
    zones = {
      zone("Kobuleti", "blue", 0),
      zone("Senaki", "red", 50000),
      zone("Poti", "red", 100000),
      zone("Zugdidi", "red", 150000),
    },
    connections = { { "Kobuleti", "Senaki" }, { "Senaki", "Poti" }, { "Poti", "Zugdidi" } },
    sides = {},
  }
end

--- A file system in memory that can read what it holds.
local function memoryFileSystem(self, options)
  options = options or {}
  self.files = self.files or {}
  local this = self
  local fsIo = {
    open = function(path, mode)
      if mode == "r" then
        local content = this.files[path]
        if content == nil then
          return nil, "No such file"
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
      local chunks = {}
      local file = {}
      file.write = function(_, text)
        table.insert(chunks, text)
        return file
      end
      file.close = function()
        this.files[path] = table.concat(chunks)
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
    if options.sanitized then
      return nil, nil, nil
    end
    return fsIo, fsLfs, nil
  end
end

local SAVE = "C:\\Saved Games\\DCS\\Missions\\Saves\\Caucasus Front\\persistent.state"

--- Players' aircraft where the list says, as coalition.getPlayers hands them over.
local function playersAt(points)
  coalition.getPlayers = function(side)
    if side ~= BLUE then
      return {}
    end
    local units = {}
    for _, point in ipairs(points) do
      table.insert(units, {
        isExist = function()
          return true
        end,
        getPoint = function()
          return { x = point.x, y = 0, z = point.z or 0 }
        end,
      })
    end
    return units
  end
end

local function groupsSubmitted()
  local names = {}
  for _, call in ipairs(dcs_mocks.groupsAdded) do
    table.insert(names, call.group.name)
  end
  return names
end

local function setUpSuite(self)
  dcs_mocks.reset()
  self.saved = {
    fileSystem = veafCampaign.fileSystem,
    getPlayers = coalition.getPlayers,
    callbacks = veafEventHandler.callbacks,
    sendConvoy = veafCampaign.sendConvoy,
    surface = land.getSurfaceType,
    crateManager = CTLDCrateManager,
    troopManager = CTLDTroopManager,
    language = veaf.config.language,
  }
  veaf.config.language = "en"
  veafEventHandler.callbacks = {}
  land.getSurfaceType = function()
    return land.SurfaceType.LAND
  end
  self.files = {}
  memoryFileSystem(self)
  playersAt({})
  veafCampaign.listeners = {}
  veafCampaign.saveParts = {}
end

local function tearDownSuite(self)
  veafCampaign.fileSystem = self.saved.fileSystem
  coalition.getPlayers = self.saved.getPlayers
  veafEventHandler.callbacks = self.saved.callbacks
  veafCampaign.sendConvoy = self.saved.sendConvoy
  land.getSurfaceType = self.saved.surface
  CTLDCrateManager = self.saved.crateManager
  CTLDTroopManager = self.saved.troopManager
  veaf.config.language = self.saved.language
  veafCampaign.data = nil
  veafCampaign.listeners = {}
  veafCampaign.saveParts = {}
  veafCampaign.stateUnwritableReported = nil
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------
TestCampaignSettings = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignSettings:test_a_setting_absent_from_the_data_table_takes_its_default()
  veafCampaign.data = persistentData()
  luaunit.assertEquals(veafCampaign.setting("wake_radius"), 60000)
  luaunit.assertEquals(veafCampaign.setting("economy", "capture"), 200)
end

function TestCampaignSettings:test_a_setting_of_the_data_table_wins()
  veafCampaign.data = persistentData({ wake_radius = 30000, economy = { capture = 50 } })
  luaunit.assertEquals(veafCampaign.setting("wake_radius"), 30000)
  luaunit.assertEquals(veafCampaign.setting("economy", "capture"), 50)
  -- a block set in part keeps the defaults of the rest
  luaunit.assertEquals(veafCampaign.setting("economy", "delivery"), 100)
end

function TestCampaignSettings:test_side_lists()
  veafCampaign.data = persistentData({ attacks = { "blue", "red" } })
  luaunit.assertTrue(veafCampaign.sideListed("attacks", "blue"))
  veafCampaign.data = persistentData()
  luaunit.assertFalse(veafCampaign.sideListed("attacks", "blue"))
  luaunit.assertTrue(veafCampaign.sideListed("attacks", "red"))
end

-- ---------------------------------------------------------------------------
-- The save reloaded
-- ---------------------------------------------------------------------------
TestCampaignSave = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignSave:test_a_persistent_campaign_writes_a_single_file_it_reloads()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  veafCampaign.zones["Senaki"].entry.owner = "neutral"
  veafCampaign.zones["Senaki"].entry.garrison = nil
  luaunit.assertTrue(veafCampaign.writeState())
  luaunit.assertNotNil(self.files[SAVE])

  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.loadResult, "loaded")
  luaunit.assertEquals(veafCampaign.zones["Senaki"].entry.owner, "neutral")
  luaunit.assertNil(veafCampaign.zones["Senaki"].entry.garrison)
end

function TestCampaignSave:test_losses_survive_the_reload()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  veafCampaign.zones["Poti"].entry.garrison[1].units[2].alive = false
  veafCampaign.writeState()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertFalse(veafCampaign.zones["Poti"].entry.garrison[1].units[2].alive)
  luaunit.assertEquals(veafCampaign.zones["Poti"]:strengthPercent(), 67)
end

function TestCampaignSave:test_no_save_is_a_fresh_campaign()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.loadResult, "fresh")
end

function TestCampaignSave:test_a_save_of_another_campaign_is_not_used()
  self.files[SAVE] = 'return {campaign="Syria",format_version=1,zones={Senaki={owner="blue"}}}'
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.loadResult, "other")
  luaunit.assertEquals(veafCampaign.zones["Senaki"].entry.owner, "red")
end

function TestCampaignSave:test_a_reset_save_starts_a_fresh_campaign()
  self.files[SAVE] = 'return {campaign="Caucasus Front",format_version=1,reset=true,zones={Senaki={owner="blue"}}}'
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.loadResult, "fresh")
  luaunit.assertEquals(veafCampaign.zones["Senaki"].entry.owner, "red")
end

function TestCampaignSave:test_an_unreadable_save_is_reported_and_not_used()
  self.files[SAVE] = "return {{{ broken"
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.loadResult, "unreadable")
end

function TestCampaignSave:test_a_save_cannot_call_anything()
  self.files[SAVE] = 'return {campaign="Caucasus Front",format_version=1,zones={Senaki={owner=os and "blue" or "red"}},'
    .. 'x=trigger.action.outText("pwned")}'
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.loadResult, "unreadable")
  luaunit.assertEquals(#dcs_mocks.messagesContaining("pwned"), 0)
end

function TestCampaignSave:test_without_io_the_campaign_runs_from_its_declared_state()
  memoryFileSystem(self, { sanitized = true })
  veafCampaign.data = persistentData()
  luaunit.assertTrue(veafCampaign.initialize())
  luaunit.assertEquals(veafCampaign.loadResult, "no-io")
end

function TestCampaignSave:test_a_zone_the_save_does_not_know_keeps_its_declared_state()
  self.files[SAVE] = 'return {campaign="Caucasus Front",format_version=1,zones={Senaki={owner="blue"},Gone={owner="red"}}}'
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.zones["Senaki"].entry.owner, "blue")
  luaunit.assertEquals(veafCampaign.zones["Poti"].entry.owner, "red")
  luaunit.assertNil(veafCampaign.zones["Gone"])
end

function TestCampaignSave:test_a_module_gets_its_part_of_the_save_back()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  veafCampaign.saveParts.economy = {
    save = function()
      return { credits = 750 }
    end,
  }
  veafCampaign.writeState()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.savedPart("economy"), { credits = 750 })
end

-- ---------------------------------------------------------------------------
-- Victory, defeat, reset
-- ---------------------------------------------------------------------------
TestCampaignOutcome = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignOutcome:test_the_enemy_holding_no_zone_is_a_victory()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  for _, name in ipairs({ "Senaki", "Poti", "Zugdidi" }) do
    veafCampaign.zones[name].entry.owner = "blue"
  end
  luaunit.assertEquals(veafCampaign.checkOutcome(), "victory")
  luaunit.assertEquals(#dcs_mocks.messagesContaining("Victory"), 1)
end

function TestCampaignOutcome:test_the_players_holding_no_zone_is_a_defeat()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  veafCampaign.zones["Kobuleti"].entry.owner = "neutral"
  luaunit.assertEquals(veafCampaign.checkOutcome(), "defeat")
end

function TestCampaignOutcome:test_a_neutral_zone_left_is_not_a_victory_yet()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  veafCampaign.zones["Senaki"].entry.owner = "blue"
  veafCampaign.zones["Poti"].entry.owner = "blue"
  veafCampaign.zones["Zugdidi"].entry.owner = "neutral"
  luaunit.assertEquals(veafCampaign.checkOutcome(), "victory")
end

function TestCampaignOutcome:test_the_last_enemy_zone_lost_ends_the_campaign()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  veafCampaign.zones["Senaki"].entry.owner = "blue"
  veafCampaign.zones["Poti"].entry.owner = "blue"
  veafCampaign.zones["Zugdidi"]:becomeNeutral()
  luaunit.assertEquals(veafCampaign.over, "victory")
end

function TestCampaignOutcome:test_once_over_the_save_is_marked_reset_and_the_next_load_is_fresh()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  veafCampaign.zones["Senaki"].entry.owner = "blue"
  veafCampaign.endCampaign("victory")
  luaunit.assertStrContains(self.files[SAVE], '["reset"]=true')
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.loadResult, "fresh")
  luaunit.assertEquals(veafCampaign.zones["Senaki"].entry.owner, "red")
end

function TestCampaignOutcome:test_once_over_nothing_is_captured()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  veafCampaign.zones["Senaki"].entry.owner = "neutral"
  veafCampaign.endCampaign("reset")
  dcs_mocks.searchObjectsObjects = {}
  veafCampaign.zones["Senaki"]:checkCapture(500)
  luaunit.assertEquals(veafCampaign.zones["Senaki"].entry.owner, "neutral")
end

function TestCampaignOutcome:test_an_episodic_campaign_never_ends_in_flight()
  local data = persistentData()
  data.persistent = nil
  veafCampaign.data = data
  veafCampaign.initialize()
  veafCampaign.zones["Kobuleti"].entry.owner = "neutral"
  luaunit.assertNil(veafCampaign.checkOutcome())
end

-- ---------------------------------------------------------------------------
-- Dormant zones
-- ---------------------------------------------------------------------------
TestCampaignDormancy = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignDormancy:test_a_persistent_campaign_starts_with_every_zone_asleep()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

function TestCampaignDormancy:test_a_player_near_wakes_the_zone()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  playersAt({ { x = 52000 } }) -- 2 km from Senaki
  veafCampaign.updateDormancy(100)
  luaunit.assertEquals(groupsSubmitted(), { "Senaki garrison" })
  luaunit.assertTrue(veafCampaign.zones["Senaki"].awake)
end

function TestCampaignDormancy:test_one_zone_wakes_per_pass_the_nearest_first()
  veafCampaign.data = persistentData({ wake_radius = 200000 })
  veafCampaign.initialize()
  playersAt({ { x = 95000 } }) -- Poti, then Senaki, then Zugdidi, then Kobuleti
  veafCampaign.updateDormancy(100)
  luaunit.assertEquals(groupsSubmitted(), { "Poti garrison" })
  veafCampaign.updateDormancy(110)
  luaunit.assertEquals(groupsSubmitted(), { "Poti garrison", "Senaki garrison" })
end

function TestCampaignDormancy:test_the_cap_keeps_the_nearest_zones_awake()
  veafCampaign.data = persistentData({ wake_radius = 200000, max_awake_zones = 2 })
  veafCampaign.initialize()
  playersAt({ { x = 0 } }) -- Kobuleti, Senaki, Poti, Zugdidi
  for pass = 1, 4 do
    veafCampaign.updateDormancy(100 + pass)
  end
  luaunit.assertTrue(veafCampaign.zones["Kobuleti"].awake)
  luaunit.assertTrue(veafCampaign.zones["Senaki"].awake)
  luaunit.assertFalse(veafCampaign.zones["Poti"].awake)
  -- the player moves east: Poti is nearer than Kobuleti, which gives its place
  playersAt({ { x = 90000 } })
  veafCampaign.updateDormancy(200)
  luaunit.assertTrue(veafCampaign.zones["Poti"].awake)
  luaunit.assertFalse(veafCampaign.zones["Kobuleti"].awake)
end

function TestCampaignDormancy:test_a_zone_sleeps_once_nobody_has_been_near_for_the_delay()
  veafCampaign.data = persistentData({ sleep_seconds = 600 })
  veafCampaign.initialize()
  dcs_mocks.addGroup("Senaki garrison", {})
  local destroyed = false
  Group.getByName("Senaki garrison").destroy = function()
    destroyed = true
  end
  playersAt({ { x = 50000 } })
  veafCampaign.updateDormancy(100)
  playersAt({})
  veafCampaign.updateDormancy(650)
  luaunit.assertTrue(veafCampaign.zones["Senaki"].awake)
  luaunit.assertFalse(destroyed)
  veafCampaign.updateDormancy(700)
  luaunit.assertFalse(veafCampaign.zones["Senaki"].awake)
  luaunit.assertTrue(destroyed)
end

function TestCampaignDormancy:test_a_sleep_is_not_a_loss_and_losses_survive_it()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  local senaki = veafCampaign.zones["Senaki"]
  playersAt({ { x = 50000 } })
  veafCampaign.updateDormancy(100)
  veafCampaign.onUnitDead({ initiator = { unitName = "Senaki garrison #2" } })
  senaki:sleep()
  -- whatever DCS says of the units removed by the sleep is not a loss
  veafCampaign.onUnitDead({ initiator = { unitName = "Senaki garrison #1" } })
  luaunit.assertEquals({ senaki:countUnits() }, { 2, 3 })
  dcs_mocks.groupsAdded = {}
  senaki:wake()
  luaunit.assertEquals(#dcs_mocks.groupsAdded[1].group.units, 2)
end

function TestCampaignDormancy:test_the_target_of_a_sortie_stays_awake()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  dcs_mocks.currentTime = 100
  veafCampaign.keepAwake(veafCampaign.zones["Zugdidi"], 600)
  veafCampaign.updateDormancy(100)
  luaunit.assertTrue(veafCampaign.zones["Zugdidi"].awake)
end

function TestCampaignDormancy:test_an_episodic_campaign_has_no_dormancy_unless_asked()
  local data = persistentData()
  data.persistent = nil
  veafCampaign.data = data
  veafCampaign.initialize()
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 4)
end

-- ---------------------------------------------------------------------------
-- Reinforcement
-- ---------------------------------------------------------------------------
TestCampaignReinforce = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignReinforce:test_the_first_damaged_group_gets_its_dead_back_in_their_places()
  local data = persistentData()
  data.zones[2].garrison = garrison("Senaki", { 1, 3 })
  veafCampaign.data = data
  veafCampaign.initialize()
  local senaki = veafCampaign.zones["Senaki"]
  senaki.awake = true
  luaunit.assertTrue(senaki:reinforce())
  luaunit.assertEquals({ senaki:countUnits() }, { 3, 3 })
  local units = dcs_mocks.groupsAdded[1].group.units
  luaunit.assertEquals(#units, 3)
  luaunit.assertEquals({ units[1].x, units[1].y }, { 10, 20 })
end

function TestCampaignReinforce:test_a_sleeping_zone_is_reinforced_in_its_record_only()
  local data = persistentData()
  data.zones[2].garrison = garrison("Senaki", { 1 })
  veafCampaign.data = data
  veafCampaign.initialize()
  luaunit.assertTrue(veafCampaign.zones["Senaki"]:reinforce())
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
  luaunit.assertEquals(veafCampaign.zones["Senaki"]:strengthPercent(), 100)
end

function TestCampaignReinforce:test_a_zone_with_nothing_missing_is_not_reinforced()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertFalse(veafCampaign.zones["Senaki"]:reinforce())
end

function TestCampaignReinforce:test_a_delivery_to_the_other_side_s_zone_does_nothing()
  local data = persistentData()
  data.zones[2].garrison = garrison("Senaki", { 1 })
  veafCampaign.data = data
  veafCampaign.initialize()
  luaunit.assertFalse(veafCampaign.deliver(veafCampaign.zones["Senaki"], "blue", "crate"))
  luaunit.assertTrue(veafCampaign.deliver(veafCampaign.zones["Senaki"], "red", "crate"))
end

-- ---------------------------------------------------------------------------
-- Counter-attacks
-- ---------------------------------------------------------------------------
TestCampaignOffensives = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignOffensives:setUp()
  setUpSuite(self)
  self.sent = {}
  local this = self
  veafCampaign.sendConvoy = function(side, from, to)
    table.insert(this.sent, { side = side, from = from.name, to = to.name })
    local record = { side = side, from = from.name, to = to.name }
    table.insert(veafCampaign.convoys, record)
    return record
  end
end

function TestCampaignOffensives:test_the_target_is_the_weakest_enemy_zone_bordering_the_side()
  local data = persistentData()
  -- blue holds Kobuleti and Poti; Senaki (between them) is red at full strength, Zugdidi red and damaged
  data.zones[3].owner = "blue"
  data.zones[4].garrison = garrison("Zugdidi", { 1 })
  veafCampaign.data = data
  veafCampaign.initialize()
  local target, from = veafCampaign.attackTarget("blue")
  luaunit.assertEquals({ target.name, from.name }, { "Zugdidi", "Poti" })
  target = veafCampaign.attackTarget("red")
  luaunit.assertEquals(target.name, "Kobuleti")
end

function TestCampaignOffensives:test_red_attacks_on_its_cadence_and_blue_does_not_by_default()
  veafCampaign.data = persistentData({ attack_seconds = 900 })
  veafCampaign.initialize()
  veafCampaign.launchOffensives(0) -- arms the clock
  veafCampaign.launchOffensives(899)
  luaunit.assertEquals(#self.sent, 0)
  veafCampaign.launchOffensives(900)
  luaunit.assertEquals(self.sent, { { side = "red", from = "Senaki", to = "Kobuleti" } })
end

function TestCampaignOffensives:test_no_more_convoys_than_the_cap()
  veafCampaign.data = persistentData({ attack_seconds = 10, max_convoys = 1 })
  veafCampaign.initialize()
  veafCampaign.launchOffensives(0)
  veafCampaign.launchOffensives(10)
  veafCampaign.launchOffensives(20)
  luaunit.assertEquals(#self.sent, 1)
end

function TestCampaignOffensives:test_a_campaign_over_sends_nothing()
  veafCampaign.data = persistentData({ attack_seconds = 10 })
  veafCampaign.initialize()
  veafCampaign.launchOffensives(0)
  veafCampaign.over = "victory"
  veafCampaign.launchOffensives(10)
  luaunit.assertEquals(#self.sent, 0)
end

-- ---------------------------------------------------------------------------
-- Deliveries by players: CTLD 2 crates and troops
-- ---------------------------------------------------------------------------
TestCampaignDeliveries = { setUp = setUpSuite, tearDown = tearDownSuite }

local function staticAt(name)
  return {
    -- the mock search walks one list for both categories: a static found as a unit is not ground
    getDesc = function()
      return { category = -1 }
    end,
    getCoalition = function()
      return BLUE
    end,
    getName = function()
      return name
    end,
    getLife = function()
      return 1
    end,
  }
end

local function troopUnit(groupName)
  return {
    getCoalition = function()
      return BLUE
    end,
    getName = function()
      return groupName .. "-1"
    end,
    getLife = function()
      return 1
    end,
    isActive = function()
      return true
    end,
    getDesc = function()
      return { category = Unit.Category.GROUND_UNIT }
    end,
    getGroup = function()
      return {
        getName = function()
          return groupName
        end,
      }
    end,
  }
end

function TestCampaignDeliveries:setUp()
  setUpSuite(self)
  local data = persistentData()
  data.zones[1].garrison = garrison("Kobuleti", { 2 })
  veafCampaign.data = data
  veafCampaign.initialize()
  self.destroyedCrates = {}
  local this = self
  local manager = {
    crates = {
      ["crate 1"] = { descriptor = { desc = "Zone supplies" } },
      ["crate 2"] = { descriptor = { desc = "Humvee - MG" } },
    },
    destroyCrate = function(_, name)
      table.insert(this.destroyedCrates, name)
    end,
  }
  CTLDCrateManager = {
    getInstance = function()
      return manager
    end,
  }
  local troops = { _droppedTemplates = { ["Rifle squad-12"] = "Rifle squad", ["Spy-13"] = "Spy" } }
  troops._removeFromDropped = function() end
  CTLDTroopManager = {
    getInstance = function()
      return troops
    end,
  }
end

function TestCampaignDeliveries:test_a_zone_supplies_crate_reinforces_and_is_consumed()
  dcs_mocks.searchObjectsObjects = { staticAt("crate 1") }
  luaunit.assertTrue(veafCampaign.collectDeliveries(veafCampaign.zones["Kobuleti"]))
  luaunit.assertEquals(veafCampaign.zones["Kobuleti"]:strengthPercent(), 100)
  luaunit.assertEquals(self.destroyedCrates, { "crate 1" })
end

function TestCampaignDeliveries:test_a_crate_of_another_kind_is_left_alone()
  dcs_mocks.searchObjectsObjects = { staticAt("crate 2") }
  luaunit.assertFalse(veafCampaign.collectDeliveries(veafCampaign.zones["Kobuleti"]))
  luaunit.assertEquals(self.destroyedCrates, {})
end

function TestCampaignDeliveries:test_ctld_troops_in_a_damaged_friendly_zone_are_a_delivery()
  dcs_mocks.searchObjectsObjects = { troopUnit("Rifle squad-12") }
  luaunit.assertTrue(veafCampaign.collectDeliveries(veafCampaign.zones["Kobuleti"]))
  luaunit.assertEquals(veafCampaign.zones["Kobuleti"]:strengthPercent(), 100)
end

function TestCampaignDeliveries:test_a_spy_team_is_not_a_delivery()
  dcs_mocks.searchObjectsObjects = { troopUnit("Spy-13") }
  luaunit.assertFalse(veafCampaign.collectDeliveries(veafCampaign.zones["Kobuleti"]))
end

function TestCampaignDeliveries:test_a_zone_with_nothing_missing_takes_no_delivery()
  veafCampaign.zones["Kobuleti"]:reinforce()
  dcs_mocks.searchObjectsObjects = { staticAt("crate 1") }
  luaunit.assertFalse(veafCampaign.collectDeliveries(veafCampaign.zones["Kobuleti"]))
  luaunit.assertEquals(self.destroyedCrates, {})
end

function TestCampaignDeliveries:test_a_delivery_is_told_to_the_listeners()
  local heard = {}
  veafCampaign.listen("delivered", function(zone, side, how)
    table.insert(heard, { zone.name, side, how })
  end)
  dcs_mocks.searchObjectsObjects = { staticAt("crate 1") }
  veafCampaign.collectDeliveries(veafCampaign.zones["Kobuleti"])
  luaunit.assertEquals(heard, { { "Kobuleti", "blue", "crate" } })
end

os.exit(luaunit.LuaUnit.run())
