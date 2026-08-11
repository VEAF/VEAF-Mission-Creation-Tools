# DCS coordinates — the same three letters mean two different things

Read this before writing anything that positions an object, in Lua or in Python. It is one page
because the confusion it describes produces **no error at all** — just a wrong position.

## The two shapes

| Where | Shape | `y` is |
|---|---|---|
| **The mission table** — a `.miz`, what the Python tooling reads and writes | `{ x, y }` | **easting** |
| **The runtime scripting API** — a vec3, what Lua sees in game | `{ x, y, z }` | **altitude** |

In both, `x` is the **northing**. The east coordinate is `y` in a mission table and `z` in a runtime
vec3. Nothing in either shape says which one you are holding.

## Why it is invisible

A mission table position fed to a runtime function is not rejected: it is read as a point at
`altitude = <the easting>` and `east = 0`. A group asked to spawn there arrives on the theatre's
central meridian at four hundred thousand metres. Conversely a runtime vec3 written into a mission
table becomes a position a hundred kilometres from the intended one, at sea level, and the mission
opens in the editor perfectly happily.

Neither DCS nor our tooling can catch it. Both shapes are three numbers with plausible names, and
every value involved is a legal coordinate. This is the entire reason the convention is written down
rather than left to be inferred from surrounding code.

## The runtime is not even internally consistent

Worth knowing before assuming "in game it is always a vec3":

```lua
-- veaf.lua:947, inside veaf.getLandHeight
local vec2 = { x = vec3.x, y = vec3.z }
local height = math.floor(land.getHeight(vec2) + 1)
```

`land.getHeight` takes a **vec2**, whose `y` is the easting — the mission-table meaning — while the
`vec3` it was derived from uses `y` for altitude. So the two conventions coexist inside the scripting
API itself, three lines apart. Do not reason from "which side of the fence am I on"; reason from the
signature of the function being called.

## What already handles it — call these instead of converting by hand

- **`veaf.placePointOnLand(point)`** (`src/scripts/veaf/veaf.lua:1118`) accepts either shape: given a
  vec2 it moves `y` into `z` before use, then returns a vec3 whose `y` is the ground height at that
  point. This is the normal way to turn a horizontal position into something spawnable.
- **`veaf.getLandHeight(vec3)`** (`veaf.lua:945`) does the vec3 → vec2 narrowing shown above, so
  callers never build a `land.*` argument themselves.
- **`resolve_coordinates`** (`src/python/veaf-tools/veaf_mission_mcp/map_tools.py:60`) covers the MCP
  path both ways, between mission-table `{x, y}` and `{lat, lon}`. It is why an agent driving the MCP
  has not been bitten by this: the conversion happens below the action.
- **`veaf_libs.coordinates.xy_to_latlon` / `latlon_to_xy`** are the projection underneath it, and their
  docstrings state the convention explicitly ("DCS local X (northing-like)").

An agent writing Lua by hand is the case none of these covers, which is why this page exists — agents
writing Lua is now a normal thing in this repository.
