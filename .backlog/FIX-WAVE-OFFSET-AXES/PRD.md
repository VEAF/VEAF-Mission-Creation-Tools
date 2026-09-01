# FIX-WAVE-OFFSET-AXES — `[latDelta,lonDelta]` moves east and south, not north and east

Status: ⬜ ready

Found on 2026-09-01 while fixing
[`FIX-AIRWAVES-COMMAND-EASTING`](../FIX-AIRWAVES-COMMAND-EASTING/PRD.md), on the line above the one
that lot fixes. **Deliberately not fixed there**: that lot restores a missing coordinate, while this
one changes where every existing mission with a non-zero offset puts its groups. Folding the two
together would make a regression indistinguishable from the fix, and this one needs David's call
before anything moves.

## What the code does

Both modules, both branches — `veafAirWaves.lua:1011` and its twin `veafQraCore.lua:993`, and again
in each file's DCS-group branch twenty lines below:

```lua
local position = { x = zoneCenter.x - lonDelta, y = zoneCenter.y, z = zoneCenter.z + latDelta }
```

`zoneCenter.x` is the **northing** and `zoneCenter.z` the **easting** — the file sets them that way
from a trigger zone, `zoneCenter.x = triggerZone.x` and `zoneCenter.z = triggerZone.y`, which is the
mission-table convention in `docs/agents/dcs-coordinates.md`. So:

| The value named | is applied to | which moves the spawn |
|---|---|---|
| `latDelta` — the **first** bracket number | `z`, the easting, **added** | **east** |
| `lonDelta` — the **second** bracket number | `x`, the northing, **subtracted** | **south** |

The names say latitude and longitude. `AirWaveZone:setRespawnDefaultOffset(defaultOffsetLatitude,
defaultOffsetLongitude)` says so in its own signature and its `@param` tags. A latitude delta belongs
on the northing and a longitude delta on the easting, and neither is where it lands — plus the
northing is subtracted, so a positive "latitude" offset moves *away* from the pole.

The swap is consistent across all four sites, so it is one decision made once and copied, not a slip.

## The documentation is wrong too, and not in a way that reveals the intent

`doc/mission-maker/scripts/veafAirWaves.en.md:274-275` and `veafAirWaves.md:273-274`:

```lua
"[0,5000]-spawn su-27, country russia",           -- 5 km north of zone centre
"[-3000,0]-spawn su-25, alt 100, country russia", -- 3 km south, low level
```

Measured against the code: `[0,5000]` is 5 km **south**, and `[-3000,0]` is 3 km **west**. The first
comment is wrong under *either* reading — the value it annotates is the longitude one, so even taking
the names at face value it should read "east". Whoever wrote it was not describing observed behaviour.

This is why the doc is left alone until the code question is settled: correcting the comments to match
today's behaviour would document the bug, and correcting them to match the names would document
something that does not happen.

## The decision this lot needs before it starts

Two ways out, and they are not equivalent for existing missions:

- **a — the code is wrong.** Put `latDelta` on the northing and `lonDelta` on the easting, both added.
  The names, the signature and the documentation all become true. **But every mission using a non-zero
  offset moves**, by up to twice the offset, in a direction the mission maker may have tuned by eye
  against what the game actually did. Someone who compensated for the swap gets their compensation
  applied twice.
- **b — the names are wrong.** Rename to what the numbers do — `eastDelta` and `southDelta`, or
  `[east,south]` — and fix the documentation to match. Nothing moves; the interface stops lying. But it
  bakes in an axis order (east first) that reads backwards to anyone used to lat/lon, and the setter is
  public API.

**Recommendation: a, with the migration said out loud** — a public interface whose two parameters both
mean something other than their names is a trap that will keep costing, and the offset is a
convenience feature rather than something a mission is built around. But this is David's to decide,
because it is his missions that move.

Worth knowing before deciding: `respawn_default_offset` defaults to `[0, 0]` in the shipped
`mission.yaml`, and `latDelta`/`lonDelta` default to 0 in both modules, so a mission that never sets
an offset is unaffected either way.

## Scope

No tickets yet — the decision above comes first. Whichever way it goes, the deliverable includes a
Lua test asserting the resulting direction per axis with distinct non-zero values (the
`FIX-AIRWAVES-COMMAND-EASTING` suites are the template), the four call sites in step, and the two
documentation pages corrected in both languages.
