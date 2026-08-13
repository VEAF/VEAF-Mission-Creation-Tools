# veafTransportMission — Transport and Logistics Missions


**Module ID:** `TRANSPORTMISSION` | **File:** `veafTransportMission.lua`

---

## Purpose

Creates a helicopter transport/logistics training mission, driven by an F10 map marker. When a `_transport` marker is placed, the module spawns cargo to pick up near a named start point, a friendly group awaiting that cargo at the drop zone (placed under the marker), and optionally enemy air defenses along the route.

---

## Dependencies

- `veafRadio` — F10 menu
- `veafMarkers` — marker event handler (`_transport`)
- `veafSpawn`, `veafUnits`, `veafNamedPoints`, `veafSecurity`

---

## Enable

```lua
veafTransportMission.initialize()
```

> **Enabled by default** in the shipped `mission.yaml`. It is marker-driven (`_transport`) and needs no configuration — just place a `_transport` marker.

---

## Key Concepts

- **Start point** — a named point (declared via `veafNamedPoints`) where the cargo to transport is spawned. It is mandatory and given by the `from` parameter.
- **Drop zone** — where the friendly group awaiting the cargo is spawned, under the `_transport` marker. The route between the start point and the drop zone must be at least 15 km long.
- **Route defenses** — optional enemy air defense groups spawned along the route when `defense` is greater than `0`.
- Only one transport mission can run at a time.

---

## Marker command

Place a marker on the F10 map and type `_transport` in its text, optionally followed by parameters separated by commas.

```text
_transport, size 3, defense 2, from FARP London
```

### Marker parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `size <n>` | `1`–`5` | `1` | Number of cargo crates to transport |
| `defense <n>` | `0`–`5` | `0` | Air defense cover along the route (`1` = light, `5` = heavy) |
| `blocade <n>` | `0`–`5` | `0` | **Has no effect**: the parameter is parsed but blockade generation is not implemented (TODO in the code) |
| `from <named point>` | named point | — | **Mandatory** start point where the cargo is spawned |
| `password <pwd>` | string | — | Security password unlocking the command |

---

## F10 Radio Menu

The **TRANSPORT MISSION** menu always exposes:

- **HELP** — usage reminder

Once a mission is generated, it adds:

- **Drop zone information** — count of friendly units at the drop zone, plus its coordinates (Lat/Lon, MGRS, bearing/range from bullseye), altitude and wind
- **Skip current objective** — cancel the current mission and clean up
- **Drop zone markers** (submenu)
  - **Request smoke on drop zone** — green smoke over the drop zone
  - **Request illumination flare over drop zone**

---

## See Also

- [veafCombatZone](veafCombatZone.en.md) — for combat objective zones
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafTransportMission` API
