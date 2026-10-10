# veafAirWaves — Wave-Based Air Attacks


**Module ID:** `AIRWAVES` | **File:** `veafAirWaves.lua`

> **See it in game**: step 12 “BVR arena (air waves)” of the [demo mission](https://github.com/VEAF/VEAF-Demo-Mission-v6/blob/main/README.en.md#the-guided-tour).

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

## Configuration (`mission.yaml`) {#configuration-missionyaml}

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
        max_altitude_ft: 30000          # player detection ceiling in feet — a player above it is not counted in the zone
        min_altitude_ft: 1000           # player detection floor in feet
        max_seconds_outside_ia: 300     # seconds before an AI group is considered lost outside zone
        minimum_life_percent: 10        # life percentage (0–100) below which an AI unit counts as destroyed (default: 0)
        reset_when_dying: false         # reset all waves when a player dies
        closed_once_active: false       # true = dead is dead: an intruder is warned, shot at, then destroyed
        max_seconds_outside_players: 30 # the escalation delay (leaving the zone, intruder in a closed zone)
        # links: ["Maykop"]             # airbases, FARPs, ships, groups or statics the zone depends on
        # follow_unit: "CVN-74"         # the zone follows this unit
        message_start: "Zone active!"   # custom zone-start message (optional)
        message_wait_for_humans: "Waiting for players..."
        message_wave_deployed: "Wave inbound!"
        message_end_zone: "Zone cleared!"
        message_end_all: "All zones cleared!"
        waves:
          - groups: "su27-flight"       # DCS group name, YAML list of names, or VEAF command
            delay: 0                    # seconds after this wave is cleared before the next; -1 = concurrent
            number: "1-2"              # how many groups to pick: integer or "min-max" range
            bias: 0                     # shift random selection towards harder groups
          - groups: "su30sm-flight"
            delay: 120
            friendly_groups: ["Tanker"]   # to defend: if they all die, the zone is lost
            support_groups: "Red AWACS"   # scenery: they count neither for the end of the wave nor for its loss
```

### `airwave_zones[]` common fields

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `name` | string | — | Yes | Internal identifier |
| `description` | string | — | No | Label shown in messages and logs |
| `start` | boolean | `false` | No | Auto-start at mission launch |
| `player_coalitions` | string[] | — | No | Coalitions whose players trigger waves (`BLUE`, `RED`). The waves spawn for the opposite side |
| `links` | string[] | `[]` | No | What the zone depends on: airbases, FARPs, ships, groups or statics, by DCS name. An airbase or FARP no longer held by the waves' side, or too damaged, **pauses the zone** (the current wave goes) until it is retaken; a ship, group or static destroyed **stops it for good** |
| `follow_unit` | string | — | No | Name of a unit the zone follows (a carrier, for instance). A trigger zone linked to a unit in the editor follows it too, without this key. The drawing on the map stays where it was put at start |
| `closed_once_active` | boolean | `false` | No | **Dead is dead**: once the zone runs, a human who was not in it at activation — or who comes back in the slot of an aircraft shot down — is warned, then put under flak, then destroyed, on the delay of `max_seconds_outside_players` (30 s without it) |

### Zone location (use one)

| Field | Type | Description |
|-------|------|-------------|
| `trigger_zone_name` | string | DCS trigger zone name (preferred) |
| `zone_center_coordinates` | string | Coordinate string, e.g. `"N41°00'00\" E044°00'00\""` |
| `zone_radius` | number | Zone radius in metres (required with coordinates) |

#### Writing a coordinate with seconds {#coordinate-with-seconds}

The symbol for seconds is a double quote, and it is the form DCS puts on screen — so the
coordinate you copy out of the game contains a `"` twice. Two ways to write it in YAML:

```yaml
# Double-quoted: the seconds symbol must be escaped with a backslash
zone_center_coordinates: "N41°00'00\" E044°00'00\""

# Single-quoted: nothing to escape, but the minutes symbol must then be doubled
zone_center_coordinates: 'N41°00''00" E044°00''00"'
```

Both produce the same position. Spaces work as separators too, if you would rather avoid
the punctuation altogether: `N41 00 00 E044 00 00`.

Until 6.17 a coordinate written with seconds broke the generated `veaf-config.lua`, which
DCS then refused *in full* — the mission loaded with no VEAF radio menu at all. The build
now checks the file it generates and refuses to ship one that does not parse.

### Timing and limits

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `delay_before_activation` | integer | `0` | Seconds before first wave after players enter |
| `delay_between_waves` | integer | `0` | Fixed inter-wave delay (overridden by min/max) |
| `min_seconds_between_waves` | integer | — | Random minimum inter-wave delay |
| `max_seconds_between_waves` | integer | — | Random maximum inter-wave delay |
| `max_altitude_ft` | integer | — | Player detection ceiling: a player above it is not counted in the zone |
| `min_altitude_ft` | integer | — | Player detection floor: a player below it is not counted in the zone |
| `max_seconds_outside_ia` | integer | — | Seconds before off-zone AI group is discarded |
| `minimum_life_percent` | number | `0` | Life percentage (0–100, compared to `100 × life / initial life`) below which an AI unit counts as destroyed |
| `max_seconds_outside_players` | integer | — | Delay of the escalation applied to a player who left the zone, or to an intruder in a closed zone: flak past this delay, destruction past twice it |

### `waves[]` fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `groups` | string or string[] | — | DCS group name, YAML list of names (`["su27-a", "su27-b"]`), or VEAF command (`[0,0]-spawn …`, `-sa6`). A string is **not** split on spaces: it names one group. `validate` checks that every name that is not a command exists in the mission |
| `delay` | integer | `0` | Seconds after wave cleared before next; `-1` = concurrent |
| `number` | string \| integer | — | How many groups to pick: `2` or `"1-3"` range |
| `bias` | integer | `0` | Shift random start index toward harder entries |
| `friendly_groups` | string or string[] | — | Groups or VEAF commands **to defend**, spawned with the wave for the players' side. If they all die, the zone is lost — the same message and reset as the players' death. Survivors go with the wave |
| `support_groups` | string or string[] | — | **Unimportant** groups or VEAF commands (support, defence), spawned with the wave for the waves' side. They count neither for the end of the wave nor for its loss, and go with it |

### Control radio menu (shortcut)

AirWave zone start/stop/reset commands **do not exist** in the standard VEAF radio menu (unlike CombatZone or Carrier). To give the Mission Master F10 control over a zone, add `radio_menu: true` to its definition: the framework automatically generates a submenu named after the zone, with "Start &lt;name&gt;", "Stop &lt;name&gt;" and "Reset &lt;name&gt;" commands.

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `radio_menu` | boolean | `false` | No | Automatically generate an F10 radio submenu to control this zone |
| `radio_menu_restrict_to_group` | string | — | No | Name of a DCS group; the generated submenu only appears for that group |
| `radio_menu_secured` | boolean | `false` | No | **Secured** commands: only a pilot of that group with the required security level can run them. Requires `radio_menu_restrict_to_group`; the build refuses otherwise |

```yaml
modules:
  AIRWAVES:
    airwave_zones:
      - name: "BVR Zone"
        start: true
        player_coalitions: [BLUE]
        trigger_zone_name: "ZONE-BVR"
        waves:
          - groups: "su27-flight"
        radio_menu: true                         # generates the control submenu
        radio_menu_restrict_to_group: "MM Ctrl"  # optional: restrict the submenu to this DCS group
        radio_menu_secured: true                 # optional: and require the security level ("+…" commands)
```

!!! warning "This menu is not secured"
    Without `radio_menu_restrict_to_group`, the submenu is posted for **every player**, on both sides,
    and its commands run without asking for any security level. On a public server, any pilot can stop
    or reset a zone while others are fighting in it. Keep it for a Mission Master group with
    `radio_menu_restrict_to_group` — knowing that any player who takes that group's slot sees the menu
    in turn — and add `radio_menu_secured: true` so that pilot must also hold the required security level.

This is **mechanism 1** (per-module shortcut). For a custom MM menu that is structured or combines several actions (AirWaves, QRA, flags, messages, Lua), use **mechanism 2** described in [veafRadio → Radio menus in YAML](veafRadio.en.md#radio-menus-in-yaml).

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
| `:resetWaves()` | Clear all added waves (useful after `veaf.deepCopy`) |
| `:addPlayerCoalition(side)` | Add a coalition whose players count (e.g. `coalition.side.BLUE`) |
| `:setRespawnRadius(m)` | Spawn scatter radius (default: 250 m) |
| `:setRespawnDefaultOffset(lat, lon)` | Offset from zone centre for spawns (metres) — first number north, second east; see [below](#spawn-offset) |
| `:setMaxSecondsOutsideOfZoneIA(n)` | Seconds before an AI wave group is considered lost if it leaves the zone |
| `:setMaxSecondsOutsideOfZonePlayers(n)` | Escalation delay for a player who left the zone (or an intruder in a closed zone): flak past this delay, destruction past twice it |
| `:setClosedOnceActive(bool)` | Close the zone once it runs: dead is dead |
| `:setFollowUnit(unitName)` | The zone follows this unit, a carrier for instance |
| `:addLink(name)` | Make the zone depend on an airbase, FARP, ship, group or static |
| `:setLinkMinLifePercent(pct)` | Minimum health of a linked airbase (0–1, default `0.9`) |
| `:setCoalition(side)` | The waves' side (default: opposite the players) |
| `:setDelayBetweenWaves(n)` | Default delay in seconds between waves |
| `:setDelayBeforeActivation(n)` | Seconds after players enter before the first wave |
| `:setMinimumAltitudeInFeet(n)` | Player detection floor (in feet) |
| `:setMaximumAltitudeInFeet(n)` | Player detection ceiling (in feet) |
| `:setMinimumLifeForAiInPercent(n)` | Life percentage (0–100) below which an AI unit counts as destroyed (default: 0) |
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

### What a fighter group does {#fighter-group-task}

A group whose **task** (in the editor) is `CAP` or `Intercept` gets its job from the script when its route
does not give it one: if it carries no aircraft engagement task (`EngageTargets` or `EngageTargetsInZone`
with *Air* targets), it is launched on **zone defense**:

- it appears where you placed it, with the options of its first waypoint (ROE, reaction to threat…);
- it flies to the wave zone and holds a race-track centred on it, along the axis it arrives from (a 20 NM
  leg, or the zone's diameter when that is shorter);
- it engages only the aircraft that enter the zone, which it ranks by type and distance.

A group placed **on a parking spot or the runway** keeps its take-off as you set it, then climbs to
27,000 ft for its patrol.
It has **ten minutes to take off** (`veafAirWaves.TAKEOFF_TIMEOUT`): until an aircraft has been seen airborne it is rolling, not out of the fight; still on the ground after that, it is counted as such and removed, like one that has landed.

So this is the normal case: place the fighter with **a single waypoint** and no task, and the script
does the rest; the build says so for every such group. If you want a flight plan of your own, write it **with** an aircraft engagement task: it is
then flown as written. A hand-written route without that engagement is replaced, and the build warns you
about it. A group with any other task (`CAS`, `Ground Attack`, `Escort`…) always flies its route.

A `-cap` command listed in a wave also defends the wave zone, not the 60 NM zone it draws around
its own leg.

### VEAF commands as groups {#spawn-offset}

Instead of a DCS group name, you can use any VEAF spawn command (the same syntax as an F10 map marker). The command is executed at the spawn position, which can be adjusted with a `[latDelta,lonDelta]` prefix (in metres, relative to the zone centre).

The **first** number moves the spawn along the north–south axis, the **second** along the east–west one. Both are positive towards the north and the east:

```lua
:addWave({
  groups = {
    "[5000,0]-spawn su-27, country russia",           -- 5 km north of zone centre
    "[0,-3000]-spawn su-25, alt 100, country russia", -- 3 km west, low level
  }
})
```

!!! warning "Behaviour change"
    Until this was fixed, the two numbers were applied to the wrong axes: the first moved the spawn **east** and the second **south**, whatever their names said. If your mission sets a non-zero offset — through this prefix or through `setRespawnDefaultOffset` — its spawn point moves when you upgrade past that fix, and an offset you had tuned by eye against the old behaviour needs to be written the way it reads.

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
local zoneNorth = veaf.deepCopy(zoneTemplate)
zoneNorth
  :setName("AW-North")
  :setTriggerZone("ZONE-AW-NORTH")
  :setDescription("Northern sector")
  :start()

local zoneSouth = veaf.deepCopy(zoneTemplate)
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
| `PAUSED` | A linked airbase is lost: the current wave is gone, the zone waits for the airbase to be retaken, then starts again. |

`NEXTWAVE` is a transient state that the zone crosses in a single `check()` cycle: it never lingers there. Callbacks such as `setOnDestroyed` fire on the `ACTIVE → NEXTWAVE` exit, and `setOnWon` fires on the `NEXTWAVE → OVER` entry.

---

## See Also

- [veafQraManager](veafQraManager.en.md) — defensive scramble system
- [veafCombatZone](veafCombatZone.en.md) — ground-based combat zones
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafAirWaves` API
