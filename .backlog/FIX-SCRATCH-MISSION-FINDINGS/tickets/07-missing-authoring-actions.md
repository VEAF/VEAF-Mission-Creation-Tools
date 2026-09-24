# 07 — Actions the agent had to replace with hand-written Lua

Status: ⬜ ready
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
