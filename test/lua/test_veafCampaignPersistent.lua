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

--- Players' aircraft where the list says, as coalition.getPlayers hands them over: blue unless `side` says.
local function playersAt(points, side)
  coalition.getPlayers = function(asked)
    if asked ~= (side or BLUE) then
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

--- Groups in the world as coalition.getGroups hands them over: `{ name, category, x, inAir, unit }`, blue
--- side, one unit each (named `unit`, else `<name> #1`).
local function worldGroups(groups)
  coalition.getGroups = function(side, category)
    local found = {}
    for _, spec in ipairs(side == BLUE and groups or {}) do
      if spec.category == category then
        local unit = {
          isExist = function()
            return true
          end,
          inAir = function()
            return spec.inAir == true
          end,
          isActive = function()
            return spec.active ~= false
          end,
          getName = function()
            return spec.unit or (spec.name .. " #1")
          end,
          getPoint = function()
            return { x = spec.x, y = 0, z = 0 }
          end,
        }
        table.insert(found, {
          getName = function()
            return spec.name
          end,
          getUnits = function()
            return { unit }
          end,
        })
      end
    end
    return found
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
    getGroups = coalition.getGroups,
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
  coalition.getGroups = self.saved.getGroups
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
-- The campaign alone owns the airfields (ticket 20, point 15)
-- ---------------------------------------------------------------------------
TestCampaignAirfields = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignAirfields:test_dcs_captures_no_airfield_of_a_persistent_campaign()
  -- 2026-11-16: Minakh's airfield, 2.3 km from the neutral zone Menagh, went blue on its own as a blue
  -- convoy drove past, while the zone followed its own rule
  local calls = {}
  local function airbase(name, category)
    return {
      getName = function()
        return name
      end,
      getDesc = function()
        return { category = category }
      end,
      autoCapture = function(_, enabled)
        table.insert(calls, { name, enabled })
      end,
    }
  end
  local saved = world.getAirbases
  world.getAirbases = function()
    return { airbase("Minakh", Airbase.Category.AIRDROME), airbase("a FARP", Airbase.Category.HELIPAD) }
  end
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  world.getAirbases = saved
  luaunit.assertEquals(calls, { { "Minakh", false } })
end

-- ---------------------------------------------------------------------------
-- A zone's waypoint number, everywhere it is named (ticket 20, point 11)
-- ---------------------------------------------------------------------------
TestCampaignZoneTitle = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignZoneTitle:test_a_zone_with_a_waypoint_is_named_with_its_number()
  local data = persistentData()
  data.zones[2].waypoint = 7
  veafCampaign.data = data
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.zoneTitle("Senaki"), "Senaki (WP 7)")
  luaunit.assertEquals(veafCampaign.zoneTitle("Kobuleti"), "Kobuleti")
  luaunit.assertStrContains(veafCampaign.zones["Senaki"]:mapLabel(), "Senaki (WP 7)")
  luaunit.assertStrContains(veafCampaign.situationText(), "Senaki (WP 7)")
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

function TestCampaignSave:test_a_zone_remembers_its_air_defence_reach_across_the_reload()
  -- measured while it was awake: a sleeping zone wakes at its true reach, not an assumed one
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  veafCampaign.zones["Poti"].entry.reach = 75000
  veafCampaign.writeState()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.zones["Poti"].entry.reach, 75000)
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

function TestCampaignSave:test_a_save_cut_short_falls_back_on_its_temporary()
  -- no `os` on the VEAF servers: the complete temporary is written first, then the file (#1146)
  self.files[SAVE .. ".tmp"] = 'return {campaign="Caucasus Front",format_version=1,zones={Senaki={owner="neutral"}}}'
  self.files[SAVE] = 'return {campaign="Caucasus Fr'
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.loadResult, "loaded")
  luaunit.assertEquals(veafCampaign.zones["Senaki"].entry.owner, "neutral")
end

function TestCampaignSave:test_a_convoy_cut_short_by_a_restart_goes_back_to_the_reserve()
  self.files[SAVE] = 'return {campaign="Caucasus Front",format_version=1,zones={},'
    .. 'sides={red={reserve={armor=1}}},convoys={{side="red",alive={"T-72B","T-72B"}}}}'
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.reserveOf("red").armor, 3)
end

function TestCampaignSave:test_a_convoy_never_takes_the_name_of_a_sleeping_garrison()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  -- Senaki's garrison is asleep: not in the world, but its name is taken
  luaunit.assertEquals(veafCampaign.uniqueConvoyName("Senaki garrison"), "Senaki garrison 2")
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

