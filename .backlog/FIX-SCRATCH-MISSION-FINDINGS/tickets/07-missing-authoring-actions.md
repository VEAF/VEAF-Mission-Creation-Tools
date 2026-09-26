# 07 — Actions the agent had to replace with hand-written Lua

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/` (new actions), the `actions.py` catalogue,
`doc/mission-maker/AI_ASSISTANT_CATALOG*.md`, tests

`FIX-MCP-AUTHORING-GAPS` put it plainly: an action that does not exist is an invitation to corrupt the
mission file. On GermanyCW-v6 the agent patched `src/mission/mission` through a Lua serializer for:

1. **Flight tasks and commands.** `edit_route` has a closed set (orbit, land, attack_group, bombing,
   engage_targets_in_zone, set_frequency, switch_waypoint). Missing for a support flight: `Tanker` and
   `AWACS` (enroute tasks), `ActivateBeacon` (TACAN channel / mode / callsign / bearing, needs the unit
   id), `EPLRS`, `SetUnlimitedFuel`, `Escort` (needs the escorted group id — why GermanyCW dropped its
   tanker escorts). Without them a "tanker" made by `add_air_group` does not refuel anyone.
2. **Mission date and start time.** The synthetic blank mission is dated 2016; a Cold War mission
   wants 1980.
3. **Bullseye per coalition.** `describe_map` reads them, nothing writes them.
4. **Briefing texts**: `sortie`, `descriptionText`, `descriptionBlueTask/RedTask/NeutralsTask`, the
   l10n dictionary handled (`FEAT-BRIEFING-METAR` found the prose lives there in editor-saved missions).
5. **`describe_units` on a folder.** Refused with `[Errno 13] Permission denied` on the directory,
   while every write action accepts a folder: the agent cannot read back what it just wrote.

## Done when

- Each action exists, validates its parameters (TACAN channel 1–126, X/Y…), is in the catalogue and
  the AI catalogue doc, and has a test
- GermanyCW-v6's tankers, AWACS, date, bullseye and briefing can be recreated with actions alone

## Outcome (PR 3)

1. `edit_route` tasks `tanker`, `awacs`, `set_unlimited_fuel`, `eplrs`, `activate_beacon`, `escort`,
   shapes read out of 401 missions under `D:\dev\_VEAF` (Tanker 855, AWACS 560, ActivateBeacon 874,
   EPLRS 12 772, SetUnlimitedFuel 1 390, Escort 599). TACAN frequency rule derived from every beacon:
   961 + channel MHz for X 1-63 / Y 64-126, 1087 + channel for X 64-126 / Y 1-63; system 3 on a ship,
   4 (X) / 5 (Y) airborne.
2. `set_mission_date` (date, start time on the theatre's clock).
3. `set_bullseye`.
4. `set_briefing`; `write_mission_folder` now writes `l10n/DEFAULT/dictionary` back (only when it
   changes), which a folder edit of dictionary-held prose needed.
5. `describe_units` reads through `open_mission`, so a folder works; a missing target is now a
   `ValueError` like every write action's.
- Bench: on a copy of GermanyCW-v6, a KC-135 tanker with TACAN 30Y and unlimited fuel, an E-3A AWACS,
  two F-15C escorting it with EPLRS, the 1980-06-01 09:30 date, the blue bullseye and a briefing, all
  through the actions; the build keeps them (`Tanker`, `ActivateBeacon` in the `.miz`).
