# Lot 8 — LUA-QUALITY: Code quality quick wins

Status: ✅ done

**Goal**: Targeted fixes for identified bugs and recurring anti-patterns in the Lua codebase.
No structural breakage — each ticket is isolated and low-risk.
**Branch**: `fix/lua-quality` → PR → `develop-v6`

| # | Ticket | File(s) | Type | Effort | Status |
|---|--------|---------|------|--------|--------|
| LUAQ-001 | Ajouter `unit:isExist()` guards dans `VeafQRA.check()` avant appels DCS | `veafQraManager.lua` | fix | 30 min | [x] |
| LUAQ-002 | Remplacer le pattern `arg`/`arg.n` (Lua 5.1 deprecated) par `{...}`/`select` dans `AirWaveZone:addWave()` | `veafAirWaves.lua` | chore | 20 min | [x] |
| LUAQ-003 | Wrapper `veaf.mist` pour centraliser les accès à `mist.DBs` (getUnitByName, getGroupByName, isHumanUnit) | `veaf.lua` + modules | chore | 60 min | [x] |
| LUAQ-004 | Factoriser la logique convoy dupliquée dans veafSpawn (`stop/move/markRoute`) | `veafSpawn.lua` | chore | 45 min | [x] |
| LUAQ-005 | Factoriser `moveTanker`/`changeTanker` (logique route commune ~40% dupliquée) | `veafMove.lua` | chore | 30 min | [x] |

**Raw total: 185 min → estimated (×1.15): ~215 min (~3h35)**

<details>
<summary>Ticket details</summary>

**LUAQ-001 — isExist() guards dans VeafQRA.check()**
Dans `VeafQRA.check()`, le watchdog tourne toutes les 5 secondes (`veafQraManager.WATCHDOG_DELAY = 5`). Les objets DCS retournés par `group:getUnits()` peuvent devenir des références stales si l'unité est détruite entre deux ticks. Même avec `if unit then`, un objet DCS mort peut lever une exception sur `:getLife()` ou `:inAir()`.
Correction : ajouter `if unit:isExist() then` avant chaque appel de méthode DCS sur une unité. Pattern à appliquer aussi dans `VeafQRA.rearm()` et `VeafQRA.resupply()`.

**LUAQ-002 — Varargs propres dans addWave()**
`addWave(...)` utilise la table implicite `arg` (Lua 5.1 legacy). Ce pattern génère du bruit `---@diagnostic disable-next-line: undefined-field` et est fragile dans certains contextes DCS.
Correction : remplacer par `local args = {...}` + `local nArgs = select('#', ...)`, supprimer la directive `@diagnostic disable`.

**LUAQ-003 — Wrapper veaf.mist**
Accès directs à `mist.DBs.unitsByName`, `mist.DBs.groupsByName`, `mist.DBs.humansByName` éparpillés dans veafSpawn, veafRadio, veafGrass, veafQraManager, veafInterpreter. Si mist change ses internals, tous ces modules cassent.
Proposition :
```lua
-- Dans veaf.lua
veaf.mist = {}
function veaf.mist.getUnitData(unitName) return mist.DBs.unitsByName[unitName] end
function veaf.mist.getGroupData(groupName) return mist.DBs.groupsByName[groupName] end
function veaf.mist.isHumanUnit(unitName) return mist.DBs.humansByName[unitName] ~= nil end
```
Remplacer tous les accès directs par ces wrappers.

**LUAQ-004 — Convoy helpers dans veafSpawn**
`_findClosestConvoy`, `_commandConvoy`, `stopClosestConvoy`, `moveClosestConvoy`, `_markClosestConvoyWithSmoke`, `markClosestConvoyWithSmoke`, `markClosestConvoyRouteWithSmoke` contiennent des blocs de validation quasi-identiques (~30 lignes chacun). Extraire `veafSpawn._getConvoyOrWarn(unitName)` qui centralise la recherche et le message d'erreur.

**LUAQ-005 — Tanker route helpers dans veafMove**
`moveTanker()` et `changeTanker()` partagent ~40% de logique identique (récupération du groupe tanker, validation des waypoints, construction de la route DCS). Extraire `veafMove._buildTankerRoute(group, waypoints)` utilisé par les deux.

</details>


---

## Lots archivés le 2026-05-29

→ [Backlog actif](backlog.md)
