# FEAT-BFR-V6-SUPPORT — what VMCT needs so BFR can plug its own script layer into v6

Status: 🔄 in-progress

## Where it comes from

BFR (Bullseye Francophone, Sharko) runs four campaigns on VMCT 5.103.3, with a layer of its own scripts (`bfr-*.lua`) on top and a `veafPatches.lua` that replaces about fifteen VMCT functions at load.
Studied on 2026-10-27 from the two public campaigns, `Operation-Bluestorm-V2` and `Operation-SeaShepherd-V2`.
David decided the same day:

- VEAF takes into VMCT what serves every mission: two security fixes, the F10 menu defects in multiplayer;
- VEAF adds what BFR needs to plug its layer in: a carrier option, a module configured by the build and initialized by the mission, the weather welcome switch, named points from a script, the v5 converter, the CTLD 2 contract;
- VEAF documents it;
- BFR ports its missions itself.

One lot, one branch, one PR, at David's request.

## Tickets

| # | ticket | kind |
|---|---|---|
| 14 | [`test-lua` finds the Lua 5.1 shipped with DCS](tickets/14-test-lua-dcs-interpreter.md) | tooling |
| 01 | [Whitelist of the text typed after a security-bypassing shortcut](tickets/01-bypass-shortcut-whitelist.md) | security |
| 02 | [Validate the SRS text-to-speech parameters before the system command](tickets/02-stts-parameters.md) | security |
| 03 | [F10 menu in multiplayer: commands bound to a live pilot, no global broadcast by mistake](tickets/03-radio-live-pilot.md) | fix |
| 04 | [Submenu reserved to some groups](tickets/04-radio-group-submenu.md) | feature |
| 05 | [Submenu per pilot in multi-slot groups](tickets/05-radio-per-pilot.md) | feature |
| 06 | [Combat zones: unknown name without a global message, menu rebuilt without duplicates](tickets/06-combat-zone-fixes.md) | fix |
| 07 | [Carrier: option not to start the VEAF 60 s loop](tickets/07-carrier-no-scheduler.md) | plug-in |
| 08 | [CTLD 2: document what BFR needs](tickets/08-ctld2-contract.md) | plug-in |
| 09 | [Named points declared from a script](tickets/09-named-points-from-script.md) | plug-in |
| 10 | [v5 converter: missions with their own script layer](tickets/10-v5-converter-custom-layer.md) | plug-in |
| 12 | [Module loaded and configured, initialized by the mission](tickets/12-initialized-by-mission.md) | plug-in |
| 13 | [`mission.yaml` switch for the VEAF weather welcome](tickets/13-weather-welcome-switch.md) | plug-in |
| 11 | [Page "Port a mission with its own script layer" (FR + EN)](tickets/11-doc-custom-script-layer.md) | documentation |

Order: 14 first (it makes the Lua suite run on David's machine), then 01-02, then the table's order.

## Decided

- **a) Ticket 12's key: `initialized_by_mission: true`.**
  Alternatives weighed: `initialize: false` sits next to the existing `init:` block of the same module and reads as its negation; `self_init` says nothing to a mission maker.
  `initialized_by_mission` says who does it, and its default (`false`) is today's behaviour.
  It is accepted under `modules.<ID>`, `external_modules.skynet`, `external_modules.csar` and `community_scripts.ctld`.
- **b) The second initialization path is cut too.**
  `veaf.registerModule` stores every module in a registry read only by `veaf.initialize()`, which the generated `veaf-config.lua` never calls (checked 2026-10-27, `docs/agents/module-initialisation.md`).
  A mission that calls `veaf.initialize()` itself would still start the module, so the build writes `veaf.setConfig(<ID>, "initializedByMission", true)` and `veaf.initialize()` skips such a module.
- **c) Bypass shortcuts declare their own whitelist** (`VeafAlias:setAllowedOptions`), so a mission's own shortcut can declare its own; a bypass shortcut without one accepts no trailing text.
- **d) Security details stay out of public text** (commit messages, PR, changelog) until the fix is released.

## In-game checks left

- 03 to 05 with at least two players in one group;
- 01 on a server, with real markers;
- 07, 12 and 13 on a converted BFR part.
