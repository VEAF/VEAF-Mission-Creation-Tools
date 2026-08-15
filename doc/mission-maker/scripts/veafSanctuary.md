# veafSanctuary — Zones protégées

**Module ID:** `SANCTUARY` | **Fichier:** `veafSanctuary.lua`

---

## Objectif

Définit des zones qui protègent une coalition : toute unité d'une autre coalition qui y entre est avertie, puis traitée. Utile pour protéger les zones d'opération des porte-avions, les bases aériennes amies ou les zones arrière sécurisées contre les intrusions ennemies.

---

## Dépendances

---

## Activation

```lua
veafSanctuary.initialize()
```

Puis définir les zones :

```lua
local zone = VeafSanctuaryZone:new()
  :setName("Carrier Zone")
  :setCoalition(coalition.side.BLUE) -- coalition protégée : les unités des autres coalitions sont traitées
  :setPolygonFromUnits({ "SANCT-NO", "SANCT-NE", "SANCT-SE", "SANCT-SO" }, true)
  :setDelayWarning(30)               -- secondes avant l'avertissement
  :setDelaySpawn(60)                 -- secondes avant le déploiement des défenses
  :setProtectFromMissiles()          -- détruire aussi les missiles tirés sur les unités présentes
veafSanctuary.addZone(zone)
```

On peut aussi construire une zone à partir d'une zone de trigger DCS :

```lua
veafSanctuary.addZoneFromTriggerZone("ZONE-CARRIER-PROTECTION")
```

---

## Configuration (`mission.yaml`) {#configuration-missionyaml}

```yaml
modules:
  SANCTUARY:
    enabled: true          # défaut : true
    logLevel: info        # surcharge optionnelle du niveau de log
    sanctuary_zones:      # liste des zones protégées
      - name: "Zone Carrier"            # identifiant interne
        polygon_units:                  # noms d'unités DCS définissant le périmètre du polygone
          - "Sanctuary-Unit-1"
          - "Sanctuary-Unit-2"
        coalition: BLUE                 # BLUE | RED — coalition protégée ; les unités des autres coalitions sont traitées
        delay_warning: 30              # secondes de présence dans la zone avant le message d'avertissement (défaut : 0)
        delay_spawn: 60                # secondes de présence dans la zone avant le déploiement des défenses (-1 = désactivé, défaut)
        delay_instant: -1              # secondes de présence dans la zone avant la destruction instantanée (-1 = désactivé, défaut)
        protect_from_missiles: false   # true = détruire aussi les missiles tirés sur les unités présentes dans la zone
```

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `enabled` | booléen | `true` | Non | Activer ou désactiver le module |
| `logLevel` | string | *(global)* | Non | Surcharge du niveau de log par module |
| `sanctuary_zones` | objet[] | `[]` | Non | Liste des zones sanctuary |
| `sanctuary_zones[].name` | string | — | Oui | Identifiant interne |
| `sanctuary_zones[].polygon_units` | string[] | — | Non | Noms d'unités DCS définissant le périmètre du polygone |
| `sanctuary_zones[].coalition` | string | — | Non | `BLUE` ou `RED` — coalition protégée ; les unités des autres coalitions sont traitées à l'entrée |
| `sanctuary_zones[].delay_warning` | entier | `0` | Non | Secondes de présence dans la zone avant l'envoi du message d'avertissement |
| `sanctuary_zones[].delay_spawn` | entier | `-1` | Non | Secondes de présence dans la zone avant le déploiement des défenses (-1 = désactivé) |
| `sanctuary_zones[].delay_instant` | entier | `-1` | Non | Secondes de présence dans la zone avant la destruction instantanée de l'intrus (-1 = désactivé) |
| `sanctuary_zones[].protect_from_missiles` | booléen | `false` | Non | true = détruire aussi les missiles tirés sur les unités présentes dans la zone |

### Exemple minimal

```yaml
modules:
  SANCTUARY:
    enabled: true
    sanctuary_zones:
      - name: "Protection Porte-Avions"
        polygon_units:
          - "SANCT-NO"
          - "SANCT-NE"
          - "SANCT-SE"
          - "SANCT-SO"
        coalition: BLUE
```

---

## Méthodes du builder

Les zones sont construites avec `VeafSanctuaryZone:new()` puis enregistrées via `veafSanctuary.addZone(zone)`. Chaque setter retourne la zone, ce qui permet le chaînage.

| Méthode | Description |
|---------|-------------|
| `:setName(value)` | Identifiant interne |
| `:setCoalition(value)` | Coalition protégée (les unités des autres coalitions sont traitées) |
| `:setRadius(value)` | Rayon de la zone circulaire (mètres) |
| `:setPosition(value)` | Centre de la zone circulaire |
| `:setPolygonFromUnits(unitNames, markPositions)` | Définir un polygone à partir d'une liste de noms d'unités DCS ; `markPositions` à `true` dessine la zone sur la carte |
| `:setPolygonFromUnitsInSequence(unitNamePrefix, markPositions)` | Définir un polygone à partir d'unités nommées `prefix #001`, `prefix #002`, ... |
| `:setProtectFromMissiles()` | Activer la destruction des missiles tirés sur les unités présentes (aucun argument — drapeau) |
| `:setDelayWarning(value)` | Secondes avant l'envoi du message d'avertissement |
| `:setOffensesBeforeDestruction(value)` | Nombre de tirs sur des joueurs avant destruction du tireur |
| `:setMessageWarning(value)` | Message d'avertissement |
| `:setMessageShotTarget(value)` | Message à la cible lorsqu'un tir est détecté |
| `:setMessageShotLauncher(value)` | Message au tireur lorsqu'un tir est détecté |
| `:setDelayInstant(value)` | Secondes avant la destruction instantanée de l'intrus (-1 pour désactiver) |
| `:setDelaySpawn(value)` | Secondes avant le déploiement des défenses (-1 pour désactiver) |
| `:setMessageSpawn(value)` | Message affiché au déploiement des défenses |
| `:addSpawnedGroups(names)` | Enregistrer des groupes déployés associés à la zone |

---

## Notes

- Une zone se définit par polygone, par cercle (position + rayon) ou depuis une zone de trigger DCS (`addZoneFromTriggerZone`)
- Par défaut, aucune destruction instantanée : `delay_instant` vaut -1 (désactivé) ; l'escalade avertissement → défenses → destruction suit les délais configurés
- Fonctionne pour les aéronefs et les unités terrestres
- N'affecte pas la coalition qui possède le sanctuary

---

## Voir aussi

- [veafMissileGuardian](veafMissileGuardian.md) — système d'interception de missiles
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafSanctuary`
