------------------------------------------------------------------
-- VEAF helper for Skynet-IADS
-- By zip (2021)
--
-- Features:
-- ---------
-- * This module offers support for integrating Skynet-IADS in a mission
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafSkynet = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafSkynet.Id = "SKYNET"

-- trace level, specific to this module
--veafSkynet.LogLevel = "trace"

veaf.loggers.new(veafSkynet.Id, veafSkynet.LogLevel)

-- delay before the mission groups are added to the IADS' at start
veafSkynet.DelayForStartup = 1

-- delay before restarting the IADS when adding a single group
veafSkynet.DelayForRestart = 20

-- delay before a dynamically spawned group is integrated into its network.
-- This exists so integration does not depend on whether DCS emits S_EVENT_BIRTH before or after
-- veafSpawn has had a chance to declare what the spawn asked for (see veafSkynet.declareSpawn):
-- the group name is only known once the spawn handler returns, so the declaration cannot be made
-- ahead of the birth event. Integration ends in delayedActivate, which waits DelayForRestart
-- seconds anyway, so this delay costs nothing observable.
veafSkynet.DelayForDynamicIntegration = 1

-- A radar that reported no range at all is asked again: how long to wait between readings, and how
-- many readings to try. Skynet reads a radar's range **once**, when the element is built, so a single
-- unlucky answer decided a site's range for the whole mission (#946, second round).
veafSkynet.DelayForRangeRecheck = 5
veafSkynet.MaxRangeRechecks = 3

-- maximum x or y (z in DCS) between a SAM site and it's point defenses in meters
veafSkynet.MaxPointDefenseDistanceFromSite = 10000

