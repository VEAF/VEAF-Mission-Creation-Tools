# 03 — aspect and a priority cut-off in the target ranking

Status: 🧑 waiting-human — done on the mocks, values to tune in R42 of `DCS-SESSION-TODO.md`
Type: feature
Issue: [#187](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/187)

## Need

The ranking in `veafSpawn.startCapWatchdog` uses type and distance only. #187 asks for:

- the target's **aspect** relative to the CAP (hot, cold, flanking) to weigh in the priority;
- a **cut-off** beyond which a target is not engaged at all, depending on the group's mission (escort vs CAP).

## Acceptance

- The aspect computation is a pure function with its own tests (hot, cold, flanking, at the boundaries).
- A target past the cut-off is not tasked; the cut-off differs between the roles that use the watchdog.
- The ladder is documented next to the existing one in the code.

## Decision (David, 2026-10-04)

The escort no longer goes through the watchdog (`air_escort` uses the DCS `Escort` task since #1068), so "escort vs CAP" has nothing left to separate: `cap` and `zone_defense` are the watchdog's only users.
The cut-off became the concrete meaning of *not engaging anything*: **a cold target far away is not chased**.
One constant for both roles; a per-role value only if the game asks for it.

## Done

- `veafSpawn.targetAspect`: the angle between the target's ground track and the line from the target to the CAP — `hot` up to 60°, `cold` from 120°, `flanking` between, and `flanking` (the neutral weight) when there is no track to read.
- The ladder reads the distance weighed by the aspect: ×0.5 hot, ×1 flanking, ×2 cold.
- A cold target more than `CAP_COLD_CUTOFF` (40 km) from the CAP is not listed, and is dropped on the tick it turns away, so a chase in progress stops at once.
- Hysteresis, from the review of the diff: a target already tracked is dropped once cold (120°), one not tracked is picked up again only under 105° (`CAP_COLD_CUTOFF_HYSTERESIS`), so a target beaming about the boundary does not flip the CAP between fight and patrol every tick.
- A velocity that does not answer as a vector reads as no track, so it cannot raise inside the watchdog.
- All three values are estimates, not sourced; they are constants of `veafSpawn`, to tune in game.
- Tests: hot, cold, flanking on both sides, one degree each side of both boundaries, the climb ignored, no track; a hot target outranking a cold one at the same distance; a cold one past the cut-off not engaged while a hot one at the same distance is; one turning cold given up.