-- Kobuleti (blue, x=0) and Senaki (red, 50 km) are the front; Poti (red, 100 km) and Zugdidi (red, 150 km)
-- the rear. Players and groups are blue: the enemies of every zone but Kobuleti.

--- Run dormancy passes from `from`, one second apart.
local function passes(count, from)
  for pass = 0, count - 1 do
    veafCampaign.updateDormancy((from or 100) + pass)
  end
end

local function awakeZones()
  local names = {}
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.awake then
      table.insert(names, zone.name)
    end
  end
  return names
end

function TestCampaignDormancy:test_a_persistent_campaign_starts_with_every_zone_asleep()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

function TestCampaignDormancy:test_the_front_is_always_awake_the_rear_asleep_with_nobody_near()
  -- David, 2026-11-16: every zone near the front stays awake
  veafCampaign.data = persistentData({ sleep_seconds = 60 })
  veafCampaign.initialize()
  passes(4)
  passes(1, 1000)
  luaunit.assertEquals(awakeZones(), { "Kobuleti", "Senaki" })
end

function TestCampaignDormancy:test_the_front_is_the_line_drawn_not_the_connections()
  -- David, 2026-11-16: a zone just behind the line, connected or not, must not be empty when the enemy
  -- goes round. The line between Kobuleti (0) and Senaki (50 km) runs at 25 km.
  local data = persistentData({ front_depth = 80000 })
  data.connections = {}
  veafCampaign.data = data
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.frontDistance(veafCampaign.zones["Poti"]), 75000)
  passes(4)
  luaunit.assertEquals(awakeZones(), { "Kobuleti", "Senaki", "Poti" }) -- Zugdidi is 125 km from it
end

function TestCampaignDormancy:test_a_zone_connected_to_an_enemy_zone_is_on_the_front_however_far_the_line()
  -- a sparse map: the line between Kobuleti and Senaki runs 25 km from each, beyond a 20 km depth
  veafCampaign.data = persistentData({ front_depth = 20000 })
  veafCampaign.initialize()
  passes(4)
  luaunit.assertEquals(awakeZones(), { "Kobuleti", "Senaki" })
end

function TestCampaignDormancy:test_the_front_line_moves_with_a_capture()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.frontDistance(veafCampaign.zones["Poti"]), 75000)
  veafCampaign.zones["Senaki"].entry.owner = "blue"
  luaunit.assertEquals(veafCampaign.frontDistance(veafCampaign.zones["Poti"]), 25000)
end

function TestCampaignDormancy:test_an_enemy_player_near_wakes_a_rear_zone()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  playersAt({ { x = 102000 } }) -- 2 km from Poti
  passes(3)
  luaunit.assertEquals(awakeZones(), { "Kobuleti", "Senaki", "Poti" })
end

function TestCampaignDormancy:test_a_friendly_player_wakes_nothing()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  playersAt({ { x = 102000 } }, RED)
  passes(4)
  luaunit.assertFalse(veafCampaign.zones["Poti"].awake)
end

function TestCampaignDormancy:test_an_enemy_ai_aircraft_in_the_air_wakes_within_the_defence_reach_and_margin()
  -- no veafCampaignOps here: a reach of 0, so the 20 km margin alone
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  worldGroups({ { name = "cap", category = Group.Category.AIRPLANE, x = 125000, inAir = true } }) -- 25 km
  passes(4)
  luaunit.assertFalse(veafCampaign.zones["Poti"].awake)
  worldGroups({ { name = "parked", category = Group.Category.AIRPLANE, x = 115000, inAir = false } })
  passes(4, 200)
  luaunit.assertFalse(veafCampaign.zones["Poti"].awake)
  worldGroups({ { name = "cap", category = Group.Category.HELICOPTER, x = 115000, inAir = true } }) -- 15 km
  passes(1, 300)
  luaunit.assertTrue(veafCampaign.zones["Poti"].awake)
end

function TestCampaignDormancy:test_a_long_range_defence_wakes_farther_out()
  -- a SAM reaching 75 km: an enemy at 90 km is within its reach and the 20 km margin
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  local zoneReach = veafCampaign.zoneReach
  veafCampaign.zoneReach = function(zone)
    return zone.name == "Poti" and 75000 or 0
  end
  worldGroups({ { name = "cap", category = Group.Category.AIRPLANE, x = 190000, inAir = true } })
  passes(4)
  veafCampaign.zoneReach = zoneReach
  luaunit.assertTrue(veafCampaign.zones["Poti"].awake)
  luaunit.assertFalse(veafCampaign.zones["Zugdidi"].awake) -- 40 km, beyond its 0 + 20 km
