# veafAirWaves — Attaques aériennes par vagues

**Module ID:** `AIRWAVES` | **Fichier:** `veafAirWaves.lua`

---

## Objectif

Définit des zones qui font apparaître des vagues récurrentes d'aéronefs IA. Quand le nombre requis de joueurs humains entre dans la zone, la première vague est lancée. À chaque vague détruite, la suivante apparaît (avec des délais optionnels). Supporte la mise à l'échelle selon le nombre de joueurs, la réinitialisation à la mort d'un joueur et des messages radio personnalisés.

---

## Dépendances

- `veafSpawn` — spawn d'aéronefs IA
- `veafRadio` — messages de statut (optionnel)

---

## Activation

Pas d'`initialize()` global. Chaque zone est créée individuellement, puis démarrée avec `:start()` :

```lua
local defenseZone = AirWaveZone:new()
  :setName("AW-East")
  :setTriggerZone("ZONE-AIRWAVES-EAST")
  :setDescription("Zone d'interception est")
  :addPlayerCoalition(coalition.side.BLUE)
  :addWave({ "MiG-23 Wave 1a", "MiG-23 Wave 1b" })
  :addWave({ "MiG-29 Wave 2" })
  :start()
```

---

## Configuration (`mission.yaml`) {#configuration-missionyaml}

```yaml
modules:
  AIRWAVES:
    enabled: true          # défaut : true
    logLevel: info        # surcharge optionnelle du niveau de log
    airwave_zones:
      - name: "Zone BVR"                  # REQUIS — identifiant interne
        description: "Arène BVR Est"      # affiché dans les messages (optionnel)
        start: true                       # true = démarrer automatiquement au lancement
        player_coalitions: [BLUE]         # BLUE | RED — coalition dont les joueurs déclenchent les vagues
        zone_center_coordinates: "N41°00'00\" E044°00'00\""  # ou trigger_zone_name
        trigger_zone_name: "ZONE-BVR-EST"  # nom de la zone de trigger DCS (alternative aux coordonnées)
        zone_radius: 50000               # rayon en mètres (avec les coordonnées)
        draw_zone: true                  # dessiner le contour de la zone sur la carte
        respawn_default_offset: [0, 0]   # [delta_lat_m, delta_lon_m] décalage depuis le centre
        respawn_radius: 1000             # rayon de dispersion autour du point de spawn (mètres)
        delay_before_activation: 60      # secondes avant la première vague après entrée des joueurs
        delay_between_waves: 120         # délai fixe entre les vagues (ignoré si min/max définis)
        min_seconds_between_waves: 60    # délai inter-vague aléatoire minimum
        max_seconds_between_waves: 180   # délai inter-vague aléatoire maximum
        max_altitude_ft: 30000          # plafond de détection des joueurs en pieds — un joueur au-dessus n'est pas compté dans la zone
        min_altitude_ft: 1000           # plancher de détection des joueurs en pieds
        max_seconds_outside_ia: 300     # secondes avant de considérer une unité IA hors zone comme perdue
        minimum_life_percent: 10        # pourcentage de vie (0–100) sous lequel une unité IA est considérée comme détruite (défaut : 0)
        reset_when_dying: false         # réinitialiser toutes les vagues quand un joueur meurt
        message_start: "Zone active !"  # message personnalisé de début de zone (optionnel)
        message_wait_for_humans: "En attente des joueurs..."
        message_wave_deployed: "Vague en approche !"
        message_end_zone: "Zone libérée !"
        message_end_all: "Toutes les zones libérées !"
        waves:
          - groups: "su27-flight"       # nom de groupe DCS ou liste séparée par espaces
            delay: 0                    # secondes après cette vague avant la suivante ; -1 = simultané
            number: "1-2"              # groupes à choisir : entier ou plage "min-max"
            bias: 0                     # décaler la sélection aléatoire vers les entrées plus difficiles
          - groups: "su30sm-flight"
            delay: 120
```

### Champs communs de `airwave_zones[]`

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `name` | string | — | Oui | Identifiant interne |
| `description` | string | — | Non | Libellé affiché dans les messages et les logs |
| `start` | booléen | `false` | Non | Démarrage automatique au lancement de la mission |
| `player_coalitions` | string[] | — | Non | Coalitions dont les joueurs déclenchent les vagues (`BLUE`, `RED`) |

