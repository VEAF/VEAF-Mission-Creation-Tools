# veafCombatZone — Zones de combat activables

**Module ID:** `COMBATZONE` | **Version:** 1.22.x | **Fichier:** `veafCombatZone.lua`

---

## Objectif

Définit des zones de combat nommées dans l'éditeur de mission que les joueurs peuvent activer et désactiver via le menu radio F10. Chaque zone suit l'état des unités ennemies, déclenche des événements de completion d'objectif, supporte la notation et peut contenir plusieurs groupes d'unités avec des règles de spawn.

---

## Dépendances

- `veafRadio` — menu F10
- `veafSpawn` — backend de spawn d'unités
- `veafMarkers` — commandes de marqueur optionnelles

---

## Activation

```lua
veafCombatZone.initialize()
```

Les zones individuelles sont créées et initialisées séparément (voir ci-dessous).

---

## Configuration (`mission.yaml`)

```yaml
modules:
  COMBATZONE:
    enabled: true          # défaut : true
    logLevel: info        # surcharge optionnelle du niveau de log
    combat_zone_settings: # surcharges globales optionnelles
      event_message_combatzonecomplete: "Objectif de zone atteint !"  # null = supprimer
      watchdog_check_interval: 30          # secondes entre les sondages du watchdog (défaut : 60)
      radio_menu_name: "Zones de combat"   # libellé du menu F10
      combat_zone_menu_name: "Opérations Zone de Combat"
      operation_menu_name: "Opérations"
    combat_zones:         # définitions de zones et d'opérations
      - type: zone                          # zone | operation
        zone_name: "CZ-Alpha"              # nom de la zone de trigger DCS
        friendly_name: "Zone Alpha"        # libellé dans le menu radio
        briefing: "Détruire la colonne blindée."  # affiché dans les infos mission
        training: false                     # true = pas de sécurité, statut verbeux
        chained_zones:                      # zones à déclencher quand celle-ci se termine
          - "CZ-Bravo"
        chained_delay: 60                   # secondes avant le déclenchement des zones chaînées
      - type: operation
        zone_name: "Op-Tonnerre"
        friendly_name: "Opération Tonnerre"
        tasking_orders:
          - zone_name: "CZ-Alpha"           # première tâche (sans dépendances)
          - zone_name: "CZ-Bravo"
            dependencies:                   # CZ-Bravo se débloque après CZ-Alpha
              - "CZ-Alpha"
```

### Champs de `combat_zone_settings`

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `event_message_combatzonecomplete` | string \| null | *(défaut module)* | Message diffusé quand une zone se termine. `null` le supprime. |
| `watchdog_check_interval` | entier | `60` | Secondes entre les sondages du watchdog |
| `radio_menu_name` | string | `"COMBAT ZONES"` | Libellé du menu de premier niveau F10 |
| `combat_zone_menu_name` | string | *(défaut)* | Libellé du sous-menu des opérations de zone |
| `operation_menu_name` | string | *(défaut)* | Libellé du sous-menu des opérations |

### Champs de `combat_zones[]` — type `zone`

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `type` | string | `zone` | Non | `zone` ou `operation` |
| `zone_name` | string | — | Oui | Nom de la zone de trigger DCS |
| `friendly_name` | string | — | Non | Libellé affiché dans le menu F10 |
| `briefing` | string | — | Non | Texte de briefing affiché aux joueurs |
| `training` | booléen | `false` | Non | Mode entraînement : pas de sécurité, statut verbeux |
| `chained_zones` | string[] | `[]` | Non | Noms des zones à déclencher à la completion |
| `chained_delay` | entier | `0` | Non | Secondes avant le déclenchement des zones chaînées |

### Champs de `combat_zones[]` — type `operation`

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `type` | string | — | Oui | Doit être `operation` |
| `zone_name` | string | — | Oui | Nom de la zone de trigger DCS |
| `friendly_name` | string | — | Non | Libellé dans le menu radio |
| `briefing` | string | — | Non | Texte de briefing |
| `tasking_orders` | objet[] | `[]` | Non | Liste de tâches ordonnées |
| `tasking_orders[].zone_name` | string | — | Oui | Nom de la zone de combat pour cette tâche |
| `tasking_orders[].dependencies` | string[] | `[]` | Non | Noms des zones devant se terminer en premier |

