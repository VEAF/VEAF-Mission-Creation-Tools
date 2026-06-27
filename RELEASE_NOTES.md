# VEAF Mission Creation Tools — 6.7.0

Version **mineure** centrée sur l'**ouverture des missions à l'outillage externe** : `veaf-tools` sait désormais lire un `.miz` et l'exporter **sans jamais exécuter de Lua** — en JSON pour les outils d'analyse (scripts, assistants IA), en Markdown pour une lecture humaine. Elle rend par ailleurs la **migration v6 définitive sur disque**, et corrige plusieurs bugs de slots dynamiques et de l'assistant interactif.

> ⚠️ **À lire avant de relancer `convert-v5`** — voir la section *Changement de comportement* plus bas.

## ✨ Nouveautés

### Exporter une mission, sans risque, dans le format qu'il vous faut

La nouvelle commande `veaf-tools export <mission>` lit un `.miz` (ou un dossier de mission extrait) et le restitue dans trois formats :

- **JSON** *(défaut)* — la structure complète de la mission, pensée pour l'**outillage** : scripts d'analyse et assistants IA. Le contrat JSON est **figé et versionné** (`schemaVersion 2`) et préserve fidèlement les tables Lua (tableaux, objets, clés mixtes) pour un décodage sans perte. `--compact` pour une sortie dense.
- **Markdown** — un **briefing lisible** : vue d'ensemble, ordre de bataille par coalition, zones de déclenchement, logique de mission (triggers VEAF vs. triggers mission), scripts chargés. Idéal pour documenter ou relire une mission d'un coup d'œil.
- **YAML** — le même objet structuré, en plus lisible.

Le point clé : **aucune exécution de Lua**. Un `.miz` est un ZIP dont le fichier `mission` est de la *donnée* ; l'interpréter avec un moteur Lua (comme le font certains outils tiers) exécuterait n'importe quel Lua piégé dans un `.miz` forgé — un risque d'exécution de code. `export` lit la mission avec notre parseur **100 % Python** (un test de garde vérifie qu'aucun `subprocess`/`lupa`/`eval`/`exec` n'est appelé sur ce chemin). Pour un `.miz`, l'option `--extract-dir` extrait en plus les ressources embarquées (scripts, sons, images) de façon durcie. La commande est aussi disponible depuis l'assistant interactif (TUI).

## 🐛 Corrections

- **Les templates d'avions de slots dynamiques ne sont plus rangés sous « hélicoptères »** — DCS stocke tous les groupes-templates de slots dynamiques dans la table hélicoptère du `.miz`, quel que soit l'appareil ; l'extraction classait donc **tous** les templates avions (A-10C II, F-16, MiG…) comme hélicoptères, et ils étaient ré-injectés dans l'éditeur en « GROUPE D'HÉLICOPTÈRES » avec le mauvais type. La catégorisation se fait désormais sur la **vraie catégorie DCS** de l'appareil. Le `dynamic-slot-templates.yaml` par défaut a été régénéré (78 templates avions déplacés).
- **Toutes les commandes sont accessibles depuis l'assistant interactif (TUI)** — `validate`, `migrate-config`, `generate-config` et `user-config` manquaient au menu ; on ne pouvait pas les lancer en double-cliquant sur `veaf-tools.exe`. Elles y figurent désormais.
- **Plus de plantage à l'injection des slots dynamiques** — sur une mission fraîchement extraite, l'injection échouait pour **tous** les templates (`'dict' object has no attribute 'append'`) quand le conteneur de groupes du pays cible était vide. Corrigé.

## ⚠️ Changement de comportement — `convert-v5` promeut maintenant la mission en v6 sur disque

Jusqu'ici, `convert-v5` migrait la config v5→v6 mais laissait la mission éclatée (`src/mission/`) en v5 ; la migration des triggers était refaite **en mémoire à chaque build**. Désormais, `convert-v5` **termine par une étape de promotion** : il construit une base, migre les triggers v5, **sauvegarde `src/mission/` dans `backup_v5/`**, puis réécrit `src/mission/` à partir du `.miz` v6 fraîchement construit. Le passage en v6 devient **définitif**.

Ce qu'il faut savoir :

- Tout le contenu éditeur (groupes, routes, unités, données injectées) est **préservé** ; seule la couche de triggers v5 est purgée.
- L'étape est **active par défaut**, **non bloquante** (en cas d'échec, vos configs converties restent intactes, avec restauration de `src/mission/` depuis la sauvegarde) et **désactivable** via `--no-promote`.
- Une copie de l'ancienne mission v5 reste disponible sous `backup_v5/`.

Une mission existante se reconstruit sans modification de votre part — mais si vous relancez `convert-v5`, attendez-vous à voir `src/mission/` réécrit en v6 et un dossier `backup_v5/` créé.

## 🙏 Remerciements

- **Dup** — pour la définition du contrat JSON d'export.
- **Tripack** — pour les missions de test ayant permis de reproduire les bugs de slots dynamiques et d'injection.
