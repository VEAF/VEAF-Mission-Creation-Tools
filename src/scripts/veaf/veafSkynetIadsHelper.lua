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

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Skynet 3.5.0 settings, written by the build from `modules.SKYNET`.
--
-- Spelling note: `Defence` throughout, because that is what the Skynet API is called
-- (`SkynetIADS:setLastLineOfDefence`) and what this page's documentation already uses. The backlog
-- lot is named with the American spelling; the code follows the API it calls.
--
-- These are global to both coalitions, unlike `DynamicSpawn` which becomes per network. Per-network
-- values would only be worth the plumbing once a mission asks for two different IADS doctrines.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- A dark site keeps a short virtual detection radius of its own and lights up inside it.
---
--- **On by default**, which changes existing missions: before 3.5.0 a site under network control was
--- entirely blind between EWR hand-overs, so flying under the radar horizon meant flying untouched.
--- Switch it off for a purist IADS.
veafSkynet.LastLineOfDefence = true

--- Bounds of that radius, in metres. Each site draws its own once, between the two, so a front does
--- not present a uniform ring a pilot can learn. Measured flat — the radius ignores altitude and the
--- firing envelope on purpose, so a short-range piece can light up for an aircraft it cannot reach.
veafSkynet.LastLineOfDefenceMinRadius = 10000
veafSkynet.LastLineOfDefenceMaxRadius = 15000

--- How long a site stays lit after the last pass through its radius, in seconds.
veafSkynet.LastLineOfDefencePersistence = 45

--- Seconds between two sweeps of the radar coverage graph. Zero switches the sweep off.
veafSkynet.CoverageRefreshInterval = 10

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
    -- A dead spotter keeps no contacts. Left behind, its latch would hold an aircraft as *triggered*
    -- for the rest of the mission and never re-report it should the unit come back under the same
    -- name — and, once propagation is in, a contact nobody is still looking at would be refreshed by
    -- the heartbeat forever.
    veafSkynet.forgetSpotter(unitName)
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
  -- #261, and this is not caution: `SkynetIADS:buildRadarCoverage` ends by calling
  -- `informChildrenOfStateChange()` on **every** SAM site — the vendored comment there says it is
  -- "to make sure autonomous sites go live" — and a site with no live parent whose autonomous
  -- behaviour is the default `AUTONOMOUS_STATE_DCS_AI` then goes live: radar on, alarm state red.
  -- `deactivateNetwork` deliberately leaves `samSites` populated and only marks the network, so the
  -- periodic sweep walks a deactivated network too and would relight it here, around the refusal
  -- `delayedActivate` exists to enforce. Worse, those elements have had `cleanUp()` called on them,
  -- so they would come back up with their world event handlers unregistered.
  if network.deactivated then
    veaf.loggers
      .get(veafSkynet.Id)
      :trace("rebuildRadarCoverage: network %s was deactivated on purpose, leaving its coverage alone", veaf.lp(networkName))
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

--- The DCS handle of a Skynet element or of one of its radar wrappers, or nil, without ever raising.
--- Both are `SkynetIADSAbstractDCSObjectWrapper` descendants, so one reader serves both.
local function _dcsRepresentationOf(skynetElement)
  if not skynetElement or not skynetElement.getDCSRepresentation then
    return nil
  end
  local ok, dcsRepresentation = pcall(skynetElement.getDCSRepresentation, skynetElement)
  return ok and dcsRepresentation or nil
end

--- One string naming this element's radar units, for a log line: `name/type/live/resolvable`.
---
--- `resolvable` is `Unit.getByName(name) ~= nil`. The two together are what a log needs to separate
--- the three states this repository could not tell apart on Tripack's 2026-09-09 log: a wrapper
--- holding a unit DCS no longer has, a wrapper holding a unit DCS has but under another name, and a
--- unit that is plainly there and answers no sensors. Only the third is a DCS question.
---
--- @param skynetElement table|nil
--- @return string
function veafSkynet.describeRadarUnits(skynetElement)
  if not skynetElement or not skynetElement.getRadars then
    return "none"
  end
  local ok, radars = pcall(skynetElement.getRadars, skynetElement)
  if not ok or type(radars) ~= "table" then
    return "unreadable"
  end
  local described = {}
  for _, radar in pairs(radars) do
    local name = tostring(radar.dcsName)
    local resolved, unit = pcall(Unit.getByName, name)
    table.insert(
      described,
      string.format(
        "%s/%s/live=%s/resolvable=%s",
        name,
        tostring(radar.typeName),
        tostring(veafSkynet.dcsObjectStillExists(_dcsRepresentationOf(radar)) and true or false),
        tostring((resolved and unit) and true or false)
      )
    )
  end
  if #described == 0 then
    return "none"
  end
  return table.concat(described, " ; ")
end

