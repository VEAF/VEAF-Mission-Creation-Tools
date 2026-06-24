# Lot WEATHERMARK-REMOVE — retire the WeatherMark community script

Status: ✅ done

**Goal**: WEATHERMARK is no longer used by VEAF. Remove it everywhere now that the default no longer references it.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| WEATHERMARK-REMOVE-001 | Remove the `weathermark` community script: drop `src/scripts/community/WeatherMark.lua`, the `weathermark` entry in `get_community_script_files()`, any validator/i18n references, and the documentation. Ensure no build/convert path still references it. | `mission_tools/mission_constants.py`, `src/scripts/community/`, `doc/`, `test/python/` | chore | ✅ |
