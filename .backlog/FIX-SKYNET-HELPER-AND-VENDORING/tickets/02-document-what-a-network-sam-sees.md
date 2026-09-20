# 02 — Document what a network SAM does and does not see

Status: ⬜ ready

## Problem

`doc/mission-maker/scripts/veafSkynetIadsHelper.md` explains what an IADS is for — sites stay dark
to survive, EWRs feed them contacts — and never states the consequence a mission maker actually
trips over:

> a site under network control has its radar switched off, so it cannot notice an aircraft above it;
> if no EWR sees the intruder, no SAM reacts, whatever the distance.

Nor does it say the corollary: destroying the EWRs makes the remaining sites *more* aggressive,
because they revert to the DCS AI. Both are surprising, both are correct, and both were reported as
bugs on 2026-09-17.

Two more things the page never says, both surfaced by that investigation:

- **"Covered" does not mean "informed".** Coverage is a flat 2D distance between the EWR's radar and
  the battery's, compared against the EWR's detection range — no horizon, no terrain, no altitude.
  It means the EWR is *near* the battery, never that it is feeding it. One 55G6 listed 18 batteries
  under its coverage in the reported log.
- **Joining the network depends on how the group arrived**: Mission Editor → yes; combat zone →
  yes, whatever `dynamic_spawn` says; VEAF spawn command → only if the command carries `skynet`;
  third-party script → only when `dynamic_spawn` is on. Two identical batteries behave in opposite
  ways depending on their origin.

The `ewr` spawn option — the one lever that gives a site permanent watch duty — is documented
nowhere on the mission-maker side.

## What to write

In `veafSkynetIadsHelper.md` and its `.en.md` twin, keeping anchors identical across languages:

1. The two conditions for a site to light up, and the fact that proximity alone is not one of them
   beyond the last-line-of-defense radius added on the Skynet side.
2. The last line of defense itself: a dark site keeps a short virtual detection radius of its own
   (10–15 km, drawn once per site), measured flat, and stays lit 45 s after the last pass. How to
   switch it off for a mission that wants a purist IADS, and the honest limit — a short-range piece
   can light up for an aircraft it cannot reach, because the radius ignores the firing envelope on
   purpose.
3. The EWR-loss inversion, stated as expected behaviour rather than left to be discovered.
4. What "covered" really means, so nobody reads the status page as "this battery is being watched".
5. The `ewr` spawn option: what a watch site is, what it costs (visible and targetable), and the
   advice to sacrifice a short-range battery rather than the system being protected.
6. A table of the four ways a group joins a network, per the list above.
7. The new `mission.yaml` keys, with their defaults, and the note that they are global to both
   coalitions while `dynamic_spawn` is per network.
8. How to diagnose: `debug_red: true`, then the three readings of the status page — EWR with no
   contacts, EWR with contacts but the site still `ACTIVE: false`, or site already `AUTONOMOUS`.

## Definition of done

- Both language files updated, both in the `nav`, anchors identical.
- `poetry run docs-check` green.
