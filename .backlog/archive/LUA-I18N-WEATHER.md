# Lot LUA-I18N-WEATHER — localize the `veafWeatherData` report

Status: ✅ done

**Goal**: follow-up to LUA-I18N-CAS. The weather report produced by `veafWeatherData` (`veafWeather.lua`, `toString` / `toStringExtended` / `toStringAtis` and their helpers) was left English, but per the project rule every VEAF on-screen message must be localized (only community modules like CTLD are exempt). It is shown after `_cas` (F10 target report), in `veafCombatZone`, and on the carrier weather menu. Route all user-facing descriptive words and labels through `veaf.t` with FR + EN catalog entries: wind `calm`, cloud densities (`No clouds`/`Scattered`/`Broken`/`Overcast`/`Few clouds`), visibility affects (`fog`/`haze`/`mist`/`dust`/`precipitations`), and the report/ATIS line labels (`Wind`/`Visibility`/`Clouds`/`Temperature`/`Dew point`/`Sunrise`/`Sunset`/`Time`/`Location`/`Altitude`, ATIS phraseology). **Decision (user)**: standardized aeronautical abbreviations stay as-is in both languages (`CAVOK`, `QNH`, `QFE`, `kts`, `m/s`, `NM`, `SM`, `ft`, `Hpa`, `inHg`, `mmHg`, `°M`/`°T`, `AGL`/`ASL`, `FL`, `LASTE`) — a FR pilot reads them unchanged. Logs stay English. Existing `test_veafWeather.lua` rendering tests assert the English words under the default FR config, so they must load `veafI18n.lua` and pin `language = "en"`; FR coverage is added at the catalog level in `test_veafI18n.lua`.

**Branch**: `feature/lua-i18n-weather` → PR → `develop-v6`

**Done**: 28 `weather.*` catalog keys added (FR + EN); all descriptive words/labels in `toStringWind`/`toStringVisibility`/`toStringClouds`/`toString`/`toStringExtended`/`toStringAtis` routed through `veaf.t`. Aeronautical abbreviations kept verbatim per the user decision. `test_veafWeather.lua` now loads `veafI18n.lua` and pins `language = "en"` (its assertions verify the English wording + format logic); 6 FR catalog tests added to `test_veafI18n.lua` (23 total). Full Lua suite green, stylua clean.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| LUA-I18N-WEATHER-001 | Route the `veafWeatherData` report (toString/Extended/Atis + helpers) through `veaf.t` (FR + EN), keep aeronautical abbreviations; update `test_veafWeather.lua` (load i18n, pin en) and add FR catalog tests | `src/scripts/veaf/veafWeather.lua`, `src/scripts/veaf/veafI18n.lua`, `test/lua/` | feat | ✅ |
