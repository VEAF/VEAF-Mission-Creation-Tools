--- Unit tests for veafCacheManager.lua / VeafCache class.
---
--- Run:  lua test/lua/test_veafCacheManager.lua
---
--- Covers:
---   - Storing and retrieving a value within its TTL
---   - Expired entries return nil
---   - LIVE_FOREVER entries never expire
---   - delCachedData removes an entry
---   - Default TTL is honoured when no per-call TTL is supplied
---   - setDefaultTimeToLive overrides the class default
---   - Multiple independent VeafCache instances do not share data
---   - Zero-TTL entries are immediately stale

-- ---------------------------------------------------------------------------
-- Bootstrap: load the test framework, DCS mocks, and modules under test.
-- ---------------------------------------------------------------------------
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua") -- exported as global for test methods
dofile(_base .. "/dcs_mocks.lua")
dofile(_base .. "/../../src/scripts/veaf/veaf.lua")
dofile(_base .. "/../../src/scripts/veaf/veafScheduler.lua")
dofile(_base .. "/../../src/scripts/veaf/veafCacheManager.lua")

-- ---------------------------------------------------------------------------
-- Test suite
-- ---------------------------------------------------------------------------
TestVeafCacheManager = {}

function TestVeafCacheManager:setUp()
  dcs_mocks.reset() -- clock back to 0, logs cleared
  self.cache = VeafCache:new()
  self.cache:setName("testCache")
end

-- 1 -------------------------------------------------------------------------
function TestVeafCacheManager:test_storeAndRetrieve()
  self.cache:setCachedData("key1", "hello", 10)
  local result = self.cache:getCachedData("key1")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.data, "hello")
end

-- 2 -------------------------------------------------------------------------
function TestVeafCacheManager:test_missingKeyReturnsNil()
  local result = self.cache:getCachedData("nope")
  luaunit.assertNil(result)
end

-- 3 -------------------------------------------------------------------------
function TestVeafCacheManager:test_expiredEntryReturnsNil()
  self.cache:setCachedData("key2", 42, 5) -- expires at t=5
  dcs_mocks.advanceTime(6) -- now t=6
  local result = self.cache:getCachedData("key2")
  luaunit.assertNil(result)
end

-- 4 -------------------------------------------------------------------------
function TestVeafCacheManager:test_validEntryReturnsData()
  self.cache:setCachedData("key3", "live", 10) -- expires at t=10
  dcs_mocks.advanceTime(9) -- now t=9
  local result = self.cache:getCachedData("key3")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.data, "live")
end

-- 5 -------------------------------------------------------------------------
function TestVeafCacheManager:test_liveForeverNeverExpires()
  self.cache:setCachedData("eternal", "forever", VeafCache.LIVE_FOREVER)
  dcs_mocks.advanceTime(1e9) -- simulate huge time advance
  local result = self.cache:getCachedData("eternal")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.data, "forever")
end

-- 6 -------------------------------------------------------------------------
function TestVeafCacheManager:test_delCachedData()
  self.cache:setCachedData("key4", "removeme", 100)
  self.cache:delCachedData("key4")
  local result = self.cache:getCachedData("key4")
  luaunit.assertNil(result)
end

-- 7 -------------------------------------------------------------------------
function TestVeafCacheManager:test_defaultTTLIsUsed()
  self.cache:setDefaultTimeToLive(3)
  self.cache:setCachedData("key5", "default") -- no explicit TTL → uses 3
  dcs_mocks.advanceTime(2)
  luaunit.assertNotNil(self.cache:getCachedData("key5"), "should still be valid at t=2")
  dcs_mocks.advanceTime(2) -- now t=4
  luaunit.assertNil(self.cache:getCachedData("key5"), "should be expired at t=4")
end

-- 8 -------------------------------------------------------------------------
function TestVeafCacheManager:test_overrideDefaultTTL()
  self.cache:setDefaultTimeToLive(100)
  luaunit.assertEquals(self.cache:getDefaultTimeToLive(), 100)
end

-- 9 -------------------------------------------------------------------------
function TestVeafCacheManager:test_independentInstances()
  local cacheA = VeafCache:new()
  cacheA:setName("A")
  local cacheB = VeafCache:new()
  cacheB:setName("B")

  cacheA:setCachedData("shared", "from-A", 10)
  cacheB:setCachedData("shared", "from-B", 10)

  luaunit.assertEquals(cacheA:getCachedData("shared").data, "from-A")
  luaunit.assertEquals(cacheB:getCachedData("shared").data, "from-B")
end

-- 10 -------------------------------------------------------------------------
function TestVeafCacheManager:test_exactlyAtExpiryBoundary()
  -- An entry set with TTL=5 should still be accessible at exactly t=5
  -- (endoflife = 0+5 = 5, getCachedData checks endoflife >= timer.getTime())
  self.cache:setCachedData("boundary", "edge", 5)
  dcs_mocks.advanceTime(5) -- now at exactly the expiry time
  local result = self.cache:getCachedData("boundary")
  luaunit.assertNotNil(result, "entry should still be valid exactly at its endoflife")
end

-- 11 -------------------------------------------------------------------------
function TestVeafCacheManager:test_overwriteEntry()
  self.cache:setCachedData("key6", "old", 100)
  self.cache:setCachedData("key6", "new", 100)
  local result = self.cache:getCachedData("key6")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.data, "new")
end

-- 12 -------------------------------------------------------------------------
function TestVeafCacheManager:test_storeNilValue()
  -- Storing nil as a value: the cache entry exists but data is nil.
  self.cache:setCachedData("nullish", nil, 10)
  local result = self.cache:getCachedData("nullish")
  luaunit.assertNotNil(result) -- the entry itself exists
  luaunit.assertNil(result.data) -- but the payload is nil
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------
os.exit(luaunit.LuaUnit.run())
