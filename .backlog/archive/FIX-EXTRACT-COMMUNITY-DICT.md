# Lot FIX-EXTRACT-COMMUNITY-DICT — `extract` crashes with KeyError on community script dicts

Status: ✅ done

**Goal**: `veaf-tools extract` raised `KeyError: 1` because `extract_mission` still indexed every script-file entry as a `(path, dest)` tuple, while `get_community_script_files()` was refactored (lot COMM-001) to return dicts. Normalize the iteration so community dicts are handled by their `path`/`dest` keys.

**Branch**: `fix/extract-community-dict` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-EXTRACT-COMMUNITY-DICT-001 | Normalize the cleanup loop in `extract_mission` to accept both tuple (VEAF/legacy) and dict (community) script descriptors; add an end-to-end regression test extracting a `.miz` that bundles a community script. | `mission_extractor/mission_extractor_worker.py`, `test/python/mission_extractor/test_mission_extractor_worker.py` | fix | ✅ |
