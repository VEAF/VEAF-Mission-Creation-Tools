# veafQraManager — Quick Reaction Alert


**Module ID:** `QRA` | **Version:** 1.2.x | **File:** `veafQraManager.lua`

---

## Purpose

Defines protected airspace zones defended by AI interceptors. When a hostile aircraft enters the zone, a QRA flight is scrambled. Once the QRA is destroyed, the zone is undefended until it resets (when all intruders have left). Supports multiple groups, rearming, airbase dependency, radio status messages, and a logistics chain (limited aircraft count with optional resupply).

---

## Dependencies

- `veafRadio` — status messages (optional)
- `veafSpawn` — AI group spawning

---

## Enable

No global `initialize()` call needed. Each QRA zone is individually created and activated with `:start()`:

```lua
local myQra = VeafQRA:new()
  :setName("QRA-North")
  :setTriggerZone("ZONE-QRA-NORTH")
  :setCoalition(coalition.side.RED)
  :addGroup("MiG-29 QRA")
  :start()
```

---

## Configuration (`mission.yaml`)

QRA definitions live in the **top-level `qra:` section** (not under `lua_modules:`). The `QRA` module must be enabled in `lua_modules:`.

```yaml
lua_modules:
  QRA:
    enable: true          # default: true
    logLevel: info        # optional log level override

qra:
  silence_all: false      # true = suppress all QRA radio messages globally
  definitions:
    - name: "QRA-North"                 # REQUIRED — identifier and radio prefix
      coalition: RED                    # REQUIRED — RED | BLUE
      enemy_coalitions: [BLUE]          # coalitions that trigger a scramble
      trigger_zone: "ZONE-QRA-NORTH"   # DCS trigger zone defining the airspace
      zone_radius: 30000               # radius in metres (alternative to trigger_zone)
      simple_groups:                   # DCS group names to scramble (unconditional)
        - "MiG-29 QRA Flight"
      groups_by_enemy_count:           # scale response to intruder count
        - enemy_count: 1               # scramble when 1 intruder detected
          groups: ["Pair-1", "Pair-2"] # group pool
          random_pick: 1               # how many groups to pick from the pool
        - enemy_count: 3
          groups: ["Flight-1", "Flight-2"]
          random_pick: 2
      delay_before_rearming: 30        # seconds before zone resets after intruders leave
      delay_before_activating: 30      # seconds after :start() before QRA goes online
      react_on_helicopters: false      # true = also trigger on enemy helicopters
      airport_link: "Batumi"           # QRA goes offline if this airbase is destroyed
```

### `qra:` top-level fields

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `silence_all` | boolean | `false` | No | Suppress all QRA radio messages globally |
| `definitions` | object[] | `[]` | No | List of QRA zone definitions |

### `definitions[]` fields

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `name` | string | — | Yes | Internal identifier and radio prefix |
| `coalition` | string | — | Yes | Defending coalition: `RED` or `BLUE` |
| `enemy_coalitions` | string[] | *(opposite)* | No | Coalitions that trigger a scramble |
| `trigger_zone` | string | — | No | DCS trigger zone name |
| `zone_radius` | integer | — | No | Zone radius in metres (when no trigger zone) |
| `simple_groups` | string[] | `[]` | No | DCS group names to always scramble |
| `groups_by_enemy_count` | object[] | `[]` | No | Scaled scramble rules |
| `groups_by_enemy_count[].enemy_count` | integer | — | Yes | Number of intruders that activates this rule |
| `groups_by_enemy_count[].groups` | string[] | — | Yes | Group name pool |
| `groups_by_enemy_count[].random_pick` | integer | `1` | No | How many groups to pick from the pool |
| `delay_before_rearming` | integer | `0` | No | Seconds before zone resets after intruders leave |
| `delay_before_activating` | integer | `0` | No | Seconds after start before QRA goes online |
| `react_on_helicopters` | boolean | `false` | No | Also trigger on enemy helicopters |
| `airport_link` | string | — | No | Linked DCS airbase name — QRA offline when destroyed |

### Minimal example

```yaml
lua_modules:
  QRA:
    enable: true

qra:
  definitions:
    - name: "QRA-Sud"
      coalition: RED
      trigger_zone: "ZONE-QRA-SUD"
      simple_groups:
        - "Su-27 Intercept"
```

---

## VeafQRA Builder Methods

All setters return `self` and can be chained. Call `:start()` at the end to activate.

### Identification

| Method | Description |
|--------|-------------|
| `:setName(name)` | Internal identifier — also used as message prefix if no description is set |
| `:setDescription(text)` | Human-readable label used in radio messages (defaults to name) |

### Zone Definition

Use one of the following to define the protected airspace:

