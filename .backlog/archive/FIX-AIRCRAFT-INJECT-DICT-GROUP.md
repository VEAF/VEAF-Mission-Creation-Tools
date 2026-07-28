# Lot FIX-AIRCRAFT-INJECT-DICT-GROUP — aircraft-group injection crashes when the group container is a dict

Status: ✅ done

**Goal**: At build, the dynamic-slot template injection fails for **every** template with `Failed to inject group <X>: 'dict' object has no attribute 'append'` (David, on `d:\dev\_VEAF\tmp\test-tripack` after `prepare --template standard` + `extract`). The preceding spawnables injection (same `inject_groups` method, different coalition/country) succeeds.

**Root cause**: [`_ensure_aircraft_category`](src/python/veaf-tools/aircrafts_injector/aircrafts_injector_worker.py) (lines 634-656) only guarantees that `country[category]["group"]` **exists** (creates `[]` when missing) but not that it is a **list**. When the extracted mission already carries that container as a **dict** — a Lua table that luadata deserializes as a dict rather than a list (an empty `{}`, or a non-sequentially-keyed table) — the method returns the dict as-is, and `inject_groups` then calls `groups_list.append(...)` ([line 763](src/python/veaf-tools/aircrafts_injector/aircrafts_injector_worker.py)) → `'dict' object has no attribute 'append'`. The runtime error is itself the proof the container is a dict. The spawnables path hits a country whose `["group"]` is a list (or absent → created as `[]`), hence no crash there.

**Fix direction**: In `_ensure_aircraft_category`, after ensuring existence, normalize `country[category]["group"]` to a list — if it is a dict, replace it in `country` with `list(values())` (empty dict → `[]`, keyed dict → its group values, preserving any existing groups) so the subsequent `.append` works. (This is the recurring "luadata empty/keyed table → dict" pitfall; keep the fix local to the injector.)

**Branch**: `fix/aircraft-inject-dict-group` → PR → `develop` (Python injector only).

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-AIRCRAFT-INJECT-DICT-GROUP-001 | `_ensure_aircraft_category`: normalize the `["group"]` container to a list (dict → `list(values())`, including empty `{}` → `[]`), writing it back into `country`, before returning. pytest: a country whose `plane.group` / `helicopter.group` is a dict (empty and keyed) → `inject_groups(mode="add")` injects without raising and preserves any pre-existing groups. | `aircrafts_injector/aircrafts_injector_worker.py`, `test/python/` | fix | ✅ (#512) |
