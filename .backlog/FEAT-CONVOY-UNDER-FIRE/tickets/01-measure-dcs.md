# 01 — Measure what DCS gives and honours

Status: 🔄 in-progress — 1 to 6 measured 2026-10-08 (see the PRD's table); 7 to be timed by eye

Before any behaviour is written, measured in DCS through the bridge on a test mission, each with its date in `known-limitations.yaml` (`kind: dcs`) whatever the answer:

1. Which events a ground unit raises when it is shot at and hit — by an aircraft, by a ground unit, by artillery (`S_EVENT_SHOT` on the shooter's side, `S_EVENT_HIT` on the target's).
2. Whether `Controller:getDetectedTargets()` answers for a ground unit, with what range and delay.
3. Whether an AI shooter loses its target behind `effectSmokeBig` (and behind a smoke marker): the ground truth of a smoke screen.
4. Whether a ground group honours `setOption` (alarm state, ROE) and a new formation while it is engaged, or only once it stops.
5. Whether `world.searchObjects` returns trees, so a forest can serve as cover; otherwise only terrain and towns do.
6. How long `land.isVisible` takes, to size how many route points can be tested in one check.
7. How long a smoke marker lasts.
