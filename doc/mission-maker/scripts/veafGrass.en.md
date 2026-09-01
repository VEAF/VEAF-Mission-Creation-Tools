# veafGrass — Grass Airstrip Configuration


**Module ID:** `GRASS` | **File:** `veafGrass.lua`

---

## Purpose

Configures unprepared grass airstrips for use in DCS missions. Provides positioning data, radio frequencies, and landing aids for rough-field landing zones that are not standard DCS airbases.

---

## Enable

```lua
veafGrass.initialize()
```

`veafGrass.initialize()` schedules `veafGrass.buildFarpsUnits` a few seconds after mission start (to let the other modules load) and registers a birth event handler. There is **no builder class**: everything is driven by the names you give to objects in the DCS Mission Editor.

---

## How it works

At startup the module scans every unit in the mission and acts based on its name:

- Static objects whose **name contains `GRASS_RUNWAY`** (case-insensitive) are used as the origin of a grass strip.
- FARP-type units (`FARP`, `FARP_SINGLE_01`, `Invisible FARP`, `FARP_T`, `SINGLE_HELIPAD`) whose **unit name starts with `FARP ` (FARP followed by a space)** receive FARP scenery.

---

## Grass Runways

To create a grass runway:

1. Place a static object in the DCS Mission Editor at the right-hand end of the future strip, pointing down the runway axis.
2. Name it so that its name **contains `GRASS_RUNWAY`** (for example `GRASS_RUNWAY_WHISKEY`).
3. Call `veafGrass.initialize()` at the module level.

At startup, `veafGrass.buildGrassRunway(grassRunwayUnit, hiddenOnMFD)` builds the strip scenery (rows of plots on each side, a tower) from that object's position and heading.

---

## FARPs

To dress up a FARP:

1. Place a FARP-type unit (`FARP`, `FARP_SINGLE_01`, `Invisible FARP`, `FARP_T` or `SINGLE_HELIPAD`).
2. Name the **unit** so that it starts with `FARP ` (for example `FARP Whiskey`).
3. Call `veafGrass.initialize()`.

At startup, `veafGrass.buildFarpsUnits(hiddenOnMFD)` adds FARP scenery around each recognised unit (via `veafGrass.buildFarpUnits`).

### Where the props are placed {#farp-layout}

The props (tents, depots, escort) are placed at a fixed distance from the FARP, along its heading.
Since 6.15.11, **if that spot is already taken by a unit or a static object, the module walks around
the FARP until it finds clear ground** — keeping the distance and changing the bearing, so the escort
stays near the FARP it serves.

This is the common case rather than an edge one: you place a static FARP in the mission (that is what
unlocks spawning on it once the zone is captured), then run `-farp` on top of it. Before, the escort
came down on its pads — close enough that a helicopter landing there met a truck.

Four things worth knowing:

- **A FARP with clear ground does not move.** The original bearing is tried first, so a mission that
  works keeps its layout exactly.
- **Forests are avoided too**, on top of units, statics and pads: DCS cannot answer *"is this spot
  clear?"* for trees, so the module asks it for a list of tree-free spots and picks from that list. The
  promise above still holds: when the spot you asked for lies in the same clearing as the nearest
  tree-free spot, it is kept as is — until this fix the escort was moved a few dozen metres even in open
  countryside.
- The whole group is checked, not just its first vehicle: the escort occupies a line some thirty metres
  long, and a clear spot whose tail overhangs would still block a pad.
- If no bearing is clear, the FARP is built anyway, at its original position. A FARP refusing to exist
  because the area is crowded would be worse.

> The markers of an `Invisible FARP` sit close to the centre on purpose, to show where the FARP is:
> they do not move.

### Refilling warehouses

Since DCS 2.8, spawned FARPs come up with an empty warehouse. The module provides functions to refill them:

- `veafGrass.fillAllFarpWarehouses()` — browses all valid FARPs and grass strips and fills their warehouses.
- `veafGrass.fillFarpWarehouse(farp)` — fills the warehouse of a given FARP.

The deposited content is defined by the `veafGrass.WAREHOUSE_ITEMS` table. The `veafGrass.helicoptersOnFARPs` table lists the helicopter types added to FARP warehouses so they are available to the dynamic slot mechanism.

---

## Notes

- The grass strip's position and heading are read from the static object named `...GRASS_RUNWAY...`.
- The generated scenery units are hidden on MFDs to avoid cluttering the display.

---

## See Also

- [veafAssets](veafAssets.en.md) — for managed tankers and AWACS at regular airbases
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafGrass` API
