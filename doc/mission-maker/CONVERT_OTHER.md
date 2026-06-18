# `convert-other` — adopter une mission tierce sur la v6

`convert-other` adopte une mission `.miz` **tierce** (non-VEAF, p. ex. *Foothold*
de Lekaa) sur la chaîne d'outils v6. C'est le pendant de
[`convert-v5`](MIGRATION_GUIDE.md), qui migre une mission **VEAF v5** : ici la
mission n'a jamais été construite avec les outils VEAF, on l'**adopte**.

> Cette commande ne contient aucune connaissance propre à une mission donnée.
> Le savoir spécifique à une famille de missions (ordre des scripts, triggers à
> retirer, réglages à surcharger…) est porté par un *profil de conversion*
> (à venir). Voir l'ADR 0007.

## Usage

```bash
veaf-tools convert-other <mission.miz> <dossier-de-sortie>
```

Sans argument (dans un terminal interactif), la commande ouvre l'assistant TUI
et demande le `.miz` source puis le dossier de sortie.

| Argument / option | Rôle |
|-------------------|------|
| `INPUT_MIZ` | Chemin du `.miz` tiers à adopter |
| `OUTPUT_FOLDER` | Dossier de mission v6 à créer / compléter |
| `--force` | Écraser un `mission.yaml` existant (sinon il est laissé intact) |
| `--report-file` | Chemin du rapport Markdown (défaut `<sortie>/convert-other-report.md`) |

## Ce que fait la commande

1. **Extrait** le `.miz` dans le dossier de mission (les scripts atterrissent
   dans `src/scripts/`). Les copies tierces des scripts communautaires connus
   (CTLD, CSAR, AIEN…) sont **conservées** telles quelles (iso-fonctionnel), au
   lieu d'être remplacées par les versions VEAF.
2. **Détecte** les scripts chargés par les triggers natifs de la mission, dans
   leur **ordre de chargement** (ordre des triggers × ordre des actions).
3. **Génère** un `mission.yaml` *scaffold* :
   - un bloc `custom_scripts:` **ordonné** (l'ordre de chargement d'origine) ;
   - une liste `strip_native_triggers:` des triggers natifs de chargement
     détectés — le **build** les supprimera (lot ultérieur) pour éviter un
     double chargement ; `convert-other` ne fait que les recenser ;
   - tous les **modules VEAF désactivés** : activez ce dont la mission a besoin.
4. **Émet** un rapport Markdown récapitulant les actions et les points à revoir.

## Après la conversion

- Relisez le `mission.yaml` : activez les modules VEAF voulus, vérifiez l'ordre
  des `custom_scripts` et leurs dépendances.
- Construisez puis testez la mission dans DCS pour confirmer le comportement
  iso-fonctionnel.
