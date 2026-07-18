# 02 — Doc admin : installation / mise à jour du hook serveur

Status: ✅ done

## Context

Aucune doc n'explique aux admins serveur comment installer/mettre à jour le hook. La seule
« doc » était l'en-tête du fichier. Manque identifié pendant le plan de déploiement flotte.

## Change

Nouvelle page `doc/mission-maker/scripts/veafServerHook.md` (aligne sur les autres pages
`doc/mission-maker/scripts/*.md`) :

- rôle du hook (commandes chat serveur, liste des pilotes, features opt-in) ;
- installation : déposer `VEAF-Server-hook.lua` + `veaf-pilots.txt` dans
  `Saved Games/<serveur>/Scripts/Hooks/` ; ordre de chargement (alphabétique) vs specific-hook ;
- le `VEAF-specific-server-hook.lua` : `serverName`, `serverBotChannel`, et les nouveaux
  `enableAutoRestart` / `enableBufferingSocket` / `pilotsDir` ;
- format `veaf-pilots.txt` (UCID → level) et la grille de niveaux (0/1/10/30/50/90/99) ;
- mise à jour : remplacer le fichier puis **redémarrer le serveur** (hook chargé au boot).

## Done when

- Page créée, liée depuis l'index doc si pertinent.
- CHANGELOG `[Unreleased]` mis à jour.
