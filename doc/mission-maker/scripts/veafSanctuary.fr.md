# veafSanctuary — Zones protégées

**Module ID:** — | **Fichier:** `veafSanctuary.lua`

---

## Objectif

Définit des zones qui détruisent automatiquement toute unité de la coalition spécifiée qui y entre. Utile pour protéger les zones d'opération des porte-avions, les bases aériennes amies ou les zones arrière sécurisées contre les intrusions ennemies.

---

## Dépendances

- `veafEventHandler` — pour la détection d'entrée dans la zone

---

## Activation

```lua
veafSanctuary.initialize()
```

Puis définir les zones :

```lua
VeafSanctuary:new()
  :setName("Carrier Zone")
  :setZoneName("ZONE-CARRIER-PROTECTION")
  :setCoalition(coalition.side.RED)  -- détruire les unités rouges qui entrent
  :setMessage("Aéronef hostile éliminé dans la zone de défense du porte-avions")
  :initialize()
```

---

## Configuration (`mission.yaml`)

```yaml
lua_modules:
  SANCTUARY:
    enable: true          # défaut : true
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
        protect_from_missiles: false   # true = intercepter aussi les missiles visant la zone
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
| `sanctuary_zones[].protect_from_missiles` | booléen | `false` | Non | Intercepter également les missiles visant la zone |

### Exemple minimal

```yaml
lua_modules:
  SANCTUARY:
    enable: true
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

| Méthode | Description |
|---------|-------------|
| `:setName(name)` | Identifiant interne |
| `:setZoneName(zone)` | Zone de trigger DCS |
| `:setCoalition(side)` | Coalition des unités à détruire |
| `:setMessage(text)` | Message affiché quand une unité est détruite |
| `:setSilent(bool)` | Supprimer les messages |
| `:initialize()` | Activer la zone |

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
