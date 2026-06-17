# veafAirWaves — Wave-Based Air Attacks


**Module ID:** `AIRWAVES` | **Version:** 1.8.x | **File:** `veafAirWaves.lua`

---

## Purpose

Defines zones that spawn recurring waves of AI aircraft. When the required number of human players enters the zone, the first wave is launched. As each wave is destroyed, the next wave spawns (with optional delays). Supports player-count scaling, reset on player death, and custom radio messages.

---

## Dependencies

- `veafSpawn` — AI aircraft spawning
- `veafRadio` — status messages (optional)

---

## Enable

No global `initialize()`. Each zone is individually created, then started with `:start()`:

```lua
local defenseZone = AirWaveZone:new()
  :setName("AW-East")
  :setTriggerZone("ZONE-AIRWAVES-EAST")
  :setDescription("Eastern intercept zone")
  :addPlayerCoalition(coalition.side.BLUE)
  :addWave({ "MiG-23 Wave 1a", "MiG-23 Wave 1b" })
  :addWave({ "MiG-29 Wave 2" })
  :start()
```

---

## Configuration (`mission.yaml`)

```yaml
modules:
  AIRWAVES:
    enabled: true          # default: true
    logLevel: info        # optional log level override
    airwave_zones:
      - name: "BVR Zone"                  # REQUIRED — internal identifier
        description: "Eastern BVR arena"  # shown in messages (optional)
        start: true                       # true = start automatically at mission start
        player_coalitions: [BLUE]         # BLUE | RED — which coalition's players trigger waves
        zone_center_coordinates: "N41°00'00\" E044°00'00\""  # use this OR trigger_zone_name
        trigger_zone_name: "ZONE-BVR-EAST"  # DCS trigger zone name (alternative to coordinates)
        zone_radius: 50000               # radius in metres (when using coordinates)
        draw_zone: true                  # draw zone boundary on the map
        respawn_default_offset: [0, 0]   # [lat_delta_m, lon_delta_m] spawn offset from zone centre
        respawn_radius: 1000             # scatter radius around spawn offset (metres)
        delay_before_activation: 60      # seconds to wait after players enter before first wave
        delay_between_waves: 120         # fixed delay between waves (ignored if min/max set)
        min_seconds_between_waves: 60    # minimum inter-wave delay (random range)
        max_seconds_between_waves: 180   # maximum inter-wave delay (random range)
        max_altitude_ft: 30000          # AI units above this altitude are removed
        min_altitude_ft: 1000           # AI units below this altitude are removed
        max_seconds_outside_ia: 300     # seconds before an AI group is considered lost outside zone
        minimum_life_percent: 0.1       # AI unit removed when below this life fraction (0–1)
        reset_when_dying: false         # reset all waves when a player dies
        message_start: "Zone active!"   # custom zone-start message (optional)
        message_wait_for_humans: "Waiting for players..."
        message_wave_deployed: "Wave inbound!"
        message_end_zone: "Zone cleared!"
        message_end_all: "All zones cleared!"
        waves:
          - groups: "su27-flight"       # DCS group name or space-separated list
            delay: 0                    # seconds after this wave is cleared before the next; -1 = concurrent
            number: "1-2"              # how many groups to pick: integer or "min-max" range
            bias: 0                     # shift random selection towards harder groups
          - groups: "su30sm-flight"
            delay: 120
```

### `airwave_zones[]` common fields

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `name` | string | — | Yes | Internal identifier |
| `description` | string | — | No | Label shown in messages and logs |
| `start` | boolean | `false` | No | Auto-start at mission launch |
| `player_coalitions` | string[] | — | No | Coalitions whose players trigger waves (`BLUE`, `RED`) |

### Zone location (use one)

| Field | Type | Description |
|-------|------|-------------|
| `trigger_zone_name` | string | DCS trigger zone name (preferred) |
| `zone_center_coordinates` | string | Coordinate string, e.g. `"N41°00'00\" E044°00'00\""` |
| `zone_radius` | number | Zone radius in metres (required with coordinates) |

