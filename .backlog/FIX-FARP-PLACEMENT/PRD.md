# FIX-FARP-PLACEMENT — a FARP placed in the jungle and on a slope, and nothing said

Status: 🧑 waiting-human

Asked by David on 2026-10-12.
On the Marianas Open Training v6, `add_farp` put « FARP Merizo » in the forest and on a slope: David saw it in game (screenshot, 2026-10-12), and a DCS probe confirmed it (`Disposition.getSimpleZones` small query, 0 of 12 points free at 30 m, 3 to 6 of 12 at 60–120 m).
The only flat and clear place within 1.2 km was found by a probe written for the mission (`VEAF-Open-Training-Mission-Marianas-v6/tools/find_farp_spot.py`: centre and 8 points at 40 m each with a free 5 m spot within 20 m, ground surface, less than 3 m of height difference), and the FARP moved there by hand.

What `develop` (e322fa89) does today, read in the code:

- `add_farp` checks only the water, through the elevation grid (`surface_warnings`, `add_farp.py:140`). It does not use the clear-ground placement `add_group` has (`veaf_libs/clear_ground_placement.py`), and nothing checks the slope.
- Nothing in VMCT removes scenery. The Marianas v5 did it by hand for its Tinian FARP: three trigger zones (`RemoveTreeTinian-1/-2/-3`, 20–25 m) and a once-trigger with the DCS action `a_remove_scene_objects`.

A helicopter pad in the trees or on a slope is unusable, and the maker learns it from a pilot.

| # | Ticket | Status |
|---|--------|--------|
| 01 | [add_farp checks its pad: clear ground and slope](tickets/01-farp-pad-checks.md) | ✅ |
| 02 | [add_farp can clear the scenery around its pad](tickets/02-farp-clear-scenery.md) | 🧑 |
| 03 | [An in-game finder for a flat, clear FARP spot](tickets/03-farp-spot-finder.md) | 🧑 |

Ticket 02 has one unknown to measure in DCS before the code is final (what `a_remove_scene_objects` removes, and whether every client sees it in multiplayer); 03 needs DCS to run. One branch, one PR.
