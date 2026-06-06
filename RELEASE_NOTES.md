# VEAF Mission Creation Tools — Notes de version v6.3.3

> Date de publication : 2026-06-06

## Vue d'ensemble

La version 6.3.3 est une version de stabilisation et de correction de bugs. Aucun changement incompatible.

---

## Corrections de bugs

### Corrections runtime Lua

- **`initialize()` manquant sur plusieurs modules** — `veafCacheManager`, `veafTime`,
  `veafUnits` et `veafSkynetIadsMonitor` ne disposaient pas de leur fonction
  `initialize()`. Comme `veaf-config.lua` appelle `<module>.initialize()` sur
  chaque module listé, leur absence provoquait un crash DCS au démarrage :
  `attempt to call field 'initialize' (a nil value)`.

### Corrections du pipeline de build

- **Erreur de syntaxe Lua sur les champs d'assets avec caractères spéciaux** —
  les champs `description`, `name` et `information` contenant des sauts de ligne
  (`\n`) ou des guillemets (`"`) utilisent désormais la syntaxe Lua longue
  (`[[...]]`), évitant une erreur de syntaxe au chargement de la mission.

- **`versions.yaml` n'est plus écrasé quand `missions.yaml` existe** — le
  builder ne copie plus le `versions.yaml` par défaut si un `missions.yaml`
  legacy est déjà présent dans `src/` ; un avertissement est émis à la place.

- **Nom du fichier de backup `v5_converter` corrigé** — la sauvegarde de
  migration utilise désormais `missionConfig.lua` (cohérent avec tous les autres
  fichiers de backup dans `backup_v5/`).

- **`presets.md` n'est plus créé silencieusement** — ce fichier a été retiré
  des defaults ; il était copié dans les dossiers mission sans utilité.

- **Avertissement quand `aircraft-templates.yaml` existe mais que l'étape de
-  pipeline est désactivée** — la commande build avertit désormais dans ce cas.

---

## Améliorations

### Pipeline de build

- **Avertissement sur les fichiers `.lua` inattendus dans `src/scripts/`** — le
  builder signale les fichiers `.lua` qui ressemblent à des résidus v5 ; ceux-ci
  seraient chargés comme scripts de mission DCS et pourraient entrer en conflit
  avec le `veaf-scripts.lua` fourni.

- **Profils de build (`--profile`)** — nouvelle option `--profile` / `-p` sur
  `veaf-tools build` permettant de sélectionner un profil nommé défini dans
  `mission.yaml`. Les profils fusionnent en profondeur sur la config de base
  (les listes sont remplacées, pas concaténées). Des exemples (`TEST`, `SERVER`)
  sont inclus dans le template `mission.yaml` par défaut.

- **`.gitignore` auto-généré** — `veaf-tools prepare` copie désormais un
  template `.gitignore` dans le dossier mission s'il est absent ; il n'est
  jamais écrasé (même avec `--force`) pour préserver les personnalisations.

- **Configuration YAML-first pour CSAR** — `external_modules.csar` dans
  `mission.yaml` génère désormais le bloc de configuration CSAR complet dans
  `veaf-config.lua`, de façon symétrique au support CTLD existant.

- **Bloc CTLD protégé et auto-initialisé** — le bloc CTLD dans `veaf-config.lua`
  est maintenant encadré par `if ctld then … end` et inclut `ctld.initialize()`
  automatiquement ; plus besoin d'appel manuel dans `mission-script.lua`.

- **Modules obligatoires protégés** — les modules Infrastructure (UNITS, TIME,
  CACHE, EVENTS, MARKERS, COMMANDS) sont désormais marqués obligatoires ; s'ils
  sont désactivés dans `mission.yaml`, un avertissement est émis et le flag est
  ignoré.

- **Résolution automatique des dépendances** — les dépendances manquantes ou
  désactivées sont auto-activées au moment du build avec un avertissement par
  module ajouté ; les chaînes transitives sont entièrement résolues sans
  modifier aucun fichier sur le disque.

- **Catégories de modules dans `veaf-config.lua`** — les fichiers de config
  générés incluent désormais des en-têtes de catégorie (Infrastructure, Core,
  Features, Combat, External) pour une meilleure lisibilité.

### Documentation

- **Profils de build** documentés dans le Guide Mission Maker et
  `MISSION_YAML_REFERENCE.md`.

- **Mode développeur** (`dev_mode` / `scripts_path`) documenté dans le Guide
  Développeur et `MISSION_YAML_REFERENCE.md`.

- **Configuration YAML-first CSAR** documentée dans le Guide Mission Maker.

---

## Full Changelog

See [CHANGELOG.md](CHANGELOG.md) for the complete list of changes.
