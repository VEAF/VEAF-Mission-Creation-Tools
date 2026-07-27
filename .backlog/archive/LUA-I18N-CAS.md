# Lot LUA-I18N-CAS — localize `_cas` user-facing messages

Status: ✅ done

**Goal**: LUA-I18N-004 routed most module messages through `veaf.t` but missed `veafCasMission`'s on-screen text, which stays English even when `veaf.config.language = "fr"`. Found during DCS-UPDATE-VERIFY (R3-FINDING-3). In scope: the short post-`_cas` spawn confirmation (`veafCasMission.lua:1103`, "TARGET: Group of N vehicles and M soldiers…") and any other short CAS feedback. The detailed F10 target report (LAT/LON, MGRS, bullseye, weather, ~1118-1151) is the "data report" category LUA-I18N-004 deliberately deferred — decide whether to include it. Add `veaf.t` keys with FR + EN catalog entries (`veafI18n.lua`) and Lua tests, following the LUA-I18N-004 pattern.

**Done**: decision was to localize **all** of `veafCasMission`'s own on-screen text (per user — "tous les messages VEAF localisés sauf modules communautaires comme CTLD"). 11 `cas.*` catalog keys added (FR + EN): spawn confirmation, full target report (target/AFAC/LAT-LON decimal & DMS/MGRS/from-bullseye value & line/weather header) and the `_cas` HELP text. The weather **body** stays English — it is `veafWeatherData.getWeatherString(...)`, a different module out of this lot's scope. Command tokens (`_cas`, `defense`, `size`, `armor`, `spacing`) kept literal in both languages. 9 new tests in `test/lua/test_veafI18n.lua` (17 total, all green).

**Branch**: `feature/lua-i18n-cas` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| LUA-I18N-CAS-001 | Route the short `_cas` feedback messages through `veaf.t` (FR + EN); decide on the detailed target report; Lua tests | `src/scripts/veaf/veafCasMission.lua`, `src/scripts/veaf/veafI18n.lua`, `test/lua/` | feat | ✅ |
