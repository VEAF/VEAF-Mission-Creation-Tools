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

3. **Une mission chargée** pour les assertions — l'environnement de mission n'existe qu'à partir de là.

## Utilisation

```
veaf-tools smoke-test --probe-only
```

Ne lance aucune assertion : rapporte seulement **ce que ce DCS autorise**. À lancer en premier, c'est
la même discipline que la sonde `Disposition` — mesurer avant de bâtir dessus. Il répond notamment si
`net.load_mission` et `DCS.exitProcess` existent, deux appels que ce dépôt n'a **jamais** faits.

```
veaf-tools smoke-test
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
| `mission` | l'environnement de mission, via `net.dostring_in` | là où vivent les scripts VEAF — donc les assertions |

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

Un piège à connaître : les extraits renvoient des **sentinelles** (`veaf-absent`, `no-singleton`,
`not-a-table`, `raised: …`) plutôt que de lever, pour qu'un prérequis manquant soit lisible. Ce sont
des chaînes **non vides, donc vraies** — une attente écrite avec un simple test de vérité passe donc
exactement dans le cas qu'elle devait attraper. C'est arrivé pendant l'écriture ; un test balaie
maintenant toutes les vérifications contre toutes les sentinelles.

## Ce qui reste à faire

Le lot [`FEAT-DCS-SMOKE-HARNESS`](../../.backlog/FEAT-DCS-SMOKE-HARNESS/PRD.md) porte le détail. En
résumé : DCS doit être lancé **à la main** pour l'instant. Le lancer et le quitter automatiquement
demande des appels DCS que ce dépôt n'a jamais faits — `--probe-only` dit s'ils sont disponibles, ce
qui donne au suivant ses faits au lieu de le laisser deviner.
