# FEAT-SMOKE-CSAR-WATER — answer "CSAR spawns on water" with a script, not a pilot

Status: 🧑 waiting-human — the checks ship in 6.15.26; the run is David's

Origin: `CHORE-ISSUE-VERIFY-SESSION` check 1. Addresses
[#245](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/245) — the one check of that lot
that never belonged in a flying session.

## Why it is not a flying check

#245 says a CSAR pilot spawns in the water. Deciding that needs three things: trigger a CSAR at a
position, read back where the pilot was placed, and ask what is under it. All three are scripting
calls. No aircraft, no human, no session — and `FEAT-DCS-SMOKE-HARNESS` (✅ 2026-08-15) exists
precisely to run assertions like this inside a real DCS.

It stayed in the flying mission out of habit, and the lot itself had already noticed it was
"assertable from the smoke harness" without drawing the conclusion. Mission A shipped without it.

## The check

A `csar-avoids-water` entry in the harness:

1. call the CSAR spawn at a given position
2. read the spawned group's position back
3. assert `land.getSurfaceType` is not `land.SurfaceType.WATER`

Run it at **two** positions, because they ask different questions:

- **open sea** — the reported case, and the one that fails today if the defect is real
- **just off the coast** — the interesting one: `FEAT-SCENERY-AWARE-SPAWN` gave `veaf.findSpawnPoint`
  land awareness, and the real question is whether CSAR goes through it at all. A pass on open sea
  with a failure near the coast means CSAR has its own placement path

## Reading the code answered the lot's central question before the run

The PRD's interesting half was: *"the real question is whether CSAR goes through `veaf.findSpawnPoint`
at all"*. **It does not.** `csar.spawnGroup` (`src/scripts/community/CSAR.lua:1041`) places the pilot
like this:

```lua
_group.units[1] = csar.createUnit(_pos.x + 50, _pos.z + 50, 120, "Soldier M4")
```

A **fixed +50/+50 offset, with no surface test of any kind**. Not "goes through findSpawnPoint and a
tier fails" — it never asks. This is the same shape as `FIX-FARP-ESCORT-PLACEMENT`, where the escort
position is a fixed distance and nothing else.

So #245 is almost certainly real, and the prediction is specific: **both** checks should fail, not just
the open-sea one. If the coast check passes while the sea one fails, this reading is wrong and something
else is placing the pilot.

## Why the fix is not in this lot, and where it belongs

`CSAR.lua` is vendored `adapted` from `VEAF/DCS-CSAR` (`vendored.yaml`), whose update procedure is *"pull
the latest ciribob CSAR.lua, re-apply the VEAF adaptations"*. **Editing it here would add an adaptation
nobody recorded, and the next update would silently erase it** — so the obvious one-line fix is the wrong
move.

The clean path already exists: `veaf.csar_initialize_replacement` (`veaf.lua:5467`) already replaces
`csar` functions from VEAF code (`csar.logError`, `csar.logInfo`, …). Replacing `csar.spawnGroup` with a
terrain-aware version belongs there — it survives a vendored update, and it needs no change to a
third-party file.

Filed as `FIX-CSAR-SPAWNS-ON-WATER` rather than done here, because this lot's deliverable is the
measurement and because the fix wants the run to confirm what it is fixing.

## Definition of done

- [x] `csar-avoids-water` runs from `veaf-tools smoke-test`, both positions — `csar-avoids-water-open-sea`
      and `csar-avoids-water-coast`, no coordinate hard-coded so they travel between theatres
- [ ] **It has actually run on a machine with DCS** — not done, and not doable from here: launching a run
      in David's DCS is his. Added as item 20 of `DCS-SESSION-TODO.md`. This box stays unticked on
      purpose: a harness check that has never run is a framework and no evidence
- [ ] #245 closed on the outcome — waiting on the run above
- [x] The check stays as a regression test either way

## What was made decidable without DCS

The verdict logic and the shape of the chunk, by nine tests: a dry placement passes, a wet one fails,
**every** "could not ask" answer fails rather than passing vacuously, the two modes really generate
different chunks, the group is destroyed on the failure paths too, the transport is `BRIDGE` (`csar` is a
mission-environment global — the hook environment would answer `csar-absent` for a mission that has it),
and — the one line no test can reach otherwise — `land.getSurfaceType` is fed `{x = p.x, y = p.z}`, the
easting in `y`, per `docs/agents/dcs-coordinates.md`. Passing `p.y` there reads the surface a hundred
kilometres away and reports it cheerfully.
