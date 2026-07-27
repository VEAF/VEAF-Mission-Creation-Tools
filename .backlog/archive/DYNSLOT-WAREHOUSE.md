# Lot DYNSLOT-WAREHOUSE — Wire dynamic-slot templates into the `.miz` warehouses

Status: ✅ done

**Goal**: Injecting a `dynSpawnTemplate=true` group puts the **group** in the mission, but for DCS to actually offer it as a Dynamic Slot the `.miz` **`warehouses`** file must also reference it (`airports[id].dynamicSpawn=true` + aircraft list). The current injector does not touch `warehouses`. Split off from AIRCRAFT-INJECT (handoff §5). Reference: `test/veaf-tools/demo-mission/src/mission/warehouses` (`dynamicSpawn = true`).

**Spike findings (001 ✅)**: Dynamic Slots are **per airbase** — `warehouses.airports[<id>].dynamicSpawn = true` enables them; `aircrafts[<type>]` is the warehouse stock; **`aircrafts[<type>].linkDynTempl = <groupId>`** links the slot to a `dynSpawnTemplate=true` group (the model providing loadout/livery/radio/route — confirmed in the demo: `linkDynTempl=2114` ↔ group "DST - UH-1H" groupId 2114). The template group's physical placement is irrelevant. The airport key `<id>` is the DCS **airdrome id**; warehouses carry no names, and the datamine has no airdrome table — but each airport block has a `coalition` field (so "all airports of a coalition" needs no names), and name→id is recoverable from the **install** (`Mods/terrains/*/Beacons.lua`). Config model (David): `warehouses.yaml` per coalition (undeclared → untouched); per coalition global defaults (fuel/weapons/aircraft+templates) applied to all coalition airports, or a specific airport list (by name or id) with overrides; the build sets `dynamicSpawn`, stock, fuel and `linkDynTempl`.

**Branch**: `feat/dynslot-warehouse` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| DYNSLOT-WAREHOUSE-001 (spike) | Investigate the `warehouses` Dynamic-Slot schema and design the wiring. **Done** — see findings above. | `mission_tools/`, `doc/` | spike | ✅ |
| DYNSLOT-WAREHOUSE-002 | Airdrome name→id table (prerequisite for naming airbases): `airdromes.yaml` generated from a DCS install's terrain `Beacons.lua` (`update-dcs-data --airdromes --dcs-path`), resolver `veaf_libs.dcs_airdromes`, bundled in the exe; install-dependent (not CI-guarded). | `veaf_build/dcs_data/airdromes.py`, `veaf_libs/{data/airdromes.yaml,dcs_airdromes.py}`, `veaf_build/cli.py`, `test/python/` | feat | ✅ |
| DYNSLOT-WAREHOUSE-003/004/005 | `warehouses_injector`: `warehouses.yaml` schema + a new `warehouses` build pipeline step (after aircraft injection) that selects airports (all-of-coalition via the `coalition` field / by id / by name via the airdrome table + mission theatre), sets `dynamicSpawn` + fuel/munitions + aircraft stock, and wires `aircrafts[<type>].linkDynTempl` from each injected `dynSpawnTemplate` group's `groupId` (by group name, else by aircraft type). Per-airport overrides are supported. | `warehouses_injector/`, `veaf_tools/commands/build.py`, `mission_builder/` (defaults map), `test/python/` | feat | ✅ |
| DYNSLOT-WAREHOUSE-006 | Commented `src/defaults/mission-folder/src/warehouses.yaml` (no-op default) + FR/EN docs (`PIPELINE_REFERENCE`, `MISSION_YAML_REFERENCE`) + tests. | `src/defaults/`, `doc/`, `test/python/` | feat | ✅ |
| DYNSLOT-WAREHOUSE-NAMES (follow-up) | Broaden airdrome name coverage to beacon-less maps (e.g. Normandy/WW2) via another install source if needed. | `veaf_build/dcs_data/airdromes.py` | feat | ⬜ |
