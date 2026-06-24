# Lot SPAWN-REFACTOR — Characterize then de-duplicate the spawn subsystem

Status: ✅ done

**Goal**: The spawn subsystem — `veafSpawnParser` (656 l., 47 parameter rules), `veafSpawnAircraft` (1486 l.), `veafSpawnGround` (1034 l.) — carries heavy copy-paste (repeated parameter validation, ~15-line debug-log blocks duplicated verbatim, 30+ repetitive default-option blocks) and has **zero luaunit tests** despite being the most complex, most pilot-facing code. Lock current behaviour with characterization tests **first**, then de-duplicate safely.

> **Coordination**: TODO0609-SPAWN-EXTERNALIZE and TODO0609-AIRCRAFT-INJECT reopen these same files. De-duplicate **there**, within those lots' scope, rather than twice — this lot may be folded into SPAWN-EXTERNALIZE once -001 lands. Respect `CLAUDE.md` §2 RULE N°1 (no refactor outside a lot already touching the file).

**Branch**: `refactor/spawn-subsystem` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| SPAWN-REFACTOR-001 | Characterization tests for `veafSpawnParser.markTextAnalysis`: 41 marker variants (rejects/typos/missing values, every command + defaults, air-role defaults, parameter parsing), captured against the live parser and asserting only deterministic fields (math.random defaults left unasserted). Locks behaviour before any dedup; unblocks UXPILOT-003. | `test/lua/test_veafSpawnParser.lua` | feat | ✅ |
| SPAWN-REFACTOR-002 | Extract a spawn-type **descriptor table** (`{type → {defaults, validators}}`) consumed by the parser, and a shared `VeafSpawner` base for the duplicated validation/debug blocks. Only within the scope of a lot already touching these files. Done as SPAWN-EXTERNALIZE-005: `CommandDescriptors` (per-command defaults) + `ParameterRules` (keyword parsing) tables, and centralized the security preamble in `registerCommandHandler`/dispatch. | `src/scripts/veaf/veafSpawnParser.lua`, `veafSpawnAircraft.lua`, `veafSpawnGround.lua`, `veafSpawnCore.lua`, `test/lua/` | refactor | ✅ |
