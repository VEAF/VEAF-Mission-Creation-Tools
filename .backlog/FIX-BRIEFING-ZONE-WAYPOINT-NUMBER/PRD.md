# FIX-BRIEFING-ZONE-WAYPOINT-NUMBER — every zone page of a mission briefing says which waypoint it is

Status: ✅ done

Asked by David on 2026-11-24, from a Google Slides capture of the *Operation Flying Whales* briefing (Syria): the overview map labels the route `W4/H4 TALBISEH`, and the zone page of Talbiseh carried `(WP4)` in its title, typed by hand. The generator wrote no waypoint number on a zone page, only `Point : TALBISEH du plan de vol`.

`objective_notes` (`mission_briefing_worker.py`) now writes `Point : W4/H4 — TALBISEH du plan de vol`: the numbers are the ones the overview map prints (planes `W`, helicopters `H`, counted from 1 on each route). A zone whose point no route carries keeps the name alone; a zone with no point has no line.

One ticket.
