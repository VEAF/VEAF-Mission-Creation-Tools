# 06 — `create_qra` and `create_cap_mission` build aircraft with the ground-vehicle builder

Status: ✅ done
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/composites.py`, `add_air_group.py`, tests

## What happens

Both composites call `add_group.insert_group_into_content(..., category="plane")`. That builder is the
ground one: `task = "Ground Nothing"` (add_group.py ~188), `playerCanDrive` / `coldAtStart` (~224),
first point `action = "Off Road"` (~246). In a plane group it gives:

```
task=Ground Nothing   route[1]: alt=0, action=Off Road, speed=5.5555   units: no payload, no fuel
```

When the QRA scrambles or the CAP is activated, the aircraft appear at ground level, at 20 km/h,
empty. Same class as `FIX-MCP-AUTHORING-GAPS` ticket 04 (a valid file, aircraft that cannot fly),
one call away from where that lot fixed it.

Found on GermanyCW-v6 (`QRA_Stendal-MiG21/23`, `OnDemand-CAP-MiG23-Border-South`); worked around with
`remove_group` + `add_air_group` + `set_group_properties(late_activation)` + pylons.

## Same builder, two more categories

Found the next day on the same mission: `create_combat_zone(category="static")` and
`(category="ship")` — and `add_group` with those categories, same builder — write the ground-vehicle
shape too.

- **static**: a vehicle group under `country.static` (`task = "Ground Nothing"`, "Off Road" route,
  `playerCanDrive`, `skill`), and the units have **no `category`** (`Armor`, `Unarmed`, `Planes`,
  `Fortifications`…), no `dead`, no `canCargo`. A static's unit name should also be the group name
  (the combat-zone prefix rule reads the static's own name).
- **ship**: `task = "Ground Nothing"`, first point `action = "Off Road"`, `playerCanDrive`.

GermanyCW-v6 has 23 statics (combat-zone targets, including parked MiGs) and 2 ship groups that were
converted by a Lua patch. Statics are the only way to make a truly inert training target — a live
T-55 fires its AA machine gun at helicopters, and no zone tag sets ROE to weapon hold.

## What ships

- Both composites build through `add_air_group`'s builder (air start at the given position,
  altitude and speed parameters, full fuel), late activation set
- `add_air_group` gains `late_activation` (today it takes a second call)
- The composites accept a loadout, or a template to copy it from: an unarmed interceptor is the next
  silent failure. The `veafSpawn-*` groups of `spawnables.yaml` are a sourced place to take CLSIDs from
- A CAP needs a route: accept a second point / race-track, else the template orbits nowhere

## Done when

- A test per composite asserts a plane group with alt > 0, a Turning Point, fuel, and no ground keys

## Outcome (PR 2)

- `insert_air_group_into_content` (in `add_air_group.py`) is the composites' builder: air start,
  fuel from the units database, one aircraft type per group (a mixed flight is refused),
  `late_activation`, `pylons`, and a race-track orbit towards a second CAP point.
- Loadout: `pylons`, or `loadout_from` a group found in the mission, then the folder's
  `spawnables.yaml` / `dynamic-slot-templates.yaml`, then the shipped ones.
- Statics: the editor's shape, measured over 583 static groups of the missions under `test/`; the
  unit `category` from `dcsUnits.yaml`, mapped with the table measured over 401 missions under
  `D:\dev\_VEAF` (`Plane`→`Planes`, `Fortification`→`Fortifications`…). One object per static; an
  unknown type is written without a category and reported. Ships: the shape of 53 ship groups, no
  task, Turning Points, 127.5 MHz AM (102 of 117 ship units).
