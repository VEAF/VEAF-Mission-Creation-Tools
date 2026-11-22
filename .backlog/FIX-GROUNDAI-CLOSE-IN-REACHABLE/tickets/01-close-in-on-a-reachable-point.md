# 01 — `closeIn` aims at a reachable point on a checked path

Status: ⬜ ready
Type: fix

## To do

- `ConvoyUnitHandler:closeIn` no longer drives onto the enemy's exact point. It aims at a point short of the enemy, within the convoy's weapons' reach, on the convoy's side of any water between them.
- The path to it is cut into short legs and each leg checked with the scripting API: `land.getSurfaceType` (no `WATER` or `SHALLOW_WATER` when the convoy holds a vehicle that cannot swim), `land.getHeight` / `land.profile` (no slope beyond what the convoy's least capable vehicle climbs; write the threshold as an estimate if not measured). A leg that fails moves the aim or tries another bearing; no reachable aim: the convoy does not push, and says so in one log line.
- Reuse what fits from `D:\dev\_dcs-other\dcs-cartographie\lua\ia-sol\` (read its README and tests first); it is a prototype run once in DCS, so it comes in with VMCT's tests, not as is. Cite the rules used as "measured 2026-11, dcs-cartographie" or "from DCS's code, dcs-cartographie" in the comments; copy nothing from its `docs/14-*`.
- The route is one order of a few `Off Road` points, not one point per leg sent one by one (orders every 2 s or less freeze a group).
- Tests (`test/lua/`, with the DCS mocks): water between the convoy and the enemy → the aim stays on the near bank; a slope too steep → another bearing; a reachable enemy → a route of a few `Off Road` points ending within reach, short of the enemy; nothing reachable → no route, one log line.

## Done when

A convoy in contact closes in along a path DCS can drive, or does not try; with tests.

## In-game check

On the Campagne server (or a test mission with a river between a convoy and its enemy): the convoy moves within 30 s of a "closing in" line and stops on its side of the water.
