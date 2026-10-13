# 03 — The shipped `spawnables.yaml` catalogue puts 51 modern jets into a WW2 mission

Status: ✅ done — the WW2 set is not shipped (known limitation)
Type: fix
Files: `mission_builder/mission_builder_worker.py` (l. 1377, the `spawnable_aircrafts` step), `src/defaults/mission-folder/src/spawnables.yaml`, the build log message, tests

## What happens

A mission with `mission.era: WW2` and an empty `src/spawnables.yaml` gets « 51 groupes aériens injectés » from the shipped catalogue: F-15C, F-14A, Mirage 2000, F-5, MiG-21/23/25, F1EE, MQ-9… (`pull-aircraft-groups` lists them). None exists in 1944, and none of the catalogue is a WW2 aircraft, so the `-cap`, `-escort` and `_spawn` templates a WW2 mission offers are all anachronisms. The Normandy Open Training switched the step off (`pipeline: spawnable_aircrafts: false`) and has no spawnable template at all.

## What ships

- The build reads `mission.era` for this step: under `WW2`, an empty `spawnables.yaml` injects nothing, and the log says why (« catalogue livré : aucun appareil de l'époque WW2 »); under `COLD_WAR`, only the types the catalogue marks for it.
- The catalogue entries carry an `era` (or a list), so the filter is data, not code.
- A WW2 set — at least P-51D, P-47D, Spitfire LF IX, Bf 109 K-4, Fw 190 A-8/D-9, Ju 88 A-4 and B-17G, as `veafSpawn-*` templates — ships with the tools (needs ticket 01 for the loadouts).

## Done when

A WW2 folder built with the default pipeline has no modern aircraft in its `.miz`, and the log names the era rule.

## Done

`aircrafts_injector.catalogue.AIRCRAFT_ERAS` says which era each type of the shipped catalogue exists in (a type not listed is kept in every era, and a test enumerates the shipped catalogue so none can be missing); the build filters the **shipped** fallback only — a `src/spawnables.yaml` the maker wrote is injected as written. Under `WW2` it injects nothing and says so (`pipeline.console.aircraft_no_era`); under `COLD_WAR` it drops the MQ-9. `MissionBuilderWorker.mission_era()` gives the era (`mission.era`, else the detected one).

Not done: the WW2 `veafSpawn-*` set. A template carries the editor's ROE and reaction options, which cannot be written from a table without checking them in DCS, and the dynamic-slot catalogue already gives players the WW2 aircraft. Written down as the known limitation `no-ww2-spawnable-aircraft-templates`.
