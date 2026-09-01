# FIX-PREPARE-THEATRE-COALITIONS — a mission the validator says DCS will refuse

Status: ✅ done

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
| 01 | [Reproduce, then fix the blank mission's coalitions](tickets/01-blank-mission-coalitions.md) | fix |
