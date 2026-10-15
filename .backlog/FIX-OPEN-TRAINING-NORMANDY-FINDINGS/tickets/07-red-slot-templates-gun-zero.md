# 07 — The red WW2 dynamic-slot templates carry `gun: 0`

Status: 🚫 wontfix — closed by David on 2026-10-14 (« on verra bien en jeu »): not measured, templates unchanged; the known limitation `ww2-slot-templates-carry-gun-zero` stays and says what to check
Type: investigate, then fix
Files: `src/defaults/mission-folder/src/dynamic-slot-templates.yaml`, the generator of the catalogue

## What happens

In the shipped catalogue the blue WW2 templates (`P-47D Template`, `P-51D Template`, `Spitfire Template`, `Mosquito Template`…) carry `payload.gun = 100`, and the red ones — `Bf-109K4 Template Red`, `FW-190A8 Template Red`, `FW-190D9 Template Red` — carry `payload.gun = 0` (fuel 296, 409 and 388). A dynamic slot is spawned from its template: if `gun` is the gun-ammunition percentage, a red WW2 pilot takes off with no cannon ammunition. A group built by `add_air_group` for the same types gets `gun = 100` (checked in the Normandy mission), so the AI is armed and the player may not be.

Not established: whether DCS reads `gun` for the Bf 109 and Fw 190 at all (their guns may be set by the pylons or a `settings` table), which is why this ticket starts with a test in the game: a red slot from the template, a red slot from `add_air_group` with `gun = 100`, `Ctrl+Shift+W`-style loadout screen and a trigger-happy five seconds.

## Done when

The first sentence of the cause is a fact (measured in DCS), and the red templates carry what the Mission Editor writes for a default Bf 109 K-4 / Fw 190 A-8 / D-9.

## Checked, not done

The shipped `dynamic-slot-templates.yaml` read on 2026-10-13: the finding is wider than written. `gun: 0` is on the `Bf-109K4`, `FW-190A8`, `FW-190D9`, `F4AU-1D` and `TF-51D` templates on **both** sides (ten groups); the P-47D, P-51D, Spitfire, Mosquito, I-16 and La-7 templates carry 100. Whether DCS reads `gun` for these types is still the open question, so nothing was changed: the templates are the editor's own export, and a guess at their shape would be written into every mission.

Written down as the known limitation `ww2-slot-templates-carry-gun-zero`, with the in-game check that settles it (a slot from the template, the loadout screen, a burst of fire). If the ammunition is zero, set `gun: 100` on the ten templates.
