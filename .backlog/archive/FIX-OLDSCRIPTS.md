# Lot FIX-OLDSCRIPTS — detect residual .lua files in src/scripts/

Status: ✅ done

**Goal**: Detect residual v5 `.lua` files in `src/scripts/` of a converted mission and emit a warning at build time.

**Context**: The original bug (`veafCommands nil`) was resolved by Lot FIX-BUNDLE. Potential secondary cause not addressed: individual v5 VEAF `.lua` files still present in `src/scripts/` could be loaded via the `src/scripts/*.lua` glob and create DCS runtime conflicts. OLDSCRIPTS-002 can be implemented independently of the investigation.

**Branch**: `fix/oldscripts-detection` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| OLDSCRIPTS-000 | Investigation: reproduce the bug with a real v5→v6 mission; obtain full DCS logs; identify the responsible file | — | chore | 15 min | ✅ (resolved — see context) |
| OLDSCRIPTS-001 | Fix: based on investigation result, fix the identified root cause | TBD | fix | TBD | ✅ (resolved by FIX-BUNDLE) |
| OLDSCRIPTS-002 | Add a warning if unexpected `.lua` files are present in `src/scripts/` (i.e. not explicitly listed in `get_mission_script_files()`) | `mission_tools/mission_constants.py` or `mission_builder_worker.py` | fix | 15 min | ✅ |
