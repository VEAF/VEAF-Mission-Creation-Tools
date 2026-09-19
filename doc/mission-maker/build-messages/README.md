# Les messages du build

## Ce que c'est {#what-it-is}

Vous avez construit une mission, la console a affiché quelque chose, et vous voulez savoir quoi en
faire. Cette section reprend les messages les plus coûteux à interpréter : ce qu'ils veulent dire
**dans l'éditeur DCS**, comment retrouver la situation qui les déclenche, les issues possibles — et
surtout ce qu'ils ne veulent **pas** dire, parce que c'est là que part le temps.

## D'abord : est-ce que le build a échoué ? {#did-the-build-fail}

Presque toujours **non**. Trois familles de sorties, qui ne se lisent pas pareil :

| Ce que vous voyez | Ce qui s'est passé | Le `.miz` |
|---|---|---|
| Une ligne jaune isolée pendant le build | Un avertissement en passant | écrit |
| Un encadré en fin de build, « … référence(s) de mission.yaml vers un objet du Mission Editor sont absentes » | Des références manquantes, regroupées exprès à la fin | écrit |
| « Build impossible : … » | Le build s'arrête | **pas** écrit |

Autrement dit, un message jaune ne vous empêche pas de lancer la mission. Il vous dit qu'une partie
de ce que vous avez configuré ne fera rien en vol — ce qui se constate en général une heure plus
tard, dans DCS, sans aucun message.

La même chose se vérifie sans reconstruire :

```powershell
.\veaf-tools.exe validate
```

> **Le `.\` est obligatoire.** Le terminal Windows par défaut est PowerShell, qui ne cherche pas
> dans le dossier courant — exprès. `cmd.exe` accepte les deux formes, donc `.\` marche partout.
> Voir [PowerShell ou invite de commandes ?](../GUIDE.md#powershell-vs-cmd).

`validate` affiche les **mêmes** contrôles, avec un code de sortie : non nul s'il y a une erreur,
et avec `--strict` non nul sur un simple avertissement aussi. C'est la commande à mettre dans un
script ; le build, lui, préfère vous livrer le `.miz` pour que vous puissiez corriger dans l'éditeur.

## Trouver votre message {#find-your-message}

| Le message parle de… | Page |
|---|---|
| pays, camps, `coalitions.red`, écran d'affectation des coalitions | [Coalitions et pays](coalitions.md) |
| un groupe, une zone de déclenchement, une unité ou un aérodrome absent | [Références manquantes](missing-references.md) |
| un fichier `.lua` dans `src/scripts/` | [Les fichiers Lua du dossier](lua-files.md) |
| des waypoints, une route que l'éditeur refuse, une table numérotée bizarrement | [Routes et tables](routes-and-tables.md) |
| CTLD, TUM, un module activé ou désactivé, un fichier son | [Modules et scripts communautaires](modules.md) |

## Si votre message n'est pas ici {#not-listed}

Ces pages ne couvrent pas tout, et ça ne sert à rien de prétendre le contraire : les outils peuvent
afficher environ **cent** messages différents, dont une bonne partie sont de simples comptes rendus
d'avancement (« Injection des scripts VEAF… ») ou tiennent tout entiers dans leur phrase.

Celles-ci couvrent les messages qui ont réellement coûté quelque chose à quelqu'un : ceux qui
bloquent, ceux qui laissent une fonctionnalité muette en vol, et ceux qui ont déjà envoyé un
créateur de mission sur une fausse piste.

Pour le reste : [Obtenir de l'aide](../../SUPPORT.md), et en particulier la commande `/ask` de
l'assistant Discord, qui cherche dans ces pages.

## Pour aller plus loin {#more}

- [Le build](../concepts/build.md) — ce que la commande fait, étape par étape
- [Référence CLI — `validate`](../../CLI_REFERENCE.md#validate)
- [Lire les journaux DCS](../LOGS.md) — pour ce qui se passe **après** le build, en jeu
