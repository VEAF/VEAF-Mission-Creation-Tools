# Lot PERF-LUADATA-PARSER — speed up the pure-Python Lua parser on large missions

Status: ✅ done

**Goal**: SECREV-001 replaced the lua-executing parser with a pure-Python state machine to remove RCE. On large missions (Flogas, 8.9 MB `.miz`) the build became 5-10× slower — `read_miz` ≈ 0.86 s, dominated by the parser. Profiling showed two hotspots: `node_entries_append` re-sorted + rescanned the whole entry list on **every** append (`O(n²·log n)` per table), and the main loop walked the input one byte at a time (`sbins[pos:pos+1]` slice + whitespace test per char). Recover speed without reintroducing code execution.

**Branch**: `perf/luadata-parser` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| PERF-LUADATA-PARSER-001 | (a) Stop sorting/rescanning on every append — keep entries in append order, track array length incrementally via an int-key set, sort once lazily in `node_to_table` (`O(n²·log n)` → `O(n)`). (b) Skip insignificant whitespace runs at C speed (`re.search`) in states where whitespace only advances the cursor. `read_miz` 0.86 s → 0.33 s (~2.6×). Output identical (array/sparse-key ordering, whitespace-insensitivity, string whitespace preserved — guarded by tests). | `luadata/serializer/unserialize.py`, `test/python/security/test_luadata_parser_perf.py` | perf | ✅ |
