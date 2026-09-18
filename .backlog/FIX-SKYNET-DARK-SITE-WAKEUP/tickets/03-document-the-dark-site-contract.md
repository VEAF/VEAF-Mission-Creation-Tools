# 03 — Document what a network SAM does and does not see

Status: 🧑 waiting-human

> **Blocked: do not implement.** This ticket waits on David's conversation with **Flogas**
> and the historical IADS developers — see the [PRD](../PRD.md). No code, no branch, no PR
> before the decisions listed there are settled.

## Problem

`doc/mission-maker/scripts/veafSkynetIadsHelper.md` explains what an IADS is for — sites stay dark
to survive, EWRs feed them contacts — and never states the consequence a mission maker actually
trips over:

> a site under network control has its radar switched off, so it cannot notice an aircraft above it;
> if no EWR sees the intruder, no SAM reacts, whatever the distance.

Nor does it say the corollary: destroying the EWRs makes the remaining sites *more* aggressive,
because they revert to the DCS AI. Both are surprising, both are correct, and both were reported as
bugs by a mission maker on 2026-09-17.

The `ewr` spawn option — the one lever that gives a site permanent watch duty — is documented
nowhere on the mission-maker side.

## What to write

In `veafSkynetIadsHelper.md` and its `.en.md` twin, keeping anchors identical across languages:

1. A short section on the two conditions for a site to light up, and the fact that proximity is
   not one of them by itself before the setting from ticket 01.
2. The EWR-loss inversion, stated as expected behaviour rather than left to be discovered.
3. The `ewr` spawn option: what a watch site is, what it costs (it is visible and targetable), and
   the advice to sacrifice a short-range battery rather than the system being protected.
4. The new proximity setting from ticket 01, once its name is fixed.
5. How to diagnose: `debug_red: true`, then the three readings of the status page — EWR with no
   contacts, EWR with contacts but the site still `ACTIVE: false`, or site already `AUTONOMOUS`.

## Definition of done

- Both language files updated, both in the `nav`, anchors identical.
- `poetry run docs-check` green.
