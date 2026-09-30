# 01 — Render the briefing map from a mission folder

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/` (a renderer module, a `veaf-tools mission briefing-map` command, a
`render_briefing_map` MCP action), tests, mission-maker doc, AI catalogue doc

## Origin

Prompt §4.13, applied by hand on GermanyCW-v6 (2026-09-25) and Caucasus-v6 (2026-09-29). See the PRD.

## Measured

- What both hand-made maps draw, all of it readable from the folder: bases with slots (warehouses +
  `exclude_airports`), FARPs, support race-tracks (first two route points of the `ASSETS` groups), CAP
  templates (`cap_missions` → `OnDemand-*` routes), QRA circles (trigger zone radius), combat zones
  numbered in `combat_zones[]` order, training zones (one letter per family), sanctuary polygons
  (`polygon_units`), carriers, bullseye.
- What is not in the data: the **front line**. Both missions hard-coded it (GermanyCW: a point list;
  Caucasus: midpoints between facing bases). It needs an input.
- Overlaps: GermanyCW moved labels by name (`QRA_LABEL_BELOW`, `SUPPORT_LABEL_AT_END`); Caucasus
  needed a spiral de-clutter with leader lines for zones 4/9 (Psebay, 5 km apart), 5/7/14 (Mozdok) and
  8/11 (Mineralnye Vody), bases and their labels registered as obstacles, and one label moved above its
  square (Tbilisi / Vaziani, 11 km apart).
- Basemap: OpenStreetMap standard tiles at zoom 9, Web Mercator, cached (Caucasus: 192 tiles once).

## Done when

- `veaf-tools mission briefing-map` (and the MCP action) renders `docs/carte.jpg` and the ~1600 px
  briefing JPEG from a mission folder, on any theatre the coordinates module knows.
- The frame is computed from the drawn objects plus a margin; an object far outside (an arena) is shown
  by an edge arrow rather than stretching the frame.
- The front line comes from `mission.yaml` (a `briefing_map.front_line` list of points, lat/lon or
  x/y), and the map says "approximate" when it is drawn.
- Markers never overlap: de-clutter with leader lines, bases and labels as obstacles; tested on the
  Caucasus-v6 data.
- The tile request carries a `User-Agent` naming the tool by its URL and **nothing personal**; tiles
  are cached in the mission folder's `.veaf-backups/tiles/`; the OpenStreetMap credit is on the
  picture; a test asserts the header.
- CI renders from fixture tiles, never from the network.
