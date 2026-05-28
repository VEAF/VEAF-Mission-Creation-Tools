# veafSkynet — Skynet IADS Integration


**Module ID:** `SKYNET` | **Version:** 3.1.x | **File:** `veafSkynetIadsHelper.lua`

---

## Purpose

Integrates the [Skynet IADS](https://github.com/walder/Skynet-IADS) third-party script with VEAF missions. Without Skynet, DCS SAM sites operate independently — each battery makes its own decisions, radars transmit continuously, and there is no coordination between EWR and SAM. Skynet turns all of that into a real IADS network: radars go silent when not needed, threats are passed between sensors, and point-defence is assigned automatically.

The VEAF module (`veafSkynet`) handles the construction of the Skynet network for you: it scans all groups present in the mission, classifies them as SAM, EWR, or point-defence, and registers them with Skynet at mission start. Dynamic groups spawned during the mission are also handled automatically when `DynamicSpawn` is enabled.

---

## Prerequisites

- Skynet IADS script must be loaded **before** `veafSkynetIadsHelper.lua` in the DCS trigger chain
- Skynet must be available as a global table (`skynet`) at the time VEAF initialises

---

## Enable

```lua
veafSkynet.initialize()
```

Call this from `missionConfig.lua` after your other module initialisations. Skynet networks for both coalitions are built automatically.

### Optional parameters

```lua
veafSkynet.initialize(
  includeRedInRadio,   -- bool: add a "Red IADS" status entry to the F10 radio menu
  debugRed,            -- bool: enable Skynet debug logging for the red network
  includeBlueInRadio,  -- bool: add a "Blue IADS" status entry to the F10 radio menu
  debugBlue            -- bool: enable Skynet debug logging for the blue network
)
```

All four parameters are optional and default to `false`.

---

## Configuration (set before `initialize()`)

These properties control how the networks are built. Set them **before** calling `initialize()`:

### Point defence

```lua
-- Disable point defence altogether (default)
veafSkynet.PointDefenceMode = veafSkynet.PointDefenceModes.None

-- Let Skynet assign point defences according to its own database logic
veafSkynet.PointDefenceMode = veafSkynet.PointDefenceModes.Skynet

-- Assign point-defence groups to DCS AI control instead (not part of Skynet network)
veafSkynet.PointDefenceMode = veafSkynet.PointDefenceModes.Dcs
```

Skynet classifies groups as *single*, *complex*, or *EWR*. With `Skynet` mode: single units defend complex sites; complex sites defend EWR. With `Dcs` mode: groups that would have been assigned as point defence are left to vanilla DCS AI.

### Group integration mode

```lua
-- Only register groups where every unit is known to Skynet (strict)
veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Strict

-- Register groups even if some units are unknown to Skynet (default, more permissive)
veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Lenient
```

Use `Strict` if you want to prevent mixed groups (e.g. a transport truck alongside a radar) from accidentally entering the IADS network.

### Dynamic spawn

```lua
-- Register dynamically spawned groups with Skynet (useful for veafSpawn / veafCombatZone)
veafSkynet.DynamicSpawn = true
```

When enabled, any group spawned by VEAF after mission start is automatically checked and added to the appropriate Skynet network.

### Startup delay

```lua
-- Seconds to wait before building the networks (default: 1)
veafSkynet.DelayForStartup = 5
```

---

## Full configuration example

```lua
-- Skynet IADS integration
veafSkynet.PointDefenceMode     = veafSkynet.PointDefenceModes.Skynet
veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Lenient
veafSkynet.DynamicSpawn         = true
veafSkynet.initialize(
  false, false,   -- red:  no radio menu, no debug
  false, false    -- blue: no radio menu, no debug
)
```

---

## Command Centers

A command center is a special static object (building, vehicle, or FARP) that, when destroyed, causes all Skynet elements of that coalition to fall back to autonomous mode — radars start transmitting continuously, coordination is lost.

```lua
-- Register a command center for red coalition
veafSkynet.addCommandCenterOfCoalition(
  coalition.side.RED,
  "RED-IADS-CMD-CENTER"    -- DCS static object name
)

-- Destroy all registered command centers of a coalition (e.g. on a trigger)
veafSkynet.destroyCommandCentersOfCoalition(coalition.side.RED)
```

When a command center is destroyed, Skynet automatically switches the network to autonomous mode — equivalent to `deactivateNetworkOfCoalition` with `SkynetElementStates.Autonomous`.

---

## Accessing the Generated Networks

The networks are built asynchronously after `initialize()`. To access the Skynet IADS object (e.g. to add custom SAM sites not covered by the auto-scan), schedule a task after startup:

```lua
mist.scheduleFunction(function()
  local redIADS = veafSkynet.getNetwork("red iads")
  if redIADS then
    -- add a group that was not auto-detected
    redIADS.iads:addSAMSite(Group.getByName("Manual SA-10"))
  end
end, {}, timer.getTime() + veafSkynet.DelayForStartup + 5)
```

The default network names are `"red iads"` and `"blue iads"` (stored in `veafSkynet.defaultIADS`).

---

## Deactivating a Network at Runtime

You can switch all elements of a coalition's network to a specific mode — useful for scripted events (command center destroyed, ceasefire, etc.):

```lua
-- Put all red elements in dark mode (radars off, effectively silent)
veafSkynet.deactivateNetworkOfCoalition(
  coalition.side.RED,
  veafSkynet.SkynetElementStates.Dark
)

-- Restore autonomous operation (radars on, no Skynet coordination)
veafSkynet.deactivateNetworkOfCoalition(
  coalition.side.RED,
  veafSkynet.SkynetElementStates.Autonomous
)
```

| Element State | Meaning |
|---------------|---------|
| `Autonomous` | Unit operates independently — radar always on, no Skynet coordination |
| `Live` | Normal Skynet operation — radar managed by network |
| `Dark` | Radar emissions off — unit is silent and cannot be targeted by HARM |

---

## Skynet IADS Monitor

`veafSkynetIadsMonitor.lua` is a companion module that monitors the state of the Skynet networks and can broadcast contact alerts on the radio. It requires no `initialize()` call — it activates on the first `AddMonitoringTask()`.

```lua
-- Monitor the red IADS and broadcast when new threats are detected
veafSkynetMonitor.AddMonitoringTask({
  iadsName   = "red iads",
  coalition  = coalition.side.BLUE,           -- notify blue players
  onDetected = function(contact)
    trigger.action.outText("New radar contact: " .. contact:getName(), 15)
  end,
  onLost = function(contact)
    trigger.action.outText("Contact lost: " .. contact:getName(), 15)
  end,
})
```

---

## See Also

- [Skynet IADS repository](https://github.com/walder/Skynet-IADS) — third-party script documentation
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafSkynet` API
