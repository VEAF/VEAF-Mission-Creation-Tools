# FEAT-FOREST-CHECK — Read where a DCS map has forests, without the game

Status: ✅ done · archived 2026-11-24

## Problem

On Syria, the probe behind `veaf-tools dcs clear-ground-check` (`Disposition.getSimpleZones`) does not see some forests (known limitation `disposition-blind-to-akamas-forest`).
Two Open Training ranges, Akamas and Ceyhan, were placed in woods while the check said clear; both were found by pilots flying them.
The F10 map in its "Map" mode does draw those forests, so the data is in the map files.

## What was established (2026-11-16)

The forests are the `Trees` meshes (shader `Simple5.1`) of `Mods/terrains/<map>/surface/<map>.surface5` (`landscape5::Surface5File`, not encrypted, 30 GB on Syria).

- The u64 at offset 8 is the size of the header and metadata; the data pool starts there. Array offsets are relative to it.
- The metadata is a list of nodes. Each node starts with a 4×4 float matrix whose rotation is the identity and whose translation is the node origin in world coordinates (engine `x` = mission `x`, engine `z` = mission `y`).
- A named array is `<u32 len><name><u16 type><u16 elem size><u32 flag><u64 byte count><u48 offset>`.
- A node holds its `Land` mesh, then overlay meshes (roads, fields, trees...), each one a group of arrays followed by its material (`<u32 len>Simple5.1<u32 len>Trees`, a parameter count, two u32, two bytes, then its bounding box as six f32 relative to the node origin), and ends with the node's base vertex buffer `Pbase` (f32 × 3, relative to the node origin).
- A `Trees` mesh has no vertex buffer of its own: its `baseIndex` array indexes the node's `Pbase`, its `TRI` array indexes its own `baseIndex`. That is the "vertex pool" an earlier session could not find; the earlier session also read the pool 0x30 bytes too far.

Checked against the ground truth David gave, on Syria: the old Ceyhan range (219000, 11000), (212316, 2506) and the Akamas T-72 (13404, -326775) fall inside a forest triangle; the open hills at (212916, 9506), the Ceyhan FARP (221016, 2506) and the current Akamas range (14640, -314461) do not.

## Every map

The same layout is on the eleven maps installed on 2026-11-16; only the material name changes (`Simple5.1`/`Trees` on Syria and Afghanistan, `CaucasusSimple5.1`/`Forest`, `HardSplat5.1`/`Forest` on Normandy...). The theatre a mission names is the `id` of the terrain's `entry.lua` (`GermanyCW` in folder `GermanyColdWar`).
Checked against the parking stands VMCT ships: none or almost none in a forest on ten maps, against 3 to 36% of the same stands moved 3 km. Marianas WWII put 164 of 534 in a forest; David's F10 captures of Agana showed open ground, and the cause was an airfield overlay drawn above a forest texture (ticket 03). With the topmost overlay deciding (ticket 04): 0 of 512 on Marianas WWII, 0 to 2.5% elsewhere, David's six Syria places still right.

## Solution

1. `veaf_libs/dcs_forests.py`: a reader that indexes the `Trees` meshes of a `.surface5` file by bounding box and loads only the meshes around the points asked, and answers "is this mission point in a forest".
2. `veaf-tools dcs forest-check <mission.miz>`: lists the ground vehicles of a mission standing in a forest, reading the map files of the local DCS install. No game launched.

A separate command rather than a forest test inside `clear-ground-check`: the forest test needs only the files of the DCS install and answers in seconds, while `clear-ground-check` needs the game running on an empty survey mission. Putting the one inside the other would make the cheap test wait for the expensive one.

## Out of scope

- An MCP action for the check (to add when an agent asks for it).
- The other kinds of scenery (buildings, towns): `clear-ground-check` keeps them.

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [Surface5 forest reader](FEAT-FOREST-CHECK.md) | ✅ |
| 02 | [`dcs forest-check` command, doc and limitation](FEAT-FOREST-CHECK.md) | ✅ |
| 03 | [Check the Marianas WWII forests in game](FEAT-FOREST-CHECK.md) | ✅ |
| 04 | [The topmost overlay decides](FEAT-FOREST-CHECK.md) | ✅ |

## Tickets, in full

## 01 — Surface5 forest reader

Status: ✅ done

`veaf_libs/dcs_forests.py`, standard library only:

- find the `.surface5` file of a theatre in a DCS install (`Mods/terrains/<folder>/surface/*.surface5`, folder or file stem matching the theatre name), and the DCS install from the registry (`HKCU\Software\Eagle Dynamics\DCS World` and `DCS World OpenBeta`, value `Path`);
- index the `Trees` meshes of the file by world bounding box, through `mmap`, without reading the 30 GB;
- `in_forest(x, y)` for a mission point: load the triangles of the meshes whose box holds the point, once, and test the point against them.

A mesh whose arrays do not agree (a `TRI` index past its `baseIndex`, a `baseIndex` past the node's `Pbase`) raises: the reader refuses a file it does not understand rather than answering "no forest".

Tests on small binary fixtures built in the test, no map file.

## 02 — `dcs forest-check` command, doc and limitation

Status: ✅ done

- `veaf-tools dcs forest-check <mission.miz> [--dcs-dir] [--report]`: reads the ground vehicles the way `clear-ground-check` does (markers skipped), lists those in a forest by group, writes an optional JSON report.
- Doc FR/EN next to `clear-ground-check`, CHANGELOG, and the known limitation `disposition-blind-to-akamas-forest` pointing to the new check.

## 03 — Check the Marianas WWII forests in game

Status: ✅ done

On every map but one, `forest-check` put none or almost none of the parking stands VMCT ships in a forest (0 to 2.3%, against 3 to 36% for the same stands moved 3 km).
On MarianaIslandsWWII it put 164 of 534 in a forest, most of them on three airfields, measured on 2026-11-16: Agana 39 of 39, Orote 34 of 35, Airfield 3 57 of 83.

The stand numbers of `data/parking/*.json` are DCS's terminal ids, one more than the Mission Editor's label (Agana: 2 to 40 in the file, 01 to 39 in the editor); its entries of type 16 are runway points, not stands.

### Result (David, 2026-11-16)

F10 view in "Map" and "Sat" modes on Agana: the whole clearing around the runway, stands 01 to 39, is open ground, bare on the Sat view.
So the reader was wrong on that map. The cause, measured on Agana's stand 39 (-811, -1606): on the Marianas the forest is a ground texture (`Splatmap5.1` / `Forest`, draw order 49), and the airfield (`SplatmapUnique5.1` / `Runway`, draw order 103) is drawn over it; the reader looked at the forest alone. Fixed by ticket 04.

## 04 — The topmost overlay decides

Status: ✅ done

A point is in a forest when the overlay drawn on top of it is a forest, as the F10 map shows it.

- Every overlay is indexed, not only the forests: each one's draw order is the u32 written after its material (Syria: Trees 93, fields 82-89, towns 94-114, sea 109; Marianas WWII: Forest 48-60, Field 56-100, Runway 103).
- A point inside a forest triangle is out of the forest when an overlay of higher draw order covers it; a tie keeps the forest.
- Overlays whose vertices are offsets from their base vertex (a float `parametricUVW`: roads, rivers, beaches, the coast's breaking waves) are not read: their shape is not in `Pbase`. A vehicle on a road through a wood therefore still counts as in the wood.
- Each mesh's arrays are now read as the chain of records that ends at its `TRI`, so an array of the previous mesh can no longer be taken for one of its own.

Checked on 2026-11-16: David's six Syria places still right, and the parking stands of the eleven maps (see the PRD).
