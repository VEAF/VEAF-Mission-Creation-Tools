# Smoke harness — checking VEAF inside a real DCS

`poetry run test-lua` runs against `test/lua/dcs_mocks.lua`, a DCS **we wrote ourselves**. It can only
confirm what we already believed. Anything beyond it was ending up in a queue: somebody had to fly it.

This harness runs assertions **inside a running DCS**, with nobody at the controls.

## What it will never be

**A CI gate.** GitHub runners have no DCS, no licence and no GPU. It is a **local** tool, run by
whoever has an install.

## Prerequisites

1. **DCS running and a mission loaded**, by you: the mission built with the `dcs_bridge` section of
   `mission.yaml` enabled (or passed through `veaf-tools dcs inject-bridge`). The test mission
   `test/veaf-tools/verify-mission-c` already enables it.
2. **The `MissionScripting.lua` change** made once on your DCS, so the bridge can load the `socket`
   library: the same as for `clear-ground-sweep`, described in
   [the CLI reference](../CLI_REFERENCE.en.md#dcs-bridge).
3. **`dcs-serve`**: the command starts one when none runs, like the other bridge commands.

## Usage

```powershell
.\veaf-tools.exe dcs smoke-test
```

Runs the checks in the mission, one line per check, and exits 1 when one fails. `--suite spotter`
runs the `demo-spotter-network` rig's checks instead.

There is no unattended run any more (`--full`, which launched DCS and loaded the mission): measured on
2026-08-15, `net.load_mission` loads nothing in single player — ED documents it SERVER ONLY — and you
are the one who launches DCS and the mission. The DCS Fiddle hook that drove it was removed
(`REFACTOR-BRIDGE-ONLY`, 2026-10-29).

## How it talks to DCS

**One transport: the VEAF bridge.** `dcs-serve` receives the Lua, and `dcs-bridge.lua` — embedded
**in** the mission — runs it in the mission scripting state. That state sees both DCS's own globals
(`Disposition`, `missionCommands`, `coalition`) and the mission's scripts (`veaf`, `csar`), so every
check runs there.

The bridge returns `tostring` of the result; a Lua error comes back as `{"error": …}` and the check
fails quoting it. The bridge runs on the mission's clock: **paused, it does not answer**.

## The test mission's contract

Borrowed from [nielsvaes/dcs-sms](https://github.com/nielsvaes/dcs-sms), and the **counter-example** is
the part worth having:

- Theatre **Syria**, anchor **`(-32220, 405386)`** — "empty desert, far from anything, but DCS does
  process events there".
- At **`(-50000, -50000)`**, over open water, **DCS silently drops death events.**

A harness that put its test units "somewhere empty" would watch kills fail to arrive and conclude the
code was broken. That is a day lost on a non-bug, and it cannot be reasoned out.

> ⚠️ **These coordinates are not verified here yet.** They come from their repository, and this one has
> already found two wrong claims in their documentation. Killing a unit at that anchor and watching
> the event arrive is part of the lot's ticket 01.

## Adding a check

Assertions are **data**, not code: an entry in `CHECKS` (`veaf_libs/dcs_smoke.py`), with a name, a Lua
snippet, what its result must look like, and **why we want to know**. A check whose purpose nobody
wrote down is a check nobody dares delete.

### The rule: your Lua must return a **string**. Always.

The bridge returns `tostring(result ~= nil and result or "")`:

| Lua returns | Python receives |
|---|---|
| `'x'` | `'x'` |
| `3` | `'3'` — a **string** |
| `true` | `'true'` |
| `false`, `nil` | `''` — **destroyed** |
| `{1, 2}` | `'table: 0x…'` — an address, not the content |

Practical corollary: **tag** your values (`count:10` rather than `10`, a word rather than a boolean),
so that "I asked, there is nothing" (`count:0`) stays distinct from "the answer was destroyed" (`''`).
A test sweeps every check against `''`: an expectation that `''` satisfies cannot tell success from a
lost value.

A trap worth knowing: the snippets return **sentinels** (`veaf-absent`, `no-singleton`, `not-a-table`,
`raised: …`) instead of raising, so a missing prerequisite is legible. They are **non-empty strings,
hence truthy** — an expectation written as a plain truthiness test passes in exactly the case it was
meant to catch. A test sweeps every check against every sentinel, and against the shape of a Lua error
(`:1: attempt to …`), which `net.dostring_in` hands back as an ordinary result.

## The CSAR-over-water checks {#csar-over-water}

`csar-avoids-water-open-sea` and `csar-avoids-water-coast` answer
[#245](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/245) — "the CSAR pilot spawns in the
water" — with no aircraft and no human pilot. Three scripting calls are enough: trigger the spawn, read
the position back, ask what is underneath.

The two checks ask different questions, and that is the point:

- **open sea** — the reported case;
- **near a coast** — the interesting one. `FEAT-SCENERY-AWARE-SPAWN` gave `veaf.findSpawnPoint`
  terrain awareness; the real question is whether CSAR goes through it. A pass offshore with a failure
  near the coast would mean CSAR has a placement path of its own.

No coordinate is hard-coded: the check anchors on the first airbase and sweeps until it finds water,
then classifies the point by what surrounds it at 150 m. So it works on any theatre.

!!! warning "Any answer other than a dry placement is a failure"
    Including the ones saying the question could not be asked (`csar-absent`, `no-water-found`,
    `no-group`). A check that passes when it asked nothing would close #245 on nothing, which is
    precisely the failure mode this rig is written against.

---

## What is left

The [`FEAT-DCS-SMOKE-HARNESS`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/.backlog/archive/FEAT-DCS-SMOKE-HARNESS.md) lot carries the detail: the committed test mission (ticket 01) and its anchor check in game.
