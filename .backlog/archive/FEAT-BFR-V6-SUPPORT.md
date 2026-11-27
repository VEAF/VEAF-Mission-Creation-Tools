# FEAT-BFR-V6-SUPPORT — what VMCT needs so BFR can plug its own script layer into v6

Status: ✅ done (#1203) · archived 2026-11-24

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
| 14 | [`test-lua` finds the Lua 5.1 shipped with DCS](FEAT-BFR-V6-SUPPORT.md) | tooling |
| 01 | [Whitelist of the text typed after a security-bypassing shortcut](FEAT-BFR-V6-SUPPORT.md) | security |
| 02 | [Validate the SRS text-to-speech parameters before the system command](FEAT-BFR-V6-SUPPORT.md) | security |
| 03 | [F10 menu in multiplayer: commands bound to a live pilot, no global broadcast by mistake](FEAT-BFR-V6-SUPPORT.md) | fix |
| 04 | [Submenu reserved to some groups](FEAT-BFR-V6-SUPPORT.md) | feature |
| 05 | [Submenu per pilot in multi-slot groups](FEAT-BFR-V6-SUPPORT.md) | feature |
| 06 | [Combat zones: unknown name without a global message, menu rebuilt without duplicates](FEAT-BFR-V6-SUPPORT.md) | fix |
| 07 | [Carrier: option not to start the VEAF 60 s loop](FEAT-BFR-V6-SUPPORT.md) | plug-in |
| 08 | [CTLD 2: document what BFR needs](FEAT-BFR-V6-SUPPORT.md) | plug-in |
| 09 | [Named points declared from a script](FEAT-BFR-V6-SUPPORT.md) | plug-in |
| 10 | [v5 converter: missions with their own script layer](FEAT-BFR-V6-SUPPORT.md) | plug-in |
| 12 | [Module loaded and configured, initialized by the mission](FEAT-BFR-V6-SUPPORT.md) | plug-in |
| 13 | [`mission.yaml` switch for the VEAF weather welcome](FEAT-BFR-V6-SUPPORT.md) | plug-in |
| 11 | [Page "Port a mission with its own script layer" (FR + EN)](FEAT-BFR-V6-SUPPORT.md) | documentation |

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

Closed on 2026-11-04 without them, at David's request: VEAF will not run them, they are BFR's to make when it ports its missions.

- 03 to 05 with at least two players in one group;
- 01 on a server, with real markers;
- 07, 12 and 13 on a converted BFR part.

## Tickets, in full

## 01 — Whitelist of the text typed after a security-bypassing shortcut

Status: ✅ done (code done; left to BFR: checked on a server with real markers)

Some marker shortcuts are usable without the mission password (`-jtac`, `-afac`, `-light`, `-smoke`, `-longsmoke`, `-signal`, `-tacan`).
The text a player types after them must only tune that shortcut's effect.

### Done when

- A test reproduces the defect and fails before the fix.
- `VeafAlias:setAllowedOptions{…}` declares, per shortcut, the options admitted after it and their strict form; a bypass shortcut without a declared list admits no trailing text.
- Trailing text holding a VEAF keyword (`_spawn`, `_cas`…) is refused.
- A refusal is whole (nothing runs), told to the marker's author only, and the refused text is never logged.
- Unchanged: the bare shortcut, `#` coordinates and `!N` delay, calls from a script, a mission with security disabled, and the documented uses (`-jtac, laser 1511`, `-smoke, color red`, `-tacan, channel 37`).
- Checked on a server with real markers (in-game).

## 02 — Validate the SRS text-to-speech parameters before the system command

Status: ✅ done

`STTS.TextToSpeech` builds a Windows command line from `freqs`, `modulations` and `name`.

### Done when

- `freqs` is a comma-separated list of numbers, `modulations` a comma-separated list of `AM`/`FM`, `name` filtered like `veafRadio._transmitViaSRS` does; otherwise nothing runs and the log says why.
- The VEAF change is recorded in `vendored.yaml`'s update steps for the script.
- Lua tests.

## 03 — F10 menu in multiplayer: commands bound to a live pilot

Status: ✅ done (code done; left to BFR: checked in game with two players in one group)

`humanUnits[x].spawned` is never reset and nothing handles a pilot leaving: when the first pilot of a group leaves, the clicks of the others stop answering.
`veaf.outTextForGroup` falls back to `trigger.action.outText`, i.e. to every player.

### Done when

- A pilot leaving his slot (`PLAYER_LEAVE_UNIT`, death, crash, ejection) is forgotten; a group's commands are bound to a pilot still present; his return rebuilds them.
- A message for a group whose group cannot be resolved is logged, never shown to everyone.
- Lua tests; checked in game with two players in one group.

## 04 — Submenu reserved to some groups

Status: ✅ done (code done; left to BFR: checked in game with two players in one group)

`groupFilter` exists per command only.

### Done when

- A submenu accepts a group filter; groups it rejects do not see the submenu nor anything under it.
- Lua tests; checked in game.

## 05 — Submenu per pilot in multi-slot groups

Status: ✅ done (code done; left to BFR: checked in game with two players in one group)

### Done when

- `veafRadio.addSubMenuPerPilot`: in a group, each present pilot gets the menu's entries under a submenu with his player name, bound to his unit, so the answer can go to him alone (`veaf.outTextForUnit`); a pilot alone gets them directly.
- Lua tests; checked in game with two players in one group.
- A demo mission step needs a mission script calling `addSubMenuPerPilot`: left to a follow-up in VEAF-Demo-Mission-v6.

## 06 — Combat zones: unknown name, menu rebuilt without duplicates

Status: ✅ done

### Done when

- `veafCombatZone.GetZone` on an unknown name only logs.
- `veafCombatZone.buildRadioMenu()` called twice leaves one menu.
- Lua tests.

## 07 — Carrier: option not to start the VEAF 60 s loop

Status: ✅ done (code done; left to BFR: checked on a converted BFR part)

### Done when

- `modules.CARRIER.init.operations_scheduler: false` initializes the carriers and their menu without starting `operationsScheduler`.
- Absent, the generated call is unchanged.
- Python and Lua tests, `MISSION_YAML_REFERENCE` FR/EN; checked on a converted BFR part.

## 08 — CTLD 2: document what BFR needs

Status: ✅ done

BFR reads CTLD v1 internals (`ctld.builtFOBS`, `pickupZones`, `logisticUnits`, `completeAASystems`, `ctld.addCallback`).

### Done when

- The page of ticket 11 maps each of these reads to the CTLD 2 event or manager that replaces it.
- No VEAF interface is added unless a BFR need is not covered (the exact list is a question to Sharko).

## 09 — Named points declared from a script

Status: ✅ done

### Done when

- A public function declares a batch of named points from a script, before or after `initialize()`.
- Lua tests; documented in ticket 11's page.

## 10 — v5 converter: missions with their own script layer

Status: ✅ done

### Done when

- Re-measured on 6.32 first.
- `scriptsToLoad` of `veafDynamicConfig.lua` becomes `custom_scripts:`, in order.
- Modules are detected in every script of `src/scripts`, not only `missionConfig.lua`.
- A setting read from data instead of written as a literal is reported.
- Python tests.

## 11 — Page "Port a mission with its own script layer" (FR + EN)

Status: ✅ done

### Done when

- `doc/mission-maker/` page, FR + EN, in the `nav`, with BFR as the example: one interface file, `custom_scripts:`, `module_settings:`, modules initialized by the mission, v5 functions and tables that changed, MiST → v6, CTLD 2 contract, new radio functions, v6 defaults that change gameplay, what to test in game.
- `known-limitations.yaml` entries for what the lot does not fix.
- Support bot index refreshed.

## 12 — Module loaded and configured, initialized by the mission

Status: ✅ done (code done; left to BFR: checked on a converted BFR part)

A module active in `modules:` is initialized by the generated `veaf-config.lua`; a mission layer that initializes it too gets it twice.
`false` is no answer for SKYNET and CTLD: it also drops the community script.

### Done when

- `initialized_by_mission: true` (PRD decision a) keeps the script and the configuration, and emits no `initialize()` call; accepted under `modules.<ID>`, `external_modules.skynet`, `external_modules.csar`, `community_scripts.ctld`.
- The registry path is cut too: `veaf.initialize()` skips such a module.
- Python and Lua tests, `MISSION_YAML_REFERENCE` FR/EN; checked on a converted BFR part.

## 13 — `mission.yaml` switch for the VEAF weather welcome

Status: ✅ done (code done; left to BFR: checked on a converted BFR part)

The switch already existed and was documented, `modules.WEATHER.welcomeBrief: false`, and it was inert: the build writes it with `veaf.setConfig` and calls `veafWeather.initialize()` without an argument, which only read its argument (measured 2026-10-27).
No new key, then: the root cause is fixed.

### Done when

- `veafWeather.initialize()` without an argument reads the mission's `welcomeBrief` setting.
- Lua and Python tests; checked on a converted BFR part.

## 14 — `test-lua` finds the Lua 5.1 shipped with DCS

Status: ✅ done

DCS ships a real Lua 5.1.5 as `<DCS install>\bin\luae.exe`; the runner only looked on PATH and in `C:\Program Files (x86)\Lua\5.1`.

### Done when

- On Windows, after the current candidates, the runner reads the DCS install path in the registry (`HKCU\Software\Eagle Dynamics\DCS World`, then `DCS World OpenBeta`, value `Path`) and tries `bin\luae.exe`, version-checked like any other candidate.
- The help message and `doc/TESTING.md` (FR + EN) say so, and say that `--coverage` still needs luacov on that interpreter's `package.path`.
- Python tests.
