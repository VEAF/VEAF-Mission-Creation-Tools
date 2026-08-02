# 06 — F-14B(U), from Heatblur's official manual

**Status:** ⬜ ready — depends on 03. Asked for by David, who flies it.

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

## Definition of done

- Pilot startup checklist for the F-14B(U), resolved and verified in game.
- Its source recorded in the file: the manual URL and the date it was read.
- David flies it and says whether it matches what he does.
