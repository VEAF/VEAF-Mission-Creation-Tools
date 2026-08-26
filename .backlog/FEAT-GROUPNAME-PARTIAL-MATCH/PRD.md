# FEAT-GROUPNAME-PARTIAL-MATCH — nommer un groupe par le nom qu'on lui a donné

Status: ✅ done

Demandé par David le 2026-08-25, en réponse à un choix que je lui ai posé pendant qu'il testait
l'artillerie en jeu : *« 1. fais la correspondance partielle »*.

## Le problème

`groupname` désigne le groupe DCS sur lequel poser le pilote automatique, et la recherche était **exacte**.
Or un groupe apparu par une commande VEAF ne porte pas le nom qu'on lui a donné : `veaf.getNameForSpawnedGroup`
le décore, donc `-arty, unitname arty-1` produit un groupe que DCS appelle `[b]-arty-1#7`.

Conséquence : `groupname arty-1` ne trouvait **jamais** rien. Le paramètre ne fonctionnait que pour les
groupes posés dans l'éditeur de missions, c'est-à-dire pas pour ceux que le pilote vient de faire apparaître —
exactement le cas de l'artillerie au marqueur.

## Ce qui se passait à la place, et qui est le vrai défaut

Un `groupname` introuvable ne disait rien : il laissait `options.group` à nil, ce qui **retombe sur la
recherche de proximité**. Le pilote automatique se posait alors sur le premier groupe allié à moins de 250 m
du marqueur — un blindé qui passait, la garde d'un pont. Le pilote croit commander sa batterie et commande
autre chose, sans un mot.

Un nom donné qui ne désigne pas **un** groupe arrête donc maintenant la commande, et le dit.

## Ce qui a été fait

`veaf.findGroupByPartialName`, posée **à côté de `getNameForSpawnedGroup`** : les deux sont des contraires,
l'une fabrique le nom décoré, l'autre le retrouve.

1. nom exact d'abord — c'est le cas du groupe posé dans l'éditeur, une seule requête, et aucune ambiguïté
   possible ;
2. sinon, énumération des groupes vivants, en retenant ceux dont le nom **contient** la chaîne demandée, sans
   tenir compte de la casse et dédoublonnés par nom (`getGroupsOfCoalition(nil)` parcourt les trois
   coalitions, et un groupe qui n'en déclare aucune apparaît trois fois — sans dédoublonnage il se refuserait
   pour ambiguïté avec lui-même) ;
3. un seul candidat → c'est lui ;
4. plusieurs → **refus**, et les noms trouvés sont dits au pilote. `arty-1` est contenu dans `arty-1` **et**
   dans `arty-10` ; en choisir un ferait tirer une batterie que personne n'a désignée. C'était la réserve de
   David sur cette option, et c'est la réponse ;
5. aucun → refus également, avec le nom redit.

## Le refus ne vaut que pour les verbes qui désignent un groupe

Seuls `set` et `unset` désignent un groupe ; `status`, `stop`, `start`, `clear` et `order` s'adressent à un
pilote automatique déjà posé et ignorent `groupname`. Un premier essai refusait pour tous les verbes, ce qui
aurait coupé la parole à un `status` à cause d'un paramètre que ce verbe n'utilise même pas. Les deux blocs —
le refus et la recherche de proximité — partagent donc la même condition.

## Le câblage, encore lui

Les tests passent par `executeCommand`, pas par `parseMarkerText`. Les tests `_gc` existants lisent le
parseur seul — c'est ce qui explique qu'ils soient tous restés verts alors que la résolution du nom et son
refus vivent dans `markTextAnalysis`, un étage au-dessus. Sixième occurrence du motif consigné dans
[FIX-GC-NEVER-REACHES-THE-MODULE](../FIX-GC-NEVER-REACHES-THE-MODULE/PRD.md).

Un détail de méthode qui a compté : les deux tests de refus ne prouvaient rien tant qu'il n'y avait **rien à
substituer** sous le marqueur. Sans groupe allié à portée, un refus qui s'arrête et un refus qui continue
finissent tous deux sans rien créer — la mutation « le refus n'arrête plus la commande » survivait. Les tests
posent donc un groupe sous le marqueur, et un test frère prouve que ce groupe **serait** pris en l'absence de
`groupname`.

## Un mock qui mentait, corrigé au passage

`coalition.getGroups` rendait `{}` alors que `Group.getByName` trouvait les groupes enregistrés. Aucun test ne
pouvait donc exercer du code qui **énumère** les groupes — et il y en a. Le correctif a demandé de remonter
`local _group_registry = {}` en tête de fichier : déclaré après son usage, la fermeture capturait la globale,
c'est-à-dire nil.

### Mutations

| Mutation | Résultat |
|---|---|
| la recherche partielle revient à l'exact *(le bug d'origine)* | 2 échecs |
| l'ambiguïté prend le premier candidat | 2 échecs |
| le refus n'arrête plus la commande (retombe sur la proximité) | 2 échecs |
| le refus ne dit plus rien | 1 échec |
| l'ambiguïté rend le premier au lieu de refuser (dans la fonction) | 1 échec |
| le dédoublonnage par nom retiré | 6 échecs |
| la recherche redevient sensible à la casse | 1 échec |
| la recherche redevient un motif au lieu d'un texte littéral | 5 échecs |
| le refus s'étend aux verbes qui ignorent `groupname` | 1 échec |
| le garde sur le type d'entrée retiré | 1 erreur |

## Definition of done

- [x] `groupname arty-1` trouve `[b]-arty-1#7`
- [x] Un nom qui désigne plusieurs groupes est refusé, et les candidats sont nommés
- [x] Un nom qui ne désigne rien n'est plus remplacé par le groupe le plus proche
- [x] Sans `groupname`, la recherche de proximité fonctionne comme avant — sous test
- [x] Un verbe qui n'utilise pas le groupe n'est pas refusé pour autant
- [x] Les tests passent par le point d'entrée, pas par le parseur seul
- [x] `coalition.getGroups` rend ce que DCS rend
- [x] La page du module dit qu'un fragment suffit, dans les deux langues
