# veafTransportMission — Missions de transport et logistique

**Module ID:** `TRANSPORT` | **Version:** — | **Fichier:** `veafTransportMission.lua`

---

## Objectif

Crée des missions de transport en hélicoptère ou aéronef avec des zones de chargement et de livraison. Définit des zones de pickup et de dépôt pour du cargo ou des troupes. S'intègre avec CTLD (Combined Arms Transport and Logistics) quand il est disponible.

---

## Dépendances

- `veafRadio` — menu F10
- `veafMarkers` — commandes de marqueur optionnelles
- Script CTLD — intégration tierce optionnelle

---

## Activation

```lua
veafTransportMission.initialize()
```

---

## Concepts clés

- **Zone de chargement** — là où les hélicoptères ou transports récupèrent le cargo/les troupes
- **Zone de livraison** — là où le cargo/les troupes doivent être déposés
- Les missions peuvent avoir des objectifs (ex : livrer N caisses pour gagner)
- Supporte les cargos pré-placés et générés dynamiquement

---

## Exemple de configuration

```lua
-- Mission de transport de troupes simple
local transportMission = VeafTransportMission:new()
  :setName("Evac-Alpha")
  :setDescription("Évacuer les troupes de la base avancée Alpha")
  :setPickupZoneName("ZONE-PICKUP-ALPHA")
  :setDeliveryZoneName("ZONE-DELIVERY-BASE")
  :setCargoType("Troops")
  :setCargoCount(8)
  :setBriefing("8 soldats sont bloqués à la base Alpha. Extrayez-les vers Senaki.")
  :initialize()
```

---

## Méthodes du builder

| Méthode | Description |
|---------|-------------|
| `:setName(name)` | Identifiant interne |
| `:setDescription(text)` | Libellé du menu F10 |
| `:setPickupZoneName(zone)` | Zone de trigger DCS pour le pickup |
| `:setDeliveryZoneName(zone)` | Zone de trigger DCS pour la livraison |
| `:setCargoType(type)` | `"Troops"`, `"Crates"`, `"Vehicles"` |
| `:setCargoCount(n)` | Nombre d'unités de cargo |
| `:setBriefing(text)` | Texte du briefing de mission |
| `:setCoalition(side)` | Coalition de la mission |
| `:initialize()` | Enregistrer et activer |

---

## Menu radio F10

- **Infos** — position de la zone de pickup, description du cargo, zone de livraison
- **Activer** — faire apparaître les unités de la zone de pickup
- **Désactiver** — nettoyer la mission

---

## Voir aussi

- [veafCombatZone](veafCombatZone.md) — pour les zones d'objectif de combat
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafTransportMission`
