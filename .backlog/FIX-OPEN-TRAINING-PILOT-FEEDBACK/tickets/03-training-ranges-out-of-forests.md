# 03 — Training ranges out of the forests

Status: ✅ done

Files: the training combat zones of the Open Training repositories, starting with Syria.

## What happened

David, 2026-11-15: the northern helicopter range of the Syria Open Training, near YF69 (`H1/H2/H3 Hélico Ceyhan`, 8 km east of the Ceyhan FARP), stands in the middle of a forest; its units spawn hidden in the trees, which makes no sense for a training range.
It is the same defect as the Akamas range (moved 2026-11-12): on Syria the DCS probe behind `clear-ground-check` does not see some forests (`disposition-blind-to-akamas-forest` in `known-limitations.yaml`), so a clean check proved nothing there.

## What to do

- Move the three Ceyhan helicopter tiers to open ground, keeping the distance from the FARP short, and check the new spot by eye in game (F10 view or smoke on each unit), as was done for Akamas.
- Then go through every other training zone of the Syria Open Training the same way: the probe being blind, only a look in game tells.
- On the other theatres, run `clear-ground-check` on every training zone; any zone whose check is doubtful, or that a player reports, gets the same look in game.
- Widen the known limitation: it is not only the Akamas forest, and the Ceyhan range is a second measured case.

## Done when

- No unit of an Open Training training zone spawns in a wood, checked by eye on Syria and by `clear-ground-check` elsewhere.
- `known-limitations.yaml` names Ceyhan as a second case and `docs/agents/dcs-runtime-traps.md` is regenerated.

## Outcome so far (2026-11-16)

- Known limitation widened in #1280: `disposition-blind-to-akamas-forest` names the Ceyhan forest, where `clear-ground-check` of 2026-11-12 had called the range's 8 vehicles clear; `dcs-runtime-traps.md` regenerated.
- Syria: the whole Ceyhan family (three trigger zones, every target and marker of the three tiers, the Reaper 1 orbit, the F10 circle and label) moved by one vector, from 8.8 km east of FARP Ceyhan to 8.7 km due south of it, centre (212316, 2506), in the plain between Körkuyu and Kurtkulağı (`tools/fix_ceyhan_range.py` of the Syria repository). OpenStreetMap shows farmland at both places, the old one included, so it says nothing about DCS's trees: the new place waits for David's look in game.
- Syria, in passing: the F10 circle and label of the Akamas range had stayed at its old place when the range moved on 2026-11-12; they now sit on its zones.
- The other theatres: no Mission Editor vehicle of a training zone moved; the new hard-tier launchers are `#command` markers, which `clear-ground-check` does not read and which the runtime settles itself. The check of every training zone needs DCS running, so it waits for David.
- Syria, checked in game (2026-11-16): the first new place, due south of the FARP, stood in a forest too, seen on the F10 map, which draws the forests the probe misses.
  The range moved a second time, onto the open hills east of Körkuyu, 10.7 km south-east of FARP Ceyhan (`tools/move_ceyhan_open.py`, Syria `37a9086`), picked on David's F10 capture set to 9.28 m per pixel; his F10 capture of the activated hard tier shows every unit on open ground.
- The known limitation now says the F10 map in "Map" mode shows those forests.

- `veaf-tools dcs forest-check` (FEAT-FOREST-CHECK, #1285 and #1287) replaced `clear-ground-check` for this: it reads the forests from the map files, without DCS. David's Mission Editor captures of Akamas Medium-Armor (in a wood) and Karpas Medium-SA15 (on its edge) agreed with it (2026-11-16).
- Run on the six Open Trainings, training groups and `#command` markers included (2026-11-16):

  | Open Training | Training groups or markers in or next to a forest | Done |
  |---|---|---|
  | Sinai, Falklands, Persian Gulf | none | nothing to move |
  | Syria | Akamas (Easy BMPs and convoy, Medium-Armor), Karpas (Medium-SA15, Hard-EWR) | 7 groups shifted 35 to 400 m, `tools/fix_forest_check.py`, Syria `5395b1e` |
  | Caucasus | Kobuleti Medium-sr-2, Akhalkalaki Medium-aaa-1, Gori Hard-ewr | 3 groups shifted 150 to 300 m, Caucasus `1a1799c` |
  | Marianas | Talofofo, NWF and Rota: 41 of 44 groups and markers, in the jungle | 44 groups into the nearest clearings of their zone circle, 10 m to 3.1 km, Marianas `a5918de` |

- Marianas: no rigid shift clears a whole range (NWF has about 3 % of its circle clear at 50 m around), so each group went to its own clearing, 100 m from any other: nothing of forest or water within 100 m of a Medium/Hard spawn marker (75 m where no 100 m clearing exists), 50 m of an Easy target. The Talofofo Hard Tor (H4-1) stays outside its circle on purpose, 12.9 km from FARP Merizo for its 12 km range.
- Each rebuilt and rechecked: `check_portees` finds no weapon in reach of what it must not reach, and no training unit or marker is left in a forest.
- Out of this ticket, `forest-check` also lists sanctuary groups, air defences and other combat zones in forests (Caucasus: Lazarevskoye, Psebay, Beslan; others on Syria, Marianas, Falklands, Persian Gulf); they are not training ranges and were left as they are.
