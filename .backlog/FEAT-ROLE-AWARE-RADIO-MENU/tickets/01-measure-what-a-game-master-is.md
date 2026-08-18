# 01 — Measure what a game master and a spectator are, from the scripting side

Status: ⬜ ready
Type: chore (measurement)
Files: a probe in a verification mission, then `docs/exploration/` for the result

Blocks [02](02-usage-class-and-policy.md) and [03](03-render-and-address.md): both depend on answers
nobody in this repository has.

## Why measure first

The design hinges on facts about DCS that the code cannot tell us and that guessing has already cost
this project once — on 2026-08-18 a game master was declared multiplayer-only, from a code reading of
DCS's own Lua, and David refuted it in one sentence. So: measure, do not infer.

## The questions, and how each is answered

Run from a mission carrying a game-master role on both sides, from `verify-mission-c` or its
successor. Each answer is a printed value, not an impression.

| Question | How |
|---|---|
| Does a game master appear in `world.getPlayers()`? | print the table while he is connected, before and after he takes the role |
| Does he hold a `unit`? a `group`? | `Unit.getByName` / the returned player objects |
| What does `veafRadio.humanGroups` hold during his session? | dump it from a menu command or the bridge |
| Does `missionCommands.addCommandForCoalition(side, …)` reach him? | add one marked command per side, look at his F10 |
| Does the plain global `missionCommands.addCommand` reach him? | same, one global command |
| Same five questions for a **spectator** | same probe, without taking a slot |
| Which side is he on, from the script's point of view? | `coalition.getPlayers`, or the birth events he raises |

Also worth capturing while the probe is up: **what events he raises** (does taking the game-master
role fire anything `veafEventHandler` sees?), since that decides whether the menu can be rebuilt when
he arrives, or must exist from the start.

## Done when

- Each row above has a measured answer, written to `docs/exploration/` with the date and the DCS
  version, in the style of `DCS-HOOK-ENVIRONMENT-BOUNDARIES.md`
- The result explicitly states which of the two reach paths (coalition-scoped, global) works for a
  game master and which for a spectator — that is the fork 02 depends on
- The probe is deleted, or folded into the smoke harness if it can assert unattended
