# 01 — Statics placed without a `shape_name`, some of which DCS refuses

Status: ✅ done — 2026-09-29
Type: fix + data
Files: `src/python/veaf-tools/veaf_mission_mcp/add_group.py` (`_build_static_group`), the unit data
(`veaf_libs/data/dcsUnits.yaml`, `update-dcs-data`), `validate_mission`, tests

## Origin

In-game test of GermanyCW-v6, 2026-09-28. Wünsdorf's command centre did not spawn when its zone was
activated; it was not even one of the zone's elements.

## Measured

- At mission load, `dcs.log`:
  `ERROR APP (Main): unknown static shape_name, category Fortification, type: .Command Center` and
  the same for `category Warehouse, type: .Ammunition depot`. DCS does not create the object; the
  combat zone never sees it.
- Four objectives affected in the mission, all placed by the MCP on 2026-09-24: Wünsdorf's
  `.Command Center`, Torgau's two and Wittenberg's one `.Ammunition depot`. Torgau's draw
  (`#spawncount=4` of 5) had only 3 elements to draw from.
- The other static types seen spawning in game did so without a `shape_name` (Warehouse, Bunker,
  Barracks 2, Fuel tank, Tank, MiG-29S and Su-27 statics), so DCS resolves many types itself — not all.
  Only these two types were refused at load (`dcs.log` logs one line per refused type).
- `_build_static_group` writes type, name and `category`, never `shape_name`; only `add_farp`
  writes one (`_SHAPES`, per heliport type).
- `dcsUnits.yaml` has no shape name for these types. VEAF's own spawner has the table:
  `veafDcsSpawner.lua` (`[".Command Center"] = "ComCenter"`, `[".Ammunition depot"] = "SkladC"`,
  about a hundred more), and `mist.lua` carries the same pairs.

Worked around in the mission by writing `ComCenter` / `SkladC` on the four statics.

## Done when

- The unit data carries each static type's `shape_name` (captured by `update-dcs-data`, or taken
  from the same source the spawner uses — one source, not a second copy of the table).
- `add_group` (category `static`) and `create_combat_zone` write it.
- `validate_mission` warns on an existing static whose type needs a `shape_name` and has none, so
  the missions already built are caught.
- Tests; the four GermanyCW-v6 statics rebuilt through the action carry the shape without the
  mission's workaround.

## Done — 2026-09-29

- The datamine carries `ShapeName` on the statics' files (228 fortifications, 5 warehouses, 24
  cargos…); `veaf_build/dcs_data/units.py` reads it for kind `static` only, and `dcsUnits.yaml`
  gains `shape_name` on 278 types (`ComCenter`, `SkladC`, `Tank` → `bak`). One source: the spawner's
  table and the YAML now come from the same DCS files, and the YAML is CI-guarded.
- `veaf_libs.dcs_units_data.get_unit_shape_name`; `_build_static_group` writes it, which covers
  `add_group` and `create_combat_zone` (both go through `insert_group_into_content`).
- `validate` warns, one line per unit, on a static without its shape
  (`validate.static_without_shape`, catalogued in `build-messages/missing-references`). Not in
  the build's end summary, whose header counts missing `mission.yaml` references.
- A `known-limitations.yaml` entry (`static-without-shape-name-is-refused`, kind `dcs`).
- Not done here: rebuilding the four GermanyCW-v6 statics through the action. That is R17.
