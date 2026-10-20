# FEAT-INSPECT-BUILT-MISSION — check a built mission through an action, not a shell

Status: ⬜ ready

Origin: David's end-to-end test on 6.31.1, 2026-10-20 — OpenCode with MiniMax M3.1 Flash (free), on a Windows sandbox set up like any user's.
After more than an hour the conversation had reached 688k tokens of context, and the AI was unzipping the built `.miz` in a shell, writing its own regexes on the `warehouses` file, failing, and trying again.

## Why it does that

The authoring guide's last step tells it to.
*Finish: validate, then build* says to read the build's counters, then "open the built `.miz` and check what the mission is about": the weather of two variants, the dynamic slots carrying presets and a BULLSEYE, the tanker's tasks, the combat-zone carriers and statics.

No action reports any of that on a built mission:

| Action | What it reports |
|---|---|
| `describe_mission` | groups and trigger zones (takes a `.miz` or a folder) |
| `describe_units` | units, loadouts, routes |
| — | warehouses, dynamic slots per airbase, injected presets, bullseye, weather variants |

So an AI with a shell parses the archive itself, one try at a time, each try staying in its context; an AI without one (Claude Desktop in chat mode) cannot do the check at all.

## Decision (David, 2026-10-20)

1. A new action reads the built `.miz` and reports, compactly, exactly what the guide asks to check.
2. The guide sends the AI to that action, and says once, in general: never unzip or parse a `.miz` or a mission file in a shell; when no action answers a question, say so to the user instead of improvising.

Left out until David's OpenCode export is read: the AI also said "the presets report is empty".
Whether that is a build defect or its own failed parsing is not known yet; it gets its own ticket if it is real.

## Tickets

- [01 — `inspect_built_mission`](tickets/01-inspect-built-mission.md)
- [02 — The guide checks through the action, never through a shell](tickets/02-guide-no-shell-parsing.md)
