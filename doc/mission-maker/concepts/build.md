# Le build

## Ce que c'est {#what-it-is}

Une commande qui recompose le `.miz` depuis le dossier de mission. Elle fait toujours les mêmes
quatre choses, puis exécute les étapes optionnelles dont elle trouve le fichier.

> **Le `.\` est obligatoire.** Le terminal Windows par défaut est PowerShell, qui ne cherche pas
> dans le dossier courant — exprès. `cmd.exe` accepte les deux formes, donc `.\` marche partout.
> Voir [PowerShell ou invite de commandes ?](../GUIDE.md#powershell-vs-cmd).

```powershell
.\veaf-tools.exe build Ma-Mission.miz
```

1. lit `src/mission/` (la mission DCS décompressée) ;
2. génère `src/scripts/veaf-config.lua` depuis `mission.yaml`, et **annonce les modules
   qu'il y a lus** — avec leur nombre d'entrées pour ceux qui portent une liste, par exemple
   `COMBATZONE (1)` ; un module que vous venez d'ajouter et qui n'apparaît pas n'a pas été lu ;
3. **retire les déclencheurs VEAF existants**, puis en injecte de neufs qui chargent les scripts
   VEAF et les vôtres au démarrage ;
4. écrit le `.miz`.

Vous n'ajoutez **jamais** un déclencheur VEAF à la main dans l'éditeur DCS. Et comme l'étape 3
nettoie avant d'injecter, reconstruire dix fois de suite produit dix fois le même résultat.

## Les étapes du pipeline {#pipeline-steps}

Chacune s'exécute **si son fichier est présent**, dans cet ordre :

| Étape | Fichier | Fiche |
|---|---|---|
| `presets` | `src/presets.yaml` | [préréglages radio](radio-presets.md) |
| `spawnable_aircrafts` | `src/spawnables.yaml` | [groupes spawnables](spawnables.md) |
| `dynamic_slot_templates` | `src/dynamic-slot-templates.yaml` | [slots dynamiques](dynamic-slots.md) |
| `waypoints` | `src/waypoints.yaml` | — |
| `warehouses` | `src/warehouses.yaml` | [slots dynamiques](dynamic-slots.md) |
| `spawn_data` | `src/spawn-groups.yaml` | — |
| `weather` | `src/versions.yaml` | [variantes météo](weather-variants.md) |

Pour en couper une :

```yaml
pipeline:
  weather: false
```

## Vérifier avant de construire {#validate}

```powershell
.\veaf-tools.exe validate
```

Elle relit la configuration et la mission ensemble, et signale ce qui ne collera pas — une zone de
combat dont la trigger zone n'existe pas, des préréglages radio sans appareil joueur à qui les
appliquer. Elle sort en erreur s'il y a une erreur ; `--strict` la fait aussi sortir sur un simple
avertissement.

## Le nom du fichier produit {#output-name}

| Ce que vous tapez | Ce que vous obtenez |
|---|---|
| `build Ma-Mission.miz` | `Ma-Mission.miz` |
| `build Ma-Mission` (sans `.miz`) | `Ma-Mission_AAAAMMJJ.miz` — la date du jour est ajoutée |
| `build` (rien) | le nom vient de `mission.name` dans `mission.yaml` |

## Le piège {#gotcha}

**Un dossier fraîchement créé produit *deux* fichiers.** `src/versions.yaml` est livré avec une
variante « midi », donc l'étape météo s'exécute et écrit en plus `missions/Ma-Mission_noon.miz`.
Le fichier à la racine est la mission de base ; celui de `missions/` est la variante. Voir
[variantes météo](weather-variants.md).

## Pour aller plus loin {#more}

- [Référence Pipeline](../../PIPELINE_REFERENCE.md) — chaque étape en détail
- [Référence `mission.yaml` — `pipeline:`](../../MISSION_YAML_REFERENCE.md#pipeline) et [`profiles:`](../../MISSION_YAML_REFERENCE.md#profiles)
- [Référence CLI — `build`](../../CLI_REFERENCE.md#build) et [`validate`](../../CLI_REFERENCE.md#validate)
- [Guide complet — ce que fait le builder](../GUIDE.md)
