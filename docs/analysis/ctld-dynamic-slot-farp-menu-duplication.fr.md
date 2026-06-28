# Menu radio CTLD dupliqué sur un hélicoptère en slot dynamique apparu sur une FARP runtime

**Destinataire :** le développeur qui réécrit CTLD (Fulgas). Ce document décrit un défaut
reproductible de CTLD `1.5.2` (la copie vendorée par VEAF) afin que la réécriture puisse
vérifier qu'il a bien disparu.

**En bref :** prendre un **slot dynamique** sur une **FARP spawnée au runtime** amène
`ctld.getUnitsInRepackRadius` à appeler `:getGroup()` sur une unité **nil** et à **planter**.
L'erreur survient *à l'intérieur* de `ctld.addTransportF10MenuOptions`, **après** que le
menu F10 a été ajouté mais **avant** que le drapeau anti-doublon `ctld.addedTo[groupId] = true`
soit posé. L'event de naissance suivant ré-entre donc dans `addTransportF10MenuOptions` et
**reconstruit tout le menu CTLD une seconde fois** → menu dupliqué, et les entrées ne font
rien parce que la construction a avorté en cours de route.

---

## 1. Symptôme (signalé par Tripack)

- Mission avec CTLD, hélicoptères disponibles en **slots dynamiques**.
- Une **FARP est spawnée au runtime** (spawn VEAF), à côté d'un slot normal (placé dans
  l'éditeur).
- Prise du slot **normal** → menu CTLD OK (unique, fonctionnel).
- Prise d'un **slot dynamique sur la FARP** → le **menu radio CTLD est dupliqué** : chaque
  entrée apparaît deux fois ; seule une copie est « active » et cliquer sur une option ne
  fait rien.

Capture (chemin du menu radio `Principal > Autre > CTLD`) :

```
F1. Vérif chargement
F2. Transport troupes...
F3. Caisses Vehicule / FOB / Drone...
F4. Commandes CTLD...
F5. Vérif chargement            <- doublon
F6. Transport troupes...        <- doublon
F7. Caisses Vehicule / FOB / Drone...
F8. Commandes CTLD...
```

Important : un slot dynamique sur un **aérodrome de base** ne reproduit **pas** le bug —
seul un slot dynamique sur une **FARP spawnée au runtime** le déclenche (voir §4).

---

## 2. Environnement

- CTLD `1.5.2` (fork vendoré VEAF ; `ctld.dontInitialize = true`, VEAF le ré-initialise).
- MIST `4.5.128-DYNSLOTS-02-VEAF` (la variante MIST gérant les slots dynamiques).
- Slots dynamiques DCS ; FARP créée au runtime (absente du `.miz`).

---

## 3. Cause racine

### 3.1 Le crash

`ctld.getUnitsInRepackRadius` déréférence le résultat de `Unit.getByName` sans vérifier le
nil :

```lua
function ctld.getUnitsInRepackRadius(_PlayerTransportUnitName, _radius)
    ...
    local unitsNamesList = ctld.getNearbyUnits(unit:getPoint(), _radius, unit:getCoalition())
    local repackableUnits = {}
    for i = 1, #unitsNamesList do
        local unitObject     = Unit.getByName(unitsNamesList[i])   -- peut être nil
        local repackableUnit = ctld.isRepackableUnit(unitsNamesList[i])
        if repackableUnit then
            repackableUnit["repackableUnitGroupID"] = unitObject:getGroup():getID()  -- CRASH : unitObject est nil
            table.insert(repackableUnits, mist.utils.deepCopy(repackableUnit))
        end
    end
    return repackableUnits
end
```

Pour un slot dynamique sur une FARP runtime, `getNearbyUnits` renvoie un **nom** d'unité
pour lequel `Unit.getByName(name)` vaut **nil** (une entrée transitoire/périmée de
`mist.DBs.unitsByName` sans unité DCS live). `isRepackableUnit(name)` renvoie quand même une
table truthy (il matche par nom de type / DB), donc la branche gardée s'exécute et
`unitObject:getGroup()` lève :

```
[string "CTLD.lua"]:<getUnitsInRepackRadius>: attempt to call method 'getGroup' (a nil value)
```

`ctld.isRepackableUnit` a le même déréférencement nil latent :

