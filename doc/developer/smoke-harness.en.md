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
   [DCS-HOOK-ENVIRONMENT-BOUNDARIES](../../docs/exploration/DCS-HOOK-ENVIRONMENT-BOUNDARIES.md)).
   That measurement is what makes unattended driving possible at all.
2. **The hook installed**: copy `src/scripts/other/dcs-fiddle-server.lua` into
   `Saved Games/DCS/Scripts/Hooks/`. It listens on `127.0.0.1:12081`.
3. **A mission loaded** for the assertions — the mission environment does not exist before that.

## Usage

```
veaf-tools smoke-test --probe-only
```

Runs no assertions: reports only **what this DCS allows**. Run it first — the same discipline as the
`Disposition` probe, measure before building on top. Among other things it answers whether
`net.load_mission` and `DCS.exitProcess` exist, two calls this repository has **never** made.

```
veaf-tools smoke-test
```

Probes, then runs the checks. Exits 1 if any fails, 0 if all pass **or the run was skipped**.

## How it talks to DCS

One transport, the hook's, read out of `dcs-fiddle-server.lua` rather than assumed: the Lua travels
**base64 in the URL path**, the target environment in `?env=`, and the reply is JSON `{result=…}` or
`{error=…}`.

| `?env=` | What it reaches | What it is for |
|---|---|---|
| `default` | the hook's own environment, via `loadstring` | the only one holding `net.*` — so, driving |
| `mission` | the mission environment, via `net.dostring_in` | where the VEAF scripts live — so, asserting |

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

One trap worth knowing: the snippets return **sentinels** (`veaf-absent`, `no-singleton`,
`not-a-table`, `raised: …`) instead of raising, so a missing prerequisite stays legible. Those are
**non-empty, therefore truthy** strings — an expectation written as a plain truthiness test passes in
exactly the case it was meant to catch. That happened while writing this; a test now sweeps every check
against every sentinel.

## What is still missing

The [`FEAT-DCS-SMOKE-HARNESS`](../../.backlog/FEAT-DCS-SMOKE-HARNESS/PRD.md) lot carries the detail.
In short: DCS has to be started **by hand** for now. Launching and quitting it automatically needs DCS
calls this repository has never made — `--probe-only` reports whether they are available, which gives
whoever picks it up facts instead of guesses.
