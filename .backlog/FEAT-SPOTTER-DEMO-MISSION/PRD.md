# FEAT-SPOTTER-DEMO-MISSION — a mission that proves the word travels

Status: 🔄 in-progress — tickets 01 to 04 done; ticket 05, the demonstration layer, is not started.

Origin: David, 2026-09-21, reading what `verify-mission-c` check 13 would have measured:

> *"l'idéal serait que tu fasses une mission de démo pour ça, avec dcs-bridge pour qu'on puisse
> tester avec"*

## Why check 13 could not answer its own question any more

`FEAT-SPOTTER-NETWORK` left exactly one debt: an in-game reading. It was written as check 13 of
`verify-mission-c`, and measuring that mission's contents showed the check had become
**indiscriminate** — killed by the lot that had just unblocked it.

| | Measured |
|---|---|
| red units able to spot in `verify-mission-c` | **two Ural-375 trucks**; the EWR and the three SA-6 are excluded from spotting by design |
| a truck's sight range | **3 km** |
| those trucks → nearest SA-6 | **8.9 km** |
| last-line-of-defence radius, shipped on by `FIX-SKYNET-HELPER-AND-VENDORING` | **10–15 km** |

Getting seen by a truck means flying within 3 km of it, hence 6–12 km from the battery — **inside its
own radius**. The battery would light up by itself and the `woke:` line would prove nothing.

## Two facts that killed the first two designs

Both read in the code rather than assumed, and both worth keeping: they are the reason the rig looks
the way it does.

1. **A battery with no EWR is not dark, it is permanently live.** A SAM site is built with
   `isAutonomous = true` and `AUTONOMOUS_STATE_DCS_AI` (`skynet-iads-compiled.lua:3014`), so with no
   parent radar it hands itself to the DCS AI and lights up. "No EWR, so the only way to wake is the
   relay" delivers the exact opposite: everything lit from the first second, control included.
2. **The site's own state cannot attribute the wake-up**, and the only thing that could —
   `spotterStatusWakeUps` — was **drained on every status cycle**, by a pair of assignments that sat
   *outside* the `if debugFlag` test. So the only trace that the feature had ever worked lived for at
   most thirty seconds, and reading it from outside raced the drain.

Fact 2 is a product defect before it is a testing problem: asked *"did the spotter network wake
anything on the server last night"*, nobody could answer. Ticket 01 fixes it, and the rig is then
trivial.

## Tickets

| # | Ticket | State |
|---|---|---|
| 01 | [A durable wake-up history, and a drain that only drains what it printed](tickets/01-durable-wake-up-history.md) | ✅ done |
| 02 | [The rig mission, and its geometry](tickets/02-the-rig-mission.md) | ✅ done |
| 03 | [An opt-in smoke suite that reads it](tickets/03-the-spotter-smoke-suite.md) | ✅ done |
| 04 | [Check 13 says it no longer discriminates, and points here](tickets/04-retire-check-13.md) | ✅ done |
| 05 | [The demonstration layer](tickets/05-the-demonstration-layer.md) | ⬜ ready |

David's sequencing, 2026-09-21: the discriminating rig first, then the demonstration; and within the
demonstration, bridge-driven before flyable.

## What the rig does not prove, said out loud

It proves **the report travelled and named the right battery**. It does not prove the battery went
*from dark to live because of it*: with no EWR the batteries are autonomous and already live, and the
hand-over records the wake-up all the same. Making a battery genuinely dark needs an EWR, and an EWR
that covers it may also be the one that informs it — so that half belongs to ticket 05 and to a human
reading the log, not to an automated check.

A rig whose limits are not written down is read as proving more than it does.

## Definition of done

- [x] A durable, attributed record of spotter wake-ups that the status page does not consume.
- [x] `test/veaf-tools/demo-spotter-network/` builds, validates, and ships the bridge.
- [x] `veaf-tools smoke-test --suite spotter` reads it, with a control that can fail.
- [x] `poetry run test-lua` and `poetry run pytest` green.
- [ ] The demonstration layer (ticket 05).
- [ ] The rig run once in DCS, and its reading recorded. **Needs DCS.**