```lua
function ctld.isRepackableUnit(_unitName)
    local unitObject = Unit.getByName(_unitName)
    local unitType   = unitObject:getTypeName()   -- même risque de nil-deref
    ...
```

### 3.2 Pourquoi le crash *duplique le menu*

La chaîne d'appels est :

```
processHumanPlayer()                      -- sur S_EVENT_BIRTH / S_EVENT_PLAYER_ENTER_UNIT
  └─ ctld.addTransportF10MenuOptions(unitName)
       ├─ missionCommands.addSubMenuForGroup(...)   -- construit le menu CTLD (Vérif chargement, Troupes, Caisses, …)
       ├─ ctld.updateRepackMenu(unitName)           -- ligne ~6895 ("add repack menu")
       │    └─ ctld.getUnitsInRepackRadius(...)      -- *** PLANTE ICI ***
       └─ ctld.addedTo[tostring(groupId)] = true     -- drapeau anti-doublon — JAMAIS ATTEINT
```

`addTransportF10MenuOptions` ne pose son drapeau anti-doublon (`ctld.addedTo[groupId] = true`)
qu'à la toute **fin** de la fonction. Comme `updateRepackMenu` → `getUnitsInRepackRadius`
lève *avant* cette ligne, le drapeau n'est jamais posé alors que le menu a déjà été ajouté.

DCS émet **deux** events quand un joueur prend un slot (`S_EVENT_PLAYER_ENTER_UNIT` **et**
`S_EVENT_BIRTH`). Pour les slots dynamiques, les deux sont différés d'~2 s (l'unité n'est pas
encore dans `mist.DBs.humansByName`), donc `addTransportF10MenuOptions` tourne **deux fois** ;
le drapeau n'étant jamais posé, la seconde exécution **réajoute tout le menu** → le doublon.

`addedTo` est indexé par group id, et les deux exécutions voient le même id, donc le
dédoublonnage *aurait* fonctionné — la seule raison pour laquelle il échoue est le crash en
milieu de fonction qui saute la pose du drapeau.

### 3.3 Pourquoi spécifiquement slot-dynamique-sur-FARP

Un slot dynamique sur un **aérodrome de base** donne une unité stable dont les voisines se
résolvent toutes en unités live → `getUnitsInRepackRadius` ne tombe pas sur une unité nil →
pas de crash → drapeau posé → menu unique. Un slot dynamique sur une **FARP spawnée au
runtime** laisse un nom transitoire dans `mist.DBs.unitsByName` (statics de la FARP /
artefacts du slot dynamique) qui se résout en `nil`, déclenchant le crash. Cela correspond au
résultat empirique (aérodrome = OK, FARP = dupliqué).

---

## 4. Preuve par le runtime

Build de diagnostic : un wrapper autour de `ctld.addTransportF10MenuOptions` journalisant, en
niveau INFO, le nom d'unité, le group id MIST (utilisé pour le dédoublonnage), le group id DCS
live, et l'état `addedTo`, à l'entrée et à la sortie.

**Slot dynamique sur un aérodrome de base (Sukhumi) — pas de doublon :**

```
[DIAG-CTLD] addTransport ENTER unit=Sukhumi-Babushara_UH-1H_0-1 mistGroupId=1000000 liveGroupId=1000000 addedTo[mist]=nil
[DIAG-CTLD] addTransport EXIT  unit=Sukhumi-Babushara_UH-1H_0-1 mistGroupId=1000000 addedTo[mist]=true
```

Une construction ; group id stable ; drapeau posé. ✔

**Slot dynamique sur une FARP spawnée au runtime — doublon :**

```
[DIAG-CTLD] addTransport ENTER unit=FARP KM9172-27.927_UH-1H_13-1 mistGroupId=1000013 liveGroupId=1000013 addedTo[mist]=nil
ERROR SCRIPTING: Mission script error: [string "CTLD.lua"]:2842: attempt to call method 'getGroup' (a nil value)
stack traceback:
	[C]: in function 'getGroup'
	CTLD.lua:2842: in function 'getUnitsInRepackRadius'
	CTLD.lua:6978: in function 'updateRepackMenu'
	CTLD.lua:6884: in function 'addTransportF10MenuOptions'
	CTLD.lua:9403: in function 'processHumanPlayer'
	CTLD.lua:9426: in function <CTLD.lua:9424>
[DIAG-CTLD] addTransport ENTER unit=FARP KM9172-27.927_UH-1H_13-1 mistGroupId=1000013 liveGroupId=1000013 addedTo[mist]=nil
ERROR SCRIPTING: Mission script error: [string "CTLD.lua"]:2842: attempt to call method 'getGroup' (a nil value)
	(même traceback)
```

