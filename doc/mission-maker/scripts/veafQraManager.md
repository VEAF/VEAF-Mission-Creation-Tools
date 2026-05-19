# veafQraManager — Quick Reaction Alert

> 🇫🇷 [Version française](../fr/scripts/veafQraManager.md)

**Module ID:** `QRA` | **Version:** 1.2.x | **File:** `veafQraManager.lua`

---

## Purpose

Defines protected airspace zones defended by AI interceptors. When a hostile aircraft enters the zone, a QRA flight is scrambled. Once the QRA is destroyed, the zone is undefended until it resets (when all intruders have left). Supports multiple groups, rearming, airbase dependency, and radio status messages.

---

## Dependencies

- `veafRadio` — status messages (optional)
- `veafSpawn` — AI group spawning

---

## Enable

No global `initialize()` call needed. Each QRA zone is individually created and initialised:

```lua
local myQra = VeafQRA:new()
  :setName("QRA-North")
  :setZone("ZONE-QRA-NORTH")
  :setCoalition(coalition.side.RED)
  :setGroups({ "MiG-29 QRA" })
  :initialize()
```

---

## VeafQRA Builder Methods

| Method | Description |
|--------|-------------|
| `:setName(name)` | Internal identifier and message prefix |
| `:setZone(zoneName)` | DCS trigger zone that defines the defended airspace |
| `:setCoalition(side)` | Which coalition defends the zone |
| `:setGroups(names)` | List of DCS group names to scramble |
| `:setRearmTime(s)` | Seconds before QRA resets after all intruders leave (default: 300) |
| `:setAirbase(name)` | Airbase the QRA depends on — if destroyed, QRA goes offline |
| `:setAirbaseMinLifePercent(pct)` | Minimum airbase health (default: 0.9 = 90%) |
| `:setSilent(bool)` | Suppress radio status messages |
| `:setMessageStart(text)` | Custom message when QRA goes online |
| `:setMessageDeploy(text)` | Custom message when QRA scrambles |
| `:setMessageDestroyed(text)` | Custom message when QRA is destroyed |
| `:setMessageReady(text)` | Custom message when QRA is ready |
| `:setMessageOut(text)` | Custom message when out of aircraft |

---

## QRA State Machine

```
READY ──(intruder enters)──> ACTIVE ──(QRA destroyed)──> DEAD
  ^                                                          |
  └──────(all intruders left + rearm delay)─────────────────┘
```

Additional states: `WILLREARM`, `OUT` (no more groups), `NOAIRBASE` (airbase destroyed), `STOP` (manually disabled).

---

## Configuration Constants

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
  :setZone("ZONE-NORTH-DEFENSE")
  :setCoalition(coalition.side.RED)
  :setGroups({ "MiG-29S QRA North-1", "MiG-29S QRA North-2" })
  :setAirbase("Beslan")
  :setRearmTime(600)
  :initialize()

-- Southern zone, always active, silent
VeafQRA:new()
  :setName("QRA-SOUTH")
  :setZone("ZONE-SOUTH-DEFENSE")
  :setCoalition(coalition.side.RED)
  :setGroups({ "Su-27 QRA South" })
  :setSilent(true)
  :initialize()
```

---

## See Also

- [veafAirWaves](veafAirWaves.md) — wave-based AI attack system (vs QRA which is defensive)
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafQraManager` API