--- Read the range data again for an element whose radars all reported nothing, and rebuild the
--- coverage as soon as one of them answers.
---
--- Re-reading **is** the repair: why DCS hands back a nil `getSensors()` for a radar unit it still
--- holds is not observable from a log, so the dependency on that one reading being lucky is removed
--- rather than explained.
---
--- Asking again is safe, but not idempotent, and the difference is worth stating rather than
--- glossing: `SkynetIADSSAMSearchRadar:setupRangeData` increments its own `triedSensors` counter on
--- every nil-sensor read, and the launcher variant guards its ammo bookkeeping on that counter
--- staying `<= 2` ("we set initial values only the first time the method is called"). A handful of
--- re-reads pushes it past that gate for good. Harmless here — the search-radar fallback into the
--- launcher's range data is ungated, which is the path this uses — and bounded by
--- `MaxRangeRechecks`, so the counter moves by at most three.
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
  -- `MaxRangeRechecks` is a mission-settable number, so zero has to mean zero rather than one.
  local willRetry = liveRadarCount > 0 and veafSkynet.MaxRangeRechecks > 0
  -- The verdict is part of the line, because the line is the diagnosis: promising a re-read that is
  -- not coming would make this log misleading in exactly the place the lot exists to make readable.
  local ending = "no radar left to ask, nothing to re-read"
  if willRetry then
    ending = string.format("re-reading in %s s", tostring(veafSkynet.DelayForRangeRecheck))
  elseif liveRadarCount > 0 then
    ending = "re-reading is switched off (MaxRangeRechecks = 0)"
  end
  -- The radar **units** are named, not just the group. Four readings of Tripack's log could not tell
  -- whether Skynet had hold of the right unit, because the line named the group only — and the group
  -- name of a zone respawn (`TESTCZ [r] TESTCZ - SA6#10316`) says nothing about the unit underneath.
  -- `resolvable` is the other half: it says whether `Unit.getByName` can find that unit at all, which
  -- separates "Skynet holds a unit DCS has forgotten" from "the unit is there and silent".
  veaf.loggers.get(veafSkynet.Id):info(
    "RADAR RANGE ZERO [%s]: radars=%s live=%s launchers=%s radarUnits=%s - the site detects nothing, %s",
    veaf.lp(elementName),
    veaf.lp(radarCount),
    veaf.lp(liveRadarCount),
    veaf.lp(skynetElement.launchers and #skynetElement.launchers or 0),
    veaf.lp(veafSkynet.describeRadarUnits(skynetElement)),
    veaf.lp(ending)
  )
  if willRetry then
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
--- the documented way to integrate mid-mission spawns: because without this, whether a zone's
--- battery is in the network is decided by a **race**, and the race is won at mission start and lost
--- for the rest of the game.
---
--- `veafCombatZone.ActivateZone` schedules the zone's activation at `timer.getTime() + 1`
--- (veafCombatZone.lua) and `veafSkynet.DelayForStartup` is `1` — the same second. The zone's
--- `initialize` has already destroyed the editor groups standing in the trigger zone, synchronously,
--- while the config script loaded; so what the enrolment can find is the group the *activation* has
--- just respawned, and only if the activation ran first. Measured on Tripack's log of 2026-09-09: it
--- did, and `TESTCZ [r] TESTCZ - SA6#10262` was enrolled at 09:58:02.591 by `loadAllAtInit` — with
--- `dynamic_spawn` absent from that mission's configuration.
---
--- So the site was in the network at second one, out of it after the first sweep, and never back.
--- Requiring the flag would not fix that; it would only make the first second consistent with the
--- rest by removing the site from both. Telling the network explicitly, every time the zone puts a
--- battery back, is what makes the answer the same at second one and at second six hundred.
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
  -- #151 posed the two integration paths as exclusive — "when the target network integrates dynamic
  -- spawns, its birth-event handler does the work […] so doing it here as well would integrate the
  -- same group twice" (veafSpawnCore.lua). A network with `dynamicSpawn` on has that handler armed,
  -- and `coalition.addGroup` fires the birth event this call would race, so the work is left to it.
  -- The second integration would be refused rather than duplicated, but "refused" is not the same
  -- promise as "never asked", and the rule is the repository's, not this function's to bend.
  if veafSkynet.integratesDynamicSpawns(veafSkynet.defaultIADS[tostring(coalitionId)]) then
    veaf.loggers.get(veafSkynet.Id):trace(
      "integrateMissionSpawn: the network of coalition %s integrates spawns itself, leaving %s to it",
      veaf.lp(coalitionId),
      veaf.lp(groupName)
    )
    return
  end
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
    -- No per-NATO-type `setActAsEW(false)` sweep here, and that is a removal rather than an
    -- oversight. VEAF used to force the large systems into EW watch, so a block was added to drop
    -- that watch once a real EWR joined; the forcing went away in a68dfd32 (2022) but the block was
    -- only flipped from `true` to `false` and carried forward ever since. Skynet already builds
    -- every radar element with `actAsEW = false`, so the sweep asked for what was already true --
    -- while silencing any SA-10/SA-6/SA-5/Patriot/Hawk explicitly marked as a watch by the `ewr`
    -- spawn option, which is why that option had never worked on those five types.

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

  -- The twin of the sweep removed in addGroupToNetwork, and removed for the same reasons. This one
  -- ran right after the enrolment loop above, so it undid every watch that loop had just set: on
  -- these five NATO types the `ewr` option had never worked, not even at first start-up.

  veafSkynet.initializePointDefences(veafSkynet.getNetwork(networkName)) -- Management of point defences (Flogas) - initialization

  if inRadio then
    --activate the radio menu to toggle IADS Status output
    iads:addRadioMenu()
  end

  --activate (build coverage) the IADS
  veaf.loggers.get(veafSkynet.Id):debug("activate (build coverage) the IADS")
  veafSkynet.delayedActivate(networkName)
end

--- Hand the Skynet 3.5.0 settings to a freshly created IADS, and check they were taken.
--
-- Called at creation rather than at initialization: `setLastLineOfDefenceRadius` clears every radius
-- already drawn, so setting it once here is what keeps a site's radius stable for the whole mission.
--
-- **Skynet's setters validate and refuse in silence.** `setLastLineOfDefenceRadius` drops the pair
-- whole when `max < min` — which a mission reaches just by naming one bound past the other's shipped
-- default, e.g. `last_line_of_defence_min_radius_km: 20` alone against a max left at 15 — and the
-- duration setters drop a negative value the same way. Writing a setting and never reading it back
-- is how a documented key ends up doing nothing with nobody told, so every value is read back and a
-- refusal is said out loud, naming what was asked and what stands.
--
-- The method guard is the shape `reportContact` uses further down: a mission that supplies its own
-- pre-3.5.0 Skynet gets one plain warning instead of a raise that would abort network creation and
-- leave the mission with no IADS at all.
--
-- @param iads table the Skynet IADS just created
-- @param networkName string the network's name, for the log lines
function veafSkynet.applyLastLineOfDefenceSettings(iads, networkName)
  if not iads.setLastLineOfDefence then
    veaf.loggers.get(veafSkynet.Id):warn(
      "this Skynet build predates 3.5.0: the last line of defence and the coverage sweep cannot be set, and modules.SKYNET's settings for them are inert (vendor a Skynet release that carries them)"
    )
    return
  end

  iads:setLastLineOfDefence(veafSkynet.LastLineOfDefence)
  iads:setLastLineOfDefenceRadius(veafSkynet.LastLineOfDefenceMinRadius, veafSkynet.LastLineOfDefenceMaxRadius)
  iads:setLastLineOfDefencePersistence(veafSkynet.LastLineOfDefencePersistence)
  iads:setCoverageRefreshInterval(veafSkynet.CoverageRefreshInterval)

  local function refused(what, asked, standing)
    veaf.loggers.get(veafSkynet.Id):warn(
      "SKYNET [%s]: %s was refused — asked for %s, Skynet stands at %s. Check the value in mission.yaml",
      veaf.lp(networkName),
      veaf.lp(what),
      veaf.lp(asked),
      veaf.lp(standing)
    )
  end

  local minRadius, maxRadius = iads:getLastLineOfDefenceRadius()
  if minRadius ~= veafSkynet.LastLineOfDefenceMinRadius or maxRadius ~= veafSkynet.LastLineOfDefenceMaxRadius then
    -- Named as the pair, because Skynet refuses the pair: the reader has to see both to understand
    -- that the bound they did not touch is what rejected the one they did.
    refused(
      "the last-line-of-defence radius (min/max, in metres)",
      tostring(veafSkynet.LastLineOfDefenceMinRadius) .. "/" .. tostring(veafSkynet.LastLineOfDefenceMaxRadius),
      tostring(minRadius) .. "/" .. tostring(maxRadius)
    )
  end
  if iads:getLastLineOfDefence() ~= veafSkynet.LastLineOfDefence then
    refused("the last line of defence on/off", veafSkynet.LastLineOfDefence, iads:getLastLineOfDefence())
  end
  if iads:getLastLineOfDefencePersistence() ~= veafSkynet.LastLineOfDefencePersistence then
    refused("the last-line-of-defence persistence (s)", veafSkynet.LastLineOfDefencePersistence, iads:getLastLineOfDefencePersistence())
  end
  if iads:getCoverageRefreshInterval() ~= veafSkynet.CoverageRefreshInterval then
    refused("the coverage sweep interval (s)", veafSkynet.CoverageRefreshInterval, iads:getCoverageRefreshInterval())
  end
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
        veafSkynet.applyLastLineOfDefenceSettings(iads, networkName)
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

  -- After the networks exist, because both read their coalitions to know who is watching whom.
  veafSkynet._armSpotterDetection()
  veafSkynet._armSpotterGraph()
  veafSkynet._armSpotterPropagation()
  veafSkynet._armSpotterHandover()
  veafSkynet._armSpotterStatus()
  veafSkynet._armSpotterView()

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
-- Spotter network — detection
--
-- A ground unit that sees a hostile aircraft reports it, and the report travels from unit to unit
-- along radio links. This section is the *seeing* half: who can see, how far, and when a sighting
-- counts as gained or lost. Where the report goes is the propagation section.
--
-- The whole feature is a **distributed early-warning radar**, not a wake-up trigger: a SAM site that
-- receives an alert holds the contact and goes live only when the aircraft enters its own firing
-- envelope, exactly as it would for a real EW radar.
--
-- Design record, with the measurements behind every number here:
-- .backlog/archive/FEAT-SPOTTER-NETWORK.md
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Off by default: switching it on changes the balance of every existing mission.
--- Written by the build from `modules.SKYNET.spotter_network`.
veafSkynet.SpotterNetwork = false

--- How far one unit can pass the word, in metres. Written from `spotter_radio_range_km`.
---
--- 20 km rather than the 10 km first assumed, and the reason is reach rather than taste: measured
--- over 8 draws of a 1 000-unit mission, the largest connected pocket at 10 km covers 5.1 % of a
--- scattered map and 61 % of a dense front, against 100 % at 20 km on both. The network percolates
--- sharply between the two, so at 10 km the feature exists without doing anything, and nobody can
--- tell why.
veafSkynet.SpotterRadioRange = 20000

--- How fast an alert crosses the map, in metres per second. Written from
--- `spotter_propagation_speed_kmh`; 1000 m/s is 3 600 km/h.
---
--- A **speed**, deliberately, and not a period. One hop covers the radio range, so exposing a period
--- as well would mean a mission maker who widens the range silently doubles how fast alerts travel.
--- The period is derived — see `veafSkynet.getSpotterHopPeriod`.
veafSkynet.SpotterPropagationSpeed = 1000

--- Seconds between two detection passes. Aligned on Skynet's own contact cycle; an aircraft at
--- 900 km/h covers 1.2 km between passes.
veafSkynet.SpotterDetectionPeriod = 5

--- A contact is acquired at the unit's range and only lost beyond range × this. An aircraft orbiting
--- exactly on the limit would otherwise flicker between seen and unseen every beat, and each flicker
--- is a message crossing the whole network.
veafSkynet.SpotterLossMargin = 1.1

--- Consecutive beats without contact before a triggered spotter re-arms. Covers terrain masking: an
--- aircraft dropping behind a ridge for a few seconds is not lost.
---
--- The margin above and this tolerance are both needed and cover different causes. The tolerance
--- alone lets an aircraft orbiting on the limit re-trigger every time it stays out for four beats;
--- the margin alone does nothing about ridges.
veafSkynet.SpotterLossBeats = 3

--- Each unit draws its own detection range once for the mission, ± this fraction of the table value.
--- Drawing per attempt would make the limit flicker — the same reason Skynet draws a site's last-line
--- radius once rather than per shot.
veafSkynet.SpotterRangeJitter = 0.2

--- Metres above the spotter the line-of-sight ray starts from, so a spotter looks from its eyes
--- rather than from the mud. The offset CTLD uses.
veafSkynet.SpotterEyeHeight = 2

--- How often each class of unit has its radio links recomputed, in seconds. A unit is classified by
--- its **type** and not by whether it has been seen moving: a tank parked for ten minutes is still
--- capable of moving, so it is already in the right loop when it starts.
veafSkynet.SpotterSpeedClasses = {
  Fast = "fast",
  Mobile = "mobile",
  Slow = "slow",
}

--- Detection and relaying are two independent properties, because they genuinely are: a command
--- vehicle sees little and relays perfectly, an ammunition dump does neither. A `range` of 0 means
--- the unit never sees anything, not that it sees a little.
---
--- **Ordered, and tested most specific first**, the way AIEN does it — a helicopter carries `Air` as
--- well as `Helicopters`, so the order is what makes it a 15 km spotter rather than a 30 km one.
--- Attribute names verified against `src/scripts/community/AIEN.lua`, which runs in game.
---
--- Three kinds of unit detect nothing here, and only these three: `AWACS` and `EWR`, already enrolled
--- as EW radars by `addGroupToNetwork`, and `SAM elements`, covered by the last line of defence with
--- a radius drawn once between 10 and 15 km. Giving a SAM site a second competing radius would mean
--- the larger one always wins and the other setting is dead weight — the exact failure mode of the
--- `ewr` spawn option, inert for four years because nothing ever applied it. They all still relay,
--- which is what produces the domino: a battery that is warned lights up *and passes the word*, so a
--- line of batteries wakes in the direction of the penetration.
---
--- The exclusion stops there. An earlier draft excluded the whole `Air` attribute on the grounds that
--- Skynet already senses through it; that only holds for `AWACS` and `EWR`, since a fighter or a
--- transport belongs to no Skynet network. A consequence, decided on 2026-09-21 and judged
--- desirable: a player flying for the network's coalition becomes a spotter.
---
--- The ranges are reasoned, not sourced. Their shape is the argument: aircraft see furthest and by a
--- wide margin, since no terrain masks them and many carry a radar; air-defence units see furthest on
--- the ground because watching the sky is their job; armour sees least, a closed-down tank having a
--- poor view of anything above the horizon. Ground ranges stay well under the radio range on purpose,
--- so what limits the network is the sensing and not the plumbing — aeroplanes are the deliberate
--- exception, seeing 30 km against a 20 km radio, so an aircraft has to close on the ground network
--- to pass the word.
veafSkynet.SpotterUnitTable = {
  { attribute = "AWACS", range = 0, relays = true, class = veafSkynet.SpotterSpeedClasses.Fast },
  { attribute = "EWR", range = 0, relays = true, class = veafSkynet.SpotterSpeedClasses.Mobile },
  { attribute = "SAM elements", range = 0, relays = true, class = veafSkynet.SpotterSpeedClasses.Mobile },
  { attribute = "Helicopters", range = 15000, relays = true, class = veafSkynet.SpotterSpeedClasses.Fast },
  { attribute = "Air", range = 30000, relays = true, class = veafSkynet.SpotterSpeedClasses.Fast },
  { attribute = "Ships", range = 12000, relays = true, class = veafSkynet.SpotterSpeedClasses.Mobile },
  { attribute = "MANPADS", range = 10000, relays = true, class = veafSkynet.SpotterSpeedClasses.Slow },
  { attribute = "AAA", range = 8000, relays = true, class = veafSkynet.SpotterSpeedClasses.Mobile },
  { attribute = "Air Defence vehicles", range = 8000, relays = true, class = veafSkynet.SpotterSpeedClasses.Mobile },
  { attribute = "Infantry", range = 4000, relays = true, class = veafSkynet.SpotterSpeedClasses.Slow },
  { attribute = "MLRS", range = 3000, relays = true, class = veafSkynet.SpotterSpeedClasses.Mobile },
  { attribute = "Artillery", range = 3000, relays = true, class = veafSkynet.SpotterSpeedClasses.Mobile },
  { attribute = "Tanks", range = 3000, relays = true, class = veafSkynet.SpotterSpeedClasses.Mobile },
  { attribute = "IFV", range = 3000, relays = true, class = veafSkynet.SpotterSpeedClasses.Mobile },
  { attribute = "APC", range = 3000, relays = true, class = veafSkynet.SpotterSpeedClasses.Mobile },
  { attribute = "Armored vehicles", range = 3000, relays = true, class = veafSkynet.SpotterSpeedClasses.Mobile },
  { attribute = "Unarmed vehicles", range = 3000, relays = true, class = veafSkynet.SpotterSpeedClasses.Mobile },
  { attribute = "Trucks", range = 3000, relays = true, class = veafSkynet.SpotterSpeedClasses.Mobile },
}

--- What a unit matching nothing in the table gets: statics, buildings, and anything DCS adds after
--- this was written. No eyes and no radio, which is the safe answer for an unknown.
veafSkynet.SpotterDefaultProfile = { range = 0, relays = false, class = veafSkynet.SpotterSpeedClasses.Slow }

--- Per unit name: the profile drawn for it, `{ range, relays, class }`. Keyed on the name so a unit
--- respawned under the same name keeps the eyes it had, rather than drawing a new pair.
veafSkynet.spotterProfiles = {}

--- Per spotter name, per contact name: `{ triggered = <boolean>, missedBeats = <number> }`.
--- A spotter is *armed* until it reports, *triggered* while it keeps seeing the same aircraft.
veafSkynet.spotterLatches = {}

--- Whether the detection pass is scheduled. Idempotent for the same reason
--- `_armVanishedSitesSweep` is: a reinitialisation must not stack a second beat.
veafSkynet.spotterDetectionArmed = false

--- Seconds an alert takes to cross one radio hop: the range it covers, divided by how fast alerts
--- are meant to travel.
---
--- Derived rather than configured, so widening the radio range slows the hops instead of silently
--- doubling the speed at which the alert outruns the aircraft. At the defaults — 20 km and
--- 3 600 km/h — this is 20 s, and an alert crosses a fully connected 200 km front in about four
--- minutes against thirteen for a fighter to fly it.
---
--- @return number seconds per hop, always strictly positive
function veafSkynet.getSpotterHopPeriod()
  local speed = veafSkynet.SpotterPropagationSpeed
  if not speed or speed <= 0 then
    -- A speed of zero would divide by nothing and stop the network dead, silently. Fall back on the
    -- shipped default rather than on infinity.
    speed = 1000
  end
  return veafSkynet.getSpotterRadioRange() / speed
end

--- The radio range actually used, in metres.
---
--- An accessor rather than the field read directly, because a zero or negative range has to be
--- refused in **one** place. Refused in the hop period alone it would still build a graph with no
--- edges at all: the feature would be on, cost its beats, and do nothing, with nothing in the log to
--- say why.
---
--- @return number metres, always strictly positive
function veafSkynet.getSpotterRadioRange()
  local range = veafSkynet.SpotterRadioRange
  if not range or range <= 0 then
    return 20000
  end
  return range
end

--- The row of `SpotterUnitTable` this unit matches, or the default profile.
---
--- @param dcsUnit table a DCS Unit handle
--- @return table `{ range = <metres>, relays = <boolean>, class = <speed class> }`, never nil
function veafSkynet.matchSpotterUnitRow(dcsUnit)
  if not dcsUnit or not dcsUnit.hasAttribute then
    return veafSkynet.SpotterDefaultProfile
  end
  for _, row in ipairs(veafSkynet.SpotterUnitTable) do
    local ok, matches = pcall(dcsUnit.hasAttribute, dcsUnit, row.attribute)
    if ok and matches then
      return row
    end
  end
  return veafSkynet.SpotterDefaultProfile
end

--- This unit's own eyes and radio, drawn once and remembered.
---
--- The ± jitter is applied at the draw and never again: asking for a fresh number every beat would
--- make the limit wander by four kilometres between two passes, and a spotter would report the same
--- aircraft over and over as the limit crossed it.
---
--- @param dcsUnit table a DCS Unit handle
--- @param unitName string|nil its name, when the caller already has it
--- @return table `{ range = <metres>, relays = <boolean>, class = <speed class> }`, never nil
function veafSkynet.getSpotterProfile(dcsUnit, unitName)
  local name = unitName or veafSkynet.safeDcsName(dcsUnit)
  if not name then
    return veafSkynet.SpotterDefaultProfile
  end
  local known = veafSkynet.spotterProfiles[name]
  if known then
    return known
  end

  local row = veafSkynet.matchSpotterUnitRow(dcsUnit)
  local range = row.range
  if range > 0 then
    range = range * (1 + (math.random() * 2 - 1) * veafSkynet.SpotterRangeJitter)
  end
  local profile = { range = range, relays = row.relays, class = row.class }
  veafSkynet.spotterProfiles[name] = profile
  return profile
end

--- Squared straight-line distance between two DCS points, altitude included.
---
--- Slant range rather than ground range, and that is the honest measure for an aircraft: a fighter
--- eight kilometres overhead is eight kilometres away, not on top of the spotter. The radio graph
--- measures on the ground instead, where the two units are both at surface level.
---
--- Squared, and compared against squared limits, because the beat runs this once per spotter per
--- aircraft every five seconds — thousands of times on a busy mission — and a square root buys
--- nothing when both sides of the comparison can be squared instead.
---
--- @param a table vec3
--- @param b table vec3
--- @return number metres squared
local function _slantRangeSq(a, b)
  local dx = a.x - b.x
  local dy = (a.y or 0) - (b.y or 0)
  local dz = a.z - b.z
  return dx * dx + dy * dy + dz * dz
end

--- Can this spotter see that aircraft right now, terrain included?
---
--- Called **only on a transition** — when a contact is gained or lost — never once per beat per pair.
--- That is what makes the ray affordable at mission scale, so it is a property the tests assert
--- rather than a comment.
---
--- @param spotterPoint table vec3 of the spotter
--- @param contactPoint table vec3 of the aircraft
--- @return boolean
function veafSkynet.spotterHasLineOfSight(spotterPoint, contactPoint)
  if not land or not land.isVisible then
    -- No terrain service: report seen rather than blind, so a missing API degrades into the
    -- behaviour the feature had before line of sight was added instead of switching it off.
    return true
  end
  local eye = { x = spotterPoint.x, y = (spotterPoint.y or 0) + veafSkynet.SpotterEyeHeight, z = spotterPoint.z }
  local ok, visible = pcall(land.isVisible, eye, contactPoint)
  if not ok then
    return true
  end
  return visible and true or false
end

--- Advance one spotter's latch for one aircraft, for one beat.
---
--- Armed and the aircraft comes into range with line of sight → reports once and becomes triggered,
--- then says nothing more while it keeps seeing it. Triggered and it loses the aircraft → after
--- `SpotterLossBeats` consecutive beats without contact it re-arms, and will report that aircraft
--- again on reacquisition.
---
--- @param spotterName string
--- @param contactName string
--- @param inRange boolean is the aircraft within the spotter's own drawn range
--- @param stillInRange boolean is it within range × the loss margin
--- @param seesIt function () -> boolean, the line-of-sight ray, called at most once and only on a
---        transition
--- @return string|nil `"acquired"`, `"lost"`, or nil when nothing changed
function veafSkynet.stepSpotterLatch(spotterName, contactName, inRange, stillInRange, seesIt)
  local latches = veafSkynet.spotterLatches[spotterName]
  if not latches then
    latches = {}
    veafSkynet.spotterLatches[spotterName] = latches
  end
  local latch = latches[contactName]

  if not latch or not latch.triggered then
    if inRange and seesIt() then
      latches[contactName] = { triggered = true, missedBeats = 0 }
      return "acquired"
    end
    return nil
  end

  -- Triggered. The margin is applied here and only here: a contact is gained at the range and given
  -- up beyond range × margin, so an aircraft holding station on the limit stays held.
  local held = stillInRange and seesIt()
  if held then
    latch.missedBeats = 0
    return nil
  end

  latch.missedBeats = latch.missedBeats + 1
  if latch.missedBeats >= veafSkynet.SpotterLossBeats then
    latches[contactName] = nil
    return "lost"
  end
  return nil
end

--- Called when a spotter gains a contact: it puts an alert on the network.
---
--- @param coa number the spotter's coalition id
--- @param spotterName string
--- @param contactName string
function veafSkynet.onSpotterAcquired(coa, spotterName, contactName)
  veaf.loggers.get(veafSkynet.Id):debug(string.format("spotter [%s] acquired [%s]", veaf.p(spotterName), veaf.p(contactName)))
  -- Recorded for the status page at the moment it happens: once the alert has spread there is no way
  -- back from a contact held by a dozen units to the eye that first saw it.
  veafSkynet.recordSpotterAcquisition(coa, tostring(spotterName) .. " -> " .. tostring(contactName))
  veafSkynet.emitSpotterMessage(coa, "alert", spotterName, contactName)
  veafSkynet.requestSpotterViewRedraw()
end

--- Called when a spotter gives up a contact, after the beat tolerance has run out: it puts a
--- cancellation on the network, travelling the same way the alert did.
---
--- @param coa number the spotter's coalition id
--- @param spotterName string
--- @param contactName string
function veafSkynet.onSpotterLost(coa, spotterName, contactName)
  veaf.loggers.get(veafSkynet.Id):debug(string.format("spotter [%s] lost [%s]", veaf.p(spotterName), veaf.p(contactName)))
  veafSkynet.emitSpotterMessage(coa, "cancel", spotterName, contactName)
  veafSkynet.requestSpotterViewRedraw()
end

--- Re-arm every latch holding an aircraft that is no longer a contact, and cancel what it started.
---
--- The detection loop can only step the pairs it walks, and it walks the aircraft currently in the
--- sky. An aircraft that is destroyed, that lands, or that leaves the mission simply stops appearing
--- — so without this its latches would stay *triggered* for good. That is not a tidy-up detail: a
--- triggered latch is what the heartbeat speaks for, so one jet shot down while it was being watched
--- leaves a phantom contact crossing the whole network every two minutes until the mission ends, held
--- forever because each heartbeat refreshes it past the forget delay.
---
--- A cancellation is sent rather than the contact merely dropped locally, for the same reason the
--- mechanism prefers cancellations everywhere else: the sites holding it are elsewhere on the map and
--- have no other way of being told.
---
--- @param contacts table the aircraft currently visible to this coalition, as `listHostileAircraft`
---        returns them
--- @param coa number the coalition whose latches to check
function veafSkynet.dropLatchesForVanishedContacts(contacts, coa)
  local present = {}
  for _, contact in ipairs(contacts) do
    present[contact.name] = true
  end

  for spotterName, latches in pairs(veafSkynet.spotterLatches) do
    local gone = {}
    for aircraft, latch in pairs(latches) do
      if latch.triggered and not present[aircraft] then
        table.insert(gone, aircraft)
      end
    end
    for _, aircraft in ipairs(gone) do
      latches[aircraft] = nil
      veaf.loggers
        .get(veafSkynet.Id)
        :debug(string.format("spotter [%s] gave up [%s]: no longer a contact", veaf.p(spotterName), veaf.p(aircraft)))
      veafSkynet.emitSpotterMessage(coa, "cancel", spotterName, aircraft)
    end
    if not next(latches) then
      veafSkynet.spotterLatches[spotterName] = nil
    end
  end
end

--- Forget everything a spotter knew. Called when it leaves the mission, so a dead unit does not keep
--- a contact alive through the heartbeat.
---
--- @param spotterName string
function veafSkynet.forgetSpotter(spotterName)
  veafSkynet.spotterLatches[spotterName] = nil
end

--- The coalitions that have a live Skynet network, as a set.
---
--- The feature lives inside the Skynet helper and does nothing when Skynet is off: there is no
--- alarm-state fallback for missions not using it (dropped on 2026-09-20). A network switched off on
--- purpose stays off — nothing may bring it back up implicitly, spotters included.
---
--- @return table set of coalition ids
function veafSkynet.getSpotterCoalitions()
  local coalitions = {}
  for _, veafSkynetNetwork in pairs(veafSkynet.structure) do
    if veafSkynetNetwork and not veafSkynetNetwork.deactivated and veafSkynetNetwork.coalitionID then
      coalitions[veafSkynetNetwork.coalitionID] = true
    end
  end
  return coalitions
end

--- The coalition this one is looking for. RED watches BLUE and the other way round; neutral units
--- are nobody's contact and nobody's spotter.
---
--- @param coa number a coalition id
--- @return number|nil the opposing coalition id, or nil for neutral
function veafSkynet.getOpposingCoalition(coa)
  if coa == coalition.side.RED then
    return coalition.side.BLUE
  elseif coa == coalition.side.BLUE then
    return coalition.side.RED
  end
  return nil
end

--- Every unit of this coalition that can see something, with the profile it drew.
---
--- @param coa number a coalition id
--- @return table array of `{ name = <string>, unit = <DCS Unit>, profile = <table> }`
function veafSkynet.listSpotters(coa)
  local spotters = {}
  local ok, dcsGroups = pcall(coalition.getGroups, coa)
  if not ok or not dcsGroups then
    return spotters
  end
  for _, dcsGroup in pairs(dcsGroups) do
    if veafSkynet.dcsObjectStillExists(dcsGroup) then
      local gotUnits, dcsUnits_ = pcall(dcsGroup.getUnits, dcsGroup)
      if gotUnits and dcsUnits_ then
        for _, dcsUnit in pairs(dcsUnits_) do
          if veafSkynet.dcsObjectStillExists(dcsUnit) then
            local name = veafSkynet.safeDcsName(dcsUnit)
            if name then
              local profile = veafSkynet.getSpotterProfile(dcsUnit, name)
              if profile.range > 0 then
                table.insert(spotters, { name = name, unit = dcsUnit, profile = profile })
              end
            end
          end
        end
      end
    end
  end
  return spotters
end

--- Every airborne aircraft of the opposing coalition — what a spotter is looking for.
---
--- Airborne is the filter that matters: an aeroplane parked on its ramp is not the penetration this
--- network exists to see coming, and reporting it would wake every battery in radio reach of an
--- airfield for the whole mission.
---
--- @param coa number the *spotting* coalition's id
--- @return table array of `{ name = <string>, unit = <DCS Unit> }`
function veafSkynet.listHostileAircraft(coa)
  local contacts = {}
  local hostile = veafSkynet.getOpposingCoalition(coa)
  if not hostile then
    return contacts
  end
  for _, category in ipairs({ Group.Category.AIRPLANE, Group.Category.HELICOPTER }) do
    local ok, dcsGroups = pcall(coalition.getGroups, hostile, category)
    if ok and dcsGroups then
      for _, dcsGroup in pairs(dcsGroups) do
        if veafSkynet.dcsObjectStillExists(dcsGroup) then
          local gotUnits, dcsUnits_ = pcall(dcsGroup.getUnits, dcsGroup)
          if gotUnits and dcsUnits_ then
            for _, dcsUnit in pairs(dcsUnits_) do
              if veafSkynet.dcsObjectStillExists(dcsUnit) then
                local airborne, inAir = pcall(dcsUnit.inAir, dcsUnit)
                local name = veafSkynet.safeDcsName(dcsUnit)
                if name and airborne and inAir then
                  table.insert(contacts, { name = name, unit = dcsUnit })
                end
              end
            end
          end
        end
      end
    end
  end
  return contacts
end

--- One detection pass, over every coalition that has a live Skynet network.
---
--- The line-of-sight ray is traced only for a pair the distance test has not already settled — the
--- latch asks for it through a closure, memoised for the pair within the beat. Everything else is
--- squared-distance arithmetic.
---
--- Returns nothing: `veafScheduler` re-arms a repeating task from its own `rep`, and ignores what the
--- task returned. Handing back a period here would read as if it drove the schedule and would not.
function veafSkynet.spotterDetectionBeat()
  if not veafSkynet.SpotterNetwork then
    return
  end

  for coa, _ in pairs(veafSkynet.getSpotterCoalitions()) do
    local contacts = veafSkynet.listHostileAircraft(coa)

    -- Aircraft that are no longer in the sky cannot be stepped by the loop below, because the loop
    -- only walks the ones that are. Left alone, their latches stay *triggered* for the rest of the
    -- mission: the heartbeat keeps speaking for a jet that was shot down two hours ago, the contact
    -- is refreshed and therefore never forgotten, and every status page lists it as live. So they are
    -- given up here, explicitly, before anything else.
    veafSkynet.dropLatchesForVanishedContacts(contacts, coa)

    if #contacts > 0 then
      local spotters = veafSkynet.listSpotters(coa)
      for _, spotter in ipairs(spotters) do
        local gotPoint, spotterPoint = pcall(spotter.unit.getPoint, spotter.unit)
        if gotPoint and spotterPoint then
          local rangeSq = spotter.profile.range * spotter.profile.range
          local marginSq = rangeSq * veafSkynet.SpotterLossMargin * veafSkynet.SpotterLossMargin
          for _, contact in ipairs(contacts) do
            local gotContact, contactPoint = pcall(contact.unit.getPoint, contact.unit)
            if gotContact and contactPoint then
              local distanceSq = _slantRangeSq(spotterPoint, contactPoint)
              local seen = nil
              local event = veafSkynet.stepSpotterLatch(
                spotter.name,
                contact.name,
                distanceSq <= rangeSq,
                distanceSq <= marginSq,
                function()
                  -- Memoised for this pair on this beat: the latch may ask twice on a transition, and
                  -- the ray is the expensive part.
                  if seen == nil then
                    seen = veafSkynet.spotterHasLineOfSight(spotterPoint, contactPoint)
                  end
                  return seen
                end
              )
              if event == "acquired" then
                veafSkynet.onSpotterAcquired(coa, spotter.name, contact.name, contact.unit)
              elseif event == "lost" then
                veafSkynet.onSpotterLost(coa, spotter.name, contact.name)
              end
            end
          end
        end
      end
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Spotter network — the radio graph
--
-- Who can talk to whom. Rebuilt in place by three loops, one per speed class, each recomputing only
-- the edges of the units of its class that have actually moved.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Metres a unit must cover before its edges are recomputed. Below it, nothing is touched.
veafSkynet.SpotterMoveThreshold = 2000

--- Seconds between two passes of each class's loop.
---
--- Honest record: the movement check costs 0.15 ms for 2 000 units, so staging the loops optimises
--- almost nothing measurable. They were chosen so each class is re-read at a rate that suits how
--- fast it can actually move, and they do no harm — but they are not a performance feature and
--- should not be sold as one.
veafSkynet.SpotterGraphPeriods = {
  [veafSkynet.SpotterSpeedClasses.Fast] = 10,
  [veafSkynet.SpotterSpeedClasses.Mobile] = 20,
  [veafSkynet.SpotterSpeedClasses.Slow] = 30,
}

--- Per coalition: `{ adjacency = { [name] = { [other] = true } }, nodes = { [name] = { x, z, class } } }`.
---
--- **The adjacency is a set of names, not a list**, and that is measured rather than taste. Removing
--- a back-edge from a list means scanning it, so patching costs O(degree²) per node; re-edging a
--- hundred units — a combat zone spawning at once — costs 86 ms with lists against 13.7 ms with sets
--- on the densest layout built, 2 000 units and 230 577 edges. Everywhere else the two are within
--- noise. Reproduce with `lua test/lua/bench_spotter_network.lua`.
veafSkynet.spotterGraphs = {}

--- Whether the three graph passes are on the clock.
veafSkynet.spotterGraphArmed = false

--- The graph of a coalition, created empty on first use.
---
--- @param coa number a coalition id
--- @return table `{ adjacency = <table>, nodes = <table> }`
function veafSkynet.getSpotterGraph(coa)
  local graph = veafSkynet.spotterGraphs[coa]
  if not graph then
    graph = { adjacency = {}, nodes = {} }
    veafSkynet.spotterGraphs[coa] = graph
  end
  return graph
end

--- Take a unit out of the graph, back-edges included.
---
--- @param graph table
--- @param name string
function veafSkynet.removeSpotterNode(graph, name)
  local edges = graph.adjacency[name]
  if edges then
    for other, _ in pairs(edges) do
      local backEdges = graph.adjacency[other]
      if backEdges then
        backEdges[name] = nil
      end
    end
  end
  graph.adjacency[name] = nil
  graph.nodes[name] = nil
end

--- Recompute one unit's edges from scratch, against every other node of the graph.
---
--- A **replacement**, not a surgical removal: the old edges go, the new ones are measured. That is
--- what avoids the individual-edge-removal code this feature would otherwise need, and it is why the
--- set representation pays — dropping a back-edge is one assignment rather than a scan.
---
--- Measured on the ground plane. Altitude is ignored on purpose: a radio link only gets better with
--- height, so counting an aircraft overhead as being directly above the unit it is talking to is the
--- physically sensible reading, not a shortcut.
---
--- @param graph table
--- @param name string
--- @param x number
--- @param z number
--- @param class string one of `veafSkynet.SpotterSpeedClasses`
function veafSkynet.reEdgeSpotterNode(graph, name, x, z, class)
  veafSkynet.removeSpotterNode(graph, name)

  local edges = {}
  graph.adjacency[name] = edges
  graph.nodes[name] = { x = x, z = z, class = class }

  local range = veafSkynet.getSpotterRadioRange()
  local rangeSq = range * range
  for other, node in pairs(graph.nodes) do
    if other ~= name then
      local dx = x - node.x
      local dz = z - node.z
      if dx * dx + dz * dz <= rangeSq then
        edges[other] = true
        graph.adjacency[other][name] = true
      end
    end
  end
end

--- Every unit of this coalition and this speed class that can relay.
---
--- Classification comes from the unit **type**, not from observation: a tank parked for ten minutes
--- is still capable of moving, so it is already in the mobile loop when it starts rolling rather than
--- being promoted into it afterwards.
---
--- @param coa number a coalition id
--- @param class string one of `veafSkynet.SpotterSpeedClasses`
--- @return table array of `{ name = <string>, x = <number>, z = <number> }`
function veafSkynet.listSpotterRelays(coa, class)
  local relays = {}
  local ok, dcsGroups = pcall(coalition.getGroups, coa)
  if not ok or not dcsGroups then
    return relays
  end
  for _, dcsGroup in pairs(dcsGroups) do
    if veafSkynet.dcsObjectStillExists(dcsGroup) then
      local gotUnits, groupUnits = pcall(dcsGroup.getUnits, dcsGroup)
      if gotUnits and groupUnits then
        for _, dcsUnit in pairs(groupUnits) do
          if veafSkynet.dcsObjectStillExists(dcsUnit) then
            local name = veafSkynet.safeDcsName(dcsUnit)
            if name then
              local profile = veafSkynet.getSpotterProfile(dcsUnit, name)
              if profile.relays and profile.class == class then
                local gotPoint, point = pcall(dcsUnit.getPoint, dcsUnit)
                if gotPoint and point then
                  table.insert(relays, { name = name, x = point.x, z = point.z })
                end
              end
            end
          end
        end
      end
    end
  end
  return relays
end

--- One pass of one class's loop, over every coalition that has a live Skynet network.
---
--- The same pass picks up units that appeared and units that vanished, which is why no DCS event has
--- to be listened to — and why a combat zone spawning a hundred units at once cannot set off a burst
--- of rebuilds. Nothing is triggered by spawning at all: the cost is one spike at the next pass, and
--- that spike is the 13.7 ms the bench measures.
---
--- The price, accepted: a freshly spawned group takes up to 30 s to enter the graph. Its *detection*
--- works immediately, since that is the 5 s beat and it does not read the graph — so its units see,
--- but cannot yet relay.
---
--- Returns nothing, for the same reason `spotterDetectionBeat` does.
---
--- @param class string one of `veafSkynet.SpotterSpeedClasses`
function veafSkynet.spotterGraphPass(class)
  if not veafSkynet.SpotterNetwork then
    return
  end

  local thresholdSq = veafSkynet.SpotterMoveThreshold * veafSkynet.SpotterMoveThreshold
  for coa, _ in pairs(veafSkynet.getSpotterCoalitions()) do
    local graph = veafSkynet.getSpotterGraph(coa)
    local seen = {}
    local changed = false
    for _, relay in ipairs(veafSkynet.listSpotterRelays(coa, class)) do
      seen[relay.name] = true
      local node = graph.nodes[relay.name]
      if not node then
        veafSkynet.reEdgeSpotterNode(graph, relay.name, relay.x, relay.z, class)
        changed = true
      else
        local dx = relay.x - node.x
        local dz = relay.z - node.z
        if dx * dx + dz * dz > thresholdSq then
          veafSkynet.reEdgeSpotterNode(graph, relay.name, relay.x, relay.z, class)
          changed = true
        end
      end
    end

    -- Whatever this class held last pass and no longer does has left the mission. Collected first,
    -- because removing from a table being walked with `pairs` is not something to rely on.
    local gone = {}
    for name, node in pairs(graph.nodes) do
      if node.class == class and not seen[name] then
        table.insert(gone, name)
      end
    end
    for _, name in ipairs(gone) do
      veafSkynet.removeSpotterNode(graph, name)
    end

    -- The map view draws units where they were last re-edged, so a pass that moved one has
    -- invalidated it: without this a spotter that drives on while still watching keeps its marker,
    -- and its range circle, where it first saw the aircraft.
    --
    -- Only when something actually moved, appeared or vanished. Asking on every pass would redraw
    -- every ten seconds whether or not anything changed, and a redraw takes the markers off the map
    -- and puts them back — which reads as a blink. Asked for rather than done, because this is
    -- exactly the burst the coalescing guard exists for: three class passes and a combat zone
    -- spawning all land within the same second.
    if changed or #gone > 0 then
      veafSkynet.requestSpotterViewRedraw()
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Spotter network — propagation
--
-- Three kinds of message travel the graph, one hop per period:
--
--   * an **alert**, when a spotter acquires an aircraft: recipients hold the contact;
--   * a **cancellation**, when it loses it: recipients drop the contact;
--   * a **heartbeat**, re-sent while a contact is still held, proving the link is alive.
--
-- The heartbeat is the safety net, and it covers every way things go wrong without having to tell
-- them apart: a cancellation lost because a relay died, a path broken by a graph that has been
-- reconfigured since, a spotter killed before it could cancel. A unit that has heard nothing for
-- long enough simply forgets.
--
-- The information therefore has a life of its own, which is the point. A recomputed-state model
-- would have been simpler and cheaper, and in it killing the spotter instantly extinguishes the
-- defence it had just alerted — rewarding the hunt for the rifleman over the hunt for the battery.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Seconds between two heartbeats from a spotter still holding a contact.
veafSkynet.SpotterHeartbeatPeriod = 120

--- Seconds a held contact survives without being heard from again. Three heartbeats: one lost
--- heartbeat must not extinguish a defence, three in a row means the path is genuinely gone.
veafSkynet.SpotterForgetDelay = 360

--- Per coalition, per unit, per aircraft: `{ stamp = <number>, heardAt = <number>, origin = <string> }`.
---
--- `stamp` is the emission time of the freshest message this unit has processed for that aircraft.
--- It serves both rules at once:
---
---   * **ordering** — a message older than the last one processed is ignored, or a cancellation
---     overtaking its own alert (possible, since the graph is reconfigured between the two) would
---     leave a site holding a contact forever;
---   * **relaying** — a unit passes on only what is fresher than what it already passed on, which
---     terminates the flood by itself, since a message carries a fixed stamp and each unit therefore
---     relays it at most once.
veafSkynet.spotterContacts = {}

--- Per coalition: the messages still travelling, each `{ kind, aircraft, origin, stamp, frontier }`
--- where `frontier` is the set of units reached by the last hop and about to relay.
veafSkynet.spotterWaves = {}

--- Whether the propagation and heartbeat loops are on the clock.
veafSkynet.spotterPropagationArmed = false

--- What this unit currently knows, as `{ [aircraftName] = { stamp, heardAt, origin } }`.
---
--- @param coa number a coalition id
--- @param unitName string
--- @return table never nil, possibly empty
function veafSkynet.getSpotterContacts(coa, unitName)
  local perCoalition = veafSkynet.spotterContacts[coa]
  if not perCoalition then
    return {}
  end
  return perCoalition[unitName] or {}
end

--- Record a message at one unit, if it is fresher than what that unit already knows.
---
--- @param coa number
--- @param unitName string
--- @param message table
--- @return boolean true when it was accepted, and therefore worth relaying
function veafSkynet.deliverSpotterMessage(coa, unitName, message)
  local perCoalition = veafSkynet.spotterContacts[coa]
  if not perCoalition then
    perCoalition = {}
    veafSkynet.spotterContacts[coa] = perCoalition
  end
  local known = perCoalition[unitName]
  if not known then
    known = {}
    perCoalition[unitName] = known
  end

  local current = known[message.aircraft]
  if current and current.stamp >= message.stamp then
    return false
  end

  if message.kind == "cancel" then
    -- Remembered as a *stamped* cancellation rather than erased, so an alert still in flight behind
    -- it cannot re-light the site it has just extinguished.
    known[message.aircraft] = { stamp = message.stamp, heardAt = timer.getTime(), origin = message.origin, cancelled = true }
  else
    known[message.aircraft] = { stamp = message.stamp, heardAt = timer.getTime(), origin = message.origin }
  end
  return true
end

--- Put a message on the network, starting at the unit that raised it.
---
--- @param coa number
--- @param kind string `"alert"` or `"cancel"`
--- @param originName string the spotter
--- @param aircraftName string
---
--- No DCS handle travels with the message. It would be dead weight: the hand-over resolves the
--- aircraft by name through `Unit.getByName`, which is also the only way to tell a live aircraft from
--- one that has left — and a heartbeat has no handle to pass anyway.
function veafSkynet.emitSpotterMessage(coa, kind, originName, aircraftName)
  local message = {
    kind = kind,
    aircraft = aircraftName,
    origin = originName,
    stamp = timer.getTime(),
    frontier = {},
  }
  if veafSkynet.deliverSpotterMessage(coa, originName, message) then
    message.frontier[originName] = true
  end

  local waves = veafSkynet.spotterWaves[coa]
  if not waves then
    waves = {}
    veafSkynet.spotterWaves[coa] = waves
  end
  table.insert(waves, message)
end

--- Advance every wave by one hop, and forget contacts nobody has heard from.
---
--- Two spotters in the same pocket send two waves that meet in the middle, and every unit is served
--- by whichever reached it first — that is, by the nearest witness — because the second arrival is
--- no fresher than the first and so is not relayed. Two spotters in **separate** pockets produce two
--- independent fronts, which falls out of the marking being per unit; nothing is written for it, so
--- it is tested rather than assumed.
function veafSkynet.spotterPropagationTick()
  if not veafSkynet.SpotterNetwork then
    return
  end

  for coa, waves in pairs(veafSkynet.spotterWaves) do
    local graph = veafSkynet.getSpotterGraph(coa)
    local stillTravelling = {}
    for _, message in ipairs(waves) do
      local nextFrontier = {}
      for unitName, _ in pairs(message.frontier) do
        local edges = graph.adjacency[unitName]
        if edges then
          for neighbour, _ in pairs(edges) do
            if veafSkynet.deliverSpotterMessage(coa, neighbour, message) then
              nextFrontier[neighbour] = true
            end
          end
        end
      end
      if next(nextFrontier) then
        message.frontier = nextFrontier
        table.insert(stillTravelling, message)
      end
    end
    veafSkynet.spotterWaves[coa] = stillTravelling
  end

  veafSkynet.forgetStaleSpotterContacts()
end

--- Drop what has not been heard from within `SpotterForgetDelay`.
---
--- This is the net under every failure the design does not try to tell apart. A cancellation is the
--- clean way for a contact to end; this is the one that always works.
function veafSkynet.forgetStaleSpotterContacts()
  local now = timer.getTime()
  for _, perCoalition in pairs(veafSkynet.spotterContacts) do
    for unitName, known in pairs(perCoalition) do
      local stale = {}
      for aircraft, contact in pairs(known) do
        if now - contact.heardAt >= veafSkynet.SpotterForgetDelay then
          table.insert(stale, aircraft)
        end
      end
      for _, aircraft in ipairs(stale) do
        known[aircraft] = nil
      end
      if not next(known) then
        perCoalition[unitName] = nil
      end
    end
  end
end

--- Re-send an alert for every contact a spotter is still holding.
---
--- Read from the latches rather than from the contact table: the latch is what a pair of eyes is
--- actually looking at right now, and it is the only thing entitled to keep a contact alive.
---
--- A heartbeat puts a **second wave in flight alongside the first**, since the earlier one may still
--- be crossing the map. That is bounded and cheap: at most crossing time ÷ heartbeat period waves
--- per spotter per aircraft — four at the worst crossing measured, 457 s over a 120 s heartbeat —
--- and each wave only ever touches the edges of its own frontier, not the whole graph. An older wave
--- also dies of its own accord wherever a fresher one has already passed, because the unit refuses
--- it and it therefore has nowhere left to go.
function veafSkynet.spotterHeartbeat()
  if not veafSkynet.SpotterNetwork then
    return
  end
  local coalitions = veafSkynet.getSpotterCoalitions()
  for spotterName, latches in pairs(veafSkynet.spotterLatches) do
    for aircraft, latch in pairs(latches) do
      if latch.triggered then
        -- The spotter's own coalition is wherever it is already a node; a unit belongs to one graph.
        for coa, _ in pairs(coalitions) do
          if veafSkynet.getSpotterGraph(coa).nodes[spotterName] then
            veafSkynet.emitSpotterMessage(coa, "alert", spotterName, aircraft)
          end
        end
      end
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Spotter network — handing over to Skynet
--
-- A site that receives an alert does **not** light up. It holds the contact and waits, exactly as it
-- would for an early-warning radar, and goes live only when the aircraft enters its own firing
-- envelope. The network is a distributed EWR, not a wake-up trigger, and that is what makes it fit
-- Skynet instead of fighting it.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Whether the hand-over loop is on the clock.
veafSkynet.spotterHandoverArmed = false

--- Whether the missing-`reportContact` warning has already been written. Once is a diagnosis, every
--- five seconds for a four-hour mission is a log nobody can read.
veafSkynet.spotterHandoverDoorWarned = false

--- The aircraft a unit is currently holding, as DCS Unit handles, skipping the ones that have left.
---
--- @param coa number
--- @param unitName string
--- @return table array of DCS Unit handles
function veafSkynet.getHeldSpotterAircraft(coa, unitName)
  local held = {}
  for aircraftName, contact in pairs(veafSkynet.getSpotterContacts(coa, unitName)) do
    if not contact.cancelled then
      local dcsUnit = Unit.getByName(aircraftName)
      if veafSkynet.dcsObjectStillExists(dcsUnit) then
        table.insert(held, dcsUnit)
      end
    end
  end
  return held
end

--- One hand-over pass: every SAM site of every network, against what its own units are holding.
---
--- `isTargetInRange` is annotated as an expensive call in Skynet's own source, so it is reached only
--- for a site that actually holds an alert — the loop is written so a site holding nothing costs one
--- table lookup per unit and stops there.
---
--- `reportContact` deliberately bypasses the kill-zone test; that is its documented contract, written
--- for the last line of defence. Here the bypass is harmless and in fact convenient, since the
--- envelope has just been checked. **Every other guard still applies** — HARM silence, ammunition,
--- power, destruction — and none of them is re-implemented here.
function veafSkynet.spotterHandoverPass()
  if not veafSkynet.SpotterNetwork then
    return
  end

  for networkName, veafSkynetNetwork in pairs(veafSkynet.structure) do
    local iads = veafSkynetNetwork.iads
    if iads and not veafSkynetNetwork.deactivated and veafSkynetNetwork.coalitionID then
      local coa = veafSkynetNetwork.coalitionID
      local gotSites, samSites = pcall(iads.getSAMSites, iads)
      if gotSites and samSites then
        for _, samSite in pairs(samSites) do
          veafSkynet.handOverSpotterAlerts(networkName, iads, coa, samSite)
        end
      end
    end
  end
end

--- Hand one site whatever its own units are holding, if the aircraft is inside its envelope.
---
--- A site is a **group** in Skynet and the network is made of **units**, so the site holds what any
--- of its units holds. That is the right reading rather than a convenience: a battery's radio is not
--- attached to one particular vehicle.
---
--- @param networkName string
--- @param iads table the Skynet IADS
--- @param coa number
--- @param samSite table a Skynet SAM site
function veafSkynet.handOverSpotterAlerts(networkName, iads, coa, samSite)
  local dcsGroup = veafSkynet.getDcsGroupFromSkynetElement(samSite)
  if not dcsGroup then
    return
  end
  local gotUnits, siteUnits = pcall(dcsGroup.getUnits, dcsGroup)
  if not gotUnits or not siteUnits then
    return
  end

  -- Collected across the site's units first, so an aircraft two of them hold is reported once.
  local held = {}
  for _, dcsUnit in pairs(siteUnits) do
    local unitName = veafSkynet.safeDcsName(dcsUnit)
    if unitName then
      for _, dcsAircraft in ipairs(veafSkynet.getHeldSpotterAircraft(coa, unitName)) do
        held[veafSkynet.safeDcsName(dcsAircraft) or tostring(dcsAircraft)] = dcsAircraft
      end
    end
  end
  if not next(held) then
    return
  end

  for _, dcsAircraft in pairs(held) do
    local inEnvelope, answer = pcall(samSite.isTargetInRange, samSite, dcsAircraft)
    if inEnvelope and answer then
      if iads.reportContact then
        local reported = pcall(iads.reportContact, iads, dcsAircraft, samSite)
        if reported then
          veafSkynet.recordSpotterWakeUp(coa, tostring(samSite.dcsName) .. " <- " .. tostring(veafSkynet.safeDcsName(dcsAircraft)))
          veaf.loggers.get(veafSkynet.Id):debug(
            string.format(
              "spotter network handed [%s] to [%s] on [%s]",
              veaf.p(veafSkynet.safeDcsName(dcsAircraft)),
              veaf.p(samSite.dcsName),
              veaf.p(networkName)
            )
          )
        end
      elseif not veafSkynet.spotterHandoverDoorWarned then
        -- The door exists in VEAF/Skynet-IADS but the artifact vendored here predates it. Said once,
        -- and said plainly: the feature is switched on and cannot do the one thing it exists for.
        veafSkynet.spotterHandoverDoorWarned = true
        veaf.loggers.get(veafSkynet.Id):warn(
          "spotter network is on, but this Skynet build has no reportContact: alerts travel and no site is ever woken (vendor a Skynet release that carries it)"
        )
      end
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Spotter network — the status page
--
-- On the model of Skynet's own, and behind the same switch: the per-network `debugFlag`, which comes
-- from `debug_red` / `debug_blue`. No new setting.
--
-- This matters more here than a status page usually does. Once this ships there are **three** reasons
-- a site can light up — an early-warning radar, the last line of defence, or a spotter — and an
-- unexplained wake-up is already the most common report on this subject. With three causes and no
-- trace the question is undecidable, for us and for the mission maker.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Seconds between two status pages. Slower than the beats it reports on: a page is read by a human
--- afterwards, in a log, and one every five seconds would bury everything else in it.
veafSkynet.SpotterStatusPeriod = 60

--- Whether the status page is on the clock.
veafSkynet.spotterStatusArmed = false

--- Per coalition, the spotters that acquired a contact since the last page, as a **set** keyed on
--- `"<spotter> -> <aircraft>"`.
---
--- Recorded at the moment it happens, because by the time the page is printed the only thing left is
--- a contact held by a dozen units and no way back to the eye that saw it.
---
--- Keyed by coalition because the page prints one section per network: a flat list is printed under
--- every debug network's header, so a mission running both sides in debug would read red's sightings
--- as blue's. A page that can misattribute a wake-up is worse than no page, since the whole reason
--- for it is that a site can now light up for three different reasons.
veafSkynet.spotterStatusAcquisitions = {}

--- Per coalition, the sites woken since the last page, as a **set** keyed on `"<site> <- <aircraft>"`.
---
--- A set rather than a list, because the hand-over reports the same contact on every 5 s pass while
--- the aircraft stays inside the envelope — which is correct, Skynet ages contacts out — and a list
--- would therefore print the same line twelve times per page and bury everything else.
veafSkynet.spotterStatusWakeUps = {}

--- Record one line for one coalition, once however many times it happens before the next page.
---
--- @param bucket table `spotterStatusAcquisitions` or `spotterStatusWakeUps`
--- @param coa number
--- @param line string
local function _recordSpotterStatus(bucket, coa, line)
  local perCoalition = bucket[coa]
  if not perCoalition then
    perCoalition = {}
    bucket[coa] = perCoalition
  end
  perCoalition[line] = true
end

--- The keys of a set, in order. Nil is an empty set, so a coalition that saw nothing needs no guard
--- at the call site.
---
--- @param set table|nil
--- @return table array of strings, sorted
local function _sortedKeys(set)
  local keys = {}
  for key, _ in pairs(set or {}) do
    table.insert(keys, key)
  end
  table.sort(keys)
  return keys
end

--- Note that a spotter acquired a contact, for the next status page of its coalition.
---
--- @param coa number
--- @param line string `"<spotter> -> <aircraft>"`
function veafSkynet.recordSpotterAcquisition(coa, line)
  _recordSpotterStatus(veafSkynet.spotterStatusAcquisitions, coa, line)
end

--- Note that a site was woken, for the next status page of its coalition.
---
--- @param coa number
--- @param line string `"<site> <- <aircraft>"`
function veafSkynet.recordSpotterWakeUp(coa, line)
  _recordSpotterStatus(veafSkynet.spotterStatusWakeUps, coa, line)
end

--- Count the graph, in one walk: nodes, edges, and connected components.
---
--- The component count is the figure that answers *"why did my alert not travel"*, which the
--- connectivity measurements say will be the common question: at the shipped range, a mission whose
--- contents are spread thin still only gathers a small share of its units into the largest pocket,
--- and an alert never leaves the pocket it starts in.
---
--- @param graph table
--- @return number nodes
--- @return number edges
--- @return number components
--- @return number the size of the largest component
function veafSkynet.describeSpotterGraph(graph)
  local nodes, degrees = 0, 0
  for name, _ in pairs(graph.nodes) do
    nodes = nodes + 1
    for _ in pairs(graph.adjacency[name] or {}) do
      degrees = degrees + 1
    end
  end

  local visited, components, largest = {}, 0, 0
  for name, _ in pairs(graph.nodes) do
    if not visited[name] then
      components = components + 1
      local size, stack = 0, { name }
      visited[name] = true
      while #stack > 0 do
        local current = table.remove(stack)
        size = size + 1
        for neighbour, _ in pairs(graph.adjacency[current] or {}) do
          if not visited[neighbour] then
            visited[neighbour] = true
            table.insert(stack, neighbour)
          end
        end
      end
      if size > largest then
        largest = size
      end
    end
  end

  return nodes, degrees / 2, components, largest
end

--- Print one status page per network in debug mode, then forget what happened since the last one.
function veafSkynet.spotterStatusPage()
  if not veafSkynet.SpotterNetwork then
    return
  end

  for networkName, veafSkynetNetwork in pairs(veafSkynet.structure) do
    if veafSkynetNetwork and veafSkynetNetwork.debugFlag and veafSkynetNetwork.coalitionID then
      local coa = veafSkynetNetwork.coalitionID
      local logger = veaf.loggers.get(veafSkynet.Id)
      local nodes, edges, components, largest = veafSkynet.describeSpotterGraph(veafSkynet.getSpotterGraph(coa))
      logger:info(string.format("=== spotter network [%s] ===", tostring(networkName)))
      logger:info(string.format("  graph: %d units, %d links, %d pockets, largest %d", nodes, edges, components, largest))

      local now = timer.getTime()
      local alerts = 0
      for unitName, known in pairs(veafSkynet.spotterContacts[coa] or {}) do
        for aircraft, contact in pairs(known) do
          if not contact.cancelled then
            alerts = alerts + 1
            logger:info(
              string.format(
                "  alert: [%s] holds [%s] from [%s], %d s old",
                tostring(unitName),
                tostring(aircraft),
                tostring(contact.origin),
                math.floor(now - contact.heardAt)
              )
            )
          end
        end
      end
      if alerts == 0 then
        logger:info("  alert: none")
      end

      -- Sorted, because a set has no order of its own and a page whose lines move about between two
      -- prints is a page nobody can diff against the previous one.
      for _, acquisition in ipairs(_sortedKeys(veafSkynet.spotterStatusAcquisitions[coa])) do
        logger:info(string.format("  saw: %s", acquisition))
      end
      for _, wakeUp in ipairs(_sortedKeys(veafSkynet.spotterStatusWakeUps[coa])) do
        logger:info(string.format("  woke: %s", wakeUp))
      end
    end
  end

  veafSkynet.spotterStatusAcquisitions = {}
  veafSkynet.spotterStatusWakeUps = {}
end

--- Put the status page on the clock.
function veafSkynet._armSpotterStatus()
  if veafSkynet.spotterStatusArmed then
    return
  end
  if not veafSkynet.SpotterNetwork then
    return
  end
  veafSkynet.spotterStatusArmed = true
  veaf.scheduleFunction(veafSkynet.spotterStatusPage, {}, timer.getTime() + veafSkynet.SpotterStatusPeriod, veafSkynet.SpotterStatusPeriod)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Spotter network — the map view
--
-- Where the status page answers *"why did that happen"* in the log afterwards, this answers
-- *"what is happening"* while it happens: a marker on the F10 map at each spotter currently holding a
-- contact, with a circle at the range it is seeing from.
--
-- **It is a coalition view, and it cannot be anything narrower.** DCS offers `markToAll`,
-- `markToCoalition` and `markToGroup`, and a game master has no group (which is also why no
-- `USAGE_ForGroup` radio command reaches one). So everybody flying for that coalition sees these
-- markers too, and on a red network that hands red pilots a live tracker of blue aircraft. It is off
-- by default and switched on per network, deliberately.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- What `modules.SKYNET.spotter_view` can ask for.
---
--- `Radio` does not switch the view on: it puts the switch where a game master can reach it, and
--- leaves it off. That is the point of a toggle, and it is also the cautious reading given what the
--- view shows to a whole coalition.
veafSkynet.SpotterViewModes = {
  Off = "off",
  On = "on",
  Radio = "radio",
}

--- How the map view is offered. Written by the build from `modules.SKYNET.spotter_view`.
veafSkynet.SpotterView = veafSkynet.SpotterViewModes.Off

--- The i18n key of the radio menu the `radio` mode adds.
veafSkynet.RadioMenuName = "menu.skynet.root"

--- Per coalition, the radio submenu carrying that coalition's toggle.
veafSkynet.spotterViewRootPaths = {}

--- Whether the view has been set up from `SpotterView`.
veafSkynet.spotterViewArmed = false

--- Coalitions whose map view is switched on, as a set. Empty by default.
veafSkynet.spotterViewCoalitions = {}

--- The marker ids currently drawn, per coalition, so a redraw replaces rather than stacks.
veafSkynet.spotterViewMarkers = {}

--- Set when a redraw has been asked for and not yet run. See `veafSkynet.requestSpotterViewRedraw`.
veafSkynet.spotterRedrawScheduled = nil

--- Seconds a redraw request waits, so a burst of them becomes one redraw.
veafSkynet.SpotterRedrawDelay = 1

--- Show or hide the map view for one coalition.
---
--- @param coa number a coalition id
--- @param bEnabled boolean
function veafSkynet.showSpotterView(coa, bEnabled)
  if bEnabled then
    veafSkynet.spotterViewCoalitions[coa] = true
    veafSkynet.requestSpotterViewRedraw()
  else
    veafSkynet.spotterViewCoalitions[coa] = nil
    veafSkynet.eraseSpotterView(coa)
  end
end

--- Remove everything drawn for one coalition.
---
--- @param coa number
function veafSkynet.eraseSpotterView(coa)
  for _, markerId in ipairs(veafSkynet.spotterViewMarkers[coa] or {}) do
    pcall(trigger.action.removeMark, markerId)
  end
  veafSkynet.spotterViewMarkers[coa] = nil
end

--- Ask for a redraw, at most one per `SpotterRedrawDelay` however many times it is called.
---
--- This is the one place in the feature where work genuinely arrives in bursts: every alert, every
--- cancellation and every graph pass is a reason to redraw, and a combat zone spawning changes the
--- picture hundreds of times at once. Without the guard, ticket 02's "a spawn triggers nothing"
--- property is undone here.
---
--- The pattern is `veafRadio.refreshRadioMenu`'s, **with one difference that matters**: that one
--- clears its flag *inside* `if not veafRadio.dontCreateMenus then` (`veafRadio.lua:630`), so with
--- menus off the flag stays set forever and the guard never re-arms. It is harmless there, because
--- with menus off there is nothing the guard was protecting. It would not be harmless here: any early
--- return in the redraw — nothing to draw, the view switched off, the feature off — would latch the
--- flag and kill every later redraw for the rest of the mission. A coalescing guard that never
--- re-arms is worse than none, because the first redraw makes it look as though it works.
function veafSkynet.requestSpotterViewRedraw()
  if veafSkynet.spotterRedrawScheduled then
    return
  end
  veafSkynet.spotterRedrawScheduled =
    veaf.scheduleFunction(veafSkynet._redrawSpotterView, {}, timer.getTime() + veafSkynet.SpotterRedrawDelay)
end

--- Redraw every switched-on coalition's view.
function veafSkynet._redrawSpotterView()
  -- First act, unconditionally, before anything that can return early. See the comment above.
  veafSkynet.spotterRedrawScheduled = nil

  for coa, _ in pairs(veafSkynet.spotterViewCoalitions) do
    veafSkynet.eraseSpotterView(coa)
    if veafSkynet.SpotterNetwork then
      local markers = {}
      veafSkynet.spotterViewMarkers[coa] = markers
      for unitName, known in pairs(veafSkynet.spotterContacts[coa] or {}) do
        for aircraft, contact in pairs(known) do
          -- Only where the alert was raised: a marker per unit *holding* it would put one on every
          -- unit of the pocket, which is a wall of markers saying the same thing.
          if not contact.cancelled and contact.origin == unitName then
            local dcsUnit = Unit.getByName(unitName)
            if veafSkynet.dcsObjectStillExists(dcsUnit) then
              local gotPoint, point = pcall(dcsUnit.getPoint, dcsUnit)
              if gotPoint and point then
                local markerId = veaf.getUniqueIdentifier()
                pcall(
                  trigger.action.markToCoalition,
                  markerId,
                  string.format("%s sees %s", tostring(unitName), tostring(aircraft)),
                  point,
                  coa,
                  true,
                  nil
                )
                table.insert(markers, markerId)

                local profile = veafSkynet.spotterProfiles[unitName]
                if profile and profile.range > 0 then
                  local circleId = veaf.getUniqueIdentifier()
                  pcall(trigger.action.circleToAll, coa, circleId, point, profile.range, nil, nil, 3, true)
                  table.insert(markers, circleId)
                end
              end
            end
          end
        end
      end
    end
  end
end

--- Build (or rebuild) one coalition's spotter submenu, with the toggle's title showing the state.
---
--- Rebuilt rather than relabelled because a DCS radio command's title is fixed once it is created:
--- the only way to make the entry read *Hide* after it has been used is to replace it.
---
--- **`USAGE_ForAll`, which is the default, and it matters here more than anywhere else.** A game
--- master has no group, so a `USAGE_ForGroup` command never reaches one (#128) — and a game master is
--- precisely the person this menu exists for. Passing a usage here would build a menu that the only
--- intended audience cannot see.
---
--- @param coa number a coalition id
function veafSkynet.buildSpotterViewRadioMenu(coa)
  if not veafRadio then
    veaf.loggers.get(veafSkynet.Id):warn("no radio module: the spotter view cannot be offered on the F10 menu")
    return
  end

  local root = veafSkynet.spotterViewRootPaths[coa]
  if root then
    veafRadio.clearSubmenu(root)
  else
    -- Scoped to the coalition: the other side has its own network and has no business seeing a
    -- switch for this one.
    root = veafRadio.addSubMenu(veaf.t(veafSkynet.RadioMenuName), nil, coa)
    veafSkynet.spotterViewRootPaths[coa] = root
  end

  local shown = veafSkynet.spotterViewCoalitions[coa] and true or false
  local title = veaf.t(shown and "menu.skynet.spotterview.hide" or "menu.skynet.spotterview.show")
  veafRadio.addCommandToSubmenu(title, root, veafSkynet.toggleSpotterViewFromRadio, coa)
  veafRadio.refreshRadioMenu()
end

--- Flip one coalition's view, from the radio command.
---
--- @param coa number a coalition id
function veafSkynet.toggleSpotterViewFromRadio(coa)
  veafSkynet.showSpotterView(coa, not veafSkynet.spotterViewCoalitions[coa])
  veafSkynet.buildSpotterViewRadioMenu(coa)
end

--- Honour `SpotterView`: draw nothing, draw from the start, or offer the switch on the radio.
---
--- Idempotent, like every other arming function here: a reinitialisation must not stack a second
--- menu entry.
function veafSkynet._armSpotterView()
  if veafSkynet.spotterViewArmed then
    return
  end
  if not veafSkynet.SpotterNetwork then
    return
  end
  local mode = veafSkynet.SpotterView
  if mode ~= veafSkynet.SpotterViewModes.On and mode ~= veafSkynet.SpotterViewModes.Radio then
    return
  end
  veafSkynet.spotterViewArmed = true

  for coa, _ in pairs(veafSkynet.getSpotterCoalitions()) do
    if mode == veafSkynet.SpotterViewModes.On then
      veafSkynet.showSpotterView(coa, true)
    else
      veafSkynet.buildSpotterViewRadioMenu(coa)
    end
  end
end

--- Put the hand-over on the clock, on the detection beat's own cadence: a contact is worth acting on
--- as often as it is worth looking for.
function veafSkynet._armSpotterHandover()
  if veafSkynet.spotterHandoverArmed then
    return
  end
  if not veafSkynet.SpotterNetwork then
    return
  end
  veafSkynet.spotterHandoverArmed = true
  veaf.scheduleFunction(
    veafSkynet.spotterHandoverPass,
    {},
    timer.getTime() + veafSkynet.SpotterDetectionPeriod,
    veafSkynet.SpotterDetectionPeriod
  )
end

--- Put propagation and the heartbeat on the clock.
---
--- The hop period is read **here**, from the range and the speed, rather than stored as a setting of
--- its own: widening the radio range must slow the hops, not silently double how fast an alert
--- crosses the map.
function veafSkynet._armSpotterPropagation()
  if veafSkynet.spotterPropagationArmed then
    return
  end
  if not veafSkynet.SpotterNetwork then
    return
  end
  veafSkynet.spotterPropagationArmed = true
  local hop = veafSkynet.getSpotterHopPeriod()
  veaf.scheduleFunction(veafSkynet.spotterPropagationTick, {}, timer.getTime() + hop, hop)
  veaf.scheduleFunction(
    veafSkynet.spotterHeartbeat,
    {},
    timer.getTime() + veafSkynet.SpotterHeartbeatPeriod,
    veafSkynet.SpotterHeartbeatPeriod
  )
end

--- Put the three graph passes on the clock, one per speed class.
function veafSkynet._armSpotterGraph()
  if veafSkynet.spotterGraphArmed then
    return
  end
  if not veafSkynet.SpotterNetwork then
    return
  end
  veafSkynet.spotterGraphArmed = true
  for _, class in pairs(veafSkynet.SpotterSpeedClasses) do
    local period = veafSkynet.SpotterGraphPeriods[class]
    veaf.scheduleFunction(veafSkynet.spotterGraphPass, { class }, timer.getTime() + period, period)
  end
end

--- Put the detection pass on the clock.
---
--- Idempotent, like `_armVanishedSitesSweep` and for the same reason: reinitialising the IADS must
--- not stack a second beat, or every sighting is reported twice.
function veafSkynet._armSpotterDetection()
  if veafSkynet.spotterDetectionArmed then
    return
  end
  if not veafSkynet.SpotterNetwork then
    return
  end
  veafSkynet.spotterDetectionArmed = true
  veaf.loggers.get(veafSkynet.Id):info(
    string.format(
      "spotter network on: radio range %s m, hop %s s",
      veaf.p(veafSkynet.getSpotterRadioRange()),
      veaf.p(veafSkynet.getSpotterHopPeriod())
    )
  )
  veaf.scheduleFunction(
    veafSkynet.spotterDetectionBeat,
    {},
    timer.getTime() + veafSkynet.SpotterDetectionPeriod,
    veafSkynet.SpotterDetectionPeriod
  )
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
