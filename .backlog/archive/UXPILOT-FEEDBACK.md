# Lot UXPILOT-FEEDBACK — Surface command errors to pilots

Status: ✅ done

**Goal**: A pilot who mistypes an F10 marker command usually gets **no feedback**, and error surfacing is inconsistent across modules. `veafSpawnAircraft` (`:67`) and `veafShortcuts` (`:625`) call `trigger.action.outText(...)`, but `veafNamedPoints.executeCommand` returns `false` silently and `veafSpawnParser` silently ignores unrecognized parameters (47-rule if-chain). A handler that crashes only logs to the DCS log — invisible in-game. Establish one feedback path and a global safety net so pilot mistakes and runtime errors are always visible.

**Branch**: `feature/uxpilot-feedback` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| UXPILOT-001 | **Global safety net**: the `veafMarkers.onEvent` dispatch (already `pcall`-wrapped + logged) now also surfaces a short in-game message to the placing coalition when a handler errors; the stack stays in the DCS log. luaunit tests (handler raises → reportToPilot called; success → not called). | `src/scripts/veaf/veafMarkers.lua`, `test/lua/` | feat | ✅ |
| UXPILOT-002 | **Unified feedback helper**: added `veaf.reportToPilot(message, duration, coalition)` (thin wrapper over `outText` / `outTextForCoalition`), used by 001 and 003. **Note**: the planned `veafNamedPoints.executeCommand` routing was dropped — its `markTextAnalysis` never returns nil when the keyphrase is present, so the "parse failed" branch is unreachable (no genuine silent failure to route there). | `src/scripts/veaf/veaf.lua`, `test/lua/` | feat | ✅ |
| UXPILOT-003 | **Unknown-parameter hints**: `markTextAnalysis` now collects unrecognized parameter keys into `options.unknownParameters` (skipping the command keyphrase), with a nearest-key suggestion via `veaf.nearestMatch` (Levenshtein); `veafSpawn.executeCommand` reports them to the placing pilot. Known keys live in `veafSpawn.KnownParameterKeys`. luaunit tests (unknown collected, typo→suggestion, valid input clean). | `src/scripts/veaf/veafSpawnParser.lua`, `src/scripts/veaf/veafSpawnCore.lua`, `src/scripts/veaf/veaf.lua`, `test/lua/` | feat | ✅ |
