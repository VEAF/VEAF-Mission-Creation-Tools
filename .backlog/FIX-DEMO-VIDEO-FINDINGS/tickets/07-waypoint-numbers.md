# 07 — Waypoint numbers in the briefing do not match the route

Status: ✅ done

Measured on Martinho's folder: `waypoints.yaml` declares INGRESS, IP, **BULLSEYE**, NOEUD, COLONNE, EGRESS, OVDA — the AI added BULLSEYE third after seeing the build inject its own at 20 000 ft. The briefing's text (`Detruire le noeud (W3)`, `la colonne (W4)`, `Rentrer a Ovda (W6)`) and the F10 labels (`W3 NOEUD`, `W4 COLONNE`) were written before, for a route of six points; the route has seven, and the deck's flight-plan page numbers NOEUD 4, COLONNE 5, OVDA 7.
The prompt asks for a render check ("each waypoint number matches the route") that a machine without PowerPoint cannot do, and nothing in `build_mission_briefing` compares them.

Fix:

- The guide says to declare BULLSEYE **last** (the build already appends its own at the end when none is declared), so it does not shift the numbers; and the prompt says to name a waypoint rather than number it, or to number after the route is final.
- `build_mission_briefing` compares every `W<n>` (and `WP<n>`) of the words it receives with the route of the built mission and warns on a number past the route's end or on a number whose name the same sentence contradicts.

Done when: a test builds a deck with a text citing a waypoint that does not exist, and the warning names it; a route-consistent text gives none.

## Result

Fix: the prompt and the guide say to declare the BULLSEYE last and to cite a waypoint by its name; `mission_briefing_worker._waypoint_warnings` compares every `W<n>` of the words with the route of the built mission (past its end, or contradicted by the point the same line names) and returns warnings. Tests: `TestWaypointNumbers` on the fixture's route POTI, KHOBI, BULLSEYE.
