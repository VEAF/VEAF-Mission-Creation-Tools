# veafCarrierOperations — Gestion des récupérations sur porte-avions

**Module ID:** `CARRIER` | **Version:** 1.12.x | **Fichier:** `veafCarrierOperations.lua`

---

## Objectif

Gère les opérations de récupération sur porte-avions. Quand les joueurs déclenchent une récupération, le porte-avions tourne automatiquement face au vent pour atteindre la vitesse de vent sur pont souhaitée, maintient ce cap pendant la période de récupération, puis reprend sa route d'origine. Affiche les informations BRC, TACAN, ICLS et radio.

---

## Dépendances

- `veafRadio` — menu F10
- `veafAssets` — enregistre les ressources porte-avions (intégration optionnelle)

---

## Activation

```lua
veafCarrierOperations.initialize()
```

Puis enregistrer chaque porte-avions :

```lua
veafCarrierOperations.addCarrier({
  name        = "Mother",
  description = "CVN-73 Theodore Roosevelt",
  groupName   = "CVN-73",
})
```

Ou laisser `veafAssets` gérer l'enregistrement automatiquement quand une ressource porte-avions a `carrier = true`.

---

## Constantes de configuration clés

| Constante | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `veafCarrierOperations.MAX_OPERATIONS_DURATION` | `45` | Arrêt automatique après N minutes |
| `veafCarrierOperations.ALIGNMENT_MANOEUVER_SPEED` | 20 nœuds | Vitesse du porte-avions pendant le virage face au vent |
| `veafCarrierOperations.MIN_WINDSPEED_FOR_CHANGING_HEADING` | 4 nœuds | Vitesse de vent minimale justifiant un virage |
| `veafCarrierOperations.MIN_CARRIER_SPEED` | 4 nœuds | Vitesse minimale du porte-avions |
| `veafCarrierOperations.DisableSecurity` | `false` | Si vrai, tout le monde peut démarrer/arrêter une récupération |

---

## Types de porte-avions supportés

Le module connaît l'offset de pont incliné pour tous les porte-avions DCS standard :

| Type DCS | Offset pont incliné | Vent sur pont |
|----------|---------------------|---------------|
| `Stennis`, `CVN_71/72/73/75`, `Forrestal` | 9,05° | 25 nœuds |
| `KUZNECOW`, `CV_1143_5` | 9° | 25 nœuds |
| `LHA_Tarawa` | −1° (pont droit) | 20 nœuds |

---

## Menu radio F10 (par porte-avions)

- **Infos** — BRC, vent relatif, canal TACAN, canal ICLS, fréquence ATC
- **Commencer récupération** — virage face au vent et ouverture d'une fenêtre de 45 minutes
- **Arrêter récupération** — fin de récupération, reprise de la route d'origine

---

## Exemple de configuration

```lua
-- Dans missionconfig.lua
veafCarrierOperations.initialize()

-- Les porte-avions sont enregistrés via veafAssets :
veafAssets.Assets = {
  {
    name        = "Mother",
    description = "CVN-73 Theodore Roosevelt",
    groupName   = "CVN-73",
    information = true,
    carrier     = true,
  },
}
veafAssets.initialize()
```

---

## Voir aussi

- [veafAssets](veafAssets.md) — gestion des ressources et intégration menu radio
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafCarrierOperations`