À noter : **deux `ENTER`, aucun `EXIT`** pour les deux (la fonction ne revient jamais
normalement), et `addedTo[mist]` est **toujours `nil`** au second enter (même group id
`1000013`) — ce qui prouve que le drapeau anti-doublon n'a jamais été posé à cause du crash,
et donc que le menu est bien construit deux fois. (Les numéros de ligne proviennent de la
copie injectée ; ils correspondent aux fonctions nommées ci-dessus.)

---

## 5. Correctif appliqué dans la copie vendorée VEAF

Gardes nil défensifs pour qu'un nom transitoire/périmé (pas d'unité live, ou une unité sans
groupe) soit ignoré au lieu de planter :

```lua
-- ctld.getUnitsInRepackRadius
for i = 1, #unitsNamesList do
    local unitObject     = Unit.getByName(unitsNamesList[i])
    local repackableUnit = ctld.isRepackableUnit(unitsNamesList[i])
    if repackableUnit and unitObject then
        local _group = unitObject:getGroup()
        if _group then
            repackableUnit["repackableUnitGroupID"] = _group:getID()
            table.insert(repackableUnits, mist.utils.deepCopy(repackableUnit))
        end
    end
end
```

```lua
-- ctld.isRepackableUnit
function ctld.isRepackableUnit(_unitName)
    local unitObject = Unit.getByName(_unitName)
    if not unitObject then
        return nil  -- nom transitoire/périmé sans unité live (slots dynamiques / FARP spawnées)
    end
    local unitType = unitObject:getTypeName()
    ...
```

Le crash supprimé, `addTransportF10MenuOptions` va jusqu'au bout, pose
`ctld.addedTo[groupId] = true`, et le second event de naissance est correctement dédoublonné.

---

## 6. À vérifier / durcir dans la réécriture de CTLD

1. **Ne jamais déréférencer `Unit.getByName(...)` sans garde nil.** `getNearbyUnits` /
   `getUnitsInRepackRadius` / `isRepackableUnit` supposent tous une unité live ; avec les
   slots dynamiques et les FARP spawnées au runtime, `mist.DBs.unitsByName` (ou toute source
   d'unités proches) peut renvoyer un nom sans unité live. Idem pour
   `:getGroup()`/`:getGroup():getID()`.
2. **Poser le garde anti-doublon *avant* de construire, ou rendre la construction
   idempotente.** Le pattern actuel pose `addedTo[groupId] = true` seulement à la *fin* d'une
   longue fonction ; *toute* erreur avant cette ligne laisse silencieusement le menu ajouté
   mais non marqué, donc l'event de naissance suivant le duplique. Préférer : marquer le
   groupe comme « menu en cours / déjà construit » dès le départ, et/ou retirer un menu CTLD
   existant pour le groupe avant de reconstruire.
3. **Les slots dynamiques émettent deux events** (`S_EVENT_PLAYER_ENTER_UNIT` +
   `S_EVENT_BIRTH`) et l'unité n'est pas encore dans la base humaine de MIST, donc la mise en
   place du menu est différée et tourne deux fois. Le dédoublonnage doit être robuste à cela
   (idempotent, ou indexé sur une identité stable).
4. **Source du group id.** Cette copie dédoublonne via `ctld.getGroupId` =
   `mist.DBs.unitsById[id].groupId` (la base MIST), pas via le `unit:getGroup():getID()` live.
   Pour le cas observé ils coïncidaient (`1000013`), mais une réécriture devrait préférer
   l'API live pour les slots dynamiques, ou garantir la cohérence des deux.
5. **Scénario de non-régression à tester :** spawner une FARP au runtime, prendre un
   hélicoptère en slot dynamique dessus, et confirmer que le menu F10 CTLD est construit
   exactement une fois et que toutes les options fonctionnent — et qu'aucune erreur
   `attempt to call method 'getGroup'/'getTypeName' (a nil value)` n'apparaît dans `dcs.log`.
