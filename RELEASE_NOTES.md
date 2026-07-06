# VEAF Mission Creation Tools — 6.8.0

Version centrée sur les **presets radio**. Vous déclarez vos listes de canaux **une seule fois** et l'outil les projette automatiquement sur les radios de chaque appareil — avec des fréquences enfin **lisibles** (noms d'aérodromes et d'indicatifs au lieu de MHz bruts). Cette version ajoute aussi la possibilité de créer des **menus radio F10 sur mesure directement en YAML**, sans écrire de Lua. Encore une fois, largement nourrie par les retours de **Tripack**.

## 🎛️ Presets radio — le nouveau modèle « plan »

- **Déclarez vos canaux une fois, l'outil s'occupe du reste.** Un bloc `channel_lists` (par rôle radio et coalition) dans `presets.yaml` est projeté automatiquement sur les radios physiques de chaque avion — y compris les cas retors : A-10 (VHF en radio 1), F/A-18 (deux radios identiques), Mi-24P (canal 0), OH-58D (pas de canal 1), AJS-37, CH-47F, et les warbirds. Plus besoin d'un préréglage par appareil pour le cas courant.
- **Fréquences lisibles.** `convert-v5` remplace les fréquences en dur par des **noms** : aérodromes du théâtre (`Gudauta`, `Batumi`…) et indicatifs VEAF (`Guard`, `Archer`, `Texaco-1`…). Une fréquence sans nom connu reste en clair.
- **`convert-v5` génère un plan simplifié par défaut**, plus une copie fidèle `presets.v5.yaml` (référence / repli, non chargée par le build).

📖 Doc : [Pipeline Reference — presets radio](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/doc/PIPELINE_REFERENCE.md)

## 📻 Menus radio F10 en YAML (sans Lua)

Créez des menus F10 sur mesure directement dans `mission.yaml` : démarrer / arrêter une QRA ou une AirWave, basculer un drapeau, afficher un message, ou appeler votre propre fonction Lua — via `modules.RADIO.user_menus` ou le raccourci `radio_menu: true` sur une QRA / AirWave. Menus réservables à un groupe précis (Mission Master).

📖 Doc : [veafRadio — Menus radio en YAML](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/doc/mission-maker/scripts/veafRadio.md#menus-radio-en-yaml) · [MISSION_YAML_REFERENCE](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/doc/MISSION_YAML_REFERENCE.md)

## 🎚️ Désactiver les planchettes (kneeboards)

`pipeline.presets` accepte désormais `{enabled: true, kneeboards: false}` : garder l'injection des fréquences radio **sans** générer les images de kneeboard.

📖 Doc : [GUIDE — Configurer le pipeline de build](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop-v6/doc/mission-maker/GUIDE.md#configuring-pipeline)

## 🐛 Corrections

- **`convert-v5` convertit à nouveau les presets radio dans l'exécutable** — un fichier de données radio n'était pas embarqué dans l'`.exe`.
- **Sortie `presets.yaml` nettoyée** — numéros de canaux cohérents (entiers) et en-tête explicatif en tête de fichier.
- **CH-47F** — sa radio FM n'est plus prise pour une VHF.

## ⚠️ À vérifier (mission makers)

- Les anciens formats de presets restent **entièrement supportés** — aucune migration forcée. Mais `convert-v5` produit maintenant un plan simplifié par défaut : pour quelques appareils (warbirds, jets à radios fusionnées), les fréquences projetées peuvent diverger « au mieux » de votre v5 d'origine — un avertissement le signale, et `presets.v5.yaml` conserve la version fidèle en repli.
- La forme de `presets.yaml` change (noms au lieu de MHz, clés numériques) — à revérifier si un script externe le lisait.

## 🙏 Remerciements

Merci à **Tripack**, dont les retours et les missions réelles sont à l'origine de la plupart de ces améliorations (presets radio, menus F10, kneeboards).
