--- Tests for veafAssets.lua — asset database build and lookup.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
-- veafMove too: veafAssets.respawn calls into it to repair a respawned asset's escort task
-- (FIX-ESCORT-RESPAWN-TASK), so a test that omits it would exercise the guarded-out branch only.
dofile(src .. "/veafMove.lua")
dofile(src .. "/veafAssets.lua")

-- ---------------------------------------------------------------------------
-- TestVeafAssetsConstants
-- ---------------------------------------------------------------------------
TestVeafAssetsConstants = {}

function TestVeafAssetsConstants:test_id()
  luaunit.assertEquals(veafAssets.Id, "ASSETS")
end

function TestVeafAssetsConstants:test_radioMenuName()
  luaunit.assertIsString(veafAssets.RadioMenuName)
  luaunit.assertTrue(#veafAssets.RadioMenuName > 0)
end

function TestVeafAssetsConstants:test_assets_table_exists()
  luaunit.assertIsTable(veafAssets.Assets)
end

function TestVeafAssetsConstants:test_assets_lookup_table_exists()
  luaunit.assertIsTable(veafAssets.assets)
end

-- ---------------------------------------------------------------------------
-- TestVeafAssetsBuildAndGet
-- ---------------------------------------------------------------------------
TestVeafAssetsBuildAndGet = {}

function TestVeafAssetsBuildAndGet:setUp()
  -- Override with a controlled test dataset
  veafAssets.Assets = {
    { name = "testTanker", description = "KC-135T", unitType = "KC-135 MPRS", side = 1 },
    { name = "testAwacs", description = "E-3A AWACS", unitType = "E-3A", side = 1 },
    { name = "testRefueler", description = "IL-78M tanker", unitType = "IL-78M", side = 2 },
  }
  veafAssets.assets = {}
  veafAssets.buildAssetsDatabase()
end

function TestVeafAssetsBuildAndGet:test_get_existing_asset()
  local asset = veafAssets.get("testTanker")
  luaunit.assertNotNil(asset)
  luaunit.assertEquals(asset.name, "testTanker")
end

function TestVeafAssetsBuildAndGet:test_get_preserves_description()
  local asset = veafAssets.get("testTanker")
  luaunit.assertNotNil(asset)
  luaunit.assertEquals(asset.description, "KC-135T")
end

function TestVeafAssetsBuildAndGet:test_get_preserves_unitType()
  local asset = veafAssets.get("testTanker")
  luaunit.assertNotNil(asset)
  luaunit.assertEquals(asset.unitType, "KC-135 MPRS")
end

function TestVeafAssetsBuildAndGet:test_get_second_asset()
  local asset = veafAssets.get("testAwacs")
  luaunit.assertNotNil(asset)
  luaunit.assertEquals(asset.description, "E-3A AWACS")
end

function TestVeafAssetsBuildAndGet:test_get_coalition2_asset()
  local asset = veafAssets.get("testRefueler")
  luaunit.assertNotNil(asset)
  luaunit.assertEquals(asset.unitType, "IL-78M")
end

function TestVeafAssetsBuildAndGet:test_get_unknown_returns_nil()
  local asset = veafAssets.get("NONEXISTENT_ASSET_XYZ")
  luaunit.assertNil(asset)
end

function TestVeafAssetsBuildAndGet:test_get_nil_key_returns_nil()
  local asset = veafAssets.get(nil)
  luaunit.assertNil(asset)
end

function TestVeafAssetsBuildAndGet:test_all_three_assets_indexed()
  luaunit.assertNotNil(veafAssets.get("testTanker"))
  luaunit.assertNotNil(veafAssets.get("testAwacs"))
  luaunit.assertNotNil(veafAssets.get("testRefueler"))
end

function TestVeafAssetsBuildAndGet:test_rebuild_replaces_old_data()
  -- Add a new asset and rebuild
  table.insert(veafAssets.Assets, { name = "newAsset", description = "New" })
  veafAssets.buildAssetsDatabase()
  luaunit.assertNotNil(veafAssets.get("newAsset"))
  luaunit.assertNotNil(veafAssets.get("testTanker"))
end

function TestVeafAssetsBuildAndGet:test_empty_assets_clear()
  veafAssets.Assets = {}
  veafAssets.assets = {}
  veafAssets.buildAssetsDatabase()
  luaunit.assertNil(veafAssets.get("testTanker"))
end

-- ---------------------------------------------------------------------------
-- TestVeafAssetsModuleFunctions
-- ---------------------------------------------------------------------------
TestVeafAssetsModuleFunctions = {}

function TestVeafAssetsModuleFunctions:test_buildAssetsDatabase_is_function()
  luaunit.assertIsFunction(veafAssets.buildAssetsDatabase)
end

function TestVeafAssetsModuleFunctions:test_get_is_function()
  luaunit.assertIsFunction(veafAssets.get)
end

function TestVeafAssetsModuleFunctions:test_initialize_is_function()
  luaunit.assertIsFunction(veafAssets.initialize)
end

function TestVeafAssetsModuleFunctions:test_buildRadioMenu_is_function()
  luaunit.assertIsFunction(veafAssets.buildRadioMenu)
end

-- ============================================================================
-- TestVeafAssetsOps - exercises info / dispose / respawn / buildRadioMenu
-- ============================================================================
TestVeafAssetsOps = {}

function TestVeafAssetsOps:setUp()
  -- Populate Assets with a single tanker entry and build the lookup table
  veafAssets.Assets = {
    { name = "testTanker", description = "KC-135T", unitType = "KC-135 MPRS", side = 1 },
  }
  veafAssets.assets = {}
  veafAssets.buildAssetsDatabase()
end

function TestVeafAssetsOps:test_help_nil()
  -- help(nil) logs text; no crash expected
  veafAssets.help(nil)
  luaunit.assertTrue(true)
end

function TestVeafAssetsOps:test_info_found_no_group()
  -- asset exists but Group.getByName returns nil → formats "not active" message
  veafAssets.info({ "testTanker", nil })
  luaunit.assertTrue(true)
end

function TestVeafAssetsOps:test_info_not_found()
  -- asset not in database → early return with "not found" message
  veafAssets.info({ "NONEXISTENT", nil })
  luaunit.assertTrue(true)
end

function TestVeafAssetsOps:test_dispose_found_no_group()
  -- asset exists; Group.getByName returns nil → nothing to destroy
  veafAssets.dispose("testTanker")
  luaunit.assertTrue(true)
end

function TestVeafAssetsOps:test_dispose_not_found()
  veafAssets.dispose("NONEXISTENT")
  luaunit.assertTrue(true)
end

function TestVeafAssetsOps:test_respawn_found()
  -- mist.respawnGroup is mocked as a no-op
  veafAssets.respawn("testTanker")
  luaunit.assertTrue(true)
end

function TestVeafAssetsOps:test_respawn_not_found()
  veafAssets.respawn("NONEXISTENT")
  luaunit.assertTrue(true)
end

function TestVeafAssetsOps:test_buildRadioMenu_empty_assets()
  -- empty assets table → early-return guard prevents veafRadio calls
  veafAssets.assets = {}
  veafAssets.buildRadioMenu()
  luaunit.assertTrue(true)
end

-- ---------------------------------------------------------------------------
-- TestVeafAssetsRespawnRepairsEscort — FIX-ESCORT-RESPAWN-TASK ticket 01
--
-- Respawning an asset gives it a new DCS group id, which silently invalidates its escort's Escort
-- task: the escort flies out its route and lands about ten minutes later (#107). The repair lives in
-- veafMove; what is asserted here is that the respawn path actually calls it, because a guard nobody
-- calls is worth nothing.
-- ---------------------------------------------------------------------------
TestVeafAssetsRespawnRepairsEscort = {}

function TestVeafAssetsRespawnRepairsEscort:setUp()
  dcs_mocks.reset()
  self._reestablish = veafMove.reestablishEscortTask
  self._calls = {}
  local calls = self._calls
  veafMove.reestablishEscortTask = function(name)
    table.insert(calls, name)
    return true
  end
  veafAssets.Assets = {
    { name = "testTanker", description = "KC-135T", unitType = "KC-135 MPRS", side = 1 },
  }
  veafAssets.assets = {}
  veafAssets.buildAssetsDatabase()
end

function TestVeafAssetsRespawnRepairsEscort:tearDown()
  veafMove.reestablishEscortTask = self._reestablish
end

function TestVeafAssetsRespawnRepairsEscort:test_respawning_an_asset_repairs_its_escort_task()
  veafAssets.respawn("testTanker")

  luaunit.assertEquals(self._calls, { "testTanker" })
end

function TestVeafAssetsRespawnRepairsEscort:test_respawning_an_unknown_asset_repairs_nothing()
  veafAssets.respawn("noSuchAsset")

  luaunit.assertEquals(#self._calls, 0)
end

function TestVeafAssetsRespawnRepairsEscort:test_the_repair_is_keyed_on_the_asset_not_on_its_linked_groups()
  -- The escort does not have to be in `linked` for its task to break: only the escorted group's id
  -- changes. So the repair is asked for the asset, once, whatever `linked` contains.
  veafAssets.assets["testTanker"].linked = { "someOtherGroup" }

  veafAssets.respawn("testTanker")

  luaunit.assertEquals(self._calls, { "testTanker" })
end

os.exit(luaunit.LuaUnit.run())
