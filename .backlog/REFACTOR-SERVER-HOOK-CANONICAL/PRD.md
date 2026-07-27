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
