# veafAirWaves — Attaques aériennes par vagues

**Module ID:** `AIRWAVES` | **Version:** 1.8.x | **Fichier:** `veafAirWaves.lua`

---

## Objectif

Définit des zones qui font apparaître des vagues récurrentes d'aéronefs IA. Quand le nombre requis de joueurs humains entre dans la zone, la première vague est lancée. À chaque vague détruite, la suivante apparaît (avec des délais optionnels). Supporte la mise à l'échelle selon le nombre de joueurs, la réinitialisation à la mort d'un joueur et des messages radio personnalisés.

---

## Dépendances

- `veafSpawn` — spawn d'aéronefs IA
- `veafRadio` — messages de statut (optionnel)

---

## Activation

Pas d'`initialize()` global. Chaque zone est créée individuellement :

```lua
local defenseZone = AirWaveZone:new()
  :setName("AW-East")
  :setZoneName("ZONE-AIRWAVES-EAST")
  :setDescription("Zone d'interception est")
  :addWave({ "MiG-23 Wave 1a", "MiG-23 Wave 1b" })
  :addWave({ "MiG-29 Wave 2" })
```

---

## Configuration (`mission.yaml`)

```yaml
lua_modules:
  AIRWAVES:
    enable: true          # défaut : true
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
        max_altitude_ft: 30000          # altitude maximale en pieds — les unités IA au-dessus sont supprimées
        min_altitude_ft: 1000           # altitude minimale en pieds
        max_seconds_outside_ia: 300     # secondes avant de considérer une unité IA hors zone comme perdue
        minimum_life_percent: 0.1       # supprimer l'unité IA en dessous de cette fraction de vie (0–1)
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
| `max_altitude_ft` | entier | — | Supprimer les unités IA au-dessus de cette altitude |
| `min_altitude_ft` | entier | — | Supprimer les unités IA en dessous de cette altitude |
| `max_seconds_outside_ia` | entier | — | Secondes avant qu'un groupe IA hors zone soit éliminé |
| `minimum_life_percent` | nombre | — | Supprimer l'unité IA quand sa vie passe sous cette fraction |

### Champs de `waves[]`

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `groups` | string | — | Nom de groupe DCS, liste séparée par espaces, ou commande spawn VEAF |
| `delay` | entier | `0` | Secondes après la vague avant la suivante ; `-1` = simultané |
| `number` | string \| entier | — | Groupes à choisir : `2` ou plage `"1-3"` |
| `bias` | entier | `0` | Décaler l'index de début aléatoire vers les entrées plus difficiles |

### Exemple minimal

```yaml
lua_modules:
  AIRWAVES:
    enable: true
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

  :setMinimumPlayersForWave(1)
  :initialize()
```

---

## Méthodes du builder AirWaveZone

| Méthode | Description |
|---------|-------------|
| `:setName(name)` | Identifiant interne |
| `:setZoneName(zoneName)` | Zone de trigger DCS définissant la zone d'interception |
| `:setDescription(text)` | Libellé pour les messages et les logs |
| `:addWave(groupNames)` | Ajouter une vague (table de noms de groupes DCS) |
| `:setMinimumPlayersForWave(n)` | Nombre minimum de joueurs humains pour déclencher une vague |
| `:setPlayerCoalitions(sides)` | Quelles coalitions comptent comme joueurs |
| `:setPlayerUnitsNames(names)` | Noms spécifiques d'unités joueur à suivre |
| `:setRespawnRadius(m)` | Rayon de dispersion des spawns (défaut : 250 m) |
| `:setRespawnDefaultOffset(lat, lon)` | Décalage par rapport au centre de zone pour les spawns |
| `:setSilent(bool)` | Supprimer tous les messages |
| `:setDrawZone(bool)` | Dessiner le contour de la zone sur la carte |
| `:setOnStart(fn)` | Callback quand la zone s'active |
| `:setOnWaveDestroyed(fn)` | Callback quand une vague est détruite |
| `:setOnCompleted(fn)` | Callback quand toutes les vagues sont terminées |
| `:setMessageStart(text)` | Message personnalisé de démarrage de zone |
| `:setMessageWaitToDeploy(text)` | Message personnalisé d'arrivée de vague |
| `:setMessageWaveDeployed(text)` | Message personnalisé de vague lancée |
| `:setMessageWaveDestroyed(text)` | Message personnalisé de vague détruite |
| `:setMessageCompleted(text)` | Message personnalisé de toutes vagues terminées |

---

## Vagues

Chaque vague est une liste de noms de groupes DCS. Tous les groupes d'une vague apparaissent simultanément. La vague suivante se déclenche quand tous les groupes de la vague courante sont détruits.

```lua
:addWave({ "BanditsA", "BanditsB" })   -- vague 1 : deux groupes apparaissent en même temps
:addWave({ "BanditsC" })               -- vague 2 : un groupe
:addWave({ "BanditsD", "BanditsE", "BanditsF" })  -- vague 3
```

---

## Exemple

```lua
-- Zone nécessitant 2 joueurs humains avec 3 vagues
AirWaveZone:new()
  :setName("Intercept-West")
  :setZoneName("ZONE-WEST-INTERCEPT")
  :setDescription("Axe de menace ouest")
  :addWave({ "Su-25T Strike 1a", "Su-25T Strike 1b" })
  :addWave({ "Su-25T Strike 2a", "Su-25T Strike 2b", "Su-25T Strike 2c" })
  :addWave({ "Su-24M Deep Strike" })
  :setMinimumPlayersForWave(2)
  :setDrawZone(true)
  :setOnCompleted(function()
    trigger.action.setUserFlag("WEST_CLEAR", true)
  end)
  :initialize()
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

`NEXTWAVE` est un état transitoire que la zone traverse en un seul cycle de `check()` : elle n'y reste jamais. Les callbacks comme `setOnWaveDestroyed` se déclenchent à la sortie de `ACTIVE → NEXTWAVE`, et `setOnCompleted` à l'entrée de `NEXTWAVE → OVER`.

---

## Voir aussi

- [veafQraManager](veafQraManager.md) — système de scramble défensif
- [veafCombatZone](veafCombatZone.md) — zones de combat terrestres
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafAirWaves`
