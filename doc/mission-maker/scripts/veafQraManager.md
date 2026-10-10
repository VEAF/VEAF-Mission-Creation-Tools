# veafQraManager — Alerte de réaction rapide (QRA)

**Module ID:** `QRA` | **Fichier:** `veafQraManager.lua`

> **Voir en jeu** : étape 10 « QRA de Soukhoumi » de la [mission de démo](https://github.com/VEAF/VEAF-Demo-Mission-v6#la-visite-guidée).

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

## Configuration (`mission.yaml`) {#configuration-missionyaml}

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
        # simple_groups: ["Vol QRA MiG-29"]  # OU une liste simple, toujours scramblée — jamais avec
        #                                    # groups_by_enemy_count, à côté duquel elle ne décolle pas
        groups_by_enemy_count:           # réponse proportionnelle au nombre d'intrus
          - enemy_count: 1               # scramble quand 1 intrus détecté
            groups: ["Duo-1", "Duo-2"]   # pool de groupes
            random_pick: 1               # tirer 1 groupe du pool (sans random_pick : tous décollent)
          - enemy_count: 3
            groups: ["Duo-1", "Vol-2"]   # pas de random_pick : les deux décollent
        delay_before_rearming: 30        # secondes avant réinitialisation après départ des intrus
        rearm_while_occupied: true       # réarmer sans attendre que la zone se vide
        scale_with_opposition: true      # palier choisi aussi d'après le niveau d'opposition
        delay_before_activating: 30      # secondes après :start() avant mise en ligne de la QRA
        react_on_helicopters: false      # true = déclencher aussi sur les hélicoptères ennemis
        airport_link: "Batumi"           # en pause tant que cette base est perdue (raccourci de links)
        # links: ["Batumi", "SA-10 Nord"]   # bases, FARP, navires, groupes ou statics dont dépend la QRA
        # follow_unit: "CVN-74"             # la zone suit cette unité (un porte-avions, par exemple)
        logistics:                       # stock d'avions fini (sans ce bloc : illimité)
          groups_available: 4            # groupes en stock au départ
          resupply_delay: 1800           # un ravitaillement toutes les 30 min
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
| `simple_groups` | string[] | `[]` | Non | Noms de groupes DCS à toujours scrambler, ou commandes VEAF (`[0,0]-spawn shilka, country russia`, `-sa6`) : une entrée qui commence par `[` ou `-` est une commande, `validate` ne la cherche pas dans la mission. **Sans** `groups_by_enemy_count` : à côté, ces groupes ne décollent jamais (une règle de niveau 1 les remplace, un niveau le plus bas supérieur à 1 empêche le niveau 1 de se déclencher), et `validate` le signale |
| `groups_by_enemy_count` | objet[] | `[]` | Non | Règles de scramble proportionnel |
| `groups_by_enemy_count[].enemy_count` | entier | — | Oui | Nombre d'intrus activant cette règle |
| `groups_by_enemy_count[].groups` | string[] | — | Oui | Pool de noms de groupes ou de commandes VEAF, comme `simple_groups` |
| `groups_by_enemy_count[].random_pick` | entier | — | Non | Combien de groupes **tirer** dans le pool, sans remise : jamais deux fois le même groupe, jamais plus que la liste n'en contient. **Absent : tous les groupes du palier décollent.** Le palier retenu est le plus grand dont `enemy_count` ne dépasse pas le nombre d'intrus, dans quelque ordre que les paliers soient écrits |
| `delay_before_rearming` | entier | `0` | Non | Secondes avant réinitialisation après départ des intrus |
| `delay_before_activating` | entier | `0` | Non | Secondes après le démarrage avant mise en ligne |
| `rearm_while_occupied` | booléen | `false` | Non | Une QRA détruite se réarme **même si des intrus sont encore dans sa zone**. Sans cette clé, elle attend que la zone soit vide — avec plusieurs joueurs sur l'objectif, presque jamais |
| `scale_with_opposition` | booléen | `false` | Non | Choisir le palier d'après le [niveau d'opposition](#opposition-level) quand il dépasse le nombre d'intrus dans la zone — le seuil du plus petit palier aussi : une paire déclenche une QRA dont le premier palier est 3 si la mission est dimensionnée pour six. Le déclenchement reste sur la zone : personne dedans, pas de scramble |
| `react_on_helicopters` | booléen | `false` | Non | Déclencher aussi sur les hélicoptères ennemis |
| `airport_link` | string | — | Non | Nom d'une base aérienne DCS liée : la QRA se met en pause tant que la base est capturée ou trop endommagée, et repart quand elle est reprise. Raccourci d'une entrée de `links` |
| `links` | string[] | `[]` | Non | Ce dont dépend la QRA : bases aériennes, FARP, navires, groupes ou statics, par leur nom DCS. Une base ou un FARP perdu **met la QRA en pause** jusqu'à sa reprise ; un navire, un groupe ou un static détruit **l'arrête pour de bon**. Un seul lien perdu suffit |
| `follow_unit` | string | — | Non | Nom d'une unité que la zone suit (un porte-avions, par exemple) ; le centre est relu à chaque vérification. Une trigger zone liée à une unité dans l'éditeur la suit aussi, sans cette clé. Si l'unité meurt, la zone reste là où elle l'a vue en dernier |
| `logistics` | objet | — | Non | Stock d'avions fini et ravitaillement — voir [Chaîne logistique](#logistics-chain) |
| `respawn_default_offset` | [nombre, nombre] | `[0, 0]` | Non | Décalage en mètres `[nord, est]`, par rapport au centre de la zone, où apparaît un élément déployé par une commande VEAF sans position `[x,y]` à elle |
| `active_at_start` | booléen | `true` | Non | `false` : la QRA est déclarée mais **pas armée** au démarrage — elle attend un `qra.start` (menu radio) ou un appel script |
| `radio_menu` | booléen | `false` | Non | Générer automatiquement un sous-menu radio F10 de contrôle de cette QRA (voir ci-dessous) |
| `radio_menu_restrict_to_group` | string | — | Non | Nom d'un groupe DCS ; le sous-menu généré n'apparaît que pour ce groupe |
| `radio_menu_secured` | booléen | `false` | Non | Commandes **sécurisées** : seul un pilote de ce groupe ayant le niveau de sécurité requis peut les exécuter. Exige `radio_menu_restrict_to_group` (le niveau vérifié est celui du groupe pour lequel le menu est posé) ; le build refuse sinon |

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
        radio_menu_secured: true                 # optionnel : et exiger le niveau de sécurité (commandes « +… »)
```

!!! warning "Ce menu n'est pas sécurisé"
    Sans `radio_menu_restrict_to_group`, le sous-menu est posé pour **tous les joueurs**, des deux
    camps, et ses commandes s'exécutent sans demander de niveau de sécurité. Sur un serveur public, un
    pilote bleu peut arrêter la QRA rouge qu'il s'apprête à survoler. Réservez-le à un groupe de
    Mission Master avec `radio_menu_restrict_to_group` — en sachant que tout joueur qui prend le slot
    de ce groupe voit le menu à son tour — et ajoutez `radio_menu_secured: true` pour que ce pilote
    doive en plus avoir le niveau de sécurité requis.

C'est le **mécanisme 1** (raccourci par module). Pour un menu MM personnalisé, structuré ou combinant plusieurs actions (QRA, AirWaves, flags, messages, Lua), utilisez le **mécanisme 2** décrit dans [veafRadio → Menus radio en YAML](veafRadio.md#radio-menus-in-yaml).

### Dimensionner l'opposition au nombre de joueurs {#opposition-level}

Des paliers par `enemy_count` répondent à **ce qui entre dans la zone**. Une paire qui s'y présente devant un dispositif de six reçoit le palier d'une paire, pendant que les quatre autres sont encore à l'écart. Le **niveau d'opposition** dit pour combien d'avions joueurs la chasse adverse est dimensionnée, dans la même unité que `enemy_count` ; une QRA marquée `scale_with_opposition: true` prend le palier du plus grand des deux nombres.

```yaml
opposition:                 # bloc racine de mission.yaml, à côté de modules:
  level: 6                  # dimensionnée pour 6 avions joueurs
  follow: air_to_air        # off (défaut) | air_to_air : joueurs en CAP | players : connectés | airborne : en vol
  lower_after: 300          # secondes pendant lesquelles un compte plus bas doit tenir avant de baisser le niveau
  players_coalition: BLUE   # BLUE (défaut) | RED : la coalition dont on compte les joueurs
```

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `level` | entier ≥ 0 | — | Le niveau au démarrage. Sans niveau ni suivi, les QRA répondent à leur zone seule |
| `follow` | string | `off` | `air_to_air` : le niveau suit les joueurs **en vol qui emportent au moins un missile air-air à guidage radar** (Fox 1 ou Fox 3) — ceux qui font de la CAP ; `players` : tous les joueurs connectés de la coalition, hélicoptères et avions d'attaque au sol compris ; `airborne` : tous ceux qui sont en vol. Relu toutes les 60 s |
| `lower_after` | secondes | `300` | Une hausse est prise **tout de suite** (un joueur qui arrive doit être servi) ; une baisse seulement quand le compte est resté plus bas pendant ce délai — une déconnexion, ou un crash suivi d'un respawn, ne change rien |
| `players_coalition` | string | `BLUE` | La coalition dont les joueurs sont comptés |

Le bloc ajoute aussi, en jeu :

- un menu radio **Opposition** : *Niveau actuel* (pour tous), *Niveau* → « 1 joueur(s) en CAP » … « 8 joueur(s) en CAP », qui fixe le niveau en un clic et arrête le suivi, et *Mode* → le mode de suivi (commandes sécurisées) ;
- un marqueur **`_opposition`**, réservé au niveau de sécurité *SENIOR_PILOT* : `_opposition 6` fixe le niveau (et arrête le suivi), `_opposition air_to_air` / `_opposition players` / `_opposition airborne` / `_opposition off` change de mode, `_opposition` seul l'annonce ;
- dans le menu des [combat missions](veafCombatMission.md), sous chaque niveau de compétence, une entrée **Taille auto** qui active le *scale* d'un groupe ennemi par deux joueurs (arrondi au-dessus), dans la limite des *scales* proposés.

Chaque changement de niveau est annoncé à tout le monde.

**Comment choisir.** Écrivez les paliers jusqu'à la taille attendue du dispositif : pour un groupe de 5 à 7 joueurs, par exemple `1` → une paire, `3` → deux paires, `5` → trois. Jamais une seule paire fixe face à 5 joueurs ou plus. Ensuite :

- soirée dont on connaît l'effectif → `level` fixe ;
- effectif inconnu, ou qui change en cours de vol → `follow: air_to_air` : seuls les joueurs en CAP comptent, pas ceux qui sont venus faire de l'attaque au sol, de l'hélico ou du transport ;
- tous les joueurs doivent compter, quel que soit leur rôle → `follow: players`, ou `follow: airborne` pour ne compter que ceux qui sont en l'air.

`air_to_air` lit l'armement **en vol** (`getAmmo`) : ce que l'avion emporte à cet instant, donc ce que le pilote a choisi au réarmement, pas le chargement posé dans la mission.
Deux AIM-9 d'autodéfense sur un avion chargé de bombes ne comptent pas ; un chasseur qui n'emporte que des missiles infrarouges non plus.
Un multirôle en attaque au sol qui garde deux AIM-120 d'escorte compte : le menu *Niveau* corrige le compte le soir où il se trompe.

Une campagne écrit ce bloc toute seule à partir de son `players` ou de `campaign next --players` — voir [Campagnes](../CAMPAIGN.md#players).

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
| `:setFollowUnit(unitName)` | La zone suit cette unité, un porte-avions par exemple |

### Défenseurs

| Méthode | Description |
|---------|-------------|
| `:addGroup(name)` | Ajouter un groupe DCS à scrambler (appeler plusieurs fois pour plusieurs groupes) |
| `:addRandomGroup(groups, number, bias)` | Piocher aléatoirement `number` groupes dans une liste |
| `:setGroupsToDeployByEnemyQuantity(n, groups)` | Adapter la réponse : déployer **tous** les `groups` quand au moins `n` ennemis sont dans la zone (le plus grand palier atteint l'emporte) |
| `:setRandomGroupsToDeployByEnemyQuantity(n, groups, number, bias)` | Même chose, en tirant `number` groupes sans remise |

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
| `:setNoNeedToLeaveZoneBeforeRearming()` | Autoriser le réarmement même si des ennemis sont encore dans la zone (`rearm_while_occupied`) |
| `:setScaleWithOpposition()` | Choisir le palier d'après le niveau d'opposition quand il dépasse le nombre d'intrus (`scale_with_opposition`) |
| `:setResetWhenLeavingZone()` | Réinitialiser immédiatement quand tous les ennemis quittent la zone |
| `:setDelayBeforeActivating(seconds)` | Délai avant mise en ligne après `:start()` |
| `:setMinimumAltitudeInFeet(feet)` | Altitude minimale de l'ennemi pour déclencher un scramble |
| `:setMaximumAltitudeInFeet(feet)` | Altitude maximale de l'ennemi pour déclencher un scramble |
| `:setRespawnDefaultOffset(latDelta, lonDelta)` | Décalage de spawn depuis le centre de la zone (mètres, lat/lon) — premier nombre vers le nord, second vers l'est ; voir [veafAirWaves](veafAirWaves.md#spawn-offset) |
| `:setRespawnRadius(meters)` | Rayon de dispersion autour du point de spawn (minimum 250 m) |

### Liens

| Méthode | Description |
|---------|-------------|
| `:addLink(name)` | Faire dépendre la QRA d'une base, d'un FARP, d'un navire, d'un groupe ou d'un static : une base perdue la met en pause, le reste détruit l'arrête |
| `:setAirportLink(name)` | Lier à une base — la QRA se met en pause tant que la base est perdue (raccourci de `:addLink`) |
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
| `NOAIRBASE` | Une base aérienne liée est capturée ou trop endommagée — la QRA attend qu'elle soit reprise |

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

> Une définition listée sous `definitions:` est démarrée automatiquement au chargement de la mission. Pour retarder sa mise en ligne, utilisez `delay_before_activating` ; pour la déclarer **sans l'armer**, mettez `active_at_start: false` (elle peut ensuite être armée par une commande radio `qra.start` ou un script) ; pour la supprimer complètement, retirez-la de `definitions:`.

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

### Ce que fait un groupe décollé {#scrambled-group-task}

Un groupe dont la **tâche** (dans l'éditeur) est `CAP` ou `Intercept` reçoit son travail du script quand sa
route n'en prévoit pas : s'il ne porte aucune tâche d'engagement des aéronefs (`EngageTargets` ou
`EngageTargetsInZone` avec des cibles *Air*), il est lancé en **défense de zone** :

- il apparaît là où vous l'avez placé, avec les options de son premier point (ROE, réaction à la menace…) ;
- il rejoint la zone de la QRA et y tient un hippodrome centré sur la zone, dans l'axe de son arrivée
  (branche de 20 NM, ou le diamètre de la zone s'il est plus court) ;
- il n'engage que les aéronefs qui entrent dans la zone, qu'il classe selon leur type et leur distance.

Un groupe placé **au parking ou sur la piste** garde son décollage tel que vous l'avez réglé, puis monte à
27 000 ft pour sa patrouille.

**Sur la piste par défaut.** Une QRA décolle vraiment de son terrain : c'est le départ que pose l'action MCP `create_qra` quand on ne lui dit rien (l'aérodrome de la coalition le plus proche de la zone, ou celui qu'on nomme), un départ en l'air seulement sur demande.
Ce que ça coûte :

- **le temps de décoller** avant d'arriver sur la zone — à mesurer en jeu, pas estimé ici ;
- **un terrain trop endommagé ou pris** (sous `airbaseMinLifePercent`) garde la QRA au sol (`NOAIRBASE`) : dans une campagne, frapper le terrain ennemi est une façon de clouer sa QRA, et c'est voulu ;
- **une unité sur la piste** l'empêche de rouler : les garnisons d'une campagne sont tenues hors du béton pour cette raison ;
- **dix minutes pour décoller** (`veafQraManager.TAKEOFF_TIMEOUT`) : tant qu'un groupe n'a pas encore été vu en l'air, il roule, il n'est pas posé ; resté au sol au-delà, il est tenu pour coincé et la QRA est réarmée. Un groupe qui a volé puis se pose est réarmé comme avant.

C'est donc le cas normal : placez l'intercepteur avec **un seul point**, sans tâche, et le script fait le
reste ; le build l'annonce pour chaque groupe concerné. Si vous voulez votre propre plan de vol, écrivez-le **avec** une tâche d'engagement des aéronefs : il
est alors suivi tel quel. Une route écrite à la main sans cet engagement est remplacée, et le build vous le
signale par un avertissement. Un groupe d'une autre tâche (`CAS`, `Ground Attack`, `Escort`…) suit toujours
sa route.

Une commande `-cap` listée dans `simple_groups` défend elle aussi la zone de la QRA, et non la zone de
60 NM qu'elle dessine autour de sa propre branche.

### Chaîne logistique {#logistics-chain}

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

Dans `mission.yaml`, le bloc `logistics:` d'une définition règle la même chose, une clé par méthode :

| Clé de `logistics` | Méthode | Rôle |
|--------------------|---------|------|
| `groups_available` | `setQRAcount` | Groupes en stock au départ ; à `0`, la QRA démarre vide et attend un ravitaillement |
| `max_ready` | `setQRAmaxCount` | Plafond de groupes en stock |
| `resupply_delay` | `setQRAresupplyDelay` | Secondes entre la commande et la livraison |
| `resupply_amount` | `setResupplyAmount` | Groupes livrés à chaque ravitaillement |
| `max_resupplies` | `setQRAmaxResupplyCount` | Groupes livrables au total (`-1` = illimité, `0` = aucun ravitaillement) |
| `resupply_below` | `setQRAminCountforResupply` | Stock sous lequel un ravitaillement part ; absent, il part dès qu'un groupe est perdu |

```yaml
modules:
  QRA:
    definitions:
      - name: "QRA-LIMITED"
        coalition: RED
        trigger_zone: "ZONE-LIMITED"
        simple_groups: ["F-15C QRA 1", "F-15C QRA 2"]
        logistics:
          groups_available: 4
          max_ready: 2
          resupply_delay: 1800
          resupply_amount: 1
```

`validate` signale une clé de `logistics` qu'il ne connaît pas.

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
