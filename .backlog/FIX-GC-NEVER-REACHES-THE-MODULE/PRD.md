# FIX-GC-NEVER-REACHES-THE-MODULE — la syntaxe livrée était morte en jeu

Status: ✅ done

Trouvé en jeu le 2026-08-25, quelques minutes après la livraison de
[`FEAT-GC-MARKER-SYNTAX`](../FEAT-GC-MARKER-SYNTAX/PRD.md) : *« "_gc arty-1" ne fait rien (le marqueur
reste et n'est pas reconnu) »*.

## Le défaut

Un gestionnaire de commande de marqueur s'enregistre avec un **filtre de mot-clé** — le dernier argument
de `veafCommands.registerCommandHandler` — et le répartiteur ne l'appelle **que** pour les textes qui
contiennent ce mot :

```lua
veafCommands.registerCommandHandler(fn, priority, security, veafGroundAI.MarkerKeyphrase)
```

Le filtre est **une seule chaîne**, appliquée par `veafCommands.handlesText` avec un `find(…, 1, true)`.
Il n'accepte pas de liste. `_ground` était déclaré, `_gc` non : le texte n'atteignait jamais le module, et
le marqueur restait sur la carte sans un mot.

Le module s'enregistre désormais **une fois par mot-clé**. Deux entrées de la même fonction plutôt qu'une
liste dans l'interface partagée : un seul module a deux orthographes, et élargir `handlesText` pour ça
serait spéculatif.

## Pourquoi 163 tests n'ont rien vu

Tous appelaient `veafGroundAI.executeCommand` ou `veaf.parseMarkerText` **directement**. Ils prouvaient que
le gestionnaire comprend le texte ; **aucun ne pouvait voir qu'on ne l'appelait jamais**.

C'est la **quatrième fois dans la journée** que ce trou exact est trouvé par un essai en vol plutôt que par
un test :

| Lot | Ce qui n'était pas couvert |
|---|---|
| `FEAT-ARTILLERY-CONTROL` | un test lisait le dernier ordre en file, donc un refus ressemblait à un succès |
| `FIX-SPAWN-BYPASSSECURITY-AS-SILENT` | le correctif réel était une indirection au-delà des tests du répartiteur |
| `FIX-WELCOME-BRIEF-NEVER-FIRES` | l'abonnement et la planification, deux fois de suite |
| **celui-ci** | le filtre qui décide si le module est appelé |

Le motif est stable : **un test qui appelle le gestionnaire prouve le gestionnaire, et ne dit rien de ce
qui l'appelle.** Quand un lot ajoute une entrée dans le monde — un abonnement, une planification, un
filtre, un enregistrement — c'est cette entrée qu'il faut asserter, pas seulement ce qu'elle déclenche.

## Les tests ajoutés

Cinq, et ils interrogent les **filtres déclarés** au lieu du gestionnaire : les deux mots-clés présents, un
texte `_gc` pris en charge, un texte `_ground` toujours pris en charge, un `_spawn` **non** pris en charge
(un filtre qui prend tout ne filtre rien et ferait répondre ce module aux marqueurs des autres), et chaque
enregistrement déclarant son niveau de sécurité — parce qu'ajouter un second enregistrement est exactement
le moment de l'oublier.

### Mutations

| Mutation | Résultat |
|---|---|
| le second enregistrement retiré *(le bug exact)* | 3 échecs |
| le filtre retiré, le module répond à tout | 2 échecs |
| la sécurité oubliée sur le second enregistrement | 1 échec |

## Definition of done

- [x] Un marqueur `_gc` atteint le module, et un test le prouve au niveau du filtre
- [x] `_ground` l'atteint toujours
- [x] Un marqueur qui ne concerne pas ce module ne l'atteint pas
- [x] Les deux enregistrements déclarent `KNOWN_PILOT`
- [x] La mission de démo reconstruite en 6.16.2 et déployée pour vérification en jeu
