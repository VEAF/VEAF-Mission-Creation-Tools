# 01 — Populate the airfield table at build time

Status: ✅ done 2026-08-16 — 225 airfields written where there were none, **confirmed in game**
Type: fix
Files: `src/python/veaf-tools/mission_builder/warehouses_bootstrap.py` (new),
`src/python/veaf-tools/mission_builder/mission_builder_worker.py`, both locale files,
`test/python/mission_builder/test_warehouses_bootstrap.py` (new)

## The change

`ensure_airports_populated(warehouses_content, theatre=…)` fills an empty `warehouses.airports` with
one entry per airfield of the theatre, keyed by numeric airdrome id, read from the bundled
`airdromes.yaml` — the same runtime-sourced table `set_airbase_coalition` and the warehouses
injector already resolve names against.

Called from the builder right after `ensure_coalitions_populated()`, which is the exact precedent:
the same shape of defect (a mission that cannot work because a table DCS expects is empty), fixed
the same way (the build supplies it), for the same reason (a mission maker should not have to know).

**A table that already holds entries is left completely alone.** Rewriting it would discard a
mission's own ownership and stock settings, and the defect only concerns missions that have none.

## The default entry

`DEFAULT_AIRPORT` is transcribed from a mission the DCS Mission Editor had just saved — 20 keys,
identical across all 224 of its airfields. `coalition` is `NEUTRAL` for every one of them, including
fields with units on them: ownership is resolved at runtime, and the in-game check that closed this
defect ran on exactly such a file. A mission maker who wants a field owned at start declares it in
`warehouses.yaml`, or `set_airbase_coalition` writes it (ticket 02 makes that stick).

Each airfield gets its **own copy** — a shared dict would make one coalition change turn every
airfield of the theatre, which a test pins.

## Tests

Eight, in `test_warehouses_bootstrap.py`: every airfield gets an entry; keys are numeric ids
(42 = Deir ez-Zor, the field the in-game measurement was made on); the entry carries the editor's
key set; entries are distinct objects; a populated table is untouched; an unknown theatre, a missing
`airports` key and an empty theatre are all no-ops rather than raising mid-build.

## Verified beyond the tests

The smoke-test mission rebuilt through the real pipeline: `warehouses` **69 bytes → 150 040**, 225
airfields, id 42 present, `NEUTRAL`, `unlimitedFuel = true`.