end

function TestCampaignDormancy:test_a_late_activated_aircraft_wakes_nothing()
  -- DCS answers isExist() and inAir() true for a group not yet activated (dcs-runtime-traps.md)
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  worldGroups({ { name = "qra", category = Group.Category.AIRPLANE, x = 102000, inAir = true, active = false } })
  passes(4)
  luaunit.assertFalse(veafCampaign.zones["Poti"].awake)
end

function TestCampaignDormancy:test_an_enemy_convoy_wakes_a_zone_within_the_ground_radius()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  worldGroups({})
  passes(1, 90) -- the mission as built: nothing on the ground
  worldGroups({ { name = "convoy", category = Group.Category.GROUND, x = 111000 } }) -- 11 km from Poti
  passes(4)
  luaunit.assertFalse(veafCampaign.zones["Poti"].awake)
  worldGroups({ { name = "convoy", category = Group.Category.GROUND, x = 109000 } }) -- 9 km
  passes(1, 200)
  luaunit.assertTrue(veafCampaign.zones["Poti"].awake)
end

function TestCampaignDormancy:test_a_garrison_does_not_wake_its_neighbour()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  worldGroups({})
  passes(1, 90)
  veafCampaign.unitIndex["Kobuleti garrison #1"] = veafCampaign.zones["Kobuleti"]
  worldGroups({ { name = "Kobuleti garrison", category = Group.Category.GROUND, x = 102000 } })
  passes(4)
  luaunit.assertFalse(veafCampaign.zones["Poti"].awake)
end

function TestCampaignDormancy:test_a_ground_group_the_mission_was_built_with_wakes_nothing()
  local parked = { { name = "fuel truck", category = Group.Category.GROUND, x = 102000 } }
  worldGroups(parked)
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  passes(4)
  luaunit.assertFalse(veafCampaign.zones["Poti"].awake)
  -- a group spawned later, at the same place, does
  table.insert(parked, { name = "troops", category = Group.Category.GROUND, x = 102000 })
  passes(1, 200)
  luaunit.assertTrue(veafCampaign.zones["Poti"].awake)
end

function TestCampaignDormancy:test_a_ground_group_spawned_just_after_initialize_counts_as_built()
  -- the FARPs' vehicles (veafGrass) come 2 s after the module initializes
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  worldGroups({ { name = "FARP vehicles", category = Group.Category.GROUND, x = 102000 } })
  passes(4)
  luaunit.assertFalse(veafCampaign.zones["Poti"].awake)
end

function TestCampaignDormancy:test_a_rear_zone_sleeps_once_nobody_has_been_near_for_the_delay()
  veafCampaign.data = persistentData({ sleep_seconds = 600 })
  veafCampaign.initialize()
  playersAt({ { x = 100000 } })
  passes(3)
  luaunit.assertTrue(veafCampaign.zones["Poti"].awake)
  playersAt({})
  passes(1, 650)
  luaunit.assertTrue(veafCampaign.zones["Poti"].awake)
  passes(1, 710)
  luaunit.assertFalse(veafCampaign.zones["Poti"].awake)
  luaunit.assertTrue(veafCampaign.zones["Senaki"].awake) -- the front never sleeps
end

