# Lot LUA-I18N-SWEEP — localize all remaining VEAF on-screen messages

Status: ✅ done

**Goal**: complete the i18n migration started by LUA-I18N-004/CAS/WEATHER. Per the project rule, every VEAF on-screen message must be localized (only community modules like CTLD are exempt). An exhaustive parallel audit of all non-community `veaf*.lua` modules found ~100 player-facing strings (passed to `outText*` / `markTo*`) still hardcoded in English. Route them all through `veaf.t` with FR + EN catalog entries.

**Decisions**:

- **Brevity / aeronautical codes stay verbatim** in both languages (extends the WEATHER decision): TACAN, ICLS, LINK 4, ACLS, BRC, COMM, BRA, MERGED, CAVOK, QNH, QFE, kn, kts, NM, SM, MGRS, AM, SRS, etc.
- **F10 radio-menu labels are out of scope** — they double as `delCommand` identifiers, so localizing them would break command removal.
- **Mission-overridable default messages** (QRA, AirWaves, Sanctuary, GroundAI, MissileGuardian, the default CAP objective) now store i18n **keys** as their defaults and resolve them through `veaf.t` at send time: the default localizes, while a mission's custom override passes through unchanged (`veaf.t` returns an unknown key verbatim before formatting).
- Logs stay English; only on-screen text is localized.

**Branch**: `feature/lua-i18n-sweep` → PR → `develop-v6`

**Done**: ~95 catalog keys added (FR + EN) across `move.*`, `namedpoints.*`, `spawn.*`, `qra.*`, `airwaves.*`, `sanctuary.*`, `groundai.*`, `mg.*`, `report.*` (shared coord/count fragments), `combatzone.*`, `combatmission.*`, `carrier.*`, `transport.*`. 13 modules routed through `veaf.t`. Rendering tests in `test_veafCombatZone`/`test_veafCombatMission`/`test_veafCarrierOperations` now load `veafI18n.lua` and pin `language = "en"`; representative FR/EN tests added to `test_veafI18n.lua` (32 total). Full Lua suite green (34 suites), stylua clean, no duplicate catalog keys.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| LUA-I18N-SWEEP-001 | Audit + route all remaining non-community VEAF on-screen messages through `veaf.t` (FR + EN); key-as-default pattern for overridable templates; keep brevity codes and radio-menu labels; update affected rendering tests + add FR catalog tests | `src/scripts/veaf/*.lua`, `src/scripts/veaf/veafI18n.lua`, `test/lua/` | feat | ✅ |
