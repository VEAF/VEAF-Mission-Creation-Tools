--- Tests for veafCampaign.lua's `sitac` block (FEAT-CAMPAIGN-SITAC-STATE): what the state file carries for a web
--- map outside DCS, and that the reload ignores it.
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

--- A recorded garrison of one group of three units, `dead` of them destroyed.
local function garrison(name, dead)
  local units = {
    { type = "T-72B", x = 10, z = 20, heading = 1, alive = true },
    { type = "BMP-2", x = 11, z = 21, heading = 2, alive = true },
    { type = "Ural-375", x = 12, z = 22, heading = 3, alive = true },
  }
  for index = 1, dead or 0 do
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

--- A persistent campaign: an airfield, a factory, a neutral outpost and a depot, in a row.
local function persistentData()
  return {
    format_version = 1,
    campaign = "Bouclier de l'Oronte",
    mission = 1,
    persistent = true,
    player_side = "blue",
    dynamic = {},
    zones = {
      zone("Minakh", "blue", 0, { airbase = "Minakh", waypoint = 3 }),
      zone("Kafr Naya", "red", 50000, {
        kind = "factory",
        structures = {
          { type = "Workshop A", x = 50000, z = 0, heading = 0, alive = true },
          { type = "Workshop A", x = 50060, z = 0, heading = 0, alive = false },
        },
      }),
      zone("Tal Rifaat", "neutral", 100000, { capture = { side = "blue", seconds = 42 } }),
      zone("Anadan", "red", 150000, { kind = "depot" }),
    },
    connections = { { "Minakh", "Kafr Naya" }, { "Kafr Naya", "Tal Rifaat" }, { "Tal Rifaat", "Anadan" } },
    sides = {},
  }
end

