# VEAF Mission Creation Tools — 6.7.7

Version **de fiabilité**, centrée sur deux retours de **Tripack**. Le build accepte désormais les avions dont la radio principale est en HF (comme le MiG-15bis), et la commande `prepare` génère un `mission.yaml` aussi complet que celui d'une conversion `convert-v5`. Aucun changement de configuration : les missions existantes n'ont rien à modifier.

## 🐛 Corrections

- **Le build ne rejette plus à tort le MiG-15bis** — après édition d'une mission contenant un MiG-15bis dans l'éditeur DCS puis ré-extraction, le build échouait avec *« Fréquence radio principale invalide (sous 30.0 MHz) »*. Le garde-fou interdisait toute fréquence principale sous 30 MHz (pour empêcher qu'un canal ADF, type Yak-52 ARK-15M à 0.625 MHz, ne devienne la radio principale). Mais le MiG-15bis a légitimement une radio HF (la RSI-6K, 3.75–5.0 MHz) que DCS écrit et accepte lui-même. La validation tient désormais compte des caractéristiques réelles de chaque avion : la fréquence HF du MiG-15bis passe, la protection contre les canaux ADF reste en place.

## 🛠️ Outillage mission-maker

- **`prepare` génère un `mission.yaml` complet** — quel que soit le template choisi (`minimal` / `standard` / `full` / `custom`), le fichier produit inclut maintenant le même préambule documenté qu'une conversion `convert-v5` : guide de syntaxe YAML, `global_log_level`, bloc `mission:` complet, `security:` et `pipeline:`. Plus besoin de partir d'une conversion v5 pour récupérer ces sections. Le bloc `modules:`, lui, reste adapté au template choisi.

## 🙏 Remerciements

Merci à **Tripack** pour le signalement des deux sujets et la fourniture des dossiers de mission qui ont permis de reproduire et corriger précisément chaque cas.
