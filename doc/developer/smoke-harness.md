# Harnais de fumée — vérifier VEAF dans un vrai DCS

`poetry run test-lua` tourne contre `test/lua/dcs_mocks.lua`, un DCS que **nous avons écrit**. Il ne
peut donc confirmer que ce que nous croyions déjà. Tout ce qui le dépasse finissait dans une file
d'attente : quelqu'un devait piloter.

Ce harnais exécute des assertions **à l'intérieur d'un DCS qui tourne**, sans personne devant.

## Ce qu'il ne sera jamais

**Une porte CI.** Les runners GitHub n'ont ni DCS, ni licence, ni GPU. C'est un outil **local**, lancé
par qui possède une installation.

## Prérequis

1. **DCS lancé et une mission chargée**, par vous : la mission bâtie avec la section `dcs_bridge` du
   `mission.yaml` activée (ou passée par `veaf-tools dcs inject-bridge`). La mission de test
   `test/veaf-tools/verify-mission-c` l'active déjà.
2. **La manip `MissionScripting.lua`** faite une fois sur votre DCS, pour que le bridge charge la
   bibliothèque `socket` : c'est la même que pour `clear-ground-sweep`, décrite dans
   [la référence CLI](../CLI_REFERENCE.md#dcs-bridge).
3. **`dcs-serve`** : la commande le démarre si aucun ne tourne, comme les autres commandes du bridge.

## Utilisation

```powershell
.\veaf-tools.exe dcs smoke-test
```

Exécute les vérifications dans la mission, une ligne par vérification, et sort en 1 si l'une échoue.
`--suite spotter` lance les vérifications du banc `demo-spotter-network` à la place.

Il n'y a plus de run sans surveillance (`--full`, qui lançait DCS et chargeait la mission) : mesuré le
2026-08-15, `net.load_mission` ne charge rien en solo — ED le documente SERVER ONLY — et c'est vous qui
lancez DCS et la mission. Le hook DCS Fiddle qui servait à ce pilotage a été retiré
(`REFACTOR-BRIDGE-ONLY`, 2026-10-29).

## Comment ça parle à DCS

**Un seul transport : le bridge VEAF.** `dcs-serve` reçoit le Lua, `dcs-bridge.lua` — embarqué **dans**
la mission — l'exécute dans l'état de script de la mission. Cet état voit à la fois les globals de DCS
(`Disposition`, `missionCommands`, `coalition`) et les scripts de la mission (`veaf`, `csar`), donc
toutes les vérifications y tournent.

Le bridge renvoie `tostring` du résultat ; une erreur Lua revient en `{"error": …}` et la vérification
échoue en la citant. Le bridge tourne sur l'horloge de la mission : **en pause, il ne répond pas**.

## Le contrat de la mission de test

Emprunté à [nielsvaes/dcs-sms](https://github.com/nielsvaes/dcs-sms), et c'est le **contre-exemple**
qui vaut le détour :

- Théâtre **Syria**, ancre **`(-32220, 405386)`** — « désert vide, loin de tout, mais DCS y traite
  bien les événements ».
- À **`(-50000, -50000)`**, au-dessus de l'eau, **DCS perd silencieusement les événements de mort.**

Un harnais qui poserait ses unités de test « quelque part de vide » verrait les kills ne pas remonter
et conclurait que le code est cassé. C'est une journée perdue sur un non-bug, et ça ne se déduit pas.

> ⚠️ **Ces coordonnées ne sont pas encore vérifiées ici.** Elles viennent de leur dépôt, et ce dépôt a
> déjà trouvé deux affirmations fausses dans leur documentation. Tuer une unité à cette ancre et
> observer l'événement arriver fait partie du ticket 01 du lot.

## Ajouter une vérification

Les assertions sont des **données**, pas du code : une entrée dans `CHECKS`
(`veaf_libs/dcs_smoke.py`), avec un nom, un extrait Lua, ce que son résultat doit valoir, et **pourquoi
on veut le savoir**. Une vérification dont personne n'a écrit la raison est une vérification que
personne n'osera supprimer.

### La règle : votre Lua doit renvoyer une **chaîne**. Toujours.

Le bridge renvoie `tostring(result ~= nil and result or "")` :

| Le Lua renvoie | Python reçoit |
|---|---|
| `'x'` | `'x'` |
| `3` | `'3'` — une **chaîne** |
| `true` | `'true'` |
| `false`, `nil` | `''` — **détruit** |
| `{1, 2}` | `'table: 0x…'` — une adresse, pas le contenu |

Corollaire pratique : **taguez** vos valeurs (`count:10` plutôt que `10`, un mot plutôt qu'un booléen),
pour que « j'ai demandé, il n'y a rien » (`count:0`) reste distinct de « la réponse a été détruite »
(`''`). Un test balaie toutes les vérifications contre `''` : une attente que `''` satisfait est une
attente incapable de distinguer un succès d'une valeur perdue.

Un piège à connaître : les extraits renvoient des **sentinelles** (`veaf-absent`, `no-singleton`,
`not-a-table`, `raised: …`) plutôt que de lever, pour qu'un prérequis manquant soit lisible. Ce sont
des chaînes **non vides, donc vraies** — une attente écrite avec un simple test de vérité passe donc
exactement dans le cas qu'elle devait attraper. Un test balaie toutes les vérifications contre toutes
les sentinelles, et contre la forme d'une erreur Lua (`:1: attempt to …`), que `net.dostring_in` rend
comme un résultat ordinaire.

## Les vérifications CSAR sur l'eau {#csar-over-water}

`csar-avoids-water-open-sea` et `csar-avoids-water-coast` répondent à
[#245](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/245) — « le pilote CSAR apparaît dans
l'eau » — sans avion et sans pilote humain. Trois appels de script suffisent : déclencher l'apparition,
relire la position, demander ce qu'il y a dessous.

Les deux vérifications posent des questions différentes, et c'est le but :

- **en haute mer** — le cas signalé ;
- **près d'une côte** — le cas intéressant. `FEAT-SCENERY-AWARE-SPAWN` a doté `veaf.findSpawnPoint` de
  la conscience du terrain ; la vraie question est de savoir si CSAR passe par là. Un succès au large
  avec un échec près de la côte signifierait que CSAR a son propre chemin de placement.

Aucune coordonnée n'est écrite en dur : la vérification s'ancre sur le premier aérodrome et balaye
jusqu'à trouver de l'eau, puis classe le point selon ce qui l'entoure à 150 m. Elle fonctionne donc sur
n'importe quel théâtre.

!!! warning "Toute réponse autre qu'un placement au sec est un échec"
    Y compris celles qui disent que la question n'a pas pu être posée (`csar-absent`, `no-water-found`,
    `no-group`). Une vérification qui passe alors qu'elle n'a rien demandé clôturerait #245 sur du vide,
    et c'est précisément le mode d'échec contre lequel ce banc d'essai est écrit.

---

## Ce qui reste à faire

Le lot [`FEAT-DCS-SMOKE-HARNESS`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/.backlog/archive/FEAT-DCS-SMOKE-HARNESS.md) porte le détail : la mission de test committée (ticket 01) et sa vérification d'ancre en jeu.
