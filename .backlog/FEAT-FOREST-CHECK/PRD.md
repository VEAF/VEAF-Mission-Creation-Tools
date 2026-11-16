# FEAT-FOREST-CHECK — Read where a DCS map has forests, without the game

Status: 🔄 in-progress

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
Checked against the parking spots VMCT ships: none or almost none in a forest on ten maps, against 3 to 36% of the same spots moved 3 km. Marianas WWII puts 164 of 534 in a forest, unexplained: known limitation `forest-check-unexplained-on-marianas-wwii`.

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
| 01 | [Surface5 forest reader](tickets/01-surface5-forest-reader.md) | ✅ |
| 02 | [`dcs forest-check` command, doc and limitation](tickets/02-forest-check-command.md) | ✅ |
