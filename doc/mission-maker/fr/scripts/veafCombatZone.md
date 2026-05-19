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

## Constantes du module

| Constante | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `veafCombatZone.SecondsBetweenWatchdogChecks` | `60` | Fréquence de vérification du watchdog de zone (s) |
| `veafCombatZone.SecondsBetweenSmokeRequests` | `180` | Délai entre marquages fumée (s) |
| `veafCombatZone.SecondsBetweenFlareRequests` | `120` | Délai entre marquages fusée (s) |
| `veafCombatZone.RadioMenuName` | `"COMBAT ZONES"` | Libellé du sous-menu F10 |
| `veafCombatZone.DefaultSpawnRadiusForUnits` | `50` | Rayon de dispersion par défaut (m) |

---

## Définir une zone

```lua
local strikeZone = VeafCombatZone:new()
  :setName("Strike Alpha")                   -- nom interne
  :setZoneName("ZONE-STRIKE-ALPHA")          -- nom de la zone de trigger DCS
  :setDescription("Colonne blindée — Senaki")
  :setBriefing("Détruire tous les véhicules. Prévoir de l'AAA et des MANPADS.")
  :addElement(
    VeafCombatZoneElement:new()
      :setGroupName("STRIKE-ALPHA-ARMOR")    -- groupe DCS à faire apparaître
      :setSpawnRadius(100)
  )
  :addElement(
    VeafCombatZoneElement:new()
      :setGroupName("STRIKE-ALPHA-AAA")
  )
  :initialize()
```

### Méthodes du builder VeafCombatZone

| Méthode | Description |
|---------|-------------|
| `:setName(name)` | Identifiant interne |
| `:setZoneName(zoneName)` | Zone de trigger DCS qui définit la zone de spawn |
| `:setDescription(text)` | Nom court affiché dans le menu radio |
| `:setBriefing(text)` | Texte complet du briefing |
| `:addElement(element)` | Ajouter un groupe d'unités à la zone |
| `:setCoalition(side)` | Forcer la coalition de spawn |
| `:setRadioGroup(name)` | Regrouper des zones sous un sous-menu radio commun |
| `:setActivateAtStart(bool)` | Activer automatiquement au démarrage de la mission |
| `:setSilent(bool)` | Supprimer les messages de statut |
| `:setOnCompleted(fn)` | Callback quand tous les ennemis sont détruits |

### Méthodes du builder VeafCombatZoneElement

| Méthode | Description |
|---------|-------------|
| `:setGroupName(name)` | Groupe DCS à faire apparaître (doit exister dans l'éditeur) |
| `:setSpawnRadius(m)` | Rayon de dispersion autour du centre de la zone |
| `:setRespawn(bool)` | Réapparaître ou non après destruction |
| `:setRespawnDelay(s)` | Délai avant réapparition (secondes) |

---

## Menu radio F10 (par zone)

- **Activer** — faire apparaître les groupes d'unités de la zone
- **Désactiver** — faire disparaître les unités, réinitialiser la zone
- **Infos** — statut, nombre d'unités restantes, briefing
- **Fumée** — marquer la zone avec de la fumée (délai applicable)
- **Fusée éclairante** — marquer la zone avec des fusées

---

## Opérations (zones groupées)

Plusieurs zones peuvent être regroupées dans une **Opération** qui se complète quand toutes les zones filles sont terminées :

```lua
VeafCombatOperation:new()
  :setName("Operation Thunder")
  :addZone("Strike Alpha")
  :addZone("Strike Bravo")
  :setBriefing("Détruire les deux colonnes blindées avant qu'elles atteignent Senaki.")
  :initialize()
```

---

## Voir aussi

- [veafCasMission](veafCasMission.md) — zones CAS générées (sans groupes pré-placés)
- [Référence API Lua](../../../LUA_API_REFERENCE.md) — API complète de `veafCombatZone`
