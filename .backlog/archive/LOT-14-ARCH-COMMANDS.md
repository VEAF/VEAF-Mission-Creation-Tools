# Lot 14 — ARCH-COMMANDS: Refactoring de l'infrastructure commandes/marqueurs

Status: ✅ done

**Goal**: Éliminer la duplication du pattern `onEventMarkChange + executeCommand + markTextAnalysis` répété dans 8+ modules, et remplacer les dispatchers if/elseif manuels par des registres dynamiques.
Chaque ticket est indépendant — ordre recommandé : ARCH-001 → ARCH-002 → ARCH-003, puis ARCH-004 → ARCH-005 en parallèle.
**Branch**: une branche par ticket `refactor/arch-xxx` → PR → `develop`
⚠️ ARCH-001 : l'ordre d'enregistrement dans le registre doit reproduire exactement l'ordre actuel du if/elseif (veafShortcuts en premier).

| # | Ticket | File(s) | Type | Effort | Status |
|---|--------|---------|------|--------|--------|
| ARCH-001 | Registre de modules dans `veafInterpreter.execute` — remplacer le if/elseif de 8 modules par un tableau ordonné ; chaque module s'auto-enregistre dans `initialize()` | `veafInterpreter.lua` + 8 modules | chore | 60 min | ✅ |
| ARCH-002 | Registre de modules dans `veafRemote.executeCommandFromRemote` — `veafRemote.registerRemoteModule(name, fn)` ; remplace le switch string sur 7 modules | `veafRemote.lua` + 7 modules | chore | 60 min | ✅ |
| ARCH-003 | Factoriser le boilerplate `onEventMarkChange` — helper `veafMarkers.makeMarkHandler(fn)` qui génère la fonction standard (invertedCoalition + executeCommand + removeMark) ; remplace 8 fonctions quasi-identiques | `veafMarkers.lua` + 8 modules | chore | 90 min | ✅ |
| ARCH-004 | Extraire `veafSpawnParser.lua` — isoler `markTextAnalysis` + `convertLaserToFreq` hors de `veafSpawnCore.lua` ; le parseur devient testable indépendamment (portage LUAR-005 pt.1) | `veafSpawnCore.lua` → `veafSpawnParser.lua`, `veafSpawn.lua` | feat | 60 min | ✅ |
| ARCH-005 | Système de handlers dans `veafSpawnCore.executeCommand` — `veafSpawn.registerCommandHandler(key, fn)` ; les 4 sous-modules s'enregistrent ; Core < 300 lignes (portage LUAR-005 pt.2) | `veafSpawnCore.lua`, `veafSpawnGround.lua`, `veafSpawnAircraft.lua`, `veafSpawnEffects.lua` | feat | 120 min | ✅ |

**Raw total: 390 min → estimated (×1.15): ~449 min (~7h30)**

<details>
<summary>Ticket details</summary>

**ARCH-001 — Registre veafInterpreter**
Actuellement `veafInterpreter.execute()` contient 8 `if/elseif` hardcodés dans l'ordre : veafShortcuts → veafSpawn → veafNamedPoints → veafCasMission → veafSecurity → veafMove → veafRadio → veafRemote. Chaque ajout de module nécessite de modifier ce fichier.
Proposition :
```lua
veafInterpreter.moduleRegistry = {}  -- ordered list
function veafInterpreter.registerModule(fn)
  table.insert(veafInterpreter.moduleRegistry, fn)
end
-- dans execute() :
for _, fn in ipairs(veafInterpreter.moduleRegistry) do
  if fn(position, command, coalition, spawnedGroups, route) then return true end
end
```
Chaque module appelle `veafInterpreter.registerModule(...)` depuis son `initialize()`. L'ordre d'enregistrement reproduit l'ordre actuel.

**ARCH-002 — Registre veafRemote**
Actuellement `veafRemote.executeCommandFromRemote()` switche sur des chaînes `"air"`, `"point"`, `"atis"`, etc. Ajouter un module nécessite de modifier `veafRemote.lua`.
Proposition :
```lua
function veafRemote.registerRemoteModule(name, fn)
  veafRemote.remoteModuleRegistry[name:lower()] = fn
end
-- dans executeCommandFromRemote() :
local handler = veafRemote.remoteModuleRegistry[_module]
if handler then _status, _retval = pcall(handler, _parameters) end
```

**ARCH-003 — Helper onEventMarkChange**
Les 8 `onEventMarkChange` sont quasi-identiques :
```lua
function module.onEventMarkChange(eventPos, event)
  local invertedCoalition = event.coalition == 1 and 2 or 1
  if module.executeCommand(eventPos, event.text, invertedCoalition, event.idx) then
    trigger.action.removeMark(event.idx)
  end
end
```
Proposition dans `veafMarkers.lua` :
```lua
function veafMarkers.makeMarkHandler(executeFn)
  return function(eventPos, event)
    local inv = event.coalition == 1 and 2 or 1
    if executeFn(eventPos, event.text, inv, event.idx) then
      trigger.action.removeMark(event.idx)
    end
  end
end
```
Note : certains modules ont des variantes légères (pas d'invertedCoalition, signature différente) — à analyser module par module.

**ARCH-004 — veafSpawnParser.lua**
`veafSpawnCore.lua` contient `convertLaserToFreq` (17 lignes) et `markTextAnalysis` (612 lignes) qui n'ont aucune dépendance sur les fonctions de spawn. Les extraire dans `veafSpawnParser.lua` rend le parseur testable de manière isolée et réduit Core de ~630 lignes.
`veafSpawn.lua` (proxy) charge `veafSpawnParser.lua` avant `veafSpawnCore.lua`.

**ARCH-005 — Système de handlers dans executeCommand**
`veafSpawnCore.executeCommand` contient un if/elseif de ~400 lignes avec 20+ branches. Chaque branche appartient logiquement à un sous-module.
Proposition :
```lua
veafSpawn.commandHandlers = {}  -- { [optionKey] = fn }
function veafSpawn.registerCommandHandler(key, fn)
  veafSpawn.commandHandlers[key] = fn
end
-- dans executeCommand(), remplace le if/elseif :
for key, fn in pairs(veafSpawn.commandHandlers) do
  if options[key] then
    local g, done = fn(eventPos, options, coalition, markId, bypassSecurity)
    if g then spawnedGroup = g end
    if done then routeDone = done end
    break
  end
end
```
Chaque sous-module enregistre ses handlers à la fin de son fichier : Ground (farp/fob/group/infantry/armor/aiDefense/transport/combat/convoy), Aircraft (unit/afac/cap), Effects (cargo/logistic/destroy/teleport/bomb/smoke/flare/signal), Core (drawing/missionMaster).

</details>
