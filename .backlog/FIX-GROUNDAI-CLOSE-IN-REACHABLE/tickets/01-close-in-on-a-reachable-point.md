# 01 — `closeIn` aims at a reachable point on a checked path

Status: 🧑 waiting-human
Type: fix

## To do

- `ConvoyUnitHandler:closeIn` no longer drives onto the enemy's exact point. It aims at a point short of the enemy, within the convoy's weapons' reach, on the convoy's side of any water between them.
- The path to it is cut into short legs and each leg checked with the scripting API: `land.getSurfaceType` (no `WATER` or `SHALLOW_WATER` when the convoy holds a vehicle that cannot swim), `land.getHeight` / `land.profile` (no slope beyond what the convoy's least capable vehicle climbs; write the threshold as an estimate if not measured). A leg that fails moves the aim or tries another bearing; no reachable aim: the convoy does not push, and says so in one log line.
- Reuse what fits from `D:\dev\_dcs-other\dcs-cartographie\lua\ia-sol\` (read its README and tests first); it is a prototype run once in DCS, so it comes in with VMCT's tests, not as is. Cite the rules used as "measured 2026-11, dcs-cartographie" or "from DCS's code, dcs-cartographie" in the comments; copy nothing from its `docs/14-*`.
- The route is one order of a few `Off Road` points, not one point per leg sent one by one (orders every 2 s or less freeze a group).
- Tests (`test/lua/`, with the DCS mocks): water between the convoy and the enemy → the aim stays on the near bank; a slope too steep → another bearing; a reachable enemy → a route of a few `Off Road` points ending within reach, short of the enemy; nothing reachable → no route, one log line.

## Done when

A convoy in contact closes in along a path DCS can drive, or does not try; with tests.

## Done

- `veafGroundAI.closeInPath`: the aim is `CLOSE_IN_STANDOFF` (300 m, estimated) short of the enemy, halfway when the enemy is closer than twice that; the straight path to it is checked every `CLOSE_IN_SAMPLE_STEP` (25 m) by `reachableAlong`, which stops before water (`WATER`, `SHALLOW_WATER`) or a slope along the drive steeper than the convoy's least capable vehicle climbs. A path cut short is kept when it still brings the convoy `PUSH_PROGRESS_MARGIN` (50 m) closer; otherwise the aim turns around the enemy, at the same distance from it, by `CLOSE_IN_BEARINGS` (±20, ±40, ±60°).
- Water stops every convoy: `Unit.getDesc` does not say whether a vehicle swims (dcs-cartographie), so "a vehicle that cannot swim" cannot be told apart; a convoy of swimmers stays on its bank too.
- The slope: `veafGroundAI.maxSlopeOf`, the lowest `Unit.getDesc().maxSlopeAngle` of the group (a sine), `DEFAULT_MAX_SLOPE` 0.35 (estimated, the prototype's prudent value) when DCS gives none. No extra margin: a BTR-80 given 0.47 climbed 31° (measured 2026-11, dcs-cartographie).
- `closeIn` gives one order of a few `Off Road` points, `CLOSE_IN_LEG` (200 m) apart at most. Nothing reachable: no route, one log line ("no reachable point toward an enemy … not closing in"), and the push clock restarts, so the next try comes two minutes later and counts toward `FUTILE_PUSHES`.
- Tests: `test_veafGroundAI_convoy.lua` (a reachable enemy, a close enemy, water on the way, a slope on the way, an aim that failed, nothing reachable, the least capable vehicle; the watch with nothing reachable); the stalemate tests now expect the aim 300 m short of the enemy.

## In-game check

On the Campagne server (or a test mission with a river between a convoy and its enemy): the convoy moves within 30 s of a "closing in" line and stops on its side of the water.
