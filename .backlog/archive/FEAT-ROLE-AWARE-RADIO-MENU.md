# FEAT-ROLE-AWARE-RADIO-MENU — a game master gets an empty F10, a spectator gets nothing

Status: 🚫 wontfix · archived 2026-09-28

**Cancelled by David on 2026-08-20**, after ticket 01's measurements: *"DCS ne nous permet pas de faire
ce qu'on veut"*. Ticket 01 stands as ✅ — its measurements are the reason, and they are kept in
[`docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md`](../../docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md)
precisely so nobody reopens this without them. Tickets 02 and 03 are 🚫.

## Why it cannot be built — the two walls

Both come from DCS, not from this framework, which is what makes the lot unbuildable rather than hard:

1. **A game master has no identity on the F10 channel.** `missionCommands` posts to everyone, to a
   coalition, or to a group, and the callback only ever receives the argument fixed at registration.
   So a secured command cannot know who clicked it — the group is the finest identity that channel
   offers, and a game master has none. Every command worth giving him (activate a zone, start a QRA,
   run carrier ops) is a secured one.
2. **Making them unsecured is not an option**, and this is David's point that closed the lot: the
   game-master slot can be taken with no password at all, and a password on it *"est difficile à
   changer et peut être facilement compromis"*. So an unsecured mission-driving menu would hand the
   mission to whoever takes the slot on a public server.

The one escape route was the marker channel — a marker carries its author, and `veafSecurity` already
resolves that into a pilot level. It would have meant exposing the carrier operations as marker
commands, which widened the lot past what the report asked for. David chose to stop instead.

## The modest version was considered too, and also dropped (2026-08-20)

RexAttaque's own proposal on #128 was smaller than what this lot attempted — *"I vote for simply cleaning
up the empty radio menus (carrier ops and such) for game masters only if possible"*. His trailing "if
possible" turns out to be the whole problem:

**A DCS submenu is one object for everybody.** Per-group commands are attached *inside* it and each is
visible only to its group, so a menu whose commands are all `USAGE_ForGroup` looks empty to anyone with
no group — but not creating it removes it from **everyone**, pilots included. There is no per-player
menu to clean up.

The only version that would work — not creating a submenu when nothing at all will be attached to it —
covers exactly the case where **no pilot is connected**. With pilots and a game master together, which is
the situation the issue was written about, the empty menu comes back. Making it work there means creating
those submenus per group (`addSubMenuForGroup`), which is a rewrite of the renderer: one logical node
would project to N DCS nodes, touching pagination, `delSubmenu`, and the references modules hold.

David's call: not worth a renderer rewrite to hide an empty menu. **Left as is.**

## What was gained anyway

- The mechanism of #128 is now **known and written down** rather than suspected: the carrier submenu
  appears because it is `USAGE_ForAll` and stays empty because every command inside is
  `USAGE_ForGroup`, and `humanGroups` is empty for a game master.
