# FEAT-DCS-SMOKE-HARNESS — assert VEAF behaviour inside a real DCS, unattended

Status: ⬜ ready

Origin: [`docs/exploration/DCS-SMS-EXPLOIT.md`](../../docs/exploration/DCS-SMS-EXPLOIT.md) §2.

## Problem

`poetry run test-lua` asserts against `test/lua/dcs_mocks.lua` — a DCS we wrote ourselves. It can
only confirm what we already believed. Everything it cannot reach ends up waiting for a human to fly
it, and that queue is currently four items long:

| Blocked on someone flying it | Where |
|---|---|
| Does `Disposition.getSimpleZones` avoid buildings and forests at all? | `FEAT-SCENERY-AWARE-SPAWN` ticket 01, 🧑 |
| Does DCS accept a coalition-scoped submenu under a global parent? | `FEAT-COMBATZONE-MENU-COALITION`, 🧑 since July |
| Does flattening Foothold's staggered script loading break AIEN/CTLD? | `FEAT-CUSTOM-SCRIPT-LOAD-DELAY`'s open question |
| Do the guided checklists work? | `FEAT-ASSIST-CHECKLISTS` — validated **by hand, in flight** |

That last one is the tell: a whole lot was signed off by a person sitting in a cockpit, which is
exactly what a harness automates. And the local situation is worse than it looks — since
`FIX-LUA-RUNNER-VERSION-CHECK`, `test-lua` **refuses to run on David's machine** (no Lua 5.1), so CI
is the only gate there at all.

## What makes it possible, and it is measured

[`DCS-HOOK-ENVIRONMENT-BOUNDARIES.md`](../../docs/exploration/DCS-HOOK-ENVIRONMENT-BOUNDARIES.md)
measured that `onSimulationFrame` fires at ~28 Hz **with no mission loaded** — 2 305 ticks before any
mission existed, verified end to end with `dcs-fiddle-server.lua` answering at the main menu. That
refutes what `dcs-sms` states as established fact about six comparable tools.

Consequence: a hook keeps polling with DCS sitting at the menu, so a script can **launch DCS, tell it
to load the test mission, assert through the bridge, and quit** — no human in the loop.

The pieces already exist: `dcs-fiddle-server.lua` as a `Scripts/Hooks` hook on `127.0.0.1:12081`, and
`veaf-tools inject-bridge` / `capture-map`, which already do exactly this kind of runtime
interrogation — that is how the airbase dumps for seven theatres were collected. **The missing piece
is not capability, it is the harness**: something that drives DCS's lifecycle and turns answers into
pass/fail.

## The constraint that shapes everything: this can never run in CI

GitHub runners have no DCS, no licence, and no GPU. So this is **not** a CI gate and must not be
sold as one. It is a local, opt-in tool run by whoever has a DCS install — which in practice means
David, or anyone doing the map-capture kit's job.

That is not a weakness, it is a scoping decision with consequences: no flaky-CI risk, no secrets, and
it must degrade to a clear "no DCS found, skipped" rather than a failure when run anywhere else.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [The test mission, and its documented contract](tickets/01-test-mission-contract.md) | ⬜ |
| 02 | [The runner: launch, load, assert, quit](tickets/02-runner.md) | ⬜ |
| 03 | [Port the four pending in-game checks](tickets/03-port-pending-checks.md) | ⬜ |

## Steal their test-mission contract, especially the counter-example

Their repo documents *which* mission to use and *why*: theatre **Syria**, anchor
**`(-32220, 405386)`** — "empty desert, far from anything, but DCS does process events there".

The valuable half is the counter-example: at `(-50000, -50000)`, over open water, **DCS silently
drops death events**. A harness that spawns its test units somewhere convenient and empty would watch
kills fail to register and conclude the code is broken. That is a day lost to a non-bug, and it is not
deducible — you have to hit it, or be told.

## Out of scope

- Replacing `test-lua`. The mocks stay: they are fast, they run everywhere, and they pin the
  fallback paths. This harness covers what only a real DCS exhibits.
- Testing the Mission Editor. Rejected — [ADR 0017](../../docs/adr/0017-no-live-mission-editor-bridge.md).
- Multiplayer / dedicated-server scenarios. Single local instance first.

## Definition of Done

- One command runs the whole thing unattended and exits non-zero on a failed assertion.
- Run with no DCS present, it **skips with an explanation** rather than failing.
- At least one of the four pending checks above is answered by it, not by a person — otherwise this
  lot has produced a framework and no evidence.
- The test-mission contract is documented with its *why*, including the open-water event-dropping
  trap, so the next person does not relocate the mission and lose a day.
