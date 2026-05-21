# veafQraManager — Alerte de réaction rapide (QRA)

**Module ID:** `QRA` | **Version:** 1.2.x | **Fichier:** `veafQraManager.lua`

---

## Objectif

Définit des zones d'espace aérien protégées défendues par des intercepteurs IA. Quand un aéronef hostile entre dans la zone, un vol QRA est scramblé. Une fois la QRA détruite, la zone n'est plus défendue jusqu'à la prochaine réinitialisation (quand tous les intrus ont quitté). Supporte plusieurs groupes, le réarmement, la dépendance à une base aérienne, les messages radio de statut, et une chaîne logistique (stock limité d'aéronefs avec ravitaillement optionnel).

---

## Dépendances

- `veafRadio` — messages de statut (optionnel)
- `veafSpawn` — spawn du groupe IA

---

## Activation

Pas d'appel global `initialize()`. Chaque zone QRA est créée et activée individuellement avec `:start()` :

```lua
local myQra = VeafQRA:new()
  :setName("QRA-North")
  :setTriggerZone("ZONE-QRA-NORTH")
  :setCoalition(coalition.side.RED)
  :addGroup("MiG-29 QRA")
  :start()
```

---

## Méthodes du builder VeafQRA

Tous les setters retournent `self` et peuvent être chaînés. Appeler `:start()` en fin de chaîne pour activer.

### Identification

| Méthode | Description |
|---------|-------------|
| `:setName(name)` | Identifiant interne — utilisé comme préfixe des messages si aucune description n'est définie |
| `:setDescription(text)` | Libellé lisible utilisé dans les messages radio (défaut : le nom) |

### Définition de la zone

Utiliser l'une des options suivantes :

