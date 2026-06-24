# Lot LUA-I18N — Localize in-game VEAF messages (Lua runtime; FR default + EN)

Status: ✅ done

**Goal**: The Lua runtime (scripts executing inside DCS) has **no i18n** — every pilot-facing message (`trigger.action.outText*`) is a hardcoded **English** literal. Add a lightweight Lua i18n layer so in-game messages can be localized, with **French as the default** and English available. This is the runtime counterpart of the design-time i18n the Python tools already have (`veaf_libs.i18n` + `locales/{en,fr}.json`). Driver: UXPILOT-FEEDBACK shipped English-only pilot messages because there was nothing to localize against (see its note).

**Design constraints / open questions** (resolve in the spike):

- **Mechanism**: a `veaf.t(key, ...)` lookup over a catalog `{ key = { fr = "...", en = "..." } }`, with `string.format`-style interpolation and fallback (missing language → default FR → key).
- **Active language**: set once from `mission.yaml` (e.g. `language: fr|en`) → emitted by `lua_config_generator` into `veaf-config.lua` as `veaf.language` (default `"fr"`). DCS does **not** expose a reliable per-pilot UI language, so this is mission-global (not per-coalition/per-pilot) unless a cheap per-player signal is found.
- **Catalog location**: one Lua catalog module loaded by the framework (e.g. `veafI18n.lua`), vs per-module inline tables. Keep it test-friendly (`poetry run test-lua`).
- **Migration is incremental**: ship the framework + the UXPILOT pilot-feedback messages first; migrate the rest module-by-module (hundreds of `outText` literals — erode over time, do not big-bang).

**Branch**: `feat/lua-i18n` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| LUA-I18N-001 (spike) | Decide the mechanism, the active-language source (mission.yaml → `veaf-config.lua` → `veaf.language`, default FR), catalog layout, and fallback rules. Deliverable: design note + framework skeleton + tests. | `src/scripts/veaf/`, `doc/`, `test/lua/` | spike | ✅ |
| LUA-I18N-002 | Implement `veaf.t(key, ...)` + the catalog + `veaf.language` wiring (`lua_config_generator` emits it from `mission.yaml`, default `"fr"`); fallbacks (lang → FR → key). luaunit tests. | `src/scripts/veaf/veaf.lua` (or `veafI18n.lua`), `veaf_libs/lua_config_generator.py`, `src/defaults/mission-folder/mission.yaml`, `test/lua/`, `test/python/` | feat | ✅ |
| LUA-I18N-003 | Migrate the **pilot-feedback** messages (UXPILOT-FEEDBACK: `veaf.reportToPilot` call sites in `veafMarkers` / `veafSpawnCore`) to `veaf.t`, with FR + EN entries — the first real consumer. | `src/scripts/veaf/veafMarkers.lua`, `src/scripts/veaf/veafSpawnCore.lua`, catalog, `test/lua/` | feat | ✅ |
| LUA-I18N-004 | Migrate the hardcoded in-game messages to `veaf.t` (FR + EN). Done across all modules with pilot-facing prose: spawn, combat zone/mission, missile guardian, CAS, transport (incl. help), move, radio, security, skynet helper, named points, ground AI, carrier ops, sanctuary enforcement, shortcuts, weather fog, assets. Logs stay English; only on-screen text localized. **Deliberately out of scope**: mission-configurable templates (Air-Waves, QRA, Ground-AI start/stop, Combat-Zone events, Sanctuary warnings — user-overridable, not catalog material) and large data reports (weather/ATC METAR report, transport nav report, carrier list/recovery status). Localizing those = a separate lot if ever wanted. | `src/scripts/veaf/*.lua`, catalog, `test/lua/` | feat | ✅ |
