# FIX-COWORK-SESSION-FINDINGS — what a Cowork session taught us about building an objective mission

Status: 🔄 in-progress

Origin: Trakdah's Claude Cowork session of 2026-10-25 (VMCT 6.31.4, Caucasus, "Fire at Adler", two AJS-37 on dynamic slots, Cold War low-level strike), read from his JSON export, plus the post-mortem his assistant wrote afterwards on the route, and three requests from David.
Cowork runs the assistant in the cloud and reaches the VEAF MCP server on the user's PC through the Claude desktop app's device bridge: the first session of that kind we could read end to end.
The write-up shared with Trakdah is [trakdah-session-review.md](trakdah-session-review.md).

## Problem

The mission built and validated, but the export and the code show five defects the assistant worked around or did not see, a security question nobody could answer from what the prompt told them, no briefing in the cockpit, no say on the enemy's level, and a route designed without the terrain.

| # | What happened | Ticket |
|---|---|---|
| 1 | `build_mission_briefing` writes its pictures into the root `.miz`, not into the `missions\…_<variant>.miz` the players fly (`find_built_mission` only looks at the root and `build/`) | 01 |
| 2 | Two plan waypoints both named `COAST` (out and back): the second replaced the first in place, silently, and W6 vanished (`waypoints_injector_worker.py`, replace-by-name) | 02 |
| 3 | `mission_path: ~/Documents/…` → `FileNotFoundError: '~\\Documents\\…'`: no `expanduser` in the MCP actions | 03 |
| 4 | The deck's "Diversion fields" line lists the departure field, and nothing lets the assistant set it (`mission_briefing_worker.py`, every airfield of the picture) | 04 |
| 5 | A COLD_WAR 1987 mission offers all 61 dynamic-slot types (F-16C, F/A-18C, AH-64D, JF-17…): the era filter only applies to `spawnables` | 05 |
| 6 | The build puts the flight on channel 2 of the Viggen, not channel 1 (the assistant's report; not measured) | 06 |
| 7 | "Security on, no hashes / hashes / off": nothing said what is locked, who passes, that the shipped password is public, or how a non-developer gets a SHA-1 | 07 |
| 8 | The briefing exists as a deck and DCS briefing pictures, nothing in the kneeboard (David) | 08 |
| 9 | The enemy's skill is never asked; `add_group` writes `"Average"` for every ground unit (David) | 09 |
| 10 | The route went out over the sea where a Viggen would use the relief: the prompt measures the exposure of the chosen route but never asks to design it after the aircraft's doctrine or to compare candidates; topo basemap only "in a desert" | 10 |
| 11 | The route was hand-edited in `waypoints.yaml` through `edit_mission_file` — where ticket 02's loss happened | 11 |
| 12 | `create_combat_zone` with statics gives no clear-ground warning, so the assistant probed with a vehicle group to find clear ground for the tanks | 12 |
| 13 | Nothing in the documentation about Cowork, its two-sided folder access, or how to use it with VMCT (David) | 13 |

Not a defect: the scaffold's "Access denied" on `Documents` — the assistant targeted another Windows profile than the one the MCP server runs under (the build log shows the user's own temp folder).

## Tickets

- [01 — Briefing pictures in every weather variant](tickets/01-briefing-pictures-in-variants.md)
- [02 — Two plan waypoints with the same name](tickets/02-duplicate-waypoint-names.md)
- [03 — `~` in a mission path](tickets/03-expand-user-in-paths.md)
- [04 — The deck's diversion fields](tickets/04-deck-diversion-fields.md)
- [05 — Dynamic slots filtered by era](tickets/05-dynamic-slots-by-era.md)
- [06 — The Viggen's channel 1](tickets/06-viggen-channel-one.md)
- [07 — Security explained, and a hash command](tickets/07-security-explained.md)
- [08 — The briefing in the kneeboard](tickets/08-briefing-kneeboard.md)
- [09 — The opposition's skill](tickets/09-opposition-skill.md)
- [10 — Route planning in the objective prompt](tickets/10-route-planning-prompt.md)
- [11 — `set_route`: write a flight plan in one action](tickets/11-set-route-action.md)
- [12 — Clear ground for statics](tickets/12-statics-clear-ground.md)
- [13 — Cowork in the AI assistant documentation](tickets/13-cowork-documentation.md)

## Needs David's DCS

Tickets 08 (the kneeboard pages shown, JPEG read) and 09 (what a ground unit's skill changes, the skill a `#veafInterpreter` battery gets) end with a measurement in game.

## Out of this lot

An interactive planning map — the route dragged on a page, read back, exposure drawn per leg, possibly a UI served by the MCP server — proposed by Trakdah's assistant.
It depends on what Cowork displays (map tiles in a published page, an interface from a local MCP server), which nobody has checked; tickets 10 and 11 already give the "I propose, you correct, I measure" loop.
To reopen once that is known.
