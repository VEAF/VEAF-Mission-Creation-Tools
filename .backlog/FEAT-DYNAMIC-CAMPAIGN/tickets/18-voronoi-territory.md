# 18 — Territory cells (Voronoi) tinted by owner

Status: 🧑 waiting-human — built and tested outside DCS in #1282 (2026-11-16); the in-game check of the test mission is David's

PRD row "Territory cells (Voronoi)"; analysis note 01 §14 (the mechanism, rewritten here: Foothold's code is GPL-3.0).

## What

- Each zone owns the part of the map nearer to its centre than to any other zone's: its Voronoi cell, computed by clipping a bounding box (the zones' extent plus `territory.margin`, 70 km) by the perpendicular bisector with every other zone.
- Each cell is filled on the F10 map in its owner's colour, faint (blue, red, grey for neutral); the edges between two cells of different owners are drawn as a line — the front.
- Redrawn when a zone changes hands, never otherwise.
- Off with `territory.enabled: false`.

## How

Pure Lua geometry (half-plane clipping of a convex polygon, each edge labelled with the zone whose bisector cut it, so that the front is the edges between owners); each cell drawn as a fan of triangles with `trigger.action.markupToAll(7, …)` — a three-point free-form polygon is what Foothold measured to fill reliably — and the front with `lineToAll`.

## Done when

Lua tests: the cells of three and four sites (areas add up to the box, each centre in its own cell); a front edge only between different owners; the marks removed and redrawn on a capture, untouched otherwise.
In game: the map is tinted, the front follows the captures.
