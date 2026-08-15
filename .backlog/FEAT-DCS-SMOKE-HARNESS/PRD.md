# FEAT-DCS-SMOKE-HARNESS — assert VEAF behaviour inside a real DCS, unattended

Status: 🔄 in-progress

> **First slice delivered 2026-08-05, and it stops short of the lot's own Definition of Done.**
> The transport, the probe, the data-driven check runner and the documented contract are in. What is
> **not** in is any evidence: no DCS was available on the machine that wrote this — no install, no
> `Saved Games` — so not one check has actually run. By this lot's own DoD ("at least one of the four
> pending checks is answered by it, not by a person") that means a framework and no evidence, which is
> exactly the failure mode ticket 03 was written to prevent. The next step is one command on a machine
> with DCS: `veaf-tools smoke-test --probe-only`.
>
> Two things were also deliberately cut from this slice, not forgotten: **launching and quitting DCS**
> (the DCS-side calls have never been made here, so the probe reports whether they exist rather than
> code being written blind against them), and **the committed test mission** (the contract is written,
> the artefact is not).
>
> **2026-08-06, on the machine that has DCS**: the probe was enriched instead of the lifecycle being
> written, because **ED's own API documentation ships with DCS** — `<install>/API/Sim_ControlAPI.md` —
> and had never been opened. It contradicts three of this lot's assumptions: the control table is
> `Sim.*` and not `DCS.*`, `net.load_mission` is **SERVER ONLY**, and `net.dostring_in` — the only
> transport every assertion uses — is **obsolete and gated behind `autoexec.cfg`**, which David's
> install does not enable. So the six checks may have had no transport at all, and the probe would have
> blamed a missing mission. Details and the resulting decision — "the decision step 4 now needs" — in
> [ticket 02](tickets/02-runner.md). No anchor on purpose: the gate does not validate anchors outside
> `doc/`, so linking one would be a link nothing here can check. Nothing was launched either: starting
> DCS is David's to do on his own session.
>
> **The evidence clause of the Definition of Done is met.** Two of the four pending checks are now
> answered **by the harness and not by a person**: `Disposition` exists and `getSimpleZones` returns
> points (`FEAT-SCENERY-AWARE-SPAWN` ticket 01, the singleton half), and **DCS accepts a coalition-scoped
> submenu under a global parent** — which closes `FEAT-COMBATZONE-MENU-COALITION`, open since July. So this
> lot is no longer "a framework and no evidence". Getting there took four runs and cost three of the
> harness's own defects, every one of them a variant of the same mistake — *in this transport, "it came
> back" is not "it worked"*: a Lua error returned as a successful string, six checks aimed at the trigger
> state instead of the scripting state, and booleans and tables arriving as `''`. All three were invisible
> to the mocks by construction, which is the argument for this lot existing.

Origin: [`docs/exploration/DCS-SMS-EXPLOIT.md`](../../docs/exploration/DCS-SMS-EXPLOIT.md) §2.

## Problem

`poetry run test-lua` asserts against `test/lua/dcs_mocks.lua` — a DCS we wrote ourselves. It can
only confirm what we already believed. Everything it cannot reach ends up waiting for a human to fly
it, and that queue is currently four items long:

| Blocked on someone flying it | Where |
|---|---|
| Does `Disposition.getSimpleZones` avoid buildings and forests at all? | `FEAT-SCENERY-AWARE-SPAWN` ticket 01 — **the singleton is measured to exist and return points**; the *avoidance* still needs a mission next to a village |
| ~~Does DCS accept a coalition-scoped submenu under a global parent?~~ **answered: yes, 2026-08-06** | `FEAT-COMBATZONE-MENU-COALITION`, now ✅ |
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
| 01 | [The test mission, and its documented contract](tickets/01-test-mission-contract.md) — contract written, mission artefact and the in-game anchor check outstanding | 🔄 |
| 02 | [The runner](tickets/02-runner.md) — probe, transport, data-driven checks **and** the launch/load/quit lifecycle (`--full`) written 2026-08-15; one in-game run left to confirm the DCS calls | 🧑 |
| 03 | [Port the four pending in-game checks](tickets/03-port-pending-checks.md) — six checks written for two of the four questions; **none has run** | 🔄 |
| 04 | [Assert VEAF through the mission bridge, not the hook](tickets/04-assert-through-the-mission-bridge.md) — transport split shipped; sentinel fixed | ✅ |

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
