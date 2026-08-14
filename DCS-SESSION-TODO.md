# What to do next time DCS is running

Everything the backlog is waiting on that **needs DCS started** — nothing here can be done from a
keyboard on a workstation without the game. Each item says what to run, what to look at, and what it
unblocks, so a session can be worked through without re-reading the whole backlog.

**Tick a line off by deleting it**, and update the ticket it names. `.backlog/README.md` stays the
source of truth for scope and status; this file is only the running order for a session in front of
the game.

Written 2026-08-12, reordered 2026-08-14 when items 0 and 0b arrived — they gate a release, so they
come first.

---

## A mission is ready for items 0 and 0b

`D:\dev\_VEAF\tmp\dcs-session-2026-08-14\TestMenuFR.miz` — Caucasus, `language: fr`, with the modules
that build menus (RADIO, SPAWN, COMBATZONE, ASSETS, WEATHER, NAMEDPOINTS, MOVE, TRANSPORTMISSION,
CASMISSION, SHORTCUTS, SECURITY) and security **left on**.

**It embeds the repository's scripts, not the published ones**, and that matters: release 6.13.0 has
none of these fixes, so a mission built the ordinary way would show the old behaviour and read as
"the fix does not work". Verified before shipping it here — the embedded bundle contains
`ZONES DE COMBAT`, `APPARITION`, `Activer la mission` and `menu.combatzone.root`, and its
`veaf-config.lua` declares `veaf.config.language = "fr"`.

Rebuild it, if needed, with:

```bash
veaf-build build --version 6.13.100 --skip-python
```

then from the mission folder:

```bash
veaf-tools mission build TestMenuFR . --dev-mode --scripts-path D:/dev/_VEAF/VEAF-Mission-Creation-Tools
```

## 0. Read the F10 menu in French — 2 min, and it gates the release