| Method | Description |
|--------|-------------|
| `:setTriggerZone(zoneName)` | DCS trigger zone name (preferred) |
| `:setZoneCenter(vec3)` | Manual center point (DCS vec3) — use with `:setZoneRadius()` |
| `:setZoneCenterFromCoordinates(coordStr)` | Center from a `"lat,lon"` string |
| `:setZoneRadius(meters)` | Radius in meters when not using a trigger zone |

### Defenders

| Method | Description |
|--------|-------------|
| `:addGroup(name)` | Add a DCS group name to scramble (call multiple times for multiple groups) |
| `:addRandomGroup(groups, number, bias)` | Randomly pick `number` groups from a list |
| `:setGroupsToDeployByEnemyQuantity(n, groups)` | Scale response: deploy `groups` when `n` enemies are in zone |
| `:setRandomGroupsToDeployByEnemyQuantity(n, groups, number, bias)` | Randomized scaling |

### Coalition

| Method | Description |
|--------|-------------|
| `:setCoalition(side)` | Coalition that owns this QRA (e.g. `coalition.side.RED`) |
| `:addEnnemyCoalition(side)` | Add an enemy coalition (defaults to the opposite of the defending coalition) |

### Behavior

| Method | Description |
|--------|-------------|
| `:setSilent(bool)` | Suppress all radio status messages for this QRA |
| `:setDrawZone(bool)` | Draw the protected zone on the map |
| `:setReactOnHelicopters()` | Also trigger on enemy helicopters (planes only by default) |
| `:setDelayBeforeRearming(seconds)` | Delay before the QRA resets after all intruders leave (`-1` = no delay) |
| `:setNoNeedToLeaveZoneBeforeRearming()` | Allow rearming even if enemies are still in the zone |
| `:setResetWhenLeavingZone()` | Reset immediately the moment all enemies leave (no wait) |
| `:setDelayBeforeActivating(seconds)` | Delay before the QRA goes online after `:start()` |
| `:setMinimumAltitudeInFeet(feet)` | Minimum enemy altitude to trigger a scramble |
| `:setMaximumAltitudeInFeet(feet)` | Maximum enemy altitude to trigger a scramble |
| `:setRespawnDefaultOffset(latDelta, lonDelta)` | Spawn offset from zone center (meters, lat/lon) |
| `:setRespawnRadius(meters)` | Scatter radius around spawn point (minimum 250 m) |

### Airbase Link

| Method | Description |
|--------|-------------|
| `:setAirportLink(name)` | Link to an airbase — QRA goes offline if the airbase is destroyed |
| `:setAirportMinLifePercent(pct)` | Minimum airbase health for QRA to remain active (0–1, default `0.9`) |

### Messages and Callbacks

All message strings accept `%s` as a token for the QRA name/description. Callbacks receive the QRA instance as their first argument.

| Method | Triggered when |
|--------|---------------|
| `:setMessageStart(text)` / `:setOnStart(fn)` | QRA goes online |
| `:setMessageDeploy(text)` / `:setOnDeploy(fn)` | QRA scrambles |
| `:setMessageDestroyed(text)` / `:setOnDestroyed(fn)` | QRA shot down |
| `:setMessageReady(text)` / `:setOnReady(fn)` | QRA ready after rearming |
| `:setMessageOut(text)` / `:setOnOut(fn)` | No more aircraft available |
| `:setMessageResupplied(text)` / `:setOnResupplied(fn)` | Logistics resupply complete |
| `:setMessageAirbaseDown(text)` / `:setOnAirbaseDown(fn)` | Linked airbase destroyed |
| `:setMessageAirbaseUp(text)` / `:setOnAirbaseUp(fn)` | Linked airbase restored |
| `:setMessageStop(text)` / `:setOnStop(fn)` | QRA goes offline |

### Warehousing / Logistics

By default the QRA has unlimited aircraft. Use these to simulate a finite stock with optional resupply:

| Method | Description |
|--------|-------------|
| `:setQRAcount(n)` | Total aircraft groups available (`-1` = infinite) |
| `:setQRAmaxCount(n)` | Max groups active at once (`-1` = infinite) |
| `:setQRAresupplyDelay(seconds)` | Seconds before a resupply cycle starts |
| `:setQRAmaxResupplyCount(n)` | Maximum number of resupply cycles (`-1` = infinite) |
| `:setQRAminCountforResupply(n)` | Remaining count that triggers a resupply |
| `:setResupplyAmount(n)` | Groups added per resupply cycle (default `1`) |

### Lifecycle

| Method | Description |
|--------|-------------|
| `:start()` | Activate the QRA — broadcasts `messageStart` and starts the watchdog |
| `:stop(silent)` | Deactivate the QRA — broadcasts `messageStop` unless `silent` is `true` |

---

## How it works

A QRA zone monitors a volume of airspace defined by a DCS trigger zone. The moment a hostile aircraft enters that space, the QRA scrambles — provided it is ready. When the QRA is shot down, the zone enters a rearming state; it will become active again once the enemies leave and the rearm timer expires.

