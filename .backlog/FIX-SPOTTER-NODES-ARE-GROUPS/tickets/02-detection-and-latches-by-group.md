# 02 — Detection and latches keyed by group

Status: ✅ done

Where the behaviour actually changes. Everything here consumes `listSpotters`, so it moves in one
step or the code is broken in between.

## What to change

- **`listSpotters(coa)` returns groups**, each with its name, its median point (ticket 01) and its
  group profile. A group with no live unit, or with range 0, is not in the list.
- **`spotterDetectionBeat`** iterates groups; the line-of-sight ray is traced **from the median**. The
  memoisation of `seesIt()` per pair on a beat stays as it is.
- **`spotterLatches` is keyed by group name.** So are `stepSpotterLatch`, `onSpotterAcquired`,
  `onSpotterLost` and `forgetSpotter`.
- **`dropLatchesForVanishedContacts`** keeps the coalition filter added by
  `FEAT-SPOTTER-DEMO-MISSION`, now built from the coalition's *group* names. Do not lose it: without
  it no latch survives a beat at all, and it has a test that fails both ways.

## Two things not to get wrong

1. **A group that loses units keeps its latch.** The latch belongs to the group, so losing one truck
   must not release a contact the rest of the convoy still sees. Only the group's disappearance does.
2. **The latch is the live detection state; a contact record is a memory.** That distinction cost a
   spotter six minutes of a red circle on a dead aircraft. It is unchanged by this lot and must stay.

## Tests

The existing beat and latch suites are re-expressed in groups. Add:

- An 11-unit group latches **once**, not eleven times, and raises **one** alert.
- A group loses a unit: the latch survives. It loses its last: the latch goes and a cancellation is
  emitted.
- Line of sight is traced from the median: a group whose median is behind a ridge does not see, even
  when one of its units would.
- The coalition filter still fails both ways, with group keys.

## What was decided while doing it

Two things the ticket did not foresee, both found by reading the wiring rather than the handlers:

1. **`spotterLatches` is now partitioned by coalition**, not merely filtered by it. `onUnitLost`
   carries a **unit** name on purpose (the group name is unreliable at death time), so it can no
   longer key a latch — and the replacement, *release the latches of a spotter group that has gone*,
   cannot be correct without knowing which side a latch belongs to. A group that no longer exists
   cannot be asked its coalition. The surgical filter was right for a savepoint; the partition is the
   structural fix, and the filter's two-way test survives as a regression guard on the new shape.
2. **`forgetSpotter` is gone**, with its call in `onUnitLost`. Under the group model losing one truck
   must not release the convoy's contact, so nothing in production called it any more and it would
   have been dead code kept alive by a test. Its test is re-expressed on the real path
   (`test_a_latch_released_because_its_spotter_went_re_arms`), and
   `test_a_lost_unit_forgets_what_it_was_watching` is **inverted** into
   `test_a_lost_unit_does_not_release_its_groups_contact` — which is the assertion that pins the
   model. `onUnitLost` still writes the `lostUnits` ledger the vanished-sites sweep reads.

**A contact stays a unit**, deliberately: the cross on the map marks one aircraft and a flight of
four is four aircraft. Only the network's own nodes became groups.

## Definition of done

- [x] `listSpotters` returns groups; detection, latches and forgetting are keyed by group.
- [x] The coalition filter preserved — as a partition, with its two-way control kept.
- [x] An 11-unit group latches **once** and raises **one** alert.
- [x] A group loses a vehicle: the latch survives and is not re-reported. It loses its last: the
      latch goes.
- [x] The line-of-sight ray is traced from the median — one ray per group, not one per vehicle,
      asserted by capturing the point it is traced from.
- [x] `poetry run test-lua` green (49 suites), `stylua` clean.