### Exemple minimal

```yaml
modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - type: zone
        zone_name: "CZ-Alpha"
        friendly_name: "Alpha"
```

---

## Constantes du module

| Constante | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `veafCombatZone.SecondsBetweenWatchdogChecks` | `60` | Fréquence de vérification du watchdog de zone (s) |
| `veafCombatZone.SecondsBetweenSmokeRequests` | `180` | Délai entre marquages fumée (s) |
| `veafCombatZone.SecondsBetweenFlareRequests` | `120` | Délai entre marquages fusée (s) |
| `veafCombatZone.RadioMenuName` | `"COMBAT ZONES"` | Libellé du sous-menu F10 |
| `veafCombatZone.DefaultSpawnRadiusForUnits` | `50` | Rayon de dispersion par défaut (m) |

---

## Fonctionnement

Placez toutes les unités qui doivent apparaître dans la zone directement dans l'éditeur de mission DCS, à l'intérieur de la trigger zone. Au démarrage de la mission, VEAF les retire toutes — la zone est vide. Quand un joueur active la zone via le menu F10, toutes les unités réapparaissent à des positions aléatoires dans le rayon de la zone. Quand toutes les unités ennemies sont détruites, la zone est marquée comme terminée (un callback optionnel se déclenche, les zones chaînées optionnelles s'activent).

Cette approche vous donne une conception entièrement visuelle dans l'éditeur tout en gardant la zone inactive au démarrage de la mission.

### Mise en place dans l'éditeur de mission DCS

1. **Créez une trigger zone** — définissez la zone de combat. Nommez-la, par exemple `ZONE-ALPHA`.
2. **Placez des groupes d'unités** à l'intérieur de la zone. Mettez-les dans n'importe quelle coalition — VEAF gère leur cycle de vie.
3. **Utilisez les tags de nom d'unité** (voir ci-dessous) pour personnaliser le comportement d'apparition par groupe.
4. **Enregistrez la zone** dans `mission-script.lua` :

```lua
VeafCombatZone:new()
  :setMissionEditorZoneName("ZONE-ALPHA")     -- nom de la trigger zone DCS
  :setFriendlyName("Alpha")                    -- libellé du menu radio
  :setBriefing("Strike Alpha — Colonne blindée")
  :initialize()
```

`veafCombatZone.initialize()` doit d'abord être appelé au niveau du module.

---

## Tags de nom d'unité

Les noms d'unités et de groupes dans l'éditeur de mission DCS peuvent porter des tags spéciaux qui contrôlent la façon dont VEAF les traite à l'activation de la zone. Les tags sont intégrés dans le nom et n'affectent pas DCS lui-même.

| Tag | Exemple | Description |
|-----|---------|-------------|
| `#spawnradius=N` | `#spawnradius=200` | Rayon de dispersion en mètres autour du centre de la zone pour ce groupe |
| `#spawnchance=N` | `#spawnchance=50` | Probabilité en pourcentage (0–100) que ce groupe apparaisse réellement |
| `#spawncount=N` | `#spawncount=3` | Nombre d'exemplaires à faire apparaître (peut être >1 pour des unités répétées) |
| `#spawngroup="name"` | `#spawngroup="SAM"` | Remplace le nom du groupe d'apparition (utile pour cibler un modèle nommé) |
| `#spawndelay=N` | `#spawndelay=120` | Délai en secondes avant l'apparition de ce groupe après l'activation de la zone |
| `#command="cmd"` | `#command="-spawn sa-11"` | Exécute une commande VEAF au lieu de faire apparaître ce groupe ; l'unité sert de déclencheur et est détruite |

### Exemple pratique — embuscade MANPADS

Vous voulez quatre positions de MANPADS dans une zone, mais seules deux devraient réellement être occupées. Placez quatre unités d'infanterie factices nommées :

```
ALPHA-MANPAD-1 #spawnchance=50
ALPHA-MANPAD-2 #spawnchance=50
ALPHA-MANPAD-3 #spawnchance=50
ALPHA-MANPAD-4 #spawnchance=50
```

Chaque position a 50 % de chances d'apparaître — statistiquement, environ deux seront actives à chaque déclenchement de la zone.

### `#command` — apparition via la syntaxe de marqueur VEAF

Le tag `#command` transforme une unité en déclencheur à usage unique. À l'activation de la zone, VEAF exécute la commande à la position de l'unité et détruit l'unité. C'est l'équivalent du dépôt d'un marqueur de carte à cet endroit.

```
SPAWN-SA11 #command="-spawn sa-11, side red"
CONVOY-TRIGGER #command="-convoy from ZONE-ALPHA to ZONE-BRAVO"
```

Cela permet de monter des apparitions complexes (batterie SA-11, convois avec routes IA) sans aucun code Lua.

---

## Définir une zone

Dans le cas le plus courant, les éléments sont peuplés automatiquement à partir des unités placées dans la trigger zone DCS via `:addZoneElementsFromZoneNamed(...)` :

```lua
local strikeZone = VeafCombatZone:new()
  :setMissionEditorZoneName("ZONE-STRIKE-ALPHA")  -- nom de la trigger zone DCS
  :setFriendlyName("Strike Alpha")                 -- libellé du menu radio
  :setBriefing("Détruire tous les véhicules. Prévoir de l'AAA et des MANPADS.")
  :addZoneElementsFromZoneNamed("ZONE-STRIKE-ALPHA")
  :initialize()
```

On peut aussi construire et attacher un élément manuellement avec `:addZoneElement(...)` :

```lua
local element = VeafCombatZoneElement:new()
  :setName("STRIKE-ALPHA-ARMOR")
  :setDcsGroup(true)
  :setSpawnGroup("STRIKE-ALPHA-ARMOR")    -- nom du groupe DCS à faire apparaître
  :setSpawnRadius(100)

strikeZone:addZoneElement(element)
```

### Méthodes du builder VeafCombatZone

| Méthode | Description |
|---------|-------------|
| `:setMissionEditorZoneName(name)` | Trigger zone DCS qui définit la zone de spawn |
| `:setFriendlyName(name)` | Libellé affiché dans le menu radio |
| `:setBriefing(text)` | Texte complet du briefing |
| `:setOnCompletedHook(fn)` | Callback quand tous les ennemis sont détruits |
| `:addZoneElement(element)` | Ajouter un élément à la zone |
| `:addZoneElementsFromZoneNamed(zoneName)` | Peupler les éléments depuis les unités d'une trigger zone |
| `:addSpawnedGroup(groupOrName)` | Déclarer un groupe déjà apparu comme appartenant à la zone |
| `:setActive(bool)` | Activer la zone au démarrage |
| `:setTraining(bool)` | Mode entraînement |
| `:setCompletable(bool)` | La zone peut être marquée comme terminée |
| `:enableUserActivation()` / `:disableUserActivation()` | Autoriser/interdire l'activation par les joueurs |
| `:setRadioGroupName(name)` | Restreindre le menu radio de la zone à un groupe de joueurs |
| `:setRadioMenuPrefix(text)` | Préfixe affiché devant le nom de la zone dans le menu |

### Méthodes du builder VeafCombatZoneElement

| Méthode | Description |
|---------|-------------|
| `:setName(name)` | Nom de l'élément |
| `:setPosition(pos)` | Position de l'élément |
| `:setDcsGroup(bool)` | L'élément référence un groupe DCS |
| `:setDcsStatic(bool)` | L'élément référence un objet statique DCS |
| `:setSpawnGroup(name)` | Nom du groupe DCS à faire apparaître |
| `:setVeafCommand(cmd)` | Commande VEAF à exécuter au lieu d'un spawn |
| `:setRoute(route)` | Route IA de l'élément |
| `:setCoalition(side)` | Coalition de l'élément |
| `:setSpawnRadius(m)` | Rayon de dispersion autour du centre de la zone |
| `:setSpawnChance(pct)` | Probabilité d'apparition (0–100) |
| `:setSpawnCount(n)` | Nombre d'exemplaires à faire apparaître |
| `:setSpawnDelay(s)` | Délai avant apparition (secondes) |

---

## Menu radio F10 (par zone)

- **Activer** — faire apparaître les groupes d'unités de la zone
- **Désactiver** — faire disparaître les unités, réinitialiser la zone
- **Infos** — statut, nombre d'unités restantes, briefing
- **Fumée** — marquer la zone avec de la fumée (délai applicable)
- **Fusée éclairante** — marquer la zone avec des fusées

> **Sécurité :** par défaut, les commandes d'activation/désactivation nécessitent une connexion `/secu login`. Seul le [mode entraînement](#mode-entraînement) supprime cette restriction. Les demandes d'infos, fumée et fusée sont toujours accessibles sans login.

### Options du menu radio

| Méthode | Description |
|---------|-------------|
| `:disableRadioMenu()` | Désactiver complètement le menu radio pour cette zone |
| `:setRadioMenuPrefix(text)` | Préfixe affiché devant le nom de la zone dans le menu |
| `:setRadioGroupName(name)` | Restreindre le menu radio de la zone à un groupe de joueurs |
| `:setEnableSmokeAndFlare(bool)` | Activer/désactiver les demandes de fumée et fusée (défaut : `true`) |
| `:setShowUnitsList(bool)` | Inclure la liste des unités restantes dans le message info (défaut : `true`) |
| `:setShowZonePositionInfo(bool)` | Inclure les coordonnées et la météo dans le message info (défaut : `true`) |

### Nettoyage des carcasses

Par défaut, à la désactivation d'une zone, les carcasses et cadavres sont automatiquement supprimés. Pour les conserver :

```lua
:disableJunkCleanup()
```

---

## Opérations (zones groupées)

Plusieurs zones peuvent être regroupées dans une **Opération** qui se complète quand toutes les zones filles sont terminées :

```lua
local operation = VeafCombatOperation:new()
  :setMissionEditorZoneName("OP-THUNDER")
  :setFriendlyName("Operation Thunder")
  :setBriefing("Détruire les deux colonnes blindées avant qu'elles atteignent Senaki.")

operation:addTaskingOrder(alphaZone)                 -- première tâche
operation:addTaskingOrder(bravoZone, { "OP-THUNDER-ALPHA" })  -- débloquée après Alpha
operation:initialize()
```

`VeafCombatOperation = VeafCombatZone:new()` — l'opération étend `VeafCombatZone`. Les tâches sont ajoutées avec `:addTaskingOrder(zone, requiredComplete)`, où `zone` est une `VeafCombatZone` et `requiredComplete` la liste optionnelle des noms de zones devant être terminées avant que celle-ci soit activée. L'opération apparaît dans le menu radio comme une seule entrée.

---

## Chaînage de zones

Une zone peut activer automatiquement une ou plusieurs zones suivantes lorsqu'elle est terminée. Cela permet de construire des progressions de campagne dynamiques sans scripting manuel :

```lua
VeafCombatZone:new()
  :setMissionEditorZoneName("ZONE-ALPHA")
  :setFriendlyName("Strike Alpha")
  :addChainedCombatZone("Strike Bravo")     -- se déclenche quand Alpha est terminée
  :addChainedCombatZone("Strike Charlie")   -- l'une est choisie au hasard
  :setChainedCombatZonesDelay(60)           -- attendre 60 s avant le chaînage
  :initialize()
```

Quand plusieurs zones chaînées sont définies, **une seule est tirée au hasard** — utile pour des scénarios à embranchements ou pour éviter la prévisibilité.

| Méthode | Description |
|---------|-------------|
| `:addChainedCombatZone(name)` | Ajouter une zone à déclencher après la complétion |
| `:setChainedCombatZonesDelay(s)` | Secondes à attendre avant le chaînage (défaut : 0) |

---

## Mode entraînement

Mettre une zone en mode entraînement change deux choses :

- **Pas de sécurité** : n'importe quel joueur peut activer ou désactiver la zone via le menu radio (normalement l'activation de la zone est journalisée et peut être restreinte par `/secu login`).
- **État détaillé** : le message d'info de la zone liste les unités restantes et leurs positions approximatives (via fumée ou relèvements), donnant aux pilotes une vue claire de ce qu'il reste.

```lua
VeafCombatZone:new()
  :setMissionEditorZoneName("ZONE-TRAINING-A")
  :setFriendlyName("Training-A")
  :setTraining(true)
  :initialize()
```

Le mode entraînement est idéal pour des scénarios d'entraînement BFM / CAS où les pilotes ont besoin de connaître les positions des unités.

---

## Voir aussi

- [veafCasMission](veafCasMission.md) — zones CAS générées (sans groupes pré-placés)
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafCombatZone`
