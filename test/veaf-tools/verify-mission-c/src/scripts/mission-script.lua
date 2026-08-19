-- mission-script.lua
-- Mission-specific Lua code that cannot be generated from mission.yaml.
--
-- This file is loaded AFTER veaf-config.lua (which is generated automatically
-- from mission.yaml by the veaf-tools build command).
--
-- Put here:
--   - Custom shortcuts / aliases  (VeafAlias:new():...)
--   - Custom Lua helper functions
--   - Third-party script setup (CTLD, CSAR, …) that requires Lua code
--
-- Do NOT put here:
--   - Module initialization calls  → use mission.yaml (modules:)
--   - Mission identity             → use mission.yaml (mission:)
--   - QRA definitions              → use mission.yaml (modules.QRA)
--   - Combat/CAP missions          → use mission.yaml (combat_missions: / cap_missions:)
--   - Assets lists                 → use mission.yaml (modules.ASSETS.assets)
--
-- `veafSkynet.DynamicSpawn` is NOT set here: it comes from mission.yaml's
-- `module_settings:` block, which the build writes into veaf-config.lua BEFORE
-- veafSkynet.initialize() runs. Setting it here would be too late -- initialize()
-- reads it to decide whether to hook the birth-event monitor at all.

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFY C — the instruments checks 6 and 7 need, and that no F10 menu provides.
--
-- veafSkynet exposes no deactivation command, and the only Skynet radio menu is
-- the community script's own "IADS Status" printout. So issue #261 ("deactivate a
-- network, then spawn a SAM into it") has no gesture without this menu, and issue
-- #151 ("is the combat-zone SAM in the network?") would be read off a status page
-- rather than off the network's actual element list.
--
-- These three commands are test instruments, not features. They go away with the
-- mission.
-- ─────────────────────────────────────────────────────────────────────────────
local RED_IADS = "red iads"
local BLUE_IADS = "blue iads" -- veafSkynet.defaultIADS[tostring(coalition.side.BLUE)] -- veafSkynet.defaultIADS[tostring(coalition.side.RED)]

local function verifyC_getRedIads()
  if not veafSkynet then
    trigger.action.outText("VERIFY C: veafSkynet is not loaded", 15)
    return nil
  end
  local iads = veafSkynet.getIADS(RED_IADS)
  if not iads then
    trigger.action.outText("VERIFY C: no [" .. RED_IADS .. "] network", 15)
  end
  return iads
end

--- Count how many times the RED network gets REACTIVATED — this is what #261 is about.
---
--- Reading an element's isActive() does not work: it reports whether that radar is currently
--- emitting, and a Skynet SAM stays dark on purpose until it has a contact. David measured the
--- consequence -- "que ce soit activé ou désactivé, même compte". Worse, SkynetIADS:deactivate()
--- never touches that state at all: it removes the scan tasks and the event handlers
--- (SkynetIADSAbstractRadarElement:cleanUp), leaving aiState exactly as it was.
---
--- What DOES happen is the thing the issue names: veafSkynet.addGroupToNetwork ends with
--- veafSkynet.delayedActivate(networkName) (veafSkynetIadsHelper.lua:794), so integrating any group
--- schedules an activation of the whole network. Wrapping _activateIADS counts those directly.
local verifyC_reactivations = 0
local verifyC_adds = 0        -- addGroupToNetwork calls that returned true
local verifyC_delayedCalls = 0 -- delayedActivate calls
--- What the MENU knows, because the menu is what triggers it. Skynet exposes no network state
--- at all, so the two readings David compared (before/after deactivation) were identical by
--- construction: nothing in them could ever have differed.
local verifyC_status = "running normally (never deactivated from this menu)"
local verifyC_verdict = "#261: deactivate the network first, then spawn a SAM"

if veafSkynet and veafSkynet.addGroupToNetwork then
  local originalAdd = veafSkynet.addGroupToNetwork
  veafSkynet.addGroupToNetwork = function(networkName, ...)
    local added = originalAdd(networkName, ...)
    if networkName == RED_IADS and added then
      verifyC_adds = verifyC_adds + 1
      trigger.action.outText(string.format("VERIFY C: group added to RED network (%d)", verifyC_adds), 15)
    end
    return added
  end
end

if veafSkynet and veafSkynet.delayedActivate then
  local originalDelayed = veafSkynet.delayedActivate
  veafSkynet.delayedActivate = function(networkName, ...)
    if networkName == RED_IADS then
      verifyC_delayedCalls = verifyC_delayedCalls + 1
      trigger.action.outText(string.format("VERIFY C: delayedActivate called on RED (%d)", verifyC_delayedCalls), 15)
    end
    return originalDelayed(networkName, ...)
  end
