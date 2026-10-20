# 01 — `inspect_built_mission`

Status: ✅ done

A read-only MCP action on a built `.miz` (or a mission folder, which it resolves to its built `.miz`) that returns what the guide's post-build check needs, and nothing more:

- per airbase and FARP: coalition, the aircraft types offered as dynamic slots, and the warehouse template it is linked to;
- per aircraft type: whether presets were injected, and how many channels per radio;
- the bullseye of each coalition;
- per weather variant: the weather that differs between variants (clouds, wind, visibility, time);
- tankers and AWACS: their tasks and frequencies;
- the counters the build reports (presets injected, waypoints, warehouse links, variants), so a zero is visible.

Compact by design: one line per item, no raw mission table, so the answer stays small in the AI's context.
A field the mission does not have is reported as absent, not skipped.

Done when:
- the action is in the catalogue, with tests on a built test mission covering each section and an absent section;
- the MCP action catalogue page (`doc/`) lists it, in both languages;
- an answer on the shipped default mission stays under a size the test asserts.

## Done (2026-10-20)

`veaf_mission_mcp/inspect_built.py`, tested on the built demo mission and on a bare copy (every section `absent`); catalogue page in both languages.
Compact by grouping: the template types once per side, each base "every blue template linked (61)" rather than the list again, presets grouped by radio layout.
Measured: the shipped default mission built (standard, Syria, FARP) reads 5 169 characters; listing each base's types made 40 245.
