# Harnais de fumée — vérifier VEAF dans un vrai DCS

`poetry run test-lua` tourne contre `test/lua/dcs_mocks.lua`, un DCS que **nous avons écrit**. Il ne
peut donc confirmer que ce que nous croyions déjà. Tout ce qui le dépasse finissait dans une file
d'attente : quelqu'un devait piloter.

Ce harnais exécute des assertions **à l'intérieur d'un DCS qui tourne**, sans personne devant.

## Ce qu'il ne sera jamais

**Une porte CI.** Les runners GitHub n'ont ni DCS, ni licence, ni GPU. C'est un outil **local**, lancé
par qui possède une installation. Il **passe** (`skip`) avec une explication au lieu d'échouer quand il
n'y a rien à interroger — sinon il deviendrait rouge sur chaque machine et personne ne le lancerait.

## Prérequis

1. **DCS lancé.** Le menu principal suffit : `onSimulationFrame` bat à ~28 Hz **sans mission
   chargée** — 2 305 ticks mesurés avant qu'une mission existe (voir
   [DCS-HOOK-ENVIRONMENT-BOUNDARIES](../../docs/exploration/DCS-HOOK-ENVIRONMENT-BOUNDARIES.md)).
   C'est cette mesure qui rend le pilotage automatique possible.
2. **Le hook installé** : copier `src/scripts/other/dcs-fiddle-server.lua` dans
   `Saved Games/DCS/Scripts/Hooks/`. Il écoute sur `127.0.0.1:12081`.

   !!! danger "Ce hook est un port d'exécution de code à distance, ouvert. Retirez-le après usage."

       Il exécute n'importe quel Lua qu'on lui envoie, sans jeton ni contrôle d'origine, et répond
       avec `Access-Control-Allow-Origin: *`. Le canal de commande est un `GET`, et un navigateur
       émet un `GET` cross-origin sans rien demander — donc **n'importe quelle page web visitée
       pendant que le hook est installé peut exécuter du code dans votre DCS**, et en lire le
       résultat. Écouter sur `127.0.0.1` ne protège pas : votre navigateur y est aussi.

       Installez-le pour lancer le harnais, retirez-le ensuite, et **ne le mettez jamais sur un
       serveur**. Voir l'[ADR 0019](../../docs/adr/0019-dcs-fiddle-server-stays-unauthenticated-for-now.md)
       pour la raison de cet état et ce qui le remplacera.

3. **`net.dostring_in` disponible** — c'est le seul chemin vers l'environnement de mission, donc sans lui
   aucune assertion ne peut tourner. **Rien à configurer : mesuré présent sur une installation
   standard** (2026-08-06), `autoexec.cfg` ne listant ni `net.allow_unsafe_api` ni
   `net.allow_dostring_in`. La doc d'ED laisse entendre le contraire ; voir la section sur cette doc
   plus bas. Si un jour il manque, le harnais le nomme précisément plutôt que d'accuser la mission.

4. **Une mission chargée** pour les assertions — l'environnement de mission n'existe qu'à partir de là.

## Utilisation

```
veaf-tools dcs smoke-test --probe-only
```

Ne lance aucune assertion : rapporte seulement **ce que ce DCS autorise**. À lancer en premier, c'est
la même discipline que la sonde `Disposition` — mesurer avant de bâtir dessus.

Ce qu'il mesure, en un aller-retour : quelle table de contrôle répond (`Sim`, `DCS`, ou les deux), si
`exitProcess` / `stopMission` / `setUserCallbacks` sont là, si `net.load_mission` existe **et** si
cette instance se déclare serveur, si `net.dostring_in` est permis, et — ce que seul le processus en
cours sait — **quel dossier d'installation et quel dossier `Saved Games` cette instance utilise**.

Il termine par **le blocage à corriger en premier**, et l'ordre compte : « pas de hook », puis « pas de
permission », puis « pas de mission ». La version précédente rapportait le manque de permission comme
« aucune mission chargée », ce qui envoyait chercher une mission à charger là où charger une mission ne
pouvait rien changer.

```
veaf-tools dcs smoke-test
```

