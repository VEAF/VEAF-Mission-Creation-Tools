# FIX-SPOTTER-WAKEUP-LOG-RECORDS-A-STATE — the wake-up history re-writes the same wake-up every 5 s

Status: ⬜ ready

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

## What to do

Record only the **transition**: this site did not already hold this aircraft handed over at the
previous pass. A static contact then costs **one** line, a genuine re-wake costs a second, and the
answer to *what did the network wake last night* is a page a human can read.

## Definition of done

- [ ] A held static contact produces **one** wake-up line, not one per pass.
- [ ] A site woken, released, and woken again by the same aircraft produces **two** — the test that
      stops the fix from being a plain de-duplication.
- [ ] `poetry run test-lua` green, `stylua` clean.