-- seconds between two sweeps looking for sites whose group has left the mission.
-- A minute is short enough that the status page never lies for long, and long enough that the sweep
-- costs nothing next to the contact-evaluation cycle it is protecting (#946).
veafSkynet.SecondsBetweenVanishedSitesSweeps = 60

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSkynet.initialized = false
--flag to know if all units present on the map should be loaded at init or not into their team's main IADS network
veafSkynet.loadAllAtInit = {
  [tostring(coalition.side.BLUE)] = true,
  [tostring(coalition.side.RED)] = true,
}
--table containing the default IADS network names initialized for each coalition
veafSkynet.defaultIADS = {
  [tostring(coalition.side.BLUE)] = "blue iads",
  [tostring(coalition.side.RED)] = "red iads",
}
veafSkynet.iadsSamUnitsTypes = {}
veafSkynet.iadsEwrUnitsTypes = {}

veafSkynet.GroupIntegrationModes = {
  Strict = 0, -- groups will only be included in the skynet networks if they contains only units known to skynet
  Lenient = 1, -- groups will be included in the skynet networks even if some units are not known to skynet
}
veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Lenient -- lenient by default

-- Management of point defences (Flogas)
-- when active, veafSkynet will attempt to set eligible groups as point defence of nearby defencible groups
-- as per Skynet database types :
--  - "single" groups will be eligible to defend "complex" or "ewr" groups
--  - "complex" groups will be eligible to defend "ewr" groups
--  - "single" groups will never be defended
veafSkynet.PointDefenceModes = {
  None = 0, -- point defences will not be created
  Skynet = 1, -- point defences will be defined with the skynet logic
  Dcs = 2, -- point defences will be defined as not a part of the skynet network and left to the dcs ai
}
veafSkynet.PointDefenceMode = veafSkynet.PointDefenceModes.None -- no point defences by default

-- Value each network is *created* with. The live setting is per network, in
-- veafSkynet.structure[networkName].dynamicSpawn, so that deactivating one coalition's network does
-- not disable dynamic integration for the other one (#261).
veafSkynet.DynamicSpawn = false -- false by default

veafSkynet.SkynetElementStates = {
  Autonomous = 0,
  Live = 1,
  Dark = 2,
}

--table containing the structure of each IADS network, first level is accessed with the IADS name. This contains the .coalitionID of the network, the IADS network (.iads), the groups added to the network (.groups) stored by groupName,
--wether this network should appear on the radio menu (.includeInRadio) and lastly if this network is in debug mode (.debugFlag). The groups store whether the group was .forceEwr or .pointDefense.
--It also carries .dynamicSpawn (does this network integrate groups spawned during the mission) and .deactivated (was this network switched off on purpose, in which case nothing may bring it back up implicitly).
veafSkynet.structure = {}

--What a veafSpawn command asked for, per group name, so that the birth-event handler can honour the
--per-spawn `skynet` option instead of integrating every eligible group it sees. Values are `false`
--(stay out of every network) or a network name. Entries are consumed on integration.
veafSkynet.declaredSpawns = {}

--- Unit names DCS has reported lost, as a set. Read by `veafSkynet.removeVanishedSites` to tell a
--- site the enemy destroyed from a site a script despawned — see there for why that matters.
---
--- It holds **every** unit death in the mission, not only the ones belonging to an IADS, and only a
--- birth under the same name takes an entry out. That is deliberate: the obvious filter — record a
--- death only when the unit's type is one Skynet knows — reads `unitType` off the event, and that is
--- precisely what stops resolving once the unit is gone (`completeUnitFromName` asks
--- `Unit.getByName`). A missed radar death would make the sweep read a kill as a despawn and remove a
--- site the player earned, so the set is left to grow rather than filtered on a field that can be
--- nil. A busy multi-hour mission costs on the order of a hundred kilobytes for it.
veafSkynet.lostUnits = {}

--- Whether the death callback and the periodic sweep are in place. See `_armVanishedSitesSweep`.
veafSkynet.vanishedSitesSweepArmed = false

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- True when DCS still holds this object.
---
--- `coalition.getGroups` can hand back a group that has been **destroyed**. That is not a suspicion:
--- it is the reason the Skynet compatibility layer wraps its own listing in `forEachLiveGroup`
--- (`src/scripts/community/skynet-iads-compiled.lua`), whose comment records that asking such a
--- group for its units raises. veafSkynet enrols the map `DelayForStartup` seconds into the mission,
--- which is *after* every combat zone has destroyed the groups standing inside it
--- (`veafCombatZone.lua`, *"remove all units in the trigger zone (we want it CLEAN !)"*), so the
--- listing it walks is routinely carrying corpses. Enrolling one produced a SAM site whose radar
--- never existed, counted as *radar destroyed* on the IADS status page for the rest of the mission
--- and holding its group name against any respawn (#946).
---
--- `not dcsObject.isExist` is deliberate, and phrased as `forEachLiveGroup` phrases it: a handle that
--- cannot answer the question must not take the whole enrolment down with it.
---
--- @param dcsObject table|nil a DCS Group, Unit or StaticObject handle
--- @return boolean true when the object is still part of the mission
function veafSkynet.dcsObjectStillExists(dcsObject)
  if not dcsObject then
    return false
  end
  if not dcsObject.isExist then
    return true
  end
  return dcsObject:isExist() and true or false
end

--- The object's name for a log line, or `"?"`, without ever raising.
---
--- Through `pcall` on purpose: the one place a name is wanted is a message about an object DCS has
--- released, and such an object can refuse every method — `getName` included. A log line must not be
--- the thing that raises.
---
--- @param dcsObject table|nil
--- @return string
function veafSkynet.safeDcsName(dcsObject)
  if not dcsObject or not dcsObject.getName then
    return "?"
  end
  local ok, name = pcall(dcsObject.getName, dcsObject)
  if ok and type(name) == "string" then
    return name
  end
  return "?"
end

--- Record that DCS reported a unit lost, so a sweep can tell a kill from a despawn.
---
--- Keyed on **unit** name rather than group name on purpose: `veafEventHandler.completeUnitFromName`
--- resolves a unit's group through `Unit.getByName`, which is exactly what has stopped answering by
--- the time a death is reported, so the group name reaching a callback is unreliable where the unit
--- name is not.
---
--- @param event table the event handed to a `veafEventHandler` callback
function veafSkynet.onUnitLost(event)
  local unitName = veafEventHandler.unitNameFromEvent(event)
  if unitName then
    veaf.loggers.get(veafSkynet.Id):trace("unit lost: %s", veaf.lp(unitName))
    veafSkynet.lostUnits[unitName] = true
  end
end

--- Forget that a unit of this name was ever lost, because one is alive again.
---
--- Without this the ledger only grows, and a **reused unit name** would then read as a kill forever:
--- a combat zone whose SAM was shot once, deactivated and activated again spawns units under the same
--- names unless the zone renames them sequentially, and the next despawn of that site would be kept
--- as *destroyed* rather than swept — quietly reinstating the defect the sweep exists to fix.
---
--- A separate callback rather than one function inspecting the event's type: the transformed event
--- carries the event **table**, populated only once `veafEventHandler.initialize` has run, so reading
--- it would make the branch depend on initialisation order for nothing.
---
--- @param event table the event handed to a `veafEventHandler` callback
function veafSkynet.onUnitBorn(event)
  local unitName = veafEventHandler.unitNameFromEvent(event)
  if unitName and veafSkynet.lostUnits[unitName] then
    veaf.loggers.get(veafSkynet.Id):trace("unit born again, no longer counted as lost: %s", veaf.lp(unitName))
    veafSkynet.lostUnits[unitName] = nil
  end
end

function veafSkynet.getStringSkynetElement(skynetElement)
  local s = tostring(skynetElement.dcsName)

  -- Through the helper rather than `dcsRepresentation:isExist()` so that describing an element whose
  -- representation is nil says so instead of raising. That matters because this is what the log line
  -- of `removeSkynetElement` calls, on elements chosen for having lost their object (#946).
  if not veafSkynet.dcsObjectStillExists(skynetElement.dcsRepresentation) then
    return s .. " (dcs object does not exist)"
  end

  local id = skynetElement.dcsRepresentation:getID()
  local category = getmetatable(skynetElement.dcsRepresentation)
  local sCategory = "unknown"
  if category == Group then
    sCategory = "group"
  elseif category == Unit then
    sCategory = "unit"
  elseif category == StaticObject then
    sCategory = "static"
  end

  if skynetElement.getNatoName then
    s = s .. " [" .. skynetElement:getNatoName() .. "]"
  else
    s = s .. " [" .. skynetElement.typeName .. "]"
  end

  s = s .. " [id=" .. id .. "]" .. " [" .. sCategory .. "]"
  return s
end

function veafSkynet.getDcsGroupFromSkynetElement(skynetElement)
  if skynetElement.dcsRepresentation and skynetElement.dcsRepresentation:isExist() then
    local category = getmetatable(skynetElement.dcsRepresentation)
    if category == Group then
      return skynetElement.dcsRepresentation
    elseif category == Unit then
      return Unit.getGroup(skynetElement.dcsRepresentation)
    end
  end

  return nil
end

function veafSkynet.getSkynetData(skynetElement)
  local function skynetDatabaseMatchType(skynetElementTypeList, skynetDatabaseTypeList)
    if skynetDatabaseTypeList and skynetElementTypeList and #skynetElementTypeList > 0 then
      for i = 1, #skynetElementTypeList do
        if skynetDatabaseTypeList[skynetElementTypeList[i].typeName] then
          return true
        end
      end
    end

    return false
  end

  for skynetDataName, skynetData in pairs(SkynetIADS.database) do
    -- first check the launchers as they are the most unique thing
    if skynetDatabaseMatchType(skynetElement.launchers, skynetData["launchers"]) then
      veaf.loggers
        .get(veafSkynet.Id)
        :trace("Matched by launcher : " .. veafSkynet.getStringSkynetElement(skynetElement) .. " > " .. skynetDataName)
      return skynetData
    end

    -- tracking and search radars can be used by multiple sites
    if skynetDatabaseMatchType(skynetElement.trackingRadars, skynetData["trackingRadar"]) then
      veaf.loggers
        .get(veafSkynet.Id)
        :trace("Matched by TR : " .. veafSkynet.getStringSkynetElement(skynetElement) .. " > " .. skynetDataName)
      return skynetData
    end
    if skynetDatabaseMatchType(skynetElement.searchRadars, skynetData["searchRadar"]) then
      veaf.loggers
        .get(veafSkynet.Id)
        :trace("Matched by SR : " .. veafSkynet.getStringSkynetElement(skynetElement) .. " > " .. skynetDataName)
      return skynetData
    end
  end

  veaf.loggers.get(veafSkynet.Id):trace("No match : " .. veafSkynet.getStringSkynetElement(skynetElement))
  return nil
end

function veafSkynet.removeSkynetElement(skynetElement, veafSkynetNetwork)
  local iads = veafSkynetNetwork.iads

  veaf.loggers.get(veafSkynet.Id):trace("Remove skynet element [" .. veafSkynet.getStringSkynetElement(skynetElement) .. "]")

  local function _removeSkynetElementFromList(list, skynetElement)
    local iIndex = -1
    if list and #list > 0 then
      for i = 1, #list do
        if list[i] == skynetElement then
          iIndex = i
          break
        end
      end

      if iIndex > 0 then
        table.remove(list, iIndex)
      end
    end
  end

  -- Detached **before** cleanUp, and this is not tidiness. `SkynetIADSAbstractRadarElement:cleanUp`
  -- walks `self.pointDefences` and cleans each one up too — but a point defence is a separate site
  -- that is still alive, still listed in `iads.samSites` and still commanded. Cleaning it up calls
  -- `world.removeEventHandler` on it, and `SkynetIADSAbstractElement:onEvent` is what makes an
  -- element react to the world: on `S_EVENT_DEAD` it goes dark when its power source or connection
  -- node is gone and tells its children, and on `S_EVENT_SHOT` it runs `weaponFired`, which is how
  -- HARM detection sees anything at all. Unregistered, the site keeps being commanded while blind to
  -- both, for the rest of the mission, and nothing says so.
  --
  -- Unreachable before #946, because the only caller was the point-defence path in `Dcs` mode, where
  -- the element being removed *is* the point defence and holds none of its own. The sweep is the
  -- first caller that meets a parent, so the cascade has to be cut here rather than at the call site.
  -- Losing its parent leaves a point defence an ordinary site, which is the right outcome: the site
  -- it was defending has left the mission.
  veafSkynet.removePointDefencesFromSkynetElement(skynetElement)

  skynetElement:cleanUp()

  -- Guarded, unlike the call this replaces: the VMR-096 note below states that this function is
  -- reached precisely when the DCS representation is gone, and `enableEmission` raises on an object
  -- DCS no longer holds. Handing emission back to something that has left the mission is meaningless
  -- anyway. Nothing had noticed because the only caller was the point-defence path, which runs on
  -- live sites; the sweep added in #946 is the first caller that meets corpses by design.
  local dcsRepresentation = skynetElement:getDCSRepresentation()
  if veafSkynet.dcsObjectStillExists(dcsRepresentation) then
    dcsRepresentation:enableEmission(true)
  end

  local list = iads.samSites
  veaf.loggers.get(veafSkynet.Id):trace("Sam sites count: " .. #list)

  _removeSkynetElementFromList(list, skynetElement)
  -- Commented out since the day it was written (`3002aaad`, 2023-11-02, the commit that created this
  -- function), and the trace below recorded the consequence as "not removed here" without saying
  -- why: `iads:getEarlyWarningRadars()` hands back a delegator **copy**
  -- (`createTableDelegator`), so removing from it would have removed nothing. The field is the real
  -- list, which is what this now uses.
  _removeSkynetElementFromList(iads.earlyWarningRadars, skynetElement)

  veaf.loggers.get(veafSkynet.Id):trace("Sam sites count: " .. #list)

  -- VMR-096: getDcsGroupFromSkynetElement returns nil once the DCS representation is gone, which
  -- is exactly the case this function is called in — so asking the group for its name raised, and
  -- the network kept listing a group that no longer exists. `dcsName` carries the group name for
  -- the SAM sites removed here (addGroupsToNetwork compares it against a group name), so the
  -- entry can still be cleared under the right key.
  local dcsGroup = veafSkynet.getDcsGroupFromSkynetElement(skynetElement)
  local groupName = (dcsGroup and dcsGroup:getName()) or skynetElement.dcsName
  if groupName then
    veafSkynetNetwork.groups[groupName] = nil
  else
    veaf.loggers.get(veafSkynet.Id):warn("cannot tell which group to remove from the network for a skynet element with no name")
  end
end

--- True when DCS reported any of the element's units lost.
---
--- The element's own `dcsName` is checked alongside its units'. For a SAM site that name is a *group*
--- name, which will not normally appear in a set keyed on unit names; when it does collide the
--- element is treated as destroyed and therefore **kept**, which is the behaviour that shipped before
--- the sweep existed — so the collision costs a stale entry, never a site removed by mistake.
local function _wasReportedLost(skynetElement)
  if skynetElement.dcsName and veafSkynet.lostUnits[skynetElement.dcsName] then
    return true
  end
  -- Named one by one rather than iterated as a literal table: any of the three can be nil on an
  -- element Skynet never completed, and a nil inside a table constructor makes `pairs` unreliable.
  local lists = { skynetElement.searchRadars, skynetElement.trackingRadars, skynetElement.launchers }
  for i = 1, 3 do
    local units = lists[i]
    if units then
      for j = 1, #units do
        if units[j].dcsName and veafSkynet.lostUnits[units[j].dcsName] then
          return true
        end
      end
    end
  end
  return false
end

--- Remove from one list every element whose DCS object is gone and that nothing reported lost.
--- Walked backwards because `removeSkynetElement` removes from the very list being iterated.
--- @return number how many were removed
local function _sweepSkynetElements(network, elements)
  if not elements then
    return 0
  end
  local removed = 0
  for i = #elements, 1, -1 do
    local skynetElement = elements[i]
    if skynetElement and not veafSkynet.dcsObjectStillExists(skynetElement.dcsRepresentation) then
      if _wasReportedLost(skynetElement) then
        veaf.loggers.get(veafSkynet.Id):trace("keeping destroyed element [%s], it was shot", veaf.lp(tostring(skynetElement.dcsName)))
      else
        veaf.loggers.get(veafSkynet.Id):debug("removing despawned element [%s] from the network", veaf.lp(tostring(skynetElement.dcsName)))
        veafSkynet.removeSkynetElement(skynetElement, network)
        removed = removed + 1
      end
    end
  end
  return removed
end

--- Drop the sites of one network whose group was despawned rather than destroyed.
---
--- **Why not simply "every site whose object is gone".** Skynet is *meant* to keep the sites the
--- player destroyed: `Raddest` for SAM sites and `Destroyed:` for early-warning radars are the SEAD
--- readout, and a mission maker watching an IADS come apart wants to read `EW: 6 | Destroyed: 4`, not
--- `EW: 2 | Destroyed: 0`. Removing a kill would delete that.
---
--- And a kill cannot be told from a despawn by looking at the object: both answer
--- `isExist() == false` and both make `SkynetIADSSamSite:isDestroyed()` true. What separates them is
--- the **event** — DCS raises `S_EVENT_DEAD` / `S_EVENT_UNIT_LOST` for a unit that was killed and
--- nothing at all for one a script removed. Hence `veafSkynet.lostUnits`, and hence this sweep only
--- removes what nobody ever reported losing.
---
--- What it exists for: a combat zone being deactivated takes its air defences with it, and the sites
--- stayed in the network for the rest of the mission — inflating the status page, walked on every
--- contact-evaluation cycle, and holding their group name against a respawn, since
--- `addGroupToNetwork` refuses a name the network already lists (#946).
---
--- @param networkName string
--- @return number how many elements were removed
function veafSkynet.removeVanishedSites(networkName)
  local network = veafSkynet.getNetwork(networkName)
  if not network or not network.iads then
    veaf.loggers.get(veafSkynet.Id):trace("removeVanishedSites: no IADS for network %s", veaf.lp(networkName))
    return 0
  end

  local removed = _sweepSkynetElements(network, network.iads.samSites) + _sweepSkynetElements(network, network.iads.earlyWarningRadars)
  if removed > 0 then
    veaf.loggers.get(veafSkynet.Id):info("network %s: removed %s despawned element(s)", veaf.lp(networkName), veaf.lp(removed))
    -- The parent/child radar graph is built once, when the network activates, and a removal used to
    -- leave the departed element listed as a **child** of everything that could see it. Measured on
    -- Tripack's log of 2026-09-09 at 10:03:13: three sites destroyed by command and one swept, and the
    -- EW radar still announced `SAM SITES IN COVERED AREA: 5`, naming four elements no longer in the
    -- network - which `informChildrenOfStateChange` then went on commanding, cleaned up as they were.
    -- Once per sweep that removed something, not once per element.
    veafSkynet.rebuildRadarCoverage(networkName)
  end
  return removed
end

--- Sweep every network. This is what the periodic schedule calls.
function veafSkynet.sweepVanishedSites()
  for networkName, _ in pairs(veafSkynet.structure) do
    veafSkynet.removeVanishedSites(networkName)
  end
end

--- Rebuild a network's parent/child radar graph.
---
--- `SkynetIADS:buildRadarCoverage` is the whole graph at once, which is what activation runs. Called
--- through `pcall` because the callers reach it right after elements have left the network, and an
--- element Skynet has cleaned up can refuse a method.
---
--- @param networkName string
--- @return boolean true when the coverage was rebuilt
function veafSkynet.rebuildRadarCoverage(networkName)
  local network = veafSkynet.getNetwork(networkName)
  if not network or not network.iads or not network.iads.buildRadarCoverage then
    veaf.loggers.get(veafSkynet.Id):trace("rebuildRadarCoverage: no IADS for network %s", veaf.lp(networkName))
    return false
  end
  local ok, err = pcall(network.iads.buildRadarCoverage, network.iads)
  if not ok then
    veaf.loggers.get(veafSkynet.Id):warn("network %s: rebuilding the radar coverage raised: %s", veaf.lp(networkName), veaf.lp(err))
    return false
  end
  veaf.loggers.get(veafSkynet.Id):trace("network %s: radar coverage rebuilt", veaf.lp(networkName))
  return true
end

--- The widest detection range this element's radars report, and the counts behind that number.
---
--- Skynet reads a radar's range in `SkynetIADSSAMSearchRadar:setupRangeData`, called from
--- `buildSingleUnit` at the instant the element is built (`skynet-iads-compiled.lua`), out of
--- `getSensors()`. The value lands in `maximumRange` and **nothing reads the sensors again**. When
--- that one answer is `nil`, the range stays 0 for the rest of the mission: the site detects nothing,
--- never goes live however close a player flies, and every status page counts it under `Raddest`,
--- since `isRadarWorking()` goes through `getSensors()` too and a search radar carrying no
--- ammunition gets nothing from the `getAmmo()` fallback either. One unread field, both of the
--- symptoms Tripack reported (#946).
---
--- @param skynetElement table|nil a Skynet SAM site or EW radar
--- @return number maxRange the widest range reported, 0 when no radar reported one
--- @return number radarCount how many radars the element holds
--- @return number liveRadarCount how many of those DCS still holds
function veafSkynet.measureRadarRange(skynetElement)
  local maxRange, radarCount, liveRadarCount = 0, 0, 0
  if not skynetElement or not skynetElement.getRadars then
    return maxRange, radarCount, liveRadarCount
  end
  local ok, radars = pcall(skynetElement.getRadars, skynetElement)
  if not ok or type(radars) ~= "table" then
    return maxRange, radarCount, liveRadarCount
  end
  for _, radar in pairs(radars) do
    radarCount = radarCount + 1
    if radar.getDCSRepresentation and veafSkynet.dcsObjectStillExists(radar:getDCSRepresentation()) then
      liveRadarCount = liveRadarCount + 1
    end
    if radar.getMaxRangeFindingTarget then
      local range = radar:getMaxRangeFindingTarget()
      if type(range) == "number" and range > maxRange then
        maxRange = range
      end
    end
  end
  return maxRange, radarCount, liveRadarCount
end

--- The element's own DCS handle, or nil, without ever raising.
local function _dcsRepresentationOf(skynetElement)
  if not skynetElement or not skynetElement.getDCSRepresentation then
    return nil
  end
  local ok, dcsRepresentation = pcall(skynetElement.getDCSRepresentation, skynetElement)
  return ok and dcsRepresentation or nil
end

--- Read the range data again for an element whose radars all reported nothing, and rebuild the
--- coverage as soon as one of them answers.
---
--- Re-reading **is** the repair: why DCS hands back a nil `getSensors()` for a radar unit it still
--- holds is not observable from a log, so the dependency on that one reading being lucky is removed
--- rather than explained. `setupRangeData` only reads DCS and assigns a number, so asking again is
--- safe and idempotent.
---
--- @param networkName string
--- @param skynetElement table
--- @param attemptsLeft number
function veafSkynet.recheckRadarRange(networkName, skynetElement, attemptsLeft)
  if not veafSkynet.dcsObjectStillExists(_dcsRepresentationOf(skynetElement)) then
    return
  end

  local _, _, liveRadarCount = veafSkynet.measureRadarRange(skynetElement)
  if liveRadarCount == 0 then
    -- Nothing left to ask. An element whose radars have all left the mission is the sweep's business,
    -- not this function's.
    return
  end

  local ok, radars = pcall(skynetElement.getRadars, skynetElement)
  if ok and type(radars) == "table" then
    for _, radar in pairs(radars) do
      if radar.setupRangeData then
        pcall(radar.setupRangeData, radar)
      end
    end
  end

  local elementName = veafSkynet.safeDcsName(_dcsRepresentationOf(skynetElement))
  local maxRange = veafSkynet.measureRadarRange(skynetElement)
  if maxRange > 0 then
    veaf.loggers
      .get(veafSkynet.Id)
      :info("RADAR RANGE RECOVERED [%s]: %s m on re-read, rebuilding the coverage", veaf.lp(elementName), veaf.lp(maxRange))
    -- Without this the number would be right and unused: the parent/child graph was built while the
    -- range was still zero, so the site would go on seeing nobody.
    veafSkynet.rebuildRadarCoverage(networkName)
    return
  end

  if attemptsLeft > 1 then
    veaf.scheduleFunction(
      veafSkynet.recheckRadarRange,
      { networkName, skynetElement, attemptsLeft - 1 },
      timer.getTime() + veafSkynet.DelayForRangeRecheck
    )
  else
    veaf.loggers.get(veafSkynet.Id):info(
      "RADAR RANGE STILL ZERO [%s]: %s re-read(s) asked, DCS reports no sensor range",
      veaf.lp(elementName),
      veaf.lp(veafSkynet.MaxRangeRechecks)
    )
  end
end

--- Check what an element's radars reported when it joined a network, and schedule a re-read when the
--- answer was "nothing".
---
--- Silent at `info` on the healthy case — one line per **faulty** element, not one per element, so a
--- mission carrying sixty batteries does not pay for this. `info` rather than `debug` for the reason
--- the previous lot recorded: the default level is `info` (`veaf.BaseLogLevel = 3` in veaf.lua) and no
--- shipped mission raises it, so a `debug` line would be invisible exactly where it is needed. The
--- counts belong in the line: they separate "the radar unit is not there" from "it is there and
--- silent" from "it has left the mission", which is what will name the DCS-side cause this repository
--- cannot measure on its own.
---
--- @param networkName string
--- @param skynetElement table|nil
function veafSkynet.checkRadarRange(networkName, skynetElement)
  if not skynetElement then
    return
  end
  local maxRange, radarCount, liveRadarCount = veafSkynet.measureRadarRange(skynetElement)
  local elementName = veafSkynet.safeDcsName(_dcsRepresentationOf(skynetElement))
  if maxRange > 0 then
    veaf.loggers
      .get(veafSkynet.Id)
      :debug("RADAR RANGE [%s]: %s m from %s radar(s)", veaf.lp(elementName), veaf.lp(maxRange), veaf.lp(radarCount))
    return
  end
  veaf.loggers.get(veafSkynet.Id):info(
    "RADAR RANGE ZERO [%s]: radars=%s live=%s launchers=%s - the site detects nothing, re-reading in %s s",
    veaf.lp(elementName),
    veaf.lp(radarCount),
    veaf.lp(liveRadarCount),
    veaf.lp(skynetElement.launchers and #skynetElement.launchers or 0),
    veaf.lp(veafSkynet.DelayForRangeRecheck)
  )
  -- `MaxRangeRechecks` is a mission-settable number, so zero has to mean zero rather than one.
  if liveRadarCount > 0 and veafSkynet.MaxRangeRechecks > 0 then
    veaf.scheduleFunction(
      veafSkynet.recheckRadarRange,
      { networkName, skynetElement, veafSkynet.MaxRangeRechecks },
      timer.getTime() + veafSkynet.DelayForRangeRecheck
    )
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- core functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- get the IADS network for a given name ("blue iads", "red iads"")
function veafSkynet.getNetwork(networkName)
  local network = nil
  if networkName then
    network = veafSkynet.structure[networkName]
  end
  return network
end

-- get the IADS object for a given name ("blue iads", "red iads"")
function veafSkynet.getIADS(networkName)
  local iads = nil
  local network = veafSkynet.getNetwork(networkName)
  if network then
    iads = network.iads
  end
  return iads
end

-- calling SkynetIADS:activate() after a delay, to avoid calling it at each time a group is added to the IADS
function veafSkynet.delayedActivate(networkName)
  veaf.loggers.get(veafSkynet.Id):debug("veafSkynet.delayedActivate(%s)", veaf.lp(networkName))
  local network = veafSkynet.structure[networkName]
  if network then
    -- #261: a network switched off on purpose must stay off. Adding a group to it used to schedule an
    -- activation unconditionally, so any spawn integrated into a deactivated network woke it back up.
    -- Only a deliberate call to veafSkynet.activateNetwork (or a full reinitialisation) clears this.
    if network.deactivated then
      veaf.loggers.get(veafSkynet.Id):debug(string.format("IADS %s was deactivated on purpose, not activating it", veaf.p(networkName)))
      return
    end
    if network.delayedActivation then
      veaf.loggers.get(veafSkynet.Id):trace(string.format("IADS %s already has a delayed activation", veaf.p(networkName)))
    else
      veaf.loggers
        .get(veafSkynet.Id)
        :trace(string.format("IADS %s will be activated in %d seconds", veaf.p(networkName), veafSkynet.DelayForRestart))
      network.delayedActivation =
        veaf.scheduleFunction(veafSkynet._activateIADS, { networkName }, timer.getTime() + veafSkynet.DelayForRestart)
    end
  end
end

function veafSkynet._activateIADS(networkName)
  veaf.loggers.get(veafSkynet.Id):debug("veafSkynet._activateIADS(%s)", veaf.lp(networkName))

  local network = veafSkynet.structure[networkName]
  if network then
    network.delayedActivation = nil
    -- #261, belt to delayedActivate's braces: an activation scheduled *before* the network was
    -- deactivated must not fire after it. Checked here too, since the schedule is already pending.
    if network.deactivated then
      veaf.loggers
        .get(veafSkynet.Id)
        :debug(string.format("IADS %s was deactivated on purpose, dropping the pending activation", veaf.p(networkName)))
      return
    end
    local iads = network.iads
    if iads then
      veaf.loggers.get(veafSkynet.Id):debug("calling iads:activate()")
      iads:activate()
    end
  end
end

function veafSkynet.getIadsOfCoalition(networkName, coa)
  local iads = nil
  if veafSkynet.structure[networkName] and coa == veafSkynet.structure[networkName].coalitionID then
    iads = veafSkynet.structure[networkName].iads
  end
  return iads
end

function veafSkynet.getNearestIADSSite(networkName, dcsGroup)
  if not dcsGroup then
    veaf.loggers.get(veafSkynet.Id):trace("No group to find the nearest IADS site for")
    return false
  end

  local coa = dcsGroup:getCoalition()
  veaf.loggers.get(veafSkynet.Id):trace(string.format("Ref coalition : %s", veaf.p(coa)))

  local iads = veafSkynet.getIadsOfCoalition(networkName, coa)
  if not iads then
    veaf.loggers.get(veafSkynet.Id):trace(
      string.format("IADS named %s for the coalition of the group %s does not exist", veaf.p(networkName), tostring(dcsGroup:getName()))
    )
    return false
  end

  local currentGroup = dcsGroup:getName()
  veaf.loggers.get(veafSkynet.Id):trace(string.format("networkName : %s", veaf.p(networkName)))
  local groupPos = veaf.getAveragePosition(dcsGroup)
  veaf.loggers.get(veafSkynet.Id):debug(string.format("Ref Position : %s", veaf.p(groupPos)))

  local nearestEWRname = nil
  local minEWRDistance = veafSkynet.MaxPointDefenseDistanceFromSite
  local nearestSAMname = nil
  local minSAMDistance = veafSkynet.MaxPointDefenseDistanceFromSite

  local CoalitionSites = nil

  local searchForGroup = function(CoalitionSites, pos, currentGroupName, ewrFlag)
    local minDistance = veafSkynet.MaxPointDefenseDistanceFromSite
    local FoundGroup = nil

    for site, site_info in pairs(CoalitionSites) do
      local site_name = site_info.dcsName -- For EWRs it looks like this gives the unit's name which would need to be reversed to the group to get position data
      veaf.loggers.get(veafSkynet.Id):trace(string.format("Checked Site groupName : %s and isEWR : %s", veaf.p(site_name), veaf.p(ewrFlag)))

      if site_name and currentGroupName ~= site_name then
        if ewrFlag then
          -- An EWR is registered by *unit* name, so its group has to be resolved from the unit. Neither
          -- end of that chain was checked, and Skynet's register outlives the units in it: a radar
          -- destroyed since the network was built -- the very thing this search walks over -- took the
          -- whole point-defence search down on `Unit.getGroup(nil)`.
          local unit = Unit.getByName(site_name)
          local group = unit and unit:getGroup()
          if group then
            site_name = group:getName()
          else
            veaf.loggers
              .get(veafSkynet.Id)
              :warn(string.format("searchForGroup: the EWR unit [%s] is gone from DCS ; it is skipped", veaf.p(site_name)))
            site_name = nil
          end
        end
        veaf.loggers.get(veafSkynet.Id):trace(string.format("Checked Site groupName : %s", veaf.p(site_name)))

        -- A skipped EWR leaves `site_name` nil, and `getAveragePosition` answers nil for it, so the
        -- site falls out of the search at the `if groupAvgPosition` below.
        local groupAvgPosition = site_name and veaf.getAveragePosition(site_name)
        veaf.loggers.get(veafSkynet.Id):debug(string.format("Checked Site groupAvgPosition : %s", veaf.p(groupAvgPosition)))

        if groupAvgPosition then
          local distance = math.sqrt((pos.x - groupAvgPosition.x) ^ 2 + (pos.z - groupAvgPosition.z) ^ 2)
          veaf.loggers.get(veafSkynet.Id):trace(string.format("Distance between checked site and pointDefense : %s", veaf.p(distance)))

          if distance <= minDistance then
            veaf.loggers.get(veafSkynet.Id):trace("This site is closer")
            FoundGroup = site_name
            minDistance = distance
          end
        end
      end
    end

    return FoundGroup, minDistance
  end

  --start by going through the EWRs
  CoalitionSites = iads:getEarlyWarningRadars()
  nearestEWRname, minEWRDistance = searchForGroup(CoalitionSites, groupPos, currentGroup, true)

  --search for SAM sites
  CoalitionSites = iads:getSAMSites()
  nearestSAMname, minSAMDistance = searchForGroup(CoalitionSites, groupPos, currentGroup)

  if minEWRDistance <= minSAMDistance then
    return nearestEWRname
  end
  return nearestSAMname
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Management of point defences (Flogas)
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafSkynet.canBePointDefence(skynetData)
  if skynetData == nil then
    return false
  end
  if skynetData["can_engage_harm"] ~= true then
    return false
  end
  if skynetData["type"] ~= "complex" and skynetData["type"] ~= "single" then
    return false
  end

  return true
end

function veafSkynet.findSkynetElementToDefend(skynetElementPointDefence, skynetDataPointDefence)
  local dcsGroupPointDefence = veafSkynet.getDcsGroupFromSkynetElement(skynetElementPointDefence)
  local iads = skynetElementPointDefence.iads
  local pointDefenceType = skynetDataPointDefence["type"]

  local pointDefencePosition = veaf.getAveragePosition(dcsGroupPointDefence)
  if pointDefencePosition == nil then
    return nil
  end

  local function findClosestSkynetElementInList(skynetElementList)
    if skynetElementList == nil or #skynetElementList <= 0 then
      return nil
    end

    local iMinDistance = veafSkynet.MaxPointDefenseDistanceFromSite
    local foundElement
    for i = 1, #skynetElementList do
      local skynetElement = skynetElementList[i]
      local skynetData = veafSkynet.getSkynetData(skynetElement)
      if skynetData and (skynetData["type"] == "ewr" or (skynetData["type"] == "complex" and pointDefenceType == "single")) then
        -- ewr are always defencible, and complex sam sites only defencible by single groups
        local dcsGroup = veafSkynet.getDcsGroupFromSkynetElement(skynetElementList[i])
        local position = veaf.getAveragePosition(dcsGroup)

        -- FEAT-COMBAT-EFFECTIVE-ADOPTION: do not spend a point defence on a **SAM site** that cannot
        -- fight any more. An S-300 whose tracking radar is gone still has launchers, a position and an
        -- entry in the IADS, so without this a Tor could guard it for a whole mission while a live site
        -- next door goes undefended.
        --
        -- **Early-warning radars are exempt, and not out of caution.** An EWR is defended because it
        -- *sees*, not because it shoots, so asking "can this still fight" about one is a category error —
        -- the comment above has always said they are always defencible. Judging them would also have made
        -- a **mixed group** — a mission maker putting a 55G6 and a launcher in one group — lose its
        -- defence silently, since such a group carries `SAM LL` with no tracking radar. Caught in review
        -- (Sourcery, PR #788), and it also removes this code's dependence on no EWR type ever gaining a
        -- SAM attribute in a datamine update.
        if position and skynetData["type"] ~= "ewr" and not veaf.isGroupCombatEffective(dcsGroup) then
          veaf.loggers.get(veafSkynet.Id):trace("skipping a SAM site that can no longer fight")
          position = nil
        end

        if position then
          local iDistance = math.sqrt((position.x - pointDefencePosition.x) ^ 2 + (position.z - pointDefencePosition.z) ^ 2)

          if iDistance < iMinDistance then
            foundElement = skynetElement
            iMinDistance = iDistance
          end
        end
      end
    end

    return foundElement
  end

  local elementToDefend = findClosestSkynetElementInList(iads:getEarlyWarningRadars())
  if elementToDefend == nil and pointDefenceType == "single" then
    elementToDefend = findClosestSkynetElementInList(iads:getSAMSites())
  end

  if elementToDefend then
    local sDescriptorPointDefence = veafSkynet.getStringSkynetElement(skynetElementPointDefence)
    local sDescriptorToDefend = veafSkynet.getStringSkynetElement(elementToDefend)
    veaf.loggers
      .get(veafSkynet.Id)
      :trace("Identified [ " .. sDescriptorToDefend .. " ] to be defended by [ " .. sDescriptorPointDefence .. " ]")
  end

  return elementToDefend
end

function veafSkynet.removePointDefencesFromSkynetElement(skynetElement)
  if skynetElement and skynetElement.pointDefences and #skynetElement.pointDefences > 0 then
    for i = 1, #skynetElement.pointDefences do
      skynetElement.pointDefences[i]:setIsAPointDefence(false)
    end
    skynetElement.pointDefences = {}
  end

  skynetElement.pointDefences = {}
end

function veafSkynet.removePointDefences(iads)
  -- not tested
  local ewrs = iads:getEarlyWarningRadars()
  if ewrs and #ewrs > 0 then
    for i = 1, #ewrs do
      veafSkynet.removePointDefencesFromSkynetElement(ewrs[i])
    end
  end
  local samSites = iads:getSAMSites()
  if samSites and #samSites > 0 then
    for i = 1, #samSites do
      veafSkynet.removePointDefencesFromSkynetElement(samSites[i])
    end
  end
end

function veafSkynet.initializePointDefenceSamSite(samSite, veafSkynetNetwork)
  if samSite:getIsAPointDefence() then
    return
  end

  local skynetData = veafSkynet.getSkynetData(samSite)
  if not veafSkynet.canBePointDefence(skynetData) then
    return
  end

  local elementToDefend = veafSkynet.findSkynetElementToDefend(samSite, skynetData)
  if elementToDefend then
    if veafSkynet.PointDefenceMode == veafSkynet.PointDefenceModes.Skynet then
      veaf.loggers.get(veafSkynet.Id):debug("Point defence: add as skynet")
      elementToDefend:addPointDefence(samSite)
    elseif veafSkynet.PointDefenceMode == veafSkynet.PointDefenceModes.Dcs then
      veaf.loggers.get(veafSkynet.Id):debug("Point defence: add as dcs")
      veafSkynet.removeSkynetElement(samSite, veafSkynetNetwork)
    end
  end
end

function veafSkynet.initializePointDefences(veafSkynetNetwork)
  if
    veafSkynet.PointDefenceMode ~= veafSkynet.PointDefenceModes.Skynet and veafSkynet.PointDefenceMode ~= veafSkynet.PointDefenceModes.Dcs
  then
    return
  end

  veaf.loggers.get(veafSkynet.Id):debug("Analyzing network to create point defences")

  local iads = veafSkynetNetwork.iads
  local samSites = iads:getSAMSites()
  if samSites and #samSites > 0 then
    for i = 1, #samSites do
      veafSkynet.initializePointDefenceSamSite(samSites[i], veafSkynetNetwork)
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Management of dynamic group spawns (Flogas)
-- Option to integrate late spawned units into the existing networks
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The birth-event handler while dynamic-spawn monitoring is on, nil while it is off.
---
--- `world.addEventHandler` takes a table with an `onEvent` method, where MiST's wrapper took a
--- plain function and answered a numeric id. The wrapper is one line here, and it keeps the
--- handler removable — which `veafEventHandler` is not: it registers callbacks and never drops
--- one, and this handler is armed and disarmed as networks come and go. `veafMissileGuardian`
--- already registers with `world.*` for the same reason.
veafSkynet.monitorDynamicSpawnHandler = nil

-- Record what a veafSpawn command asked for, so the birth-event handler can honour the per-spawn
-- `skynet` option. The group name is only known once the spawn handler returns, hence
-- veafSkynet.DelayForDynamicIntegration: the declaration may land after the birth event.
-- `skynetOption` is what the parser produced: false, true, or a network name.
function veafSkynet.declareSpawn(groupName, skynetOption)
  if not groupName then
    return
  end
  if skynetOption == nil or skynetOption == true then
    -- nothing to override: `true` means "the coalition's default network", which is what the
    -- dynamic-spawn handler does on its own.
    return
  end
  veaf.loggers.get(veafSkynet.Id):trace("declareSpawn(%s, %s)", veaf.p(groupName), veaf.p(skynetOption))
  veafSkynet.declaredSpawns[groupName] = skynetOption
end

-- Does this network integrate groups spawned during the mission on its own? Callers use this to know
-- whether they must integrate a group themselves or leave it to the birth-event handler — doing both
-- would integrate it twice. An unknown network answers false, so a spawn targeting a network that does
-- not exist still takes the explicit path and reports its failure to the player.
function veafSkynet.integratesDynamicSpawns(networkName)
  local network = veafSkynet.getNetwork(networkName)
  return (network ~= nil) and (network.dynamicSpawn == true)
end

-- Which network a dynamically spawned group should join, honouring what the spawn declared.
-- Returns nil when the group must stay out of every network.
function veafSkynet.resolveDynamicSpawnNetwork(groupName, coalitionId)
  local declared = veafSkynet.declaredSpawns[groupName]
  if declared ~= nil then
    veafSkynet.declaredSpawns[groupName] = nil -- consumed
    if declared == false then
      veaf.loggers
        .get(veafSkynet.Id)
        :debug(string.format("group %s was spawned with `skynet false`, keeping it out of the IADS", veaf.p(groupName)))
      return nil
    end
    return declared -- an explicit network name wins over the coalition default
  end

  -- Nobody declared this group: it comes from the Mission Editor or a third-party script, which is
  -- exactly what dynamic spawn integration is for.
  return veafSkynet.defaultIADS[tostring(coalitionId)]
end

--- Integrate one spawned group into its network.
---
--- `requireDynamicSpawn` is what separates the two callers. The birth-event handler sees **every**
--- eligible group DCS reports, including whatever a third-party script spawns, so it must honour the
--- network's `dynamicSpawn` flag. A mission feature respawning content the mission author placed on
--- the map is not in that category — see veafSkynet.integrateMissionSpawn.
---
--- @param groupName string
--- @param coalitionId number
--- @param requireDynamicSpawn boolean
function veafSkynet._integrateSpawn(groupName, coalitionId, requireDynamicSpawn)
  local dcsGroup = Group.getByName(groupName)
  if not dcsGroup then
    veaf.loggers.get(veafSkynet.Id):trace(string.format("group %s no longer exists, not integrating it", veaf.p(groupName)))
    veafSkynet.declaredSpawns[groupName] = nil
    return
  end

  local networkName = veafSkynet.resolveDynamicSpawnNetwork(groupName, coalitionId)
  if not networkName then
    return
  end

  local network = veafSkynet.getNetwork(networkName)
  if not network then
    veaf.loggers
      .get(veafSkynet.Id)
      :debug(string.format("no IADS network named %s to integrate %s into", veaf.p(networkName), veaf.p(groupName)))
    return
  end
  -- #261: the flag is per network, so one coalition switching dynamic integration off leaves the
  -- other one working.
  if requireDynamicSpawn and not network.dynamicSpawn then
    veaf.loggers.get(veafSkynet.Id):trace(string.format("network %s does not integrate dynamically spawned groups", veaf.p(networkName)))
    return
  end

  veaf.loggers
    .get(veafSkynet.Id)
    :debug(string.format("DYNAMIC SPAWN adding spawned group [%s] to IADS network [%s]", groupName, networkName))
  if veafSkynet.addGroupToNetwork(networkName, dcsGroup, false, false) then
    veafSkynet.initializePointDefences(network)
    --iads:buildRadarCoverage()
  end
end

function veafSkynet._integrateDynamicSpawn(groupName, coalitionId)
  veafSkynet._integrateSpawn(groupName, coalitionId, true)
end

--- Integrate a group a mission feature has just respawned into its coalition's default network,
--- whether or not that network integrates dynamic spawns.
---
--- What this exists for: a combat zone respawns its groups through `VeafGroupSpawn:respawn()` ->
--- `veafDcsSpawner.addGroup` -> `coalition.addGroup`, and no link in that chain knows Skynet exists.
--- The only catch-all is the birth-event handler, which is armed only when a network carries
--- `dynamicSpawn == true` — off by default. So the sweep #946 added removed a zone's air defences
--- when the zone was switched off, and nothing put them back: on a mission that cycles its zones, the
--- IADS drained as the mission ran.
---
--- Why not simply require `dynamic_spawn` here, which FIX-SKYNET-DYNAMICSPAWN-SCOPE established as
--- the documented way to integrate mid-mission spawns: `veafSkynet.loadAllAtInit` is true for both
--- coalitions, so the start-up enrolment already takes an active zone's batteries **without** that
--- flag. The same site would be in the network at second one and out of it at second sixty under one
--- configuration, which no mission maker can read as an option.
---
--- The coalition is read from the group rather than passed in, so a caller holding a country id
--- cannot get it wrong. Integrating twice is not a risk: `addGroupToNetwork` refuses a group the
--- network already lists.
---
--- @param groupName string|nil
function veafSkynet.integrateMissionSpawn(groupName)
  if not groupName or not veafSkynet.initialized then
    return
  end
  local dcsGroup = Group.getByName(groupName)
  if not veafSkynet.dcsObjectStillExists(dcsGroup) then
    veaf.loggers.get(veafSkynet.Id):trace(string.format("group %s does not exist, not integrating it", veaf.p(groupName)))
    return
  end
  local coalitionId = dcsGroup:getCoalition()
  -- Deferred like the birth-event path, and for the same reason: veafSpawn declares a spawn's
  -- `skynet` option once its handler has returned a group name, which can be after this call.
  veaf.scheduleFunction(
    veafSkynet._integrateSpawn,
    { groupName, coalitionId, false },
    timer.getTime() + veafSkynet.DelayForDynamicIntegration
  )
end

function veafSkynet.OnDynamicSpawn(event)
  if not veafSkynet.initialized then
    return
  end
  if event.id ~= world.event.S_EVENT_BIRTH then
    return
  end
  if event.initiator == nil or Object.getCategory(event.initiator) ~= Object.Category.UNIT then
    return
  end

  -- birth event will be triggered for each unit of a spawned group, but we want to manage the group, so we only work for for the first unit
  local dcsGroup = Unit.getGroup(event.initiator)
  local firstDcsUnit = dcsGroup:getUnit(1)
  if firstDcsUnit == nil then
    return
  end
  if firstDcsUnit:getID() ~= event.initiator:getID() then
    return
  end

  local coalitionId = dcsGroup:getCoalition()
  if not veafSkynet.defaultIADS[tostring(coalitionId)] then
    veaf.loggers.get(veafSkynet.Id):error("No default IADS network for coalition " .. tostring(coalitionId))
    return
  end

  -- Deferred on purpose: veafSpawn can only declare the spawn's `skynet` option once its handler has
  -- returned a group name, which may be after DCS emits the birth event. Deciding here would race it.
  local groupName = dcsGroup:getName()
  veaf.scheduleFunction(
    veafSkynet._integrateDynamicSpawn,
    { groupName, coalitionId },
    timer.getTime() + veafSkynet.DelayForDynamicIntegration
  )
end

function veafSkynet.monitorDynamicSpawn(bMonitor)
  if bMonitor then
    if veafSkynet.monitorDynamicSpawnHandler ~= nil then
      return -- already active
    end
    veaf.loggers.get(veafSkynet.Id):debug("DYNAMIC SPAWN monitoring ON")
    veafSkynet.monitorDynamicSpawnHandler = {
      onEvent = function(_, event)
        veafSkynet.OnDynamicSpawn(event)
      end,
    }
    world.addEventHandler(veafSkynet.monitorDynamicSpawnHandler)
  else
    if veafSkynet.monitorDynamicSpawnHandler == nil then
      return -- already inactive
    end
    veaf.loggers.get(veafSkynet.Id):debug("DYNAMIC SPAWN monitoring OFF")
    world.removeEventHandler(veafSkynet.monitorDynamicSpawnHandler)
    veafSkynet.monitorDynamicSpawnHandler = nil
  end
end

-- Arm the birth-event handler if *any* network integrates dynamic spawns, disarm it when none does.
-- The handler is shared by every network, so it can only be removed once nobody wants it — which is
-- why deactivating a single network must not call monitorDynamicSpawn(false) directly (#261).
function veafSkynet.refreshDynamicSpawnMonitoring()
  local wanted = false
  for _, network in pairs(veafSkynet.structure) do
    if network.dynamicSpawn then
      wanted = true
      break
    end
  end
  veafSkynet.monitorDynamicSpawn(wanted)
end

-- Turn dynamic spawn integration on or off for one network.
function veafSkynet.setDynamicSpawn(networkName, bEnabled)
  local network = veafSkynet.getNetwork(networkName)
  if not network then
    veaf.loggers.get(veafSkynet.Id):debug(string.format("no IADS network named %s", veaf.p(networkName)))
    return false
  end
  network.dynamicSpawn = bEnabled and true or false
  veaf.loggers.get(veafSkynet.Id):debug(string.format("network %s dynamicSpawn=%s", veaf.p(networkName), veaf.p(network.dynamicSpawn)))
  veafSkynet.refreshDynamicSpawnMonitoring()
  return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafSkynet.isGroupUsable(dcsGroup)
  if veafSkynet.GroupIntegrationMode == veafSkynet.GroupIntegrationModes.Strict then
    for _, dcsUnit in pairs(dcsGroup:getUnits()) do
      local dcsUnitType = dcsUnit:getTypeName()
      if not veafSkynet.iadsEwrUnitsTypes[dcsUnitType] and not veafSkynet.iadsSamUnitsTypes[dcsUnitType] then
        return false
      end
    end

    return true
  else
    for _, dcsUnit in pairs(dcsGroup:getUnits()) do
      local dcsUnitType = dcsUnit:getTypeName()
      if veafSkynet.iadsEwrUnitsTypes[dcsUnitType] or veafSkynet.iadsSamUnitsTypes[dcsUnitType] then
        return true
      end
    end

    return false
  end
end

function veafSkynet.addGroupToNetwork(networkName, dcsGroup, forceEwr, pointDefense, alreadyAddedGroups, silent)
  -- Both guards precede the first dereference, which is where the `nil` one always belonged: it used
  -- to sit *below* the `dcsGroup:getName()` of the log line, so it could never fire — a nil group
  -- raised instead of being refused.
  if not dcsGroup then
    veaf.loggers.get(veafSkynet.Id):error("No group to find to add to network")
    return false
  end

  -- #946: this is the single door every caller goes through — the start-up enrolment walking
  -- `coalition.getGroups`, the birth-event handler, the radio menu and the `_skynet` markers — so it
  -- is where the "DCS still lists what it destroyed" check belongs. See
  -- `veafSkynet.dcsObjectStillExists`.
  --
  -- `info`, not `debug`, and not `error` either. Not error, because a group that died before its
  -- deferred integration ran is ordinary mission life. But not debug: the default log level is
  -- `info` (`veaf.BaseLogLevel = 3` in veaf.lua) and no shipped mission raises it, so a debug line
  -- would be invisible exactly where it is needed. The whole reason this defect reached a bug report
  -- is that nothing anywhere said a word about it — sixteen sites enrolled dead, in silence. One
  -- line per refusal, naming the group, is what makes it readable in a log nobody had to configure.
  if not veafSkynet.dcsObjectStillExists(dcsGroup) then
    veaf.loggers
      .get(veafSkynet.Id)
      :info("ADD GROUP REFUSED [%s]: DCS no longer holds this group", veaf.lp(veafSkynet.safeDcsName(dcsGroup)))
    return false
  end

  veaf.loggers
    .get(veafSkynet.Id)
    :debug("ADD GROUP START [" .. dcsGroup:getName() .. "] [id=" .. dcsGroup:getID() .. "] to IADS network [" .. networkName .. "]")

  if not veafSkynet.isGroupUsable(dcsGroup) then
    veaf.loggers.get(veafSkynet.Id):trace("Group is not usable for skynet")
    return false
  end

  local forceEwr = false or forceEwr
  local pointDefense = false or pointDefense
  local silent = false or silent

  local batchMode = (alreadyAddedGroups ~= nil)
  local alreadyAddedGroups = alreadyAddedGroups or {}
  local groupName = dcsGroup:getName()
  local coa = dcsGroup:getCoalition()
  local iads = veafSkynet.getIadsOfCoalition(networkName, coa)
  if not iads then
    veaf.loggers
      .get(veafSkynet.Id)
      :debug(string.format("IADS named %s for the coalition of the group %s does not exist", veaf.p(networkName), tostring(groupName)))
    return false
  end
  local didSomething = false
  -- The element this call put in the network, kept past the unit loop so its radar range can be
  -- checked once the group is in (#946, second round). `addedSite` itself is per-unit.
  local addedElement = nil

  veaf.loggers
    .get(veafSkynet.Id)
    :trace(string.format("batchMode=%s forceEwr=%s PointDefense=%s", tostring(batchMode), tostring(forceEwr), tostring(pointDefense)))

  local defended_name = nil
  if pointDefense and not forceEwr then
    veaf.loggers.get(veafSkynet.Id):trace(string.format("SAM is requested as pointDefense"))

    if pointDefense == true then
      veaf.loggers.get(veafSkynet.Id):trace(string.format("Find nearest site to defend"))
      defended_name = veafSkynet.getNearestIADSSite(networkName, dcsGroup)
    else
      defended_name = pointDefense
      local defended_SAM = iads:getSAMSiteByGroupName(defended_name)
      -- VMR-024: this used to call `getEarlyWarningRadars(defended_name)`. Skynet's signature is
      -- `getEarlyWarningRadars()` — it takes **no argument** and returns *every* EWR as a table
      -- delegator, so the name was silently ignored and the result was always truthy. The lookup
      -- therefore never failed, and `defended_site` became the whole collection rather than the
      -- radar that was asked for.
      --
      -- `getEarlyWarningRadarByUnitName` is the accessor that does what the call meant: it matches
      -- on `getDCSName()`, exactly as `getSAMSiteByGroupName` does for SAM sites. The asymmetry in
      -- the two method names is Skynet's — a SAM site's DCS name is its group, an EWR's is its unit
      -- — so a `defended_name` naming a *group* whose EWR unit is named differently will now
      -- correctly find nothing instead of incorrectly finding everything.
      local defended_EWR = iads:getEarlyWarningRadarByUnitName(defended_name)

      local defended_site = defended_EWR
      if defended_SAM then
        defended_site = defended_SAM
      end

      if defended_site then
        local defended_pos = veaf.getAvgGroupPos(defended_name)
        local dcsGroup_pos = veaf.getAvgGroupPos(groupName)
        local distance = math.sqrt((dcsGroup_pos.x - defended_pos.x) ^ 2 + (dcsGroup_pos.z - defended_pos.z) ^ 2)
        veaf.loggers.get(veafSkynet.Id):trace(string.format("Distance between requested site and pointDefense : %s", veaf.p(distance)))

        if distance > veafSkynet.MaxPointDefenseDistanceFromSite then
          defended_name = nil
          veaf.loggers.get(veafSkynet.Id):info("User requested SAM Site out of reach for point defense")
        end
      else
        defended_name = nil
      end
    end
  end

  local dcsGroupName = dcsGroup:getName()

  for _, dcsUnit in pairs(dcsGroup:getUnits()) do
    local dcsUnitName = dcsUnit:getName()
    local dcsUnitType = dcsUnit:getTypeName()

    local addedSite = nil
    local sLog = string.format(
      " - iads[%s] unit[%s][%d][%s] group[%s][%d]",
      iads.name,
      dcsUnitName,
      dcsUnit:getID(),
      dcsUnitType,
      dcsGroupName,
      dcsGroup:getID()
    )

    if not veafSkynet.iadsEwrUnitsTypes[dcsUnitType] and not veafSkynet.iadsSamUnitsTypes[dcsUnitType] then
      veaf.loggers.get(veafSkynet.Id):trace(sLog .. " => unit type is not eligible for skynet")
    elseif alreadyAddedGroups[groupName] then
      veaf.loggers.get(veafSkynet.Id):trace(sLog .. " => group as already been marked as added by veafSkynet")
      break -- if group is added no need to go check the other units
    else
      local bShouldBeAdded = true
      local sams = iads:getSAMSites()
      for i = 1, #sams do
        local sam = sams[i]
        if sam.dcsName == dcsGroupName then
          veaf.loggers.get(veafSkynet.Id):trace(sLog .. " => already in network as SAM group")
          bShouldBeAdded = false
          break
        end
      end

      local ewrs = iads:getEarlyWarningRadars()
      for i = 1, #ewrs do
        local ewr = ewrs[i]
        local dcsGroupEwr = veafSkynet.getDcsGroupFromSkynetElement(ewr)

        if not dcsGroupEwr then
          veaf.loggers.get(veafSkynet.Id):trace(sLog .. " => group not found for skynet ewr " .. veafSkynet.getStringSkynetElement(ewr))
        elseif dcsGroupEwr:getName() == dcsGroupName then
          veaf.loggers.get(veafSkynet.Id):trace(sLog .. " => already in network as EWR group")
          bShouldBeAdded = false
          break
        end
      end

      if not bShouldBeAdded then
        break -- if group is added no need to go check the other units
      end

      if veafSkynet.iadsSamUnitsTypes[dcsUnitType] then
        local samsite = iads:addSAMSite(groupName)
        if samsite then
          addedSite = samsite
          didSomething = true
          alreadyAddedGroups[groupName] = true
          veaf.loggers.get(veafSkynet.Id):trace(sLog .. " => added as SAM")
        end
      end

      local ewrFlag = false
      if addedSite == nil and veafSkynet.iadsEwrUnitsTypes[dcsUnitType] then
        local ewr = iads:addEarlyWarningRadar(dcsUnitName)
        if ewr then
          addedSite = ewr
          didSomething = true
          ewrFlag = true
          veaf.loggers.get(veafSkynet.Id):trace(sLog .. " => added as EWR")
        end
      end

      --user requested configuration
      if addedSite and pointDefense and not forceEwr and not ewrFlag then
        if defended_name then
          local text = string.format("Point Defense added to site : %s", string.format(defended_name))
          veaf.loggers.get(veafSkynet.Id):info(text)
          if not silent then
            trigger.action.outText(text, 10)
          end
          if iads:getSAMSiteByGroupName(defended_name) then
            veaf.loggers.get(veafSkynet.Id):trace(string.format("adding pointDefense to SAM -> OK"))
            iads:getSAMSiteByGroupName(defended_name):addPointDefence(addedSite)
          else
            veaf.loggers.get(veafSkynet.Id):trace(string.format("adding pointDefense to EWR -> OK"))
            iads:getEarlyWarningRadars(defended_name):addPointDefence(addedSite)

            --confirm that the addition of point defenses to the EWR which is gathered through it's group name but only the unit name is stored in the structure
            --local site_info = iads:getEarlyWarningRadars(defended_name)
            --veaf.loggers.get(veafSkynet.Id):debug(string.format("Recovered EWR name : %s", veaf.p(site_info[1].dcsName)))
            --local pointDefenses = site_info[1].pointDefences
            --veaf.loggers.get(veafSkynet.Id):debug(string.format("Recover pointDefense name : %s", veaf.p(pointDefenses[#pointDefenses].dcsName)))
          end
        else
          veaf.loggers.get(veafSkynet.Id):info("Could not find SAM site within range to add point defenses to")
          if not silent then
            trigger.action.outText(veaf.t("skynet.no_sam_in_range"), 15)
          end
        end
      elseif forceEwr then
        veaf.loggers.get(veafSkynet.Id):trace(string.format("SAM/EWR is forced EWR"))

        if addedSite then
          veaf.loggers.get(veafSkynet.Id):trace("Unit Forced as EWR")
          addedSite:setActAsEW(true)
        end
      end

      if addedSite then
        addedElement = addedSite
        break -- if something has been added for this group no need to check the remaining units
      end
    end
  end

  if didSomething then
    if not batchMode and not forceEwr and not pointDefense then
      -- specific configurations, for each SAM type
      veaf.loggers.get(veafSkynet.Id):trace("Specific configuration applied")

      iads:getSAMSitesByNatoName("SA-10"):setActAsEW(false)
      iads:getSAMSitesByNatoName("SA-6"):setActAsEW(false)
      iads:getSAMSitesByNatoName("SA-5"):setActAsEW(false)
      iads:getSAMSitesByNatoName("Patriot"):setActAsEW(false)
      iads:getSAMSitesByNatoName("Hawk"):setActAsEW(false)
    end

    -- reactivate (rebuild coverage) the IADS
    veaf.loggers.get(veafSkynet.Id):trace("reactivate (rebuild coverage) the IADS")
    veafSkynet.delayedActivate(networkName)

    --add the added site to the structure of the network it was added to
    veafSkynet.structure[networkName].groups[groupName] = { forceEwr = forceEwr, pointDefense = defended_name }

    -- Last, so a site that reports no radar range at all is caught at the one moment its range was
    -- ever read. See veafSkynet.checkRadarRange.
    veafSkynet.checkRadarRange(networkName, addedElement)
  end

  return didSomething
end

local function initializeIADS(networkName, coa, inRadio, debug)
  local iads = veafSkynet.getIadsOfCoalition(networkName, coa)
  if not iads then
    veaf.loggers.get(veafSkynet.Id):trace(string.format("IADS named %s for coalition %s does not exist", veaf.p(networkName), veaf.p(coa)))
    return false
  end
  veaf.loggers.get(veafSkynet.Id):trace(string.format("initializeIADS %s", tostring(iads:getCoalitionString())))

  if debug then
    veaf.loggers.get(veafSkynet.Id):debug("adding debug information")
    local iadsDebug = iads:getDebugSettings()
    iadsDebug.IADSStatus = true
    iadsDebug.radarWentDark = true -- FG iadsDebug.samWentDark = true
    iadsDebug.contacts = true
    iadsDebug.radarWentLive = true
    iadsDebug.noWorkingCommmandCenter = false
    iadsDebug.ewRadarNoConnection = false
    iadsDebug.samNoConnection = false
    iadsDebug.jammerProbability = true
    iadsDebug.addedEWRadar = true
    iadsDebug.hasNoPower = false
    iadsDebug.harmDefence = true
    iadsDebug.samSiteStatusEnvOutput = true
    iadsDebug.earlyWarningRadarStatusEnvOutput = true
  end

  local alreadyAddedGroups = {}
  local dcsGroups = coalition.getGroups(coa)
  for _, dcsGroup in pairs(dcsGroups) do
    -- #946: tested here as well as inside addGroupToNetwork, and not out of caution. This loop asks
    -- the handle for its name **before** reaching that function, and a DCS object that has left the
    -- mission can refuse any method — the Skynet compatibility layer records `getUnits` raising and
    -- there is nothing to say `getName` is safer. A raise here does not skip one group: it aborts the
    -- whole enrolment, and every group listed after the corpse never joins the IADS.
    if veafSkynet.structure[networkName] and veafSkynet.dcsObjectStillExists(dcsGroup) then
      local groupName = dcsGroup:getName()
      if groupName then
        local structureData = veafSkynet.structure[networkName].groups[groupName]
        local forceEwr = false
        local pointDefense = false
        if structureData then
          if structureData.forceEwr then
            forceEwr = structureData.forceEwr
          end
          if structureData.pointDefense then
            pointDefense = structureData.pointDefense
          end
        end
        if veafSkynet.loadAllAtInit[tostring(coa)] or structureData then
          veafSkynet.addGroupToNetwork(networkName, dcsGroup, forceEwr, pointDefense, alreadyAddedGroups, true)
        end
      end
    end
  end

  if veafSkynet.loadAllAtInit[tostring(coa)] then
    veafSkynet.loadAllAtInit[tostring(coa)] = false
  end

  veaf.loggers.get(veafSkynet.Id):trace("Specific configuration applied")
  -- specific configurations, for each SAM type
  iads:getSAMSitesByNatoName("SA-10"):setActAsEW(false)
  iads:getSAMSitesByNatoName("SA-6"):setActAsEW(false)
  iads:getSAMSitesByNatoName("SA-5"):setActAsEW(false)
  iads:getSAMSitesByNatoName("Patriot"):setActAsEW(false)
  iads:getSAMSitesByNatoName("Hawk"):setActAsEW(false)

  veafSkynet.initializePointDefences(veafSkynet.getNetwork(networkName)) -- Management of point defences (Flogas) - initialization

  if inRadio then
    --activate the radio menu to toggle IADS Status output
    iads:addRadioMenu()
  end

  --activate (build coverage) the IADS
  veaf.loggers.get(veafSkynet.Id):debug("activate (build coverage) the IADS")
  veafSkynet.delayedActivate(networkName)
end

local function createNetwork(networkName, coa, loadUnits, UserAdd)
  local UserAdd = UserAdd or false
  local loadUnits = loadUnits or false

  local networkName = networkName
  if networkName then
    networkName = tostring(networkName)
  else
    veaf.loggers.get(veafSkynet.Id):error("networkName is of invalid format")
    return false
  end
  local coa = coa
  if coa then
    coa = tonumber(coa)
  else
    veaf.loggers.get(veafSkynet.Id):error("Coalition specified is of invalid format")
    return false
  end
  veaf.loggers.get(veafSkynet.Id):trace("networkName= %s", veaf.lp(networkName))
  veaf.loggers.get(veafSkynet.Id):trace("CoalitionID= %s", veaf.lp(coa))
  veaf.loggers.get(veafSkynet.Id):trace("loadUnits= %s", veaf.lp(loadUnits))
  veaf.loggers.get(veafSkynet.Id):trace("UserAdd= %s", veaf.lp(UserAdd))

  if networkName and coa then
    if (UserAdd and not veafSkynet.structure[networkName]) or not UserAdd then
      local debugFlag = veafSkynet.debugBlue
      local includeInRadio = veafSkynet.includeBlueInRadio

      if coa == coalition.side.RED then
        debugFlag = veafSkynet.debugRed
        includeInRadio = veafSkynet.includeRedInRadio
      end

      veaf.loggers.get(veafSkynet.Id):trace("creating network...")
      local iads = SkynetIADS:create(networkName)
      iads.coalitionID = coa
      if iads then
        if not veafSkynet.structure[networkName] then
          veaf.loggers.get(veafSkynet.Id):trace("network is new")
          veafSkynet.structure[networkName] = {}
          veafSkynet.structure[networkName].coalitionID = coa
          veafSkynet.structure[networkName].includeInRadio = includeInRadio
          veafSkynet.structure[networkName].debugFlag = debugFlag
          veafSkynet.structure[networkName].groups = {}
          -- the module-level flag is the value a network is created with; from then on it is per network
          veafSkynet.structure[networkName].dynamicSpawn = veafSkynet.DynamicSpawn
        end
        veafSkynet.structure[networkName].iads = iads

        if veaf.loggers.get(veafSkynet.Id):wouldLogTrace() then
          veaf.loggers.get(veafSkynet.Id):trace("Stored structure for network named %s :", veaf.lp(networkName))
          for index, _ in pairs(veafSkynet.structure[networkName]) do
            veaf.loggers.get(veafSkynet.Id):trace("-> %s", veaf.lp(index))
          end
          veaf.loggers.get(veafSkynet.Id):trace("Stored IADS structure for network named %s :", veaf.lp(networkName))
          for index, _ in pairs(veafSkynet.structure[networkName].iads) do
            veaf.loggers.get(veafSkynet.Id):trace("-> %s", veaf.lp(index))
          end
          veaf.loggers.get(veafSkynet.Id):trace("CoalitionID for network named %s :", veaf.lp(networkName))
          veaf.loggers.get(veafSkynet.Id):trace("-> %s", veaf.lp(veafSkynet.structure[networkName].iads.coalitionID))
          veaf.loggers.get(veafSkynet.Id):trace("-> %s", veaf.lp(veafSkynet.structure[networkName].iads:getCoalitionString()))
        end

        if loadUnits then
          initializeIADS(networkName, coa, includeInRadio, debugFlag)
        end
        return true
      end
    else
      local text = string.format('The network name "%s" already exists', veaf.p(networkName))
      veaf.loggers.get(veafSkynet.Id):info(text)
    end
  end
  return false
end

-- reset an IADS network, useful when many additions are made at once to harmonize the structure
function veafSkynet.reinitializeNetwork(networkName)
  if not veafSkynet.initialized then
    return false
  end

  if networkName and veafSkynet.structure[networkName] then
    local networkStructure = veafSkynet.structure[networkName]
    if networkStructure.iads then
      veaf.loggers.get(veafSkynet.Id):trace("Stored structure for network named %s has IADS, deactivating", veaf.lp(networkName))
      if networkStructure.includeInRadio then
        veaf.loggers.get(veafSkynet.Id):trace("Removing radio menu...")
        networkStructure.iads:removeRadioMenu()
      end
      networkStructure.iads:deactivate()
    end
    -- rebuilding a network from scratch is a deliberate act, so it clears the "switched off on
    -- purpose" mark — otherwise initializeIADS's own delayedActivate at the end would be refused
    -- and the reinitialised network would stay dark (#261).
    networkStructure.deactivated = nil
    createNetwork(networkName, networkStructure.coalitionID, true)
  end
end

-- reset an IADS networks, useful when many additions/destructions are made at once to harmonize the structures on the skynet side
function veafSkynet.reinitialize()
  if not veafSkynet.initialized then
    return false
  end

  for networkName, _ in pairs(veafSkynet.structure) do
    veafSkynet.reinitializeNetwork(networkName)
  end
end

function veafSkynet.initialize(includeRedInRadio, debugRed, includeBlueInRadio, debugBlue)
  veaf.loggers.get(veafSkynet.Id):info(string.format("initializing Skynet in %s seconds", tostring(veafSkynet.DelayForStartup)))
  veaf.scheduleFunction(
    veafSkynet._initialize,
    { includeRedInRadio, debugRed, includeBlueInRadio, debugBlue },
    timer.getTime() + veafSkynet.DelayForStartup
  )
end

function veafSkynet._initialize(includeRedInRadio, debugRed, includeBlueInRadio, debugBlue)
  veafSkynet.includeRedInRadio = includeRedInRadio or false
  veafSkynet.debugRed = debugRed or false
  veafSkynet.includeBlueInRadio = includeBlueInRadio or false
  veafSkynet.debugBlue = debugBlue or false

  veaf.loggers.get(veafSkynet.Id):info("Initializing module")

  veaf.loggers.get(veafSkynet.Id):debug(string.format("includeRedInRadio=%s", veaf.p(includeRedInRadio)))
  veaf.loggers.get(veafSkynet.Id):debug(string.format("debugRed=%s", veaf.p(debugRed)))
  veaf.loggers.get(veafSkynet.Id):debug(string.format("includeBlueInRadio=%s", veaf.p(includeBlueInRadio)))
  veaf.loggers.get(veafSkynet.Id):debug(string.format("debugBlue=%s", veaf.p(debugBlue)))

  -- prepare the list of units supported by Skynet IADS
  for _, groupData in pairs(SkynetIADS.database) do
    for _, listName in pairs({ "searchRadar", "trackingRadar", "launchers", "misc" }) do
      if groupData["type"] ~= "ewr" then
        local list = groupData[listName]
        if list then
          for unitType, _ in pairs(list) do
            veaf.loggers.get(veafSkynet.Id):trace(string.format("-> SAM"))
            veafSkynet.iadsSamUnitsTypes[unitType] = true
          end
        end
      end
    end
  end
  veaf.loggers.get(veafSkynet.Id):trace(string.format("veafSkynet.iadsSamUnitsTypes=%s", veaf.p(veafSkynet.iadsSamUnitsTypes)))

  -- add EWR-capable units
  for _, unit in pairs(dcsUnits.DcsUnitsDatabase) do
    if unit then
      veaf.loggers.get(veafSkynet.Id):trace(string.format("testing unit %s", veaf.p(unit.type)))
      if unit.attribute then
        veaf.loggers.get(veafSkynet.Id):trace(string.format("unit.attribute = %s", veaf.p(unit.attribute)))
        if unit.attribute["SAM SR"] then
          veafSkynet.iadsEwrUnitsTypes[unit.type] = true
          veaf.loggers.get(veafSkynet.Id):trace(string.format("-> EWR"))
        elseif unit.attribute["EWR"] then
          veafSkynet.iadsEwrUnitsTypes[unit.type] = true
          veaf.loggers.get(veafSkynet.Id):trace(string.format("-> EWR"))
        elseif unit.attribute["AWACS"] then
          veafSkynet.iadsEwrUnitsTypes[unit.type] = true
          veaf.loggers.get(veafSkynet.Id):trace(string.format("-> EWR"))
        end
      end
    end
  end
  veaf.loggers.get(veafSkynet.Id):trace(string.format("veafSkynet.iadsEwrUnitsTypes=%s", veaf.p(veafSkynet.iadsEwrUnitsTypes)))

  veaf.loggers.get(veafSkynet.Id):info("Creating IADS for BLUE")
  createNetwork(veafSkynet.defaultIADS[tostring(coalition.side.BLUE)], coalition.side.BLUE, true)

  veaf.loggers.get(veafSkynet.Id):info("Creating IADS for RED")
  createNetwork(veafSkynet.defaultIADS[tostring(coalition.side.RED)], coalition.side.RED, true)

  veafSkynet.initialized = true

  if veafSkynet.CommandCentersPreinitialize and #veafSkynet.CommandCentersPreinitialize > 0 then
    for _, commandCenter in pairs(veafSkynet.CommandCentersPreinitialize) do
      veafSkynet.addCommandCenterOfCoalition(commandCenter.CoalitionId, commandCenter.CommandCenterName)
    end

    veafSkynet.CommandCentersPreinitialize = {}
  end

  -- arms the shared birth handler if any network was created wanting dynamic integration
  veafSkynet.refreshDynamicSpawnMonitoring()

  veafSkynet._armVanishedSitesSweep()

  veaf.loggers.get(veafSkynet.Id):info(string.format("Skynet IADS has been initialized"))
end

--- Watch for units being lost, and sweep the networks periodically (#946).
---
--- Idempotent, because a reinitialisation must not stack a second death callback (`addCallback` does
--- not deduplicate) nor a second schedule: every unit lost would be recorded twice and every sweep
--- run twice, which is the shape of #824.
function veafSkynet._armVanishedSitesSweep()
  if veafSkynet.vanishedSitesSweepArmed then
    return
  end
  veafSkynet.vanishedSitesSweepArmed = true

  -- Guarded the way veafMissionDb guards it: the module is loadable without the event handler, and a
  -- missing dispatcher must cost the ledger, not the IADS.
  if veafEventHandler and veafEventHandler.addCallback then
    veafEventHandler.addCallback("veafSkynet.onUnitLost", { "S_EVENT_DEAD", "S_EVENT_UNIT_LOST" }, veafSkynet.onUnitLost)
    veafEventHandler.addCallback("veafSkynet.onUnitBorn", { "S_EVENT_BIRTH" }, veafSkynet.onUnitBorn)
  else
    veaf.loggers.get(veafSkynet.Id):warn("no event handler: a site whose group is destroyed cannot be told from one that was despawned")
  end

  veaf.scheduleFunction(
    veafSkynet.sweepVanishedSites,
    {},
    timer.getTime() + veafSkynet.SecondsBetweenVanishedSitesSweeps,
    veafSkynet.SecondsBetweenVanishedSitesSweeps
  )
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Command centers and network deactivation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
veafSkynet.CommandCentersPreinitialize = {} -- this is to memorize the command centers requested for a coalition, if the network of the coalition does not exist yet

function veafSkynet.addCommandCenter(veafSkynetNetwork, sCommandCenterName)
  local iads = veafSkynetNetwork.iads

  ---@type StaticObject|Unit|nil
  local dcsCommandCenterObject = StaticObject.getByName(sCommandCenterName)
  if not dcsCommandCenterObject then
    dcsCommandCenterObject = Unit.getByName(sCommandCenterName)
  end
  if not dcsCommandCenterObject then
    local dcsCommandCenterGroup = Group.getByName(sCommandCenterName)
    if dcsCommandCenterGroup then
      dcsCommandCenterObject = dcsCommandCenterGroup:getUnit(1)
    end
  end

  if not dcsCommandCenterObject then
    veaf.loggers.get(veafSkynet.Id):error("Requested command center not found: " .. sCommandCenterName)
    return
  end

  iads:addCommandCenter(dcsCommandCenterObject)
  veaf.loggers.get(veafSkynet.Id):trace("Command center unit added [" .. sCommandCenterName .. "]")
  iads:buildRadarCoverage() -- as command center is added after the network initialisation, coverage should be rebuilt
end

function veafSkynet.addCommandCenterOfCoalition(iCoalitionId, sCommandCenterName)
  if veafSkynet.initialized then
    local veafSkynetNetwork = veafSkynet.getNetwork(veafSkynet.defaultIADS[tostring(iCoalitionId)])

    if veafSkynetNetwork == nil then
      veaf.loggers.get(veafSkynet.Id):error(
        "Veaf skynet network not found. Please ensure that veafSkynetIadsHelper has been initialized for coalition [" .. iCoalitionId .. "]"
      )
      return
    end

    veafSkynet.addCommandCenter(veafSkynetNetwork, sCommandCenterName)
  else
    veaf.loggers.get(veafSkynet.Id):trace(
      "Veaf skynet not initialized. Command center [" .. sCommandCenterName .. "] stored to be added later for [" .. iCoalitionId .. "]"
    )
    table.insert(veafSkynet.CommandCentersPreinitialize, { CoalitionId = iCoalitionId, CommandCenterName = sCommandCenterName })
  end
end

function veafSkynet.destroyCommandCenters(veafSkynetNetwork, iExplosionStrength)
  iExplosionStrength = iExplosionStrength or 200 -- default explosion may not be enough to destroy certain bunkers
  local iads = veafSkynetNetwork.iads

  if not iads:isCommandCenterUsable() then
    veaf.loggers.get(veafSkynet.Id):trace("Network has no usable command center")
    return
  end

  local ccs = iads:getCommandCenters()

  for i = 1, #ccs do
    local cc = ccs[i]

    local dcsObject = cc.dcsRepresentation

    if dcsObject:isExist() then
      local category = getmetatable(dcsObject)
      if category == Group then
        for _, dcsUnit in pairs(dcsObject:getUnits()) do
          veaf.loggers.get(veafSkynet.Id):trace("Command center unit exploded: " .. dcsUnit:getName())
          trigger.action.explosion(dcsUnit:getPosition().p, iExplosionStrength)
        end
      else
        veaf.loggers.get(veafSkynet.Id):trace("Command center unit exploded: " .. dcsObject:getName())
        trigger.action.explosion(dcsObject:getPosition().p, iExplosionStrength)
      end
    end
  end
end

function veafSkynet.destroyCommandCentersOfCoalition(iCoalitionId, iExplosionStrength)
  local veafSkynetNetwork = veafSkynet.getNetwork(veafSkynet.defaultIADS[tostring(iCoalitionId)])
  veafSkynet.destroyCommandCenters(veafSkynetNetwork, iExplosionStrength)
end

function veafSkynet.deactivateNetwork(veafSkynetNetwork, elementStates)
  local elementState = elementStates or veafSkynet.SkynetElementStates.Live
  local iads = veafSkynetNetwork.iads

  local sElementState = "live"
  if elementState == veafSkynet.SkynetElementStates.Autonomous then
    sElementState = "autonomous"
  elseif elementState == veafSkynet.SkynetElementStates.Dark then
    sElementState = "dark"
  end
  veaf.loggers
    .get(veafSkynet.Id)
    :trace("Deactivating network " .. iads:getCoalitionString() .. ". Network elements will go " .. sElementState)

  local function setGroupState(skynetElement)
    skynetElement:finishHarmDefence()
    skynetElement:cleanUp()

    veafSkynet.removePointDefencesFromSkynetElement(skynetElement)
    if elementState == veafSkynet.SkynetElementStates.Autonomous then
      skynetElement:resetAutonomousState()
      skynetElement:goAutonomous()
    elseif elementState == veafSkynet.SkynetElementStates.Dark then
      skynetElement:goDark() -- goDark will not always turn the radar off - eg an EWR that is tracking targets will stay on
    else
      skynetElement:goLive() -- goLive will not always turn the radar on - eg a SAM site out of ammo will stay off
    end
  end

  -- #261: this used to call veafSkynet.monitorDynamicSpawn(false), which removes the event handler
  -- *shared by every network* — so switching off one coalition's IADS disarmed the other one's
  -- dynamic integration too, and nothing ever re-armed it.
  --
  -- Marking the network instead. Note that `dynamicSpawn` is deliberately left alone: a group
  -- spawned with `skynet true` into a deactivated network still gets attached — that is what the
  -- option asks for — it simply must not wake the network up, which delayedActivate now refuses.
  -- The group lights up with the rest when someone reactivates the network on purpose.
  veafSkynetNetwork.deactivated = true
  iads:deactivate()

  local ewrs = iads:getEarlyWarningRadars()
  for i = 1, #ewrs do
    local ewr = ewrs[i]
    setGroupState(ewr)
  end
  local sams = iads:getSAMSites()
  for i = 1, #sams do
    local sam = sams[i]
    setGroupState(sam)
  end

  -- Copying the elements and emptying the Skynet lists before doing the state switch to ensure that Skynet does not keep controlling the elements after deactivation.
  -- Does not seem necessary after all, and keeping the lists in the Skynet network allows to reactivate it later if needed.
  -- Note that as it is, reactivating will not rebuild point defences, so it is more of a testing thing still.
  -- Code kept here just in case.
  --[[
    local skynetGroups = {}
    for i = 1, #iads.earlyWarningRadars do
        table.insert(skynetGroups, iads.earlyWarningRadars[i])
    end
    for i = 1, #iads.samSites do
        table.insert(skynetGroups, iads.samSites[i])
    end
    
    iads.earlyWarningRadars = {}
    iads.samSites = {}

    for i = 1, #skynetGroups do
        local skynetGroup = skynetGroups[i]
        setGroupState(skynetGroup)
    end
    ]]
end

function veafSkynet.deactivateNetworkOfCoalition(iCoalitionId, elementStates)
  local veafSkynetNetwork = veafSkynet.getNetwork(veafSkynet.defaultIADS[tostring(iCoalitionId)])
  veafSkynet.deactivateNetwork(veafSkynetNetwork, elementStates)
end

-- Bring a deliberately deactivated network back up. This is the symmetric half of
-- deactivateNetwork, which the API was missing: since #261 a deactivated network stays down, so
-- without this there would be no way back short of reinitializing it.
-- Everything attached while the network was down comes up with it.
function veafSkynet.activateNetwork(veafSkynetNetwork)
  if not veafSkynetNetwork then
    veaf.loggers.get(veafSkynet.Id):debug("no network to activate")
    return false
  end

  local networkName = nil
  for name, network in pairs(veafSkynet.structure) do
    if network == veafSkynetNetwork then
      networkName = name
      break
    end
  end
  if not networkName then
    veaf.loggers.get(veafSkynet.Id):warn("cannot tell which network this is, not activating it")
    return false
  end

  veafSkynetNetwork.deactivated = nil
  veaf.loggers.get(veafSkynet.Id):debug(string.format("activating network %s on purpose", veaf.p(networkName)))
  veafSkynet.delayedActivate(networkName)
  return true
end

function veafSkynet.activateNetworkOfCoalition(iCoalitionId)
  local veafSkynetNetwork = veafSkynet.getNetwork(veafSkynet.defaultIADS[tostring(iCoalitionId)])
  return veafSkynet.activateNetwork(veafSkynetNetwork)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Load module
-------------------------------------------------------------------------------------------------------------------------------------------------------------
veaf.loggers.get(veafSkynet.Id):info(veaf.loggers.get(veafSkynet.Id):getVersionInfo())

-- Note on `dynamic_spawn` (#151): the build writes it as `veafSkynet.DynamicSpawn = <bool>` into
-- veaf-config.lua, right before its initialize() call, rather than as a veaf.setConfig key read here.
-- The generated block calls initialize() directly and so bypasses this callback, so a second source
-- of truth could overwrite the first depending on load order. createNetwork reads the variable when
-- it creates each network, which is after the generated block has run.
veaf.registerModule(veafSkynet.Id, function()
  local cfg = veaf.getConfig(veafSkynet.Id)
  veafSkynet.initialize(cfg.includeRedInRadio, cfg.debugRed, cfg.includeBlueInRadio, cfg.debugBlue)
end, { enable = true, includeRedInRadio = true, debugRed = false, includeBlueInRadio = true, debugBlue = false }, 220)