### State machine

```
STOP ──start()──► READY ──(intruder enters)──► ACTIVE ──(QRA destroyed)──► DEAD
  ▲                 ▲                                                          │
  │                 └──────────(all intruders left + rearm delay)─────────────┘
  │                                                     │
  └──────────────────────────stop()────────────────────►┘
```

Full states:

| State | Meaning |
|-------|---------|
| `STOP` | Inactive — `stop()` was called or the QRA was never started |
| `READY` | Armed and watching for intruders |
| `READY_WAITINGFORMORE` | QRA scrambled; additional intruders triggered deployment of more groups |
| `ACTIVE` | QRA is airborne and intercepting |
| `DEAD` | QRA was destroyed; waiting for conditions to rearm |
| `WILLREARM` | Rearming timer is running |
| `OUT` | No more aircraft available (stock exhausted) |
| `NOAIRBASE` | The linked airbase was destroyed — QRA stands down |

### Setting up in the DCS Mission Editor

1. **Create a trigger zone** — draw the airspace you want to protect. Name it something memorable, e.g. `ZONE-QRA-NORTH`.
2. **Place the QRA group** — create the aircraft group that will scramble. Set it to **Late Activation** so it does not spawn at mission start (VEAF handles activation). Give the group a distinctive name, e.g. `MiG-29 QRA North`.
3. **Wire it up in `mission-script.lua`** (or via `mission.yaml` → `qra:` for the recommended YAML approach):

```lua
VeafQRA:new()
  :setName("QRA-North")
  :setTriggerZone("ZONE-QRA-NORTH")
  :setCoalition(coalition.side.RED)
  :addGroup("MiG-29 QRA North")
  :start()
```

That is all — no trigger conditions, no scheduled functions. VEAF handles detection, scramble, and rearm automatically.

### Logistics chain

By default a QRA has unlimited aircraft. The logistics system lets you model a finite airfield stock with optional resupply — useful for long persistent missions:

| Parameter | Role |
|-----------|------|
| `setQRAcount(n)` | Total aircraft groups available (acts as the current stock) |
| `setQRAmaxCount(n)` | Hard cap on simultaneous active groups |
| `setQRAresupplyDelay(s)` | Seconds to wait before a resupply starts |
| `setQRAminCountforResupply(n)` | Stock level that triggers a resupply |
| `setQRAmaxResupplyCount(n)` | Maximum number of resupply cycles (`-1` = unlimited) |
| `setResupplyAmount(n)` | Groups added per resupply cycle (default `1`) |

Think of it as a warehouse: `QRAcount` is what is on the shelf, `resupplyDelay` is the truck delivery time, and `minCountforResupply` is the reorder point.

---

## Global Configuration

| Constant | Default | Description |
|----------|---------|-------------|
| `veafQraManager.WATCHDOG_DELAY` | `5` | Check interval in seconds |
| `veafQraManager.MINIMUM_LIFE_FOR_QRA_IN_PERCENT` | `10` | Minimum QRA unit life before considered destroyed |
| `veafQraManager.DEFAULT_airbaseMinLifePercent` | `0.9` | Default airbase health threshold |
| `veafQraManager.AllSilence` | `false` | Globally suppress all QRA messages |

---

## Example: Multiple QRA Zones

```lua
-- Northern zone defended by MiG-29s, tied to Beslan airbase
VeafQRA:new()
  :setName("QRA-NORTH")
  :setTriggerZone("ZONE-NORTH-DEFENSE")
  :setCoalition(coalition.side.RED)
  :addGroup("MiG-29S QRA North-1")
  :addGroup("MiG-29S QRA North-2")
  :setAirportLink("Beslan")
  :setDelayBeforeRearming(600)
  :start()

-- Southern zone, always active, silent
VeafQRA:new()
  :setName("QRA-SOUTH")
  :setTriggerZone("ZONE-SOUTH-DEFENSE")
  :setCoalition(coalition.side.RED)
  :addGroup("Su-27 QRA South")
  :setSilent(true)
  :start()
```

### Example: Finite stock with resupply

```lua
-- 4 groups total, max 2 active at once, resupply 1 group every 30 min
VeafQRA:new()
  :setName("QRA-LIMITED")
  :setTriggerZone("ZONE-LIMITED")
  :setCoalition(coalition.side.RED)
  :addGroup("F-15C QRA 1")
  :addGroup("F-15C QRA 2")
  :setQRAcount(4)
  :setQRAmaxCount(2)
  :setQRAresupplyDelay(1800)
  :setResupplyAmount(1)
  :start()
```

---

## See Also

- [veafAirWaves](veafAirWaves.md) — wave-based AI attack system (vs QRA which is defensive)
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafQraManager` API
