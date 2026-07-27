# Lot CONVERT-CUSTOM-LOADER-HINT — guide custom Lua loaders to v6 `custom_scripts:`

Status: ✅ done

**Goal**: IMC-Day testing (Flogas) showed a v5 mission whose own `src/scripts/VeafDynamicLoader.lua` is a *mission-scripts loader* (its own ordered `scriptsToLoad`: Moose, FgTools, FgWeather, FgCsg2, missionConfig, FgMission). `convert-v5` does not (and should not) parse arbitrary custom loaders, so those scripts were never registered as `custom_scripts:` → no load trigger → the runtime F10 menu was missing (the real **IMC2-003** root cause). Per David: do **not** build a brittle parser for one specific loader shape; instead detect generically that an undeclared `.lua` *loads other scripts* and point the user at the v6 `custom_scripts:` mechanism. Also resolves the misleading "unexpected lua file" advice for the v5 `VeafDynamicLoader.lua` (name-collides with the v6 framework loader — see ADR 0004).

**Branch**: `feat/custom-loader-hint` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CUSTOM-LOADER-HINT-001 | When the build finds an undeclared `src/scripts/*.lua` whose content loads other scripts (heuristic on `loadfile`/`dofile`/`require`/`a_do_script_file`/`do_script_file`), emit an explanatory warning pointing to the v6 `custom_scripts:` section (instead of the generic "declare it" advice). Generic, no parsing of the loaded list. Replaces the IMC2-003 auto-migration idea (deemed too brittle for rare advanced cases). | `mission_builder/mission_builder_worker.py`, locales, `test/python/` | feat | ✅ |
