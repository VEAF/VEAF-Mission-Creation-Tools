# FIX-AIR-SLOT-HEADING — an air-start player slot flew north whatever its heading

Status: ✅ done

Asked by David on 2026-10-12, after the FIX-FARP-PLACEMENT test mission.
`add_player_slot` with `start: air` and `heading_deg: 180` gave an A-10 that flew north: the heading was written on the unit, and DCS ignored it.

The Mission Editor's own files gave the cause: it orients an air start toward its second waypoint (known limitation `air-start-flies-toward-its-second-point`).

| # | Ticket | Status |
|---|--------|--------|
| 01 | [An air start carries its heading on a second waypoint](tickets/01-second-waypoint.md) | ✅ |

One branch, one PR.
