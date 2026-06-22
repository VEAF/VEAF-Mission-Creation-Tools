# VEAF Mission Creation Tools — 6.6.0

Cette version est une étape de **consolidation et d'améliorations** : elle ouvre l'outillage v6 à l'**adoption de missions tierces** (campagnes Foothold), enrichit la **boîte à outils des mission makers** (validation avant build, gabarits de modules, assistant interactif), et corrige un large lot de problèmes remontés en test — notamment autour de `convert-v5`, des slots dynamiques et des zones de combat.

> Pas de changement cassant : une mission v6 existante se reconstruit sans modification.

## 🆕 Adopter une mission tierce (non-VEAF) sur l'outillage v6

Tout un écosystème pour reprendre une mission externe (pilote : la campagne Foothold de Lekaa) :

- **`veaf-tools convert-other`** — adopte un `.miz` tiers : extraction, détection des scripts chargés par les triggers natifs, génération d'un `mission.yaml` avec un bloc `custom_scripts:` ordonné (ordre de chargement préservé).
- **Profils de conversion (`--profile`)** — le profil `foothold` active les bons modules VEAF, normalise les noms de scripts versionnés (`Moose_2026-xx-xx.lua` → `Moose.lua`), désactive automatiquement les libs communautaires fournies par la mission (Moose, CTLD, AIEN…), et signale les modules incompatibles.
- **`config_override:`** — ne réécris que les globales Lua que tu changes (validées lexicalement), sans toucher la config amont d'origine.
- **`strip_native_triggers:`** — le build retire les triggers de chargement natifs de la mission pour éviter le double chargement.
- **`convert-other --update`** — réimporte une nouvelle version amont du `.miz` en préservant ton `mission.yaml` réglé, et rapporte les scripts ajoutés/modifiés/retirés.
- **Build multi-variant** — un même dossier produit plusieurs `.miz` en un seul `build` (ex. Modern / Cold-War) via `build_variants:`.

## 🛠️ Nouveaux outils pour les mission makers

- **`veaf-tools validate`** — un *linter* qui vérifie un dossier de mission **avant** le build (syntaxe `mission.yaml`, modules, scripts déclarés, groupes/zones référencés) et regroupe tous les problèmes en une passe.
- **Validation des références au build** — le `build` signale désormais, dans un **récapitulatif bien visible en fin de build** (sans bloquer), toute référence de `mission.yaml` vers un objet du Mission Editor introuvable (zones de déclenchement, groupes, unités, aérodromes).
- **`prepare --template`** — échafaude un `mission.yaml` à partir d'un gabarit de modules (`minimal` / `standard` / `full` / `custom` interactif).
- **Pont CLI ↔ TUI** — n'importe quelle commande bascule dans l'assistant interactif si un paramètre requis manque (ou avec `--tui`), avec navigation arrière (Ctrl-B).
- **`veaf-build publish-local <dir>`** — déploie un build dans un dossier de mission local pour tester l'outillage sans passer par GitHub.

## ✨ Fonctionnalités de mission

- **`active_at_start: true`** — active une zone de combat dès le début de la mission depuis `mission.yaml` (retrouve en déclaratif ce qui s'écrivait à la main en Lua).
- **`radiobeep.ogg`** — le bip JTAC de secours est maintenant fourni et injecté automatiquement quand CTLD est activé.

## 🐛 Corrections notables

- **AirWaves** — une zone définie par centre + rayon avec une `trigger_zone_name` absente ne déclenche plus une ERREUR en jeu (avertissement seulement ; la zone fonctionne via centre/rayon). Et la config AirWaves générée ne fait plus planter la mission au démarrage.
- **`convert-v5`** — extrait correctement les **sous-zones d'une opération de combat** (gori) et résout leurs références ; n'émet plus de modules/QRA fantômes depuis de la config commentée ; ne produit plus de `mission.yaml` inparsable quand une QRA était désactivée en v5.
- **Slots dynamiques / templates** — les avions ne sont plus rangés sous la catégorie *hélicoptère* (50 templates CAP par défaut **et** templates de slots dynamiques) ; une radio ADF/kHz (Yak-52 ARK-15M) ne corrompt plus la fréquence principale du slot (*« Fréquence invalide 0.625 MHz »*) ; les templates injectés par l'outil ne polluent plus la liste des slots multijoueur.
- **`cap_missions`** — plus de fausse alerte « groupe manquant » : la validation tient compte du préfixe `OnDemand-`.
- **Intégration des libs communautaires** — VEAF n'applique plus son intégration à une lib que la mission a désactivée (cas du maker qui fournit sa propre version).
- **`custom_scripts:`** — l'ordre de déclaration est désormais réellement respecté à l'exécution.
- **Cartes** — table des aérodromes mise à jour pour l'extension de la carte Syrie ; gabarit AFAC MQ-9 restauré dans les `spawnables.yaml` par défaut.

## 🔧 Changements

- **`TUM` (The Universal Mission)** est désormais **opt-in** et auto-initialisé quand il est activé.

## 📚 Documentation

- Réécriture en profondeur des pages de scripts/API pour coller au vrai code Lua v6 (suppression d'API inexistantes), parité FR/EN, et guides dédiés à l'adoption Foothold.

## 🙏 Remerciements

Un grand merci à **Tripack** pour ses retours de test approfondis sur la VEAF-Demo-Mission, à l'origine d'une grande partie des correctifs de cette version.
