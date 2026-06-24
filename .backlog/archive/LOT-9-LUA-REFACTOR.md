# Lot 9 — LUA-REFACTOR: Refactoring structurel des modules majeurs

Status: ✅ done

**Goal**: Réduire la complexité des modules les plus chargés du codebase Lua.
Chaque ticket est indépendant mais risqué — à traiter un par un avec tests en mission réelle.
**Branch**: une branche par ticket `refactor/lua-xxx` → PR → `develop-v6`
⚠️ Impact fort sur les missions existantes : chaque PR doit être testée en mission avant merge.

| # | Ticket | File(s) | Type | Effort | Status |
|---|--------|---------|------|--------|--------|
| LUAR-001 | Scinder `veafSpawn.lua` (3200+ lignes) en 4 modules thématiques — `veafSpawn.lua` devient un proxy de backward compatibility | `veafSpawn*.lua` | feat | 240 min | ✅ |
| LUAR-002 | Machine d'état explicite (FSM) pour `AirWaveZone` | `veafAirWaves.lua` | feat | 120 min | ✅ |
| LUAR-003 | Scinder `VeafQRA` (1200+ lignes) en `VeafQRACore` + `VeafQRALogistics` | `veafQraManager.lua` | feat | 150 min | ✅ |
| LUAR-004 | `RadioMenuBuilder` — abstraction de la construction des menus dans veafRadio | `veafRadio.lua` | feat | 90 min | ✅ |

**Raw total: 600 min → estimated (×1.15): ~690 min (~11h30)**

> LUAR-005 migré vers **Lot 14 — ARCH-COMMANDS** (ARCH-004 + ARCH-005) après analyse : le pattern marker/command est transversal à 8+ modules.

<details>
<summary>Ticket details</summary>

**LUAR-001 — Split veafSpawn.lua**
3200+ lignes, 35+ fonctions publiques avec 5 responsabilités distinctes. Proposition de découpage :
- `veafSpawnCore.lua` — `executeCommand`, parsing de markers, `doSpawnGroup`, `_createDcsUnits`, dessin (addPointToDrawing, drawCircle, drawSquare, eraseDrawing)
- `veafSpawnGround.lua` — `spawnGroup`, `spawnInfantryGroup`, `spawnArmoredPlatoon`, `spawnAirDefenseBattery`, `spawnTransportCompany`, `spawnFullCombatGroup`, `spawnConvoy`, `spawnFarp`, `spawnFob`
- `veafSpawnAircraft.lua` — `spawnUnit` (avions/hélicos), `spawnCombatAirPatrol`, JTAC/lasing
- `veafSpawnEffects.lua` — `spawnBomb`, `spawnSmoke`, `spawnSignalFlare`, `spawnIlluminationFlare`, `spawnCargo`, `spawnLogistic`, `destroy`, `teleport`

**Décision (2026-05-21)** : `veafSpawn.lua` devient un **proxy** qui charge les 4 sous-modules et ré-exporte les fonctions publiques — les missions existantes n'ont rien à changer. Pas de deprecation warnings (DISC-016 rejeté) : le proxy est transparent et silencieux, les missions continueront de fonctionner indéfiniment.

**LUAR-002 — FSM AirWaveZone**
`AirWaveZone` gère 7+ états (`READY`, `WAITING_FOR_HUMANS`, `ACTIVE`, `WAITING_FOR_NEXTWAVE`, `CLEANUP`, `DONE`, `PAUSED`) via des variables booléennes et des `if/elseif` chaînés dans `check()`.
Refactorer en FSM explicite :
```lua
AirWaveZone.FSM = {
  READY = { enter = AirWaveZone._onEnterReady, transitions = { WAITING_FOR_HUMANS = AirWaveZone._canWaitForHumans } },
  ACTIVE = { enter = AirWaveZone._onEnterActive, transitions = { WAITING_FOR_NEXTWAVE = AirWaveZone._waveEnded } },
  ...
}
```
Bénéfice : `check()` devient une boucle sur `FSM[self.state].transitions`, pas de if imbriqués, états clairement documentés.

**LUAR-003 — Split VeafQRA**
`VeafQRA` fait 1200+ lignes avec 3 responsabilités :
1. **Détection + spawn** : `check()`, `humanBornEvent()`, `spawnQra()`, `despawnQra()`
2. **Logistique** : `rearm()`, `resupply()`, `refuel()`, délais de ravitaillement
3. **Communication** : messages radio, marqueurs carte, `getInformation()`

Proposition :
- `VeafQRACore` — état, détection, spawn/despawn
- `VeafQRALogistics` — rearm/resupply/refuel (classe séparée, référencée depuis Core)
- Laisser les messages dans Core mais extraire `VeafQRA:buildStatusMessage()` en helpers

**LUAR-004 — RadioMenuBuilder**
`veafRadio.lua` construit les menus DCS missionCommands via des appels `missionCommands.addSubMenu` / `addCommand` entrelacés avec la logique de rebuild. Créer `RadioMenuBuilder` :
```lua
local RadioMenuBuilder = {}
function RadioMenuBuilder:new(root) ... end
function RadioMenuBuilder:addMenu(label, parent) ... end
function RadioMenuBuilder:addCommand(label, parent, fn, args) ... end
function RadioMenuBuilder:build() ... end
function RadioMenuBuilder:rebuild() ... end  -- clear + rebuild
```
Isole la complexité de l'arbre DCS et facilite le test unitaire.

</details>
