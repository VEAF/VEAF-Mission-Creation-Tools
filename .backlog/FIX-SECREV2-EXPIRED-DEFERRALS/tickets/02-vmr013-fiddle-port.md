# 02 — The fiddle-server port: re-anchor the deferral or close it

Status: 🧑 waiting-human
Type: chore
Finding: VMR-013 (Security flaw, **MEDIUM**), `src/scripts/other/dcs-fiddle-server.lua:270`

## The finding, and why its own severity understates it

`dcs-fiddle-server` **executes arbitrary Lua from unauthenticated HTTP requests**. No token, no origin
check. [ADR 0019](../../../docs/adr/0019-dcs-fiddle-server-stays-unauthenticated-for-now.md) accepted
that, for now, with reasons.

The triage entry adds something the review did not say, and it is the part to carry forward:

> *Severity is understated in the review: `cors='*'` plus a GET channel means **any web page visited
> while the hook is installed gets code execution**, so "loopback only" is not the protection it sounds
> like.*

That is the sentence to re-read before deciding this can wait again.

## Why it was deferred, and what has changed

Deferred because *"no DCS is available to test a change to the transport `FEAT-DCS-SMOKE-HARNESS` speaks
through, and shipping untested auth there breaks the harness invisibly."* Two things did ship instead: a
danger warning in the harness documentation, at the point where it tells you to install the hook, and
**the token design, written down in ADR 0019 to be implemented with the harness's remaining slice, where
it can be tested.**

What changed by 2026-08-11: the harness **has** run in a live DCS. What did *not* change: its ticket 04
(*"Assert VEAF through the mission bridge, not the hook"*) explicitly **keeps the hook** for driving DCS —
locate, launch, load, quit — and only moves the `veaf-*` assertions to the mission bridge. So the
dependency is real and still live.

## This ticket's first job is to decide whether it should exist

Three possible outcomes, and picking one is the work:

1. **Fold it into `FEAT-DCS-SMOKE-HARNESS` ticket 04** and delete this ticket. The token was designed to
   land with that slice; if ticket 04 is the slice, this is a duplicate and the honest fix is a paragraph
   there rather than a lot here.
2. **Implement the token now**, if the harness can be exercised in a DCS session — ADR 0019 says the
   design is ready and only the testing was missing.
3. **Re-anchor the deferral to a condition that can actually expire**, if neither is possible today.
   *"When the harness's remaining slice ships"* is such a condition; *"when a DCS is available"* is not,
   because nothing announces it.

Outcome 1 is the most likely and the cheapest. What must **not** happen is a fourth deferral with no
named collector — that is how this finding became invisible for a month in the first place.

## Tasks

- [ ] Read ADR 0019's token design and check it against what ticket 04 actually changes.
- [ ] Pick outcome 1, 2 or 3 and write the reason here.
- [ ] Whichever way: make sure exactly **one** place names the condition, and that a closing lot trips
      over it. The triage entry alone was not enough — this ticket exists because it was not read.

## Blocked on

David: a DCS session, or the call on outcome 1 versus 3.
