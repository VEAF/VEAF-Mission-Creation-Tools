# What to do next time DCS is running

Everything the backlog is waiting on that **needs DCS started** — nothing here can be done from a
keyboard on a workstation without the game. Each item says what to run, what to look at, and what it
unblocks, so a session can be worked through without re-reading the whole backlog.

**Tick a line off by deleting it**, and update the ticket it names. `.backlog/README.md` stays the
source of truth for scope and status; this file is only the running order for a session in front of
the game.

Written 2026-08-12.

---

## 1. Capture the parking slots — 5 min per map

Unblocks [`FEAT-MCP-MUTATION-ACTIONS` 09](.backlog/FEAT-MCP-MUTATION-ACTIONS/tickets/09-add-air-group.md)
(*"put a two-ship of F-16s on the ramp at Incirlik"*), which cannot start without this data.

Same kit as the airbase captures of `FEAT-AIRDROMES-RUNTIME-SOURCE`: load a bridge mission, start
`dcs-serve`, then:

```bash
veaf-tools capture-map --parking --out-dir veaf_build/dcs_data
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
