# 04 — Shipped aircraft catalogues: a J-11A with weapons, no mods

Status: ✅ done

Files: `src/defaults/mission-folder/src/dynamic-slot-templates.yaml`, `src/defaults/mission-folder/src/spawnables.yaml` (if a J-11A template goes there), the Open Training prompt (4.1), tests.

## What happened

- `J-11A Template Red` (and its blue twin) in `dynamic-slot-templates.yaml` carries an empty `pylons` table, and the J-11A has no DCS named payload: there is no source of a J-11A air-to-air loadout anywhere in the tools. The Marianas OT took one from its v5 (`veafSpawn-J-11A - FOX3 - ECM ON - Radar ON - HARD X1`: R-73, R-27ET and R-77 pairs, ECM pods).
- The same catalogue offers three community mods as dynamic slots: `A-4E-C`, `Bronco-OV-10A`, `T-45`, types absent from the DCS unit database (`list_unit_types` finds none of them). The prompt says « Aucun mod exigé » (4.2); its rule « retire ceux d'une autre époque » does not catch them, and the Syria OT v6 still offers all three.

## Done when

- The catalogue's J-11A templates carry an air-to-air loadout (sourced, say from where), so `loadout_from: "J-11A Template Red"` arms a flight.
- The three mods leave the shipped `dynamic-slot-templates.yaml`, or move to an opt-in list the maker adds on purpose; the build warns when a mission's dynamic-slot templates name a type the unit database does not know.
- The prompt says it in 4.1, next to the era rule.
- Tests: every type of the shipped catalogues exists in the unit database; every fighter template of the catalogue has pylons.

## Done

- The J-11A templates (blue and red) carry `veafSpawn-J-11A - FOX3 - ECM ON - Radar ON - HARD X1` of the Marianas OT v5 (`tools/loadouts-v5.json`), verbatim.
- The new test « every CAP template carries a loadout » also found `Mig-29G Template Red` empty: it took its blue twin's pylons, verbatim. `P-47D-40` (CAP, guns only) is the one exception, named in the test.
- The six mod templates left the catalogue (128 → 122 templates); the build warns, per template, about a type the unit database does not know (`cmd.build.aircraft_unknown_type`), for both catalogues.
- Not done: the other templates with an empty table are player slots with task `Nothing`, armed on the ramp; none was given a loadout nobody sourced.
