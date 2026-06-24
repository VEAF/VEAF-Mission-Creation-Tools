# Lot 16 — LUA-COVERAGE: Couverture de tests ≥ 50 % par module

Status: ✅ done

**Goal**: Faire passer chaque module Lua à au moins 50 % de couverture de ligne (mesurée via `poetry run test-lua --coverage`).
Couverture initiale (2026-05-23) : 48,35 % global, mais 26 modules en dessous du seuil.
**Branch**: une branche par ticket `test/cov-xxx` → PR → `develop-v6`
⚠️ Certains modules nécessitent d'étoffer `dcs_mocks.lua` pour exposer des chemins de code difficiles à atteindre.

| # | Ticket | Modules ciblés (couverture actuelle) | Type | Effort | Status |
|---|--------|--------------------------------------|------|--------|--------|
| COV-001 | `veaf.lua` → 50 % (31 %) — utilitaires core : `veaf.p`, `veaf.safeCall`, timers, loggers, `getCountryForCoalition`, `getClosestAirbase` | `veaf.lua` | chore | 90 min | ✅ |
| COV-002 | `veafSpawn` sub-modules → 50 % chacun — Core (19 %), Ground (6 %), Aircraft (3 %), Effects (7 %) ; nécessite mock `mist.dynAdd` et `trigger.action.*` | `veafSpawnCore`, `veafSpawnGround`, `veafSpawnAircraft`, `veafSpawnEffects` | chore | 180 min | ✅ |
| COV-003 | `veafCombatMission` (32 %) + `veafCombatZone` (26 %) → 50 % chacun — logique d'état de zone, spawn de vagues, victoire | `veafCombatMission.lua`, `veafCombatZone.lua` | chore | 120 min | ✅ |
| COV-004 | `veafAirWaves` (34 %) + `veafCarrierOperations` (9 %) → 50 % chacun — FSM AirWave, helpers carrier | `veafAirWaves.lua`, `veafCarrierOperations.lua` | chore | 120 min | ✅ |
| COV-005 | `veafRadio` (30 %) + `veafShortcuts` (10 %) → 50 % chacun — construction de menus, dispatch de raccourcis | `veafRadio.lua`, `veafShortcuts.lua` | chore | 90 min | ✅ |
| COV-006 | `veafQraCore` (43 %) + `veafQraLogistics` (31 %) + `veafSkynetIadsHelper` (11 %) + `veafSkynetIadsMonitor` (23 %) → 50 % chacun | `veafQraCore.lua`, `veafQraLogistics.lua`, `veafSkynetIadsHelper.lua`, `veafSkynetIadsMonitor.lua` | chore | 90 min | ✅ |
| COV-007 | `veafCasMission` (47 %) + `veafTransportMission` (21 %) + `veafGroundAI` (28 %) + `veafMove` (18 %) → 50 % chacun | `veafCasMission.lua`, `veafTransportMission.lua`, `veafGroundAI.lua`, `veafMove.lua` | chore | 90 min | ✅ |
| COV-008 | `veafAirbases` (29 %) + `veafAssets` (23 %) + `veafInterpreter` (39 %) + `veafMissileGuardian` (36 %) + `veafRemote` (32 %) + `veafSanctuary` (31 %) + `veafWeather` (37 %) → 50 % chacun | 7 fichiers | chore | 120 min | ✅ |

**Raw total: 900 min → estimated (×1.15): ~1035 min (~17h15)**

> Modules déjà ≥ 50 % (non ciblés) : `dcsDataExport` (55 %), `veafCacheManager` (100 %), `veafCommands` (76 %), `veafEventHandler` (83 %), `veafGrass` (70 %), `veafMarkers` (52 %), `veafNamedPoints` (97 %), `veafQraManager` (100 %), `veafSecurity` (59 %), `veafSpawn` proxy (100 %), `veafSpawnParser` (54 %), `veafTime` (87 %), `veafUnits` (78 %).
