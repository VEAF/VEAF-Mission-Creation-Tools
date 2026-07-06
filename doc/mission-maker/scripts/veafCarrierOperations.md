# veafCarrierOperations — Gestion des récupérations sur porte-avions

**Module ID:** `CARRIER` | **Version:** 1.12.x | **Fichier:** `veafCarrierOperations.lua`

---

## Objectif

Gère les opérations de récupération sur porte-avions. Quand les joueurs déclenchent une récupération, le porte-avions tourne automatiquement face au vent pour atteindre la vitesse de vent sur pont souhaitée, maintient ce cap pendant la période de récupération, puis reprend sa route d'origine. Affiche les informations BRC, TACAN, ICLS et radio.

---

## Dépendances

- `veafRadio` — menu F10
- `veafRemote` — expose une commande distante `carrier`

---

## Activation

```lua
veafCarrierOperations.initialize()
```

Il n'existe pas d'API d'enregistrement par porte-avions. À l'`initialize()`, le module parcourt tous les groupes de la mission et enregistre automatiquement tout groupe contenant un type d'unité porte-avions connu (voir [Types de porte-avions supportés](#types-de-porte-avions-supportés)). Sa route initiale, son camp et ses données ATC (TACAN/ICLS/LINK4/ACLS/tour, lues dans les tâches programmées du porte-avions) sont capturés à ce moment-là. Il suffit de placer un groupe porte-avions dans l'éditeur de mission — aucun appel de script n'est nécessaire.

> Le module gère aussi deux groupes de soutien optionnels (hélicoptère de sauvetage et ravitailleur de récupération), eux aussi détectés par leur nom — voir [Pedro et ravitailleur S3B](#pedro-et-ravitailleur-s3b).

---

## Configuration (`mission.yaml`)

Les opérations de porte-avions sont activées via l'ID de module `CARRIER`. Les porte-avions eux-mêmes ne sont pas déclarés dans `mission.yaml` : ils sont détectés automatiquement à partir des groupes porte-avions présents dans la mission (voir [Activation](#activation)).

```yaml
modules:
  CARRIER:
    enabled: true          # défaut : true
    logLevel: info        # surcharge optionnelle du niveau de log
    init:
      include_carrier_operations_radio: true  # ajouter le menu carrier au F10 (défaut : true)
```

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `enable` | booléen | `true` | Non | Activer ou désactiver le module |
| `logLevel` | string | *(global)* | Non | Surcharge du niveau de log par module |
| `init.include_carrier_operations_radio` | booléen | `true` | Non | Ajouter le menu des opérations porte-avions au menu radio F10 |

### Exemple minimal

```yaml
modules:
  CARRIER:
    enabled: true
```

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

## Pedro et ravitailleur S3B

En plus du porte-avions lui-même, le module gère automatiquement deux groupes de soutien, détectés **par leur nom** — aucun appel de script, aucune entrée `mission.yaml`. Il suffit de les placer dans l'éditeur de mission en respectant la convention de nommage.

| Groupe | Nom attendu | Rôle | Positionnement automatique |
|--------|-------------|------|----------------------------|
| Pedro | `<nom unité porte-avions> Pedro` | Hélicoptère de sauvetage (SH-60B) | 250 ft, 1 nm sur tribord, accompagne le porte-avions à la même vitesse et au même cap |
| Ravitailleur S3B | `<nom unité porte-avions> S3B-Tanker` | Ravitailleur de récupération d'urgence (S-3B Tanker) | 8000 ft, 10 nm en arrière et 4 nm sur tribord, ravitaillement sur le BRC |

`<nom unité porte-avions>` est le nom de l'**unité** porte-avions (identique au nom du groupe pour un porte-avions seul dans son groupe, le cas courant). Exemple : pour une unité porte-avions nommée `CVN-73`, placez les groupes `CVN-73 Pedro` et `CVN-73 S3B-Tanker`.

Une fois nommés correctement, les deux groupes sont, à chaque cycle d'opérations :

- **détectés automatiquement** ;
- **respawnés** lorsqu'ils sont détruits ;
- **routés** automatiquement, leur trajectoire étant (re)calculée pour rester en formation avec le porte-avions.

Si un groupe est absent, le module l'ignore et journalise un avertissement — `No Pedro group named <nom>` ou `No Tanker group named <nom>` — sans bloquer les opérations.

---

## Menu radio F10

Le menu de premier niveau **CARRIER OPS** contient un sous-menu **CARRIER OPS - BLUE** et un sous-menu **CARRIER OPS - RED**, chacun avec un sous-menu par porte-avions (nommé d'après le groupe porte-avions). Lorsque les opérations sont arrêtées, chaque sous-menu de porte-avions propose :

- **Start carrier air operations for 45 minutes** — virage face au vent et ouverture d'une fenêtre de récupération de 45 minutes
- **Start carrier air operations for 90 minutes** — idem, pour 90 minutes (`MAX_OPERATIONS_DURATION` × 2)
- **ATC - Request informations** — TACAN, ICLS, LINK 4 / ACLS, tour, BRC et temps restant, plus la navigation courante et la météo

Pendant les opérations, les deux items *Start* sont remplacés par :

- **End air operations** — arrête la récupération et renvoie le porte-avions sur sa route initiale

> Par défaut les items *Start*/*End* sont sécurisés (mot de passe requis). Positionnez `veafCarrierOperations.DisableSecurity = true` pour les rendre accessibles à tous.

---

## Voir aussi

- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafCarrierOperations`
