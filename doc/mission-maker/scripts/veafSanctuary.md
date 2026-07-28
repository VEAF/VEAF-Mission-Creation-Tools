# veafSanctuary — Zones protégées

**Module ID:** `SANCTUARY` | **Fichier:** `veafSanctuary.lua`

---

## Objectif

Définit des zones qui détruisent automatiquement toute unité de la coalition spécifiée qui y entre. Utile pour protéger les zones d'opération des porte-avions, les bases aériennes amies ou les zones arrière sécurisées contre les intrusions ennemies.

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
  :setCoalition(coalition.side.RED)  -- protéger contre les unités rouges qui entrent
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
        coalition: RED                  # BLUE | RED — coalition dont les unités sont détruites à l'entrée
        delay_warning: 30              # secondes avant l'envoi du message d'avertissement (défaut : 0)
        delay_spawn: 60                # secondes avant que la zone devient active après le démarrage
        delay_instant: 0               # secondes entre les contrôles de destruction répétés (défaut : 0)
        protect_from_missiles: false   # true = détruire aussi les missiles tirés sur les unités présentes dans la zone
```

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `enable` | booléen | `true` | Non | Activer ou désactiver le module |
| `logLevel` | string | *(global)* | Non | Surcharge du niveau de log par module |
| `sanctuary_zones` | objet[] | `[]` | Non | Liste des zones sanctuary |
| `sanctuary_zones[].name` | string | — | Oui | Identifiant interne |
| `sanctuary_zones[].polygon_units` | string[] | — | Non | Noms d'unités DCS définissant le périmètre du polygone |
| `sanctuary_zones[].coalition` | string | — | Non | `BLUE` ou `RED` — les unités de cette coalition sont détruites à l'entrée |
| `sanctuary_zones[].delay_warning` | entier | `0` | Non | Secondes avant l'envoi du message d'avertissement |
| `sanctuary_zones[].delay_spawn` | entier | `0` | Non | Secondes avant que la zone s'active après le démarrage de la mission |
| `sanctuary_zones[].delay_instant` | entier | `0` | Non | Secondes entre les contrôles de destruction répétés |
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
        coalition: RED
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

- La zone utilise la zone de trigger DCS définie dans l'éditeur de mission
- Les unités sont détruites immédiatement à l'entrée dans la zone
- Fonctionne pour les aéronefs et les unités terrestres
- N'affecte pas la coalition qui possède le sanctuary

---

## Voir aussi

- [veafMissileGuardian](veafMissileGuardian.md) — système d'interception de missiles
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafSanctuary`
