# Lot REFACTOR-SERVER-HOOK-CANONICAL — hook serveur = source déployable unique

Status: ✅ done
Branch: fix/refactor-server-hook-canonical → PR → develop

## Problem Statement

Les 6 serveurs VEAF (`foothold1/2`, `private1/2`, `public1/2`) tournent une **variante
allégée, éditée à la main** de `VEAF-Server-hook.lua` (v2.5.0) qui **diverge du repo VMCT** :
BufferingSocket retiré, autorestart interne commenté, chemin du fichier pilotes mutualisé.
Aucun pipeline ne déploie le hook (copie manuelle) → le repo n'est pas la source réellement
déployée, et un copier-coller depuis le repo réintroduirait des fonctions non voulues (dont
un `require('BufferingSocket')` **en dur** qui **crashe le hook au chargement** si le module
natif est absent — pénalisant tout utilisateur public du repo, pas seulement VEAF).

Le callback chat a déjà été corrigé (`onPlayerTrySendChat`, lot FIX-SERVERHOOK-CHAT-SIM-LOGGER,
#590). Ce lot supprime la divergence restante.

## Solution

Faire du hook du repo une **source unique paramétrable** dont les **défauts reproduisent le
comportement de prod** (features VEAF OFF par défaut), activables depuis le
`VEAF-specific-server-hook.lua` (chargé après, per-serveur). **On ne supprime rien — on rend
configurable** (décision David).

- **`enableBufferingSocket`** (OFF) : le `require` BufferingSocket en dur (+ `package.path`)
  devient un chargement **`pcall` opt-in** dans `setupBufferingSocket()`, appelé depuis
  `onSimulationStart`. Si demandé mais introuvable → auto-désactivation propre, pas de crash.
- **`enableAutoRestart`** (OFF) : `stopMissionIfNeeded` (watchdog idle/uptime, sur
  `onPlayerDisconnect` + `onSimulationFrame`) et les commandes chat `restart` / `restartnow` /
  `halt` sont gated par ce flag. `haltnow`, `pause`, `send`, `code` et la branche générique
  restent inconditionnels.
- **`pilotsDir`** (nil → `VEAF_SERVER_DIR`) : chemin du `veaf-pilots.txt` surchargé par le
  specific-hook (prod VEAF le mutualise un cran au-dessus).
- Bump `veafServerHook.Version` → 2.7.0. En-tête réécrit (features opt-in, specific-hook,
  nom correct `veaf-pilots.txt`).

Résultat : le hook du repo = ce qui tourne (comportement par défaut) ; les configs VEAF vivent
dans le specific-hook ; déployer devient un copier-coller pur.

## Validation

`src/scripts/Hooks/` est hors périmètre des gates CI luacheck/stylua (qui ne couvrent que
`src/scripts/veaf/`) — pas de reformatage du fichier legacy (RULE N°1). Le hook tourne dans
l'environnement GameGUI (`Sim`/`net`/`log`) non couvert par le harnais luaunit. Validation :

- **`luac -p`** : syntaxe Lua 5.1 OK.
- **Smoke test** (mocks `lfs`/`Sim`/`log`/`net`, hors harnais) : le hook se charge **sans**
  BufferingSocket ; flags OFF par défaut ; `setupBufferingSocket()` no-op quand OFF et
  auto-désactivation propre quand ON mais module absent.
- **En jeu** (volet 2) : `/send` visible, `/secu login` déverrouille, `VEAFHOOK ... ran command`
  apparaît dans `dcs.log`.

## Out of scope

- Déploiement sur les 6 serveurs (volet 2 du plan) : édition du clone `VEAF-Servers`, exécuté
  par David (push + prod + reload).
- Mise à jour de la copie figée `VEAF-Servers-Public` (v2.1.0) : volet 4, optionnel.

## Tickets

1. `01-configurable-hook.md` — rendre BufferingSocket/autorestart/pilotsDir configurables.
2. `02-admin-doc.md` — doc admin d'installation/mise à jour du hook serveur.

---

## 01 — Rendre le hook configurable (BufferingSocket / autorestart / pilotsDir)

Status: ✅ done

### Change (`src/scripts/Hooks/VEAF-Server-hook.lua`)

- New flags OFF by default: `enableBufferingSocket`, `enableAutoRestart`; new `pilotsDir` (nil).
- BufferingSocket: remove the top-level `require` (+ `package.path`/`cpath`, `config` require);
  load it defensively (`pcall`) in a new `setupBufferingSocket()` called from `onSimulationStart`,
  only when `enableBufferingSocket`; auto-disable + log if the module cannot be loaded.
- Autorestart: gate `stopMissionIfNeeded` (on `onPlayerDisconnect` + `onSimulationFrame`) and the
  `restart`/`restartnow`/`halt` chat commands on `enableAutoRestart`. Keep `haltnow`/`pause`/`send`/
  `code`/generic branch unconditional.
- Pilots path: `loadPilots` uses `(veafServerHook.pilotsDir or VEAF_SERVER_DIR)`.
- Bump `Version` → 2.7.0; header updated (opt-in features, specific-hook, `veaf-pilots.txt`).

### Validation

- `luac -p src/scripts/Hooks/VEAF-Server-hook.lua` → OK.
- Smoke test (mocks, hors harnais) : chargement sans BufferingSocket, flags OFF, `setupBufferingSocket`
  no-op quand OFF / dégradation propre si module absent. All green.
- Non-régression : `poetry run test-lua` (le hook n'est pas dans le harnais ; confirme l'absence
  d'effet de bord).

### Done when

- Flags en place, comportements gated, syntaxe + smoke test verts.
- Le hook charge sans BufferingSocket présent (bug du repo public corrigé).

---

## 02 — Doc admin : installation / mise à jour du hook serveur

Status: ✅ done

### Context

Aucune doc n'explique aux admins serveur comment installer/mettre à jour le hook. La seule
« doc » était l'en-tête du fichier. Manque identifié pendant le plan de déploiement flotte.

### Change

Nouvelle page `doc/mission-maker/scripts/veafServerHook.md` (aligne sur les autres pages
`doc/mission-maker/scripts/*.md`) :

- rôle du hook (commandes chat serveur, liste des pilotes, features opt-in) ;
- installation : déposer `VEAF-Server-hook.lua` + `veaf-pilots.txt` dans
  `Saved Games/<serveur>/Scripts/Hooks/` ; ordre de chargement (alphabétique) vs specific-hook ;
- le `VEAF-specific-server-hook.lua` : `serverName`, `serverBotChannel`, et les nouveaux
  `enableAutoRestart` / `enableBufferingSocket` / `pilotsDir` ;
- format `veaf-pilots.txt` (UCID → level) et la grille de niveaux (0/1/10/30/50/90/99) ;
- mise à jour : remplacer le fichier puis **redémarrer le serveur** (hook chargé au boot).

### Done when

- Page créée, liée depuis l'index doc si pertinent.
- CHANGELOG `[Unreleased]` mis à jour.
