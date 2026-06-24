# Lot FIX-SRS-WARN — false warning when SRS config file is absent

Status: ✅ done

**Goal**: Suppress the spurious `W|initialize` warning emitted when SRS is not installed. SRS integration is optional; an absent config file is normal, not an error.

**Root cause**: `veafRadio.lua:932-934` — `loadfile(srsConfigPath)` returns `nil` both when the file **does not exist** and when it exists but is invalid. The code logs a `warn` in both cases. Users without SRS see this warning on every mission start.

**Fix**: Use `lfs.attributes(srsConfigPath)` (already available via `l_lfs`) to test for file existence before calling `loadfile`:
- File absent → `debug` log ("SRS config not found, SRS integration disabled")
- File present but `loadfile` returns `nil` → keep `warn` (actual corruption/syntax error)

**File**: `src/scripts/veaf/veafRadio.lua`, around line 920–934.

**Branch**: `fix/srs-warn` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| SRS-001 | Check `lfs.attributes` before `loadfile`; downgrade absent-file log to `debug` | `src/scripts/veaf/veafRadio.lua` | fix | 10 min | ✅ |
