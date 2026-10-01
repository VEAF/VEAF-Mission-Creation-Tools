# FIX-SECU-VERB-AND-LOG-NOISE — what a live private1 session showed on 2026-09-29

Status: 🧑 waiting-human — merged in #1032; 6.26.0 is out and the hook is deployed on the six servers (2026-10-01), so only ticket 01's in-game check is left

Open Training **Caucasus v6** on private1, evening of 2026-09-29, six pilots, mission built that
day from `develop` (`dd60e7a5`, so with `FIX-SECURED-FORALL-AND-UPDATER-BAT` already in). David
could not activate a combat zone from the radio menu and said so while flying; the server log was
read live. The secured-command defect of that afternoon was **not** the cause — it was already
fixed in the running mission. What the log showed instead is that **`/secu login` still exists,
still answers "mission authenticated", and no longer unlocks anything**, plus three smaller things
the same 90 minutes of log made plain.

The five are grouped because they were found in one sitting and four of the five are read in the
same file; none blocks anything on its own.

## What was measured

- `/secu login` at 19:20:59 → `VEAF-SECURITY|I: [Ninja 1-1 | Zip] is unlocking the mission`,
  `executeCommand` returned `true`, and the radio menu kept refusing.
- `/secu elevate` at 19:38:38 → `group 1000166 elevated to level 99 for 120 seconds`, and at
  19:38:55 a combat zone activation came through `VEAF-COMBATZONE|I|realMethod` — the secured
  proxy's own path. So the menu works; only the verb was wrong.
- David is `level=99` in `veaf-pilots.txt`, against the `LEVEL_SENIOR_PILOT` (10) the combat-zone
  command requires. Level was never the problem.
- Three pilots typed four different wrong commands in 90 minutes looking for the right one
  (`/sec`, `/se cu login`, `/veaf login`, `/veaflogin`), each raising a Lua error with a stack
  traceback.
- 2 506 `VEAF-COMBATZONE` lines in 90 minutes, at INFO.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [`/secu login` promises an authentication it no longer grants](tickets/01-secu-login-promises-nothing.md) | 🧑 |
| 02 | [a mistyped chat command raises a Lua error instead of answering the pilot](tickets/02-unknown-module-raises.md) | ✅ |
| 03 | [the combat-zone watchdog logs its whole inventory at INFO](tickets/03-combatzone-diag-verbosity.md) | ✅ |
| 04 | [a normal disconnect logs an ERROR from the server hook](tickets/04-playerdetails-nil-on-disconnect.md) | ✅ |
| 05 | [the `+` on a secured command never goes away](tickets/05-secured-plus-prefix-misleads.md) | ✅ |

## Definition of done

- Each ticket closed with what was measured, not only what was changed.
- Tickets 01 and 02 carry tests; 03 and 04 are level changes and need one each on the path that
  decides the level.
- `CHANGELOG.md` entry. `doc/` updated wherever `/secu login` is still taught as the way to unlock
  a mission — and the reason ticket 01 exists is that pilots are still reading it somewhere.
