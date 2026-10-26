# 05 — Dynamic slots filtered by era

Status: ✅ done

`mission.era: COLD_WAR`, 1987: `inspect_built_mission` shows Senaki offering 61 types, F-16C_50, FA-18C_hornet, AH-64D_BLK_II, JF-17, F-15ESE and Su-33 among them.
The build log said "1 shipped aircraft group(s) left out: not of the COLD_WAR era" — that is `spawnables.yaml`; `filter_by_era` (`aircrafts_injector/catalogue.py`) is not applied to the dynamic-slot templates.

Apply the same table (`AIRCRAFT_ERAS`) to the shipped dynamic-slot catalogue, with the same rule: a type the table does not know is kept.
A mission's own `src/dynamic-slot-templates.yaml` is not filtered — the maker chose it.
The build log says how many templates the era removed.

Done when: a COLD_WAR mission offers no F-16C, F/A-18C or AH-64D on its dynamic slots and still offers the AJS-37, MiG-21 and F-5E; a MODERN mission is unchanged; a sweep test enumerates the catalogue's types against the table; `describe_known_limitations` or the guide no longer needs the assistant to point it out.

## Result

Fix: the build filters the shipped dynamic-slot catalogue by era like the spawnables (`era_filtered_catalogue`, MODERN never filtered). `AIRCRAFT_ERAS` now covers the 60 types of both catalogues, `COLD_WAR` meaning the variant DCS models was in service before 1991 — service dates are estimates, not sourced. `ERA_LEFT_OUT` keeps the F/A-18C (flew from 1987, DCS models a 2000s lot) and the TF-51D in every era.
A COLD_WAR mission now offers no warbird either: they are WW2 (the P-51D and the Korean F4U-1D_CW stay in COLD_WAR).
Tests: `TestShippedDynamicSlotTemplates`, enumerated over the catalogue.
