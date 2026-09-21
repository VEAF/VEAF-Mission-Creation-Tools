# 02 — Detection and latches keyed by group

Status: ⬜ ready

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

## Definition of done

- [ ] `listSpotters` returns groups; detection, latches and forgetting are keyed by group.
- [ ] The coalition filter preserved, with its two-way control.
- [ ] `poetry run test-lua` green, `stylua` clean.
