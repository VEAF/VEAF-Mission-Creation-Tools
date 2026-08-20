# What a game master is, from the mission scripting side

**Measured 2026-08-20, DCS 2.9.28.26385 (x86_64, MT, Windows), single-player session.**
Probe: `test/veaf-tools/verify-mission-c/src/scripts/probeRoleMenus.lua` (deleted after the run — this
page is its output). Ticket 01 of
[`FEAT-ROLE-AWARE-RADIO-MENU`](../../.backlog/FEAT-ROLE-AWARE-RADIO-MENU/PRD.md).

## Why this page exists

The design of a role-aware radio menu turns on facts about DCS that the code cannot state, and guessing
them has already been wrong here once: on 2026-08-18 a game master was declared multiplayer-only from a
reading of DCS's own Lua, and David refuted it the same day by taking the role in a solo session. So
every line below is a printed value, not a reading.

**The game-master role works in single player.** That is the first result, and it invalidates a claim
that was sitting in `verify-mission-c`'s README until today.

## A game master is invisible to the scripting environment

| Question | Answer |
|---|---|
| Does he appear in `world.getPlayers()`? | **The function does not exist.** `attempt to call a nil value` — `world.getPlayers` belongs to the hook environment, not to mission scripting. The ticket asked about an API unreachable from here. |
| `coalition.getPlayers(NEUTRAL/RED/BLUE)` | **0, 0, 0** — on every sample, with a game master connected |
| `veafRadio.humanGroups` | **0 groups** |
| `veafRadio.humanUnits` | **0 units, 0 spawned** |
| Does he hold a unit or a group? | No — there is nothing to ask |
| What events does taking the role raise? | **None.** No `S_EVENT_BIRTH`, no `PLAYER_ENTER_UNIT`, no `TOOK_CONTROL` |

Nothing in the scripting API can see him, name him, count him, or notice him arriving.

## But menus do reach him — and the coalition filter works

Read off the F10 menu while holding the role on the **blue** side:

| Path | API | Reaches a game master? |
|---|---|---|
| **A** — global, `USAGE_ForAll` | `missionCommands.addCommand` | **yes** |
| **B** — coalition-scoped, `USAGE_ForAll` | `missionCommands.addCommandForCoalition` | **yes, correctly filtered** — `VERIFY C ROLES - BLUE` was there, `- RED` was not |
| **C** — per-group, `USAGE_ForGroup` | `missionCommands.addCommandForGroup` | **no** |

Observed, not inferred: `VERIFY C ROLES` contained *only* ROLE-A, with ROLE-C absent from the same
submenu. The three `USAGE_ForAll` commands of the pre-existing `VERIFY C` menu were all present too.

## The three consequences that decide the design

**1. `USAGE_ForGroup` can never reach him, and no setting will change that.** The renderer attaches
those commands by walking `veafRadio.humanGroups` (`veafRadio.lua:426`); the table is empty, so there is
nothing to attach to. This is the exact mechanism of
[#128](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/128) — the carrier submenu is created
because it is `USAGE_ForAll`, and stays empty because every command inside it is `USAGE_ForGroup`.

**2. The menu must exist from the start.** Since taking the role raises no event, nothing can trigger a
rebuild when a game master turns up. Any design that waits to notice him is impossible.

**3. Coalition scoping is a usable channel, and it is the good news.** A game master picks a side and the
filter honours it, so a per-side menu reaches him with his side's commands and not the other's. This also
clears [PR #769](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/769), which moved the carrier
submenus from the global path onto the scoped one: it did not narrow what a game master can see.

## What is NOT measured, and must not be read into this page

- **A spectator.** Not exercised in this session. Worth predicting *as a hypothesis to test*, not as a
  result: a spectator has no side, so path B cannot filter him in and only path A could reach him — which
  would put his commands in everyone's menu. That cost has to be weighed before anything is built for
  him.
- **The pilot control.** `humanGroups = 0` was not re-measured with a slot taken in the same session, so
  strictly speaking these zeros are not contrasted against a known-good reading. What makes them
  trustworthy anyway is that `USAGE_ForGroup` commands demonstrably work for pilots in every VEAF
  mission — if `humanGroups` stayed empty for a pilot, no per-group command would work for anyone. Worth
  one contrasting sample next time the probe is up, all the same.
- **Multiplayer.** Everything here is single-player. A game master on a real server may differ; nothing
  above should be assumed to carry over.

## Where this left the lot: cancelled

`FEAT-ROLE-AWARE-RADIO-MENU` was **cancelled by David on 2026-08-20**, on the strength of these
measurements — *"DCS ne nous permet pas de faire ce qu'on veut"*. This page is kept as the reason, so
that the question is not reopened without it.

Two walls, and both are DCS's rather than this framework's:

1. **The F10 channel never reports who clicked.** `missionCommands` posts to everyone, to a coalition, or
   to a group, and a callback only receives the argument fixed at registration. So a secured command
   cannot identify a game master — and every command worth giving him (activate a zone, start a QRA, run
   carrier operations) is a secured one.
2. **Leaving them unsecured is not an option.** The game-master slot can be taken with no password, and a
   password on it is hard to change and easily compromised. An unsecured mission-driving menu therefore
   hands the mission to whoever takes that slot on a public server.

The one escape route measured but not taken: **a marker carries its author**, and
[`veafSecurity.getMarkerSecurityLevel`](../../src/scripts/veaf/veafSecurity.lua:775) already resolves that
into a pilot level. A game master can place markers, so marker commands are a secured channel that is
open to him — but the commands this lot was about are menu-only, so using it would have meant exposing
carrier operations as marker commands, widening the lot past what the report asked. Recorded here as the
door that exists, for whoever wants to walk through it later.

## What this measurement paid for anyway

- The mechanism of [#128](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/128) is **known**
  rather than suspected: the carrier submenu appears because it is `USAGE_ForAll`, and stays empty
  because every command inside it is `USAGE_ForGroup` while `humanGroups` is empty for a game master.
- [PR #769](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/769) is cleared: coalition-scoped
  menus *do* reach a game master, correctly filtered, so scoping the carrier submenus took nothing away
  from him.
- The game-master role **works in single player**, which corrects a claim that stood in
  `verify-mission-c`'s README until today.
