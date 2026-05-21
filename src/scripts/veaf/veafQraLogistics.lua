------------------------------------------------------------------
-- VEAF QRA Logistics for DCS World
-- Extracted from veafQraManager.lua — warehousing and resupply chain.
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafQRALogistics class — warehouse/supply-chain data and logic
--
-- Responsibilities:
--   * Track available aircraft groups (QRAcount / QRAmaxCount)
--   * Manage the resupply schedule (delayBeforeQRAresupply, QRAresupplyMax, etc.)
--   * Execute checkWarehousing() and resupply() on behalf of the owning VeafQRACore
--
-- VeafQRACore keeps a `logistics` field pointing to an instance of this class.
-- Methods that need to transition core state receive `qra` (the VeafQRACore) as
-- the first parameter.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafQRALogistics = {}

function VeafQRALogistics.init(object)
  -- maximum number of QRA ready for action at once, -1 indicates infinite
  object.QRAmaxCount = -1
  -- number of groups of aircrafts that can be spawned for this QRA in total, -1 indicates infinite
  object.QRAcount = -1
  -- delay in seconds before the QRA counter is increased by one, simulating a logistic chain
  object.delayBeforeQRAresupply = 0
  -- maximum number of resupplies at a given time, -1 indicates infinite; decremented on each resupply; 0 = no resupply
  object.QRAresupplyMax = -1
  -- minimum QRAcount that will trigger a resupply (-1 = as soon as an aircraft group is lost)
  object.QRAminCountforResupply = -1
  -- how many aircraft groups are resupplied at once
  object.resupplyAmount = 1
  -- indicator: a resupply is already scheduled/in-flight
  object.isResupplying = false
end

function VeafQRALogistics:new()
  local obj = {}
  setmetatable(obj, self)
  self.__index = self
  VeafQRALogistics.init(obj)
  return obj
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Setters
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function VeafQRALogistics:setQRAcount(count)
  if count and type(count) == "number" and count >= -1 then
    self.QRAcount = count
  end
  return self
end

function VeafQRALogistics:setQRAmaxCount(maxCount)
  if maxCount and type(maxCount) == "number" and maxCount >= -1 then
    self.QRAmaxCount = maxCount
  end
  return self
end

function VeafQRALogistics:setQRAresupplyDelay(resupplyDelay)
  if resupplyDelay and type(resupplyDelay) == "number" and resupplyDelay >= 0 then
    self.delayBeforeQRAresupply = resupplyDelay
  end
  return self
end

function VeafQRALogistics:setQRAmaxResupplyCount(maxResupplyCount)
  if maxResupplyCount and type(maxResupplyCount) == "number" and maxResupplyCount >= -1 then
    self.QRAresupplyMax = maxResupplyCount
  end
  return self
end

function VeafQRALogistics:setQRAminCountforResupply(minCountforResupply)
  if minCountforResupply and type(minCountforResupply) == "number" and minCountforResupply >= -1 and minCountforResupply ~= 0 then
    self.QRAminCountforResupply = minCountforResupply
  end
  return self
end

function VeafQRALogistics:setResupplyAmount(resupplyAmount)
  if resupplyAmount and type(resupplyAmount) == "number" and resupplyAmount >= 1 then
    self.resupplyAmount = resupplyAmount
  end
  return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Getters
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function VeafQRALogistics:getQRAcount()
  return self.QRAcount
end

