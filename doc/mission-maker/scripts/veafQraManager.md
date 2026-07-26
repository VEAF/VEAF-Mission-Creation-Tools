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

### Via `mission.yaml` (recommandé)

`veafQraManager.initialize()` est appelé automatiquement par le framework.

### Via `mission-script.lua`

Appeler `veafQraManager.initialize()` **avant** de déclarer les zones :

```lua
veafQraManager.initialize()
```

> **Important :** sans cet appel, les événements `S_EVENT_BIRTH` et `S_EVENT_PLAYER_ENTER_UNIT` ne sont pas écoutés. Les pilotes qui rejoignent via un slot dynamique seront invisibles des QRA et ne déclencheront aucune interception.

Chaque zone QRA est ensuite créée et activée individuellement avec `:start()` :

```lua
local myQra = VeafQRA:new()
  :setName("QRA-North")
  :setTriggerZone("ZONE-QRA-NORTH")
  :setCoalition(coalition.side.RED)
  :addGroup("MiG-29 QRA")
  :start()
```

---

## Configuration (`mission.yaml`)

Les définitions QRA vivent **sous `modules.QRA`** (`silence_all` + `definitions:`). Le module `QRA` doit être activé dans `modules:`.

```yaml
modules:
  QRA:
    silence_all: false      # true = supprimer tous les messages radio QRA globalement
    definitions:
      - name: "QRA-Nord"                  # REQUIS — identifiant et préfixe radio
        coalition: RED                    # REQUIS — RED | BLUE
        enemy_coalitions: [BLUE]          # coalitions qui déclenchent le scramble
        trigger_zone: "ZONE-QRA-NORD"    # zone de trigger DCS définissant l'espace aérien
        zone_radius: 30000               # rayon en mètres (alternative à trigger_zone)
        simple_groups:                   # noms de groupes DCS à scrambler (inconditionnels)
          - "Vol QRA MiG-29"
        groups_by_enemy_count:           # réponse proportionnelle au nombre d'intrus
          - enemy_count: 1               # scramble quand 1 intrus détecté
            groups: ["Duo-1", "Duo-2"]   # pool de groupes
            random_pick: 1               # combien de groupes choisir dans le pool
          - enemy_count: 3
            groups: ["Vol-1", "Vol-2"]
            random_pick: 2
        delay_before_rearming: 30        # secondes avant réinitialisation après départ des intrus
        delay_before_activating: 30      # secondes après :start() avant mise en ligne de la QRA
        react_on_helicopters: false      # true = déclencher aussi sur les hélicoptères ennemis
        airport_link: "Batumi"           # la QRA se désactive si cette base est détruite
```

### Champs de `modules.QRA`

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `silence_all` | booléen | `false` | Non | Supprimer tous les messages radio QRA globalement |
| `definitions` | objet[] | `[]` | Non | Liste des définitions de zones QRA |

### Champs de `definitions[]`

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `name` | string | — | Oui | Identifiant interne et préfixe radio |
| `coalition` | string | — | Oui | Coalition défensive : `RED` ou `BLUE` |
| `enemy_coalitions` | string[] | *(opposée)* | Non | Coalitions qui déclenchent un scramble |
| `trigger_zone` | string | — | Non | Nom de la zone de trigger DCS |
| `zone_radius` | entier | — | Non | Rayon de zone en mètres (sans zone de trigger) |
| `simple_groups` | string[] | `[]` | Non | Noms de groupes DCS à toujours scrambler |
| `groups_by_enemy_count` | objet[] | `[]` | Non | Règles de scramble proportionnel |
| `groups_by_enemy_count[].enemy_count` | entier | — | Oui | Nombre d'intrus activant cette règle |
| `groups_by_enemy_count[].groups` | string[] | — | Oui | Pool de noms de groupes |
| `groups_by_enemy_count[].random_pick` | entier | `1` | Non | Combien de groupes choisir dans le pool |
| `delay_before_rearming` | entier | `0` | Non | Secondes avant réinitialisation après départ des intrus |
| `delay_before_activating` | entier | `0` | Non | Secondes après le démarrage avant mise en ligne |
| `react_on_helicopters` | booléen | `false` | Non | Déclencher aussi sur les hélicoptères ennemis |
| `airport_link` | string | — | Non | Nom de base aérienne DCS liée — QRA hors ligne si détruite |
| `active_at_start` | booléen | `true` | Non | `false` : la QRA est déclarée mais **pas armée** au démarrage — elle attend un `qra.start` (menu radio) ou un appel script |
| `radio_menu` | booléen | `false` | Non | Générer automatiquement un sous-menu radio F10 de contrôle de cette QRA (voir ci-dessous) |
| `radio_menu_restrict_to_group` | string | — | Non | Nom d'un groupe DCS ; le sous-menu généré n'apparaît que pour ce groupe |

### Menu radio de contrôle (raccourci)

Les commandes de démarrage/arrêt d'une QRA **n'existent pas** dans le menu radio VEAF standard (contrairement à CombatZone ou Carrier). Pour donner au Mission Master un contrôle F10 sur une QRA, ajoutez `radio_menu: true` à sa définition : le framework génère automatiquement un sous-menu nommé d'après la QRA, avec les commandes « Démarrer &lt;nom&gt; » et « Arrêter &lt;nom&gt; ».

