# VEAF Mission Creation Tools — v6.3.4

**Version de consolidation** — corrections, clarté des erreurs, et enrichissement de la documentation.

Un grand merci à **Flogas** pour ses tests approfondis et ses retours précieux qui ont contribué à la qualité de cette version.

---

## Nouveautés

### Scripts Lua personnalisés dans `mission.yaml`

Il est désormais possible de déclarer des scripts Lua personnalisés situés dans `src/scripts/` via la nouvelle section `custom_scripts` de `mission.yaml`. Chaque script peut désactiver la génération automatique du trigger de chargement DCS avec `generate_load_trigger: false`.

---

## Corrections

- **Erreurs YAML** : si `mission.yaml` contient une erreur de syntaxe, l'outil affiche maintenant un message clair indiquant le fichier, la ligne, la colonne et une explication en langage naturel — plus de crash Python cryptique.
- **Modules obligatoires** : spécifier `enable: true/false` sur un module Lua obligatoire (`UNITS`, `TIME`, `CACHE`…) lève désormais une erreur explicite au lieu d'être silencieusement ignoré.

---

## Documentation

- **Nouvelle URL** : la documentation est maintenant publiée sur [veaf.github.io/documentation/](https://veaf.github.io/documentation/). Mettez à jour vos favoris.
- **Français par défaut** : le français est désormais la langue principale de la documentation ; l'anglais reste disponible en langue secondaire.
- **Nouvelle section** dans la référence `MISSION_YAML_REFERENCE` : explication des erreurs de syntaxe YAML et leurs causes courantes.
- **Pages enrichies** : Skynet IADS Helper, QRA Manager, Combat Zone, Radio, Weather — contenus corrigés et complétés.

---

## Retraits

- La commande `convert` a été supprimée. Elle était non fonctionnelle sur les missions v6. Le flux `extract` suivi de `build` couvre entièrement son usage.

---

*VEAF Mission Creation Tools est un projet communautaire open-source. Contributions et retours bienvenus sur [GitHub](https://github.com/VEAF/VEAF-Mission-Creation-Tools).*
