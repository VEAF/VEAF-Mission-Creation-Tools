# veafSpawn — Dynamic Unit Spawning

**Module ID:** `SPAWN` | **Version:** 1.59.x | **File:** `veafSpawn.lua`

---

## Purpose

Listens for F10 map marker text commands and spawns units, groups, convoys, FARPs, smoke, flares, cargo, and JTAC controllers on demand. This is the primary player-facing spawning interface.

---

## Dependencies

- `veafMarkers` — for marker event handling
- `veafRadio` — for the radio menu
- `veafSecurity` — for permission checks (optional)

---

## Enable

```lua
veafSpawn.initialize()
```

Call after all other modules that veafSpawn depends on.

---

## Key Configuration Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `veafSpawn.SpawnKeyphrase` | `"_spawn"` | Marker prefix that triggers spawn |
| `veafSpawn.DestroyKeyphrase` | `"_destroy"` | Marker prefix for destroy command |
| `veafSpawn.TeleportKeyphrase` | `"_teleport"` | Marker prefix for teleport |
| `veafSpawn.IlluminationFlareAglAltitude` | `1000` | Default flare altitude (m AGL) |
| `veafSpawn.ShellingInterval` | `5` | Seconds between shelling rounds |
| `veafSpawn.AFAC.maximumAmount` | `8` | Max simultaneous AFACs per coalition |
| `veafSpawn.HideRadioMenu` | `false` | Hide the Spawn submenu in F10 |
| `veafSpawn.LogisticUnitType` | `"FARP Ammo Dump Coating"` | Static object type for logistics |

---

## Marker Commands (Player-Facing)

### Spawn a unit

```
_spawn unit, name [DCS_TYPE]
_spawn unit, name F-16C, group 2, hdg 180, alt 20000
_spawn unit, name T-80, group 4, hdg 270, spacing 50
```

Options: `name`, `group`, `hdg`, `alt`, `speed`, `side`, `country`, `skill`, `spacing`, `immortal`.

### Spawn a predefined group

```
_spawn group, name [GROUP_NAME]
```

Group must be defined in `spawnables.yaml`.

### Spawn a CAP patrol

```
_spawn cap, name Su-27, alt 25000, capradius 20000
```

Options: `name`, `alt`, `hdg`, `speed`, `group`, `capradius`, `distance`.

### Spawn an AFAC/JTAC

```
_spawn afac, name A-10C, freq 133.0, mod AM, code 1688, alt 15000
```

Options: `name`, `freq`, `mod`, `code`, `alt`, `speed`, `immortal`.

### Spawn a convoy

Place two markers: one with the command (start), one as the destination.

```
_spawn convoy, dest [DEST_MARKER_NAME], speed 50, defense 2, armor 2, size 3
```

Options: `dest`, `speed`, `defense [0-5]`, `armor [0-5]`, `size [0-5]`, `patrol`, `offroad`.

### Spawn smoke

```
_spawn smoke, color red
_spawn smoke, color green, shells 5
```

Colors: `red`, `green`, `blue`, `white`, `orange`.

### Spawn illumination flares

```
_spawn flare, power 1000000, shells 5, heading 90, distance 500
```

### Spawn explosions

```
_spawn bomb, power 500, shells 3
```

### Spawn a FARP

```
_spawn farp, name "FARP Alpha", side blue
```

### Destroy units

```
_destroy, radius 500
_destroy, name Tank-1
```

### Teleport a group

```
_teleport, name "Viper Flight"
```

---

## Spawnable Groups (spawnables.yaml)

Define reusable group templates that players can spawn with `_spawn group`:

```yaml
groups:
  - name: "RED-CAP"
    description: "Red CAP (2 × MiG-29S)"
    coalition: red
    country: Russia
    units:
      - type: MiG-29S
        skill: High
      - type: MiG-29S
        skill: High

  - name: "ARMOR-PLATOON"
    description: "Armoured platoon (4 × T-80)"
    coalition: red
    country: Russia
    units:
      - type: T-80
        count: 4
        skill: Average
```

---

## See Also

- [veafMove](veafMove.md) — moving existing groups
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafSpawn` API
