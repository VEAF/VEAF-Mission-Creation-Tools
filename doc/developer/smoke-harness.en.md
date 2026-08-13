# Smoke harness — assert VEAF inside a real DCS

`poetry run test-lua` runs against `test/lua/dcs_mocks.lua`, a DCS **we wrote ourselves**. It can only
confirm what we already believed. Everything beyond it was ending up in a queue: somebody had to fly.

This harness runs assertions **inside a running DCS**, with nobody watching.

## What it will never be

**A CI gate.** GitHub runners have no DCS, no licence and no GPU. It is a **local** tool, run by
whoever has an install. It **skips** with an explanation rather than failing when there is nothing to
talk to — otherwise it would be red on every machine and nobody would run it.

## Prerequisites

1. **DCS running.** The main menu is enough: `onSimulationFrame` fires at ~28 Hz **with no mission
   loaded** — 2,305 ticks measured before any mission existed (see
   [DCS-HOOK-ENVIRONMENT-BOUNDARIES](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/exploration/DCS-HOOK-ENVIRONMENT-BOUNDARIES.md)).
   That measurement is what makes unattended driving possible at all.
2. **The hook installed**: copy `src/scripts/other/dcs-fiddle-server.lua` into
   `Saved Games/DCS/Scripts/Hooks/`. It listens on `127.0.0.1:12081`.

   !!! danger "This hook is an open remote-code-execution port. Remove it when you are done."

       It runs any Lua it is sent, with no token and no origin check, and it answers with
       `Access-Control-Allow-Origin: *`. The command channel is a `GET`, and a browser sends a
       cross-origin `GET` without asking first — so **any web page you visit while the hook is
       installed can run code in your DCS**, and read what it returns. Binding to `127.0.0.1` does
       not help: your browser is on `127.0.0.1` too.

       Install it to run the harness, take it out afterwards, and **never put it on a server**. See
       [ADR 0019](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0019-dcs-fiddle-server-stays-unauthenticated-for-now.md) for why it
       is still like this and what replaces it.

3. **`net.dostring_in` available** — it is the only path into the mission environment, so without it no
   assertion can run at all. **Nothing to configure: measured present on a stock install**
   (2026-08-06), with `autoexec.cfg` listing neither `net.allow_unsafe_api` nor
   `net.allow_dostring_in`. ED's documentation implies otherwise; see the section on that documentation
   below. Should it ever be missing, the harness names it precisely instead of blaming the mission.

4. **A mission loaded** for the assertions — the mission environment does not exist before that.

## Usage

```
veaf-tools dcs smoke-test --probe-only
```

Runs no assertions: reports only **what this DCS allows**. Run it first — the same discipline as the
`Disposition` probe, measure before building on top.

What it measures, in one round trip: which control table answers (`Sim`, `DCS`, or both), whether
`exitProcess` / `stopMission` / `setUserCallbacks` are there, whether `net.load_mission` exists **and**
whether this instance calls itself a server, whether `net.dostring_in` is permitted, and — the thing
only the running process knows — **which install and which `Saved Games` folder this instance is
using**.

It closes with **the one thing to fix first**, and the order matters: "no hook", then "no permission",
then "no mission". The previous version reported the missing permission as "no mission loaded", which
sent the reader looking for a mission to load where loading one could not have helped.

```
veaf-tools dcs smoke-test
```

Probes, then runs the checks. Exits 1 if any fails, 0 if all pass **or the run was skipped**.

## How it talks to DCS

One transport, the hook's, read out of `dcs-fiddle-server.lua` rather than assumed: the Lua travels
**base64 in the URL path**, the target environment in `?env=`, and the reply is JSON `{result=…}` or
`{error=…}`.

| `?env=` | What it reaches | What it is for |
|---|---|---|
| `default` | the hook's own environment, via `loadstring` | the only one holding `net.*` — so, driving |
| `mission` | the **trigger** state, via `net.dostring_in` | where `a_do_script` and the `a_*` actions live |

!!! warning "`env=mission` is not where the VEAF scripts live"

    That was the first slice's assumption and it is wrong — **measured 2026-08-06**, with a mission
    loaded and a pilot in the cockpit: a chunk sent there returns
    `:1: attempt to index global 'env' (a nil value)`. The chunk **ran** — that is a Lua runtime error
    from inside the target state, not a refusal — so that state simply has no `env`. It is the
    **trigger** state.

    This repository had already established it without drawing the consequence: `FEAT-ASSIST-CHECKLISTS`
    ticket 01 located `a_cockpit_highlight` "one `net.dostring_in` away". And the hook says it in one
    line, in its own bootstrap: `net.dostring_in("mission", 'a_do_script("dofile(…)")')` — it reaches the
    scripting state **through** `a_do_script`, not directly.

    So the six checks in the first slice were aimed one state short. They now go through a **measured
    route**, which the probe discovers by trying `a_do_script` (the path ED documents as current, and
    which returns its values directly) then `net.dostring_in("scripting", …)`. The route test is
    `return type(env)` and the answer must **be** `table`: a route that runs the chunk somewhere else
    returns a Lua error, which this transport hands back as an ordinary string — "something came back"
    proves nothing.

