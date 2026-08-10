# veafGrass — Grass Airstrip Configuration


**Module ID:** — | **File:** `veafGrass.lua`

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
- FARP-type units (`FARP`, `FARP_SINGLE_01`, `Invisible FARP`, `FARP_T`, `SINGLE_HELIPAD`) whose **group name starts with `FARP ` (FARP followed by a space)** receive FARP scenery.

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
2. Name its **group** so that it starts with `FARP ` (for example `FARP Whiskey`).
3. Call `veafGrass.initialize()`.

At startup, `veafGrass.buildFarpsUnits(hiddenOnMFD)` adds FARP scenery around each recognised unit (via `veafGrass.buildFarpUnits`).

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
