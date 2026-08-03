# 06 — F-14B(U), from Heatblur's official manual

**Status:** 🧑 waiting-human — written and resolved; David has to fly it.

The F-14B(U) has no usable ED autostart, and David's Chuck's Guide covers the 2023 F-14B, not this
variant. **Heatblur publishes the official manual as HTML**, and it is already in the right shape:

- <https://f14.manuals.heatblur.se/f14bu/procedures/checklists/startup.html> — Startup, pilot and RIO
- alongside Pre Start, Post Start, Quick Start CV and Quick Start Field, each in both seats

Read on 2026-08-02; the steps are control/position pairs:

```
AIR SOURCE switch — Set to OFF
ENG CRANK switch — Set to R (Right engine)
Right throttle — Advance to IDLE at 20% RPM
R GEN caution light — Turns off at ~59% RPM
```

Which maps onto the instructor format almost line for line: the left side is `control`, the right
side is the position, and a step like the last one — a light coming on by itself — is a `confirm`.

## What to be careful about

- **Take the procedure, not the prose.** The sequence and the positions are technical facts about the
  aircraft; Heatblur's sentences are theirs. Labels get rewritten in our own words, FR and EN, and
  the manual is cited as the source rather than quoted.
- The manual has a **pilot** and a **RIO** checklist. Start with the pilot one; the RIO's is a second
  checklist, not extra steps in the same one.
- Two seats and two engines mean controls that exist twice (`Right throttle`, `Left throttle`) and
  hints differing by one word. That is exactly where ticket 03's near-tie refusal earns its keep.
- The engine boxes **one** element per step. A step naming a control that exists per-engine has to
  pick a side, or be split.

## What it took, beyond reading the manual

Three things had to be built before a single step could resolve, none of them foreseen here:

1. **The F-14B(U) needed its own index.** Its `clickabledata.lua` points at the F-14B's, so the
   generator now separates *whose cockpit* from *whose bindings* — and it turned out to need both:
   the F-14B(U)'s own Input folders are stubs that pull the F-14B's profiles in, giving 4 valued
   positions read alone against 87 read as a pair.
2. **The unit catalogue does not know this aircraft.** It is generated from a datamine at a pinned
   revision, and the F-14B(U) is newer. A checklist naming `F-14BU` was rejected outright — the wrong
   answer for the aircraft somebody just bought. A committed cockpit index now counts as proof an
   aircraft exists, alongside the catalogue.
3. **The manual's vocabulary is not the cockpit's.** It says the transfer pump goes to *OFF*; the
   switch is labelled *SHUTOFF*. The resolver refused, listing the positions the control actually has
   — which is exactly the refusal earning its keep, and the file records the cockpit's word.

What the aircraft turned out to allow: the two transfer-pump steps and the two engine-crank steps are
**checked** (`Engine Crank` runs Right −1 / Left +1); the throttles are axes and the air-source
selector is five separate buttons, so those steps are pilot-confirmed.

## Definition of done

- [x] Pilot startup checklist for the F-14B(U), written the instructor way and resolved.
- [x] Its source recorded in the file: the manual URL and the date it was read, with the labels
      written in our own words rather than Heatblur's.
- [ ] **Verified in game** — needs a running DCS, so it waits for David.
- [ ] David flies it and says whether it matches what he does.
