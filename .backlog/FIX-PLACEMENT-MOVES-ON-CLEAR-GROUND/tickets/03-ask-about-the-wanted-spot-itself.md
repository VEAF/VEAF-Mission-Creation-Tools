# 03 — Ask about the wanted spot itself, not about its nearest neighbour

Status: ⬜ ready

Type: fix · Files: `src/scripts/veaf/veafGrass.lua`, `test/lua/test_veafGrass.lua`

Replaces the approach ticket 01 shipped. Ticket 01 is **not** reverted: its occupancy-probe
composition and its logging stay, and its own record of what it delivered stays honest.

## Why ticket 01's guard cannot fire

Measured in game 2026-09-01, twelve instrumented decisions across three `-farp` markers:

```
gap (m):  61.8  46.3  83.9  81.3  58.5  43.9  97.0  82.5  73.1  48.5  69.4  127.0
PLACEMENT_CLEARANCE = 12
```

The nearest candidate ever offered is at **43.9 m**, nearly four times the threshold. The guard's own
log line appears **zero** times in the session.

`Disposition.getSimpleZones(centre, radius, safeRadius, attempts)` **samples at random** inside the
circle rather than tessellating it, so nothing makes a sample land near the requested spot. *"The
nearest candidate proves the wanted spot"* is therefore unsound as a method, whatever constant it
uses — and widening the threshold to ~130 m would accept a spot nothing has shown to be clear, which
is the original defect mirrored.

## What to do instead

Ask DCS about the wanted spot directly. Candidates, in the order worth trying:

1. `Disposition.getSimpleZones(wanted[1], smallRadius, extent + PLACEMENT_CLEARANCE, n)` — same API,
   same knowledge of forests, asked at the right place. A free zone returned within a few metres of
   the centre answers the question.
2. `Disposition.getPointHeight(pos)` / `Disposition.getPointWater(pos, …)` — both exist beside it and
   may be cheaper. **Establish what they actually answer before building on either**; the schema in
   `veaf_libs/data/dcs-schema/dcs-world-api.lua` gives signatures, not semantics.

Whichever is chosen, the reasoning goes in the code: the next reader needs to know why the neighbour
approach was dropped.

## Definition of done

- [ ] The requested bearing is kept when the wanted spot is itself clear of scenery, with the occupancy
      probe still deciding on top — that composition is ticket 01's and is correct
- [ ] Verified against a **real** `-farp` on open ground, not a fabricated gap: the guard's log line
      appears, and bearings come out equal at `1x`
- [ ] Still moves the escort in or beside a wood, and off a static FARP's apron — the two halves that
      make the check able to fail
- [ ] The instrumentation from #898 kept or replaced by something that says as much: it is what turned
      "it does not work" into "the gap is 43.9 m against a 12 m threshold" in one run
- [ ] No test builds its own `gap` to make a branch run. If a value has to be constructed, the test
      says which real measurement it stands for

## The lesson this ticket exists to record

Ticket 01's test asserts a true theorem about a situation the game does not produce. It was green,
reviewed, and shipped, and the defect it was written for survived untouched. **A test that constructs
its own input can confirm the theorem but never the premise** — and the premise is where this one
failed.