function TestCampaignDormancy:test_a_sleep_is_not_a_loss_and_losses_survive_it()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  local poti = veafCampaign.zones["Poti"]
  playersAt({ { x = 100000 } })
  passes(3)
  veafCampaign.onUnitDead({ initiator = { unitName = "Poti garrison #2" } })
  poti:sleep()
  -- whatever DCS says of the units removed by the sleep is not a loss
  veafCampaign.onUnitDead({ initiator = { unitName = "Poti garrison #1" } })
  luaunit.assertEquals({ poti:countUnits() }, { 2, 3 })
  dcs_mocks.groupsAdded = {}
  poti:wake()
  luaunit.assertEquals(#dcs_mocks.groupsAdded[1].group.units, 2)
end

function TestCampaignDormancy:test_the_target_of_a_sortie_wakes_even_when_the_rear_is_full()
  veafCampaign.data = persistentData({ max_awake_zones = 1 })
  veafCampaign.initialize()
  playersAt({ { x = 100000 } })
  passes(3)
  luaunit.assertTrue(veafCampaign.zones["Poti"].awake)
  dcs_mocks.currentTime = 200
  veafCampaign.keepAwake(veafCampaign.zones["Zugdidi"], 600)
  passes(1, 200)
  luaunit.assertTrue(veafCampaign.zones["Zugdidi"].awake)
  luaunit.assertTrue(veafCampaign.zones["Poti"].awake)
end

function TestCampaignDormancy:test_zones_wanted_by_ai_do_not_swap_when_the_rear_is_full()
  -- measured 2026-11-16: moving aircraft swapped two zones at every pass, 27 wakes in 3 minutes
  -- a 40 km margin: both rear zones are within reach of an aircraft between them
  veafCampaign.data = persistentData({ max_awake_zones = 1, reach_wake_margin = 40000, wake_radius = 30000 })
  veafCampaign.initialize()
  worldGroups({ { name = "cap", category = Group.Category.AIRPLANE, x = 115000, inAir = true } })
  passes(3)
  luaunit.assertTrue(veafCampaign.zones["Poti"].awake)
  -- nearer Zugdidi now, still within Poti's reach: Poti keeps its place
  worldGroups({ { name = "cap", category = Group.Category.AIRPLANE, x = 135000, inAir = true } })
  passes(5, 200)
  luaunit.assertTrue(veafCampaign.zones["Poti"].awake)
  luaunit.assertFalse(veafCampaign.zones["Zugdidi"].awake)
  -- a player wants Zugdidi: it takes the place of the zone only AI wanted
  playersAt({ { x = 150000 } })
  passes(1, 300)
  luaunit.assertTrue(veafCampaign.zones["Zugdidi"].awake)
  luaunit.assertFalse(veafCampaign.zones["Poti"].awake)
end

function TestCampaignDormancy:test_between_players_the_nearer_zone_takes_the_place()
  veafCampaign.data = persistentData({ wake_radius = 200000, max_awake_zones = 1 })
  veafCampaign.initialize()
  playersAt({ { x = 100000 } })
  passes(3)
  luaunit.assertTrue(veafCampaign.zones["Poti"].awake)
  playersAt({ { x = 150000 } })
  passes(1, 200)
  luaunit.assertTrue(veafCampaign.zones["Zugdidi"].awake)
  luaunit.assertFalse(veafCampaign.zones["Poti"].awake)
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

function TestCampaignOffensives:test_only_the_attacking_sides_send_convoys_to_a_neutral_zone()
  -- 2026-11-16: blue's AI sent a free convoy to Menagh three minutes after the players paid for the same assault
  local data = persistentData()
  data.zones[2].owner, data.zones[2].garrison = "neutral", nil -- Senaki, between blue Kobuleti and red Poti
  veafCampaign.data = data
  veafCampaign.initialize()
  luaunit.assertNotNil(veafCampaign.pendingAssaults["Senaki|red"])
  luaunit.assertNil(veafCampaign.pendingAssaults["Senaki|blue"])
end

function TestCampaignOffensives:test_a_due_assault_is_not_sent_where_a_convoy_of_its_side_already_drives()
  local data = persistentData()
  data.zones[2].owner, data.zones[2].garrison = "neutral", nil
  veafCampaign.data = data
  veafCampaign.initialize()
  table.insert(veafCampaign.convoys, { side = "red", from = "Poti", to = "Senaki" }) -- sent meanwhile
  veafCampaign.launchDueAssaults(1000000)
  luaunit.assertEquals(#self.sent, 0)
end

TestCampaignConvoyGoal = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignConvoyGoal:test_a_convoy_whose_target_is_its_side_s_frees_its_place()
  -- 2026-11-16: two red convoys held both places of max_convoys for an hour, their targets taken by helicopter
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  local record = { name = "Senaki - Kobuleti assault", side = "red", from = "Senaki", to = "Kobuleti", sentAt = 0 }
  table.insert(veafCampaign.convoys, record)
  veafCampaign.checkConvoyGoal(record, 10)
  luaunit.assertNil(record.ended)
  veafCampaign.zones["Kobuleti"].entry.owner = "red"
  veafCampaign.checkConvoyGoal(record, 20)
  luaunit.assertTrue(record.ended)
  luaunit.assertEquals(veafCampaign.convoysUnderway("red"), 0)
end

-- review of PR #1293: a retired convoy gave its points back but not its units, so each one emptied the reserve the
-- counter-attacks draw from; as a restart does (applySave), its survivors go back to the reserve, bought or not
function TestCampaignConvoyGoal:test_a_retired_convoy_gives_its_survivors_back_to_the_reserve()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  veafCampaign.data.sides = veafCampaign.data.sides or {}
  veafCampaign.data.sides.red = veafCampaign.data.sides.red or {}
  veafCampaign.data.sides.red.reserve = {}
  local savedUnits, savedLogistics = veafCampaign.convoyUnits, veafCampaignLogistics
  local credited = {}
  veafCampaignLogistics = {
    active = true,
    credit = function(side, points)
      table.insert(credited, { side = side, points = points })
    end,
  }
  veafCampaign.convoyUnits = function()
    local function unit(typeName)
      return {
        getTypeName = function()
          return typeName
        end,
      }
    end
    return { unit("T-72B"), unit("T-72B") }
  end
  for _, purchased in ipairs({ false, true }) do
    local record = { name = "Poti assault", side = "red", from = "Poti", to = "Kobuleti", purchased = purchased or nil }
    veafCampaign.retireConvoy(record, "test")
  end
  veafCampaign.convoyUnits, veafCampaignLogistics = savedUnits, savedLogistics
  local reserve = veafCampaign.reserveOf("red")
  local category = veafCampaign.reserveCategory("T-72B")
  luaunit.assertEquals(reserve[category], 4, "two survivors back from each convoy")
  luaunit.assertEquals(#credited, 2, "their price too, bought or not")
  luaunit.assertEquals(credited[2].points, veafCampaign.unitsPrice({ "T-72B", "T-72B" }))
end

function TestCampaignConvoyGoal:test_a_convoy_on_the_road_too_long_frees_its_place()
  veafCampaign.data = persistentData({ convoy_timeout = 600 })
  veafCampaign.initialize()
  local record = { name = "Senaki - Kobuleti assault", side = "red", from = "Senaki", to = "Kobuleti", sentAt = 100 }
  table.insert(veafCampaign.convoys, record)
  veafCampaign.checkConvoyGoal(record, 699)
  luaunit.assertNil(record.ended)
  veafCampaign.checkConvoyGoal(record, 700)
  luaunit.assertTrue(record.ended)
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
  -- the shape CTLD 2 stores (`CTLD.lua`, CTLDTroopManager): a table per dropped group, not a name
  local troops = {
    _droppedTemplates = {
      ["Rifle squad-12"] = { key = "rifle", name = "Rifle squad" },
      ["Spy-13"] = { key = "spy", name = "Spy" },
      ["JTAC Group-14"] = { key = "jtac", name = "JTAC Group" },
    },
  }
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

function TestCampaignDeliveries:test_a_jtac_team_is_not_a_delivery()
  dcs_mocks.searchObjectsObjects = { troopUnit("JTAC Group-14") }
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

-- ---------------------------------------------------------------------------
-- Self-check
-- ---------------------------------------------------------------------------
TestCampaignSelfCheck = { setUp = setUpSuite, tearDown = tearDownSuite }

function TestCampaignSelfCheck:test_a_healthy_campaign_reads_all_ok()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  veafCampaign.writeState()
  local text = veafCampaign.selfCheckText()
  luaunit.assertStrContains(text, "OK  zones placed: 4 of 4")
  luaunit.assertStrContains(text, "OK  load: fresh")
  luaunit.assertStrContains(text, "OK  save: 1 write(s), last one succeeded: true")
  luaunit.assertNotStrContains(text, "KO")
end

function TestCampaignSelfCheck:test_a_zone_that_cannot_be_placed_and_a_save_that_cannot_be_written_read_ko()
  memoryFileSystem(self, { sanitized = true })
  local data = persistentData()
  data.zones[4].x, data.zones[4].z = nil, nil
  veafCampaign.data = data
  veafCampaign.initialize()
  veafCampaign.writeState()
  local text = veafCampaign.selfCheckText()
  luaunit.assertStrContains(text, "KO  zones placed: 3 of 4 Zugdidi")
  luaunit.assertStrContains(text, "KO  load: no-io")
  luaunit.assertStrContains(text, "KO  save: 0 write(s)")
end

function TestCampaignSelfCheck:test_other_modules_add_their_lines()
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  table.insert(veafCampaign.selfChecks, function(verdict)
    return { verdict(false, "campaign.check.outcome", "economy") }
  end)
  luaunit.assertStrContains(veafCampaign.selfCheckText(), "KO  outcome: economy")
  table.remove(veafCampaign.selfChecks)
end

os.exit(luaunit.LuaUnit.run())
