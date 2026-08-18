# FEAT-SMOKE-CSAR-WATER — answer "CSAR spawns on water" with a script, not a pilot

Status: ⬜ ready

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

## Definition of done

- [ ] `csar-avoids-water` runs from `veaf-tools smoke-test`, both positions
- [ ] It has actually run on a machine with DCS, and the result is recorded here — a harness check
      that has never run is a framework and no evidence, the failure mode `FEAT-DCS-SMOKE-HARNESS`
      was written to avoid
- [ ] #245 closed on the outcome: fixed, or confirmed with the reproduction the assertion gives
- [ ] The check stays as a regression test either way — that is the point of doing it here