- [PR #769](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/769) is cleared: coalition-scoped
  menus *do* reach a game master, so scoping the carrier submenus did not narrow his view.
- A false claim in `verify-mission-c`'s README is corrected — it said a solo session could not answer
  #128, which is the opposite of what happened.

Origin: David, 2026-08-18, running `verify-mission-c`: *"pas de commande dans le menu carrier en game
master"*. Closes the report side of [#128](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/128),
and widens it — David's framing: **give a reasonable radio menu to the game master and to spectators,
with the commands and menus that suit their role**.

## Why it happens — and it is two problems, not one

**Visibility.** `veafRadio.RadioMenuBuilder:_placeCommandOnMenu` renders a command declared
`USAGE_ForGroup` (or `USAGE_ForUnit`) by walking `veafRadio.humanGroups` and attaching it **group by
group** (`veafRadio.lua:426`). A game master has no group and a spectator has none either, so neither
is ever iterated: the submenu is created — it is `USAGE_ForAll` — and stays empty. Measured on the
Carrier menu, every command of which is `USAGE_ForGroup` (`veafCarrierOperations.lua:846` onwards).
Only `USAGE_ForAll` commands reach them today.

**Addressing.** Making the command *appear* is not enough. A `USAGE_ForGroup` command is called with
the caller's `unitName`, and its handler uses that to answer — `veaf.outTextForGroup(unitName, …)`,
`veafSecurity` checks, "your group" semantics. With no unit there is nothing to pass, and a handler
that assumes one will fail or answer into the void. **This is the part that makes the lot a design
job rather than a one-line fix.**

## What has to be decided, and it is not obvious

- **Which commands even make sense without an aircraft.** Activating a combat zone, starting a QRA,
  running carrier operations, reading an IADS status, changing the weather: all global effects, all
  sensible for a game master. "Info on your aircraft", the guided checklists, rearm/refuel: not.
  The lot needs a rule, not a hand-picked list — most plausibly a **third usage class** (a command
  that can run unattached), declared where the command is declared.
- ~~**How to reach them at all.**~~ **Measured 2026-08-20**: `addCommandForCoalition` **does** reach a
  game master and filters correctly to his side; the global path reaches him too; `USAGE_ForGroup`
  cannot, ever, because the renderer walks `humanGroups` and that table is empty for him. He is also
  invisible to `coalition.getPlayers` and raises **no event** on arrival, so the menu must exist from the
  start rather than be rebuilt when he shows up. `world.getPlayers` turned out not to exist in mission
  scripting at all. **The spectator is still unmeasured**: having no side, only the global path could
  reach him — which puts the command in everyone's menu, and that cost is still a decision to take.
- **What "answer" means with no unit.** Probably a coalition-wide `outTextForCoalition`, or a global
  `outText` for a spectator. Whatever is chosen, the handlers that take `unitName` need to tolerate
  its absence rather than each inventing a fallback.
- **Security.** `veafSecurity` gates commands on the player. A game master is the most privileged
  player in the mission and the least identified by a unit — decide deliberately, and write it down,
  rather than discovering later that the unattached path skipped a check.

## Tickets

| # | What |
|---|---|
| [01](FEAT-ROLE-AWARE-RADIO-MENU.md) | Measure what a game master and a spectator *are*, from the scripting side |
| [02](FEAT-ROLE-AWARE-RADIO-MENU.md) | The usage class and the per-role policy, decided from 01's measurements |
| [03](FEAT-ROLE-AWARE-RADIO-MENU.md) | Render the menus and address the answers; close #128 |

## Definition of done

- [ ] A game master sees a menu that lets him drive a mission: zones, QRA, carriers, IADS, weather
- [ ] A spectator sees whatever was deliberately chosen for him — including, if that is the decision,
      nothing at all, written down as a decision
- [ ] A pilot's menu is **unchanged**, and that is asserted by a test
- [ ] What each role sees is documented in the mission-maker docs (both languages), because a mission
      maker declaring a command now has a role dimension to think about
- [ ] #128 closed citing the reproduction and the fix

---

## Tickets, in full

## 01 — Measure what a game master and a spectator are, from the scripting side

Status: ✅ done

**Measured 2026-08-20**, DCS 2.9.28.26385, single-player session. Results:
[`docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md`](../../docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md).
The probe has been deleted, as this ticket asked.
Type: chore (measurement)
Files: a probe in a verification mission, then `docs/exploration/` for the result

Blocks [02](FEAT-ROLE-AWARE-RADIO-MENU.md) and [03](FEAT-ROLE-AWARE-RADIO-MENU.md): both depend on answers
nobody in this repository has.

### Why measure first

The design hinges on facts about DCS that the code cannot tell us and that guessing has already cost
this project once — on 2026-08-18 a game master was declared multiplayer-only, from a code reading of
DCS's own Lua, and David refuted it in one sentence. So: measure, do not infer.

### The questions, and how each is answered

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

### Done when

- Each row above has a measured answer, written to `docs/exploration/` with the date and the DCS
  version, in the style of `DCS-HOOK-ENVIRONMENT-BOUNDARIES.md`
- The result explicitly states which of the two reach paths (coalition-scoped, global) works for a
  game master and which for a spectator — that is the fork 02 depends on
- The probe is deleted, or folded into the smoke harness if it can assert unattended

### What the probe does, and one thing it deliberately does not rely on

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

### The answers, in one table

Full write-up in [`docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md`](../../docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md).
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

---

## 02 — A usage class for unattached commands, and the per-role policy

Status: 🚫 wontfix

Cancelled with the lot on 2026-08-20 — the policy it would have decided has nowhere to live: a secured command cannot identify a game master on the F10 channel, and an unsecured one would hand the mission to whoever takes the slot. See the
[PRD](FEAT-ROLE-AWARE-RADIO-MENU.md) for the two walls, and
[`docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md`](../../docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md)
for the measurements behind them.
Type: feat (design + declaration)
Files: `src/scripts/veaf/veafRadio.lua`, every module declaring commands, the mission-maker docs
(both languages), tests

Depends on [01](FEAT-ROLE-AWARE-RADIO-MENU.md).

### The decision this ticket makes

Today a command declares one of three usages: `USAGE_ForAll` (rendered once, globally),
`USAGE_ForGroup` (rendered per human group, handler gets a `unitName`), `USAGE_ForUnit` (per unit).
The split conflates two independent things:

- **who may see it**, and
- **whether it needs a caller's unit to do its work**.

`ForAll` happens to mean both "everyone sees it" and "no unit needed"; `ForGroup` means both "pilots
only" and "needs a unit". A game master needs the combination the vocabulary cannot express: *seen by
someone with no unit, and able to run without one*.

Rather than a fourth flag bolted on, prefer making the two dimensions explicit — an **audience** and
a **needs-a-caller** property — with the three existing constants kept as the shorthands they are, so
no existing declaration changes meaning. Whatever shape is chosen, write the reasoning down: this
vocabulary is what every module and every mission maker uses.

### Classifying the existing commands

The rule has to be applied, not just defined. Sweep every `addCommandToSubmenu` /
`addCommandToMenu` call in `src/scripts/veaf/` and classify each — enumerate them from the code, do
not sample: a family of commands hand-picked from memory is how a sweep misses the third of its
cases. First read, to be checked:

- **Runs unattached** (global effect): combat-zone activate/deactivate, QRA start/stop, carrier
  operations, IADS status, weather, named points, most of `veafRemote`
- **Needs a caller**: anything answering "your group"/"your aircraft" — guided checklists, rearm and
  refuel, unit info, CTLD's transport actions, anything reading the caller's position

The uncertain middle — a command that *can* work unattached but whose message is written as if to a
pilot — is the interesting part, and the count of those belongs in this ticket's result.

### Security

`veafSecurity` gates on the caller. An unattached command has no caller to gate on, and a game master
is simultaneously the most privileged and the least identified participant. Decide explicitly whether
the unattached path is trusted, gated by role, or refused for secured commands — and record it. A
security decision made by omission is the failure mode this project has already paid for once
(SECREV-2, `veaf.SecurityDisabled`).

### Done when

- The usage vocabulary is extended (or restated) with the reasoning written in this ticket
- Every existing command is classified, from an enumeration of the call sites, and the counts recorded
- The security stance for unattached commands is explicit, with a test
- Existing pilot-facing behaviour is byte-for-byte unchanged, asserted by test

---

## 03 — Render the role's menu, and answer without a unit; close #128

Status: 🚫 wontfix

Cancelled with the lot on 2026-08-20 — there is nothing left to render: the lot was cancelled before a usage class existed to render. See the
[PRD](FEAT-ROLE-AWARE-RADIO-MENU.md) for the two walls, and
[`docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md`](../../docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md)
for the measurements behind them.
Type: feat
Files: `src/scripts/veaf/veafRadio.lua`, the handlers taking a `unitName`, tests, mission-maker docs

Depends on [01](FEAT-ROLE-AWARE-RADIO-MENU.md) and [02](FEAT-ROLE-AWARE-RADIO-MENU.md).

### Rendering

`_placeCommandOnMenu` renders anything not `USAGE_ForAll` by walking `veafRadio.humanGroups`
(`veafRadio.lua:426`), so a participant with no group gets nothing. Add the path 02's classification
calls for: a command marked as runnable unattached is **also** placed through whichever reach 01
measured to work — coalition-scoped for a game master, global for a spectator if that is the decision.

Two traps to avoid, both of which would be reported as bugs:

- **No duplicates.** A pilot must not see the same command twice because it was rendered both per
  group and coalition-wide. The existing menu already carries a coalition dimension
  (`FEAT-COMBATZONE-MENU-COALITION`) — reuse it rather than inventing a parallel one.
- **Rebuild timing.** A game master arriving after the menu was built must still get it. 01 measures
  what event, if any, his arrival raises; if none does, the menu has to exist from the start rather
  than be rebuilt on his arrival.

### Addressing

A handler invoked unattached gets no `unitName`. Today they answer with `veaf.outTextForGroup(unitName, …)`,
which cannot work. Give them one shared way to answer — an output helper that falls back to the
coalition (or global) when there is no unit — rather than letting each handler invent a fallback.
Handlers that genuinely cannot work without a caller are not in this path at all: 02 classified them
out.

### Done when

- A game master sees, and can run, the commands 02 classified as unattached — verified in game on the
  Carrier menu, the reproduction #128 was reported from
- A spectator sees exactly what 02 decided, no more
- A pilot's menu is unchanged: same commands, same order, same pagination — asserted by test, not by eye
- No command appears twice for anyone
- `veafRadio`'s doc page (both languages) documents the role dimension for mission makers
- **#128 closed**, citing the reproduction (empty Carrier menu in game master, 2026-08-18) and the fix

---
