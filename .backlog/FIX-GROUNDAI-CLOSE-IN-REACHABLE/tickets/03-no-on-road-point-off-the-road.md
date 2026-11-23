# 03 — No route starts `On Road` off the road

Status: 🧑 waiting-human
Type: fix

## To do

- From DCS's code (dcs-cartographie, 2026-11): an `On Road` point far from any road makes the whole route fail, silently. The routes of `veafGroundAI.lua` that put an `On Road` point at the convoy's own position or at a computed point (lines 1361, 1362, 2152, 2157, 2216, 2218, 2245, 2253, 2269 on 2026-11-22) may fail when the convoy is off the road, which is where a fight leaves it.
- For each of them: when the point is more than a few metres from the nearest road (`land.getClosestPointOnRoads`), start with an `Off Road` leg to the road's nearest point, then `On Road`.
- If DCS can be run, measure once whether such a route really fails (a convoy off the road given an `On Road` retreat), and add the result to `known-limitations.yaml` (`kind: dcs`, dated), regenerating `docs/agents/dcs-runtime-traps.md`; otherwise write "from DCS's code, not measured" in the comment.
- Tests: an off-road position gets an `Off Road` leg to the road first; a position on the road does not.

## Done when

No route of the ground AI puts an `On Road` point away from a road; with tests.

## Done

- `veafGroundAI.roadEntry` / `roadExit` / `roadRoute`: a point more than `ON_ROAD_TOLERANCE` (10 m, from DCS's code, not measured) from the nearest road (`land.getClosestPointOnRoads`) gets an `Off Road` leg to the road point, then `On Road` (and `On Road` to the road point, then `Off Road` to a place away from the road); with no road at all, `Off Road`.
- Used by the fall back (`fallBackRoute`: a rally point more than 300 m from a road is no longer an `On Road` point; the friendly place either), the retreat (`_gc …, retreat`, both groups) and the resume (the armed vehicles going to fetch the unarmed ones). `onwardRoute` already went to the road first; the points of a Mission Editor route keep the action their author gave them.
- DCS could not be run in this session: not measured, so no `known-limitations.yaml` entry; the comment says "from DCS's code, dcs-cartographie; not measured".
- Tests: `test_veafGroundAI_convoy.lua` (an off-road position gets to the road first, a position on the road does not, no road stays off road, a rally point off the road, a retreat from off the road).

## In-game check

On the Campagne server, a convoy that fought off the road retires or drives on: `dcs.log` shows it moving after its retreat order.