This is **not** the bridge `capture-map` uses (`dcs-serve` + `dcs-bridge.lua`): that one lives *inside*
the mission, so it cannot answer before the mission exists, and cannot be what loads it.

## The test-mission contract

Borrowed from [nielsvaes/dcs-sms](https://github.com/nielsvaes/dcs-sms), and the **counter-example** is
the part worth having:

- Theatre **Syria**, anchor **`(-32220, 405386)`** — "empty desert, far from anything, but DCS does
  process events there".
- At **`(-50000, -50000)`**, over open water, **DCS silently drops death events.**

A harness that put its test units "somewhere empty" would watch kills fail to register and conclude the
code was broken. That is a day lost to a non-bug, and it is not deducible.

> ⚠️ **These coordinates are not verified here yet.** They come from their repository, and this
> repository has already found **two** claims in their documentation to be false (the hook and editor
> sharing a Lua VM, and the "it dies at the main menu" claim). Killing a unit at that anchor and
> watching the event arrive is part of the lot's ticket 01.

## Adding a check

Assertions are **data**, not code: an entry in `CHECKS` (`veaf_libs/dcs_smoke.py`) with a name, a Lua
snippet, what its result must be, and **why we want to know**. A check whose purpose nobody wrote down
is a check nobody dares delete.

### The rule: your Lua must return a **string**. Always.

Measured 2026-08-06 in a mission, and everything else follows from it:

| The Lua returns | Python receives |
|---|---|
| `'x'` | `'x'` |
| `3` | `'3'` — a **string** |
| `true` | `''` — **destroyed** |
| `{1, 2}` | `''` — **destroyed** |

A boolean and a table are therefore indistinguishable from each other *and* from a chunk that returned
nothing. Two of the six original checks died of it: one expected a number, the other `True` — and the
second was worse than unpassable, it was **silent on the one question it existed to settle**.

Practical corollary: **tag** numeric values (`count:10`, not `10`), so that "asked, and there is nothing"
(`count:0`) stays distinct from "the answer was destroyed" (`''`). A test sweeps every check against `''`:
an expectation that `''` satisfies is an expectation that cannot tell success from a lost value.

One trap worth knowing: the snippets return **sentinels** (`veaf-absent`, `no-singleton`,
`not-a-table`, `raised: …`) instead of raising, so a missing prerequisite stays legible. Those are
**non-empty, therefore truthy** strings — an expectation written as a plain truthiness test passes in
exactly the case it was meant to catch. That happened while writing this; a test now sweeps every check
against every sentinel.

## The source that settles it: ED's own documentation, shipped with DCS

`<DCS install>/API/Sim_ControlAPI.md` documents the hook API. **Read it before adding a call here**:
three of its statements contradict what this module originally assumed.

| What was assumed | What ED documents | Consequence |
|---|---|---|
| the control table is `DCS.*` | it is `Sim.*` | **measured: `Sim` and `DCS` are the *same table*** — either name works, but the probe reports it instead of assuming one |
| `net.load_mission` loads a mission | `net.load_mission` is **SERVER ONLY** | measured: `isServer=true` in single-player, so the call is legitimate on a local instance |
| `net.dostring_in` is available | **OBSOLETE and UNSAFE**, gated behind `autoexec.cfg` | **the restriction does not hold as written**: measured present with neither key set. The harness therefore checks for the *function*, not for the config |

And one thing no documentation states: **the transport lies about failure.**
`net.dostring_in(state, string)` returns a Lua error **as its result**, with HTTP 200 and a `{result=…}`
body — so a failure in the mission environment is shaped exactly like a successful answer. Measured at
the main menu: `return env.mission.theatre` came back as `:1: attempt to index global 'env' (a nil
value)`, and the probe concluded "mission environment answered". That is the **third** time this lot has
been caught by a truthy failure — the sentinels, the submenu check returning a constant, and this. In
this transport, "it came back" is not "it worked".

Two more useful things are documented there and not yet used:
`onMissionLoadBegin` / `onMissionLoadProgress(progress, message)` / `onMissionLoadEnd` — an **event**
signal that a load has finished, far better than watching a frame counter that freezes during the load;
and `Sim.getLogHistory(from)`, which makes `dcs.log` readable through the hook instead of parsed off
disk.

## What is still missing

The [`FEAT-DCS-SMOKE-HARNESS`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/.backlog/FEAT-DCS-SMOKE-HARNESS/PRD.md) lot carries the detail.
In short: DCS has to be started **by hand** for now. Launching and quitting it automatically needs DCS
calls this repository has never made — `--probe-only` reports whether they are available, which gives
whoever picks it up facts instead of guesses.
