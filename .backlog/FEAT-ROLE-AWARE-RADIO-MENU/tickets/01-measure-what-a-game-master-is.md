# 01 — Measure what a game master and a spectator are, from the scripting side

Status: ✅ done

**Measured 2026-08-20**, DCS 2.9.28.26385, single-player session. Results:
[`docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md`](../../../docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md).
The probe has been deleted, as this ticket asked.
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

## What the probe does, and one thing it deliberately does not rely on

Written 2026-08-20. Two halves, because **the probe must not depend on the mechanism it measures**: the
question is whether menus reach an unattached player, so a probe you have to click could measure nothing
at all — if no command reaches him, there is no click.

- **A loop** writing to `dcs.log` every 10 s: `world.getPlayers()`, `coalition.getPlayers()` per side,
  `veafRadio.humanGroups` and `humanUnits`, plus an event handler logging BIRTH / PLAYER_ENTER_UNIT /
  PLAYER_LEAVE_UNIT / TOOK_CONTROL — the last of which answers "can the menu be rebuilt when he arrives,
  or must it exist from the start?".
- **Four marked commands**, one per reach path: global `ForAll`, coalition-scoped `ForAll` (one per side),
  and per-group `ForGroup`. Which of them are *visible* is the fork ticket 02 hangs on, and it is the one
  thing the log cannot capture — so the README asks for it to be written down per role.

**A note the ticket did not anticipate**: PR #769 (`FIX-CARRIER-MENU-COALITION`) moved the carrier
submenus from the global path onto the coalition-scoped one. So the coalition-scoped path is no longer a
curiosity — if it does not reach a game master, that PR narrowed what he can see, and ticket 02 has to
account for it. That is why the probe carries a scoped menu per side rather than one.

**A stale claim corrected on the way.** `verify-mission-c`'s README stated that check 11 *"needs a real
multiplayer server with a game-master client; a solo session cannot answer it"*. That is the very claim
this ticket cites as having been refuted — David took the role in a solo session the same day and found
the carrier menu empty. The README said the opposite of the ticket next to it, and would have talked the
next reader out of measuring at all.

## The answers, in one table

Full write-up in [`docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md`](../../../docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md).
The short version, because it is what 02 and 03 need:

| | Result |
|---|---|
| `world.getPlayers()` | **does not exist** in mission scripting — `attempt to call a nil value`. This ticket asked about a hook-environment API. |
| `coalition.getPlayers()` × 3 sides | 0, 0, 0 with a game master connected |
| `veafRadio.humanGroups` / `humanUnits` | 0 / 0 |
| events on taking the role | **none** |
| global `ForAll` | **reaches him** |
| coalition-scoped `ForAll` | **reaches him, filtered to his side** |
| per-group `ForGroup` | **absent** — observed, not deduced |

Three consequences for the design:

1. **`USAGE_ForGroup` can never reach him.** The renderer walks `humanGroups`, which is empty. Not a
   setting to find — the mechanism of #128 itself.
2. **The menu must exist from the start**: no event marks his arrival, so nothing can trigger a rebuild.
3. **Coalition scoping is a usable channel**, which also clears PR #769 of having narrowed his view.

**Not measured, and flagged as such rather than filled in:** the spectator, and a contrasting
`humanGroups` reading with a slot taken. Both are named in the write-up.

**A stale claim corrected on the way.** `verify-mission-c`'s README said check 11 *"needs a real
multiplayer server; a solo session cannot answer it"* — the very claim this ticket cites as refuted. It
contradicted the ticket beside it and would have talked the next reader out of measuring at all.
