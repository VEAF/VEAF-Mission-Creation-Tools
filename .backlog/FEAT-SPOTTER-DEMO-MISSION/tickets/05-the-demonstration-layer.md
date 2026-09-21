# 05 — The demonstration layer

Status: ⬜ ready

The rig answers the question; it is not something a human enjoys loading. David's sequencing on
2026-09-21 was the rig first, then this — and within this, bridge-driven before flyable.

## What it adds

- **The last line of defence back on**, shown on its own: a battery lighting up with no report and no
  EWR contact, which is the behaviour the rig deliberately switches off to stay discriminating.
- **A genuinely dark battery.** That needs an EWR covering it, and therefore an answer to the
  question this lot parked: an EWR that covers a battery may also be the one that informs it, so
  attributing the wake-up to the relay needs either terrain masking a human can verify in game, or a
  different discriminator.
- **The F10 map view** (`spotter_view: "radio"`), the per-coalition toggle, and the game-master case
  (#128).
- **A flyable approach** that makes the mechanism legible from the cockpit: a low run past the
  spotter, a battery ahead that had no way of seeing you.

## Open before starting

The EWR question above is a design decision, not typing. **Do not start by placing units.**

Worth re-reading first: `reportContact` does not check whether the site was already live, so a
battery lit by its EWR and then reported to by the relay records a wake-up the EWR earned. That is
the false positive the rig avoids by having no EWR at all, and the one this ticket has to solve
differently.