### Timing and limits

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `delay_before_activation` | integer | `0` | Seconds before first wave after players enter |
| `delay_between_waves` | integer | `0` | Fixed inter-wave delay (overridden by min/max) |
| `min_seconds_between_waves` | integer | — | Random minimum inter-wave delay |
| `max_seconds_between_waves` | integer | — | Random maximum inter-wave delay |
| `max_altitude_ft` | integer | — | Remove AI units above this altitude |
| `min_altitude_ft` | integer | — | Remove AI units below this altitude |
| `max_seconds_outside_ia` | integer | — | Seconds before off-zone AI group is discarded |
| `minimum_life_percent` | number | — | Remove AI unit when life drops below this fraction |

### `waves[]` fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `groups` | string | — | DCS group name, space-separated list, or VEAF spawn command |
| `delay` | integer | `0` | Seconds after wave cleared before next; `-1` = concurrent |
| `number` | string \| integer | — | How many groups to pick: `2` or `"1-3"` range |
| `bias` | integer | `0` | Shift random start index toward harder entries |

### Minimal example

```yaml
modules:
  AIRWAVES:
    enabled: true
    airwave_zones:
      - name: "BVR Arena"
        start: true
        player_coalitions: [BLUE]
        trigger_zone_name: "ZONE-BVR"
        delay_between_waves: 90
        waves:
          - groups: "su27-2ship"
            delay: 0
          - groups: "su30sm-2ship"
            delay: 60
```

---

## AirWaveZone Builder Methods

