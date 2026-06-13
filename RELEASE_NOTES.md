# VEAF Mission Creation Tools — 6.5.0

Cette version sort les données VEAF du Lua maintenu à la main vers du **YAML généré au build**, ajoute les **Dynamic Slots** DCS, **localise les messages en jeu**, et embarque un **assistant de documentation** — accompagné d'un large lot de corrections build et runtime.

## ✨ Nouveautés

- **Base de spawn en YAML** — les définitions d'unités/groupes de `_spawn` vivent désormais en YAML, injectées dans le `.miz` au build. Extensible/surchargeable via un `src/spawn-groups.yaml` optionnel (plus de Lua à éditer).
- **Warehouses Dynamic-Slot** — un nouveau `src/warehouses.yaml` configure les Dynamic Slots DCS par coalition (aéroports, carburant/munitions/stock, et le modèle `dynSpawnTemplate` qui fournit emport/livrée/route).
- **Localisation en jeu (FR/EN)** — les messages pilote VEAF sont traduits ; la langue suit `mission.language`, sinon celle des outils (les logs restent en anglais).
- **Assistant de documentation** — posez une question à la doc VEAF et obtenez une réponse sourcée, dans la barre latérale du site **et** en CLI : `veaf-tools ask "comment activer CTLD ?"` (sans clé API).
- **Données DCS issues du datamine** — unités, pays, aérodromes et specs radio régénérés de façon reproductible via `veaf-build update-dcs-data`, sans installation DCS.
- **Plus de groupes sol bleu+rouge obligatoires** — le build ajoute une unité placeholder cachée à une coalition vide pour que DCS enregistre le camp.
- **Détection automatique de l'ère** — `build` déduit `WW2`/`COLD_WAR`/`MODERN` quand `mission.era` n'est pas défini (une valeur manuelle gagne).
- **Défauts plus malins** — un `mission.yaml` neuf active une baseline VEAF (menu F10, spawn, raccourcis, CAS/transport à la demande…) : une nouvelle mission marche d'emblée.

## 🔧 Corrections notables

- **Chargement dynamique des scripts** fiable en DEV et PROD ; plusieurs bugs du mode dynamique corrigés (modules initialisés deux fois → effets dupliqués, scripts non chargés, `_spawn` non enregistré).
- **Presets radio** : la mission se sauve toujours (fini « Invalid frequency ») — les fréquences hors plage d'un appareil sont retirées au lieu de casser la sauvegarde.
- **Injection de waypoints** : le décollage et un waypoint à heure verrouillée sont préservés → fini « flight delayed to start » / « no waypoints with locked time ».
- **Injection d'avions** d'un pays absent de la mission source : plus de crash du Mission Editor.
- **UX spawn** : un paramètre marqueur mal orthographié est signalé au pilote (« vouliez-vous dire… ? ») et la commande est annulée au lieu de spawner n'importe quoi.
- **`convert-v5`** : préserve les éléments v5 commentés, les presets radio sur-mesure et `silenceAtc`, avec un rapport plus clair.

## ⚠️ Rupture — templates avions

L'injection des groupes avions est scindée en deux étapes : **avions spawnables** (`src/spawnables.yaml`) et **templates Dynamic-Slot** (`src/dynamic-slot-templates.yaml`). Les anciens `aircraft-templates.yaml` / `templates.yaml` ne sont **plus injectés** — régénérez-les avec `extract-aircraft-groups` (le build prévient s'il trouve les anciens fichiers).

## 🔒 Sécurité

Le parseur `.miz` n'exécute plus de Lua embarqué (parseur pur-Python) — ouvrir/convertir une mission ne peut plus exécuter de code arbitraire. Extraction d'archives durcie et parsing `.miz` ~2,6× plus rapide.

## 🙏 Remerciements

Merci à **Flogas** et **Tripack** pour les tests et retours.

---

La liste complète et détaillée des changements est dans le [CHANGELOG](CHANGELOG.md).
