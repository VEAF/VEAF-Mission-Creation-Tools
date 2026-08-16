# 03 — Offer a hot start on a dynamic-slot airfield

Status: ✅ done 2026-08-16 — needs one in-game confirmation
Type: fix
Files: `src/python/veaf-tools/warehouses_injector/warehouses_injector_worker.py`,
`src/defaults/mission-folder/src/warehouses.yaml`,
`test/python/warehouses_injector/test_warehouses_injector.py`

## The measurement

Reported in game on 2026-08-16, the run where everything else finally worked: *"seul défaut,
l'option spawn hot des slots dyn est désactivée"*.

`allowHotStart` is the field behind that option. The DCS Mission Editor writes it **false**, so
`DEFAULT_AIRPORT` copies false, and nothing ever set it back: `_apply_to_airport` handled
`dynamicSpawn`, fuel, munitions and stock, and did not know about it. Grepped: `allowHotStart`
appeared in exactly one place in the whole Python tree — the default entry.

## The change

An airfield the mission opens to dynamic slots offers a hot start: `_apply_to_airport` writes
`allowHotStart = True` beside `dynamicSpawn = True`. A dynamic slot the pilot can only take cold is
half the feature, and the mission has deliberately opened that airfield.

`hot_start: false` under a coalition's `defaults:` turns it back off — symmetric with the existing
`fuel:` and `weapons:` keys, so a mission wanting cold starts only can say so in one line. An
airfield of another coalition is never touched, which a test pins.

## Tests

Three: a configured airfield offers a hot start; `hot_start: false` turns it off; an airfield of a
coalition the config does not declare keeps whatever it had.

## Verified beyond the tests

Rebuilt: Deir ez-Zor (blue) and Palmyra (red) carry `allowHotStart = true` with their 52-type
catalogue; the neutral airfields keep `false` and stay inert.
