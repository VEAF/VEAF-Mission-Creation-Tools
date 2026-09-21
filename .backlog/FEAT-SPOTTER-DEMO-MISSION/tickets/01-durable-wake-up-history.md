# 01 — A durable wake-up history, and a drain that only drains what it printed

Status: ✅ done

## The defect

`veafSkynet.spotterStatusWakeUps` is the only structure that names the spotter relay as the cause of
a site going live. It was wiped by two assignments at the end of `spotterStatusPage()` — placed
**outside** the `if debugFlag` test, so they ran on every cycle whether or not anything had printed.

Three consequences, in order of what they cost:

1. **No trace survives.** *"Did the spotter network wake anything on the server last night?"* had no
   answer and could not have one: the record lived thirty seconds at most.
2. **A mission with debug off filled two tables every cycle and threw them away**, unread.
3. **One coalition's page wiped the other's records.** A mission running red in debug and blue not
   lost blue's records on red's page, so switching blue's debug on later showed an empty first page —
   which reads as *nothing happened*, the one answer a diagnostic page must never give by accident.

## What was done

- **`veafSkynet.spotterWakeUpLog`** — per coalition, oldest first, never drained, capped at
  `SpotterWakeUpLogSize` (200) with the oldest dropped. An **array**, not a set: the page dedupes
  because the same contact is re-reported every 5 s, but a history collapsing two wake-ups two hours
  apart into one line is not a history.
- **`veafSkynet.getSpotterWakeUpLog(coa)`** to read it.
- The drain is now **per coalition, inside the branch that printed it**.
- The page buckets are only **filled** for a coalition that will print them
  (`_coalitionPrintsStatusPage`). Without that, the fix above would let them grow for the whole
  mission on a mission with debug off, since the page is the only thing that empties them.

The history is deliberately **not** behind that test: it is capped, and it is what answers the
question after the fact, when nobody thought to switch debug on beforehand.

## Definition of done

- [x] The history survives a page that drains the bucket — asserted, with the bucket checked empty in
      the same test so it cannot pass because nothing drains at all.
- [x] It is recorded with debug off, and the bucket is not.
- [x] Repeats are kept, the cap drops the oldest, coalitions do not read each other's.
- [x] A coalition that was not printed keeps its records.
- [x] `poetry run test-lua` green.
