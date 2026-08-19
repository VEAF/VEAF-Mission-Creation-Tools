# 02 — Name the holed table, by path

Status: ✅ done — 2026-08-19. Holes are reported by path — a `validate` warning and a build-time
log line, both through `t()`. Two corrections came out of building it, both caught by this lot's own
principle: an empty container is normalised to an empty **list** rather than having its key removed
(`tasks = {}` is what DCS writes on every waypoint with no task, so dropping it would change a mission
nobody touched), and re-serialising a locale JSON to add one key reordered 17 lines of it.
Type: feat
Files: the normaliser from ticket 01, its callers, tests

## Why closing a hole cannot be silent

Normalising a holed container **renumbers** it: `[1], [3]` becomes `[1], [2]`. That is the right
outcome — it repairs what a hand edit broke, and it is what lets the build finish — but it is still a
change to the file, and this lot exists because writers that change what they were not asked to are
how three defects reached production unnoticed. A normaliser that silently closes holes would be one
more of them.

## What the silence cost, measured 2026-08-18

Building `verify-mission-c` produced three holed tables, and each surfaced somewhere else:

| Holed table | Where the build died | Related to the edit? |
|---|---|---|
| `…plane.group` numbered `1,3,4` | `group_insertion.max_ids` | yes |
| `…group.1.units` numbered `[3]` | same | no |
| `…group.1.route.points` numbered `[2]` | `waypoints_injector._inject_waypoints_into_group` | **no** |

Three debugging rounds, and the message named the table in none of them —
`AttributeError: 'int' object has no attribute 'get'` points at the reader, never at the data.

## What ships

The normaliser reports each hole it closed as a **path**:

```
coalition.blue.country[1].plane.group: keys 1, 3, 4 -> 1..3
coalition.blue.country[1].plane.group[1].units: keys 3 -> 1..1
```

Surfaced where a person will see it: a build-time warning, and in the MCP's `validate_mission` result.

## Where this belongs — decided

`FIX-MCP-AUTHORING-GAPS` ticket 02 asked for the same reporting in `validate_mission`. It belongs
**here**, because here is where the holes are detected — a check living in `validate_mission` alone
would say nothing to the mission maker who never runs it, and would duplicate the traversal. The MCP
surfaces what the normaliser found rather than looking for it a second time. Cross-referenced in that
lot's ticket.

## Done when

- Every hole closed is reported with its full path and its before/after keys
- A build over a holed mission prints them rather than dying, or dying without saying where
- A well-formed mission reports nothing at all — no noise on the nominal path
- `validate_mission` surfaces the same list rather than re-deriving it
