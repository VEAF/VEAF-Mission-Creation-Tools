# FEAT-COMBAT-LOG — a combat log for an exact debrief

Status: 🔄 in progress

Origin: the debrief of "Marteau du Golan" (2026-10-29) had to be guessed from the Tacview: an ACMI names no shooter, records no destruction, and the AH-64s' gun does not show in it. David's task T430.

## Scope

| # | Ticket | Status |
|---|---|---|
| 01 | [The module writes every shot, hit and kill](tickets/01-module.md) | 🔄 |
| 02 | [`veaf-tools mission combat-log`: the recap per pilot](tickets/02-command.md) | 🔄 |
| 03 | [Measure in game what DCS gives](tickets/03-measure-in-game.md) | 🧑 |

## Decisions

- One JSON object per line (`.jsonl`), appended, flushed every 10 s rather than per line (a gun run raises one hit per shell, and a synchronous flush runs on the simulation thread): a server crash loses at most 10 s, and the reader skips a line cut short.
- The module listens to DCS directly (`world.addEventHandler`), not through `veafEventHandler`, whose callbacks run 0.5 s late: by then a weapon object may be gone.
- Each line records what DCS handed over (`weapon_object`, `weapon_name`): the file is its own measurement of what guns give, since nothing could be measured without DCS running.
- On by default in the shipped mission folder (`COMBATLOG: true`); the file is written only where the scripting environment keeps `io`/`os`/`lfs`, otherwise one warning and nothing else.