--- A file system in memory that reads back what it was given.
local function memoryFileSystem(self)
  self.files = {}
  local files = self.files
  local fsIo = {
    open = function(path, mode)
      if mode == "r" then
        local content = files[path]
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

-- the apostrophe is not a folder character: `stateFolder` makes it an underscore
local SAVE = "C:\\Saved Games\\DCS\\Missions\\Saves\\Bouclier de l_Oronte\\persistent.state"

--- The block's zone of that name.
local function sitacZone(sitac, name)
  for _, entry in ipairs(sitac.zones) do
    if entry.name == name then
      return entry
    end
  end
  return nil
end

TestCampaignSitac = {}

function TestCampaignSitac:setUp()
  dcs_mocks.reset()
  self.saved = {
    fileSystem = veafCampaign.fileSystem,
    callbacks = veafEventHandler.callbacks,
    surface = land.getSurfaceType,
    LOtoLL = coord.LOtoLL,
    mission = env.mission,
    economy = veafCampaignEconomy,
    logistics = veafCampaignLogistics,
  }
  veafEventHandler.callbacks = {}
  land.getSurfaceType = function()
    return land.SurfaceType.LAND
  end
  -- one degree of latitude per 100 km north, of longitude per 100 km east, from 36N 37E
  coord.LOtoLL = function(point)
    return 36 + point.x / 100000, 37 + point.z / 100000, 0
  end
  env.mission = { theatre = "Syria" }
  veafCampaignEconomy, veafCampaignLogistics = nil, nil
  memoryFileSystem(self)
  veafCampaign.listeners = {}
  veafCampaign.saveParts = {}
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
end

function TestCampaignSitac:tearDown()
  veafCampaign.fileSystem = self.saved.fileSystem
  veafEventHandler.callbacks = self.saved.callbacks
  land.getSurfaceType = self.saved.surface
  coord.LOtoLL = self.saved.LOtoLL
  env.mission = self.saved.mission
  veafCampaignEconomy, veafCampaignLogistics = self.saved.economy, self.saved.logistics
  veafCampaign.data = nil
  veafCampaign.listeners = {}
  veafCampaign.saveParts = {}
  veafCampaign.convoys = {}
end

function TestCampaignSitac:test_the_block_names_the_theatre_the_campaign_and_the_time()
  dcs_mocks.currentTime = 1234
  local sitac = veafCampaign.stateTable().sitac
  luaunit.assertEquals(sitac.theatre, "Syria")
  luaunit.assertEquals(sitac.campaign, "Bouclier de l'Oronte")
  luaunit.assertEquals(sitac.updated, 1234)
end

function TestCampaignSitac:test_the_zones_come_in_the_campaign_order_with_their_position()
  local sitac = veafCampaign.stateTable().sitac
  local names = {}
  for _, entry in ipairs(sitac.zones) do
    table.insert(names, entry.name)
  end
  luaunit.assertEquals(names, { "Minakh", "Kafr Naya", "Tal Rifaat", "Anadan" })
  local factory = sitacZone(sitac, "Kafr Naya")
  luaunit.assertAlmostEquals(factory.lat, 36.5, 1e-9)
  luaunit.assertAlmostEquals(factory.lon, 37, 1e-9)
end

function TestCampaignSitac:test_each_zone_has_its_kind()
  local sitac = veafCampaign.stateTable().sitac
  luaunit.assertEquals(sitacZone(sitac, "Minakh").kind, "airfield")
  luaunit.assertEquals(sitacZone(sitac, "Kafr Naya").kind, "factory")
  luaunit.assertEquals(sitacZone(sitac, "Tal Rifaat").kind, "outpost")
  luaunit.assertEquals(sitacZone(sitac, "Anadan").kind, "depot")
end

function TestCampaignSitac:test_a_zone_carries_its_waypoint_and_owner()
  local sitac = veafCampaign.stateTable().sitac
  luaunit.assertEquals(sitacZone(sitac, "Minakh").waypoint, 3)
  luaunit.assertNil(sitacZone(sitac, "Anadan").waypoint)
  luaunit.assertEquals(sitacZone(sitac, "Minakh").owner, "blue")
  luaunit.assertEquals(sitacZone(sitac, "Tal Rifaat").owner, "neutral")
end

function TestCampaignSitac:test_the_garrison_is_counted_never_listed()
  veafCampaign.zones["Anadan"].entry.garrison = garrison("Anadan", 2)
  local entry = sitacZone(veafCampaign.stateTable().sitac, "Anadan")
  luaunit.assertEquals(entry.garrison, { alive = 1, total = 3 })
  -- the composition is what the intelligence rule hides: no unit type anywhere in the zone's entry
  luaunit.assertNotStrContains(veafCampaign.serialize(entry), "T-72B")
  luaunit.assertNil(sitacZone(veafCampaign.stateTable().sitac, "Tal Rifaat").garrison)
end

function TestCampaignSitac:test_a_capture_in_progress_gives_its_side_and_seconds()
  local sitac = veafCampaign.stateTable().sitac
  luaunit.assertEquals(sitacZone(sitac, "Tal Rifaat").capture, { side = "blue", seconds = 42 })
  luaunit.assertNil(sitacZone(sitac, "Minakh").capture)
end

function TestCampaignSitac:test_buildings_are_counted_standing_and_total()
  local sitac = veafCampaign.stateTable().sitac
  luaunit.assertEquals(sitacZone(sitac, "Kafr Naya").structures, { standing = 1, total = 2 })
  luaunit.assertNil(sitacZone(sitac, "Minakh").structures)
end

function TestCampaignSitac:test_a_zone_says_whether_it_is_awake()
  veafCampaign.zones["Anadan"].awake = true
  local sitac = veafCampaign.stateTable().sitac
  luaunit.assertTrue(sitacZone(sitac, "Anadan").awake)
  luaunit.assertFalse(sitacZone(sitac, "Kafr Naya").awake)
end

function TestCampaignSitac:test_the_connections_are_pairs_of_zone_names()
  local sitac = veafCampaign.stateTable().sitac
  luaunit.assertEquals(sitac.connections, { { "Minakh", "Kafr Naya" }, { "Kafr Naya", "Tal Rifaat" }, { "Tal Rifaat", "Anadan" } })
end

function TestCampaignSitac:test_a_convoy_under_way_gives_its_side_route_and_units_alive()
  local saved = veafCampaign.refreshConvoy
  veafCampaign.refreshConvoy = function() end
  veafCampaign.convoys = {
    { name = "convoy 1", side = "blue", from = "Minakh", to = "Kafr Naya", alive = { "M-1 Abrams", "M-2 Bradley" }, absorbed = {} },
    { name = "convoy 2", side = "red", from = "Anadan", to = "Tal Rifaat", alive = {}, absorbed = {}, ended = true },
  }
  local sitac = veafCampaign.stateTable().sitac
  veafCampaign.refreshConvoy = saved
  luaunit.assertEquals(sitac.convoys, { { side = "blue", from = "Minakh", to = "Kafr Naya", units = 2 } })
end

function TestCampaignSitac:test_each_side_has_its_credits_and_stock()
  veafCampaignEconomy = { credits = 1915 }
  veafCampaignLogistics = {
    active = true,
    stock = function(side)
      return ({ blue = 600, red = 250 })[side]
    end,
  }
  local sitac = veafCampaign.stateTable().sitac
  luaunit.assertEquals(sitac.sides.blue, { credits = 1915, resources = 600 })
  luaunit.assertEquals(sitac.sides.red, { resources = 250 })
end

function TestCampaignSitac:test_without_economy_nor_resources_the_sides_are_empty()
  local sitac = veafCampaign.stateTable().sitac
  luaunit.assertEquals(sitac.sides, { blue = {}, red = {} })
end

function TestCampaignSitac:test_the_block_is_written_in_the_state_file()
  luaunit.assertTrue(veafCampaign.writeState())
  local state = assert(loadstring(self.files[SAVE]))()
  luaunit.assertEquals(state.sitac.campaign, "Bouclier de l'Oronte")
  luaunit.assertEquals(#state.sitac.zones, 4)
end

function TestCampaignSitac:test_the_reload_ignores_the_block()
  veafCampaign.zones["Kafr Naya"].entry.owner = "neutral"
  veafCampaign.zones["Kafr Naya"].entry.garrison = nil
  luaunit.assertTrue(veafCampaign.writeState())
  -- a block that says otherwise is not read back: the zones' own state is
  local content = self.files[SAVE]
  luaunit.assertStrContains(content, '["sitac"]=')
  veafCampaign.data = persistentData()
  veafCampaign.initialize()
  luaunit.assertEquals(veafCampaign.loadResult, "loaded")
  luaunit.assertEquals(veafCampaign.zones["Kafr Naya"].entry.owner, "neutral")
  luaunit.assertNil(veafCampaign.data.sitac)
  luaunit.assertNil(veafCampaign.zones["Kafr Naya"].entry.sitac)
end

os.exit(luaunit.LuaUnit.run())
