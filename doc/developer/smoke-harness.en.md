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

   !!! danger "This hook runs Lua in your DCS. Remove it when you are done, never on a server."

       This hook is the **omltcat/dcs-lua-runner** fork with authentication. Since `FIX-SECREV2` it
       **requires a per-session password** (`FIDDLE.AUTH = true`, `BYPASS_LOCAL = false`): at each
       launch it draws a secret and writes it to `%USERPROFILE%\dcs-fiddle-token.txt`, then rejects any
       request without the matching Basic auth. The local bypass, which let a web page on loopback
       through via the (spoofable) Host header, is **off** — that is the vector
       [ADR 0019](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0019-dcs-fiddle-server-stays-unauthenticated-for-now.md)
       described, and it is closed.

       What is still true: **any local process that can read that file can run Lua in your DCS**.
       Install the hook to run the harness, take it out afterwards, and **never deploy it on a
       server**. (The upstream DCS Fiddle web UI, which relied on the local bypass, is no longer
       supported by this build.)

   The harness reads the same file automatically (username `veaf`). If your install writes the secret
   elsewhere (the hook's `os` function unavailable → fallback to the `writedir`), pass it with
   `--fiddle-token` or the `DCS_FIDDLE_TOKEN` variable.

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

Probes, then runs the checks. Exits 1 if any fails, 0 if all pass **or the run was skipped**. Assumes
DCS is already running with a mission loaded.

```
veaf-tools dcs smoke-test --full --mission <path.miz>
```

The **full, unattended** run: it locates `DCS.exe` (from the install dir the probe reports, or
`--dcs-exe`), launches it, waits for the hook to answer, loads the mission (`net.load_mission`,
legitimate in single-player since `isServer=true`), waits for the mission to become active, runs the
checks, then **quits DCS** — always, even on failure, or the next run inherits a running instance.
Every wait is bounded and names the step that timed out. As a safeguard it **refuses** a DCS that is
already running (loading a mission would overwrite the live session); `--allow-running` lifts that, and
in that case it does not quit an instance it did not start.

## How it talks to DCS

**Two transports, each for what it reaches** (ticket 04). A check names its own via `Check.transport`:

| Transport | What it sees | Which checks |
|---|---|---|
| **hook** (`dcs-fiddle-server.lua`) | a **bare** scripting state: DCS's own globals (`Disposition`, `missionCommands`, `coalition`) are there, the mission's scripts are **not** | DCS-native checks, and driving (load/quit) |
| **bridge** (`dcs-serve` → `dcs-bridge.lua`, injected **into** the mission) | the state the mission's scripts run in — where `veaf` lives | every **VEAF** assertion (`veaf-loaded`, `findspawnpoint-exists`) |

Why the split: the hook reaches a state where `env` is a table but the mission's scripts never ran, so
`veaf` is `nil` there. The probe now **measures** that (`type(veaf)` on the hook route) instead of
inferring it from `env` — `env` exists in *every* scripting state, loaded or bare, which is what made
"the scripts are here" look true. So a VEAF assertion goes through the bridge, or it reads `veaf-absent`
forever. When the bridge is absent, the check **fails naming `dcs-serve`**, never reporting
`veaf-absent`: the bridge is a stated prerequisite, not "nothing to talk to".

The hook's transport, read out of `dcs-fiddle-server.lua` rather than assumed: the Lua travels
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

It is the **same** bridge `capture-map` uses (`dcs-serve` + `dcs-bridge.lua`): it lives *inside* the
mission, so it cannot load one and cannot answer before one exists — hence the hook for driving and the
bridge for VEAF assertions, each where it actually answers.

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
The launch → load → assert → quit cycle is now **written** (the `--full` mode above), on the facts the
probe established — `net.load_mission` present and `isServer=true` in single-player. The orchestration is
covered by tests with fakes; the real behaviour of the DCS calls themselves is confirmed by an in-game
run, which a unit test cannot replay. Still outstanding: the committed test mission (ticket 01) and its
in-game anchor check.
