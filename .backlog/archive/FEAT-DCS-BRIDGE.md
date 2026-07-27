# Lot FEAT-DCS-BRIDGE — Optional dcs-bridge.lua injection

Status: ✅ done

**Goal**: Allow the build tool to optionally inject `dcs-bridge.lua` into a DCS mission via a DO SCRIPT FILE trigger, controlled by a flag in `mission.yaml`.

**Branch**: `feature/dcs-bridge-injection` → PR → `develop`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| DCSB-001 | Add optional `dcs_bridge.enabled` key (bool, default `false`) to the `mission.yaml` schema and `MissionConfig` dataclass | `src/defaults/mission-folder/mission.yaml`, `mission_config.py` | feat | 15 min | ✅ |
| DCSB-002 | Add optional `dcs_bridge.lua_path` key (path to `dcs-bridge.lua`; auto-detected from a well-known location if absent) | `mission_config.py` | feat | 15 min | ✅ |
| DCSB-003 | Copy `dcs-bridge.lua` into the build output and inject the DO SCRIPT FILE trigger into the mission | `mission_builder_worker.py` | feat | 30 min | ✅ |
| DCSB-004 | TDD tests: trigger injected when `enabled: true`, absent when `false`, error raised when file not found | `test/` | test | 20 min | ✅ |
| DCSB-005 | Document `dcs_bridge` section in the default `mission.yaml` and in the user documentation | `src/defaults/mission-folder/mission.yaml`, `doc/` | doc | 10 min | ✅ |
