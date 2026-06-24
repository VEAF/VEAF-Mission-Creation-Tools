# Lot FIX-AIRWAVES-GENERATOR — generated AirWaves configs call non-existent setters

Status: ✅ done

**Goal**: `lua_config_generator._emit_airwave_zone` emitted an `AirWaveZone:new():…:start()` chain including setters absent from `src/scripts/veaf/veafAirWaves.lua` (`setMessageWaveDeployed`, `setMessageEndZone`, `setMessageEndAll`, `setMinimumSecondsBetweenWaves`, `setMaximumSecondsBetweenWaves`). In Lua a nil method call raises "attempt to call method '…' (a nil value)" → any mission whose `mission.yaml` configures an AirWaves zone crashed at mission start. Found during the DOC-REVIEW audit (out of doc scope).

**Branch**: `fix/airwaves-generator` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-AIRWAVES-GENERATOR-001 | Emit only real `AirWaveZone` methods: map `message_wave_deployed`→`setMessageDeploy`, `message_end_zone`→`setMessageWon`; collapse the inter-wave delay to a single `setDelayBetweenWaves` (prefer the configured min — no runtime random range); drop the unsupported `message_end_all` + max-delay bound. Add a test parsing `veafAirWaves.lua` for the real `AirWaveZone` methods that asserts every emitted method exists | `src/python/veaf-tools/veaf_libs/lua_config_generator.py`, `test/python/veaf_libs/test_lua_config_generator.py` | fix | ✅ |

**Done**: generator emits only verified `AirWaveZone` setters; 3 regression tests (`test_emit_airwave_zone_only_real_methods` parses the Lua and asserts no emitted method is non-existent; plus message-mapping and delay-collapse tests). The Lua's runtime model has no random min/max inter-wave delay and no "all zones cleared" message, so those config keys collapse/drop rather than crash. (A proper random-delay + cross-zone-message feature in `veafAirWaves.lua` would be a separate enhancement, not a bug fix.)
