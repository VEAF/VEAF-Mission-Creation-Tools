# FIX-PREPARE-THEATRE-COALITIONS — a mission the validator says DCS will refuse

Status: ⬜ ready

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

## Definition of done

- [ ] Reproduced (or shown not to reproduce, and the lot closed with that finding recorded)
- [ ] If real: a mission produced by `prepare --theatre` + `build` loads in DCS
- [ ] A test covering the path end to end — the defect is in the seam between two commands, so a
      test of either alone would have missed it, and did
- [ ] The tutorial's step is re-checked against the fix

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Reproduce, then fix the blank mission's coalitions](tickets/01-blank-mission-coalitions.md) | fix |
