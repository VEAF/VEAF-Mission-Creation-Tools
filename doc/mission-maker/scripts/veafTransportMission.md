# veafTransportMission — Missions de transport et logistique

**Module ID:** `TRANSPORT` | **Version:** — | **Fichier:** `veafTransportMission.lua`

---

## Objectif

Crée une mission d'entraînement au transport et à la logistique en hélicoptère, pilotée par un marqueur sur la carte F10. Quand un marqueur `_transport` est posé, le module fait apparaître le cargo à récupérer près d'un point nommé de départ, un groupe ami qui attend ce cargo sur la zone de livraison (sous le marqueur), et optionnellement des défenses anti-aériennes ennemies le long de la route.

---

## Dépendances

- `veafRadio` — menu F10
- `veafMarkers` — gestionnaire d'événement de marqueur (`_transport`)
- `veafSpawn`, `veafUnits`, `veafNamedPoints`, `veafSecurity`

---

## Activation

```lua
veafTransportMission.initialize()
```

> **Activé par défaut** dans le `mission.yaml` livré. Piloté par marqueur (`_transport`), sans configuration requise — posez simplement un marqueur `_transport`.

---

## Concepts clés

- **Point de départ** — un point nommé (déclaré via `veafNamedPoints`) où apparaît le cargo à transporter. Il est obligatoire et fourni par le paramètre `from`.
- **Zone de livraison** — là où apparaît le groupe ami qui attend le cargo, sous le marqueur `_transport`. La route entre le point de départ et la zone de livraison doit faire au moins 15 km.
- **Défenses sur la route** — groupes de défense anti-aérienne ennemis optionnels, placés le long de la route quand `defense` est supérieur à `0`.
- Une seule mission de transport peut être active à la fois.

---

## Commande par marqueur

Posez un marqueur sur la carte F10 et tapez `_transport` dans son texte, suivi optionnellement de paramètres séparés par des virgules.

```text
_transport, size 3, defense 2, from FARP London
```

### Paramètres du marqueur

| Paramètre | Valeurs | Défaut | Description |
|-----------|---------|--------|-------------|
| `size <n>` | `1`–`5` | `1` | Nombre de caisses de cargo à transporter |
| `defense <n>` | `0`–`5` | `0` | Couverture anti-aérienne le long de la route (`1` = légère, `5` = lourde) |
| `blocade <n>` | `0`–`5` | `0` | Blocus ennemi autour de la zone de livraison (`1` = léger, `5` = lourd) |
| `from <point nommé>` | point nommé | — | Point de départ **obligatoire** où apparaît le cargo |
| `password <mdp>` | string | — | Mot de passe de sécurité débloquant la commande |

---

## Menu radio F10

Le menu **TRANSPORT MISSION** expose toujours :

- **HELP** — rappel d'utilisation

Une fois une mission générée, il ajoute :

- **Drop zone information** — nombre d'unités amies sur la zone de livraison, ainsi que ses coordonnées (Lat/Lon, MGRS, relèvement/distance depuis le bullseye), altitude et vent
- **Skip current objective** — annule la mission en cours et nettoie
- **Drop zone markers** (sous-menu)
  - **Request smoke on drop zone** — fumigène vert sur la zone de livraison
  - **Request illumination flare over drop zone**

---

## Voir aussi

- [veafCombatZone](veafCombatZone.md) — pour les zones d'objectif de combat
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafTransportMission`
