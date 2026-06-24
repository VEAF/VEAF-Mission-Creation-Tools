# Lot FIX-MARKERS-INIT — add missing `veafMarkers.initialize()`

Status: ✅ done

**Goal**: Fix DCS runtime error `attempt to call field 'initialize' (a nil value)` on `veafMarkers`.

**Context**: The `initialize()` function was missing from `veafMarkers.lua` even though `veaf-config.lua` always calls it. The module was already self-initializing on load; the added function simply logs.

**Branch**: direct commit without branch (minimal fix, tested by user)

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| MARKERS-INIT-001 | Add `veafMarkers.initialize()` to `src/scripts/veaf/veafMarkers.lua` | `src/scripts/veaf/veafMarkers.lua` | fix | 5 min | ✅ |
