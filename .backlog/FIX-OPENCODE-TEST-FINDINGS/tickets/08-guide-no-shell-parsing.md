# 02 — The guide checks through the action, never through a shell

Status: ✅ done

In `veaf_mission_mcp/data/authoring-guide.md`, *Finish: validate, then build*: "open the built `.miz` and check" becomes "call `inspect_built_mission` and check".

And one general rule, near the top where the guide says to ground every answer in the oracle: never unzip, grep or parse a `.miz` or a mission file in a shell — every read goes through an action (`describe_*`, `read_mission_file`, `inspect_built_mission`).
When no action answers a question, tell the user what could not be checked rather than improvising a parser.

The two mission prompts (`data/mission-prompts/`) are checked for the same instruction and aligned if they carry it.

Done when: the guide and prompts say it, and nothing in them still asks to open a `.miz` by hand.

## Done (2026-10-20)

The guide's rule sits right after the oracle section; *Finish* and the two prompts' checklists (both languages) check through `inspect_built_mission`, `describe_mission` and `describe_units`; a test fails when any of them asks to open a `.miz` by hand or names `veaf_libs/data/`.
