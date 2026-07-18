# 03 — Auto Dynamic Spawn slots on assignment

Status: ⬜ ready

## Goal

Assigning a base to a coalition also enables its Dynamic Spawn slots and stocks its warehouse with
that coalition's dynamic templates — "by default, activate dyn slots + fill with dynamic spawnables".

## Details

- On `set_airbase_coalition`, also set `entry["dynamicSpawn"] = True` (recipe side).
- The actual warehouse **filling** (stock + `linkDynTempl`) happens at build via the existing
  `warehouses_injector`, which needs the injected templates' `groupId`s. So:
  - Ship an **effective** default `src/warehouses.yaml` (replace the fully-commented default): declare
    `blue:`/`red:` with `defaults` (unlimited fuel/munitions + dynamic-spawn) and **no** `airports:`
    list, so the injector applies to *every* airfield of that coalition — which, in lazy mode, is
    exactly the base(s) just assigned.
  - Add a worker mode to **auto-fill** a coalition's warehouse from all injected dynamic templates of
    that coalition when the config does not enumerate `aircrafts` (derive the type list from the
    `dynSpawnTemplate=true` groups already present). Keep explicit `aircrafts` overriding.
- Defaults lockstep: update `src/defaults/mission-folder/src/warehouses.yaml`.
- If `warehouses_injector_worker.py` is under the mypy `ignore_errors` list and is substantially
  edited, drop its entry and fix the types.

## Tests

- `set_airbase_coalition` sets `dynamicSpawn` on the entry.
- Worker auto-fill: a coalition with no explicit `aircrafts` stocks every injected template of that
  coalition (planes/helicopters under the right category) and links `linkDynTempl` to the right
  `groupId`.
- Explicit `aircrafts` still overrides auto-fill.
