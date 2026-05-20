# veafAirWaves — Wave-Based Air Attacks

> 🇫🇷 [Version française](veafAirWaves.md)

**Module ID:** `AIRWAVES` | **Version:** 1.7.x | **File:** `veafAirWaves.lua`

---

## Purpose

Defines zones that spawn recurring waves of AI aircraft. When the required number of human players enters the zone, the first wave is launched. As each wave is destroyed, the next wave spawns (with optional delays). Supports player-count scaling, reset on player death, and custom radio messages.

---

## Dependencies

- `veafSpawn` — AI aircraft spawning
- `veafRadio` — status messages (optional)

---

## Enable

No global `initialize()`. Each zone is individually created:

```lua
local defenseZone = AirWaveZone:new()
  :setName("AW-East")
  :setZoneName("ZONE-AIRWAVES-EAST")
  :setDescription("Eastern intercept zone")
  :addWave({ "MiG-23 Wave 1a", "MiG-23 Wave 1b" })
  :addWave({ "MiG-29 Wave 2" })
  :setMinimumPlayersForWave(1)
  :initialize()
```

---

## AirWaveZone Builder Methods

| Method | Description |
|--------|-------------|
| `:setName(name)` | Internal identifier |
| `:setZoneName(zoneName)` | DCS trigger zone defining the interception area |
| `:setDescription(text)` | Label for messages and logs |
| `:addWave(groupNames)` | Add a wave (table of DCS group names) |
| `:setMinimumPlayersForWave(n)` | Minimum human players needed to trigger a wave |
| `:setPlayerCoalitions(sides)` | Which coalitions to count as players |
| `:setPlayerUnitsNames(names)` | Specific player unit names to track |
| `:setRespawnRadius(m)` | Spawn scatter radius (default: 250 m) |
| `:setRespawnDefaultOffset(lat, lon)` | Offset from zone centre for spawns |
| `:setSilent(bool)` | Suppress all messages |
| `:setDrawZone(bool)` | Draw zone outline on map |
| `:setOnStart(fn)` | Callback when zone activates |
| `:setOnWaveDestroyed(fn)` | Callback when a wave is destroyed |
| `:setOnCompleted(fn)` | Callback when all waves done |
| `:setMessageStart(text)` | Custom zone-start message |
| `:setMessageWaitToDeploy(text)` | Custom wave-incoming message |
| `:setMessageWaveDeployed(text)` | Custom wave-launched message |
| `:setMessageWaveDestroyed(text)` | Custom wave-down message |
| `:setMessageCompleted(text)` | Custom all-waves-done message |

---

## Waves

Each wave is a list of DCS group names. All groups in a wave spawn simultaneously. The next wave triggers when all groups of the current wave are destroyed.

```lua
:addWave({ "BanditsA", "BanditsB" })   -- wave 1: two groups spawn at once
:addWave({ "BanditsC" })               -- wave 2: one group
:addWave({ "BanditsD", "BanditsE", "BanditsF" })  -- wave 3
```

---

## Example

```lua
-- Zone that requires 2 human players and has 3 waves
AirWaveZone:new()
  :setName("Intercept-West")
  :setZoneName("ZONE-WEST-INTERCEPT")
  :setDescription("Western threat axis")
  :addWave({ "Su-25T Strike 1a", "Su-25T Strike 1b" })
  :addWave({ "Su-25T Strike 2a", "Su-25T Strike 2b", "Su-25T Strike 2c" })
  :addWave({ "Su-24M Deep Strike" })
  :setMinimumPlayersForWave(2)
  :setDrawZone(true)
  :setOnCompleted(function()
    trigger.action.setUserFlag("WEST_CLEAR", true)
  end)
  :initialize()
```

---

## See Also

- [veafQraManager](veafQraManager.md) — defensive scramble system
- [veafCombatZone](veafCombatZone.md) — ground-based combat zones
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafAirWaves` API
