# 01 — measure what one catalogued point costs, before sweeping anything

Status: ✅ done — measured in game on Caucasus, 2026-09-28; **decision 1 reopened** (see *Verdict*)
Type: chore

## Why this comes first

The perimeter decision rests on an estimate that is **known to be wrong in one direction**. It
assumed one probe per point; decision 2 asks for the **clear radius** at each point, which costs
several. Nobody knows how many, so nobody knows whether the coarse pass takes forty minutes or six
hours — and that difference decides whether the whole-map pass survives at all.

This is deliberately its own ticket: a measurement that could change the design must not be buried
inside the work it would change.

## What to measure

1. **The cost of one point with its radius**, for whatever method obtains it — expanding rings until
   the first obstacle, bisection between two bounds, or a fixed ladder of radii. Compare at least
   two; the cheapest that is accurate enough wins.
2. **The accuracy that costs the least.** A radius good to 10 m is probably as useful as one good to
   1 m, since a group's footprint moves by up to 38.8 m between draws. Find the coarsest answer that
   still discriminates.
3. **The real duration of both passes**, extrapolated from the above and given as a range rather
   than a single figure.

Baseline already in hand: one probe is **0.38 ms** (~2600/s), measured in game on 2026-09-26. The
large-clearance query is 12.0 ms and must not be used here at all.

## What was measured, 2026-09-28

Caucasus, on the empty survey mission (`veaf-tools` `clear_ground_survey.build_survey_mission`, no
unit at all), over `dcs-serve`. Twelve sample points 3 km from twelve airfields drawn at random with
a fixed seed. Raw figures in the session log; method in `clear_ground_survey.measure_cost`.

**Two methods compared.**

- **Rings** (the reference): one probe at the point, then rings every 20 m, one probe every 20 m of
  arc, until one holds a sample that is not clear. The radius is the last clear ring.
- **Grid + distance transform**: one probe per grid cell, and the radius of a cell is its distance
  to the nearest cell that is not clear, less one spacing — computed offline, 1.4 s per million
  cells in pure Python. The grid is centred on the sample itself for the comparison: a snapped grid
  put the nearest cell up to 140 m away, and the first run compared two different places.

**Cost.**

| | measured |
|---|---|
| one probe, on an empty mission | **0.15 to 0.17 ms** (0.38 ms on 2026-09-26 was taken on a loaded mission) |
| one call across `dcs-serve`, empty chunk | **190 ms** — the bridge's cadence, not DCS |
| rings, per point, to 500 m | 1 to 2 055 probes, 0.2 to 0.8 s — dominated by the call |
| grid, per point | **one probe**; the radius costs nothing more |

So the call is what costs, not the probe: a batch must carry whole rows, several at a time (10 000
cells per call spends 1.5 s probing for 0.19 s crossing).

**Accuracy, grid radius against rings, same 12 points.**

| spacing | worst error | in the unsafe direction (grid promises more than there is) |
|---|---|---|
| **25 m** | −20 / +10 m | +10 m, twice — within the 40 m margin |
| 50 m | **+130 m** | once: a copse between two cells, 60 m from the point (grid said 170 m, rings 40 m) |
| 100 m | +80 m | several |
| 200 m | **+200 m** | several (240 m promised where rings stop at 40 m) |

Where the rings reach their 500 m ceiling the grid reads 550 to 1 000 m: that is the ceiling of
the reference, not an error of the grid.

**Durations**, Caucasus (409 × 699 km over its airfields plus 20 km; 21 airfields), at the measured
0.15 ms a probe and 10 000 cells per call:

| pass | cells | duration |
|---|---|---|
| fine around the 21 airfields, 6 km squares at 25 m | 1.2 M | **~4 min** |
| fine, one combat zone, 6 km square at 25 m | 58 k | **~10 s** |
| whole map at 200 m | 7.1 M | ~20 min — but its radius is not usable |
| whole map at 50 m | 114 M | ~5 h — and wrong once in twelve |
| whole map at 25 m | 457 M | ~20 h |

## Verdict

- **The method is the grid, at 25 m.** One probe per point, the radius from a distance transform.
  The rings are exact but pay a call per point; the grid pays one probe per point and is within the
  margin at 25 m.
- **The coarse pass cannot carry a radius.** At 200 m it promises clearings that are not there, in
  the direction that puts a battery in a wood. Cost was never the issue; accuracy is.
- **Decision 1 is reopened** — the ticket's own rule. What the numbers suggest, for David to decide:
  sweep finely (25 m) where groups are placed, answer "not covered" everywhere else and place as
  requested (decision 4), and since a combat zone sweeps in ten seconds, sweep a zone on demand
  when DCS is at hand rather than the whole map ahead of time.

## Definition of done

- [x] The per-point cost is measured, not estimated, for at least two radius methods
- [x] The duration of the coarse and fine passes is stated as a range, with the method that produced
      it
- [x] If the whole-map coarse pass turns out to cost hours rather than minutes, **say so and reopen
      decision 1** rather than quietly shrinking the perimeter — reopened on accuracy rather than
      cost: the 200 m pass is affordable and wrong
- [x] The numbers land in the PRD, replacing the estimates it currently carries — once David has
      decided what replaces decision 1
