# FEAT-ROLE-AWARE-RADIO-MENU — a game master gets an empty F10, a spectator gets nothing

Status: ⬜ ready

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
- **How to reach them at all.** `missionCommands.addCommandForCoalition` reaches a coalition; a game
  master picks a side, so it *probably* reaches him — **to be measured**, along with whether he
  appears in `world.getPlayers()` and what `humanGroups` holds during his session. A spectator has no
  side, so only the global `missionCommands.addCommand` could reach him — which puts the command in
  *everyone's* menu, and that is a cost to weigh, not a detail.
- **What "answer" means with no unit.** Probably a coalition-wide `outTextForCoalition`, or a global
  `outText` for a spectator. Whatever is chosen, the handlers that take `unitName` need to tolerate
  its absence rather than each inventing a fallback.
- **Security.** `veafSecurity` gates commands on the player. A game master is the most privileged
  player in the mission and the least identified by a unit — decide deliberately, and write it down,
  rather than discovering later that the unattached path skipped a check.

## Tickets

| # | What |
|---|---|
| [01](tickets/01-measure-what-a-game-master-is.md) | Measure what a game master and a spectator *are*, from the scripting side |
| [02](tickets/02-usage-class-and-policy.md) | The usage class and the per-role policy, decided from 01's measurements |
| [03](tickets/03-render-and-address.md) | Render the menus and address the answers; close #128 |

## Definition of done

- [ ] A game master sees a menu that lets him drive a mission: zones, QRA, carriers, IADS, weather
- [ ] A spectator sees whatever was deliberately chosen for him — including, if that is the decision,
      nothing at all, written down as a decision
- [ ] A pilot's menu is **unchanged**, and that is asserted by a test
- [ ] What each role sees is documented in the mission-maker docs (both languages), because a mission
      maker declaring a command now has a role dimension to think about
- [ ] #128 closed citing the reproduction and the fix