| Method | Description |
|--------|-------------|
| `:setName(name)` | Internal identifier |
| `:setTriggerZone(zoneName)` | DCS trigger zone defining the interception area |
| `:setZoneCenter(vec3)` | Zone centre point, as an alternative to a trigger zone |
| `:setZoneCenterFromCoordinates(coords)` | Zone centre from a coordinate string |
| `:setZoneRadius(m)` | Zone radius in metres (when using a centre) |
| `:setDescription(text)` | Label for messages and logs |
| `:addWave(...)` | Add a wave — see [Wave definition](#wave-definition) |
| `:resetWaves()` | Clear all added waves (useful after `mist.utils.deepCopy`) |
| `:addPlayerCoalition(side)` | Add a coalition whose players count (e.g. `coalition.side.BLUE`) |
| `:setRespawnRadius(m)` | Spawn scatter radius (default: 250 m) |
| `:setRespawnDefaultOffset(lat, lon)` | Offset from zone centre for spawns (metres, lat/lon) |
| `:setMaxSecondsOutsideOfZoneIA(n)` | Seconds before an AI wave group is considered lost if it leaves the zone |
| `:setMaxSecondsOutsideOfZonePlayers(n)` | Seconds before the zone resets if all players leave |
| `:setDelayBetweenWaves(n)` | Default delay in seconds between waves |
| `:setDelayBeforeActivation(n)` | Seconds after players enter before the first wave |
| `:setMinimumAltitudeInFeet(n)` | Player detection floor (in feet) |
| `:setMaximumAltitudeInFeet(n)` | Player detection ceiling (in feet) |
| `:setResetWhenDying(bool)` | Reset the zone when a player dies |
| `:setSilent(bool)` | Suppress all messages |
| `:setDrawZone(bool)` | Draw zone outline on map |
| `:setOnStart(fn)` | Callback `(zoneName, playerUnits)` when zone activates |
| `:setOnDeploy(fn)` | Callback `(zoneName, waveIndex, playerUnits)` when a wave is launched |
| `:setOnDestroyed(fn)` | Callback `(zoneName, waveIndex, playerUnits)` when a wave is destroyed |
| `:setOnWon(fn)` | Callback `(zoneName, playerUnits)` when all waves done |
| `:setOnLost(fn)` | Callback `(zoneName, playerUnits)` when the zone is lost |
| `:setOnStop(fn)` | Callback `(zoneName, playerUnits)` when the zone is stopped |
| `:setMessageStart(text)` | Custom zone-start message |
| `:setMessageDeploy(text)` | Custom wave-launched message |
| `:setMessageDeployPlayers(text)` | Custom BRAA message sent to players in the zone |
| `:setMessageDestroyed(text)` | Custom wave-down message |
| `:setMessageWon(text)` | Custom all-waves-done message |
| `:setMessageLost(text)` | Custom loss message |
| `:setMessageStop(text)` | Custom zone-stop message |
| `:start()` | Start the zone |
| `:stop()` | Stop the zone |

---

## Wave definition

`addWave(...)` accepts several forms — from the simplest to the most powerful:

```lua
-- A single group name
:addWave("Bandits Alpha")

-- Several group names at once
:addWave("Bandits Alpha", "Bandits Bravo")

-- A table of group names
:addWave({ "Bandits Alpha", "Bandits Bravo", "Bandits Charlie" })

-- A parameter table with full control
:addWave({
  groups  = { "Fighter 1", "Fighter 2", "Fighter 3", "Fighter 4", "Fighter 5" },
  number  = "1-3",   -- pick between 1 and 3 of these groups at random
  bias    = 2,        -- start the random pick from the 3rd group (index 2+1)
  delay   = 30,       -- wait 30 s before spawning the next wave after this one is cleared
})
```

### `number` — controlling how many spawn

`number` sets how many groups from the list are actually spawned. It can be:
- An integer: `number = 2` always spawns exactly 2 groups
- A range string: `number = "2-4"` randomly spawns 2, 3, or 4 groups

If `number` exceeds the list length, the same group can be picked more than once — useful for spawning multiple instances of the same threat.

### `bias` — skewing towards harder variants

`bias` shifts the starting index of the random selection towards the end of the list. A `bias` of 0 (default) picks from the whole list uniformly. A `bias` of 3 on a 6-group list means the first 3 entries are less likely to be chosen.

The typical pattern is to order groups from easiest to hardest — early in a campaign `bias` stays at 0, and you increase it over time to make the opposition progressively more dangerous:

```lua
-- A wave pool ordered by difficulty. Adjust bias= dynamically in callbacks.
:addWave({
  groups = {
    "Su-25 Flight",       -- 1: easy
    "Su-25T Flight",      -- 2: medium
    "Su-27 Flight",       -- 3: hard
    "Su-30SM Flight",     -- 4: very hard
  },
  number = "1-2",
  bias   = 0,   -- start easy; raise to 2 later in the mission
})
```

### `delay` — simultaneous waves

When `delay` is **negative**, the next wave spawns immediately after this one — without waiting for it to be destroyed. This lets you send multiple threat packages at once:

```lua
:addWave({ groups = { "Fighter Escort" }, delay = -1 })  -- launches together with...
:addWave({ groups = { "Strike Package" } })              -- ...this wave
```

### VEAF commands as groups

Instead of a DCS group name, you can use any VEAF spawn command (the same syntax as an F10 map marker). The command is executed at the spawn position, which can be adjusted with a `[latDelta,lonDelta]` prefix (in metres, relative to the zone centre):

```lua
:addWave({
  groups = {
    "[0,5000]-spawn su-27, country russia",           -- 5 km north of zone centre
    "[-3000,0]-spawn su-25, alt 100, country russia", -- 3 km south, low level
  }
})
```

This makes it easy to set up layered threats from different directions without pre-placing groups in the DCS Mission Editor.

---

## Examples

### Basic three-wave intercept zone

```lua
AirWaveZone:new()
  :setName("Intercept-West")
  :setTriggerZone("ZONE-WEST-INTERCEPT")
  :setDescription("Western threat axis")
  :addPlayerCoalition(coalition.side.BLUE)
  :addWave({ "Su-25T Strike 1a", "Su-25T Strike 1b" })
  :addWave({ "Su-25T Strike 2a", "Su-25T Strike 2b", "Su-25T Strike 2c" })
  :addWave({ "Su-24M Deep Strike" })
  :setDrawZone(true)
  :setOnWon(function()
    trigger.action.setUserFlag("WEST_CLEAR", true)
  end)
  :start()
```

### Randomised waves with escalating difficulty

```lua
AirWaveZone:new()
  :setName("Intercept-East")
  :setTriggerZone("ZONE-EAST-INTERCEPT")
  :setDescription("Eastern threat axis — progressive difficulty")
  :addPlayerCoalition(coalition.side.BLUE)
  -- Wave 1: pick 1 or 2 light fighters from a pool
  :addWave({
    groups = { "MiG-21 Flight", "MiG-23 Flight", "MiG-29 Flight", "Su-27 Flight" },
    number = "1-2",
    bias   = 0,
    delay  = 120,   -- 2-minute breather before wave 2
  })
  -- Wave 2: medium fighters, slightly harder pool
  :addWave({
    groups = { "MiG-29 Flight", "Su-27 Flight", "Su-30SM Flight" },
    number = 2,
    bias   = 1,
    delay  = 60,
  })
  -- Wave 3: heavy escort + simultaneous ground attack (negative delay)
  :addWave({ groups = { "Su-27 Escort" }, delay = -1 })
  :addWave({ groups = { "Su-24M Strike" } })
  :setDrawZone(true)
  :start()
```

### Reusing a template zone with deep copy

When several sectors share the same wave structure, define a template zone and clone it. Use `:resetWaves()` to clear the template's waves before adding sector-specific ones:

```lua
-- Define a shared template (NOT started yet)
local zoneTemplate = AirWaveZone:new()
  :addPlayerCoalition(coalition.side.BLUE)
  :setDrawZone(true)
  :addWave({ "MiG-29 Wave 1" })
  :addWave({ "Su-27 Wave 2" })

-- Clone and customise for each sector
local zoneNorth = mist.utils.deepCopy(zoneTemplate)
zoneNorth
  :setName("AW-North")
  :setTriggerZone("ZONE-AW-NORTH")
  :setDescription("Northern sector")
  :start()

local zoneSouth = mist.utils.deepCopy(zoneTemplate)
zoneSouth
  :setName("AW-South")
  :setTriggerZone("ZONE-AW-SOUTH")
  :setDescription("Southern sector")
  :resetWaves()                          -- clear template waves
  :addWave({ "Su-25T Wave 1" })          -- add sector-specific waves
  :addWave({ "Su-24M Wave 2", "Su-24M Wave 2b" })
  :start()
```

---

## Zone lifecycle (state machine)

Each `AirWaveZone` progresses through a set of named states. Understanding them helps when reading logs or writing callbacks.

```
STOP ──start()──► READY
                    │  player(s) enter zone
                    ▼
         WAITING_FOR_MORE_HUMANS
                    │  activation delay elapsed
                    ▼
              ┌── NEXTWAVE ──┐
              │               │
         last wave        more waves
              │               │
              ▼               ▼
            OVER    WAITING_FOR_NEXTWAVE
                            │  inter-wave delay elapsed
                            ▼
                          ACTIVE
                            │  wave destroyed
                            └──► NEXTWAVE  (loops until OVER)
```

| State | Meaning |
|-------|---------|
| `STOP` | Zone inactive — `stop()` was called or the zone has never been started. |
| `READY` | Zone started, watching for players to enter. |
| `WAITING_FOR_MORE_HUMANS` | At least one player is in the zone; the activation timer is running. |
| `NEXTWAVE` | Transient routing state: immediately decides between `OVER` and `WAITING_FOR_NEXTWAVE`. |
| `WAITING_FOR_NEXTWAVE` | Wave slot available; the inter-wave delay is counting down. |
| `ACTIVE` | Current wave is spawned and alive. |
| `OVER` | All waves have been destroyed — the zone is finished. |

`NEXTWAVE` is a transient state that the zone crosses in a single `check()` cycle: it never lingers there. Callbacks such as `setOnDestroyed` fire on the `ACTIVE → NEXTWAVE` exit, and `setOnWon` fires on the `NEXTWAVE → OVER` entry.

---

## See Also

- [veafQraManager](veafQraManager.md) — defensive scramble system
- [veafCombatZone](veafCombatZone.md) — ground-based combat zones
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafAirWaves` API