--- Returns true when warehousing is active (i.e. aircraft groups are finite).
function VeafQRALogistics:isActive()
  return self.QRAcount ~= -1
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Core logistics methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Called by VeafQRACore:check() to evaluate warehousing state and trigger resupply when needed.
--- @param qra table  The owning VeafQRACore instance.
function VeafQRALogistics:checkWarehousing(qra)
  veaf.loggers.get(veafQraManager.Id):trace("VeafQRALogistics[%s]:checkWarehousing()", veaf.lp(qra.name))
  veaf.loggers.get(veafQraManager.Id):trace("resupply state is %s", veaf.lp(self.isResupplying))

  -- if a resupply is not already on the way, and there are aircraft in stock, and the count is below
  -- the threshold (or an aircraft was just lost and mode is "resupply on every loss")
  if
    not self.isResupplying
    and self.QRAresupplyMax ~= 0
    and (
      self.QRAcount < self.QRAminCountforResupply
      or (self.QRAcount < self.QRAmaxCount or (self.QRAmaxCount == -1 and qra.state == veafQraManager.STATUS_DEAD))
        and self.QRAminCountforResupply == -1
    )
  then
    veaf.loggers.get(veafQraManager.Id):trace("QRA has %s/%s aircraft groups available", veaf.lp(self.QRAcount), veaf.lp(self.QRAmaxCount))
    veaf.loggers
      .get(veafQraManager.Id)
      :trace("QRA has %s aircraft groups ready for resupply (-1 for infinite)", veaf.lp(self.QRAresupplyMax))
    veaf.loggers.get(veafQraManager.Id):trace("QRA resupply asks for %s aircraft groups", veaf.lp(self.resupplyAmount))
    local resupplyAmount = self.resupplyAmount

    -- cap to available slots
    if self.QRAmaxCount ~= -1 and resupplyAmount > self.QRAmaxCount - self.QRAcount then
      resupplyAmount = self.QRAmaxCount - self.QRAcount
      veaf.loggers
        .get(veafQraManager.Id)
        :trace("There are only %s available aircraft group slots for this QRA", veaf.lp(self.QRAmaxCount - self.QRAcount))
    end

    -- cap to stock
    if self.QRAresupplyMax ~= -1 and resupplyAmount > self.QRAresupplyMax then
      resupplyAmount = self.QRAresupplyMax
      veaf.loggers.get(veafQraManager.Id):trace("QRA can only be resupplied by %s aircraft groups", veaf.lp(self.QRAresupplyMax))
    end

    veaf.loggers.get(veafQraManager.Id):trace("%s aircraft groups will be handled for resupply", veaf.lp(resupplyAmount))
    if resupplyAmount > 0 then
      self.isResupplying = true
      if self.delayBeforeQRAresupply > 0 then
        veaf.loggers.get(veafQraManager.Id):trace("QRA will be resupplied in %s seconds", veaf.lp(self.delayBeforeQRAresupply))
        mist.scheduleFunction(function(args)
          veaf.safeCall(VeafQRALogistics.resupply, args[1], args[2], args[3])
        end, { { self, qra, resupplyAmount } }, timer.getTime() + self.delayBeforeQRAresupply)
      else
        veaf.loggers.get(veafQraManager.Id):trace("QRA is being resupplied...")
        self:resupply(qra, resupplyAmount)
      end
    end
  end

  if self.QRAcount == 0 then
    veaf.loggers.get(veafQraManager.Id):trace("QRA is out of aircraft groups")
    if not qra.silent and not qra.outAnnounced then
      qra:_sendStatusMessage(qra.messageOut)
      qra.outAnnounced = true
    end
    if qra.onOut then
      qra.onOut()
    end
    qra:setScheduledState(veafQraManager.STATUS_OUT)
  end
end

--- Execute a resupply: increase QRAcount and notify the owning QRA if it was OUT.
--- @param qra table  The owning VeafQRACore instance.
--- @param resupplyAmount number  Number of aircraft groups to resupply.
function VeafQRALogistics:resupply(qra, resupplyAmount)
  veaf.loggers.get(veafQraManager.Id):debug("VeafQRALogistics[%s]:resupply(%s)", veaf.lp(qra.name), veaf.lp(resupplyAmount))

  -- abort if the QRA is no longer able to operate
  if qra.scheduled_state == veafQraManager.STATUS_NOAIRBASE or qra.scheduled_state == veafQraManager.STATUS_STOP then
    veaf.loggers.get(veafQraManager.Id):trace("QRA is no longer operating, resupply did not take place")
    self.isResupplying = false
    return
  end

  if resupplyAmount and type(resupplyAmount) == "number" and resupplyAmount > 0 then
    veaf.loggers.get(veafQraManager.Id):trace("QRA is going to be resupplied, old count is : %s", veaf.lp(self.QRAcount))
    self.QRAcount = self.QRAcount + resupplyAmount
    veaf.loggers.get(veafQraManager.Id):trace("QRA was resupplied, new count is : %s", veaf.lp(self.QRAcount))

    veaf.loggers
      .get(veafQraManager.Id)
      :trace("QRA previously had %s aircraft groups ready for resupply (-1 for infinite)", veaf.lp(self.QRAresupplyMax))
    if self.QRAresupplyMax ~= -1 then
      self.QRAresupplyMax = self.QRAresupplyMax - resupplyAmount
      if self.QRAresupplyMax < 0 then
        self.QRAresupplyMax = 0
      end
    end
    veaf.loggers
      .get(veafQraManager.Id)
      :trace("QRA now only has %s aircraft groups ready for resupply (-1 for infinite)", veaf.lp(self.QRAresupplyMax))

    if qra.state == veafQraManager.STATUS_OUT then
      veaf.loggers.get(veafQraManager.Id):trace("QRA now has at least one aircraft group ready for action, resuming service...")
      if not qra.silent then
        qra:_sendStatusMessage(qra.messageResupplied)
      end
      if qra.onResupplied then
        qra.onResupplied()
      end
      qra.outAnnounced = false
      -- QRA that just arrived act as if the QRA had just died — they need to be rearmed
      qra.state = veafQraManager.STATUS_DEAD
      if qra.scheduled_state == veafQraManager.STATUS_OUT then
        qra.scheduled_state = nil
      end
    end
  end

  self.isResupplying = false
end

--- Called when the QRA is destroyed to decrement the aircraft group counter.
function VeafQRALogistics:onQRADestroyed()
  if self.QRAcount > 0 then
    veaf.loggers.get(veafQraManager.Id):trace("QRA will now see one of its aircraft groups removed")
    self.QRAcount = self.QRAcount - 1
  end
end
