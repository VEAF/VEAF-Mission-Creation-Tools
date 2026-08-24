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
local verifyC_deactivatedFromMenu = false
local verifyC_status = "running normally (never deactivated from this menu)"
local verifyC_verdict = "#261: deactivate the network first, then spawn a SAM"

if veafSkynet and veafSkynet.addGroupToNetwork then
  local originalAdd = veafSkynet.addGroupToNetwork
  -- The second argument is a **DCS group object**, not a name: `addGroupToNetwork(networkName,
  -- dcsGroup, ...)`. Printing it directly gave "table: 0000016AB83D4588" in game on 2026-08-22.
  veafSkynet.addGroupToNetwork = function(networkName, dcsGroup, ...)
    local added = originalAdd(networkName, dcsGroup, ...)
    if networkName == RED_IADS and added then
      verifyC_adds = verifyC_adds + 1
      -- Name the group. A bare counter cannot say *what* joined, and two groups were integrated
      -- before the zone was even activated -- expected, since `dynamic_spawn` makes the birth events
      -- of the mission's own starting groups reach the monitor, but indistinguishable from a defect
      -- without the name.
      local name = "?"
      if dcsGroup and dcsGroup.getName then
        local ok, value = pcall(function()
          return dcsGroup:getName()
        end)
        if ok then
          name = tostring(value)
        end
      end
      trigger.action.outText(
        string.format("VERIFY C: group added to RED network (%d): %s", verifyC_adds, name),
        15
      )
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
      -- Say which of the two situations this is. The old wording claimed "since the last
      -- deactivation" unconditionally, so an activation on a network that had never been switched
      -- off read as the very defect #261 is about. It misled a real reading on 2026-08-22.
      local context = "network was NOT deactivated -- this is normal startup/integration traffic"
      if verifyC_deactivatedFromMenu then
        context = string.format("%d since it was deactivated -- THIS IS #261", verifyC_reactivations)
      end
      trigger.action.outText(string.format("VERIFY C: RED IADS activate() called (%s)", context), 20)
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

--- Deactivate through **veafSkynet.deactivateNetwork**, never `iads:deactivate()`.
---
--- This instrument called the raw Skynet method until 2026-08-22, and that silently invalidated the
--- whole of check 7: the #261 fix keys off `network.deactivated`, a flag set by
--- `veafSkynet.deactivateNetwork` (veafSkynetIadsHelper.lua:1344) and unknown to Skynet itself. So the
--- check switched the network off by a route the fix cannot see, then correctly reported that a spawn
--- woke it up — measuring the absence of a guard it had bypassed. It printed
--- "#261 CONFIRMED" on a working product.
---
--- The real deactivation paths all go through the VEAF API (`deactivateNetwork`,
--- `deactivateNetworkOfCoalition`); `iads` is an internal object no mission reaches.
local function verifyC_deactivateRedIads()
  local network = veafSkynet and veafSkynet.getNetwork(RED_IADS)
  if not network then
    trigger.action.outText("VERIFY C: no [" .. RED_IADS .. "] network", 15)
    return
  end
  do
    veafSkynet.deactivateNetwork(network)
    verifyC_deactivatedFromMenu = true
    verifyC_reactivations = 0
    verifyC_status = "DEACTIVATED from this menu, nothing has reactivated it since"
    verifyC_verdict = "#261: now spawn a SAM -- marker text  -samsr, country russia"
    trigger.action.outText("VERIFY C: RED IADS deactivated -- now spawn a SAM near it", 15)
  end
end

local function verifyC_activateRedIads()
  local network = veafSkynet and veafSkynet.getNetwork(RED_IADS)
  if not network then
    trigger.action.outText("VERIFY C: no [" .. RED_IADS .. "] network", 15)
    return
  end
  do
    -- Symmetrically: only `veafSkynet.activateNetwork` clears the `deactivated` flag.
    veafSkynet.activateNetwork(network)
    verifyC_deactivatedFromMenu = false
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
