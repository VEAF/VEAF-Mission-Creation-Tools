# VEAF Mission Creation Tools — 6.6.1

Version de **correctifs** dans la lignée de la 6.6.0 : elle complète l'assistant interactif et répare l'injection des slots dynamiques. Aucun changement cassant — une mission existante se reconstruit sans modification.

## 🐛 Corrections

- **Toutes les commandes sont accessibles depuis l'assistant interactif (TUI)** — `validate`, `migrate-config`, `generate-config` et `user-config` manquaient au menu : on ne pouvait pas les lancer en double-cliquant sur `veaf-tools.exe`. Elles y figurent désormais (et `migrate-config` ouvre l'assistant quand son fichier d'entrée n'est pas fourni).
- **Plus de plantage à l'injection des templates de slots dynamiques** — sur une mission fraîchement extraite (`extract`), l'injection échouait pour **tous** les templates avec `'dict' object has no attribute 'append'` quand le conteneur de groupes du pays cible était vide. Le build injecte désormais correctement les slots dynamiques.

## 🙏 Remerciements

Merci à **Tripack** pour le signalement et la mission de test (`test-tripack`) qui ont permis de reproduire le bug d'injection.
