# veafSkynetIadsHelper — Skynet IADS Integration

**Module ID:** `SKYNET` | **File:** `veafSkynetIadsHelper.lua` | **Lua table:** `veafSkynet`

---

## Purpose

[Skynet-IADS](https://github.com/walder/Skynet-IADS) is a third-party script that drives ground-based air defence radars to optimise their survivability and lethality by staying dark as much as possible. It simulates an IADS (Integrated Air Defence System) in which Early Warning Radars (EWR) scan the sky and share detections with SAM sites, allowing those sites to activate only when they can engage a contact.

`veafSkynetIadsHelper` automates the construction of these networks from the groups present in the mission, and provides tools to monitor, control, and tie them to mission objectives.

---

## Requirements

- The Skynet IADS script must be downloaded separately and loaded **before** `veafSkynetIadsHelper`
- Configure via `mission.yaml` (recommended) or in `mission-script.lua` for advanced options not available in YAML

---

## Configuration (`mission.yaml`)

```yaml
modules:
  SKYNET:
    enabled: true
    include_red_in_radio: false   # show RED network status in F10 menu
    debug_red: false              # verbose Skynet logging for RED network
    include_blue_in_radio: false  # show BLUE network status in F10 menu
    debug_blue: false             # verbose Skynet logging for BLUE network
    dynamic_spawn: false          # also integrate groups that appear during the mission
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `false` | Enable Skynet integration |
| `include_red_in_radio` | boolean | `false` | Add RED IADS status to F10 radio menu |
| `debug_red` | boolean | `false` | Enable verbose Skynet debug for RED coalition |
| `include_blue_in_radio` | boolean | `false` | Add BLUE IADS status to F10 radio menu |
| `debug_blue` | boolean | `false` | Enable verbose Skynet debug for BLUE coalition |
| `dynamic_spawn` | boolean | `false` | Also integrate groups that appear **during** the mission — see [Groups appearing during the mission](#dynamic-spawn) |

---

## Activation (via `mission-script.lua`)

```lua
if veafSkynet then
    veafSkynet.PointDefenceMode = veafSkynet.PointDefenceModes.Skynet
    veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Strict
    veafSkynet.DynamicSpawn = false
    veafSkynet.DelayForStartup = 5
    veafSkynet.initialize(
        false, -- includeRedInRadio
        false, -- debugRed
        false, -- includeBlueInRadio
        false  -- debugBlue
    )
end
```

---

## How it works

The module scans all groups in the mission at startup and adds eligible ones to the Skynet IADS networks. Initialisation is delayed by `DelayForStartup` seconds to let other modules finish first. Late-activation groups are included; dynamically spawned groups are not (unless `DynamicSpawn = true`).

The module always creates two Skynet networks: one for **blue** coalition, one for **red**.

---

## Global properties (set before `initialize`)

### Point Defence mode — `veafSkynet.PointDefenceMode`

Identifies SAM sites capable of intercepting anti-radiation missiles and assigns them as point defences for nearby network elements.

| Value | Description |
|-------|-------------|
| `veafSkynet.PointDefenceModes.None` | No point defences (**default**) |
| `veafSkynet.PointDefenceModes.Skynet` | Point defences managed by Skynet (recommended if enabled) |
| `veafSkynet.PointDefenceModes.Dcs` | Excludes point defences from the IADS network — handed to DCS AI (always on, more effective but more vulnerable) |

### Group integration mode — `veafSkynet.GroupIntegrationMode`

Controls which DCS groups are added to the Skynet networks.

| Value | Description |
|-------|-------------|
| `veafSkynet.GroupIntegrationModes.Strict` | Only groups composed **entirely** of Skynet-known units are integrated |
| `veafSkynet.GroupIntegrationModes.Lenient` | Groups containing **at least one** Skynet-known unit are integrated (**default**) |

In `Lenient` mode, a convoy of tanks and trucks escorted by a SA-19 will be integrated. In `Strict` mode, it will not.

### Groups appearing during the mission — `dynamic_spawn` {#dynamic-spawn}

Set from `mission.yaml` (`dynamic_spawn`), or before `initialize` with `veafSkynet.DynamicSpawn`.

| Value | Description |
|-------|-------------|
| `false` | Only groups present at startup are integrated (**default**) |
| `true` | Groups appearing during the mission also join the existing networks |

**What it costs.** Once on, the module watches **every unit birth** in the mission to spot eligible groups. That is why it is off by default: turn it on when the mission spawns SAMs while it runs (combat zones, dynamic campaign), not as a matter of course.

**What it fixes.** Without it, a SAM appearing during the mission — a combat-zone one included — joins no network at all, and nothing says so.

**Who decides, group by group.** A spawn command's `skynet` option stays in charge: `skynet false` keeps the group **out** of every network (which is what the convoy shortcuts carry), and `skynet <network name>` sends it to that network rather than its coalition's. A group no VEAF command declared — placed in the Mission Editor, created by a third-party script — joins its coalition's network, which is exactly what this setting is for.

> The two integration paths are exclusive: when the target network integrates spawns, it does the work; otherwise `veafSpawn` does it as the group appears. A group is never integrated twice.

**Scoped per network.** The setting belongs to each network. Switching integration off on the red side — or deactivating the red network — leaves blue working.

```lua
-- during the mission, network by network
veafSkynet.setDynamicSpawn("red iads", false)
```

### Startup delay — `veafSkynet.DelayForStartup`

Seconds to wait before initialising networks (default: `1`). Increase if other modules initialise groups with a delay.

---

## Command Centers

In Skynet, a **Command Center** is a unit or static object that a network depends on. If all Command Centers of a network are destroyed, that network switches to autonomous mode (all elements remain on permanently, but still benefit from Skynet intelligence, in particular HARM evasion).

This mechanism provides concrete mission objectives: destroy the command center to disrupt the air defence network.

```lua
-- Add a Command Center to a network (can be a group, unit or static)
veafSkynet.addCommandCenterOfCoalition(coalition.side.RED, "CommandCenterRed")

-- Destroy (explode) all Command Centers of a network
veafSkynet.destroyCommandCentersOfCoalition(coalition.side.RED)
```

---

## Deactivating a network {#deactivation}

Deactivates a Skynet network and sets all its elements to a defined state before handing them back to DCS AI.

```lua
veafSkynet.deactivateNetworkOfCoalition(coalition.side.RED)
-- or with a specific state:
veafSkynet.deactivateNetworkOfCoalition(coalition.side.RED, veafSkynet.SkynetElementStates.Dark)
```

| State | Description |
|-------|-------------|
| `veafSkynet.SkynetElementStates.Autonomous` | Autonomous mode per each element's individual configuration |
| `veafSkynet.SkynetElementStates.Live` | All elements switched on (**default**) |
| `veafSkynet.SkynetElementStates.Dark` | All elements switched off |

**A deactivated network stays deactivated.** Spawning a SAM into it no longer wakes it up: the group is still attached — that is what `skynet true` asks for — but the network does not come back on its own. Before, one spawned SAM was enough to restart a network you had just switched off.

Bringing it back up is a deliberate call. Everything attached meanwhile comes up with it:

```lua
veafSkynet.activateNetworkOfCoalition(coalition.side.RED)
```

Deactivating one network **leaves the other alone**: the blue network keeps its state and its integration of dynamic spawns.

---

## Accessing generated networks

After initialisation (which is deferred), access the Skynet network objects via a scheduled task:

```lua
local assignRedIadsTaskId = nil
local myRedIads = nil

local function AssignRedIadsTask()
    if not veafSkynet then
        veaf.removeFunction(assignRedIadsTaskId)
        return
    end
    if veafSkynet.initialized then
        veaf.removeFunction(assignRedIadsTaskId)
        local veafSkynetNetwork = veafSkynet.getNetwork(veafSkynet.defaultIADS[tostring(coalition.side.RED)])
        myRedIads = veafSkynetNetwork.iads
    end
end

assignRedIadsTaskId = veaf.scheduleFunction(AssignRedIadsTask, {}, timer.getTime() + veafSkynet.DelayForStartup + 1, 10)
```

---

## Example — Mission-objective-driven autonomous switch

This example creates a Command Center from a template group, then exposes functions to enable/disable the network as the mission progresses.

```lua
local function SkynetNetworkEnable(iCoalition)
    local veafSkynetNetwork = veafSkynet.getNetwork(veafSkynet.defaultIADS[tostring(iCoalition)])
    local iads = veafSkynetNetwork.iads
    if #iads:getCommandCenters() > 0 and iads:isCommandCenterUsable() then
        return -- already active
    end
    local sTemplateName = "SkynetCommandCenterRed"
    local ccData = mist.cloneInZone(sTemplateName, "SkynetCommandCenterZone")
    veafSkynet.addCommandCenterOfCoalition(iads:getCoalition(), ccData.name)
end

local function SkynetNetworkDisable(iCoalition)
    veafSkynet.destroyCommandCentersOfCoalition(iCoalition)
end
```

---

## See also

- [Skynet IADS documentation](https://github.com/walder/Skynet-IADS) — third-party script (not included in VEAF)
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafSkynet` API
