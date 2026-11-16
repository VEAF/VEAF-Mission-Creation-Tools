# 03 — Check the Marianas WWII forests in game

Status: 🧑 waiting-human

On every map but one, `forest-check` puts none or almost none of the parking spots VMCT ships in a forest (0 to 2.3%, against 3 to 36% for the same spots moved 3 km).
On MarianaIslandsWWII it puts 164 of 534 in a forest, most of them on three airfields, measured on 2026-11-16:

| Airfield (id) | Stands in a forest | Example stand, mission (x, y) |
|---|---|---|
| Agana (1) | 39 of 41 | #40, (-811, -1606) |
| Orote (2) | 34 of 35 | #34, (-4991, -17056) |
| Airfield 3 (3) | 57 of 83 | #82, (174307, 91592) |

Flat triangles were ruled out (the fix of 2026-11-16 changed nothing there), and the modern MarianaIslands map puts 0 of its 282 stands in a forest.
Two explanations are left: the 1944 map draws its dispersal areas under the trees, or the reader misses something on that map.

## Check

In DCS, on MarianaIslandsWWII (an empty mission is enough, no pilot): F10 view in "Map" mode, then the Sat view, on the three example stands.

- **Trees on the stands** (green dotted area on the Map view, canopy on the Sat view): the reader is right. Change the known limitation `forest-check-unexplained-on-marianas-wwii` into a `kind: dcs` entry saying the 1944 airfields stand in the trees, dated.
- **Open ground on the stands**: the reader is wrong on that map. Open a fix: compare the forest meshes of Agana with the F10 drawing, find what this map lays out differently.

Item R55 of `DCS-SESSION-TODO.md`.
