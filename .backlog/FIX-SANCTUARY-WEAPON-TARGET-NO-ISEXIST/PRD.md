# FIX-SANCTUARY-WEAPON-TARGET-NO-ISEXIST — a weapon whose target has no `isExist` raises in the sanctuary

Status: ⬜ ready

## Found

Claude and David, 2026-10-12, `dcs.log` of Privé 1 (`C:\Users\veaf\Saved Games\private1_server\Logs\dcs.log`), Sinai Open Training 6.29.0.
12 lines `VEAF-SCHEDULER|E| … veaf-scripts.lua:68601: attempt to call method 'isExist' (a nil value)`, 20:25:08 to 20:43:22 UTC, each on a player's weapon shot (the first is Angrydad54's, 20:25:06).
Line 68601 of the built script is `if not target or not target:isExist()` in `veafSanctuary.lua`, the guard added for a weapon released with no target: `weapon:getTarget()` returned an object that has no `isExist`.
The scheduler catches the error and logs it; the shot is not recorded by the sanctuary.
What the object is, is a hypothesis (a scenery object), not measured.

The same log produced two other findings, each in its own repository: Skynet (`VEAF/Skynet-IADS`, lot `FIX-STATIC-DOES-NOT-EXIST-IN-CONTACTS`) and the JTAC laser (`VEAF/CTLD`, lot `FEAT-JTAC-LOG-REAL-LASER-CODE`).

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-guard-by-what-the-target-answers.md) | Measure the object, then guard by what it can answer | ⬜ |

## Definition of done

- A Lua test where the mocked target has no `isExist`; the existing test for a target destroyed since stays green.
- The ticket says what the object was, measured, not assumed.
- `CHANGELOG.md` entry under `[Unreleased]`.
