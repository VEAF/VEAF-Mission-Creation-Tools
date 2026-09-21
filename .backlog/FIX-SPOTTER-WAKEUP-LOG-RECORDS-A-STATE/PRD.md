# FIX-SPOTTER-WAKEUP-LOG-RECORDS-A-STATE — the wake-up history re-writes the same wake-up every 5 s

Status: ✅ done

Found on 2026-09-21 while reading the spotter network's own durable history in game, during the
visual validation of `FEAT-SPOTTER-DEMO-MISSION`.

## The measurement

Read out of a live mission holding **one** static contact:

```
{ at=81,  line=SamCentre <- VisualTarget-1 }
{ at=81,  line=SamNorth  <- VisualTarget-1 }
{ at=86,  line=SamCentre <- VisualTarget-1 }
{ at=86,  line=SamNorth  <- VisualTarget-1 }
{ at=91,  line=SamCentre <- VisualTarget-1 }
…
```

**117 entries for a single aircraft that had not moved**, two per hand-over pass, one pass every five
seconds — about **24 lines a minute, for ever**, as long as the contact is held.

### And the history is capped, which turns noise into loss

`veafSkynet.SpotterWakeUpLogSize` is **200 entries per coalition**, and the oldest go first — a
deliberate choice, since an unbounded table is how a Lua state runs a four-hour server out of memory.

Put the two together: at ~24 lines a minute, **one held contact overwrites the entire history in
about eight minutes**. So the durable log does not answer *what did the network wake last night*; it
answers *what did it wake in the last eight minutes*, and only if nothing was being held. That is
the question it was written for, and it cannot answer it.

## Why it matters, and it is not cosmetic

This history exists because of a question `FEAT-SPOTTER-NETWORK` could not answer: *"did the spotter
network wake anything on the server last night?"* The original defect was that the only trace lived
for at most thirty seconds, drained on every status cycle. Ticket 01 of that lot made it durable.

Durable and **useless in the same way**, for the opposite reason: asked the same question after an
evening's flying, the answer is thousands of identical lines. A log drowned at 95 % noise is a log
nobody reads, which is the state the feature was meant to leave behind. This repository has the
measurement for that already — a journal written too finely produced 124 lines a minute where its own
comment claimed "a few hundred per sortie".

## The cause

`handOverSpotterAlerts` records a wake-up whenever it hands a contact to a site whose envelope the
aircraft is in — every pass, whether or not anything changed. It records a **state**, not an
**event**.

Two things to be careful about while fixing it:

- **A re-wake is a real event.** A site that goes dark and is woken again by the same aircraft has to
  produce a second line: collapsing on "site + aircraft" alone would hide exactly the flapping this
  history is the only witness to.
- **The site's own state cannot attribute the wake-up** — that is why the history exists at all. So
  the transition has to be read from what the hand-over knew at the previous pass, not from asking the
  site whether it is live.

## Where the code is

All in `src/scripts/veaf/veafSkynetIadsHelper.lua`:

| | |
|---|---|
| `veafSkynet.recordSpotterWakeUp(coa, line)` | writes both the status-page bucket and the durable log |
| `veafSkynet.spotterWakeUpLog` | the durable history, `{ at, line }` per entry, per coalition |
| `veafSkynet.SpotterWakeUpLogSize` | the 200-entry cap, oldest dropped first |
| `veafSkynet.handOverSpotterAlerts` | the caller — records on every pass, which is the defect |
| `veafSkynet.getSpotterWakeUpLog(coa)` | the reader |

Tests: `test/lua/test_veafSkynetIadsHelper_spotter.lua`, class **`TestSpotterWakeUpHistory`** — extend
it rather than starting a new one. The hand-over's own suite is `TestSpotterHandover`, and its fixture
already stands up a Skynet site double, which is what a transition test needs.

Gates: `poetry run test-lua`, then `stylua --check src/scripts/veaf/ test/lua/`.

## What to do

Record only the **transition**: this site did not already hold this aircraft at the previous pass. A
static contact then costs **one** line, a genuine re-wake costs a second, the cap stops being reached
by a quiet mission, and the answer to *what did the network wake last night* is a page a human can
read.

## Definition of done

- [x] A held static contact produces **one** wake-up line, not one per pass.
- [x] A site woken, released, and woken again by the same aircraft produces **two** — the test that
      stops the fix from being a plain de-duplication.
- [x] A quiet mission holding one contact no longer reaches the 200-entry cap — the number that
      makes this a loss of information and not a matter of tidiness.
- [x] `poetry run test-lua` green, `stylua` clean.

## What was built

`veafSkynet.spotterHandedOver` holds, per coalition and per site, the aircraft that site was handed
at the **previous** pass. `handOverSpotterAlerts` reads it before the loop and rewrites it after, and
records a wake-up only for an aircraft that was not in it. Skynet is still told on every pass — it
ages contacts out — and only the recording is gated; the per-pass `debug` line, which flooded the
same way through the other channel, went with it.

There are **three** ways a site is released and they take different branches, so all three clear the
memory: the aircraft leaves the envelope (nothing is reported, the rewritten set is empty), the site
stops holding anything at all (the early return before the envelope is ever asked), and — found in
review — the site's **DCS group is gone**, which has no group name to key on and returned before
reaching the memory at all. That last one is the one with teeth: a battery destroyed and respawned
under the same name, which is what a mission with combat zones does, read the still-held contact as
one it was already holding and wrote nothing, losing the single event the history exists for. It is
now forgotten under the Skynet site's own name, which is the group's. A release is stored as
*nothing* rather than an empty table, so being woken again later is a new event.

Two stale comments went with it, both teaching the behaviour this lot removes — that the hand-over
reports the same contact on every pass, and that the page's deduplication is what keeps the history
readable.

Five tests in `TestSpotterWakeUpHistory`, which now stands up the same Skynet site double as
`TestSpotterHandover` — a transition is only observable by running real hand-over passes. Twelve
passes on a held contact give one line while Skynet is told twelve times; an hour of passes (720)
still gives one and never approaches the cap; the three re-wake tests were each checked against the
code without its guard and **all three go red**, which is what stops the fix from being a
de-duplication.

Not covered here: the in-game re-reading. The measurement that opened this lot came from a live
mission, and the counterpart — a night of flying producing a history a human can read — needs DCS.
