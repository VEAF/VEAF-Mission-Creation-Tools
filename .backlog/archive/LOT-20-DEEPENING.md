# Lot 20 — DEEPENING: Architecture deepening Python + Lua ✅

Status: ✅ done

**Goal**: `Group` dataclass + `iter_groups()`, `DcsMission` weather/options accessors, suppression du traversal dupliqué dans les injectors, base class `GroupInjectorWorker`, migration `veafGroundAI` → `veafCommands`, restructuration options spawn, config resolution dans `MissionBuilderWorker`.

| # | Ticket | File(s) | Type | Effort | Status |
|---|--------|---------|------|--------|--------|
| DEEP-001 | `Group` dataclass + `DcsMission.iter_groups()` + tests | `miz_tools.py`, `__init__.py`, `test_miz_tools.py` | feat | 60 min | ✅ |
| DEEP-002 | `DcsMission.get/set_weather()` + `get/set_options()` | `miz_tools.py`, `weather_injector_worker.py` | feat | 30 min | ✅ |
| DEEP-003 | Supprimer traversal dupliqué des 3 injectors | `presets_injector_worker.py`, `waypoints_injector_worker.py` | chore | 60 min | ✅ |
| DEEP-004 | `GroupInjectorWorker` base class | `veaf_libs/group_injector_worker.py`, injectors | feat | 60 min | ✅ |
| DEEP-005 | `veafGroundAI` → `veafCommands.registerCommandHandler` | `veafGroundAI.lua`, `veafCommands.lua` | chore | 30 min | ✅ |
| DEEP-006 | Restructuration table options spawn `markTextAnalysis()` | `veafSpawnParser.lua` | chore | 60 min | ✅ |
| DEEP-007 | Config resolution dans `MissionBuilderWorker.__init__()` | `mission_builder_worker.py`, `build.py` | chore | 60 min | ✅ |

**Raw total: 360 min → ~414 min (~7h)**