```yaml
modules:
  QRA:
    definitions:
      - name: "QRA-Nord"
        coalition: RED
        trigger_zone: "ZONE-QRA-NORD"
        simple_groups:
          - "MiG-29 QRA Nord"
        radio_menu: true                         # génère le sous-menu de contrôle
        radio_menu_restrict_to_group: "MM Ctrl"  # optionnel : réserver le sous-menu à ce groupe DCS
```

C'est le **mécanisme 1** (raccourci par module). Pour un menu MM personnalisé, structuré ou combinant plusieurs actions (QRA, AirWaves, flags, messages, Lua), utilisez le **mécanisme 2** décrit dans [veafRadio → Menus radio en YAML](veafRadio.md#menus-radio-en-yaml).

### Exemple minimal

```yaml
modules:
  QRA:
    definitions:
      - name: "QRA-Sud"
        coalition: RED
        trigger_zone: "ZONE-QRA-SUD"
        simple_groups:
          - "Interception Su-27"
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

## Fonctionnement

Une zone QRA surveille un volume d'espace aérien défini par une trigger zone DCS. Dès qu'un aéronef hostile y pénètre, la QRA décolle — à condition d'être prête. Quand la QRA est abattue, la zone entre en état de réarmement ; elle redevient active une fois les ennemis partis et le minuteur de réarmement expiré.

### Machine à états

```
STOP ──start()──► READY ──(intrus entre)──► ACTIVE ──(QRA détruite)──► DEAD
  ▲                 ▲                                                      │
  │                 └──────────(tous les intrus partis + délai réarm.)─────┘
  │                                                     │
  └──────────────────────────stop()────────────────────►┘
```

États complets :

| État | Signification |
|------|---------------|
| `STOP` | Inactive — `stop()` a été appelé ou la QRA n'a jamais démarré |
| `READY` | Armée et en surveillance d'intrus |
| `READY_WAITINGFORMORE` | QRA décollée ; des intrus supplémentaires ont déclenché le déploiement de groupes additionnels |
| `ACTIVE` | La QRA est en vol et en interception |
| `DEAD` | La QRA a été détruite ; en attente des conditions de réarmement |
| `WILLREARM` | Le minuteur de réarmement est en cours |
| `OUT` | Plus d'aéronefs disponibles (stock épuisé) |
| `NOAIRBASE` | La base aérienne liée a été détruite — la QRA se met en retrait |

### Mise en place dans l'éditeur de mission DCS

1. **Créez une trigger zone** — dessinez l'espace aérien à protéger. Donnez-lui un nom mémorable, par exemple `ZONE-QRA-NORTH`.
2. **Placez le groupe QRA** — créez le groupe d'aéronefs qui décollera. Mettez-le en **Activation différée** (*Late Activation*) pour qu'il n'apparaisse pas au démarrage (VEAF gère l'activation). Donnez au groupe un nom distinctif, par exemple `MiG-29 QRA North`.
3. **Reliez le tout** — l'approche recommandée est `mission.yaml` (aucun Lua requis) ; l'équivalent `mission-script.lua` est donné ensuite.

**Via `mission.yaml`** (recommandé) — ajoutez la définition sous `modules.QRA` :

```yaml
modules:
  QRA:
    definitions:
      - name: "QRA-North"
        coalition: RED
        trigger_zone: "ZONE-QRA-NORTH"
        simple_groups:
          - "MiG-29 QRA North"
```

> Il n'y a pas d'équivalent YAML de `:start()` : toute définition listée sous `definitions:` est démarrée automatiquement au chargement de la mission. Pour retarder sa mise en ligne, utilisez `delay_before_activating` ; pour ne pas la démarrer, retirez-la (ou commentez-la) de `definitions:`.

**Via `mission-script.lua`** — appelez le builder après `veafQraManager.initialize()`, puis `:start()` explicitement :

```lua
VeafQRA:new()
  :setName("QRA-North")
  :setTriggerZone("ZONE-QRA-NORTH")
  :setCoalition(coalition.side.RED)
  :addGroup("MiG-29 QRA North")
  :start()
```

C'est tout — aucune condition de trigger, aucune fonction planifiée. VEAF gère la détection, le décollage et le réarmement automatiquement.

### Chaîne logistique

Par défaut, une QRA dispose d'aéronefs en nombre illimité. Le système de logistique permet de modéliser un stock d'aérodrome fini avec ravitaillement optionnel — utile pour les missions persistantes de longue durée :

| Paramètre | Rôle |
|-----------|------|
| `setQRAcount(n)` | Nombre total de groupes disponibles (sert de stock courant) |
| `setQRAmaxCount(n)` | Plafond strict de groupes actifs simultanément |
| `setQRAresupplyDelay(s)` | Secondes à attendre avant le démarrage d'un ravitaillement |
| `setQRAminCountforResupply(n)` | Niveau de stock qui déclenche un ravitaillement |
| `setQRAmaxResupplyCount(n)` | Nombre maximum de cycles de ravitaillement (`-1` = illimité) |
| `setResupplyAmount(n)` | Groupes ajoutés par cycle de ravitaillement (défaut `1`) |

Voyez cela comme un entrepôt : `QRAcount` est ce qui est en rayon, `resupplyDelay` le délai de livraison du camion, et `minCountforResupply` le point de recommande.

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
