# FIX-MCP-EDITOR-ROUNDTRIP — what the Mission Editor does to what the MCP writes

Status: ⬜ ready

Origin: the 2026-08-15 DCS session, item 2 of `DCS-SESSION-TODO.md`. Six mutations were written into a
copy of the demo mission through the MCP, David opened it in the Mission Editor and saved it, and the
before/after tables were compared field by field.

## Why it took a human and a running editor

Every one of these actions is covered by unit tests, and every test passes. The tests assert what the
action **wrote**; they cannot assert what DCS **keeps**. Three of the six mutations survived untouched,
one was silently discarded, and one was overwritten by a recalculation — none of which any test in this
repository could have seen.

That is the entire value of the round-trip, and it is why ticket 02 of `FEAT-MCP-MUTATION-ACTIONS`
called it *"the only half no test can cover"*.

## What survived, and what did not

| Mutation | Verdict |
|---|---|
| Group moved 6 km, route attached | ✅ preserved exactly |
| Group renamed | ✅ preserved |
| Loadout cut to 6 stations | ✅ preserved |
| Trigger zone reshaped to **6 vertices** | ✅ **preserved** — see below, this settles an open question |
| Line + textbox on the Blue layer | ✅ both preserved |
| Waypoint removed, another ETA-relocked | ✅ the mission saves, so the relock was right |
| **`Bombing` task on a new waypoint** | ❌ **silently deleted by the editor** |
| **Unit heading set to 275°** | ⚠️ **overwritten** by DCS's own recalculation |

### The zone answer, which was an open question rather than a defect

`edit_zone` warns that the editor "only draws 4-point quad zones" and asks for a round-trip to find
out whether a 6-vertex polygon survives. **It does** — all six vertices came back byte-identical. So
the action does **not** need to refuse above four, and the warning can say this is measured rather
than feared. That is ticket 04 below, and it is a documentation change rather than a fix.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [`add_task` writes an incomplete task the editor discards](tickets/01-task-params-incomplete.md) | ⬜ |
| 02 | [`edit_route add` ignores the altitude and speed it is given](tickets/02-add-waypoint-ignores-alt-speed.md) | ⬜ |
| 03 | [A heading set on a flying aircraft does not survive](tickets/03-heading-recalculated.md) | ⬜ |
| 04 | [The 6-vertex zone survives — say so](tickets/04-polygon-zone-confirmed.md) | ⬜ |

01 is the one that matters: a task the editor deletes is a flight that quietly does nothing, which is
the failure mode `FEAT-MCP-MUTATION-ACTIONS` ticket 04 named as its worst case and could not test for.

## Definition of Done

- Each defect reproduced by a test written **before** its fix, against the measured field layout.
- The seven task kinds audited against real examples, not just `bombing`.
- Full Python gate green; coverage ratchet respected.
- The round-trip re-run in the editor for 01, since that is the only thing that proves it.
