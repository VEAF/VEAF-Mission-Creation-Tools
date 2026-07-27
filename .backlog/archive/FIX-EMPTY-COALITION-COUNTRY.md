# Lot FIX-EMPTY-COALITION-COUNTRY — build crash on an empty coalition side

Status: ✅ done

**Goal**: `veaf-tools build` crashed with `AttributeError: 'dict' object has no attribute 'append'` (`coalition_placeholder._find_or_add_country`) on a minimal mission where one side is empty. An empty DCS `country = {}` Lua table deserializes to a dict (not a list) under `all_is_dict`, so `setdefault("country", [])` returned the existing dict and `.append` failed. Reproduced with a single-A-10C Caucasus mission (blue populated, red/neutrals empty).

**Branch**: `fix/empty-coalition-country` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-EMPTY-COALITION-COUNTRY-001 | Coerce a coalition's `country` to a list (handling the empty-`{}` dict case, keeping any values) before appending the placeholder country. Regression test with `country: {}`. | `mission_builder/coalition_placeholder.py`, `test/python/mission_builder/test_coalition_placeholder.py` | fix | ✅ |