### Localisation de la zone (utiliser l'une ou l'autre)

| Champ | Type | Description |
|-------|------|-------------|
| `trigger_zone_name` | string | Nom de la zone de trigger DCS (recommandé) |
| `zone_center_coordinates` | string | Chaîne de coordonnées, ex : `"N41°00'00\" E044°00'00\""` |
| `zone_radius` | nombre | Rayon de la zone en mètres (requis avec les coordonnées) |

### Timing et limites

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `delay_before_activation` | entier | `0` | Secondes avant la première vague après entrée des joueurs |
| `delay_between_waves` | entier | `0` | Délai inter-vague fixe (surchargé par min/max) |
| `min_seconds_between_waves` | entier | — | Délai inter-vague aléatoire minimum |
| `max_seconds_between_waves` | entier | — | Délai inter-vague aléatoire maximum |
| `max_altitude_ft` | entier | — | Plafond de détection des joueurs : un joueur au-dessus n'est pas compté dans la zone |
| `min_altitude_ft` | entier | — | Plancher de détection des joueurs : un joueur en dessous n'est pas compté dans la zone |
| `max_seconds_outside_ia` | entier | — | Secondes avant qu'un groupe IA hors zone soit éliminé |
| `minimum_life_percent` | nombre | `0` | Pourcentage de vie (0–100, comparé à `100 × vie / vie initiale`) sous lequel une unité IA est considérée comme détruite |

### Champs de `waves[]`

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `groups` | string | — | Nom de groupe DCS, liste séparée par espaces, ou commande spawn VEAF |
| `delay` | entier | `0` | Secondes après la vague avant la suivante ; `-1` = simultané |
| `number` | string \| entier | — | Groupes à choisir : `2` ou plage `"1-3"` |
| `bias` | entier | `0` | Décaler l'index de début aléatoire vers les entrées plus difficiles |

### Menu radio de contrôle (raccourci)

Les commandes de démarrage/arrêt/réinitialisation d'une zone AirWave **n'existent pas** dans le menu radio VEAF standard (contrairement à CombatZone ou Carrier). Pour donner au Mission Master un contrôle F10 sur une zone, ajoutez `radio_menu: true` à sa définition : le framework génère automatiquement un sous-menu nommé d'après la zone, avec les commandes « Démarrer &lt;nom&gt; », « Arrêter &lt;nom&gt; » et « Réinitialiser &lt;nom&gt; ».

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `radio_menu` | booléen | `false` | Non | Générer automatiquement un sous-menu radio F10 de contrôle de cette zone |
| `radio_menu_restrict_to_group` | string | — | Non | Nom d'un groupe DCS ; le sous-menu généré n'apparaît que pour ce groupe |

```yaml
modules:
  AIRWAVES:
    airwave_zones:
      - name: "Zone BVR"
        start: true
        player_coalitions: [BLUE]
        trigger_zone_name: "ZONE-BVR"
        waves:
          - groups: "su27-flight"
        radio_menu: true                         # génère le sous-menu de contrôle
        radio_menu_restrict_to_group: "MM Ctrl"  # optionnel : réserver le sous-menu à ce groupe DCS
```

C'est le **mécanisme 1** (raccourci par module). Pour un menu MM personnalisé, structuré ou combinant plusieurs actions (AirWaves, QRA, flags, messages, Lua), utilisez le **mécanisme 2** décrit dans [veafRadio → Menus radio en YAML](veafRadio.md#radio-menus-in-yaml).

### Exemple minimal

```yaml
modules:
  AIRWAVES:
    enabled: true
    airwave_zones:
      - name: "Arène BVR"
        start: true
        player_coalitions: [BLUE]
        trigger_zone_name: "ZONE-BVR"
        delay_between_waves: 90
        waves:
          - groups: "su27-2ship"
            delay: 0
          - groups: "su30sm-2ship"
            delay: 60
```

---

## Méthodes du builder AirWaveZone

