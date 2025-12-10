------------------------------------------------------------------
-- VEAF Cache Manager
-- By Zip (2024-25)
--
-- Features:
-- ---------
-- * Manage cached data with fixed or flexible lifespan
------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafCacheManager = {}

--- Identifier. All output in the log will start with this.
veafCacheManager.Id = "CACHE - "

--- Version.
veafCacheManager.Version = "0.0.2"

-- trace level, specific to this module
veafCacheManager.LogLevel = "trace"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.loggers.new(veafCacheManager.Id, veafCacheManager.LogLevel)

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafCache class
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafCache = {}

VeafCache.DEFAULT_TIME_TO_LIVE = 1 -- 1 second
VeafCache.LIVE_FOREVER = -1 -- this is the TTL for a computed once, cached forever data

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CTOR

function VeafCache.init(object)
  -- technical name (VeafCache instance name)
  object.name = nil
  -- cache data
  object.cache = {}
  -- default time to live
  object.defaultTTL = VeafCache.DEFAULT_TIME_TO_LIVE
end

function VeafCache:new(objectToCopy)
  veaf.loggers.get(veafCacheManager.Id):debug("VeafCache:new()")
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self

  -- init the new object
  VeafCache.init(objectToCreate)

  return objectToCreate
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTIES

-- technical name (VeafCache instance name)
function VeafCache:setName(value)
  veaf.loggers.get(veafCacheManager.Id):debug("VeafCache[]:setName(%s)", veaf.p(value))
  self.name = value
end

-- technical name (VeafCache instance name)
function VeafCache:getName()
  return self.name or self.description
end

-- default time to live
function VeafCache:setDefaultTimeToLive(value)
  self.defaultTTL = value
  veaf.loggers.get(veafCacheManager.Id):debug("VeafCache[%s]:setDefaultTimeToLive(%s)", veaf.p(self:getName()), veaf.p(value))
  return self
end

-- default time to live
function VeafCache:getDefaultTimeToLive()
  return self.defaultTTL
end


-- remove cached data
function VeafCache:delCachedData(key)
  if self.cache then
    self.cache[key] = nil
  end
end

-- set cached data
function VeafCache:setCachedData(key, value, timetolive)
  local cachedData = nil
  if self.cache then
    local _endoflife = timer.getTime() + (timetolive or self:getDefaultTimeToLive())
    if timetolive == VeafCache.LIVE_FOREVER then
      _endoflife = VeafCache.LIVE_FOREVER
    end
    cachedData = {
      data = value,
      endoflife = _endoflife
    }
    self.cache[key] = cachedData
  end
  return cachedData
end

-- get cached data
function VeafCache:getCachedData(key)
  if self.cache then
    local cachedData = self.cache[key]
    if cachedData and cachedData.endoflife < timer.getTime() then
      return cachedData
    end
  end
  return nil
end

veaf.loggers.get(veafCacheManager.Id):info(veaf.loggers.get(veafCacheManager.Id):getVersionInfo(veafCacheManager.Version))
