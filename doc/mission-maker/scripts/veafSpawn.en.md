# veafSpawn — Dynamic Unit Spawning


**Module ID:** `SPAWN` | **File:** `veafSpawn.lua`

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
_spawn unit, name F-16C, hdg 180, alt 20000
_spawn unit, name T-80, hdg 270, spacing 50
```

**Options:**

- `name` — unit type
- `hdg` — heading (degrees)
- `alt` — altitude (feet)
- `side` — coalition override
- `country` — country override
- `skill` — AI skill level
- `spacing` — unit spacing (meters)
- `immortal` — make units invulnerable

### Spawn a predefined group

```
_spawn group, name [GROUP_NAME]
```

The group alias must exist in the **spawn database**: the built-in one (e.g. `sa2`, `sa3`, …) or your optional `src/spawn-groups.yaml`, which extends/overrides it. The database lives in YAML and is injected into the `.miz` at build time (no Lua to edit). See [Pipeline Reference — spawn data](../../PIPELINE_REFERENCE.en.md).

> **Typos abort the command.** If a parameter is not recognized (e.g. `headng` instead of `heading`), the spawn is **not** performed and the pilot gets a hint (*did you mean 'heading'?*). Fix the marker text and try again.

### Spawn a CAP patrol

```
_spawn cap, name Su-27, alt 25000, capradius 20000
```

**Options:**

- `name` — aircraft type
- `alt` — patrol altitude (feet)
- `hdg` — initial heading
- `speed` — patrol speed (knots)
- `capradius` — CAP orbit radius (meters)
- `distance` — distance from marker

### Spawn an AFAC/JTAC

```
_spawn afac, name A-10C, freq 133.0, mod AM, laser 1688, alt 15000
```

**Options:**

- `name` — aircraft type
- `freq` — radio frequency
- `mod` — modulation (`AM` or `FM`)
- `laser` — laser code, between `1111` and `1688`. Each of the last three digits runs from 1 to 8 (no `0`, no `9`): `1688` works, `1690` does not. An impossible code is ignored and the default (`1688`) stays in effect.
- `alt` — orbit altitude (feet)
- `speed` — orbit speed (knots)
- `immortal` — make unit invulnerable

### Spawn a convoy

Place two markers: one with the command (start), one as the destination.

```
_spawn convoy, dest [DEST_MARKER_NAME], speed 50, defense 2, armor 2, size 3
```

**Options:**

- `dest` — destination marker name
- `speed` — convoy speed (km/h)
- `defense [0-5]` — air defense level
- `armor [0-5]` — armor level
- `size` — number of vehicles (default: 10; the `-convoy` alias draws a random size between 6 and 15)
- `patrol` — loop back to start
- `offroad` — allow off-road movement

#### Several legs: write `dest` as many times as you need {#convoy-itinerary}

`dest` can be repeated. The convoy walks the points **in the order you write them**, setting off again by itself on each arrival:

```
_spawn convoy, dest KOBULETI, dest BATUMI, dest POTI, speed 40
```

A single `dest` is still a one-leg trip: nothing changes for the markers you already use.

Two things worth knowing:

- **`patrol` applies to the last leg only.** Patrolling between two points of an itinerary would contradict the itinerary itself.
- **A leg starts from wherever the convoy is**, not from where it spawned — it has been driving since.

#### The four radio commands {#convoy-radio-commands}

The F10 menu offers four commands doing four different things. The two brakes in particular are not interchangeable:

| Command | Effect | When to reach for it |
|---|---|---|
| **Send to next point** | starts the next leg at once, without waiting for arrival | to speed up a mission that is dragging |
| **Hold at next point** | lets the convoy **finish its leg**, then park at that point and wait | to pace a mission: the convoy stops somewhere you chose |
| **Halt where it stands** | the convoy stops **on the spot**, mid-road if need be | to rescue a mission going wrong |
| **Resume after a halt** | picks the current leg back up where it was interrupted | after halting on the spot |

"Hold at next point" and "Halt where it stands" look alike from a distance and do not substitute for one another: the first chooses **where** the convoy stops, the second chooses **when**. Every command reports what it did, naming the point involved.

On the last leg, "Hold at next point" tells you there is no next point rather than doing nothing.

### Spawn smoke

```
_spawn smoke, color red
_spawn smoke, color green, shells 5
```

**Colors:** `red`, `green`, `blue`, `white`, `orange`

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

## Spawnable aircraft groups (`src/spawnables.yaml`)

> ⚠️ Not to be confused with the `_spawn group` command (ground/helicopter groups from the `veafUnits` database). This is about real **aircraft groups**, hidden and late-activated, that `veafSpawn` **clones** on demand in-game.

A **spawnable aircraft group** is identified by the **`veafSpawn-` name prefix** (the `veafSpawn` runtime contract). At build time, the `spawnable_aircrafts` pipeline step injects `src/spawnables.yaml` into the `.miz`.

The file uses the **full DCS aircraft-group schema** (`airplanes`/`helicopters` → `coalitions` → country → group), identical to the one described in the [Pipeline Reference — Step 3](../../PIPELINE_REFERENCE.en.md#pipeline-step-3-aircraft-groups). It is usually produced by extracting from a mission:

```bash
veaf-tools content extract-aircraft-groups --kind spawnable
```

**Dynamic-slot templates** (`dynSpawnTemplate = true`, DCS Dynamic Slots) are a separate family, in `src/dynamic-slot-templates.yaml` (step `dynamic_slot_templates`) — see [ADR 0002](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0002-aircraft-group-injection-sort-criteria.md).

---

## See Also

- [veafMove](veafMove.en.md) — moving existing groups
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafSpawn` API
