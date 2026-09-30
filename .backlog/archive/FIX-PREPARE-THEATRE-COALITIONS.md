# FIX-PREPARE-THEATRE-COALITIONS — a mission the validator says DCS will refuse

Status: ✅ done · archived 2026-09-28

Origin: found while writing the tutorial (`DOC-TUTORIAL`, PR #863) — the walkthrough's own steps
produced it.

## The report

`prepare --template minimal --theatre Caucasus`, then `build`, then `extract`, then `validate`
reportedly fails with:

> Side 'blue' holds units but no country is assigned to it: DCS will open the coalition assignment
> screen and refuse to load the mission.

The explanation offered: the build injects aircraft groups under `coalition.<side>.country`, while
the synthetic blank mission `--theatre` generates leaves `coalitions = { blue = {}, red = {} }`
empty.

## Reproduce before fixing — it is not confirmed

**This has not been independently reproduced.** `prepare` needs a real Windows console (it drives
an interactive prompt through InquirerPy) and refuses to run from Git Bash or a captured
PowerShell session, so the report stands on the tutorial agent's run alone.

Start there: reproduce it in `cmd.exe` or a real terminal, capture the exact commands and the exact
message. If it does **not** reproduce, say so and close the lot — a lot that finds nothing is a
good outcome, an invented fix is not.

## Why it matters if it holds

`--theatre` is the path a newcomer takes: it is what the new tutorial teaches, and what someone
starting a mission from nothing will use. A first mission that DCS refuses to load, on the
documented happy path, is the worst possible first contact — and the failure surfaces two commands
later, in `validate`, not where it was caused.

## Outcome — reproduced, and worse than reported

It reproduces, and `prepare` runs fine from a captured session: the "No Windows console found" that
blocked the earlier attempt comes from the *overwrite* prompt, which only fires when the target
folder already holds the files being copied. Into an empty folder there is no prompt.

The report understated it. `validate` flags **both** sides, not only blue, and the built mission
carries **six** unassigned countries: USA / France / CJTF Blue and Russia / USSR / CJTF Red, with
`coalitions = { blue = {}, neutrals = {}, red = {} }` untouched.

The offered explanation is right about the mechanism and incomplete about the culprits. Two build
steps create countries, and neither assigned them:

- the **aircraft-group injector**, for the shipped `src/spawnables.yaml` and
  `src/dynamic-slot-templates.yaml` that `prepare` copies (CJTF Blue, CJTF Red, France, USSR);
- the **coalition placeholder**, whose whole purpose is to register a side with DCS (USA, Russia).

Fixed in the injectors, not in the generator — see the ticket for why the generator option would
have silenced `validate` while leaving the mission unloadable.

## Definition of done

- [x] Reproduced (or shown not to reproduce, and the lot closed with that finding recorded)
- [x] If real: a mission produced by `prepare --theatre` + `build` loads in DCS — **not verified in
      DCS** (no DCS on the machine that did this work). Verified instead that `validate` is clean and
      that every unit-owning country id is listed in `coalitions.<side>`, which is the condition DCS
      checks
- [x] A test covering the path end to end — the defect is in the seam between two commands, so a
      test of either alone would have missed it, and did
- [x] The tutorial's step is re-checked against the fix — `doc/mission-maker/TUTORIAL.md` line 44 is
      the exact command that was re-run; it now validates clean and the page needs no change

## Left open

`validate` reports a side only when it has **no** assigned country at all. A mission with one country
assigned out of three passes it and still will not load. Out of scope here — the check also runs
inside the build, so tightening it changes what existing missions are allowed to build — but worth a
lot of its own.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Reproduce, then fix the blank mission's coalitions](FIX-PREPARE-THEATRE-COALITIONS.md) | fix |

---

## Tickets, in full

## 01 — Reproduce, then fix the blank mission's coalitions

Status: ✅ done

Type: fix · Files: wherever `--theatre` generates the blank mission, plus the build's group injection

### Step one is reproduction, and it may fail

Run, in a **real Windows console** (`prepare` drives an interactive prompt and refuses a captured
or Git Bash session — "No Windows console found"):

```
veaf-tools prepare --template minimal --theatre Caucasus <folder>
veaf-tools build
veaf-tools extract
veaf-tools validate
```

Expected per the report: `validate` complains that side `blue` holds units while no country is
assigned to it, and says DCS will refuse to load the mission.

If it does not reproduce, **stop and close the lot with that finding**. The report comes from a
single run by another agent and has not been confirmed since; an invented fix would be worse than
no lot.

### If it reproduces

The offered explanation: the build injects aircraft groups under `coalition.<side>.country`, while
the blank mission `--theatre` generates leaves `coalitions = { blue = {}, red = {} }` empty. Verify
that before acting on it — read what `--theatre` actually writes, and what the build actually adds.

Then decide where the fix belongs. Both are defensible and they are not equivalent:

- **In the generator**: a blank mission declares a country per side from the start. Simple, but it
  bakes a choice of country into every generated mission.
- **In the injector**: whatever adds a group to a side ensures that side has a country. Narrower in
  intent and fixes the same failure whatever produced the mission — including missions from other
  sources.

Say which you chose and why.

### What was done

Reproduced with, from the repo, into an **empty** target folder (no console needed — the
"No Windows console found" comes from the overwrite prompt, which an empty folder never triggers):

```
poetry run veaf-tools mission prepare --template minimal --theatre Caucasus <folder>
poetry run veaf-tools mission build mission.miz <folder> --scripts-path <scripts-root>
poetry run veaf-tools mission extract <folder>/My-Mission_<date>.miz <folder>
poetry run veaf-tools mission validate <folder>
```

`validate` reported the error for **both** blue and red. The extracted table showed
`coalitions = { blue = {}, neutrals = {}, red = {} }` against six unit-owning countries: USA (2),
France (5), CJTF Blue (80) / Russia (0), USSR (68), CJTF Red (81).

**Chosen: the injector.** Two places create countries and neither assigned them —
`aircrafts_injector._get_or_create_country` (the shipped `spawnables.yaml` and
`dynamic-slot-templates.yaml`) and `mission_builder.coalition_placeholder` (the per-side
placeholder). Both now call `mission_tools.group_insertion.assign_country_to_side`, which
`group_insertion.add_group` — the MCP path — has always called; `blank_mission.py`'s docstring
already claimed every group-adding path did.

The generator option was rejected as *wrong*, not merely broader: `coalitions.<side>` must list
**every** country that owns units on that side. Declaring one country in the blank mission would
satisfy `validate` — which only reports a side with no country at all — while five of the six stayed
unassigned and DCS still refused the mission. It would have hidden the defect.

### Definition of done

- [x] Reproduced (or closed as not reproducible, with the evidence)
- [x] A mission from `prepare --theatre` + `build` loads in DCS — or at minimum passes `validate`,
      and say plainly which of the two you were able to check → **`validate` only**; no DCS on this
      machine. Beyond `validate` (which is satisfied by one assigned country), the test asserts the
      real invariant: every unit-owning country id appears in `coalitions.<side>`
- [x] A test over the **whole path**: prepare → build → validate. The defect lives in the seam
      between commands, so a test of either alone would miss it, and did →
      `test/python/test_prepare_theatre_build_validate.py`, driving the real CLI commands. Verified
      to fail without the fix (`countries [2, 5, 80] own units but are not listed in coalitions.blue`)
- [x] The tutorial's corresponding step still holds — `doc/mission-maker/TUTORIAL.md` line 44 is the
      command that was re-run; no doc change needed

---
