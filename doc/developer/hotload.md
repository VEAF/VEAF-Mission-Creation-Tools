# Scripts en direct avec dcs-hotload

[dcs-hotload](https://github.com/MacFlorent/dcs-hotload) exécute du Lua dans une mission DCS **qui tourne**, sans la redémarrer.
Le script est relu sur le disque à chaque exécution : on modifie le fichier, on relance, on voit le résultat.
Il se lance de deux façons :

- **depuis le menu F10** : chaque fichier de `user-f10/` devient une commande du menu ;
- **depuis une boîte aux lettres** : un fichier `.lua` déposé dans `user-inbox/` s'exécute une fois, et son résultat est écrit dans `user-outbox/`. Un éditeur, un terminal ou un agent peut ainsi piloter la mission.

Il n'ouvre aucun port réseau : tout passe par des fichiers.
C'est un outil tiers, écrit par Flogas ; sa documentation complète est dans son [README](https://github.com/MacFlorent/dcs-hotload#readme).

Cette page explique comment le charger dans une mission construite avec VMCT, **sans rien changer à VMCT** : un petit script de démarrage, déclaré dans `custom_scripts`.

> ⚠️ **Recette pas encore testée en jeu.**
> Le script de démarrage a été vérifié avec l'interpréteur Lua de DCS (`luae.exe`) contre des `lfs` et `env` simulés, dans les cinq cas décrits [plus bas](#what-was-checked) ; il n'a pas encore tourné dans une vraie mission.
> Flogas le teste ; cette page sera corrigée selon ce qu'il trouve.

## Le principe {#principle}

dcs-hotload s'installe **une fois par poste**, dans `Saved Games\DCS\Scripts\dcs-hotload\`.
La mission embarque un script de démarrage qui le charge **s'il est là**, et ne fait rien sinon.

Le même `.miz` va donc partout :

| Où tourne la mission | Ce qui se passe |
|---|---|
| Ton poste, hotload installé, `io` et `lfs` débloqués | hotload démarre, le menu F10 **Hotload** apparaît |
| Un serveur, un joueur, un poste sans hotload | rien, sans message d'erreur |
| Un poste où `io` ou `lfs` sont encore verrouillés | rien, sans message d'erreur |

Mettre le chemin du poste directement dans les sources de la mission (`dofile([[D:\...\dcs-hotload.lua]])`) ne marche que sur ce poste : ailleurs, le `dofile` échoue au chargement de la mission.

## Prérequis {#prerequisites}

1. **Débloquer `io` et `lfs`** dans `Scripts\MissionScripting.lua` de l'installation DCS : commenter les lignes `sanitizeModule('io')` et `sanitizeModule('lfs')`.
   Les mises à jour de DCS remettent le fichier d'origine : la manip est à refaire après chacune.

   > ⚠️ **Ce déblocage vaut pour toute l'installation DCS, pas pour une mission.**
   > Une fois `io` et `lfs` débloqués, **n'importe quelle mission** que vous chargez, y compris une mission téléchargée depuis un serveur multijoueur, peut lire et écrire des fichiers sur votre disque.
   > C'est le prix de hotload, et de tous les outils qui demandent la même manip.
   > À faire sur un poste de développement, en connaissance de cause.

2. **Installer dcs-hotload** : télécharger `dcs-hotload-<version>.zip` depuis ses [releases GitHub](https://github.com/MacFlorent/dcs-hotload/releases) et l'extraire dans `Saved Games\DCS\Scripts\`. L'archive contient un seul dossier `dcs-hotload\`, avec `dcs-hotload.lua` dedans.

   ```powershell
   Expand-Archive "$env:USERPROFILE\Downloads\dcs-hotload-3.0.0.zip" "$env:USERPROFILE\Saved Games\DCS\Scripts"
   ```

   Si votre dossier d'écriture DCS s'appelle `DCS.openbeta`, adaptez le chemin.

3. **Créer le dossier `user-f10\`** à côté de `dcs-hotload.lua` : chaque fichier `.lua` qu'il contient devient une commande du menu F10.
   Pour la boîte aux lettres, créer aussi `user-inbox\` et `user-outbox\` (voir le [README de hotload](https://github.com/MacFlorent/dcs-hotload#mailbox)).

## Le script de démarrage {#boot-script}

Dans le dossier de la mission, créer `src\scripts\hotload-boot.lua` :

```lua
-- hotload-boot.lua: loads dcs-hotload when this machine has it, otherwise does nothing.
-- One install per machine, in Saved Games\DCS\Scripts\dcs-hotload\.
-- true: user-f10\, user-lib\ and the mailbox live in missions\<sortie>\ under the install.
local PER_MISSION = false

if lfs and io then
  local install = lfs.writedir() .. [[Scripts\dcs-hotload]]
  local file = install .. [[\dcs-hotload.lua]]
  if lfs.attributes(file) then
    local root = install
    if PER_MISSION then
      local ok, sortie = pcall(function()
        return env.getValueDictByKey(env.mission.sortie)
      end)
      if ok and type(sortie) == "string" and sortie ~= "" then
        root = install .. [[\missions\]] .. (sortie:gsub("[^%w%-_]", "_"))
      end
    end
    Hotload = Hotload or {}
    Hotload.root = root
    local ok, err = pcall(dofile, file)
    if not ok then
      env.error("hotload-boot: " .. tostring(err))
    end
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

Pour ne l'embarquer que dans une variante de développement, le mettre dans un [profil de build](../MISSION_YAML_REFERENCE.md#profiles) ; ce n'est pas nécessaire, puisqu'il ne fait rien là où hotload n'est pas installé.

## Ordre de chargement {#load-order}

Les scripts de mission se chargent toujours dans cet ordre : `veaf-config.lua` → `mission-script.lua` → les `custom_scripts`, dans l'ordre de déclaration.
Quand le script de démarrage tourne, **les modules VEAF sont déjà chargés et initialisés** : un script lancé depuis hotload peut appeler `veafSpawn`, `veafCombatZone` ou n'importe quel autre module directement.

Si `hotload-boot.lua` est déclaré après d'autres `custom_scripts`, ceux-ci sont chargés aussi.

## Un dossier par mission {#per-mission-root}

Par défaut, `user-f10\`, `user-lib\` et la boîte aux lettres sont **communs à toutes les missions** : ce sont ceux du dossier d'installation.

Pour qu'une mission ait les siens, passer `PER_MISSION` à `true` dans le script de démarrage.
Le dossier racine devient alors `Saved Games\DCS\Scripts\dcs-hotload\missions\<nom de la mission>\`, où le nom est le `sortie` de la mission (le nom saisi dans l'éditeur de mission), chaque caractère autre qu'une lettre, un chiffre, `-` ou `_` étant remplacé par `_` (espaces comprises).
Une mission sans `sortie` garde le dossier commun.

Les dossiers ne sont pas créés automatiquement : créer `user-f10\` (et la boîte aux lettres, si besoin) dans ce dossier.
S'il manque, hotload le dit à l'écran au démarrage de la mission.

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

Le script de démarrage ci-dessus, extrait tel quel de cette page, a été exécuté avec l'interpréteur Lua 5.1 livré avec DCS (`bin\luae.exe`), contre des `lfs` et `env` simulés et un faux `dcs-hotload.lua` :

| Cas | Résultat attendu et obtenu |
|---|---|
| hotload installé | chargé, racine = dossier d'installation |
| hotload installé, `PER_MISSION = true` | chargé, racine = `missions\<sortie>` avec les caractères spéciaux remplacés |
| hotload absent | rien, aucune erreur |
| `io` ou `lfs` verrouillés | rien, aucune erreur |
| `dcs-hotload.lua` qui lève une erreur | une ligne `hotload-boot:` dans le log, le chargement de la mission continue |

Il reste à le voir tourner dans DCS.