Sonde, puis exécute les vérifications. Sort en 1 si l'une échoue, en 0 si tout passe **ou si le run a
été sauté**.

## Comment ça parle à DCS

Un seul transport, celui du hook, lu dans `dcs-fiddle-server.lua` plutôt que supposé : le Lua voyage
**en base64 dans le chemin de l'URL**, l'environnement cible dans `?env=`, et la réponse est un JSON
`{result=…}` ou `{error=…}`.

| `?env=` | Ce que ça atteint | À quoi ça sert |
|---|---|---|
| `default` | l'environnement du hook, via `loadstring` | le seul qui contient `net.*` — donc le pilotage |
| `mission` | l'état **trigger**, via `net.dostring_in` | là où vivent `a_do_script` et les actions `a_*` |

!!! warning "`env=mission` n'est pas là où vivent les scripts VEAF"

    C'était l'hypothèse de la première tranche, et elle est fausse — **mesuré le 2026-08-06**, mission
    chargée et pilote dans le cockpit : un chunk envoyé là renvoie
    `:1: attempt to index global 'env' (a nil value)`. Le chunk **a tourné** — c'est une erreur
    d'exécution Lua venue de l'intérieur de l'état ciblé, pas un refus — donc cet état n'a simplement
    pas de `env`. C'est l'état **trigger**.

    Notre propre dépôt l'avait déjà établi sans en tirer la conséquence : le ticket 01 de
    `FEAT-ASSIST-CHECKLISTS` avait situé `a_cockpit_highlight` « à un `net.dostring_in` de distance ».
    Et le hook le dit en une ligne, dans son propre amorçage :
    `net.dostring_in("mission", 'a_do_script("dofile(…)")')` — il atteint l'état de script **à travers**
    `a_do_script`, pas directement.

    Conséquence : les six vérifications de la première tranche visaient un état trop court. Elles
    passent maintenant par une **route mesurée**, que la sonde découvre en essayant
    `a_do_script` (le chemin qu'ED documente comme actuel, et qui renvoie ses valeurs directement) puis
    `net.dostring_in("scripting", …)`. Le test de la route est `return type(env)` et la réponse doit
    **valoir** `table` : une route qui exécute le chunk ailleurs renvoie une erreur Lua, que ce
    transport rend comme une chaîne ordinaire — « quelque chose est revenu » ne prouve rien.

Ce n'est **pas** le bridge que `capture-map` utilise (`dcs-serve` + `dcs-bridge.lua`) : celui-là vit
*dans* la mission, il ne peut donc pas répondre avant que la mission existe, ni la charger.

## Le contrat de la mission de test

Emprunté à [nielsvaes/dcs-sms](https://github.com/nielsvaes/dcs-sms), et c'est le **contre-exemple**
qui vaut le détour :

- Théâtre **Syria**, ancre **`(-32220, 405386)`** — « désert vide, loin de tout, mais DCS y traite
  bien les événements ».
- À **`(-50000, -50000)`**, au-dessus de l'eau, **DCS perd silencieusement les événements de mort.**

Un harnais qui poserait ses unités de test « quelque part de vide » verrait les kills ne pas remonter
et conclurait que le code est cassé. C'est une journée perdue sur un non-bug, et ça ne se déduit pas.

> ⚠️ **Ces coordonnées ne sont pas encore vérifiées ici.** Elles viennent de leur dépôt, et ce dépôt a
> déjà trouvé **deux** affirmations fausses dans leur documentation (le partage de VM entre le hook et
> l'éditeur, et le « ça meurt au menu principal »). Tuer une unité à cette ancre et observer
> l'événement arriver fait partie du ticket 01 du lot.

## Ajouter une vérification

Les assertions sont des **données**, pas du code : une entrée dans `CHECKS`
(`veaf_libs/dcs_smoke.py`), avec un nom, un extrait Lua, ce que son résultat doit valoir, et **pourquoi
on veut le savoir**. Une vérification dont personne n'a écrit la raison est une vérification que
personne n'osera supprimer.

### La règle : votre Lua doit renvoyer une **chaîne**. Toujours.

Mesuré le 2026-08-06 en mission, et tout le reste en découle :

| Le Lua renvoie | Python reçoit |
|---|---|
| `'x'` | `'x'` |
| `3` | `'3'` — une **chaîne** |
| `true` | `''` — **détruit** |
| `{1, 2}` | `''` — **détruit** |

Un booléen et une table sont donc indiscernables l'un de l'autre *et* d'un chunk qui n'a rien renvoyé.
Deux des six vérifications d'origine en sont mortes : l'une attendait un nombre, l'autre `true` — et la
seconde était pire qu'impossible, elle était **muette sur la seule question qu'elle devait trancher**.

Corollaire pratique : **taguez** vos valeurs numériques (`count:10` plutôt que `10`), pour que « j'ai
demandé, il n'y a rien » (`count:0`) reste distinct de « la réponse a été détruite » (`''`). Un test
balaie toutes les vérifications contre `''` : une attente que `''` satisfait est une attente incapable de
distinguer un succès d'une valeur perdue.

Un piège à connaître : les extraits renvoient des **sentinelles** (`veaf-absent`, `no-singleton`,
`not-a-table`, `raised: …`) plutôt que de lever, pour qu'un prérequis manquant soit lisible. Ce sont
des chaînes **non vides, donc vraies** — une attente écrite avec un simple test de vérité passe donc
exactement dans le cas qu'elle devait attraper. C'est arrivé pendant l'écriture ; un test balaie
maintenant toutes les vérifications contre toutes les sentinelles.

## La source qui tranche : la doc d'ED, livrée avec DCS

`<installation DCS>/API/Sim_ControlAPI.md` documente l'API du hook. **Lisez-la avant d'ajouter un appel
ici** : trois de ses affirmations contredisent ce que ce module supposait au départ.

| Ce qu'on supposait | Ce qu'ED documente | Conséquence |
|---|---|---|
| la table de contrôle est `DCS.*` | c'est `Sim.*` | **mesuré : `Sim` et `DCS` sont la *même table*** — les deux noms marchent, mais la sonde le rapporte au lieu d'en supposer un |
| `net.load_mission` charge une mission | `net.load_mission` est **SERVER ONLY** | mesuré : `isServer=true` en solo, donc l'appel est légitime sur une instance locale |
| `net.dostring_in` est disponible | **OBSOLETE et UNSAFE**, conditionné à `autoexec.cfg` | **la restriction ne s'applique pas telle quelle** : mesuré présent sans aucune des deux clés. Le harnais vérifie donc la *fonction*, pas la config |

Et une chose qu'aucune doc ne dit : **le transport ment sur l'échec.** `net.dostring_in(state, string)`
renvoie une erreur Lua **comme résultat**, en HTTP 200 avec un corps `{result=…}` — une erreur dans
l'environnement de mission a donc exactement la forme d'une réponse réussie. Mesuré au menu principal :
`return env.mission.theatre` a renvoyé `:1: attempt to index global 'env' (a nil value)`, et la sonde a
conclu « l'environnement de mission a répondu ». C'est la **troisième** fois que ce lot se fait prendre
par un échec véridique — les sentinelles, le check de sous-menu qui renvoyait une constante, et
celui-ci. Dans ce transport, « ça est revenu » n'est pas « ça a marché ».

Deux autres choses utiles y sont documentées et pas encore exploitées :
`onMissionLoadBegin` / `onMissionLoadProgress(progress, message)` / `onMissionLoadEnd` — un signal
d'**événement** pour savoir qu'un chargement est terminé, bien meilleur que de surveiller un compteur
d'images qui gèle pendant le chargement ; et `Sim.getLogHistory(from)`, qui rend le `dcs.log` lisible à
travers le hook au lieu d'être analysé sur disque.

## Ce qui reste à faire

Le lot [`FEAT-DCS-SMOKE-HARNESS`](../../.backlog/FEAT-DCS-SMOKE-HARNESS/PRD.md) porte le détail. En
résumé : DCS doit être lancé **à la main** pour l'instant. Le lancer, charger la mission et le quitter
reste à écrire, et la sonde ci-dessus est ce qui donne les faits pour l'écrire — notamment le point
`SERVER ONLY`, qui décide si une instance solo suffit ou s'il faut passer par le mode serveur.
