# FEAT-ROLE-AWARE-RADIO-MENU — a game master gets an empty F10, a spectator gets nothing

Status: 🚫 wontfix

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
