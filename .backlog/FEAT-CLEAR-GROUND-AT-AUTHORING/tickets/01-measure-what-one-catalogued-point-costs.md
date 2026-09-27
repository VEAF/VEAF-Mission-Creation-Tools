# 01 — measure what one catalogued point costs, before sweeping anything

Status: ⬜ ready
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

## Definition of done

- [ ] The per-point cost is measured, not estimated, for at least two radius methods
- [ ] The duration of the coarse and fine passes is stated as a range, with the method that produced
      it
- [ ] If the whole-map coarse pass turns out to cost hours rather than minutes, **say so and reopen
      decision 1** rather than quietly shrinking the perimeter
- [ ] The numbers land in the PRD, replacing the estimates it currently carries
