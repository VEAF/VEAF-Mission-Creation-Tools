# 06 — Measure whether late-activated sanctuary vertices give DCS a position

Status: ⬜ ready
Type: measure (DCS), possibly doc
Files: none until measured; then `.prompts/new-open-training-mission.*.md` or
`src/scripts/veaf/veaf.lua` (`veaf.getPolygonFromUnits`)

## Origin

The Open Training prompt (§4.1): "Le polygone est tracé par des unités en activation différée
(`polygon_units`), jamais activées." GermanyCW-v6 (2026-09-28) followed it for its four sanctuaries
(23 vertices).

## Measured, on paper only

- `veaf.getPolygonFromUnits` takes `Unit.getByName(name)`, else `Group.getByName(name):getUnit(1)`,
  reads `unit:getPosition().p` and destroys the unit (`veaf.lua`).
- The demo mission does as the prompt says: its 16 `Sanctuary_Kutaisi_Polygon` groups are all
  `lateActivation = true`.
- The Caucasus v5, whose sanctuary the prompt's rule comes from, does not: its `BlueSanctuary`
  vertices are **active** ships, destroyed by the script at start.
- Whether DCS returns a unit, and its position, for a group that was never activated has not been
  checked. If it does not, every vertex is skipped and the sanctuary has no polygon, with no error.

## Done when

- Measured in DCS (dcs-bridge): `Unit.getByName` and `getPosition()` on a never-activated vertex,
  and the polygon a sanctuary actually builds from them.
- If it works: nothing to change, the answer written here. If not: the prompt says active units,
  or `getPolygonFromUnits` reads the position from the mission data (`env.mission`) instead.