| Méthode | Description |
|---------|-------------|
| `:setTriggerZone(zoneName)` | Nom de la zone trigger DCS (recommandé) |
| `:setZoneCenter(vec3)` | Centre manuel (vec3 DCS) — à combiner avec `:setZoneRadius()` |
| `:setZoneCenterFromCoordinates(coordStr)` | Centre depuis une chaîne `"lat,lon"` |
| `:setZoneRadius(meters)` | Rayon en mètres (quand on n'utilise pas de zone trigger) |

### Défenseurs

| Méthode | Description |
|---------|-------------|
| `:addGroup(name)` | Ajouter un groupe DCS à scrambler (appeler plusieurs fois pour plusieurs groupes) |
| `:addRandomGroup(groups, number, bias)` | Piocher aléatoirement `number` groupes dans une liste |
| `:setGroupsToDeployByEnemyQuantity(n, groups)` | Adapter la réponse : déployer `groups` quand `n` ennemis sont dans la zone |
| `:setRandomGroupsToDeployByEnemyQuantity(n, groups, number, bias)` | Adaptation aléatoire au nombre d'ennemis |

### Coalition

| Méthode | Description |
|---------|-------------|
| `:setCoalition(side)` | Coalition qui possède cette QRA (ex. `coalition.side.RED`) |
| `:addEnnemyCoalition(side)` | Ajouter une coalition ennemie (défaut : opposée à la coalition défendante) |

### Comportement

| Méthode | Description |
|---------|-------------|
| `:setSilent(bool)` | Supprimer tous les messages radio de cette QRA |
| `:setDrawZone(bool)` | Afficher la zone protégée sur la carte |
| `:setReactOnHelicopters()` | Déclencher aussi sur les hélicoptères ennemis (avions seulement par défaut) |
| `:setDelayBeforeRearming(seconds)` | Délai avant réinitialisation après départ de tous les intrus (`-1` = pas de délai) |
| `:setNoNeedToLeaveZoneBeforeRearming()` | Autoriser le réarmement même si des ennemis sont encore dans la zone |
| `:setResetWhenLeavingZone()` | Réinitialiser immédiatement quand tous les ennemis quittent la zone |
| `:setDelayBeforeActivating(seconds)` | Délai avant mise en ligne après `:start()` |
| `:setMinimumAltitudeInFeet(feet)` | Altitude minimale de l'ennemi pour déclencher un scramble |
| `:setMaximumAltitudeInFeet(feet)` | Altitude maximale de l'ennemi pour déclencher un scramble |
| `:setRespawnDefaultOffset(latDelta, lonDelta)` | Décalage de spawn depuis le centre de la zone (mètres, lat/lon) |
| `:setRespawnRadius(meters)` | Rayon de dispersion autour du point de spawn (minimum 250 m) |

### Lien à une base aérienne

| Méthode | Description |
|---------|-------------|
| `:setAirportLink(name)` | Lier à une base — la QRA passe hors ligne si la base est détruite |
| `:setAirportMinLifePercent(pct)` | Santé minimale de la base pour que la QRA reste active (0–1, défaut `0,9`) |

### Messages et callbacks

Les chaînes de message acceptent `%s` comme token pour le nom/la description de la QRA. Les callbacks reçoivent l'instance QRA en premier argument.

| Méthode | Déclencheur |
|---------|------------|
| `:setMessageStart(text)` / `:setOnStart(fn)` | La QRA se met en ligne |
| `:setMessageDeploy(text)` / `:setOnDeploy(fn)` | La QRA est scramblée |
| `:setMessageDestroyed(text)` / `:setOnDestroyed(fn)` | La QRA est abattue |
| `:setMessageReady(text)` / `:setOnReady(fn)` | La QRA est prête après réarmement |
| `:setMessageOut(text)` / `:setOnOut(fn)` | Plus d'aéronefs disponibles |
| `:setMessageResupplied(text)` / `:setOnResupplied(fn)` | Ravitaillement logistique terminé |
| `:setMessageAirbaseDown(text)` / `:setOnAirbaseDown(fn)` | Base aérienne liée détruite |
| `:setMessageAirbaseUp(text)` / `:setOnAirbaseUp(fn)` | Base aérienne liée restaurée |
| `:setMessageStop(text)` / `:setOnStop(fn)` | La QRA passe hors ligne |

### Logistique / Stock d'aéronefs

Par défaut, la QRA dispose d'un nombre illimité d'aéronefs. Utiliser ces méthodes pour simuler un stock fini avec ravitaillement optionnel :

| Méthode | Description |
|---------|-------------|
| `:setQRAcount(n)` | Nombre total de groupes disponibles (`-1` = illimité) |
| `:setQRAmaxCount(n)` | Nombre maximum de groupes actifs simultanément (`-1` = illimité) |
| `:setQRAresupplyDelay(seconds)` | Secondes avant le déclenchement d'un cycle de ravitaillement |
| `:setQRAmaxResupplyCount(n)` | Nombre maximum de cycles de ravitaillement (`-1` = illimité) |
| `:setQRAminCountforResupply(n)` | Stock restant qui déclenche un ravitaillement |
| `:setResupplyAmount(n)` | Groupes ajoutés par cycle de ravitaillement (défaut `1`) |

### Cycle de vie

| Méthode | Description |
|---------|-------------|
| `:start()` | Activer la QRA — diffuse `messageStart` et démarre le watchdog |
| `:stop(silent)` | Désactiver la QRA — diffuse `messageStop` sauf si `silent` vaut `true` |

---

## Machine à états QRA

```
PRÊTE ──(intrus entre)──> ACTIVE ──(QRA détruite)──> MORTE
  ^                                                       |
  └──────(tous les intrus partis + délai de réarmement)──┘
```

États supplémentaires : `WILLREARM`, `OUT` (plus de groupes), `NOAIRBASE` (base aérienne détruite), `STOP` (désactivée manuellement).

---

## Configuration globale

| Constante | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `veafQraManager.WATCHDOG_DELAY` | `5` | Intervalle de vérification en secondes |
| `veafQraManager.MINIMUM_LIFE_FOR_QRA_IN_PERCENT` | `10` | Vie minimale des unités QRA avant destruction |
| `veafQraManager.DEFAULT_airbaseMinLifePercent` | `0,9` | Seuil de santé par défaut de la base |
| `veafQraManager.AllSilence` | `false` | Supprimer globalement tous les messages QRA |

---

## Exemple : plusieurs zones QRA

```lua
-- Zone nord défendue par des MiG-29, liée à la base de Beslan
VeafQRA:new()
  :setName("QRA-NORTH")
  :setTriggerZone("ZONE-NORTH-DEFENSE")
  :setCoalition(coalition.side.RED)
  :addGroup("MiG-29S QRA North-1")
  :addGroup("MiG-29S QRA North-2")
  :setAirportLink("Beslan")
  :setDelayBeforeRearming(600)
  :start()

-- Zone sud, toujours active, silencieuse
VeafQRA:new()
  :setName("QRA-SOUTH")
  :setTriggerZone("ZONE-SOUTH-DEFENSE")
  :setCoalition(coalition.side.RED)
  :addGroup("Su-27 QRA South")
  :setSilent(true)
  :start()
```

### Exemple : stock limité avec ravitaillement

```lua
-- 4 groupes au total, max 2 actifs simultanément, +1 groupe toutes les 30 min
VeafQRA:new()
  :setName("QRA-LIMITED")
  :setTriggerZone("ZONE-LIMITED")
  :setCoalition(coalition.side.RED)
  :addGroup("F-15C QRA 1")
  :addGroup("F-15C QRA 2")
  :setQRAcount(4)
  :setQRAmaxCount(2)
  :setQRAresupplyDelay(1800)
  :setResupplyAmount(1)
  :start()
```

---

## Voir aussi

- [veafAirWaves](veafAirWaves.md) — système d'attaque IA par vagues (vs QRA qui est défensif)
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafQraManager`
