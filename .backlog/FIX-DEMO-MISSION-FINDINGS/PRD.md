# FIX-DEMO-MISSION-FINDINGS — what building the v6 demo mission found

Status: ⬜ ready

## Origin

On 2026-10-05 the new demo mission `VEAF/VEAF-Demo-Mission-v6` (Caucasus) was built from an empty folder with veaf-tools 6.27.0 and the `veaf-mission-mcp` actions (in-process, develop at `3c257c96`), reviewed, then flown once in DCS with `dcs-bridge` probing the running mission.
Its `docs/retours-vmct.md` lists 15 findings; this lot carries the ones that belong to VMCT, grouped by what they break.

The test bench is `D:\dev\_VEAF\VEAF-Demo-Mission-v6`: `tools/verify.py` checks a build, `tools/make_test_mission.py` makes the bridge mission, and the demo's `CLAUDE.md` says how it is rebuilt.
Every workaround the demo carries is named in the tickets, so that each fix can remove one.

**Two findings stopped the whole VEAF configuration with nothing in `validate` or the build to say so** (tickets 01 and 03), and a third turns any such error into a total outage (02).
They come first.

## The findings

| # | Defect | Measured |
|---|--------|----------|
| [01](tickets/01-user-menu-lua-action-breaks-config.md) | A `lua` action in `modules.RADIO.user_menus` is written as a bare reference evaluated in `veaf-config.lua`, before `mission-script.lua` defines it | `attempt to index global 'demo' (a nil value)` at `veaf-config.lua:62`; everything after it in the config never ran |
| [02](tickets/02-one-module-init-error-stops-the-config.md) | One module's init error stops the whole `veaf-config.lua` | a CTLD init error left 0 combat zones registered, `#veafInterpreter` carriers never replaced, no QRA, assets or Skynet |
| [03](tickets/03-ctld-config-inline-comment.md) | `ctld-config.yaml`: an end-of-line comment is read by CTLD as part of the value; and the embedded config may lag one build | `jtacLaserCodeMax: 1686   # …` → `CTLD.lua:22287: 'for' limit must be a number` |
| [04](tickets/04-build-exits-1-after-success.md) | The build exits 1 after succeeding when stdin is closed | auto-pause `input()` → `EOFError` (`veaf_tools/app.py:87`) |
| [05](tickets/05-cargoships-spawns-nothing.md) | `-cargoships` spawns nothing, silently | from a combat-zone `#command` carrier and standalone at sea: no group, no log line after `doSpawnGroup` |
| [06](tickets/06-operation-has-no-activation-command.md) | A combat operation's radio menu has no activate / deactivate command | commands commented out at `veafCombatZone.lua:2897`, `:2913`; docs describe an « Opérations » submenu that does not exist |
| [07](tickets/07-mcp-authoring-gaps.md) | MCP gaps the demo had to script around | no `On Road` waypoint, no operation composite, no briefing-pictures action, `describe_map` without group positions, `#veafInterpreter` clear ground sized for one vehicle |
| [08](tickets/08-small-truths.md) | Small places where docs or labels say something false or nothing | `_spawn unit, name T-80` matches no type; build adds a BULLSEYE waypoint the template does not mention; carrier ops label not translated |

## Definition of done

- Tickets 01–03: each defect reproduced by a test that fails before the fix, and caught by `validate` or the build where it cannot be prevented.
- Every ticket's demo workaround removed in the demo repository, the demo rebuilt and `tools/verify.py` green, and the demo's `docs/retours-vmct.md` updated.
- Tickets 01, 02, 03 and 05 checked in DCS (the demo's test mission and bridge make it a short session).
