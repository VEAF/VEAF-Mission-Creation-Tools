# FIX-MCP-AUTHORING-GAPS — four defects an agent met authoring one real mission

Status: ⬜ ready

Origin: building `test/veaf-tools/verify-mission-c` on 2026-08-18 (`CHORE-ISSUE-VERIFY-SESSION`). The
mission was authored almost entirely through the MCP actions, which is the point of them. Three times
the actions could not do the job, so the agent opened `src/mission/mission` and edited Lua by hand —
and **every corrupted build of that session came from those hand edits**:

- a group removed by hand left the list numbered `1,3,4`. Lua loads that without complaint; the build
  dies on `AttributeError: 'int' object has no attribute 'get'`, from a parser that only converts a
  table to a list when its keys are `1..n`. The message never names the offending table, and each
  hole fixed reveals the next one — it took three rounds (`group_insertion.max_ids`, then
  `waypoints_injector`) to get a green build.
- a renumbering regex written to repair the first hole matched *any* indentation and silently
  renumbered `units` and `route.points` too, creating two more holes of the same kind.

So this lot is not about convenience. **An action that does not exist is an invitation to corrupt the
mission file**, and the corruption is invisible to Lua, invisible to `git diff`, and reported by a
message that points nowhere near the cause.

The fourth defect is of a different kind and worth more attention than the three others: the action
worked, wrote a valid mission, and produced aircraft that could not fly. It cost two rounds of a DCS
session and was twice attributed to whatever the check under test happened to be about.

## The four holes

| # | What was missing | What the agent did instead |
|---|---|---|
| [01](tickets/01-combat-zone-yaml-insert-point.md) | `create_combat_zone` appends its `combat_zones[]` entries after the file's trailing comment block | left it, then moved the entries by hand |
| [02](tickets/02-remove-group.md) | no action removes a group | deleted the Lua block by hand — three corrupted builds |
| [03](tickets/03-folder-targets-for-editors.md) | `edit_route` and the other `miz_path` actions refuse a mission **folder** | hand-wrote a 3-waypoint tanker track and an `Escort` task into `src/mission/mission` |
| [04](tickets/04-add-air-group-zero-fuel.md) | `add_air_group` writes `fuel = 0` | nothing — it was not noticed until the aircraft flew into the ground, twice |

## Definition of done

- [ ] A combat zone created into an existing `combat_zones:` list lands **inside** it, wherever the
      comments sit
- [ ] A group can be removed through an action, and removal renumbers what it leaves behind
- [ ] `validate_mission` reports a holed numeric table by **path**, so the build never has to
- [ ] The editing actions accept a mission folder wherever `add_group` already does
- [ ] Each of the three is covered by a test built from the shape that broke here, not from a
      synthetic one