[`FIX-RADIO-MENU-I18N`](.backlog/FIX-RADIO-MENU-I18N/PRD.md) (PR #733) localised **90 labels across 12
modules**. Every pilot sees this on the first mission after the release, so a regression here is the
most visible thing we could ship.

Load the mission, open F10 → VEAF, and check the tree reads:

| Expected | Was |
|---|---|
| `APPARITION` | SPAWN |
| `ZONES DE COMBAT` | COMBAT ZONES |
| `MOYENS` | ASSETS |
| `MISSION CAS` | CAS MISSION |
| `MÉTÉO ET ATC` | WEATHER AND ATC |
| `POINTS NOMMÉS` | NAMED POINTS |
| `DÉPLACER` | MOVE |
| `MISSION DE TRANSPORT` | TRANSPORT MISSION |

Then one submenu deep: a combat zone should offer `Activer la zone`, `Infos`,
`Demander de la fumée ROUGE sur l'objectif`. `MISSIONS`, `VEAF` and `GUARDIAN` are **deliberately
identical** in both languages — not an oversight.

**What would be silent**: a label showing as `menu.combatzone.root`. That means a key with no
catalogue entry, and it would only appear for the entry that is missing.

**Also worth a glance**: any label carrying a literal `%s`. Five of those shipped in the first commit
of that lot and were caught in review; the guard that forbids them is new.

## 0b. Check the two security fixes — 5 min, same mission

Both from [`FIX-DOCAUDIT-CODE`](.backlog/FIX-DOCAUDIT-CODE/PRD.md) (PR #730), both in the release.

- **`_transport` no longer asks a listed pilot for the password.** Place a `_transport` marker with no
  `password` while listed in `veaf-pilots.txt`. It used to be refused whatever your tier, because the
  check was called without the marker id. This is the one place `veafSecurity.md`'s "nothing changes
  for a listed pilot" was false.
- **The tier names work.** Nothing to type: if the mission loads and the F10 menus appear, the
  dispatchers accepted `KNOWN_PILOT` / `SENIOR_PILOT` / `ADMIN`. What to watch in `dcs.log` is the
  **deprecation notice** — it should be *absent*, since all 24 of our own declarations were migrated.
  One appearing means a module still declares `L9`.

## 1. Capture the parking slots — 5 min per map

Unblocks [`FEAT-MCP-MUTATION-ACTIONS` 09](.backlog/FEAT-MCP-MUTATION-ACTIONS/tickets/09-add-air-group.md)
(*"put a two-ship of F-16s on the ramp at Incirlik"*), which cannot start without this data.

Same kit as the airbase captures of `FEAT-AIRDROMES-RUNTIME-SOURCE`: load a bridge mission, start
`dcs-serve`, then:

```bash
veaf-tools dcs capture-map --parking --out-dir veaf_build/dcs_data
```

- Caucasus, Syria and PersianGulf first — they cover most missions.
- It writes `parking/<theatre>.json` next to the airbase dump. Commit it.
- Then paste one airfield's slots into ticket 08 so the runtime's real field names are recorded
  rather than assumed — the shipped API schema is already known to be incomplete here.

## 2. Open a mutated mission in the Mission Editor

The acceptance criterion of
[`FEAT-MCP-MUTATION-ACTIONS` 02 and 03](.backlog/FEAT-MCP-MUTATION-ACTIONS/PRD.md), and the only half
no test can cover — `FIX-MAPRESOURCE-KEY` is what a plausible-looking write the editor rejects costs.

Take any built `.miz`, then through the MCP (or a Python call):

- `set_unit_properties` — change a loadout and a heading on one aircraft.
- `set_group_properties` — move a group **that has a route** a few km, and rename another.

Then open it in the ME and **save it**. What to watch for: no complaint on load, the moved group's
route still attached to its units, the loadout as asked, and — the one that would be silent — the
group still where you put it after the save.

Four more edits ship in the same lot and want the same pass, each with one thing that could be
silently wrong:

- `edit_route` — add a waypoint with an **attack task**, then *fly it*. The editor accepting a task
  table is not proof DCS runs it, and a flight that quietly does nothing is this ticket's worst case.
  Also remove the route's only ETA-locked waypoint and check the mission still **saves** (the action
  re-locks the first, which is what `FIX-WAYPOINTS-ETA-LOCKED` says DCS itself does).
- `edit_zone` — reshape a combat zone into a polygon with **more than four vertices**, save, reopen.
  The VEAF runtime handles any polygon through mist, but the ME has **no UI** for a non-quad zone, so
  whether it preserves or flattens the shape is unknown. If it flattens it, the action should refuse
  above four rather than warn.
- `add_map_drawing` — place a line and a textbox on the **Blue** layer, and check red cannot see them.
- The **rebuild**: build the mission from its folder again and confirm the drawing is still there. That
  is the entire reason drawings are not left to the editor.

## 2b. Measure the six drawing shapes that no mission here contains

`FEAT-MCP-MUTATION-ACTIONS` ticket 07 ships three shapes — line, rect, textbox — because those are the
only field layouts present in any `.miz` in this repository. `circle`, `oval`, a free-form `Polygon`,
`arrow`, `chevron` and `icon` are **refused by name** rather than guessed, since inventing a layout is
what `FIX-MAPRESOURCE-KEY` and `FIX-COMMUNITY-SOUNDS-PRUNED` both cost.

Five minutes in the editor closes it: draw **one of each** on any layer, save, and send the `.miz` (or
just its `mission` file). Each shape is then a table entry, not an investigation.

## 3. Confirm a rebuilt checklist picture is not served stale

[`FEAT-ASSIST-FOLLOWUP` 01](.backlog/FEAT-ASSIST-FOLLOWUP/PRD.md) shipped the fix: a checklist image's
file name now carries 8 hex of its own content hash, so DCS cannot serve a cached bitmap under a name
it already knows. **No unit test can see DCS's resource cache**, hence this flight.

Edit a checklist step's text, rebuild, and fly it **without restarting DCS**. The old bug read as
*"the text is wrong, but only on the first image"*.

## 4. Confirm the staggered script loading

[`FEAT-CUSTOM-SCRIPT-LOAD-DELAY`](.backlog/FEAT-CUSTOM-SCRIPT-LOAD-DELAY/PRD.md) is ✅ and verified
against the real Foothold Caucasus 4.4.1 `.miz`, but never watched in game.

Build an adopted Foothold and check `dcs.log`: 6 scripts at start, 5 around +3 s, AIEN at +12 s. The
thing that matters is AIEN seeing a **populated** world — Foothold creates part of its groups from
t+2 s onwards, and loading AIEN at t=0 shows it an empty one **with no log error**.

## 5. Fly the F-14B(U) startup checklist

[`FEAT-ASSIST-AUTHORING` 06](.backlog/FEAT-ASSIST-AUTHORING/tickets/06-f14b-manual.md) — written,
resolved, and its four automatic steps already verified in game on 2026-08-03. All that is left is
your verdict on whether the procedure matches what you actually do.

## 6. The smoke harness's remaining slice

[`FEAT-DCS-SMOKE-HARNESS`](.backlog/FEAT-DCS-SMOKE-HARNESS/PRD.md) — locate, launch, load, quit.
`net.load_mission` and `Sim.exitProcess` are **measured present** and `isServer()` is true in
single-player, so nothing technical blocks it. Starting DCS is the part only you can do.

This is the lever that pays: run once on 2026-08-06 it closed `FEAT-COMBATZONE-MENU-COALITION` (open
since July) and turned `Disposition` from assumed into existing.

## 7. Test a token on the fiddle-server port

[`FIX-SECREV2-EXPIRED-DEFERRALS` 02](.backlog/FIX-SECREV2-EXPIRED-DEFERRALS/PRD.md) — **VMR-013**, and
it is a live security hole rather than a nicety: the port executes arbitrary Lua from unauthenticated
HTTP, and with `cors='*'` plus a GET channel, any web page visited while the hook is installed gets
code execution.

It was deferred for want of a DCS to test a token on, over the transport the smoke harness speaks
through — and the harness has since run in game, so the dependency is live.

## 8. Two lower-priority pilot items

- [`FEAT-ASSIST-FOLLOWUP` 02](.backlog/FEAT-ASSIST-FOLLOWUP/PRD.md) — whether an
  `a_cockpit_highlight` leaks into another cockpit. Needs **a second pilot**; the per-session id
  exists for it and has never been exercised.
- [`FEAT-ASSIST-FOLLOWUP` 03](.backlog/FEAT-ASSIST-FOLLOWUP/PRD.md) — an F-16C pilot's review of the
  six shipped steps. The engine was flown and works; the *procedure* was never checked by a pilot.
