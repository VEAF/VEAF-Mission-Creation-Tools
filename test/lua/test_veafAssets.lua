--- Tests for veafAssets.lua — asset database build and lookup.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafAssets.lua")

-- ---------------------------------------------------------------------------
-- TestVeafAssetsConstants
-- ---------------------------------------------------------------------------
TestVeafAssetsConstants = {}

function TestVeafAssetsConstants:test_id()
  luaunit.assertEquals(veafAssets.Id, "ASSETS")
end

function TestVeafAssetsConstants:test_version()
  luaunit.assertIsString(veafAssets.Version)
  luaunit.assertTrue(#veafAssets.Version > 0)
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
    { name = "testTanker",  description = "KC-135T",       unitType = "KC-135 MPRS", side = 1 },
    { name = "testAwacs",   description = "E-3A AWACS",    unitType = "E-3A",        side = 1 },
    { name = "testRefueler",description = "IL-78M tanker", unitType = "IL-78M",      side = 2 },
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

os.exit(luaunit.LuaUnit.run())
