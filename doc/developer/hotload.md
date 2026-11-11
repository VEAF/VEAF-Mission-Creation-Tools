# Scripts en direct avec dcs-hotload

[dcs-hotload](https://github.com/MacFlorent/dcs-hotload) exécute du Lua dans une mission DCS **qui tourne**, sans la redémarrer.
Le script est relu sur le disque à chaque exécution : on modifie le fichier, on relance, on voit le résultat.
Il se lance de deux façons :

- **depuis le menu F10** : chaque fichier de `user-f10/` devient une commande du menu ;
- **depuis une boîte aux lettres** : un fichier `.lua` déposé dans `user-inbox/` s'exécute une fois, et son résultat est écrit dans `user-outbox/`. Un éditeur, un terminal ou un agent peut ainsi piloter la mission.

Il n'ouvre aucun port réseau : tout passe par des fichiers.
C'est un outil tiers, écrit par Flogas ; sa documentation complète est dans son [README](https://github.com/MacFlorent/dcs-hotload#readme).

Cette page explique comment le charger dans une mission construite avec VMCT, **sans rien changer à VMCT**, en suivant le modèle de hotload : une copie de hotload **par mission**, dans le dossier de la mission, chargée par un petit script de démarrage déclaré dans `custom_scripts`.

> ⚠️ **Recette pas encore testée en jeu.**
> Le script de démarrage a été vérifié avec l'interpréteur Lua de DCS (`luae.exe`), dans les cas décrits [plus bas](#what-was-checked) ; il n'a pas encore tourné dans une vraie mission.

## Le principe {#principle}

Chaque mission a **sa** copie de hotload, dans un dossier `dcs-hotload\` à côté de son `mission.yaml`.
Ses commandes F10, ses bibliothèques et sa boîte aux lettres sont dans cette copie : deux missions ne mélangent rien.

La mission embarque un script de démarrage qui contient le chemin de ce dossier **sur le poste du développeur**.
Il charge hotload si le dossier est là, et ne fait rien de visible sinon.

Le même `.miz` va donc partout :

| Où tourne la mission | Ce qui se passe |
|---|---|
| Ton poste, `io` et `lfs` débloqués | hotload démarre, le menu F10 **Hotload** apparaît |
| Ton poste, après une mise à jour de DCS qui a reverrouillé `io` et `lfs` | hotload le dit à l'écran : il faut refaire le déblocage |
| Un serveur, un joueur, tout autre poste | une ligne `HOTLOAD: not booted:` dans `dcs.log`, rien à l'écran, la mission tourne |

Pourquoi un script de démarrage plutôt que le trigger que pose `hotload-setup.py patch-miz` : VMCT **régénère** le `.miz` à chaque build, et un trigger ajouté au `.miz` disparaîtrait au build suivant.
Le script de démarrage, lui, vit dans les sources de la mission.
Il fait la même chose que le trigger de hotload, dont il reprend le code.

## Installer hotload dans la mission {#install}

1. **Télécharger** `dcs-hotload-<version>.zip` depuis les [releases GitHub](https://github.com/MacFlorent/dcs-hotload/releases) de hotload.

2. **L'extraire dans le dossier de la mission**, celui qui contient `mission.yaml`. L'archive contient un seul dossier `dcs-hotload\`, avec `dcs-hotload.lua` dedans :

   ```powershell
   cd "D:\Missions\ma-mission"
   Expand-Archive "$env:USERPROFILE\Downloads\dcs-hotload-3.1.0.zip" .
   ```

   On obtient :

   ```text
   ma-mission\
     mission.yaml
     src\
     build\
     dcs-hotload\
       dcs-hotload.lua
       bin\
   ```

3. **Créer `dcs-hotload\user-f10\`** : chaque fichier `.lua` qu'il contient devient une commande du menu F10.
   L'archive ne le contient pas, et sans lui hotload affiche une erreur au démarrage de la mission.
   Pour la boîte aux lettres, créer aussi `dcs-hotload\user-inbox\` et `dcs-hotload\user-outbox\` (voir le [README de hotload](https://github.com/MacFlorent/dcs-hotload#mailbox)) ; `user-lib\` se crée quand on en a besoin.

   ```powershell
   New-Item -ItemType Directory dcs-hotload\user-f10, dcs-hotload\user-inbox, dcs-hotload\user-outbox
   ```

Le dossier `dcs-hotload\` fait partie des sources de la mission : vos commandes F10 et vos bibliothèques y vivent, il peut aller dans le dépôt git de la mission.

## Débloquer `io` et `lfs` {#unlock}

hotload lit et écrit des fichiers : il lui faut `io` et `lfs`, que DCS retire aux missions par défaut.
Le script de setup de hotload fait le déblocage ; il demande Python 3.8 ou plus, rien d'autre :

```powershell
python dcs-hotload\bin\hotload-setup.py unlock --dcs "C:\Program Files\Eagle Dynamics\DCS World"
```

`--dcs` est le dossier d'installation de DCS, celui qui contient `Scripts\MissionScripting.lua` : rien ne le devine.
Le script commente les lignes `sanitizeModule('io')` et `sanitizeModule('lfs')` de ce fichier et garde l'original en `MissionScripting.lua.bak`.
Si l'installation est sous `C:\Program Files`, il faut lancer PowerShell en administrateur.
À la main, c'est la même modification : commenter ces deux lignes.

Les mises à jour de DCS remettent le fichier d'origine : la manip est à refaire après chacune, et hotload le signale à l'écran quand elle manque.

> ⚠️ **Ce déblocage vaut pour toute l'installation DCS, pas pour une mission.**
> Une fois `io` et `lfs` débloqués, **n'importe quelle mission** que vous chargez, y compris une mission téléchargée depuis un serveur multijoueur, peut lire et écrire des fichiers sur votre disque.
> Il touche aussi aux contrôles d'intégrité du multijoueur.
> C'est le prix de hotload, et de tous les outils qui demandent la même manip.
> À faire sur un poste de développement, en connaissance de cause.

## Le script de démarrage {#boot-script}

Dans le dossier de la mission, créer `src\scripts\hotload-boot.lua`, et remplacer le chemin de la première ligne de code par celui du dossier `dcs-hotload` de **votre** mission :

```lua
-- hotload-boot.lua: loads this mission's copy of dcs-hotload, https://github.com/MacFlorent/dcs-hotload
-- BASE_HOTLOAD_PATH is the mission's dcs-hotload folder on the developer's machine.
-- Where it is missing, as on a player's machine or a server, the mission writes one
-- "HOTLOAD: not booted:" line to dcs.log and runs on, with nothing on screen.
-- Empty it ([[]]) to build a copy that names no local folder.
local BASE_HOTLOAD_PATH = [[D:\Missions\ma-mission\dcs-hotload]]

local f, err
if BASE_HOTLOAD_PATH == "" then
  err = "BASE_HOTLOAD_PATH is not set"
else
  f, err = loadfile(BASE_HOTLOAD_PATH .. [[\dcs-hotload.lua]])
end
if not f then
  env.info("HOTLOAD: not booted: " .. tostring(err))
else
  Hotload = Hotload or {}
  Hotload.root = BASE_HOTLOAD_PATH
  local ok, crash = pcall(f)
  if not ok then
    env.error("HOTLOAD: boot failed: " .. tostring(crash))
  end
end
```

Puis le déclarer dans `mission.yaml` :

```yaml
custom_scripts:
  scripts:
    - path: src/scripts/hotload-boot.lua
```

Si la mission a déjà des `custom_scripts`, ajouter la ligne à la liste existante.
Le build l'embarque dans le `.miz` et génère son trigger de chargement (voir [`custom_scripts:`](../MISSION_YAML_REFERENCE.md#custom-scripts)).

Ce que fait le script :

- **il ne dépend pas de `io` ni de `lfs`** : `loadfile` reste disponible dans une mission, déverrouillée ou non. Sur un poste qui n'a pas le dossier, il échoue proprement et le script s'arrête là ;
- **il donne son dossier à hotload** (`Hotload.root`) : hotload y cherche `user-f10\`, `user-lib\` et la boîte aux lettres ;
- **il protège la mission d'une erreur de hotload** : si `dcs-hotload.lua` lève une erreur au démarrage, une ligne `HOTLOAD: boot failed:` part dans `dcs.log`, sans fenêtre d'erreur, et le reste de la mission se charge.

Les lignes `HOTLOAD:` sont celles qu'écrit hotload lui-même : un `grep HOTLOAD` dans `dcs.log` les trouve toutes.

## Le chemin de votre poste est dans le `.miz` {#local-path}

Une mission ne sait pas où elle est sur le disque : le chemin est donc écrit en dur dans le script, et le build le copie dans le `.miz`.
Le `.miz` que vous distribuez contient donc quelque chose comme `D:\Missions\ma-mission\dcs-hotload`.

C'est **sans effet** ailleurs : sur un autre poste, le dossier n'existe pas, et la mission écrit sa ligne `HOTLOAD: not booted:` dans `dcs.log`.
Le seul inconvénient est que le chemin, donc le nom de vos dossiers, se lit dans le `.miz`.

Pour un `.miz` qui ne nomme aucun dossier, deux façons :

- **vider le chemin** (`local BASE_HOTLOAD_PATH = [[]]`) et reconstruire ; la mission écrit alors `HOTLOAD: not booted: BASE_HOTLOAD_PATH is not set` dans `dcs.log`, partout ;
- **ne pas embarquer le script** dans la version distribuée, en le déclarant seulement dans un [profil de build](../MISSION_YAML_REFERENCE.md#profiles) de développement.

`hotload-setup.py boot-path --clear` ne sert pas ici : il ne connaît que le trigger que pose `patch-miz`.

## Vérifier avec `status` {#status}

Le script de setup sait dire ce qui manque :

```powershell
python dcs-hotload\bin\hotload-setup.py status --dcs "C:\Program Files\Eagle Dynamics\DCS World" --miz "build\ma-mission.miz"
```

`--miz` est nécessaire : le `.miz` construit par VMCT est dans `build\`, pas à côté de `dcs-hotload\`.
Sur une mission montée comme cette page le décrit, la sortie ressemble à :

```text
hotload-setup: dcs-hotload 3.1.0 in D:\Missions\ma-mission\dcs-hotload
hotload-setup: mailbox on
hotload-setup: MissionScripting.lua: unlocked
hotload-setup: ma-mission.miz does not load dcs-hotload: run patch-miz
```

Les trois premières lignes sont utiles : version de la copie, boîte aux lettres, déblocage de `io` et `lfs`.
**La dernière est fausse pour nous** : `status` ne reconnaît que le trigger que pose `patch-miz` et un `dofile` écrit avec un chemin en toutes lettres, pas notre script de démarrage, qui passe par une variable.
Il conclut donc que la mission ne charge pas hotload, et sort avec le code 2.
**Ne pas lancer `patch-miz`** : il ajouterait un second chargement au `.miz`, que le build suivant effacerait de toute façon.

Pour savoir si la mission charge vraiment hotload, le plus sûr reste de la lancer : le message `dcs-hotload 3.1.0 ready` à l'écran, et `HOTLOAD: ready` dans `dcs.log`, avec le dossier racine.

## Ordre de chargement {#load-order}

Les scripts de mission se chargent toujours dans cet ordre : `veaf-config.lua` → `mission-script.lua` → les `custom_scripts`, dans l'ordre de déclaration.
Quand le script de démarrage tourne, **les modules VEAF sont déjà chargés et initialisés** : un script lancé depuis hotload peut appeler `veafSpawn`, `veafCombatZone` ou n'importe quel autre module directement.

Si `hotload-boot.lua` est déclaré après d'autres `custom_scripts`, ceux-ci sont chargés aussi.

## Deux réserves {#caveats}

**Le menu F10 a dix places à sa racine.**
DCS n'affiche que dix entrées par niveau du menu F10, et hotload ajoute la sienne, **Hotload**, à la racine.
Une mission VEAF y place déjà ses propres menus : nous n'avons pas encore compté combien, et si la racine est pleine, une entrée disparaîtra.
À vérifier en jeu.

**On ne recharge pas les modules VEAF avec hotload.**
Le [README de hotload](https://github.com/MacFlorent/dcs-hotload#libraries-in-user-lib) l'interdit lui-même : on ne recharge pas du code qui possède des objets vivants.
Les modules VEAF possèdent des menus radio, des tâches planifiées et des zones enregistrées ; les recharger remplacerait leurs fonctions sous des objets déjà créés.
hotload sert à **piloter et tester** une mission VEAF en direct : faire spawner un groupe, interroger l'état d'une zone, essayer un bout de script de mission.
Pour tester une modification d'un module VEAF, il reste le [mode développeur](GUIDE.md#developer-mode) et un redémarrage de la mission.

## Ce qui a été vérifié {#what-was-checked}

Le script de démarrage ci-dessus, extrait tel quel de cette page (seul le chemin remplacé par un dossier de test), a été exécuté avec l'interpréteur Lua 5.1 livré avec DCS (`bin\luae.exe`), avec des `env`, `trigger`, `timer`, `missionCommands` et `lfs` simulés, contre le vrai `dcs-hotload.lua` 3.1.0 et contre un faux qui lève une erreur :

| Cas | Résultat attendu et obtenu |
|---|---|
| dossier présent, `io` et `lfs` débloqués | hotload démarre, racine = le dossier de la mission, menu **Hotload** créé |
| dossier absent | une ligne `HOTLOAD: not booted:` dans le log, rien à l'écran, aucune erreur |
| chemin vidé (`[[]]`) | une ligne `HOTLOAD: not booted: BASE_HOTLOAD_PATH is not set`, rien à l'écran |
| `io` et `lfs` verrouillés, dossier absent (un joueur) | une ligne `HOTLOAD: not booted:`, rien à l'écran, aucune erreur |
| `io` et `lfs` verrouillés, dossier présent (ton poste après une mise à jour) | hotload affiche à l'écran qu'il faut refaire le déblocage |
| `dcs-hotload.lua` qui lève une erreur | une ligne `HOTLOAD: boot failed:` dans le log, rien à l'écran, le chargement de la mission continue |
| dossier présent sans `user-f10\` | hotload démarre et affiche à l'écran qu'il ne peut pas lire `user-f10` |

`hotload-setup.py` 3.1.0 a été lancé sur un `.miz` construit par VMCT (la mission de démo), avec ce script ajouté dans `l10n/DEFAULT/`, là où le build range les `custom_scripts` :

- `status --miz` répond `does not load dcs-hotload: run patch-miz` et sort avec le code 2, comme décrit [ci-dessus](#status) ;
- `boot-path --clear --miz` répond `has no BASE_HOTLOAD_PATH: run patch-miz`, sort avec le code 1 et ne touche pas au `.miz`.

Il reste à le voir tourner dans DCS.