end

if veafSkynet and veafSkynet._activateIADS then
  local originalActivate = veafSkynet._activateIADS
  veafSkynet._activateIADS = function(networkName)
    if networkName == RED_IADS then
      verifyC_reactivations = verifyC_reactivations + 1
      if verifyC_status:find("DEACTIVATED") or verifyC_status:find("REACTIVATED") then
        verifyC_status = string.format("REACTIVATED %dx since it was deactivated", verifyC_reactivations)
        verifyC_verdict = "#261 CONFIRMED -- a spawn woke a network that was switched off"
      end
      trigger.action.outText(
        string.format("VERIFY C: RED IADS REACTIVATED (%d since the last deactivation)", verifyC_reactivations),
        20
      )
    end
    return originalActivate(networkName)
  end
end

--- Print what the RED network holds, plus the reactivation count.
local function verifyC_listRedIads()
  local iads = verifyC_getRedIads()
  if not iads then
    return
  end
  -- Index the lists, never pairs() them: getSAMSites/getEarlyWarningRadars return a
  -- SkynetIADSTableDelegator, a proxy table carrying its own fields alongside the elements.
  local lines = {}
  local total = 0

  local function report(prefix, list)
    for i = 1, #list do
      local element = list[i]
      total = total + 1
      -- The radar state is shown for information only. It is NOT the answer to #261.
      local radar = "dark"
      if element.isActive and element:isActive() then
        radar = "LIVE"
      end
      table.insert(lines, string.format("  %s [radar %s] %s", prefix, radar, veafSkynet.getStringSkynetElement(element)))
    end
  end

  report("EWR", iads:getEarlyWarningRadars())
  report("SAM", iads:getSAMSites())

  -- Where did a spawn actually land? veafSpawn defaults to country "usa", so a marker without
  -- `country russia` builds a BLUE battery -- which joins the BLUE network and leaves RED untouched.
  -- Listing only RED makes that indistinguishable from "nothing was integrated at all".
  local blue = veafSkynet.getIADS(BLUE_IADS)
  local blueCount = 0
  if blue then
    local function count(list)
      for _ = 1, #list do
        blueCount = blueCount + 1
      end
    end
    count(blue:getEarlyWarningRadars())
    count(blue:getSAMSites())
  end
  table.insert(lines, string.format("  (BLUE network holds %d element(s) -- a spawn with no `country russia` lands there)", blueCount))

  if total == 0 then
    table.insert(lines, "  (network is empty)")
  end
  table.insert(lines, 1, string.format("  chain: %d group(s) added | %d delayedActivate | %d actual reactivation(s)", verifyC_adds, verifyC_delayedCalls, verifyC_reactivations))
  table.insert(lines, 1, string.format("  %d element(s) in the network:", total))
  table.insert(lines, 1, "  -> " .. verifyC_verdict)
  table.insert(lines, 1, "  status: " .. verifyC_status)
  table.insert(lines, 1, "RED IADS")
  trigger.action.outText(table.concat(lines, "\n"), 30)
end

local function verifyC_deactivateRedIads()
  local iads = verifyC_getRedIads()
  if iads then
    iads:deactivate()
    verifyC_reactivations = 0
    verifyC_status = "DEACTIVATED from this menu, nothing has reactivated it since"
    verifyC_verdict = "#261: now spawn a SAM -- marker text  -samsr, country russia"
    trigger.action.outText("VERIFY C: RED IADS deactivated -- now spawn a SAM near it", 15)
  end
end

local function verifyC_activateRedIads()
  local iads = verifyC_getRedIads()
  if iads then
    iads:activate()
    verifyC_status = "activated by hand from this menu"
    verifyC_verdict = "#261: deactivate the network first, then spawn a SAM"
    trigger.action.outText("VERIFY C: RED IADS activated", 15)
  end
end

if veafRadio then
  local menu = veafRadio.addSubMenu("VERIFY C")
  veafRadio.addCommandToSubmenu("List RED IADS elements", menu, verifyC_listRedIads, nil, veafRadio.USAGE_ForAll)
  veafRadio.addCommandToSubmenu("Deactivate RED IADS", menu, verifyC_deactivateRedIads, nil, veafRadio.USAGE_ForAll)
  veafRadio.addCommandToSubmenu("Activate RED IADS", menu, verifyC_activateRedIads, nil, veafRadio.USAGE_ForAll)
  veafRadio.refreshRadioMenu()
end
