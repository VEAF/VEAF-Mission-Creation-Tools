# 03 — The build opens a carrier's deck to every dynamic template of its side

Status: ⬜ ready
Type: fix + data
Files: `src/python/veaf-tools/warehouses_injector/warehouses_injector_worker.py`, the unit data
(`veaf_libs/data/dcsUnits.yaml`, `update-dcs-data`), tests

## Origin

GermanyCW-v6, 2026-09-28, once the carrier had a warehouse (ticket 02): the default
`warehouses.yaml` (no `ships:` key) applies the coalition defaults to every ship of the side.

## Measured

- The build log went from « 12 aéroports configurés, 0 navires/FARP, 612 liens de modèle » to
  « … 1 navire/FARP, 663 liens » — 51 more links, all on the Stennis: every blue template,
  B-52H and CH-47 included.
- The filter is by the **ship's** type only: "`AircraftCarrier` takes planes and helicopters"
  (module docstring). Nothing asks whether the **aircraft** can use a deck.
- The unit data cannot answer: `dcsUnits.yaml` carries `AircraftCarrier With Catapult` / `With
  Arresting Gear` / `With Tramplin` as ship attributes (23 occurrences), and no aircraft entry
  says which deck it can use. DCS does: an aircraft's `LandRWCategories`.

Worked around with a `ships: { CVN-74 Stennis: { aircrafts: {…} } }` list of five types (F/A-18C,
F-14B, AV-8B, UH-1H, AH-64D).

## Done when

- `update-dcs-data` captures each aircraft's `LandRWCategories` into the unit data.
- The injector stocks a carrier only with the aircraft whose categories match the ship's
  (catapult / arresting gear / ski-jump / helicopters), the way it already filters an airfield by
  its parking.
- An explicit `aircrafts:` list is still obeyed. Tested on a catapult carrier and on a LHA.