| Méthode | Description |
|---------|-------------|
| `:setName(name)` | Identifiant interne |
| `:setTriggerZone(zoneName)` | Zone de trigger DCS définissant la zone d'interception |
| `:setZoneCenter(vec3)` | Centre de la zone (point), alternative à la zone de trigger |
| `:setZoneCenterFromCoordinates(coords)` | Centre de la zone depuis une chaîne de coordonnées |
| `:setZoneRadius(m)` | Rayon de la zone en mètres (avec un centre) |
| `:setDescription(text)` | Libellé pour les messages et les logs |
| `:addWave(...)` | Ajouter une vague — voir [Définition d'une vague](#définition-dune-vague) |
| `:resetWaves()` | Vider toutes les vagues ajoutées (utile après `mist.utils.deepCopy`) |
| `:addPlayerCoalition(side)` | Ajouter une coalition dont les joueurs comptent (ex : `coalition.side.BLUE`) |
| `:setRespawnRadius(m)` | Rayon de dispersion des spawns (défaut : 250 m) |
| `:setRespawnDefaultOffset(lat, lon)` | Décalage par rapport au centre de zone pour les spawns |
| `:setMaxSecondsOutsideOfZoneIA(n)` | Secondes avant qu'un groupe IA hors zone soit considéré comme perdu |
| `:setMaxSecondsOutsideOfZonePlayers(n)` | Secondes avant que la zone se réinitialise si tous les joueurs sortent |
| `:setDelayBetweenWaves(n)` | Délai par défaut en secondes entre les vagues |
| `:setDelayBeforeActivation(n)` | Secondes après l'entrée des joueurs avant la première vague |
| `:setMinimumAltitudeInFeet(n)` | Plancher de détection des joueurs (en pieds) |
| `:setMaximumAltitudeInFeet(n)` | Plafond de détection des joueurs (en pieds) |
| `:setMinimumLifeForAiInPercent(n)` | Pourcentage de vie (0–100) sous lequel une unité IA est considérée comme détruite (défaut : 0) |
| `:setResetWhenDying(bool)` | Réinitialiser la zone quand un joueur meurt |
| `:setSilent(bool)` | Supprimer tous les messages |
| `:setDrawZone(bool)` | Dessiner le contour de la zone sur la carte |
| `:setOnStart(fn)` | Callback `(zoneName, playerUnits)` quand la zone s'active |
| `:setOnDeploy(fn)` | Callback `(zoneName, waveIndex, playerUnits)` quand une vague est lancée |
| `:setOnDestroyed(fn)` | Callback `(zoneName, waveIndex, playerUnits)` quand une vague est détruite |
| `:setOnWon(fn)` | Callback `(zoneName, playerUnits)` quand toutes les vagues sont terminées |
| `:setOnLost(fn)` | Callback `(zoneName, playerUnits)` quand la zone est perdue |
| `:setOnStop(fn)` | Callback `(zoneName, playerUnits)` quand la zone est arrêtée |
| `:setMessageStart(text)` | Message personnalisé de démarrage de zone |
| `:setMessageDeploy(text)` | Message personnalisé de vague lancée |
| `:setMessageDeployPlayers(text)` | Message BRAA personnalisé envoyé aux joueurs en zone |
| `:setMessageDestroyed(text)` | Message personnalisé de vague détruite |
| `:setMessageWon(text)` | Message personnalisé de toutes vagues terminées |
| `:setMessageLost(text)` | Message personnalisé de zone perdue |
| `:setMessageStop(text)` | Message personnalisé d'arrêt de zone |
| `:start()` | Démarrer la zone |
| `:stop()` | Arrêter la zone |

---

## Définition d'une vague

`addWave(...)` accepte plusieurs formes — de la plus simple à la plus puissante :

```lua
-- Un seul nom de groupe
:addWave("Bandits Alpha")

-- Plusieurs noms de groupes d'un coup
:addWave("Bandits Alpha", "Bandits Bravo")

-- Une table de noms de groupes
:addWave({ "Bandits Alpha", "Bandits Bravo", "Bandits Charlie" })

-- Une table de paramètres avec contrôle complet
:addWave({
  groups  = { "Fighter 1", "Fighter 2", "Fighter 3", "Fighter 4", "Fighter 5" },
  number  = "1-3",   -- choisir entre 1 et 3 de ces groupes au hasard
  bias    = 2,        -- démarrer le tirage aléatoire au 3e groupe (index 2+1)
  delay   = 30,       -- attendre 30 s avant la vague suivante une fois celle-ci nettoyée
})
```

### `number` — contrôler combien de groupes apparaissent

`number` définit combien de groupes de la liste apparaissent réellement. Valeurs possibles :
- un entier : `number = 2` fait toujours apparaître exactement 2 groupes ;
- une plage sous forme de chaîne : `number = "2-4"` fait apparaître 2, 3 ou 4 groupes au hasard.

Si `number` dépasse la longueur de la liste, un même groupe peut être tiré plusieurs fois — utile pour faire apparaître plusieurs exemplaires de la même menace.

### `bias` — pencher vers les variantes plus difficiles

`bias` décale l'index de départ du tirage aléatoire vers la fin de la liste. Un `bias` de 0 (défaut) tire uniformément dans toute la liste. Un `bias` de 3 sur une liste de 6 groupes rend les 3 premières entrées moins susceptibles d'être choisies.

Le motif typique consiste à ordonner les groupes du plus facile au plus difficile — en début de campagne, `bias` reste à 0, puis vous l'augmentez au fil du temps pour rendre l'opposition progressivement plus dangereuse :

```lua
-- Un pool de vagues ordonné par difficulté. Ajustez bias= dynamiquement dans des callbacks.
:addWave({
  groups = {
    "Su-25 Flight",       -- 1 : facile
    "Su-25T Flight",      -- 2 : moyen
    "Su-27 Flight",       -- 3 : difficile
    "Su-30SM Flight",     -- 4 : très difficile
  },
  number = "1-2",
  bias   = 0,   -- démarrer facile ; monter à 2 plus tard dans la mission
})
```

### `delay` — vagues simultanées

Lorsque `delay` est **négatif**, la vague suivante apparaît immédiatement après celle-ci — sans attendre sa destruction. Cela permet d'envoyer plusieurs paquets de menaces en même temps :

```lua
:addWave({ groups = { "Fighter Escort" }, delay = -1 })  -- décolle en même temps que...
:addWave({ groups = { "Strike Package" } })              -- ...cette vague
```

### Commandes VEAF comme groupes

Au lieu d'un nom de groupe DCS, vous pouvez utiliser n'importe quelle commande de spawn VEAF (la même syntaxe qu'un marqueur de la carte F10). La commande est exécutée à la position d'apparition, ajustable avec un préfixe `[latDelta,lonDelta]` (en mètres, relatif au centre de la zone) :

```lua
:addWave({
  groups = {
    "[0,5000]-spawn su-27, country russia",           -- 5 km au nord du centre de la zone
    "[-3000,0]-spawn su-25, alt 100, country russia", -- 3 km au sud, basse altitude
  }
})
```

Cela permet de monter facilement des menaces étagées venant de directions différentes, sans pré-placer de groupes dans l'éditeur de mission DCS.

---

## Exemples

### Zone d'interception basique à trois vagues

```lua
AirWaveZone:new()
  :setName("Intercept-West")
  :setTriggerZone("ZONE-WEST-INTERCEPT")
  :setDescription("Axe de menace ouest")
  :addPlayerCoalition(coalition.side.BLUE)
  :addWave({ "Su-25T Strike 1a", "Su-25T Strike 1b" })
  :addWave({ "Su-25T Strike 2a", "Su-25T Strike 2b", "Su-25T Strike 2c" })
  :addWave({ "Su-24M Deep Strike" })
  :setDrawZone(true)
  :setOnWon(function()
    trigger.action.setUserFlag("WEST_CLEAR", true)
  end)
  :start()
```

### Vagues aléatoires à difficulté croissante

```lua
AirWaveZone:new()
  :setName("Intercept-East")
  :setTriggerZone("ZONE-EAST-INTERCEPT")
  :setDescription("Axe de menace est — difficulté progressive")
  :addPlayerCoalition(coalition.side.BLUE)
  -- Vague 1 : tirer 1 ou 2 chasseurs légers dans un pool
  :addWave({
    groups = { "MiG-21 Flight", "MiG-23 Flight", "MiG-29 Flight", "Su-27 Flight" },
    number = "1-2",
    bias   = 0,
    delay  = 120,   -- 2 minutes de répit avant la vague 2
  })
  -- Vague 2 : chasseurs moyens, pool un peu plus difficile
  :addWave({
    groups = { "MiG-29 Flight", "Su-27 Flight", "Su-30SM Flight" },
    number = 2,
    bias   = 1,
    delay  = 60,
  })
  -- Vague 3 : escorte lourde + attaque au sol simultanée (delay négatif)
  :addWave({ groups = { "Su-27 Escort" }, delay = -1 })
  :addWave({ groups = { "Su-24M Strike" } })
  :setDrawZone(true)
  :start()
```

### Réutiliser une zone modèle par copie profonde

Quand plusieurs secteurs partagent la même structure de vagues, définissez une zone modèle et clonez-la. Utilisez `:resetWaves()` pour vider les vagues du modèle avant d'ajouter celles propres au secteur :

```lua
-- Définir un modèle partagé (PAS encore démarré)
local zoneTemplate = AirWaveZone:new()
  :addPlayerCoalition(coalition.side.BLUE)
  :setDrawZone(true)
  :addWave({ "MiG-29 Wave 1" })
  :addWave({ "Su-27 Wave 2" })

-- Cloner et personnaliser pour chaque secteur
local zoneNorth = mist.utils.deepCopy(zoneTemplate)
zoneNorth
  :setName("AW-North")
  :setTriggerZone("ZONE-AW-NORTH")
  :setDescription("Secteur nord")
  :start()

local zoneSouth = mist.utils.deepCopy(zoneTemplate)
zoneSouth
  :setName("AW-South")
  :setTriggerZone("ZONE-AW-SOUTH")
  :setDescription("Secteur sud")
  :resetWaves()                          -- vider les vagues du modèle
  :addWave({ "Su-25T Wave 1" })          -- ajouter les vagues propres au secteur
  :addWave({ "Su-24M Wave 2", "Su-24M Wave 2b" })
  :start()
```

---

## Cycle de vie de la zone (machine d'états)

Chaque `AirWaveZone` progresse à travers un ensemble d'états nommés. Les connaître aide à lire les logs ou à écrire des callbacks.

```
STOP ──start()──► READY
                    │  joueur(s) entrent dans la zone
                    ▼
         WAITING_FOR_MORE_HUMANS
                    │  délai d'activation écoulé
                    ▼
              ┌── NEXTWAVE ──┐
              │               │
         dernière vague   autres vagues
              │               │
              ▼               ▼
            OVER    WAITING_FOR_NEXTWAVE
                            │  délai entre vagues écoulé
                            ▼
                          ACTIVE
                            │  vague détruite
                            └──► NEXTWAVE  (boucle jusqu'à OVER)
```

| État | Signification |
|------|---------------|
| `STOP` | Zone inactive — `stop()` a été appelé ou la zone n'a jamais démarré. |
| `READY` | Zone démarrée, en attente de joueurs. |
| `WAITING_FOR_MORE_HUMANS` | Au moins un joueur est dans la zone ; le minuteur d'activation tourne. |
| `NEXTWAVE` | État de routage transitoire : décide immédiatement entre `OVER` et `WAITING_FOR_NEXTWAVE`. |
| `WAITING_FOR_NEXTWAVE` | Prochain slot de vague disponible ; le délai entre vagues décompte. |
| `ACTIVE` | La vague courante est spawnée et vivante. |
| `OVER` | Toutes les vagues ont été détruites — la zone est terminée. |

`NEXTWAVE` est un état transitoire que la zone traverse en un seul cycle de `check()` : elle n'y reste jamais. Les callbacks comme `setOnDestroyed` se déclenchent à la sortie de `ACTIVE → NEXTWAVE`, et `setOnWon` à l'entrée de `NEXTWAVE → OVER`.

---

## Voir aussi

- [veafQraManager](veafQraManager.md) — système de scramble défensif
- [veafCombatZone](veafCombatZone.md) — zones de combat terrestres
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafAirWaves`
